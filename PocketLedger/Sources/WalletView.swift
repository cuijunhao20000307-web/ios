import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct WalletView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var showPrivateWallet = false
    @State private var section = 0
    @State private var showCard = false
    @State private var showAccount = false
    @State private var selectedCard: UUID?
    @State private var search = ""
    @State private var stacked = true
    @State private var editAccount: BankAccount?
    @State private var secretShown = false
    @State private var revealedSecret: String?
    @State private var unlockFailed = false

    var body: some View {
        NavigationStack {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("지갑").font(.largeTitle.bold())
                        Text("카드와 통장을 한곳에").font(.subheadline).foregroundStyle(LedgerTheme.subtext)
                    }
                    Spacer()
                    Button { section == 0 ? (showCard = true) : (showAccount = true) } label: {
                        Image(systemName: "plus").font(.system(size: 19, weight: .bold))
                            .foregroundStyle(.white).frame(width: 46, height: 46)
                            .background(LedgerTheme.accent, in: Circle())
                    }
                    .accessibilityLabel(section == 0 ? "카드 추가" : "통장 추가")
                }
                Picker("지갑", selection: $section) {
                    Text("카드 지갑").tag(0)
                    Text("통장 지갑").tag(1)
                }.pickerStyle(.segmented)
                if section == 0 { cardsContent } else { accountsContent }
                Surface {
                    Button { showPrivateWallet = true } label: {
                        HStack {
                            Image(systemName: "lock.shield.fill").font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("개인정보 보관함").font(.headline)
                                Text("카드 · 계좌 · 신분증 · 비밀번호 · 구독").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption)
                        }
                    }.buttonStyle(.plain)
                }
            }
            .padding(20).padding(.top, 8)
            .frame(maxWidth: 780).frame(maxWidth: .infinity)
        }
        .background(LedgerTheme.background)
        .searchable(text: $search, prompt: "카드 및 은행 검색")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { withAnimation(.easeInOut(duration: 0.25)) { stacked.toggle() } } label: {
                        Label(stacked ? "목록 보기" : "겹쳐 보기", systemImage: stacked ? "list.bullet" : "rectangle.stack")
                    }
                    Button { showPrivateWallet = true } label: { Label("개인정보 보관함", systemImage: "lock.shield") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .navigationDestination(item: $selectedCard) { id in
            LedgerCardDetail(cardID: id)
        }
        }
        .sheet(isPresented: $showPrivateWallet) { PrivateWalletView() }
        .sheet(isPresented: $showCard) { CardForm() }
        .sheet(isPresented: $showAccount) { BankAccountForm() }
        .sheet(item: $editAccount) { BankAccountForm(existing: $0) }
        .alert("보호된 코드", isPresented: $secretShown) {
            Button("닫기") { revealedSecret = nil }
        } message: {
            Text(revealedSecret ?? "저장된 코드가 없습니다.")
        }
        .alert("인증 실패", isPresented: $unlockFailed) {
            Button("확인", role: .cancel) { }
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
        return VStack(alignment: .leading, spacing: 16) {
            SectionHeading(title: "결제 카드", detail: "\(cards.count)장")
            if cards.isEmpty {
                Surface { EmptyContent(symbol: "creditcard", title: "표시할 카드가 없어요", subtitle: "+ 버튼으로 새 카드를 추가할 수 있어요") }
            } else {
                VStack(spacing: stacked ? -1 : 16) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        let full = !stacked || index == cards.count - 1
                        Button { selectedCard = card.id } label: {
                            if full {
                                LedgerStackCard(card: card, spent: store.spent(on: card, in: .now))
                                    .aspectRatio(1.586, contentMode: .fit)
                            } else {
                                LedgerStackCard(card: card, spent: store.spent(on: card, in: .now))
                                    .aspectRatio(1.586, contentMode: .fit)
                                    .frame(height: 54, alignment: .top)
                                    .clipped()
                                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 19, topTrailingRadius: 19))
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(card.name + " 카드 상세")
                    }
                }
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity)
                Text("카드를 누르면 상세 정보를 확인할 수 있어요. 전체 카드번호와 보안 정보는 기기 인증으로 보호됩니다.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
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
                                Label("비밀코드 보호", systemImage: "lock.shield.fill")
                                    .font(.system(size: 12)).foregroundStyle(LedgerTheme.subtext)
                                Spacer()
                                Button("코드 확인") { Task { await reveal(account) } }
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(LedgerTheme.accent)
                            }
                        }
                    }
                }
                Text("표시 잔액은 직접 입력한 값이며, 은행과 실시간 연동되지 않습니다.")
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

