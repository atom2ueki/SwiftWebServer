//
//  Response.swift
//  SwiftWebServer
//
//  HTTP Response handling with proper error management
//

import Foundation

public class Response {
    var connection: Connection?
    var statusCode: HTTPStatusCode = .ok
    var headers: HTTPHeaders = HTTPHeaders()

    init(connection: Connection) {
        self.connection = connection
    }

    // MARK: - Status Code Management

    @discardableResult
    public func status(_ code: HTTPStatusCode) -> Response {
        self.statusCode = code
        return self
    }

    @discardableResult
    public func status(_ code: Int) -> Response {
        self.statusCode = HTTPStatusCode(code: code)
        return self
    }

    // MARK: - Convenience Error Response Methods

    /// Set status code and send JSON error response in one call
    public func status(_ code: HTTPStatusCode, error message: String) {
        self.statusCode = code
        let errorJson = "{\"error\": \"\(message)\"}"
        json(errorJson)
    }

    /// Set status code and send JSON error response in one call (with integer status code)
    public func status(_ code: Int, error message: String) {
        self.statusCode = HTTPStatusCode(code: code)
        let errorJson = "{\"error\": \"\(message)\"}"
        json(errorJson)
    }

    // MARK: - Common Error Response Shortcuts

    /// Send 400 Bad Request with error message
    public func badRequest(_ message: String) {
        status(.badRequest, error: message)
    }

    /// Send 401 Unauthorized with error message
    public func unauthorized(_ message: String) {
        status(.unauthorized, error: message)
    }

    /// Send 403 Forbidden with error message
    public func forbidden(_ message: String) {
        status(.forbidden, error: message)
    }

    /// Send 404 Not Found with error message
    public func notFound(_ message: String) {
        status(.notFound, error: message)
    }

    /// Send 409 Conflict with error message
    public func conflict(_ message: String) {
        status(.conflict, error: message)
    }

    /// Send 500 Internal Server Error with error message
    public func internalServerError(_ message: String) {
        status(.internalServerError, error: message)
    }

    // MARK: - Header Management

    @discardableResult
    public func header(_ header: HTTPHeader, _ value: String) -> Response {
        headers[header] = value
        return self
    }

    @discardableResult
    public func header(_ name: String, _ value: String) -> Response {
        headers[name] = value
        return self
    }

    @discardableResult
    public func headers(_ newHeaders: [String: String]) -> Response {
        for (key, value) in newHeaders {
            headers[key] = value
        }
        return self
    }

    // MARK: - Content Type Helpers

    @discardableResult
    public func contentType(_ type: ContentType, charset: String? = nil) -> Response {
        headers[.contentType] = type.headerValue(charset: charset)
        return self
    }

    // MARK: - Response Building

    private func preparePayload(contentType: ContentType, content: String) -> String {
        // Set content type if not already set
        if headers[.contentType] == nil {
            headers[.contentType] = contentType.headerValue()
        }

        // Set content length
        headers[.contentLength] = "\(content.utf8.count)"

        // Build headers string
        var headerString = ""
        for (key, value) in headers.allHeaders {
            headerString += "\(key): \(value)\r\n"
        }

        let payload = """
        HTTP/1.1 \(statusCode.rawValue) \(statusCode.reasonPhrase)\r
        \(headerString)\r
        \(content)
        """
        return payload
    }

    private func send(payload: String) {
        guard let connection = connection else {
            print("No connection available to send response")
            return
        }

        let data = payload.data(using: .utf8) ?? Data()
        connection.send(data: data)

        // Close connection after sending response
        connection.disconnect()
    }

    // MARK: - Public Response Methods

    public func send(_ content: String) {
        let payload = preparePayload(contentType: .textPlain, content: content)
        send(payload: payload)
    }

    public func html(_ htmlContent: String) {
        let payload = preparePayload(contentType: .textHtml, content: htmlContent)
        send(payload: payload)
    }

    public func json(_ jsonString: String) {
        let payload = preparePayload(contentType: .applicationJson, content: jsonString)
        send(payload: payload)
    }

    public func json<T: Encodable>(_ object: T) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(object)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw SwiftWebServerError.jsonParsingError(reason: "Failed to convert encoded data to string")
        }
        json(jsonString)
    }

    // MARK: - File Serving

    public func sendFile(_ filePath: String) throws {
        let fileURL = URL(fileURLWithPath: filePath)

        guard FileManager.default.fileExists(atPath: filePath) else {
            throw SwiftWebServerError.fileNotFound(path: filePath)
        }

        do {
            let fileData = try Data(contentsOf: fileURL)
            let contentType = ContentType.from(filePath: filePath)

            if contentType.isText {
                // For text files, convert to string
                guard let content = String(data: fileData, encoding: .utf8) else {
                    throw SwiftWebServerError.contentEncodingError(reason: "Failed to decode file as UTF-8")
                }
                let payload = preparePayload(contentType: contentType, content: content)
                send(payload: payload)
            } else {
                // For binary files, send raw data
                sendBinaryFile(data: fileData, contentType: contentType)
            }
        } catch let error as SwiftWebServerError {
            throw error
        } catch {
            throw SwiftWebServerError.fileReadError(path: filePath, reason: error.localizedDescription)
        }
    }

    private func sendBinaryFile(data: Data, contentType: ContentType) {
        // Set content type
        headers[.contentType] = contentType.mimeType
        headers[.contentLength] = "\(data.count)"

        // Build headers
        var headerString = ""
        for (key, value) in headers.allHeaders {
            headerString += "\(key): \(value)\r\n"
        }

        let responseHeader = """
        HTTP/1.1 \(statusCode.rawValue) \(statusCode.reasonPhrase)\r
        \(headerString)\r

        """

        guard let connection = connection else {
            print("No connection available to send response")
            return
        }

        // Send header
        if let headerData = responseHeader.data(using: .utf8) {
            connection.send(data: headerData)
        }

        // Send binary data
        connection.send(data: data)
        connection.disconnect()
    }

    // MARK: - Error Response

    public func sendError(_ error: SwiftWebServerError) {
        status(error.httpStatusCode)
        json(error.errorResponseBody)
    }

    // MARK: - Redirect

    /// Redirect to a URL with specified status code
    public func redirect(_ url: String, status: HTTPStatusCode = .found) {
        self.status(status)
        header(.location, url)
        send("")
    }

    /// Redirect to a URL (temporary redirect - 302)
    public func redirect(_ url: String, permanent: Bool = false) {
        status(permanent ? .movedPermanently : .found)
        header(.location, url)
        send("")
    }

    /// Permanent redirect (301 Moved Permanently)
    public func redirectPermanent(_ url: String) {
        redirect(url, status: .movedPermanently)
    }

    /// Temporary redirect (302 Found)
    public func redirectTemporary(_ url: String) {
        redirect(url, status: .found)
    }

    /// Temporary redirect preserving method (307 Temporary Redirect)
    public func redirectTemporaryPreserveMethod(_ url: String) {
        redirect(url, status: .temporaryRedirect)
    }

    /// Permanent redirect preserving method (308 Permanent Redirect)
    public func redirectPermanentPreserveMethod(_ url: String) {
        redirect(url, status: .permanentRedirect)
    }
}
