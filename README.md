# PocketLedger v0.4.3

SwiftUI personal ledger for iOS 17+. Korean UI. Local data storage, spending and income, cards and accounts, monthly budget, six-month charts, recurring entries, light/dark mode, CSV export, Face ID/device passcode and native system tab bar (Duo adaptive placement and standard iPhone navigation).

## Build an unsigned IPA
The GitHub Actions workflow builds for a physical iPhone and uploads an unsigned IPA artifact. Open Actions → Build PocketLedger unsigned IPA → Run workflow. Once the run succeeds, download the artifact and extract the IPA. A valid signing method is needed before installation.

The icon is restored from the losslessly encoded original pixel data by scripts/restore_icon.py before the build. For local Xcode development run python3 scripts/restore_icon.py first.

No banking integration. Never upload real account details or signing credentials to this public repository.

## Native iPhone Duo layout
Build with Xcode 27.1 or later (iOS 27.1+ SDK). The app uses native SwiftUI TabView rather than an in-app custom dock. The system determines the bar location, backdrop, and overflow according to the device pose; no private system patches are required. The GitHub Actions job verifies the SDK before building. Physical Duo testing is required to confirm the appearance and navigation in each pose.

## v0.4.0 Private wallet
Native Duo navigation is unchanged. Open Wallet → 개인정보 보관함, Recurring → 나의 구독 관리, or Settings → 보관함 백업. New data resides in a separate device-only Keychain archive; the phone must have a passcode. Includes editable card/account/security-card/login/identity/passport/customs/certificate metadata and secret notes, local favorites/search, subscription dates and estimated monthly KRW total, generic local reminders, recycle bin, and vault font settings. Encrypted backup (AES-GCM, PBKDF2-HMAC-SHA256 600k iterations, random salt) exports/imports the private archive only through Files, including manual iCloud Drive selection. Restore replaces that archive, not the existing ledger. Existing bank secrets and ledger records are excluded. No payment processing, actual certificate file import, automatic iCloud sync, currency-rate service, widget extension, or localization beyond Korean is included in this build. Do not store real CVC or bank login credentials unless you understand the risks. Test with dummy data first; security review and on-device tests are required before real sensitive use.

## v0.4.2 Wallet layout
Card list is a compact Apple Wallet-inspired stack with a list-view toggle and search. Cards open a native NavigationStack detail page. Full number, optional CVC, owner, expiry and card network can be edited from the main wallet after device authentication, linked by existing ledger UUID to the private archive. No numbers from reference screenshots are included. Card copy is device-local and expires after 60 seconds. Existing last-four-only cards and spending history remain. Full number is masked until authentication; CVC requires a separate authentication. Card art uses existing gradient colors, not actual card images. Device testing and security review still required.

## v0.4.2 balance and currency
Home ledger balance is opening account balances plus all recorded income minus expenses through today. Old manually entered balances are interpreted as opening balances; adjust them if they already include historical transactions. Display currency is optional manual-rate conversion of existing KRW data; amounts and input remain KRW and are not relabeled. No live exchange-rate or real bank integration.

Language selector supports Korean, simplified/traditional Chinese, Japanese, English, Spanish, French, and German. Main interface labels have translations; secondary strings may fall back to English or Korean until localization is complete. User content and persistent identifiers remain unchanged. Language and currency are independent preferences.

## v0.4.3 adaptive wallet
Responsive two-column Dashboard, Settings and card detail using available safe-area content width. Wallet stack is centered; expanded list uses adaptive grid. Decorative custom artwork imports through PhotosPicker, downsampled to 1000×630 JPEG with contrast controls; no real card photos or secrets should be used as artwork. Optional network badge including none. Legacy card fields remain decodable. Private card data stays in the existing protected archive. Fixes missing localization refresh identifiers in Surface. No change to native tab bar.

## v0.4.4 interface refinement
Unified grouped dashboard with full-width balance, monthly income and expenses, budget and proportional category sections, native add action. Wallet search is on demand; native toolbar carries add and menu, centered genuine overlapping cards with correct ratio and consistent width, optional grid. Original native Duo navigation and data model retained.

## v0.4.5 artwork-first interactive wallet
Custom artwork displays with only the last four digits and optional network badge; full card number stays in authenticated details. Every exposed card strip is selectable. Long-press and drag lifts a card, animates other cards into rearranged slots, and saves order on release. Drag reorder is disabled during search to avoid changing hidden cards. Native matched zoom navigation on supported iOS, reduced-motion fallback. No actual Apple Pay default payment changes. Existing data and native Duo dock remain intact.

## v0.4.6 card editor accessibility
Wallet root exposes a native edit toolbar item and an overflow edit fallback. With multiple cards the user selects the card by nickname and last four digits; the existing editor opens directly. Deck hit regions use Buttons independently of simultaneous long-press reordering. Detail edit and native Duo navigation retained. Device verification required.

