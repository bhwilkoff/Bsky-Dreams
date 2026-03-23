import Foundation

indirect enum ThreadViewPost: Codable {
    case post(ThreadPost)
    case notFound(NotFoundPost)
    case blocked(BlockedPost)

    var post: ThreadPost? {
        if case .post(let p) = self { return p }
        return nil
    }

    init(from decoder: Decoder) throws {
        guard let container = try? decoder.container(keyedBy: TypeKey.self),
              let type = try? container.decode(String.self, forKey: .type) else {
            self = .notFound(NotFoundPost(uri: "", notFound: true))
            return
        }
        switch type {
        case "app.bsky.feed.defs#threadViewPost":
            self = (try? .post(ThreadPost(from: decoder))) ?? .notFound(NotFoundPost(uri: "", notFound: true))
        case "app.bsky.feed.defs#notFoundPost":
            self = (try? .notFound(NotFoundPost(from: decoder))) ?? .notFound(NotFoundPost(uri: "", notFound: true))
        case "app.bsky.feed.defs#blockedPost":
            self = (try? .blocked(BlockedPost(from: decoder))) ?? .notFound(NotFoundPost(uri: "", notFound: true))
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
