# PocketLedger v0.4.56

## v0.4.56 / Build 63 — refine interactive presentation on the restored baseline
The device video shows disconnected background strips moving across the viewport during repeated pulls, metadata vanishing early and home chrome appearing only at reset. Keep the Build 59/62 layout, card measurement, tap regions and gestures. Limit decorative sibling retreat to -24/+32pt with a slight depth scale/blur; fade the home header/footer with the same displayed progress, bring details in earlier and add a subtle 10pt rise and blur. The source deck remains mounted and only its artwork is hidden while the scene is active; one selected artwork remains visible. Forward and reverse effects are continuous functions of the same interactive progress, within 420ms for a full transition. Device acceptance remains pending and must not be inferred from compilation.


## v0.4.55 / Build 62 — restore the morning Build 59 wallet implementation
The physical-device feedback for Builds 60 and 61 reports lowered placement, unresponsive card taps and failed card switching. At the user's request, restore WalletView.swift, WalletMotionDriver.swift, WalletCardMotion.swift and their tests byte-for-byte from the morning Build 59 commit 5d60edc01dafc66c814c488387ae63b29371334f. This restores the prior layout, detail header order, linear transition, tap strips, browsing and GestureState-based long-press handling. Remove the experimental shared-anchor spring presentation and persistent drag/tap-suppression state through that restoration. Existing stored order is retained; any order already changed in the app remains user data. Version metadata is incremented to deliver the recovery as an update. Do not claim new animation improvements or hardware acceptance; device confirmation remains required.


## v0.4.54 / Build 61 — correct the real card return coordinates
The November 24 device recording shows the selected bottom card returning to the first slot before jumping down, with background cards appearing only at the final reset. Build 60 measured a background outside the artwork's offset modifiers; all source frames therefore used the unshifted layout Y. Measure the deck once and derive each resting frame from its actual slot, centered scale and scroll offset. This also restores nonzero exposed-strip masks for background cards. Add first/middle/last, six/eight-card and scrolled-deck geometry regressions. Keep artwork, account data, interactions and animation settings unchanged. Simulator preparation now overlaps boot with compilation, uses only the active architecture and logs/bounds each command. Physical-device visual acceptance is still required.


## v0.4.53 / Build 60 — centered card stack and coordinated spring motion
The stack uses a shared base width, 14pt clipping, a centered 0.92–1 ease-out scale and a subtle per-card shadow. Long press lifts the card with haptics, dims its neighbors, animates vacant slots and commits order only after snapping into place. Selection keeps one artwork layer linked by matchedGeometryEffect to a measured moving anchor, with spring-driven scale and interactive pull-down. Closing fades/blurs details over 150ms, returns sibling strips from above at 30ms intervals and restores all home chrome in the final 200ms. AnimationConfig holds timing, spring and appearance parameters. Existing data, private storage, currency art and native navigation remain intact.

The presentation frame clock evaluates the configured damped spring and normalizes its endpoint to a 450ms budget. Reorder uses SwiftUI's requested 0.35 / 0.8 spring; settling may outlast its response parameter. Build and physical-device verification results are recorded separately; source changes do not establish real-device visual acceptance.


## v0.4.52 / Build 59 — soft fade and smooth card return
The user's November 24 exit-video shows full background card faces overlapping as the selected card flies back into its original exposed slot. Card siblings now stay withdrawn until the late part of the reverse animation, then return with a smoothstep movement curve. Their artwork is clipped to its measured original visible strip so adjacent cards never temporarily reveal full faces. The background card alpha and detail metadata alpha use gentler smoothstep fade windows, kept strictly non-overlapping to prevent ghosted double pages. Selecting and returning uses the same reversible progress function, while the selected flying card remains above all sibling cards. Performance optimizations, privacy, bank images, balances and all existing functions are preserved. Real iPhone Duo acceptance remains pending.



