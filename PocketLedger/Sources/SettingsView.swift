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
    @State private var budgetText = ""
    @State private var confirmReset = false
    @State private var confirmSample = false
    @State private var deviceAuthUnavailable = false
    @State private var exportURL: URL?
    @State private var exportError = false

    var body: some View {
        let _ = languageRefresh
        let _ = moneyRefresh
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L("설정")).font(.system(size: 30, weight: .bold))
                    Text(L("가계부를 내 방식대로")).font(.subheadline).foregroundStyle(LedgerTheme.subtext)
                }
                DuoColumns(spacing: 20) {
                    VStack(alignment: .leading, spacing: 20) {
                Surface {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading(title: "언어")
                        Picker(L("언어"), selection: $appLanguage) {
                            ForEach(AppLocalization.options, id: \.0) { option in
                                Text(option.0 == "system" ? L(option.1) : option.1).tag(option.0)
                            }
                        }.pickerStyle(.menu)
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading(title: "표시 통화")
                        Picker(L("통화"), selection: $currency) {
                            ForEach(DisplayCurrency.allCases) { item in
                                Text(item.formattedName).tag(item.rawValue)
                            }
                        }.pickerStyle(.menu)
                        Button { showCovers = true } label: {
                            Label(L("통화별 잔액 커버"), systemImage: "photo.on.rectangle")
                        }
                        Text(L("통화 기호만 변경하며 금액은 변환하지 않습니다."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeading(title: "월 예산")
                        HStack {
                            TextField(L("예산"), text: $budgetText).keyboardType(.numberPad)
                                .font(.system(.body, design: .rounded))
                                .minimumScaleFactor(0.75)
                            Text(DisplayCurrency.selected.symbol).foregroundStyle(LedgerTheme.subtext).fixedSize()
                            Button(L("저장")) { store.data.monthlyBudget = max(1, budgetText.toMoneyInt) }
                                .fontWeight(.semibold).fixedSize().disabled(budgetText.toMoneyInt < 1)
                        }
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading(title: "화면 테마")
                        Picker(L("테마"), selection: $store.data.appearance) {
                            ForEach(AppearanceMode.allCases) { mode in
                                Text(L(mode == .system ? "시스템 설정" : mode.rawValue)).tag(mode)
                            }
                        }.pickerStyle(.segmented)
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionHeading(title: "메뉴 위치")
                        Label(L("시스템 자동 배치"), systemImage: "rectangle.split.3x1")
                            .font(.body)
                        Text("iPhone Duo에서는 시스템이 화면 자세와 상태 표시줄에 맞춰 메뉴를 배치합니다. 일반 iPhone에서는 하단 탭 막대를 사용합니다. 공간이 부족하면 일부 메뉴는 더 보기로 이동할 수 있습니다.")
                            .font(.system(size: 12)).foregroundStyle(LedgerTheme.subtext)
                    }
                }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 20) {
                Surface {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeading(title: "월간 결산")
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
                Surface {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading(title: "결제 연동")
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
                Surface {
                    VStack(alignment: .leading, spacing: 15) {
                        SectionHeading(title: "보안")
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
                Surface {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeading(title: "데이터")
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
                        Button { confirmSample = true } label: {
                            Label(L("예시 데이터 채우기"), systemImage: "sparkles")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Divider()
                        Button(role: .destructive) { confirmReset = true } label: {
                            Label(L("가계부 기록 삭제 (보관함 제외)"), systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeading(title: "안내")
                        Label(L("기기 내부 저장 · 별도 서버 없음"), systemImage: "iphone")
                        Label(L("은행 · 카드 실시간 연동 없음"), systemImage: "wifi.slash")
                        Label(L("통장 비밀코드는 백업·동기화하지 않음"), systemImage: "lock.shield")
                        Text("이 앱은 개인 기록용 가계부 프로토타입입니다. 실제 결제 또는 은행 로그인 기능을 제공하지 않습니다.")
                            .font(.system(size: 12)).foregroundStyle(LedgerTheme.subtext).padding(.top, 5)
                    }
                    .font(.system(size: 13))
                }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("Digital Wallet · v0.4.19")
                    .font(.caption).foregroundStyle(LedgerTheme.subtext)
                    .frame(maxWidth: .infinity)
            }
            .padding(20).padding(.top, 8)
            .frame(maxWidth: 920).frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showPrivateSettings) { PrivateWalletView(initialSection: 3) }
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
        .confirmationDialog("현재 데이터를 예시 데이터로 바꿀까요?", isPresented: $confirmSample, titleVisibility: .visible) {
            Button("예시 데이터 적용", role: .destructive) { store.clear(); store.loadSample(); budgetText = String(store.data.monthlyBudget) }
        } message: { Text("기존 거래와 카드, 통장 기록이 삭제됩니다.") }
        .confirmationDialog("모든 데이터를 삭제할까요?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("모두 삭제", role: .destructive) { store.clear(); budgetText = String(store.data.monthlyBudget) }
        } message: { Text("기존 가계부 거래, 카드, 통장, 통장 비밀코드가 삭제됩니다. 별도 개인정보 보관함은 유지됩니다. 복구할 수 없습니다.") }
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
    private var newItems: [PaymentImport] { preview.filter { item in !store.data.entries.contains { $0.id == item.id } } }
    var body: some View {
        NavigationStack {
            Form {
                Section("Apple Wallet") {
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
                        ForEach(MoneyCategory.allCases) { Text(L($0.rawValue)).tag($0) }
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
