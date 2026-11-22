import SwiftUI

struct DashboardView: View {
    @Environment(\.appLanguageRevision) private var languageRefresh
    @Environment(\.displayCurrencyRevision) private var moneyRefresh
    @EnvironmentObject private var store: LedgerStore
    @State private var monthOffset = 0
    @State private var showAdd = false

    private var month: Date { Calendar.current.date(byAdding: .month, value: monthOffset, to: .now) ?? .now }
    private var expenses: Int { store.amount(of: .expense, in: month) }
    private var incomes: Int { store.amount(of: .income, in: month) }
    private var entries: [MoneyEntry] { store.entries(in: month) }
    private var ratio: Double { max(0, Double(expenses) / Double(max(store.data.monthlyBudget, 1))) }
    private var categoryTotals: [(MoneyCategory, Int)] {
        MoneyCategory.allCases.compactMap { category -> (MoneyCategory, Int)? in
            let amount = entries.filter { $0.kind == .expense && $0.category == category }.reduce(0) { $0 + $1.amount }
            return amount > 0 ? (category, amount) : nil
        }.sorted { $0.1 > $1.1 }
    }

    var body: some View {
        let _ = languageRefresh
        let _ = moneyRefresh
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L("나의 가계부")).font(.largeTitle.bold())
                        .padding(.bottom, 2)
                        .accessibilityAddTraits(.isHeader)
                    if store.data.isSample {
                        Label(L("샘플 데이터 · 설정에서 초기화 가능"), systemImage: "info.circle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    balanceCard
                    monthSelector
                    HStack(spacing: 12) {
                        totalTile("이번 달 지출", value: expenses, symbol: "arrow.up.right", tint: .pink)
                        totalTile("이번 달 수입", value: incomes, symbol: "arrow.down.left", tint: .green)
                    }
                    DuoColumns(spacing: 16, minWidth: 590) {
                        budgetCard
                        categoriesCard
                    }
                    recentCard
                }
                .padding(.horizontal, 20).padding(.vertical, 16)
                .frame(maxWidth: 920)
                .frame(maxWidth: .infinity)
            }
            .background(LedgerTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus").fontWeight(.semibold) }
                        .accessibilityLabel(L("거래 추가"))
                }
            }
        }
        .sheet(isPresented: $showAdd) { TransactionForm() }
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(L("현재 가계부 잔액"), systemImage: "wallet.pass")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Image(systemName: "lock.shield").font(.subheadline)
            }.foregroundStyle(.white.opacity(0.78))
            Text(store.ledgerBalance.won)
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                .foregroundStyle(.white)
            Text(L("기초 잔액 + 수입 − 지출 · 오늘까지"))
                .font(.caption).foregroundStyle(.white.opacity(0.76))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.10, green: 0.14, blue: 0.24), Color(red: 0.22, green: 0.28, blue: 0.44)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    private var monthSelector: some View {
        HStack {
            Button { monthOffset -= 1 } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }
            Spacer(minLength: 8)
            Text(month.koreanMonthTitle).font(.headline).lineLimit(1)
            Spacer(minLength: 8)
            Button { monthOffset += 1 } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private func totalTile(_ title: String, value: Int, symbol: String, tint: Color) -> some View {
        Surface {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: symbol).font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                        .frame(width: 30, height: 30)
                        .background(tint.opacity(0.12), in: Circle())
                    Text(L(title)).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(value.won).font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.45)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var budgetCard: some View {
        Surface {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(title: "월 지출 예산")
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(expenses.won).font(.title3.weight(.semibold)).monospacedDigit()
                    Text("/ " + store.data.monthlyBudget.won).font(.caption).foregroundStyle(.secondary)
                }
                .lineLimit(1).minimumScaleFactor(0.55)
                ProgressView(value: min(1, ratio))
                    .tint(ratio > 1 ? .pink : LedgerTheme.accent)
                HStack(alignment: .firstTextBaseline) {
                    Text(ratio > 1 ? L("예산을 초과했어요") : L("남은 예산") + " " + max(store.data.monthlyBudget - expenses, 0).won)
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 6)
                    Text(ratio, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.weight(.semibold)).monospacedDigit()
                }
            }
            .frame(minHeight: 132, alignment: .topLeading)
        }
    }

    private var categoriesCard: some View {
        Surface {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(title: "카테고리별 지출")
                if categoryTotals.isEmpty {
                    Label(L("아직 지출이 없어요"), systemImage: "chart.pie")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .padding(.vertical, 10)
                } else {
                    GeometryReader { proxy in
                        HStack(spacing: 0) {
                            ForEach(categoryTotals, id: \.0) { item in
                                Rectangle().fill(item.0.color)
                                    .frame(width: proxy.size.width * CGFloat(item.1) / CGFloat(max(expenses, 1)))
                            }
                        }.clipShape(Capsule())
                    }.frame(height: 7)
                    ForEach(categoryTotals, id: \.0) { category, amount in
                        HStack(spacing: 8) {
                            Circle().fill(category.color).frame(width: 9, height: 9)
                            Text(L(category.rawValue)).font(.subheadline)
                            Spacer(minLength: 6)
                            Text(amount.won).font(.subheadline.weight(.medium)).monospacedDigit()
                        }
                    }
                }
            }
            .frame(minHeight: 132, alignment: .topLeading)
        }
    }

    private var recentCard: some View {
        Surface {
            VStack(alignment: .leading, spacing: 9) {
                SectionHeading(title: "최근 거래", detail: "최대 5건")
                if entries.isEmpty {
                    Label(L("거래가 없어요"), systemImage: "receipt")
                        .font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 10)
                } else {
                    ForEach(Array(entries.prefix(5))) { entry in
                        EntryLine(entry: entry, source: store.sourceName(for: entry.sourceId))
                        if entry.id != entries.prefix(5).last?.id { Divider().opacity(0.6) }
                    }
                }
            }
        }
    }
}
