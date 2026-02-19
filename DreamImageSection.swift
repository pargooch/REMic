import SwiftUI

// MARK: - Dream Image Section

struct DreamImageSection: View {
    let dream: Dream
    let store: DreamStore

    @StateObject private var imageService = ImageGenerationService()
    @State private var showComicViewer = false
    @State private var showLegacyGallery = false
    @State private var errorMessage: String?
    @State private var showSignUpBanner = false
    @AppStorage("dreamIncludeAvatar") private var includeAvatar = true
    @Environment(\.colorScheme) private var colorScheme

    private var isAvailable: Bool {
        ImageGenerationService.isAvailable
    }

    private var hasAvatar: Bool {
        AuthManager.shared.avatarDescription != nil
    }

    var body: some View {
        ComicPanelCard(titleBanner: "Dream Visualization", bannerColor: ComicTheme.Colors.goldenYellow) {
            VStack(alignment: .leading, spacing: 16) {
                // Header row
                HStack {
                    if isAvailable && !dream.hasComicPages && !dream.hasImages {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                
                             
                            }
                            Text("AI creates a comic page from your dream")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .foregroundColor(.secondary)
                    }

                    Spacer()

                    if dream.hasComicPages {
                        Button {
                            showComicViewer = true
                        } label: {
                            Label("View", systemImage: "eye")
                        }
                        .buttonStyle(.comicSecondary)
                        .frame(maxWidth: 120)
                    } else if dream.hasImages {
                        Button {
                            showLegacyGallery = true
                        } label: {
                            Label("View", systemImage: "eye")
                        }
                        .buttonStyle(.comicSecondary)
                        .frame(maxWidth: 120)
                    }
                }

                // Profile completeness prompt
                if isAvailable && !dream.hasComicPages && !dream.hasImages {
                    profileCompletenessPrompt
                }

                // Avatar consent toggle
                if hasAvatar {
                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle")
                            .font(.title3.weight(.bold))
                            .foregroundColor(ComicTheme.Colors.deepPurple)
                        Text("Include my likeness")
                            .font(ComicTheme.Typography.comicButton(13))
                            .textCase(.uppercase)
                            .tracking(0.5)
                        Spacer()
                        Toggle("", isOn: $includeAvatar)
                            .labelsHidden()
                            .tint(ComicTheme.Colors.deepPurple)
                    }
                    .padding(10)
                    .background(ComicTheme.Semantic.cardSurface(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ComicTheme.Dimensions.buttonCornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: ComicTheme.Dimensions.buttonCornerRadius)
                            .stroke(ComicTheme.Colors.deepPurple.opacity(0.3), lineWidth: 2.0)
                    )
                }

                if !isAvailable {
                    unavailableView
                } else if dream.hasComicPages {
                    comicPagePreview
                } else if dream.hasImages {
                    legacyImagesView
                } else {
                    generateView
                }
            }
        }
        .sheet(isPresented: $showComicViewer) {
            ComicPageViewer(pages: dream.sortedComicPages)
        }
        .sheet(isPresented: $showLegacyGallery) {
            DreamImageGalleryView(dream: dream)
        }
    }

    // MARK: - Comic Page Preview

    private var comicPagePreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Show first comic page as preview
            if let firstPage = dream.sortedComicPages.first, let uiImage = firstPage.uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onTapGesture {
                        showComicViewer = true
                    }
            }

            SignUpPromptBanner(isVisible: $showSignUpBanner)

            if imageService.isGenerating {
                generatingView
            } else {
                Button {
                    generateComicPage()
                } label: {
                    Label("Redraw my dream!", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.comicSecondary(color: ComicTheme.Colors.boldBlue))
            }

            errorView
        }
    }

    // MARK: - Legacy Images (backward compat)

    private var legacyImagesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            DreamImagePreview(images: dream.sortedImages)

            SignUpPromptBanner(isVisible: $showSignUpBanner)

            if imageService.isGenerating {
                generatingView
            } else {
                Button {
                    generateComicPage()
                } label: {
                    Label("Regenerate as Comic Page", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.comicSecondary(color: ComicTheme.Colors.boldBlue))
            }

            errorView
        }
    }

    // MARK: - Unavailable State

    private var unavailableView: some View {
        VStack(spacing: 12) {
            SoundEffectText(text: "OFFLINE!", fillColor: ComicTheme.Colors.crimsonRed, fontSize: 22)

            Text("Image generation requires Apple Silicon or sign-in.")
                .font(ComicTheme.Typography.speechBubble(13))
                .multilineTextAlignment(.center)
                .speechBubble()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Generate State

    private var generateView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if imageService.isGenerating {
                generatingView
            } else {
                Button {
                    generateComicPage()
                } label: {
                    Label("Draw my dream!", systemImage: "wand.and.stars")
                }
                .buttonStyle(.comicPrimary(color: ComicTheme.Colors.boldBlue))
            }

            errorView
        }
    }

    // MARK: - Shared Components

    private var generatingView: some View {
        VStack(spacing: 14) {
            SoundEffectText(text: "CREATING!", fillColor: ComicTheme.Colors.goldenYellow, fontSize: 26)
                .frame(maxWidth: .infinity)

            Text(imageService.statusMessage.isEmpty ? "Painting your dream..." : imageService.statusMessage)
                .font(ComicTheme.Typography.speechBubble(13))
                .speechBubble()

            ProgressView(value: imageService.progress)
                .tint(ComicTheme.Colors.boldBlue)

            Button {
                imageService.cancel()
            } label: {
                Label("Cancel", systemImage: "xmark")
            }
            .buttonStyle(.comicDestructive)
        }
    }

    @ViewBuilder
    private var profileCompletenessPrompt: some View {
        let profile = AuthManager.shared.userProfile
        if profile?.gender == nil && profile?.age == nil {
            HStack(spacing: 10) {
                Image(systemName: "person.text.rectangle")
                    .font(.title3.weight(.bold))
                    .foregroundColor(ComicTheme.Colors.hotPink)
                Text("Add your details in Profile to appear in your dreams!")
                    .font(ComicTheme.Typography.speechBubble(12))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(ComicTheme.Semantic.cardSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ComicTheme.Dimensions.buttonCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: ComicTheme.Dimensions.buttonCornerRadius)
                    .stroke(ComicTheme.Colors.hotPink.opacity(0.3), lineWidth: 2.0)
            )
        }
    }

    @ViewBuilder
    private var errorView: some View {
        if let error = errorMessage {
            VStack(spacing: 10) {
                Text(error)
                    .font(ComicTheme.Typography.speechBubble(13))
                    .foregroundColor(ComicTheme.Colors.crimsonRed)
                    .multilineTextAlignment(.center)
                    .speechBubble()

                Button {
                    generateComicPage()
                } label: {
                    Label("Try Again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.comicSecondary(color: ComicTheme.Colors.crimsonRed))
            }
        }
    }

    // MARK: - Actions

    private func generateComicPage() {
        guard let rewrittenText = dream.rewrittenText else { return }
        print("Generating comic page for dream story...")

        errorMessage = nil

        Task {
            do {
                // Build dreamer profile, including avatar only if consented
                var profile = AuthManager.shared.dreamerProfile
                if !includeAvatar {
                    // Strip avatar description when user opts out
                    if let p = profile {
                        profile = DreamerProfile(gender: p.gender, age: p.age, avatar_description: nil)
                    }
                }

                let comicPages = try await imageService.generateComicPage(
                    from: rewrittenText,
                    dreamerProfile: profile
                )

                var updated = dream
                updated.comicPages = comicPages
                store.updateDream(updated)

                if !AuthManager.shared.isAuthenticated {
                    showSignUpBanner = true
                }
            } catch let error as ImageGenerationError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Image Preview (legacy)

struct DreamImagePreview: View {
    let images: [GeneratedDreamImage]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(images) { image in
                    if let uiImage = image.uiImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(ComicTheme.panelBorderColor(colorScheme), lineWidth: 2)
                            )
                    }
                }
            }
        }
    }
}

