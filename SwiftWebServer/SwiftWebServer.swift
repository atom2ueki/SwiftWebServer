//
//  SwiftWebServer.swift
//  SwiftWebServer
//
//  Created by Tony Li on 22/4/20.
//  Copyright © 2020 Tony Li. All rights reserved.
//

import Foundation
import CoreFoundation

final public class SwiftWebServer
{
    // completion arrays
    typealias routeHandler = (_ res: Connection) -> Void
    var routeHandlers: [String: routeHandler]?
    
    // store connections
    static var connections = [CFData: Connection]()
    
    var ipv4cfsocket: CFSocket!
    var ipv6cfsocket: CFSocket!
    
    static var times: Int = 0
    
    public init()
    {
        routeHandlers = [String: routeHandler]()
    }
    
    private let handleConnect: CFSocketCallBack = { socket, callbackType, address, data, info in
        if callbackType == CFSocketCallBackType.acceptCallBack {
            guard let socket = socket, let info = info, let address = address, CFSocketIsValid(socket),
                let nativeSocketHandle = data?.bindMemory(to: CFSocketNativeHandle.self, capacity: 1).pointee else { return }
            
            let server = Unmanaged<SwiftWebServer>.fromOpaque(info).takeUnretainedValue()
            
            if SwiftWebServer.connections[address] == nil
            {
                let intTrue: UInt32 = 1
                let unsafeIntTrue = withUnsafePointer(to: intTrue) { truePointer in
                    return truePointer
                }
                
                let setReuseAddressResult = setsockopt(nativeSocketHandle, SOL_SOCKET, SO_REUSEADDR, unsafeIntTrue, socklen_t(MemoryLayout<UInt32>.size))
                
                if setReuseAddressResult == 0
                {
                    acceptConnection(server: server, address: address, nativeSocketHandle: nativeSocketHandle)
                }
            }else
            {
                print("still exist")
            }
        }else
        {
            print(123)
        }
    }
    
    private func porthtons(port: in_port_t) -> in_port_t {
        let isLittleEndian = Int(OSHostByteOrder()) == OSLittleEndian
        return isLittleEndian ? _OSSwapInt16(port) : port
    }
    
    static func acceptConnection(server: SwiftWebServer, address: CFData, nativeSocketHandle: CFSocketNativeHandle)
    {
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        
        // create connection
        CFStreamCreatePairWithSocket(kCFAllocatorDefault, nativeSocketHandle, &readStream, &writeStream)
        guard let inputStream = readStream?.takeRetainedValue(), let outputStream = writeStream?.takeRetainedValue() else
        {
            return
        }
        
        (inputStream as InputStream).setProperty(true, forKey: kCFStreamPropertyShouldCloseNativeSocket as Stream.PropertyKey)
        (outputStream as OutputStream).setProperty(true, forKey: kCFStreamPropertyShouldCloseNativeSocket as Stream.PropertyKey)
        
        let connection = Connection(inputStream: inputStream, outputStream: outputStream)
        connection.server = server
        SwiftWebServer.connections[address] = connection
        connection.connect()
    }
    
    public func listen(_ port: UInt, completion: () -> Void)
    {
        // prepare reuse address
        let intTrue: UInt32 = 1
        let unsafeIntTrue = withUnsafePointer(to: intTrue) { truePointer in
            return truePointer
        }
        
        var context = CFSocketContext(version: 0,
                                      info: UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque()),
                                      retain: nil,
                                      release: nil,
                                      copyDescription: nil)
        
        ipv4cfsocket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, CFSocketCallBackType.acceptCallBack.rawValue, self.handleConnect, &context)

//        let ipv4Sock = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP)
//        ipv4cfsocket = CFSocketCreateWithNative(kCFAllocatorDefault, ipv4Sock, CFSocketCallBackType.acceptCallBack.rawValue, handleConnect, &context)

        let setReuseAddressV4Result = setsockopt(CFSocketGetNative(ipv4cfsocket), SOL_SOCKET, SO_REUSEADDR, unsafeIntTrue, socklen_t(MemoryLayout<UInt32>.size))

        if setReuseAddressV4Result != 0
        {
            print("something wrong ipv4 reuse ip & port.")
        }
        
