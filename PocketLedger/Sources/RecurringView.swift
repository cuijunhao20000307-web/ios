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
    @State private var showFixedExpenses = false
    @State private var editingRule: RecurringRule?
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
                Surface {
                    Button { showFixedExpenses = true } label: {
                        HStack {
                            Label(L("매월 고정 지출 설정"), systemImage: "calendar.badge.clock")
                            Spacer()
                            Text(store.data.recurringRules
                                .filter { $0.enabled && $0.kind == .expense }
                                .reduce(0) { $0 + $1.amount }.won)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
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
                        HStack {
                            Button(L("수정")) { editingRule = rule }
                                .font(.caption)
                            Spacer()
                            Button(L("삭제"), role: .destructive) {
                                store.data.recurringRules.removeAll { $0.id == rule.id }
                            }.font(.caption)
                        }
                    }
                }
            }.padding(20).frame(maxWidth: 780).frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showSubscriptions) { PrivateWalletView(initialSection: 1) }
        .sheet(isPresented: $showFixedExpenses) { FixedExpensesSettingsView() }
        .sheet(isPresented: $showForm) { RecurringForm() }
        .sheet(item: $editingRule) { RecurringForm(existing: $0) }
    }
}

// Single ledger-backed monthly schedule is shared by the Auto tab and Settings.
// No extra preference store is needed; this remains compatible with backups.
struct FixedExpensesSettingsView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss
    @State private var showAdd = false
    @State private var editingRule: RecurringRule?
    @State private var deletingRule: RecurringRule?

    private var expenses: [RecurringRule] {
        store.data.recurringRules.filter { $0.kind == .expense }
            .sorted { $0.day == $1.day ? $0.title < $1.title : $0.day < $1.day }
    }
    private var monthlyTotal: Int {
        expenses.filter { $0.enabled }.reduce(0) { $0 + $1.amount }
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Label(L("월 고정 지출 합계"), systemImage: "calendar.badge.clock")
                        Spacer()
                        Text(monthlyTotal.won)
                            .font(.headline.monospacedDigit())
                    }
                    Text(L("설정된 고정 지출은 앱을 열 때 지정일에 자동 기록됩니다."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section(L("매월 고정 지출 설정")) {
                    if expenses.isEmpty {
                        Label(L("고정 지출 없음"), systemImage: "calendar.badge.exclamationmark")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(expenses) { rule in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Button {
                                    editingRule = rule
                                } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(rule.title).font(.headline)
                                        Text(L(rule.category.rawValue) + " · " + rule.amount.won)
                                            .font(.subheadline).foregroundStyle(.secondary)
                                        Text(L("매월 결제일") + ": " + String(rule.day))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Toggle(L("활성"), isOn: Binding(
                                    get: { store.data.recurringRules.first(where: { $0.id == rule.id })?.enabled ?? false },
                                    set: { enabled in
                                        if let index = store.data.recurringRules.firstIndex(where: { $0.id == rule.id }) {
                                            store.data.recurringRules[index].enabled = enabled
                                            if enabled { store.processRecurring() }
                                        }
                                    }
                                ))
                                .labelsHidden()
                            }
                            HStack {
                                Button(L("수정")) { editingRule = rule }
                                Spacer()
                                Button(L("삭제"), role: .destructive) { deletingRule = rule }
                            }
                            .font(.caption)
                        }
                        .padding(.vertical, 5)
                    }
                    Button {
                        showAdd = true
                    } label: {
                        Label(L("고정 지출 추가"), systemImage: "plus.circle.fill")
                    }
                }
                Section {
                    Text(L("선택한 날이 없는 달에는 말일에 기록됩니다."))
                    Text(L("규칙 수정은 기존에 기록된 거래를 변경하지 않습니다."))
                    Text(L("신용카드 사용액을 이미 지출로 기록했다면 카드 대금을 다시 지출로 넣을 때 이중 계산될 수 있습니다."))
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            .navigationTitle(L("매월 고정 지출 설정"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("닫기")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel(L("고정 지출 추가"))
                }
            }
            .sheet(isPresented: $showAdd) { RecurringForm(fixedExpenseOnly: true) }
            .sheet(item: $editingRule) { RecurringForm(existing: $0, fixedExpenseOnly: true) }
            .confirmationDialog(L("삭제"), isPresented: Binding(
                get: { deletingRule != nil },
                set: { if !$0 { deletingRule = nil } }
            ), titleVisibility: .visible) {
                Button(L("삭제"), role: .destructive) {
                    if let deletingRule {
                        store.data.recurringRules.removeAll { $0.id == deletingRule.id }
                    }
                    deletingRule = nil
                }
            }
        }
    }
}

