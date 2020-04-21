//
//  Request.swift
//  SwiftWebServer
//
//  Created by Tony Li on 22/4/20.
//  Copyright © 2020 Tony Li. All rights reserved.
//

import Foundation

class Request
{
    var header: String
    var method: String
    var path: String
    
    init(inputData: Data) {
        // parse data and get method and path.
        let header = String(decoding: inputData, as: UTF8.self)
        self.header = header
        if let headerParam = header.components(separatedBy: CharacterSet.newlines).first {
            #if DEBUG
            print(headerParam)
            #endif
            
            let requestParamSplit = headerParam.split(separator: " ")
            // three parts, {method, path, http version}
            if requestParamSplit.count >= 3
            {
                let method = requestParamSplit[0]
                self.method = String(method)
                let path = requestParamSplit[1]
                self.path = String(path)
                return
            }
        }
        // TODO: throw error.
        self.method = ""
        self.path = ""
    }
}
