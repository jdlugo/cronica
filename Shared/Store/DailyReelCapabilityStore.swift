import Foundation
import Security

actor KeychainDailyReelCapabilityStore: DailyReelCapabilityPersisting {
    private let service: String

    init(service: String = "\(Bundle.main.bundleIdentifier ?? "com.dlugokecki.qscanlite").daily-reel") {
        self.service = service
    }

    func load(publicationID: String, mode: DailyReelSessionMode) async -> String? {
        var query = baseQuery(publicationID: publicationID, mode: mode)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func save(_ capability: String, publicationID: String, mode: DailyReelSessionMode) async {
        let query = baseQuery(publicationID: publicationID, mode: mode)
        let data = Data(capability.utf8)
        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(item as CFDictionary, nil)
        }
    }

    func clear(publicationID: String, mode: DailyReelSessionMode) async {
        SecItemDelete(baseQuery(publicationID: publicationID, mode: mode) as CFDictionary)
    }

    private func baseQuery(publicationID: String, mode: DailyReelSessionMode) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(mode.rawValue):\(publicationID)",
        ]
    }
}
