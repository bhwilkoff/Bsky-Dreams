import SwiftUI

struct GalleryView: View {
    @State private var images: [(PostView, EmbedImage)] = []
    @State private var cursor: String?
    @State private var isLoading = false
    @State private var lightboxItem: LightboxData? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && images.isEmpty {
                    ProgressView("Loading gallery...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    galleryGrid
                }
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { if images.isEmpty { await load() } }
        .sheet(item: $lightboxItem) { item in
            LightboxView(images: [item.image], startIndex: 0)
        }
    }

    private var galleryGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(images.enumerated()), id: \.offset) { i, pair in
                    let (_, img) = pair
                    AsyncImage(url: URL(string: img.thumb)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Color.nbBorder
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
                    .onTapGesture { lightboxItem = LightboxData(image: img) }
                    .onAppear {
                        if i == images.count - 6 {
                            Task { await load(loadMore: true) }
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .refreshable {
            images = []
            cursor = nil
            await load()
        }
    }

    private func load(loadMore: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let resp = try await ATProtocolClient.shared.getTimeline(
                limit: 50,
                cursor: loadMore ? cursor : nil
            )
            let newPairs = resp.feed.flatMap { item -> [(PostView, EmbedImage)] in
                guard let imgs = item.post.embed?.images else { return [] }
                return imgs.map { (item.post, $0) }
            }

            if loadMore {
                images.append(contentsOf: newPairs)
            } else {
                images = newPairs
            }
            cursor = resp.cursor
        } catch {}
    }

    struct LightboxData: Identifiable {
        var id: String { image.id }
        let image: EmbedImage
    }
}
