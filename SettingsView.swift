import SwiftUI

struct SettingsView: View {
    @StateObject private var authManager = AuthManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: ComicTheme.Dimensions.gutterWidth) {
                // Account section
                ComicPanelCard(titleBanner: "Account", bannerColor: ComicTheme.Colors.deepPurple) {
                    if authManager.isAuthenticated {
                        NavigationLink {
                            AccountView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.title2.weight(.bold))
                                    .foregroundColor(ComicTheme.Colors.deepPurple)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(authManager.userEmail ?? "Signed in")
                                        .font(ComicTheme.Typography.comicButton(14))
                                        .foregroundColor(.primary)
                                    Text("Cloud sync enabled")
                                        .font(ComicTheme.Typography.speechBubble(12))
                                        .foregroundColor(ComicTheme.Colors.emeraldGreen)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink {
                            AuthView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.title2.weight(.bold))
                                    .foregroundColor(ComicTheme.Colors.boldBlue)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Sign In / Sign Up")
                                        .font(ComicTheme.Typography.comicButton(14))
                                        .foregroundColor(.primary)
                                    Text("Create an account to sync dreams and AI content.")
                                        .font(ComicTheme.Typography.speechBubble(12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Notifications section
                ComicPanelCard(titleBanner: "Notifications", bannerColor: ComicTheme.Colors.emeraldGreen) {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bell.badge.fill")
                                .font(.title3.weight(.bold))
                                .foregroundColor(ComicTheme.Colors.goldenYellow)
                            Text("Notification Settings")
                                .font(ComicTheme.Typography.comicButton(14))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .halftoneBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AccountView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var showAvatarPicker = false
    @State private var gender: String = ""
    @State private var ageString: String = ""
    @State private var isSaving = false
    @Environment(\.colorScheme) private var colorScheme

    private var profileChanged: Bool {
        let currentGender = authManager.userProfile?.gender ?? ""
        let currentAge = authManager.userProfile?.age.map { String($0) } ?? ""
        return gender != currentGender || ageString != currentAge
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ComicTheme.Dimensions.gutterWidth) {
                // Profile card
                ComicPanelCard(titleBanner: "Profile", bannerColor: ComicTheme.Colors.deepPurple) {
                    HStack(spacing: 14) {
                        ProfilePictureView(size: 60, editable: true) {
                            showAvatarPicker = true
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.userEmail ?? "Signed in")
                                .font(ComicTheme.Typography.comicButton(14))
                            if authManager.isCloudEnabled {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                    Text("Cloud sync enabled")
                                }
                                .font(ComicTheme.Typography.speechBubble(12))
                                .foregroundColor(ComicTheme.Colors.emeraldGreen)
                            }
                        }
                        Spacer()
                    }
                }

                // Dream Character profile
                ComicPanelCard(titleBanner: "Dream Character", bannerColor: ComicTheme.Colors.hotPink) {
                    VStack(spacing: 14) {
                        Text("These details personalize your dream comics")
                            .font(ComicTheme.Typography.speechBubble(12))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        GenderPicker(selection: $gender)

                        ComicTextField(
                            icon: "number",
                            iconColor: ComicTheme.Colors.goldenYellow,
                            placeholder: "Age",
                            text: $ageString,
                            keyboardType: .numberPad
                        )

                        if let desc = authManager.avatarDescription {
                            HStack(spacing: 10) {
                                Image(systemName: "person.text.rectangle")
                                    .font(.body.weight(.bold))
                                    .foregroundColor(ComicTheme.Colors.hotPink)
                                    .frame(width: 24)
                                Text(desc)
                                    .font(ComicTheme.Typography.speechBubble(13))
                                    .foregroundColor(.secondary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ComicTheme.Semantic.cardSurface(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: ComicTheme.Dimensions.buttonCornerRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: ComicTheme.Dimensions.buttonCornerRadius)
                                    .stroke(ComicTheme.Semantic.panelBorder(colorScheme).opacity(0.3), lineWidth: 2.0)
                            )
                        }

                        if profileChanged {
                            Button {
                                Task { await saveProfile() }
                            } label: {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Label("Save", systemImage: "checkmark.circle.fill")
                                }
                            }
                            .buttonStyle(.comicPrimary(color: ComicTheme.Colors.hotPink))
                            .disabled(isSaving)
                        }
                    }
                }

                // Sign out
                Button(role: .destructive) {
                    authManager.logout()
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .buttonStyle(.comicDestructive)
            }
            .padding()
        }
        .halftoneBackground()
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            gender = authManager.userProfile?.gender ?? ""
            ageString = authManager.userProfile?.age.map { String($0) } ?? ""
        }
        .sheet(isPresented: $showAvatarPicker) {
            AvatarPickerView()
        }
    }

    private func saveProfile() async {
        isSaving = true
        await authManager.updateProfile(
            gender: gender.isEmpty ? nil : gender,
            age: Int(ageString)
        )
        isSaving = false
    }
}

// MARK: - Gender Picker

struct GenderPicker: View {
    @Binding var selection: String
    @Environment(\.colorScheme) private var colorScheme

    private let options = ["Male", "Female", "Non-binary", "Prefer not to say"]

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.fill")
                .font(.body.weight(.bold))
                .foregroundColor(ComicTheme.Colors.deepPurple)
                .frame(width: 24)

            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection = option
                    } label: {
                        HStack {
                            Text(option)
                            if selection == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selection.isEmpty ? "Gender" : selection)
                        .font(ComicTheme.Typography.speechBubble())
                        .foregroundColor(selection.isEmpty ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(ComicTheme.Semantic.cardSurface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ComicTheme.Dimensions.buttonCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: ComicTheme.Dimensions.buttonCornerRadius)
                .stroke(ComicTheme.Semantic.panelBorder(colorScheme).opacity(0.3), lineWidth: 2.0)
        )
    }
}
