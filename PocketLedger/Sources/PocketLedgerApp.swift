import SwiftUI
import AppIntents
import Foundation
import Combine

@main
struct PocketLedgerApp: App {
    @StateObject private var store = LedgerStore()
    @AppStorage("appLanguage") private var appLanguage = "system"
    @AppStorage("displayCurrency") private var currency = "KRW"
    @AppStorage("displayCurrencyRevision") private var currencyRevision = 0

    var body: some Scene {
        WindowGroup {
            AppShell()
                .environmentObject(store)
                .environment(\.locale, AppLocalization.locale)
                .environment(\.appLanguageRevision, appLanguage)
                .environment(\.displayCurrencyRevision, currency + String(currencyRevision))
                .preferredColorScheme(store.data.appearance.colorScheme)
                .tint(LedgerTheme.accent)
        }
    }
}

struct AppShell: View {
    @Environment(\.appLanguageRevision) private var languageRefresh
    @Environment(\.displayCurrencyRevision) private var moneyRefresh
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: WalletTab = .home
    @State private var unlocked = false
    @AppStorage("monthlyReportEnabled") private var reportEnabled = true
    @AppStorage("monthlyReportNotifications") private var reportNotifications = false
    @AppStorage("lastViewedMonthlyReport") private var lastReport = ""
    @State private var report: ReportMonth?
    private let monthClock = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        let _ = languageRefresh
        let _ = moneyRefresh
        ZStack {
            LedgerTheme.background.ignoresSafeArea()
            if store.data.appLockEnabled && !unlocked {
                LockedView {
                    Task { unlocked = await LocalUnlock.authorize() }
                }
            } else {
                nativeNavigation
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active && store.data.appLockEnabled { unlocked = false }
            if phase == .active { store.processRecurring(); if !store.data.appLockEnabled { unlocked = true } }
        }
        .onReceive(monthClock) { _ in checkPending() }
        .onReceive(NotificationCenter.default.publisher(for: PaymentInbox.changed)) { _ in checkPending() }
        .onChange(of: unlocked) { _, value in if value { checkPending() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { checkPending() }
            if phase == .background { report = nil }
        }
        .sheet(item: $report) { value in
            MonthlyReportView(month: value.date)
        }
        .onChange(of: store.data.appLockEnabled) { _, enabled in
            unlocked = !enabled
            if enabled { Task { unlocked = await LocalUnlock.authorize() } }
        }
        .task {
            if store.data.appLockEnabled { unlocked = await LocalUnlock.authorize() }
            else { unlocked = true }
            _ = await MonthlyReportNotice.configure(reportNotifications)
            checkPending()
        }
    }

    private func checkPending() {
        guard scenePhase == .active, !store.data.appLockEnabled || unlocked else { return }
        PaymentInbox.drain(into: store)
        guard reportEnabled, report == nil else { return }
        let month = ReportMonth.previous
        let key = ReportMonth.key(month)
        guard lastReport != key, !store.entries(in: month).isEmpty else { return }
        lastReport = key
        report = ReportMonth(date: month)
    }

    // Native bars use the system's shared bar region on iPhone Duo when
    // linked against iOS 27.1+. No fake internal rail or device-width threshold.
    @ViewBuilder private var nativeNavigation: some View {
        if #available(iOS 18.0, *) {
            TabView(selection: $tab) {
                ForEach(WalletTab.allCases) { item in
                    Tab(L(item.rawValue), systemImage: item.symbol, value: item) {
                        page(for: item)
                    }
                }
            }
            .tabViewStyle(.tabBarOnly)
        } else {
            TabView(selection: $tab) {
                ForEach(WalletTab.allCases) { item in
                    page(for: item)
                        .tabItem { Label(L(item.rawValue), systemImage: item.symbol) }
                        .tag(item)
                }
            }
        }
    }

    @ViewBuilder private func page(for item: WalletTab) -> some View {
        switch item {
        case .home: DashboardView()
        case .history: HistoryView()
        case .wallet: WalletView()
        case .analytics: AnalyticsView()
        case .recurring: RecurringView()
        case .settings: SettingsView()
        }
    }
}

