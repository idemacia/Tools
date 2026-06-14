import Combine
import Foundation

@MainActor
final class DeskViewModel: ObservableObject {
    @Published var displayTitle = "待办"
    @Published var statusMessage = "连接 NAS…"
    @Published var serverConnected = false
    @Published var bridgeConnected = false
    @Published var incompleteTasks: [DeskTask] = []
    @Published var completedTasks: [DeskTask] = []
    @Published var showCompletedSection: Bool {
        didSet { AppSettings.showCompletedSection = showCompletedSection }
    }
    @Published var quitOnClosePanel: Bool {
        didSet { AppSettings.quitOnClosePanel = quitOnClosePanel }
    }
    @Published var showSettings = false
    @Published var viewMode: DeskViewMode {
        didSet {
            AppSettings.viewMode = viewMode
            Task { await refreshFromServer() }
        }
    }
    @Published var panelOpacity: Double {
        didSet { AppSettings.panelOpacity = panelOpacity }
    }
    @Published var fontSize: Double {
        didSet { AppSettings.fontSize = fontSize }
    }
    @Published var panelVisible: Bool {
        didSet { AppSettings.panelVisible = panelVisible }
    }

    private let api = NasApiClient.shared
    private let calendar = Calendar.current
    private var pollTimer: Timer?
    private var dayBoundaryTimer: Timer?
    private var allIncomplete: [DeskTask] = []
    private var allCompleted: [DeskTask] = []

    init() {
        panelOpacity = AppSettings.panelOpacity
        fontSize = AppSettings.fontSize
        panelVisible = AppSettings.panelVisible
        viewMode = AppSettings.viewMode
        showCompletedSection = AppSettings.showCompletedSection
        quitOnClosePanel = AppSettings.quitOnClosePanel
        scheduleDayBoundaryRefresh()
    }

    deinit {
        pollTimer?.invalidate()
        dayBoundaryTimer?.invalidate()
    }

    func startPolling() {
        pollTimer?.invalidate()
        Task { await refreshFromServer() }
        pollTimer = Timer.scheduledTimer(withTimeInterval: AppConstants.pollIntervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshFromServer()
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func refreshFromServer() async {
        guard AppSettings.isConfigured else {
            serverConnected = false
            bridgeConnected = false
            statusMessage = "请在设置中填写 NAS 地址"
            return
        }

        do {
            let health = try await api.health()
            serverConnected = health.ok
            bridgeConnected = health.bridge
            if health.bridge {
                statusMessage = "NAS 已连接 · 钉钉桥在线"
            } else {
                statusMessage = "NAS 已连接 · 钉钉桥未启动"
            }

            let viewParam = viewMode == .today ? "today" : nil
            allIncomplete = try await api.listTasks(view: viewParam, status: "incomplete")
            let completedLimit = viewMode == .history ? 200 : 30
            allCompleted = try await api.listTasks(status: "completed")
            allCompleted = Array(
                allCompleted
                    .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
                    .prefix(completedLimit)
            )
            applyLists()
        } catch {
            serverConnected = false
            bridgeConnected = false
            statusMessage = error.localizedDescription
        }
    }

    func completeTask(id: String) {
        Task {
            do {
                let task = try await api.completeTask(id: id)
                statusMessage = "已完成 · \(task.text)"
                await refreshFromServer()
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func uncompleteTask(id: String) {
        Task {
            do {
                let task = try await api.uncompleteTask(id: id)
                statusMessage = "已恢复 · \(task.text)"
                await refreshFromServer()
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func setDueDate(taskID: String, dueDate: Date?) {
        Task {
            do {
                _ = try await api.setDueDate(id: taskID, dueDate: dueDate)
                statusMessage = dueDate == nil ? "已清除截止日期" : "已更新截止日期"
                await refreshFromServer()
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func completeMostRecent() {
        guard let task = allIncomplete.last else {
            statusMessage = "没有可完成的任务"
            return
        }
        completeTask(id: task.id)
    }

    func clearCompleted() {
        Task {
            do {
                let n = try await api.clearCompleted()
                statusMessage = "已清除 \(n) 条已完成"
                await refreshFromServer()
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func addTask(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            do {
                try await api.ingest(text: trimmed)
                statusMessage = "已添加"
                await refreshFromServer()
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func dailyStats(on day: Date = Date()) -> TaskPeriodStats {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let tasks = (allIncomplete + allCompleted).filter { task in
            let createdIn = task.createdAt >= start && task.createdAt < end
            let dueIn = task.dueDate.map { $0 >= start && $0 < end } ?? false
            return createdIn || dueIn
        }
        let completed = tasks.filter(\.isCompleted).count
        return TaskPeriodStats(
            periodStart: start,
            periodEnd: end,
            planned: tasks.count,
            completed: completed,
            incomplete: tasks.count - completed
        )
    }

    private func applyLists() {
        incompleteTasks = filteredIncompleteTasks()
        completedTasks = allCompleted
        updateTitle()
    }

    private func filteredIncompleteTasks() -> [DeskTask] {
        switch viewMode {
        case .incomplete, .history:
            return allIncomplete
        case .today:
            let today = Date()
            return allIncomplete.filter { task in
                calendar.isDate(task.createdAt, inSameDayAs: today)
                    || (task.dueDate.map { calendar.isDate($0, inSameDayAs: today) } ?? false)
            }
        }
    }

    private func updateTitle() {
        switch viewMode {
        case .incomplete, .today:
            let count = incompleteTasks.count
            displayTitle = count == 0 ? "待办" : "待办（\(count) 项）"
        case .history:
            displayTitle = "历史"
        }
    }

    private func scheduleDayBoundaryRefresh() {
        dayBoundaryTimer?.invalidate()
        guard let nextMidnight = calendar.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 5),
            matchingPolicy: .nextTime
        ) else { return }

        let interval = nextMidnight.timeIntervalSinceNow
        dayBoundaryTimer = Timer.scheduledTimer(withTimeInterval: max(interval, 60), repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshFromServer()
                self?.scheduleDayBoundaryRefresh()
            }
        }
    }
}
