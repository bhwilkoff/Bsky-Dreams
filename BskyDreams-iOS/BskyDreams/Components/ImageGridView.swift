import SwiftUI

struct ImageGridView: View {
    let images: [EmbedImage]
    @State private var lightboxIndex: Int? = nil

    var body: some View {
        Group {
            switch images.count {
            case 1:
                singleImage(images[0], index: 0)
            case 2:
                HStack(spacing: 2) {
                    ForEach(Array(images.enumerated()), id: \.element.id) { i, img in
                        gridImage(img, index: i)
                    }
                }
                .frame(height: 180)
            case 3:
                HStack(spacing: 2) {
                    gridImage(images[0], index: 0)
                    VStack(spacing: 2) {
                        gridImage(images[1], index: 1)
                        gridImage(images[2], index: 2)
                    }
                }
                .frame(height: 180)
            default: // 4+
                LazyVGrid(columns: [.init(), .init()], spacing: 2) {
                    ForEach(Array(images.prefix(4).enumerated()), id: \.element.id) { i, img in
                        gridImage(img, index: i)
                            .frame(height: 120)
                    }
                }
            }
        }
        .clipped()
        .nbBorder()
        .fullScreenCover(item: Binding(
            get: { lightboxIndex.map { LightboxItem(index: $0) } },
            set: { lightboxIndex = $0?.index }
        )) { item in
            LightboxView(images: images, startIndex: item.index)
        }
    }

    private func singleImage(_ img: EmbedImage, index: Int) -> some View {
        AsyncImage(url: URL(string: img.fullsize)) { phase in
            imageContent(phase)
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: 480)
        .clipped()
        .onTapGesture { lightboxIndex = index }
    }

    private func gridImage(_ img: EmbedImage, index: Int) -> some View {
        AsyncImage(url: URL(string: img.thumb)) { phase in
            imageContent(phase)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onTapGesture { lightboxIndex = index }
    }

    private func imageContent(_ phase: AsyncImagePhase) -> some View {
        Group {
            switch phase {
            case .success(let img):
                img.resizable().scaledToFill()
            case .failure:
                Color.nbBorder
                    .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
            case .empty:
                Color.nbBorder.shimmering()
            @unknown default:
                Color.nbBorder
            }
        }
    }

    struct LightboxItem: Identifiable {
        var id: Int { index }
        let index: Int
    }
}

// MARK: - Lightbox

struct LightboxView: View {
    let images: [EmbedImage]
    var startIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int

    init(images: [EmbedImage], startIndex: Int) {
        self.images = images
        self.startIndex = startIndex
        _currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(images.enumerated()), id: \.element.id) { i, img in
                    AsyncImage(url: URL(string: img.fullsize)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                        default:
                            ProgressView().tint(.white)
                        }
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // Close + alt text bar
            HStack {
                if let alt = images[safe: currentIndex]?.alt, !alt.isEmpty {
                    Text(alt)
                        .font(.inter(12))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .font(.inter(15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Link Card

struct LinkCardView: View {
    let card: ExternalCard

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let thumb = card.thumb, let url = URL(string: thumb) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .clipped()
                    default:
                        Color.nbBorder.frame(height: 80)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                if let host = URL(string: card.uri)?.host {
                    Text(host.uppercased())
                        .font(.syne(10))
                        .foregroundStyle(Color.nbAccent)
                        .tracking(1)
                }
                Text(card.title)
                    .font(.inter(14, weight: .semibold))
                    .foregroundStyle(Color.nbBlack)
                    .lineLimit(2)
                if !card.description.isEmpty {
                    Text(card.description)
                        .font(.inter(12))
                        .foregroundStyle(Color.nbBlack.opacity(0.6))
                        .lineLimit(2)
                }
            }
            .padding(10)
        }
        .nbBorder()
        .nbShadow()
        .onTapGesture {
            if let url = URL(string: card.uri) {
                UIApplication.shared.open(url)
            }
        }
    }
}

// MARK: - Quoted Post

struct QuotedPostView: View {
    let post: PostView

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                AvatarView(url: post.author.avatar, size: 20)
                Text(post.author.name)
                    .font(.inter(13, weight: .semibold))
                Text("@\(post.author.handle)")
                    .font(.inter(12))
                    .foregroundStyle(Color.nbBlack.opacity(0.5))
            }
            if !post.record.text.isEmpty {
                Text(post.record.text)
                    .font(.inter(13))
                    .lineLimit(3)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.nbBorder.opacity(0.3))
        .nbBorder()
    }
}

// MARK: - Video Thumbnail

struct VideoThumbnailView: View {
    let video: VideoEmbed

    var body: some View {
        ZStack {
            AsyncImage(url: video.thumbnail.flatMap { URL(string: $0) }) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: Color.nbBlack.opacity(0.8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 300)
            .clipped()

            Image(systemName: "play.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white.shadow(.drop(radius: 4)))
        }
        .nbBorder()
        .contentShape(Rectangle())
    }
}

// MARK: - Shimmer Effect

extension View {
    func shimmering() -> some View {
        self.overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.3), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
    }
}

// MARK: - Safe Array Access

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}
