import SwiftUI

struct SettingsSheet: View {
    @ObservedObject var viewModel: DeskViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("设置")
                    .font(.headline)
                Spacer()
                Button("完成") { dismiss() }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Picker("分区", selection: $viewModel.settingsTab) {
                ForEach(SettingsTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            Group {
                switch viewModel.settingsTab {
                case .connection:
                    ConnectionSettingsContent(viewModel: viewModel)
                case .llm:
                    LlmSettingsContent()
                case .schedule:
                    ScheduleSettingsContent()
                case .stats:
                    ServerStatsContent()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 520, height: 640)
    }
}

// MARK: - Connection

private struct ConnectionSettingsContent: View {
    @ObservedObject var viewModel: DeskViewModel

    @State private var serverURL = AppSettings.serverBaseURL
    @State private var apiToken = AppSettings.apiToken
    @State private var webUsername = AppSettings.webUsername
    @State private var webPassword = AppSettings.webPassword
    @State private var feedback = ""
    @State private var feedbackIsError = false
    @State private var isTesting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("NAS 服务器")
                        .font(.subheadline.weight(.semibold))
                    Text("连接 notes-desk-server，钉钉桥与提醒在 NAS 端运行。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    SettingsField("服务器地址", text: $serverURL, prompt: "http://192.168.1.100:8080")
                    Text("Web 登录（与浏览器相同，默认 admin / admin）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SettingsField("用户名", text: $webUsername, prompt: "admin")
                    SettingsSecureField("密码", text: $webPassword)
                    SettingsField("API Token（可选）", text: $apiToken, prompt: "Docker 环境变量 NOTESDESK_TOKEN")

                    HStack {
                        Button {
                            Task { await testConnection() }
                        } label: {
                            if isTesting {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("测试连接")
                            }
                        }
                        .disabled(isTesting)
                        Button("保存") { saveAndRefresh() }
                            .buttonStyle(.borderedProminent)
                    }
                    SettingsFeedback(text: feedback, isError: feedbackIsError)
                }

                Divider()

                Toggle("关闭浮窗时退出程序", isOn: $viewModel.quitOnClosePanel)
                Text("默认关闭浮窗仅隐藏窗口，程序仍在菜单栏运行。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                let stats = viewModel.dailyStats()
                Text("今日统计（本地估算）")
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 16) {
                    StatChip("应做", stats.planned)
                    StatChip("已完成", stats.completed)
                    StatChip("未完成", stats.incomplete)
                }
                Text("完整周/月/年统计请切换到「统计分析」。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
    }

    private func testConnection() async {
        isTesting = true
        defer { isTesting = false }
        let backup = authBackup()
        applyDraft()
        AppSettings.sessionCookie = ""
        defer { restoreAuth(backup) }
        await runAuthTest()
    }

    private func saveAndRefresh() {
        applyDraft()
        AppSettings.sessionCookie = ""
        feedback = "已保存，正在登录…"
        feedbackIsError = false
        Task {
            do {
                if apiToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    try await NasApiClient.shared.login(username: webUsername, password: webPassword)
                }
                feedback = "已保存并登录"
                await viewModel.refreshFromServer()
            } catch {
                feedback = error.localizedDescription
                feedbackIsError = true
            }
        }
    }

    private func runAuthTest() async {
        do {
            let health = try await NasApiClient.shared.health()
            if apiToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try await NasApiClient.shared.login(username: webUsername, password: webPassword)
            }
            _ = try await NasApiClient.shared.listTasks(status: "incomplete")
            feedback = health.ok
                ? (health.bridge ? "连接成功 · 已登录 · 钉钉桥在线" : "连接成功 · 已登录 · 钉钉桥未启动")
                : "服务器返回异常"
            feedbackIsError = !health.ok
        } catch {
            feedback = error.localizedDescription
            feedbackIsError = true
        }
    }

    private func applyDraft() {
        AppSettings.serverBaseURL = serverURL
        AppSettings.apiToken = apiToken
        AppSettings.webUsername = webUsername
        AppSettings.webPassword = webPassword
    }

    private struct AuthBackup {
        let url, token, user, pass, session: String
    }

    private func authBackup() -> AuthBackup {
        AuthBackup(
            url: AppSettings.serverBaseURL,
            token: AppSettings.apiToken,
            user: AppSettings.webUsername,
            pass: AppSettings.webPassword,
            session: AppSettings.sessionCookie
        )
    }

    private func restoreAuth(_ b: AuthBackup) {
        AppSettings.serverBaseURL = b.url
        AppSettings.apiToken = b.token
        AppSettings.webUsername = b.user
        AppSettings.webPassword = b.pass
        AppSettings.sessionCookie = b.session
    }
}

// MARK: - LLM

private struct LlmSettingsContent: View {
    @State private var enabled = false
    @State private var baseUrl = "https://api.openai.com/v1"
    @State private var apiKey = ""
    @State private var model = "gpt-4o-mini"
    @State private var hasApiKey = false
    @State private var feedback = ""
    @State private var feedbackIsError = false
    @State private var isBusy = false
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("AI 大模型（周/月/年分析）")
                    .font(.subheadline.weight(.semibold))
                Text("配置保存在 NAS 服务端，与 Web 管理页同步。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("启用 AI 分析", isOn: $enabled)
                SettingsField("API Base URL", text: $baseUrl, prompt: "https://api.openai.com/v1")
                SettingsSecureField(
                    "API Key",
                    text: $apiKey,
                    prompt: hasApiKey ? "已保存，留空则不修改" : ""
                )
                SettingsField("模型", text: $model, prompt: "gpt-4o-mini")

                HStack {
                    Button("测试连接") { Task { await testLlm() } }
                        .disabled(isBusy)
                    Button("保存") { Task { await saveLlm() } }
                        .buttonStyle(.borderedProminent)
                        .disabled(isBusy)
                }
                SettingsFeedback(text: feedback, isError: feedbackIsError)
            }
            .padding(20)
        }
        .task { await load() }
    }

    private func load() async {
        guard !loaded else { return }
        do {
            let cfg = try await NasApiClient.shared.getLlmConfig()
            enabled = cfg.enabled
            baseUrl = cfg.baseUrl
            model = cfg.model
            hasApiKey = cfg.hasApiKey ?? false
            apiKey = ""
            loaded = true
        } catch {
            feedback = error.localizedDescription
            feedbackIsError = true
        }
    }

    private func saveLlm() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let cfg = try await NasApiClient.shared.saveLlmConfig(
                enabled: enabled,
                provider: "openai",
                baseUrl: baseUrl,
                apiKey: apiKey,
                model: model,
                maxTokens: 2048,
                temperature: 0.3
            )
            hasApiKey = cfg.hasApiKey ?? hasApiKey
            apiKey = ""
            feedback = "AI 配置已保存"
            feedbackIsError = false
        } catch {
            feedback = error.localizedDescription
            feedbackIsError = true
        }
    }

    private func testLlm() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let msg = try await NasApiClient.shared.testLlm(
                baseUrl: baseUrl,
                apiKey: apiKey.isEmpty ? nil : apiKey,
                model: model
            )
            feedback = msg
            feedbackIsError = false
        } catch {
            feedback = error.localizedDescription
            feedbackIsError = true
        }
    }
}

