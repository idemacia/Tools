import AppKit
import SwiftUI

@main
struct NotesDeskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("NotesDesk", systemImage: "note.text") {
            MenuContentView(viewModel: appDelegate.viewModel, appDelegate: appDelegate)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(viewModel: appDelegate.viewModel)
        }
    }
}

private struct MenuContentView: View {
    @ObservedObject var viewModel: PanelViewModel
    let appDelegate: AppDelegate

    var body: some View {
        Group {
            if viewModel.folders.isEmpty {
                Text("未读取到文件夹")
            } else {
                Menu("文件夹：\(viewModel.selectedFolder?.displayName ?? "未选择")") {
                    ForEach(viewModel.folders) { folder in
                        Button(folder.displayName) {
                            viewModel.selectedFolder = folder
                        }
                    }
                }
            }

            Toggle("显示浮窗", isOn: $viewModel.panelVisible)
                .onChange(of: viewModel.panelVisible) { visible in
                    appDelegate.setPanelVisible(visible)
                }

            Button("立即刷新") {
                Task { await viewModel.refresh() }
            }

            Button("重新加载文件夹列表") {
                Task { await viewModel.loadFolders() }
            }

            Divider()

            Button("设置…") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }

            Button("退出 NotesDesk") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = PanelViewModel()
    private var panelController: FloatingPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        bootstrap()
    }

    private func bootstrap() {
        guard panelController == nil else { return }

        let controller = FloatingPanelController(viewModel: viewModel)
        panelController = controller
        controller.applyVisibility(viewModel.panelVisible)
        viewModel.bootstrap()

        print("NotesDesk 已启动。菜单栏图标：note.text；浮窗已显示。")
        print("若浮窗无内容，请在 系统设置 → 隐私与安全性 → 自动化 中允许 NotesDesk 控制「备忘录」。")
    }

    func setPanelVisible(_ visible: Bool) {
        panelController?.applyVisibility(visible)
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.shutdown()
    }
}
