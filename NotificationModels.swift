import Foundation

// MARK: - Notification Template

enum NotificationCategory: String, Codable, CaseIterable, Identifiable {
    case generalReminder = "general_reminder"
    case dreamReflection = "dream_reflection"
    case nightmareFollowUp = "nightmare_followup"
    case weeklyDigest = "weekly_digest"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .generalReminder: return L("Daily Check-in")
        case .dreamReflection: return L("Dream Reflection")
        case .nightmareFollowUp: return L("Nightmare Follow-up")
        case .weeklyDigest: return L("Weekly Digest")
        }
    }

    var description: String {
        switch self {
        case .generalReminder:
            return L("Gentle reminder to log your dreams")
        case .dreamReflection:
            return L("Reflect on dreams you've recorded")
        case .nightmareFollowUp:
            return L("Check in after rewriting a nightmare")
        case .weeklyDigest:
            return L("Weekly summary of your dream journey")
        }
    }

    var icon: String {
        switch self {
        case .generalReminder: return "bell.fill"
        case .dreamReflection: return "sparkles"
        case .nightmareFollowUp: return "heart.fill"
        case .weeklyDigest: return "calendar"
        }
    }
}

struct NotificationTemplate: Identifiable, Codable {
    let id: UUID
    let category: NotificationCategory
    var titleOptions: [String]
    var bodyOptions: [String]

    init(category: NotificationCategory, titleOptions: [String], bodyOptions: [String]) {
        self.id = UUID()
        self.category = category
        self.titleOptions = titleOptions
        self.bodyOptions = bodyOptions
    }

    func randomTitle() -> String {
        titleOptions.randomElement() ?? "REMic"
    }

    func randomBody() -> String {
        bodyOptions.randomElement() ?? "Time to check your dreams"
    }

    // Default templates
    static let defaults: [NotificationTemplate] = [
        NotificationTemplate(
            category: .generalReminder,
            titleOptions: [
                "Good morning!",
                "Dream Journal Time",
                "Remember Your Dreams?",
                "Start Your Day Mindfully"
            ],
            bodyOptions: [
                "Did you dream last night? Take a moment to record it.",
                "Your dreams are waiting to be captured.",
                "A few minutes to log your dreams can make a big difference.",
                "Dreams fade quickly - save yours now."
            ]
        ),
        NotificationTemplate(
            category: .dreamReflection,
            titleOptions: [
                "Time to Reflect",
                "Dream Insight",
                "Look Back",
                "Your Dream Journey"
            ],
            bodyOptions: [
                "Revisit a dream you recorded and see how it makes you feel now.",
                "Your past dreams might hold insights for today.",
                "Take a moment to reflect on your dream patterns.",
                "What have your dreams been telling you lately?"
            ]
        ),
        NotificationTemplate(
            category: .nightmareFollowUp,
            titleOptions: [
                "How Are You Feeling?",
                "Gentle Check-in",
                "You're Doing Great",
                "Healing Journey"
            ],
            bodyOptions: [
                "How did the rewritten dream make you feel? Consider reading it again.",
                "Remember, you have the power to reshape your dreams.",
                "Take a moment to revisit your peaceful dream version.",
                "Your healing journey continues. We're here for you."
            ]
        ),
        NotificationTemplate(
            category: .weeklyDigest,
            titleOptions: [
                "Your Week in Dreams",
                "Weekly Reflection",
                "Dream Summary",
                "This Week's Journey"
            ],
            bodyOptions: [
                "See how your dream patterns evolved this week.",
                "Time for your weekly dream check-in.",
                "Reflect on your dream journey this week.",
                "A week of dreams - what stories did they tell?"
            ]
        )
    ]
}

// MARK: - Schedule Configuration

enum NotificationFrequency: String, Codable, CaseIterable, Identifiable {
    case daily = "daily"
    case weekdays = "weekdays"
    case weekends = "weekends"
    case weekly = "weekly"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: return L("Every Day")
        case .weekdays: return L("Weekdays Only")
        case .weekends: return L("Weekends Only")
        case .weekly: return L("Once a Week")
        case .custom: return L("Custom Days")
        }
    }
}

struct NotificationSchedule: Codable, Equatable {
    var frequency: NotificationFrequency
    var time: Date // Time of day for the notification
    var selectedDays: Set<Int> // 1 = Sunday, 7 = Saturday (for custom)
    var weeklyDay: Int // Day of week for weekly (1-7)

    init(
        frequency: NotificationFrequency = .daily,
        time: Date = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date(),
        selectedDays: Set<Int> = [],
        weeklyDay: Int = 2 // Monday
    ) {
        self.frequency = frequency
        self.time = time
        self.selectedDays = selectedDays
        self.weeklyDay = weeklyDay
    }

    // Get the days of week this schedule applies to
    var effectiveDays: Set<Int> {
        switch frequency {
        case .daily:
            return Set(1...7)
        case .weekdays:
            return Set(2...6) // Monday to Friday
        case .weekends:
            return Set([1, 7]) // Sunday and Saturday
        case .weekly:
            return Set([weeklyDay])
        case .custom:
            return selectedDays
        }
    }

    static let `default` = NotificationSchedule()
}

// MARK: - User Settings for Each Template

struct NotificationSettings: Identifiable, Codable {
    var id: UUID { templateId }
    let templateId: UUID
    let category: NotificationCategory
    var isEnabled: Bool
    var schedule: NotificationSchedule

    init(template: NotificationTemplate, isEnabled: Bool = false, schedule: NotificationSchedule = .default) {
        self.templateId = template.id
        self.category = template.category
        self.isEnabled = isEnabled
        self.schedule = schedule
    }
}

// MARK: - Dream-Specific Notification

struct DreamNotification: Identifiable, Codable, Equatable {
    let id: UUID
    let dreamId: UUID
    var scheduledDate: Date
    var isEnabled: Bool
    var notificationType: NotificationCategory

    init(dreamId: UUID, scheduledDate: Date, type: NotificationCategory = .nightmareFollowUp) {
        self.id = UUID()
        self.dreamId = dreamId
        self.scheduledDate = scheduledDate
        self.isEnabled = true
        self.notificationType = type
    }
}
