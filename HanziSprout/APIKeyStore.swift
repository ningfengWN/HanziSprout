import Foundation
import Security

enum APIKeyStore {
    private static let service = "com.ningfeng.HanziSprout.zhipu"
    private static let account = "standard-api-key"
    private static var query: [String: Any] { [kSecClass as String:kSecClassGenericPassword, kSecAttrService as String:service, kSecAttrAccount as String:account] }
    static func read() throws -> String? {
        var q = query; q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data, let key = String(data: data, encoding: .utf8) else { throw StoreError.failed }
        return key
    }
    static func save(_ input: String) throws {
        let key = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, key.count <= 512, !key.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0) }) else { throw StoreError.invalid }
        let data = Data(key.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String:data] as CFDictionary)
        if status == errSecItemNotFound {
            var q = query; q[kSecValueData as String] = data
            q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            q[kSecAttrSynchronizable as String] = false
            guard SecItemAdd(q as CFDictionary, nil) == errSecSuccess else { throw StoreError.failed }
        } else if status != errSecSuccess { throw StoreError.failed }
    }
    static func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw StoreError.failed }
    }
    enum StoreError: LocalizedError {
        case failed, invalid
        var errorDescription: String? { self == .invalid ? "请粘贴完整的 API Key，不要包含空格或换行。" : "系统钥匙串暂时不可用，请解锁设备后重试。" }
    }
}
