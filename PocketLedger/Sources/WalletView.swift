import SwiftUI

struct WalletView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var section = 0
    @State private var showCard = false
    @State private var showAccount = false
    @State private var editCard: PaymentCard?
    @State private var editAccount: BankAccount?
    @State private var secretShown = false
    @State private var revealedSecret: String?
    @State private var unlockFailed = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("나의 지갑").font(.system(size: 30, weight: .bold))
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

                if section == 0 { cardsContent }
                else { accountsContent }
            }
            .padding(20).padding(.top, 8)
            .frame(maxWidth: 780).frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showCard) { CardForm() }
        .sheet(isPresented: $showAccount) { BankAccountForm() }
        .sheet(item: $editCard) { CardForm(existing: $0) }
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

    private var cardsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(title: "결제 카드", detail: "\(store.data.cards.count)장")
            if store.data.cards.isEmpty {
                Surface { EmptyContent(symbol: "creditcard", title: "등록된 카드가 없어요", subtitle: "오른쪽 위 +를 눌러 카드를 추가해 보세요") }
            } else {
                ForEach(store.data.cards) { card in
                    AnimatedWalletCard(card: card, spent: store.spent(on: card, in: .now)) { editCard = card }
                    if card.spendingLimit > 0 {
                        HStack {
                            Text("월 사용 한도 " + card.spendingLimit.won)
                            Spacer()
                            Text("\(Int(Double(store.spent(on: card, in: .now)) / Double(card.spendingLimit) * 100))% 사용")
                        }
                        .font(.system(size: 12)).foregroundStyle(LedgerTheme.subtext)
                        .padding(.horizontal, 7)
                    }
                }
                Text("카드를 누르면 수정할 수 있어요. 카드 번호는 끝 4자리만 저장합니다.")
                    .font(.system(size: 12)).foregroundStyle(LedgerTheme.subtext)
            }
        }
    }

    private var accountsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "은행 통장", detail: "\(store.data.accounts.count)개")
            if store.data.accounts.isEmpty {
                Surface { EmptyContent(symbol: "building.columns", title: "등록된 통장이 없어요", subtitle: "+ 버튼에서 은행과 잔액을 추가해 보세요") }
            } else {
                ForEach(store.data.accounts) { account in
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

struct CardForm: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss
    var existing: PaymentCard? = nil
    @State private var name = ""
    @State private var issuer = ""
    @State private var lastFour = ""
    @State private var tone: WalletTone = .midnight
    @State private var limit = ""
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section("카드") {
                    TextField("카드 별칭 (예: 생활 카드)", text: $name)
                    TextField("카드사 (예: 현대카드)", text: $issuer)
                    TextField("카드번호 마지막 4자리", text: $lastFour)
                        .keyboardType(.numberPad)
                        .onChange(of: lastFour) { _, value in lastFour = String(value.filter(\.isNumber).prefix(4)) }
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
                Section {
                    Text("보안을 위해 카드번호 전체, 유효기간, CVC는 저장하지 않습니다.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if existing != nil {
                    Section { Button("이 카드 삭제", role: .destructive) { confirmDelete = true } }
                }
            }
            .navigationTitle(existing == nil ? "카드 등록" : "카드 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || issuer.isEmpty || lastFour.count != 4)
                }
            }
            .confirmationDialog("카드를 삭제할까요?", isPresented: $confirmDelete) {
                Button("삭제", role: .destructive) {
                    if let existing { store.data.cards.removeAll { $0.id == existing.id } }
                    dismiss()
                }
            }
            .onAppear {
                if let existing {
                    name = existing.name; issuer = existing.issuer; lastFour = existing.lastFour
                    tone = existing.tone; limit = String(existing.spendingLimit)
                }
            }
        }
    }
    private func save() {
        let card = PaymentCard(id: existing?.id ?? UUID(), name: name, issuer: issuer,
                               lastFour: lastFour, tone: tone, spendingLimit: limit.toMoneyInt)
        if let index = store.data.cards.firstIndex(where: { $0.id == card.id }) { store.data.cards[index] = card }
        else { store.data.cards.append(card) }
        dismiss()
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
        if let index = store.data.accounts.firstIndex(where: { $0.id == account.id }) { store.data.accounts[index] = account }
        else { store.data.accounts.append(account) }
        dismiss()
    }
}