## v0.4.51 / Build 58 — smooth card transition optimization
A perceived dropped-frame regression was reported on the physical iPhone Duo with Build 57. Build 58 isolates CADisplayLink's animation progress in a dedicated observed SwiftUI scene; updating progress no longer invalidates the entire NavigationStack, card deck, accounts list and ledger content. The flying selected card uses a constant source layout, compositor scaling and positioning rather than reshaping its card content each frame. Card artwork UIImage providers are cached in memory, invalidated by card ID and a lightweight data fingerprint. Selection and reverse transitions retain their geometric endpoints, fade envelopes, protected card data and original 2240×1000 currency cover assets. The symptom has not yet been remeasured on a physical Duo; a successful compile cannot establish 60/120 fps.



## v0.4.50 / Build 57 — single card scene, no ghosted crossfade
Based on three November 24 recordings (Build 56 residual/ghost UI and two Apple Wallet reference videos), opening and closing no longer crossfade two entire wallet pages. The root wallet remains mounted for exact geometry and scroll position but becomes visually hidden during a transition; on an opaque canvas, measured background-card sprites retreat above/below while **one selected card** moves in one continuous linear path. Detail UI comes in after the other cards have left, eliminating doubled card faces and labels. Closing reverses the same path; long-press reorder, normal browsing, cards and financial data remain unchanged. A pure Swift regression test asserts that the background-card opacity and detail metadata opacity envelopes never overlap. Hardware visual parity is still unverified.



## v0.4.49 Restore returned deck and add drag browsing (Build 56)
Addresses the Build 55 recording where the card artwork disappeared after return while invisible tap strips remained active. One display-link clock now publishes the actual linear progress for all layers with implicit animations disabled. Closing retargets from the displayed frame; completion resets selection and refreshes only the render-only card layer, keeping the original scroll view, hit strips and saved order. Destination measurement is frozen during motion. A stationary background replaces the moving translucent full-page background that caused ghosted pages.

Ordinary vertical dragging within the stack now fans cards around the touched strip, with neighboring cards moving together and a linear return on release. Browsing does not save order. Holding first retains the existing long-press reorder. Original artwork, dimensions, covers, protected data and all other features remain. CI runs real pixel-visibility and gesture regression tests on compact and wide simulators before packaging. Physical Duo verification and comparison with native Wallet remain pending.

## v0.4.48 Geometry-linked card selection and original covers (Build 55)
Card selection now uses the card's measured stack/grid rectangle and the existing detail card's measured rectangle. One artwork layer travels between them with a shared 360ms linear progress; upper background cards retreat and lower cards move below the viewport at the same time. Returning reverses that geometry without changing persisted order. Animation completion replaces fixed delay timers. A downward pan beginning inside the actual header/card region at scroll-top drives the same progress, while controls and transaction scrolling keep their existing behavior. Short/cancelled pulls return to the detail; Reduce Motion omits spatial motion. Existing card dimensions, exposed-strip hit regions, long-press reorder, DuoColumns, protected data and all other features are retained.

The unmodified 2240×1000 KRW/CNY/JPY/USD original covers are now tracked in Assets.xcassets under the existing balance-cover-{CODE} names. Local imported covers retain priority. The logo-fetch step now only fills missing resources and keeps all bundled bank artwork unchanged. CI verifies source hashes, motion geometry/release decisions and the four names in the compiled Assets.car before publishing an unsigned IPA.

Physical-device verification and visual acceptance are still pending. See [validation notes](docs/WALLET_MOTION_VALIDATION.md); compilation alone does not establish Apple Wallet parity.

## v0.4.47 Continuous linear card animation and reliable pull-down return (Build 54)
The Wallet card stack and details are linked to one explicit 360ms linear transition progress rather than a delayed two-stage card shuffle + page insertion. The selected card advances smoothly while other cards recede and the detail slides up and fades in. Closing or dragging the detail down reverses that same progress, leaving the physical card order unchanged. The pull-down recognizer is attached to the full detail overlay, with a guarded header/card start region, instead of competing with the card's nested ScrollView. Short drags spring back; long or fast downward drags dismiss. The card sizes and touch regions, auto reorder gesture, bank images, backups, online update, and all account features are preserved. Reduce Motion skips slide motion.


