import Foundation
import Security

struct KeychainManager {
    private let service = "com.bskydreams.app"

    func saveSession(_ session: BskySession, key: String) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        saveData(data, key: key)
    }

    func loadSession(key: String) -> BskySession? {
        guard let data = loadData(key: key) else { return nil }
        return try? JSONDecoder().decode(BskySession.self, from: data)
    }

    func deleteSession(key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    func saveData(_ data: Data, key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func loadData(key: String) -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return data
    }

    func saveString(_ value: String, key: String) {
        guard let data = value.data(using: .utf8) else { return }
        saveData(data, key: key)
    }

    func loadString(key: String) -> String? {
        guard let data = loadData(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
