import Foundation

public enum HostSettings {
    private enum Key {
        static let selectedFolderID = "hostSelectedFolderID"
    }

    public static var selectedFolderID: String? {
        get {
            UserDefaults.standard.string(forKey: Key.selectedFolderID)
                ?? SharedStore.selectedFolderID
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.selectedFolderID)
            SharedStore.selectedFolderID = newValue
        }
    }
}
