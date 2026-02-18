import Foundation

class BackendService {
    static let shared = BackendService()

    private let baseURL: URL = {
        #if DEBUG
        return URL(string: "http://localhost:3002/api/")!
        #else
        return URL(string: "https://dreamcatcher-api.percodice.it/api/")!
        #endif
    }()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config)
    }

    private var authToken: String? {
        AuthManager.shared.authToken
    }

    private func makeURL(path: String) throws -> URL {
        let relativePath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard let url = URL(string: relativePath, relativeTo: baseURL) else {
            throw BackendError.invalidURL
        }
        return url
    }

    private func makeRequest(url: URL, method: String, body: Data? = nil, requiresAuth: Bool = false) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if requiresAuth, let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw BackendError.noData
            }

            switch httpResponse.statusCode {
            case 200...299:
                guard !data.isEmpty else {
                    throw BackendError.noData
                }
                do {
                    let decoder = JSONDecoder()
                    return try decoder.decode(T.self, from: data)
                } catch {
                    #if DEBUG
                    if let raw = String(data: data, encoding: .utf8) {
                        print("⚠️ Decoding \(T.self) failed. Raw response:\n\(raw)")
                    }
                    print("⚠️ Decoding error: \(error)")
                    #endif
                    throw BackendError.decodingError(error)
                }
            case 401:
                throw BackendError.unauthorized
            case 404:
                throw BackendError.notFound("Resource not found")
            case 409:
                throw BackendError.conflict("Conflict with existing resource")
            default:
                let message = String(data: data, encoding: .utf8)
                throw BackendError.serverError(statusCode: httpResponse.statusCode, message: message)
            }
        } catch let error as BackendError {
            throw error
        } catch {
            throw BackendError.networkError(error)
        }
    }

    private func sendVoid(_ request: URLRequest) async throws {
        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw BackendError.noData
            }
            switch httpResponse.statusCode {
            case 200...299:
                return
            case 401:
                throw BackendError.unauthorized
            case 404:
                throw BackendError.notFound("Resource not found")
            case 409:
                throw BackendError.conflict("Conflict with existing resource")
            default:
                throw BackendError.serverError(statusCode: httpResponse.statusCode, message: nil)
            }
        } catch let error as BackendError {
            throw error
        } catch {
            throw BackendError.networkError(error)
        }
    }

    func register(email: String, password: String) async throws -> AuthResponse {
        let url = try makeURL(path: "auth/register")
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        let request = try makeRequest(url: url, method: "POST", body: data, requiresAuth: false)
        return try await send(request, as: AuthResponse.self)
    }

    func register(email: String, password: String, profile: UserProfile) async throws -> AuthResponse {
        let url = try makeURL(path: "auth/register")
        var profileDict: [String: Any] = [:]
        if let gender = profile.gender { profileDict["gender"] = gender }
        if let age = profile.age { profileDict["age"] = age }
        if let timezone = profile.timezone { profileDict["timezone"] = timezone }

        let body: [String: Any] = [
            "email": email,
            "password": password,
            "profile": profileDict
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        let request = try makeRequest(url: url, method: "POST", body: data, requiresAuth: false)
        return try await send(request, as: AuthResponse.self)
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let url = try makeURL(path: "auth/login")
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        let request = try makeRequest(url: url, method: "POST", body: data, requiresAuth: false)
        return try await send(request, as: AuthResponse.self)
    }

    func getDreams(userId: String?) async throws -> [APIDream] {
        var components = URLComponents(url: try makeURL(path: "/dreams/"), resolvingAgainstBaseURL: true)
        if let userId = userId {
            components?.queryItems = [URLQueryItem(name: "user_id", value: userId)]
        }
        guard let url = components?.url else {
            throw BackendError.invalidURL
        }
        let request = try makeRequest(url: url, method: "GET", requiresAuth: true)
        return try await send(request, as: [APIDream].self)
    }

    func getDream(id: String) async throws -> APIDream {
        let url = try makeURL(path: "/dreams/\(id)")
        let request = try makeRequest(url: url, method: "GET", requiresAuth: true)
        return try await send(request, as: APIDream.self)
    }

    func createDream(userId: String, originalText: String, title: String?) async throws -> APIDream {
        let url = try makeURL(path: "/dreams/")
        var body: [String: Any] = [
            "user_id": userId,
            "original_text": originalText
        ]
        if let title = title {
            body["title"] = title
        }
        let data = try JSONSerialization.data(withJSONObject: body)
        let request = try makeRequest(url: url, method: "POST", body: data, requiresAuth: true)
        return try await send(request, as: APIDream.self)
    }

    func deleteDream(id: String) async throws {
        let url = try makeURL(path: "/dreams/\(id)")
        let request = try makeRequest(url: url, method: "DELETE", requiresAuth: true)
        try await sendVoid(request)
    }

    func rewriteDream(text: String, moodType: String, model: String? = nil, dreamerProfile: DreamerProfile? = nil) async throws -> AIRewriteResponse {
        let url = try makeURL(path: "/ai/dream-rewrite")
        var body: [String: Any] = [
            "text": text,
            "mood_type": moodType
        ]
        if let model = model {
            body["model"] = model
        }
        if let profile = dreamerProfile {
            var profileDict: [String: Any] = [:]
            if let gender = profile.gender { profileDict["gender"] = gender }
            if let age = profile.age { profileDict["age"] = age }
            if let avatar = profile.avatar_description { profileDict["avatar_description"] = avatar }
            body["dreamer_profile"] = profileDict
        }
        let data = try JSONSerialization.data(withJSONObject: body)
        let request = try makeRequest(url: url, method: "POST", body: data, requiresAuth: true)
        return try await send(request, as: AIRewriteResponse.self)
    }

    func getRewrittenDreams(dreamId: String?) async throws -> [APIRewrittenDream] {
        var components = URLComponents(url: try makeURL(path: "/rewritten-dreams/"), resolvingAgainstBaseURL: true)
        if let dreamId = dreamId {
            components?.queryItems = [URLQueryItem(name: "dream_id", value: dreamId)]
        }
        guard let url = components?.url else {
            throw BackendError.invalidURL
        }
        let request = try makeRequest(url: url, method: "GET", requiresAuth: true)
        return try await send(request, as: [APIRewrittenDream].self)
    }

    func getVisualizations(rewrittenDreamId: String?) async throws -> [APIVisualization] {
        var components = URLComponents(url: try makeURL(path: "/visualizations/"), resolvingAgainstBaseURL: true)
        if let rewrittenDreamId = rewrittenDreamId {
            components?.queryItems = [URLQueryItem(name: "rewritten_dream_id", value: rewrittenDreamId)]
        }
        guard let url = components?.url else {
            throw BackendError.invalidURL
        }
        let request = try makeRequest(url: url, method: "GET", requiresAuth: true)
        return try await send(request, as: [APIVisualization].self)
    }

    func createVisualization(rewrittenDreamId: String, visualizationType: String, imageAssets: [String], status: String) async throws -> APIVisualization {
        let url = try makeURL(path: "/visualizations/")
        let body: [String: Any] = [
            "rewritten_dream_id": rewrittenDreamId,
            "visualization_type": visualizationType,
            "image_assets": imageAssets,
            "status": status
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        let request = try makeRequest(url: url, method: "POST", body: data, requiresAuth: true)
        return try await send(request, as: APIVisualization.self)
    }

    func updateVisualization(id: String, imageAssets: [String]?, status: String?) async throws -> APIVisualization {
        let url = try makeURL(path: "/visualizations/\(id)")
        var body: [String: Any] = [:]
        if let imageAssets = imageAssets {
            body["image_assets"] = imageAssets
        }
        if let status = status {
            body["status"] = status
        }
        let data = try JSONSerialization.data(withJSONObject: body)
        let request = try makeRequest(url: url, method: "PUT", body: data, requiresAuth: true)
        return try await send(request, as: APIVisualization.self)
    }

    func uploadImage(data: Data, filename: String) async throws -> String {
        let url = try makeURL(path: "/uploads/images")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = data

        let (responseData, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.noData
        }
        switch httpResponse.statusCode {
        case 200...299:
            guard let urlString = String(data: responseData, encoding: .utf8), !urlString.isEmpty else {
                throw BackendError.noData
            }
            return urlString
        case 401:
            throw BackendError.unauthorized
        default:
            throw BackendError.serverError(statusCode: httpResponse.statusCode, message: nil)
        }
    }

    // MARK: - Single-Shot Comic Page Generation

    /// One request → backend handles LLM layout + image generation → returns complete page(s)
    func generateComicPage(rewrittenText: String, dreamerProfile: DreamerProfile? = nil) async throws -> ComicPageGenerationResponse {
        let url = try makeURL(path: "ai/generate-comic-page")
        var body: [String: Any] = [
            "rewritten_text": rewrittenText
        ]
        if let profile = dreamerProfile {
            var profileDict: [String: Any] = [:]
            if let gender = profile.gender { profileDict["gender"] = gender }
            if let age = profile.age { profileDict["age"] = age }
            if let avatar = profile.avatar_description { profileDict["avatar_description"] = avatar }
            body["dreamer_profile"] = profileDict
        }
        let data = try JSONSerialization.data(withJSONObject: body)
        let request = try makeRequest(url: url, method: "POST", body: data, requiresAuth: true)
        return try await send(request, as: ComicPageGenerationResponse.self)
    }

    // MARK: - Profile

    func getMyProfile() async throws -> UserProfile {
        let url = try makeURL(path: "users/me/profile")
        let request = try makeRequest(url: url, method: "GET", requiresAuth: true)
        return try await send(request, as: UserProfile.self)
    }

    func updateMyProfile(gender: String? = nil, age: Int? = nil, timezone: String? = nil) async throws -> UserProfile {
        let url = try makeURL(path: "users/me/profile")
        var body: [String: Any] = [:]
        if let gender = gender { body["gender"] = gender }
        if let age = age { body["age"] = age }
        if let timezone = timezone { body["timezone"] = timezone }
        let data = try JSONSerialization.data(withJSONObject: body)
        let request = try makeRequest(url: url, method: "PATCH", body: data, requiresAuth: true)
        return try await send(request, as: UserProfile.self)
    }

    // MARK: - Avatar

    func uploadAvatar(imageData: Data) async throws -> AvatarResponse {
        let url = try makeURL(path: "users/avatar")
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"avatar.png\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        return try await send(request, as: AvatarResponse.self)
    }

    func deleteAvatar() async throws {
        let url = try makeURL(path: "users/avatar")
        let request = try makeRequest(url: url, method: "DELETE", requiresAuth: true)
        try await sendVoid(request)
    }

    // MARK: - Dream Analysis

    func analyzeDream(text: String, dreamDate: Date) async throws -> DreamAnalysisResponse {
        let url = try makeURL(path: "dream-analysis")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let body: [String: Any] = [
            "text": text,
            "dream_date": formatter.string(from: dreamDate)
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        let request = try makeRequest(url: url, method: "POST", body: data, requiresAuth: true)
        return try await send(request, as: DreamAnalysisResponse.self)
    }

    func getDreamAnalysisTrends(period: String) async throws -> TrendsResponse {
        let url = try makeURL(path: "dream-analysis/trends")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [URLQueryItem(name: "period", value: period)]
        guard let finalURL = components?.url else { throw BackendError.invalidURL }
        let request = try makeRequest(url: finalURL, method: "GET", requiresAuth: true)
        return try await send(request, as: TrendsResponse.self)
    }

    func getDreamAnalysisSummary(period: String) async throws -> AnalysisSummaryResponse {
        let url = try makeURL(path: "dream-analysis/summary")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [URLQueryItem(name: "period", value: period)]
        guard let finalURL = components?.url else { throw BackendError.invalidURL }
        let request = try makeRequest(url: finalURL, method: "GET", requiresAuth: true)
        return try await send(request, as: AnalysisSummaryResponse.self)
    }

    func getDreamAnalysis(dreamId: String) async throws -> DreamAnalysisResponse {
        let url = try makeURL(path: "dream-analysis/\(dreamId)")
        let request = try makeRequest(url: url, method: "GET", requiresAuth: true)
        return try await send(request, as: DreamAnalysisResponse.self)
    }

    func getAIModels() async throws -> [AIModel] {
        let url = try makeURL(path: "/ai/models")
        let request = try makeRequest(url: url, method: "GET", requiresAuth: true)
        return try await send(request, as: [AIModel].self)
    }
}
