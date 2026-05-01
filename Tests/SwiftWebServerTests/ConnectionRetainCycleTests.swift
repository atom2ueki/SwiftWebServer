//
//  ConnectionRetainCycleTests.swift
//  SwiftWebServerTests
//
//  Regression tests for issue #6: Connection ↔ SwiftWebServer retain cycle.
//

import XCTest
@testable import SwiftWebServer

@MainActor
final class ConnectionRetainCycleTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        // Avoid bleeding state into other tests: a Connection's bg-queue
        // disconnect path may have queued an async update to this dict.
        SwiftWebServer.connections = [:]
    }

    /// With `Connection.server` held weakly, a live Connection must not
    /// keep the SwiftWebServer alive after its owner drops the last
    /// strong reference. Pre-fix (strong reference) this test fails:
    /// `connection.server -> server` pinned the graph indefinitely.
    func testConnectionHoldsServerWeakly() {
        weak var weakServer: SwiftWebServer?
        var connection: Connection?

        autoreleasepool {
            let server = SwiftWebServer()
            weakServer = server
            // Invalid socket handle: recv will fail quickly on the bg queue
            // without performing real I/O. We're testing the object graph,
            // not socket behavior.
            connection = Connection(nativeSocketHandle: -1, server: server)
            // Ensure the static dict is empty so it can't pin the server
            // transitively if a prior test left state behind — the cycle
            // under test is Connection.server, not the dictionary itself.
            SwiftWebServer.connections = [:]
        }

        XCTAssertNil(
            weakServer,
            "Connection.server must be weak so SwiftWebServer can deallocate while a Connection is still alive"
        )
        XCTAssertNotNil(connection, "Sanity: the Connection itself is still alive in this scope")
    }
}