## v0.4.7 card detail presentation
Explicit selected-card state renders the detail pane inside the existing native NavigationStack, rather than relying on a matched zoom navigation destination. Linear 0.24-second slide transition with reduced-motion fallback. Native back and edit toolbar actions, direct detail selection in overflow menu, nontransparent hit regions and post-drag tap suppression. Keep reorder and authenticated card details. Device verification required.

## v0.4.8 wallet personal information tab
Third wallet segment 개인정보 embeds the existing authenticated private vault instead of showing a separate sheet from the card list. Leaving the embedded vault locks it. Existing settings and recurring-entry sheet presentations remain available. Native Duo navigation and stored data unchanged.

## v0.4.9 bank security cards
Account-specific optional security cards: 25–50 entries, five-column numbered grid (horizontal scrolling when narrow), vertical or horizontal numbering, masked input with reveal toggle, device authentication, two-digit lookup, device-only passcode-protected Keychain storage. No screenshot values or backup/CSV inclusion. Requires device verification.

## v0.4.10 bank website details
Protected per-account website URL, ID, password with reveal control, and memo in the bank editor. Separate device-only Keychain service; never included in ledger JSON, backups or CSV. Security-card grid defaults to visible during authenticated editing, preserves leading zeroes and advances to the next code after four digits. All screenshot contents remain excluded. Device testing required.

## v0.4.11 simplified personal information
Embedded wallet personal information shows only ID and passport sections with separate add actions and fixed document types. No subscription, trash, settings or search sub-tabs in the embedded view. Existing private data and full vault functions remain available via other existing entry points; no migration deletes records. Face ID/device authentication retained; late unlock invalidated when leaving. Device verification required.

## v0.4.12 safe-area security grid, document photos, smoother card navigation
Grid sizes from real available content width; no fixed-width horizontal overflow. Five columns when width permits, three on very narrow screens. Authenticated front/back photos for payment cards, bank accounts, ID and passport: AES-GCM file encryption, device-only passcode-protected key, excluded from backups, full-screen view, replace/delete. Photo edits save independently. Card detail uses eased scale/fade while retaining explicit selection and native toolbar. Device verification required.

## v0.4.13 stable wallet header and card detail motion
All wallet sections share a fixed top-aligned header and full-height content area. The embedded identity lock fills its available space without vertically recentering the wallet header. Card detail mounts without crossfading the previous wallet page; only its own content eases in and out, with the native toolbar preserved and reduced-motion fallback. Removes duplicate navigation title and softens deck reorder easing. Device verification required.

## v0.4.14 neutral card detail and continuous transition
Card number view/copy controls use adaptive neutral gray capsules with dark/light system text; CVC badge is neutral as well. The wallet stays mounted behind the detail view, preserving deck ordering and scroll position. A single 460ms eased transition presents detail, 380ms closing transition reveals the same deck; removes delayed onAppear animation and blank frame. Original Duo system navigation, independent hit regions, and reduce-motion support remain. Authentication results invalidated when detail closes. Device verification required.

## v0.4.15 opaque card navigation
Keep one persistent native toolbar owner and the existing deck. Clip the page transition to actual safe content viewport and use an opaque eased slide rather than overlapping transparent cards and labels. Direct edit action in detail, menu fallback in wallet. Artwork fits instead of cropping; imported images with existing margins retain those margins. Existing gray actions, authentication and data retained. Device verification required.

## v0.4.16 display currency, monthly report and payment imports
Currency preference changes symbol only; no FX conversion or stored value migration. Monthly summary of completed calendar months, optional local reminder scheduled for first day at midnight, foreground summary on next unlocked launch, PNG sharing. iOS does not guarantee background execution or image generation at midnight. Apple Wallet integration uses the Record Wallet Payment App Intent with a user-configured Shortcuts automation, queued until unlocked app consumes it. Naver Pay, Kakao Pay, WeChat Pay and Apple Wallet support reviewed UTF-8 CSV import (standard template and selected header aliases), no direct account history API. Whole integer ledger amounts only; fractional or unsupported rows excluded and reported. External transaction IDs deduplicate; fallback IDs derive from row contents and occurrence. Native wallet and data retained. Device testing required.

## v0.4.17 bank logo directory
61 bank entries (KR, CN, JP, US), 27 bundled logos and clear generic fallbacks for other entries. Search, country filters, automatic logo selection for matching legacy bank names, manual entry, and automatic tone suggestions. Optional bankLogoID preserves old data decoding. Existing bank security, photos, and payment functions unchanged. See BankLogoCredits; device testing required.

## v0.4.18 bank logo expansion
50 logo assets in repository, including all 21 Korean entries and 18 Chinese entries; 11 additional Japan/US logos sourced at build time with validated SVG and actual asset availability fallback. Shinhan replaced by vector artwork with larger intrinsic size; picker icons enlarged, IBK and KB switched to locally sourced symbols. No runtime downloads, existing accounts unaffected. Some graphics reflect earlier bank branding. Build and device tests required.
