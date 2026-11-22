import Foundation
import SwiftUI

enum WalletTab: String, CaseIterable, Identifiable {
    case home = "홈"
    case history = "내역"
    case wallet = "지갑"
    case analytics = "분석"
    case recurring = "자동"
    case settings = "설정"
    case newTransaction = "거래 추가"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .history: "chart.bar.xaxis"
        case .wallet: "wallet.bifold.fill"
        case .analytics: "chart.bar.fill"
        case .recurring: "calendar.badge.clock"
        case .settings: "gearshape.fill"
        case .newTransaction: "plus.circle.fill"
        }
    }
}

enum DockPlacement: String, Codable, CaseIterable, Identifiable {
    case automatic = "자동 감지"
    case bottom = "하단 (일반 iPhone)"
    case right = "오른쪽 (Duo)"
    var id: String { rawValue }
}

enum MoneyKind: String, Codable, CaseIterable, Identifiable {
    case expense = "지출"
    case income = "수입"
    var id: String { rawValue }
}

enum MoneyCategory: String, Codable, CaseIterable, Identifiable {
    case food = "식비"
    case shopping = "쇼핑"
    case transit = "교통"
    case housing = "주거"
    case bills = "공과금"
    case health = "건강"
    case leisure = "여가"
    case salary = "급여"
    case transfer = "이체"
    case other = "기타"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .food: "fork.knife"
        case .shopping: "bag.fill"
        case .transit: "tram.fill"
        case .housing: "house.fill"
        case .bills: "bolt.fill"
        case .health: "cross.case.fill"
        case .leisure: "gamecontroller.fill"
        case .salary: "banknote.fill"
        case .transfer: "arrow.left.arrow.right"
        case .other: "square.grid.2x2.fill"
        }
    }
    var color: Color {
        switch self {
        case .food: .orange
        case .shopping: .pink
        case .transit: .blue
        case .housing: .indigo
        case .bills: .yellow
        case .health: .green
        case .leisure: .purple
        case .salary: .mint
        case .transfer: .cyan
        case .other: .gray
        }
    }
}

enum WalletTone: String, Codable, CaseIterable, Identifiable {
    case midnight = "미드나이트"
    case cobalt = "코발트"
    case violet = "바이올렛"
    case coral = "코랄"
    case emerald = "에메랄드"
    var id: String { rawValue }
    var gradient: [Color] {
        switch self {
        case .midnight: [Color(red: 0.12, green: 0.15, blue: 0.23), Color(red: 0.27, green: 0.31, blue: 0.42)]
        case .cobalt: [Color(red: 0.13, green: 0.32, blue: 0.82), Color(red: 0.12, green: 0.69, blue: 0.88)]
        case .violet: [Color(red: 0.43, green: 0.22, blue: 0.84), Color(red: 0.77, green: 0.40, blue: 0.81)]
        case .coral: [Color(red: 0.90, green: 0.31, blue: 0.41), Color(red: 1.00, green: 0.57, blue: 0.42)]
        case .emerald: [Color(red: 0.05, green: 0.53, blue: 0.49), Color(red: 0.21, green: 0.74, blue: 0.61)]
        }
    }
}

struct PaymentCard: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var issuer: String
    var lastFour: String
    var tone: WalletTone
    var spendingLimit: Int
    // Optional fields preserve decoding of legacy cards.
    var artwork: Data? = nil
    var artworkTextDark: Bool? = nil
    var artworkDim: Double? = nil
    var artworkShowNetwork: Bool? = nil
    var network: String? = nil
}

struct BankAccount: Codable, Identifiable, Equatable {
    var id = UUID()
    var nickname: String
    var bankName: String
    var accountNumber: String
    var balance: Int
    var tone: WalletTone
    var bankLogoID: String? = nil
}

struct MoneyEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var amount: Int
    var kind: MoneyKind
    var category: MoneyCategory
    var date: Date
    var sourceId: UUID?
}

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system = "시스템 설정", light = "라이트", dark = "다크"
    var id: String { rawValue }
    var colorScheme: ColorScheme? { self == .system ? nil : (self == .dark ? .dark : .light) }
}

struct RecurringRule: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var amount: Int
    var kind: MoneyKind
    var category: MoneyCategory
    var day: Int
    var sourceId: UUID?
    var startDate: Date
    var enabled: Bool = true
}

struct LedgerData: Codable {
    var cards: [PaymentCard] = []
    var accounts: [BankAccount] = []
    var entries: [MoneyEntry] = []
    var monthlyBudget = 1_500_000
    var dockPlacement: DockPlacement = .automatic
    var appLockEnabled = false
    var isSample = false
    var appearance: AppearanceMode = .system
    var recurringRules: [RecurringRule] = []

    enum CodingKeys: String, CodingKey { case cards, accounts, entries, monthlyBudget, dockPlacement, appLockEnabled, isSample, appearance, recurringRules }
    init(cards: [PaymentCard] = [], accounts: [BankAccount] = [], entries: [MoneyEntry] = [], monthlyBudget: Int = 1_500_000, dockPlacement: DockPlacement = .automatic, appLockEnabled: Bool = false, isSample: Bool = false, appearance: AppearanceMode = .system, recurringRules: [RecurringRule] = []) {
        self.cards = cards; self.accounts = accounts; self.entries = entries; self.monthlyBudget = monthlyBudget
        self.dockPlacement = dockPlacement; self.appLockEnabled = appLockEnabled; self.isSample = isSample
        self.appearance = appearance; self.recurringRules = recurringRules
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cards = try c.decodeIfPresent([PaymentCard].self, forKey: .cards) ?? []
        accounts = try c.decodeIfPresent([BankAccount].self, forKey: .accounts) ?? []
        entries = try c.decodeIfPresent([MoneyEntry].self, forKey: .entries) ?? []
        monthlyBudget = try c.decodeIfPresent(Int.self, forKey: .monthlyBudget) ?? 1_500_000
        dockPlacement = try c.decodeIfPresent(DockPlacement.self, forKey: .dockPlacement) ?? .automatic
        appLockEnabled = try c.decodeIfPresent(Bool.self, forKey: .appLockEnabled) ?? false
        isSample = try c.decodeIfPresent(Bool.self, forKey: .isSample) ?? false
        appearance = try c.decodeIfPresent(AppearanceMode.self, forKey: .appearance) ?? .system
        recurringRules = try c.decodeIfPresent([RecurringRule].self, forKey: .recurringRules) ?? []
    }
}

enum DisplayCurrency: String, CaseIterable, Identifiable {
    case KRW, CNY, JPY, USD, EUR, GBP, HKD, TWD, SGD, CAD, AUD, CHF, THB, INR, VND
    var id: String { rawValue }
    static var selected: DisplayCurrency {
        DisplayCurrency(rawValue: UserDefaults.standard.string(forKey: "displayCurrency") ?? "KRW") ?? .KRW
    }
    var symbol: String {
        switch self {
        case .KRW: "₩"
        case .CNY, .JPY: "¥"
        case .USD: "$"
        case .EUR: "€"
        case .GBP: "£"
        case .HKD: "HK$"
        case .TWD: "NT$"
        case .SGD: "S$"
        case .CAD: "CA$"
        case .AUD: "A$"
        case .CHF: "CHF "
        case .THB: "฿"
        case .INR: "₹"
        case .VND: "₫"
        }
    }
    var formattedName: String {
        rawValue + " · " + symbol + " · " + (AppLocalization.locale.localizedString(forCurrencyCode: rawValue) ?? rawValue)
    }
    static func format(_ amount: Int) -> String {
        // Display preference only: the ledger's integer values are untouched.
        let formatter = NumberFormatter()
        formatter.locale = AppLocalization.locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        let digits = formatter.string(from: NSNumber(value: amount.magnitude)) ?? String(amount.magnitude)
        return (amount < 0 ? "−" : "") + selected.symbol + digits
    }
}

