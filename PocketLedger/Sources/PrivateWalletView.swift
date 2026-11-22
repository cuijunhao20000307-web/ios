import SwiftUI
import UIKit
import Security
import CryptoKit
import CommonCrypto
import UniformTypeIdentifiers
import UserNotifications

// Independent private wallet: no network, analytics or plaintext JSON on disk.
enum PrivateKind: String, Codable, CaseIterable, Identifiable {
    case card = "신용·체크카드", account = "은행 계좌", security = "보안카드"
    case login = "ID · 비밀번호", identity = "주민등록증", driver = "운전면허증"
    case passport = "여권", customs = "개인통관고유부호", certificate = "인증서 정보", note = "기타 비밀 메모"
    var id: String { rawValue }
    var fields: [String] {
        switch self {
        case .card: return ["카드사", "카드번호", "유효기간", "카드 소유자", "CVC"]
        case .account: return ["은행명", "계좌번호", "예금주", "보안 메모"]
        case .security: return ["발급 기관", "일련번호", "보안카드 번호"]
        case .login: return ["웹사이트", "사용자 ID", "비밀번호"]
        case .identity: return ["성명", "주민등록번호", "발급일", "발급 기관"]
        case .driver: return ["성명", "면허번호", "발급일", "갱신일"]
        case .passport: return ["성명", "여권번호", "국적", "발급일", "만료일"]
        case .customs: return ["성명", "통관고유부호"]
        case .certificate: return ["발급 기관", "인증서 이름", "만료일", "참고 정보"]
        case .note: return ["내용"]
        }
    }
    var icon: String {
        switch self {
        case .card: return "creditcard.fill"
        case .account: return "building.columns.fill"
        case .security: return "number.square"
        case .login: return "key.fill"
        case .identity, .driver: return "person.text.rectangle"
        case .passport: return "book.closed"
        case .customs: return "shippingbox"
        case .certificate: return "checkmark.seal"
        case .note: return "lock.doc"
        }
    }
}

struct PrivateRecord: Codable, Identifiable {
    var id = UUID()
    var kind: PrivateKind = .card
    var title = ""
    var fields: [String: String] = [:]
    var link: UUID?
    var favorite = false
    var deletedAt: Date?
}

enum BillingCycle: String, Codable, CaseIterable, Identifiable {
    case weekly = "매주", monthly = "매월", yearly = "매년"
    var id: String { rawValue }
    var monthlyFactor: Double {
        switch self { case .weekly: return 52.0/12; case .monthly: return 1; case .yearly: return 1.0/12 }
    }
    var component: Calendar.Component {
        switch self { case .weekly: return .weekOfYear; case .monthly: return .month; case .yearly: return .year }
    }
}
struct PrivateSubscription: Codable, Identifiable {
    var id = UUID()
    var title = ""
    var amount = 0 // KRW equivalent manually entered by the owner
    var cycle: BillingCycle = .monthly
    var firstDate = Date()
    var source: UUID?
    var enabled = true
    var remind = true
    var deletedAt: Date?

    func dates(from now: Date = .now, count: Int = 1) -> [Date] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: firstDate)
        let today = cal.startOfDay(for: now)
        let elapsed = cal.dateComponents([cycle.component], from: start, to: today).value(for: cycle.component) ?? 0
        var result: [Date] = []
        var n = max(0, elapsed - 1)
        // Always derive from original anchor, so February does not change later months.
        for _ in 0..<(count + 5) {
            guard let d = cal.date(byAdding: cycle.component, value: n, to: start) else { break }
            if d >= today { result.append(d) }
            if result.count == count { break }
            n += 1
        }
        return result
    }
}
struct PrivateArchive: Codable {
    var version = 1
    var records: [PrivateRecord] = []
    var subscriptions: [PrivateSubscription] = []
}

enum PrivateVaultError: LocalizedError {
    case keychain(OSStatus), invalidBackup, weakPassword
    var errorDescription: String? {
        switch self {
        case .keychain: return "보안 저장소를 사용할 수 없습니다. 기기 암호 및 여유 공간을 확인하세요."
        case .invalidBackup: return "백업 파일이 손상되었거나 비밀번호가 올바르지 않습니다."
        case .weakPassword: return "백업 비밀번호는 12자 이상이어야 합니다."
        }
    }
}

