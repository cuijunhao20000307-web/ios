# PocketLedger v0.4.0

SwiftUI personal ledger for iOS 17+. Korean UI. Local data storage, spending and income, cards and accounts, monthly budget, six-month charts, recurring entries, light/dark mode, CSV export, Face ID/device passcode and native system tab bar (Duo adaptive placement and standard iPhone navigation).

## Build an unsigned IPA
The GitHub Actions workflow builds for a physical iPhone and uploads an unsigned IPA artifact. Open Actions → Build PocketLedger unsigned IPA → Run workflow. Once the run succeeds, download the artifact and extract the IPA. A valid signing method is needed before installation.

The icon is restored from the losslessly encoded original pixel data by scripts/restore_icon.py before the build. For local Xcode development run python3 scripts/restore_icon.py first.

No banking integration. Never upload real account details or signing credentials to this public repository.

## Native iPhone Duo layout
Build with Xcode 27.1 or later (iOS 27.1+ SDK). The app uses native SwiftUI TabView rather than an in-app custom dock. The system determines the bar location, backdrop, and overflow according to the device pose; no private system patches are required. The GitHub Actions job verifies the SDK before building. Physical Duo testing is required to confirm the appearance and navigation in each pose.

## v0.4.0 Private wallet
Native Duo navigation is unchanged. Open Wallet → 개인정보 보관함, Recurring → 나의 구독 관리, or Settings → 보관함 백업. New data resides in a separate device-only Keychain archive; the phone must have a passcode. Includes editable card/account/security-card/login/identity/passport/customs/certificate metadata and secret notes, local favorites/search, subscription dates and estimated monthly KRW total, generic local reminders, recycle bin, and vault font settings. Encrypted backup (AES-GCM, PBKDF2-HMAC-SHA256 600k iterations, random salt) exports/imports the private archive only through Files, including manual iCloud Drive selection. Restore replaces that archive, not the existing ledger. Existing bank secrets and ledger records are excluded. No payment processing, actual certificate file import, automatic iCloud sync, currency-rate service, widget extension, or localization beyond Korean is included in this build. Do not store real CVC or bank login credentials unless you understand the risks. Test with dummy data first; security review and on-device tests are required before real sensitive use.