## v0.4.46 Apple-style card auto-switch and readable hint (Build 53)
When a stacked card is tapped, the selected card first animates to the front/bottom of the stack while neighboring cards slide to their new visual slots (260ms linear); only after that transition does the card detail slide up and fade in. The visual focus never writes to persistent card order. Closing returns the stack to its original positions. The stack card width is reduced from 365 to 320 points and overlap from 43–58 to 35–46 points so the bottom reordering hint is visible on the Duo inner screen. Card artwork aspect ratio, existing touch/long-press controls, details, and other sections are preserved. Accessibility Reduce Motion skips the staged delay.


## v0.4.45 Unlock screen uses actual app icon (Build 52)
Replace the generic blue lock shield on the protected-ledger launch screen with the same artwork as the installed app icon, using a duplicated runtime image asset referencing the existing AppIcon PNG blob. Keep all authentication, copy, button, screen layout and iPhone Duo behavior unchanged.


## v0.4.44 Split water and electricity expenses (Build 51)
The old combined "Bills/水电杂费/공과금" entry choice is replaced by two distinct categories: Water bill (水费/수도 요금) and Electricity bill (电费/전기 요금). Both are available in regular transaction entry, CSV import categorization and monthly fixed expense schedules, with distinct SF symbols, colors and individual statistics. The legacy combined enum case remains decodable and visible for previously stored records / existing recurring schedules, but is hidden from new entry selectors. Old transactions are not guessed or reassigned to water or electricity, protecting the historical ledger and backups. Card UI and animation are unchanged.


## v0.4.43 Native-style background card retreat (Build 50)
Choosing a bank card animates the unselected cards backward (slight scale reduction, rising depth offset and subtle dimming) while the chosen card lifts and the detail opens from the bottom with a linear slide-and-fade. Returning or swiping down to dismiss reverses these motions. Only the render-only card art receives the depth transform; the existing touch zones, card order, spacing, scroll view, internal/external layouts and drag-to-reorder mechanics remain unchanged. Reduce Motion disables decorative depth. Includes all prior backup, online update, security card and fixed expense features.


## v0.4.42 Vertical slide + fade card details, swipe-down dismissal (Build 49)
The **original** Wallet card stack, card sizes, tap target regions, toolbar, scrolling, detail information and inner/outer layouts are unchanged. Card detail now enters from the bottom and fades in, and closes downward while fading out using linear timing. Press and drag down on the detail card art to interactively move and fade the entire detail overlay; a meaningful swipe dismisses it, and short drags return to rest. The existing back/close action still works. Swipe-to-dismiss attaches only to the card art to avoid stealing gestures from transaction lists and other scroll content. Accessibility Reduce Motion still reduces the transition. All v0.4.41 updater, security card and backup changes remain.


## v0.4.41 Download updates from inside app (Build 48)
Settings > Online Updates now discovers official GitHub Releases with HTTPS IPA assets and offers an in-app Download IPA action, validates the downloaded ZIP header/size, and opens the iOS share sheet so it can be saved or sent to a user-selected signing/install tool. The GitHub Actions workflow publishes unsigned IPAs as versioned release assets after successful builds; this makes direct downloads possible without a personal GitHub API token. Unsigned IPA apps cannot silently sign or install themselves; re-sign/reinstall with the same bundle ID and compatible signing identity to preserve data, and back up first. The historical card layout and linear animation remain unchanged.


## v0.4.40 Restore original wallet layout, linear card motion (Build 47)
Reverted the experimental Duo cinematic card layout. The wallet's original stack/list geometry, toolbar, tap regions, scrolling, card detail screen and interactions are restored from the previously working v0.4.34. Only the opening, closing and reordering animation curves are linear. Keeps all newer security card, monthly expenses, backup restore and online update fixes.


