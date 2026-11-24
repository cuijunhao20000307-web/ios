import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PhotosUI
import ImageIO

struct WalletView: View {
    @Environment(\.appLanguageRevision) private var languageRefresh
    @Environment(\.displayCurrencyRevision) private var moneyRefresh
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.displayCurrencyRevision) private var currencyRevision
    @State private var section = 0
    @State private var showCard = false
    @State private var editPaymentCard: PaymentCard?
    @State private var showAccount = false
    @State private var selectedCard: UUID?
    // Keep the driver alive without subscribing the entire wallet page to
    // each display-link tick. The isolated scene is the only observer.
    @State private var cardMotion = WalletMotionDriver()
    @State private var deckRenderRevision = 0
    @State private var cardFrames: [UUID: CGRect] = [:]
    @State private var sourceCardFrame: CGRect?
    @State private var sourceVisibleFraction: CGFloat = 1
    @State private var detailCardFrame: CGRect = .zero
    @State private var transitionStarted = false
    @State private var transitionSettled = false
    @State private var transitionClosing = false
    @State private var transitionToken = UUID()
    @State private var detailPullActive = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var deckDragging = false
    @State private var search = ""
    @AppStorage("walletStacked") private var stacked = true
    @State private var searchVisible = false
    @FocusState private var searchFocused: Bool
    @State private var editAccount: BankAccount?
    @State private var securityAccount: BankAccount?
    @State private var secretShown = false
    @State private var revealedSecret: String?
    @State private var unlockFailed = false

    var body: some View {
        let _ = languageRefresh
        let _ = moneyRefresh
        NavigationStack {
            GeometryReader { viewport in
                ZStack(alignment: .top) {
                    walletRoot
                        .frame(width: viewport.size.width, height: viewport.size.height, alignment: .top)
                        // Keep original stack mounted for geometry and scroll
                        // restoration, but never blend it with detail artwork.
                        .opacity(transitionStarted ? 0 : 1)
                        .allowsHitTesting(selectedCard == nil)
                        .accessibilityHidden(selectedCard != nil)
                        .zIndex(0)
                    if let id = selectedCard {
                        WalletTransitionScene(
                            cardID: id, cards: filteredCards, frames: cardFrames,
                            source: sourceCardFrame, destination: detailCardFrame,
                            sourceVisibleFraction: sourceVisibleFraction,
                            stacked: stacked, editingCard: editPaymentCard?.id == id,
                            ready: transitionStarted, settled: transitionSettled, pulling: detailPullActive,
                            viewport: viewport.size, motion: cardMotion,
                            onPullChanged: updateCardPull, onPullEnded: finishCardPull,
                            onClose: closeCard,
                            onDetailFrame: { frame in
                                guard frame.width > 0, frame.height > 0 else { return }
                                if !transitionStarted || transitionSettled { detailCardFrame = frame }
                                if !transitionStarted && !transitionClosing {
                                    startCardTransition(id)
                                }
                            })
                            .transition(.identity)
                            .zIndex(1)
                    }
                }
                .frame(width: viewport.size.width, height: viewport.size.height)
                .coordinateSpace(name: "walletPresentation")
                .onPreferenceChange(WalletSourceCardFramesKey.self) { frames in
                    if selectedCard == nil { cardFrames = frames }
                }
                .environment(\.walletRetreatDistance, viewport.size.height)
                .clipped()
            }
            .background(LedgerTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if section != 2 {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            if selectedCard != nil { closeCard() }
                            else if section == 0 { showCard = true }
                            else { showAccount = true }
                        } label: {
                            Image(systemName: selectedCard == nil ? "plus" : "chevron.left")
                                .fontWeight(.semibold)
                                .contentTransition(.identity)
                                .transaction { $0.animation = nil }
                        }
                        .accessibilityLabel(L(selectedCard != nil ? "닫기" : (section == 0 ? "카드 추가" : "통장 추가")))
                        .accessibilityIdentifier(selectedCard == nil ? "wallet.add" : "wallet.close")
                        if let id = selectedCard {
                            Button {
                                editPaymentCard = store.data.cards.first(where: { $0.id == id })
                            } label: {
                                Image(systemName: "square.and.pencil")
                            }.accessibilityLabel(L("카드 수정"))
                        } else {
                        Menu {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        searchVisible.toggle()
                                        if !searchVisible { search = "" }
                                    }
                                    searchFocused = searchVisible
                                } label: { Label(L("카드 및 은행 검색"), systemImage: "magnifyingglass") }
                                if section == 0 {
                                    if !store.data.cards.isEmpty {
                                        Menu {
                                            ForEach(store.data.cards) { card in
                                                Button { openCard(card.id) } label: {
                                                    Label(card.name + " · " + card.lastFour, systemImage: "creditcard")
                                                }
                                            }
                                        } label: { Label(L("카드 정보"), systemImage: "creditcard") }
                                        Menu {
                                            ForEach(store.data.cards) { card in
                                                Button { editPaymentCard = card } label: {
                                                    Label(card.name + " · " + card.lastFour, systemImage: "creditcard")
                                                }
                                            }
                                        } label: { Label(L("카드 수정"), systemImage: "square.and.pencil") }
                                    }
                                    Button { withAnimation(.easeInOut(duration: 0.25)) { stacked.toggle() } } label: {
                                        Label(L(stacked ? "목록 보기" : "겹쳐 보기"), systemImage: stacked ? "square.grid.2x2" : "rectangle.stack")
                                    }
                                }
                                Button { searchFocused = false; section = 2 } label: {
                                    Label(L("개인정보 보관함"), systemImage: "lock.shield")
                                }
                        } label: { Image(systemName: "ellipsis") }
                        }
                    }
                }
            }
        }
        .onDisappear {
            guard !transitionSettled else { return }
            cardMotion.set(0)
            selectedCard = nil
            transitionToken = UUID()
            transitionStarted = false
            transitionSettled = false
            transitionClosing = false
            detailPullActive = false
            deckRenderRevision += 1
        }
        .sheet(isPresented: $showCard) { CardForm() }
        .sheet(item: $editPaymentCard, onDismiss: {
            if let id = selectedCard, !store.data.cards.contains(where: { $0.id == id }) { closeCard() }
        }) { CardForm(existing: $0) }
        .sheet(isPresented: $showAccount) { BankAccountForm() }
        .sheet(item: $editAccount) { BankAccountForm(existing: $0) }
        .sheet(item: $securityAccount) { BankSecurityCardView(account: $0) }
        .alert("보호된 코드", isPresented: $secretShown) {
            Button(L("닫기")) { revealedSecret = nil }
        } message: {
            Text(revealedSecret ?? "저장된 코드가 없습니다.")
        }
        .alert(L("인증 실패"), isPresented: $unlockFailed) {
            Button(L("확인"), role: .cancel) { }
        } message: {
            Text("Face ID 또는 기기 암호 인증을 완료해야 확인할 수 있습니다.")
        }
    }

    private func openCard(_ id: UUID) {
        guard selectedCard == nil, store.data.cards.contains(where: { $0.id == id }) else { return }
        searchFocused = false
        deckDragging = false
        transitionToken = UUID()
        sourceCardFrame = cardFrames[id]
        sourceVisibleFraction = 1
        if stacked, let source = sourceCardFrame,
           let index = filteredCards.firstIndex(where: { $0.id == id }),
           filteredCards.indices.contains(index + 1),
           let next = cardFrames[filteredCards[index + 1].id] {
            sourceVisibleFraction = min(1, max(0, (next.minY - source.minY) / max(1, source.height)))
        }
        detailCardFrame = .zero
        transitionStarted = false
        transitionSettled = false
        transitionClosing = false
        detailPullActive = false
        cardMotion.set(0)
        selectedCard = id
    }

    private func startCardTransition(_ id: UUID) {
        guard selectedCard == id, !transitionStarted, !transitionClosing else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { transitionStarted = true }
        let token = transitionToken
        // Destination geometry is now laid out. No timer or staged shuffle.
        cardMotion.animate(to: 1, duration: reduceMotion || sourceCardFrame == nil ? 0 : WalletCardMotion.duration) {
            guard transitionToken == token, selectedCard == id, !transitionClosing, !detailPullActive else { return }
            transitionSettled = true
        }
    }

    private func closeCard() {
        guard selectedCard != nil, !transitionClosing else { return }
        transitionToken = UUID()
        let token = transitionToken
        transitionClosing = true
        transitionSettled = false
        detailPullActive = false
        cardMotion.animate(to: 0, duration: reduceMotion || sourceCardFrame == nil ? 0 : WalletCardMotion.duration * Double(cardMotion.value)) {
            guard transitionToken == token, transitionClosing else { return }
            selectedCard = nil
            sourceCardFrame = nil
            transitionStarted = false
            transitionClosing = false
        }
    }

    private var cardReturnDistance: CGFloat {
        WalletCardMotion.returnDistance(source: sourceCardFrame, destination: detailCardFrame)
    }

    private func updateCardPull(_ translation: CGFloat) {
        guard !transitionClosing, transitionSettled || detailPullActive else { return }
        if !detailPullActive {
            transitionToken = UUID()
            detailPullActive = true
            transitionSettled = false
        }
        cardMotion.set(WalletCardMotion.progress(translation: translation, distance: cardReturnDistance))
    }

    private func finishCardPull(_ translation: CGFloat, _ velocity: CGFloat, _ cancelled: Bool) {
        guard detailPullActive, !transitionClosing else { return }
        if !cancelled && WalletCardMotion.shouldDismiss(translation: translation, velocity: velocity, distance: cardReturnDistance) {
            closeCard()
        } else {
            detailPullActive = false
            transitionToken = UUID()
            let token = transitionToken
            cardMotion.animate(to: 1, duration: reduceMotion ? 0 : 0.20) {
                guard transitionToken == token, selectedCard != nil, !transitionClosing else { return }
                transitionSettled = true
            }
        }
    }

    private var walletSections: some View {
        Picker(L("지갑"), selection: $section) {
            Text(L("카드 지갑")).tag(0)
            Text(L("통장 지갑")).tag(1)
            Text(L("개인정보")).tag(2)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity)
    }

    private var walletRoot: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Text(L("지갑")).font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
                if searchVisible && section != 2 {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField(L("카드 및 은행 검색"), text: $search)
                            .focused($searchFocused)
                        Button {
                            search = ""; searchVisible = false; searchFocused = false
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }.accessibilityLabel(L("닫기"))
                    }
                    .padding(12)
                    .background(LedgerTheme.panel, in: RoundedRectangle(cornerRadius: 14))
                    .frame(maxWidth: 460).frame(maxWidth: .infinity)
                }
                walletSections
            }
            .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 16)
            .frame(maxWidth: 920).frame(maxWidth: .infinity)
            if section == 2 {
                PrivateWalletView(embedded: true)
                    .frame(maxWidth: 920, maxHeight: .infinity, alignment: .top)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                ScrollView {
                    Group {
                        if section == 0 { cardsContent } else { accountsContent }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 16)
                    .frame(maxWidth: 920).frame(maxWidth: .infinity)
                }
                .scrollDisabled(deckDragging)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(LedgerTheme.background)
        .onChange(of: section) { _, next in
            searchFocused = false; deckDragging = false
            if next == 2 { search = ""; searchVisible = false }
        }
    }

    private var filteredCards: [PaymentCard] {
        store.data.cards.filter {
            search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) ||
            $0.issuer.localizedCaseInsensitiveContains(search) || $0.lastFour.contains(search)
        }
    }

    private var cardsContent: some View {
        let cards = filteredCards
        return VStack(spacing: 12) {
            if cards.isEmpty {
                Surface { EmptyContent(symbol: "creditcard", title: "표시할 카드가 없어요", subtitle: "+ 버튼으로 새 카드를 추가할 수 있어요") }
                    .frame(maxWidth: 400)
            } else {
                if stacked {
                    InteractiveWalletDeck(cards: cards, selectedCard: transitionStarted ? selectedCard : nil,
                        transitionProgress: 0, renderRevision: deckRenderRevision,
                        canReorder: search.isEmpty,
                        dragging: $deckDragging,
                        spent: { store.spent(on: $0, in: .now) },
                        select: openCard,
                        reorder: { id, target in
                            guard search.isEmpty,
                                  let index = store.data.cards.firstIndex(where: { $0.id == id }),
                                  store.data.cards.indices.contains(target), index != target else { return }
                            withAnimation(reduceMotion ? nil : .linear(duration: 0.30)) {
                                store.data.cards.move(fromOffsets: IndexSet(integer: index), toOffset: target > index ? target + 1 : target)
                            }
                        })
                        .frame(maxWidth: 320)
                    if search.isEmpty && cards.count > 1 {
                        Text(L("카드를 길게 눌러 순서를 변경할 수 있어요"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260, maximum: 365), spacing: 16)], spacing: 16) {
                        ForEach(cards) { card in
                            Button { openCard(card.id) } label: {
                                LedgerStackCard(card: card, spent: store.spent(on: card, in: .now))
                                    .aspectRatio(1.586, contentMode: .fit)
                                    .walletSourceFrame(card.id)
                                    .opacity(transitionStarted && selectedCard == card.id ? 0 : 1)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(card.name + " " + L("카드 정보"))
                        }
                    }
                    .frame(maxWidth: 750)
                }
                Text(String(cards.count) + " " + L("카드"))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.top, 5)
        .frame(maxWidth: .infinity)
    }

    private var accountsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "은행 통장", detail: "\(store.data.accounts.count)개")
            if store.data.accounts.isEmpty {
                Surface { EmptyContent(symbol: "building.columns", title: "등록된 통장이 없어요", subtitle: "+ 버튼에서 은행과 잔액을 추가해 보세요") }
            } else {
                ForEach(store.data.accounts.filter { search.isEmpty || $0.nickname.localizedCaseInsensitiveContains(search) || $0.bankName.localizedCaseInsensitiveContains(search) }) { account in
                    Surface {
                        VStack(alignment: .leading, spacing: 17) {
                            HStack(spacing: 12) {
                                BankLogoMark(bank: BankDirectory.resolve(id: account.bankLogoID, name: account.bankName), tone: account.tone, size: 54)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(account.nickname).font(.system(size: 16, weight: .bold))
                                    Text(account.bankName).font(.system(size: 12)).foregroundStyle(LedgerTheme.subtext)
                                }
                                Spacer()
                                Button { editAccount = account } label: {
                                    Image(systemName: "ellipsis").font(.headline).frame(width: 32, height: 32)
                                }
                                .foregroundStyle(LedgerTheme.subtext)
                            }
                            Text(account.accountNumber.lastFourMasked)
                                .font(.system(size: 14, design: .monospaced)).foregroundStyle(LedgerTheme.subtext)
                            Text(account.balance.won)
                                .font(.system(size: 29, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
                            HStack {
                                Label(L("비밀코드 보호"), systemImage: "lock.shield.fill")
                                    .font(.system(size: 12)).foregroundStyle(LedgerTheme.subtext)
                                Spacer()
                                Button(L("코드 확인")) { Task { await reveal(account) } }
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(LedgerTheme.accent)
                            }
                            Divider()
                            ProtectedPhotoLink(owner: "bank", id: account.id)
                            Divider()
                            Button { securityAccount = account } label: {
                                HStack {
                                    Label(L("보안카드"), systemImage: "number.square")
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption)
                                }.contentShape(Rectangle())
                            }.buttonStyle(.plain).foregroundStyle(LedgerTheme.accent)
                        }
                    }
                }
                Text(L("통장 잔액은 직접 입력한 기초 잔액입니다. 홈의 가계부 잔액은 거래에 따라 계산합니다."))
                    .font(.system(size: 12)).foregroundStyle(LedgerTheme.subtext)
            }
        }
    }

    @MainActor private func reveal(_ account: BankAccount) async {
        guard await LocalUnlock.authorize() else { unlockFailed = true; return }
        revealedSecret = SecureVault.retrieve(for: account.id) ?? "등록된 비밀코드가 없습니다."
        secretShown = true
    }
}


