import AppKit
import NotesWidgetCore
import SwiftUI

@main
struct NotesWidgetHostApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("NotesWidget", systemImage: "note.text") {
            MenuContentView(viewModel: appDelegate.viewModel)
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuContentView: View {
    @ObservedObject var viewModel: SyncViewModel

    var body: some View {
        Group {
            if let status = viewModel.statusMessage {
                Text(status)
                    .font(.caption)
            }

            if viewModel.folders.isEmpty {
                Text("未读取到文件夹")
                Text("请在 系统设置 → 自动化 中允许 NotesDeskWidget 控制「备忘录」，然后点「重新加载文件夹列表」。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Menu("文件夹：\(viewModel.selectedFolder?.displayName ?? "未选择")") {
                    ForEach(viewModel.folders) { folder in
                        Button(folder.displayName) {
                            viewModel.selectedFolder = folder
                        }
                    }
                }
            }

            Button("立即同步并刷新 Widget") {
                Task { await viewModel.sync() }
            }

            Button("重新加载文件夹列表") {
                Task { await viewModel.loadFolders() }
            }

            Button("打开自动化设置…") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                    NSWorkspace.shared.open(url)
                }
            }

            Divider()

            Text("请保持此应用在后台运行，Widget 才能自动同步。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Widget 显示此处所选文件夹，无需在小组件里再选。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("退出 NotesWidgetHost") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = SyncViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        viewModel.start()
        WidgetSnapshotServer.shared.start()
        print("NotesWidgetHost 已启动。")
        print("→ 菜单栏点击 note.text 图标可管理同步。")
        print("→ 若文件夹为空，请在 系统设置 → 自动化 中允许控制「备忘录」。")
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard url.scheme == AppConstants.urlScheme, url.host == "open" else { continue }
            guard let noteID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "noteID" })?
                .value
            else { continue }
            NotesOpener.open(noteID: noteID)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.stop()
        WidgetSnapshotServer.shared.stop()
    }
}
