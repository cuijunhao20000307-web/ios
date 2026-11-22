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
            // Manual right mode also works in an OS-constrained portrait viewport.
            // The OS-owned status/media strip outside this scene is not drawable.
            let wide = proxy.size.width >= 580
            let hasVerticalRoom = proxy.size.height >= 330
            let rightRail = hasVerticalRoom && (
                store.data.dockPlacement == .right ||
                (store.data.dockPlacement == .automatic && wide)
            )
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
                            .layoutPriority(1)
                        LedgerDock(selection: $tab, vertical: true, compact: !wide)
                            .padding(.trailing, wide ? 8 : 3)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    var compact = false

    var body: some View {
        if vertical {
            glassSurface(
                VStack(spacing: compact ? 2 : 5) { tabs }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 2)
                    .frame(width: compact ? 48 : 64)
            )
        } else {
            glassSurface(
                HStack(spacing: 0) { tabs }
                    .padding(.vertical, 7)
                    .padding(.horizontal, 4)
            )
        }
    }

    @ViewBuilder private func glassSurface<Content: View>(_ content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 25))
        } else {
            fallbackGlass(content)
        }
        #else
        fallbackGlass(content)
        #endif
    }

    private func fallbackGlass<Content: View>(_ content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 25).strokeBorder(
                LinearGradient(colors: [.white.opacity(0.65), .white.opacity(0.08), .white.opacity(0.3)],
                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
    }

    @ViewBuilder private var tabs: some View {
        ForEach(WalletTab.allCases) { item in
            Button { selection = item } label: {
                VStack(spacing: 3) {
                    Image(systemName: item.symbol)
                        .font(.system(size: compact ? 18 : 21, weight: selection == item ? .semibold : .regular))
                        .frame(height: 23)
                    Text(item.rawValue)
                        .font(.system(size: compact ? 9 : 10, weight: selection == item ? .bold : .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(selection == item ? LedgerTheme.accent : LedgerTheme.subtext)
                .frame(maxWidth: vertical ? nil : .infinity)
                .frame(width: vertical ? (compact ? 44 : 58) : nil, height: 44)
                .background(selection == item ? LedgerTheme.accent.opacity(0.14) : Color.clear,
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
                .background(LedgerTheme.panel, in: RoundedRectangle(cornerRadius: 26))
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
