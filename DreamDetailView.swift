import SwiftUI

struct DreamDetailView: View {
    @EnvironmentObject var store: DreamStore
    let dream: Dream

    @State private var selectedTone = "happy"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var aiService = AIService()

    // Editing states
    @State private var isEditing = false
    @State private var editedText = ""
    @State private var isEditingOriginal = false
    @State private var editedOriginalText = ""

    let tones = ["happy", "funny", "hopeful", "calm", "positive"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Original dream
                ComicPanelCard(titleBanner: "Original Dream", bannerColor: ComicTheme.Colors.deepPurple) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Spacer()
                            Button {
                                if isEditingOriginal {
                                    saveOriginalText()
                                } else {
                                    editedOriginalText = dream.originalText
                                    isEditingOriginal = true
                                }
                            } label: {
                                Label(isEditingOriginal ? "Save" : "Edit", systemImage: isEditingOriginal ? "checkmark" : "pencil")
                            }
                            .buttonStyle(.comicSecondary)
                            .frame(maxWidth: 120)

                            if isEditingOriginal {
                                Button {
                                    isEditingOriginal = false
                                    editedOriginalText = ""
                                } label: {
                                    Label("Cancel", systemImage: "xmark")
                                }
                                .buttonStyle(.comicDestructive)
                                .frame(maxWidth: 120)
                            }
                        }

                        if isEditingOriginal {
                            ZStack(alignment: .topLeading) {
                                Text(editedOriginalText.isEmpty ? " " : editedOriginalText)
                                    .font(.body)
                                    .padding(12)
                                    .opacity(0)

                                TextEditor(text: $editedOriginalText)
                                    .font(.body)
                                    .scrollContentBackground(.hidden)
                                    .scrollDisabled(true)
                                    .padding(6)
                            }
                            .frame(minHeight: 100)
                            .background(Color(.systemBackground).opacity(0.5))
                            .cornerRadius(8)
                        } else {
                            Text(dream.originalText)
                                .font(.body)
                        }
                    }
                }

                // Show rewritten dream if available
                if let rewritten = dream.rewrittenText {
                    ComicPanelCard(titleBanner: "Rewritten Dream (\(dream.tone?.capitalized ?? ""))", bannerColor: ComicTheme.Colors.boldBlue) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Spacer()
                                Button {
                                    if isEditing {
                                        saveEditedText()
                                    } else {
                                        editedText = rewritten
                                        isEditing = true
                                    }
                                } label: {
                                    Label(isEditing ? "Save" : "Edit", systemImage: isEditing ? "checkmark" : "pencil")
                                }
                                .buttonStyle(.comicSecondary)
                                .frame(maxWidth: 120)

                                if isEditing {
                                    Button {
                                        isEditing = false
                                        editedText = ""
                                    } label: {
                                        Label("Cancel", systemImage: "xmark")
                                    }
                                    .buttonStyle(.comicDestructive)
                                    .frame(maxWidth: 120)
                                }
                            }

                            if isEditing {
                                ZStack(alignment: .topLeading) {
                                    Text(editedText.isEmpty ? " " : editedText)
                                        .font(.body)
                                        .padding(12)
                                        .opacity(0)

                                    TextEditor(text: $editedText)
                                        .font(.body)
                                        .scrollContentBackground(.hidden)
                                        .scrollDisabled(true)
                                        .padding(6)
                                }
                                .frame(minHeight: 100)
                                .background(Color(.systemBackground).opacity(0.5))
                                .cornerRadius(8)
                            } else {
                                Text(rewritten)
                                    .font(ComicTheme.Typography.speechBubble())
                                    .speechBubble()
                            }
                        }
                    }
                }

                // Tone picker
                ComicPanelCard(titleBanner: dream.rewrittenText != nil ? "Try a Different Tone?" : "How Should This Dream Feel?", bannerColor: ComicTheme.Colors.crimsonRed) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Comic-styled tone chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(tones, id: \.self) { tone in
                                    Button {
                                        selectedTone = tone
                                    } label: {
                                        Text(tone.capitalized)
                                            .font(.system(size: 13, weight: .bold))
                                            .tracking(0.5)
                                    }
                                    .buttonStyle(ToneChipStyle(isSelected: selectedTone == tone))
                                    .disabled(isEditing)
                                }
                            }
                        }

                        if isLoading {
                            VStack(spacing: 12) {
                                SoundEffectText(text: "REWRITING!", fillColor: ComicTheme.Colors.boldBlue, fontSize: 20)

                                ProgressView()
                                    .tint(ComicTheme.Colors.boldBlue)

                                Button {
                                    cancelRewrite()
                                } label: {
                                    Label("Cancel", systemImage: "xmark")
                                }
                                .buttonStyle(.comicDestructive)
                            }
                        } else {
                            Button {
                                rewriteDream()
                            } label: {
                                Label(
                                    dream.rewrittenText != nil ? "Rewrite Again" : "Rewrite with AI",
                                    systemImage: dream.rewrittenText != nil ? "arrow.clockwise" : "sparkles"
                                )
                            }
                            .buttonStyle(.comicPrimary(color: ComicTheme.Colors.boldBlue))
                            .disabled(isEditing)
                        }

                        // Error message
                        if let errorMessage = errorMessage {
                            VStack(spacing: 12) {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(ComicTheme.Colors.crimsonRed)
                                    .speechBubble()

                                Button {
                                    rewriteDream()
                                } label: {
                                    Label("Try Again", systemImage: "arrow.clockwise")
                                }
                                .buttonStyle(.comicSecondary)
                            }
                        }
                    }
                }

                // Image generation section (only show if rewritten)
                if dream.rewrittenText != nil {
                    DreamImageSection(dream: dream, store: store)
                }

                // Per-dream notification management
                DreamNotificationSection(dreamId: dream.id, hasRewrite: dream.rewrittenText != nil)
            }
            .padding()
        }
        .halftoneBackground()
        .navigationTitle("Dream")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let currentTone = dream.tone {
                selectedTone = currentTone
            }
        }
        .onDisappear {
            aiService.cancel()
        }
    }

    // MARK: - AI Rewrite
    func rewriteDream() {
        isLoading = true
        errorMessage = nil

        aiService.rewriteDream(
            original: dream.originalText,
            tone: selectedTone
        ) { result in
            DispatchQueue.main.async {
                isLoading = false

                switch result {
                case .success(let rewritten):
                    var updated = dream
                    updated.rewrittenText = rewritten
                    updated.tone = selectedTone
                    store.updateDream(updated)

                case .failure(let error):
                    if case .cancelled = error {
                        return
                    }

                    print("Rewrite failed: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    func cancelRewrite() {
        aiService.cancel()
        isLoading = false
    }

    func saveEditedText() {
        var updated = dream
        updated.rewrittenText = editedText
        store.updateDream(updated)
        isEditing = false
        editedText = ""
    }

    func saveOriginalText() {
        guard !editedOriginalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var updated = dream
        updated.originalText = editedOriginalText
        store.updateDream(updated)
        isEditingOriginal = false
        editedOriginalText = ""
    }
}

// MARK: - Tone Chip Style

struct ToneChipStyle: ButtonStyle {
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? ComicTheme.Colors.crimsonRed : Color.clear)
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isSelected ? ComicTheme.Colors.crimsonRed : ComicTheme.panelBorderColor(colorScheme).opacity(0.4),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}