// The ledger keeps only public metadata and the last four digits.
// All complete card details live in the existing protected wallet archive.
struct LedgerStackCard: View {
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
        GeometryReader { geo in
            let pad = max(12, geo.size.width * 0.055)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top) {
                    Text(card.issuer).font(.system(size: 16, weight: .bold)).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(card.name).font(.system(size: 14, weight: .medium)).lineLimit(1).opacity(0.85)
                }
                Spacer(minLength: 6)
                Text(number).font(.system(size: max(14, geo.size.width * 0.049), weight: .semibold, design: .monospaced))
                    .lineLimit(1).minimumScaleFactor(0.65)
                    .privacySensitive()
                Spacer(minLength: 6)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let holder = record?.fields["카드 소유자"], !holder.isEmpty {
                            Text("사용자 이름").font(.caption2).opacity(0.75)
                            Text(holder).font(.subheadline.bold()).lineLimit(1).privacySensitive()
                        } else {
                            Text("이번 달 사용").font(.caption2).opacity(0.75)
                            Text(spent.won).font(.subheadline.bold()).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                    if let expiry = record?.fields["유효기간"], !expiry.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("유효기간").font(.caption2).opacity(0.75)
                            Text(expiry).font(.subheadline.bold()).privacySensitive()
                        }
                    }
                    Spacer(minLength: 4)
                    if let brand = record?.fields["카드 브랜드"], !brand.isEmpty && brand != "기타" {
                        Text(brand).font(.system(size: 14, weight: .black, design: .rounded))
                            .padding(7).foregroundStyle(.black)
                            .background(.white, in: RoundedRectangle(cornerRadius: 5))
                    } else {
                        Image(systemName: "wave.3.right").font(.title3).rotationEffect(.degrees(90))
                    }
                }
            }
            .padding(pad)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    LinearGradient(colors: card.tone.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    Circle().stroke(.white.opacity(0.09), lineWidth: 38)
                        .frame(width: geo.size.width * 0.65)
                        .offset(x: geo.size.width * 0.48, y: -geo.size.width * 0.27)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 19).strokeBorder(.white.opacity(0.19), lineWidth: 1))
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
    @EnvironmentObject private var store: LedgerStore
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
        Group {
            if let card {
                ScrollView {
                    VStack(alignment: .leading, spacing: 23) {
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
                                Label(authorized ? "정보 잠그기" : "카드번호 보기", systemImage: authorized ? "lock" : "lock.open")
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                            }.buttonStyle(.bordered).disabled(busy)
                            Button {
                                Task { await unlock(copy: true) }
                            } label: {
                                Label(copied ? "복사 완료" : "카드번호 복사", systemImage: "doc.on.doc")
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                            }.buttonStyle(.borderedProminent).disabled(busy)
                        }.tint(accent)
                        Text("카드 정보").font(.title2.bold())
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
                            info("카드 브랜드", value: authorized ? record?.fields["카드 브랜드"] : nil)
                        }
                        Text("이번 달 사용").font(.title2.bold())
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
                    .padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
                }
                .navigationTitle(card.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { clear(); edit = true } label: { Image(systemName: "square.and.pencil") }
                            .accessibilityLabel("카드 수정")
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
        .alert("확인", isPresented: Binding(get: {error != nil}, set: {if !$0 {error = nil}})) { Button("확인") {error = nil} } message: { Text(error ?? "") }
    }
    private func badge(_ icon: String) -> some View {
        Image(systemName: icon).foregroundStyle(accent).frame(width: 46, height: 46)
            .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
    }
    private func info(_ name: String, value: String?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(name).font(.subheadline).foregroundStyle(.secondary)
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
    @EnvironmentObject private var store: LedgerStore
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

    private let brands = ["기타", "VISA", "Mastercard", "AMEX", "JCB", "UnionPay", "BC", "Tmoney"]
    private var digits: String { (protectedRecord?.fields["카드번호"] ?? "").filter(\.isNumber) }
    private var effectiveLastFour: String { digits.isEmpty ? lastFour : String(digits.suffix(4)) }
    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !issuer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        effectiveLastFour.count == 4 && (digits.isEmpty || (12...19).contains(digits.count)) &&
        ((protectedRecord?.fields["CVC"] ?? "").isEmpty || (3...4).contains((protectedRecord?.fields["CVC"] ?? "").count))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("카드") {
                    TextField("카드 별칭", text: $name)
                    TextField("카드사", text: $issuer)
                    TextField("카드번호 마지막 4자리", text: $lastFour)
                        .keyboardType(.numberPad)
                        .onChange(of: lastFour) { _, value in lastFour = String(value.filter(\.isNumber).prefix(4)) }
                        .disabled(!digits.isEmpty)
                    Picker("카드 색상", selection: $tone) {
                        ForEach(WalletTone.allCases) { Text($0.rawValue).tag($0) }
                    }
                    HStack {
                        Text("월 사용 한도")
                        Spacer()
                        TextField("선택", text: $limit).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                        Text("원").foregroundStyle(.secondary)
                    }
                }
                Section("전체 카드 정보 · 보호됨") {
                    if protectedRecord == nil {
                        Button { Task { await openProtected() } } label: {
                            Label("기기 인증 후 카드번호 · CVC 등록", systemImage: "lock.shield")
                        }.disabled(busy)
                        Text("기존 보안 정보는 잠긴 상태에서 수정하거나 덮어쓰지 않습니다.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Picker("카드 브랜드", selection: field("카드 브랜드", fallback: "기타")) {
                            ForEach(brands, id: \.self) { Text($0).tag($0) }
                        }
                        Toggle("보안 정보 표시", isOn: $visible)
                        if visible {
                            TextField("전체 카드번호", text: field("카드번호")).keyboardType(.numberPad)
                            TextField("CVC", text: field("CVC")).keyboardType(.numberPad)
                        } else {
                            SecureField("전체 카드번호", text: field("카드번호")).keyboardType(.numberPad)
                            SecureField("CVC", text: field("CVC")).keyboardType(.numberPad)
                        }
                        TextField("사용자 이름", text: field("카드 소유자")).textInputAutocapitalization(.characters)
                        TextField("유효기간 (MM/YY)", text: field("유효기간")).keyboardType(.numbersAndPunctuation)
                        if !digits.isEmpty { Text("카드번호 끝자리: " + effectiveLastFour).font(.caption).foregroundStyle(.secondary) }
                        Text("전체 카드번호 및 CVC는 선택 항목이며 기기 전용 Keychain에 저장됩니다. 실제 CVC 저장은 권장하지 않습니다.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if existing != nil { Section { Button("이 카드 삭제", role: .destructive) { confirmDelete = true } } }
            }
            .navigationTitle(existing == nil ? "카드 등록" : "카드 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장") { save() }.disabled(!valid || busy) }
            }
            .confirmationDialog("카드를 삭제할까요?", isPresented: $confirmDelete) {
                Button("삭제", role: .destructive) { Task { await delete() } }
            } message: { Text("연결된 보안 정보는 인증 후 보관함 휴지통으로 이동합니다.") }
            .onAppear {
                if let existing {
                    id = existing.id; name = existing.name; issuer = existing.issuer; lastFour = existing.lastFour
                    tone = existing.tone; limit = String(existing.spendingLimit)
                }
            }
            .onChange(of: phase) { _, p in
                if p != .active { visible = false }
                if p == .background { protectedRecord = nil; dismiss() }
            }
            .overlay { if phase != .active { Color(uiColor: .systemBackground).ignoresSafeArea() } }
            .alert("확인", isPresented: Binding(get: {error != nil}, set: {if !$0 {error = nil}})) { Button("확인") {error = nil} } message: { Text(error ?? "") }
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
        do { protectedRecord = LinkedCardVault.draft(for: draftCard(), archive: try PrivateStorage.load()) }
        catch { self.error = error.localizedDescription }
    }
    private func draftCard() -> PaymentCard {
        PaymentCard(id: id, name: name, issuer: issuer, lastFour: effectiveLastFour, tone: tone, spendingLimit: limit.toMoneyInt)
    }
    private func save() {
        guard valid else { return }
        let card = draftCard()
        if var record = protectedRecord {
            record.title = name; record.link = id; record.fields["카드사"] = issuer
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
    @EnvironmentObject private var store: LedgerStore
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
        NavigationStack {
            Form {
                Section("통장 정보") {
                    TextField("통장 별칭 (예: 월급 통장)", text: $nickname)
                    TextField("은행명", text: $bank)
                    TextField("계좌번호 · 선택", text: $accountNumber).keyboardType(.numbersAndPunctuation)
                    HStack {
                        Text("현재 잔액")
                        Spacer()
                        TextField("0", text: $balance).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                        Text("원").foregroundStyle(.secondary)
                    }
                    Picker("색상", selection: $tone) {
                        ForEach(WalletTone.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Section("비밀코드 · 선택") {
                    SecureField(existing == nil ? "새 비밀코드 입력" : "변경할 비밀코드 (비우면 유지)", text: $secret)
                        .textContentType(.password)
                    Text("비밀코드는 이 기기의 iOS 키체인에 따로 보관합니다. 조회할 때 기기 인증이 필요해요. 은행 로그인 비밀번호 저장은 권장하지 않습니다.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if existing != nil { Section { Button("통장 삭제", role: .destructive) { confirmDelete = true } } }
            }
            .navigationTitle(existing == nil ? "통장 등록" : "통장 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || bank.isEmpty)
                }
            }
            .alert("키체인 저장 실패", isPresented: $saveError) {
                Button("확인", role: .cancel) { }
            } message: { Text("비밀코드를 안전하게 저장하지 못했습니다. 기기 잠금 설정을 확인하고 다시 시도하세요.") }
            .confirmationDialog("이 통장을 삭제할까요?", isPresented: $confirmDelete) {
                Button("삭제", role: .destructive) {
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
