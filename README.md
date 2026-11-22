# PocketLedger v0.3.0

SwiftUI personal ledger for iOS 17+. Korean UI. Local data storage, spending and income, cards and accounts, monthly budget, six-month charts, recurring entries, light/dark mode, CSV export, Face ID/device passcode and adaptive dock (bottom or right).

## Build an unsigned IPA
The GitHub Actions workflow builds for a physical iPhone and uploads an unsigned IPA artifact. Open Actions → Build PocketLedger unsigned IPA → Run workflow. Once the run succeeds, download the artifact and extract the IPA. A valid signing method is needed before installation.

The icon is restored from the losslessly encoded original pixel data by scripts/restore_icon.py before the build. For local Xcode development run python3 scripts/restore_icon.py first.

No banking integration. Never upload real account details or signing credentials to this public repository.
