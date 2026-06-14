import Combine
import Foundation
import NotesWidgetCore
import WidgetKit

@MainActor
final class SyncViewModel: ObservableObject {
    @Published var folders: [NotesFolder] = []
    @Published var selectedFolder: NotesFolder? {
        didSet {
            HostSettings.selectedFolderID = selectedFolder?.id
            if selectedFolder?.id != oldValue?.id {
                Task { await sync() }
            }
        }
    }
    @Published var statusMessage: String?

    private let watcher = NotesWatcher()
    private var pollTask: Task<Void, Never>?
    private var lastContentFingerprint: String?

    init() {
        if let savedID = HostSettings.selectedFolderID {
            selectedFolder = NotesFolder(id: savedID)
        }
    }

    func start() {
        watcher.start { [weak self] in
            Task { @MainActor in
                await self?.sync()
            }
        }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(AppConstants.hostSyncPollInterval))
                await self?.sync()
            }
        }
        Task {
            await loadFolders()
            await sync()
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        watcher.stop()
    }

    func loadFolders() async {
        guard SharedStore.isAvailable else {
            statusMessage = "App Group 不可用，请用 Xcode 签名运行 Host。"
            return
        }

        do {
            folders = try NotesReader.listFolders()
            SharedStore.saveFolders(folders)
            resolveSelectedFolder()
            if folders.isEmpty {
                statusMessage = "未读取到文件夹，请在 系统设置 → 自动化 中允许 NotesDeskWidget 控制「备忘录」。"
            } else {
                statusMessage = "已加载 \(folders.count) 个文件夹，Widget 可选。"
            }
            reloadWidgets()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func sync() async {
        guard let folder = selectedFolder else {
            statusMessage = "请选择一个文件夹。"
            reloadWidgets()
            return
        }

        let snapshot: NoteSnapshot
        do {
            let note = try NotesReader.fetchFirstNote(in: folder)
            snapshot = NoteSnapshot.success(folder: folder, note: note)
            statusMessage = "已同步：\(note.displayTitle)"
        } catch {
            snapshot = NoteSnapshot.failure(folder: folder, message: error.localizedDescription)
            statusMessage = error.localizedDescription
        }

        publishSnapshot(snapshot)
    }

    private func publishSnapshot(_ snapshot: NoteSnapshot) {
        SharedStore.saveSnapshot(snapshot)
        SharedStore.saveCurrentWidgetSnapshot(snapshot)
        KeychainSnapshotStore.save(snapshot)
        WidgetSnapshotServer.shared.update(snapshot)

        let fingerprint = contentFingerprint(for: snapshot)
        guard fingerprint != lastContentFingerprint else { return }
        lastContentFingerprint = fingerprint
        reloadWidgets()
    }

    private func contentFingerprint(for snapshot: NoteSnapshot) -> String {
        [
            snapshot.folderID,
            snapshot.note.id,
            snapshot.note.title,
            snapshot.note.body,
            snapshot.errorMessage ?? "",
        ].joined(separator: "\u{001F}")
    }

    private func resolveSelectedFolder() {
        if let savedID = HostSettings.selectedFolderID,
           let matched = folders.first(where: { $0.id == savedID }) {
            selectedFolder = matched
            return
        }

        if let saved = selectedFolder,
           let matched = folders.first(where: { $0.account == saved.account && $0.name == saved.name }) {
            selectedFolder = matched
            return
        }

        if let firstWithNotes = folders.first(where: { $0.noteCount > 0 }) {
            selectedFolder = firstWithNotes
            return
        }

        selectedFolder = folders.first
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: "NotesDeskWidget")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
