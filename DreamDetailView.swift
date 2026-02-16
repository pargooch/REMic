import SwiftUI
import UserNotifications

struct DreamDetailView: View {
    @EnvironmentObject var store: DreamStore
    let dream: Dream

    @State private var selectedTone = "happy"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var aiService = AIService()

    // Editing states
    @State private var isEditing = false
    @State private var editedText = ""

    let tones = ["happy", "funny", "hopeful", "calm", "positive"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Original dream
                Text("Original Dream")
                    .font(.headline)

                Text(dream.originalText)
                    .font(.body)

                Divider()

                // Show rewritten dream if available
                if let rewritten = dream.rewrittenText {
                    HStack {
                        Text("Rewritten Dream (\(dream.tone?.capitalized ?? ""))")
                            .font(.headline)

                        Spacer()

                        Button {
                            if isEditing {
                                // Save changes
                                saveEditedText()
                            } else {
                                // Enter edit mode
                                editedText = rewritten
                                isEditing = true
                            }
                        } label: {
                            Label(isEditing ? "Save" : "Edit", systemImage: isEditing ? "checkmark" : "pencil")
                                .font(.subheadline)
                        }
                        .buttonStyle(.bordered)

                        if isEditing {
                            Button {
                                // Cancel editing
                                isEditing = false
                                editedText = ""
                            } label: {
                                Label("Cancel", systemImage: "xmark")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if isEditing {
                        ZStack(alignment: .topLeading) {
                            // Hidden text to calculate dynamic height
                            Text(editedText.isEmpty ? " " : editedText)
                                .font(.body)
                                .padding(12)
                                .opacity(0)

                            TextEditor(text: $editedText)
                                .font(.body)
                                .scrollContentBackground(.hidden)
                                .scrollDisabled(true)
                                .padding(6)
                        }
                        .frame(minHeight: 100)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    } else {
                        Text(rewritten)
                            .font(.body)
                    }

                    Divider()
                }

                // Always show rewrite options
                Text(dream.rewrittenText != nil ? "Try a different tone?" : "How would you like this dream to feel?")
                    .font(.subheadline)

                Picker("Tone", selection: $selectedTone) {
                    ForEach(tones, id: \.self) { tone in
                        Text(tone.capitalized)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(isEditing)

                // Rewrite button or Cancel button
                if isLoading {
                    Button {
                        cancelRewrite()
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.top)

                    ProgressView("Rewriting dream...")
                        .padding(.top)
                } else {
                    Button {
                        rewriteDream()
                    } label: {
                        Label(
                            dream.rewrittenText != nil ? "Rewrite Again" : "Rewrite with AI",
                            systemImage: dream.rewrittenText != nil ? "arrow.clockwise" : "sparkles"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                    .disabled(isEditing)
                }

                // Error message with retry button
                if let errorMessage = errorMessage {
                    VStack(spacing: 12) {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)

                        Button {
                            rewriteDream()
                        } label: {
                            Label("Try Again", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top)
                }

                // Image generation section (only show if rewritten)
                if dream.rewrittenText != nil {
                    Divider()
                    DreamImageSection(dream: dream, store: store)
                }

                Divider()

                // Per-dream notification management
                DreamNotificationSection(dreamId: dream.id, hasRewrite: dream.rewrittenText != nil)
            }
            .padding()
        }
        .navigationTitle("Dream")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Set the picker to the current tone if already rewritten
            if let currentTone = dream.tone {
                selectedTone = currentTone
            }
        }
        .onDisappear {
            // Cancel any ongoing request when leaving the view
            aiService.cancel()
        }
    }

    // MARK: - AI Rewrite
    func rewriteDream() {
        isLoading = true
        errorMessage = nil

        aiService.rewriteDream(
            original: dream.originalText,
            tone: selectedTone
        ) { result in
            DispatchQueue.main.async {
                isLoading = false

                switch result {
                case .success(let rewritten):
                    var updated = dream
                    updated.rewrittenText = rewritten
                    updated.tone = selectedTone
                    store.updateDream(updated)

                case .failure(let error):
                    // Don't show error for cancelled requests
                    if case .cancelled = error {
                        return
                    }

                    print("Rewrite failed: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    func cancelRewrite() {
        aiService.cancel()
        isLoading = false
    }

    func saveEditedText() {
        var updated = dream
        updated.rewrittenText = editedText
        store.updateDream(updated)
        isEditing = false
        editedText = ""
    }
}

// MARK: - Dream Notification Section

struct DreamNotificationSection: View {
    let dreamId: UUID
    let hasRewrite: Bool

    @StateObject private var notificationManager = NotificationManager.shared
    @State private var showAddReminder = false
    @State private var reminders: [DreamNotification] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(.accentColor)
                Text("Reminders")
                    .font(.headline)

                Spacer()

                Button {
                    showAddReminder = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }

            if reminders.isEmpty {
                VStack(spacing: 8) {
                    Text("No reminders set")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Add a reminder to revisit this dream")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                // List of scheduled reminders
                ForEach(reminders) { reminder in
                    DreamReminderRow(
                        reminder: reminder,
                        onDelete: { deleteReminder(reminder) }
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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

struct DreamReminderRow: View {
    let reminder: DreamNotification
    let onDelete: () -> Void

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
                .foregroundColor(isExpired ? .secondary : .accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.notificationType.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isExpired ? .secondary : .primary)

                if isExpired {
                    Text("Expired")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(timeDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

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
                                    .foregroundColor(.accentColor)
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
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Reminder Type")
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
                                            .foregroundColor(.accentColor)
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
                                    .foregroundColor(.accentColor)
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
                    Text("When")
                }

                Section {
                    Text(previewText)
                        .font(.callout)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Preview")
                }
            }
            .navigationTitle("Add Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addReminder()
                    }
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

// MARK: - Dream Image Section

struct DreamImageSection: View {
    let dream: Dream
    let store: DreamStore

    @StateObject private var imageService = ImageGenerationService()
    @State private var selectedStyle: DreamImageStyle = .comicBook
    @State private var showImageGallery = false
    @State private var errorMessage: String?
    @State private var showSignUpBanner = false

    private var isAvailable: Bool {
        ImageGenerationService.isAvailable
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "photo.stack.fill")
                    .foregroundColor(.accentColor)
                Text("Dream Visualization")
                    .font(.headline)

                Spacer()

                if dream.hasImages {
                    Button {
                        showImageGallery = true
                    } label: {
                        Label("View", systemImage: "eye")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Show provider info if available
            if isAvailable && !dream.hasImages {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.caption2)
                        Text("Flat Vector Style · On-Device")
                            .font(.caption)
                    }
                    Text("AI creates 1-4 panels based on story")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .foregroundColor(.secondary)
            }

            if !isAvailable {
                // Not available message
                VStack(spacing: 8) {
                    Image(systemName: "cpu")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("MLX Not Available")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Image generation requires Apple Silicon device (iPhone 12+ or M1+ Mac).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if dream.hasImages {
                // Show existing images preview
                DreamImagePreview(images: dream.sortedImages)

                // Subtle sign-up prompt after image generation
                SignUpPromptBanner(isVisible: $showSignUpBanner)

                // Style picker for regeneration
                VStack(alignment: .leading, spacing: 8) {
                    Text("Style")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        ForEach(DreamImageStyle.allCases) { style in
                            StyleButton(
                                style: style,
                                isSelected: selectedStyle == style
                            ) {
                                selectedStyle = style
                            }
                        }
                    }
                }

                // Regenerate option with loading state
                if imageService.isGenerating {
                    VStack(spacing: 12) {
                        ProgressView(value: imageService.progress) {
                            Text(imageService.statusMessage.isEmpty ? "Generating..." : imageService.statusMessage)
                        }

                        Button("Cancel") {
                            imageService.cancel()
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    Button {
                        generateImages()
                    } label: {
                        Label("Regenerate Images", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            } else {
                // Generation options
                Text("Create flat vector comic panels from your dream")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Style picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Style")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        ForEach(DreamImageStyle.allCases) { style in
                            StyleButton(
                                style: style,
                                isSelected: selectedStyle == style
                            ) {
                                selectedStyle = style
                            }
                        }
                    }
                }

                // Generate button
                if imageService.isGenerating {
                    VStack(spacing: 12) {
                        ProgressView(value: imageService.progress) {
                            Text(imageService.statusMessage.isEmpty ? "Generating..." : imageService.statusMessage)
                        }

                        Button("Cancel") {
                            imageService.cancel()
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    Button {
                        generateImages()
                    } label: {
                        Label("Generate Dream Sequence", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .sheet(isPresented: $showImageGallery) {
            DreamImageGalleryView(dream: dream)
        }
        .onAppear {
            // Initialize style from existing dream images
            if let styleString = dream.imageStyle,
               let style = DreamImageStyle.allCases.first(where: { $0.rawValue == styleString }) {
                selectedStyle = style
            }
        }
    }

    private func generateImages() {
        guard let rewrittenText = dream.rewrittenText else { return }
        print("Generating comic panels for dream story...")

        errorMessage = nil

        Task {
            do {
                // AI Visual Director decides panel count based on story complexity
                let images = try await imageService.generateSequenceImages(
                    from: rewrittenText,
                    style: selectedStyle
                )

                // Update dream with generated images
                var updated = dream
                updated.generatedImages = images
                updated.imageStyle = selectedStyle.rawValue
                store.updateDream(updated)

                // Show subtle sign-up prompt for non-authenticated users
                if !AuthManager.shared.isAuthenticated {
                    showSignUpBanner = true
                }
            } catch let error as ImageGenerationError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct StyleButton: View {
    let style: DreamImageStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: style.icon)
                    .font(.title2)
                Text(style.rawValue)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.accentColor : Color(.systemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct DreamImagePreview: View {
    let images: [GeneratedDreamImage]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(images) { image in
                    if let uiImage = image.uiImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
}

struct DreamImageGalleryView: View {
    let dream: Dream
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex: Int = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Main image
                TabView(selection: $selectedIndex) {
                    ForEach(Array(dream.sortedImages.enumerated()), id: \.element.id) { index, image in
                        VStack {
                            if let uiImage = image.uiImage {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .padding()
                            }

                            Text("Scene \(index + 1)")
                                .font(.headline)

                            Text(image.prompt)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))

                // Thumbnail strip
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(dream.sortedImages.enumerated()), id: \.element.id) { index, image in
                            if let uiImage = image.uiImage {
                                Button {
                                    withAnimation {
                                        selectedIndex = index
                                    }
                                } label: {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(selectedIndex == index ? Color.accentColor : Color.clear, lineWidth: 2)
                                        )
                                }
                            }
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGray6))
            }
            .navigationTitle("Dream Sequence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
