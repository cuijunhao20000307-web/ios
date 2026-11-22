import SwiftUI
import UniformTypeIdentifiers
import Foundation
import CryptoKit
import Security

// This is a user-directed encrypted iCloud Drive file export/import. No iCloud
// entitlement is required for the Files picker, and no automatic sync is implied.
// The archive contains highly sensitive private-wallet fields: require a unique,
// memorable password and device owner authentication for both operations.
private struct DigitalCloudBackupEnvelope: Codable {
    var version: Int
    var salt: Data
    var sealed: Data
}

private struct DigitalCloudPhoto: Codable {
    var owner: String
    var id: UUID
    var back: Bool
    var bytes: Data
}
private struct DigitalCloudBackupPayload: Codable {
    var version: Int
    var date: Date
    var ledger: LedgerData
    var privateArchive: PrivateArchive
    var photos: [DigitalCloudPhoto]
    var preferences: [String: String]
}

private enum DigitalCloudBackupError: LocalizedError {
    case invalid, tooLarge, password, security
    var errorDescription: String? {
        switch self {
        case .invalid: "Backup is damaged, incompatible or the password is incorrect."
        case .tooLarge: "The backup is too large (maximum 90 MB)."
        case .password: "Choose a backup password of at least 12 characters."
        case .security: "Device owner authentication was not completed."
        }
    }
}

@MainActor
private enum DigitalCloudBackupCodec {
    static let maxBytes = 90_000_000

    static func collect(_ store: LedgerStore) throws -> DigitalCloudBackupPayload {
        let vault = try PrivateStorage.load()
        var photos: [DigitalCloudPhoto] = []
        var size = 0
        func add(_ owner: String, id: UUID) throws {
            for back in [false, true] {
                if let bytes = try ProtectedPhotoStorage.load(owner: owner, id: id, back: back) {
                    guard bytes.count <= 4_000_000 else { throw DigitalCloudBackupError.tooLarge }
                    size += bytes.count
                    guard size <= 55_000_000 else { throw DigitalCloudBackupError.tooLarge }
                    photos.append(DigitalCloudPhoto(owner: owner, id: id, back: back, bytes: bytes))
                }
            }
        }
        for card in store.data.cards { try add("card", id: card.id) }
        for bank in store.data.accounts { try add("bank", id: bank.id) }
        for doc in vault.records where doc.kind == .identity || doc.kind == .passport {
            try add("identity", id: doc.id)
        }
        let keys = ["appLanguage", "displayCurrency"]
        var settings: [String: String] = [:]
        for key in keys { if let value = UserDefaults.standard.string(forKey: key) { settings[key] = value } }
        return DigitalCloudBackupPayload(version: 1, date: .now, ledger: store.data,
                    privateArchive: vault, photos: photos, preferences: settings)
    }