// Reuse artwork UIImage providers across deck, flying card and detail.
// No card pixels or other private fields leave process memory.
@MainActor private enum LedgerArtworkPreviewCache {
    private static let images: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 24
        cache.totalCostLimit = 96 * 1024 * 1024
        return cache
    }()
    private static func signature(_ data: Data) -> String {
        let count = data.count
        return data.withUnsafeBytes { buffer in
            let marks = [0, 1, 2, count / 7, count / 3, count / 2,
                (count * 2) / 3, (count * 6) / 7, count - 3, count - 2, count - 1]
            var fingerprint: UInt64 = 14695981039346656037
            for i in marks where i >= 0 && i < count {
                fingerprint = (fingerprint ^ UInt64(buffer[i])) &* 1099511628211
            }
            return String(count) + "-" + String(fingerprint, radix: 16)
        }
    }
    static func image(for card: PaymentCard) -> UIImage? {
        guard let data = card.artwork, !data.isEmpty else { return nil }
        let key = NSString(string: card.id.uuidString + "-" + signature(data))
        if let hit = images.object(forKey: key) { return hit }
        guard let decoded = UIImage(data: data) else { return nil }
        images.setObject(decoded, forKey: key,
            cost: Int(decoded.size.width * decoded.size.height * 4))
        return decoded
    }
}

private struct LedgerCardBackground: View {
    let card: PaymentCard
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: card.tone.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                if let decoded = LedgerArtworkPreviewCache.image(for: card) {
                    Image(uiImage: decoded).resizable().scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                    (card.artworkTextDark == true ? Color.white : Color.black)
                        .opacity(min(max(card.artworkShowNetwork == nil && card.artworkDim == 0.18 ? 0 : (card.artworkDim ?? 0), 0), 0.65))
                }
            }.clipped()
        }
    }
}
// Rectangles are measured in the same viewport, including the deck's scroll offset.
private struct WalletSourceCardFramesKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
private struct WalletDetailCardFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next.width > 0 { value = next }
    }
}
private struct WalletRetreatDistanceKey: EnvironmentKey { static let defaultValue: CGFloat = 800 }
private extension EnvironmentValues {
    var walletRetreatDistance: CGFloat {
        get { self[WalletRetreatDistanceKey.self] }
        set { self[WalletRetreatDistanceKey.self] = newValue }
    }
}
private extension View {
    func walletSourceFrame(_ id: UUID) -> some View {
        background {
            GeometryReader { geometry in
                Color.clear.preference(key: WalletSourceCardFramesKey.self,
                    value: [id: geometry.frame(in: .named("walletPresentation"))])
            }
        }
    }
}
// The frame clock only invalidates this small animation scene, never the
// NavigationStack, wallet root, unrelated ledger panels or transaction list.
private struct WalletTransitionScene: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let cardID: UUID
    let cards: [PaymentCard]
    let frames: [UUID: CGRect]
    let source: CGRect?
    let destination: CGRect
    let sourceVisibleFraction: CGFloat
    let stacked: Bool
    let editingCard: Bool
    let ready: Bool
    let settled: Bool
    let pulling: Bool
    let viewport: CGSize
    @ObservedObject var motion: WalletMotionDriver
    let onPullChanged: (CGFloat) -> Void
    let onPullEnded: (CGFloat, CGFloat, Bool) -> Void
    let onClose: () -> Void
    let onDetailFrame: (CGRect) -> Void

    var body: some View {
        let progress = motion.value
        let focus = cards.firstIndex(where: { $0.id == cardID }) ?? 0
        ZStack(alignment: .top) {
            LedgerTheme.background.opacity(ready ? 1 : 0)
            if ready && !reduceMotion && source != nil {
                ZStack(alignment: .topLeading) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        if card.id != cardID, let frame = frames[card.id] {
                            let retreat: CGFloat = index < focus
                                ? -viewport.height * 0.85 : viewport.height * 1.06
                            // During return keep the original exposed strip;
                            // do not uncover full card faces between slots.
                            let nextFrame = index + 1 < cards.count
                                ? frames[cards[index + 1].id] : nil
                            let exposed = stacked
                                ? WalletCardMotion.stackVisibleHeight(
                                    current: frame, next: nextFrame)
                                : frame.height
                            LedgerStackCard(card: card, spent: store.spent(on: card, in: .now))
                                .frame(width: frame.width, height: frame.height)
                                .mask(alignment: .top) {
                                    Rectangle().frame(height: exposed)
                                }
                                .position(x: frame.midX, y: frame.midY +
                                    retreat * WalletCardMotion.siblingRetreatProgress(progress))
                                .opacity(Double(WalletCardMotion.siblingOpacity(progress)))
                                .zIndex(Double(index))
                        }
                    }
                }
                .frame(width: viewport.width, height: viewport.height)
                .clipped()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            LedgerCardDetail(cardID: cardID, editingCard: editingCard,
                artworkHidden: !settled && source != nil && !reduceMotion, dismissEnabled: settled || pulling,
                onPullChanged: onPullChanged, onPullEnded: onPullEnded, onClose: onClose)
                .frame(width: viewport.width, height: viewport.height, alignment: .top)
                .coordinateSpace(name: "walletDetail")
                .background(LedgerTheme.background)
                .opacity(!ready ? 0 : reduceMotion ? 1 :
                    Double(WalletCardMotion.detailOpacity(progress)))
                .allowsHitTesting(settled || pulling)
                .accessibilityHidden(!settled)
                .onPreferenceChange(WalletDetailCardFrameKey.self, perform: onDetailFrame)
            if ready && !reduceMotion, let card = cards.first(where: { $0.id == cardID }), let source {
                WalletFlyingCard(card: card, spent: store.spent(on: card, in: .now),
                    source: source, destination: destination.width > 0 ? destination : source,
                    sourceVisibleFraction: sourceVisibleFraction, retreatDistance: viewport.height,
                    progress: progress)
                    .opacity(settled ? 0 : 1)
                    .transition(.identity)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .zIndex(2)
            }
        }
        .frame(width: viewport.width, height: viewport.height)
        .clipped()
    }
}

private struct WalletFlyingCard: View {
    let card: PaymentCard
    let spent: Int
    let source: CGRect
    let destination: CGRect
    let sourceVisibleFraction: CGFloat
    let retreatDistance: CGFloat
    var progress: CGFloat
    var body: some View {
        let rect = WalletCardMotion.frame(source: source, destination: destination, progress: progress)
        let scale = rect.width / max(1, source.width)
        LedgerStackCard(card: card, spent: spent)
            // Keep text/layout fixed. Only apply scale and position every frame.
            .frame(width: source.width, height: source.height)
            .mask(alignment: .top) {
                Rectangle().frame(height: WalletCardMotion.visibleHeight(source: source, current: rect,
                    visibleFraction: sourceVisibleFraction, retreat: retreatDistance,
                    progress: progress) / max(scale, 0.001))
            }
            .scaleEffect(scale)
            .position(x: rect.midX, y: rect.midY)
    }
}

private struct DeckDragState: Equatable {
    let id: UUID
    var translation: CGFloat = 0
}

// The full cards are drawn in a fixed coordinate space, with dedicated hit regions
// for the visible strips. Long press lifts a card; dragging changes its proposed
// slot, and only release writes the new order to persistent ledger data.
private struct InteractiveWalletDeck: View {
    let cards: [PaymentCard]
    // Selected card is visual-only state: the original overlay touch regions
    // and scroll geometry do not move or shrink.
    let selectedCard: UUID?
    let transitionProgress: CGFloat
    let renderRevision: Int
    let canReorder: Bool
    @Binding var dragging: Bool
    let spent: (PaymentCard) -> Int
    let select: (UUID) -> Void
    let reorder: (UUID, Int) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var drag: DeckDragState?
    @State private var suppressTapUntil = Date.distantPast
    @Namespace private var dragSpace
    @StateObject private var browseMotion = WalletMotionDriver()
    @State private var browseAnchor: Int?
    @Environment(\.walletRetreatDistance) private var retreatDistance

