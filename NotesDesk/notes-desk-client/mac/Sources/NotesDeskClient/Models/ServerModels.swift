import Foundation

enum StatsPeriod: String, CaseIterable, Identifiable {
    case week
    case month
    case year

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .week: return "周"
        case .month: return "月"
        case .year: return "年"
        }
    }
}

struct ServerPeriodStats: Codable, Sendable {
    let periodStart: String
    let periodEnd: String
    let planned: Int
    let completed: Int
    let incomplete: Int
    let overdue: Int
    let lateCompleted: Int
    let completionRate: Double
    let avgCompletionHours: Double?
    let abandoned: Int
    let neverDue: Int
}

struct AnalysisReportOverview: Codable, Sendable {
    let headline: String
    let grade: String
    let summary: String
}

struct AnalysisSuggestion: Codable, Sendable, Identifiable {
    let priority: String
    let action: String
    let reason: String

    var id: String { "\(priority)-\(action)" }

    var priorityLabel: String {
        switch priority {
        case "high": return "高"
        case "medium": return "中"
        case "low": return "低"
        default: return priority
        }
    }
}

struct AnalysisReport: Codable, Sendable {
    let periodLabel: String
    let overview: AnalysisReportOverview
    let metricsInterpretation: String
    let wasteAnalysis: String
    let comparisonWithPrevious: String
    let strengths: [String]
    let risks: [String]
    let suggestions: [AnalysisSuggestion]
    let nextPeriodFocus: String
}

struct AnalysisResult: Codable, Sendable {
    let source: String
    let report: AnalysisReport
    let summary: String?
    let wasteAnalysis: String?
    let suggestions: [String]?
}

struct AnalysisRunResult: Codable, Sendable {
    let stats: ServerPeriodStats
    let analysis: AnalysisResult
    let periodLabel: String
    let pushed: Bool
}

struct ServerLlmConfig: Codable, Sendable {
    var enabled: Bool
    var provider: String
    var baseUrl: String
    var apiKey: String?
    var model: String
    var maxTokens: Int
    var temperature: Double
    var hasApiKey: Bool?

    enum CodingKeys: String, CodingKey {
        case enabled, provider, baseUrl, apiKey, model, maxTokens, temperature, hasApiKey
    }
}

struct LlmConfigResponse: Codable {
    let config: ServerLlmConfig
}

struct ServerAppSettings: Codable, Sendable {
    var reminderDelayHours: Double
    var remindersEnabled: Bool
    var showCompletedSection: Bool
    var analysisScheduleEnabled: Bool
    var analysisPushToDingTalk: Bool
    var weeklyAnalysisEnabled: Bool
    var weeklyAnalysisWeekday: Int
    var weeklyAnalysisHour: Int
    var monthlyAnalysisEnabled: Bool
    var monthlyAnalysisDay: Int
    var monthlyAnalysisHour: Int
    var yearlyAnalysisEnabled: Bool
    var yearlyAnalysisMonth: Int
    var yearlyAnalysisDay: Int
    var yearlyAnalysisHour: Int

    static var defaults: ServerAppSettings {
        ServerAppSettings(
            reminderDelayHours: 1,
            remindersEnabled: true,
            showCompletedSection: true,
            analysisScheduleEnabled: true,
            analysisPushToDingTalk: true,
            weeklyAnalysisEnabled: true,
            weeklyAnalysisWeekday: 1,
            weeklyAnalysisHour: 8,
            monthlyAnalysisEnabled: true,
            monthlyAnalysisDay: 1,
            monthlyAnalysisHour: 8,
            yearlyAnalysisEnabled: true,
            yearlyAnalysisMonth: 1,
            yearlyAnalysisDay: 1,
            yearlyAnalysisHour: 8
        )
    }
}

struct ServerSettingsResponse: Codable {
    let settings: ServerAppSettings
}

struct OkMessageResponse: Codable {
    let ok: Bool?
    let message: String?
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case connection
    case llm
    case schedule
    case stats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .connection: return "连接"
        case .llm: return "AI 大模型"
        case .schedule: return "分析定时"
        case .stats: return "统计分析"
        }
    }
}

enum StatsDateHelper {
    static func isoWeek(of date: Date = Date()) -> Int {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return cal.component(.weekOfYear, from: date)
    }

    static func year(of date: Date = Date()) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return cal.component(.year, from: date)
    }

    static func month(of date: Date = Date()) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return cal.component(.month, from: date)
    }

    static let weekdayLabels = ["日", "一", "二", "三", "四", "五", "六"]

    static func dayString(from date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func date(fromDayString s: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: s)
    }

    static func shiftDayString(_ s: String, by days: Int) -> String {
        guard let date = date(fromDayString: s) else { return s }
        let next = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
        return dayString(from: next)
    }
}

struct TaskComment: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let taskId: String
    var body: String
    let createdAt: Date
    var updatedAt: Date
}
