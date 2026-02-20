import SwiftUI

struct DreamsListView: View {
    @EnvironmentObject var store: DreamStore
    @ObservedObject private var authManager = AuthManager.shared
    @State private var searchText = ""
    @State private var resendMessage: String?
    @State private var isResending = false
    @State private var isSelectMode = false
    @State private var selectedDreamIDs: Set<UUID> = []
    @State private var showDeleteConfirmation = false
    @State private var showNewDream = false

    private var filteredDreams: [Dream] {
        guard !searchText.isEmpty else { return store.dreams }
        let query = searchText.lowercased()
        return store.dreams.filter {
            $0.originalText.lowercased().contains(query) ||
            ($0.rewrittenText?.lowercased().contains(query) ?? false) ||
            ($0.tone?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                if authManager.isAuthenticated && !authManager.emailVerified {
                    emailVerificationBanner
                }
                LazyVStack(spacing: ComicTheme.Dimensions.gutterWidth) {
                    if store.dreams.isEmpty {
                        emptyState
                    } else if filteredDreams.isEmpty {
                        Text(L("No dreams match your search"))
                            .font(ComicTheme.Typography.speechBubble(13))
                            .foregroundColor(.secondary)
                            .padding(.top, 40)
                    } else {
                        ForEach(filteredDreams) { dream in
                            if isSelectMode {
                                Button {
                                    toggleSelection(dream.id)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: selectedDreamIDs.contains(dream.id) ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 22, weight: .medium))
                                            .foregroundColor(selectedDreamIDs.contains(dream.id) ? ComicTheme.Colors.boldBlue : .secondary)
                                        DreamRowView(dream: dream)
                                    }
                                }
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink {
                                    DreamDetailView(dream: dream)
                                } label: {
                                    DreamRowView(dream: dream)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
                .padding(.bottom, isSelectMode ? 70 : 0)
            }
            .halftoneBackground()
            .navigationTitle(L("Dreams"))
            .searchable(text: $searchText, prompt: Text(L("Search dreams...")))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSelectMode {
                        Button(L("Cancel")) {
                            exitSelectMode()
                        }
                    } else {
                        NavigationLink {
                            CalendarDreamsView()
                        } label: {
                            Image(systemName: "calendar")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(ComicTheme.Colors.deepPurple)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSelectMode {
                        Button {
                            if selectedDreamIDs.count == filteredDreams.count {
                                selectedDreamIDs.removeAll()
                            } else {
                                selectedDreamIDs = Set(filteredDreams.map(\.id))
                            }
                        } label: {
                            Text(selectedDreamIDs.count == filteredDreams.count ? L("Deselect All") : L("Select All"))
                                .font(.subheadline.weight(.semibold))
                        }
                    } else {
                        HStack(spacing: 12) {
                            if !store.dreams.isEmpty {
                                Button {
                                    isSelectMode = true
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(ComicTheme.Colors.crimsonRed)
                                }
                            }
                            Button {
                                showNewDream = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(ComicTheme.Colors.boldBlue)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showNewDream) {
                NavigationStack {
                    NewDreamView()
                }
            }

            // Delete bar at bottom
            if isSelectMode {
                deleteBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isSelectMode)
        .confirmationDialog(
            L("Delete %lld dreams?", selectedDreamIDs.count),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L("Delete"), role: .destructive) {
                deleteSelectedDreams()
            }
            Button(L("Cancel"), role: .cancel) {}
        } message: {
            Text(L("This will permanently remove the selected dreams and all their content."))
        }
    }

    // MARK: - Delete Bar

    private var deleteBar: some View {
        Button {
            if !selectedDreamIDs.isEmpty {
                showDeleteConfirmation = true
            }
        } label: {
            Label(
                selectedDreamIDs.isEmpty
                    ? L("Select Dreams to Delete")
                    : L("Delete %lld Dreams", selectedDreamIDs.count),
                systemImage: "trash"
            )
        }
        .buttonStyle(.comicDestructive)
        .disabled(selectedDreamIDs.isEmpty)
        .opacity(selectedDreamIDs.isEmpty ? 0.5 : 1)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Helpers

    private func toggleSelection(_ id: UUID) {
        if selectedDreamIDs.contains(id) {
            selectedDreamIDs.remove(id)
        } else {
            selectedDreamIDs.insert(id)
        }
    }

    private func deleteSelectedDreams() {
        for id in selectedDreamIDs {
            NotificationManager.shared.cancelDreamNotification(for: id)
            if let dream = store.dreams.first(where: { $0.id == id }) {
                store.deleteDream(dream)
            }
        }
        exitSelectMode()
    }

    private func exitSelectMode() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isSelectMode = false
            selectedDreamIDs.removeAll()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ComicPanelCard(titleBanner: L("Welcome, Dreamer!"), bannerColor: ComicTheme.Colors.deepPurple) {
            VStack(spacing: 16) {
                SoundEffectText(text: L("DREAM ON!"), fillColor: ComicTheme.Colors.goldenYellow, fontSize: 42)

                Text(L("Record your first dream to begin your comic journey!"))
                    .font(ComicTheme.Typography.speechBubble())
                    .multilineTextAlignment(.center)
                    .speechBubble()
            }
        }
        .padding(.top, 40)
    }

    // MARK: - Email Verification Banner

    private var emailVerificationBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ComicTheme.Colors.goldenYellow)

            VStack(alignment: .leading, spacing: 2) {
                Text(L("Verify your email to unlock all features"))
                    .font(ComicTheme.Typography.caption())
                    .foregroundColor(.primary)

                if let resendMessage {
                    Text(resendMessage)
                        .font(ComicTheme.Typography.caption())
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                guard !isResending else { return }
                isResending = true
                Task {
                    let message = await authManager.resendVerificationEmail()
                    resendMessage = message
                    isResending = false
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    resendMessage = nil
                }
            } label: {
                if isResending {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(L("Resend"))
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(ComicTheme.Colors.goldenYellow))
                }
            }
            .disabled(isResending)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: ComicTheme.Dimensions.panelCornerRadius)
                .fill(ComicTheme.Colors.goldenYellow.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: ComicTheme.Dimensions.panelCornerRadius)
                        .stroke(ComicTheme.Colors.goldenYellow.opacity(0.4), lineWidth: 1.5)
                )
        )
        .padding(.horizontal)
        .padding(.top, 4)
    }
}

struct DreamRowView: View {
    let dream: Dream
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared = false

