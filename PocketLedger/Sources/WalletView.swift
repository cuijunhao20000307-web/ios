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
    @State private var showPrivateWallet = false
    @State private var section = 0
    @State private var showCard = false
    @State private var showAccount = false
    @State private var selectedCard: UUID?
    @State private var search = ""
    @AppStorage("walletStacked") private var stacked = true
    @State private var searchVisible = false
    @FocusState private var searchFocused: Bool
    @State private var editAccount: BankAccount?
    @State private var secretShown = false
    @State private var revealedSecret: String?
    @State private var unlockFailed = false

    var body: some View {
        let _ = languageRefresh
        let _ = moneyRefresh
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L("지갑")).font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    if searchVisible {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                            TextField(L("카드 및 은행 검색"), text: $search)
                                .focused($searchFocused)
                            Button {
                                search = ""; searchVisible = false; searchFocused = false
                            } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                            .accessibilityLabel(L("닫기"))
                        }
                        .padding(12)
                        .background(LedgerTheme.panel, in: RoundedRectangle(cornerRadius: 14))
                        .frame(maxWidth: 460)
                        .frame(maxWidth: .infinity)
                    }
                    Picker(L("지갑"), selection: $section) {
                        Text(L("카드 지갑")).tag(0)
                        Text(L("통장 지갑")).tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 390)
                    .frame(maxWidth: .infinity)
                    if section == 0 { cardsContent } else { accountsContent }
                    Button { showPrivateWallet = true } label: {
                        Label(L("개인정보 보관함"), systemImage: "lock.shield")
                            .font(.subheadline.weight(.medium))
                            .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20).padding(.vertical, 16)
                .frame(maxWidth: 920).frame(maxWidth: .infinity)
            }
            .background(LedgerTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { if section == 0 { showCard = true } else { showAccount = true } } label: {
                        Image(systemName: "plus").fontWeight(.semibold)
                    }.accessibilityLabel(L(section == 0 ? "카드 추가" : "통장 추가"))
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { searchVisible.toggle(); if !searchVisible { search = "" } }
                            searchFocused = searchVisible
                        } label: { Label(L("카드 및 은행 검색"), systemImage: "magnifyingglass") }
                        if section == 0 {
                            Button { withAnimation(.easeInOut(duration: 0.25)) { stacked.toggle() } } label: {
                                Label(L(stacked ? "목록 보기" : "겹쳐 보기"), systemImage: stacked ? "square.grid.2x2" : "rectangle.stack")
                            }
                        }
                        Button { showPrivateWallet = true } label: { Label(L("개인정보 보관함"), systemImage: "lock.shield") }
                    } label: { Image(systemName: "ellipsis") }
                }
            }
            .navigationDestination(item: $selectedCard) { id in LedgerCardDetail(cardID: id) }
        }
        .sheet(isPresented: $showPrivateWallet) { PrivateWalletView() }
        .sheet(isPresented: $showCard) { CardForm() }
        .sheet(isPresented: $showAccount) { BankAccountForm() }
        .sheet(item: $editAccount) { BankAccountForm(existing: $0) }
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
                    WalletDeckLayout {
                        ForEach(cards) { card in
                            Button { selectedCard = card.id } label: {
                                LedgerStackCard(card: card, spent: store.spent(on: card, in: .now))
                                    .aspectRatio(1.586, contentMode: .fit)
                                    .contentShape(RoundedRectangle(cornerRadius: 19))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(card.name + " " + L("카드 정보"))
                        }
                    }
                    .frame(maxWidth: 365)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260, maximum: 365), spacing: 16)], spacing: 16) {
                        ForEach(cards) { card in
                            Button { selectedCard = card.id } label: {
                                LedgerStackCard(card: card, spent: store.spent(on: card, in: .now))
                                    .aspectRatio(1.586, contentMode: .fit)
                            }.buttonStyle(.plain)
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
                                Image(systemName: "building.columns.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(LinearGradient(colors: account.tone.gradient, startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 13))
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


private struct LedgerCardBackground: View {
    let card: PaymentCard
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: card.tone.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                if let artwork = card.artwork, let decoded = UIImage(data: artwork) {
                    Image(uiImage: decoded).resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                    (card.artworkTextDark == true ? Color.white : Color.black)
                        .opacity(min(max(card.artworkDim ?? 0.18, 0), 0.65))
                }
            }.clipped()
        }
    }
}
private struct WalletDeckLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = min(proposal.width ?? 365, 365)
        guard !subviews.isEmpty else { return CGSize(width: width, height: 0) }
        let step = max(43, min(58, width * 0.155))
        return CGSize(width: width, height: width / 1.586 + CGFloat(subviews.count - 1) * step)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = min(bounds.width, 365)
        let step = max(43, min(58, width * 0.155))
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

