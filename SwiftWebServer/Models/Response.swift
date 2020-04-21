//
//  Response.swift
//  SwiftWebServer
//
//  Created by Tony Li on 22/4/20.
//  Copyright © 2020 Tony Li. All rights reserved.
//

import Foundation

class Response {
    // properties
    var outputStream: OutputStream
    
    init(_ outputStream: OutputStream) {
        self.outputStream = outputStream
    }
    
    func preparePayload(content: String? = nil, code: Int) -> String
    {
        if code == 404
        {
            let content = """
            <html><body><h1>Can't find the page, 404!</h1><img src="https://media.giphy.com/media/WQOIEQRgiK722l3PQT/giphy.gif" /></body></html>
            """
            
            let resHeaders = String(format: "HTTP/1.1 %d OK\nContent-Length: %d\nContent-Type: text/html; encoding=utf8\nConnection: Closed", code, content.count)
            
            let payload = String(format: "%@\n\n%@", resHeaders, content)
            
            return payload
        }else
        {
            if let content = content
            {
                let resHeaders = String(format: "HTTP/1.1 %d OK\nContent-Length: %d\nContent-Type: text/html; encoding=utf8\nConnection: Closed", code, content.count)
                
                let payload = String(format: "%@\n\n%@", resHeaders, content)
                
                return payload
            }
            
            
        }
        return ""
    }
    
    func send(aStream: OutputStream, payload: String)
    {
        if let echoData = payload.data(using: .utf8)
        {
            if let sentData = echoData.withUnsafeBytes({ pointer in
                return pointer.baseAddress?.bindMemory(to: UInt8.self, capacity: 1)
            }) {
                aStream.write(sentData, maxLength: echoData.count)
                print("sent")
            }
        }
    }
}
