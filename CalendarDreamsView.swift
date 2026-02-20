import SwiftUI

struct CalendarDreamsView: View {
    @EnvironmentObject var store: DreamStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()

    private var calendar: Calendar { Calendar.current }

    private var dreamsForSelectedDate: [Dream] {
        store.dreams.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    /// Maps day-of-month to the dreams on that day within the displayed month
    private var dreamsByDay: [Int: [Dream]] {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        let filtered = store.dreams.filter {
            let dc = calendar.dateComponents([.year, .month], from: $0.date)
            return dc.year == components.year && dc.month == components.month
        }
        return Dictionary(grouping: filtered) { calendar.component(.day, from: $0.date) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ComicTheme.Dimensions.gutterWidth) {
                // Calendar card
                ComicPanelCard(bannerColor: ComicTheme.Colors.deepPurple) {
                    VStack(spacing: 16) {
                        monthHeader
                        weekdayHeader
                        dayGrid
                    }
                }

                // Dreams for selected date
                if dreamsForSelectedDate.isEmpty {
                    ComicPanelCard(bannerColor: ComicTheme.Colors.goldenYellow) {
                        VStack(spacing: 8) {
                            Image(systemName: "moon.zzz")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text(L("No dreams on this date"))
                                .font(ComicTheme.Typography.speechBubble(13))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                } else {
                    ForEach(dreamsForSelectedDate) { dream in
                        NavigationLink {
                            DreamDetailView(dream: dream)
                        } label: {
                            DreamRowView(dream: dream)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .halftoneBackground()
        .navigationTitle(L("Calendar"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.bold))
                    .foregroundColor(ComicTheme.Colors.deepPurple)
                    .frame(width: 36, height: 36)
            }

            Spacer()

            Text(monthYearString)
                .font(ComicTheme.Typography.sectionHeader())
                .tracking(1.5)
                .foregroundColor(.primary)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.bold))
                    .foregroundColor(ComicTheme.Colors.deepPurple)
                    .frame(width: 36, height: 36)
            }
            .disabled(calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month))
            .opacity(calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month) ? 0.3 : 1)
        }
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    // MARK: - Weekday Header

    private var weekdayHeader: some View {
        let symbols = calendar.veryShortWeekdaySymbols
        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                Text(symbols[index])
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Day Grid

    private var dayGrid: some View {
        let days = generateDays()
        let rows = days.chunked(into: 7)

        return VStack(spacing: 4) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(week, id: \.id) { day in
                        dayCell(day)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: CalendarDay) -> some View {
        let isSelected = day.isCurrentMonth && calendar.isDate(day.date, inSameDayAs: selectedDate)
        let isToday = day.isCurrentMonth && calendar.isDateInToday(day.date)
        let dreams = day.isCurrentMonth ? (dreamsByDay[day.dayNumber] ?? []) : []
        let hasRewrite = dreams.contains { $0.rewrittenText != nil }
        let hasImages = dreams.contains { $0.hasComicPages || $0.hasImages }

        Button {
            if day.isCurrentMonth {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedDate = day.date
                }
            }
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(ComicTheme.Colors.deepPurple)
                            .frame(width: 32, height: 32)
                    } else if isToday {
                        Circle()
                            .stroke(ComicTheme.Colors.deepPurple, lineWidth: 1.5)
                            .frame(width: 32, height: 32)
                    }

                    Text("\(day.dayNumber)")
                        .font(.system(size: 14, weight: isSelected || isToday ? .bold : .medium))
                        .foregroundColor(
                            !day.isCurrentMonth ? .secondary.opacity(0.3) :
                            isSelected ? .white :
                            .primary
                        )
                }
                .frame(height: 32)

                // Dream indicators
                HStack(spacing: 2) {
                    if !dreams.isEmpty {
                        Circle()
                            .fill(ComicTheme.Colors.deepPurple)
                            .frame(width: 4, height: 4)
                    }
                    if hasRewrite {
                        Circle()
                            .fill(ComicTheme.Colors.goldenYellow)
                            .frame(width: 4, height: 4)
                    }
                    if hasImages {
                        Circle()
                            .fill(ComicTheme.Colors.boldBlue)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(!day.isCurrentMonth)
    }

    // MARK: - Day Generation

    private func generateDays() -> [CalendarDay] {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let firstOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingEmpty = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [CalendarDay] = []

        // Leading days from previous month
        if leadingEmpty > 0, let prevMonth = calendar.date(byAdding: .month, value: -1, to: firstOfMonth),
           let prevRange = calendar.range(of: .day, in: .month, for: prevMonth) {
            let prevDays = Array(prevRange)
            for i in (prevDays.count - leadingEmpty)..<prevDays.count {
                let date = calendar.date(bySetting: .day, value: prevDays[i], of: prevMonth) ?? prevMonth
                days.append(CalendarDay(date: date, dayNumber: prevDays[i], isCurrentMonth: false))
            }
        }

        // Current month days
        for day in range {
            let date = calendar.date(bySetting: .day, value: day, of: firstOfMonth) ?? firstOfMonth
            days.append(CalendarDay(date: date, dayNumber: day, isCurrentMonth: true))
        }

        // Trailing days to fill last row
        let totalCells = ((days.count + 6) / 7) * 7
        if days.count < totalCells, let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstOfMonth) {
            for day in 1...(totalCells - days.count) {
                let date = calendar.date(bySetting: .day, value: day, of: nextMonth) ?? nextMonth
                days.append(CalendarDay(date: date, dayNumber: day, isCurrentMonth: false))
            }
        }

        return days
    }
}

// MARK: - Calendar Day Model

private struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date
    let dayNumber: Int
    let isCurrentMonth: Bool
}

// MARK: - Array Chunking

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
