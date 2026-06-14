import Foundation

public struct NotesFolder: Identifiable, Hashable, Sendable, Codable {
    public let account: String
    public let name: String
    public let noteCount: Int

    public var id: String { "\(account)\u{001F}\(name)" }

    public var displayName: String {
        if noteCount > 0 {
            return "\(account) / \(name)（\(noteCount)）"
        }
        return "\(account) / \(name)"
    }

    public init(account: String, name: String, noteCount: Int = 0) {
        self.account = account
        self.name = name
        self.noteCount = noteCount
    }

    public init?(id: String) {
        let parts = id.split(separator: "\u{001F}", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        account = parts[0]
        name = parts[1]
        noteCount = 0
    }
}
