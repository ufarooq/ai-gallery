import Foundation
import Security

// Already defined in Model.swift, ensure it's accessible here.
// If Model.swift is in the same target, it should be.
// struct ImportedModelInfo: Codable, Hashable { ... }

struct AccessTokenData: Codable, Hashable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Int64 // Store as Unix timestamp (seconds since epoch)
}

protocol DataStoreRepository {
    // Text Input History
    func saveTextInputHistory(history: [String]) async
    func readTextInputHistory() async -> [String]

    // Theme Override
    func saveThemeOverride(theme: String) async
    func readThemeOverride() async -> String // Returns default if not set

    // Access Token
    func saveAccessTokenData(accessToken: String, refreshToken: String, expiresAt: Int64) async
    func clearAccessTokenData() async
    func readAccessTokenData() async -> AccessTokenData?

    // Imported Models
    func saveImportedModels(importedModels: [ImportedModelInfo]) async
    func readImportedModels() async -> [ImportedModelInfo]
}

class DefaultDataStoreRepository: DataStoreRepository {

    private let userDefaults = UserDefaults.standard
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    // MARK: - Keys
    private enum PreferencesKeys {
        static let TEXT_INPUT_HISTORY = "text_input_history"
        static let THEME_OVERRIDE = "theme_override"
        static let IMPORTED_MODELS_INFO = "imported_models_info"
    }

    private enum KeychainKeys {
        static let SERVICE_NAME = "com.example.GalleryApp" // Use your app's bundle ID or a unique service name
        static let ACCOUNT_NAME = "user_access_token" // Generic account name for this piece of data

        static let ACCESS_TOKEN_KEY = "access_token"
        static let REFRESH_TOKEN_KEY = "refresh_token"
        static let EXPIRES_AT_KEY = "expires_at"
    }

    private let defaultTheme = "system" // Or your desired default theme identifier

    // MARK: - Text Input History
    func saveTextInputHistory(history: [String]) async {
        do {
            let data = try jsonEncoder.encode(history)
            userDefaults.set(data, forKey: PreferencesKeys.TEXT_INPUT_HISTORY)
        } catch {
            print("Failed to save text input history: \(error)")
        }
    }

    func readTextInputHistory() async -> [String] {
        guard let data = userDefaults.data(forKey: PreferencesKeys.TEXT_INPUT_HISTORY) else {
            return []
        }
        do {
            let history = try jsonDecoder.decode([String].self, from: data)
            return history
        } catch {
            print("Failed to read text input history: \(error)")
            return []
        }
    }

    // MARK: - Theme Override
    func saveThemeOverride(theme: String) async {
        userDefaults.set(theme, forKey: PreferencesKeys.THEME_OVERRIDE)
    }

    func readThemeOverride() async -> String {
        return userDefaults.string(forKey: PreferencesKeys.THEME_OVERRIDE) ?? defaultTheme
    }

    // MARK: - Access Token (Keychain)
    func saveAccessTokenData(accessToken: String, refreshToken: String, expiresAt: Int64) async {
        let tokenData = AccessTokenData(accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt)
        do {
            let data = try jsonEncoder.encode(tokenData)
            updateKeychainValue(data, forService: KeychainKeys.SERVICE_NAME, account: KeychainKeys.ACCOUNT_NAME)
        } catch {
            print("Failed to encode AccessTokenData: \(error)")
        }
    }

    func clearAccessTokenData() async {
        deleteKeychainValue(forService: KeychainKeys.SERVICE_NAME, account: KeychainKeys.ACCOUNT_NAME)
    }

    func readAccessTokenData() async -> AccessTokenData? {
        guard let data = readKeychainValue(forService: KeychainKeys.SERVICE_NAME, account: KeychainKeys.ACCOUNT_NAME) else {
            return nil
        }
        do {
            let tokenData = try jsonDecoder.decode(AccessTokenData.self, from: data)
            return tokenData
        } catch {
            print("Failed to decode AccessTokenData: \(error)")
            return nil
        }
    }

    // MARK: - Imported Models
    func saveImportedModels(importedModels: [ImportedModelInfo]) async {
        do {
            let data = try jsonEncoder.encode(importedModels)
            userDefaults.set(data, forKey: PreferencesKeys.IMPORTED_MODELS_INFO)
        } catch {
            print("Failed to save imported models: \(error)")
        }
    }

    func readImportedModels() async -> [ImportedModelInfo] {
        guard let data = userDefaults.data(forKey: PreferencesKeys.IMPORTED_MODELS_INFO) else {
            return []
        }
        do {
            let models = try jsonDecoder.decode([ImportedModelInfo].self, from: data)
            return models
        } catch {
            print("Failed to read imported models: \(error)")
            return []
        }
    }

    // MARK: - Keychain Helper Methods

    private func baseKeychainQuery(service: String, account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        return query
    }

    private func updateKeychainValue(_ value: Data, forService service: String, account: String) {
        var query = baseKeychainQuery(service: service, account: account)

        // Check if item exists
        let status = SecItemCopyMatching(query as CFDictionary, nil)

        if status == errSecSuccess { // Item exists, update it
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: value
            ]
            let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            if updateStatus != errSecSuccess {
                print("Failed to update keychain item. Status: \(updateStatus)")
            }
        } else if status == errSecItemNotFound { // Item does not exist, add it
            query[kSecValueData as String] = value
            // query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly // Example accessibility
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            if addStatus != errSecSuccess {
                print("Failed to add keychain item. Status: \(addStatus)")
            }
        } else {
            print("Keychain error on check. Status: \(status)")
        }
    }

    private func readKeychainValue(forService service: String, account: String) -> Data? {
        var query = baseKeychainQuery(service: service, account: account)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = kCFBooleanTrue

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let data = item as? Data else {
            if status != errSecItemNotFound { // Don't print for item not found, it's a valid case
                 print("Failed to read keychain item. Status: \(status)")
            }
            return nil
        }
        return data
    }

    private func deleteKeychainValue(forService service: String, account: String) {
        let query = baseKeychainQuery(service: service, account: account)
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            print("Failed to delete keychain item. Status: \(status)")
        }
    }
}
