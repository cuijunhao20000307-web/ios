import Foundation
import SwiftUI

enum WalletTab: String, CaseIterable, Identifiable {
    case home = "홈"
    case history = "내역"
    case wallet = "지갑"
    case analytics = "분석"
    case recurring = "자동"
    case settings = "설정"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .history: "chart.bar.xaxis"
        case .wallet: "wallet.bifold.fill"
        case .analytics: "chart.bar.fill"
        case .recurring: "calendar.badge.clock"
        case .settings: "gearshape.fill"
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
    var fractionDigits: Int { [.KRW, .JPY, .VND].contains(self) ? 0 : 2 }
    static var selected: DisplayCurrency {
        DisplayCurrency(rawValue: UserDefaults.standard.string(forKey: "displayCurrency") ?? "KRW") ?? .KRW
    }
    var rate: Double? {
        if self == .KRW { return 1 }
        let value = UserDefaults.standard.double(forKey: "displayRate." + rawValue)
        return value.isFinite && value > 0 ? value : nil
    }
    var formattedName: String {
        Locale.current.localizedString(forCurrencyCode: rawValue).map { rawValue + " · " + $0 } ?? rawValue
    }
    static func format(_ amount: Int) -> String {
        let choice = selected
        let active: DisplayCurrency = choice.rate == nil ? .KRW : choice
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: UserDefaults.standard.string(forKey: "appLanguage").flatMap { $0 == "system" ? nil : $0 } ?? Locale.current.identifier)
        formatter.numberStyle = .currency
        formatter.currencyCode = active.rawValue
        formatter.minimumFractionDigits = active.fractionDigits
        formatter.maximumFractionDigits = active.fractionDigits
        let rate = active.rate ?? 1
        let value = Double(amount) / rate
        let rendered = formatter.string(from: NSNumber(value: value)) ?? String(amount) + " KRW"
        return active == .KRW ? rendered : "≈ " + rendered
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
