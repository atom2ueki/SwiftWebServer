//
//  BindRequestTests.swift
//  SwiftWebServerTests
//
//  Tests for the host: parameter resolution introduced alongside
//  loopback-bind support in `listen(_:host:completion:)`.
//

import XCTest
import Foundation
@testable import SwiftWebServer

@MainActor
final class BindRequestTests: XCTestCase {

    func testNilHostPreservesDualStackAnyBehavior() throws {
        let request = try BindRequest.resolve(host: nil)
        XCTAssertEqual(request.ipv4?.s_addr, INADDR_ANY)
        XCTAssertNotNil(request.ipv6)
        XCTAssertTrue(isUnspecified(request.ipv6))
    }

    func testLocalhostBindsBothLoopbackFamilies() throws {
        let request = try BindRequest.resolve(host: "localhost")
        XCTAssertEqual(request.ipv4?.s_addr, INADDR_LOOPBACK.bigEndian)
        XCTAssertNotNil(request.ipv6)
        XCTAssertTrue(isLoopback(request.ipv6))
    }

    func testIPv4LoopbackLiteralBindsIPv4Only() throws {
        let request = try BindRequest.resolve(host: "127.0.0.1")
        XCTAssertEqual(request.ipv4?.s_addr, INADDR_LOOPBACK.bigEndian)
        XCTAssertNil(request.ipv6)
    }

    func testIPv6LoopbackLiteralBindsIPv6Only() throws {
        let request = try BindRequest.resolve(host: "::1")
        XCTAssertNil(request.ipv4)
        XCTAssertNotNil(request.ipv6)
        XCTAssertTrue(isLoopback(request.ipv6))
    }

    func testIPv4AnyLiteralBindsIPv4Only() throws {
        let request = try BindRequest.resolve(host: "0.0.0.0")
        XCTAssertEqual(request.ipv4?.s_addr, INADDR_ANY)
        XCTAssertNil(request.ipv6)
    }

    func testIPv6AnyLiteralBindsIPv6Only() throws {
        let request = try BindRequest.resolve(host: "::")
        XCTAssertNil(request.ipv4)
        XCTAssertNotNil(request.ipv6)
        XCTAssertTrue(isUnspecified(request.ipv6))
    }

    func testInvalidHostThrows() {
        XCTAssertThrowsError(try BindRequest.resolve(host: "not.an.ip.address.here.invalid"))
        XCTAssertThrowsError(try BindRequest.resolve(host: ""))
    }

    func testListenWithLocalhostReachesRunningState() {
        let server = SwiftWebServer()
        let port = Self.ephemeralPort()
        var completed = false
        server.listen(UInt(port), host: "localhost") {
            completed = true
        }
        defer { server.close() }
        XCTAssertTrue(completed, "Completion should fire")
        guard case .running = server.status else {
            XCTFail("Expected .running, got \(server.status)")
            return
        }
    }

    func testListenWithInvalidHostFails() {
        let server = SwiftWebServer()
        var completed = false
        server.listen(0, host: "not.a.real.address") {
            completed = true
        }
        defer { server.close() }
        XCTAssertFalse(completed, "Completion should not fire on invalid host")
        guard case .error = server.status else {
            XCTFail("Expected .error, got \(server.status)")
            return
        }
    }

    func testInvalidHostLeavesCurrentPortAtZero() {
        // Regression test: previously `_currentPort` was set before host
        // resolution, so an invalid host left `currentPort` reporting the
        // requested port even though the server was in `.error`. Per
        // doc contract, `currentPort` is `0 if not running`.
        let server = SwiftWebServer()
        let requestedPort: UInt = 4242
        server.listen(requestedPort, host: "not.a.real.address") { }
        defer { server.close() }
        XCTAssertEqual(server.currentPort, 0, "currentPort must be 0 when status is .error")
    }

    func testIPv4BindFailureLeavesCurrentPortAtZero() {
        // Regression test: a failed bind() must reset _currentPort to 0
        // and tear down any partially-created sockets.
        let server = SwiftWebServer()
        let port = Self.ephemeralPort()
        // Hold the port via a parallel listener bound to loopback so the
        // server-under-test conflicts when it tries to bind the same port.
        let blocker = SwiftWebServer()
        blocker.listen(UInt(port), host: "127.0.0.1") { }
        defer { blocker.close() }
        precondition({
            if case .running = blocker.status { return true } else { return false }
        }(), "Test setup: blocker server must be running")

        server.listen(UInt(port), host: "127.0.0.1") { }
        defer { server.close() }
        guard case .error = server.status else {
            XCTFail("Expected .error after bind conflict, got \(server.status)")
            return
        }
        XCTAssertEqual(server.currentPort, 0, "currentPort must be 0 after bind failure")
    }

    // MARK: - Helpers

    private func isLoopback(_ addr: in6_addr?) -> Bool {
        guard var addr = addr else { return false }
        return withUnsafeBytes(of: &addr) { raw in
            raw.elementsEqual(Self.loopbackBytes)
        }
    }

    private func isUnspecified(_ addr: in6_addr?) -> Bool {
        guard var addr = addr else { return false }
        return withUnsafeBytes(of: &addr) { raw in
            raw.allSatisfy { $0 == 0 }
        }
    }

    private static let loopbackBytes: [UInt8] = {
        var bytes = [UInt8](repeating: 0, count: 16)
        bytes[15] = 1
        return bytes
    }()

    private static func ephemeralPort() -> UInt16 {
        // Reserve an ephemeral port via a throwaway socket so this test
        // doesn't collide with anything else on the host. We assert each
        // syscall result so a silent failure can't return port 0 and
        // make the calling test trivially pass against `listen(0)`.
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        precondition(fd >= 0, "Could not create temporary socket: errno \(errno)")
        defer { close(fd) }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = INADDR_LOOPBACK.bigEndian
        addr.sin_port = 0
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        precondition(bindResult == 0, "bind() failed in test helper: errno \(errno)")
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &len)
            }
        }
        precondition(nameResult == 0, "getsockname() failed in test helper: errno \(errno)")
        let port = UInt16(bigEndian: addr.sin_port)
        precondition(port != 0, "OS returned port 0 from getsockname; helper would return a meaningless port")
        return port
    }
}
