import SwiftUI

struct MoodSuggestionView: View {
    let suggestedMood: SuggestedMood
    let onSelect: (String) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            onSelect(suggestedMood.mood)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .font(.body.weight(.bold))
                    .foregroundColor(ComicTheme.Colors.goldenYellow)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 0) {
                        Text("We suggest rewriting this as a ")
                            .font(ComicTheme.Typography.speechBubble(13))
                        Text(suggestedMood.mood.capitalized)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(ComicTheme.Colors.boldBlue)
                        Text(" dream")
                            .font(ComicTheme.Typography.speechBubble(13))
                    }
                    .foregroundColor(.primary)

                    Text(suggestedMood.suggestion_reason)
                        .font(ComicTheme.Typography.speechBubble(11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(ComicTheme.Semantic.cardSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ComicTheme.Dimensions.buttonCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: ComicTheme.Dimensions.buttonCornerRadius)
                    .stroke(ComicTheme.Colors.goldenYellow.opacity(0.3), lineWidth: 2.0)
            )
        }
        .buttonStyle(.plain)
    }
}
