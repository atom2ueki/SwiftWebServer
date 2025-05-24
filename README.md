# SwiftWebServer

A lightweight, Express.js-inspired web server for Swift, built using Swift Package Manager.

## Project Structure

The core logic of the server is located in the `Sources/SwiftWebServerCore` directory. Tests can be found in `SwiftWebServerTests`.

## Installation

SwiftWebServer uses Swift Package Manager. To add it as a dependency to your Swift project, add the following to your `Package.swift` file's dependencies array:

```swift
.package(url: "your_repo_url_here", .upToNextMajor(from: "1.0.0")) // Replace with actual URL and version
```

And then add `SwiftWebServer` to your target's dependencies:

```swift
.target(
    name: "YourApp",
    dependencies: ["SwiftWebServer"]),
```

*(Note: You'll need to replace `"your_repo_url_here"` with the actual URL of this repository once it's published.)*

## Usage

Here's a basic example of how to create a server and define a route:

```swift
import SwiftWebServerCore // Or just SwiftWebServer if you name the product differently

let server = SwiftWebServer()

// Define a GET route
server.get("/hello") { req, res in
    let name = req.path.split(separator: "/").last ?? "World" // Example: /hello/Jules
    res.status(200).send("Hello, \(name)!")
}

// Define a POST route that echoes JSON
server.post("/echo") { req, res in
    // Assuming Request object will have a 'body' property in the future
    // For now, let's imagine it does for this example.
    // let requestBody = req.body ?? "{ "error": "No body" }" 
    // res.status(200).json(requestBody)

    // Placeholder until request body parsing is fully implemented
    res.status(200).json("{ "message": "POST request received, body parsing TBD" }")
}

// Start the server on port 8080
server.listen(8080) {
    print("Server started on port 8080")
}

// Keep the server running (e.g., by running the RunLoop)
RunLoop.current.run() 
```

### Request Object (`req`)

The `Request` object (passed as the first parameter to your route handlers) provides information about the incoming HTTP request:

*   `req.path`: The path of the request (e.g., "/hello").
*   `req.method`: The HTTP method (e.g., "GET", "POST").
*   `req.header`: The full request header string.
    *(Future enhancements will include parsed headers, query parameters, and request body.)*

### Response Object (`res`)

The `Response` object (passed as the second parameter) is used to send a response back to the client:

*   `res.status(code: Int)`: Sets the HTTP status code (e.g., `res.status(200)`). Returns `self` for chaining.
*   `res.send(content: String)`: Sends a plain text or HTML response. Sets Content-Type to `text/html`.
*   `res.json(content: String)`: Sends a JSON response. Sets Content-Type to `application/json`.

## Development

To build and test this package locally:

```bash
swift build
swift test
```
