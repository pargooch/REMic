import SwiftUI

// MARK: - Speech Bubble Shape

struct SpeechBubbleShape: Shape {
    var tailPosition: CGFloat = 0.2
    var tailWidth: CGFloat = 20
    var tailHeight: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius: CGFloat = ComicTheme.Dimensions.panelCornerRadius
        let bodyRect = CGRect(
            x: rect.minX, y: rect.minY,
            width: rect.width, height: rect.height - tailHeight
        )

        path.addRoundedRect(
            in: bodyRect,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )

        let tailX = bodyRect.minX + bodyRect.width * tailPosition
        path.move(to: CGPoint(x: tailX, y: bodyRect.maxY))
        path.addLine(to: CGPoint(x: tailX + tailWidth / 2, y: rect.maxY))
        path.addLine(to: CGPoint(x: tailX + tailWidth, y: bodyRect.maxY))

        return path
    }
}

// MARK: - Speech Bubble View Modifier

struct SpeechBubbleModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 14)
            .background(
                SpeechBubbleShape()
                    .fill(ComicTheme.Semantic.cardSurface(colorScheme))
            )
            .overlay(
                SpeechBubbleShape()
                    .stroke(
                        ComicTheme.Semantic.panelBorder(colorScheme),
                        lineWidth: ComicTheme.Dimensions.speechBubbleBorderWidth
                    )
            )
    }
}

extension View {
    func speechBubble() -> some View {
        modifier(SpeechBubbleModifier())
    }
}