    private func stepFor(_ width: CGFloat) -> CGFloat { max(35, min(46, width * 0.14)) }
    private func target(_ id: UUID, _ distance: CGFloat, _ step: CGFloat) -> Int {
        let origin = cards.firstIndex { $0.id == id } ?? 0
        return min(max(0, origin + Int((distance / step).rounded())), max(0, cards.count - 1))
    }
    private func slot(_ index: Int, origin: Int?, destination: Int?) -> Int {
        guard let origin, let destination else { return index }
        if index == origin { return destination }
        if origin < destination && index > origin && index <= destination { return index - 1 }
        if destination < origin && index >= destination && index < origin { return index + 1 }
        return index
    }
    var body: some View {
        WalletDeckLayout {
            ForEach(cards) { _ in Color.clear }
        }
        .overlay {
            GeometryReader { geo in
                let width = min(320, geo.size.width)
                let height = width / 1.586
                let step = stepFor(width)
                let origin = drag.flatMap { value in cards.firstIndex { $0.id == value.id } }
                let destination = drag.map { target($0.id, $0.translation, step) }
                ZStack(alignment: .topLeading) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        let lifted = drag?.id == card.id
                        let progress: CGFloat = selectedCard == nil || reduceMotion ? 0 : transitionProgress
                        let fan = browseAnchor.map { WalletDeckFan.offset(index: index, anchor: $0,
                            translation: browseMotion.value, height: height, step: step) } ?? 0
                        let y = lifted ? CGFloat(index) * step + (drag?.translation ?? 0)
                            : CGFloat(slot(index, origin: origin, destination: destination)) * step
                        let focus = selectedCard.flatMap { id in cards.firstIndex { $0.id == id } }
                        // Upper cards retreat together; lower cards leave below.
                        // Selection never invents a new stack order.
                        let retreat: CGFloat = focus.map { index < $0 ? -height * 0.6 : retreatDistance } ?? 0
                        LedgerStackCard(card: card, spent: spent(card))
                            .frame(width: width, height: height)
                            .walletSourceFrame(card.id)
                            .scaleEffect(lifted && !reduceMotion ? 1.035 : 1, anchor: .top)
                            .shadow(color: .black.opacity(lifted ? 0.22 : 0), radius: 9, y: 4)
                            .offset(y: y + retreat * progress + (reduceMotion ? 0 : fan))
                            .opacity(selectedCard == card.id ? 0 : 1)
                            .id("\(card.id)-\(renderRevision)")
                            .transition(.identity)
                            .zIndex(lifted ? Double(cards.count + 2) : Double(index))
                            .animation(lifted || reduceMotion ? nil : .linear(duration: 0.22), value: destination)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                            touchRegion(card, index: index, width: width,
                                height: index == cards.count - 1 ? height : step, step: step)
                        }
                    }
                    .zIndex(Double(cards.count + 2))
                }
                .frame(width: width, height: geo.size.height, alignment: .topLeading)
                .coordinateSpace(name: dragSpace)
                .background {
                    WalletDeckBrowseRecognizer(enabled: selectedCard == nil && !dragging,
                        onChanged: { y, translation in
                            if browseAnchor == nil {
                                browseAnchor = WalletDeckFan.anchor(at: y, step: step, count: cards.count)
                            }
                            browseMotion.set(translation)
                            suppressTapUntil = .now.addingTimeInterval(0.3)
                        }, onEnded: {
                            browseMotion.animate(to: 0, duration: reduceMotion ? 0 : 0.26) { browseAnchor = nil }
                            suppressTapUntil = .now.addingTimeInterval(0.3)
                        })
                }
            }
        }
        .onChange(of: drag?.id) { old, id in
            dragging = id != nil
            if id != nil { browseMotion.set(0); browseAnchor = nil }
            if old != nil && id == nil { suppressTapUntil = .now.addingTimeInterval(0.25) }
        }
        .onChange(of: selectedCard) { _, _ in browseMotion.set(0); browseAnchor = nil }
        .onDisappear { dragging = false; browseMotion.set(0); browseAnchor = nil }
    }

    @ViewBuilder private func touchRegion(_ card: PaymentCard, index: Int, width: CGFloat, height: CGFloat, step: CGFloat) -> some View {
        let button = Button {
            if drag == nil && Date.now >= suppressTapUntil { select(card.id) }
        } label: {
            Rectangle().fill(Color.black.opacity(0.001))
                .frame(width: width, height: height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("카드 선택") + ": " + card.name)
        .accessibilityIdentifier("wallet.card.select.\(index)")
        if canReorder && cards.count > 1 {
            button
                .simultaneousGesture(reorderGesture(card.id, step: step))
                .accessibilityAction(named: Text(L("앞으로 이동"))) {
                    if index < cards.count - 1 { reorder(card.id, index + 1) }
                }
                .accessibilityAction(named: Text(L("뒤로 이동"))) {
                    if index > 0 { reorder(card.id, index - 1) }
                }
        } else { button }
    }

    private func reorderGesture(_ id: UUID, step: CGFloat) -> some Gesture {
        LongPressGesture(minimumDuration: 0.25, maximumDistance: 12)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(dragSpace)))
            .updating($drag) { value, state, _ in
                switch value {
                case .first(true):
                    state = DeckDragState(id: id)
                case .second(true, let movement):
                    state = DeckDragState(id: id, translation: movement?.translation.height ?? 0)
                default: break
                }
            }
            .onEnded { value in
                if case .second(true, let movement) = value, let movement {
                    reorder(id, target(id, movement.translation.height, step))
                }
                suppressTapUntil = .now.addingTimeInterval(0.25)
                dragging = false
            }
    }
}

// Ordinary dragging fans the deck. Holding first still enters the existing
// reorder gesture; only that gesture is allowed to change persisted order.
private struct WalletDeckBrowseRecognizer: UIViewRepresentable {
    let enabled: Bool
    let onChanged: (CGFloat, CGFloat) -> Void
    let onEnded: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> Marker {
        let marker = Marker()
        marker.isUserInteractionEnabled = false
        context.coordinator.marker = marker
        marker.onMove = { [weak coordinator = context.coordinator] in coordinator?.attach() }
        return marker
    }
    func updateUIView(_ view: Marker, context: Context) {
        context.coordinator.parent = self
        context.coordinator.attach()
    }
    static func dismantleUIView(_ view: Marker, coordinator: Coordinator) { coordinator.detach() }
    final class Marker: UIView {
        var onMove: (() -> Void)?
        override func didMoveToWindow() { super.didMoveToWindow(); onMove?() }
        override func didMoveToSuperview() { super.didMoveToSuperview(); onMove?() }
    }
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: WalletDeckBrowseRecognizer
        weak var marker: Marker?
        weak var scroll: UIScrollView?
        private var startY: CGFloat = 0
        private var offset: CGPoint = .zero
        private var savedBounces = true
        private var savedScrollEnabled = true
        private var tracking = false
        private lazy var pan: UIPanGestureRecognizer = {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handle(_:)))
            pan.maximumNumberOfTouches = 1
            pan.delegate = self
            return pan
        }()
        init(_ parent: WalletDeckBrowseRecognizer) { self.parent = parent }
        func attach() {
            var ancestor = marker?.superview
            while let view = ancestor {
                if let candidate = view as? UIScrollView {
                    if candidate !== scroll {
                        detach()
                        scroll = candidate
                        candidate.addGestureRecognizer(pan)
                    }
                    return
                }
                ancestor = view.superview
            }
        }
        func detach() {
            if tracking {
                scroll?.bounces = savedBounces
                scroll?.isScrollEnabled = savedScrollEnabled
                tracking = false
            }
            scroll?.removeGestureRecognizer(pan)
            scroll = nil
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard parent.enabled, let marker, marker.bounds.contains(touch.location(in: marker)) else { return false }
            startY = touch.location(in: marker).y
            return true
        }
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard parent.enabled, let scroll else { return false }
            let velocity = pan.velocity(in: scroll)
            return abs(velocity.y) > abs(velocity.x) * 1.12
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            other === scroll?.panGestureRecognizer
        }
        @objc private func handle(_ recognizer: UIPanGestureRecognizer) {
            guard let scroll else { return }
            switch recognizer.state {
            case .began:
                tracking = true
                offset = scroll.contentOffset
                savedBounces = scroll.bounces
                savedScrollEnabled = scroll.isScrollEnabled
                scroll.bounces = false
                scroll.isScrollEnabled = false
                fallthrough
            case .changed:
                guard tracking else { return }
                scroll.setContentOffset(offset, animated: false)
                parent.onChanged(startY, recognizer.translation(in: scroll).y)
            case .ended, .cancelled, .failed:
                guard tracking else { return }
                tracking = false
                scroll.setContentOffset(offset, animated: false)
                scroll.bounces = savedBounces
                scroll.isScrollEnabled = savedScrollEnabled
                parent.onEnded()
            default: break
            }
        }
    }
}

private struct WalletDeckLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = min(proposal.width ?? 320, 320)
        guard !subviews.isEmpty else { return CGSize(width: width, height: 0) }
        let step = max(35, min(46, width * 0.14))
        return CGSize(width: width, height: width / 1.586 + CGFloat(subviews.count - 1) * step)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = min(bounds.width, 320)
        let step = max(35, min(46, width * 0.14))
        for i in subviews.indices {
            subviews[i].place(at: CGPoint(x: bounds.midX - width / 2, y: bounds.minY + CGFloat(i) * step),
                              anchor: .topLeading, proposal: ProposedViewSize(width: width, height: width / 1.586))
        }
    }
}
private struct LedgerCardStrip: View {
    let card: PaymentCard
    var body: some View {
        HStack {
            Text(card.issuer).font(.system(size: 16, weight: .bold)).lineLimit(1)
            Spacer(minLength: 10)
            Text(card.name).font(.system(size: 14, weight: .medium)).lineLimit(1)
        }
        .foregroundStyle(card.artwork != nil && card.artworkTextDark == true ? Color.black : Color.white)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background { LedgerCardBackground(card: card) }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 19, topTrailingRadius: 19))
    }
}
private struct LedgerNetworkBadge: View {
    let network: String
    var body: some View {
        if network == "Mastercard" {
            HStack(spacing: -8) {
                Circle().fill(Color(red: 0.9, green: 0.08, blue: 0.17)).frame(width: 25, height: 25)
                Circle().fill(Color(red: 1, green: 0.63, blue: 0.08)).frame(width: 25, height: 25)
            }
            .accessibilityLabel("Mastercard")
        } else if network != "none" && network != "기타" && !network.isEmpty {
            Text(network)
                .font(.system(size: network == "UnionPay" ? 11 : 14, weight: .black, design: .rounded))
                .italic(network == "VISA")
                .foregroundStyle(network == "VISA" || network == "AMEX" ? Color(red: 0.07, green: 0.23, blue: 0.56) : .black)
                .padding(.horizontal, 7).padding(.vertical, 5)
                .background(.white, in: RoundedRectangle(cornerRadius: 5))
        }
    }
}
private enum LedgerArtwork {
    // Downsample before decoding and render a bounded 1.586:1 decorative JPEG.
    static func prepare(_ data: Data) -> Data? {
        guard data.count <= 40_000_000,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1600
              ] as CFDictionary) else { return nil }
        let image = UIImage(cgImage: thumb)
        let size = CGSize(width: 1000, height: 630)
        guard image.size.width > 0 && image.size.height > 0 else { return nil }
        let scale = max(size.width / image.size.width, size.height / image.size.height)
        let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let output = UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 0.80) { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2, width: drawn.width, height: drawn.height))
        }
        return output.count <= 1_000_000 ? output : nil
    }
}

// The ledger keeps only public metadata and the last four digits.
// All complete card details live in the existing protected wallet archive.
struct LedgerStackCard: View {
    @Environment(\.appLanguageRevision) private var languageRefresh
    @Environment(\.displayCurrencyRevision) private var moneyRefresh
    let card: PaymentCard
    let spent: Int
    var record: PrivateRecord? = nil
    var showNumber = false

    private var number: String {
        let digits = (record?.fields["카드번호"] ?? "").filter(\.isNumber)
        if showNumber && !digits.isEmpty {
            let chars = Array(digits)
            return stride(from: 0, to: chars.count, by: 4).map {
                String(chars[$0..<min($0 + 4, chars.count)])
            }.joined(separator: "  ")
        }
        return "••••  ••••  ••••  " + card.lastFour
    }
    var body: some View {
        let _ = languageRefresh
        let _ = moneyRefresh
        GeometryReader { geo in
            let pad = max(12, geo.size.width * 0.055)
            Group {
                if card.artwork != nil {
                    ZStack(alignment: .bottomLeading) {
                        LedgerCardBackground(card: card)
                        HStack(alignment: .bottom, spacing: 8) {
                            Text("•••• " + card.lastFour)
                                .font(.system(size: max(12, min(19, geo.size.width * 0.043)), weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(card.artworkTextDark == true ? Color.black : Color.white)
                                .shadow(color: card.artworkTextDark == true ? .white.opacity(0.24) : .black.opacity(0.32), radius: 1.5)
                            Spacer(minLength: 4)
                            if card.artworkShowNetwork == true {
                                LedgerNetworkBadge(network: card.network ?? "none")
                            }
                        }
                        .padding(.horizontal, max(12, geo.size.width * 0.055))
                        .padding(.bottom, max(10, geo.size.height * 0.07))
                    }
                } else {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(card.issuer).font(.system(size: 13, weight: .medium)).opacity(0.8).lineLimit(1)
                        Text(card.name).font(.system(size: 17, weight: .semibold)).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "wave.3.right").font(.system(size: 18, weight: .light))
                        .rotationEffect(.degrees(90)).accessibilityHidden(true)
                }
                Spacer(minLength: 6)
                Text(number).font(.system(size: max(14, min(22, geo.size.width * 0.049)), weight: .semibold, design: .monospaced))
                    .lineLimit(1).minimumScaleFactor(0.65)
                    .privacySensitive()
                Spacer(minLength: 6)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let holder = record?.fields["카드 소유자"], !holder.isEmpty {
                            Text(L("사용자 이름")).font(.caption2).opacity(0.75)
                            Text(holder).font(.subheadline.bold()).lineLimit(1).privacySensitive()
                        } else {
                            Text(L("이번 달 사용")).font(.caption2).opacity(0.75)
                            Text(spent.won).font(.subheadline.bold()).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                    if let expiry = record?.fields["유효기간"], !expiry.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("유효기간")).font(.caption2).opacity(0.75)
                            Text(expiry).font(.subheadline.bold()).privacySensitive()
                        }
                    }
                    Spacer(minLength: 4)
                    LedgerNetworkBadge(network: card.network ?? record?.fields["카드 브랜드"] ?? "none")
                }
            }
            .padding(pad)
            .foregroundStyle(card.artwork != nil && card.artworkTextDark == true ? Color.black : Color.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { LedgerCardBackground(card: card) }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 19).strokeBorder(.white.opacity(0.19), lineWidth: 1))
            .shadow(color: .black.opacity(0.13), radius: 6, x: 0, y: 2)
        }
    }
}

private enum LinkedCardVault {
    static func record(in archive: PrivateArchive, id: UUID) -> PrivateRecord? {
        archive.records.first { $0.kind == .card && $0.link == id && $0.deletedAt == nil }
    }
    static func draft(for card: PaymentCard, archive: PrivateArchive) -> PrivateRecord {
        if let current = record(in: archive, id: card.id) { return current }
        var record = PrivateRecord()
        record.kind = .card
        record.link = card.id
        record.title = card.name
        record.fields["카드사"] = card.issuer
        return record
    }
    // Reload immediately before saving to retain any other vault changes.
    static func save(_ record: PrivateRecord) throws {
        var archive = try PrivateStorage.load()
        if let i = archive.records.firstIndex(where: { $0.id == record.id }) { archive.records[i] = record }
        else if let i = archive.records.firstIndex(where: { $0.kind == .card && $0.link == record.link && $0.deletedAt == nil && record.link != nil }) {
            var updated = record
            updated.id = archive.records[i].id
            archive.records[i] = updated
        } else { archive.records.append(record) }
        try PrivateStorage.save(archive)
    }
    static func trash(id: UUID) throws {
        var archive = try PrivateStorage.load()
        var changed = false
        for i in archive.records.indices where archive.records[i].kind == .card && archive.records[i].link == id && archive.records[i].deletedAt == nil {
            archive.records[i].deletedAt = .now
            changed = true
        }
        if changed { try PrivateStorage.save(archive) }
    }
}

