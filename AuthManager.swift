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
    
    // MARK: - UserDefaults Keys
    
    private let tokenKey = "authToken"
    private let userIdKey = "userId"
    private let emailKey = "userEmail"
    private let cloudEnabledKey = "isCloudEnabled"
    
    // MARK: - Services
    
    private let backendService = BackendService.shared
    
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
            let response = try await backendService.register(email: email, password: password)
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
            let response = try await backendService.login(email: email, password: password)
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
        isAuthenticated = false
        
        // Clear stored credentials
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: emailKey)
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
            self.isAuthenticated = true
            
            // Persist to UserDefaults
            UserDefaults.standard.set(response.token, forKey: tokenKey)
            UserDefaults.standard.set(response.user._id, forKey: userIdKey)
            UserDefaults.standard.set(email, forKey: emailKey)
        }
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
