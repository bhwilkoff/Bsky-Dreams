import SwiftUI

struct AvatarView: View {
    let url: String?
    var size: CGFloat = 40

    var body: some View {
        AsyncImage(url: url.flatMap { URL(string: $0) }) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                // Use app icon as fallback — matches the cloud logo brand
                appIconFallback
            case .empty:
                // Show placeholder while loading
                Color.nbBorder.opacity(0.3)
                    .overlay(ProgressView().scaleEffect(0.5))
            @unknown default:
                appIconFallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .overlay(Circle().strokeBorder(Color.nbBlack, lineWidth: 1.5))
    }

    private var appIconFallback: some View {
        Group {
            if let icon = UIImage(named: "AppIcon") {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "cloud.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.2)
                    .foregroundStyle(Color.nbAccent)
                    .background(Color.nbBorder.opacity(0.2))
            }
        }
    }
}
