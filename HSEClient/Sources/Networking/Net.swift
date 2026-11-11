import Foundation

/// Shared URLSession with sane timeouts, plus one automatic retry when a connection
/// went stale during idle/sleep (URLSession otherwise reuses a dead socket and hangs).
enum Net {
    static let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 20      // per request
        c.timeoutIntervalForResource = 40     // whole transfer
        c.waitsForConnectivity = false
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: c)
    }()

    static func data(for req: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: req)
        } catch let error as URLError where isTransient(error) {
            // Stale/dropped connection — retry once forces a fresh one.
            return try await session.data(for: req)
        }
    }

    private static func isTransient(_ error: URLError) -> Bool {
        switch error.code {
        case .networkConnectionLost, .timedOut, .cannotConnectToHost,
             .cannotFindHost, .dnsLookupFailed, .notConnectedToInternet:
            return true
        default:
            return false
        }
    }
}