//        let ipv6Sock = socket(PF_INET6, SOCK_STREAM, IPPROTO_TCP)
//        ipv6cfsocket = CFSocketCreateWithNative(kCFAllocatorDefault, ipv6Sock, CFSocketCallBackType.acceptCallBack.rawValue, handleConnect, &context)
        
        ipv6cfsocket = CFSocketCreate(kCFAllocatorDefault, PF_INET6, SOCK_STREAM, IPPROTO_TCP, CFSocketCallBackType.acceptCallBack.rawValue, self.handleConnect, &context)
        
        let setReuseAddressV6Result = setsockopt(CFSocketGetNative(ipv6cfsocket), SOL_SOCKET, SO_REUSEADDR, unsafeIntTrue, socklen_t(MemoryLayout<UInt32>.size))

        if setReuseAddressV6Result != 0
        {
            print("something wrong ipv6 reuse ip & port.")
        }
        
//        let setNOSIGPIPEAddressV6Result = setsockopt(CFSocketGetNative(ipv6cfsocket), SOL_SOCKET, SO_NOSIGPIPE, unsafeIntTrue, socklen_t(MemoryLayout<UInt32>.size))
//
//        if setNOSIGPIPEAddressV6Result != 0
//        {
//            print("something wrong ipv6 SO_NOSIGPIPE.")
//        }
        
        // bind ipv4
        var sin = sockaddr_in()
        sin.sin_len = UInt8(MemoryLayout<sockaddr_in>.stride)
        sin.sin_family = sa_family_t(AF_INET)
        sin.sin_port = porthtons(port: in_port_t(port))
        sin.sin_addr.s_addr = INADDR_ANY

        // bind a socket with CFSocketSetAddress.
        withUnsafePointer(to: sin) { pointer in
            pointer.withMemoryRebound(to: UInt8.self, capacity: 1, { bytes in
                let sincfd = CFDataCreate(kCFAllocatorDefault, bytes, CFIndex(sin.sin_len))
                CFSocketSetAddress(ipv4cfsocket, sincfd)
            })
        }
        
        // bind ipv6
        var sin6 = sockaddr_in6()
        sin6.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.stride)
        sin6.sin6_family = sa_family_t(AF_INET6)
        sin6.sin6_port = porthtons(port: in_port_t(port))
        sin6.sin6_addr = in6addr_any

        // bind a socket with CFSocketSetAddress.
        withUnsafePointer(to: sin6) { pointer in
            pointer.withMemoryRebound(to: UInt8.self, capacity: 1, { bytes in
                let sin6cfd = CFDataCreate(kCFAllocatorDefault, bytes, CFIndex(sin6.sin6_len))
                CFSocketSetAddress(ipv6cfsocket, sin6cfd)
            })
        }
        
        // listening on a socket by adding the socket to a run loop.
        let socketsource4 = CFSocketCreateRunLoopSource(kCFAllocatorDefault, ipv4cfsocket, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), socketsource4, CFRunLoopMode.defaultMode)
        
        let socketsource6 = CFSocketCreateRunLoopSource(kCFAllocatorDefault, ipv6cfsocket, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), socketsource6, CFRunLoopMode.defaultMode)
        
        // callback
        completion()
    }
    
    public func close()
    {
        let socketsourceV4 = CFSocketCreateRunLoopSource(kCFAllocatorDefault, ipv4cfsocket, 0)
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), socketsourceV4, CFRunLoopMode.defaultMode)
        CFSocketInvalidate(ipv4cfsocket)
        
        let socketsourceV6 = CFSocketCreateRunLoopSource(kCFAllocatorDefault, ipv6cfsocket, 0)
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), socketsourceV6, CFRunLoopMode.defaultMode)
        CFSocketInvalidate(ipv6cfsocket)
        
        // close all connections inside connections
        for connection in SwiftWebServer.connections
        {
            connection.value.disconnect()
        }
    }
}

// MARK: make routes for server
// TODO: use factor pattern to handle CURD operations.
extension SwiftWebServer
{
    public func get(_ path: String, completion: @escaping (_ res: Connection) -> Void)
    {
        // req is request object.
        let key = String(format: "%@ %@", "GET", path)
        
        // res is connection object.
        self.routeHandlers?[key] = completion
    }
    
    public func post(_ path: String, completion: @escaping (_ res: Connection) -> Void)
    {
        // req is request object.
        let key = String(format: "%@ %@", "POST", path)
        
        // res is connection object.
        self.routeHandlers?[key] = completion
    }
    
    public func put(_ path: String, completion: @escaping (_ res: Connection) -> Void)
    {
        // req is request object.
        let key = String(format: "%@ %@", "PUT", path)
        
        // res is connection object.
        self.routeHandlers?[key] = completion
    }
    
    public func delete(_ path: String, completion: @escaping (_ res: Connection) -> Void)
    {
        // req is request object.
        let key = String(format: "%@ %@", "DELETE", path)
        
        // res is connection object.
        self.routeHandlers?[key] = completion
    }
}
