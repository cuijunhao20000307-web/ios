import SwiftUI

enum LedgerTheme {
    static let background = Color(uiColor: .systemGroupedBackground)
    static let text = Color.primary
    static let subtext = Color.secondary
    static let accent = Color(red: 0.24, green: 0.34, blue: 0.93)
    static let panel = Color(uiColor: .secondarySystemGroupedBackground)
}

struct Surface<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LedgerTheme.panel, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct SectionHeading: View {
    @Environment(\.appLanguageRevision) private var languageRefresh
    @Environment(\.displayCurrencyRevision) private var moneyRefresh
    let title: String
    var detail: String? = nil
    var body: some View {
        let _ = languageRefresh
        let _ = moneyRefresh
        HStack(alignment: .firstTextBaseline) {
            Text(L(title)).font(.system(size: 20, weight: .bold))
            Spacer()
            if let detail { Text(L(detail)).font(.system(size: 12, weight: .medium)).foregroundStyle(LedgerTheme.subtext) }
        }
    }
}

struct EmptyContent: View {
    @Environment(\.appLanguageRevision) private var languageRefresh
    @Environment(\.displayCurrencyRevision) private var moneyRefresh
    var symbol: String
    var title: String
    var subtitle: String
    var body: some View {
        let _ = languageRefresh
        let _ = moneyRefresh
        VStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(LedgerTheme.accent)
                .padding(18)
                .background(LedgerTheme.accent.opacity(0.08), in: Circle())
            Text(L(title)).font(.headline).foregroundStyle(LedgerTheme.text)
            Text(L(subtitle)).font(.subheadline).foregroundStyle(LedgerTheme.subtext)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}

struct EntryLine: View {
    @Environment(\.appLanguageRevision) private var languageRefresh
    @Environment(\.displayCurrencyRevision) private var moneyRefresh
    let entry: MoneyEntry
    let source: String?
    var body: some View {
        let _ = languageRefresh
        let _ = moneyRefresh
        HStack(spacing: 13) {
            Image(systemName: entry.category.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(entry.category.color)
                .frame(width: 46, height: 46)
                .background(entry.category.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                HStack(spacing: 5) {
                    Text(L(entry.category.rawValue))
                    if let source { Text("· " + source).lineLimit(1) }
                    Text("· " + entry.date.formatted(.dateTime.month().day().locale(AppLocalization.locale)))
                }
                .font(.system(size: 11))
                .foregroundStyle(LedgerTheme.subtext)
            }
            Spacer(minLength: 5)
            Text((entry.kind == .expense ? "−" : "+") + entry.amount.won)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(entry.kind == .expense ? LedgerTheme.text : .green)
        }
        .padding(.vertical, 7)
    }
}

struct WalletCardArt: View {
    @Environment(\.appLanguageRevision) private var languageRefresh
    @Environment(\.displayCurrencyRevision) private var moneyRefresh
    let card: PaymentCard
    let spent: Int
    var body: some View {
        let _ = languageRefresh
        let _ = moneyRefresh
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(card.issuer).font(.system(size: 13, weight: .medium)).opacity(0.83)
                    Text(card.name).font(.system(size: 21, weight: .bold)).lineLimit(1)
                }
                Spacer()
                Image(systemName: "wave.3.right")
                    .font(.system(size: 25, weight: .light))
                    .rotationEffect(.degrees(90))
            }
            Spacer(minLength: 0)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("••••  ••••  ••••  \(card.lastFour)")
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    Text("이번 달 사용  " + spent.won)
                        .font(.system(size: 12, weight: .medium)).opacity(0.84)
                }
                Spacer()
                ZStack {
                    Circle().fill(.white.opacity(0.8)).frame(width: 26, height: 26).offset(x: -10)
                    Circle().fill(.white.opacity(0.48)).frame(width: 26, height: 26).offset(x: 10)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 200)
        .background(LinearGradient(colors: card.tone.gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 27, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Circle().stroke(.white.opacity(0.13), lineWidth: 48)
                .frame(width: 180, height: 180)
                .offset(x: 80, y: -85)
                .clipped()
        }
    }
}


// Adapt to the actual available content width (after system navigation/safe areas),
// not an assumed device name or a horizontal size class.
struct DuoColumns: Layout {
    var spacing: CGFloat = 20
    var minWidth: CGFloat = 650

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? max(320, subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 320)
        let columns = width >= minWidth ? 2 : 1
        let cellWidth = max(0, (width - CGFloat(columns - 1) * spacing) / CGFloat(columns))
        var height: CGFloat = 0
        for start in stride(from: 0, to: subviews.count, by: columns) {
            let rowHeight = (start..<min(start + columns, subviews.count)).map {
                subviews[$0].sizeThatFits(ProposedViewSize(width: cellWidth, height: nil)).height
            }.max() ?? 0
            if start > 0 { height += spacing }
            height += rowHeight
        }
        return CGSize(width: width, height: height)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columns = bounds.width >= minWidth ? 2 : 1
        let w = max(0, (bounds.width - CGFloat(columns - 1) * spacing) / CGFloat(columns))
        var y = bounds.minY
        for start in stride(from: 0, to: subviews.count, by: columns) {
            var rowHeight: CGFloat = 0
            for i in start..<min(start + columns, subviews.count) {
                let p = ProposedViewSize(width: w, height: nil)
                subviews[i].place(at: CGPoint(x: bounds.minX + CGFloat(i - start) * (w + spacing), y: y), anchor: .topLeading, proposal: p)
                rowHeight = max(rowHeight, subviews[i].sizeThatFits(p).height)
            }
            y += rowHeight + spacing
        }
    }
}
