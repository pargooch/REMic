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
    @State private var showForgotPassword = false

    var body: some View {
        ScrollView {
            VStack(spacing: ComicTheme.Dimensions.gutterWidth) {
                // Title sound effect
                SoundEffectText(
                    text: isLoginMode ? L("LOG IN!") : L("SIGN UP!"),
                    fillColor: ComicTheme.Colors.boldBlue,
                    fontSize: 32
                )
                .padding(.top, 8)

                // Credentials
                ComicPanelCard(titleBanner: L("Account"), bannerColor: ComicTheme.Colors.boldBlue) {
                    VStack(spacing: 14) {
                        ComicTextField(
                            icon: "envelope.fill",
                            iconColor: ComicTheme.Colors.boldBlue,
                            placeholder: L("Email"),
                            text: $email,
                            keyboardType: .emailAddress
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                        ComicSecureField(
                            icon: "lock.fill",
                            iconColor: ComicTheme.Colors.crimsonRed,
                            placeholder: L("Password"),
                            text: $password
                        )
                    }
                }

                // Profile fields (sign up only)
                if !isLoginMode {
                    ComicPanelCard(titleBanner: L("Profile"), bannerColor: ComicTheme.Colors.deepPurple) {
                        VStack(spacing: 14) {
                            GenderPicker(selection: $gender)

                            ComicTextField(
                                icon: "number",
                                iconColor: ComicTheme.Colors.goldenYellow,
                                placeholder: L("Age"),
                                text: $ageString,
                                keyboardType: .numberPad
                            )

                            ComicTextField(
                                icon: "globe",
                                iconColor: ComicTheme.Colors.emeraldGreen,
                                placeholder: L("Timezone (e.g., %@)", TimeZone.current.identifier),
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
                        SoundEffectText(text: L("LOADING!"), fillColor: ComicTheme.Colors.boldBlue, fontSize: 20)
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
                            isLoginMode ? L("Log In") : L("Create Account"),
                            systemImage: isLoginMode ? "arrow.right.circle.fill" : "person.badge.plus"
                        )
                    }
                    .buttonStyle(.comicPrimary(color: isLoginMode ? ComicTheme.Colors.boldBlue : ComicTheme.Colors.emeraldGreen))
                    .disabled(isSubmitDisabled)
                    .opacity(isSubmitDisabled ? 0.5 : 1.0)
                }

                // Forgot password (login only)
                if isLoginMode && !authManager.isLoading {
                    Button {
                        showForgotPassword = true
                    } label: {
                        Text(L("Forgot Password?"))
                            .font(ComicTheme.Typography.comicButton(13))
                            .foregroundColor(ComicTheme.Colors.crimsonRed)
                    }
                    .buttonStyle(.plain)
                }

                // Toggle mode
                HStack(spacing: 6) {
                    Text(isLoginMode ? L("Need an account?") : L("Have an account?"))
                        .font(ComicTheme.Typography.speechBubble(14))
                        .foregroundColor(.secondary)
                    Button(isLoginMode ? L("Sign Up") : L("Log In")) {
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
        .navigationTitle(isLoginMode ? L("Log In") : L("Sign Up"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordSheet(prefillEmail: email)
        }
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

// MARK: - Forgot Password Sheet

struct ForgotPasswordSheet: View {
    var prefillEmail: String = ""

    @StateObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var isSending = false
    @State private var resultMessage: String?
    @State private var isSuccess = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: ComicTheme.Dimensions.gutterWidth) {
                    SoundEffectText(
                        text: L("RESET!"),
                        fillColor: ComicTheme.Colors.crimsonRed,
                        fontSize: 28
                    )
                    .padding(.top, 8)

                    ComicPanelCard(titleBanner: L("Forgot Password"), bannerColor: ComicTheme.Colors.crimsonRed) {
                        VStack(spacing: 14) {
                            Text(L("Enter your email address and we'll send you a link to reset your password."))
                                .font(ComicTheme.Typography.speechBubble(13))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ComicTextField(
                                icon: "envelope.fill",
                                iconColor: ComicTheme.Colors.boldBlue,
                                placeholder: L("Email"),
                                text: $email,
                                keyboardType: .emailAddress
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                        }
                    }

                    if isSending {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(ComicTheme.Colors.crimsonRed)
                            Text(L("Sending..."))
                                .font(ComicTheme.Typography.speechBubble(13))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button {
                            Task { await sendReset() }
                        } label: {
                            Label(L("Send Reset Link"), systemImage: "envelope.arrow.triangle.branch")
                        }
                        .buttonStyle(.comicPrimary(color: ComicTheme.Colors.crimsonRed))
                        .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                    }

                    if let resultMessage {
                        Text(resultMessage)
                            .font(ComicTheme.Typography.speechBubble(13))
                            .foregroundColor(isSuccess ? ComicTheme.Colors.emeraldGreen : ComicTheme.Colors.crimsonRed)
                            .speechBubble()
                    }
                }
                .padding()
            }
            .halftoneBackground()
            .navigationTitle(L("Forgot Password"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Cancel")) {
                        dismiss()
                    }
                    .foregroundStyle(ComicTheme.Colors.crimsonRed)
                    .fontWeight(.bold)
                }
            }
        }
        .onAppear {
            if email.isEmpty {
                email = prefillEmail
            }
        }
    }

    private func sendReset() async {
        isSending = true
        let message = await authManager.requestPasswordReset(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
        isSending = false
        resultMessage = message
        isSuccess = !message.lowercased().contains("fail") && !message.lowercased().contains("error")
    }
}
