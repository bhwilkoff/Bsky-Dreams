import Foundation

// MARK: - AT Protocol HTTP Client

@MainActor
final class ATProtocolClient {
    static let shared = ATProtocolClient()

    let baseURL = URL(string: "https://bsky.social/xrpc/")!
    let chatBaseURL = URL(string: "https://api.bsky.chat/xrpc/")!

    private var authManager: AuthManager?
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }

    func configure(authManager: AuthManager) {
        self.authManager = authManager
    }

    // MARK: - Core Request Methods

    func get<T: Decodable>(
        _ lexicon: String,
        params: [String: String] = [:],
        useChat: Bool = false,
        authenticated: Bool = true
    ) async throws -> T {
        let base = useChat ? chatBaseURL : baseURL
        var components = URLComponents(url: base.appendingPathComponent(lexicon), resolvingAgainstBaseURL: false)!
        if !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var req = URLRequest(url: components.url!)
        if authenticated {
            req = try await authorizedRequest(req)
        }
        return try await perform(req)
    }

    func post<T: Decodable>(
        _ lexicon: String,
        body: some Encodable,
        useChat: Bool = false,
        authenticated: Bool = true
    ) async throws -> T {
        let base = useChat ? chatBaseURL : baseURL
        var req = URLRequest(url: base.appendingPathComponent(lexicon))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        if authenticated {
            req = try await authorizedRequest(req)
        }
        return try await perform(req)
    }

    func postVoid(
        _ lexicon: String,
        body: some Encodable,
        useChat: Bool = false
    ) async throws {
        let base = useChat ? chatBaseURL : baseURL
        var req = URLRequest(url: base.appendingPathComponent(lexicon))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        req = try await authorizedRequest(req)
        _ = try await perform(req) as EmptyResponse
    }

    func uploadBlob(data: Data, mimeType: String) async throws -> BlobResponse {
        var req = URLRequest(url: baseURL.appendingPathComponent("com.atproto.repo.uploadBlob"))
        req.httpMethod = "POST"
        req.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        req = try await authorizedRequest(req)
        return try await perform(req)
    }

    // MARK: - Private

    private func authorizedRequest(_ req: URLRequest) async throws -> URLRequest {
        guard let auth = authManager, let session = auth.session else {
            throw AuthError.notLoggedIn
        }
        var req = req
        req.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
        return req
    }

    private func perform<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: req)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            // Refresh and retry once
            await authManager?.refreshSession()
            guard let auth = authManager, let newSession = auth.session else {
                throw AuthError.notLoggedIn
            }
            var retryReq = req
            retryReq.setValue("Bearer \(newSession.accessJwt)", forHTTPHeaderField: "Authorization")
            let (retryData, retryResponse) = try await session.data(for: retryReq)
            guard let retryHTTP = retryResponse as? HTTPURLResponse,
                  retryHTTP.statusCode == 200 else {
                throw AuthError.refreshFailed
            }
            return try decoder.decode(T.self, from: retryData)
        }

        guard httpResponse.statusCode == 200 else {
            let err = try? decoder.decode(ATError.self, from: data)
            throw APIError.serverError(httpResponse.statusCode, err?.message ?? "Unknown error")
        }

        return try decoder.decode(T.self, from: data)
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .useDefaultKeys
        return d
    }
}

// MARK: - Response Models

struct BlobResponse: Codable {
    let blob: BlobRef
}

struct EmptyResponse: Codable {}

struct CreateRecordResponse: Codable {
    let uri: String
    let cid: String
}

enum APIError: LocalizedError {
    case invalidResponse
    case serverError(Int, String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid server response"
        case .serverError(let code, let msg): "Server error \(code): \(msg)"
        case .decodingFailed: "Failed to parse response"
        }
    }
}
