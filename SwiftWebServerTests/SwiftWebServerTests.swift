//
//  SwiftWebServerTests.swift
//  SwiftWebServerTests
//
//  Created by Tony Li on 22/4/20.
//  Copyright © 2020 Tony Li. All rights reserved.
//

import XCTest
@testable import SwiftWebServerCore

class SwiftWebServerTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testRouteRegistration() {
        let server = SwiftWebServer()
        let expectation = self.expectation(description: "Route handler should be called")
        expectation.isInverted = true // We are not actually calling it in this unit test

        server.get("/test") { req, res in
            // In a real E2E test, we'd send a response and verify it.
            // For this unit test, merely reaching here if called would be enough,
            // but we are testing registration, not invocation.
            XCTFail("Handler should not be directly invoked in this test setup")
            expectation.fulfill() 
        }

        // Check if the route handler is registered
        // The key format is "METHOD PATH" e.g. "GET /test"
        XCTAssertNotNil(server.routeHandlers?["GET /test"], "GET /test route should be registered")
        
        // Fulfill the expectation if we are not calling the handler.
        // If the handler was meant to be called, this would be inside the handler.
        // Since we are just testing registration, we fulfill it if the handler is registered.
        // However, the above XCTAssertNotNil is the primary check.
        // For an inverted expectation, we don't fulfill it if we don't expect it to be called.
        // So, if XCTAssertNotNil passes, the registration part is fine.
        
        // To satisfy the expectation for an inverted one, we wait for a short timeout.
        // If the handler (with XCTFail) is NOT called, the test passes.
        waitForExpectations(timeout: 0.1)
    }

    func testPostRouteRegistration() {
        let server = SwiftWebServer()
        server.post("/submit") { req, res in
            // Handler logic
        }
        XCTAssertNotNil(server.routeHandlers?["POST /submit"], "POST /submit route should be registered")
    }

}
