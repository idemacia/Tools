import Combine
import Foundation

@MainActor
final class PanelViewModel: ObservableObject {
    @Published var note = NotePreview.empty
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var folders: [NotesFolder] = []
    @Published var selectedFolder: NotesFolder? {
        didSet {
            AppSettings.selectedFolderID = selectedFolder?.id
            if selectedFolder?.id != oldValue?.id {
                Task { await refresh() }
            }
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

    private let watcher = NotesWatcher()

    init() {
        panelOpacity = AppSettings.panelOpacity
        fontSize = AppSettings.fontSize
        panelVisible = AppSettings.panelVisible
        if let savedID = AppSettings.selectedFolderID {
            selectedFolder = NotesFolder(id: savedID)
        }
    }

    func bootstrap() {
        watcher.start { [weak self] in
            Task { @MainActor in
                await self?.refresh()
            }
        }
        Task {
            await loadFolders()
            await refresh()
        }
    }

    func shutdown() {
        watcher.stop()
    }

    func loadFolders() async {
        do {
            folders = try NotesReader.listFolders()
            resolveSelectedFolder()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        guard let folder = selectedFolder else {
            note = .empty
            errorMessage = folders.isEmpty
                ? "未读取到文件夹，请检查自动化权限。"
                : "请先在菜单栏中选择一个文件夹。"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            note = try NotesReader.fetchFirstNote(in: folder)
            errorMessage = nil
        } catch {
            note = .empty
            errorMessage = error.localizedDescription
        }
    }

    func openInNotes() {
        NotesOpener.open(noteID: note.id)
    }

    private func resolveSelectedFolder() {
        if let savedID = AppSettings.selectedFolderID,
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
}
