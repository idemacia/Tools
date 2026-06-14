import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: PanelViewModel

    var body: some View {
        Form {
            Section("显示") {
                Slider(value: $viewModel.panelOpacity, in: 0.6...1.0) {
                    Text("背景透明度")
                }
                Slider(value: $viewModel.fontSize, in: 12...20, step: 1) {
                    Text("字号")
                }
            }

            Section("文件夹") {
                if viewModel.folders.isEmpty {
                    Text("未读取到文件夹，请检查自动化权限。")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("当前文件夹", selection: folderBinding) {
                        ForEach(viewModel.folders) { folder in
                            Text(folder.displayName).tag(Optional(folder))
                        }
                    }
                }
            }

            Section {
                Text("双击浮窗可在系统「备忘录」中打开当前笔记。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 320)
        .padding()
    }

    private var folderBinding: Binding<NotesFolder?> {
        Binding(
            get: { viewModel.selectedFolder },
            set: { viewModel.selectedFolder = $0 }
        )
    }
}
