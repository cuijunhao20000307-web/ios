import Foundation
import Combine

@MainActor
final class LedgerStore: ObservableObject {
    @Published var data: LedgerData { didSet { save() } }
    private let url: URL
    private var processingRecurring = false

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        url = documents.appendingPathComponent("ledger-data.json")
        if let raw = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(LedgerData.self, from: raw) {
            data = decoded
        } else {
            data = LedgerData()
        }
        processRecurring()
    }

    private func save() {
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        } catch {
            print("Local save failed: \(error.localizedDescription)")
        }
    }

    // Generate only due occurrences, with stable deterministic IDs for idempotency.
    func processRecurring(asOf today: Date = .now) {
        guard !processingRecurring else { return }
        processingRecurring = true
        defer { processingRecurring = false }
        let calendar = Calendar.current
        let currentMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today
        var newEntries: [MoneyEntry] = []
        for rule in data.recurringRules where rule.enabled && rule.amount > 0 {
            guard let firstMonth = calendar.dateInterval(of: .month, for: rule.startDate)?.start else { continue }
            var cursor = firstMonth
            var count = 0
            while cursor <= currentMonth && count < 240 {
                let days = calendar.range(of: .day, in: .month, for: cursor)?.count ?? 28
                let date = calendar.date(byAdding: .day, value: min(max(rule.day, 1), days) - 1, to: cursor) ?? cursor
                if date <= today && date >= calendar.startOfDay(for: rule.startDate) {
                    let key = "\(rule.id.uuidString)|\(calendar.component(.year, from: cursor))|\(calendar.component(.month, from: cursor))"
                    let id = UUID.deterministic(key)
                    if !data.entries.contains(where: { $0.id == id }) && !newEntries.contains(where: { $0.id == id }) {
                        newEntries.append(MoneyEntry(id: id, title: rule.title, amount: rule.amount, kind: rule.kind, category: rule.category, date: date, sourceId: rule.sourceId))
                    }
                }
                guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
                cursor = next; count += 1
            }
        }
        if !newEntries.isEmpty { data.entries.append(contentsOf: newEntries) }
    }

    // Recorded account balances are opening amounts, not a live bank feed.
    // Derive from transaction history each time instead of mutating stored balances.
    var ledgerBalance: Int {
        let opening = data.accounts.reduce(0) { $0 + $1.balance }
        let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now
        return data.entries.filter { $0.date < endOfToday }.reduce(opening) {
            $0 + ($1.kind == .income ? $1.amount : -$1.amount)
        }
    }

    func entries(in month: Date) -> [MoneyEntry] {
        guard let range = month.monthInterval() else { return [] }
        return data.entries.filter { range.contains($0.date) }.sorted { $0.date > $1.date }
    }

    func amount(of kind: MoneyKind, in month: Date) -> Int {
        entries(in: month).filter { $0.kind == kind }.reduce(0) { $0 + $1.amount }
    }

    func spent(on card: PaymentCard, in month: Date) -> Int {
        entries(in: month).filter { $0.sourceId == card.id && $0.kind == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    func sourceName(for id: UUID?) -> String? {
        guard let id else { return nil }
        return data.cards.first(where: { $0.id == id })?.name
            ?? data.accounts.first(where: { $0.id == id })?.nickname
    }

    func deleteAccount(_ account: BankAccount) {
        SecureVault.remove(for: account.id)
        try? BankSecurityStorage.remove(account.id); try? BankWebsiteStorage.remove(account.id)
        data.accounts.removeAll { $0.id == account.id }
    }

    func loadSample() {
        for account in data.accounts { try? BankSecurityStorage.remove(account.id); try? BankWebsiteStorage.remove(account.id) }
        let card1 = PaymentCard(name: "데일리 카드", issuer: "현대카드", lastFour: "1256", tone: .midnight, spendingLimit: 800_000)
        let card2 = PaymentCard(name: "생활 카드", issuer: "신한카드", lastFour: "7834", tone: .cobalt, spendingLimit: 500_000)
        let account = BankAccount(nickname: "월급 통장", bankName: "국민은행", accountNumber: "123456789012", balance: 2_680_000, tone: .emerald)
        let now = Date()
        data = LedgerData(cards: [card1, card2], accounts: [account], entries: [
            MoneyEntry(title: "11월 월급", amount: 3_100_000, kind: .income, category: .salary, date: now, sourceId: account.id),
            MoneyEntry(title: "점심 식사", amount: 12_000, kind: .expense, category: .food, date: now, sourceId: card1.id),
            MoneyEntry(title: "편의점", amount: 6_800, kind: .expense, category: .food, date: now.addingTimeInterval(-86400), sourceId: card1.id),
            MoneyEntry(title: "교통카드", amount: 45_000, kind: .expense, category: .transit, date: now.addingTimeInterval(-172800), sourceId: card2.id),
            MoneyEntry(title: "온라인 쇼핑", amount: 73_000, kind: .expense, category: .shopping, date: now.addingTimeInterval(-259200), sourceId: card1.id)
        ], monthlyBudget: 1_500_000, dockPlacement: data.dockPlacement, appLockEnabled: data.appLockEnabled, isSample: true)
    }

    // CSV에는 거래 기록만 포함하며 계좌번호와 보안 코드는 제외합니다.
    func exportTransactionsCSV() throws -> URL {
        func field(_ value: String) -> String {
            "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        var rows = ["날짜,구분,분류,내용,금액(원),결제수단"]
        for entry in data.entries.sorted(by: { $0.date < $1.date }) {
            rows.append([
                formatter.string(from: entry.date), entry.kind.rawValue,
                entry.category.rawValue, entry.title, String(entry.amount),
                sourceName(for: entry.sourceId) ?? ""
            ].map(field).joined(separator: ","))
        }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("PocketLedger_거래내역.csv")
        try Data(("\u{FEFF}" + rows.joined(separator: "\r\n") + "\r\n").utf8)
            .write(to: file, options: .atomic)
        return file
    }

    func clear() {
        for account in data.accounts { SecureVault.remove(for: account.id); try? BankSecurityStorage.remove(account.id); try? BankWebsiteStorage.remove(account.id) }
        let dock = data.dockPlacement
        data = LedgerData()
        data.dockPlacement = dock
    }
}
