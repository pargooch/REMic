import SwiftUI

// MARK: - Art Deco Corner Ornament

struct ArtDecoCornerOrnament: Shape {
    enum Corner { case topLeading, topTrailing, bottomLeading, bottomTrailing }
    let corner: Corner
    let armLength: CGFloat
    let thickness: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let d = thickness * 2.5

        switch corner {
        case .topLeading:
            path.addRect(CGRect(x: 0, y: 0, width: thickness, height: armLength))
            path.addRect(CGRect(x: 0, y: 0, width: armLength, height: thickness))
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: d, y: 0))
            path.addLine(to: CGPoint(x: 0, y: d))
            path.closeSubpath()

        case .topTrailing:
            let w = rect.width
            path.addRect(CGRect(x: w - thickness, y: 0, width: thickness, height: armLength))
            path.addRect(CGRect(x: w - armLength, y: 0, width: armLength, height: thickness))
            path.move(to: CGPoint(x: w, y: 0))
            path.addLine(to: CGPoint(x: w - d, y: 0))
            path.addLine(to: CGPoint(x: w, y: d))
            path.closeSubpath()

        case .bottomLeading:
            let h = rect.height
            path.addRect(CGRect(x: 0, y: h - armLength, width: thickness, height: armLength))
            path.addRect(CGRect(x: 0, y: h - thickness, width: armLength, height: thickness))
            path.move(to: CGPoint(x: 0, y: h))
            path.addLine(to: CGPoint(x: d, y: h))
            path.addLine(to: CGPoint(x: 0, y: h - d))
            path.closeSubpath()

        case .bottomTrailing:
            let w = rect.width
            let h = rect.height
            path.addRect(CGRect(x: w - thickness, y: h - armLength, width: thickness, height: armLength))
            path.addRect(CGRect(x: w - armLength, y: h - thickness, width: armLength, height: thickness))
            path.move(to: CGPoint(x: w, y: h))
            path.addLine(to: CGPoint(x: w - d, y: h))
            path.addLine(to: CGPoint(x: w, y: h - d))
            path.closeSubpath()
        }
        return path
    }
}

// MARK: - Art Deco Panel Card

struct ComicPanelCard<Content: View>: View {
    let titleBanner: String?
    let bannerColor: Color
    let cardBackground: Color?
    let content: Content
    @Environment(\.colorScheme) private var colorScheme

    init(
        titleBanner: String? = nil,
        bannerColor: Color = ComicTheme.Semantic.primaryAction,
        cardBackground: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.titleBanner = titleBanner
        self.bannerColor = bannerColor
        self.cardBackground = cardBackground
        self.content = content()
    }

    private var bannerTextColor: Color {
        return bannerColor
    }

    private var resolvedBackground: Color {
        cardBackground ?? ComicTheme.Semantic.cardSurface(colorScheme)
    }

    var body: some View {
        let outerRadius = ComicTheme.Dimensions.panelCornerRadius

        VStack(alignment: .leading, spacing: 0) {
            if let title = titleBanner {
                artDecoBanner(title: title)
            }

            content
                .padding()
        }
        .background(resolvedBackground)
        .clipShape(RoundedRectangle(cornerRadius: outerRadius))
        // Outer border — thin black
        .overlay(
            RoundedRectangle(cornerRadius: outerRadius)
                .stroke(
                    ComicTheme.Semantic.panelBorder(colorScheme),
                    lineWidth: ComicTheme.Dimensions.panelBorderWidth
                )
        )
    }

    // MARK: - Art Deco Banner

    @ViewBuilder
    private func artDecoBanner(title: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Left decorative line
                Rectangle()
                    .fill(bannerTextColor.opacity(0.4))
                    .frame(minWidth: 8, maxWidth: 40, minHeight: 1, maxHeight: 1)

                Text(title.uppercased())
                    .font(ComicTheme.Typography.sectionHeader())
                    .tracking(2.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(bannerTextColor)
                    .layoutPriority(1)

                // Right decorative line
                Rectangle()
                    .fill(bannerTextColor.opacity(0.4))
                    .frame(minWidth: 8, maxWidth: 40, minHeight: 1, maxHeight: 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Bottom separator
            Rectangle()
                .fill(bannerTextColor.opacity(0.2))
                .frame(height: 0.5)
                .padding(.horizontal, 12)
        }
    }
}
