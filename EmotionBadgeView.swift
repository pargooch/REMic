import SwiftUI

struct EmotionBadgeView: View {
    let emotion: EmotionResult
    @Environment(\.colorScheme) private var colorScheme

    static let emotionColors: [String: Color] = [
        "fear": Color(red: 0xFD/255, green: 0x5A/255, blue: 0x46/255),
        "sadness": Color(red: 0.2, green: 0.4, blue: 0.9),
        "anger": .orange,
        "anxiety": Color(red: 0.95, green: 0.85, blue: 0.1),
        "stress": ComicTheme.Colors.deepPurple,
        "loneliness": .gray,
        "helplessness": Color(red: 0.1, green: 0.2, blue: 0.6),
        "shame": .brown,
        "grief": Color(red: 0.05, green: 0.1, blue: 0.4),
        "confusion": .teal,
    ]

    private var badgeColor: Color {
        Self.emotionColors[emotion.emotion.lowercased()] ?? ComicTheme.Colors.boldBlue
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(L(emotion.emotion.capitalized))
                .font(.system(size: 12, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(String(format: "%.0f%%", emotion.intensity * 100))
                .font(.system(size: 10, weight: .heavy))
                .opacity(0.7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .fixedSize()
        .background(badgeColor.opacity(0.15 + emotion.intensity * 0.2))
        .foregroundColor(badgeColor)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(badgeColor.opacity(0.4), lineWidth: 1.5)
        )
    }
}
