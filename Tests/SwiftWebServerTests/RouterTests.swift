//
//  RouterTests.swift
//  SwiftWebServerTests
//
//  Tests for the new Router system and parameter parsing
//

import XCTest
@testable import SwiftWebServer

final class RouterTests: XCTestCase {

    var router: Router!

    override func setUp() {
        super.setUp()
        router = Router()
    }

    override func tearDown() {
        router = nil
        super.tearDown()
    }

    // MARK: - Path Segment Tests

    func testPathSegmentParsing() {
        let segments = PathSegment.parse(pattern: "/user/{id}/posts/{postId}")

        XCTAssertEqual(segments.count, 4)
        XCTAssertEqual(segments[0], .literal("user"))
        XCTAssertEqual(segments[1], .parameter("id"))
        XCTAssertEqual(segments[2], .literal("posts"))
        XCTAssertEqual(segments[3], .parameter("postId"))
    }

    func testSimplePathSegmentParsing() {
        let segments = PathSegment.parse(pattern: "/api/status")

        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0], .literal("api"))
        XCTAssertEqual(segments[1], .literal("status"))
    }

    func testParameterOnlyPath() {
        let segments = PathSegment.parse(pattern: "/{id}")

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0], .parameter("id"))
    }

    // MARK: - Route Matching Tests

    func testSimpleRouteMatching() throws {
        // Create a mock request
        let requestData = "GET /user/123 HTTP/1.1\r\nHost: localhost\r\n\r\n".data(using: .utf8)!
        let request = try Request(inputData: requestData)

        // Add route to router
        router.addRoute(method: .get, pattern: "/user/{id}") { _, _ in
            // Handler implementation
        }

        // Test route matching
        let match = router.findRoute(for: request)
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.pathParameters["id"], "123")
    }

    func testMultipleParameterRouteMatching() throws {
        let requestData = "GET /user/456/posts/789 HTTP/1.1\r\nHost: localhost\r\n\r\n".data(using: .utf8)!
        let request = try Request(inputData: requestData)

        router.addRoute(method: .get, pattern: "/user/{userId}/posts/{postId}") { _, _ in
            // Handler implementation
        }

        let match = router.findRoute(for: request)
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.pathParameters["userId"], "456")
        XCTAssertEqual(match?.pathParameters["postId"], "789")
    }

    func testNoMatchForDifferentMethod() throws {
        let requestData = "POST /user/123 HTTP/1.1\r\nHost: localhost\r\n\r\n".data(using: .utf8)!
        let request = try Request(inputData: requestData)

        router.addRoute(method: .get, pattern: "/user/{id}") { _, _ in
            // Handler implementation
        }

        let match = router.findRoute(for: request)
        XCTAssertNil(match)
    }

    func testNoMatchForDifferentPath() throws {
        let requestData = "GET /admin/123 HTTP/1.1\r\nHost: localhost\r\n\r\n".data(using: .utf8)!
        let request = try Request(inputData: requestData)

        router.addRoute(method: .get, pattern: "/user/{id}") { _, _ in
            // Handler implementation
        }

        let match = router.findRoute(for: request)
        XCTAssertNil(match)
    }

    func testExactPathMatching() throws {
        let requestData = "GET /api/status HTTP/1.1\r\nHost: localhost\r\n\r\n".data(using: .utf8)!
        let request = try Request(inputData: requestData)

        router.addRoute(method: .get, pattern: "/api/status") { _, _ in
            // Handler implementation
        }

        let match = router.findRoute(for: request)
        XCTAssertNotNil(match)
        XCTAssertTrue(match?.pathParameters.isEmpty ?? false)
    }

    // MARK: - Path Parameter Parser Tests

    func testPathParameterParsing() {
        let parameters = PathParameterParser.parseParameters(from: "/user/123", using: "/user/{id}")

        XCTAssertNotNil(parameters)
        XCTAssertEqual(parameters?["id"], "123")
    }

    func testMultiplePathParameterParsing() {
        let parameters = PathParameterParser.parseParameters(
            from: "/user/456/posts/789",
            using: "/user/{userId}/posts/{postId}"
        )

        XCTAssertNotNil(parameters)
        XCTAssertEqual(parameters?["userId"], "456")
        XCTAssertEqual(parameters?["postId"], "789")
    }

    func testPathParameterParsingMismatch() {
        let parameters = PathParameterParser.parseParameters(from: "/user/123/extra", using: "/user/{id}")
        XCTAssertNil(parameters)
    }

    func testParameterSegmentDetection() {
        XCTAssertTrue(PathParameterParser.isParameterSegment("{id}"))
        XCTAssertTrue(PathParameterParser.isParameterSegment("{userId}"))
        XCTAssertFalse(PathParameterParser.isParameterSegment("user"))
        XCTAssertFalse(PathParameterParser.isParameterSegment("{incomplete"))
        XCTAssertFalse(PathParameterParser.isParameterSegment("incomplete}"))
    }

    func testParameterNameExtraction() {
        XCTAssertEqual(PathParameterParser.extractParameterName(from: "{id}"), "id")
        XCTAssertEqual(PathParameterParser.extractParameterName(from: "{userId}"), "userId")
        XCTAssertEqual(PathParameterParser.extractParameterName(from: "literal"), "literal")
    }

    func testPatternValidation() {
        XCTAssertTrue(PathParameterParser.validatePattern("/user/{id}"))
        XCTAssertTrue(PathParameterParser.validatePattern("/user/{userId}/posts/{postId}"))
        XCTAssertTrue(PathParameterParser.validatePattern("/api/status"))
        XCTAssertFalse(PathParameterParser.validatePattern("/user/{"))
        XCTAssertFalse(PathParameterParser.validatePattern("/user/}"))
        XCTAssertFalse(PathParameterParser.validatePattern("/user/{}"))
    }

    // MARK: - Query Parameter Parser Tests

    func testQueryParameterParsing() {
        let parameters = QueryParameterParser.parseQueryString("name=John&age=30&city=NYC")

        XCTAssertEqual(parameters["name"], "John")
        XCTAssertEqual(parameters["age"], "30")
        XCTAssertEqual(parameters["city"], "NYC")
    }

    func testQueryParameterURLDecoding() {
        let parameters = QueryParameterParser.parseQueryString("name=John%20Doe&message=Hello%20World")

        XCTAssertEqual(parameters["name"], "John Doe")
        XCTAssertEqual(parameters["message"], "Hello World")
    }

    func testEmptyQueryString() {
        let parameters = QueryParameterParser.parseQueryString("")
        XCTAssertTrue(parameters.isEmpty)
    }

    func testQueryParameterWithoutValue() {
        let parameters = QueryParameterParser.parseQueryString("flag&name=John")

        XCTAssertEqual(parameters["flag"], "")
        XCTAssertEqual(parameters["name"], "John")
    }

    func testQueryStringExtraction() {
        XCTAssertEqual(
            QueryParameterParser.extractQueryString(from: "http://example.com/path?name=John&age=30"),
            "name=John&age=30"
        )
        XCTAssertEqual(
            QueryParameterParser.extractQueryString(from: "/path?name=John"),
            "name=John"
        )
        XCTAssertNil(QueryParameterParser.extractQueryString(from: "/path"))
    }

    // MARK: - Request Integration Tests

    func testRequestPathParameterIntegration() throws {
        let requestData = "GET /user/123?name=John HTTP/1.1\r\nHost: localhost\r\n\r\n".data(using: .utf8)!
        let request = try Request(inputData: requestData)

        // Simulate router setting path parameters
        request.setPathParameters(["id": "123"])

        XCTAssertEqual(request.param("id"), "123")
        XCTAssertEqual(request.query("name"), "John")
        XCTAssertEqual(request.params["id"], "123")
    }

    func testRequestWithoutParameters() throws {
        let requestData = "GET /api/status HTTP/1.1\r\nHost: localhost\r\n\r\n".data(using: .utf8)!
        let request = try Request(inputData: requestData)

        XCTAssertNil(request.param("id"))
        XCTAssertTrue(request.params.isEmpty)
    }
}
