# Digital Wallet v0.4.53 / Build 60 — source candidate

Based on main commit `5d60edc01dafc66c814c488387ae63b29371334f` (v0.4.52 / Build 59).

## Implemented
- Shared 320pt maximum base width; 14pt continuous corners and 0.12 / 6pt shadow before scaling.
- One scale(forIndex:) entry point uses 0.92 + 0.08 * easeOut(index / (count - 1)). All cards share a horizontal center; top anchoring preserves equal exposed heights.
- Long press: one light haptic, 1.04 lift, deeper shadow, raised zIndex and 8% neighbor dimming. A proposed slot animates with response 0.35 / damping 0.8. The data array is persisted once after the released card settles; cancellation does not save a reorder.
- The single selected artwork uses matchedGeometryEffect against a measured anchor. A bounded damped-spring frame clock controls geometry, fades and interactive pull; it reaches an exact endpoint in 0.45 seconds. The heavy wallet root does not observe frame ticks.
- Details move/fade/blur in. On exit they fade/blur out for 0.15 seconds; siblings then return from above with 10pt initial blur, roughly 30ms stagger, and increasing opacity. Home title, segmented picker and footer fade back in during the final 0.2 seconds.
- Toolbar icons crossfade with 4pt blur and 0.8–1 scale. The app's native navigation remains outside the animated scene.
- One reset function handles completed close, navigation away, backgrounding and Reduce Motion changes. Interrupted opens reverse from the current frame.

## Configuration
`PocketLedger/Sources/WalletCardMotion.swift` begins with `AnimationConfig` (timing, scale, blur, shadows, spring response/damping). SwiftUI Animation convenience properties are in `WalletMotionDriver.swift`.

The normal spring is 0.45 / 0.82. Reorder intentionally uses the separately requested 0.35 / 0.8. SwiftUI spring response is not a strict total settling duration. The display-link transition evaluates the same damped response and normalizes/clamps its small tail for deterministic endpoints within 450ms. This is documented rather than claimed identical to SwiftUI's internal solver.

## Validation actually performed
- Tree-sitter Swift syntax parsing of all application Swift files and modified test files: passed. This is not Swift type checking or Xcode compilation.
- Original four balance-cover SHA-256 checks: passed.
- Git whitespace/conflict checks: passed.
- Full source ZIP integrity check: passed at packaging.

## Not yet verified
Xcode compilation, the Swift regression executable, simulator UI tests and physical iPhone tests have NOT run in this Linux workspace. No new IPA has been built. Publishing this branch to the public GitHub repository was blocked by automatic approval review, pending explicit permission to publish the modified source. No PR was created.

## Open / build
Open `PocketLedger.xcodeproj`, select the `PocketLedger` scheme and an iOS 17+ target. For an unsigned device build on a Mac with the project-required Xcode/SDK:

```sh
xcodebuild -project PocketLedger.xcodeproj -scheme PocketLedger -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
```

The test fixture runner in scripts/run_wallet_ui_tests.py is intentionally restricted to ephemeral CI simulators. Do not run it on a simulator containing user data. Validate six-card rendering, repeat first/middle/last open-close, interrupt opening, cancel/release pull, long-press both directions, app backgrounding, Reduce Motion and narrow/wide layouts.

The original data models, private archive, banking code storage, backup, updater and financial logic are unchanged. Source compatibility and real-device animation acceptance remain pending actual build/test.
