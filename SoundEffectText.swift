import SwiftUI

struct SoundEffectText: View {
    let text: String
    var rotation: Double = -5
    var fillColor: Color = ComicTheme.Palette.goldenYellow
    var strokeColor: Color = ComicTheme.Palette.inkBlack
    var fontSize: CGFloat = 36

    @State private var isAnimated = false

    var body: some View {
        Text(text)
            .font(ComicTheme.Typography.soundEffect(fontSize))
            .foregroundStyle(fillColor)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(isAnimated ? 1.0 : 0.3)
            .opacity(isAnimated ? 1.0 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    isAnimated = true
                }
            }
    }
}
