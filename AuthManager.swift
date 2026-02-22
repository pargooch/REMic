import Foundation
import Combine

// MARK: - AuthManager

/// Manages user authentication and session state
/// Provides cloud sync capabilities when authenticated
class AuthManager: ObservableObject {
    // MARK: - Singleton
    
    static let shared = AuthManager()
    
    // MARK: - Published Properties
    
    /// Whether the user is currently authenticated
    @Published var isAuthenticated = false
    
    /// Loading state during authentication operations
    @Published var isLoading = false
    
    /// Current error message to display to user
    @Published var error: String?
    
    /// User ID from the backend (used for cloud operations)
    @Published var cloudUserId: String?
    
    /// Whether the user's email has been verified
    @Published var emailVerified = false

    /// Whether cloud sync is enabled
    @Published var isCloudEnabled = true
    
    // MARK: - Private Properties
    
    /// JWT authentication token
    private(set) var authToken: String?
    
    /// User's email address
    private(set) var userEmail: String?
    
    /// User ID (alias for cloudUserId for compatibility)
    var userId: String? {
        cloudUserId
    }

    /// Cached user profile (gender, age, timezone)
    @Published var userProfile: UserProfile?

    /// Avatar image data (cached locally)
    private(set) var avatarImageData: Data?

    /// AI-generated description of the user's avatar
    private(set) var avatarDescription: String?

    /// Convenience: build a DreamerProfile from cached user data
    var dreamerProfile: DreamerProfile? {
        guard let profile = userProfile,
              profile.gender != nil || profile.age != nil || avatarDescription != nil else {
            return nil
        }
        return DreamerProfile(
            gender: profile.gender,
            age: profile.age,
            avatar_description: avatarDescription
        )
    }

    // MARK: - UserDefaults Keys

    private let tokenKey = "authToken"
    private let userIdKey = "userId"
    private let emailKey = "userEmail"
    private let cloudEnabledKey = "isCloudEnabled"
    private let genderKey = "userGender"
    private let ageKey = "userAge"
    private let timezoneKey = "userTimezone"
    private let avatarDescriptionKey = "avatarDescription"
    private let emailVerifiedKey = "emailVerified"
    
    // MARK: - Services

    private let backendService = BackendService.shared
    private let turnstileService = TurnstileService.shared
    
    // MARK: - Initialization
    
    private init() {
        loadStoredCredentials()
    }
    
    // MARK: - Public Methods
    
    /// Sign up a new user
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    func signUp(email: String, password: String) async {
        await MainActor.run {
            isLoading = true
            error = nil
        }

        do {
            let turnstileToken = try await turnstileService.getToken()
            let response = try await backendService.register(email: email, password: password, turnstileToken: turnstileToken)
            await handleAuthSuccess(response: response, email: email)
        } catch {
            await handleAuthError(error)
        }

        await MainActor.run {
            isLoading = false
        }
    }

    /// Sign up a new user with profile details
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - profile: User profile (gender, age, timezone)
    func signUp(email: String, password: String, profile: UserProfile) async {
        await MainActor.run {
            isLoading = true
            error = nil
        }

        do {
            let turnstileToken = try await turnstileService.getToken()
            let response = try await backendService.register(email: email, password: password, profile: profile, turnstileToken: turnstileToken)
            await handleAuthSuccess(response: response, email: email)
        } catch {
            await handleAuthError(error)
        }

        await MainActor.run {
            isLoading = false
        }
    }

    /// Login an existing user
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    func login(email: String, password: String) async {
        await MainActor.run {
            isLoading = true
            error = nil
        }

        do {
            let turnstileToken = try await turnstileService.getToken()
            let response = try await backendService.login(email: email, password: password, turnstileToken: turnstileToken)
            await handleAuthSuccess(response: response, email: email)
        } catch {
            await handleAuthError(error)
        }

        await MainActor.run {
            isLoading = false
        }
    }
    
    /// Logout the current user and clear all credentials
    func logout() {
        authToken = nil
        userEmail = nil
        cloudUserId = nil
        userProfile = nil
        avatarImageData = nil
        avatarDescription = nil
        emailVerified = false
        isAuthenticated = false

        // Clear stored credentials
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: emailKey)
        UserDefaults.standard.removeObject(forKey: genderKey)
        UserDefaults.standard.removeObject(forKey: ageKey)
        UserDefaults.standard.removeObject(forKey: timezoneKey)
        UserDefaults.standard.removeObject(forKey: avatarDescriptionKey)
        UserDefaults.standard.removeObject(forKey: emailVerifiedKey)

