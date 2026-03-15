import SwiftUI

// Renders AT Protocol rich text with byte-accurate facet slicing

struct RichTextView: View {
    let text: String
    let facets: [RichTextFacet]?
    var font: Font = .inter(15)

    var body: some View {
        if let facets, !facets.isEmpty {
            Text(buildAttributedString())
                .font(font)
                .environment(\.openURL, OpenURLAction { url in
                    // Custom URL handling for mentions/hashtags
                    return .systemAction
                })
        } else {
            Text(text)
                .font(font)
                .foregroundStyle(Color.nbBlack)
        }
    }

    private func buildAttributedString() -> AttributedString {
        guard let facets else { return AttributedString(text) }

        let utf8 = Array(text.utf8)
        var result = AttributedString()

        // Sort facets by byte start
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

            // Facet text
            let facetSlice = utf8[start..<end]
            if let facetText = String(bytes: facetSlice, encoding: .utf8) {
                var attrStr = AttributedString(facetText)
                let feature = facet.features.first

                switch feature {
                case .link(let link):
                    if let url = URL(string: link.uri) {
                        attrStr[\.link] = url
                    }
                    attrStr[\.foregroundColor] = UIColor(Color.nbBlue)
                case .mention(let mention):
                    if let url = URL(string: "bskydreams://profile?did=\(mention.did)") {
                        attrStr[\.link] = url
                    }
                    attrStr[\.foregroundColor] = UIColor(Color.nbBlue)
                case .tag(let tag):
                    if let url = URL(string: "bskydreams://search?q=%23\(tag.tag)") {
                        attrStr[\.link] = url
                    }
                    attrStr[\.foregroundColor] = UIColor(Color.nbBlue)
                case .unknown, nil:
                    break
                }

                result += attrStr
            }

            pos = end
        }

        // Remaining text after last facet
        if pos < utf8.count {
            let tail = utf8[pos...]
            if let s = String(bytes: tail, encoding: .utf8) {
                result += AttributedString(s)
            }
        }

        // Base styling
        result[\.foregroundColor] = UIColor(Color.nbBlack)
        return result
    }
}
