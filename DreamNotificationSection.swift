import SwiftUI
import UserNotifications

// MARK: - Dream Notification Section

struct DreamNotificationSection: View {
    let dreamId: UUID
    let hasRewrite: Bool

    @StateObject private var notificationManager = NotificationManager.shared
    @State private var showAddReminder = false
    @State private var reminders: [DreamNotification] = []

    var body: some View {
        ComicPanelCard(titleBanner: "Reminders", bannerColor: ComicTheme.Colors.emeraldGreen) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(ComicTheme.Colors.goldenYellow)

                    Spacer()

                    Button {
                        showAddReminder = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(ComicTheme.Colors.boldBlue)
                    }
                }

                if reminders.isEmpty {
                    VStack(spacing: 8) {
                        Text("No reminders set")
                            .font(ComicTheme.Typography.comicButton(14))
                            .foregroundColor(.secondary)
                        Text("Add a reminder to revisit this dream")
                            .font(ComicTheme.Typography.speechBubble(12))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else {
                    ForEach(reminders) { reminder in
                        DreamReminderRow(
                            reminder: reminder,
                            onDelete: { deleteReminder(reminder) }
                        )
                    }
                }
            }
        }
        .onAppear {
            loadReminders()
        }
        .onChange(of: notificationManager.dreamNotifications) {
            loadReminders()
        }
        .sheet(isPresented: $showAddReminder) {
            AddDreamReminderSheet(
                dreamId: dreamId,
                hasRewrite: hasRewrite,
                onAdd: { loadReminders() }
            )
        }
    }

    private func loadReminders() {
        reminders = notificationManager.dreamNotifications.filter { $0.dreamId == dreamId }
    }

    private func deleteReminder(_ reminder: DreamNotification) {
        notificationManager.dreamNotifications.removeAll { $0.id == reminder.id }
        notificationManager.saveDreamNotifications()
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["dream_\(reminder.id.uuidString)"]
        )
        loadReminders()
    }
}

// MARK: - Dream Reminder Row

struct DreamReminderRow: View {
    let reminder: DreamNotification
    let onDelete: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var isExpired: Bool {
        reminder.scheduledDate < Date()
    }

    private var timeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: reminder.scheduledDate, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: reminder.notificationType.icon)
                .foregroundColor(isExpired ? .secondary : ComicTheme.Colors.boldBlue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.notificationType.displayName)
                    .font(ComicTheme.Typography.comicButton(13))
                    .foregroundColor(isExpired ? .secondary : .primary)

                if isExpired {
                    Text("EXPIRED")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(ComicTheme.Colors.crimsonRed)
                } else {
                    Text(timeDescription)
                        .font(ComicTheme.Typography.speechBubble(12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .foregroundColor(ComicTheme.Colors.crimsonRed)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(ComicTheme.Semantic.cardSurface(colorScheme))
        .cornerRadius(ComicTheme.Dimensions.buttonCornerRadius)
    }
}

// MARK: - Add Dream Reminder Sheet

struct AddDreamReminderSheet: View {
    let dreamId: UUID
    let hasRewrite: Bool
    let onAdd: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationManager = NotificationManager.shared

    @State private var selectedType: NotificationCategory = .dreamReflection
    @State private var selectedTime: ReminderTime = .tomorrow

    enum ReminderTime: String, CaseIterable, Identifiable {
        case oneHour = "1 hour"
        case sixHours = "6 hours"
        case tomorrow = "Tomorrow"
        case twoDays = "2 days"
        case oneWeek = "1 week"
        case custom = "Custom"

        var id: String { rawValue }

        var hours: Int {
            switch self {
            case .oneHour: return 1
            case .sixHours: return 6
            case .tomorrow: return 24
            case .twoDays: return 48
            case .oneWeek: return 168
            case .custom: return 0
            }
        }
    }

    @State private var customDate = Date().addingTimeInterval(86400)

    private var availableTypes: [NotificationCategory] {
        if hasRewrite {
            return [.dreamReflection, .nightmareFollowUp]
        } else {
            return [.dreamReflection]
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    ForEach(availableTypes) { type in
                        Button {
                            selectedType = type
                        } label: {
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundColor(ComicTheme.Colors.boldBlue)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(type.displayName)
                                        .foregroundColor(.primary)
                                    Text(type.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if selectedType == type {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(ComicTheme.Colors.boldBlue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("REMINDER TYPE")
                        .font(ComicTheme.Typography.sectionHeader(11))
                        .tracking(1)
                }

                Section {
                    ForEach(ReminderTime.allCases) { time in
                        if time != .custom {
                            Button {
                                selectedTime = time
                            } label: {
                                HStack {
                                    Text(time.rawValue)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedTime == time {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(ComicTheme.Colors.boldBlue)
                                    }
                                }
                            }
                        }
                    }

                    Button {
                        selectedTime = .custom
                    } label: {
                        HStack {
                            Text("Custom")
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedTime == .custom {
                                Image(systemName: "checkmark")
                                    .foregroundColor(ComicTheme.Colors.boldBlue)
                            }
                        }
                    }

                    if selectedTime == .custom {
                        DatePicker(
                            "Date & Time",
                            selection: $customDate,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                } header: {
                    Text("WHEN")
                        .font(ComicTheme.Typography.sectionHeader(11))
                        .tracking(1)
                }

                Section {
                    Text(previewText)
                        .font(.callout)
                        .foregroundColor(.secondary)
                } header: {
                    Text("PREVIEW")
                        .font(ComicTheme.Typography.sectionHeader(11))
                        .tracking(1)
                }
            }
            .navigationTitle("Add Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .tint(ComicTheme.Colors.boldBlue)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(ComicTheme.Colors.crimsonRed)
                    .fontWeight(.bold)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addReminder()
                    }
                    .foregroundStyle(ComicTheme.Colors.emeraldGreen)
                    .fontWeight(.bold)
                }
            }
        }
    }

    private var previewText: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        let date = selectedTime == .custom
            ? customDate
            : Date().addingTimeInterval(TimeInterval(selectedTime.hours * 3600))

        return "You'll receive a \"\(selectedType.displayName)\" reminder on \(dateFormatter.string(from: date))"
    }

    private func addReminder() {
        let scheduledDate = selectedTime == .custom
            ? customDate
            : Date().addingTimeInterval(TimeInterval(selectedTime.hours * 3600))

        let notification = DreamNotification(
            dreamId: dreamId,
            scheduledDate: scheduledDate,
            type: selectedType
        )

        notificationManager.dreamNotifications.append(notification)
        notificationManager.saveDreamNotifications()

        Task {
            if !notificationManager.isAuthorized {
                _ = await notificationManager.requestAuthorization()
            }
            await scheduleNotification(notification)
        }

        onAdd()
        dismiss()
    }

    private func scheduleNotification(_ notification: DreamNotification) async {
        guard let template = notificationManager.templates.first(where: { $0.category == notification.notificationType }) else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = template.randomTitle()
        content.body = template.randomBody()
        content.sound = .default
        content.userInfo = ["dreamId": dreamId.uuidString]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: notification.scheduledDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "dream_\(notification.id.uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to schedule notification: \(error)")
        }
    }
}
