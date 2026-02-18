import SwiftUI
import Charts

struct DreamAnalysisView: View {
    @EnvironmentObject var store: DreamStore
    @Environment(DreamAnalysisService.self) private var analysisService
    @Environment(\.dismiss) private var dismiss
    @State private var isReanalyzing = false
    @State private var reanalyzeProgress = 0
    @State private var reanalyzeTotal = 0

    var body: some View {
        @Bindable var service = analysisService

        ScrollView {
            VStack(spacing: 20) {
                // Period Selector
                ComicPanelCard(titleBanner: "Time Period", bannerColor: ComicTheme.Colors.deepPurple) {
                    Picker("Period", selection: $service.selectedPeriod) {
                        ForEach(DreamAnalysisService.AnalysisPeriod.allCases, id: \.self) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Trend Chart
                ComicPanelCard(titleBanner: "Emotion Trends", bannerColor: ComicTheme.Colors.hotPink) {
                    if analysisService.isLoadingTrends {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(ComicTheme.Colors.hotPink)
                            Text("Loading trends...")
                                .font(ComicTheme.Typography.speechBubble(12))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else if let error = analysisService.trendsError {
                        errorView(message: error) {
                            Task { await analysisService.fetchTrends(period: analysisService.selectedPeriod) }
                        }
                    } else if let trends = analysisService.trends {
                        if trends.data_points.isEmpty {
                            emptyTrendsView
                        } else {
                            TrendChartView(dataPoints: trends.data_points, trendDirection: trends.trend_direction)
                        }
                    } else {
                        emptyTrendsView
                    }
                }

                // Summary Cards
                if let summary = analysisService.summary {
                    summarySection(summary)
                } else if analysisService.isLoadingSummary {
                    ComicPanelCard(titleBanner: "Summary", bannerColor: ComicTheme.Colors.boldBlue) {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(ComicTheme.Colors.boldBlue)
                            Text("Loading summary...")
                                .font(ComicTheme.Typography.speechBubble(12))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                } else if let error = analysisService.summaryError {
                    ComicPanelCard(titleBanner: "Summary", bannerColor: ComicTheme.Colors.boldBlue) {
                        errorView(message: error) {
                            Task { await analysisService.fetchSummary(period: analysisService.selectedPeriod) }
                        }
                    }
                }

                // Empty state when no data at all
                if analysisService.trends == nil && analysisService.summary == nil
                    && !analysisService.isLoadingTrends && !analysisService.isLoadingSummary
                    && analysisService.trendsError == nil && analysisService.summaryError == nil {
                    emptyState
                }
            }
            .padding()
        }
        .halftoneBackground()
        .navigationTitle("Dream Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
                    .foregroundStyle(ComicTheme.Colors.hotPink)
                    .fontWeight(.bold)
            }
            // TEMP: Re-analyze all dreams with correct entry dates
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await reanalyzeAllDreams() }
                } label: {
                    if isReanalyzing {
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.mini)
                            Text("\(reanalyzeProgress)/\(reanalyzeTotal)")
                                .font(.caption2.bold())
                        }
                    } else {
                        Image(systemName: "arrow.clockwise.circle")
                    }
                }
                .disabled(isReanalyzing)
                .foregroundStyle(ComicTheme.Colors.deepPurple)
            }
        }
        .onChange(of: analysisService.selectedPeriod) { _, newPeriod in
            Task {
                await analysisService.fetchTrends(period: newPeriod)
                await analysisService.fetchSummary(period: newPeriod)
            }
        }
        .task {
            await analysisService.loadData()
        }
    }

    // MARK: - TEMP: Bulk Re-analyze

    private func reanalyzeAllDreams() async {
        let dreamsToAnalyze = store.dreams.filter { !$0.originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        reanalyzeTotal = dreamsToAnalyze.count
        reanalyzeProgress = 0
        isReanalyzing = true
        defer { isReanalyzing = false }

        for dream in dreamsToAnalyze {
            do {
                let result = try await analysisService.analyzeDream(text: dream.originalText, dreamDate: dream.date)
                var updated = dream
                updated.analysis = result
                store.updateDream(updated)
            } catch {
                print("Re-analyze failed for dream \(dream.id): \(error)")
            }
            reanalyzeProgress += 1
        }

        await analysisService.loadData()
    }

    // MARK: - Summary Section

    @ViewBuilder
    private func summarySection(_ summary: AnalysisSummaryResponse) -> some View {
        // Most Common Feeling
        ComicPanelCard(titleBanner: "Most Common Feeling", bannerColor: ComicTheme.Colors.boldBlue) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.most_common_emotion.capitalized)
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(EmotionBadgeView.emotionColors[summary.most_common_emotion.lowercased()] ?? ComicTheme.Colors.boldBlue)
                    Text(String(format: "Average intensity: %.0f%%", summary.most_common_intensity * 100))
                        .font(ComicTheme.Typography.speechBubble(12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("\(store.dreams.count)")
                        .font(.system(size: 36, weight: .black))
                        .foregroundColor(ComicTheme.Colors.boldBlue.opacity(0.3))
                    Text("dreams")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
        }

        // Mood Distribution
        if !summary.mood_distribution.isEmpty {
            ComicPanelCard(titleBanner: "Suggested Moods", bannerColor: ComicTheme.Colors.goldenYellow) {
                Chart(summary.mood_distribution) { entry in
                    SectorMark(
                        angle: .value("Count", entry.count),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Mood", entry.mood.capitalized))
                    .cornerRadius(4)
                }
                .frame(height: 180)

                VStack(spacing: 6) {
                    ForEach(summary.mood_distribution) { entry in
                        HStack {
                            Text(entry.mood.capitalized)
                                .font(.system(size: 12, weight: .bold))
                            Spacer()
                            Text(String(format: "%.0f%%", entry.percentage))
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }

        // Sparkline
        if let sparkline = summary.sparkline_data, !sparkline.isEmpty {
            ComicPanelCard(titleBanner: "Activity", bannerColor: ComicTheme.Colors.emeraldGreen) {
                Chart(Array(sparkline.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Day", index),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(ComicTheme.Colors.emeraldGreen)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    AreaMark(
                        x: .value("Day", index),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(ComicTheme.Colors.emeraldGreen.opacity(0.15))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 60)
            }
        }
    }

    // MARK: - Empty & Error States

    private var emptyTrendsView: some View {
        VStack(spacing: 8) {
            Text("Keep logging dreams to see trends")
                .font(ComicTheme.Typography.speechBubble(13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var emptyState: some View {
        ComicPanelCard(bannerColor: ComicTheme.Colors.deepPurple) {
            VStack(spacing: 16) {
                SoundEffectText(text: "ZAP!", fillColor: ComicTheme.Colors.goldenYellow, fontSize: 36)

                Text("Record your first dream to start tracking your emotions")
                    .font(ComicTheme.Typography.speechBubble())
                    .multilineTextAlignment(.center)
                    .speechBubble()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 20)
    }

    private func errorView(message: String, retry: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            SoundEffectText(text: "OOPS!", fillColor: ComicTheme.Colors.crimsonRed, fontSize: 20)

            Text(message)
                .font(ComicTheme.Typography.speechBubble(12))
                .foregroundColor(.secondary)
                .speechBubble()

            Button {
                retry()
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.comicSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
