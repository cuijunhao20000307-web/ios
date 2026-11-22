import SwiftUI
import Charts

struct AnalyticsView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var monthOffset = 0
    private var month: Date { Calendar.current.date(byAdding: .month, value: monthOffset, to: .now) ?? .now }
    private var sixMonths: [(Date, Int)] {
        (0..<6).reversed().compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .month, value: -offset, to: month) else { return nil }
            return (date, store.amount(of: .expense, in: date))
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("지출 분석").font(.system(size: 30, weight: .bold))
                HStack {
                    Button { monthOffset -= 1 } label: { Image(systemName: "chevron.left") }
                    Spacer()
                    Text(month.koreanMonthTitle).font(.headline)
                    Spacer()
                    Button { monthOffset += 1 } label: { Image(systemName: "chevron.right") }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeading(title: "최근 6개월 지출")
                        Chart(sixMonths, id: \.0) { item in
                            BarMark(x: .value("월", item.0, unit: .month), y: .value("지출", item.1))
                                .foregroundStyle(LedgerTheme.accent.gradient)
                                .cornerRadius(6)
                        }.frame(height: 230)
                        Text("선택 월까지의 6개월 · 원 단위").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeading(title: "카드별 지출")
                        if store.data.cards.isEmpty { Text("카드를 먼저 등록해 주세요.").foregroundStyle(.secondary) }
                        ForEach(store.data.cards) { card in
                            let spent = store.spent(on: card, in: month)
                            VStack(alignment: .leading, spacing: 7) {
                                HStack {
                                    Text(card.name).font(.subheadline).fontWeight(.semibold)
                                    Spacer()
                                    Text(spent.won).font(.subheadline)
                                }
                                ProgressView(value: Double(spent), total: Double(max(card.spendingLimit, spent, 1)))
                                    .tint(card.tone.gradient.first ?? LedgerTheme.accent)
                                Text(card.spendingLimit > 0 ? "월 한도 \(card.spendingLimit.won)" : "월 한도 미설정")
                                    .font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 5)
                        }
                    }
                }
            }.padding(20).frame(maxWidth: 780).frame(maxWidth: .infinity)
        }
    }
}
