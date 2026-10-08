import Foundation

extension ATProtocolClient {
    func listNotifications(limit: Int = 50, cursor: String? = nil) async throws -> NotificationsResponse {
        var params: [String: String] = ["limit": "\(limit)"]
        if let cursor { params["cursor"] = cursor }
        return try await get("app.bsky.notification.listNotifications", params: params)
    }

    /// Server-side unread total (counting a fetched page capped the badge at its size).
    func unreadNotificationCount() async throws -> Int {
        struct Response: Codable { let count: Int }
        let r: Response = try await get("app.bsky.notification.getUnreadCount", params: [:])
        return r.count
    }

    func updateNotificationsSeen() async throws {
        let formatter = ISO8601DateFormatter()
        try await postVoid("app.bsky.notification.updateSeen", body: [
            "seenAt": formatter.string(from: Date())
        ])
    }
}