enum PrivateStorage {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "app.pocketledger.private-wallet.v1",
         kSecAttrAccount as String: "archive"]
    }
    static func load() throws -> PrivateArchive {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        if status == errSecItemNotFound { return PrivateArchive() }
        guard status == errSecSuccess, let data = result as? Data else {
            throw PrivateVaultError.keychain(status)
        }
        let archive = try JSONDecoder().decode(PrivateArchive.self, from: data)
        guard archive.version == 1 else { throw PrivateVaultError.invalidBackup }
        return archive
    }
    static func save(_ archive: PrivateArchive) throws {
        let data = try JSONEncoder().encode(archive)
        let changes = [kSecValueData as String: data]
        var status = SecItemUpdate(query as CFDictionary, changes as CFDictionary)
        if status == errSecItemNotFound {
            var q = query
            q[kSecValueData as String] = data
            q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
            status = SecItemAdd(q as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw PrivateVaultError.keychain(status) }
    }
}

private struct ProtectedEnvelope: Codable {
    let version: Int
    let salt: Data
    let sealed: Data
}
enum PrivateBackup {
    private static func key(_ password: String, salt: Data) throws -> SymmetricKey {
        var output = Data(count: 32)
        let length = output.count
        let bytes = Array(password.utf8)
        let status = output.withUnsafeMutableBytes { out in
            salt.withUnsafeBytes { s in
                password.withCString { p in
                    CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), p, bytes.count,
                        s.bindMemory(to: UInt8.self).baseAddress, salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 600_000,
                        out.bindMemory(to: UInt8.self).baseAddress, length)
                }
            }
        }
        guard status == kCCSuccess else { throw PrivateVaultError.invalidBackup }
        return SymmetricKey(data: output)
    }
    static func seal(_ archive: PrivateArchive, password: String) throws -> Data {
        guard password.count >= 12 else { throw PrivateVaultError.weakPassword }
        var salt = Data(count: 32)
        let length = salt.count
        let result = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, length, $0.baseAddress!) }
        guard result == errSecSuccess else { throw PrivateVaultError.keychain(result) }
        let plaintext = try JSONEncoder().encode(archive)
        let box = try AES.GCM.seal(plaintext, using: key(password, salt: salt))
        guard let combined = box.combined else { throw PrivateVaultError.invalidBackup }
        return try JSONEncoder().encode(ProtectedEnvelope(version: 1, salt: salt, sealed: combined))
    }
    static func open(_ data: Data, password: String) throws -> PrivateArchive {
        guard data.count <= 10_000_000 else { throw PrivateVaultError.invalidBackup }
        let envelope = try JSONDecoder().decode(ProtectedEnvelope.self, from: data)
        guard envelope.version == 1, envelope.salt.count == 32 else { throw PrivateVaultError.invalidBackup }
        let box = try AES.GCM.SealedBox(combined: envelope.sealed)
        let raw = try AES.GCM.open(box, using: key(password, salt: envelope.salt))
        let archive = try JSONDecoder().decode(PrivateArchive.self, from: raw)
        guard archive.version == 1, archive.subscriptions.allSatisfy({$0.amount >= 0 && $0.amount <= 1_000_000_000}),
              Set(archive.records.map(\.id)).count == archive.records.count,
              Set(archive.subscriptions.map(\.id)).count == archive.subscriptions.count else { throw PrivateVaultError.invalidBackup }
        return archive
    }
}
struct PrivateBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    var bytes: Data
    init(bytes: Data) { self.bytes = bytes }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw PrivateVaultError.invalidBackup }
        bytes = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: bytes) }
}

enum PrivateReminders {
    static let prefix = "pocketledger.subscription."
    static func refresh(_ subscriptions: [PrivateSubscription], askPermission: Bool = false) async {
        let center = UNUserNotificationCenter.current()
        if askPermission { _ = try? await center.requestAuthorization(options: [.alert, .sound]) }
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter {$0.hasPrefix(prefix)})
        var candidates: [(UUID, Date)] = []
        let calendar = Calendar.current
        for sub in subscriptions where sub.enabled && sub.remind && sub.deletedAt == nil {
            for date in sub.dates(count: 12) {
                if let day = calendar.date(byAdding: .day, value: -1, to: date),
                   let fire = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day), fire > .now {
                    candidates.append((sub.id, fire))
                }
            }
        }
        let free = max(0, 48 - pending.filter { !$0.identifier.hasPrefix(prefix) }.count)
        for (id, date) in candidates.sorted(by: {$0.1 < $1.1}).prefix(free) {
            let content = UNMutableNotificationContent()
            content.title = "PocketLedger"
            content.body = "다가오는 구독 결제일이 있습니다."
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: calendar.dateComponents([.year,.month,.day,.hour,.minute], from: date), repeats: false)
            let request = UNNotificationRequest(identifier: prefix + id.uuidString + "." + String(Int(date.timeIntervalSince1970)), content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}

