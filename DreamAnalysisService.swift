import Foundation
import Observation

@Observable
final class DreamAnalysisService {
    var selectedPeriod: AnalysisPeriod = .thirtyDays
    var trends: TrendsResponse?
    var summary: AnalysisSummaryResponse?

    var isAnalyzing = false
    var isLoadingTrends = false
    var isLoadingSummary = false
    var analysisError: String?
    var trendsError: String?
    var summaryError: String?

    enum AnalysisPeriod: String, CaseIterable {
        case sevenDays = "7"
        case thirtyDays = "30"
        case ninetyDays = "90"
        case all = "all"

        var displayName: String {
            switch self {
            case .sevenDays: return "7 Days"
            case .thirtyDays: return "30 Days"
            case .ninetyDays: return "90 Days"
            case .all: return "All"
            }
        }
    }

    // MARK: - API Methods

    @MainActor
    func analyzeDream(text: String, dreamDate: Date) async throws -> DreamAnalysisResponse {
        isAnalyzing = true
        analysisError = nil
        defer { isAnalyzing = false }

        do {
            let result = try await BackendService.shared.analyzeDream(text: text, dreamDate: dreamDate)
            return result
        } catch {
            analysisError = error.localizedDescription
            throw error
        }
    }

    @MainActor
    func fetchTrends(period: AnalysisPeriod) async {
        isLoadingTrends = true
        trendsError = nil
        defer { isLoadingTrends = false }

        do {
            trends = try await BackendService.shared.getDreamAnalysisTrends(period: period.rawValue)
        } catch {
            trendsError = error.localizedDescription
        }
    }

    @MainActor
    func fetchSummary(period: AnalysisPeriod) async {
        isLoadingSummary = true
        summaryError = nil
        defer { isLoadingSummary = false }

        do {
            summary = try await BackendService.shared.getDreamAnalysisSummary(period: period.rawValue)
        } catch {
            summaryError = error.localizedDescription
        }
    }

    @MainActor
    func fetchDreamAnalysis(dreamId: String) async throws -> DreamAnalysisResponse {
        return try await BackendService.shared.getDreamAnalysis(dreamId: dreamId)
    }

    @MainActor
    func loadData() async {
        await fetchTrends(period: selectedPeriod)
        await fetchSummary(period: selectedPeriod)
    }

    // MARK: - Mood Mapping

    private static let moodToToneMap: [String: String] = [
        "peaceful": "calm",
        "calm": "calm",
        "serene": "calm",
        "humorous": "funny",
        "funny": "funny",
        "lighthearted": "funny",
        "empowering": "positive",
        "positive": "positive",
        "confident": "positive",
        "hopeful": "hopeful",
        "optimistic": "hopeful",
        "inspiring": "hopeful",
        "happy": "happy",
        "joyful": "happy",
        "cheerful": "happy",
    ]

    func mapSuggestedMoodToTone(_ mood: String) -> String {
        Self.moodToToneMap[mood.lowercased()] ?? "hopeful"
    }
}