struct LockedView: View {
    @Environment(\.appLanguageRevision) private var languageRefresh
    @Environment(\.displayCurrencyRevision) private var moneyRefresh
    let onUnlock: () -> Void
    var body: some View {
        let _ = languageRefresh
        let _ = moneyRefresh
        VStack(spacing: 18) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48)).foregroundStyle(LedgerTheme.accent)
                .frame(width: 90, height: 90)
                .background(LedgerTheme.panel, in: RoundedRectangle(cornerRadius: 26))
            Text(L("나의 가계부")).font(.system(size: 29, weight: .bold))
            Text(L("보호된 가계부입니다")).font(.subheadline).foregroundStyle(LedgerTheme.subtext)
            Button(action: onUnlock) {
                Label(L("Face ID / 기기 암호로 열기"), systemImage: "faceid")
                    .font(.system(size: 15, weight: .bold)).frame(maxWidth: 280)
                    .padding(15).foregroundStyle(.white)
                    .background(LedgerTheme.accent, in: RoundedRectangle(cornerRadius: 15))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


// Shortcuts passes user-authorized values, not access to wallet history.
// Queue each record atomically; the live unlocked ledger consumes it to avoid
// competing writers overwriting the existing ledger file.
struct PendingApplePayment: Codable {
    let id: UUID
    let title: String
    let amount: Int
    let date: Date
}
enum PaymentInbox {
    static let changed = Notification.Name("PocketLedger.PaymentInboxChanged")
    static func folder() throws -> URL {
        let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("PaymentInbox", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var protectedDir = dir
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try protectedDir.setResourceValues(values)
        return dir
    }
    static func enqueue(_ item: PendingApplePayment) throws {
        let path = try folder().appendingPathComponent(item.id.uuidString + ".json")
        try JSONEncoder().encode(item).write(to: path, options: [.atomic, .completeFileProtection])
        NotificationCenter.default.post(name: changed, object: nil)
    }
    @MainActor static func drain(into store: LedgerStore) {
        guard let dir = try? folder(), let paths = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for path in paths where path.pathExtension == "json" {
            guard let raw = try? Data(contentsOf: path), let item = try? JSONDecoder().decode(PendingApplePayment.self, from: raw),
                  item.amount > 0, item.amount <= 1_000_000_000_000 else { continue }
            if !store.data.entries.contains(where: { $0.id == item.id }) {
                let source = UserDefaults.standard.string(forKey: "applePaymentSource").flatMap { UUID(uuidString: $0) }
                let valid = store.data.cards.contains { $0.id == source } || store.data.accounts.contains { $0.id == source }
                store.data.entries.append(MoneyEntry(id: item.id, title: "[Apple Wallet] " + item.title, amount: item.amount,
                    kind: .expense, category: .other, date: item.date, sourceId: valid ? source : nil))
            }
            // Only consume after the persisted ledger has the record.
            let ledger = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("ledger-data.json")
            if let data = try? Data(contentsOf: ledger), let saved = try? JSONDecoder().decode(LedgerData.self, from: data),
               saved.entries.contains(where: { $0.id == item.id }) { try? FileManager.default.removeItem(at: path) }
        }
    }
}
struct RecordWalletPaymentIntent: AppIntent {
    static var title: LocalizedStringResource = "Record Wallet Payment"
    static var description = IntentDescription("Record a payment supplied by your personal Shortcuts automation. Amount is a whole number; no FX conversion.")
    static var openAppWhenRun: Bool = true
    @Parameter(title: "Amount") var amount: Int
    @Parameter(title: "Merchant") var merchant: String
    @Parameter(title: "Transaction Date") var transactionDate: Date?
    @Parameter(title: "Transaction ID") var transactionID: String?
    func perform() async throws -> some IntentResult {
        guard amount > 0, amount <= 1_000_000_000_000, !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, merchant.count <= 300 else {
            throw NSError(domain: "PocketLedger", code: 1, userInfo: [NSLocalizedDescriptionKey: "Enter a positive whole amount and merchant."])
        }
        let date = transactionDate ?? .now
        let external = transactionID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let id = external.isEmpty ? UUID() : UUID.deterministic("Apple Wallet|" + external)
        try PaymentInbox.enqueue(PendingApplePayment(id: id, title: merchant, amount: amount, date: date))
        return .result()
    }
}
