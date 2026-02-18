import SwiftUI

struct NewDreamView: View {
    @EnvironmentObject var store: DreamStore
    @Environment(\.dismiss) var dismiss
    @Environment(DreamAnalysisService.self) private var analysisService

    @State private var dreamText = ""
    @State private var dreamDate = Date()
    @State private var speechService = SpeechRecognitionService()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("What did you dream?")
                        .font(ComicTheme.Typography.speechBubble())
                        .speechBubble()
                        .padding(.top)

                    ComicPanelCard(bannerColor: ComicTheme.Colors.deepPurple) {
                        ZStack(alignment: .topLeading) {
                            if dreamText.isEmpty && !speechService.isRecording {
                                Text("Describe your dream or nightmare...")
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }

                            TextEditor(text: $dreamText)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 200)
                        }
                    }

                    // Voice recording button
                    Button {
                        if speechService.isRecording {
                            speechService.stopRecording()
                        } else {
                            Task {
                                speechService.transcribedText = ""
                                await speechService.startRecording()
                            }
                        }
                    } label: {
                        Label(
                            speechService.isRecording ? "Stop Recording" : "Record Dream",
                            systemImage: speechService.isRecording ? "stop.circle.fill" : "mic.circle.fill"
                        )
                    }
                    .buttonStyle(.comicPrimary(color: speechService.isRecording ? ComicTheme.Colors.crimsonRed : ComicTheme.Colors.deepPurple))
                    .accessibilityHint(speechService.isRecording ? "Tap to stop voice recording" : "Tap to start describing your dream with your voice")

                    if speechService.isRecording {
                        HStack(spacing: 8) {
                            PulsingDot()
                            Text("Listening...")
                                .font(ComicTheme.Typography.speechBubble(13))
                                .foregroundColor(.secondary)
                        }
                    }

                    if let error = speechService.error {
                        Text(error)
                            .font(ComicTheme.Typography.speechBubble(12))
                            .foregroundColor(ComicTheme.Colors.crimsonRed)
                            .speechBubble()
                    }

                    // Dream date picker
                    ComicPanelCard(bannerColor: ComicTheme.Colors.goldenYellow) {
                        DatePicker(
                            "When did you see this dream?",
                            selection: $dreamDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .font(ComicTheme.Typography.speechBubble(13))
                        .datePickerStyle(.compact)
                    }

                    Button {
                        let dream = Dream(originalText: dreamText, date: dreamDate)
                        store.addDream(dream)
                        // Fire-and-forget analysis if authenticated
                        if AuthManager.shared.isAuthenticated {
                            let dreamId = dream.id
                            let text = dreamText
                            let entryDate = dream.date
                            Task {
                                if let result = try? await analysisService.analyzeDream(text: text, dreamDate: entryDate) {
                                    if var updated = store.dreams.first(where: { $0.id == dreamId }) {
                                        updated.analysis = result
                                        store.updateDream(updated)
                                    }
                                }
                            }
                        }
                        dismiss()
                    } label: {
                        Label("Save Dream", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.comicPrimary(color: ComicTheme.Colors.emeraldGreen))
                    .disabled(dreamText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .halftoneBackground()
            .navigationTitle("New Dream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(ComicTheme.Colors.crimsonRed)
                    .fontWeight(.bold)
                }
            }
            .onChange(of: speechService.transcribedText) { _, newValue in
                if !newValue.isEmpty {
                    dreamText = newValue
                }
            }
            .onDisappear {
                speechService.stopRecording()
            }
        }
    }
}

// MARK: - Pulsing Recording Indicator

private struct PulsingDot: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(ComicTheme.Colors.crimsonRed)
            .frame(width: 10, height: 10)
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}
