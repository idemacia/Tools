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
    @Published var settingsTab: SettingsTab = .connection
    @Published var filterDate: String? = nil
    @Published var searchQuery: String = ""
    @Published var commentsTask: DeskTask? = nil
    /// 当前月历月份内的色点标记
    @Published var calendarMarks = CalendarDayMarks()
    @Published var commentCounts: [String: Int] = [:]
    private var calendarMonth: String = String(StatsDateHelper.dayString().prefix(7))
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

            let viewParam = viewMode == .today && filterDate == nil ? "today" : nil
            let q = searchQuery.isEmpty ? nil : searchQuery
            var counts: [String: Int] = [:]
            if let q {
                // 有搜索词：全库搜索（含已完成），忽略日期与「今日」视图
                let res = try await api.listTasks(q: q, includeCompleted: true)
                allIncomplete = res.tasks.filter { !$0.isCompleted }
                allCompleted = res.tasks.filter(\.isCompleted)
                counts = res.commentCounts
            } else if let filterDate {
                let res = try await api.listTasks(
                    date: filterDate,
                    includeCompleted: true
                )
                allIncomplete = res.tasks.filter { !$0.isCompleted }
                allCompleted = res.tasks.filter(\.isCompleted)
                counts = res.commentCounts
            } else {
                let incompleteRes = try await api.listTasks(
                    view: viewParam,
                    status: "incomplete"
                )
                allIncomplete = incompleteRes.tasks
                counts = incompleteRes.commentCounts
                let completedLimit = viewMode == .history ? 200 : 30
                let completedRes = try await api.listTasks(status: "completed")
                allCompleted = Array(
                    completedRes.tasks
                        .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
                        .prefix(completedLimit)
                )
                for (k, v) in completedRes.commentCounts { counts[k] = v }
            }
            commentCounts = counts
            applyLists()
            await loadCalendarDays(month: calendarMonth)
        } catch {
            serverConnected = false
            bridgeConnected = false
            statusMessage = error.localizedDescription
        }
    }

    func setCalendarMonth(_ month: String) {
        guard month != calendarMonth else { return }
        calendarMonth = month
        Task { await loadCalendarDays(month: month) }
    }

    private func loadCalendarDays(month: String) async {
        guard AppSettings.isConfigured else { return }
        do {
            calendarMarks = try await api.calendarDays(month: month)
        } catch {
            // 月历色点失败不阻断列表
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

    func dailyStats(on day: Date = Date()) -> LocalDailyStats {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let tasks = (allIncomplete + allCompleted).filter { task in
            let createdIn = task.createdAt >= start && task.createdAt < end
            let dueIn = task.dueDate.map { $0 >= start && $0 < end } ?? false
            return createdIn || dueIn
        }
        let completed = tasks.filter(\.isCompleted).count
        return LocalDailyStats(
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
        // 搜索结果已是全库命中，勿再按「今日」裁剪
        if !searchQuery.isEmpty {
            return allIncomplete
        }
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
        if !searchQuery.isEmpty {
            let count = incompleteTasks.count + completedTasks.count
            displayTitle = "搜索「\(searchQuery)」（\(count)）"
            return
        }
        if let filterDate {
            let count = incompleteTasks.count + completedTasks.count
            displayTitle = "\(filterDate)（\(count)）"
            return
        }
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
