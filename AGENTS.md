# Codex instructions: Digital Wallet / PocketLedger

## Source of truth
- Repository: https://github.com/cuijunhao20000307-web/ios
- Branch: main. Baseline app before this handoff: **v0.4.47 (Build 54)**.
- Read `CODEX_HANDOFF.md` and `README.md` first. Do **not** recreate this app from scratch.
- Xcode project: `PocketLedger.xcodeproj`, shared scheme `PocketLedger`.
- Main application source: `PocketLedger/Sources/`, especially `WalletView.swift`.
- Use the GitHub HEAD as the source of truth. Keep existing data models backward compatible.

## Priority: Apple Wallet-like continuous card selection and dismissal
- User has reported that even Build 54's card transition is not yet visually right on the actual iPhone Duo and that swipe-down dismissal had failed in a prior build. Treat this as **unresolved until real-device testing**.
- In `WalletView.swift`, inspect `WalletView.openCard`, `closeCard`, `cardTransitionProgress`, `detailPullDown`, `InteractiveWalletDeck`, and `LedgerCardDetail`.
- Match the reference Apple Wallet recording supplied by the user: one uninterrupted, spatially coherent card open/close motion; background cards move in sync; no delayed shuffle, no hard jump between screens; interactive pull-down should track the finger and return to the original stack.
- Keep the credit-card images, aspect ratio (1.586), card order, touch target geometry, long-press reorder, other layouts, and financial data. Do not claim exact visual parity solely from CI.
- Support Reduce Motion and preserve inner/outer phone layouts. Do not break scroll gestures and controls within card details.
- Keep the hint below the stack visible when cards fit. Current compact stack width cap: 320pt; step ~35–46pt. Change only if device testing proves necessary.

## Core architecture
- `PocketLedgerApp.swift`: app entry point and Face ID/device passcode gate.
- `WalletView.swift`: card stack, bank accounts, security cards, card detail, gestures/animations.
- `Models.swift`: Codable models, localized money categories, payments and recurring rules.
- `LedgerStore.swift`: local ledger persistence and calculations.
- `PrivateWalletView.swift`, `SecureVault.swift`: separate encrypted private archive and local auth.
- `DigitalCloudBackupView.swift`: encrypted manual backup / restore flow.
- `SettingsView.swift`: settings and download/share flow for unsigned IPA update.
- `RecurringView.swift`: scheduled income, fixed expenses and subscriptions.
- `Assets.xcassets`: bank logos, app icon; `BankLogoCredits/` contains attribution.
- `scripts/restore_icon.py`: reconstruct the original icon before building.
- `scripts/fetch_bank_logos.py`: fetch missing logos during CI. Review licenses and do not replace assets casually.

## Build / validation
- Workflow: `.github/workflows/build-unsigned-ipa.yml`, with runner `xcode-27` and iOS SDK >= 27.1.
- Project deployment target iOS 17.0, Swift 5, bundle ID `com.example.pocketledger`.
- Locally on an appropriate macOS/Xcode environment:
  1. `python3 scripts/restore_icon.py`
  2. `python3 scripts/fetch_bank_logos.py` (if logos missing; network dependent)
  3. `xcodebuild -project PocketLedger.xcodeproj -scheme PocketLedger -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build`
- The build produces an **unsigned IPA**, not an install-ready signed iOS app. Never promise installation without signing/provisioning. GitHub Release IPA does not contain all four original local balance covers by default.
- Current GitHub Actions green build does not prove real-device animations or gesture correctness.
- Avoid actual banking credentials or real card numbers in examples, logs, commits, issue descriptions, and tests. Use dummy data.

## Completion expectations
- Make minimal, reviewable changes, compare with supplied reference videos, build with CI, report exact commit / build / IPA link, list anything not verified on hardware, and provide an actual unsigned IPA if requested.