    static func seal(_ payload: DigitalCloudBackupPayload, password: String) throws -> Data {
        guard password.count >= 12 else { throw DigitalCloudBackupError.password }
        let bytes = try JSONEncoder().encode(payload)
        guard bytes.count <= maxBytes else { throw DigitalCloudBackupError.tooLarge }
        var salt = Data(count: 32)
        let status = salt.withUnsafeMutableBytes { raw -> Int32 in
            guard let ptr = raw.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, raw.count, ptr)
        }
        guard status == errSecSuccess else { throw DigitalCloudBackupError.security }
        let key = try PrivateBackup.key(password, salt: salt)
        let box = try AES.GCM.seal(bytes, using: key)
        guard let sealed = box.combined else { throw DigitalCloudBackupError.invalid }
        return try JSONEncoder().encode(DigitalCloudBackupEnvelope(version: 1, salt: salt, sealed: sealed))
    }

    static func open(_ file: Data, password: String) throws -> DigitalCloudBackupPayload {
        guard file.count <= maxBytes else { throw DigitalCloudBackupError.tooLarge }
        let envelope = try JSONDecoder().decode(DigitalCloudBackupEnvelope.self, from: file)
        guard envelope.version == 1, envelope.salt.count == 32, envelope.sealed.count < maxBytes else {
            throw DigitalCloudBackupError.invalid
        }
        let key = try PrivateBackup.key(password, salt: envelope.salt)
        let raw = try AES.GCM.open(try AES.GCM.SealedBox(combined: envelope.sealed), using: key)
        let snapshot = try JSONDecoder().decode(DigitalCloudBackupPayload.self, from: raw)
        try validate(snapshot)
        return snapshot
    }

    static func validate(_ backup: DigitalCloudBackupPayload) throws {
        guard backup.version == 1,
              backup.privateArchive.version == 1,
              backup.ledger.entries.count <= 250_000,
              backup.ledger.cards.count <= 5_000,
              backup.ledger.accounts.count <= 5_000,
              backup.privateArchive.records.count <= 20_000,
              backup.privateArchive.subscriptions.count <= 20_000,
              backup.photos.count <= 20_000,
              backup.photos.reduce(0, { $0 + $1.bytes.count }) <= 55_000_000,
              backup.ledger.monthlyBudget >= 0,
              Set(backup.ledger.cards.map(\.id)).count == backup.ledger.cards.count,
              Set(backup.ledger.accounts.map(\.id)).count == backup.ledger.accounts.count,
              Set(backup.ledger.entries.map(\.id)).count == backup.ledger.entries.count,
              Set(backup.privateArchive.records.map(\.id)).count == backup.privateArchive.records.count,
              Set(backup.privateArchive.subscriptions.map(\.id)).count == backup.privateArchive.subscriptions.count,
              backup.ledger.entries.allSatisfy({ $0.amount >= 0 && $0.amount <= 1_000_000_000_000 }),
              backup.photos.allSatisfy({ $0.bytes.count <= 4_000_000 })
        else { throw DigitalCloudBackupError.invalid }
        let cardIDs = Set(backup.ledger.cards.map(\.id))
        let accountIDs = Set(backup.ledger.accounts.map(\.id))
        let identityIDs = Set(backup.privateArchive.records.filter {
            $0.kind == .identity || $0.kind == .passport
        }.map(\.id))
        var uniquePhotos: Set<String> = []
        for photo in backup.photos {
            let valid = (photo.owner == "card" && cardIDs.contains(photo.id)) ||
                        (photo.owner == "bank" && accountIDs.contains(photo.id)) ||
                        (photo.owner == "identity" && identityIDs.contains(photo.id))
            let key = photo.owner + "|" + photo.id.uuidString + "|" + (photo.back ? "back" : "front")
            guard valid && uniquePhotos.insert(key).inserted else {
                throw DigitalCloudBackupError.invalid
            }
        }
    }

    static func restore(_ snapshot: DigitalCloudBackupPayload, to store: LedgerStore) throws {
        try validate(snapshot)
        let previousLedger = store.data
        let previousVault = try PrivateStorage.load()
        // Snapshot each attachment to be changed; rollback if any write fails.
        var oldPhotos: [(DigitalCloudPhoto, Data?)] = []
        for photo in snapshot.photos {
            let previous = try ProtectedPhotoStorage.load(owner: photo.owner, id: photo.id, back: photo.back)
            oldPhotos.append((photo, previous))
        }
        do {
            try PrivateStorage.save(snapshot.privateArchive)
            for photo in snapshot.photos {
                try ProtectedPhotoStorage.save(photo.bytes, owner: photo.owner, id: photo.id, back: photo.back)
            }
            try store.restoreFromBackup(snapshot.ledger)
        } catch {
            // Best effort rollback, without removing any unrelated local files.
            try? PrivateStorage.save(previousVault)
            for (photo, previous) in oldPhotos {
                if let previous {
                    try? ProtectedPhotoStorage.save(previous, owner: photo.owner, id: photo.id, back: photo.back)
                } else {
                    try? ProtectedPhotoStorage.remove(owner: photo.owner, id: photo.id, back: photo.back)
                }
            }
            try? store.restoreFromBackup(previousLedger)
            throw error
        }
        if let code = snapshot.preferences["appLanguage"],
           ["system", "ko", "zh-Hans", "zh-Hant", "ja", "en", "es", "fr", "de"].contains(code) {
            UserDefaults.standard.set(code, forKey: "appLanguage")
        }
        if let code = snapshot.preferences["displayCurrency"], DisplayCurrency(rawValue: code) != nil {
            UserDefaults.standard.set(code, forKey: "displayCurrency")
        }
    }
}

private struct DigitalCloudBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    static var writableContentTypes: [UTType] { [.data] }
    var bytes: Data
    init(bytes: Data) { self.bytes = bytes }
    init(configuration: ReadConfiguration) throws {
        guard let bytes = configuration.file.regularFileContents else { throw DigitalCloudBackupError.invalid }
        self.bytes = bytes
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: bytes)
    }
}

