import Foundation
import AuthenticationServices
import AppKit

/// Stored token set (persisted in Keychain as JSON).
struct Tokens: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date

    var isExpiringSoon: Bool { Date() >= expiresAt.addingTimeInterval(-60) }
}

enum AuthState {
    case loading     // reading Keychain at launch
    case signedOut
    case signedIn
}

enum AuthError: LocalizedError {
    case cancelled
    case noCode
    case server(String)
    case notLoggedIn

    var errorDescription: String? {
        switch self {
        case .cancelled: return "Вход отменён"
        case .noCode: return "В ответе нет кода авторизации"
        case .server(let m): return "Сервер ВШЭ: \(m)"
        case .notLoggedIn: return "Не выполнен вход"
        }
    }
}

/// OAuth2 + PKCE against HSE Keycloak, with token storage and refresh.
/// client_id / redirect are the public ones used by HSE App X.
@MainActor
final class AuthService: NSObject, ObservableObject {
    // MARK: Config (reverse-engineered from HSE App X)
    static let keycloak = "https://saml.hse.ru/realms/hse/protocol/openid-connect"
    static let clientID = "app-x-android"
    static let redirectURI = "ru.hse.hseappx://saml.hse.ru/authorize_callback"
    static let callbackScheme = "ru.hse.hseappx"
    static let scope = "profile email"

    @Published private(set) var state: AuthState = .loading
    @Published var lastError: String?

    private var tokens: Tokens? {
        didSet { state = (tokens == nil) ? .signedOut : .signedIn }
    }
    /// Single in-flight refresh shared by all callers (prevents the refresh-token race).
    private var refreshTask: Task<Void, Error>?
    private var webSession: ASWebAuthenticationSession?

    override init() {
        super.init()
        // Read Keychain off the main thread so launch never blocks on it.
        Task { [weak self] in
            let data = await Task.detached { Keychain.load() }.value
            let loaded = data.flatMap { try? JSONDecoder().decode(Tokens.self, from: $0) }
            await MainActor.run { self?.tokens = loaded }   // nil → signedOut, value → signedIn
        }
    }

    // MARK: Login

    func login() async {
        lastError = nil
        let pkce = PKCE()
        var comps = URLComponents(string: Self.keycloak + "/auth")!
        comps.queryItems = [
            .init(name: "client_id", value: Self.clientID),
            .init(name: "redirect_uri", value: Self.redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: Self.scope),
            .init(name: "state", value: pkce.state),
            .init(name: "code_challenge", value: pkce.challenge),
            .init(name: "code_challenge_method", value: "S256"),
        ]
        do {
            let callback = try await authenticate(url: comps.url!)
            let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
            guard let code = items.first(where: { $0.name == "code" })?.value else { throw AuthError.noCode }
            try await exchange(code: code, verifier: pkce.verifier)
        } catch {
            if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                lastError = AuthError.cancelled.localizedDescription
            } else {
                lastError = error.localizedDescription
            }
        }
    }

    func logout() {
        refreshTask?.cancel()
        refreshTask = nil
        tokens = nil
        Task.detached { Keychain.clear() }
    }

    private func authenticate(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(
                url: url, callbackURLScheme: Self.callbackScheme
            ) { callbackURL, error in
                if let error { cont.resume(throwing: error) }
                else if let callbackURL { cont.resume(returning: callbackURL) }
                else { cont.resume(throwing: AuthError.cancelled) }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.webSession = session
            session.start()
        }
    }

    // MARK: Token endpoints

    private func exchange(code: String, verifier: String) async throws {
        try await tokenRequest(form: [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": Self.redirectURI,
            "code_verifier": verifier,
        ])
    }

    /// Returns a valid access token, refreshing if needed. All callers share one refresh.
    func validAccessToken() async throws -> String {
        // If a refresh is already running, wait for it instead of starting another.
        if let task = refreshTask { try await task.value }
        guard let t = tokens else { throw AuthError.notLoggedIn }
        if t.isExpiringSoon { try await refreshNow() }
        guard let token = tokens?.accessToken else { throw AuthError.notLoggedIn }
        return token
    }

    /// Force a refresh (used after a 401), coalesced with any in-flight one.
    func forceRefresh() async throws { try await refreshNow() }

    private func refreshNow() async throws {
        if let task = refreshTask { return try await task.value }
        guard let rt = tokens?.refreshToken else { throw AuthError.notLoggedIn }
        let task = Task<Void, Error> { [weak self] in
            guard let self else { return }
            try await self.tokenRequest(form: ["grant_type": "refresh_token", "refresh_token": rt])
        }
        refreshTask = task
        defer { refreshTask = nil }
        try await task.value
    }

    private func tokenRequest(form: [String: String]) async throws {
        var req = URLRequest(url: URL(string: Self.keycloak + "/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var body = form
        body["client_id"] = Self.clientID
        req.httpBody = body
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, resp) = try await Net.data(for: req)
        let http = resp as? HTTPURLResponse
        if http?.statusCode == 400 || http?.statusCode == 401 {
            // invalid_grant: the session ended (refresh expired or reused) → require re-login.
            tokens = nil
            Task.detached { Keychain.clear() }
            let msg = (try? JSONDecoder().decode([String: AnyCodable].self, from: data))?["error"]?.value as? String
            throw AuthError.server(msg ?? "invalid_grant")
        }
        guard (200..<300).contains(http?.statusCode ?? 0) else {
            throw AuthError.server("HTTP \(http?.statusCode ?? -1)")
        }
        let r = try JSONDecoder().decode(TokenResponse.self, from: data)
        let new = Tokens(
            accessToken: r.access_token,
            refreshToken: r.refresh_token,
            expiresAt: Date().addingTimeInterval(TimeInterval(r.expires_in))
        )
        tokens = new
        if let enc = try? JSONEncoder().encode(new) {
            Task.detached { Keychain.save(enc) }
        }
    }
}

private struct TokenResponse: Decodable {
    let access_token: String
    let refresh_token: String
    let expires_in: Int
}

/// Tiny type-erased decodable, used only to read the "error" field.
private struct AnyCodable: Decodable {
    let value: Any
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { value = s }
        else if let i = try? c.decode(Int.self) { value = i }
        else { value = "" }
    }
}

// MARK: - Presentation anchor (macOS)

extension AuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? ASPresentationAnchor()
    }
}
