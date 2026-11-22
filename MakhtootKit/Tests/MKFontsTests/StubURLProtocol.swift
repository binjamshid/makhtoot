import Foundation

/// Minimal `URLProtocol` stub so `MKFontDownloader`/`MKCatalogManifestFetchService`
/// tests exercise real `URLSession` code paths (real request construction,
/// real response/status handling) without any real network access ، no
/// third-party mocking library (D-101).
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Response: Sendable {
        var statusCode: Int
        var data: Data
        var error: Error?
    }

    /// Keyed by absolute URL string. `nonisolated(unsafe)` + a lock: this
    /// is test-only global mutable state, guarded manually since
    /// `URLProtocol`'s override points are not `async`.
    private static let lock = NSLock()
    nonisolated(unsafe) private static var responses: [String: Response] = [:]
    nonisolated(unsafe) private static var callCount: [String: Int] = [:]

    static func stub(_ url: URL, statusCode: Int = 200, data: Data = Data(), error: Error? = nil) {
        lock.lock(); defer { lock.unlock() }
        responses[url.absoluteString] = Response(statusCode: statusCode, data: data, error: error)
    }

    static func callCount(for url: URL) -> Int {
        lock.lock(); defer { lock.unlock() }
        return callCount[url.absoluteString] ?? 0
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        responses.removeAll()
        callCount.removeAll()
    }

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { client?.urlProtocolDidFinishLoading(self); return }
        Self.lock.lock()
        let response = Self.responses[url.absoluteString]
        Self.callCount[url.absoluteString, default: 0] += 1
        Self.lock.unlock()

        guard let response else {
            client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
            return
        }
        if let error = response.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let httpResponse = HTTPURLResponse(url: url, statusCode: response.statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
