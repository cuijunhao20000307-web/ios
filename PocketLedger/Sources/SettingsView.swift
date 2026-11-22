import SwiftUI
import UniformTypeIdentifiers
import UserNotifications
import UIKit
import ImageIO

struct SettingsView: View {
    @Environment(\.appLanguageRevision) private var languageRefresh
    @Environment(\.displayCurrencyRevision) private var moneyRefresh
    @EnvironmentObject private var store: LedgerStore
    @AppStorage("appLanguage") private var appLanguage = "system"
    @AppStorage("displayCurrency") private var currency = "KRW"
    @AppStorage("displayCurrencyRevision") private var currencyRevision = 0
    @AppStorage("monthlyReportEnabled") private var reportEnabled = true
    @AppStorage("monthlyReportNotifications") private var reportNotifications = false
    @State private var showCovers = false
    @State private var showReports = false
    @State private var showPaymentLinks = false
    @State private var notificationError = false
    @State private var showPrivateSettings = false
    @State private var showICloudBackup = false
    @State private var showFixedExpenses = false
    @State private var showOnlineUpdates = false
    @State private var budgetText = ""
    @State private var budgetSavedFeedback = false
    @State private var pendingDestructiveAction: SettingsDestructiveAction?
    @State private var deviceAuthUnavailable = false
    @State private var exportURL: URL?
    @State private var exportError = false

