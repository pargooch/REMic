# REMic

A therapeutic iOS app for dream journaling and nightmare rewriting using AI-powered Imagery Rehearsal Therapy (IRT).

## Overview

REMic helps users process nightmares by rewriting them into calming, positive versions. The app uses AI (via OpenRouter/xAI Grok) to transform distressing dream content into emotionally safe narratives, following evidence-based IRT principles used in PTSD treatment.

## Features

### Core Features
- **Dream Journaling** - Record and store your dreams
- **AI Nightmare Rewriting** - Transform nightmares using therapeutic rewriting with selectable tones (happy, funny, hopeful, calm, positive)
- **Editable Rewrites** - Manually edit AI-generated rewrites to personalize them
- **Data Persistence** - Dreams are saved locally and persist between app launches

### Dream Visualization
- **Dual Provider Support** - Uses Apple Image Playground (iOS 18.4+) or OpenAI DALL-E 3 as fallback
- **Multiple Styles** - Choose from Animation (3D), Illustration (2D flat), or Sketch styles
- **Sequence Generation** - Create 2-6 images representing different scenes from your dream
- **Image Gallery** - View generated images in a swipeable gallery with thumbnails
- **Regeneration** - Generate new images with different styles at any time
- **On-Device Option** - Apple Image Playground runs entirely on-device (free, private)

> **Note**: Requires either iOS 18.4+ with Apple Intelligence, or an OpenAI API key.

### Notification System
- **Global Notification Settings** - Configure 4 notification types independently:
  - Daily Check-in: Reminders to log dreams
  - Dream Reflection: Prompts to revisit past dreams
  - Nightmare Follow-up: Check-ins after rewriting nightmares
  - Weekly Digest: Weekly dream journey summaries
- **Flexible Scheduling** - Daily, weekdays, weekends, weekly, or custom day selection
- **Per-Dream Reminders** - Set individual reminders for specific dreams
- **Multiple Reminders** - Add unlimited reminders per dream with different types and times

## Architecture

### Tech Stack
- **UI Framework**: SwiftUI
- **Minimum iOS**: 17.0+ (18.4+ for Apple Image Playground)
- **AI Text Provider**: OpenRouter API (xAI Grok 4 Fast)
- **AI Image Provider**: Apple Image Playground (on-device) or OpenAI DALL-E 3 (cloud)
- **Local Storage**: JSON file persistence
- **Notifications**: UserNotifications framework

### Project Structure

```
REMic/
├── REMicApp.swift         # App entry point & notification delegate
├── ContentView.swift             # Main dream list view
├── DreamDetailView.swift         # Dream detail, rewrite, edit, images & reminders
├── NewDreamView.swift            # New dream entry form
├── Dream.swift                   # Dream data model
├── DreamStore.swift              # Dream persistence & state management
├── AIService.swift               # OpenRouter API integration
├── ImageGenerationService.swift  # Image generation (Apple Image Playground + DALL-E)
├── Config.swift                  # API key configuration
├── NotificationModels.swift      # Notification data models
├── NotificationManager.swift     # Notification scheduling service
├── NotificationSettingsView.swift # Global notification settings UI
├── Info.plist                    # App configuration (gitignored)
├── Secrets.plist                 # API keys (gitignored)
└── Secrets.plist.example         # API key template
```

## Setup

### Prerequisites
- Xcode 15.0+
- iOS 17.0+ device or simulator
- OpenRouter API key (for AI text rewriting)
- OpenAI API key (optional, for DALL-E image generation)

### Installation

1. Clone the repository
2. Copy `Secrets.plist.example` to `Secrets.plist`
3. Add your API keys to `Secrets.plist`:
   ```xml
   <key>OPENROUTER_API_KEY</key>
   <string>sk-or-v1-your-key-here</string>
   <key>OPENAI_API_KEY</key>
   <string>sk-your-openai-key-here</string>
   ```