// MARK: - Schedule

private struct ScheduleSettingsContent: View {
    @State private var settings = ServerAppSettings.defaults
    @State private var feedback = ""
    @State private var feedbackIsError = false
    @State private var isBusy = false
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("AI 分析定时与推送")
                    .font(.subheadline.weight(.semibold))
                Text("定时任务在服务器本地时间（Asia/Shanghai）整点检查；分析完成后可推送到钉钉。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("启用定时 AI 分析", isOn: $settings.analysisScheduleEnabled)
                Toggle("分析完成后推送钉钉（含手动触发）", isOn: $settings.analysisPushToDingTalk)

                Divider()

                Toggle("周分析", isOn: $settings.weeklyAnalysisEnabled)
                HStack {
                    Text("星期")
                    Picker("", selection: $settings.weeklyAnalysisWeekday) {
                        ForEach(0 ..< 7, id: \.self) { i in
                            Text("周\(StatsDateHelper.weekdayLabels[i])").tag(i)
                        }
                    }
                    .labelsHidden()
                    Stepper("时 \(settings.weeklyAnalysisHour)", value: $settings.weeklyAnalysisHour, in: 0 ... 23)
                }
                .font(.caption)

                Toggle("月分析", isOn: $settings.monthlyAnalysisEnabled)
                HStack {
                    Stepper("每月 \(settings.monthlyAnalysisDay) 日", value: $settings.monthlyAnalysisDay, in: 1 ... 28)
                    Stepper("\(settings.monthlyAnalysisHour) 时", value: $settings.monthlyAnalysisHour, in: 0 ... 23)
                }
                .font(.caption)

                Toggle("年分析", isOn: $settings.yearlyAnalysisEnabled)
                HStack {
                    Stepper("\(settings.yearlyAnalysisMonth) 月", value: $settings.yearlyAnalysisMonth, in: 1 ... 12)
                    Stepper("\(settings.yearlyAnalysisDay) 日", value: $settings.yearlyAnalysisDay, in: 1 ... 28)
                    Stepper("\(settings.yearlyAnalysisHour) 时", value: $settings.yearlyAnalysisHour, in: 0 ... 23)
                }
                .font(.caption)

                Divider()

                Text("钉钉提醒")
                    .font(.subheadline.weight(.medium))
                Toggle("启用钉钉提醒", isOn: $settings.remindersEnabled)
                HStack {
                    Text("延迟 \(String(format: "%.1f", settings.reminderDelayHours)) 小时")
                    Slider(value: $settings.reminderDelayHours, in: 0.1 ... 24, step: 0.1)
                }
                .font(.caption)

                Button("保存设置") { Task { await save() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(isBusy)
                SettingsFeedback(text: feedback, isError: feedbackIsError)
            }
            .padding(20)
        }
        .task { await load() }
    }