    private var accentColor: Color {
        if dream.hasComicPages { return ComicTheme.Colors.boldBlue }
        if dream.rewrittenText != nil { return ComicTheme.Colors.goldenYellow }
        return ComicTheme.Colors.deepPurple
    }

    var body: some View {
        ComicPanelCard {
            HStack(spacing: 12) {
                // Thumbnail if comic pages or images exist
                if let firstPage = dream.sortedComicPages.first, let uiImage = firstPage.uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: ComicTheme.Dimensions.badgeCornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: ComicTheme.Dimensions.badgeCornerRadius)
                                .stroke(ComicTheme.Semantic.panelBorder(colorScheme), lineWidth: 1.5)
                        )
                } else if let firstImage = dream.sortedImages.first, let uiImage = firstImage.uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: ComicTheme.Dimensions.badgeCornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: ComicTheme.Dimensions.badgeCornerRadius)
                                .stroke(ComicTheme.Semantic.panelBorder(colorScheme), lineWidth: 1.5)
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(dream.originalText)
                        .lineLimit(2)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)

                    HStack(spacing: 6) {
                        // Date badge
                        Text(dream.date, style: .date)
                            .font(ComicTheme.Typography.caption())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(accentColor.opacity(0.15))
                            .foregroundColor(accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        Spacer()

                        if dream.rewrittenText != nil {
                            Image(systemName: "sparkles")
                                .font(.caption.weight(.bold))
                                .foregroundColor(ComicTheme.Colors.goldenYellow)
                        }

                        if dream.hasComicPages || dream.hasImages {
                            Image(systemName: "book.pages.fill")
                                .font(.caption.weight(.bold))
                                .foregroundColor(ComicTheme.Colors.boldBlue)
                        }
                    }
                }
            }
        }
        .scaleEffect(appeared ? 1.0 : 0.92)
        .opacity(appeared ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        DreamsListView()
            .environmentObject(DreamStore())
    }
}
