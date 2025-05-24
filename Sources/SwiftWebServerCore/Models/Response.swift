//
//  Response.swift
//  SwiftWebServer
//
//  Created by Tony Li on 22/4/20.
//  Copyright © 2020 Tony Li. All rights reserved.
//

import Foundation

public class Response {
    // properties
    public internal(set) var outputStream: OutputStream
    private var statusCode: Int = 200
    
    init(_ outputStream: OutputStream) {
        self.outputStream = outputStream
    }
    
    public func status(_ code: Int) -> Self {
        self.statusCode = code
        return self
    }
    
    private func preparePayload(contentType: String, content: String?) -> String
    {
        let responseContent: String
        let currentContentType: String

        if self.statusCode == 404 {
            responseContent = """
            <html><body><h1>Can't find the page, 404!</h1><img src="https://media.giphy.com/media/WQOIEQRgiK722l3PQT/giphy.gif" /></body></html>
            """
            currentContentType = "text/html; charset=utf-8"
        } else {
            responseContent = content ?? ""
            currentContentType = "\(contentType); charset=utf-8"
        }
        
        let statusText = HTTPURLResponse.localizedString(forStatusCode: self.statusCode)
        let resHeaders = String(format: "HTTP/1.1 %d %@\nContent-Length: %d\nContent-Type: %@\nConnection: Closed", self.statusCode, statusText, responseContent.utf8.count, currentContentType)
        
        let payload = String(format: "%@\n\n%@", resHeaders, responseContent)
        
        return payload
    }
    
    public func send(payload: String)
    {
        if let echoData = payload.data(using: .utf8)
        {
            echoData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Void in
                guard let baseAddress = ptr.baseAddress else { return }
                let pointer = baseAddress.assumingMemoryBound(to: UInt8.self)
                self.outputStream.write(pointer, maxLength: echoData.count)
            }
            print("sent")
        }
    }

    public func send(_ content: String) {
        let payload = preparePayload(contentType: "text/html", content: content)
        send(payload: payload)
        // Consider closing the outputStream or signaling connection closure if appropriate.
        // For now, just sending the payload.
    }

    public func json(_ jsonString: String) {
        let payload = preparePayload(contentType: "application/json", content: jsonString)
        send(payload: payload)
        // Similar consideration for closing stream as above.
    }
}
