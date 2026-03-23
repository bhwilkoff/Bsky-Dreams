import Foundation

extension ATProtocolClient {
    func listNotifications(limit: Int = 50, cursor: String? = nil) async throws -> NotificationsResponse {
        var params: [String: String] = ["limit": "\(limit)"]
        if let cursor { params["cursor"] = cursor }
        return try await get("app.bsky.notification.listNotifications", params: params)
    }

    func updateNotificationsSeen() async throws {
        let formatter = ISO8601DateFormatter()
        try await postVoid("app.bsky.notification.updateSeen", body: [
            "seenAt": formatter.string(from: Date())
        ])
    }
}