// Neutral adaptive gray action surfaces; keep native tab and toolbar tint unchanged.
private struct NeutralCardActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.primary)
            .frame(minHeight: 44)
            .padding(.horizontal, 8)
            .background(Color(uiColor: configuration.isPressed ? .tertiarySystemFill : .secondarySystemFill), in: Capsule())
            .opacity(enabled ? 1 : 0.45)
    }
}

// Observe the existing detail ScrollView's pan stream. Only a downward,
// vertical pull beginning on the measured header/card at scroll-top is claimed.
// Starting on controls or transaction rows leaves normal scrolling untouched.
private struct WalletCardPullRecognizer: UIViewRepresentable {
    let enabled: Bool
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat, CGFloat, Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> Marker {
        let marker = Marker()
        marker.isUserInteractionEnabled = false
        context.coordinator.marker = marker
        marker.onMove = { [weak coordinator = context.coordinator] in coordinator?.attach() }
        return marker
    }
    func updateUIView(_ view: Marker, context: Context) {
        context.coordinator.parent = self
        context.coordinator.attach()
    }
    static func dismantleUIView(_ view: Marker, coordinator: Coordinator) { coordinator.detach() }

    final class Marker: UIView {
        var onMove: (() -> Void)?
        override func didMoveToWindow() { super.didMoveToWindow(); onMove?() }
        override func didMoveToSuperview() { super.didMoveToSuperview(); onMove?() }
    }
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: WalletCardPullRecognizer
        weak var marker: Marker?
        weak var scroll: UIScrollView?
        private var tracking = false
        private var savedBounces = true
        private lazy var pan: UIPanGestureRecognizer = {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handle(_:)))
            pan.delegate = self
            pan.maximumNumberOfTouches = 1
            pan.cancelsTouchesInView = false
            return pan
        }()
        init(_ parent: WalletCardPullRecognizer) { self.parent = parent }
        func attach() {
            var ancestor = marker?.superview
            while let view = ancestor {
                if let candidate = view as? UIScrollView {
                    if candidate !== scroll {
                        detach()
                        scroll = candidate
                        candidate.addGestureRecognizer(pan)
                    }
                    return
                }
                ancestor = view.superview
            }
        }
        func detach() {
            if tracking {
                scroll?.bounces = savedBounces
                tracking = false
            }
            scroll?.removeGestureRecognizer(pan)
            scroll = nil
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard parent.enabled, let marker else { return false }
            return marker.bounds.contains(touch.location(in: marker))
        }
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard parent.enabled, let marker, let scroll, marker.window != nil,
                  marker.bounds.contains(pan.location(in: marker)),
                  scroll.contentOffset.y <= -scroll.adjustedContentInset.top + 1 else { return false }
            let velocity = pan.velocity(in: scroll)
            return velocity.y > 0 && velocity.y > abs(velocity.x) * 1.12
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            other === scroll?.panGestureRecognizer
        }
        @objc private func handle(_ recognizer: UIPanGestureRecognizer) {
            guard let scroll else { return }
            let translation = max(0, recognizer.translation(in: scroll).y)
            switch recognizer.state {
            case .began:
                tracking = true
                savedBounces = scroll.bounces
                scroll.bounces = false
                scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: -scroll.adjustedContentInset.top), animated: false)
                parent.onChanged(translation)
            case .changed:
                if tracking { parent.onChanged(translation) }
            case .ended, .cancelled, .failed:
                guard tracking else { return }
                tracking = false
                scroll.bounces = savedBounces
                parent.onEnded(translation, recognizer.velocity(in: scroll).y, recognizer.state != .ended)
            default: break
            }
        }
    }
}

