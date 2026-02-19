import SwiftUI

struct ComicPanelCard<Content: View>: View {
    let titleBanner: String?
    let bannerColor: Color
    let content: Content
    @Environment(\.colorScheme) private var colorScheme

    init(
        titleBanner: String? = nil,
        bannerColor: Color = ComicTheme.Semantic.primaryAction,
        @ViewBuilder content: () -> Content
    ) {
        self.titleBanner = titleBanner
        self.bannerColor = bannerColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title = titleBanner {
                Text(title.uppercased())
                    .font(ComicTheme.Typography.sectionHeader())
                    .tracking(1.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(bannerColor == ComicTheme.Palette.goldenYellow ? ComicTheme.Palette.inkBlack : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(bannerColor)
            }

            content
                .padding()
        }
        .background(
            ZStack {
                ComicTheme.Semantic.cardSurface(colorScheme)
                HalftoneBackground(dotSpacing: 18, opacity: 0.03)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: ComicTheme.Dimensions.panelCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: ComicTheme.Dimensions.panelCornerRadius)
                .stroke(
                    ComicTheme.Semantic.panelBorder(colorScheme),
                    lineWidth: ComicTheme.Dimensions.panelBorderWidth
                )
        )
    }
}
