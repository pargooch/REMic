import SwiftUI

// MARK: - Halftone Dot Pattern

struct HalftoneBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    var dotSpacing: CGFloat = 12
    var opacity: Double = 0.07

    var body: some View {
        Canvas { context, size in
            let dotColor: Color = colorScheme == .dark ? .white : .black
            let dotSize: CGFloat = 3.0

            for x in stride(from: CGFloat(0), to: size.width, by: dotSpacing) {
                for y in stride(from: CGFloat(0), to: size.height, by: dotSpacing) {
                    let offset: CGFloat = Int(y / dotSpacing) % 2 == 0 ? dotSpacing / 2 : 0
                    let center = CGPoint(x: x + offset, y: y)
                    let rect = CGRect(
                        x: center.x - dotSize / 2,
                        y: center.y - dotSize / 2,
                        width: dotSize, height: dotSize
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(dotColor.opacity(opacity))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Paper Grain Texture

struct PaperGrainTexture: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            let grainColor: Color = colorScheme == .dark ? .white : .black
            let step: CGFloat = 3
            for x in stride(from: CGFloat(0), to: size.width, by: step) {
                for y in stride(from: CGFloat(0), to: size.height, by: step) {
                    let hash = (Int(x * 7 + y * 13) % 100)
                    if hash < 15 {
                        let dotSize = CGFloat(hash % 3 + 1) * 0.4
                        let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(grainColor.opacity(0.025))
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Composite Comic Background

struct ComicBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ComicTheme.Semantic.background(colorScheme)
                .ignoresSafeArea()

            PaperGrainTexture()
                .ignoresSafeArea()

            HalftoneBackground(dotSpacing: 12, opacity: 0.07)
                .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }
}

extension View {
    func halftoneBackground() -> some View {
        self.background(ComicBackground())
    }
}
