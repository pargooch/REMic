import SwiftUI
import Charts

struct TrendChartView: View {
    let dataPoints: [TrendDataPoint]
    let trendDirection: String

    /// The currently highlighted emotion (tapped in legend). Nil = all shown equally.
    @State private var highlightedEmotion: String?
    @State private var selectedDate: Date?

    private var emotions: [String] {
        Array(Set(dataPoints.map { $0.emotion })).sorted()
    }

    private var groupedByEmotion: [String: [TrendDataPoint]] {
        Dictionary(grouping: dataPoints, by: { $0.emotion })
    }

    /// All parsed dates sorted
    private var allDates: [Date] {
        dataPoints.compactMap { $0.parsedDate }.sorted()
    }

    /// X axis domain — always at least 7 days wide so the chart never collapses
    private var xDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        guard let earliest = allDates.first, let latest = allDates.last else {
            let now = Date()
            return calendar.date(byAdding: .day, value: -7, to: now)!...now
        }
        let span = latest.timeIntervalSince(earliest)
        let minSpan: TimeInterval = 7 * 24 * 3600 // 7 days minimum
        if span < minSpan {
            let center = earliest.addingTimeInterval(span / 2)
            let start = center.addingTimeInterval(-minSpan / 2)
            let end = center.addingTimeInterval(minSpan / 2)
            return start...end
        }
        // Add 1 day padding on each side
        let start = calendar.date(byAdding: .day, value: -1, to: earliest)!
        let end = calendar.date(byAdding: .day, value: 1, to: latest)!
        return start...end
    }

    private func colorForEmotion(_ emotion: String) -> Color {
        EmotionBadgeView.emotionColors[emotion.lowercased()] ?? ComicTheme.Colors.boldBlue
    }

    /// Opacity for a given emotion based on highlight state
    private func opacityForEmotion(_ emotion: String) -> Double {
        guard let highlighted = highlightedEmotion else { return 1.0 }
        return emotion == highlighted ? 1.0 : 0.15
    }

    /// Line width for a given emotion based on highlight state
    private func lineWidthForEmotion(_ emotion: String) -> Double {
        guard let highlighted = highlightedEmotion else { return 2.5 }
        return emotion == highlighted ? 3.5 : 1.5
    }

    /// Point size for a given emotion based on highlight and selection state
    private func pointSizeForEmotion(_ emotion: String, point: TrendDataPoint) -> Double {
        let isSelected = isPointSelected(point)
        if let highlighted = highlightedEmotion {
            if emotion == highlighted {
                return isSelected ? 70 : 40
            } else {
                return isSelected ? 20 : 10
            }
        }
        return isSelected ? 60 : 30
    }

    /// Data points matching the selected date (for the tooltip)
    private var selectedPoints: [TrendDataPoint] {
        guard let selectedDate else { return [] }
        let calendar = Calendar.current
        return dataPoints.filter { point in
            guard let d = point.parsedDate else { return false }
            return calendar.isDate(d, inSameDayAs: selectedDate)
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                trendBadge
            }

            if dataPoints.isEmpty {
                VStack(spacing: 8) {
                    Text("Keep logging dreams to see trends")
                        .font(ComicTheme.Typography.speechBubble(13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                chartView
                    .frame(height: 240)
                    .padding(.bottom, 4)
                    .animation(.easeInOut(duration: 0.3), value: highlightedEmotion)

                // Tooltip for selected date
                if !selectedPoints.isEmpty {
                    selectedPointTooltip
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }

            // Interactive legend
            legendView
        }
    }

    // MARK: - Chart

    private var chartView: some View {
        Chart {
            ForEach(emotions, id: \.self) { emotion in
                let points = (groupedByEmotion[emotion] ?? [])
                    .sorted { ($0.parsedDate ?? .distantPast) < ($1.parsedDate ?? .distantPast) }

                ForEach(points) { point in
                    LineMark(
                        x: .value("Date", point.parsedDate ?? Date()),
                        y: .value("Intensity", point.intensity),
                        series: .value("Emotion", emotion)
                    )
                    .foregroundStyle(colorForEmotion(emotion).opacity(opacityForEmotion(emotion)))
                    .lineStyle(StrokeStyle(
                        lineWidth: lineWidthForEmotion(emotion),
                        lineCap: .round,
                        lineJoin: .round
                    ))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", point.parsedDate ?? Date()),
                        y: .value("Intensity", point.intensity)
                    )
                    .foregroundStyle(colorForEmotion(emotion).opacity(opacityForEmotion(emotion)))
                    .symbolSize(pointSizeForEmotion(emotion, point: point))
                }
            }

            // Selection rule line
            if let selectedDate {
                RuleMark(x: .value("Selected", selectedDate))
                    .foregroundStyle(.gray.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: 0...1)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 0.25, 0.5, 0.75, 1.0]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    .foregroundStyle(.gray.opacity(0.3))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: "%.0f%%", v * 100))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: xAxisStride)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    .foregroundStyle(.gray.opacity(0.2))
                AxisTick(stroke: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(.gray.opacity(0.4))
                AxisValueLabel(anchor: .top) {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .chartXSelection(value: $selectedDate)
    }

    /// How many days between each X axis tick mark
    private var xAxisStride: Int {
        let span = xDomain.upperBound.timeIntervalSince(xDomain.lowerBound)
        let days = Int(span / (24 * 3600))
        if days <= 7 { return 1 }
        if days <= 14 { return 2 }
        if days <= 30 { return 5 }
        if days <= 90 { return 14 }
        return 30
    }

    // MARK: - Tooltip

    private var selectedPointTooltip: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let date = selectedPoints.first?.parsedDate {
                Text(date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
            }
            ForEach(selectedPoints.sorted { $0.intensity > $1.intensity }) { point in
                HStack(spacing: 6) {
                    Circle()
                        .fill(colorForEmotion(point.emotion))
                        .frame(width: 8, height: 8)
                    Text(point.emotion.capitalized)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(colorForEmotion(point.emotion))
                    Spacer()
                    Text(String(format: "%.0f%%", point.intensity * 100))
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(.primary)
                }
                .opacity(opacityForEmotion(point.emotion) < 1.0 ? 0.4 : 1.0)
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Legend

    private var legendView: some View {
        FlowLayout(spacing: 6) {
            ForEach(emotions, id: \.self) { emotion in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if highlightedEmotion == emotion {
                            highlightedEmotion = nil
                        } else {
                            highlightedEmotion = emotion
                        }
                    }
                } label: {
                    let isHighlighted = highlightedEmotion == emotion
                    let isDimmed = highlightedEmotion != nil && !isHighlighted
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isDimmed ? Color.gray.opacity(0.3) : colorForEmotion(emotion))
                            .frame(width: 12, height: 3)
                        Text(emotion.capitalized)
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        isDimmed
                            ? Color.gray.opacity(0.06)
                            : isHighlighted
                                ? colorForEmotion(emotion).opacity(0.2)
                                : colorForEmotion(emotion).opacity(0.12)
                    )
                    .foregroundColor(isDimmed ? .gray : colorForEmotion(emotion))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(
                                isDimmed
                                    ? Color.gray.opacity(0.15)
                                    : isHighlighted
                                        ? colorForEmotion(emotion).opacity(0.5)
                                        : colorForEmotion(emotion).opacity(0.3),
                                lineWidth: isHighlighted ? 1.5 : 1
                            )
                    )
                    .opacity(isDimmed ? 0.5 : 1.0)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Trend Badge

    private var trendBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: trendIcon)
                .font(.caption.weight(.bold))
            Text(trendDirection.capitalized)
                .font(.system(size: 11, weight: .bold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(trendColor.opacity(0.15))
        .foregroundColor(trendColor)
        .clipShape(Capsule())
    }

    private var trendIcon: String {
        switch trendDirection.lowercased() {
        case "improving": return "arrow.down.right"
        case "worsening": return "arrow.up.right"
        default: return "minus"
        }
    }

    private var trendColor: Color {
        switch trendDirection.lowercased() {
        case "improving": return ComicTheme.Colors.emeraldGreen
        case "worsening": return ComicTheme.Colors.crimsonRed
        default: return .gray
        }
    }

    // MARK: - Helpers

    private func isPointSelected(_ point: TrendDataPoint) -> Bool {
        guard let selectedDate, let pointDate = point.parsedDate else { return false }
        return Calendar.current.isDate(pointDate, inSameDayAs: selectedDate)
    }
}

// MARK: - Date Parsing Helper

extension TrendDataPoint {
    /// Cached date formatters (creating these is expensive)
    private static let iso8601Full: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601NoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let iso8601DateOnly: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    private static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var parsedDate: Date? {
        // Full ISO8601 with fractional seconds: "2026-02-18T14:30:00.000Z"
        if let d = Self.iso8601Full.date(from: date) { return d }
        // ISO8601 without fractional seconds: "2026-02-18T14:30:00Z"
        if let d = Self.iso8601NoFraction.date(from: date) { return d }
        // Date only: "2026-02-18"
        if let d = Self.iso8601DateOnly.date(from: date) { return d }
        // Fallback: "2026-02-18"
        return Self.yyyyMMdd.date(from: date)
    }
}