## v0.4.39 Online updates (Build 46)
Settings > Online updates now checks the official repository over HTTPS and compares numeric app versions with the installed version. Published GitHub Releases containing an IPA are preferred; while this repo has no Releases, the latest successful, non-expired GitHub Actions unsigned IPA artifact is offered as a fallback, with a link to its Actions run. The app never downloads private user data or sends wallet contents to GitHub. There is no silent on-device installation of unsigned IPAs on iOS. Users must sign and install with their own sideloading method and should back up first. No new update entitlement or App Store dependency is required.


## v0.4.38 Adaptive five-column security card grid (Build 45)
The Face ID-protected read-only security-card grid and the editing grid now fit their available width on inner and cover screens without any horizontal scrolling. They preserve five columns and the original printed card positions, adapt typography and inter-column spacing on narrow layouts, and avoid the previous hard-coded minimum of 380pt which cropped edge columns. Existing stored codes, two-digit forward/reverse lookup, monthly fixed expenses and backup restore behavior are unchanged.


## v0.4.37 Fixed monthly expenses (Build 44)
Added Credit card repayment and Mobile phone bill spending categories with localized labels. The new Settings > Monthly fixed expenses sheet and Recurring tab let users add, edit, pause or delete monthly expenses, choose category, amount (KRW), due day (1–31), start date and optional payment source. Existing salary schedules are unchanged. Entries post when the app is next opened after the due date; months without the selected day use their final day. Existing posted entries remain unchanged when a rule is edited. Existing recurring IDs prevent duplicate automatic entries for the same month. Credit card repayments may double count spending if individual purchases are already recorded. The independent iCloud backup restore password input fix remains included.


## v0.4.36 Backup restore password entry (Build 43)
The iCloud Drive backup screen now separates creation and recovery passwords. Creation still requires a new password and confirmation in its own section. When restoring, choose a backup file and enter its existing password **once** directly under the Restore section to inspect it. Decryption no longer reads the create-backup inputs. The password is cleared after successful verification; the user must separately confirm destructive restoration and pass device authentication. Backup format and encryption are unchanged.


## v0.4.35 Duo card-stack animation (Build 42)
The card wallet now uses reference-specific internal and external screen layouts: a center stack collapses into a left-side selected card with a right-side transaction list on the inner screen, while the outer screen expands the selected card to the top and displays transactions below it. Motion remains a continuous transform of the same card rather than switching to a full-screen trailing slide. Custom card artwork, two-digit security-card lookup, long-press drag-to-reorder, transaction editing and the original card-detail screen remain supported. App behavior and physical dimensions require real Duo verification; iOS Reduce Motion is respected.


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

## v0.4.19 currency-specific dashboard covers
KRW/CNY/JPY/USD select the corresponding balance-cover-{CODE} asset, or an imported original 2240x1000 PNG, automatically. Settings offers multi-file import by filename prefix. Imported artwork remains on-device; no change to balance amounts. Other currencies and missing covers fall back to original gradient. Assets maintain 2.24:1 with no crop, with left-side contrast scrim and bounded width on Duo. The four conversation uploads are supplied separately as an asset pack; they are not yet bundled in the repository. Device testing required.

## Digital Wallet display name
Home screen display name and bundle name: **Digital Wallet**. Executable name and bundle identifier are kept unchanged for side-load updates and to preserve app data. Updated in-app settings branding, local monthly notification title, and monthly summary branding. Existing v0.4.19 build remains compatible with original 2240x1000 currency-cover artwork. The renamed cover-bundled unsigned IPA is supplied as a repackaged artifact.

