import ApplicationServices
import Foundation

public enum NotesReader {
    private static let fieldSeparator = "\u{001E}"
    private static let folderFieldSeparator = "\u{001F}"

    public static func listFolders() throws -> [NotesFolder] {
        let script = """
        tell application "Notes"
            set rows to {}
            repeat with acc in accounts
                set accName to name of acc as text
                repeat with f in folders of acc
                    set folderName to name of f as text
                    set noteCount to count of notes of f
                    set end of rows to accName & "\(folderFieldSeparator)" & folderName & "\(folderFieldSeparator)" & (noteCount as text)
                end repeat
            end repeat
            return rows
        end tell
        """

        let rows = try runAppleScriptReturningList(script)
        return rows.compactMap(parseFolderRow)
            .sorted { lhs, rhs in
                if lhs.noteCount != rhs.noteCount {
                    return lhs.noteCount > rhs.noteCount
                }
                if lhs.account != rhs.account {
                    return lhs.account.localizedCaseInsensitiveCompare(rhs.account) == .orderedAscending
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    public static func fetchFirstNote(in folder: NotesFolder) throws -> NotePreview {
        let escapedAccount = escapeAppleScriptString(folder.account)
        let escapedFolder = escapeAppleScriptString(folder.name)
        let script = """
        tell application "Notes"
            set targetAccount to missing value
            repeat with acc in accounts
                if name of acc is "\(escapedAccount)" then
                    set targetAccount to acc
                    exit repeat
                end if
            end repeat

            if targetAccount is missing value then
                return "ACCOUNT_NOT_FOUND"
            end if

            set targetFolder to missing value
            repeat with f in folders of targetAccount
                if name of f is "\(escapedFolder)" then
                    set targetFolder to f
                    exit repeat
                end if
            end repeat

            if targetFolder is missing value then
                return "FOLDER_NOT_FOUND"
            end if

            if (count of notes of targetFolder) is 0 then
                return "EMPTY_FOLDER"
            end if

            set theNote to item 1 of notes of targetFolder
            set noteTitle to name of theNote
            set noteBody to plaintext of theNote
            set noteId to id of theNote as text
            return noteId & "\(fieldSeparator)" & noteTitle & "\(fieldSeparator)" & noteBody
        end tell
        """

        let raw = try runAppleScriptReturningString(script)

        if raw == "ACCOUNT_NOT_FOUND" {
            throw NotesReaderError.folderNotFound("\(folder.account) / \(folder.name)")
        }
        if raw == "FOLDER_NOT_FOUND" {
            throw NotesReaderError.folderNotFound(folder.displayName)
        }
        if raw == "EMPTY_FOLDER" {
            throw NotesReaderError.emptyFolder(folder.displayName)
        }

        let parts = raw.components(separatedBy: fieldSeparator)
        guard parts.count >= 3 else {
            throw NotesReaderError.invalidResponse
        }

        return NotePreview(
            id: parts[0],
            title: parts[1],
            body: parts.dropFirst(2).joined(separator: fieldSeparator)
        )
    }

    private static func parseFolderRow(_ row: String) -> NotesFolder? {
        let parts = row.components(separatedBy: folderFieldSeparator)
        guard parts.count == 3, let noteCount = Int(parts[2]) else {
            return nil
        }
        return NotesFolder(account: parts[0], name: parts[1], noteCount: noteCount)
    }

    private static func runAppleScriptReturningString(_ source: String) throws -> String {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw NotesReaderError.scriptFailed("无法创建 AppleScript。")
        }

        let output = script.executeAndReturnError(&error)
        if let error {
            let message = (error[NSAppleScript.errorMessage] as? String) ?? "AppleScript 执行失败。"
            if message.localizedCaseInsensitiveContains("not authorized")
                || message.localizedCaseInsensitiveContains("权限")
                || message.localizedCaseInsensitiveContains("assist") {
                throw NotesReaderError.automationDenied
            }
            throw NotesReaderError.scriptFailed(message)
        }

        guard let value = output.stringValue else {
            throw NotesReaderError.invalidResponse
        }
        return value
    }

    private static func runAppleScriptReturningList(_ source: String) throws -> [String] {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw NotesReaderError.scriptFailed("无法创建 AppleScript。")
        }

        let output = script.executeAndReturnError(&error)
        if let error {
            let message = (error[NSAppleScript.errorMessage] as? String) ?? "AppleScript 执行失败。"
            if message.localizedCaseInsensitiveContains("not authorized")
                || message.localizedCaseInsensitiveContains("权限")
                || message.localizedCaseInsensitiveContains("assist") {
                throw NotesReaderError.automationDenied
            }
            throw NotesReaderError.scriptFailed(message)
        }

        guard let descriptor = output.coerce(toDescriptorType: typeAEList) else {
            return []
        }

        var items: [String] = []
        for index in 1...descriptor.numberOfItems {
            if let item = descriptor.atIndex(index)?.stringValue {
                items.append(item)
            }
        }
        return items
    }

    private static func escapeAppleScriptString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
