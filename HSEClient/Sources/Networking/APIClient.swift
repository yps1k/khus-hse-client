import Foundation

/// Client for the private HSE App X backend (api.hseapp.ru).
/// Versions are per-endpoint (verified live): some paths sit under /v3/, some /v2/, some at root.
@MainActor
final class APIClient {
    static let host = "https://api.hseapp.ru"
    private let auth: AuthService

    init(auth: AuthService) { self.auth = auth }

    enum Version: String { case v3 = "/v3/", v2 = "/v2/", root = "/" }

    // MARK: Public endpoints

    func profile() async throws -> Profile {
        try await get("dump/me", .v3)
    }

    /// Own schedule.
    func schedule(from: Date, to: Date) async throws -> [Lesson] {
        try await timetable(from: from, to: to)
    }

    /// Schedule of any target: own (all nil), a person (email), a group, or an auditorium.
    func timetable(from: Date, to: Date,
                   email: String? = nil, group: String? = nil, auditorium: String? = nil) async throws -> [Lesson] {
        let f = DateFormatter.yyyyMMdd
        var q = "ruz/lessons?start=\(f.string(from: from))&end=\(f.string(from: to))"
        if let email { q += "&email=\(email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email)" }
        if let group { q += "&group=\(group)" }
        if let auditorium { q += "&auditorium=\(auditorium)" }
        return try await get(q, .v3)
    }

    /// Buildings grouped by campus (for the free-rooms finder).
    func buildings() async throws -> [Campus] {
        try await post("dump/buildings/groups", .v3, body: ["is_free": false])
    }

    /// Free rooms in a building during [from, to].
    func freeRooms(buildingId: String, from: Date, to: Date) async throws -> [FreeRoom] {
        let iso = ISO8601DateFormatter()
        let body: [String: Any] = [
            "building_id": buildingId,
            "date_from": iso.string(from: from),
            "date_to": iso.string(from: to),
            "capacity_gte": 0,
            "facilities": [String](),
        ]
        let resp: FreeRoomsResponse = try await post("rooms/free", .root, body: body)
        return resp.rooms
    }

    /// Full profile of any person by email (the "account" page).
    func person(email: String) async throws -> PersonProfile {
        let enc = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? email
        return try await get("dump/email/\(enc)", .v3)
    }

    /// People search (type nil), or GROUP / AUDITORIUM.
    func search(_ query: String, type: String? = nil) async throws -> [SearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        var q = "dump/search?q=\(encoded)"
        if let type { q += "&type=\(type)" }
        return try await get(q, .v3)
    }

    func grades() async throws -> GradesResponse {
        try await get("grades", .v2)
    }

    func deadlines(completed: Bool = false) async throws -> DeadlinesResponse {
        try await post("deadlines", .v2, body: ["is_completed": completed])
    }

    func notifications() async throws -> NotificationsResponse {
        try await get("notifications/feed", .v2)
    }

    func cafes() async throws -> [CafeGroup] {
        try await get("food/cafes", .root)
    }

    // MARK: Core

    private func get<T: Decodable>(_ path: String, _ v: Version) async throws -> T {
        try await request(path, v, method: "GET", body: nil)
    }

    private func post<T: Decodable>(_ path: String, _ v: Version, body: [String: Any]) async throws -> T {
        let data = try JSONSerialization.data(withJSONObject: body)
        return try await request(path, v, method: "POST", body: data)
    }

    private func request<T: Decodable>(_ path: String, _ v: Version, method: String, body: Data?) async throws -> T {
        func make(_ token: String) -> URLRequest {
            var req = URLRequest(url: URL(string: Self.host + v.rawValue + path)!)
            req.httpMethod = method
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("ru", forHTTPHeaderField: "Accept-Language")
            if let body {
                req.httpBody = body
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            return req
        }

        var token = try await auth.validAccessToken()
        var (data, resp) = try await Net.data(for: make(token))

        // One retry on 401 with a forced refresh (token revoked early).
        if (resp as? HTTPURLResponse)?.statusCode == 401 {
            try await auth.forceRefresh()
            token = try await auth.validAccessToken()
            (data, resp) = try await Net.data(for: make(token))
        }

        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.http((resp as? HTTPURLResponse)?.statusCode ?? -1, body)
        }
        do {
            return try JSONDecoder.hse.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }
}

enum APIError: LocalizedError {
    case http(Int, String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .http(let code, _): return "Ошибка запроса (HTTP \(code))"
        case .decoding: return "Не удалось разобрать ответ"
        }
    }
}

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Moscow")
        return f
    }()
}

extension JSONDecoder {
    /// Decoder that understands the API's ISO-8601 timestamps (with and without fractional seconds).
    static let hse: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            if let date = ISO8601DateFormatter.withFractional.date(from: s) { return date }
            if let date = ISO8601DateFormatter.plain.date(from: s) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Bad date: \(s)"))
        }
        return d
    }()
}

extension ISO8601DateFormatter {
    static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
    }()
}
