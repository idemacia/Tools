import Foundation
import WidgetKit

struct NotesWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: NoteSnapshot
}

struct NotesWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> NotesWidgetEntry {
        NotesWidgetEntry(date: Date(), snapshot: .placeholder(message: "加载中…"))
    }

    func getSnapshot(in context: Context, completion: @escaping (NotesWidgetEntry) -> Void) {
        Task {
            completion(await makeEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NotesWidgetEntry>) -> Void) {
        Task {
            let entry = await makeEntry()
            let nextUpdate = Date().addingTimeInterval(AppConstants.widgetTimelineRefreshInterval)
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    private func makeEntry() async -> NotesWidgetEntry {
        if AppConstants.widgetUseHardcodedTestData {
            return NotesWidgetEntry(date: Date(), snapshot: hardcodedTestSnapshot())
        }

        // macOS Widget 扩展进程常无法读 App Group，依次尝试 localhost / Keychain
        if let snapshot = await WidgetSnapshotFetcher.fetchFromHost() {
            return NotesWidgetEntry(date: Date(), snapshot: snapshot)
        }

        if let snapshot = KeychainSnapshotStore.load() {
            return NotesWidgetEntry(date: Date(), snapshot: snapshot)
        }

        if let snapshot = SharedStore.loadCurrentWidgetSnapshot() {
            return NotesWidgetEntry(date: Date(), snapshot: snapshot)
        }

        let snapshots = SharedStore.loadAllSnapshots()

        if let hostFolderID = SharedStore.selectedFolderID, let snapshot = snapshots[hostFolderID] {
            return NotesWidgetEntry(date: Date(), snapshot: snapshot)
        }

        if let snapshot = snapshots.values.first(where: { $0.errorMessage == nil && !$0.note.body.isEmpty }) {
            return NotesWidgetEntry(date: Date(), snapshot: snapshot)
        }

        return NotesWidgetEntry(
            date: Date(),
            snapshot: .placeholder(message: "请保持 Host 运行，并在菜单栏点「立即同步并刷新 Widget」。")
        )
    }

    private func hardcodedTestSnapshot() -> NoteSnapshot {
        NoteSnapshot(
            folderID: "iCloud\u{001F}Notes",
            folderDisplayName: "iCloud / Notes（35）【测试数据】",
            note: NotePreview(
                id: "debug-note-id",
                title: "更新学习计划",
                body: "这是一条写死的测试备忘录。"
            ),
            updatedAt: Date(),
            errorMessage: nil
        )
    }
}
