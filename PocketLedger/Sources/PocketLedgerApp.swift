import SwiftUI

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
        .onChange(of: store.data.appLockEnabled) { _, enabled in
            unlocked = !enabled
            if enabled { Task { unlocked = await LocalUnlock.authorize() } }
        }
        .task {
            if store.data.appLockEnabled { unlocked = await LocalUnlock.authorize() }
            else { unlocked = true }
        }
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
