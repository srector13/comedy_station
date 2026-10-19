import Foundation
import Security

/// A key in the keychain, synced through iCloud Keychain to the person's
/// other devices.
struct KeychainKeyStore: KeyStoring {
    static let tmdb = KeychainKeyStore(service: "Standup.TMDB")

    let service: String

    private var item: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "api-key",
        ]
    }

    func load() -> String? {
        var query = item
        query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8), !key.isEmpty
        else { return nil }
        return key
    }

    func save(_ key: String?) {
        var match = item
        match[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        SecItemDelete(match as CFDictionary)
        guard let key, !key.isEmpty else { return }
        var new = item
        new[kSecAttrSynchronizable as String] = true
        new[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        new[kSecValueData as String] = Data(key.utf8)
        SecItemAdd(new as CFDictionary, nil)
    }
}
