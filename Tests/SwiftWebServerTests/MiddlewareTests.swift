import XCTest
@testable import SwiftWebServer

final class MiddlewareTests: XCTestCase {

    // MARK: - Middleware Chain Tests

    func testMiddlewareChainExecution() throws {
        let chain = MiddlewareChain()
        var executionOrder: [String] = []

        // Create test middleware
        let middleware1 = TestMiddleware(name: "middleware1", executionOrder: &executionOrder)
        let middleware2 = TestMiddleware(name: "middleware2", executionOrder: &executionOrder)
        let middleware3 = TestMiddleware(name: "middleware3", executionOrder: &executionOrder)

        chain.add(middleware1)
        chain.add(middleware2)
        chain.add(middleware3)

        // Create mock request and response
        let mockData = "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n".data(using: .utf8)!
        let request = try Request(inputData: mockData)
        let response = MockResponse()

        let expectation = XCTestExpectation(description: "Middleware chain execution")

        chain.execute(request: request, response: response) { error in
            XCTAssertNil(error)
            XCTAssertEqual(executionOrder, ["middleware1", "middleware2", "middleware3"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testMiddlewareChainWithError() throws {
        let chain = MiddlewareChain()
        var executionOrder: [String] = []

        // Create test middleware with one that throws an error
        let middleware1 = TestMiddleware(name: "middleware1", executionOrder: &executionOrder)
        let middleware2 = ErrorMiddleware()
        let middleware3 = TestMiddleware(name: "middleware3", executionOrder: &executionOrder)

        chain.add(middleware1)
        chain.add(middleware2)
        chain.add(middleware3)

        // Create mock request and response
        let mockData = "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n".data(using: .utf8)!
        let request = try Request(inputData: mockData)
        let response = MockResponse()

        let expectation = XCTestExpectation(description: "Middleware chain error handling")

        chain.execute(request: request, response: response) { error in
            XCTAssertNotNil(error)
            XCTAssertTrue(error is MiddlewareError)
            // Only middleware1 should have executed
            XCTAssertEqual(executionOrder, ["middleware1"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - BodyParser Tests

    func testBodyParserWithJSON() throws {
        let bodyParser = BodyParser()
        let jsonData = """
        {"name": "John", "age": 30}
        """.data(using: .utf8)!

        let requestData = """
        POST /api/test HTTP/1.1\r
        Content-Type: application/json\r
        Content-Length: \(jsonData.count)\r
        \r
        {"name": "John", "age": 30}
        """.data(using: .utf8)!

        let request = try Request(inputData: requestData)
        let response = MockResponse()

        let expectation = XCTestExpectation(description: "JSON body parsing")

        try bodyParser.execute(request: request, response: response) {
            XCTAssertNotNil(request.parsedBody)
            XCTAssertNotNil(request.jsonBody)

            if let jsonBody = request.jsonBody {
                XCTAssertEqual(jsonBody["name"] as? String, "John")
                XCTAssertEqual(jsonBody["age"] as? Int, 30)
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testBodyParserWithFormData() throws {
        let bodyParser = BodyParser()
        let formData = "name=John&age=30"

        let requestData = """
        POST /api/test HTTP/1.1\r
        Content-Type: application/x-www-form-urlencoded\r
        Content-Length: \(formData.count)\r
        \r
        \(formData)
        """.data(using: .utf8)!

        let request = try Request(inputData: requestData)
        let response = MockResponse()

        let expectation = XCTestExpectation(description: "Form data parsing")

        try bodyParser.execute(request: request, response: response) {
            XCTAssertNotNil(request.parsedBody)
            XCTAssertNotNil(request.formBody)

            if let formBody = request.formBody {
                XCTAssertEqual(formBody["name"], "John")
                XCTAssertEqual(formBody["age"], "30")
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Logger Middleware Tests

    func testLoggerMiddleware() throws {
        var logMessages: [String] = []
        let options = LoggerOptions(level: .basic, customLogger: { message in
            logMessages.append(message)
        })

        let logger = LoggerMiddleware(options: options)

        let mockData = "GET /test HTTP/1.1\r\nHost: localhost\r\n\r\n".data(using: .utf8)!
        let request = try Request(inputData: mockData)
        let response = MockResponse()

        let expectation = XCTestExpectation(description: "Logger middleware")

        try logger.execute(request: request, response: response) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(logMessages.count, 2) // Request and response logs
        XCTAssertTrue(logMessages[0].contains("GET /test"))
        XCTAssertTrue(logMessages[1].contains("GET /test"))
    }

    // MARK: - CORS Middleware Tests

    func testCORSMiddleware() throws {
        let cors = CORSMiddleware()

        let mockData = "GET /api/test HTTP/1.1\r\nHost: localhost\r\nOrigin: https://example.com\r\n\r\n".data(using: .utf8)!
        let request = try Request(inputData: mockData)
        let response = MockResponse()

        let expectation = XCTestExpectation(description: "CORS middleware")

        try cors.execute(request: request, response: response) {
            // Check that CORS headers were set
            XCTAssertNotNil(response.headers["Access-Control-Allow-Origin"])
            XCTAssertNotNil(response.headers["Access-Control-Allow-Methods"])
            XCTAssertNotNil(response.headers["Access-Control-Allow-Headers"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Auth Middleware Tests

    func testAuthMiddlewareWithValidToken() throws {
        let options = BearerTokenOptions(validator: { token in
            return token == "valid-token"
        })
        let auth = BearerTokenMiddleware(options: options)

        let mockData = "GET /secure HTTP/1.1\r\nHost: localhost\r\nAuthorization: Bearer valid-token\r\n\r\n".data(using: .utf8)!
        let request = try Request(inputData: mockData)
        let response = MockResponse()

        let expectation = XCTestExpectation(description: "Auth middleware with valid token")

        try auth.execute(request: request, response: response) {
            XCTAssertEqual(request.authToken, "valid-token")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testAuthMiddlewareWithInvalidToken() throws {
        let options = BearerTokenOptions(validator: { token in
            return token == "valid-token"
        })
        let auth = BearerTokenMiddleware(options: options)

        let mockData = "GET /secure HTTP/1.1\r\nHost: localhost\r\nAuthorization: Bearer invalid-token\r\n\r\n".data(using: .utf8)!
        let request = try Request(inputData: mockData)
        let response = MockResponse()

        // The middleware should handle the invalid token and not call next()
        // It should send an unauthorized response instead
        try auth.execute(request: request, response: response) {
            XCTFail("Expected middleware to handle invalid token and not call next()")
        }

        // Check that the response status was set to unauthorized
        XCTAssertEqual(response.statusCode, .unauthorized)
    }
}

// MARK: - Test Helper Classes

class TestMiddleware: Middleware {
    let name: String
    let executionOrder: UnsafeMutablePointer<[String]>

    init(name: String, executionOrder: UnsafeMutablePointer<[String]>) {
        self.name = name
        self.executionOrder = executionOrder
    }

    func execute(request: Request, response: Response, next: @escaping NextFunction) throws {
        executionOrder.pointee.append(name)
        try next()
    }
}

class ErrorMiddleware: Middleware {
    func execute(request: Request, response: Response, next: @escaping NextFunction) throws {
        throw MiddlewareError.chainInterrupted(reason: "Test error")
    }
}

class MockResponse: Response {
    init() {
        let mockServer = SwiftWebServer()
        let mockConnection = MockConnection(server: mockServer)
        super.init(connection: mockConnection)
    }
}

class MockConnection: Connection {
    init(server: SwiftWebServer) {
        // Create a mock connection that doesn't actually connect
        super.init(nativeSocketHandle: -1, server: server)
    }

    override func send(data: Data) {
        // Mock implementation - do nothing
    }

    override func disconnect() {
        // Mock implementation - do nothing
    }
}
