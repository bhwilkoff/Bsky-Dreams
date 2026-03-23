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

    /// Overload that accepts a pre-built [URLQueryItem] list, allowing repeated
    /// keys such as `?members=did1&members=did2` required by getConvoForMembers.
    func get<T: Decodable>(
        _ lexicon: String,
        queryItems: [URLQueryItem],
        useChat: Bool = false,
        authenticated: Bool = true
    ) async throws -> T {
        let base = useChat ? chatBaseURL : baseURL
        var components = URLComponents(url: base.appendingPathComponent(lexicon), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems
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

    // MARK: - Video Upload (video.bsky.app)

    private let videoBaseURL = URL(string: "https://video.bsky.app/xrpc/")!

    /// Cached PDS DID for the current session (e.g. "did:web:porcini.us-east.host.bsky.network").
    /// Resolved once from the PLC directory and reused for the session lifetime.
    private var cachedPdsDid: String? = nil

    /// Resolve the user's PDS DID by fetching their DID document from the PLC directory.
    /// video.bsky.app requires a service-scoped JWT whose audience is the user's PDS DID,
    /// not did:web:video.bsky.app.
    private func resolvePdsDid(userDid: String) async throws -> String {
        if let cached = cachedPdsDid { return cached }
        struct DidDoc: Decodable {
            struct Service: Decodable {
                let id: String
                let serviceEndpoint: String
            }
            let service: [Service]?
        }
        let url = URL(string: "https://plc.directory/\(userDid)")!
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.serverError(0, "Could not resolve DID document")
        }
        let doc = try decoder.decode(DidDoc.self, from: data)
        guard let pdsService = doc.service?.first(where: { $0.id == "#atproto_pds" }),
              let host = URL(string: pdsService.serviceEndpoint)?.host else {
            throw APIError.serverError(0, "No PDS service in DID document")
        }
        let pdsDid = "did:web:\(host)"
        cachedPdsDid = pdsDid
        print("[VideoUpload] Resolved PDS DID: \(pdsDid)")
        return pdsDid
    }

    /// Fetch a service-scoped JWT for the given audience DID and lexicon method.
    private func getServiceAuth(aud: String, lxm: String? = nil) async throws -> String {
        struct ServiceAuthResp: Decodable { let token: String }
        var params = ["aud": aud]
        if let lxm { params["lxm"] = lxm }
        let result: ServiceAuthResp = try await get(
            "com.atproto.server.getServiceAuth",
            params: params
        )
        return result.token
    }

    func uploadVideo(data: Data, mimeType: String = "video/mp4", did: String) async throws -> VideoJobStatus {
        let pdsDid = try await resolvePdsDid(userDid: did)
        let serviceToken = try await getServiceAuth(aud: pdsDid, lxm: "com.atproto.repo.uploadBlob")

        var components = URLComponents(url: videoBaseURL.appendingPathComponent("app.bsky.video.uploadVideo"), resolvingAgainstBaseURL: false)!
        let videoName = "video_\(Int(Date().timeIntervalSince1970)).mp4"
        components.queryItems = [
            URLQueryItem(name: "did", value: did),
            URLQueryItem(name: "name", value: videoName)
        ]
        var req = URLRequest(url: components.url!)
        req.httpMethod = "POST"
        req.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(serviceToken)", forHTTPHeaderField: "Authorization")
        req.httpBody = data
        req.timeoutInterval = 120  // video uploads can be large
        let (respData, response) = try await session.data(for: req)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode == 200 else {
            let err = try? decoder.decode(ATError.self, from: respData)
            throw APIError.serverError(statusCode, err?.message ?? "Video upload failed")
        }
        return try decoder.decode(VideoJobStatus.self, from: respData)
    }

    func getVideoJobStatus(jobId: String) async throws -> VideoJobStatus {
        struct Response: Decodable { let jobStatus: VideoJobStatus }
        var components = URLComponents(url: videoBaseURL.appendingPathComponent("app.bsky.video.getJobStatus"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "jobId", value: jobId)]
        var req = URLRequest(url: components.url!)
        req = try await authorizedRequest(req)
        let response: Response = try await perform(req)
        return response.jobStatus
    }

    /// Upload a video blob and poll until server processing completes.
    /// Returns the final `UploadedBlob` ready for embedding in a post.
    func uploadVideoAndWait(data: Data, mimeType: String = "video/mp4", did: String) async throws -> UploadedBlob {
        let job = try await uploadVideo(data: data, mimeType: mimeType, did: did)
        if job.state == "JOB_STATE_COMPLETED", let blob = job.blob { return blob }
        if job.state == "JOB_STATE_FAILED" {
            throw APIError.serverError(0, job.error ?? "Video processing failed")
        }
        // Poll up to 90 seconds
        for _ in 0..<90 {
            try await Task.sleep(for: .seconds(1))
            let status = try await getVideoJobStatus(jobId: job.jobId)
            if status.state == "JOB_STATE_COMPLETED", let blob = status.blob { return blob }
            if status.state == "JOB_STATE_FAILED" {
                throw APIError.serverError(0, status.error ?? "Video processing failed")
            }
        }
        throw APIError.serverError(0, "Video processing timed out — try a shorter clip")
    }

    /// Post a `[String: Any]` body via JSONSerialization (for dynamic AT Protocol records).
    func postDict<T: Decodable>(
        _ lexicon: String,
        body: [String: Any],
        useChat: Bool = false
    ) async throws -> T {
        let base = useChat ? chatBaseURL : baseURL
        var req = URLRequest(url: base.appendingPathComponent(lexicon))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req = try await authorizedRequest(req)
        return try await perform(req)
    }

    func postDictVoid(_ lexicon: String, body: [String: Any], useChat: Bool = false) async throws {
        _ = try await postDict(lexicon, body: body, useChat: useChat) as EmptyResponse
    }

    // MARK: - Seen Posts Sync (app.bsky-dreams.seen)

    private static let seenCollection = "app.bsky-dreams.seen"
    private static let seenRkey = "recent"

    /// Fetch the seen-posts record from the user's AT Protocol repo.
    /// Returns the list of URIs, or an empty array if the record doesn't exist yet.
    func getSeenRecord(repo: String) async throws -> [String] {
        struct SeenRecordResponse: Codable {
            let value: SeenRecordValue
            struct SeenRecordValue: Codable {
                let uris: [String]
            }
        }
        let result: SeenRecordResponse = try await get(
            "com.atproto.repo.getRecord",
            params: [
                "repo": repo,
                "collection": ATProtocolClient.seenCollection,
                "rkey": ATProtocolClient.seenRkey
            ]
        )
        return result.value.uris
    }

    /// Write (upsert) the seen-posts record to the user's AT Protocol repo.
    func putSeenRecord(repo: String, uris: [String]) async throws {
        let record: [String: Any] = [
            "$type": ATProtocolClient.seenCollection,
            "uris": uris,
            "syncedAt": Date().timeIntervalSince1970 * 1000
        ]
        let body: [String: Any] = [
            "repo": repo,
            "collection": ATProtocolClient.seenCollection,
            "rkey": ATProtocolClient.seenRkey,
            "record": record
        ]
        try await postDictVoid("com.atproto.repo.putRecord", body: body)
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
    let blob: UploadedBlob
}

/// The blob object returned by com.atproto.repo.uploadBlob.
/// Structure: { "$type": "blob", "ref": { "$link": "..." }, "mimeType": "...", "size": ... }
struct UploadedBlob: Codable {
    let ref: BlobRef
    let mimeType: String?
    let size: Int?
}

/// Job status returned by app.bsky.video.uploadVideo and app.bsky.video.getJobStatus.
struct VideoJobStatus: Codable {
    let jobId: String
    let did: String
    let state: String
    let blob: UploadedBlob?
    let error: String?
    let message: String?
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
