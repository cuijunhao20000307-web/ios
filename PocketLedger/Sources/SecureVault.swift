import Foundation
import Security
import CryptoKit
import LocalAuthentication

/// Only account secrets are stored in the device-only iOS Keychain.
/// They are intentionally excluded from the JSON model and any data exports.
enum SecureVault {
    private static let service = "app.pocketledger.bank-secrets"

    @discardableResult
    static func save(_ secret: String, for id: UUID) -> Bool {
        let key = id.uuidString
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = Data(secret.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    static func retrieve(for id: UUID) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func remove(for id: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum LocalUnlock {
    static func isAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    static func authorize() async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = L("취소")
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "가계부의 보호된 정보를 확인합니다."
            )
        } catch {
            return false
        }
    }
}


struct BankSecurityCard: Codable {
    static let counts = [25, 30, 35, 40, 45, 50]
    var serial = ""
    var vertical = true
    var codes = Array(repeating: "", count: 30)
    static func digits(_ s: String, max: Int) -> String {
        String(s.filter { "0123456789".contains($0) }.prefix(max))
    }
    var valid: Bool {
        Self.counts.contains(codes.count) && serial.count <= 64 &&
        codes.allSatisfy { $0.isEmpty || ($0.count == 4 && $0 == Self.digits($0, max: 4)) }
    }
    mutating func resize(_ n: Int) {
        guard Self.counts.contains(n) else { return }
        if n < codes.count { codes = Array(codes.prefix(n)) }
        else { codes += Array(repeating: "", count: n - codes.count) }
    }
}
enum BankSecurityStorage {
    private static func query(_ id: UUID) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "app.pocketledger.bank-security.v1",
         kSecAttrAccount as String: id.uuidString]
    }
    static func load(_ id: UUID) throws -> BankSecurityCard? {
        var q = query(id)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw PrivateVaultError.keychain(status) }
        let card = try JSONDecoder().decode(BankSecurityCard.self, from: data)
        guard card.valid else { throw PrivateVaultError.invalidBackup }
        return card
    }
    static func save(_ card: BankSecurityCard, id: UUID) throws {
        guard card.valid else { throw PrivateVaultError.invalidBackup }
        let q = query(id)
        let data = try JSONEncoder().encode(card)
        var status = SecItemUpdate(q as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = q
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw PrivateVaultError.keychain(status) }
    }
    static func remove(_ id: UUID) throws {
        let status = SecItemDelete(query(id) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw PrivateVaultError.keychain(status) }
    }
}


struct BankWebsiteDetails: Codable {
    var website = ""
    var username = ""
    var password = ""
    var memo = ""
    var valid: Bool { website.count <= 2048 && username.count <= 1024 && password.count <= 1024 && memo.count <= 8192 }
}
enum BankWebsiteStorage {
    private static func query(_ id: UUID) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "app.pocketledger.bank-website.v1",
         kSecAttrAccount as String: id.uuidString]
    }
    static func load(_ id: UUID) throws -> BankWebsiteDetails? {
        var q = query(id)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw PrivateVaultError.keychain(status) }
        let card = try JSONDecoder().decode(BankWebsiteDetails.self, from: data)
        guard card.valid else { throw PrivateVaultError.invalidBackup }
        return card
    }
    static func save(_ card: BankWebsiteDetails, id: UUID) throws {
        guard card.valid else { throw PrivateVaultError.invalidBackup }
        let q = query(id)
        let data = try JSONEncoder().encode(card)
        var status = SecItemUpdate(q as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = q
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw PrivateVaultError.keychain(status) }
    }
    static func remove(_ id: UUID) throws {
        let status = SecItemDelete(query(id) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw PrivateVaultError.keychain(status) }
    }
}


// Encrypted attachment files kept outside exported archives and excluded from backups.
enum ProtectedPhotoStorage {
    private static func key() throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "app.pocketledger.photo-key.v1",
            kSecAttrAccount as String: "local"
        ]
        var read = query
        read[kSecReturnData as String] = true
        read[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(read as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data, data.count == 32 { return SymmetricKey(data: data) }
        guard status == errSecItemNotFound else { throw PrivateVaultError.keychain(status) }
        let key = SymmetricKey(size: .bits256)
        var item = query
        item[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        let added = SecItemAdd(item as CFDictionary, nil)
        guard added == errSecSuccess else { throw PrivateVaultError.keychain(added) }
        return key
    }
    private static func url(owner: String, id: UUID, back: Bool) throws -> URL {
        guard ["card", "bank", "identity"].contains(owner) else { throw PrivateVaultError.invalidBackup }
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("ProtectedPhotos", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var dir = directory
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try dir.setResourceValues(values)
        return directory.appendingPathComponent(owner + "-" + id.uuidString + (back ? "-back" : "-front"))
    }
    static func load(owner: String, id: UUID, back: Bool) throws -> Data? {
        let path = try url(owner: owner, id: id, back: back)
        guard FileManager.default.fileExists(atPath: path.path) else { return nil }
        let box = try AES.GCM.SealedBox(combined: Data(contentsOf: path))
        return try AES.GCM.open(box, using: key(), authenticating: Data(path.lastPathComponent.utf8))
    }
    static func save(_ data: Data, owner: String, id: UUID, back: Bool) throws {
        guard data.count <= 4_000_000 else { throw PrivateVaultError.invalidBackup }
        let path = try url(owner: owner, id: id, back: back)
        let box = try AES.GCM.seal(data, using: key(), authenticating: Data(path.lastPathComponent.utf8))
        guard let combined = box.combined else { throw PrivateVaultError.invalidBackup }
        try combined.write(to: path, options: [.atomic, .completeFileProtection])
    }
    static func remove(owner: String, id: UUID, back: Bool) throws {
        let path = try url(owner: owner, id: id, back: back)
        if FileManager.default.fileExists(atPath: path.path) { try FileManager.default.removeItem(at: path) }
    }
}
