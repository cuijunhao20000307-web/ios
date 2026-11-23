# Digital Wallet / PocketLedger — Codex project handoff

**As of 2026-11-23**  
**Repository:** https://github.com/cuijunhao20000307-web/ios  
**Working branch:** `main`  
**Verified source baseline:** `ae0f87d5c2bbc722c0b42f313025f46efe06211e`  
**App version:** `0.4.47` / **Build:** `54`  
**Language/stack:** SwiftUI / Swift 5; Korean primary UI, some Chinese and other localization in model. iOS 17 deployment target; Xcode 27.x workflow uses iOS SDK 27.1+ for Duo-aware navigation.  
**Build status:** v0.4.47 CI build succeeded; animation and touch behavior still require testing on actual iPhone Duo.

## What this project is
An iPhone personal ledger / digital wallet (not actual banking app), built around an Apple Wallet-like card-stack front page, integrated bank account cards, monthly expense and income tracking, recurring rules, financial charts, protected private archive, encrypted user-directed backups, and shareable unsigned IPA update flow. The user uses normal iPhone and iPhone Duo (inner and outer screens). Keep full original functionality and artwork.

## Important source files
| Area | File |
| --- | --- |
| App entry, lock UI | `PocketLedger/Sources/PocketLedgerApp.swift` |
| Wallet stack, animations, card/account/security UI | `PocketLedger/Sources/WalletView.swift` |
| Models and localized expense categories | `PocketLedger/Sources/Models.swift` |
| Storage / logic | `PocketLedger/Sources/LedgerStore.swift` |
| Private card/account/identity records | `PocketLedger/Sources/PrivateWalletView.swift`, `SecureVault.swift` |
| Manual encrypted backup + restore | `PocketLedger/Sources/DigitalCloudBackupView.swift` |
| Scheduled salary/expenses | `PocketLedger/Sources/RecurringView.swift` |
| Settings, online update/download IPA | `PocketLedger/Sources/SettingsView.swift` |
| Visuals | `PocketLedger/Assets.xcassets/` |
| Xcode config | `PocketLedger.xcodeproj/project.pbxproj` |
| CI build and unsigned IPA | `.github/workflows/build-unsigned-ipa.yml` |

## Latest behavior, open problems, and user feedback
- v0.4.44 / Build 51 split **water** and **electricity** spending categories, retaining legacy combined categories for old data.
- v0.4.45 / Build 52 uses the real app icon for Face ID app lock screen.
- v0.4.46 / Build 53 added staged card auto-switch animation but was **rejected by the user** because it did not look like Apple's. It also reduced stacked card width to 320pt and overlap for a previously obscured instruction line.
- v0.4.47 / Build 54 changed to a single 360ms linear transition via `cardTransitionProgress`, coordinated with the background deck, and moved drag-to-close handling to the detail overlay.
- The user explicitly said **“动画不是这样啊”**, **“下拖也返回不到卡片页”** and asked to rework the linear animation. These issues must be considered **not yet user-validated**; do not tell the user they are fixed only because CI passed.

### User's expected animation
1. Tap a visible exposed card strip and get a single, seamless Apple Wallet-like transition to that selected card. Cards behind it move in a coordinated way with no arbitrary ~270ms pause or fake reorder that flips the stack.
2. The card/detail follows an intuitive vertical movement; underlying cards have coherent depth and opacity; the transition should not look like a separate full-screen page abruptly popping in.
3. Drag **down from the card/header zone** to close. Finger tracking, dismissal threshold and reversal of the entrance animation must work; a short drag springs/returns to initial detail state. Preserve normal scrolling elsewhere.
4. Closing via toolbar returns to exactly the same card stack, including order, touch regions and visible instruction text.
5. Smooth on the user's iPhone Duo outer and inner screens; respect accessibility Reduce Motion.

### User-provided video references (not committed to public GitHub)
- `ScreenRecording_11-23-2026 21-21-29_1(1).mp4` — Apple native Wallet reference according to user.
- `ScreenRecording_11-23-2026 21-22-50_1.mp4` — project's app recording according to user.
- `ScreenRecording_11-23-2026 21-35-39_1.mp4` — additional user-reported animation issue.
- `ScreenRecording_11-23-2026 21-36-12_1.mp4` — user-provided example of the behavior wanted.
- `ScreenRecording_11-23-2026 21-37-06_1.mp4` — swipe-down-to-return failure.
If supplied locally, inspect recordings while protecting any visible financial data. Do not post them to a public repository without explicit permission.

## App compatibility / safety invariants
- Never erase or migrate existing user data unnecessarily. Codable models, bank images, security-card two-digit code lookup, backups and private archive remain compatible.
- Preserve legacy `MoneyCategory.bills` when decoding old ledger data, while exposing separate water/electricity choices for new entries.
- Preserve long-press card reorder, normal tap targets, navigation, app lock Face ID, encryption and iCloud Drive manual backup selection.
- Do not break in-app updater; it downloads/exports IPA but unsigned iOS packages must still be signed by user.
- Do not claim physical device testing or Apple Wallet exactness without performing actual device validation.
- Do not invent a working signed IPA or real bank APIs; this app is local and not connected to real bank accounts.

## Asset caveat — four original currency covers
The original **KRW, CNY, JPY and USD** balance cover images were previously inserted into a larger *full* unsigned IPA outside the repository. They do **not** appear as four tracked source assets in the current GitHub tree. This handoff ZIP includes copies of the user-supplied `KRW.png`, `CNY.png`, `JPY.png`, `USD.png` under `SupplementalAssets/OriginalBalanceCovers/`. Codex should inspect the in-app consumers, import these as appropriate and ensure the GitHub Actions IPA contains them by default, rather than repeatedly patching binary packages after CI. Preserve original images and dimensions.

## Recommended execution order for Codex
1. Open `AGENTS.md`, `README.md` and the actual Swift code. Confirm baseline version and HEAD.
2. Reproduce/compare gesture & transition with the recordings and current Build 54; identify why current motion differs from Apple native. Avoid implementing animations from verbal assumptions alone.
3. Fix linear animation and interactive down swipe without changing card proportions or causing scrolling conflicts.
4. Make sure four original currency covers are part of the build (with user consent, if committing to a public repo).
5. Build with Xcode 27.1+ SDK, inspect CI logs, use test accounts/cards and validate on both device modes when available.
6. Bump marketing version/build for genuine new releases; publish verified unsigned IPA and report exact SHA and remaining limitations.

## Reproduce unsigned IPA build
```bash
python3 scripts/restore_icon.py
python3 scripts/fetch_bank_logos.py
xcodebuild \
  -project PocketLedger.xcodeproj \
  -scheme PocketLedger \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build
```

### Suggested Codex opening request
> Continue the existing Digital Wallet/PocketLedger SwiftUI repository on branch main from Build 54, not a rewrite. Read AGENTS.md and CODEX_HANDOFF.md. Compare the attached Apple Wallet reference and our app recordings, then repair the continuous linear card transition and reliable interactive downward dismissal on iPhone Duo, preserving all current data, art, card sizing, tap/reorder behavior, and encrypted backup features. Incorporate all four original currency covers into the normal build. Commit your changes, compile, test what is possible, and give the exact new build/IPA plus hardware-testing limitations.