// MARK: - Image Gallery View (legacy)

struct DreamImageGalleryView: View {
    let dream: Dream
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex: Int = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(dream.sortedImages.enumerated()), id: \.element.id) { index, image in
                        VStack {
                            if let uiImage = image.uiImage {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .padding()
                            }

                            Text("Scene \(index + 1)")
                                .font(ComicTheme.Typography.sectionHeader(16))

                            Text(image.prompt)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(dream.sortedImages.enumerated()), id: \.element.id) { index, image in
                            if let uiImage = image.uiImage {
                                Button {
                                    withAnimation {
                                        selectedIndex = index
                                    }
                                } label: {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(
                                                    selectedIndex == index ? ComicTheme.Colors.boldBlue : Color.clear,
                                                    lineWidth: 2
                                                )
                                        )
                                }
                            }
                        }
                    }
                    .padding()
                }
                .background(ComicTheme.Semantic.cardSurface(.light))
            }
            .halftoneBackground()
            .navigationTitle("Dream Sequence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(ComicTheme.Colors.boldBlue)
                    .fontWeight(.bold)
                }
            }
        }
    }
}

// MARK: - Sign Up Prompt Banner

struct SignUpPromptBanner: View {
    @Binding var isVisible: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if isVisible {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "cloud.fill")
                    .foregroundColor(ComicTheme.Colors.emeraldGreen)
                    .font(.title3.weight(.bold))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Save your dreams!")
                        .font(ComicTheme.Typography.comicButton(13))
                        .textCase(.uppercase)
                    Text("Sign up to sync rewrites and comics across devices.")
                        .font(ComicTheme.Typography.speechBubble(12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    isVisible = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body.weight(.bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(ComicTheme.Semantic.cardSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ComicTheme.Dimensions.buttonCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: ComicTheme.Dimensions.buttonCornerRadius)
                    .stroke(ComicTheme.Colors.emeraldGreen.opacity(0.3), lineWidth: 2.0)
            )
        }
    }
}
