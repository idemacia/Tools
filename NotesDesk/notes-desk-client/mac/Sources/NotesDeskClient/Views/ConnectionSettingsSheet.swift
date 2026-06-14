import SwiftUI

struct ConnectionSettingsSheet: View {
    @ObservedObject var viewModel: DeskViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var serverURL = AppSettings.serverBaseURL
    @State private var apiToken = AppSettings.apiToken
    @State private var feedback = ""
    @State private var feedbackIsError = false
    @State private var isTesting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("设置")
                        .font(.headline)
                    Spacer()
                    Button("完成") { dismiss() }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("NAS 服务器")
                        .font(.subheadline.weight(.semibold))

                    Text("连接 notes-desk-server，钉钉桥与提醒在 NAS 端运行。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    labeledField("服务器地址", text: $serverURL, prompt: "http://192.168.1.100:8080")
                    labeledField("API Token（可选）", text: $apiToken, prompt: "对应 NOTESDESK_TOKEN")

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

                        Button("保存") {
                            saveAndRefresh()
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if !feedback.isEmpty {
                        Text(feedback)
                            .font(.caption)
                            .foregroundStyle(feedbackIsError ? .red : .green)
                    }
                }

                Divider()

                Toggle("关闭浮窗时退出程序", isOn: $viewModel.quitOnClosePanel)

                Text("默认关闭浮窗仅隐藏窗口，程序仍在菜单栏运行。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                let stats = viewModel.dailyStats()
                Text("今日统计")
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 16) {
                    statItem("应做", stats.planned)
                    statItem("已完成", stats.completed)
                    statItem("未完成", stats.incomplete)
                }
                .font(.caption)
            }
            .padding(20)
        }
        .frame(width: 420, height: 480)
    }

    private func labeledField(_ title: String, text: Binding<String>, prompt: String = "") -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(prompt, text: text).textFieldStyle(.roundedBorder)
        }
    }

    private func testConnection() async {
        isTesting = true
        defer { isTesting = false }
        let prevURL = AppSettings.serverBaseURL
        let prevToken = AppSettings.apiToken
        AppSettings.serverBaseURL = serverURL
        AppSettings.apiToken = apiToken
        do {
            let health = try await NasApiClient.shared.health()
            feedback = health.ok
                ? (health.bridge ? "连接成功 · 钉钉桥在线" : "连接成功 · 钉钉桥未启动")
                : "服务器返回异常"
            feedbackIsError = !health.ok
        } catch {
            feedback = error.localizedDescription
            feedbackIsError = true
        }
        AppSettings.serverBaseURL = prevURL
        AppSettings.apiToken = prevToken
    }

    private func saveAndRefresh() {
        AppSettings.serverBaseURL = serverURL
        AppSettings.apiToken = apiToken
        feedback = "已保存"
        feedbackIsError = false
        Task { await viewModel.refreshFromServer() }
    }

    private func statItem(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.title3.monospacedDigit())
            Text(title).foregroundStyle(.secondary)
        }
    }
}
