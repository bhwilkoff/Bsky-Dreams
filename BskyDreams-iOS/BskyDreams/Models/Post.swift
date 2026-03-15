import Foundation

// MARK: - Core Post Models

struct PostView: Codable, Identifiable, Hashable {
    var id: String { uri }
    let uri: String
    let cid: String
    let author: ActorProfile
    let record: PostRecord
    let embed: Embed?
    let likeCount: Int?
    let replyCount: Int?
    let repostCount: Int?
    let indexedAt: String
    let viewer: PostViewer?
    let labels: [Label]?

    // For reply context in feed
    let reply: FeedReplyContext?

    var rkey: String { uri.components(separatedBy: "/").last ?? "" }

    var relativeTime: String {
        guard let date = ISO8601DateFormatter().date(from: indexedAt) else { return "" }
        return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }

    static func == (lhs: PostView, rhs: PostView) -> Bool { lhs.uri == rhs.uri }
    func hash(into hasher: inout Hasher) { hasher.combine(uri) }
}

struct PostRecord: Codable {
    let text: String
    let createdAt: String
    let langs: [String]?
    let facets: [RichTextFacet]?
    let reply: PostReplyRef?
    let embed: RecordEmbed?
    let tags: [String]?
}

struct PostReplyRef: Codable {
    let root: StrongRef
    let parent: StrongRef
}

struct StrongRef: Codable {
    let uri: String
    let cid: String
}

struct FeedReplyContext: Codable {
    let root: FeedContextPost?
    let parent: FeedContextPost?

    enum FeedContextPost: Codable {
        case post(PostView)
        case notFound(NotFoundPost)
        case blocked(BlockedPost)

        var postView: PostView? {
            if case .post(let v) = self { return v }
            return nil
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let post = try? container.decode(PostView.self) {
                self = .post(post)
            } else if let nf = try? container.decode(NotFoundPost.self) {
                self = .notFound(nf)
            } else {
                let blocked = try container.decode(BlockedPost.self)
                self = .blocked(blocked)
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .post(let v): try container.encode(v)
            case .notFound(let v): try container.encode(v)
            case .blocked(let v): try container.encode(v)
            }
        }
    }
}

struct NotFoundPost: Codable {
    let uri: String
    let notFound: Bool
}

struct BlockedPost: Codable {
    let uri: String
    let blocked: Bool
}

// MARK: - Post Viewer State

struct PostViewer: Codable {
    let muted: Bool?
    let blocked: Bool?
    let like: String?       // AT URI of like record if liked
    let repost: String?     // AT URI of repost record if reposted
    let replyDisabled: Bool?
    let embeddingDisabled: Bool?
}

// MARK: - Rich Text Facets

struct RichTextFacet: Codable {
    let index: ByteSlice
    let features: [FacetFeature]

    struct ByteSlice: Codable {
        let byteStart: Int
        let byteEnd: Int
    }
}

enum FacetFeature: Codable {
    case link(FacetLink)
    case mention(FacetMention)
    case tag(FacetTag)
    case unknown

    struct FacetLink: Codable {
        let uri: String
    }

    struct FacetMention: Codable {
        let did: String
    }

    struct FacetTag: Codable {
        let tag: String
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "app.bsky.richtext.facet#link":
            self = .link(try FacetLink(from: decoder))
        case "app.bsky.richtext.facet#mention":
            self = .mention(try FacetMention(from: decoder))
        case "app.bsky.richtext.facet#tag":
            self = .tag(try FacetTag(from: decoder))
        default:
            self = .unknown
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .link(let v): try v.encode(to: encoder)
        case .mention(let v): try v.encode(to: encoder)
        case .tag(let v): try v.encode(to: encoder)
        case .unknown: break
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
}

// MARK: - Embeds

enum Embed: Codable {
    case images(ImagesEmbed)
    case video(VideoEmbed)
    case external(ExternalEmbed)
    case record(RecordEmbedView)
    case recordWithMedia(RecordWithMediaEmbed)
    case unknown

    var images: [EmbedImage]? {
        if case .images(let e) = self { return e.images }
        if case .recordWithMedia(let e) = self {
            if case .images(let inner) = e.media { return inner.images }
        }
        return nil
    }

    var external: ExternalCard? {
        if case .external(let e) = self { return e.external }
        return nil
    }

    var quotedPost: PostView? {
        if case .record(let e) = self {
            if case .post(let p) = e.record { return p }
        }
        if case .recordWithMedia(let e) = self {
            if case .post(let p) = e.record.record { return p }
        }
        return nil
    }