struct RecurringForm: View {
    var existing: RecurringRule? = nil
    var fixedExpenseOnly = false
    @Environment(\.appLanguageRevision) private var languageRefresh
    @Environment(\.displayCurrencyRevision) private var moneyRefresh
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.displayCurrencyRevision) private var currencyRevision
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var amount = ""
    @State private var kind: MoneyKind = .expense
    @State private var category: MoneyCategory = .other
    @State private var day = 1
    @State private var startDate = Date()
    @State private var sourceId: UUID?
    private var valid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount.toMoneyInt > 0
    }
    var body: some View {
        let _ = languageRefresh
        let _ = moneyRefresh
        NavigationStack {
            Form {
                Section {
                    TextField(L("항목 이름"), text: $title)
                    TextField(L("금액 (원)"), text: $amount)
                        .keyboardType(.numberPad)
                    if !fixedExpenseOnly {
                        Picker(L("구분"), selection: $kind) {
                            ForEach(MoneyKind.allCases) { Text(L($0.rawValue)).tag($0) }
                        }
                        .onChange(of: kind) { _, v in category = v == .income ? .salary : .other }
                    }
                    Picker(L("분류"), selection: $category) {
                        if category == .bills { Text(L(MoneyCategory.bills.rawValue)).tag(MoneyCategory.bills) }
                        ForEach(MoneyCategory.selectableCases) { Text(L($0.rawValue)).tag($0) }
                    }
                    Stepper(L("매월 결제일") + ": " + String(day), value: $day, in: 1...31)
                    DatePicker(L("시작일"), selection: $startDate, displayedComponents: .date)
                    Picker(L("결제 수단"), selection: $sourceId) {
                        Text(L("미지정")).tag(Optional<UUID>.none)
                        ForEach(store.data.cards) { card in
                            Text(card.name).tag(Optional(card.id))
                        }
                        ForEach(store.data.accounts) { account in
                            Text(account.nickname).tag(Optional(account.id))
                        }
                    }
                    if fixedExpenseOnly && category == .creditCardRepayment {
                        Text(L("신용카드 사용액을 이미 지출로 기록했다면 카드 대금을 다시 지출로 넣을 때 이중 계산될 수 있습니다."))
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                Section {
                    Text(L("매월 자동 기록"))
                        .font(.subheadline.weight(.semibold))
                    Text(L("설정된 고정 지출은 앱을 열 때 지정일에 자동 기록됩니다."))
                    Text(L("선택한 날이 없는 달에는 말일에 기록됩니다."))
                    if existing != nil {
                        Text(L("규칙 수정은 기존에 기록된 거래를 변경하지 않습니다."))
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            .navigationTitle(L(fixedExpenseOnly
                ? (existing == nil ? "고정 지출 추가" : "고정 지출 편집")
                : (existing == nil ? "자동 기록 추가" : "수정")))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("취소")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("저장")) { save() }.disabled(!valid)
                }
            }
            .onAppear {
                if let existing {
                    title = existing.title
                    amount = String(existing.amount)
                    kind = fixedExpenseOnly ? .expense : existing.kind
                    category = existing.category
                    day = existing.day
                    startDate = existing.startDate
                    sourceId = existing.sourceId
                } else if fixedExpenseOnly {
                    kind = .expense
                }
            }
        }
    }
    private func save() {
        guard valid else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = RecurringRule(
            id: existing?.id ?? UUID(), title: trimmed, amount: amount.toMoneyInt,
            kind: fixedExpenseOnly ? .expense : kind, category: category, day: day,
            sourceId: sourceId, startDate: startDate,
            enabled: existing?.enabled ?? true
        )
        if let index = store.data.recurringRules.firstIndex(where: { $0.id == item.id }) {
            store.data.recurringRules[index] = item
        } else {
            store.data.recurringRules.append(item)
        }
        store.processRecurring()
        dismiss()
    }
}
