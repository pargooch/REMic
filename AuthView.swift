import SwiftUI

struct AuthView: View {
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoginMode: Bool = true
    @State private var gender: String = ""
    @State private var ageString: String = ""
    @State private var timezone: String = TimeZone.current.identifier

    var body: some View {
        ScrollView {
            VStack(spacing: ComicTheme.Dimensions.gutterWidth) {
                // Title sound effect
                SoundEffectText(
                    text: isLoginMode ? "LOG IN!" : "SIGN UP!",
                    fillColor: ComicTheme.Colors.boldBlue,
                    fontSize: 32
                )
                .padding(.top, 8)

                // Credentials
                ComicPanelCard(titleBanner: "Account", bannerColor: ComicTheme.Colors.boldBlue) {
                    VStack(spacing: 14) {
                        ComicTextField(
                            icon: "envelope.fill",
                            iconColor: ComicTheme.Colors.boldBlue,
                            placeholder: "Email",
                            text: $email,
                            keyboardType: .emailAddress
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                        ComicSecureField(
                            icon: "lock.fill",
                            iconColor: ComicTheme.Colors.crimsonRed,
                            placeholder: "Password",
                            text: $password
                        )
                    }
                }

                // Profile fields (sign up only)
                if !isLoginMode {
                    ComicPanelCard(titleBanner: "Profile", bannerColor: ComicTheme.Colors.deepPurple) {
                        VStack(spacing: 14) {
                            GenderPicker(selection: $gender)

                            ComicTextField(
                                icon: "number",
                                iconColor: ComicTheme.Colors.goldenYellow,
                                placeholder: "Age",
                                text: $ageString,
                                keyboardType: .numberPad
                            )

                            ComicTextField(
                                icon: "globe",
                                iconColor: ComicTheme.Colors.emeraldGreen,
                                placeholder: "Timezone (e.g., \(TimeZone.current.identifier))",
                                text: $timezone
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                        }
                    }
                }

                // Submit
                if authManager.isLoading {
                    VStack(spacing: 12) {
                        SoundEffectText(text: "LOADING!", fillColor: ComicTheme.Colors.boldBlue, fontSize: 20)
                        ProgressView()
                            .tint(ComicTheme.Colors.boldBlue)
                    }
                } else {
                    Button {
                        Task {
                            await submit()
                        }
                    } label: {
                        Label(
                            isLoginMode ? "Log In" : "Create Account",
                            systemImage: isLoginMode ? "arrow.right.circle.fill" : "person.badge.plus"
                        )
                    }
                    .buttonStyle(.comicPrimary(color: isLoginMode ? ComicTheme.Colors.boldBlue : ComicTheme.Colors.emeraldGreen))
                    .disabled(isSubmitDisabled)
                    .opacity(isSubmitDisabled ? 0.5 : 1.0)
                }

                // Toggle mode
                HStack(spacing: 6) {
                    Text(isLoginMode ? "Need an account?" : "Have an account?")
                        .font(ComicTheme.Typography.speechBubble(14))
                        .foregroundColor(.secondary)
                    Button(isLoginMode ? "Sign Up" : "Log In") {
                        withAnimation(.spring(response: 0.3)) {
                            isLoginMode.toggle()
                        }
                    }
                    .font(ComicTheme.Typography.comicButton(14))
                    .foregroundColor(ComicTheme.Colors.boldBlue)
                    .buttonStyle(.plain)
                }

                // Error
                if let error = authManager.error {
                    Text(error)
                        .font(ComicTheme.Typography.speechBubble(13))
                        .foregroundColor(ComicTheme.Colors.crimsonRed)
                        .speechBubble()
                }
            }
            .padding()
        }
        .halftoneBackground()
        .navigationTitle(isLoginMode ? "Log In" : "Sign Up")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() async {
        if isLoginMode {
            await authManager.login(email: email, password: password)
        } else {
            let age = Int(ageString)
            let profile = UserProfile(
                gender: gender.isEmpty ? nil : gender,
                age: age,
                timezone: timezone.isEmpty ? nil : timezone
            )
            await authManager.signUp(email: email, password: password, profile: profile)
        }
    }

    private var isSubmitDisabled: Bool {
        if authManager.isLoading { return true }
        guard !email.isEmpty, !password.isEmpty else { return true }
        return false
    }
}

// MARK: - Comic Text Field

struct ComicTextField: View {
    let icon: String
    var iconColor: Color = ComicTheme.Colors.boldBlue
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body.weight(.bold))
                .foregroundColor(iconColor)
                .frame(width: 24)

            TextField(placeholder, text: $text)
                .font(ComicTheme.Typography.speechBubble())
                .keyboardType(keyboardType)
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

// MARK: - Comic Secure Field

struct ComicSecureField: View {
    let icon: String
    var iconColor: Color = ComicTheme.Colors.crimsonRed
    let placeholder: String
    @Binding var text: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body.weight(.bold))
                .foregroundColor(iconColor)
                .frame(width: 24)

            SecureField(placeholder, text: $text)
                .font(ComicTheme.Typography.speechBubble())
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
