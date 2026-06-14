import Foundation
import Security

public enum KeychainSnapshotStore {
    private static let service = "com.notesdesk.widget.snapshot"
    private static let account = "widget-current"

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private static func queryWithAccessGroup() -> [String: Any] {
        var query = baseQuery()
        query[kSecAttrAccessGroup as String] = AppConstants.appGroupID
        return query
    }

    public static func save(_ snapshot: NoteSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }

        // SPM 直跑时无 App Group  entitlement，需先按 service/account 清理旧条目
        SecItemDelete(baseQuery() as CFDictionary)
        SecItemDelete(queryWithAccessGroup() as CFDictionary)

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        var status = SecItemUpdate(baseQuery() as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = baseQuery()
            addQuery.merge(attributes) { _, new in new }
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }

        if status == errSecDuplicateItem {
            SecItemDelete(baseQuery() as CFDictionary)
            var addQuery = baseQuery()
            addQuery.merge(attributes) { _, new in new }
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }

        if status != errSecSuccess {
            print("KeychainSnapshotStore 写入失败: \(status)")
        }
    }

    public static func load() -> NoteSnapshot? {
        load(matching: queryWithAccessGroup()) ?? load(matching: baseQuery())
    }

    private static func load(matching query: [String: Any]) -> NoteSnapshot? {
        var searchQuery = query
        searchQuery[kSecReturnData as String] = true
        searchQuery[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(searchQuery as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let snapshot = try? JSONDecoder().decode(NoteSnapshot.self, from: data)
        else {
            return nil
        }
        return snapshot
    }
}
