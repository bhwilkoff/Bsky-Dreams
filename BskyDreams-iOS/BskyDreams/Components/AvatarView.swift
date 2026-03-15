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
            case .failure, .empty:
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .foregroundStyle(Color.nbBlack.opacity(0.4))
                    .background(Color.nbBorder)
            @unknown default:
                Color.nbBorder
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: 0))
        .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 1.5))
    }
}
