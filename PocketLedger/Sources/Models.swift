import Foundation
import SwiftUI

enum WalletTab: String, CaseIterable, Identifiable {
    case home = "홈"
    case history = "내역"
    case wallet = "지갑"
    case analytics = "분석"
    case recurring = "자동"
    case settings = "설정"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .history: "chart.bar.xaxis"
        case .wallet: "wallet.bifold.fill"
        case .analytics: "chart.bar.fill"
        case .recurring: "calendar.badge.clock"
        case .settings: "gearshape.fill"
        }
    }
}

enum DockPlacement: String, Codable, CaseIterable, Identifiable {
    case automatic = "자동 감지"
    case bottom = "하단 (일반 iPhone)"
    case right = "오른쪽 (Duo)"
    var id: String { rawValue }
}

enum MoneyKind: String, Codable, CaseIterable, Identifiable {
    case expense = "지출"
    case income = "수입"
    var id: String { rawValue }
}

enum MoneyCategory: String, Codable, CaseIterable, Identifiable {
    case food = "식비"
    case shopping = "쇼핑"
    case transit = "교통"
    case housing = "주거"
    case bills = "공과금"
    case health = "건강"
    case leisure = "여가"
    case salary = "급여"
    case transfer = "이체"
    case other = "기타"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .food: "fork.knife"
        case .shopping: "bag.fill"
        case .transit: "tram.fill"
        case .housing: "house.fill"
        case .bills: "bolt.fill"
        case .health: "cross.case.fill"
        case .leisure: "gamecontroller.fill"
        case .salary: "banknote.fill"
        case .transfer: "arrow.left.arrow.right"
        case .other: "square.grid.2x2.fill"
        }
    }
    var color: Color {
        switch self {
        case .food: .orange
        case .shopping: .pink
        case .transit: .blue
        case .housing: .indigo
        case .bills: .yellow
        case .health: .green
        case .leisure: .purple
        case .salary: .mint
        case .transfer: .cyan
        case .other: .gray
        }
    }
}

enum WalletTone: String, Codable, CaseIterable, Identifiable {
    case midnight = "미드나이트"
    case cobalt = "코발트"
    case violet = "바이올렛"
    case coral = "코랄"
    case emerald = "에메랄드"
    var id: String { rawValue }
    var gradient: [Color] {
        switch self {
        case .midnight: [Color(red: 0.12, green: 0.15, blue: 0.23), Color(red: 0.27, green: 0.31, blue: 0.42)]
        case .cobalt: [Color(red: 0.13, green: 0.32, blue: 0.82), Color(red: 0.12, green: 0.69, blue: 0.88)]
        case .violet: [Color(red: 0.43, green: 0.22, blue: 0.84), Color(red: 0.77, green: 0.40, blue: 0.81)]
        case .coral: [Color(red: 0.90, green: 0.31, blue: 0.41), Color(red: 1.00, green: 0.57, blue: 0.42)]
        case .emerald: [Color(red: 0.05, green: 0.53, blue: 0.49), Color(red: 0.21, green: 0.74, blue: 0.61)]
        }
    }
}

struct PaymentCard: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var issuer: String
    var lastFour: String
    var tone: WalletTone
    var spendingLimit: Int
}

struct BankAccount: Codable, Identifiable, Equatable {
    var id = UUID()
    var nickname: String
    var bankName: String
    var accountNumber: String
    var balance: Int
    var tone: WalletTone
}

struct MoneyEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var amount: Int
    var kind: MoneyKind
    var category: MoneyCategory
    var date: Date
    var sourceId: UUID?
}

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system = "시스템 설정", light = "라이트", dark = "다크"
    var id: String { rawValue }
    var colorScheme: ColorScheme? { self == .system ? nil : (self == .dark ? .dark : .light) }
}

struct RecurringRule: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var amount: Int
    var kind: MoneyKind
    var category: MoneyCategory
    var day: Int
    var sourceId: UUID?
    var startDate: Date
    var enabled: Bool = true
}

struct LedgerData: Codable {
    var cards: [PaymentCard] = []
    var accounts: [BankAccount] = []
    var entries: [MoneyEntry] = []
    var monthlyBudget = 1_500_000
    var dockPlacement: DockPlacement = .automatic
    var appLockEnabled = false
    var isSample = false
    var appearance: AppearanceMode = .system
    var recurringRules: [RecurringRule] = []

