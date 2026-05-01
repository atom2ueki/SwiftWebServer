//
//  BindRequest.swift
//  SwiftWebServer
//
//  Resolves the optional `host:` parameter passed to `listen(_:host:completion:)`
//  into the IPv4 and/or IPv6 addresses to bind. See the documentation on
//  `SwiftWebServer.listen(_:host:completion:)` for the supported values.
//

import Foundation

internal struct BindRequest {
    /// IPv4 address to bind, in network byte order. When `nil` no IPv4 socket is opened.
    let ipv4: in_addr?
    /// IPv6 address to bind. When `nil` no IPv6 socket is opened.
    let ipv6: in6_addr?

    static func resolve(host: String?) throws -> BindRequest {
        // nil preserves the original dual-stack ANY behavior so existing
        // call sites keep their semantics.
        guard let host else {
            return BindRequest(ipv4: in_addr(s_addr: INADDR_ANY), ipv6: in6addr_any)
        }

        // Convenience: bind both loopback families. Useful for OAuth callbacks
        // and other "this machine only" flows where the consumer doesn't care
        // whether the local browser uses IPv4 or IPv6 to reach localhost.
        if host == "localhost" {
            return BindRequest(
                ipv4: in_addr(s_addr: INADDR_LOOPBACK.bigEndian),
                ipv6: in6addr_loopback
            )
        }

        // Parse as IPv4 literal first.
        if let v4 = parseIPv4(host) {
            return BindRequest(ipv4: v4, ipv6: nil)
        }
        // Then IPv6.
        if let v6 = parseIPv6(host) {
            return BindRequest(ipv4: nil, ipv6: v6)
        }

        throw BindResolveError(message: "Invalid bind host '\(host)'. Pass an IPv4/IPv6 literal or \"localhost\".")
    }

    private static func parseIPv4(_ host: String) -> in_addr? {
        var addr = in_addr()
        let result = host.withCString { cstr in
            inet_pton(AF_INET, cstr, &addr)
        }
        return result == 1 ? addr : nil
    }

    private static func parseIPv6(_ host: String) -> in6_addr? {
        var addr = in6_addr()
        let result = host.withCString { cstr in
            inet_pton(AF_INET6, cstr, &addr)
        }
        return result == 1 ? addr : nil
    }
}

internal struct BindResolveError: Error {
    let message: String
}
