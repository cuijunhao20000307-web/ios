import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var monthOffset = 0
    @State private var filter: String = "전체"
    @State private var showAdd = false
    @State private var editing: MoneyEntry?
    @State private var removing: MoneyEntry?

    private var month: Date { Calendar.current.date(byAdding: .month, value: monthOffset, to: .now) ?? .now }
    private var filtered: [MoneyEntry] {
        store.entries(in: month).filter {
            filter == "전체" || (filter == "지출" && $0.kind == .expense) || (filter == "수입" && $0.kind == .income)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("거래 내역").font(.system(size: 30, weight: .bold))
                        Text("지출과 수입을 한눈에").font(.subheadline).foregroundStyle(LedgerTheme.subtext)
                    }
                    Spacer()
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 19, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 46, height: 46).background(LedgerTheme.accent, in: Circle())
                    }
                }
                HStack {
                    Button { monthOffset -= 1 } label: { Image(systemName: "chevron.left") }
                    Spacer()
                    Text(month.koreanMonthTitle).font(.headline)
                    Spacer()
                    Button { monthOffset += 1 } label: { Image(systemName: "chevron.right") }
                }
                .padding(15)
                .background(.white, in: RoundedRectangle(cornerRadius: 17))

                Picker("거래 구분", selection: $filter) {
                    ForEach(["전체", "지출", "수입"], id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.segmented)

                Surface {
                    if filtered.isEmpty {
                        EmptyContent(symbol: "list.bullet.rectangle", title: "해당 거래가 없어요", subtitle: "다른 달 또는 구분을 선택해 보세요")
                    } else {
                        VStack(spacing: 4) {
                            ForEach(filtered) { entry in
                                Button { editing = entry } label: {
                                    EntryLine(entry: entry, source: store.sourceName(for: entry.sourceId))
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("수정", systemImage: "pencil") { editing = entry }
                                    Button("삭제", systemImage: "trash", role: .destructive) { removing = entry }
                                }
                                if entry.id != filtered.last?.id { Divider().opacity(0.48) }
                            }
                        }
                    }
                }
                Text("내역을 누르면 수정할 수 있고, 길게 누르면 삭제할 수 있어요.")
                    .font(.system(size: 12)).foregroundStyle(LedgerTheme.subtext)
            }
            .padding(20).padding(.top, 8)
            .frame(maxWidth: 780).frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showAdd) { TransactionForm() }
        .sheet(item: $editing) { TransactionForm(existing: $0) }
        .confirmationDialog("이 거래를 삭제할까요?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
            Button("거래 삭제", role: .destructive) {
                if let removing { store.data.entries.removeAll { $0.id == removing.id } }
                removing = nil
            }
        }
    }
}

struct TransactionForm: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss
    var existing: MoneyEntry? = nil
    @State private var title = ""
    @State private var amount = ""
    @State private var kind: MoneyKind = .expense
    @State private var category: MoneyCategory = .food
    @State private var date = Date()
    @State private var sourceChoice = "none"

    private var valid: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount.toMoneyInt > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("거래 내용") {
                    Picker("종류", selection: $kind) {
                        ForEach(MoneyKind.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)
                    TextField("예: 점심 식사", text: $title)
                    HStack {
                        Text("금액")
                        Spacer()
                        TextField("0", text: $amount).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                        Text("원").foregroundStyle(.secondary)
                    }
                    Picker("카테고리", selection: $category) {
                        ForEach(MoneyCategory.allCases) { Text($0.rawValue).tag($0) }
                    }
                    DatePicker("날짜", selection: $date, displayedComponents: .date)
                }
                Section("결제 수단 · 선택") {
                    Picker("지갑", selection: $sourceChoice) {
                        Text("선택 안 함").tag("none")
                        ForEach(store.data.cards) { card in Text("카드 · " + card.name).tag(card.id.uuidString) }
                        ForEach(store.data.accounts) { account in Text("통장 · " + account.nickname).tag(account.id.uuidString) }
                    }
                    Text("거래를 기록해도 통장 잔액은 자동으로 변경되지 않습니다.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(existing == nil ? "거래 추가" : "거래 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }.fontWeight(.semibold).disabled(!valid)
                }
            }
            .onAppear {
                if let existing {
                    title = existing.title
                    amount = String(existing.amount)
                    kind = existing.kind
                    category = existing.category
                    date = existing.date
                    sourceChoice = existing.sourceId?.uuidString ?? "none"
                }
            }
        }
    }

    private func save() {
        let id = existing?.id ?? UUID()
        let entry = MoneyEntry(id: id, title: title.trimmingCharacters(in: .whitespacesAndNewlines), amount: amount.toMoneyInt,
                               kind: kind, category: category, date: date,
                               sourceId: UUID(uuidString: sourceChoice))
        if let index = store.data.entries.firstIndex(where: { $0.id == id }) {
            store.data.entries[index] = entry
        } else {
            store.data.entries.append(entry)
        }
        dismiss()
    }
}
