import Foundation
import Security

public enum KeychainSnapshotStore {
    private static let service = "com.notesdesk.widget.snapshot"
    private static let account = "widget-current"

    public static func save(_ snapshot: NoteSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: AppConstants.appGroupID,
        ]
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            print("KeychainSnapshotStore 写入失败: \(status)")
        }
    }

    public static func load() -> NoteSnapshot? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: AppConstants.appGroupID,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let snapshot = try? JSONDecoder().decode(NoteSnapshot.self, from: data)
        else {
            return nil
        }
        return snapshot
    }
}