struct PrivateWalletView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @AppStorage("privateWalletFont") private var font = "기본"
    @AppStorage("privateWalletSize") private var size = "기본"
    private let initialSection: Int
    @State private var section: Int

    init(initialSection: Int = 0) {
        self.initialSection = initialSection
        _section = State(initialValue: initialSection)
    }
    @State private var archive: PrivateArchive?
    @State private var record: PrivateRecord?
    @State private var subscription: PrivateSubscription?
    @State private var search = ""
    @State private var error: String?
    @State private var authenticating = false
    @State private var exportFile: PrivateBackupDocument?
    @State private var showExport = false
    @State private var showImport = false
    @State private var incoming: Data?
    @State private var password = ""
    @State private var confirmation = ""
    @State private var backupMode: String?
    @State private var confirmEmpty = false

    var body: some View {
        NavigationStack {
            Group {
                if let archive {
                    List {
                        Section {
                            Picker("분류", selection: $section) {
                                Text("보관함").tag(0)
                                Text("구독").tag(1)
                                Text("휴지통").tag(2)
                                Text("설정").tag(3)
                            }.pickerStyle(.segmented)
                        }
                        if section == 0 { records(archive) }
                        else if section == 1 { subscriptions(archive) }
                        else if section == 2 { trash(archive) }
                        else { settings }
                    }
                    .searchable(text: $search, prompt: "이름 검색")
                } else {
                    VStack(spacing: 18) {
                        Image(systemName: "lock.shield.fill").font(.system(size: 52)).foregroundStyle(LedgerTheme.accent)
                        Text("개인정보 보관함").font(.title.bold())
                        Text("Face ID / Touch ID 또는 기기 암호로 보호됩니다.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button("보관함 열기") { Task { await unlock() } }.buttonStyle(.borderedProminent).disabled(authenticating)
                    }.padding(24)
                }
            }
            .navigationTitle("나의 디지털 지갑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
                if archive != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button { lock() } label: { Image(systemName: "lock") }.accessibilityLabel("잠그기")
                    }
                }
            }
            .font(.system(.body, design: font == "둥근 글꼴" ? .rounded : font == "고정폭" ? .monospaced : .default))
            .dynamicTypeSize(size == "작게" ? .small : size == "크게" ? .xxLarge : .large)
            .overlay { if phase != .active { Color(uiColor: .systemBackground).ignoresSafeArea() } }
            .onAppear { section = initialSection }
            .onChange(of: phase) { _, value in if value == .background { lock() } }
            .sheet(item: $record) { item in
                PrivateRecordEditor(record: item) { value in
                    guard var a = archive else { return false }
                    if let i = a.records.firstIndex(where: {$0.id == value.id}) { a.records[i] = value }
                    else { a.records.append(value) }
                    return commit(a)
                }
                .environmentObject(store)
            }
            .sheet(item: $subscription) { item in
                PrivateSubscriptionEditor(item: item) { value in
                    guard var a = archive else { return false }
                    if let i = a.subscriptions.firstIndex(where: {$0.id == value.id}) { a.subscriptions[i] = value }
                    else { a.subscriptions.append(value) }
                    if commit(a) {
                        Task { await PrivateReminders.refresh(a.subscriptions, askPermission: value.remind) }
                        return true
                    }
                    return false
                }.environmentObject(store)
            }
            .sheet(isPresented: Binding(get: { backupMode != nil }, set: { if !$0 { resetBackup() } }), onDismiss: {
                if exportFile != nil && archive != nil { showExport = true }
            }) {
                NavigationStack {
                    Form {
                        if backupMode == "export" {
                            Text("보관함 및 구독 정보만 포함합니다. 기존 가계부 거래·통장 비밀코드는 포함하지 않습니다.")
                            SecureField("백업 비밀번호 (12자 이상)", text: $password)
                            SecureField("비밀번호 확인", text: $confirmation)
                        } else {
                            Text("복원하면 현재 보관함과 구독이 백업 내용으로 교체됩니다. 기존 가계부 기록은 유지됩니다.")
                            SecureField("백업 비밀번호", text: $password)
                        }
                        Button(backupMode == "export" ? "암호화 파일 만들기" : "교체 및 복원", role: backupMode == "export" ? nil : .destructive) {
                            performBackup()
                        }.disabled(password.isEmpty || (backupMode == "export" && (password.count < 12 || password != confirmation)))
                    }
                    .navigationTitle("암호화 백업")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("취소") { resetBackup() } } }
                    .overlay { if phase != .active { Color(uiColor: .systemBackground).ignoresSafeArea() } }
                }
            }
            .fileExporter(isPresented: $showExport, document: exportFile, contentType: .data, defaultFilename: "PocketLedger-private-backup.plbackup") { result in
                if case .failure(let e) = result { error = e.localizedDescription }
                exportFile = nil
            }
            .fileImporter(isPresented: $showImport, allowedContentTypes: [.data]) { result in
                do {
                    let url = try result.get()
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    guard archive != nil, (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 10_000_001) <= 10_000_000 else { throw PrivateVaultError.invalidBackup }
                    incoming = try Data(contentsOf: url)
                    backupMode = "import"
                } catch { self.error = error.localizedDescription }
            }
            .alert("확인", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("확인") { error = nil } } message: { Text(error ?? "") }
            .confirmationDialog("휴지통을 영구 삭제할까요?", isPresented: $confirmEmpty) {
                Button("영구 삭제", role: .destructive) {
                    guard var a = archive else { return }
                    a.records.removeAll {$0.deletedAt != nil}
                    a.subscriptions.removeAll {$0.deletedAt != nil}
                    _ = commit(a)
                }
            }
        }
    }
    @MainActor private func unlock() async {
        guard !authenticating else { return }
        authenticating = true
        defer { authenticating = false }
        guard await LocalUnlock.authorize(), phase != .background else { return }
        do {
            let a = try PrivateStorage.load()
            archive = a
            await PrivateReminders.refresh(a.subscriptions)
        } catch { self.error = error.localizedDescription }
    }
    private func lock() {
        archive = nil; record = nil; subscription = nil; search = ""
        resetBackup(); exportFile = nil; showExport = false; showImport = false
    }
    private func resetBackup() { backupMode = nil; password = ""; confirmation = ""; incoming = nil }
    @discardableResult private func commit(_ next: PrivateArchive) -> Bool {
        do { try PrivateStorage.save(next); archive = next; return true }
        catch { self.error = error.localizedDescription; return false }
    }
    private func performBackup() {
        do {
            guard let a = archive else { return }
            if backupMode == "export" {
                exportFile = PrivateBackupDocument(bytes: try PrivateBackup.seal(a, password: password))
                resetBackup()
            } else if let incoming {
                let restored = try PrivateBackup.open(incoming, password: password)
                if commit(restored) {
                    resetBackup()
                    Task { await PrivateReminders.refresh(restored.subscriptions) }
                }
            }
        } catch {
            resetBackup()
            self.error = "백업 처리 실패: " + error.localizedDescription
        }
    }
    private func matches(_ title: String) -> Bool { search.isEmpty || title.localizedCaseInsensitiveContains(search) }
    @ViewBuilder private func records(_ a: PrivateArchive) -> some View {
        Section {
            Button { record = PrivateRecord() } label: { Label("정보 추가", systemImage: "plus.circle.fill") }
        }
        ForEach(PrivateKind.allCases) { kind in
            let rows = a.records.filter {$0.kind == kind && $0.deletedAt == nil && matches($0.title)}.sorted {
                if $0.favorite != $1.favorite { return $0.favorite && !$1.favorite }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            if !rows.isEmpty {
                Section(kind.rawValue) {
                    ForEach(rows) { row in
                        Button { record = row } label: {
                            HStack {
                                Label(row.title, systemImage: kind.icon)
                                Spacer()
                                if row.favorite { Image(systemName: "star.fill").foregroundStyle(.orange) }
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }
                        }.swipeActions {
                            Button(role: .destructive) {
                                var n = a
                                if let i = n.records.firstIndex(where: {$0.id == row.id}) { n.records[i].deletedAt = .now; _ = commit(n) }
                            } label: { Label("휴지통", systemImage: "trash") }
                        }
                    }
                }
            }
        }
        Section { Text("민감 정보는 이 기기의 Keychain에 보관됩니다. 실제 결제나 자동 로그인을 제공하지 않습니다. 카드 CVC나 은행 암호 저장은 권장하지 않습니다.").font(.caption).foregroundStyle(.secondary) }
    }
    @ViewBuilder private func subscriptions(_ a: PrivateArchive) -> some View {
        let active = a.subscriptions.filter {$0.deletedAt == nil && $0.enabled}
        let monthly = active.reduce(0.0) {$0 + Double($1.amount) * $1.cycle.monthlyFactor}
        Section("월 예상 구독료") {
            Text(monthly, format: .currency(code: "KRW").precision(.fractionLength(0))).font(.title.bold())
            Text("직접 입력한 원화 기준 예상액 · 자동 결제 및 거래 기록과 별도").font(.caption).foregroundStyle(.secondary)
            Button { subscription = PrivateSubscription() } label: { Label("구독 추가", systemImage: "plus.circle.fill") }
        }
        Section("나의 구독") {
            ForEach(a.subscriptions.filter {$0.deletedAt == nil && matches($0.title)}.sorted {($0.dates().first ?? .distantFuture) < ($1.dates().first ?? .distantFuture)}) { row in
                Button { subscription = row } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack { Text(row.title).font(.headline); Spacer(); Text(row.amount.won).fontWeight(.semibold) }
                        Text(row.cycle.rawValue + " · " + (store.sourceName(for: row.source) ?? "미지정") + (row.enabled ? "" : " · 일시 중지")).font(.caption).foregroundStyle(.secondary)
                        if row.enabled, let date = row.dates().first { Text("다음 결제: " + date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary) }
                    }
                }.swipeActions {
                    Button(role: .destructive) {
                        var n = a
                        if let i = n.subscriptions.firstIndex(where: {$0.id == row.id}) {
                            n.subscriptions[i].deletedAt = .now
                            if commit(n) { Task { await PrivateReminders.refresh(n.subscriptions) } }
                        }
                    } label: { Label("휴지통", systemImage: "trash") }
                }
            }
        }
        Section { Text("알림을 허용하면 결제 전날 오전 9시에 일반 알림을 표시합니다. 알림 개수 제한으로 가까운 일정부터 등록되며, 보관함을 열면 다시 계산합니다.").font(.caption).foregroundStyle(.secondary) }
    }
    @ViewBuilder private func trash(_ a: PrivateArchive) -> some View {
        Section("삭제된 정보") {
            ForEach(a.records.filter {$0.deletedAt != nil}) { row in
                HStack { Text(row.title); Spacer(); Button("복원") {
                    var n = a
                    if let i = n.records.firstIndex(where: {$0.id == row.id}) { n.records[i].deletedAt = nil; _ = commit(n) }
                }.buttonStyle(.borderless) }
            }
            ForEach(a.subscriptions.filter {$0.deletedAt != nil}) { row in
                HStack { Text(row.title); Spacer(); Button("복원") {
                    var n = a
                    if let i = n.subscriptions.firstIndex(where: {$0.id == row.id}) {
                        n.subscriptions[i].deletedAt = nil
                        if commit(n) { Task { await PrivateReminders.refresh(n.subscriptions) } }
                    }
                }.buttonStyle(.borderless) }
            }
            Button("휴지통 비우기", role: .destructive) { confirmEmpty = true }
        }
    }
    private var settings: some View {
        Group {
            Section("보관함 화면 설정") {
                Picker("글꼴", selection: $font) { ForEach(["기본", "둥근 글꼴", "고정폭"], id: \.self) { Text($0) } }
                Picker("글자 크기", selection: $size) { ForEach(["작게","기본","크게"], id: \.self) { Text($0) } }
            }
            Section("백업 및 복원") {
                Button { backupMode = "export" } label: { Label("암호화 백업 내보내기", systemImage: "square.and.arrow.up") }
                Button { showImport = true } label: { Label("암호화 백업 가져오기", systemImage: "square.and.arrow.down") }
                Text("파일 앱에서 iCloud Drive 또는 기기 저장소를 직접 선택할 수 있습니다. 자동 iCloud 동기화는 제공되지 않으며 비밀번호를 잊으면 백업을 복원할 수 없습니다.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct PrivateRecordEditor: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State var record: PrivateRecord
    let save: (PrivateRecord) -> Bool
    @State private var visible = false
    @State private var failed = false
    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    Picker("종류", selection: $record.kind) { ForEach(PrivateKind.allCases) { Text($0.rawValue).tag($0) } }
                    TextField("이름", text: $record.title)
                    Toggle("즐겨찾기", isOn: $record.favorite)
                    if record.kind == .card || record.kind == .account {
                        Picker("가계부 연결", selection: $record.link) {
                            Text("연결 안 함").tag(Optional<UUID>.none)
                            if record.kind == .card {
                                ForEach(store.data.cards) { Text($0.name).tag(Optional($0.id)) }
                            } else {
                                ForEach(store.data.accounts) { Text($0.nickname).tag(Optional($0.id)) }
                            }
                        }
                    }
                }
                Section("보호된 정보") {
                    Toggle("내용 표시", isOn: $visible)
                    ForEach(record.kind.fields, id: \.self) { field in
                        HStack {
                            let binding = Binding(get: {record.fields[field] ?? ""}, set: {record.fields[field] = $0})
                            if visible {
                                TextField(field, text: binding).autocorrectionDisabled().textInputAutocapitalization(.never)
                                Button {
                                    UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: binding.wrappedValue]], options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(60)])
                                } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.borderless).disabled(binding.wrappedValue.isEmpty).accessibilityLabel(field + " 복사")
                            } else {
                                SecureField(field, text: binding).autocorrectionDisabled().textInputAutocapitalization(.never)
                            }
                        }
                    }
                    Text("복사한 정보는 이 기기에서 60초 후 만료되도록 설정됩니다.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("정보 편집")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장") {
                    var value = record
                    value.fields = value.fields.filter {value.kind.fields.contains($0.key)}
                    if save(value) { dismiss() } else { failed = true }
                }.disabled(record.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
            .onChange(of: record.kind) { _, _ in record.link = nil }
            .onChange(of: phase) { _, p in if p != .active { visible = false }; if p == .background { dismiss() } }
            .overlay { if phase != .active { Color(uiColor: .systemBackground).ignoresSafeArea() } }
            .alert("저장 실패", isPresented: $failed) { Button("확인") {} } message: { Text("기존 데이터는 변경되지 않았습니다.") }
        }
    }
}

