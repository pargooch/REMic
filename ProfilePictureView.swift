import SwiftUI

/// Circular avatar display with comic panel border styling
struct ProfilePictureView: View {
    var size: CGFloat = 60
    var editable: Bool = false
    var onTap: (() -> Void)?

    @StateObject private var authManager = AuthManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if let imageData = authManager.avatarImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(ComicTheme.Colors.boldBlue.opacity(0.3))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(
                    ComicTheme.panelBorderColor(colorScheme),
                    lineWidth: ComicTheme.Dimensions.panelBorderWidth
                )
        )
        .overlay(alignment: .bottomTrailing) {
            if editable {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: size * 0.3))
                    .foregroundColor(ComicTheme.Colors.boldBlue)
                    .background(Circle().fill(ComicTheme.Semantic.cardSurface(colorScheme)).padding(2))
            }
        }
        .onTapGesture {
            if editable {
                onTap?()
            }
        }
    }
}
