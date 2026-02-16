import Foundation
import FoundationModels

// MARK: - AI Service Error

enum AIServiceError: LocalizedError {
    case networkError(Error)
    case invalidAPIKey
    case rateLimited
    case serverError(statusCode: Int)
    case invalidResponse
    case emptyResponse
    case apiError(message: String)
    case cancelled
    case notSupported

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidAPIKey:
            return "Invalid API key. Please check your OpenRouter API key."
        case .rateLimited:
            return "Rate limited. Please wait a moment and try again."
        case .serverError(let statusCode):
            return "Server error (HTTP \(statusCode)). Please try again later."
        case .invalidResponse:
            return "Invalid response from AI service."
        case .emptyResponse:
            return "AI returned an empty response. Please try again."
        case .apiError(let message):
            return "API error: \(message)"
        case .cancelled:
            return "Request was cancelled."
        case .notSupported:
            return "On-device AI requires iOS 26+ with Apple Intelligence."
        }
    }
}

// MARK: - AI Provider

enum AIProvider: String {
    case backend = "Cloud"              // Backend API (requires sign-in)
    case appleFoundationModels = "On-Device"  // On-device, free, private (iOS 26+)
}

// MARK: - AI Service

class AIService {
    private var currentTask: Task<Void, Never>?

    /// Check if Apple Foundation Models is available
    @available(iOS 26.0, *)
    static var isOnDeviceAvailable: Bool {
        let model = SystemLanguageModel.default
        if case .available = model.availability {
            return true
        }
        return false
    }

