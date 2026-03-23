import SwiftUI

// Renders AT Protocol rich text with byte-accurate facet slicing

struct RichTextView: View {
    let text: String
    let facets: [RichTextFacet]?
    var font: Font = .system(size: 15)

    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    /// Link/mention/hashtag color — a lighter teal-blue in dark mode so it remains
    /// readable against the deep-navy card surface (#142033) without clashing.
    private var linkColor: Color {
        colorScheme == .dark
            ? Color(hex: "#5DB8D0")   // muted teal-sky — visible on #142033, not garish
            : Color.nbBlue            // #0047FF — standard blue on white
    }

    var body: some View {
        // line-height 1.55 on 15pt ≈ 23.25pt total; SwiftUI lineSpacing adds gap *between* lines.
        // Default iOS line height ≈ 18pt → additional spacing ≈ 5pt.
        if let facets, !facets.isEmpty {
            Text(buildAttributedString())
                .font(font)
                .lineSpacing(5)
                .foregroundStyle(Color.nbBlack)
                .environment(\.openURL, OpenURLAction { url in
                    handleInternalURL(url)
                })
        } else {
            Text(text)
                .font(font)
                .lineSpacing(5)
                .foregroundStyle(Color.nbBlack)
        }
    }

    @MainActor
    private func handleInternalURL(_ url: URL) -> OpenURLAction.Result {
        guard url.scheme == "bskydreams" else { return .systemAction }
        switch url.host {
        case "profile":
            if let did = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "did" })?.value {
                store.navigationPath.append(ProfileDestination(actor: did))
                return .handled
            }
        case "search":
            if let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "q" })?.value {
                // Strip leading # for hashtag navigation
                let tag = q.hasPrefix("#") ? String(q.dropFirst()) : q
                store.navigationPath.append(HashtagDestination(tag: tag))
                return .handled
            }
        default:
            break
        }
        return .systemAction
    }

    private func buildAttributedString() -> AttributedString {
        guard let facets else { return AttributedString(text) }

        let utf8 = Array(text.utf8)
        var result = AttributedString()
        let sorted = facets.sorted { $0.index.byteStart < $1.index.byteStart }
        var pos = 0

        for facet in sorted {
            let start = facet.index.byteStart
            let end = min(facet.index.byteEnd, utf8.count)

            // Plain text before this facet
            if pos < start {
                let slice = utf8[pos..<start]
                if let s = String(bytes: slice, encoding: .utf8) {
                    result += AttributedString(s)
                }
            }

            // Facet text with attributes
            let facetSlice = utf8[start..<end]
            if let facetText = String(bytes: facetSlice, encoding: .utf8) {
                var attrStr = AttributedString(facetText)

                switch facet.features.first {
                case .link(let link):
                    attrStr.link = URL(string: link.uri)
                    attrStr.foregroundColor = linkColor
                case .mention(let mention):
                    attrStr.link = URL(string: "bskydreams://profile?did=\(mention.did)")
                    attrStr.foregroundColor = linkColor
                case .tag(let tag):
                    attrStr.link = URL(string: "bskydreams://search?q=%23\(tag.tag)")
                    attrStr.foregroundColor = linkColor
                case .unknown, nil:
                    break
                }

                result += attrStr
            }

            pos = end
        }

        // Remaining plain text after last facet
        if pos < utf8.count {
            let tail = utf8[pos...]
            if let s = String(bytes: tail, encoding: .utf8) {
                result += AttributedString(s)
            }
        }

        return result
    }
}