4. Open `REMic.xcodeproj` in Xcode
5. Add `Secrets.plist` to the project target (ensure it's included in "Copy Bundle Resources")
6. Build and run

> **Note**: The OpenAI API key is optional. Without it, dream visualization features will be disabled.

### Getting API Keys

**OpenRouter (Required for AI text rewriting):**
1. Visit [openrouter.ai](https://openrouter.ai)
2. Create an account
3. Navigate to [openrouter.ai/keys](https://openrouter.ai/keys)
4. Generate a new API key
5. Add credits to your account

**OpenAI (Optional, for DALL-E image generation):**
1. Visit [platform.openai.com](https://platform.openai.com)
2. Create an account or sign in
3. Navigate to [platform.openai.com/api-keys](https://platform.openai.com/api-keys)
4. Create a new secret key
5. Add credits to your account (DALL-E 3 costs ~$0.04-0.08 per image)

## Configuration

### API Key Sources (Priority Order)

**OpenRouter (text rewriting):**
1. Environment variable: `OPENROUTER_API_KEY`
2. `Secrets.plist` file (recommended for development)
3. `Info.plist` (fallback)

**OpenAI (image generation - optional):**
1. Environment variable: `OPENAI_API_KEY`
2. `Secrets.plist` file (recommended for development)
3. `Info.plist` (fallback)

### AI Model
Currently configured to use `x-ai/grok-4-fast` via OpenRouter. To change the model, edit `AIService.swift`:
```swift
"model": "x-ai/grok-4-fast"
```

## Usage

### Recording a Dream
1. Tap `+` on the main screen
2. Enter your dream description
3. Tap "Save"

### Rewriting a Nightmare
1. Select a dream from the list
2. Choose a tone (happy, funny, hopeful, calm, positive)
3. Tap "Rewrite with AI"
4. Wait for the AI to generate a peaceful version
5. Optionally edit the result by tapping "Edit"

### Setting Reminders
1. In a dream's detail view, scroll to "Reminders"
2. Tap `+` to add a new reminder
3. Select reminder type and timing
4. Tap "Add"

### Configuring Notifications
1. Tap the gear icon on the main screen
2. Enable notifications if prompted
3. Toggle individual notification types on/off
4. Tap on a notification type to configure its schedule

### Generating Dream Images
1. First, rewrite a dream using AI
2. Scroll to "Dream Visualization" section
3. Choose an image style (Animation, Illustration, or Sketch)
4. Select number of scenes (2-6)
5. Tap "Generate Dream Sequence"
6. View images in the gallery by tapping "View"

**Provider Priority:**
- **iOS 18.4+**: Uses Apple Image Playground (free, on-device, private)
- **iOS 17.0-18.3**: Uses OpenAI DALL-E 3 (requires API key, ~$0.04-0.08/image)

## Data Storage

- **Dreams**: Stored in `documents/dreams.json`
- **Generated Images**: Stored as PNG data within dream records
- **Notification Settings**: Stored in UserDefaults
- **No Cloud Sync**: All data is local to the device

## Security

- API keys are stored in `Secrets.plist` (gitignored)
- `.gitignore` prevents committing sensitive files
- No user data is sent to external servers except dream text for AI processing

---

## Milestones

### Phase 1: Core Functionality
- [x] Dream data model
- [x] Dream list view (ContentView)
- [x] New dream entry (NewDreamView)
- [x] Dream detail view
- [x] Local data persistence (JSON file storage)
- [x] Delete dreams with swipe

### Phase 2: AI Integration
- [x] OpenRouter API integration
- [x] AI nightmare rewriting
- [x] Tone selection (happy, funny, hopeful, calm, positive)
- [x] Error handling with descriptive messages
- [x] Request cancellation support
- [x] Retry mechanism for failed requests
- [x] Loading states and progress indicators

### Phase 3: Content Editing
- [x] Edit rewritten dream content
- [x] Dynamic TextEditor sizing
- [x] Save/cancel editing
- [x] Re-rewrite with different tones

### Phase 4: Notification System
- [x] Notification permission handling
- [x] Global notification settings view
- [x] 4 notification categories (Daily, Reflection, Follow-up, Weekly)
- [x] Notification templates with message variety
- [x] Flexible scheduling (daily, weekdays, weekends, weekly, custom)
- [x] Time picker for notifications
- [x] Custom day selection
- [x] Per-dream notification management
- [x] Multiple reminders per dream
- [x] Reminder type selection
- [x] Custom date/time for reminders
- [x] Delete individual reminders
- [x] Expired reminder detection
- [x] Relative time display ("in 2 hours")

### Phase 5: User Experience
- [x] Settings access from main screen
- [x] Sparkles indicator for rewritten dreams
- [x] Consistent UI styling
- [ ] Onboarding flow for new users
- [ ] Dark mode optimization
- [ ] Haptic feedback
- [ ] Accessibility improvements (VoiceOver, Dynamic Type)

### Phase 6: Enhanced Features
- [ ] Dream categories/tags
- [ ] Search and filter dreams
- [ ] Dream statistics and insights
- [ ] Export dreams (PDF, text)
- [ ] Dream sharing
- [ ] Multiple AI model options
- [ ] Offline mode with queued rewrites

### Phase 7: Advanced Therapy Features
- [ ] Guided IRT exercises
- [ ] Progress tracking over time
- [ ] Mood tracking before/after rewrite
- [ ] Therapist notes section
- [ ] Audio dream recording
- [x] Dream visualization/illustration generation (OpenAI DALL-E 3)

### Phase 8: Platform & Sync
- [ ] iCloud sync
- [ ] iPad optimization
- [ ] macOS Catalyst support
- [ ] Apple Watch companion app
- [ ] Widgets for quick dream entry
- [ ] Siri Shortcuts integration

### Phase 9: Monetization & Distribution
- [ ] App Store assets (screenshots, description)
- [ ] Privacy policy
- [ ] Terms of service
- [ ] In-app purchases or subscription
- [ ] TestFlight beta
- [ ] App Store submission

---

## API Reference

### AIService

```swift
class AIService {
    func cancel()
    func rewriteDream(
        original: String,
        tone: String,
        completion: @escaping (Result<String, AIServiceError>) -> Void
    )
}
```

### AIServiceError

| Error | Description |
|-------|-------------|
| `.networkError` | Network connectivity issue |
| `.invalidAPIKey` | 401 Unauthorized |
| `.rateLimited` | 429 Too Many Requests |
| `.serverError` | 5xx Server Error |
| `.invalidResponse` | Malformed API response |
| `.emptyResponse` | AI returned empty content |
| `.apiError` | API-specific error message |
| `.cancelled` | Request was cancelled |

### NotificationManager

```swift
class NotificationManager: ObservableObject {
    static let shared: NotificationManager

    @Published var isAuthorized: Bool
    @Published var templates: [NotificationTemplate]
    @Published var settings: [NotificationSettings]
    @Published var dreamNotifications: [DreamNotification]

    func requestAuthorization() async -> Bool
    func updateSettings(for category: NotificationCategory, ...)
    func scheduleDreamNotification(for dream: Dream, afterHours: Int)
    func cancelDreamNotification(for dreamId: UUID)
}
```

### ImageGenerationService

```swift
@MainActor
class ImageGenerationService: ObservableObject {
    static var isAvailable: Bool  // Check if any provider is available
    static var availableProvider: ImageGenerationProvider  // Which provider will be used

    @Published var isGenerating: Bool
    @Published var progress: Double
    @Published var generatedImages: [GeneratedDreamImage]

    func generateSequenceImages(
        from text: String,
        style: DreamImageStyle,
        numberOfImages: Int
    ) async throws -> [GeneratedDreamImage]

    func generateSingleImage(
        prompt: String,
        style: DreamImageStyle
    ) async throws -> GeneratedDreamImage

    func cancel()
}

enum ImageGenerationProvider {
    case appleImagePlayground  // iOS 18.4+ with Apple Intelligence
    case openAIDALLE           // Requires OpenAI API key
    case none                  // No provider available
}
```

### DreamImageStyle

| Style | Description |
|-------|-------------|
| `.animation` | 3D animated movie style |
| `.illustration` | Flat 2D illustration |
| `.sketch` | Hand-drawn sketch |

### ImageGenerationError

| Error | Description |
|-------|-------------|
| `.notSupported` | No provider available (needs iOS 18.4+ or OpenAI key) |
| `.unavailable` | Service temporarily unavailable |
| `.cancelled` | Generation was cancelled |
| `.unsupportedLanguage` | Text language not supported (Image Playground) |
| `.invalidAPIKey` | Invalid OpenAI API key (DALL-E) |
| `.rateLimited` | Too many requests (DALL-E) |
| `.serverError` | Server error (DALL-E) |
| `.invalidResponse` | Malformed API response (DALL-E) |
| `.creationFailed` | General creation failure |
| `.noImagesGenerated` | No images were produced |

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Ensure no API keys are committed
5. Submit a pull request

## License

[Add your license here]

## Acknowledgments

- Imagery Rehearsal Therapy (IRT) research
- OpenRouter for AI API access
- xAI for Grok model