    enum CodingKeys: String, CodingKey { case cards, accounts, entries, monthlyBudget, dockPlacement, appLockEnabled, isSample, appearance, recurringRules }
    init(cards: [PaymentCard] = [], accounts: [BankAccount] = [], entries: [MoneyEntry] = [], monthlyBudget: Int = 1_500_000, dockPlacement: DockPlacement = .automatic, appLockEnabled: Bool = false, isSample: Bool = false, appearance: AppearanceMode = .system, recurringRules: [RecurringRule] = []) {
        self.cards = cards; self.accounts = accounts; self.entries = entries; self.monthlyBudget = monthlyBudget
        self.dockPlacement = dockPlacement; self.appLockEnabled = appLockEnabled; self.isSample = isSample
        self.appearance = appearance; self.recurringRules = recurringRules
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cards = try c.decodeIfPresent([PaymentCard].self, forKey: .cards) ?? []
        accounts = try c.decodeIfPresent([BankAccount].self, forKey: .accounts) ?? []
        entries = try c.decodeIfPresent([MoneyEntry].self, forKey: .entries) ?? []
        monthlyBudget = try c.decodeIfPresent(Int.self, forKey: .monthlyBudget) ?? 1_500_000
        dockPlacement = try c.decodeIfPresent(DockPlacement.self, forKey: .dockPlacement) ?? .automatic
        appLockEnabled = try c.decodeIfPresent(Bool.self, forKey: .appLockEnabled) ?? false
        isSample = try c.decodeIfPresent(Bool.self, forKey: .isSample) ?? false
        appearance = try c.decodeIfPresent(AppearanceMode.self, forKey: .appearance) ?? .system
        recurringRules = try c.decodeIfPresent([RecurringRule].self, forKey: .recurringRules) ?? []
    }
}

enum DisplayCurrency: String, CaseIterable, Identifiable {
    case KRW, CNY, JPY, USD, EUR, GBP, HKD, TWD, SGD, CAD, AUD, CHF, THB, INR, VND
    var id: String { rawValue }
    var fractionDigits: Int { [.KRW, .JPY, .VND].contains(self) ? 0 : 2 }
    static var selected: DisplayCurrency {
        DisplayCurrency(rawValue: UserDefaults.standard.string(forKey: "displayCurrency") ?? "KRW") ?? .KRW
    }
    var rate: Double? {
        if self == .KRW { return 1 }
        let value = UserDefaults.standard.double(forKey: "displayRate." + rawValue)
        return value.isFinite && value > 0 ? value : nil
    }
    var formattedName: String {
        Locale.current.localizedString(forCurrencyCode: rawValue).map { rawValue + " · " + $0 } ?? rawValue
    }
    static func format(_ amount: Int) -> String {
        let choice = selected
        let active: DisplayCurrency = choice.rate == nil ? .KRW : choice
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: UserDefaults.standard.string(forKey: "appLanguage").flatMap { $0 == "system" ? nil : $0 } ?? Locale.current.identifier)
        formatter.numberStyle = .currency
        formatter.currencyCode = active.rawValue
        formatter.minimumFractionDigits = active.fractionDigits
        formatter.maximumFractionDigits = active.fractionDigits
        let rate = active.rate ?? 1
        let value = Double(amount) / rate
        let rendered = formatter.string(from: NSNumber(value: value)) ?? String(amount) + " KRW"
        return active == .KRW ? rendered : "≈ " + rendered
    }
}

extension Int {
    var won: String { DisplayCurrency.format(self) }
}

extension Date {
    func monthInterval() -> DateInterval? { Calendar.current.dateInterval(of: .month, for: self) }
    var koreanMonthTitle: String { formatted(.dateTime.year().month(.wide).locale(Locale(identifier: "ko_KR"))) }
}

extension String {
    var lastFourMasked: String {
        let clean = self.filter(\.isNumber)
        return clean.isEmpty ? "미등록" : "•••• " + String(clean.suffix(4))
    }
    var toMoneyInt: Int { Int(filter(\.isNumber)) ?? 0 }
}

private struct DisplayCurrencyRevisionKey: EnvironmentKey {
    static let defaultValue = "KRW0"
}
extension EnvironmentValues {
    var displayCurrencyRevision: String {
        get { self[DisplayCurrencyRevisionKey.self] }
        set { self[DisplayCurrencyRevisionKey.self] = newValue }
    }
}
