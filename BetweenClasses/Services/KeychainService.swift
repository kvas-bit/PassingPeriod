import Foundation
import Security

enum KeychainKey {
    static let canvasToken  = "bc_canvas_token"
    static let canvasSchool = "bc_canvas_school"
    static let icalURL      = "bc_ical_url"
    static let geminiKey    = "bc_gemini_key"
}

enum KeychainError: Error, LocalizedError {
    case notFound
    case unexpectedData
    case unhandledError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .notFound:          return "Key not found in Keychain."
        case .unexpectedData:    return "Unexpected data format in Keychain."
        case .unhandledError(let s): return "Keychain error: \(s)"
        }
    }
}

struct KeychainService {
    static func save(_ value: String, for key: String) throws {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData:   data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status)
        }
    }

    static func retrieve(_ key: String) throws -> String {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            throw KeychainError.notFound
        }
        guard let data = result as? Data, let str = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }
        return str
    }

    static func delete(_ key: String) throws {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status)
        }
    }

    static func exists(_ key: String) -> Bool {
        (try? retrieve(key)) != nil
    }
}
