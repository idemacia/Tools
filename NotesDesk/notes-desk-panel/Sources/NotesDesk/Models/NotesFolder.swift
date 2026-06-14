import Foundation

struct NotesFolder: Identifiable, Hashable, Sendable {
    let account: String
    let name: String
    let noteCount: Int

    var id: String { "\(account)\u{001F}\(name)" }

    var displayName: String {
        if noteCount > 0 {
            return "\(account) / \(name)（\(noteCount)）"
        }
        return "\(account) / \(name)"
    }

    init(account: String, name: String, noteCount: Int = 0) {
        self.account = account
        self.name = name
        self.noteCount = noteCount
    }

    init?(id: String) {
        let parts = id.split(separator: "\u{001F}", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        account = parts[0]
        name = parts[1]
        noteCount = 0
    }
}
