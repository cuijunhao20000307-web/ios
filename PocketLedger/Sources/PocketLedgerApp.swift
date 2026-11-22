import SwiftUI

@main
struct PocketLedgerApp: App {
    @StateObject private var store = LedgerStore()

    var body: some Scene {
        WindowGroup {
            AppShell()
                .environmentObject(store)
                .preferredColorScheme(store.data.appearance.colorScheme)
                .tint(LedgerTheme.accent)
        }
    }
}

struct AppShell: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: WalletTab = .home
    @State private var unlocked = false

    var body: some View {
        GeometryReader { proxy in
            let ratio = proxy.size.width / max(proxy.size.height, 1)
            let duoLike = proxy.size.width >= 600 && ratio > 1.05
            let rightRail = store.data.dockPlacement == .right ||
                (store.data.dockPlacement == .automatic && duoLike)
            ZStack {
                LedgerTheme.background.ignoresSafeArea()
                if store.data.appLockEnabled && !unlocked {
                    LockedView {
                        Task { unlocked = await LocalUnlock.authorize() }
                    }
                } else if rightRail {
                    HStack(spacing: 0) {
                        page
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        LedgerDock(selection: $tab, vertical: true)
                            .padding(.trailing, 12)
                    }
                } else {
                    VStack(spacing: 0) {
                        page.frame(maxWidth: .infinity, maxHeight: .infinity)
                        LedgerDock(selection: $tab, vertical: false)
                            .padding(.horizontal, 14)
                            .padding(.bottom, 5)
                    }
                }
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

    @ViewBuilder private var page: some View {
        switch tab {
        case .home: DashboardView()
        case .history: HistoryView()
        case .wallet: WalletView()
        case .analytics: AnalyticsView()
        case .recurring: RecurringView()
        case .settings: SettingsView()
        }
    }
}

struct LedgerDock: View {
    @Binding var selection: WalletTab
    let vertical: Bool

    var body: some View {
        Group {
            if vertical {
                VStack(spacing: 10) { tabs }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 9)
                    .frame(width: 76)
            } else {
                HStack(spacing: 0) { tabs }
                    .padding(.vertical, 11)
                    .padding(.horizontal, 8)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 27, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 27).stroke(.white.opacity(0.8), lineWidth: 1))
        .shadow(color: .black.opacity(0.07), radius: 14, y: 5)
    }

    @ViewBuilder private var tabs: some View {
        ForEach(WalletTab.allCases) { item in
            Button { selection = item } label: {
                VStack(spacing: 6) {
                    Image(systemName: item.symbol)
                        .font(.system(size: vertical ? 21 : 20, weight: selection == item ? .semibold : .regular))
                        .frame(height: 23)
                    Text(item.rawValue)
                        .font(.system(size: 10, weight: selection == item ? .bold : .medium))
                }
                .foregroundStyle(selection == item ? LedgerTheme.accent : LedgerTheme.subtext)
                .frame(maxWidth: vertical ? nil : .infinity)
.frame(width: vertical ? 55 : nil, height: vertical ? 47 : 45)
                .background(selection == item ? LedgerTheme.accent.opacity(0.10) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.rawValue + " 탭")
        }
    }
}

struct LockedView: View {
    let onUnlock: () -> Void
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48)).foregroundStyle(LedgerTheme.accent)
                .frame(width: 90, height: 90)
                .background(.white, in: RoundedRectangle(cornerRadius: 26))
            Text("나의 가계부").font(.system(size: 29, weight: .bold))
            Text("보호된 가계부입니다").font(.subheadline).foregroundStyle(LedgerTheme.subtext)
            Button(action: onUnlock) {
                Label("Face ID / 기기 암호로 열기", systemImage: "faceid")
                    .font(.system(size: 15, weight: .bold)).frame(maxWidth: 280)
                    .padding(15).foregroundStyle(.white)
                    .background(LedgerTheme.accent, in: RoundedRectangle(cornerRadius: 15))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