    private func load() async {
        guard !loaded else { return }
        do {
            settings = try await NasApiClient.shared.getServerSettings()
            loaded = true
        } catch {
            feedback = error.localizedDescription
            feedbackIsError = true
        }
    }

    private func save() async {
        isBusy = true
        defer { isBusy = false }
        do {
            settings = try await NasApiClient.shared.saveServerSettings(settings)
            feedback = "分析设置已保存"
            feedbackIsError = false
        } catch {
            feedback = error.localizedDescription
            feedbackIsError = true
        }
    }
}

// MARK: - Stats

private struct ServerStatsContent: View {
    @State private var period: StatsPeriod = .week
    @State private var year = StatsDateHelper.year()
    @State private var week = StatsDateHelper.isoWeek()
    @State private var month = StatsDateHelper.month()
    @State private var stats: ServerPeriodStats?
    @State private var analysis: AnalysisResult?
    @State private var periodLabel = ""
    @State private var pushed: Bool?
    @State private var feedback = ""
    @State private var feedbackIsError = false
    @State private var statsLoading = false
    @State private var analyzeLoading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("统计分析")
                    .font(.subheadline.weight(.semibold))
                Text("手动运行 AI 分析并推送钉钉；定时分析在「分析定时」中配置。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Picker("周期", selection: $period) {
                        ForEach(StatsPeriod.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .frame(width: 72)
                    Stepper("年 \(year)", value: $year, in: 2020 ... 2100)
                        .font(.caption)
                }
                if period == .week {
                    Stepper("ISO 周 \(week)", value: $week, in: 1 ... 53)
                        .font(.caption)
                }
                if period == .month {
                    Stepper("月 \(month)", value: $month, in: 1 ... 12)
                        .font(.caption)
                }

                HStack {
                    Button(statsLoading ? "加载中…" : "刷新统计") {
                        Task { await loadStats() }
                    }
                    .disabled(statsLoading || analyzeLoading)
                    Button(analyzeLoading ? "AI 分析中…" : "运行 AI 分析") {
                        Task { await runAnalyze() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(statsLoading || analyzeLoading)
                }

                SettingsFeedback(text: feedback, isError: feedbackIsError)
                if pushed == true {
                    Text("分析报告已推送到钉钉").font(.caption).foregroundStyle(.green)
                }
                if pushed == false, analysis != nil {
                    Text("分析完成，但钉钉推送失败").font(.caption).foregroundStyle(.orange)
                }

                if let stats {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        StatChip("计划", stats.planned)
                        StatChip("完成", stats.completed)
                        StatChip("完成率", "\(Int(stats.completionRate * 100))%")
                        StatChip("逾期", stats.overdue)
                    }
                }

                if let report = analysis?.report {
                    AnalysisReportView(report: report, source: analysis?.source ?? "rules", periodLabel: periodLabel)
                } else if stats != nil, !statsLoading {
                    Text("统计已加载。点击「运行 AI 分析」生成报告。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .task { await loadStats() }
        .onChange(of: period) { _ in Task { await loadStats() } }
        .onChange(of: year) { _ in Task { await loadStats() } }
        .onChange(of: week) { _ in Task { await loadStats() } }
        .onChange(of: month) { _ in Task { await loadStats() } }
    }

    private func loadStats() async {
        statsLoading = true
        defer { statsLoading = false }
        feedback = ""
        do {
            stats = try await NasApiClient.shared.getPeriodStats(
                period: period,
                year: year,
                week: period == .week ? week : nil,
                month: period == .month ? month : nil
            )
            analysis = nil
            pushed = nil
        } catch {
            feedback = error.localizedDescription
            feedbackIsError = true
        }
    }

    private func runAnalyze() async {
        analyzeLoading = true
        defer { analyzeLoading = false }
        feedback = ""
        do {
            let res = try await NasApiClient.shared.runAnalysis(
                period: period,
                year: year,
                week: period == .week ? week : nil,
                month: period == .month ? month : nil
            )
            stats = res.stats
            analysis = res.analysis
            periodLabel = res.periodLabel
            pushed = res.pushed
        } catch {
            feedback = error.localizedDescription
            feedbackIsError = true
        }
    }
}

private struct AnalysisReportView: View {
    let report: AnalysisReport
    let source: String
    let periodLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(report.periodLabel.isEmpty ? periodLabel : report.periodLabel)
                    .font(.caption.weight(.semibold))
                Text("等级 \(report.overview.grade)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())
                Text(source == "llm" ? "AI 生成" : "规则兜底")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(report.overview.headline).font(.subheadline.weight(.semibold))
            Text(report.overview.summary).font(.caption)

            ReportSection("指标解读", report.metricsInterpretation)
            ReportSection("时间浪费", report.wasteAnalysis)
            ReportSection("与上周期对比", report.comparisonWithPrevious)

            if !report.strengths.isEmpty {
                Text("优势").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                ForEach(report.strengths, id: \.self) { Text("• \($0)").font(.caption) }
            }
            if !report.risks.isEmpty {
                Text("风险").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                ForEach(report.risks, id: \.self) { Text("• \($0)").font(.caption) }
            }
            if !report.suggestions.isEmpty {
                Text("改进建议").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                ForEach(report.suggestions) { s in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(s.priorityLabel).font(.caption2)
                                .padding(.horizontal, 4)
                                .background(.quaternary)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            Text(s.action).font(.caption.weight(.medium))
                        }
                        Text(s.reason).font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            ReportSection("下周期重点", report.nextPeriodFocus)
        }
        .padding(.top, 4)
    }
}

private struct ReportSection: View {
    let title: String
    let content: String
    init(_ title: String, _ content: String) {
        self.title = title
        self.content = content
    }
    var body: some View {
        if !content.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Text(content).font(.caption)
            }
        }
    }
}

// MARK: - Shared widgets

private struct SettingsField: View {
    let title: String
    @Binding var text: String
    var prompt = ""
    init(_ title: String, text: Binding<String>, prompt: String = "") {
        self.title = title
        _text = text
        self.prompt = prompt
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(prompt, text: $text).textFieldStyle(.roundedBorder)
        }
    }
}

private struct SettingsSecureField: View {
    let title: String
    @Binding var text: String
    var prompt = ""
    init(_ title: String, text: Binding<String>, prompt: String = "") {
        self.title = title
        _text = text
        self.prompt = prompt
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            SecureField(prompt, text: $text).textFieldStyle(.roundedBorder)
        }
    }
}

private struct SettingsFeedback: View {
    let text: String
    let isError: Bool
    var body: some View {
        if !text.isEmpty {
            Text(text).font(.caption).foregroundStyle(isError ? .red : .green)
        }
    }
}

private struct StatChip: View {
    let title: String
    let value: String
    init(_ title: String, _ value: Int) {
        self.title = title
        self.value = "\(value)"
    }
    init(_ title: String, _ value: String) {
        self.title = title
        self.value = value
    }
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.monospacedDigit())
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
