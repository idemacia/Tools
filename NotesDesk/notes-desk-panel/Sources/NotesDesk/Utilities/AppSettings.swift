import Foundation

enum AppSettings {
    private enum Key {
        static let selectedFolderID = "selectedFolderID"
        static let selectedFolder = "selectedFolder"
        static let panelOpacity = "panelOpacity"
        static let fontSize = "fontSize"
        static let panelOriginX = "panelOriginX"
        static let panelOriginY = "panelOriginY"
        static let panelVisible = "panelVisible"
    }

    static var selectedFolderID: String? {
        get {
            if let id = UserDefaults.standard.string(forKey: Key.selectedFolderID) {
                return id
            }
            // Migrate legacy folder-name-only setting.
            if let legacyName = UserDefaults.standard.string(forKey: Key.selectedFolder) {
                return "iCloud\u{001F}\(legacyName)"
            }
            return nil
        }
        set { UserDefaults.standard.set(newValue, forKey: Key.selectedFolderID) }
    }

    static var selectedFolder: String? {
        get { UserDefaults.standard.string(forKey: Key.selectedFolder) }
        set { UserDefaults.standard.set(newValue, forKey: Key.selectedFolder) }
    }

    static var panelOpacity: Double {
        get {
            let value = UserDefaults.standard.double(forKey: Key.panelOpacity)
            return value == 0 ? 0.92 : value
        }
        set { UserDefaults.standard.set(newValue, forKey: Key.panelOpacity) }
    }

    static var fontSize: Double {
        get {
            let value = UserDefaults.standard.double(forKey: Key.fontSize)
            return value == 0 ? 14 : value
        }
        set { UserDefaults.standard.set(newValue, forKey: Key.fontSize) }
    }

    static var panelOrigin: CGPoint {
        get {
            CGPoint(
                x: UserDefaults.standard.double(forKey: Key.panelOriginX),
                y: UserDefaults.standard.double(forKey: Key.panelOriginY)
            )
        }
        set {
            UserDefaults.standard.set(newValue.x, forKey: Key.panelOriginX)
            UserDefaults.standard.set(newValue.y, forKey: Key.panelOriginY)
        }
    }

    static var panelVisible: Bool {
        get {
            if UserDefaults.standard.object(forKey: Key.panelVisible) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Key.panelVisible)
        }
        set { UserDefaults.standard.set(newValue, forKey: Key.panelVisible) }
    }
}
