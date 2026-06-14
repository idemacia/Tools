import Foundation

enum NotesOpener {
    static func open(noteID: String) {
        guard !noteID.isEmpty else { return }

        let escapedID = noteID
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "Notes"
            activate
            show note id "\(escapedID)"
        end tell
        """

        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
    }
}
