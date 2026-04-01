import Foundation

// MARK: - Core Post Models

struct PostView: Identifiable, Hashable {
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
    let labels: [BskyLabel]?

    // For reply context in feed
    let reply: FeedReplyContext?

    var rkey: String { uri.components(separatedBy: "/").last ?? "" }

    var relativeTime: String {
        let date: Date?
        // AT Protocol timestamps often include fractional seconds — try both parsers
        let withFractions = ISO8601DateFormatter()
        withFractions.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        date = withFractions.date(from: indexedAt) ?? ISO8601DateFormatter().date(from: indexedAt)
        guard let date else { return "now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func == (lhs: PostView, rhs: PostView) -> Bool { lhs.uri == rhs.uri }
    func hash(into hasher: inout Hasher) { hasher.combine(uri) }

    /// True if the post carries any adult/NSFW content label.
    private static let adultLabelValues: Set<String> = ["porn", "sexual", "nudity", "graphic-media", "adult", "gore", "nsfw"]
    var isAdultContent: Bool {
        guard let labels else { return false }
        return labels.contains { Self.adultLabelValues.contains($0.val) }
    }

    /// True if the post is in English (or has no language tag, which is common for older posts).
    var isEnglish: Bool {
        guard let langs = record.langs, !langs.isEmpty else { return true }
        return langs.contains { $0.hasPrefix("en") }
    }
}

// MARK: - PostView Codable
// Custom implementation supports both the standard feed format AND the
// app.bsky.embed.record#viewRecord format, which uses "value" instead of
// "record" and "embeds" (array) instead of "embed" (single).

extension PostView: Codable {
    private enum CodingKeys: String, CodingKey {
        case uri, cid, author, likeCount, replyCount, repostCount, indexedAt, viewer, labels, reply
        case record          // standard feed format
        case value           // #viewRecord format — same content, different key
        case embed           // standard: single embed
        case embeds          // #viewRecord: array of embeds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uri        = try c.decode(String.self, forKey: .uri)
        cid        = try c.decode(String.self, forKey: .cid)
        author     = try c.decode(ActorProfile.self, forKey: .author)
        indexedAt  = try c.decode(String.self, forKey: .indexedAt)

        // "record" in feed response; "value" in #viewRecord
        if let r = try? c.decodeIfPresent(PostRecord.self, forKey: .record) {
            record = r
        } else if let v = try? c.decodeIfPresent(PostRecord.self, forKey: .value) {
            record = v
        } else {
            record = PostRecord(text: "", createdAt: indexedAt, langs: nil, facets: nil, reply: nil, embed: nil, tags: nil)
        }

        // "embed" in feed response (single); "embeds" in #viewRecord (array — take first)
        if let e = try? c.decodeIfPresent(Embed.self, forKey: .embed) {
            embed = e
        } else if let arr = try? c.decodeIfPresent([Embed].self, forKey: .embeds) {
            embed = arr.first
        } else {
            embed = nil
        }

        likeCount   = try? c.decodeIfPresent(Int.self, forKey: .likeCount)
        replyCount  = try? c.decodeIfPresent(Int.self, forKey: .replyCount)
        repostCount = try? c.decodeIfPresent(Int.self, forKey: .repostCount)
        viewer      = try? c.decodeIfPresent(PostViewer.self, forKey: .viewer)
        labels      = try? c.decodeIfPresent([BskyLabel].self, forKey: .labels)
        reply       = try? c.decodeIfPresent(FeedReplyContext.self, forKey: .reply)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(uri, forKey: .uri)
        try c.encode(cid, forKey: .cid)
        try c.encode(author, forKey: .author)
        try c.encode(record, forKey: .record)
        try c.encodeIfPresent(embed, forKey: .embed)
        try c.encodeIfPresent(likeCount, forKey: .likeCount)
        try c.encodeIfPresent(replyCount, forKey: .replyCount)
        try c.encodeIfPresent(repostCount, forKey: .repostCount)
        try c.encode(indexedAt, forKey: .indexedAt)
        try c.encodeIfPresent(viewer, forKey: .viewer)
        try c.encodeIfPresent(labels, forKey: .labels)
        try c.encodeIfPresent(reply, forKey: .reply)
    }
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

    indirect enum FeedContextPost: Codable {
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
            } else if let blocked = try? container.decode(BlockedPost.self) {
                self = .blocked(blocked)
            } else {
                self = .notFound(NotFoundPost(uri: "", notFound: true))
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
        guard let container = try? decoder.container(keyedBy: TypeKey.self),
              let type = try? container.decode(String.self, forKey: .type) else {
            self = .unknown
            return
        }
        switch type {
        case "app.bsky.embed.images#view":
            self = (try? .images(ImagesEmbed(from: decoder))) ?? .unknown
        case "app.bsky.embed.video#view":
            self = (try? .video(VideoEmbed(from: decoder))) ?? .unknown
        case "app.bsky.embed.external#view":
            self = (try? .external(ExternalEmbed(from: decoder))) ?? .unknown
        case "app.bsky.embed.record#view":
            self = (try? .record(RecordEmbedView(from: decoder))) ?? .unknown
        case "app.bsky.embed.recordWithMedia#view":
            self = (try? .recordWithMedia(RecordWithMediaEmbed(from: decoder))) ?? .unknown
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
    enum CodingKeys: String, CodingKey { case link = "$link" }
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
    /// Uploaded blob for the thumbnail — set after uploading the OG image at post time.
    /// Not Codable (transient), only used locally before the record is created.
    var uploadedThumb: UploadedBlob? = nil

    enum CodingKeys: String, CodingKey {
        case uri, title, description, thumb
    }
}

struct RecordEmbedView: Codable {
    let record: EmbeddedRecord

    indirect enum EmbeddedRecord: Codable {
        case post(PostView)
        case notFound(NotFoundPost)
        case blocked(BlockedPost)

        init(from decoder: Decoder) throws {
            guard let container = try? decoder.container(keyedBy: TypeKey.self),
                  let type = try? container.decode(String.self, forKey: .type) else {
                self = .notFound(NotFoundPost(uri: "", notFound: true))
                return
            }
            switch type {
            case "app.bsky.embed.record#viewRecord":
                // viewRecord uses 'value' not 'record' — PostView decode may fail; fall back gracefully
                self = (try? .post(PostView(from: decoder))) ?? .notFound(NotFoundPost(uri: "", notFound: true))
            case "app.bsky.embed.record#viewNotFound":
                self = (try? .notFound(NotFoundPost(from: decoder))) ?? .notFound(NotFoundPost(uri: "", notFound: true))
            case "app.bsky.embed.record#viewBlocked":
                self = (try? .blocked(BlockedPost(from: decoder))) ?? .notFound(NotFoundPost(uri: "", notFound: true))
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
            guard let container = try? decoder.container(keyedBy: TypeKey.self),
                  let type = try? container.decode(String.self, forKey: .type) else {
                self = .unknown
                return
            }
            switch type {
            case "app.bsky.embed.images#view": self = (try? .images(ImagesEmbed(from: decoder))) ?? .unknown
            case "app.bsky.embed.video#view": self = (try? .video(VideoEmbed(from: decoder))) ?? .unknown
            case "app.bsky.embed.external#view": self = (try? .external(ExternalEmbed(from: decoder))) ?? .unknown
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

struct BskyLabel: Codable {
    let src: String
    let uri: String
    let cid: String?
    let val: String
    let neg: Bool?
    let cts: String
}