    /// Check availability with fallback for older iOS
    static var canUseOnDevice: Bool {
        if #available(iOS 26.0, *) {
            return isOnDeviceAvailable
        }
        return false
    }

    /// Check if backend is available (user is signed in)
    static var canUseBackend: Bool {
        AuthManager.shared.isAuthenticated
    }

    /// Get the preferred AI provider
    /// Priority: Backend (if signed in) > On-device (if available)
    static var preferredProvider: AIProvider {
        if canUseBackend {
            return .backend
        } else if canUseOnDevice {
            return .appleFoundationModels
        }
        return .appleFoundationModels
    }

    /// Check if any AI provider is available
    static var isAvailable: Bool {
        canUseBackend || canUseOnDevice
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: - Dream Rewrite (Async)

    /// Rewrite a dream with the specified tone
    /// Uses backend if signed in, falls back to on-device
    func rewriteDream(original: String, tone: String) async throws -> String {
        // Try backend first if authenticated
        if Self.canUseBackend {
            do {
                return try await rewriteWithBackend(original: original, tone: tone)
            } catch {
                print("Backend rewrite failed: \(error), falling back to on-device")
                // Fall through to on-device
            }
        }

        // Try on-device
        if #available(iOS 26.0, *), Self.isOnDeviceAvailable {
            return try await rewriteWithFoundationModelsAsync(original: original, tone: tone)
        }

        throw AIServiceError.notSupported
    }

    // MARK: - Dream Rewrite (Completion Handler - Legacy)

    func rewriteDream(
        original: String,
        tone: String,
        completion: @escaping (Result<String, AIServiceError>) -> Void
    ) {
        Task {
            do {
                let result = try await rewriteDream(original: original, tone: tone)
                await MainActor.run {
                    completion(.success(result))
                }
            } catch let error as AIServiceError {
                await MainActor.run {
                    completion(.failure(error))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(.apiError(message: error.localizedDescription)))
                }
            }
        }
    }

    // MARK: - Backend Implementation

    private func rewriteWithBackend(original: String, tone: String) async throws -> String {
        guard let userId = AuthManager.shared.userId else {
            throw AIServiceError.notSupported
        }

        // Step 1: Create dream on backend
        let apiDream = try await BackendService.shared.createDream(
            userId: userId,
            originalText: original,
            title: "Dream"
        )

        // Step 2: Request AI rewrite with mood
        let moodType = mapToneToMoodType(tone)
        let rewrittenDream = try await BackendService.shared.rewriteDream(
            dreamId: apiDream._id,
            moodType: moodType
        )

        return rewrittenDream.rewritten_text
    }

    /// Map app tone names to backend mood_type values
    private func mapToneToMoodType(_ tone: String) -> String {
        switch tone.lowercased() {
        case "happy": return "happy"
        case "funny": return "humorous"
        case "hopeful": return "empowering"
        case "calm": return "peaceful"
        case "positive": return "empowering"
        default: return "neutral"
        }
    }

    // MARK: - Foundation Models Async Implementation

    @available(iOS 26.0, *)
    private func rewriteWithFoundationModelsAsync(original: String, tone: String) async throws -> String {
        let session = LanguageModelSession(
            instructions: """
            You are a master storyteller and therapeutic writing specialist trained in Imagery Rehearsal Therapy (IRT).
            You transform nightmares and distressing dreams into healing, empowering narratives.

            YOUR EXPERTISE:
            - Literary fiction writing with rich, evocative prose
            - Psychological understanding of dream symbolism and emotional processing
            - Therapeutic narrative techniques that promote healing and resolution

            WRITING MASTERY:
            - Use varied sentence rhythms: short punchy sentences for impact, flowing sentences for beauty
            - Include vivid sensory details: textures, colors, sounds, scents, physical sensations
            - Employ literary devices: metaphors, similes, personification, imagery
            - Create atmospheric immersion through environmental description
            - Build emotional arcs with natural progression and satisfying resolution

            THERAPEUTIC TRANSFORMATION:
            - Fear transforms into courage and curiosity
            - Threats become protectors or allies
            - Chaos resolves into peace and understanding
            - Isolation transforms into connection and belonging
            - The dreamer discovers inner strength they didn't know they had

            NARRATIVE STRUCTURE:
            1. Opening: Establish the transformed scene with beautiful imagery
            2. Development: Show the dreamer navigating with confidence
            3. Transformation: The pivotal moment where darkness becomes light
            4. Resolution: Emotional fulfillment and lasting peace
            """
        )

        let toneGuidance = getToneGuidance(tone)

        let prompt = """
        Transform this dream into a beautifully written \(tone) story.

        TONE: \(toneGuidance)

        WRITING REQUIREMENTS:
        1. First-person perspective ("I") throughout - the dreamer is the protagonist
        2. 4-6 paragraphs of polished, literary prose
        3. Open with an evocative, atmospheric description
        4. Include at least 3 specific sensory details (sight, sound, touch, smell, taste)
        5. Show emotional transformation through the narrative arc
        6. End with a powerful, resonant conclusion that leaves the reader feeling peaceful

        STYLE NOTES:
        - Write like a published author, not a summary
        - Vary your sentence lengths and structures
        - Use specific, concrete details rather than vague descriptions
        - Make the transformation feel earned and natural, not forced

        ORIGINAL DREAM TO TRANSFORM:
        \(original)

        Now write the transformed dream as a beautiful, healing story:
        """

        let response = try await session.respond(to: prompt)
        let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

        if content.isEmpty {
            throw AIServiceError.emptyResponse
        }

        return content
    }

    // MARK: - Foundation Models Implementation

    /// Get tone-specific writing guidance
    private func getToneGuidance(_ tone: String) -> String {
        switch tone.lowercased() {
        case "happy":
            return "Radiant joy and pure delight. The world is vibrant and alive with color. Unexpected pleasures unfold at every turn. Laughter bubbles up naturally. There's a sense of celebration, of everything clicking into place perfectly. The atmosphere feels like sunshine after rain."
        case "funny":
            return "Playful absurdity and gentle humor. Scary things become hilariously incompetent or endearingly silly. There's witty internal monologue and comedic timing. The dreamer finds themselves chuckling at the absurdity. Transform tension into laughter, danger into slapstick. The mood is light, playful, and delightfully unexpected."
        case "hopeful":
            return "Dawn breaking after a long night. Darkness gradually surrendering to warm, golden light. Every obstacle reveals a hidden path forward. Seeds of possibility are everywhere. There's a profound sense that beautiful things are coming, that the best is yet to unfold. The future feels bright and full of promise."
        case "calm":
            return "Deep serenity and tranquil peace. Slow, gentle rhythms like breathing. Soft light, quiet sounds, comforting textures. Time moves unhurried. There's a sanctuary-like quality - safe, warm, protected. The dreamer feels held by something greater, completely at ease. Stillness that nourishes the soul."
        case "positive":
            return "Empowerment and personal triumph. The dreamer discovers strength they never knew they had. Challenges become opportunities for growth. Fear transforms into courage, weakness into resilience. There's a sense of capability, of rising to meet whatever comes. The dreamer emerges changed, stronger, more confident."
        default:
            return "Create a peaceful, uplifting narrative that brings comfort and emotional safety."
        }
    }

    // MARK: - Comic Book Scene Generation

    /// Generate comic-book style scene descriptions for image generation
    /// Panel count is determined automatically based on story complexity (1-4 panels)
    func generateComicScenes(from storyText: String) async throws -> [String] {
        if #available(iOS 26.0, *), Self.isOnDeviceAvailable {
            return try await generateScenesWithFoundationModels(from: storyText)
        } else {
            throw AIServiceError.notSupported
        }
    }

    /// Legacy method for backward compatibility
    func generateComicScenes(from storyText: String, numberOfScenes: Int) async throws -> [String] {
        // Ignore numberOfScenes - AI decides based on story complexity
        return try await generateComicScenes(from: storyText)
    }

    @available(iOS 26.0, *)
    private func generateScenesWithFoundationModels(from storyText: String) async throws -> [String] {
        // Step 1: Preprocess the story to remove first-person and names
        let sanitizedStory = preprocessStoryForImageGeneration(storyText)

        let session = LanguageModelSession(
            instructions: """
            You are an AI that generates MLX image prompts
            for a dream-to-comic application.

            Your job is to convert the story into
            flat graphic comic panels.

            PANEL COUNT DECISION:
            - very simple story → 1 panel
            - short story with progression → 2 panels
            - full narrative arc → 3-4 panels

            PROMPT WRITING RULES:
            - Think like a graphic designer, not an illustrator.
            - Use simple objects, simple actions.
            - Describe only what can be clearly drawn.
            - No poetic language.
            - No long sentences.
            - No metaphors.
            - Focus on: subject + action + environment.

            REQUIRED STYLE (include in EVERY prompt):
            flat vector comic panel, graphic design style,
            thick black vector outlines, simple geometric shapes,
            two-dimensional, no depth, no shading,
            solid flat colors only,
            high contrast color blocks,
            clean poster-like composition,
            bold centered subject,
            minimal background,
            symbolic silhouette characters,
            comic sound effect text,
            screen print look,
            no gradients, no lighting, no texture,
            no realism, no 3D, no photorealism

            OUTPUT FORMAT (JSON ONLY):
            {
              "panelCount": number,
              "panels": [
                {
                  "panel": 1,
                  "storyPart": "which part of story",
                  "prompt": "simple prompt with style"
                }
              ]
            }

            OUTPUT RULES:
            - Output only valid JSON.
            - No explanations.
            - Each prompt: subject + action + style keywords.
            - Keep prompts SHORT and CONCRETE.
            """
        )

        let prompt = """
        Convert this dream story into flat vector comic panels.

        STORY:
        "\(sanitizedStory)"

        For each panel, write a SHORT prompt:
        - What subject? (silhouette, shape, object)
        - What action? (running, flying, standing)
        - What environment? (forest, sky, room)
        - Add the required style keywords.

        Output valid JSON only:
        """

        let response = try await session.respond(to: prompt)

        // Step 2: Parse JSON response with new format
        let scenes = parseVisualDirectorResponse(response.content)

        // Step 3: Post-process scenes to ensure no banned content
        return scenes.map { sanitizeScenePrompt($0) }
    }

    /// Parse the visual director JSON response
    private func parseVisualDirectorResponse(_ response: String) -> [String] {
        var jsonString = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code blocks if present
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        } else if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to parse as JSON
        if let data = jsonString.data(using: .utf8) {
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let panels = json["panels"] as? [[String: Any]] {
                    var prompts: [String] = []
                    for panel in panels {
                        if let prompt = panel["prompt"] as? String {
                            prompts.append(prompt)
                        }
                    }
                    if !prompts.isEmpty {
                        let panelCount = json["panelCount"] as? Int ?? prompts.count
                        print("Visual Director: Generated \(panelCount) panels from story")
                        for (i, panel) in panels.enumerated() {
                            if let storyPart = panel["storyPart"] as? String {
                                print("  Panel \(i + 1) [\(storyPart)]")
                            }
                        }
                        return prompts
                    }
                }
            } catch {
                print("JSON parsing failed: \(error)")
            }
        }

        // Fallback: try legacy parsing
        print("Falling back to legacy parsing")
        return parseComicJSONResponse(response, expectedPanels: 3)
    }

    /// Parse the comic book JSON response from Foundation Models
    private func parseComicJSONResponse(_ response: String, expectedPanels: Int) -> [String] {
        // Try to extract JSON from the response
        var jsonString = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code blocks if present
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        } else if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to parse as JSON
        if let data = jsonString.data(using: .utf8) {
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let panels = json["panels"] as? [[String: Any]] {
                    var prompts: [String] = []
                    for panel in panels {
                        if let prompt = panel["prompt"] as? String {
                            prompts.append(prompt)
                        }
                    }
                    if !prompts.isEmpty {
                        print("Successfully parsed \(prompts.count) comic panels from JSON")
                        return prompts
                    }
                }
            } catch {
                print("JSON parsing failed: \(error)")
            }
        }

        // Fallback: try to extract prompts using regex
        print("Falling back to regex parsing")
        return parseSceneResponse(response)
    }

    /// Preprocess story text to remove first-person pronouns and convert to scene descriptions
    private func preprocessStoryForImageGeneration(_ text: String) -> String {
        var result = text

        // Replace first-person pronouns with neutral scene descriptions
        let replacements: [(pattern: String, replacement: String)] = [
            ("\\bI was\\b", "The scene was"),
            ("\\bI am\\b", "The moment is"),
            ("\\bI felt\\b", "There was a feeling of"),
            ("\\bI see\\b", "Visible in the scene"),
            ("\\bI saw\\b", "Appearing in view"),
            ("\\bI walked\\b", "A path led through"),
            ("\\bI ran\\b", "Motion swept across"),
            ("\\bI flew\\b", "Soaring through"),
            ("\\bI found\\b", "Discovered within"),
            ("\\bI noticed\\b", "Revealed in the light"),
            ("\\bI heard\\b", "Sounds echoed through"),
            ("\\bI\\b", ""),
            ("\\bme\\b", ""),
            ("\\bmy\\b", "the"),
            ("\\bmine\\b", ""),
            ("\\bmyself\\b", ""),
            ("\\bwe\\b", ""),
            ("\\bus\\b", ""),
            ("\\bour\\b", "the")
        ]

        for (pattern, replacement) in replacements {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: replacement
                )
            }
        }

        return result
    }

    /// Post-process a scene prompt to remove any remaining first-person or problematic content
    private func sanitizeScenePrompt(_ scene: String) -> String {
        var result = scene

        // Step 1: Remove any first-person pronouns completely
        let firstPersonReplacements: [(pattern: String, replacement: String)] = [
            ("\\bI am\\b", ""),
            ("\\bI was\\b", ""),
            ("\\bI have\\b", ""),
            ("\\bI had\\b", ""),
            ("\\bI feel\\b", ""),
            ("\\bI felt\\b", ""),
            ("\\bI see\\b", ""),
            ("\\bI saw\\b", ""),
            ("\\bI walk\\b", ""),
            ("\\bI walked\\b", ""),
            ("\\bI run\\b", ""),
            ("\\bI ran\\b", ""),
            ("\\bI stand\\b", ""),
            ("\\bI stood\\b", ""),
            ("\\bI look\\b", ""),
            ("\\bI looked\\b", ""),
            ("\\bI find\\b", ""),
            ("\\bI found\\b", ""),
            ("\\bI know\\b", ""),
            ("\\bI knew\\b", ""),
            ("\\bI think\\b", ""),
            ("\\bI thought\\b", ""),
            ("\\bI want\\b", ""),
            ("\\bI wanted\\b", ""),
            ("\\bI need\\b", ""),
            ("\\bI needed\\b", ""),
            ("\\bI can\\b", ""),
            ("\\bI could\\b", ""),
            ("\\bI will\\b", ""),
            ("\\bI would\\b", ""),
            ("\\bI'm\\b", ""),
            ("\\bI've\\b", ""),
            ("\\bI'd\\b", ""),
            ("\\bI'll\\b", ""),
            ("\\bmy own\\b", ""),
            ("\\bmy\\b", "the"),
            ("\\bmine\\b", ""),
            ("\\bmyself\\b", ""),
            ("\\bme\\b", ""),
            ("\\bI\\b", ""),
            ("\\bwe are\\b", ""),
            ("\\bwe were\\b", ""),
            ("\\bwe have\\b", ""),
            ("\\bwe had\\b", ""),
            ("\\bwe're\\b", ""),
            ("\\bwe've\\b", ""),
            ("\\bwe'll\\b", ""),
            ("\\bwe'd\\b", ""),
            ("\\bour\\b", "the"),
            ("\\bours\\b", ""),
            ("\\bourselves\\b", ""),
            ("\\bus\\b", ""),
            ("\\bwe\\b", "")
        ]

        for (pattern, replacement) in firstPersonReplacements {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: replacement
                )
            }
        }

        // Step 2: Remove human-related words completely
        let humanPatterns = [
            "\\bman\\b", "\\bwoman\\b", "\\bperson\\b", "\\bpeople\\b",
            "\\bboy\\b", "\\bgirl\\b", "\\bchild\\b", "\\bchildren\\b",
            "\\bhuman\\b", "\\bhumans\\b", "\\bface\\b", "\\bfaces\\b",
            "\\bhand\\b", "\\bhands\\b", "\\bbody\\b", "\\bbodies\\b",
            "\\bfinger\\b", "\\bfingers\\b", "\\barm\\b", "\\barms\\b",
            "\\bleg\\b", "\\blegs\\b", "\\bhead\\b", "\\bheads\\b",
            "\\bmother\\b", "\\bfather\\b", "\\bparent\\b", "\\bparents\\b",
            "\\bmom\\b", "\\bdad\\b", "\\bbrother\\b", "\\bsister\\b",
            "\\bfriend\\b", "\\bfriends\\b", "\\bfamily\\b", "\\bfamilies\\b",
            "\\bsomeone\\b", "\\banyone\\b", "\\beveryone\\b", "\\bnobody\\b",
            "\\bsomebody\\b", "\\banybody\\b", "\\beverybody\\b"
        ]

        for pattern in humanPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: ""
                )
            }
        }

        // Step 3: Remove common names (capitalized words that might be names)
        // We'll be conservative and only remove very common names
        let commonNames = [
            "\\bJohn\\b", "\\bSarah\\b", "\\bMike\\b", "\\bMary\\b", "\\bDavid\\b",
            "\\bEmma\\b", "\\bJames\\b", "\\bLisa\\b", "\\bTom\\b", "\\bAnn\\b",
            "\\bBob\\b", "\\bJane\\b", "\\bMom\\b", "\\bDad\\b", "\\bMommy\\b",
            "\\bDaddy\\b", "\\bGrandma\\b", "\\bGrandpa\\b", "\\bNana\\b", "\\bPapa\\b"
        ]

        for pattern in commonNames {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: ""
                )
            }
        }

        // Step 4: Clean up artifacts (double spaces, orphaned punctuation)
        result = result.replacingOccurrences(of: "  ", with: " ")
        result = result.replacingOccurrences(of: " ,", with: ",")
        result = result.replacingOccurrences(of: " .", with: ".")
        result = result.replacingOccurrences(of: ",,", with: ",")
        result = result.replacingOccurrences(of: "..", with: ".")
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // Step 5: Final validation - if any banned words remain, use fallback
        if containsBannedContent(result) {
            return createFallbackPrompt(from: result)
        }

        return result
    }

    /// Check if text contains any banned content that would cause Image Playground to fail
    private func containsBannedContent(_ text: String) -> Bool {
        let lowercased = text.lowercased()

        // Allow silhouette-based symbolic characters
        let allowedSilhouetteTerms = ["dreamer silhouette", "shadow silhouette", "monster silhouette",
                                       "child silhouette", "stranger silhouette", "silhouette shape",
                                       "shadow shape", "shadowy form", "dark silhouette"]

        // Check if this is a valid silhouette-based prompt
        var hasSilhouetteContext = false
        for term in allowedSilhouetteTerms {
            if lowercased.contains(term) {
                hasSilhouetteContext = true
                break
            }
        }

        // Banned words that would trigger Image Playground errors
        let bannedWords = [
            " i ", " me ", " my ", " we ", " us ", " our ",
            "person", "people", "human", "man ", "woman", "boy ", "girl ",
            "face ", "hand ", "body", "head ", "eye ", "arm ", "leg ",
            "character", "figure", "hero", "protagonist",
            " he ", " she ", " him ", " her ", " his ", " they ", " them ", " their "
        ]

        // If prompt has silhouette context, skip checking for "child" (since "Child silhouette" is OK)
        let conditionalBanned = hasSilhouetteContext ? [] : ["child"]

        for word in bannedWords + conditionalBanned {
            if lowercased.contains(word) {
                return true
            }
        }

        // Check for standalone "I" at word boundaries
        if let regex = try? NSRegularExpression(pattern: "\\bI\\b", options: []) {
            let range = NSRange(text.startIndex..., in: text)
            if regex.firstMatch(in: text, options: [], range: range) != nil {
                return true
            }
        }

        return false
    }

    /// Create a safe fallback prompt when sanitization fails
    private func createFallbackPrompt(from text: String) -> String {
        let vectorStyle = "flat vector comic panel, graphic design style, thick black vector outlines, simple geometric shapes, two-dimensional, no depth, no shading, solid flat colors only, high contrast color blocks, clean poster-like composition, bold centered subject, minimal background, symbolic silhouette characters, screen print look"

        // Extract key visual elements only
        let keywords = extractVisualKeywords(from: text)

        // Flat vector style fallback prompts
        let fallbacks = [
            "Silhouette figure with arms raised, SMASH! text, yellow orange background, \(vectorStyle)",
            "Dark shadow shape, lightning bolt, purple blue color blocks, \(vectorStyle)",
            "Explosion circle, BOOM! text, red orange shapes, \(vectorStyle)",
            "Standing figure with cape, POW! text, gold blue background, \(vectorStyle)"
        ]

        if keywords.isEmpty {
            return fallbacks[Int.random(in: 0..<fallbacks.count)]
        }

        // Use vector style with extracted keywords
        return "Silhouette showing \(keywords.joined(separator: ", ")), \(vectorStyle)"
    }

    /// Extract only safe visual keywords from text
    private func extractVisualKeywords(from text: String) -> [String] {
        let lowercased = text.lowercased()
        var keywords: [String] = []

        let safeVisualWords: [String: String] = [
            "forest": "mystical forest",
            "tree": "ancient trees",
            "garden": "blooming garden",
            "flower": "colorful flowers",
            "ocean": "vast ocean",
            "sea": "calm sea",
            "beach": "sandy beach",
            "mountain": "majestic mountains",
            "sky": "expansive sky",
            "cloud": "fluffy clouds",
            "star": "twinkling stars",
            "moon": "glowing moon",
            "sun": "warm sunlight",
            "river": "flowing river",
            "lake": "serene lake",
            "waterfall": "cascading waterfall",
            "meadow": "peaceful meadow",
            "castle": "grand castle",
            "path": "winding path",
            "light": "ethereal light",
            "magic": "magical sparkles",
            "glow": "soft glow",
            "crystal": "glittering crystals",
            "rainbow": "vibrant rainbow"
        ]

        for (keyword, scenic) in safeVisualWords {
            if lowercased.contains(keyword) && !keywords.contains(scenic) {
                keywords.append(scenic)
                if keywords.count >= 4 {
                    break
                }
            }
        }

        return keywords
    }

    private func createScenePrompt(storyText: String, numberOfScenes: Int) -> String {
        let panelDescriptions = getPanelStructure(numberOfScenes)

        return """
        Create exactly \(numberOfScenes) simple image prompts for dreamy artwork.

        STORY THEME (use as inspiration only):
        "\(storyText)"

        ⚠️ CRITICAL RULES - MUST FOLLOW EXACTLY:
        - NEVER use: I, me, my, mine, myself, we, us, our, ours
        - NEVER use: person, people, man, woman, boy, girl, child, human
        - NEVER use: face, hand, hands, body, head, arm, leg
        - NEVER use names like John, Sarah, Mom, Dad
        - ONLY describe animals and nature scenes
        - Use THIRD-PERSON descriptions only

        HERO CHARACTER (use the SAME one in ALL scenes):
        Choose ONE: orange tabby cat, silver owl, red fox, golden wolf, white rabbit

        PANEL FLOW:
        \(panelDescriptions)

        FORMAT: Write simple, clear descriptions. Each prompt should be 1-2 sentences maximum.

        EXAMPLE PROMPTS:
        1. An orange tabby cat stands at the edge of a misty forest, golden morning light filtering through tall trees, magical fireflies glowing
        2. The orange cat leaps across mossy stones over a sparkling stream, water droplets catching sunlight, lush ferns on both banks
        3. The cat rests peacefully under a blooming cherry tree, pink petals falling gently, soft sunset colors in the sky
        4. The orange cat and a silver owl sit together on a hilltop, overlooking a beautiful valley, rainbow arcing across the horizon

        Now write \(numberOfScenes) simple scene descriptions:
        """
    }

    /// Get panel structure description based on number of scenes
    private func getPanelStructure(_ count: Int) -> String {
        switch count {
        case 2:
            return """
            Panel 1 (SETUP): Wide establishing shot - introduce hero and world, hint at journey ahead
            Panel 2 (RESOLUTION): Triumphant/peaceful ending - show transformation, journey complete
            """
        case 3:
            return """
            Panel 1 (SETUP): Wide establishing shot - introduce hero in their world
            Panel 2 (JOURNEY): Action/challenge - hero faces obstacle or makes discovery
            Panel 3 (RESOLUTION): Peaceful ending - transformation complete, new understanding
            """
        case 4:
            return """
            Panel 1 (HOOK): Dramatic opening - hero at threshold of adventure
            Panel 2 (RISING): Challenge emerges - hero takes action, faces obstacle
            Panel 3 (CLIMAX): Turning point - confrontation or revelation, most dramatic moment
            Panel 4 (RESOLUTION): Peace achieved - hero transformed, world beautiful
            """
        case 6:
            return """
            Panel 1 (OPENING): Atmospheric wide shot - establish world and mood
            Panel 2 (INTRODUCTION): Hero revealed - show character and personality
            Panel 3 (INCITING): Challenge appears - something changes, journey begins
            Panel 4 (RISING ACTION): Hero struggles - faces obstacles, shows courage
            Panel 5 (CLIMAX): Peak moment - biggest challenge or revelation
            Panel 6 (RESOLUTION): New dawn - peace, transformation, beauty
            """
        default:
            return """
            Panel 1: Establishing shot - set the scene
            Panels 2-\(count-1): Journey and challenges
            Panel \(count): Resolution and peace
            """
        }
    }

    private func parseSceneResponse(_ response: String) -> [String] {
        var scenes: [String] = []

        // Parse numbered list format (1. scene, 2. scene, etc.)
        let lines = response.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Match patterns like "1.", "1)", "1:", "Scene 1:", etc.
            let patterns = [
                "^\\d+\\.\\s*(.+)$",      // 1. description
                "^\\d+\\)\\s*(.+)$",      // 1) description
                "^\\d+:\\s*(.+)$",        // 1: description
                "^Scene\\s*\\d+[:.)]?\\s*(.+)$"  // Scene 1: description
            ]

            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)),
                   let range = Range(match.range(at: 1), in: trimmed) {
                    let scene = String(trimmed[range]).trimmingCharacters(in: .whitespaces)
                    if !scene.isEmpty {
                        scenes.append(scene)
                        break
                    }
                }
            }
        }

        // If parsing failed, try to split by double newlines
        if scenes.isEmpty {
            scenes = response.components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        return scenes
    }
}

