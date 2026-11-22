import SwiftUI
import CryptoKit

extension UUID {
    static func deterministic(_ value: String) -> UUID {
        let bytes = Array(Insecure.SHA1.hash(data: Data(value.utf8)).prefix(16))
        var b = bytes; b[6] = (b[6] & 0x0f) | 0x50; b[8] = (b[8] & 0x3f) | 0x80
        let str = b.map { String(format: "%02x", $0) }.joined()
        return UUID(uuidString: "\(str.prefix(8))-\(str.dropFirst(8).prefix(4))-\(str.dropFirst(12).prefix(4))-\(str.dropFirst(16).prefix(4))-\(str.dropFirst(20))")!
    }
}

struct RecurringView: View {
    @Environment(\.appLanguageRevision) private var languageRefresh
    @Environment(\.displayCurrencyRevision) private var moneyRefresh
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.displayCurrencyRevision) private var currencyRevision
    @State private var showSubscriptions = false
    @State private var showForm = false
    var body: some View {
        let _ = languageRefresh
        let _ = moneyRefresh
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(L("자동 기록")).font(.system(size: 30, weight: .bold))
                    Spacer()
                    Button { showForm = true } label: { Label(L("추가"), systemImage: "plus.circle.fill") }
                }
                Surface {
                    Button { showSubscriptions = true } label: {
                        HStack {
                            Label(L("나의 구독 관리"), systemImage: "calendar.badge.clock")
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption)
                        }
                    }
                }
                Text("월급, 월세, 구독료를 매월 지정일에 기록합니다. 앱을 열 때 기한이 지난 내역을 반영합니다.")
                    .font(.subheadline).foregroundStyle(.secondary)
                if store.data.recurringRules.isEmpty { Surface { EmptyContent(symbol: "calendar.badge.clock", title: "등록된 자동 기록이 없어요", subtitle: "월급이나 고정 지출을 추가해 보세요") } }
                ForEach(store.data.recurringRules) { rule in
                    Surface {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(rule.title).font(.headline)
                                Text("매월 \(rule.day)일 · \(rule.kind.rawValue) · \(rule.amount.won)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("활성", isOn: Binding(get: { store.data.recurringRules.first(where: {$0.id == rule.id})?.enabled ?? false }, set: { v in
                                if let i = store.data.recurringRules.firstIndex(where: {$0.id == rule.id}) { store.data.recurringRules[i].enabled = v; store.processRecurring() }
                            })).labelsHidden()
                        }
                        Button(L("삭제"), role: .destructive) { store.data.recurringRules.removeAll { $0.id == rule.id } }
                            .font(.caption)
                    }
                }
            }.padding(20).frame(maxWidth: 780).frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showSubscriptions) { PrivateWalletView(initialSection: 1) }
        .sheet(isPresented: $showForm) { RecurringForm() }
    }
}

struct RecurringForm: View {
    @Environment(\.appLanguageRevision) private var languageRefresh
    @Environment(\.displayCurrencyRevision) private var moneyRefresh
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.displayCurrencyRevision) private var currencyRevision
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var amount = ""
    @State private var kind: MoneyKind = .expense
    @State private var category: MoneyCategory = .bills
    @State private var day = 1
    @State private var startDate = Date()
    @State private var sourceId: UUID?
    var body: some View {
        let _ = languageRefresh
        let _ = moneyRefresh
        NavigationStack {
            Form {
                TextField(L("항목 이름"), text: $title)
                TextField(L("금액 (원)"), text: $amount).keyboardType(.numberPad)
                Picker(L("구분"), selection: $kind) { ForEach(MoneyKind.allCases) { Text(L($0.rawValue)).tag($0) } }
                    .onChange(of: kind) { _, v in category = v == .income ? .salary : .bills }
                Picker(L("분류"), selection: $category) { ForEach(MoneyCategory.allCases) { Text(L($0.rawValue)).tag($0) } }
                Stepper("매월 \(day)일", value: $day, in: 1...31)
                DatePicker(L("시작일"), selection: $startDate, displayedComponents: .date)
                Picker(L("결제 수단"), selection: $sourceId) {
                    Text(L("미지정")).tag(Optional<UUID>.none)
                    ForEach(store.data.cards) { card in Text(card.name).tag(Optional(card.id)) }
                    ForEach(store.data.accounts) { account in Text(account.nickname).tag(Optional(account.id)) }
                }
                Text("29~31일이 없는 달에는 해당 월의 마지막 날에 기록합니다. 과거 날짜부터 시작하면 이전 달 내역도 생성됩니다.").font(.caption).foregroundStyle(.secondary)
            }
            .navigationTitle(L("자동 기록 추가"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("취소")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(L("저장")) {
                    store.data.recurringRules.append(RecurringRule(title: title.trimmingCharacters(in: .whitespacesAndNewlines), amount: amount.toMoneyInt, kind: kind, category: category, day: day, sourceId: sourceId, startDate: startDate))
                    store.processRecurring(); dismiss()
                }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || amount.toMoneyInt == 0) }
            }
        }
    }
}
