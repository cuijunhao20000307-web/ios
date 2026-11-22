import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var monthOffset = 0
    @State private var showAdd = false

    private var month: Date { Calendar.current.date(byAdding: .month, value: monthOffset, to: .now) ?? .now }
    private var expenses: Int { store.amount(of: .expense, in: month) }
    private var incomes: Int { store.amount(of: .income, in: month) }
    private var entries: [MoneyEntry] { store.entries(in: month) }
    private var balance: Int { store.data.accounts.reduce(0) { $0 + $1.balance } }

    private var categoryTotals: [(MoneyCategory, Int)] {
        MoneyCategory.allCases.compactMap { category -> (MoneyCategory, Int)? in
            let amount = entries.filter { $0.kind == .expense && $0.category == category }.reduce(0) { $0 + $1.amount }
            return amount > 0 ? (category, amount) : nil
        }.sorted { $0.1 > $1.1 }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("나의 가계부")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("오늘도 현명하게 관리해요")
                            .font(.system(size: 14)).foregroundStyle(LedgerTheme.subtext)
                    }
                    Spacer()
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 19, weight: .bold))
                            .frame(width: 46, height: 46)
                            .foregroundStyle(.white)
                            .background(LedgerTheme.accent, in: Circle())
                    }
                    .accessibilityLabel("거래 추가")
                }
                if store.data.isSample {
                    Label("샘플 데이터 · 설정에서 초기화 가능", systemImage: "info.circle")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("등록된 통장 잔액 합계").font(.system(size: 13, weight: .medium)).opacity(0.8)
                            Spacer()
                            Image(systemName: "wallet.pass.fill").font(.system(size: 20))
                        }
                        Text(balance.won)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.65).lineLimit(1)
                        Text(store.data.accounts.isEmpty ? "지갑에서 통장을 등록해 보세요" : "등록된 통장 \(store.data.accounts.count)개 기준 · 수동 관리 잔액")
                            .font(.system(size: 12)).opacity(0.75)
                    }
                    .foregroundStyle(.white)
                    .padding(25)
                    .frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [Color(red: 0.13, green: 0.16, blue: 0.28), Color(red: 0.24, green: 0.29, blue: 0.51)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))

                HStack {
                    Button { monthOffset -= 1 } label: { Image(systemName: "chevron.left").frame(width: 36, height: 36) }
                    Spacer()
                    Text(month.koreanMonthTitle).font(.system(size: 20, weight: .bold))
                    Spacer()
                    Button { monthOffset += 1 } label: { Image(systemName: "chevron.right").frame(width: 36, height: 36) }
                }
                .foregroundStyle(LedgerTheme.text)

                HStack(spacing: 12) {
                    totalTile("이번 달 지출", value: expenses, symbol: "arrow.up.right", tint: .pink)
                    totalTile("이번 달 수입", value: incomes, symbol: "arrow.down.left", tint: .green)
                }

                Surface {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeading(title: "월 지출 예산")
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(expenses.won).font(.system(size: 22, weight: .bold, design: .rounded))
                            Text("/ " + store.data.monthlyBudget.won)
                                .font(.system(size: 12)).foregroundStyle(LedgerTheme.subtext)
                                .minimumScaleFactor(0.75).lineLimit(1)
                        }
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(LedgerTheme.background)
                                Capsule().fill(expenses > store.data.monthlyBudget ? Color.pink : LedgerTheme.accent)
                                    .frame(width: geometry.size.width * min(CGFloat(expenses) / CGFloat(max(store.data.monthlyBudget, 1)), 1))
                            }
                        }
                        .frame(height: 11)
                        HStack {
                            Text(expenses > store.data.monthlyBudget ? "예산을 초과했어요" : "예산까지 " + max(store.data.monthlyBudget - expenses, 0).won + " 남았어요")
                                .font(.system(size: 12)).foregroundStyle(LedgerTheme.subtext)
                            Spacer()
                            Text("\(Int(100 * Double(expenses) / Double(max(store.data.monthlyBudget, 1))))%")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 11) {
                    SectionHeading(title: "카테고리별 지출")
                    Surface {
                        if categoryTotals.isEmpty {
                            EmptyContent(symbol: "chart.pie.fill", title: "아직 지출이 없어요", subtitle: "+ 버튼에서 첫 거래를 등록해 보세요")
                        } else {
                            VStack(spacing: 12) {
                                ForEach(categoryTotals, id: \.0) { category, amount in
                                    HStack(spacing: 12) {
                                        Image(systemName: category.icon).foregroundStyle(category.color)
                                            .frame(width: 30)
                                        Text(category.rawValue).font(.system(size: 14, weight: .medium))
                                        Spacer()
                                        Text(amount.won).font(.system(size: 14, weight: .semibold))
                                    }
                                    if category != categoryTotals.last?.0 { Divider().opacity(0.5) }
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 11) {
                    SectionHeading(title: "최근 거래", detail: "최대 5건")
                    Surface {
                        if entries.isEmpty {
                            EmptyContent(symbol: "receipt", title: "거래가 없어요", subtitle: "수입과 지출을 간편하게 기록하세요")
                        } else {
                            VStack(spacing: 3) {
                                ForEach(Array(entries.prefix(5))) { entry in
                                    EntryLine(entry: entry, source: store.sourceName(for: entry.sourceId))
                                    if entry.id != entries.prefix(5).last?.id { Divider().opacity(0.45) }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 25)
            .frame(maxWidth: 780)
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showAdd) { TransactionForm() }
    }

    private func totalTile(_ title: String, value: Int, symbol: String, tint: Color) -> some View {
        Surface {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tint)
                    .padding(9)
                    .background(tint.opacity(0.11), in: Circle())
                Text(title).font(.system(size: 12)).foregroundStyle(LedgerTheme.subtext)
                Text(value.won).font(.system(size: 19, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.65).lineLimit(1)
            }
        }
    }
}
