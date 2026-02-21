import SwiftUI

// MARK: - Art Deco Diamond Crosshatch Pattern

struct ArtDecoBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    var lineSpacing: CGFloat = 24
    var opacity: Double = 0.035

    var body: some View {
        Canvas { context, size in
            let lineColor: Color = colorScheme == .dark ? .white : Color(white: 0.3)
            let style = StrokeStyle(lineWidth: 0.5)
            let resolvedColor = lineColor.opacity(opacity)

            // Diagonal lines going top-left to bottom-right
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var linePath = Path()
                linePath.move(to: CGPoint(x: x, y: 0))
                linePath.addLine(to: CGPoint(x: x + size.height, y: size.height))
                context.stroke(linePath, with: .color(resolvedColor), style: style)
                x += lineSpacing
            }

            // Diagonal lines going top-right to bottom-left
            x = 0
            while x < size.width + size.height {
                var linePath = Path()
                linePath.move(to: CGPoint(x: x, y: 0))
                linePath.addLine(to: CGPoint(x: x - size.height, y: size.height))
                context.stroke(linePath, with: .color(resolvedColor), style: style)
                x += lineSpacing
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Legacy Halftone (kept for potential reuse)

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

// MARK: - Composite Background

struct ComicBackground: View {
    var baseColor: Color?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        (colorScheme == .dark
            ? ComicTheme.Semantic.background(colorScheme)
            : (baseColor ?? ComicTheme.Palette.appBackground))
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

extension View {
    func halftoneBackground() -> some View {
        self.background(ComicBackground())
    }

    func halftoneBackground(_ color: Color) -> some View {
        self.background(ComicBackground(baseColor: color))
    }
}
