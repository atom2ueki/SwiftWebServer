//
//  Connection.swift
//  SwiftWebServer
//
//  Connection handling with error management
//

import Foundation

class Connection {
    var nativeSocketHandle: Int32
    var server: SwiftWebServer?

    init(nativeSocketHandle: Int32, server: SwiftWebServer) {
        self.nativeSocketHandle = nativeSocketHandle
        self.server = server

        // start reading from socket
        readFromSocket()
    }

    func readFromSocket() {
        // Create a background queue for socket operations
        let queue = DispatchQueue(label: "atom2ueki.socket.read.queue", qos: .background)

        queue.async {
            var buffer = [UInt8](repeating: 0, count: 4096)
            let bytesRead = recv(self.nativeSocketHandle, &buffer, buffer.count, 0)

            if bytesRead > 0 {
                let data = Data(bytes: buffer, count: bytesRead)
                self.handleRequest(data: data)
            } else {
                // Handle connection error or closure
                self.handleConnectionError(bytesRead: bytesRead)
            }
        }
    }

    private func handleConnectionError(bytesRead: Int) {
        if bytesRead == 0 {
            // Connection closed by client
            print("Connection closed by client")
        } else {
            // Error occurred
            let error = SwiftWebServerError.connectionFailed(reason: "recv failed with code: \(bytesRead)")
            print("Connection error: \(error.errorDescription ?? "Unknown error")")
        }
        disconnect()
    }

    private func handleRequest(data: Data) {
        do {
            let request = try createRequest(from: data)
            let response = Response(connection: self)

            // Process the request
            processRequest(request: request, response: response)

        } catch let error as SwiftWebServerError {
            // Handle known server errors
            handleServerError(error)
        } catch {
            // Handle unexpected errors
            let serverError = SwiftWebServerError.unexpectedError(error: error)
            handleServerError(serverError)
        }
    }

    private func createRequest(from data: Data) throws -> Request {
        guard !data.isEmpty else {
            throw SwiftWebServerError.malformedRequest
        }

        // Validate request size
        let maxRequestSize = 1024 * 1024 // 1MB
        if data.count > maxRequestSize {
            throw SwiftWebServerError.requestTooLarge(size: data.count, maxSize: maxRequestSize)
        }

        return try Request(inputData: data)
    }

    private func processRequest(request: Request, response: Response) {
        // HTTP method is already validated during Request parsing

        // Build and execute middleware chain
        guard let server = self.server else {
            let error = SwiftWebServerError.internalServerError(reason: "Server reference lost")
            handleServerError(error, response: response)
            return
        }

        let middlewareChain = server.middlewareManagerInternal.buildChain(for: request)

        // Add the final route handler as the last "middleware"
        let routeHandlerMiddleware = RouteHandlerMiddleware(server: server)
        middlewareChain.add(routeHandlerMiddleware)

        // Execute the middleware chain
        middlewareChain.execute(request: request, response: response) { [weak self] error in
            if let error = error {
                if let serverError = error as? SwiftWebServerError {
                    self?.handleServerError(serverError, response: response)
                } else if let middlewareError = error as? MiddlewareError {
                    let serverError = SwiftWebServerError.middlewareError(error: middlewareError)
                    self?.handleServerError(serverError, response: response)
                } else {
                    let serverError = SwiftWebServerError.unexpectedError(error: error)
                    self?.handleServerError(serverError, response: response)
                }
            }
            // If no error, the response should have been sent by the route handler or middleware
        }
    }

    private func handleServerError(_ error: SwiftWebServerError, response: Response? = nil) {
        print("Server error: \(error.description)")

        if let response = response {
            // Send error response to client
            response.sendError(error)
        } else {
            // Create a basic error response
            let errorResponse = createErrorResponse(for: error)
            sendRawResponse(errorResponse)
        }
    }

    private func createErrorResponse(for error: SwiftWebServerError) -> String {
        let statusCode = error.httpStatusCode
        let body = error.errorResponseBody

        return """
        HTTP/1.1 \(statusCode.rawValue) \(statusCode.reasonPhrase)\r
        Content-Type: application/json\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
    }

    private func sendRawResponse(_ response: String) {
        let data = response.data(using: .utf8) ?? Data()
        _ = data.withUnsafeBytes { bytes in
            Darwin.send(nativeSocketHandle, bytes.bindMemory(to: UInt8.self).baseAddress, data.count, 0)
        }
    }

    func send(data: Data) {
        _ = data.withUnsafeBytes { bytes in
            Darwin.send(nativeSocketHandle, bytes.bindMemory(to: UInt8.self).baseAddress, data.count, 0)
        }
    }

    func disconnect() {
        close(nativeSocketHandle)

        // Remove from connections dictionary safely
        DispatchQueue.main.async {
            SwiftWebServer.connections = SwiftWebServer.connections.filter { $0.value !== self }
        }
    }
}

// MARK: - Route Handler Middleware

/// Internal middleware that handles route matching and execution
/// This is the final middleware in the chain that actually processes the route
internal class RouteHandlerMiddleware: Middleware {
    private weak var server: SwiftWebServer?

    init(server: SwiftWebServer) {
        self.server = server
    }

    func execute(request: Request, response: Response, next: @escaping NextFunction) throws {
        guard let server = self.server else {
            throw SwiftWebServerError.internalServerError(reason: "Server reference lost")
        }

        var routeFound = false

        // First, try to match routes using the new Router system
        if let routeMatch = server.router.findRoute(for: request) {
            routeFound = true
            // Set path parameters in the request
            request.setPathParameters(routeMatch.pathParameters)
            // Execute route handler
            routeMatch.route.handler(request, response)
            return // Don't call next() - route handled
        }

        // Fallback: try legacy route handlers for backward compatibility
        if let routeHandlers = server.routeHandlers, !routeHandlers.isEmpty {
            let requestKey = "\(request.method.rawValue) \(request.path)"

            if let handler = routeHandlers[requestKey] {
                routeFound = true
                // Execute route handler
                handler(request, response)
                return // Don't call next() - route handled
            }
        }

        // If no route found, try to serve static files (only for GET requests)
        if !routeFound && request.method == .get {
            if let staticFilePath = server.findStaticFile(for: request.path) {
                do {
                    try response.sendFile(staticFilePath)
                    routeFound = true
                    return // Don't call next() - file served
                } catch let error as SwiftWebServerError {
                    throw error
                } catch {
                    throw SwiftWebServerError.fileReadError(path: staticFilePath, reason: error.localizedDescription)
                }
            }
        }

        // If still no route or file found, send 404
        if !routeFound {
            // For GET requests, try to serve a custom 404 HTML page
            if request.method == .get {
                if let custom404Path = server.findStaticFile(for: "/404.html") {
                    do {
                        response.status(.notFound)
                        try response.sendFile(custom404Path)
                        return // Don't call next() - 404 page served
                    } catch {
                        // If custom 404 page fails, fall back to default error
                    }
                }
            }

            throw SwiftWebServerError.routeNotFound(path: request.path, method: request.method.rawValue)
        }
    }
}