struct DigitalCloudBackupView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var password = ""
    @State private var confirmation = ""
    @State private var output: DigitalCloudBackupDocument?
    @State private var export = false
    @State private var importFile = false
    @State private var incoming: Data?
    @State private var preview: DigitalCloudBackupPayload?
    @State private var confirmRestore = false
    @State private var busy = false
    @State private var notice: String?
    private var hasPending: Bool { incoming != nil }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(L("iCloud Drive에 암호화 백업 저장"), systemImage: "icloud.and.arrow.up")
                        .font(.headline)
                    Text(L("백업은 계좌·거래·개인정보 보관함·보호 사진을 포함하며, 암호로 암호화됩니다. 은행 로그인 비밀번호, 보안카드, 기기 전용 키는 제외됩니다."))
                        .font(.caption).foregroundStyle(.secondary)
                    SecureField(L("백업 비밀번호 (12자 이상)"), text: $password)
                        .textContentType(.newPassword).privacySensitive()
                    SecureField(L("비밀번호 확인"), text: $confirmation)
                        .textContentType(.newPassword).privacySensitive()
                    Button { createBackup() } label: {
                        Label(L("암호화 백업 만들기"), systemImage: "lock.doc")
                    }
                    .disabled(busy || password.count < 12 || confirmation != password)
                    Text(L("파일 앱에서 저장 위치로 iCloud Drive를 선택하세요. 자동 iCloud 동기화는 아닙니다."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Button { importFile = true } label: {
                        Label(L("iCloud Drive에서 복원 파일 선택"), systemImage: "icloud.and.arrow.down")
                    }
                    .disabled(busy)
                    if hasPending {
                        Button { inspectBackup() } label: {
                            Label(L("비밀번호로 백업 확인"), systemImage: "checkmark.shield")
                        }
                        .disabled(busy || password.isEmpty)
                    }
                    if let preview {
                        Text(preview.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(.secondary)
                        Text(summary(preview))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button(role: .destructive) {
                            confirmRestore = true
                        } label: {
                            Label(L("현재 데이터를 교체하여 복원"), systemImage: "arrow.counterclockwise")
                        }.disabled(busy)
                    }
                    Text(L("복원은 현재 가계부와 개인정보 보관함을 교체합니다. 기존 데이터를 먼저 별도 백업하세요."))
                        .font(.caption).foregroundStyle(.orange)
                } header: {
                    Text(L("iCloud 백업 복원"))
                }
            }
            .navigationTitle(L("iCloud 백업 · 복원"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button(L("닫기")) { wipe(); dismiss() }
            } }
            .overlay { if phase != .active { Color(uiColor: .systemBackground).ignoresSafeArea() } }
            .fileExporter(isPresented: $export, document: output, contentType: .data,
                          defaultFilename: "Digital-Wallet-\(Date.now.formatted(.dateTime.year().month().day())).dwbackup") { result in
                if case .failure(let error) = result { notice = error.localizedDescription }
                output = nil; password = ""; confirmation = ""
            }
            .fileImporter(isPresented: $importFile, allowedContentTypes: [.data]) { result in
                do {
                    let file = try result.get()
                    let access = file.startAccessingSecurityScopedResource()
                    defer { if access { file.stopAccessingSecurityScopedResource() } }
                    guard (try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 90_000_001) <= 90_000_000 else {
                        throw DigitalCloudBackupError.tooLarge
                    }
                    incoming = try Data(contentsOf: file)
                    preview = nil
                } catch { notice = error.localizedDescription }
            }
            .confirmationDialog(L("현재 데이터와 개인정보 보관함을 교체할까요?"),
                                isPresented: $confirmRestore, titleVisibility: .visible) {
                Button(L("교체 및 복원"), role: .destructive) { doRestore() }
            } message: {
                Text(L("현재 데이터를 먼저 별도 백업했는지 확인하세요. 되돌릴 수 없습니다."))
            }
            .alert(L("iCloud 백업 · 복원"), isPresented: Binding(
                get: { notice != nil }, set: { if !$0 { notice = nil } }
            )) { Button(L("확인")) { notice = nil } } message: { Text(notice ?? "") }
        }
    }
    private func summary(_ backup: DigitalCloudBackupPayload) -> String {
        let ledger = L("거래") + ": " + String(backup.ledger.entries.count)
        let cards = L("카드") + ": " + String(backup.ledger.cards.count)
        let banks = L("통장") + ": " + String(backup.ledger.accounts.count)
        let privateRecords = L("개인정보") + ": " + String(backup.privateArchive.records.count)
        let photos = L("사진") + ": " + String(backup.photos.count)
        return [ledger, cards, banks, privateRecords, photos].joined(separator: " · ")
    }
    private func wipe() {
        password = ""; confirmation = ""; incoming = nil; preview = nil; output = nil
    }
    private func createBackup() {
        busy = true
        Task { @MainActor in
            defer { busy = false }
            guard await LocalUnlock.authorize() else { notice = DigitalCloudBackupError.security.localizedDescription; return }
            do {
                output = DigitalCloudBackupDocument(bytes: try DigitalCloudBackupCodec.seal(
                    DigitalCloudBackupCodec.collect(store), password: password))
                export = true
            } catch { notice = error.localizedDescription }
        }
    }
    private func inspectBackup() {
        guard let incoming else { return }
        busy = true
        Task { @MainActor in
            defer { busy = false }
            guard await LocalUnlock.authorize() else { notice = DigitalCloudBackupError.security.localizedDescription; return }
            do { preview = try DigitalCloudBackupCodec.open(incoming, password: password) }
            catch { preview = nil; notice = error.localizedDescription }
        }
    }
    private func doRestore() {
        guard let preview else { return }
        busy = true
        Task { @MainActor in
            defer { busy = false }
            guard await LocalUnlock.authorize() else { notice = DigitalCloudBackupError.security.localizedDescription; return }
            do {
                try DigitalCloudBackupCodec.restore(preview, to: store)
                wipe()
                notice = L("복원 완료")
            } catch { notice = error.localizedDescription }
        }
    }
}