    var body: some View {
        let _ = languageRefresh
        let _ = moneyRefresh
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 13) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("설정")).font(.system(size: 30, weight: .bold))
                    Text(L("가계부를 내 방식대로")).font(.subheadline).foregroundStyle(LedgerTheme.subtext)
                }
                DuoColumns(spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                SettingsCompactSection {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 10) {
                            CompactSettingsTitle(title: "언어")
                            Spacer(minLength: 3)
                            Picker(L("언어"), selection: $appLanguage) {
                                ForEach(AppLocalization.options, id: \.0) { option in
                                    Text(option.0 == "system" ? L(option.1) : option.1).tag(option.0)
                                }
                            }.pickerStyle(.menu)
                        }
                    }
                }
                SettingsCompactSection {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 8) {
                            CompactSettingsTitle(title: "표시 통화")
                            Spacer(minLength: 4)
                            // A Picker's automatic label wraps on Duo's narrow settings column.
                            // Keep the complete selected currency code, symbol, and name inline.
                            Menu {
                                ForEach(DisplayCurrency.allCases) { item in
                                    Button {
                                        currency = item.rawValue
                                    } label: {
                                        if currency == item.rawValue {
                                            Label(item.formattedName, systemImage: "checkmark")
                                        } else {
                                            Text(item.formattedName)
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Text(DisplayCurrency(rawValue: currency)?.formattedName ?? DisplayCurrency.KRW.formattedName)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                        .allowsTightening(true)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 11, weight: .semibold))
                                        .fixedSize()
                                }
                                .foregroundStyle(LedgerTheme.accent)
                                .frame(maxWidth: 230, alignment: .trailing)
                                .contentShape(Rectangle())
                                .accessibilityLabel(L("통화"))
                            }
                            .buttonStyle(.plain)
                            .layoutPriority(1)
                        }
                        HStack(spacing: 10) {
                            Button { showCovers = true } label: {
                                Label(L("통화별 잔액 커버"), systemImage: "photo.on.rectangle")
                                    .font(.subheadline)
                            }
                            Spacer(minLength: 0)
                            Text(L("통화 기호만 변경하며 금액은 변환하지 않습니다."))
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                                .lineLimit(2).multilineTextAlignment(.trailing)
                        }
                    }
                }
                SettingsCompactSection {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 7) {
                            CompactSettingsTitle(title: "월 예산")
                            Spacer(minLength: 3)
                            TextField(L("예산"), text: $budgetText)
                                .keyboardType(.numberPad)
                                .font(.system(.body, design: .rounded))
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                                .lineLimit(1)
                                .frame(minWidth: 65, maxWidth: 128)
                                .onChange(of: budgetText) { _, _ in
                                    budgetSavedFeedback = false
                                }
                            Text(DisplayCurrency.selected.symbol)
                                .font(.subheadline)
                                .foregroundStyle(LedgerTheme.subtext)
                                .fixedSize()
                            Button {
                                store.data.monthlyBudget = max(1, budgetText.toMoneyInt)
                                budgetSavedFeedback = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: budgetSavedFeedback ? "checkmark.circle.fill" : "square.and.arrow.down")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(L(budgetSavedFeedback ? "저장 완료" : "저장"))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(budgetSavedFeedback ? Color.green : Color.white)
                                .frame(width: 85, height: 34)
                                .background(
                                    budgetSavedFeedback ? Color.green.opacity(0.12) : LedgerTheme.accent,
                                    in: Capsule()
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(L(budgetSavedFeedback ? "저장 완료" : "저장"))
                            .disabled(budgetText.toMoneyInt < 1)
                            .opacity(budgetText.toMoneyInt < 1 ? 0.45 : 1)
                        }
                    }
                }
                SettingsCompactSection {
                    VStack(alignment: .leading, spacing: 9) {
                        CompactSettingsTitle(title: "화면 테마")
                        Picker(L("테마"), selection: $store.data.appearance) {
                            ForEach(AppearanceMode.allCases) { mode in
                                Text(L(mode == .system ? "시스템 설정" : mode.rawValue)).tag(mode)
                            }
                        }.pickerStyle(.segmented)
                    }
                }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 10) {
                SettingsCompactSection {
                    VStack(alignment: .leading, spacing: 10) {
                        CompactSettingsTitle(title: "월간 결산")
                        Toggle(L("월간 결산 자동 표시"), isOn: $reportEnabled)
                        Toggle(L("매월 1일 자정 알림"), isOn: $reportNotifications)
                            .onChange(of: reportNotifications) { _, enabled in
                                Task {
                                    if !(await MonthlyReportNotice.configure(enabled, request: enabled)) {
                                        reportNotifications = false
                                        notificationError = true
                                    }
                                }
                            }
                        Button { showReports = true } label: {
                            Label(L("월간 결산 보기"), systemImage: "chart.bar.doc.horizontal")
                        }
                    }
                }
                SettingsCompactSection {
                    VStack(alignment: .leading, spacing: 9) {
                        CompactSettingsTitle(title: "매월 고정 지출 설정")
                        Button { showFixedExpenses = true } label: {
                            HStack {
                                Label(L("매월 고정 지출 설정"), systemImage: "calendar.badge.clock")
                                Spacer()
                                Text(store.data.recurringRules
                                    .filter { $0.enabled && $0.kind == .expense }
                                    .reduce(0) { $0 + $1.amount }.won)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                        }
                        Text(L("설정된 고정 지출은 앱을 열 때 지정일에 자동 기록됩니다."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                SettingsCompactSection {
                    VStack(alignment: .leading, spacing: 9) {
                        CompactSettingsTitle(title: "결제 연동")
                        Button { showPaymentLinks = true } label: {
                            HStack {
                                Label("Apple Wallet · Naver Pay · Kakao Pay · WeChat Pay", systemImage: "wallet.pass")
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption)
                            }
                        }
                        Text(L("자동 은행 조회 없이 단축어 및 CSV 가져오기를 사용합니다."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                SettingsCompactSection {
                    VStack(alignment: .leading, spacing: 10) {
                        CompactSettingsTitle(title: "보안")
                        Toggle(isOn: Binding(get: { store.data.appLockEnabled }, set: { wantsLock in
                            if wantsLock && !LocalUnlock.isAvailable() { deviceAuthUnavailable = true }
                            else { store.data.appLockEnabled = wantsLock }
                        })) {
                            Label(L("앱 열기 잠금"), systemImage: "faceid")
                        }
                        .tint(LedgerTheme.accent)
                        Text("활성화 시 앱 재실행 또는 백그라운드 복귀 후 Face ID / 기기 암호가 필요합니다. 비밀코드 확인에는 별도 인증을 사용합니다.")
                            .font(.system(size: 12)).foregroundStyle(LedgerTheme.subtext)
                    }
                }
                SettingsCompactSection {
                    VStack(alignment: .leading, spacing: 9) {
                        CompactSettingsTitle(title: "온라인 업데이트")
                        Button { showOnlineUpdates = true } label: {
                            HStack {
                                Label(L("업데이트 확인"), systemImage: "arrow.triangle.2.circlepath")
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption)
                            }
                        }
                        Text(L("업데이트를 확인하려면 인터넷 연결이 필요합니다"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                SettingsCompactSection {
                    VStack(alignment: .leading, spacing: 10) {
                        CompactSettingsTitle(title: "데이터")
                        Button { showICloudBackup = true } label: {
                            Label(L("iCloud 백업 · 복원"), systemImage: "icloud.and.arrow.up")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Divider()
                        Button { showPrivateSettings = true } label: {
                            Label(L("보관함 백업 · 글꼴 · 휴지통"), systemImage: "lock.doc")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Divider()
                        Button {
                            do { exportURL = try store.exportTransactionsCSV() }
                            catch { exportError = true }
                        } label: {
                            Label(L("거래 내역 CSV 내보내기"), systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityHint("계좌번호 및 비밀코드를 제외한 거래 내역을 파일로 공유합니다")
                        if let exportURL {
                            ShareLink(item: exportURL) {
                                Label(L("CSV 파일 공유하기"), systemImage: "doc.text")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        Divider()
                        Button { withAnimation(.easeInOut(duration: 0.20)) { pendingDestructiveAction = .sample } } label: {
                            Label(L("예시 데이터 채우기"), systemImage: "sparkles")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Divider()
                        Button(role: .destructive) { withAnimation(.easeInOut(duration: 0.20)) { pendingDestructiveAction = .reset } } label: {
                            Label(L("가계부 기록 삭제 (보관함 제외)"), systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                SettingsCompactSection {
                    VStack(alignment: .leading, spacing: 10) {
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 9) {
                                Label(L("기기 내부 저장 · 별도 서버 없음"), systemImage: "iphone")
                                Label(L("은행 · 카드 실시간 연동 없음"), systemImage: "wifi.slash")
                                Label(L("통장 비밀코드는 백업·동기화하지 않음"), systemImage: "lock.shield")
                                Text(L("이 앱은 개인 기록용 가계부 프로토타입입니다. 실제 결제 또는 은행 로그인 기능을 제공하지 않습니다."))
                                    .font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.top, 4)
                        } label: {
                            CompactSettingsTitle(title: "안내")
                        }
                    }
                    .font(.system(size: 13))
                }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("Digital Wallet · v0.4.44")
                    .font(.caption).foregroundStyle(LedgerTheme.subtext)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: 960).frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showPrivateSettings) { PrivateWalletView(initialSection: 3) }
        .sheet(isPresented: $showICloudBackup) { DigitalCloudBackupView() }
        .sheet(isPresented: $showFixedExpenses) { FixedExpensesSettingsView() }
        .sheet(isPresented: $showOnlineUpdates) { DigitalWalletOnlineUpdateView() }
        .onAppear { budgetText = String(store.data.monthlyBudget) }
        .onChange(of: currency) { _, _ in currencyRevision += 1 }
        .sheet(isPresented: $showCovers) { CurrencyCoverSettingsView() }
        .sheet(isPresented: $showReports) { MonthlyReportView() }
        .sheet(isPresented: $showPaymentLinks) { PaymentLinksView() }
        .alert(L("알림 설정을 확인하세요"), isPresented: $notificationError) { Button(L("확인")) {} }
        .alert("파일을 만들 수 없습니다", isPresented: $exportError) {
            Button(L("확인"), role: .cancel) { }
        } message: { Text("저장 공간을 확인한 후 다시 시도하세요.") }
        .alert("기기 인증을 사용할 수 없어요", isPresented: $deviceAuthUnavailable) {
            Button(L("확인"), role: .cancel) { }
        } message: {
            Text("iPhone에 Face ID 또는 잠금 암호를 설정한 뒤 다시 시도하세요.")
        }
        .overlay {
            if let action = pendingDestructiveAction {
                SettingsCenteredConfirmation(
                    action: action,
                    onCancel: { withAnimation(.easeInOut(duration: 0.18)) { pendingDestructiveAction = nil } },
                    onConfirm: {
                        // Dismiss before changing the store so the confirmation cannot be retriggered.
                        pendingDestructiveAction = nil
                        store.clear()
                        if action == .sample { store.loadSample() }
                        budgetText = String(store.data.monthlyBudget)
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: pendingDestructiveAction)

    }
}


// Compact, card-based settings keep expanded Duo and normal iPhone layouts
// aligned without wasting a full card's vertical padding for each row.
private struct SettingsCompactSection<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LedgerTheme.panel,
                        in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }
}
private struct CompactSettingsTitle: View {
    let title: String
    var body: some View {
        Text(L(title))
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

// The repeating alert contains no financial data. iOS delivers it while the
// application is closed; the actual image is rendered locally when opened.
enum MonthlyReportNotice {
    static let identifier = "pocketledger.monthly-report"
    static func configure(_ enabled: Bool, request: Bool = false) async -> Bool {
        let center = UNUserNotificationCenter.current()
        if !enabled {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            return true
        }
        do {
            if request {
                guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else { return false }
            }
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return false }
            var due = DateComponents()
            due.calendar = Calendar(identifier: .gregorian)
            due.day = 1; due.hour = 0; due.minute = 0
            let content = UNMutableNotificationContent()
            content.title = "Digital Wallet"
            content.body = L("지난달 결산이 준비되었습니다.")
            content.sound = .default
            try await center.add(UNNotificationRequest(identifier: identifier, content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: due, repeats: true)))
            return true
        } catch { return false }
    }
}

struct ReportMonth: Identifiable {
    let date: Date
    var id: Date { date }
    static var previous: Date {
        let now = Date()
        let first = Calendar.current.dateInterval(of: .month, for: now)?.start ?? now
        return Calendar.current.date(byAdding: .month, value: -1, to: first) ?? first
    }
    static func key(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)"
    }
}
struct MonthlyReportCard: View {
    let month: Date
    let entries: [MoneyEntry]
    let budget: Int
    private var spending: Int { entries.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amount } }
    private var income: Int { entries.filter { $0.kind == .income }.reduce(0) { $0 + $1.amount } }
    private var totals: [(MoneyCategory, Int)] {
        MoneyCategory.allCases.map { category in
            (category, entries.filter { $0.kind == .expense && $0.category == category }.reduce(0) { $0 + $1.amount })
        }.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("Digital Wallet", systemImage: "wallet.bifold.fill").font(.headline)
                Spacer()
                Text(month.koreanMonthTitle).font(.caption.weight(.semibold))
            }.foregroundStyle(.secondary)
            Text(L("월간 결산")).font(.largeTitle.bold())
            VStack(alignment: .leading, spacing: 8) {
                Text(L("이번 달 지출")).font(.subheadline).foregroundStyle(.white.opacity(0.75))
                Text(spending.won).font(.system(size: 37, weight: .semibold, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.35).foregroundStyle(.white)
            }
            .padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [Color(red: 0.13, green: 0.17, blue: 0.28), Color(red: 0.30, green: 0.36, blue: 0.60)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
            HStack(spacing: 12) {
                tile(L("이번 달 수입"), income.won)
                tile(L("월간 순수입"), (income - spending).won)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(L("월 지출 예산")).font(.headline)
                ProgressView(value: min(1, max(0, Double(spending) / Double(max(1, budget)))))
                    .tint(LedgerTheme.accent)
                Text(spending.won + " / " + budget.won).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.5)
                Text(L("현재 설정된 예산 기준")).font(.caption2).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text(L("카테고리별 지출")).font(.headline)
                if totals.isEmpty { Text(L("아직 지출이 없어요")).foregroundStyle(.secondary) }
                ForEach(totals.prefix(5), id: \.0) { item in
                    VStack(spacing: 5) {
                        HStack {
                            Label(L(item.0.rawValue), systemImage: item.0.icon)
                            Spacer()
                            Text(item.1.won).monospacedDigit()
                        }.font(.subheadline).lineLimit(1).minimumScaleFactor(0.6)
                        GeometryReader { geo in
                            Capsule().fill(item.0.color).frame(width: geo.size.width * CGFloat(item.1) / CGFloat(max(1, spending)))
                        }.frame(height: 6).background(Color.secondary.opacity(0.12), in: Capsule())
                    }
                }
            }
            HStack {
                Text(L("거래 내역")).font(.subheadline)
                Spacer()
                Text(String(entries.count) + " " + L("건")).font(.headline.monospacedDigit())
            }
        }.padding(24).background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 28))
    }
    private func tile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.4)
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
struct MonthlyReportView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State var month: Date = ReportMonth.previous
    @State private var imageURL: URL?
    @State private var imageError = false
    private var card: MonthlyReportCard {
        MonthlyReportCard(month: month, entries: store.entries(in: month), budget: store.data.monthlyBudget)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Button { change(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        Spacer()
                        Text(month.koreanMonthTitle).font(.headline)
                        Spacer()
                        Button { change(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                            .disabled(ReportMonth.key(month) == ReportMonth.key(ReportMonth.previous))
                    }.buttonStyle(.plain)
                    card
                    if let imageURL {
                        ShareLink(item: imageURL) { Label(L("결산 이미지 공유"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button { render() } label: { Label(L("결산 이미지 만들기"), systemImage: "photo").frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent)
                    }
                }.padding(16).frame(maxWidth: 520).frame(maxWidth: .infinity)
            }
            .background(LedgerTheme.background)
            .navigationTitle(L("월간 결산"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("닫기")) { dismiss() } } }
            .privacySensitive()
            .overlay { if phase != .active { Color(uiColor: .systemBackground).ignoresSafeArea() } }
            .alert(L("파일을 만들 수 없습니다"), isPresented: $imageError) { Button(L("확인")) {} }
        }
        .onDisappear { removeImage() }
    }
    private func change(_ n: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: n, to: month), next <= ReportMonth.previous else { return }
        removeImage(); month = next
    }
    @MainActor private func render() {
        let renderer = ImageRenderer(content: card.frame(width: 380).padding(12).background(Color(uiColor: .systemGroupedBackground)).environment(\.colorScheme, .light))
        renderer.scale = 3
        guard let bytes = renderer.uiImage?.pngData() else { imageError = true; return }
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("PocketLedger-\(ReportMonth.key(month))-\(UUID().uuidString).png")
        do { try bytes.write(to: path, options: [.atomic, .completeFileProtection]); imageURL = path }
        catch { imageError = true }
    }
    private func removeImage() {
        if let imageURL { try? FileManager.default.removeItem(at: imageURL) }
        imageURL = nil
    }
}

enum PaymentProvider: String, CaseIterable, Identifiable {
    case apple = "Apple Wallet", naver = "Naver Pay", kakao = "Kakao Pay", wechat = "WeChat Pay"
    var id: String { rawValue }
    var icon: String {
        switch self { case .apple: "wallet.pass"; case .naver, .kakao: "creditcard"; case .wechat: "message.fill" }
    }
}
struct PaymentImport: Identifiable {
    let id: UUID
    let title: String
    let amount: Int
    let date: Date
    let kind: MoneyKind
}
enum PaymentCSV {
    // Standard UTF-8 CSV, including quoted fields, escaped quotes and CRLF.
    static func rows(_ text: String) -> [[String]] {
        let chars = Array(text.replacingOccurrences(of: "\u{FEFF}", with: "").replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n"))
        var result: [[String]] = []; var row: [String] = []; var field = ""; var quoted = false; var i = 0
        while i < chars.count {
            let char = chars[i]
            if char == "\"" {
                if quoted && i + 1 < chars.count && chars[i + 1] == "\"" { field.append("\""); i += 1 }
                else { quoted.toggle() }
            } else if char == "," && !quoted { row.append(field); field = "" }
            else if char == "\n" && !quoted { row.append(field); result.append(row); row = []; field = "" }
            else { field.append(char) }
            i += 1
        }
        if quoted { return [] }
        if !field.isEmpty || !row.isEmpty { row.append(field); result.append(row) }
        return result
    }
    static func parse(_ text: String, provider: PaymentProvider) -> (items: [PaymentImport], skipped: Int) {
        let table = rows(text)
        let dateKeys = ["date", "날짜", "거래일시", "결제일시", "交易时间", "交易日期"]
        let merchantKeys = ["merchant", "title", "내용", "가맹점", "상호명", "결제처", "交易对方", "商户名称"]
        let amountKeys = ["amount", "금액", "금액(원)", "결제금액", "金额(元)", "金额（元）", "金额"]
        let kindKeys = ["kind", "구분", "收/支", "收支"]
        let idKeys = ["id", "transaction_id", "거래번호", "결제번호", "交易单号"]
        let normalize: (String) -> String = { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        guard let headerIndex = table.firstIndex(where: { row in
            let headers = row.map(normalize)
            return headers.contains(where: { dateKeys.contains($0) }) && headers.contains(where: { merchantKeys.contains($0) }) &&
                headers.contains(where: { amountKeys.contains($0) }) && headers.contains(where: { kindKeys.contains($0) })
        }) else { return ([], table.count) }
        let headers = table[headerIndex].map(normalize)
        func index(_ keys: [String]) -> Int? { headers.firstIndex(where: { keys.contains($0) }) }
        guard let dateColumn = index(dateKeys), let merchantColumn = index(merchantKeys), let amountColumn = index(amountKeys), let kindColumn = index(kindKeys) else { return ([], 0) }
        let idColumn = index(idKeys)
        let statusColumn = index(["当前状态", "거래상태", "status"])
        let parser = DateFormatter(); parser.locale = Locale(identifier: "en_US_POSIX"); parser.isLenient = false
        let iso = ISO8601DateFormatter()
        var items: [PaymentImport] = []; var skipped = 0; var occurrences: [String: Int] = [:]
        for row in table.dropFirst(headerIndex + 1) {
            guard !row.allSatisfy({ normalize($0).isEmpty }) else { continue }
            func field(_ i: Int?) -> String {
                guard let i, row.indices.contains(i) else { return "" }
                return row[i].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let rawDate = field(dateColumn)
            var date = iso.date(from: rawDate)
            if date == nil {
                for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd", "yyyy.MM.dd HH:mm:ss", "yyyy.MM.dd"] {
                    parser.dateFormat = format
                    if let parsed = parser.date(from: rawDate) { date = parsed; break }
                }
            }
            let rawKind = normalize(field(kindColumn))
            let kind: MoneyKind?
            switch rawKind {
            case "expense", "지출", "支出": kind = .expense
            case "income", "수입", "收入": kind = .income
            default: kind = nil
            }
            let amountText = field(amountColumn).replacingOccurrences(of: ",", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "₩¥￥$€£ "))
            let merchant = field(merchantColumn)
            let status = normalize(field(statusColumn))
            guard let date, let kind, let number = Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX")),
                  number > 0, number <= 1_000_000_000_000,
                  number == Decimal(NSDecimalNumber(decimal: number).int64Value),
                  !merchant.isEmpty, merchant.count <= 300,
                  status.isEmpty || ["success", "completed", "결제완료", "결제 완료", "완료", "支付成功", "已支付", "已收款", "交易成功", "对方已收钱"].contains(status)
            else { skipped += 1; continue }
            let amount = Int(NSDecimalNumber(decimal: number).int64Value)
            let external = field(idColumn)
            let key = provider.rawValue + "|" + (external.isEmpty ? "\(rawDate)|\(merchant)|\(kind.rawValue)|\(amount)" : external)
            let sequence = occurrences[key, default: 0]
            occurrences[key] = sequence + 1
            let id = UUID.deterministic(external.isEmpty ? key + "|\(sequence)" : key)
            if items.contains(where: { $0.id == id }) { skipped += 1; continue }
            items.append(PaymentImport(id: id, title: "[\(provider.rawValue)] \(merchant)", amount: amount, date: date, kind: kind))
        }
        return (items, skipped)
    }
}
struct PaymentLinksView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss
    @State private var provider: PaymentProvider = .naver
    @State private var source = "none"
    @State private var category: MoneyCategory = .other
    @State private var importing = false
    @State private var preview: [PaymentImport] = []
    @State private var skipped = 0
    @State private var message: String?
    @AppStorage("applePaymentSource") private var appleSource = "none"
    @Environment(\.openURL) private var openURL
    private var newItems: [PaymentImport] { preview.filter { item in !store.data.entries.contains { $0.id == item.id } } }
    var body: some View {
        NavigationStack {
            Form {
                Section("Apple Wallet") {
                    Button {
                        if let url = URL(string: "shortcuts://") { openURL(url) }
                    } label: {
                        Label(L("Apple Pay 바로가기 설정"), systemImage: "square.stack.3d.up")
                    }
                    Text(L("단축어 앱 → 자동화 → + → 거래(Transaction) → 카드 선택 → 즉시 실행 → Digital Wallet의 Record Wallet Payment 동작 추가. 결제 금액·가맹점을 변수로 연결하고 저장하세요."))
                        .font(.caption).foregroundStyle(.secondary)
                    Button {
                        UIPasteboard.general.string = L("단축어 앱 → 자동화 → + → 거래(Transaction) → 카드 선택 → 즉시 실행 → Digital Wallet의 Record Wallet Payment 동작 추가. 결제 금액·가맹점을 변수로 연결하고 저장하세요.")
                    } label: {
                        Label(L("연동 절차 복사"), systemImage: "doc.on.doc")
                    }
                    Text(L("단축어 앱의 거래 자동화에서 Digital Wallet 결제 기록 동작을 추가하세요. 금액과 가맹점, 가능하면 거래 날짜 및 고유 ID를 전달합니다."))
                        .font(.subheadline)
                    Picker(L("결제 수단 · 선택"), selection: $appleSource) { sources }
                    Text(L("카드 결제 전체 내역을 직접 조회하지 않습니다. 입력값은 변환하지 않습니다."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section(L("결제 내역 가져오기")) {
                    Picker(L("결제 연동"), selection: $provider) {
                        ForEach(PaymentProvider.allCases) { Label($0.rawValue, systemImage: $0.icon).tag($0) }
                    }
                    Picker(L("결제 수단 · 선택"), selection: $source) { sources }
                    Picker(L("카테고리"), selection: $category) {
                        ForEach(MoneyCategory.selectableCases) { Text(L($0.rawValue)).tag($0) }
                    }
                    Button { importing = true } label: { Label(L("CSV 가져오기"), systemImage: "doc.badge.plus") }
                    Text("date,merchant,amount,kind,id\n2026-01-01,Sample,1000,expense,example-1")
                        .font(.caption.monospaced()).textSelection(.enabled)
                    Text(L("UTF-8 CSV 형식으로 가져오세요. 취소·미완료·소수 금액은 제외하며 실제 결제 통화는 변환하지 않습니다."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !preview.isEmpty {
                    Section(L("가져오기 미리보기")) {
                        Text(L("새 거래") + ": \(newItems.count) · " + L("중복") + ": \(preview.count - newItems.count) · " + L("제외") + ": \(skipped)")
                            .font(.caption)
                        ForEach(newItems.prefix(30)) { item in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.title).lineLimit(2)
                                HStack {
                                    Text(item.date.formatted(date: .abbreviated, time: .omitted))
                                    Spacer()
                                    Text((item.kind == .expense ? "−" : "+") + item.amount.won)
                                }.font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Button(L("확인 후 가져오기")) { commit() }.disabled(newItems.isEmpty)
                        Button(L("취소"), role: .cancel) { preview = []; skipped = 0 }
                    }
                }
            }
            .navigationTitle(L("결제 연동"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("닫기")) { dismiss() } } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                do {
                    let file = try result.get()
                    let scoped = file.startAccessingSecurityScopedResource()
                    defer { if scoped { file.stopAccessingSecurityScopedResource() } }
                    guard (try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 2_000_001) <= 2_000_000 else { message = L("CSV 파일을 확인하세요"); return }
                    let contents = try String(contentsOf: file, encoding: .utf8)
                    let parsed = PaymentCSV.parse(contents, provider: provider)
                    preview = parsed.items; skipped = parsed.skipped
                    if preview.isEmpty { message = L("CSV 파일을 확인하세요") }
                } catch { message = L("CSV 파일을 확인하세요") }
            }
            .onChange(of: provider) { _, _ in preview = []; skipped = 0 }
            .alert(L("확인"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button(L("확인")) { message = nil }
            } message: { Text(message ?? "") }
        }
    }
    @ViewBuilder private var sources: some View {
        Text(L("선택 안 함")).tag("none")
        ForEach(store.data.cards) { Text($0.name).tag($0.id.uuidString) }
        ForEach(store.data.accounts) { Text($0.nickname).tag($0.id.uuidString) }
    }
    private func commit() {
        let items = newItems
        let sourceId = UUID(uuidString: source)
        store.data.entries.append(contentsOf: items.map {
            MoneyEntry(id: $0.id, title: $0.title, amount: $0.amount, kind: $0.kind, category: category, date: $0.date, sourceId: sourceId)
        })
        message = L("가져오기 완료") + ": \(items.count)"
        preview = []; skipped = 0
    }
}


// Currency artwork is decorative, not a currency conversion or online bank feature.
enum CurrencyCoverStore {
    static let codes = ["KRW", "CNY", "JPY", "USD"]
    private static func directory() throws -> URL {
        let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("CurrencyCovers", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    static func image(_ code: String) -> UIImage? {
        guard codes.contains(code) else { return nil }
        if let path = try? directory().appendingPathComponent(code + ".png"),
           let img = UIImage(contentsOfFile: path.path) { return img }
        return UIImage(named: "balance-cover-" + code)
    }
    static func importFiles(_ urls: [URL]) -> (count: Int, failed: Int) {
        var count = 0
        var failed = 0
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let name = url.deletingPathExtension().lastPathComponent.uppercased()
                guard let code = codes.first(where: { name == $0 || name.hasPrefix($0 + "_") || name.hasPrefix($0 + "-") }),
                      url.pathExtension.lowercased() == "png",
                      (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 25_000_001) <= 25_000_000
                else { failed += 1; continue }
                let data = try Data(contentsOf: url)
                guard data.count <= 25_000_000,
                      let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                      (properties[kCGImagePropertyPixelWidth] as? Int) == 2240,
                      (properties[kCGImagePropertyPixelHeight] as? Int) == 1000,
                      CGImageSourceCreateImageAtIndex(source, 0, nil) != nil
                else { failed += 1; continue }
                try data.write(to: directory().appendingPathComponent(code + ".png"), options: [.atomic, .completeFileProtection])
                count += 1
            } catch { failed += 1 }
        }
        return (count, failed)
    }
}

struct CurrencyCoverSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("currencyCoverRevision") private var revision = 0
    @State private var picking = false
    @State private var message: String?
    var body: some View {
        let _ = revision
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(L("KRW · CNY · JPY · USD 커버를 한 번 가져오면 통화 선택에 맞춰 자동으로 표시됩니다."))
                        .font(.subheadline).foregroundStyle(.secondary)
                    ForEach(CurrencyCoverStore.codes, id: \.self) { code in
                        Surface {
                            VStack(alignment: .leading, spacing: 8) {
                                Text((DisplayCurrency(rawValue: code)?.formattedName) ?? code).font(.headline)
                                if let image = CurrencyCoverStore.image(code) {
                                    Image(uiImage: image).resizable().scaledToFit()
                                        .aspectRatio(2.24, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                } else {
                                    Label(L("커버 미등록"), systemImage: "photo")
                                        .foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 54)
                                }
                            }
                        }
                    }
                    Button { picking = true } label: {
                        Label(L("커버 PNG 가져오기"), systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent)
                    Text("KRW.png · CNY.png · JPY.png · USD.png\n2240 × 1000 px")
                        .font(.caption.monospaced()).foregroundStyle(.secondary)
                }.padding(16).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .navigationTitle(L("통화별 잔액 커버"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("닫기")) { dismiss() } } }
            .fileImporter(isPresented: $picking, allowedContentTypes: [.png], allowsMultipleSelection: true) { result in
                do {
                    let response = CurrencyCoverStore.importFiles(try result.get())
                    revision += 1
                    message = L("가져오기 완료") + ": \(response.count) · " + L("제외") + ": \(response.failed)"
                } catch { message = L("커버 파일을 확인하세요") }
            }
            .alert(L("확인"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button(L("확인")) { message = nil }
            } message: { Text(message ?? "") }
        }
    }
}


// The platform confirmationDialog is represented as a floating popover on
// certain Duo expanded layouts and may be clipped by the scrolled viewport.
// Use a viewport-centered, two-action confirmation instead, never anchored
// to the tapped row. Destructive operations require a second explicit tap.
private enum SettingsDestructiveAction: Equatable {
    case sample
    case reset

    var title: String {
        switch self {
        case .sample: "현재 데이터를 예시 데이터로 바꿀까요?"
        case .reset: "모든 가계부 데이터를 삭제할까요?"
        }
    }
    var details: String {
        switch self {
        case .sample: "기존 거래·카드·통장과 은행 보안 정보가 삭제되고 예시 데이터로 교체됩니다. 개인정보 보관함은 유지됩니다."
        case .reset: "거래·카드·통장과 관련 은행 보안 정보가 영구 삭제됩니다. 개인정보 보관함은 유지됩니다. 이 작업은 되돌릴 수 없습니다."
        }
    }
    var buttonTitle: String {
        switch self {
        case .sample: "예시 데이터로 교체"
        case .reset: "모두 삭제"
        }
    }
}

private struct SettingsCenteredConfirmation: View {
    let action: SettingsDestructiveAction
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.23)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onCancel)

                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: action == .sample ? "exclamationmark.triangle.fill" : "trash.fill")
                            .font(.title3)
                            .foregroundStyle(action == .sample ? Color.orange : Color.red)
                            .frame(width: 34, height: 34)
                            .background((action == .sample ? Color.orange : Color.red).opacity(0.11),
                                        in: RoundedRectangle(cornerRadius: 10))
                        Text(L(action.title))
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(L(action.details))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Button(action: onCancel) {
                            Text(L("취소"))
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.bordered)
                        .tint(.secondary)

                        Button(role: .destructive, action: onConfirm) {
                            Text(L(action.buttonTitle))
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                    .padding(.top, 4)
                }
                .padding(22)
                .frame(maxWidth: min(430, max(260, geometry.size.width - 36)))
                .background(Color(uiColor: .systemBackground),
                            in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.16), radius: 24, y: 12)
                .padding(.horizontal, 16)
                .accessibilityElement(children: .contain)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}



// GitHub Release is the preferred stable channel. While this personal
// repository has no Releases, the most recent successful Actions IPA is
// a read-only fallback. Neither path installs unsigned code in-app.
private struct DigitalWalletUpdateCandidate {
    let version: String
    let url: URL
    let notes: String
    let channel: String
    let downloadURL: URL?
}

private enum DigitalWalletUpdateSource {
    private static let api = "https://api.github.com/repos/cuijunhao20000307-web/ios"
    private static let ownerRepoPath = "/cuijunhao20000307-web/ios/"

    private struct Release: Decodable {
        var tag_name: String
        var html_url: URL
        var body: String?
        var draft: Bool
        var prerelease: Bool
        var assets: [ReleaseAsset]
    }
    private struct ReleaseAsset: Decodable {
        var name: String
        var browser_download_url: URL?
    }
    private struct Runs: Decodable {
        var workflow_runs: [Run]
    }
    private struct Run: Decodable {
        var id: Int
        var status: String
        var conclusion: String?
        var head_branch: String?
        var name: String?
        var html_url: URL
    }
    private struct ArtifactResult: Decodable {
        var artifacts: [Artifact]
    }
    private struct Artifact: Decodable {
        var name: String
        var expired: Bool
    }
    private enum CheckError: Error {
        case unavailable
    }
    private static func safeGitHub(_ url: URL) -> Bool {
        url.scheme == "https" &&
        url.host?.lowercased() == "github.com" &&
        url.path.hasPrefix(ownerRepoPath)
    }
    // Never download an arbitrary URL from remote release metadata.
    // IPA distribution is limited to this repository's public HTTPS release assets.
    private static func verifiedIPADownload(_ asset: ReleaseAsset) -> URL? {
        guard asset.name.lowercased().hasSuffix(".ipa"),
              let url = asset.browser_download_url,
              safeGitHub(url),
              url.path.hasPrefix(ownerRepoPath + "releases/download/") else { return nil }
        return url
    }
    private static func versionParts(_ name: String) -> [Int]? {
        let raw = name.hasPrefix("v") ? String(name.dropFirst()) : name
        let parts = raw.split(separator: ".")
        guard parts.count == 3,
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) else { return nil }
        let numbers = parts.compactMap { Int($0) }
        return numbers.count == 3 ? numbers : nil
    }
    static func isNewer(_ remote: String, than installed: String) -> Bool {
        guard let lhs = versionParts(remote), let rhs = versionParts(installed) else { return false }
        for i in 0..<3 {
            if lhs[i] != rhs[i] { return lhs[i] > rhs[i] }
        }
        return false
    }
    private static func best(_ list: [DigitalWalletUpdateCandidate]) -> DigitalWalletUpdateCandidate? {
        list.max { left, right in isNewer(right.version, than: left.version) }
    }
    private static func fetchJSON<T: Decodable>(_ suffix: String) async throws -> T {
        guard let url = URL(string: api + suffix) else { throw CheckError.unavailable }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("DigitalWallet-iOS-Updater", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              data.count <= 2_000_000 else { throw CheckError.unavailable }
        return try JSONDecoder().decode(T.self, from: data)
    }
    static func latest() async throws -> DigitalWalletUpdateCandidate? {
        var choices: [DigitalWalletUpdateCandidate] = []
        var feedWasReachable = false
        do {
            let releases: [Release] = try await fetchJSON("/releases")
            feedWasReachable = true
            for release in releases where !release.draft && !release.prerelease {
                guard safeGitHub(release.html_url),
                      versionParts(release.tag_name) != nil,
                      let assetURL = release.assets.compactMap(verifiedIPADownload).first
                else { continue }
                choices.append(DigitalWalletUpdateCandidate(
                    version: release.tag_name,
                    url: release.html_url,
                    notes: String((release.body ?? "").prefix(2400)),
                    channel: "공식 릴리스",
                    downloadURL: assetURL))
            }
        } catch {
            // Network failures on one GitHub endpoint do not stop fallback.
        }
        do {
            let result: Runs = try await fetchJSON("/actions/workflows/build-unsigned-ipa.yml/runs?per_page=15")
            feedWasReachable = true
            for run in result.workflow_runs.prefix(15)
                where run.status == "completed" && run.conclusion == "success" &&
                      run.head_branch == "main" &&
                      run.name == "Build PocketLedger unsigned IPA" && safeGitHub(run.html_url) {
                do {
                    let artifacts: ArtifactResult = try await fetchJSON("/actions/runs/\(run.id)/artifacts")
                    for artifact in artifacts.artifacts where !artifact.expired {
                        let prefix = "PocketLedger-v"
                        let suffix = "-unsigned-ipa"
                        guard artifact.name.hasPrefix(prefix), artifact.name.hasSuffix(suffix) else { continue }
                        let candidateVersion = String(artifact.name.dropFirst(prefix.count)
                            .dropLast(suffix.count))
                        guard versionParts(candidateVersion) != nil else { continue }
                        choices.append(DigitalWalletUpdateCandidate(
                            version: candidateVersion,
                            url: run.html_url,
                            notes: "",
                            channel: "GitHub 빌드",
                            downloadURL: nil))
                    }
                    // The most recent available successful build is sufficient.
                    if choices.contains(where: { $0.url == run.html_url }) { break }
                } catch { continue }
            }
        } catch {
            // A valid Release remains usable if Actions is unavailable.
        }
        guard feedWasReachable else { throw CheckError.unavailable }
        return best(choices)
    }
}

private struct DigitalWalletOnlineUpdateView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var loading = false
    @State private var checked = false
    @State private var latest: DigitalWalletUpdateCandidate?
    @State private var failed = false
    @State private var downloading = false
    @State private var downloadError: String?
    @State private var downloadedFile: DigitalWalletDownloadedFile?

    private var installed: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }
    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(L("설치된 버전"),
                                   value: "v" + installed + " · Build " + build)
                    Button {
                        Task { await check() }
                    } label: {
                        Label(L("업데이트 확인"), systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(loading)
                    if loading {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(L("업데이트 확인 중"))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section(L("온라인 업데이트")) {
                    if checked && failed {
                        Label(L("업데이트 확인 실패"), systemImage: "wifi.exclamationmark")
                            .foregroundStyle(.orange)
                        Text(L("업데이트를 확인하려면 인터넷 연결이 필요합니다"))
                            .font(.caption).foregroundStyle(.secondary)
                    } else if let latest {
                        let hasNewer = DigitalWalletUpdateSource.isNewer(latest.version, than: installed)
                        Label(L(hasNewer ? "새 버전" : "최신 버전입니다"),
                              systemImage: hasNewer ? "arrow.down.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(hasNewer ? LedgerTheme.accent : .green)
                        LabeledContent(L("새 버전"), value: latest.version)
                        Text(L(latest.channel))
                            .font(.caption).foregroundStyle(.secondary)
                        if !latest.notes.isEmpty {
                            Text(L("업데이트 내용")).font(.subheadline.weight(.semibold))
                            Text(latest.notes)
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                        if hasNewer, latest.downloadURL != nil {
                            Button {
                                Task { await downloadIPA(latest) }
                            } label: {
                                Label(L("앱에서 IPA 다운로드"), systemImage: "arrow.down.to.line")
                            }
                            .disabled(downloading)
                            if downloading {
                                HStack(spacing: 10) {
                                    ProgressView()
                                    Text(L("IPA 다운로드 중"))
                                }
                            }
                        } else if hasNewer {
                            Text(L("GitHub Actions 빌드는 직접 다운로드할 수 없습니다. 릴리스 IPA가 게시되면 앱 안에서 다운로드할 수 있습니다."))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Link(destination: latest.url) {
                            Label(L("GitHub에서 업데이트 열기"),
                                  systemImage: "arrow.up.right.square")
                        }
                    } else if checked {
                        Label(L("다운로드 가능한 버전이 없습니다"),
                              systemImage: "shippingbox")
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    Text(L("서명 후 설치 안내"))
                    Text(L("앱은 자동으로 IPA를 설치할 수 없습니다"))
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            .navigationTitle(L("온라인 업데이트"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("닫기")) { dismiss() }
                }
            }
            .task { if !checked { await check() } }
            .sheet(item: $downloadedFile) { selected in
                DigitalWalletIPAExporter(url: selected.url)
            }
            .alert(L("IPA 다운로드 실패"), isPresented: Binding(
                get: { downloadError != nil },
                set: { if !$0 { downloadError = nil } }
            )) {
                Button(L("확인")) { downloadError = nil }
            } message: {
                Text(downloadError ?? "")
            }
        }
    }
    @MainActor private func downloadIPA(_ candidate: DigitalWalletUpdateCandidate) async {
        guard !downloading,
              let url = candidate.downloadURL,
              url.scheme == "https",
              url.host?.lowercased() == "github.com",
              url.path.hasPrefix("/cuijunhao20000307-web/ios/releases/download/"),
              DigitalWalletUpdateSource.isNewer(candidate.version, than: installed)
        else { return }
        downloading = true
        defer { downloading = false }
        do {
            // Download the actual IPA rather than presenting an Actions web page.
            let (temporary, response) = try await URLSession.shared.download(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw DigitalWalletUpdateDownloadError.invalid
            }
            let fileSize = try temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard fileSize >= 100_000, fileSize <= 200_000_000 else {
                throw DigitalWalletUpdateDownloadError.invalid
            }
            let handle = try FileHandle(forReadingFrom: temporary)
            let magic = try handle.read(upToCount: 4)
            try handle.close()
            // An IPA is a ZIP archive. Do not execute or unzip it in the app.
            guard magic == Data([0x50, 0x4b, 0x03, 0x04]) else {
                throw DigitalWalletUpdateDownloadError.invalid
            }
            let safeVersion = candidate.version.filter { $0.isNumber || $0 == "." }
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("Digital-Wallet-v" + safeVersion + "-unsigned.ipa")
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: temporary, to: destination)
            downloadedFile = DigitalWalletDownloadedFile(url: destination)
        } catch {
            downloadError = error.localizedDescription
        }
    }
    @MainActor private func check() async {
        guard !loading else { return }
        loading = true
        defer { loading = false; checked = true }
        do {
            latest = try await DigitalWalletUpdateSource.latest()
            failed = false
        } catch {
            latest = nil
            failed = true
        }
    }
}

private enum DigitalWalletUpdateDownloadError: LocalizedError {
    case invalid
    var errorDescription: String? {
        "The IPA download failed validation. Use the verified GitHub release page instead."
    }
}

private struct DigitalWalletDownloadedFile: Identifiable {
    let id = UUID()
    let url: URL
}

private struct DigitalWalletIPAExporter: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