        // Remove avatar file
        clearAvatarFromDocuments()
    }
    
    /// Update profile on backend (PATCH) and cache locally
    func updateProfile(gender: String?, age: Int?) async throws {
        let updated = try await backendService.updateMyProfile(
            gender: gender,
            age: age
        )
        await MainActor.run {
            self.userProfile = updated
            cacheProfile(updated)
        }
    }

    /// Fetch profile from backend and cache locally
    func fetchProfile() async {
        guard isAuthenticated else { return }
        do {
            let profile = try await backendService.getMyProfile()
            await MainActor.run {
                self.userProfile = profile
                cacheProfile(profile)
                if let desc = profile.avatar_description {
                    self.avatarDescription = desc
                    UserDefaults.standard.set(desc, forKey: avatarDescriptionKey)
                }
            }
        } catch {
            print("Failed to fetch profile: \(error)")
        }
    }

    /// Re-fetch user object from backend and update emailVerified state
    func refreshUser() async {
        guard isAuthenticated else { return }
        do {
            let user = try await backendService.getMe()
            await MainActor.run {
                self.emailVerified = user.email_verified ?? false
                UserDefaults.standard.set(self.emailVerified, forKey: emailVerifiedKey)
                if let profile = user.profile {
                    self.userProfile = profile
                    cacheProfile(profile)
                }
            }
        } catch BackendError.notFound {
            // User account not found on this server — stale credentials, clear them
            print("[Auth] User not found on server, clearing stale credentials")
            await MainActor.run { logout() }
        } catch BackendError.unauthorized {
            await MainActor.run { logout() }
        } catch {
            print("Failed to refresh user: \(error)")
        }
    }

    /// Request password reset email. Returns a user-facing message.
    func requestPasswordReset(email: String) async -> String {
        do {
            let turnstileToken = try await turnstileService.getToken()
            let response = try await backendService.forgotPassword(email: email, turnstileToken: turnstileToken)
            return response.message ?? L("Password reset email sent!")
        } catch let error as BackendError {
            if case .serverError(_, let message) = error {
                return message ?? L("Failed to send reset email")
            }
            return error.localizedDescription
        } catch {
            return error.localizedDescription
        }
    }

    /// Resend verification email. Returns a user-facing message.
    func resendVerificationEmail() async -> String {
        do {
            let response = try await backendService.resendVerification()
            return response.message ?? L("Verification email sent!")
        } catch let error as BackendError {
            if case .serverError(400, let message) = error {
                return message ?? L("Email is already verified")
            }
            return error.localizedDescription
        } catch {
            return error.localizedDescription
        }
    }

    private func cacheProfile(_ profile: UserProfile) {
        if let gender = profile.gender {
            UserDefaults.standard.set(gender, forKey: genderKey)
        } else {
            UserDefaults.standard.removeObject(forKey: genderKey)
        }
        if let age = profile.age {
            UserDefaults.standard.set(age, forKey: ageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: ageKey)
        }
        if let tz = profile.timezone {
            UserDefaults.standard.set(tz, forKey: timezoneKey)
        }
    }

    /// Toggle cloud sync on/off
    func setCloudEnabled(_ enabled: Bool) {
        isCloudEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: cloudEnabledKey)
    }
    
    // MARK: - Private Helpers
    
    /// Load stored credentials from UserDefaults
    private func loadStoredCredentials() {
        authToken = UserDefaults.standard.string(forKey: tokenKey)
        cloudUserId = UserDefaults.standard.string(forKey: userIdKey)
        userEmail = UserDefaults.standard.string(forKey: emailKey)
        isCloudEnabled = UserDefaults.standard.object(forKey: cloudEnabledKey) as? Bool ?? true
        emailVerified = UserDefaults.standard.bool(forKey: emailVerifiedKey)

        // Restore cached profile
        let gender = UserDefaults.standard.string(forKey: genderKey)
        let age = UserDefaults.standard.object(forKey: ageKey) as? Int
        let timezone = UserDefaults.standard.string(forKey: timezoneKey)
        if gender != nil || age != nil || timezone != nil {
            userProfile = UserProfile(gender: gender, age: age, timezone: timezone)
        }

        avatarDescription = UserDefaults.standard.string(forKey: avatarDescriptionKey)
        loadAvatarFromDocuments()

        // Update authentication state
        isAuthenticated = authToken != nil && cloudUserId != nil
    }
    
    /// Handle successful authentication
    private func handleAuthSuccess(response: AuthResponse, email: String) async {
        await MainActor.run {
            // Store credentials
            self.authToken = response.token
            self.cloudUserId = response.user._id
            self.userEmail = email
            self.emailVerified = response.user.email_verified ?? false
            self.isAuthenticated = true

            // Cache user profile from auth response
            if let profile = response.user.profile {
                self.userProfile = profile
                cacheProfile(profile)
            }

            // Persist to UserDefaults
            UserDefaults.standard.set(response.token, forKey: tokenKey)
            UserDefaults.standard.set(response.user._id, forKey: userIdKey)
            UserDefaults.standard.set(email, forKey: emailKey)
            UserDefaults.standard.set(self.emailVerified, forKey: emailVerifiedKey)
        }

        // Fetch full profile (includes avatar description) after login
        await fetchProfile()
    }
    
    /// Handle authentication errors
    private func handleAuthError(_ error: Error) async {
        await MainActor.run {
            if let backendError = error as? BackendError {
                switch backendError {
                case .unauthorized:
                    self.error = "Invalid email or password"
                    // Clear stored credentials if unauthorized
                    logout()
                case .conflict(let message):
                    self.error = message
                case .networkError(let networkError):
                    self.error = "Network error: \(networkError.localizedDescription)"
                case .serverError(_, let message):
                    self.error = message ?? "Server error occurred"
                default:
                    self.error = backendError.localizedDescription
                }
            } else {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Avatar Management

    /// Save avatar image and description
    func setAvatar(imageData: Data, description: String) {
        avatarImageData = imageData
        avatarDescription = description
        UserDefaults.standard.set(description, forKey: avatarDescriptionKey)
        saveAvatarToDocuments(imageData)
    }

    /// Clear avatar data
    func clearAvatar() {
        avatarImageData = nil
        avatarDescription = nil
        UserDefaults.standard.removeObject(forKey: avatarDescriptionKey)
        clearAvatarFromDocuments()
    }

    private var avatarFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("avatar.png")
    }

    private func saveAvatarToDocuments(_ data: Data) {
        try? data.write(to: avatarFileURL)
    }

    private func loadAvatarFromDocuments() {
        if let data = try? Data(contentsOf: avatarFileURL) {
            avatarImageData = data
        }
    }

    private func clearAvatarFromDocuments() {
        try? FileManager.default.removeItem(at: avatarFileURL)
    }
}

// MARK: - SyncQueueManager

/// Manages background synchronization queue for cloud operations
/// Coordinates sync tasks when user is authenticated
class SyncQueueManager: ObservableObject {
    // MARK: - Singleton
    
    static let shared = SyncQueueManager()
    
    // MARK: - Published Properties
    
    /// Whether a sync operation is currently in progress
    @Published var isSyncing = false
    
    /// Number of pending sync operations
    @Published var pendingOperations = 0
    
    /// Last sync timestamp
    @Published var lastSyncDate: Date?
    
    /// Current sync error if any
    @Published var syncError: String?
    
    // MARK: - Private Properties
    
    private var syncQueue: [SyncOperation] = []
    private let authManager = AuthManager.shared
    
    // MARK: - Initialization
    
    private init() {
        // Initialize sync queue
    }
    
    // MARK: - Public Methods
    
    /// Add a sync operation to the queue
    func enqueueSyncOperation(_ operation: SyncOperation) {
        syncQueue.append(operation)
        pendingOperations = syncQueue.count
    }
    
    /// Process all pending sync operations
    func processSyncQueue() async {
        guard authManager.isAuthenticated else {
            syncError = "Not authenticated"
            return
        }
        
        guard !isSyncing else {
            return // Already syncing
        }
        
        await MainActor.run {
            isSyncing = true
            syncError = nil
        }
        
        // Process operations
        while !syncQueue.isEmpty {
            let operation = syncQueue.removeFirst()
            await processOperation(operation)
        }
        
        await MainActor.run {
            isSyncing = false
            pendingOperations = syncQueue.count
            lastSyncDate = Date()
        }
    }
    
    /// Clear all pending operations
    func clearQueue() {
        syncQueue.removeAll()
        pendingOperations = 0
    }
    
    // MARK: - Private Helpers
    
    private func processOperation(_ operation: SyncOperation) async {
        // Process individual sync operation
        // This is a placeholder for actual sync logic
        do {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
            // Actual sync logic would go here
        } catch {
            await MainActor.run {
                syncError = error.localizedDescription
            }
        }
    }
}

// MARK: - SyncOperation

/// Represents a single sync operation
struct SyncOperation {
    enum OperationType {
        case upload
        case download
        case delete
    }
    
    let id: UUID
    let type: OperationType
    let resourceId: String?
    
    init(type: OperationType, resourceId: String? = nil) {
        self.id = UUID()
        self.type = type
        self.resourceId = resourceId
    }
}