extension Int {
    var won: String { DisplayCurrency.format(self) }
}

extension Date {
    func monthInterval() -> DateInterval? { Calendar.current.dateInterval(of: .month, for: self) }
    var koreanMonthTitle: String { formatted(.dateTime.year().month(.wide).locale(AppLocalization.locale)) }
}

extension String {
    var lastFourMasked: String {
        let clean = self.filter(\.isNumber)
        return clean.isEmpty ? "미등록" : "•••• " + String(clean.suffix(4))
    }
    var toMoneyInt: Int { Int(filter(\.isNumber)) ?? 0 }
}

private struct DisplayCurrencyRevisionKey: EnvironmentKey {
    static let defaultValue = "KRW0"
}
extension EnvironmentValues {
    var displayCurrencyRevision: String {
        get { self[DisplayCurrencyRevisionKey.self] }
        set { self[DisplayCurrencyRevisionKey.self] = newValue }
    }
}

enum AppLocalization {
    static let options: [(String, String)] = [
        ("system", "시스템 언어"), ("ko", "한국어"), ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁體中文"), ("ja", "日本語"), ("en", "English"),
        ("es", "Español"), ("fr", "Français"), ("de", "Deutsch")
    ]
    static var code: String {
        let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        if saved != "system" { return saved }
        let preferred = Locale.preferredLanguages.first ?? "ko"
        if preferred.hasPrefix("zh") {
            return preferred.contains("Hant") || preferred.contains("-TW") || preferred.contains("-HK") ? "zh-Hant" : "zh-Hans"
        }
        let prefix = String(preferred.prefix(2))
        return ["ko", "ja", "en", "es", "fr", "de"].contains(prefix) ? prefix : "en"
    }
    static var locale: Locale { Locale(identifier: code) }
    static let table: [String: [String]] = [
        "저장 완료": ["Saved","已保存","已儲存","保存しました","Guardado","Enregistré","Gespeichert"],
        "이 앱은 개인 기록용 가계부 프로토타입입니다. 실제 결제 또는 은행 로그인 기능을 제공하지 않습니다.": ["This is a personal ledger prototype. It cannot process actual payments or sign in to banks.","本应用是个人记账原型，不提供实际支付或银行登录。","本應用是個人記帳原型，不提供實際支付或銀行登入。","個人用の家計簿アプリです。実際の決済や銀行ログインには対応しません。"],
        "iPhone Duo에서는 시스템이 화면 자세와 상태 표시줄에 맞춰 메뉴를 배치합니다. 일반 iPhone에서는 하단 탭 막대를 사용합니다. 공간이 부족하면 일부 메뉴는 더 보기로 이동할 수 있습니다.": ["On iPhone Duo, menu placement follows screen posture and status-bar space. Other iPhones use a bottom tab bar. Some items can move to More if space is limited.","在 iPhone Duo 上，系统根据折叠状态和状态栏调整菜单位置。普通 iPhone 使用底部标签栏；空间不足时部分菜单可能移入“更多”。","在 iPhone Duo 上，系統依折疊狀態及狀態列調整選單位置。一般 iPhone 使用底部標籤列；空間不足時部分選單可能移至「更多」。","iPhone Duoでは画面の姿勢とステータスバーに合わせてメニューを配置します。通常のiPhoneでは下部タブを使用します。","En iPhone Duo, el sistema adapta la barra a la pantalla. En otros iPhone usa pestañas inferiores.","Sur iPhone Duo, les menus s'adaptent à l'écran; sur iPhone classique, la barre d'onglets est en bas.","Auf dem iPhone Duo folgt das Menü der Displayhaltung; andere iPhones nutzen untere Tabs."],
        "배치 설명": ["Layout explanation","布局说明","佈局說明","配置の説明","Descripción del diseño","Explication de la disposition","Layoutbeschreibung"],
        "모두 삭제": ["Delete all","全部删除","全部刪除","すべて削除","Eliminar todo","Tout supprimer","Alles löschen"],
        "예시 데이터로 교체": ["Replace with sample","替换为示例数据","替換為範例資料","サンプルに置き換える","Reemplazar por ejemplo","Remplacer par un exemple","Durch Beispieldaten ersetzen"],
        "거래·카드·통장과 관련 은행 보안 정보가 영구 삭제됩니다. 개인정보 보관함은 유지됩니다. 이 작업은 되돌릴 수 없습니다.": ["Transactions, cards, bank accounts and related security details will be permanently deleted. The private vault is preserved. This cannot be undone.","交易、银行卡、银行账户及相关银行安全资料将永久删除。个人信息保险库会保留，此操作无法撤销。","交易、銀行卡、銀行帳戶及相關銀行安全資料將永久刪除。個人資訊保險庫會保留，此操作無法復原。","取引、カード、口座と関連するセキュリティ情報は完全に削除されます。個人情報保管庫は保持されます。元に戻せません。"],
        "기존 거래·카드·통장과 은행 보안 정보가 삭제되고 예시 데이터로 교체됩니다. 개인정보 보관함은 유지됩니다.": ["Existing transactions, cards, bank accounts and associated bank security details will be deleted and replaced with sample data. The private vault is preserved.","现有交易、银行卡、银行账户和相关银行安全资料将删除并替换为示例数据。个人信息保险库会保留。","現有交易、銀行卡、銀行帳戶及相關銀行安全資料將刪除並替換為範例資料。個人資訊保險庫會保留。","既存の取引、カード、口座および関連する銀行のセキュリティ情報は削除され、サンプルデータに置き換わります。個人情報保管庫は保持されます。"],
        "모든 가계부 데이터를 삭제할까요?": ["Delete all ledger data?","删除全部账本数据？","刪除全部帳本資料？","家計簿のすべてのデータを削除しますか？","¿Eliminar todos los datos?","Supprimer toutes les données ?","Alle Haushaltsbuchdaten löschen?"],
        "현재 데이터를 예시 데이터로 바꿀까요?": ["Replace current data with sample data?","将当前数据替换为示例数据？","將目前資料替換為範例資料？","現在のデータをサンプルデータに置き換えますか？","¿Sustituir los datos por ejemplos?","Remplacer les données par un exemple ?","Daten durch Beispieldaten ersetzen?"],
        "단축어 앱 → 자동화 → + → 거래(Transaction) → 카드 선택 → 즉시 실행 → Digital Wallet의 Record Wallet Payment 동작 추가. 결제 금액·가맹점을 변수로 연결하고 저장하세요.": ["Shortcuts → Automation → + → Transaction → select cards → Run Immediately → add Digital Wallet's Record Wallet Payment action. Pass amount and merchant from transaction variables and save.","快捷指令 → 自动化 → + → 交易 → 选择卡片 → 立即运行 → 添加 Digital Wallet 的 Record Wallet Payment 动作，将交易金额与商户变量对应后保存。","捷徑 → 自動化 → + → 交易 → 選擇卡片 → 立即執行 → 加入 Digital Wallet 的 Record Wallet Payment 動作，連結金額與商家變數後儲存。","ショートカット→オートメーション→取引→カードを選択→すぐに実行→Digital Walletの「Record Wallet Payment」アクションを追加し、金額と加盟店の変数を設定して保存してください。"],
        "연동 절차 복사": ["Copy setup instructions","复制设置步骤","複製設定步驟","設定手順をコピー"],
        "Apple Pay 바로가기 설정": ["Set up Apple Pay Shortcut","设置 Apple Pay 快捷指令","設定 Apple Pay 捷徑","Apple Payショートカットを設定"],
        "iCloud 백업 · 복원": ["iCloud Backup & Restore","iCloud 备份与恢复","iCloud 備份與恢復","iCloud バックアップと復元","Copia iCloud y restauración","Sauvegarde et restauration iCloud","iCloud-Sicherung und Wiederherstellung"],
        "한중일 문자 입력이 안 되면 내용 표시를 켜서 입력한 뒤 다시 잠그세요.": ["If secure input blocks CJK characters, enable Show Content to type them, then hide them again.","如果隐藏输入时无法输入中日韩文字，请先开启“显示内容”输入，完成后再关闭。","若隱藏輸入時無法輸入中日韓文字，請先開啟「顯示內容」輸入，再關閉。","保護入力で文字を打てないときは「内容を表示」で入力後、再び隠してください。"],
        "키보드의 지구본 버튼으로도 언어를 전환할 수 있어요.": ["You can also switch languages using the keyboard globe key.","也可以通过键盘上的地球图标切换语言。","也可透過鍵盤上的地球圖示切換語言。","キーボードの地球儀キーでも言語を変更できます。"],
        "선택한 키보드가 없어요. iPhone 설정 → 일반 → 키보드 → 키보드 → 새로운 키보드 추가에서 설치하세요.": ["The selected keyboard is not installed. Add it in iPhone Settings > General > Keyboard > Keyboards > Add New Keyboard.","未安装所选键盘。前往 iPhone 设置 → 通用 → 键盘 → 键盘 → 添加新键盘。","未安裝所選鍵盤。前往 iPhone 設定 → 一般 → 鍵盤 → 鍵盤 → 加入新鍵盤。","キーボードが未設定です。iPhoneの設定 → 一般 → キーボード → 新しいキーボードを追加。"],
        "시스템 키보드": ["System keyboard","系统键盘","系統鍵盤","システムキーボード","Teclado del sistema","Clavier système","Systemtastatur"],
        "키보드 언어": ["Keyboard language","键盘语言","鍵盤語言","キーボードの言語","Idioma del teclado","Langue du clavier","Tastatursprache"],
        "이 카드로 기록된 이번 달 지출이 없습니다.": ["No spending recorded for this card this month.","这张银行卡本月暂无消费记录。","這張銀行卡本月暫無消費紀錄。","今月、このカードの支出記録はありません。","No hay gastos con esta tarjeta este mes.","Aucune dépense enregistrée ce mois-ci pour cette carte.","Keine Ausgaben für diese Karte in diesem Monat."],
        "카드 소비 내역": ["Card spending details","银行卡消费明细","銀行卡消費明細","カード利用明細","Gastos de tarjeta","Dépenses de carte","Kartenausgaben"],
        "커버 파일을 확인하세요": ["Check cover files","请检查封面文件","請檢查封面檔案","画像ファイルを確認してください","Comprueba los archivos","Vérifiez les fichiers","Dateien prüfen"],
        "커버 PNG 가져오기": ["Import cover PNGs","导入封面PNG","匯入封面PNG","PNGを取り込む","Importar PNG","Importer PNG","PNG importieren"],
        "커버 미등록": ["No cover installed","未导入封面","未匯入封面","カバー未登録","Sin portada","Sans couverture","Kein Cover"],
        "KRW · CNY · JPY · USD 커버를 한 번 가져오면 통화 선택에 맞춰 자동으로 표시됩니다.": ["Import KRW, CNY, JPY and USD covers once; they switch automatically with the currency.","一次导入韩元、人民币、日元、美元封面，选择币种后自动切换。","一次匯入韓元、人民幣、日圓、美元封面，選擇幣種後自動切換。","KRW・CNY・JPY・USDの画像を取り込むと通貨に合わせて自動切替します。","Importa las cuatro portadas una vez.","Importez les quatre couvertures une fois.","Vier Cover einmal importieren."],
        "통화별 잔액 커버": ["Currency balance covers","币种余额封面","幣種餘額封面","通貨別残高カバー","Portadas por moneda","Couvertures par devise","Währungscover"],
        "등록된 로고 없음": ["Logo unavailable","暂无标志","暫無標誌","ロゴなし","Sin logo","Sans logo","Kein Logo"],
        "은행 로고": ["Bank logo","银行标志","銀行標誌","銀行ロゴ","Logo bancario","Logo bancaire","Banklogo"],
        "직접 입력": ["Enter manually","自定义银行","自訂銀行","手動入力","Entrada manual","Saisie manuelle","Manuell eingeben"],
        "은행 검색": ["Search banks","搜索银行","搜尋銀行","銀行を検索","Buscar bancos","Rechercher une banque","Bank suchen"],
        "은행 선택": ["Select bank","选择银行","選擇銀行","銀行を選択","Elegir banco","Choisir une banque","Bank auswählen"],
        "기초 잔액": ["Opening balance","期初余额","期初餘額","期首残高"],
        "알림 설정을 확인하세요": ["Check notification settings","请检查通知权限","請檢查通知權限","通知設定を確認してください"],
        "가져오기 완료": ["Import complete","导入完成","匯入完成","取込完了"],
        "CSV 파일을 확인하세요": ["Check the CSV format","请检查CSV文件格式","請檢查CSV檔案格式","CSV形式を確認してください"],
        "확인 후 가져오기": ["Confirm import","确认导入","確認匯入","確認して取り込む"],
        "제외": ["Skipped","已跳过","已略過","除外"],
        "중복": ["Duplicates","重复","重複","重複"],
        "새 거래": ["New transactions","新交易","新交易","新規取引"],
        "가져오기 미리보기": ["Import preview","导入预览","匯入預覽","取込プレビュー"],
        "UTF-8 CSV 형식으로 가져오세요. 취소·미완료·소수 금액은 제외하며 실제 결제 통화는 변환하지 않습니다.": ["Use UTF-8 CSV. Cancelled, incomplete and fractional amounts are skipped; no FX conversion.","请使用UTF-8 CSV。跳过取消、未完成及非整数金额，不做汇率换算。","使用UTF-8 CSV，略過取消、未完成及非整數金額，不換算。","UTF-8 CSVを使用。取消・未完了・小数金額は除外し、換算しません。"],
        "CSV 가져오기": ["Import CSV","导入CSV","匯入CSV","CSVを取り込む","Importar CSV","Importer CSV","CSV importieren"],
        "결제 내역 가져오기": ["Import payments","导入支付账单","匯入支付帳單","決済履歴を取り込む","Importar pagos","Importer paiements","Zahlungen importieren"],
        "카드 결제 전체 내역을 직접 조회하지 않습니다. 입력값은 변환하지 않습니다.": ["No direct card history access or exchange conversion.","不直接读取全部卡片记录，不换算输入金额。","不直接讀取全部卡片紀錄，不換算金額。","カード履歴の直接取得・換算は行いません。"],
        "단축어 앱의 거래 자동화에서 Digital Wallet 결제 기록 동작을 추가하세요. 금액과 가맹점, 가능하면 거래 날짜 및 고유 ID를 전달합니다.": ["In Shortcuts, add Record Wallet Payment to a Transaction automation. Pass amount, merchant, date and unique ID when available.","在快捷指令的交易自动化中添加 Record Wallet Payment，传入金额、商户及可用的交易日期和唯一ID。","在捷徑交易自動化加入 Record Wallet Payment，傳入金額、商戶及可用的日期與ID。","取引オートメーションに Record Wallet Payment を追加し、金額・店名・日時・IDを渡します。"],
        "자동 은행 조회 없이 단축어 및 CSV 가져오기를 사용합니다.": ["Use Shortcuts and CSV imports, not live bank access.","使用快捷指令和CSV导入，不实时读取银行。","使用捷徑及CSV匯入，不即時讀取銀行。","ショートカットとCSV取込を使用します。","Atajos e importación CSV.","Raccourcis et import CSV.","Kurzbefehle und CSV-Import."],
        "결제 연동": ["Payment integration","支付联动","支付連動","決済連携","Conectar pagos","Intégration paiements","Zahlungsintegration"],
        "건": ["transactions","笔","筆","件","operaciones","opérations","Buchungen"],
        "결산 이미지 만들기": ["Create summary image","生成总结图片","產生總結圖片","レポート画像を作成","Crear imagen","Créer une image","Bild erstellen"],
        "결산 이미지 공유": ["Share summary image","分享总结图片","分享總結圖片","レポート画像を共有","Compartir imagen","Partager l’image","Bild teilen"],
        "현재 설정된 예산 기준": ["Based on current budget setting","按当前预算设置计算","按目前預算計算","現在の予算設定に基づく","Según presupuesto actual","Selon le budget actuel","Aktuelles Budget"],
        "월간 순수입": ["Net income","本月结余","本月結餘","月間収支","Saldo mensual","Solde mensuel","Monatssaldo"],
        "지난달 결산이 준비되었습니다.": ["Your previous month's summary is ready to view.","上月消费总结可以查看了。","上月消費總結可以查看了。","先月のレポートを確認できます。","Tu resumen está listo.","Votre bilan est disponible.","Ihre Monatsübersicht ist verfügbar."],
        "월간 결산 보기": ["View monthly summaries","查看月度总结","查看月度總結","月次レポートを見る","Ver resúmenes","Voir les bilans","Monatsübersichten"],
        "매월 1일 자정 알림": ["Midnight reminder on the first","每月1日零点通知","每月1日零點通知","毎月1日午前0時に通知","Aviso el día 1","Rappel le 1er à minuit","Erinnerung am Monatsersten"],
        "월간 결산 자동 표시": ["Show monthly summary","自动显示月度总结","自動顯示月度總結","月次レポートを自動表示","Mostrar resumen mensual","Afficher le bilan mensuel","Monatsübersicht anzeigen"],
        "월간 결산": ["Monthly summary","月度总结","月度總結","月次レポート","Resumen mensual","Bilan mensuel","Monatsübersicht"],
        "통화 기호만 변경하며 금액은 변환하지 않습니다.": ["Only the currency symbol changes; no conversion.","仅切换货币符号，不进行金额换算。","僅切換貨幣符號，不換算金額。","通貨記号のみ変更します。換算はしません。","Solo cambia el símbolo.","Seul le symbole change.","Nur das Symbol ändert sich."],
        "이름을 먼저 입력하세요.": ["Enter a name first.","请先填写名称。","請先填寫名稱。","先に名前を入力してください。"],
        "사진 삭제": ["Delete photo","删除照片","刪除照片","写真を削除","Eliminar foto","Supprimer la photo","Foto löschen"],
        "뒷면 사진": ["Back photo","背面照片","背面照片","裏面の写真","Foto posterior","Photo verso","Rückseite"],
        "앞면 사진": ["Front photo","正面照片","正面照片","表面の写真","Foto frontal","Photo recto","Vorderseite"],
        "앞면 · 뒷면 사진": ["Front and back photos","正面与背面照片","正面與背面照片","表面・裏面の写真","Fotos de ambas caras","Photos recto verso","Vorder- und Rückseite"],
        "사진": ["Photos","照片","照片","写真","Fotos","Photos","Fotos"],
        "여권 추가": ["Add passport","添加护照","新增護照","パスポートを追加","Añadir pasaporte","Ajouter un passeport","Reisepass hinzufügen"],
        "신분증 추가": ["Add ID card","添加身份证","新增身分證","身分証を追加","Añadir documento","Ajouter une carte d’identité","Ausweis hinzufügen"],
        "신분증 · 여권": ["ID card · Passport","身份证 · 护照","身分證 · 護照","身分証・パスポート","Identidad · Pasaporte","Identité · Passeport","Ausweis · Reisepass"],
        "신분증": ["ID card","身份证","身分證","身分証","Documento de identidad","Carte d’identité","Personalausweis"],
        "기기 인증 후 웹사이트 정보 수정": ["Authenticate to edit website details","验证设备后编辑网站资料","驗證裝置後編輯網站資料","端末認証後にウェブ情報を編集","Autenticar para editar","Authentifier pour modifier","Zum Bearbeiten authentifizieren"],
        "메모": ["Memo","备注","備註","メモ","Nota","Note","Notiz"],
        "웹사이트 비밀번호": ["Website password","网站密码","網站密碼","ウェブサイトのパスワード","Contraseña web","Mot de passe web","Web-Passwort"],
        "웹사이트 ID": ["Website ID","网站账号","網站帳號","ウェブサイトID","Usuario web","Identifiant web","Web-Benutzername"],
        "웹사이트 계정": ["Website account","网站账户","網站帳戶","ウェブサイトのアカウント","Cuenta web","Compte web","Webkonto"],
        "보안 저장 실패": ["Secure storage failed","安全存储失败","安全儲存失敗","安全な保存に失敗"],
        "조회 초기화": ["Clear lookup","清空查询","清除查詢","照会をクリア"],
        "뒤 두 자리": ["Last two digits","后两位","後兩位","末尾2桁"],
        "앞 두 자리": ["First two digits","前两位","前兩位","先頭2桁"],
        "보안카드 조회": ["Security card lookup","安全卡查询","安全卡查詢","セキュリティカード照会"],
        "보안카드 삭제": ["Delete security card","删除安全卡","刪除安全卡","セキュリティカード削除"],
        "이 기기에만 저장 · 백업 및 동기화 제외": ["Device only · No backup or sync","仅本机保存，不备份或同步","僅本機儲存，不備份或同步","端末のみ保存・同期なし"],
        "개수를 줄이면 마지막 코드가 삭제됩니다.": ["Reducing the count removes the last codes when saved.","减少数量并保存后会删除末尾代码。","減少數量並儲存後會刪除末尾代碼。","件数を減らして保存すると末尾のコードが削除されます。"],
        "뒤로": ["Back","返回","返回","戻る"],
        "완료": ["Done","完成","完成","完了"],
        "코드 입력": ["Enter codes","录入代码","輸入代碼","コード入力"],
        "세로": ["Down","纵向","縱向","縦"],
        "가로": ["Across","横向","橫向","横"],
        "방향": ["Direction","排列方向","排列方向","方向"],
        "개수": ["Count","数量","數量","件数"],
        "통장 저장 후 등록하세요.": ["Save the account first.","请先保存账户。","請先儲存帳戶。","先に口座を保存してください。"],
        "보안카드 등록 · 수정": ["Add/edit security card","登记或编辑安全卡","登記或編輯安全卡","セキュリティカード登録・編集"],
        "개인정보": ["Personal info", "个人信息", "個人資訊", "個人情報", "Datos personales", "Informations personnelles", "Persönliche Daten"],
        "뒤로 이동": ["Move backward","向后移动","向後移動","奥に移動"],
        "앞으로 이동": ["Move forward","向前移动","向前移動","手前に移動"],
        "카드를 길게 눌러 순서를 변경할 수 있어요": ["Hold a card to rearrange it","长按卡片可拖动排序","長按卡片可拖動排序","長押しでカードを並べ替え"],
        "카드 선택": ["Select card","选择卡片","選擇卡片","カードを選択"],
        "카드 브랜드 표시": ["Show network on artwork","卡面显示品牌标识","卡面顯示品牌標識","カード画像にブランドを表示","Mostrar marca","Afficher le réseau","Kartennetz anzeigen"],
        "거래가 없어요": ["No transactions","暂无交易","暫無交易","取引がありません","Sin movimientos","Aucune opération","Keine Buchungen"],
        "아직 지출이 없어요": ["No expenses yet","暂无支出","暫無支出","支出はまだありません","Sin gastos","Aucune dépense","Noch keine Ausgaben"],
        "샘플 데이터 · 설정에서 초기화 가능": ["Sample data · Reset in Settings","示例数据 · 可在设置中重置","範例資料 · 可在設定中重設","サンプルデータ・設定でリセット","Datos de ejemplo","Données d’exemple","Beispieldaten"],
        "남은 예산": ["Remaining budget","剩余预算","剩餘預算","残りの予算","Presupuesto restante","Budget restant","Restbudget"],
        "카드 디자인": ["Card design","卡面设计","卡面設計","カードデザイン","Diseño de tarjeta","Design de carte","Kartendesign"],
        "사진 선택": ["Choose artwork","选择卡面图片","選擇卡面圖片","画像を選択","Elegir imagen","Choisir une image","Bild auswählen"],
        "이미지 제거": ["Remove artwork","移除卡面图片","移除卡面圖片","画像を削除","Quitar imagen","Supprimer l’image","Bild entfernen"],
        "어두운 글자": ["Dark lettering","深色文字","深色文字","暗い文字","Texto oscuro","Texte sombre","Dunkler Text"],
        "이미지 음영": ["Image shading","图片遮罩","圖片遮罩","画像の陰影","Sombreado","Ombrage","Bildabdunklung"],
        "없음": ["None","无","無","なし","Ninguno","Aucun","Keine"],
        "카드 사진에는 실제 카드번호, CVC 등 민감 정보가 없어야 합니다. 장식 이미지로만 사용됩니다.": ["Use decorative artwork without real card numbers, CVC or other sensitive data.","只使用装饰图片，请勿导入含真实卡号、CVC 等敏感信息的照片。","只使用裝飾圖片，請勿匯入含真實卡號、CVC 等敏感資訊的照片。","実際のカード番号やCVCを含まない装飾画像を使用してください。"],
        "이미지를 불러올 수 없습니다.": ["Unable to load image.","无法载入图片。","無法載入圖片。","画像を読み込めません。"],
        "홈": ["Home", "首页", "首頁", "ホーム", "Inicio", "Accueil", "Start"],
        "내역": ["History", "明细", "明細", "履歴", "Historial", "Historique", "Verlauf"],
        "지갑": ["Wallet", "钱包", "錢包", "ウォレット", "Cartera", "Portefeuille", "Wallet"],
        "분석": ["Analytics", "分析", "分析", "分析", "Análisis", "Analyse", "Analyse"],
        "자동": ["Auto", "自动", "自動", "自動", "Automático", "Auto", "Automatisch"],
        "설정": ["Settings", "设置", "設定", "設定", "Ajustes", "Réglages", "Einstellungen"],
        "언어": ["Language", "语言", "語言", "言語", "Idioma", "Langue", "Sprache"],
        "시스템 언어": ["System language", "跟随系统", "跟隨系統", "システム言語", "Idioma del sistema", "Langue du système", "Systemsprache"],
        "가계부를 내 방식대로": ["Make your ledger yours", "自定义你的账本", "自訂你的帳本", "自分好みの家計簿"],
        "월 예산": ["Monthly budget", "月度预算", "每月預算", "月間予算", "Presupuesto mensual", "Budget mensuel", "Monatsbudget"],
        "예산": ["Budget", "预算", "預算", "予算", "Presupuesto", "Budget", "Budget"],
        "원": ["KRW", "韩元", "韓元", "ウォン", "KRW", "KRW", "KRW"],
        "저장": ["Save", "保存", "儲存", "保存", "Guardar", "Enregistrer", "Speichern"],
        "화면 테마": ["Appearance", "界面主题", "介面主題", "外観", "Apariencia", "Apparence", "Erscheinungsbild"],
        "테마": ["Theme", "主题", "主題", "テーマ", "Tema", "Thème", "Design"],
        "라이트": ["Light", "浅色", "淺色", "ライト", "Claro", "Clair", "Hell"],
        "다크": ["Dark", "深色", "深色", "ダーク", "Oscuro", "Sombre", "Dunkel"],
        "시스템 설정": ["System", "系统", "系統", "システム", "Sistema", "Système", "System"],
        "메뉴 위치": ["Navigation position", "菜单位置", "選單位置", "メニュー位置"],
        "시스템 자동 배치": ["Automatic system layout", "系统自动布局", "系統自動配置", "システム自動配置"],
        "보안": ["Security", "安全", "安全性", "セキュリティ", "Seguridad", "Sécurité", "Sicherheit"],
        "앱 열기 잠금": ["App lock", "应用锁", "App 鎖定", "アプリロック", "Bloqueo de app", "Verrouillage", "App-Sperre"],
        "데이터": ["Data", "数据", "資料", "データ", "Datos", "Données", "Daten"],
        "보관함 백업 · 글꼴 · 휴지통": ["Vault backup, font and trash", "保险库备份、字体与回收站", "保險庫備份、字型與垃圾桶", "保管庫のバックアップ・フォント・ゴミ箱"],
        "거래 내역 CSV 내보내기": ["Export transactions as CSV", "导出交易 CSV", "匯出交易 CSV", "取引をCSVで書き出す"],
        "CSV 파일 공유하기": ["Share CSV file", "分享 CSV 文件", "分享 CSV 檔案", "CSVを共有"],
        "예시 데이터 채우기": ["Load sample data", "填充示例数据", "填入範例資料", "サンプルデータを入れる"],
        "가계부 기록 삭제 (보관함 제외)": ["Delete ledger records (keep vault)", "删除账本记录（保留保险库）", "刪除帳本紀錄（保留保險庫）", "家計簿を削除（保管庫を除く）"],
        "안내": ["About", "关于", "關於", "情報", "Información", "À propos", "Info"],
        "기기 내부 저장 · 별도 서버 없음": ["On-device storage · No server", "本机存储 · 无服务器", "裝置內儲存 · 無伺服器", "端末内保存・サーバーなし"],
        "은행 · 카드 실시간 연동 없음": ["No live bank connection", "不实时连接银行或银行卡", "不即時連接銀行或信用卡", "銀行・カードのリアルタイム連携なし"],
        "통장 비밀코드는 백업·동기화하지 않음": ["Bank secret codes are not backed up or synced", "银行保密码不备份或同步", "銀行保密碼不備份或同步", "口座の秘密コードはバックアップ・同期なし"],
        "확인": ["OK", "确定", "確認", "OK", "Aceptar", "OK", "OK"],
        "취소": ["Cancel", "取消", "取消", "キャンセル", "Cancelar", "Annuler", "Abbrechen"],
        "닫기": ["Close", "关闭", "關閉", "閉じる", "Cerrar", "Fermer", "Schließen"],
        "삭제": ["Delete", "删除", "刪除", "削除", "Eliminar", "Supprimer", "Löschen"],
        "수정": ["Edit", "编辑", "編輯", "編集", "Editar", "Modifier", "Bearbeiten"],
        "추가": ["Add", "添加", "新增", "追加", "Añadir", "Ajouter", "Hinzufügen"],
        "나의 가계부": ["My ledger", "我的账本", "我的帳本", "マイ家計簿", "Mi registro", "Mon budget", "Mein Haushaltsbuch"],
        "오늘도 현명하게 관리해요": ["Manage your money wisely", "轻松管理每一天", "輕鬆管理每一天", "今日も賢く管理"],
        "거래 추가": ["Add transaction", "添加交易", "新增交易", "取引を追加", "Añadir transacción", "Ajouter une opération", "Buchung hinzufügen"],
        "현재 가계부 잔액": ["Current ledger balance", "当前账本余额", "目前帳本餘額", "現在の家計簿残高", "Saldo actual", "Solde actuel", "Aktueller Saldo"],
        "기초 잔액 + 수입 − 지출 · 오늘까지": ["Opening balance + income − expenses through today", "期初余额＋收入－支出（截至今日）", "期初餘額＋收入－支出（截至今日）", "期首残高＋収入−支出（今日まで）"],
        "기초 잔액 (KRW)": ["Opening balance (KRW)", "期初余额（韩元）", "期初餘額（韓元）", "期首残高（KRW）"],
        "이번 달 지출": ["Monthly spending", "本月支出", "本月支出", "今月の支出", "Gastos del mes", "Dépenses du mois", "Monatsausgaben"],
        "이번 달 수입": ["Monthly income", "本月收入", "本月收入", "今月の収入", "Ingresos del mes", "Revenus du mois", "Monatseinnahmen"],
        "월 지출 예산": ["Monthly spending budget", "月度支出预算", "每月支出預算", "月間支出予算"],
        "예산을 초과했어요": ["Budget exceeded", "已超出预算", "已超出預算", "予算を超えました"],
        "카테고리별 지출": ["Spending by category", "分类支出", "分類支出", "カテゴリ別支出"],
        "최근 거래": ["Recent transactions", "近期交易", "近期交易", "最近の取引"],
        "최대 5건": ["Up to 5", "最多5笔", "最多5筆", "最大5件"],
        "전체": ["All", "全部", "全部", "すべて", "Todo", "Tout", "Alle"],
        "지출": ["Expense", "支出", "支出", "支出", "Gasto", "Dépense", "Ausgabe"],
        "수입": ["Income", "收入", "收入", "収入", "Ingreso", "Revenu", "Einnahme"],
        "거래 내역": ["Transactions", "交易明细", "交易明細", "取引履歴", "Transacciones", "Transactions", "Buchungen"],
        "지출과 수입을 한눈에": ["Income and expenses at a glance", "收支一目了然", "收支一目了然", "収支をひと目で"],
        "거래 구분": ["Transaction type", "交易类型", "交易類型", "取引区分"],
        "거래 내용": ["Transaction details", "交易内容", "交易內容", "取引内容"],
        "종류": ["Type", "类型", "類型", "種類", "Tipo", "Type", "Typ"],
        "금액": ["Amount", "金额", "金額", "金額", "Importe", "Montant", "Betrag"],
        "카테고리": ["Category", "分类", "分類", "カテゴリ", "Categoría", "Catégorie", "Kategorie"],
        "날짜": ["Date", "日期", "日期", "日付", "Fecha", "Date", "Datum"],
        "결제 수단 · 선택": ["Payment method · Optional", "付款方式（选填）", "付款方式（選填）", "支払方法（任意）"],
        "선택 안 함": ["None", "不选择", "不選擇", "選択なし", "Ninguno", "Aucun", "Keine"],
        "거래 수정": ["Edit transaction", "编辑交易", "編輯交易", "取引を編集"],
        "식비": ["Food", "餐饮", "餐飲", "食費", "Comida", "Alimentation", "Essen"],
        "쇼핑": ["Shopping", "购物", "購物", "買い物", "Compras", "Achats", "Einkäufe"],
        "교통": ["Transport", "交通", "交通", "交通", "Transporte", "Transport", "Verkehr"],
        "주거": ["Housing", "住房", "住房", "住居", "Vivienda", "Logement", "Wohnen"],
        "공과금": ["Bills", "水电杂费", "水電雜費", "光熱費", "Facturas", "Factures", "Nebenkosten"],
        "건강": ["Health", "健康", "健康", "健康", "Salud", "Santé", "Gesundheit"],
        "여가": ["Leisure", "娱乐", "娛樂", "娯楽", "Ocio", "Loisirs", "Freizeit"],
        "급여": ["Salary", "工资", "薪資", "給与", "Salario", "Salaire", "Gehalt"],
        "이체": ["Transfer", "转账", "轉帳", "振込", "Transferencia", "Virement", "Überweisung"],
        "기타": ["Other", "其他", "其他", "その他", "Otros", "Autre", "Sonstiges"],
        "지출 분석": ["Spending analysis", "支出分析", "支出分析", "支出分析"],
        "최근 6개월 지출": ["Last 6 months", "近6个月支出", "近6個月支出", "直近6か月の支出"],
        "월": ["Month", "月", "月", "月", "Mes", "Mois", "Monat"],
        "카드별 지출": ["Spending by card", "按卡片统计支出", "依卡片統計支出", "カード別支出"],
        "자동 기록": ["Recurring entries", "自动记账", "自動記帳", "自動記録"],
        "나의 구독 관리": ["Manage subscriptions", "订阅管理", "訂閱管理", "サブスク管理"],
        "항목 이름": ["Item name", "项目名称", "項目名稱", "項目名"],
        "금액 (원)": ["Amount (KRW)", "金额（韩元）", "金額（韓元）", "金額（ウォン）"],
        "구분": ["Type", "类型", "類型", "区分"],
        "분류": ["Category", "分类", "分類", "分類"],
        "시작일": ["Start date", "开始日期", "開始日期", "開始日"],
        "결제 수단": ["Payment method", "付款方式", "付款方式", "支払方法"],
        "미지정": ["Unspecified", "未指定", "未指定", "未指定"],
        "자동 기록 추가": ["Add recurring entry", "添加自动记账", "新增自動記帳", "自動記録を追加"],
        "카드 추가": ["Add card", "添加卡片", "新增卡片", "カードを追加"],
        "통장 추가": ["Add account", "添加账户", "新增帳戶", "口座を追加"],
        "카드 지갑": ["Cards", "银行卡", "銀行卡", "カード", "Tarjetas", "Cartes", "Karten"],
        "통장 지갑": ["Bank accounts", "银行账户", "銀行帳戶", "銀行口座", "Cuentas", "Comptes", "Konten"],
        "개인정보 보관함": ["Private vault", "个人保险库", "個人保險庫", "個人情報保管庫"],
        "카드 및 은행 검색": ["Search cards and banks", "搜索卡片与银行", "搜尋卡片與銀行", "カード・銀行を検索"],
        "목록 보기": ["List view", "列表视图", "清單檢視", "リスト表示"],
        "겹쳐 보기": ["Stack view", "叠放视图", "堆疊檢視", "重ねて表示"],
        "결제 카드": ["Payment cards", "支付卡", "支付卡", "決済カード"],
        "은행 통장": ["Bank accounts", "银行账户", "銀行帳戶", "銀行口座"],
        "비밀코드 보호": ["Protected code", "保密码保护", "保密碼保護", "秘密コード保護"],
        "코드 확인": ["View code", "查看密码", "查看密碼", "コードを確認"],
        "사용자 이름": ["Cardholder", "持卡人姓名", "持卡人姓名", "カード名義"],
        "이번 달 사용": ["Spent this month", "本月消费", "本月消費", "今月の利用額"],
        "정보 잠그기": ["Lock details", "锁定资料", "鎖定資料", "情報をロック"],
        "카드번호 보기": ["Show card number", "显示完整卡号", "顯示完整卡號", "カード番号を表示"],
        "복사 완료": ["Copied", "已复制", "已複製", "コピー済み"],
        "카드번호 복사": ["Copy card number", "复制卡号", "複製卡號", "カード番号をコピー"],
        "카드 정보": ["Card details", "银行卡信息", "銀行卡資訊", "カード情報"],
        "유효기간": ["Expiry date", "有效期", "有效期限", "有効期限"],
        "카드 브랜드": ["Card network", "卡组织", "卡組織", "カードブランド"],
        "미등록": ["Not registered", "未登记", "未登記", "未登録"],
        "카드": ["Card", "卡片", "卡片", "カード"],
        "카드 별칭": ["Card nickname", "卡片别名", "卡片別名", "カードのニックネーム"],
        "카드사": ["Card issuer", "发卡机构", "發卡機構", "カード会社"],
        "카드번호 마지막 4자리": ["Last four digits", "卡号末四位", "卡號末四碼", "カード番号の末尾4桁"],
        "카드 색상": ["Card color", "卡片颜色", "卡片顏色", "カードの色"],
        "월 사용 한도": ["Monthly spending limit", "月消费额度", "每月消費額度", "月間利用限度額"],
        "선택": ["Optional", "选填", "選填", "任意"],
        "전체 카드 정보 · 보호됨": ["Full card details · Protected", "完整卡片资料 · 已保护", "完整卡片資料 · 已保護", "カード詳細・保護済み"],
        "기기 인증 후 카드번호 · CVC 등록": ["Authenticate to enter number and CVC", "设备验证后登记卡号和 CVC", "裝置驗證後登記卡號與 CVC", "端末認証後に番号・CVCを入力"],
        "보안 정보 표시": ["Show protected details", "显示安全资料", "顯示安全資料", "保護情報を表示"],
        "전체 카드번호": ["Full card number", "完整卡号", "完整卡號", "カード番号全桁"],
        "유효기간 (MM/YY)": ["Expiry (MM/YY)", "有效期 (MM/YY)", "有效期限 (MM/YY)", "有効期限 (MM/YY)"],
        "카드 등록": ["Register card", "登记卡片", "登記卡片", "カード登録"],
        "카드 수정": ["Edit card", "编辑卡片", "編輯卡片", "カード編集"],
        "이 카드 삭제": ["Delete this card", "删除此卡", "刪除此卡", "このカードを削除"],
        "통장 정보": ["Account details", "账户资料", "帳戶資料", "口座情報"],
        "은행명": ["Bank name", "银行名称", "銀行名稱", "銀行名"],
        "계좌번호": ["Account number", "账号", "帳號", "口座番号"],
        "계좌번호 · 선택": ["Account number · Optional", "账号（选填）", "帳號（選填）", "口座番号（任意）"],
        "색상": ["Color", "颜色", "顏色", "色"],
        "비밀코드 · 선택": ["Secret code · Optional", "保密码（选填）", "保密碼（選填）", "秘密コード（任意）"],
        "통장 삭제": ["Delete account", "删除账户", "刪除帳戶", "口座を削除"],
        "통장 등록": ["Register account", "登记账户", "登記帳戶", "口座登録"],
        "통장 수정": ["Edit account", "编辑账户", "編輯帳戶", "口座編集"],
        "신용·체크카드": ["Credit and debit cards", "信用卡与借记卡", "信用卡與簽帳金融卡", "クレジット・デビットカード"],
        "은행 계좌": ["Bank account", "银行账户", "銀行帳戶", "銀行口座"],
        "보안카드": ["Security card", "安全卡", "安全卡", "セキュリティカード"],
        "ID · 비밀번호": ["Login and password", "账号与密码", "帳號與密碼", "ID・パスワード"],
        "주민등록증": ["National ID", "身份证", "身分證", "身分証"],
        "운전면허증": ["Driver’s license", "驾驶证", "駕駛執照", "運転免許証"],
        "여권": ["Passport", "护照", "護照", "パスポート"],
        "개인통관고유부호": ["Korean customs ID", "个人通关号码", "個人通關號碼", "個人通関固有番号"],
        "인증서 정보": ["Certificate details", "证书资料", "憑證資料", "証明書情報"],
        "기타 비밀 메모": ["Private notes", "私密备忘录", "私密備忘錄", "秘密メモ"],
        "카드번호": ["Card number", "卡号", "卡號", "カード番号"],
        "카드 소유자": ["Cardholder", "持卡人", "持卡人", "カード名義"],
        "예금주": ["Account holder", "开户人", "開戶人", "口座名義"],
        "보안 메모": ["Secure note", "安全备忘录", "安全備忘錄", "保護メモ"],
        "발급 기관": ["Issuer", "签发机关", "簽發機關", "発行機関"],
        "일련번호": ["Serial number", "序列号", "序號", "シリアル番号"],
        "보안카드 번호": ["Security card code", "安全卡号码", "安全卡號碼", "セキュリティカード番号"],
        "웹사이트": ["Website", "网站", "網站", "ウェブサイト"],
        "사용자 ID": ["User ID", "用户 ID", "使用者 ID", "ユーザーID"],
        "비밀번호": ["Password", "密码", "密碼", "パスワード"],
        "성명": ["Name", "姓名", "姓名", "氏名"],
        "주민등록번호": ["National ID number", "身份证号码", "身分證號碼", "住民登録番号"],
        "발급일": ["Issue date", "签发日期", "簽發日期", "発行日"],
        "면허번호": ["License number", "驾驶证号码", "駕照號碼", "免許証番号"],
        "갱신일": ["Renewal date", "更新日期", "更新日期", "更新日"],
        "여권번호": ["Passport number", "护照号码", "護照號碼", "旅券番号"],
        "국적": ["Nationality", "国籍", "國籍", "国籍"],
        "만료일": ["Expiration date", "到期日期", "到期日期", "有効期限"],
        "통관고유부호": ["Customs ID", "通关号码", "通關號碼", "通関番号"],
        "인증서 이름": ["Certificate name", "证书名称", "憑證名稱", "証明書名"],
        "참고 정보": ["Reference details", "参考资料", "參考資料", "参考情報"],
        "내용": ["Content", "内容", "內容", "内容"],
        "매주": ["Weekly", "每周", "每週", "毎週"],
        "매월": ["Monthly", "每月", "每月", "毎月"],
        "매년": ["Yearly", "每年", "每年", "毎年"],
        "기본": ["Default", "默认", "預設", "標準"],
        "보관함": ["Vault", "保险库", "保險庫", "保管庫"],
        "구독": ["Subscriptions", "订阅", "訂閱", "サブスク"],
        "휴지통": ["Trash", "回收站", "垃圾桶", "ゴミ箱"],
        "이름 검색": ["Search name", "搜索名称", "搜尋名稱", "名前を検索"],
        "보관함 열기": ["Unlock vault", "解锁保险库", "解鎖保險庫", "保管庫を開く"],
        "나의 디지털 지갑": ["My digital wallet", "我的数字钱包", "我的數位錢包", "マイデジタルウォレット"],
        "잠그기": ["Lock", "锁定", "鎖定", "ロック"],
        "둥근 글꼴": ["Rounded", "圆体", "圓體", "丸ゴシック"],
        "고정폭": ["Monospaced", "等宽字体", "等寬字型", "等幅"],
        "작게": ["Small", "小", "小", "小"],
        "크게": ["Large", "大", "大", "大"],
        "백업 비밀번호": ["Backup password", "备份密码", "備份密碼", "バックアップパスワード"],
        "비밀번호 확인": ["Confirm password", "确认密码", "確認密碼", "パスワード確認"],
        "암호화 백업": ["Encrypted backup", "加密备份", "加密備份", "暗号化バックアップ"],
        "영구 삭제": ["Delete permanently", "永久删除", "永久刪除", "完全に削除"],
        "정보 추가": ["Add information", "添加资料", "新增資料", "情報を追加"],
        "월 예상 구독료": ["Estimated monthly subscription cost", "预计每月订阅费", "預計每月訂閱費", "月間サブスク予想額"],
        "구독 추가": ["Add subscription", "添加订阅", "新增訂閱", "サブスクを追加"],
        "나의 구독": ["My subscriptions", "我的订阅", "我的訂閱", "マイサブスク"],
        "삭제된 정보": ["Deleted items", "已删除资料", "已刪除資料", "削除済み情報"],
        "복원": ["Restore", "恢复", "復原", "復元"],
        "휴지통 비우기": ["Empty trash", "清空回收站", "清空垃圾桶", "ゴミ箱を空にする"],
        "보관함 화면 설정": ["Vault appearance", "保险库显示设置", "保險庫顯示設定", "保管庫の外観"],
        "글꼴": ["Font", "字体", "字型", "フォント"],
        "글자 크기": ["Font size", "字号", "字體大小", "文字サイズ"],
        "백업 및 복원": ["Backup and restore", "备份与恢复", "備份與復原", "バックアップと復元"],
        "암호화 백업 내보내기": ["Export encrypted backup", "导出加密备份", "匯出加密備份", "暗号化バックアップを書き出す"],
        "암호화 백업 가져오기": ["Import encrypted backup", "导入加密备份", "匯入加密備份", "暗号化バックアップを読み込む"],
        "기본 정보": ["Basic information", "基本信息", "基本資訊", "基本情報"],
        "이름": ["Name", "名称", "名稱", "名前"],
        "즐겨찾기": ["Favorite", "收藏", "收藏", "お気に入り"],
        "가계부 연결": ["Link to ledger", "关联账本", "連結帳本", "家計簿にリンク"],
        "연결 안 함": ["Not linked", "不关联", "不連結", "リンクなし"],
        "보호된 정보": ["Protected information", "受保护资料", "受保護資料", "保護された情報"],
        "내용 표시": ["Show contents", "显示内容", "顯示內容", "内容を表示"],
        "정보 편집": ["Edit information", "编辑资料", "編輯資料", "情報編集"],
        "저장 실패": ["Save failed", "保存失败", "儲存失敗", "保存失敗"],
        "구독 서비스 이름": ["Subscription name", "订阅服务名称", "訂閱服務名稱", "サブスクサービス名"],
        "결제 금액 (원)": ["Payment amount (KRW)", "支付金额（韩元）", "付款金額（韓元）", "支払額（KRW）"],
        "결제 주기": ["Billing cycle", "扣款周期", "扣款週期", "支払周期"],
        "첫 결제일": ["First payment date", "首次扣款日", "首次扣款日", "初回支払日"],
        "사용 중": ["Active", "使用中", "使用中", "利用中"],
        "결제 전날 알림": ["Reminder before payment", "扣款前一天提醒", "扣款前一天提醒", "支払前日の通知"],
        "구독 편집": ["Edit subscription", "编辑订阅", "編輯訂閱", "サブスク編集"],
        "표시 통화": ["Display currency", "显示币种", "顯示幣別", "表示通貨", "Moneda de visualización", "Devise d’affichage", "Anzeigewährung"],
        "통화": ["Currency", "币种", "幣別", "通貨", "Moneda", "Devise", "Währung"],
        "직접 입력 환율": ["Manual exchange rate", "手动输入汇率", "手動輸入匯率", "手動為替レート"],
        "환율을 저장하기 전에는 원화로 표시합니다.": ["Amounts remain in KRW until a rate is saved.", "保存汇率前仍以韩元显示。", "儲存匯率前仍以韓元顯示。", "レート保存まではKRW表示です。"],
        "기존 데이터와 입력 금액은 KRW로 유지합니다. 다른 통화는 직접 설정한 환율로 환산한 참고 금액입니다. 실시간 환율은 제공하지 않습니다.": ["Stored and entered amounts remain in KRW. Other currencies are estimates using your manual rate, not live rates.", "原始数据和输入金额保留韩元，其他币种按手动汇率换算，仅供参考，不提供实时汇率。", "原始資料與輸入金額保留韓元，其他幣別按手動匯率換算，僅供參考。", "保存・入力はKRWのままです。他通貨は手動レートによる参考表示で、リアルタイムレートではありません。"],
        "통장 잔액은 직접 입력한 기초 잔액입니다. 홈의 가계부 잔액은 거래에 따라 계산합니다.": ["Account amounts are manually entered opening balances. Home balance adjusts with recorded transactions.", "账户金额为手动填写的期初余额，首页余额根据交易计算。", "帳戶金額為手動輸入的期初餘額，首頁餘額依交易計算。", "口座金額は手入力の期首残高です。ホーム残高は取引から計算します。"],
        "거래는 홈의 가계부 잔액에 자동 반영됩니다. 은행 계좌의 실제 잔액과는 연동되지 않습니다.": ["Transactions update the home ledger balance, not your actual bank balance.", "交易自动反映到首页账本余额，不连接银行实际余额。", "交易自動反映到首頁帳本餘額，不連接銀行實際餘額。", "取引はホーム残高に反映されます。実際の銀行残高とは連携しません。"],
        "미드나이트": ["Midnight", "午夜黑", "午夜黑", "ミッドナイト"],
        "코발트": ["Cobalt", "钴蓝", "鈷藍", "コバルト"],
        "바이올렛": ["Violet", "紫色", "紫色", "バイオレット"],
        "코랄": ["Coral", "珊瑚色", "珊瑚色", "コーラル"],
        "에메랄드": ["Emerald", "翠绿", "翠綠", "エメラルド"],
        "보호된 가계부입니다": ["Your ledger is protected", "账本已锁定", "帳本已鎖定", "家計簿は保護されています"],
        "Face ID / 기기 암호로 열기": ["Unlock with Face ID or device passcode", "使用 Face ID 或设备密码解锁", "使用 Face ID 或裝置密碼解鎖", "Face ID またはパスコードで開く"],
        "인증 실패": ["Authentication failed", "验证失败", "驗證失敗", "認証に失敗しました"],
        "저장된 코드가 없습니다.": ["No saved code.", "未保存密码。", "未儲存密碼。", "保存されたコードがありません。"],
        "카드 · 계좌 · 신분증 · 비밀번호 · 구독": ["Cards, accounts, IDs, passwords, subscriptions", "卡片、账户、证件、密码、订阅", "卡片、帳戶、證件、密碼、訂閱", "カード・口座・身分証・パスワード・サブスク"]
    ]
}
func L(_ key: String) -> String {
    let code = AppLocalization.code
    if code == "ko" { return key }
    guard let values = AppLocalization.table[key] else { return key }
    let index = ["en", "zh-Hans", "zh-Hant", "ja", "es", "fr", "de"].firstIndex(of: code) ?? 0
    return values.indices.contains(index) ? values[index] : (values.first ?? key)
}

private struct AppLanguageRevisionKey: EnvironmentKey {
    static let defaultValue = "system"
}
extension EnvironmentValues {
    var appLanguageRevision: String {
        get { self[AppLanguageRevisionKey.self] }
        set { self[AppLanguageRevisionKey.self] = newValue }
    }
}
