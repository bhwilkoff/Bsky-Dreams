import Foundation
import Observation

@Observable
@MainActor
final class AuthManager {
    var session: BskySession?
    var isLoggedIn: Bool { session != nil }
    var isLoading = false
    var errorMessage: String?

    private let keychain = KeychainManager()
    private let sessionKey = "bsky_session"
    private let credentialsKey = "bsky_saved_creds"

    init() {
        session = keychain.loadSession(key: sessionKey)
    }

    // MARK: - Login

    func login(handle: String, appPassword: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let cleanHandle = handle.hasPrefix("@") ? String(handle.dropFirst()) : handle

        do {
            let result = try await createSession(handle: cleanHandle, password: appPassword)
            session = result
            keychain.saveSession(result, key: sessionKey)
            // Save credentials for silent re-auth when both tokens expire
            let creds = SavedCredentials(handle: cleanHandle, appPassword: appPassword)
            if let data = try? JSONEncoder().encode(creds) {
                keychain.saveData(data, key: credentialsKey)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Logout

    func logout() {
        session = nil
        keychain.deleteSession(key: sessionKey)
        keychain.deleteSession(key: credentialsKey)
    }

    // MARK: - Token Refresh

    func refreshIfNeeded() async {
        guard let s = session else { return }
        guard let exp = jwtExpiry(s.accessJwt) else {
            // Can't parse expiry — try refresh as a safety measure
            await refreshSession()
            return
        }

        // Refresh if within 1 hour of expiry, or already expired (negative interval)
        if exp.timeIntervalSinceNow < 3600 {
            await refreshSession()
        }
    }

    /// One refresh at a time: refresh tokens ROTATE, so parallel 401s each
    /// refreshing with the same token make every caller but the first fail.
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    func refreshSession() async {
        if let inFlight = refreshTask { return await inFlight.value }
        let task = Task { await performRefreshFlow() }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    private func performRefreshFlow() async {
        // Start from the NEWEST tokens in the Keychain: the background notification
        // check refreshes with its own AuthManager, which rotates the refresh token
        // out from under this instance's in-memory copy.
        guard let s = keychain.loadSession(key: sessionKey) ?? session else { return }
        do {
            let refreshed = try await performRefresh(refreshJwt: s.refreshJwt)
            session = refreshed
            keychain.saveSession(refreshed, key: sessionKey)
        } catch AuthError.refreshFailed {
            // The server REJECTED the refresh token — try silent re-auth with saved
            // credentials. Keep the existing session alive during the attempt.
            await trySilentReauth()
        } catch {
            // Offline / timeout / 5xx: transient. Keep the session; the next
            // foreground or 401 retries. Never log anyone out for a dead network.
        }
    }

    // MARK: - Silent Re-authentication

    private func trySilentReauth() async {
        guard let data = keychain.loadData(key: credentialsKey),
              let creds = try? JSONDecoder().decode(SavedCredentials.self, from: data) else {
            // No saved credentials — force re-login
            session = nil
            keychain.deleteSession(key: sessionKey)
            return
        }

        do {
            let result = try await createSession(handle: creds.handle, password: creds.appPassword)
            session = result
            keychain.saveSession(result, key: sessionKey)
        } catch AuthError.loginFailed {
            // The server rejected the saved app password (revoked) — clear everything.
            session = nil
            keychain.deleteSession(key: sessionKey)
            keychain.deleteSession(key: credentialsKey)
        } catch {
            // Transient (offline, rate-limited, 5xx) — keep credentials for the next try.
        }
    }

    // MARK: - API

    private func createSession(handle: String, password: String) async throws -> BskySession {
        let url = URL(string: "https://bsky.social/xrpc/com.atproto.server.createSession")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["identifier": handle, "password": password])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard httpResponse.statusCode == 200 else {
            let err = try? JSONDecoder().decode(ATError.self, from: data)
            // Only 400/401 mean "these credentials are wrong"; 429/5xx are transient.
            if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
                throw AuthError.loginFailed(err?.message ?? "Invalid credentials")
            }
            throw APIError.serverError(httpResponse.statusCode, err?.message ?? "Bluesky is unavailable — try again shortly")
        }
        return try JSONDecoder().decode(BskySession.self, from: data)
    }

    private func performRefresh(refreshJwt: String) async throws -> BskySession {
        let url = URL(string: "https://bsky.social/xrpc/com.atproto.server.refreshSession")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(refreshJwt)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
                throw AuthError.refreshFailed
            }
            throw APIError.serverError(httpResponse.statusCode, "refreshSession")
        }
        return try JSONDecoder().decode(BskySession.self, from: data)
    }

    private func jwtExpiry(_ jwt: String) -> Date? {
        let parts = jwt.components(separatedBy: ".")
        guard parts.count == 3 else { return nil }
        var base64 = parts[1]
        let remainder = base64.count % 4
        if remainder != 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: base64),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = payload["exp"] as? TimeInterval else { return nil }
        return Date(timeIntervalSince1970: exp)
    }
}

// MARK: - Models

struct BskySession: Codable {
    let accessJwt: String
    let refreshJwt: String
    let handle: String
    let did: String
    let email: String?
    let emailConfirmed: Bool?
}

struct SavedCredentials: Codable {
    let handle: String
    let appPassword: String
}

struct ATError: Codable {
    let error: String?
    let message: String?
}

enum AuthError: LocalizedError {
    case loginFailed(String)
    case refreshFailed
    case notLoggedIn

    var errorDescription: String? {
        switch self {
        case .loginFailed(let msg): return "Login failed: \(msg)"
        case .refreshFailed: return "Session expired. Please log in again."
        case .notLoggedIn: return "You must be logged in."
        }
    }
}