struct PrivateSubscriptionEditor: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State var item: PrivateSubscription
    let save: (PrivateSubscription) -> Bool
    @State private var amount = ""
    @State private var failed = false
    var body: some View {
        NavigationStack {
            Form {
                TextField("구독 서비스 이름", text: $item.title)
                TextField("결제 금액 (원)", text: $amount).keyboardType(.numberPad)
                Picker("결제 주기", selection: $item.cycle) { ForEach(BillingCycle.allCases) { Text($0.rawValue).tag($0) } }
                DatePicker("첫 결제일", selection: $item.firstDate, displayedComponents: .date)
                Picker("결제 수단", selection: $item.source) {
                    Text("미지정").tag(Optional<UUID>.none)
                    ForEach(store.data.cards) { Text($0.name).tag(Optional($0.id)) }
                    ForEach(store.data.accounts) { Text($0.nickname).tag(Optional($0.id)) }
                }
                Toggle("사용 중", isOn: $item.enabled)
                Toggle("결제 전날 알림", isOn: $item.remind)
            }
            .navigationTitle("구독 편집")
            .onAppear { amount = item.amount > 0 ? String(item.amount) : "" }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장") {
                    item.amount = amount.toMoneyInt
                    if save(item) { dismiss() } else { failed = true }
                }.disabled(item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || amount.toMoneyInt <= 0 || amount.toMoneyInt > 1_000_000_000) }
            }
            .onChange(of: phase) { _, p in if p == .background { dismiss() } }
            .overlay { if phase != .active { Color(uiColor: .systemBackground).ignoresSafeArea() } }
            .alert("저장 실패", isPresented: $failed) { Button("확인") {} }
        }
    }
}
