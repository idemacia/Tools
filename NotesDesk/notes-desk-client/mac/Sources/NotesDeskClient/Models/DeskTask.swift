import Foundation

enum AppConstants {
    static let pollIntervalSeconds: TimeInterval = 30
    static let appSupportSubdirectory = "NotesDeskClient"
}

enum MessageSource: String, Codable, Sendable {
    case feishu
    case dingtalk
    case manual
}

struct DeskTask: Codable, Identifiable, Sendable, Equatable {
    let id: String
    var text: String
    var createdAt: Date
    var dueDate: Date?
    var completedAt: Date?
    var remindedAt: Date?
    var source: MessageSource
    var dingtalkMessageId: String?
    var dingtalkStaffId: String?

    var isCompleted: Bool { completedAt != nil }

    func isOverdue(calendar: Calendar = .current) -> Bool {
        guard !isCompleted, let dueDate else { return false }
        return dueDate < Date()
    }
}

enum DeskViewMode: String, CaseIterable, Identifiable {
    case incomplete
    case today
    case history

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .incomplete: return "全部未完成"
        case .today: return "今日"
        case .history: return "历史"
        }
    }
}

struct TaskPeriodStats: Sendable, Equatable {
    let periodStart: Date
    let periodEnd: Date
    let planned: Int
    let completed: Int
    let incomplete: Int
}