## Digital Wallet v0.4.20 Duo card detail and multilingual document input
Card detail left pane places monthly spending below card artwork and shows this card's current month expense records, with tap to edit; right pane keeps card information and photos. For identity and passport fields, use installed iOS Chinese, Korean, Japanese, English or system keyboards via a native UITextField input-mode selector, plus instructions for installing missing keyboards in iOS Settings. Hidden fields remain protected; show temporarily to enter CJK characters on iOS configurations where secure input disallows IME composition. Existing data and bundle ID unchanged. Device testing required.

## Digital Wallet v0.4.21 iCloud Drive backup and Shortcuts setup
Password-protected AES-256-GCM archive (PBKDF2-HMAC-SHA256, 600k iterations) through the iOS Files picker. The user explicitly selects iCloud Drive for save and restore; unsigned side-loaded builds cannot silently sync via iCloud without provisioning capabilities. Includes ledger, private Keychain archive, protected document/card photos and basic currency/language preferences. Bank login passwords, account secrets, website credentials, security cards and device-only keys are deliberately excluded and remain on their original device. Restore requires reauthentication, password, validation, and destructive confirmation with rollback attempt. iCloud file location and available storage depend on iOS settings. Apple Pay action is exposed to Shortcuts and a settings button opens Shortcuts with transaction trigger guidance. Personal automations cannot be created directly by another app. Real-device verification required.

## Digital Wallet v0.4.22 — Duo settings icon and destructive confirmation
The system automatic menu placement row uses a custom grey vector D/Duo icon matching the supplied reference. Sample-data replacement and destructive ledger reset no longer use the popover-style `confirmationDialog` that clips on expanded Duo. Both display a centered, viewport-bounded custom modal with a dimmed backdrop, explicit Cancel and red destructive confirmation, and localized explanatory text. The private vault remains independent. No data schema or bundle identifier changes. Verify on folded and unfolded device sizes.

## Digital Wallet v0.4.23 compact settings on Duo
Settings cards now use 11pt vertical and 14pt horizontal padding, 10pt intra-column spacing, and 12pt between Duo columns; key selectors and monthly budget are aligned into single rows. The long automatic-layout help and app-information text are still accessible via collapsed disclosure controls. All settings controls, security, iCloud backup, private vault and payment integration are retained. Wallet data and Bundle ID are unchanged. Needs on-device unfolded/folded verification.

## Digital Wallet v0.4.24 currency selector single-line fix
Replaces the currency Picker's automatic label with an accessible Menu whose value label stays on one line (e.g., KRW · ₩ · 韩元) and arrow stays adjacent. DisplayCurrency code, symbol, localized label and selection behavior are unchanged; selected currency continues to flow through AppStorage. Long strings can scale down in narrow columns. Existing compact settings, Duo adaptive layout, encrypted backup and photo assets preserved. Needs on-device layout validation.

## Digital Wallet v0.4.25: monthly-budget save button UI
Changed the monthly-budget inline Save text to a blue pill with a save icon. After tapping it, a green check and localized 'Saved' label confirms the updated value. The button holds a fixed width so currency, amount, and title stay in one compact row on Duo. The feedback clears as soon as the user edits the amount. No model or bundle identifier changes.

## Digital Wallet v0.4.26 automatic Face ID launch and native Duo add-transaction rail action
AppShell now presents device owner authentication automatically once per app activation when app lock is enabled, rather than requiring the initial button press. The native lock screen remains visible until verification succeeds. LAContext may transiently make the app inactive, which no longer cancels auth or triggers duplicate prompts. Backgrounding invalidates outstanding results and locks the app; cancellation leaves an explicit retry button. Enabling the lock automatically prompts once as well. History uses an extra native tab action entry while the history tab is selected, presented in the system rail on Duo (subject to iOS tab overflow). It opens TransactionForm and immediately restores the history tab. The original header plus is retained only on compact layouts, as a fallback on standard iPhones. Existing data and Bundle ID are unchanged. Run on-device validation especially for biometric scene transitions and system rail overflow.

