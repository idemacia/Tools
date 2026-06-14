import CoreFoundation
import Foundation

public enum SharedStore {
    private enum Key {
        static let folders = "foldersJSON"
        static let snapshots = "snapshotsByFolderJSON"
        static let selectedFolderID = "selectedFolderID"
        static let widgetCurrent = "widgetCurrentJSON"
    }

    private enum FileName {
        static let folders = "folders.json"
        static let snapshots = "snapshots.json"
        static let selectedFolderID = "selectedFolderID.txt"
        static let widgetCurrent = "widget-current.json"
    }

    public static var containerURL: URL? {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupID) {
            return url
        }
        let fallback = groupContainerDirectory
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: fallback.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return fallback
        }
        return nil
    }

    private static var groupContainerDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers/\(AppConstants.appGroupID)", isDirectory: true)
    }

    public static var isAvailable: Bool {
        containerURL != nil
    }

    public static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppConstants.appGroupID)
    }

    public static func saveFolders(_ folders: [NotesFolder]) {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        writeFile(data, named: FileName.folders)
        writePreference(data, forKey: Key.folders)
    }

    public static func loadFolders() -> [NotesFolder] {
        if let data = readPreferenceData(forKey: Key.folders),
           let folders = try? JSONDecoder().decode([NotesFolder].self, from: data) {
            return folders
        }
        if let data = readFile(named: FileName.folders),
           let folders = try? JSONDecoder().decode([NotesFolder].self, from: data) {
            return folders
        }
        return []
    }

    public static func saveSnapshot(_ snapshot: NoteSnapshot) {
        var map = loadAllSnapshots()
        map[snapshot.folderID] = snapshot
        guard let data = try? JSONEncoder().encode(map) else { return }
        writeFile(data, named: FileName.snapshots)
        writePreference(data, forKey: Key.snapshots)
    }

    /// Widget 优先读取此快照（单文件，扩展进程更可靠）。
    public static func saveCurrentWidgetSnapshot(_ snapshot: NoteSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        writeFile(data, named: FileName.widgetCurrent)
        writePreference(data, forKey: Key.widgetCurrent)
    }

    public static func loadCurrentWidgetSnapshot() -> NoteSnapshot? {
        if let data = readPreferenceData(forKey: Key.widgetCurrent),
           let snapshot = try? JSONDecoder().decode(NoteSnapshot.self, from: data) {
            return snapshot
        }
        if let data = readFile(named: FileName.widgetCurrent),
           let snapshot = try? JSONDecoder().decode(NoteSnapshot.self, from: data) {
            return snapshot
        }
        return nil
    }

    public static func loadSnapshot(for folderID: String?) -> NoteSnapshot? {
        guard let folderID, !folderID.isEmpty else { return nil }
        return loadAllSnapshots()[folderID]
    }

    public static func loadAllSnapshots() -> [String: NoteSnapshot] {
        if let data = readPreferenceData(forKey: Key.snapshots),
           let map = try? JSONDecoder().decode([String: NoteSnapshot].self, from: data) {
            return map
        }
        if let data = readFile(named: FileName.snapshots),
           let map = try? JSONDecoder().decode([String: NoteSnapshot].self, from: data) {
            return map
        }
        return [:]
    }

    public static var selectedFolderID: String? {
        get {
            if let data = readFile(named: FileName.selectedFolderID),
               let value = String(data: data, encoding: .utf8),
               !value.isEmpty {
                return value
            }
            if let value = readPreferenceString(forKey: Key.selectedFolderID), !value.isEmpty {
                return value
            }
            return defaults?.string(forKey: Key.selectedFolderID)
        }
        set {
            if let newValue {
                writeFile(Data(newValue.utf8), named: FileName.selectedFolderID)
                writePreference(Data(newValue.utf8), forKey: Key.selectedFolderID)
            } else {
                deleteFile(named: FileName.selectedFolderID)
                CFPreferencesSetValue(
                    Key.selectedFolderID as CFString,
                    nil,
                    AppConstants.appGroupID as CFString,
                    kCFPreferencesAnyUser,
                    kCFPreferencesCurrentHost
                )
                CFPreferencesAppSynchronize(AppConstants.appGroupID as CFString)
                defaults?.removeObject(forKey: Key.selectedFolderID)
                defaults?.synchronize()
            }
        }
    }

    private static func fileURL(named name: String) -> URL? {
        containerURL?.appendingPathComponent(name, isDirectory: false)
    }

    private static func writeFile(_ data: Data, named name: String) {
        if let url = fileURL(named: name) {
            try? data.write(to: url, options: .atomic)
        }
        let fallbackURL = groupContainerDirectory.appendingPathComponent(name, isDirectory: false)
        try? data.write(to: fallbackURL, options: .atomic)
    }

    private static func readFile(named name: String) -> Data? {
        if let url = fileURL(named: name), let data = try? Data(contentsOf: url) {
            return data
        }
        let fallbackURL = groupContainerDirectory.appendingPathComponent(name, isDirectory: false)
        return try? Data(contentsOf: fallbackURL)
    }

    private static func deleteFile(named name: String) {
        if let url = fileURL(named: name) {
            try? FileManager.default.removeItem(at: url)
        }
        let fallbackURL = groupContainerDirectory.appendingPathComponent(name, isDirectory: false)
        try? FileManager.default.removeItem(at: fallbackURL)
    }

    private static func writePreference(_ data: Data, forKey key: String) {
        defaults?.set(data, forKey: key)
        defaults?.synchronize()
        CFPreferencesSetValue(
            key as CFString,
            data as CFPropertyList,
            AppConstants.appGroupID as CFString,
            kCFPreferencesAnyUser,
            kCFPreferencesCurrentHost
        )
        CFPreferencesAppSynchronize(AppConstants.appGroupID as CFString)
    }

    private static func readPreferenceData(forKey key: String) -> Data? {
        if let value = CFPreferencesCopyAppValue(key as CFString, AppConstants.appGroupID as CFString) {
            return value as? Data
        }
        return defaults?.data(forKey: key)
    }

    private static func readPreferenceString(forKey key: String) -> String? {
        if let data = readPreferenceData(forKey: key) {
            return String(data: data, encoding: .utf8)
        }
        return defaults?.string(forKey: key)
    }
}