struct LedgerCardDetail: View {
    @Environment(\.appLanguageRevision) private var languageRefresh
    @Environment(\.displayCurrencyRevision) private var moneyRefresh
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.displayCurrencyRevision) private var currencyRevision
    @Environment(\.scenePhase) private var phase
    @Environment(\.dismiss) private var dismiss
    let cardID: UUID
    @State private var record: PrivateRecord?
    @State private var authorized = false
    @State private var revealCVC = false
    @State private var edit = false
    @State private var busy = false
    @State private var error: String?
    @State private var copied = false
    private var card: PaymentCard? { store.data.cards.first { $0.id == cardID } }
    private var accent: Color { Color.teal }

    var body: some View {
        let _ = languageRefresh
        let _ = moneyRefresh
        Group {
            if let card {
                ScrollView {
                    DuoColumns(spacing: 24, minWidth: 620) {
                        VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(card.issuer).font(.headline).foregroundStyle(.secondary)
                            Text(card.name).font(.largeTitle.bold())
                        }
                        LedgerStackCard(card: card, spent: store.spent(on: card, in: .now), record: authorized ? record : nil, showNumber: authorized)
                            .aspectRatio(1.586, contentMode: .fit)
                        HStack {
                            Button {
                                Task { await unlock(copy: false) }
                            } label: {
                                Label(L(authorized ? "정보 잠그기" : "카드번호 보기"), systemImage: authorized ? "lock" : "lock.open")
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                            }.buttonStyle(.bordered).disabled(busy)
                            Button {
                                Task { await unlock(copy: true) }
                            } label: {
                                Label(L(copied ? "복사 완료" : "카드번호 복사"), systemImage: "doc.on.doc")
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                            }.buttonStyle(.borderedProminent).disabled(busy)
                        }.tint(accent)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .leading, spacing: 20) {
                        Text(L("카드 정보")).font(.title2.bold())
                        VStack(spacing: 0) {
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
                        Text(L("이번 달 사용")).font(.title2.bold())
                        Surface {
                            VStack(alignment: .leading, spacing: 9) {
                                Text(store.spent(on: card, in: .now).won).font(.title.bold())
                                if card.spendingLimit > 0 {
                                    Text("월 사용 한도 " + card.spendingLimit.won).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                        if authorized && record == nil {
                            Text("전체 카드 정보가 아직 등록되지 않았습니다. 편집에서 카드번호, 유효기간을 입력하세요.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(20).frame(maxWidth: 920).frame(maxWidth: .infinity)
                }
                .navigationTitle(card.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { clear(); edit = true } label: { Image(systemName: "square.and.pencil") }
                            .accessibilityLabel(L("카드 수정"))
                    }
                }
                .sheet(isPresented: $edit, onDismiss: { if self.card == nil { dismiss() } }) {
                    CardForm(existing: card)
                }
            } else {
                ContentUnavailableView("삭제된 카드", systemImage: "creditcard")
            }
        }
        .onChange(of: phase) { _, p in if p == .background { clear() } }
        .overlay { if phase != .active { Color(uiColor: .systemBackground).ignoresSafeArea() } }
        .onDisappear { clear() }
        .alert(L("확인"), isPresented: Binding(get: {error != nil}, set: {if !$0 {error = nil}})) { Button(L("확인")) {error = nil} } message: { Text(error ?? "") }
    }
    private func badge(_ icon: String) -> some View {
        Image(systemName: icon).foregroundStyle(accent).frame(width: 46, height: 46)
            .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
    }
    private func info(_ name: String, value: String?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L(name)).font(.subheadline).foregroundStyle(.secondary)
            Text(value.flatMap { $0.isEmpty ? nil : $0 } ?? (authorized ? "미등록" : "••••"))
                .font(.headline).privacySensitive()
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 14)
    }
    private func clear() { record = nil; authorized = false; revealCVC = false; copied = false }
    @MainActor private func unlock(copy: Bool) async {
        if authorized && !copy { clear(); return }
        guard !busy else { return }
        busy = true
        defer { busy = false }
        guard await LocalUnlock.authorize(), phase != .background else { return }
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
        defer { busy = false }
        guard await LocalUnlock.authorize(), phase != .background else { return }
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
    @State private var artworkDim = 0.18
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
                        Text(L("원")).foregroundStyle(.secondary)
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
                    artworkDim = min(max(existing.artworkDim ?? 0.18, 0), 0.65); network = existing.network ?? "none"
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
        PaymentCard(id: id, name: name, issuer: issuer, lastFour: effectiveLastFour, tone: tone, spendingLimit: limit.toMoneyInt, artwork: artwork, artworkTextDark: artworkDark, artworkDim: artworkDim, network: networkEdited || existing?.network != nil || existing == nil ? network : nil)
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
    var existing: BankAccount? = nil
    @State private var nickname = ""
    @State private var bank = ""
    @State private var accountNumber = ""
    @State private var balance = ""
    @State private var secret = ""
    @State private var tone: WalletTone = .emerald
    @State private var confirmDelete = false
    @State private var saveError = false

    var body: some View {
        let _ = languageRefresh
        let _ = moneyRefresh
        NavigationStack {
            Form {
                Section(L("통장 정보")) {
                    TextField("통장 별칭 (예: 월급 통장)", text: $nickname)
                    TextField(L("은행명"), text: $bank)
                    TextField(L("계좌번호 · 선택"), text: $accountNumber).keyboardType(.numbersAndPunctuation)
                    HStack {
                        Text(L("기초 잔액 (KRW)"))
                        Spacer()
                        TextField("0", text: $balance).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                        Text(L("원")).foregroundStyle(.secondary)
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
                if existing != nil { Section { Button(L("통장 삭제"), role: .destructive) { confirmDelete = true } } }
            }
            .navigationTitle(L(existing == nil ? "통장 등록" : "통장 수정"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("취소")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("저장")) { save() }
                        .disabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || bank.isEmpty)
                }
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
            .onAppear {
                if let existing {
                    nickname = existing.nickname; bank = existing.bankName; accountNumber = existing.accountNumber
                    balance = String(existing.balance); tone = existing.tone
                }
            }
        }
    }
    private func save() {
        let id = existing?.id ?? UUID()
        if !secret.isEmpty && !SecureVault.save(secret, for: id) { saveError = true; return }
        let account = BankAccount(id: id, nickname: nickname, bankName: bank,
                                  accountNumber: accountNumber, balance: balance.toMoneyInt, tone: tone)
        if let index = store.data.accounts.firstIndex(where: { $0.id == id }) { store.data.accounts[index] = account }
        else { store.data.accounts.append(account) }
        dismiss()
    }
}