    var video: VideoCard? {
        if case .video(let e) = self { return VideoCard(
            playlist: e.playlist,
            thumbnail: e.thumbnail,
            alt: e.alt,
            aspectRatio: e.aspectRatio
        )}
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TypeKey.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "app.bsky.embed.images#view":
            self = .images(try ImagesEmbed(from: decoder))
        case "app.bsky.embed.video#view":
            self = .video(try VideoEmbed(from: decoder))
        case "app.bsky.embed.external#view":
            self = .external(try ExternalEmbed(from: decoder))
        case "app.bsky.embed.record#view":
            self = .record(try RecordEmbedView(from: decoder))
        case "app.bsky.embed.recordWithMedia#view":
            self = .recordWithMedia(try RecordWithMediaEmbed(from: decoder))
        default:
            self = .unknown
        }
    }

    func encode(to encoder: Encoder) throws {}

    private enum TypeKey: String, CodingKey {
        case type = "$type"
    }
}

struct ImagesEmbed: Codable {
    let images: [EmbedImage]
}

struct EmbedImage: Codable, Identifiable {
    var id: String { fullsize }
    let alt: String
    let image: BlobView?
    let fullsize: String
    let thumb: String
    let aspectRatio: AspectRatio?

    struct AspectRatio: Codable {
        let width: Int
        let height: Int
    }
}

struct BlobView: Codable {
    let ref: BlobRef?
    let mimeType: String?
    let size: Int?
}

struct BlobRef: Codable {
    let link: String
}

struct VideoEmbed: Codable {
    let playlist: String?
    let thumbnail: String?
    let alt: String?
    let aspectRatio: EmbedImage.AspectRatio?
}

struct VideoCard {
    let playlist: String?
    let thumbnail: String?
    let alt: String?
    let aspectRatio: EmbedImage.AspectRatio?
}

struct ExternalEmbed: Codable {
    let external: ExternalCard
}

struct ExternalCard: Codable {
    let uri: String
    let title: String
    let description: String
    let thumb: String?
}

struct RecordEmbedView: Codable {
    let record: EmbeddedRecord

    enum EmbeddedRecord: Codable {
        case post(PostView)
        case notFound(NotFoundPost)
        case blocked(BlockedPost)

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: TypeKey.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "app.bsky.embed.record#viewRecord":
                self = .post(try PostView(from: decoder))
            case "app.bsky.embed.record#viewNotFound":
                self = .notFound(try NotFoundPost(from: decoder))
            case "app.bsky.embed.record#viewBlocked":
                self = .blocked(try BlockedPost(from: decoder))
            default:
                self = .notFound(NotFoundPost(uri: "", notFound: true))
            }
        }

        func encode(to encoder: Encoder) throws {}

        private enum TypeKey: String, CodingKey { case type = "$type" }
    }
}

struct RecordWithMediaEmbed: Codable {
    let record: RecordEmbedView
    let media: MediaEmbed

    enum MediaEmbed: Codable {
        case images(ImagesEmbed)
        case video(VideoEmbed)
        case external(ExternalEmbed)
        case unknown

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: TypeKey.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "app.bsky.embed.images#view": self = .images(try ImagesEmbed(from: decoder))
            case "app.bsky.embed.video#view": self = .video(try VideoEmbed(from: decoder))
            case "app.bsky.embed.external#view": self = .external(try ExternalEmbed(from: decoder))
            default: self = .unknown
            }
        }

        func encode(to encoder: Encoder) throws {}

        private enum TypeKey: String, CodingKey { case type = "$type" }
    }
}

enum RecordEmbed: Codable {
    case images(RecordImagesEmbed)
    case video(RecordVideoEmbed)
    case external(RecordExternalEmbed)
    case record(RecordRecordEmbed)
    case recordWithMedia(RecordWithMediaRecordEmbed)
    case unknown

    struct RecordImagesEmbed: Codable {
        let images: [RecordImage]
        struct RecordImage: Codable {
            let alt: String
            let image: BlobView?
        }
    }

    struct RecordVideoEmbed: Codable {
        let video: BlobView?
        let captions: [Caption]?
        let alt: String?
        let aspectRatio: EmbedImage.AspectRatio?
        struct Caption: Codable { let lang: String; let file: BlobView? }
    }

    struct RecordExternalEmbed: Codable {
        let external: ExternalCard
    }

    struct RecordRecordEmbed: Codable {
        let record: StrongRef
    }

    struct RecordWithMediaRecordEmbed: Codable {
        let record: RecordRecordEmbed
        let media: RecordImagesEmbed
    }

    init(from decoder: Decoder) throws { self = .unknown }
    func encode(to encoder: Encoder) throws {}
}

// MARK: - Labels

struct Label: Codable {
    let src: String
    let uri: String
    let cid: String?
    let val: String
    let neg: Bool?
    let cts: String
}
