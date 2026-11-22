import SwiftUI

struct AnimatedWalletCard: View {
    let card: PaymentCard
    let spent: Int
    let onEdit: () -> Void
    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.78)) { expanded.toggle() }
            } label: {
                WalletCardArt(card: card, spent: spent)
                    .scaleEffect(expanded ? 1 : 0.975)
                    .rotation3DEffect(.degrees(expanded && !reduceMotion ? -3 : 0), axis: (x: 1, y: 0, z: 0))
                    .shadow(color: .black.opacity(expanded ? 0.18 : 0.08), radius: expanded ? 18 : 7, y: 7)
            }.buttonStyle(.plain).accessibilityLabel("\(card.name) 카드 상세 열기")
            if expanded {
                HStack {
                    Text("이번 달 사용: \(spent.won)").font(.subheadline)
                    Spacer()
                    Button("카드 수정", action: onEdit).fontWeight(.semibold)
                }.padding(16).background(LedgerTheme.panel, in: RoundedRectangle(cornerRadius: 16))
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}
