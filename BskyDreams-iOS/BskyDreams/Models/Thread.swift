import Foundation

enum ThreadViewPost: Codable {
    case post(ThreadPost)
    case notFound(NotFoundPost)
    case blocked(BlockedPost)

    var post: ThreadPost? {
        if case .post(let p) = self { return p }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TypeKey.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "app.bsky.feed.defs#threadViewPost":
            self = .post(try ThreadPost(from: decoder))
        case "app.bsky.feed.defs#notFoundPost":
            self = .notFound(try NotFoundPost(from: decoder))
        case "app.bsky.feed.defs#blockedPost":
            self = .blocked(try BlockedPost(from: decoder))
        default:
            self = .notFound(NotFoundPost(uri: "", notFound: true))
        }
    }

    func encode(to encoder: Encoder) throws {}

    private enum TypeKey: String, CodingKey { case type = "$type" }
}

struct ThreadPost: Codable, Identifiable {
    var id: String { post.uri }
    let post: PostView
    let parent: ThreadViewPost?
    let replies: [ThreadViewPost]?
}

struct ThreadResponse: Codable {
    let thread: ThreadViewPost
}
