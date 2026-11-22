import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var budgetText = ""
    @State private var confirmReset = false
    @State private var confirmSample = false
    @State private var deviceAuthUnavailable = false
    @State private var exportURL: URL?
    @State private var exportError = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("설정").font(.system(size: 30, weight: .bold))
                    Text("가계부를 내 방식대로").font(.subheadline).foregroundStyle(LedgerTheme.subtext)
                }
                Surface {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeading(title: "월 예산")
                        HStack {
                            TextField("예산", text: $budgetText).keyboardType(.numberPad)
                                .font(.system(.body, design: .rounded))
                                .minimumScaleFactor(0.75)
                            Text("원").foregroundStyle(LedgerTheme.subtext).fixedSize()
                            Button("저장") { store.data.monthlyBudget = max(1, budgetText.toMoneyInt) }
                                .fontWeight(.semibold).fixedSize().disabled(budgetText.toMoneyInt < 1)
                        }
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading(title: "화면 테마")
                        Picker("테마", selection: $store.data.appearance) {
                            ForEach(AppearanceMode.allCases) { mode in
                                Text(mode == .system ? "자동" : mode.rawValue).tag(mode)
                            }
                        }.pickerStyle(.segmented)
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionHeading(title: "메뉴 위치")
                        Picker("도크", selection: $store.data.dockPlacement) {
                            ForEach(DockPlacement.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                        Text("넓은 화면에서는 오른쪽 도크, 좁은 화면에서는 하단 도크를 사용합니다. 오른쪽을 선택해도 공간이 부족하면 자동으로 하단으로 전환됩니다.")
                            .font(.system(size: 12)).foregroundStyle(LedgerTheme.subtext)
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 15) {
                        SectionHeading(title: "보안")
                        Toggle(isOn: Binding(get: { store.data.appLockEnabled }, set: { wantsLock in
                            if wantsLock && !LocalUnlock.isAvailable() { deviceAuthUnavailable = true }
                            else { store.data.appLockEnabled = wantsLock }
                        })) {
                            Label("앱 열기 잠금", systemImage: "faceid")
                        }
                        .tint(LedgerTheme.accent)
                        Text("활성화 시 앱 재실행 또는 백그라운드 복귀 후 Face ID / 기기 암호가 필요합니다. 비밀코드 확인에는 별도 인증을 사용합니다.")
                            .font(.system(size: 12)).foregroundStyle(LedgerTheme.subtext)
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeading(title: "데이터")
                        Button {
                            do { exportURL = try store.exportTransactionsCSV() }
                            catch { exportError = true }
                        } label: {
                            Label("거래 내역 CSV 내보내기", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityHint("계좌번호 및 비밀코드를 제외한 거래 내역을 파일로 공유합니다")
                        if let exportURL {
                            ShareLink(item: exportURL) {
                                Label("CSV 파일 공유하기", systemImage: "doc.text")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        Divider()
                        Button { confirmSample = true } label: {
                            Label("예시 데이터 채우기", systemImage: "sparkles")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Divider()
                        Button(role: .destructive) { confirmReset = true } label: {
                            Label("모든 가계부 데이터 삭제", systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeading(title: "안내")
                        Label("기기 내부 저장 · 별도 서버 없음", systemImage: "iphone")
                        Label("은행 · 카드 실시간 연동 없음", systemImage: "wifi.slash")
                        Label("통장 비밀코드는 백업·동기화하지 않음", systemImage: "lock.shield")
                        Text("이 앱은 개인 기록용 가계부 프로토타입입니다. 실제 결제 또는 은행 로그인 기능을 제공하지 않습니다.")
                            .font(.system(size: 12)).foregroundStyle(LedgerTheme.subtext).padding(.top, 5)
                    }
                    .font(.system(size: 13))
                }
                Text("PocketLedger · v0.3.1")
                    .font(.caption).foregroundStyle(LedgerTheme.subtext)
                    .frame(maxWidth: .infinity)
            }
            .padding(20).padding(.top, 8)
            .frame(maxWidth: 780).frame(maxWidth: .infinity)
        }
        .onAppear { budgetText = String(store.data.monthlyBudget) }
        .alert("파일을 만들 수 없습니다", isPresented: $exportError) {
            Button("확인", role: .cancel) { }
        } message: { Text("저장 공간을 확인한 후 다시 시도하세요.") }
        .alert("기기 인증을 사용할 수 없어요", isPresented: $deviceAuthUnavailable) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("iPhone에 Face ID 또는 잠금 암호를 설정한 뒤 다시 시도하세요.")
        }
        .confirmationDialog("현재 데이터를 예시 데이터로 바꿀까요?", isPresented: $confirmSample, titleVisibility: .visible) {
            Button("예시 데이터 적용", role: .destructive) { store.clear(); store.loadSample(); budgetText = String(store.data.monthlyBudget) }
        } message: { Text("기존 거래와 카드, 통장 기록이 삭제됩니다.") }
        .confirmationDialog("모든 데이터를 삭제할까요?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("모두 삭제", role: .destructive) { store.clear(); budgetText = String(store.data.monthlyBudget) }
        } message: { Text("모든 거래, 카드, 통장, 저장된 비밀코드가 삭제됩니다. 복구할 수 없습니다.") }
    }
}