## Digital Wallet v0.4.27: polished Duo layout symbol
Replaces the old 27×27 programmatically drawn near-D icon with a transparent PNG reconstructed from the user's second image reference, including a distinct dot and bottom pill. The source image is a 256×334 portrait asset, tinted as a monochrome template and displayed at 35×44 points with no background rectangle. Old SwiftUI Path removed; existing data, iCloud backup and Face ID remain unchanged.

## Digital Wallet v0.4.28 — automatic layout without menu setting
Removed the entire Menu position / system automatic layout section and unused Duo icon asset. The existing native SwiftUI TabView automatically uses normal iPhone bottom tabs, and system-managed navigation where supported on Duo. Existing responsive DuoColumns selects columns based on available viewport, not device identity. No additional switch, model detection, data migration or user setup. Retains the same Bundle ID, app data and backup compatibility.

## Digital Wallet v0.4.29 — 11 missing bank logos restored
After auditing all 61 `BankDirectory.entries` asset references against `Assets.xcassets`, filled seven missing JP and four missing US image sets. Nine SVG source files are scalable and one further JP historic symbol is a carefully drawn simplified representation; the remaining US PNC logo is a 256px PNG. Existing IDs and stored banking data are unchanged. Sources are documented in BankLogoCredits. The SBI Sumishin bank has rebranded and its legacy list entry is preserved for stored-account compatibility. All bank logos are trademarks of their owners. iCloud, cards and Face ID unaffected.

## Digital Wallet v0.4.30 — legible bank wordmarks
Keeps the 11 already-bundled Japanese and U.S. vector/logo resources from v0.4.29, with no runtime requests. Widely rectangular bank logo assets (Japan Post Bank, Rakuten Bank, Sony Bank, Truist and PNC) may now use a 1.55× wide frame in the bank-selection grid, rather than forcing the entire wordmark into a 40×40 square. The picker uses a minimum 166-point card width so names remain legible and layout can reduce columns on smaller displays. Square emblems and bank-account rows keep their previous footprint. No changes to stored account IDs, bundle ID or ledger data.

## Digital Wallet v0.4.31 — bank security card visibility fix
The bank account editor now opens the saved card's view instead of always forcing edit mode. The security-card lookup view shows the saved 4-digit code count and a 'View saved security card' action. It requires a fresh device-owner authentication, then displays a responsive read-only 25–50-entry grid, with missing codes represented by a dash. Data is loaded from existing Keychain BankSecurityStorage; nothing is re-created, migrated or uploaded. Codes are marked privacy sensitive and hidden on app inactivity/background/close. Existing query-by-number and editing flows remain intact. No Bundle ID change, Keychain migration or backup inclusion of the banking security codes. The full code grid is sensitive: do not screenshot, share or publish it.

## Digital Wallet v0.4.32 — Security card printed layout fix
The authenticated read-only security card grid uses five fixed numbered columns on every phone size. Thirty-code security cards always map the first display row to 01, 07, 13, 19, 25 and the next row to 02, 08, 14, 20, 26. Full four-digit codes are visually split into two groups of two digits (format only). On narrow screens the entire grid scrolls horizontally instead of reordering IDs. The editor grid also keeps five stable columns; stored index and Keychain schema do not change. Never commit or log bank authentication codes.

## Digital Wallet v0.4.33 — bank-independent paired security-card lookup
All saved banks use the same UI and `BankSecurityCard.matches(firstTwo:)` helper. Each stored four-digit row is interpreted as two separate two-digit pairs: first two digits and last two digits. The full-view table shows a visible divider between the pairs, without altering saved Keychain codes or numbered positions. In the lookup panel users now enter the first *two digits*, not the printed position number, and get the matching last two digits. Match strings preserve leading zeros. When first-pair values repeat, the UI presents all matching printed card positions rather than assuming a unique response. No values are logged, copied to the repository, synced, or included in the IPA. This is a local lookup aid and does not imply every financial institution's official verification procedure follows this scheme.