struct LedgerCardDetail: View {
    @Environment(\.appLanguageRevision) private var languageRefresh
    @Environment(\.displayCurrencyRevision) private var moneyRefresh
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.displayCurrencyRevision) private var currencyRevision
    @Environment(\.scenePhase) private var phase
    let cardID: UUID
    let editingCard: Bool
    let artworkHidden: Bool
    let dismissEnabled: Bool
    let onPullChanged: (CGFloat) -> Void
    let onPullEnded: (CGFloat, CGFloat, Bool) -> Void
    let onClose: () -> Void
    @State private var record: PrivateRecord?
    @State private var authorized = false
    @State private var revealCVC = false
    @State private var busy = false
    @State private var error: String?
    @State private var copied = false
    @State private var editingTransaction: MoneyEntry?
    @State private var authSession = UUID()
    private var card: PaymentCard? { store.data.cards.first { $0.id == cardID } }
    private var accent: Color { Color.primary }
    private var thisMonthExpenses: [MoneyEntry] {
        store.entries(in: .now).filter { $0.kind == .expense && $0.sourceId == cardID }
    }

    var body: some View {
        let _ = languageRefresh
        let _ = moneyRefresh
        Group {
            if let card {
                ScrollView {
                    DuoColumns(spacing: 24, minWidth: 620) {
                        VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(card.issuer).font(.headline).foregroundStyle(.secondary)
                            Text(card.name).font(.largeTitle.bold())
                        }
                        LedgerStackCard(card: card, spent: store.spent(on: card, in: .now), record: authorized ? record : nil, showNumber: authorized)
                            .aspectRatio(1.586, contentMode: .fit)
                            .background {
                                GeometryReader { geometry in
                                    Color.clear.preference(key: WalletDetailCardFrameKey.self,
                                        value: geometry.frame(in: .named("walletDetail")))
                                }
                            }
                            .opacity(artworkHidden ? 0 : 1)
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("wallet.detail.header")
                        .background {
                            WalletCardPullRecognizer(enabled: dismissEnabled,
                                onChanged: onPullChanged, onEnded: onPullEnded)
                        }
                        HStack {
                            Button {
                                Task { await unlock(copy: false) }
                            } label: {
                                Label(L(authorized ? "정보 잠그기" : "카드번호 보기"), systemImage: authorized ? "lock" : "lock.open")
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                            }.buttonStyle(NeutralCardActionStyle()).disabled(busy)
                            .accessibilityIdentifier("wallet.card.reveal")
                            Button {
                                Task { await unlock(copy: true) }
                            } label: {
                                Label(L(copied ? "복사 완료" : "카드번호 복사"), systemImage: "doc.on.doc")
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                            }.buttonStyle(NeutralCardActionStyle()).disabled(busy)
                        }
                        Text(L("이번 달 사용")).font(.title2.bold())
                        Surface {
                            VStack(alignment: .leading, spacing: 9) {
                                Text(store.spent(on: card, in: .now).won)
                                    .font(.title.bold()).monospacedDigit()
                                    .lineLimit(1).minimumScaleFactor(0.55)
                                if card.spendingLimit > 0 {
                                    Text(L("월 사용 한도") + " " + card.spendingLimit.won)
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                        HStack(alignment: .firstTextBaseline) {
                            Text(L("카드 소비 내역")).font(.title2.bold())
                            Spacer()
                            Text(String(thisMonthExpenses.count) + " " + L("건"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Surface {
                            if thisMonthExpenses.isEmpty {
                                Label(L("이 카드로 기록된 이번 달 지출이 없습니다."),
                                      systemImage: "list.bullet.rectangle")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                            } else {
                                VStack(spacing: 2) {
                                    ForEach(thisMonthExpenses) { entry in
                                        Button { editingTransaction = entry } label: {
                                            EntryLine(entry: entry, source: nil)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        if entry.id != thisMonthExpenses.last?.id {
                                            Divider().opacity(0.55)
                                        }
                                    }
                                }
                            }
                        }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .leading, spacing: 20) {
                        Text(L("카드 정보")).font(.title2.bold())
                        VStack(spacing: 0) {
                            info("카드번호", value: authorized ? formattedCardNumber(record?.fields["카드번호"]) : "•••• " + card.lastFour)
                            Divider()
                            HStack(spacing: 14) {
                                badge("lock.shield")
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("CVC").foregroundStyle(.secondary).font(.subheadline)
                                    Text(revealCVC ? (record?.fields["CVC"].flatMap { $0.isEmpty ? nil : $0 } ?? "미등록") : "••••••")
                                        .font(.headline.monospacedDigit()).privacySensitive()
                                }
                                Spacer()
                                Button {
                                    Task { await toggleCVC() }
                                } label: {
                                    Image(systemName: revealCVC ? "lock.open.fill" : "lock.fill")
                                        .font(.body).padding(12)
                                        .background(.secondary.opacity(0.10), in: Circle())
                                }.buttonStyle(.plain).disabled(busy)
                            }.padding(.vertical, 13)
                            Divider()
                            info("사용자 이름", value: authorized ? record?.fields["카드 소유자"] : nil)
                            Divider()
                            info("유효기간", value: authorized ? record?.fields["유효기간"] : nil)
                            Divider()
                            info("카드 브랜드", value: card.network == "none" ? L("없음") : (card.network ?? (authorized ? record?.fields["카드 브랜드"] : nil)))
                        }
                        Text(L("사진")).font(.title2.bold())
                        Surface { ProtectedPhotoLink(owner: "card", id: card.id) }
                        if authorized && record == nil {
                            Text("전체 카드 정보가 아직 등록되지 않았습니다. 편집에서 카드번호, 유효기간을 입력하세요.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(20).frame(maxWidth: 920).frame(maxWidth: .infinity)
                }
                .background(Color.clear)
            } else {
                ContentUnavailableView("삭제된 카드", systemImage: "creditcard")
                    .overlay(alignment: .bottom) { Button(L("닫기"), action: onClose).padding() }
            }
        }
        .sheet(item: $editingTransaction) { TransactionForm(existing: $0) }
        .onChange(of: artworkHidden) { _, hidden in if hidden { clear() } }
        .onChange(of: editingCard) { _, value in if value { clear() } }
        .onChange(of: phase) { _, p in if p == .background { clear() } }
        .overlay { if phase != .active { Color(uiColor: .systemBackground).ignoresSafeArea() } }
        .onDisappear { clear() }
        .alert(L("확인"), isPresented: Binding(get: {error != nil}, set: {if !$0 {error = nil}})) { Button(L("확인")) {error = nil} } message: { Text(error ?? "") }
    }
    private func formattedCardNumber(_ value: String?) -> String? {
        let digits = Array((value ?? "").filter(\.isNumber))
        guard !digits.isEmpty else { return nil }
        let groups = digits.count == 15 ? [4, 6, 5] : Array(repeating: 4, count: (digits.count + 3) / 4)
        var index = 0
        return groups.compactMap { length -> String? in
            guard index < digits.count else { return nil }
            let end = min(index + length, digits.count)
            let part = String(digits[index..<end])
            index = end
            return part
        }.joined(separator: " ")
    }
    private func badge(_ icon: String) -> some View {
        Image(systemName: icon).foregroundStyle(accent).frame(width: 46, height: 46)
            .background(Color(uiColor: .secondarySystemFill), in: RoundedRectangle(cornerRadius: 13))
    }
    private func info(_ name: String, value: String?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L(name)).font(.subheadline).foregroundStyle(.secondary)
            Text(value.flatMap { $0.isEmpty ? nil : $0 } ?? (authorized ? "미등록" : "••••"))
                .font(.headline).privacySensitive()
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 14)
    }
    private func clear() { authSession = UUID(); record = nil; authorized = false; revealCVC = false; copied = false }
    @MainActor private func unlock(copy: Bool) async {
        if authorized && !copy { clear(); return }
        guard !busy else { return }
        busy = true
        let token = authSession
        defer { busy = false }
        guard await LocalUnlock.authorize(), token == authSession, !Task.isCancelled, phase != .background else { return }
        do {
            let archive = try PrivateStorage.load()
            record = LinkedCardVault.record(in: archive, id: cardID)
            authorized = true
            if copy {
                guard let number = record?.fields["카드번호"], !number.isEmpty else {
                    error = "등록된 전체 카드번호가 없습니다."; return
                }
                UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: number]], options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(60)])
                copied = true
            }
        } catch { self.error = error.localizedDescription }
    }
    @MainActor private func toggleCVC() async {
        if revealCVC { revealCVC = false; return }
        guard !busy else { return }
        busy = true
        let token = authSession
        defer { busy = false }
        guard await LocalUnlock.authorize(), token == authSession, !Task.isCancelled, phase != .background else { return }
        do {
            record = LinkedCardVault.record(in: try PrivateStorage.load(), id: cardID)
            authorized = true
            revealCVC = true
        } catch { self.error = error.localizedDescription }
    }
}

struct CardForm: View {
    @Environment(\.appLanguageRevision) private var languageRefresh
    @Environment(\.displayCurrencyRevision) private var moneyRefresh
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.displayCurrencyRevision) private var currencyRevision
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    var existing: PaymentCard? = nil
    @State private var id = UUID()
    @State private var name = ""
    @State private var issuer = ""
    @State private var lastFour = ""
    @State private var tone: WalletTone = .midnight
    @State private var limit = ""
    @State private var protectedRecord: PrivateRecord?
    @State private var busy = false
    @State private var visible = false
    @State private var confirmDelete = false
    @State private var error: String?

    @State private var artwork: Data?
    @State private var artworkDark = false
    @State private var artworkDim = 0.0
    @State private var artworkShowNetwork = false
    @State private var network = "none"
    @State private var networkEdited = false
    @State private var photo: PhotosPickerItem?
    @State private var photoLoading = false

    private let brands = ["none", "VISA", "Mastercard", "AMEX", "JCB", "UnionPay", "BC", "Tmoney", "Discover", "Diners Club", "Maestro"]
    private var digits: String { (protectedRecord?.fields["카드번호"] ?? "").filter(\.isNumber) }
    private var effectiveLastFour: String { digits.isEmpty ? lastFour : String(digits.suffix(4)) }
    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !issuer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        effectiveLastFour.count == 4 && (digits.isEmpty || (12...19).contains(digits.count)) &&
        ((protectedRecord?.fields["CVC"] ?? "").isEmpty || (3...4).contains((protectedRecord?.fields["CVC"] ?? "").count))
    }

    var body: some View {
        let _ = languageRefresh
        let _ = moneyRefresh
        NavigationStack {
            Form {
                Section(L("카드")) {
                    TextField(L("카드 별칭"), text: $name)
                    TextField(L("카드사"), text: $issuer)
                    TextField(L("카드번호 마지막 4자리"), text: $lastFour)
                        .keyboardType(.numberPad)
                        .onChange(of: lastFour) { _, value in lastFour = String(value.filter(\.isNumber).prefix(4)) }
                        .disabled(!digits.isEmpty)
                    Picker(L("카드 색상"), selection: $tone) {
                        ForEach(WalletTone.allCases) { Text(L($0.rawValue)).tag($0) }
                    }
                    HStack {
                        Text(L("월 사용 한도"))
                        Spacer()
                        TextField(L("선택"), text: $limit).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                        Text(DisplayCurrency.selected.symbol).foregroundStyle(.secondary)
                    }
                }
                Section(L("카드 디자인")) {
                    LedgerStackCard(card: draftCard(), spent: 0)
                        .aspectRatio(1.586, contentMode: .fit)
                        .frame(maxWidth: 440)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                    PhotosPicker(selection: $photo, matching: .images) {
                        Label(L("사진 선택"), systemImage: "photo.on.rectangle")
                    }.disabled(photoLoading)
                    if photoLoading { ProgressView() }
                    if artwork != nil {
                        Button(L("이미지 제거"), role: .destructive) { artwork = nil; photo = nil }
                        Toggle(L("어두운 글자"), isOn: $artworkDark)
                        Toggle(L("카드 브랜드 표시"), isOn: $artworkShowNetwork)
                        HStack {
                            Text(L("이미지 음영"))
                            Slider(value: $artworkDim, in: 0...0.65)
                        }
                    }
                    Picker(L("카드 브랜드"), selection: $network) {
                        ForEach(brands, id: \.self) { brand in
                            Text(brand == "none" ? L("없음") : brand).tag(brand)
                        }
                    }
                    .onChange(of: network) { _, _ in networkEdited = true }
                    Text(L("카드 사진에는 실제 카드번호, CVC 등 민감 정보가 없어야 합니다. 장식 이미지로만 사용됩니다."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section(L("전체 카드 정보 · 보호됨")) {
                    if protectedRecord == nil {
                        Button { Task { await openProtected() } } label: {
                            Label(L("기기 인증 후 카드번호 · CVC 등록"), systemImage: "lock.shield")
                        }.disabled(busy)
                        Text("기존 보안 정보는 잠긴 상태에서 수정하거나 덮어쓰지 않습니다.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Toggle(L("보안 정보 표시"), isOn: $visible)
                        if visible {
                            TextField(L("전체 카드번호"), text: field("카드번호")).keyboardType(.numberPad)
                            TextField("CVC", text: field("CVC")).keyboardType(.numberPad)
                        } else {
                            SecureField(L("전체 카드번호"), text: field("카드번호")).keyboardType(.numberPad)
                            SecureField("CVC", text: field("CVC")).keyboardType(.numberPad)
                        }
                        TextField(L("사용자 이름"), text: field("카드 소유자")).textInputAutocapitalization(.characters)
                        TextField(L("유효기간 (MM/YY)"), text: field("유효기간")).keyboardType(.numbersAndPunctuation)
                        if !digits.isEmpty { Text("카드번호 끝자리: " + effectiveLastFour).font(.caption).foregroundStyle(.secondary) }
                        Text("전체 카드번호 및 CVC는 선택 항목이며 기기 전용 Keychain에 저장됩니다. 실제 CVC 저장은 권장하지 않습니다.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let existing {
                    Section(L("사진")) { ProtectedPhotoLink(owner: "card", id: existing.id) }
                }
                if existing != nil { Section { Button(L("이 카드 삭제"), role: .destructive) { confirmDelete = true } } }
            }
            .navigationTitle(L(existing == nil ? "카드 등록" : "카드 수정"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("취소")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(L("저장")) { save() }.disabled(!valid || busy || photoLoading) }
            }
            .confirmationDialog("카드를 삭제할까요?", isPresented: $confirmDelete) {
                Button(L("삭제"), role: .destructive) { Task { await delete() } }
            } message: { Text("연결된 보안 정보는 인증 후 보관함 휴지통으로 이동합니다.") }
            .onAppear {
                if let existing {
                    id = existing.id; name = existing.name; issuer = existing.issuer; lastFour = existing.lastFour
                    tone = existing.tone; limit = String(existing.spendingLimit)
                    artwork = existing.artwork; artworkDark = existing.artworkTextDark ?? false
                    artworkDim = min(max(existing.artworkShowNetwork == nil && existing.artworkDim == 0.18 ? 0 : (existing.artworkDim ?? 0), 0), 0.65)
                    artworkShowNetwork = existing.artworkShowNetwork ?? false
                    network = existing.network ?? "none"
                }
            }
            .task(id: photo) {
                guard let item = photo else { return }
                photoLoading = true
                defer { if photo == item { photoLoading = false } }
                do {
                    guard let data = try await item.loadTransferable(type: Data.self),
                          !Task.isCancelled, photo == item,
                          let converted = LedgerArtwork.prepare(data) else {
                        if !Task.isCancelled && photo == item { error = L("이미지를 불러올 수 없습니다.") }
                        return
                    }
                    artwork = converted
                    artworkDim = 0
                } catch { if !Task.isCancelled && photo == item { self.error = L("이미지를 불러올 수 없습니다.") } }
            }
            .onChange(of: phase) { _, p in
                if p != .active { visible = false }
                if p == .background { protectedRecord = nil; dismiss() }
            }
            .overlay { if phase != .active { Color(uiColor: .systemBackground).ignoresSafeArea() } }
            .alert(L("확인"), isPresented: Binding(get: {error != nil}, set: {if !$0 {error = nil}})) { Button(L("확인")) {error = nil} } message: { Text(error ?? "") }
        }
    }
    private func field(_ key: String, fallback: String = "") -> Binding<String> {
        Binding(get: { protectedRecord?.fields[key] ?? fallback }, set: { value in
            if key == "카드번호" { protectedRecord?.fields[key] = String(value.filter(\.isNumber).prefix(19)) }
            else if key == "CVC" { protectedRecord?.fields[key] = String(value.filter(\.isNumber).prefix(4)) }
            else { protectedRecord?.fields[key] = value }
        })
    }
    @MainActor private func openProtected() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        guard await LocalUnlock.authorize(), phase != .background else { return }
        do {
            protectedRecord = LinkedCardVault.draft(for: draftCard(), archive: try PrivateStorage.load())
            if existing?.network == nil && !networkEdited, let brand = protectedRecord?.fields["카드 브랜드"], brands.contains(brand) {
                network = brand
            }
        }
        catch { self.error = error.localizedDescription }
    }
    private func draftCard() -> PaymentCard {
        PaymentCard(id: id, name: name, issuer: issuer, lastFour: effectiveLastFour, tone: tone, spendingLimit: limit.toMoneyInt, artwork: artwork, artworkTextDark: artworkDark, artworkDim: artworkDim, artworkShowNetwork: artworkShowNetwork, network: networkEdited || existing?.network != nil || existing == nil ? network : nil)
    }
    private func save() {
        guard valid else { return }
        let card = draftCard()
        if var record = protectedRecord {
            record.title = name; record.link = id; record.fields["카드사"] = issuer
            if let selected = card.network { record.fields["카드 브랜드"] = selected }
            do { try LinkedCardVault.save(record) }
            catch { self.error = error.localizedDescription; return }
        }
        if let index = store.data.cards.firstIndex(where: { $0.id == card.id }) { store.data.cards[index] = card }
        else { store.data.cards.append(card) }
        protectedRecord = nil
        dismiss()
    }
    @MainActor private func delete() async {
        guard let existing, !busy else { return }
        busy = true
        defer { busy = false }
        guard await LocalUnlock.authorize(), phase != .background else { return }
        do {
            try LinkedCardVault.trash(id: existing.id)
            store.data.cards.removeAll { $0.id == existing.id }
            protectedRecord = nil
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct BankAccountForm: View {
    @Environment(\.appLanguageRevision) private var languageRefresh
    @Environment(\.displayCurrencyRevision) private var moneyRefresh
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.displayCurrencyRevision) private var currencyRevision
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    var existing: BankAccount? = nil
    @State private var nickname = ""
    @State private var bank = ""
    @State private var bankLogoID: String?
    @State private var showBankPicker = false
    @State private var loadedAccount = false
    @State private var accountNumber = ""
    @State private var balance = ""
    @State private var secret = ""
    @State private var tone: WalletTone = .emerald
    @State private var confirmDelete = false
    @State private var saveError = false
    @State private var showSecurity = false
    @State private var websiteDetails: BankWebsiteDetails?
    @State private var revealPassword = false
    @State private var authenticatingWebsite = false
    @State private var websiteSession = UUID()

    var body: some View {
        let _ = languageRefresh
        let _ = moneyRefresh
        NavigationStack {
            Form {
                Section(L("통장 정보")) {
                    TextField("통장 별칭 (예: 월급 통장)", text: $nickname)
                    Button { showBankPicker = true } label: {
                        HStack(spacing: 12) {
                            BankLogoMark(bank: BankDirectory.resolve(id: bankLogoID, name: bank), tone: tone, size: 40)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L("은행 선택")).foregroundStyle(.secondary).font(.caption)
                                Text(bank.isEmpty ? L("은행 선택") : bank).foregroundStyle(.primary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                    }.buttonStyle(.plain)
                    TextField(L("은행명"), text: $bank)
                        .onChange(of: bank) { _, value in
                            if let current = bankLogoID, BankDirectory.byID(current)?.name != value {
                                bankLogoID = BankDirectory.resolve(id: nil, name: value)?.id
                            }
                        }
                    TextField(L("계좌번호 · 선택"), text: $accountNumber).keyboardType(.numbersAndPunctuation)
                    HStack {
                        Text(L("기초 잔액") + " (" + DisplayCurrency.selected.symbol + ")")
                        Spacer()
                        TextField("0", text: $balance).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                        Text(DisplayCurrency.selected.symbol).foregroundStyle(.secondary)
                    }
                    Picker(L("색상"), selection: $tone) {
                        ForEach(WalletTone.allCases) { Text(L($0.rawValue)).tag($0) }
                    }
                }
                Section(L("비밀코드 · 선택")) {
                    SecureField(existing == nil ? "새 비밀코드 입력" : "변경할 비밀코드 (비우면 유지)", text: $secret)
                        .textContentType(.password)
                    Text("비밀코드는 이 기기의 iOS 키체인에 따로 보관합니다. 조회할 때 기기 인증이 필요해요. 은행 로그인 비밀번호 저장은 권장하지 않습니다.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    if websiteDetails != nil {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(L("웹사이트"), systemImage: "globe").font(.subheadline.weight(.medium)).foregroundStyle(.teal)
                            TextField(L("웹사이트"), text: websiteField(\.website))
                                .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                            Divider()
                            Label(L("웹사이트 ID"), systemImage: "person.crop.circle").font(.subheadline.weight(.medium)).foregroundStyle(.teal)
                            TextField(L("웹사이트 ID"), text: websiteField(\.username))
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                            Divider()
                            Label(L("웹사이트 비밀번호"), systemImage: "key.fill").font(.subheadline.weight(.medium)).foregroundStyle(.teal)
                            HStack {
                                if revealPassword {
                                    TextField(L("웹사이트 비밀번호"), text: websiteField(\.password))
                                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                                } else {
                                    SecureField(L("웹사이트 비밀번호"), text: websiteField(\.password))
                                }
                                Button { revealPassword.toggle() } label: {
                                    Image(systemName: revealPassword ? "eye" : "eye.slash").foregroundStyle(.secondary)
                                }.buttonStyle(.plain).accessibilityLabel(L("내용 표시"))
                            }
                            Divider()
                            Label(L("메모"), systemImage: "note.text").font(.subheadline).foregroundStyle(.secondary)
                            TextEditor(text: websiteField(\.memo)).frame(minHeight: 92)
                        }
                        .privacySensitive()
                    } else {
                        Button { Task { await unlockWebsite() } } label: {
                            Label(L("기기 인증 후 웹사이트 정보 수정"), systemImage: "lock.shield")
                        }.disabled(authenticatingWebsite)
                    }
                } header: { Text(L("웹사이트 계정")) } footer: {
                    Text(L("이 기기에만 저장 · 백업 및 동기화 제외"))
                }
                Section(L("보안카드")) {
                    if existing != nil {
                        Button { showSecurity = true } label: {
                            Label(L("보안카드 보기 · 수정"), systemImage: "number.square")
                        }
                    } else {
                        Text(L("통장 저장 후 등록하세요.")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let existing {
                    Section(L("사진")) { ProtectedPhotoLink(owner: "bank", id: existing.id) }
                }
                if existing != nil { Section { Button(L("통장 삭제"), role: .destructive) { confirmDelete = true } } }
            }
            .navigationTitle(L(existing == nil ? "통장 등록" : "통장 수정"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("취소")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("저장")) { save() }
                        .disabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || bank.isEmpty || authenticatingWebsite || websiteDetails?.valid == false)
                }
            }
            .sheet(isPresented: $showBankPicker) {
                BankLogoPicker(selected: bankLogoID) { entry in
                    if let entry { bank = entry.name; bankLogoID = entry.id; tone = entry.tone }
                    else { bankLogoID = nil; bank = "" }
                }
            }
            .sheet(isPresented: $showSecurity) {
                if let existing { BankSecurityCardView(account: existing) }
            }
            .alert("키체인 저장 실패", isPresented: $saveError) {
                Button(L("확인"), role: .cancel) { }
            } message: { Text("비밀코드를 안전하게 저장하지 못했습니다. 기기 잠금 설정을 확인하고 다시 시도하세요.") }
            .confirmationDialog("이 통장을 삭제할까요?", isPresented: $confirmDelete) {
                Button(L("삭제"), role: .destructive) {
                    if let existing { store.deleteAccount(existing) }
                    dismiss()
                }
            }
            .onChange(of: phase) { _, next in
                if next != .active { revealPassword = false }
                if next == .background { clearWebsite(); secret = "" }
            }
            .overlay { if phase != .active { Color(uiColor: .systemBackground).ignoresSafeArea() } }
            .onDisappear { clearWebsite() }
            .onAppear {
                guard !loadedAccount else { return }
                loadedAccount = true
                if let existing {
                    nickname = existing.nickname; bank = existing.bankName; accountNumber = existing.accountNumber
                    balance = String(existing.balance); tone = existing.tone
                    bankLogoID = existing.bankLogoID ?? BankDirectory.resolve(id: nil, name: existing.bankName)?.id
                }
            }
        }
    }
    private func websiteField(_ key: WritableKeyPath<BankWebsiteDetails, String>) -> Binding<String> {
        Binding(get: { websiteDetails?[keyPath: key] ?? "" }, set: { value in
            websiteDetails?[keyPath: key] = value
        })
    }
    @MainActor private func unlockWebsite() async {
        guard !authenticatingWebsite else { return }
        authenticatingWebsite = true
        let token = websiteSession
        defer { authenticatingWebsite = false }
        guard await LocalUnlock.authorize(), token == websiteSession, phase != .background else { return }
        do {
            if let existing { websiteDetails = try BankWebsiteStorage.load(existing.id) ?? BankWebsiteDetails() }
            else { websiteDetails = BankWebsiteDetails() }
        } catch { saveError = true }
    }
    private func clearWebsite() {
        websiteSession = UUID(); websiteDetails = nil; revealPassword = false
    }
    private func save() {
        let id = existing?.id ?? UUID()
        if let websiteDetails {
            do { try BankWebsiteStorage.save(websiteDetails, id: id) }
            catch { saveError = true; return }
        }
        if !secret.isEmpty && !SecureVault.save(secret, for: id) { saveError = true; return }
        let account = BankAccount(id: id, nickname: nickname, bankName: bank,
                                  accountNumber: accountNumber, balance: balance.toMoneyInt, tone: tone,
                                  bankLogoID: BankDirectory.resolve(id: bankLogoID, name: bank)?.id)
        if let index = store.data.accounts.firstIndex(where: { $0.id == id }) { store.data.accounts[index] = account }
        else { store.data.accounts.append(account) }
        dismiss()
    }
}


struct BankSecurityCardView: View {
    let account: BankAccount
    var startEditing = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var card: BankSecurityCard?
    @State private var busy = false
    @State private var editing = false
    @State private var grid = false
    @State private var reveal = false
    @State private var serialVisible = false
    @State private var hasSaved = false
    @State private var error = false
    @State private var deleteConfirmation = false
    @State private var viewingSavedCodes = false
    @State private var unlockFailed = false
    @State private var session = UUID()
    @State private var front = ""
    @State private var back = ""
    @FocusState private var focused: Int?

    var body: some View {
        NavigationStack {
            Group {
                if let card {
                    if grid {
                        if viewingSavedCodes { savedCodeGrid(card) }
                        else { codeGrid(card) }
                    }
                    else if editing { settings(card) }
                    else { lookup(card) }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "lock.shield.fill").font(.system(size: 48)).foregroundStyle(.teal)
                        Text(L("보안카드")).font(.title2.bold())
                        Text(account.nickname).foregroundStyle(.secondary)
                        Button(L("보관함 열기")) { Task { await unlock() } }
                            .buttonStyle(.borderedProminent).disabled(busy)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(L(grid ? (viewingSavedCodes ? "보안카드 전체 보기" : "코드 입력") : "보안카드"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L(grid ? "뒤로" : "닫기")) {
                        if grid { closeGrid() } else { lock(); dismiss() }
                    }
                }
                if card != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        if grid { Button(L("완료")) { closeGrid() } }
                        else if editing { Button(L("저장"), action: save).disabled(card?.valid != true) }
                        else {
                            Button { editing = true; front = ""; back = "" } label: { Image(systemName: "square.and.pencil") }
                                .accessibilityLabel(L("수정"))
                        }
                    }
                }
            }
            .task { await unlock() }
            .onChange(of: phase) { _, p in
                if p == .background { lock() }
                else if p == .inactive && viewingSavedCodes {
                    // Never leave an entire security grid visible in the app switcher.
                    closeGrid()
                }
            }
            .onDisappear { lock() }
            .overlay { if phase != .active { Color(uiColor: .systemBackground).ignoresSafeArea() } }
            .alert(L("보안 저장 실패"), isPresented: $error) { Button(L("확인")) {} }
            .alert(L("인증 실패"), isPresented: $unlockFailed) {
                Button(L("확인"), role: .cancel) {}
            } message: {
                Text(L("Face ID 또는 기기 암호 인증을 완료해야 확인할 수 있습니다."))
            }
            .confirmationDialog(L("보안카드 삭제"), isPresented: $deleteConfirmation) {
                Button(L("삭제"), role: .destructive) {
                    do { try BankSecurityStorage.remove(account.id); lock(); dismiss() } catch { self.error = true }
                }
            }
        }
    }
    private var serialBinding: Binding<String> {
        Binding(get: { card?.serial ?? "" }, set: { card?.serial = String($0.prefix(64)) })
    }
    private func settings(_ value: BankSecurityCard) -> some View {
        Form {
            Section {
                HStack {
                    Group {
                        if serialVisible { TextField(L("일련번호"), text: serialBinding) }
                        else { SecureField(L("일련번호"), text: serialBinding) }
                    }
                    Button { serialVisible.toggle() } label: { Image(systemName: serialVisible ? "eye" : "eye.slash") }
                        .buttonStyle(.plain).accessibilityLabel(L("내용 표시"))
                }.privacySensitive()
                VStack(alignment: .leading, spacing: 10) {
                    Label(L("개수"), systemImage: "number")
                    Picker(L("개수"), selection: Binding(get: { card?.codes.count ?? 30 }, set: { card?.resize($0) })) {
                        ForEach(BankSecurityCard.counts, id: \.self) { Text(String($0)).tag($0) }
                    }.pickerStyle(.segmented)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Label(L("방향"), systemImage: "arrow.left.and.right")
                    Picker(L("방향"), selection: Binding(get: { card?.vertical ?? true }, set: { card?.vertical = $0 })) {
                        Text(L("가로")).tag(false)
                        Text(L("세로")).tag(true)
                    }.pickerStyle(.segmented)
                }
                Button {
                    serialVisible = false; reveal = true; grid = true
                } label: {
                    HStack {
                        Text(L("코드 입력"))
                        Spacer()
                        Text("\(value.codes.filter { $0.count == 4 }.count)/\(value.codes.count)").foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").font(.caption)
                    }
                }
            } header: { Text(L("보안카드")) } footer: {
                Text(L("개수를 줄이면 마지막 코드가 삭제됩니다."))
            }
            if hasSaved { Section { Button(L("보안카드 삭제"), role: .destructive) { deleteConfirmation = true } } }
            Section { Text(L("이 기기에만 저장 · 백업 및 동기화 제외")).font(.caption).foregroundStyle(.secondary) }
        }
    }
    // Read-only viewer: no TextField or accidental editing of stored bank codes.
    // A separate device-owner check is required before displaying all values.
    // All five printed columns must remain visible, even with Duo's side rail.
    // The old hard minimum of 380pt caused both edge columns to be cropped.
    private func savedCodeGrid(_ value: BankSecurityCard) -> some View {
        GeometryReader { geo in
            let columnCount = 5
            let rowCount = (value.codes.count + columnCount - 1) / columnCount
            let available = max(0, geo.size.width - 20)
            let gridWidth = min(available, 660)
            let gap: CGFloat = gridWidth < 320 ? 3 : 7
            let cellWidth = max(0, (gridWidth - CGFloat(columnCount - 1) * gap) / CGFloat(columnCount))
            let numberFont = min(19, max(9, cellWidth * 0.235))
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 7) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(LedgerTheme.accent)
                        Text(L("인증된 보안카드 조회"))
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1).minimumScaleFactor(0.75)
                        Spacer(minLength: 2)
                        Text("\(value.codes.filter { $0.count == 4 }.count)/\(value.codes.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text(L("보안카드 전체 번호는 다른 사람에게 공개하지 마세요."))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.fixed(cellWidth), spacing: gap), count: columnCount),
                        spacing: gridWidth < 320 ? 9 : 12
                    ) {
                        ForEach(0..<(rowCount * columnCount), id: \.self) { cell in
                            // Preserve paper-card order: 01..07, 08..14, ...
                            let index = (cell % columnCount) * rowCount + cell / columnCount
                            if index < value.codes.count {
                                VStack(spacing: 5) {
                                    Text(String(format: "%02d", index + 1))
                                        .font(.system(size: min(13, max(9, cellWidth * 0.25)),
                                                      weight: .regular, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Group {
                                        if value.codes[index].count == 4 {
                                            HStack(spacing: gridWidth < 320 ? 1 : 4) {
                                                Text(String(value.codes[index].prefix(2)))
                                                Rectangle()
                                                    .fill(Color.secondary.opacity(0.30))
                                                    .frame(width: 1, height: 17)
                                                Text(String(value.codes[index].suffix(2)))
                                            }
                                            .frame(maxWidth: .infinity)
                                        } else {
                                            Text("—")
                                        }
                                    }
                                    .font(.system(size: numberFont, weight: .semibold, design: .monospaced))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                    .frame(width: cellWidth, height: gridWidth < 320 ? 40 : 46)
                                    .background(Color(uiColor: .secondarySystemFill),
                                                in: RoundedRectangle(cornerRadius: gridWidth < 320 ? 8 : 10))
                                    .privacySensitive()
                                }
                                .frame(width: cellWidth)
                            } else {
                                Color.clear.frame(width: cellWidth, height: 65)
                            }
                        }
                    }
                    .frame(width: gridWidth)
                    Button { closeGrid() } label: {
                        Label(L("번호 숨기기"), systemImage: "eye.slash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
                }
                .frame(width: gridWidth, alignment: .leading)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }
        }
        .privacySensitive()
    }

    private func codeGrid(_ value: BankSecurityCard) -> some View {
        GeometryReader { geo in
            let available = max(0, geo.size.width - 20)
            let gridWidth = min(available, 660)
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(spacing: 14) {
                        Toggle(L("내용 표시"), isOn: $reveal)
                        Text("\(value.codes.filter { $0.count == 4 }.count) / \(value.codes.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        // Editing is also fully visible without a horizontal swipe.
                        columns(value, width: gridWidth)
                            .frame(width: gridWidth)
                    }
                    .frame(width: gridWidth)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: focused) { _, index in
                    if let index {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            scroll.scrollTo(index, anchor: .center)
                        }
                    }
                }
            }
        }
        .privacySensitive()
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button { moveFocus(-1, count: value.codes.count) } label: { Image(systemName: "chevron.up") }
                Button { moveFocus(1, count: value.codes.count) } label: { Image(systemName: "chevron.down") }
                Spacer()
                Button(L("완료")) { focused = nil }
            }
        }
    }

    private func columns(_ value: BankSecurityCard, width: CGFloat) -> some View {
        let count = 5
        let rows = (value.codes.count + count - 1) / count
        let gap: CGFloat = width < 320 ? 3 : 6
        let cellWidth = max(0, (width - CGFloat(count - 1) * gap) / CGFloat(count))
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(cellWidth), spacing: gap), count: count), spacing: 10) {
            ForEach(0..<(rows * count), id: \.self) { cell in
                let index = value.vertical ? (cell % count) * rows + cell / count : cell
                if index < value.codes.count {
                    VStack(spacing: 4) {
                        Text(String(format: "%02d", index + 1))
                            .font(.system(size: min(13, max(9, cellWidth * 0.25)), design: .monospaced))
                            .foregroundStyle(.secondary)
                        Group {
                            if reveal { TextField("----", text: codeBinding(index)) }
                            else { SecureField("----", text: codeBinding(index)) }
                        }
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: min(19, max(10, cellWidth * 0.24)),
                                      weight: .medium, design: .monospaced))
                        .focused($focused, equals: index)
                        .frame(width: cellWidth, height: width < 320 ? 40 : 44)
                        .background(Color(uiColor: .secondarySystemFill),
                                    in: RoundedRectangle(cornerRadius: width < 320 ? 8 : 10))
                        .overlay(RoundedRectangle(cornerRadius: width < 320 ? 8 : 10)
                            .strokeBorder(focused == index ? Color.teal : Color.clear, lineWidth: 1.5))
                        .accessibilityLabel(L("코드 입력") + " " + String(index + 1))
                    }
                    .frame(width: cellWidth)
                    .id(index)
                } else {
                    Color.clear.frame(width: cellWidth, height: 64)
                }
            }
        }
    }
    private func codeBinding(_ index: Int) -> Binding<String> {
        Binding(get: { guard let card, card.codes.indices.contains(index) else { return "" }; return card.codes[index] }, set: {
            guard card?.codes.indices.contains(index) == true else { return }
            let previous = card?.codes[index] ?? ""
            let digits = BankSecurityCard.digits($0, max: 4)
            card?.codes[index] = digits
            if previous.count < 4 && digits.count == 4 && focused == index {
                if let count = card?.codes.count, index + 1 < count { focused = index + 1 }
                else { focused = nil }
            }
        })
    }
    private func moveFocus(_ offset: Int, count: Int) {
        focused = min(max((focused ?? (offset > 0 ? -1 : 0)) + offset, 0), count - 1)
    }
    private func closeGrid() {
        focused = nil
        reveal = false
        grid = false
        viewingSavedCodes = false
    }
    private func lookup(_ value: BankSecurityCard) -> some View {
        Form {
            Section(account.nickname) {
                LabeledContent(L("개수"), value: String(value.codes.count))
                HStack {
                    Text(L("일련번호")); Spacer()
                    Text(serialVisible ? value.serial : "••••••").privacySensitive()
                    Button { serialVisible.toggle() } label: { Image(systemName: "eye") }.buttonStyle(.plain)
                }
            }
            Section {
                HStack {
                    Label(L("저장된 보안카드 코드"), systemImage: "number.square")
                        .font(.subheadline)
                    Spacer()
                    Text("\(value.codes.filter { $0.count == 4 }.count) / \(value.codes.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if hasSaved {
                    Button {
                        Task { await showSavedCodes() }
                    } label: {
                        HStack {
                            Label(L("보안카드 전체 보기"), systemImage: "eye")
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption)
                        }
                    }
                    .disabled(busy || value.codes.allSatisfy { $0.count != 4 })
                } else {
                    Text(L("저장된 보안카드가 없습니다."))
                        .font(.caption).foregroundStyle(.secondary)
                }
            } footer: {
                Text(L("보안카드 코드를 보려면 기기 인증이 필요합니다."))
            }
            Section(L("보안카드 조회")) {
                // Restore the original front/back search rows; input is a
                // two-digit code half, never the printed card row number.
                lookupRow(L("앞 두 자리"), number: $front,
                          matches: value.matches(firstTwo: front), first: true)
                lookupRow(L("뒤 두 자리"), number: $back,
                          matches: value.matches(lastTwo: back), first: false)
                if front.count == 2 {
                    lookupFeedback(value.matches(firstTwo: front), first: true)
                }
                if back.count == 2 {
                    lookupFeedback(value.matches(lastTwo: back), first: false)
                }
                Button(L("조회 초기화")) { front = ""; back = "" }
                    .disabled(front.isEmpty && back.isEmpty)
            }
            Section {
                Button(L("보안카드 등록 · 수정")) {
                    editing = true; front = ""; back = ""
                }
            }
        }
    }
    private func lookupRow(_ title: String, number: Binding<String>,
                           matches: [BankSecurityPairMatch], first: Bool) -> some View {
        // A unique result appears inline, where the old UI showed its code.
        // Multiple matches are displayed with ordinal numbers below the row.
        let counterpart = matches.count == 1
            ? (first ? matches[0].lastTwo : matches[0].firstTwo)
            : "••"
        return HStack {
            Text(title)
            Spacer()
            TextField("01", text: Binding(
                get: { number.wrappedValue },
                set: { number.wrappedValue = BankSecurityCard.digits($0, max: 2) }
            ))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.body.monospacedDigit())
            .frame(width: 60)
            .accessibilityLabel(title)
            Text(counterpart)
                .font(.headline.monospacedDigit())
                .frame(width: 60)
                .privacySensitive()
        }
    }
    @ViewBuilder private func lookupFeedback(_ matches: [BankSecurityPairMatch],
                                              first: Bool) -> some View {
        if matches.isEmpty {
            Label(L("일치하는 코드가 없습니다."), systemImage: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if matches.count > 1 {
            VStack(alignment: .leading, spacing: 10) {
                Text(L("같은 앞 두 자리가 여러 개 있습니다. 카드 번호를 확인하세요."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(matches) { matched in
                    HStack {
                        Text(String(format: "%02d", matched.ordinal))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(first ? matched.lastTwo : matched.firstTwo)
                            .font(.headline.monospacedDigit())
                            .privacySensitive()
                    }
                }
            }
        }
    }
    @MainActor private func showSavedCodes() async {
        guard !busy, !editing, hasSaved, card != nil else { return }
        busy = true
        let token = session
        defer { busy = false }
        guard await LocalUnlock.authorize(),
              !Task.isCancelled, token == session, phase != .background else {
            if token == session { unlockFailed = true }
            return
        }
        front = ""
        back = ""
        serialVisible = false
        viewingSavedCodes = true
        grid = true
    }

    @MainActor private func unlock() async {
        guard card == nil, !busy else { return }
        busy = true
        let token = session
        defer { busy = false }
        guard await LocalUnlock.authorize(), !Task.isCancelled, token == session, phase != .background else { return }
        do {
            let stored = try BankSecurityStorage.load(account.id)
            card = stored ?? BankSecurityCard()
            hasSaved = stored != nil
            editing = startEditing || stored == nil
        } catch { self.error = true }
    }
    private func save() {
        guard let card, card.valid, phase == .active else { return }
        do {
            try BankSecurityStorage.save(card, id: account.id)
            hasSaved = true; editing = false; serialVisible = false; reveal = false
            if startEditing { lock(); dismiss() }
        } catch { self.error = true }
    }
    private func lock() {
        session = UUID(); card = nil; editing = false; grid = false; reveal = false
        viewingSavedCodes = false
        serialVisible = false; front = ""; back = ""; focused = nil
    }
}


struct ProtectedPhotoLink: View {
    let owner: String
    let id: UUID
    @State private var presented = false
    var body: some View {
        Button { presented = true } label: {
            HStack {
                Label(L("앞면 · 뒷면 사진"), systemImage: "photo.on.rectangle")
                Spacer()
                Image(systemName: "lock.shield").foregroundStyle(.secondary)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain)
        .sheet(isPresented: $presented) { ProtectedPhotoView(owner: owner, id: id) }
    }
}

struct ProtectedPhotoView: View {
    let owner: String
    let id: UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var authorized = false
    @State private var busy = false
    @State private var failed = false
    @State private var session = UUID()
    @State private var front: Data?
    @State private var back: Data?
    @State private var frontPicker: PhotosPickerItem?
    @State private var backPicker: PhotosPickerItem?
    @State private var preview: UIImage?
    @State private var full = false
    @State private var deleting: Bool?
    var body: some View {
        NavigationStack {
            Group {
                if authorized {
                    ScrollView {
                        VStack(spacing: 20) {
                            photoPanel(false)
                            photoPanel(true)
                            Text(L("이 기기에만 저장 · 백업 및 동기화 제외"))
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(20).frame(maxWidth: 560).frame(maxWidth: .infinity)
                    }
                } else {
                    VStack(spacing: 18) {
                        Image(systemName: "lock.shield.fill").font(.largeTitle)
                        Button(L("보관함 열기")) { Task { await unlock() } }.buttonStyle(.borderedProminent).disabled(busy)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(L("사진"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("닫기")) { clear(); dismiss() } } }
            .task { await unlock() }
            .task(id: frontPicker) { if let item = frontPicker { await importPhoto(item, backSide: false) } }
            .task(id: backPicker) { if let item = backPicker { await importPhoto(item, backSide: true) } }
            .onChange(of: phase) { _, p in if p == .background { clear() } }
            .overlay { if phase != .active { Color(uiColor: .systemBackground).ignoresSafeArea() } }
            .fullScreenCover(isPresented: $full, onDismiss: { preview = nil }) {
                ZStack(alignment: .topTrailing) {
                    Color.black.ignoresSafeArea()
                    if authorized, phase == .active, let preview {
                        GeometryReader { g in
                            Image(uiImage: preview).resizable().scaledToFit()
                                .frame(width: g.size.width, height: g.size.height)
                        }
                    }
                    Button { full = false } label: {
                        Image(systemName: "xmark.circle.fill").font(.title).foregroundStyle(.white)
                            .padding(20)
                    }.accessibilityLabel(L("닫기"))
                }.privacySensitive()
            }
            .confirmationDialog(L("사진 삭제"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
                Button(L("삭제"), role: .destructive) {
                    guard authorized, let side = deleting else { return }
                    do {
                        try ProtectedPhotoStorage.remove(owner: owner, id: id, back: side)
                        if side { back = nil } else { front = nil }
                    } catch { failed = true }
                    deleting = nil
                }
            }
            .alert(L("보안 저장 실패"), isPresented: $failed) { Button(L("확인")) {} }
        }
    }
    private func photoPanel(_ backSide: Bool) -> some View {
        let data = backSide ? back : front
        return Surface {
            VStack(alignment: .leading, spacing: 12) {
                Text(L(backSide ? "뒷면 사진" : "앞면 사진")).font(.headline)
                if let data, let image = UIImage(data: data) {
                    Button { preview = image; full = true } label: {
                        Image(uiImage: image).resizable().scaledToFit()
                            .frame(maxHeight: 220).frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain).privacySensitive()
                } else {
                    Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 110)
                }
                HStack {
                    PhotosPicker(selection: backSide ? $backPicker : $frontPicker, matching: .images) {
                        Label(L("사진 선택"), systemImage: "plus.circle")
                    }.disabled(busy)
                    Spacer()
                    if data != nil {
                        Button(role: .destructive) { deleting = backSide } label: { Image(systemName: "trash") }
                            .disabled(busy)
                    }
                }
            }
        }
    }
    @MainActor private func unlock() async {
        guard !busy, !authorized else { return }
        busy = true
        let current = session
        defer { busy = false }
        guard await LocalUnlock.authorize(), current == session, phase != .background, !Task.isCancelled else { return }
        do {
            front = try ProtectedPhotoStorage.load(owner: owner, id: id, back: false)
            back = try ProtectedPhotoStorage.load(owner: owner, id: id, back: true)
            authorized = true
        } catch { clear(); failed = true }
    }
    @MainActor private func importPhoto(_ item: PhotosPickerItem, backSide: Bool) async {
        guard authorized, !busy else { return }
        busy = true
        let current = session
        defer { busy = false; if backSide { backPicker = nil } else { frontPicker = nil } }
        do {
            guard let raw = try await item.loadTransferable(type: Data.self),
                  current == session, authorized, phase != .background, !Task.isCancelled,
                  raw.count <= 40_000_000,
                  let source = CGImageSourceCreateWithData(raw as CFData, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 2000
                  ] as CFDictionary),
                  let bytes = UIImage(cgImage: image).jpegData(compressionQuality: 0.86)
            else { if current == session { failed = true }; return }
            try ProtectedPhotoStorage.save(bytes, owner: owner, id: id, back: backSide)
            if backSide { back = bytes } else { front = bytes }
        } catch { if current == session { failed = true } }
    }
    private func clear() {
        session = UUID(); authorized = false; front = nil; back = nil
        preview = nil; full = false; frontPicker = nil; backPicker = nil
    }
}


// Offline bank directory; no financial information is sent to a logo service.
private struct BankDirectoryEntry: Identifiable {
    let id: String
    let country: String
    let name: String
    let aliases: String
    let tone: WalletTone
    let asset: String?
}
private enum BankDirectory {
    static let entries: [BankDirectoryEntry] = [
        .init(id: "kr-kb", country: "KR", name: "KB국민은행", aliases: "KB 국민은행 Kookmin 国民银行", tone: .midnight, asset: "bank-kr-kb"),
        .init(id: "kr-shinhan", country: "KR", name: "신한은행", aliases: "Shinhan 新韩银行", tone: .cobalt, asset: "bank-kr-shinhan"),
        .init(id: "kr-woori", country: "KR", name: "우리은행", aliases: "Woori 友利银行", tone: .cobalt, asset: "bank-kr-woori"),
        .init(id: "kr-hana", country: "KR", name: "하나은행", aliases: "Hana KEB 韩亚银行", tone: .emerald, asset: "bank-kr-hana"),
        .init(id: "kr-ibk", country: "KR", name: "IBK기업은행", aliases: "IBK 기업은행 Industrial 企业银行", tone: .cobalt, asset: "bank-kr-ibk"),
        .init(id: "kr-sc", country: "KR", name: "SC제일은행", aliases: "SC 제일은행 Standard Chartered 渣打银行", tone: .emerald, asset: "bank-kr-sc"),
        .init(id: "kr-nh", country: "KR", name: "NH농협은행", aliases: "NH Nonghyup 농협 农协", tone: .emerald, asset: "bank-kr-nh"),
        .init(id: "kr-kakao", country: "KR", name: "카카오뱅크", aliases: "KakaoBank", tone: .midnight, asset: "bank-kr-kakao"),
        .init(id: "kr-toss", country: "KR", name: "토스뱅크", aliases: "Toss Bank", tone: .cobalt, asset: "bank-kr-toss"),
        .init(id: "kr-kbank", country: "KR", name: "케이뱅크", aliases: "K Bank", tone: .cobalt, asset: "bank-kr-kbank"),
        .init(id: "kr-kdb", country: "KR", name: "KDB산업은행", aliases: "KDB 산업은행", tone: .cobalt, asset: "bank-kr-kdb"),
        .init(id: "kr-busan", country: "KR", name: "부산은행", aliases: "BNK Busan", tone: .coral, asset: "bank-kr-busan"),
        .init(id: "kr-im", country: "KR", name: "iM뱅크", aliases: "대구은행 Daegu", tone: .cobalt, asset: "bank-kr-im"),
        .init(id: "kr-post", country: "KR", name: "우체국", aliases: "Korea Post", tone: .coral, asset: "bank-kr-post"),
        .init(id: "kr-mg", country: "KR", name: "새마을금고", aliases: "MG", tone: .cobalt, asset: "bank-kr-mg"),
        .init(id: "kr-cu", country: "KR", name: "신협", aliases: "Credit Union", tone: .emerald, asset: "bank-kr-cu"),
        .init(id: "kr-suhyup", country: "KR", name: "Sh수협은행", aliases: "수협 Suhyup", tone: .cobalt, asset: "bank-kr-suhyup"),
        .init(id: "kr-gyeongnam", country: "KR", name: "경남은행", aliases: "BNK Kyongnam", tone: .coral, asset: "bank-kr-gyeongnam"),
        .init(id: "kr-gwangju", country: "KR", name: "광주은행", aliases: "Kwangju", tone: .cobalt, asset: "bank-kr-gwangju"),
        .init(id: "kr-jeonbuk", country: "KR", name: "전북은행", aliases: "Jeonbuk", tone: .cobalt, asset: "bank-kr-jeonbuk"),
        .init(id: "kr-jeju", country: "KR", name: "제주은행", aliases: "Jeju", tone: .cobalt, asset: "bank-kr-jeju"),
        .init(id: "cn-icbc", country: "CN", name: "中国工商银行", aliases: "工商银行 ICBC", tone: .coral, asset: "bank-cn-icbc"),
        .init(id: "cn-ccb", country: "CN", name: "中国建设银行", aliases: "建设银行 CCB", tone: .cobalt, asset: "bank-cn-ccb"),
        .init(id: "cn-abc", country: "CN", name: "中国农业银行", aliases: "农业银行 ABC", tone: .emerald, asset: "bank-cn-abc"),
        .init(id: "cn-boc", country: "CN", name: "中国银行", aliases: "BOC Bank of China", tone: .coral, asset: "bank-cn-boc"),
        .init(id: "cn-bocom", country: "CN", name: "交通银行", aliases: "BOCOM", tone: .cobalt, asset: "bank-cn-bocom"),
        .init(id: "cn-psbc", country: "CN", name: "中国邮政储蓄银行", aliases: "邮储银行 PSBC", tone: .emerald, asset: "bank-cn-psbc"),
        .init(id: "cn-cmb", country: "CN", name: "招商银行", aliases: "CMB", tone: .coral, asset: "bank-cn-cmb"),
        .init(id: "cn-citic", country: "CN", name: "中信银行", aliases: "CITIC", tone: .coral, asset: "bank-cn-citic"),
        .init(id: "cn-spdb", country: "CN", name: "浦发银行", aliases: "上海浦东发展银行 SPDB", tone: .cobalt, asset: "bank-cn-spdb"),
        .init(id: "cn-cib", country: "CN", name: "兴业银行", aliases: "CIB", tone: .cobalt, asset: "bank-cn-cib"),
        .init(id: "cn-cmbc", country: "CN", name: "中国民生银行", aliases: "民生银行 CMBC", tone: .emerald, asset: "bank-cn-cmbc"),
        .init(id: "cn-ceb", country: "CN", name: "中国光大银行", aliases: "光大银行 CEB", tone: .violet, asset: "bank-cn-ceb"),
        .init(id: "cn-pingan", country: "CN", name: "平安银行", aliases: "Ping An", tone: .coral, asset: "bank-cn-pingan"),
        .init(id: "cn-hxb", country: "CN", name: "华夏银行", aliases: "Huaxia", tone: .coral, asset: "bank-cn-hxb"),
        .init(id: "cn-gdb", country: "CN", name: "广发银行", aliases: "CGB", tone: .coral, asset: "bank-cn-gdb"),
        .init(id: "cn-bob", country: "CN", name: "北京银行", aliases: "Bank of Beijing", tone: .coral, asset: "bank-cn-bob"),
        .init(id: "cn-bos", country: "CN", name: "上海银行", aliases: "Bank of Shanghai", tone: .cobalt, asset: "bank-cn-bos"),
        .init(id: "cn-czb", country: "CN", name: "浙商银行", aliases: "CZBank", tone: .coral, asset: "bank-cn-czb"),
        .init(id: "jp-mufg", country: "JP", name: "三菱UFJ銀行", aliases: "MUFG 三菱日联", tone: .coral, asset: "bank-jp-mufg"),
        .init(id: "jp-smbc", country: "JP", name: "三井住友銀行", aliases: "SMBC 三井住友", tone: .emerald, asset: "bank-jp-smbc"),
        .init(id: "jp-mizuho", country: "JP", name: "みずほ銀行", aliases: "Mizuho 瑞穗银行", tone: .cobalt, asset: "bank-jp-mizuho"),
        .init(id: "jp-jppost", country: "JP", name: "ゆうちょ銀行", aliases: "Japan Post Bank 日本邮政", tone: .emerald, asset: "bank-jp-jppost"),
        .init(id: "jp-resona", country: "JP", name: "りそな銀行", aliases: "Resona 理索纳", tone: .emerald, asset: "bank-jp-resona"),
        .init(id: "jp-rakuten", country: "JP", name: "楽天銀行", aliases: "Rakuten 乐天银行", tone: .coral, asset: "bank-jp-rakuten"),
        .init(id: "jp-seven", country: "JP", name: "セブン銀行", aliases: "Seven Bank", tone: .emerald, asset: "bank-jp-seven"),
        .init(id: "jp-paypay", country: "JP", name: "PayPay銀行", aliases: "PayPay Bank", tone: .coral, asset: "bank-jp-paypay"),
        .init(id: "jp-sbi", country: "JP", name: "住信SBIネット銀行", aliases: "SBI Sumishin", tone: .cobalt, asset: "bank-jp-sbi"),
        .init(id: "jp-sony", country: "JP", name: "ソニー銀行", aliases: "Sony Bank", tone: .cobalt, asset: "bank-jp-sony"),
        .init(id: "us-chase", country: "US", name: "Chase", aliases: "JPMorgan Chase 摩根大通", tone: .cobalt, asset: "bank-us-chase"),
        .init(id: "us-boa", country: "US", name: "Bank of America", aliases: "美国银行 BofA", tone: .cobalt, asset: "bank-us-boa"),
        .init(id: "us-wells", country: "US", name: "Wells Fargo", aliases: "富国银行", tone: .coral, asset: "bank-us-wells"),
        .init(id: "us-citi", country: "US", name: "Citibank", aliases: "花旗银行 Citi", tone: .cobalt, asset: "bank-us-citi"),
        .init(id: "us-usbank", country: "US", name: "U.S. Bank", aliases: "US Bank", tone: .cobalt, asset: "bank-us-usbank"),
        .init(id: "us-capitalone", country: "US", name: "Capital One", aliases: "第一资本", tone: .cobalt, asset: "bank-us-capitalone"),
        .init(id: "us-pnc", country: "US", name: "PNC Bank", aliases: "PNC", tone: .coral, asset: "bank-us-pnc"),
        .init(id: "us-truist", country: "US", name: "Truist", aliases: "Truist Bank", tone: .violet, asset: "bank-us-truist"),
        .init(id: "us-td", country: "US", name: "TD Bank", aliases: "Toronto Dominion", tone: .emerald, asset: "bank-us-td"),
        .init(id: "us-amex", country: "US", name: "American Express National Bank", aliases: "AMEX 美国运通", tone: .cobalt, asset: "bank-us-amex"),
        .init(id: "us-bmo", country: "US", name: "BMO Bank", aliases: "BMO", tone: .cobalt, asset: "bank-us-bmo"),
        .init(id: "us-eastwest", country: "US", name: "East West Bank", aliases: "华美银行", tone: .cobalt, asset: "bank-us-eastwest")
    ]
    static func byID(_ id: String) -> BankDirectoryEntry? { entries.first { $0.id == id } }
    static func normalize(_ s: String) -> String {
        s.lowercased().filter { !$0.isWhitespace && !$0.isPunctuation }
    }
    static func resolve(id: String?, name: String) -> BankDirectoryEntry? {
        if let id, let item = byID(id), item.name == name { return item }
        let key = normalize(name)
        guard !key.isEmpty else { return nil }
        return entries.first { normalize($0.name) == key || $0.aliases.split(separator: " ").contains { normalize(String($0)) == key } }
    }
}
private struct BankLogoMark: View {
    let bank: BankDirectoryEntry?
    let tone: WalletTone
    let size: CGFloat
    // Full horizontal bank wordmarks are unreadable if shrunk to a square.
    // Allow additional width only in bank selection rows where text can wrap.
    var showFullWordmark: Bool = false
    private var isHorizontalMark: Bool {
        guard let id = bank?.id else { return false }
        return ["jp-jppost", "jp-rakuten", "jp-sony", "us-truist", "us-pnc"].contains(id)
    }
    private var markWidth: CGFloat {
        showFullWordmark && isHorizontalMark ? size * 1.55 : size
    }
    var body: some View {
        Group {
            if let asset = bank?.asset, UIImage(named: asset) != nil {
                Image(asset)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(size * 0.04)
                    .frame(width: markWidth, height: size)
                    .background(Color.white)
            } else {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: size * 0.38))
                    .foregroundStyle(.white)
                    .frame(width: markWidth, height: size)
                    .background(LinearGradient(colors: tone.gradient,
                                               startPoint: .topLeading,
                                               endPoint: .bottomTrailing))
            }
        }
        .frame(width: markWidth, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.20))
        .accessibilityHidden(true)
    }
}
private struct BankLogoPicker: View {
    @Environment(\.dismiss) private var dismiss
    let selected: String?
    let choose: (BankDirectoryEntry?) -> Void
    @State private var country = "KR"
    @State private var search = ""
    private var countries: [String] { ["KR", "CN", "JP", "US"] }
    private var rows: [BankDirectoryEntry] {
        BankDirectory.entries.filter {
            if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return $0.country == country }
            return ($0.name + " " + $0.aliases + " " + $0.country).localizedCaseInsensitiveContains(search)
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker(L("은행 선택"), selection: $country) {
                        ForEach(countries, id: \.self) { code in
                            Text(AppLocalization.locale.localizedString(forRegionCode: code) ?? code).tag(code)
                        }
                    }.pickerStyle(.segmented)
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField(L("은행 검색"), text: $search)
                        if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain) }
                    }.padding(12).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 166, maximum: 250), spacing: 10)], spacing: 10) {
                        ForEach(rows) { bank in
                            Button {
                                choose(bank); dismiss()
                            } label: {
                                HStack(spacing: 7) {
                                    BankLogoMark(bank: bank, tone: bank.tone, size: 40, showFullWordmark: true)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(bank.name).font(.system(size: 13, weight: .semibold))
                                            .lineLimit(2).minimumScaleFactor(0.7)
                                            .foregroundStyle(.primary)
                                        if bank.asset.flatMap({ UIImage(named: $0) }) == nil { Text(L("등록된 로고 없음")).font(.caption2).foregroundStyle(.secondary) }
                                    }
                                    Spacer(minLength: 0)
                                    if selected == bank.id {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(LedgerTheme.accent).font(.caption)
                                    }
                                }
                                .padding(8).frame(maxWidth: .infinity, minHeight: 56)
                                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected == bank.id ? LedgerTheme.accent : Color.secondary.opacity(0.22), lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                    }
                    Button { choose(nil); dismiss() } label: {
                        Label(L("직접 입력"), systemImage: "plus.circle").frame(maxWidth: .infinity)
                    }.buttonStyle(.bordered)
                }.padding(16).frame(maxWidth: 800).frame(maxWidth: .infinity)
            }
            .background(LedgerTheme.background)
            .navigationTitle(L("은행 선택"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("닫기")) { dismiss() } } }
            .onAppear { if let selected, let bank = BankDirectory.byID(selected) { country = bank.country } }
        }
    }
}
