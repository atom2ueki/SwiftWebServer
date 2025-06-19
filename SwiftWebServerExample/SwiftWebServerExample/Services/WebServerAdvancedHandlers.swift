//
//  WebServerAdvancedHandlers.swift
//  SwiftWebServerExample
//
//  Advanced feature demonstration handlers
//

import Foundation
import SwiftWebServer

extension WebServerManager {
    
    // MARK: - ETag Demo
    
    func handleETagDemo(_ req: Request, _ res: Response) {
        let content = """
        {
            "message": "ETag demonstration",
            "timestamp": "\(ISO8601DateFormatter().string(from: Date()))",
            "data": {
                "server": "SwiftWebServer",
                "feature": "ETag caching",
                "description": "This response includes ETag headers for conditional requests"
            },
            "instructions": [
                "1. Make this request again to see the same ETag",
                "2. Add 'If-None-Match' header with the ETag value",
                "3. You should receive a 304 Not Modified response"
            ]
        }
        """
        
        // The ETag middleware will automatically handle ETag generation and conditional requests
        res.sendWithETag(content, contentType: .applicationJson)
        addLogMessage("ETag demo request processed", type: .info)
    }
    
    // MARK: - Cookie Demo
    
    func handleCookieDemo(_ req: Request, _ res: Response) {
        // Read existing cookies
        let existingCookies = req.cookies
        let visitCount = Int(existingCookies["visit_count"] ?? "0") ?? 0
        let newVisitCount = visitCount + 1
        
        // Set various types of cookies
        res.cookie("visit_count", "\(newVisitCount)", attributes: CookieAttributes(
            expires: Date().addingTimeInterval(3600), // 1 hour
            secure: false,
            httpOnly: false,
            sameSite: .lax
        ))
        
        res.cookie("session_demo", "demo-session-\(UUID().uuidString.prefix(8))", attributes: CookieAttributes(
            expires: Date().addingTimeInterval(1800), // 30 minutes
            secure: false,
            httpOnly: true,
            sameSite: .strict
        ))
        
        res.cookie("preferences", "theme=dark;lang=en", attributes: CookieAttributes(
            expires: Date().addingTimeInterval(86400 * 30), // 30 days
            secure: false,
            httpOnly: false,
            sameSite: .lax
        ))
        
        let responseData = [
            "message": "Cookie demonstration",
            "visit_count": newVisitCount,
            "cookies_received": existingCookies,
            "cookies_set": [
                "visit_count": "Tracks number of visits (1 hour expiry)",
                "session_demo": "Demo session cookie (30 minutes, HttpOnly)",
                "preferences": "User preferences (30 days)"
            ],
            "instructions": [
                "Check your browser's developer tools to see the Set-Cookie headers",
                "Make another request to see the visit count increment",
                "Cookies will be automatically sent back in subsequent requests"
            ]
        ] as [String : Any]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: responseData)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            res.json(jsonString)
            addLogMessage("Cookie demo: Visit #\(newVisitCount)", type: .info)
        } catch {
            res.internalServerError("Failed to generate cookie demo response")
        }
    }
    
    // MARK: - File Upload Demo
    
    func handleFileUploadDemo(_ req: Request, _ res: Response) {
        // Check if this is a multipart request
        guard let contentType = req.header("Content-Type"),
              contentType.contains("multipart/form-data") else {
            res.badRequest("File upload demo requires multipart/form-data. Use Content-Type: multipart/form-data and include a file field in your form data.")
            return
        }
        
        // In a real implementation, you would parse the multipart data
        // For this demo, we'll simulate file processing
        let simulatedFileInfo = [
            "message": "File upload demonstration",
            "status": "simulated_success",
            "file_info": [
                "name": "demo_file.txt",
                "size": "1024 bytes",
                "type": "text/plain",
                "uploaded_at": ISO8601DateFormatter().string(from: Date())
            ],
            "features_demonstrated": [
                "Multipart form data parsing",
                "File type detection",
                "File size validation",
                "Secure file handling"
            ],
            "note": "This is a simulation - actual file parsing would require additional implementation"
        ] as [String : Any]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: simulatedFileInfo)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            res.status(.created).json(jsonString)
            addLogMessage("File upload demo processed", type: .success)
        } catch {
            res.internalServerError("Failed to process upload demo")
        }
    }
    
    // MARK: - CORS Demo
    
    func handleCORSDemo(_ req: Request, _ res: Response) {
        // The CORS middleware automatically handles CORS headers
        // This endpoint demonstrates various CORS scenarios
        
        let origin = req.header("Origin") ?? "unknown"
        let method = req.method.rawValue
        
        let corsInfo = [
            "message": "CORS demonstration",
            "request_info": [
                "origin": origin,
                "method": method,
                "headers": req.headers.allHeaders
            ],
            "cors_headers_set": [
                "Access-Control-Allow-Origin": "Configured in CORSMiddleware",
                "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type, Authorization, Accept",
                "Access-Control-Allow-Credentials": "true"
            ],
            "features_demonstrated": [
                "Automatic CORS header injection",
                "Preflight request handling",
                "Origin validation",
                "Credential support"
            ],
            "test_instructions": [
                "Make a request from a different origin (e.g., from a web page)",
                "Check the response headers for CORS headers",
                "Try a preflight OPTIONS request",
                "Test with credentials included"
            ]
        ] as [String : Any]
        
        // Add some custom headers to demonstrate CORS
        res.header("X-Custom-Header", "CORS-Demo-Value")
        res.header("X-Server-Time", ISO8601DateFormatter().string(from: Date()))
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: corsInfo)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            res.json(jsonString)
            addLogMessage("CORS demo request from origin: \(origin)", type: .info)
        } catch {
            res.internalServerError("Failed to generate CORS demo response")
        }
    }
    
    // MARK: - Error Handling Demo
    
    func handleErrorDemo(_ req: Request, _ res: Response) {
        let errorType = req.query("type") ?? "generic"
        
        switch errorType {
        case "400":
            res.badRequest("Bad Request Demo - This demonstrates a 400 Bad Request error. Client sent invalid data or malformed request.")
            addLogMessage("Error demo: 400 Bad Request", type: .warning)
            
        case "401":
            res.unauthorized("Unauthorized Demo - This demonstrates a 401 Unauthorized error. Authentication required but not provided or invalid.")
            addLogMessage("Error demo: 401 Unauthorized", type: .warning)
            
        case "403":
            res.forbidden("Forbidden Demo - This demonstrates a 403 Forbidden error. User authenticated but lacks permission for this resource.")
            addLogMessage("Error demo: 403 Forbidden", type: .warning)
            
        case "404":
            res.notFound("Not Found Demo - This demonstrates a 404 Not Found error. The requested resource does not exist.")
            addLogMessage("Error demo: 404 Not Found", type: .warning)
            
        case "500":
            res.internalServerError("Internal Server Error Demo - This demonstrates a 500 Internal Server Error. Something went wrong on the server side.")
            addLogMessage("Error demo: 500 Internal Server Error", type: .error)
            
        case "timeout":
            // Simulate a timeout by delaying the response
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                res.status(408).json("""
                {
                    "error": "Request Timeout Demo",
                    "code": 408,
                    "message": "This demonstrates a delayed response (timeout simulation)",
                    "details": "Request took too long to process"
                }
                """)
            }
            addLogMessage("Error demo: Timeout simulation started", type: .warning)
            return
            
        default:
            let errorDemo = [
                "message": "Error Handling Demonstration",
                "available_error_types": [
                    "400": "Bad Request - ?type=400",
                    "401": "Unauthorized - ?type=401",
                    "403": "Forbidden - ?type=403",
                    "404": "Not Found - ?type=404",
                    "500": "Internal Server Error - ?type=500",
                    "timeout": "Request Timeout - ?type=timeout"
                ],
                "usage": "Add ?type=<error_code> to this endpoint to see different error responses",
                "features_demonstrated": [
                    "Proper HTTP status codes",
                    "Structured error responses",
                    "Error logging",
                    "Client-friendly error messages"
                ]
            ] as [String : Any]
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: errorDemo)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                res.json(jsonString)
                addLogMessage("Error demo: Overview requested", type: .info)
            } catch {
                res.internalServerError("Failed to generate error demo response")
            }
        }
    }
}
