//
//  Connection.swift
//  SwiftWebServer
//
//  Created by Tony Li on 22/4/20.
//  Copyright © 2020 Tony Li. All rights reserved.
//

import Foundation
import CoreFoundation

public class Connection: NSObject {
    
    weak var server: SwiftWebServer?
    
    var inputData: Data
    
    var inputStream: InputStream
    var outputStream: OutputStream
    
    var isSpaceAvailable = false
    
    private let queue = DispatchQueue(label: "com.swiftwebserver.stream.queue", attributes: .concurrent)
    
    public init(inputStream: InputStream, outputStream: OutputStream) {
        #if DEBUG
        print("init a new conection.")
        #endif
        self.inputStream = inputStream
        self.outputStream = outputStream
        self.inputData = Data()
        super.init()
    }
    
    public func connect()
    {
        // set stream delegte
        self.inputStream.delegate = self
        self.outputStream.delegate = self
        
        // add streams into current runloop
        self.inputStream.schedule(in: RunLoop.current, forMode: .default)
        self.outputStream.schedule(in: RunLoop.current, forMode: .default)
        
        // open
        self.inputStream.open()
        self.outputStream.open()
    }
    
    public func disconnect()
    {
        #if DEBUG
        print("remove streams from runloop")
        #endif
        // remove streams from current runloop
        self.inputStream.remove(from: .current, forMode: .common)
        self.outputStream.remove(from: .current, forMode: .common)
        
        // close streams
        self.inputStream.close()
        self.outputStream.close()
        
        // remove itself from connections
        for connection in SwiftWebServer.connections
        {
            if connection.value == self
            {
                #if DEBUG
                print("removed from connection list.")
                #endif
                SwiftWebServer.connections.removeValue(forKey: connection.key)
            }
        }
    }
    
    private func hasBytesAvailable()
    {
        self.queue.async(flags: .barrier) {
            // read stream
            let bufferSize = 1024
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer {
                buffer.deallocate()
            }
            
            while self.inputStream.hasBytesAvailable {
                let bytesRead = self.inputStream.read(buffer, maxLength: bufferSize)
                if bytesRead > 0 {
                    self.inputData.append(buffer, count: bytesRead)
                }
            }
            
            if self.isSpaceAvailable && self.inputData.count > 0
            {
                #if DEBUG
                print("read data successful!")
                #endif
                self.hasSpaceAvailable()
            }
        }
    }
    
    private func hasSpaceAvailable()
    {
        self.queue.async { [weak self] in
            
            guard let `self` = self else {return}
            
            if self.outputStream.hasSpaceAvailable
            {
                #if DEBUG
                print("hasSpaceAvailable")
                #endif
                
                self.isSpaceAvailable = true
                
                if self.inputData.count > 0
                {
                    #if DEBUG
                    print("render page")
                    #endif
                    let request = Request(inputData: self.inputData)
                    let response = Response(self.outputStream)

                    if let routeHandlers = self.server?.routeHandlers, routeHandlers.count > 0
                    {
                        var found: Bool = false
                        
                        for routeHanlder in routeHandlers
                        {
                            let key = routeHanlder.key
                            let method = String(key.split(separator: " ")[0])
                            let path = String(key.split(separator: " ")[1])
                            if method == request.method && path == request.path
                            {
                                found = true
                                routeHanlder.value(request, response)
                            }
                        }
                        
                        if !found
                        {
                            response.status(404).send("") // Use Response object to send 404
                        }
                        
                    }else
                    {
                        print("server reference gone.")
                    }
                    
                    self.inputData = Data()
                    self.isSpaceAvailable = false
                    return
                }
            }
        }
    }
}

extension Connection: StreamDelegate
{
    public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .openCompleted:
            if aStream == self.outputStream
            {
                print("write openCompleted")
            }
            if aStream == self.inputStream
            {
                print("read openCompleted")
            }
            break
        case .errorOccurred:
            if aStream == self.outputStream
            {
                #if DEBUG
                if let msg = self.outputStream.streamError?.localizedDescription
                {
                    print("write errorOccurred: , %@", msg)
                }
                #endif
            }
            if aStream == self.inputStream
            {
                #if DEBUG
                if let msg = self.inputStream.streamError?.localizedDescription
                {
                    print("read errorOccurred: , %@", msg)
                }
                #endif
            }
            break
        case .hasBytesAvailable:
            hasBytesAvailable()
            break
        case .hasSpaceAvailable:
            hasSpaceAvailable()
            break
        case .endEncountered:
            if aStream == self.outputStream
            {
                #if DEBUG
                print("write endEncountered")
                #endif
                disconnect()
            }
            if aStream == self.inputStream
            {
                #if DEBUG
                print("read endEncountered")
                #endif
                disconnect()
            }
            break
        default:
            break
        }
    }
}
