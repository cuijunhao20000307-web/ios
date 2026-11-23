# Wallet motion validation — v0.4.49 / Build 56

## Build 56 regression and verification

The new user feedback video demonstrates a persistent blank deck after returning, while the same hit strips still open details. A second 5.19-second native reference explicitly requests ordinary interactive fan/accordion browsing. Both are now in scope; the previous patch omitted browsing.

The new `WalletMotionDriver` publishes actual displayed progress on CADisplayLink, in one transaction with implicit animation disabled. A retargetable track handles interrupted opening and cancelled pulls. Idle decks explicitly use zero transition progress and the render-only artwork identities are refreshed on return; touch targets and root scroll identity remain unchanged. Destination geometry is frozen during the transition. Background cards stay opaque beneath a stationary fading backdrop, avoiding the prior double page crossfade.

`WalletDeckFan` moves the touched card with the drag and spreads neighbors around it. A scoped UIKit recognizer suspends the surrounding scroll only while browsing, restores it on release/cancellation, and yields if long-press sorting has started. Only the original reorder callback writes order.

CI runs `WalletUITests` on compact and wide iOS simulators with a synthetic six-card ledger. It checks actual colored pixels in each exposed strip after repeated first/middle/last selections and returns, interrupted opening, up/down browsing, short pull cancellation, and full pull dismissal. A post-test file check verifies persisted card IDs remain in the original order. Test movies and xcresult bundles are uploaded. These checks do not replace real Duo testing.

## Reference observations

Primary reference: the locally supplied `ScreenRecording_11-23-2026 22-49-49_1.mov` (21.6 seconds, approximately 59 fps). Also reviewed the handoff's native, desired-motion, existing-app and failed-return recordings. Recordings and frames remain outside this public repository.

- Approximately 14.51–14.87 seconds: the selected foreground card moves from its current stack position toward the top. Its artwork remains spatially continuous, the remaining stack retreats, and transaction details appear beneath it.
- Approximately 13.27–13.84 seconds: return restores the stack while the selected card returns to its stack position and the lower foreground card re-enters from below.
- The native recording also contains interactive stack browsing and payment/default-card system behavior. The app now supports ordinary interactive stack browsing as well as card-to-detail selection/return and its separate long-press ordering. System payment/default-card behavior is not part of this local ledger.

## Implemented behavior

The actual source frame includes its deck slot and scroll position. The target uses the unchanged detail layout, including DuoColumns and text layout. A persistent render-only card layer interpolates the two rectangles and continuously reveals the initially exposed strip, avoiding an immediate flash of the hidden artwork; ownership returns to the protected detail artwork only at rest. Background cards use the same transition progress. There is no selected-card slot reassignment or delayed page entrance. Animation completion is guarded against stale callbacks.

The pull recognizer begins only on the measured header/card region, with downward vertical velocity, while the existing detail scroll view is at its top. It observes simultaneously with that scroll view and suppresses its bounce while the dismissal is tracking. Starting on other content remains normal scrolling. Cancellation and upward reversal restore detail. Dismissal never mutates stored order. Reduce Motion skips spatial transforms.

## Automated checks

- `swiftc PocketLedger/Sources/WalletCardMotion.swift tests/WalletCardMotionTests.swift -o /tmp/wallet-motion-tests && /tmp/wallet-motion-tests`: endpoints, exact reverse path, aspect ratio across compact/expanded sizes, drag clamping and release thresholds.
- `python3 scripts/verify_balance_covers.py`: original dimensions and SHA-256 values.
- CI: full iPhoneOS Release compilation with signing disabled; `verify_balance_covers.py --app ...` verifies compiled Asset Catalog names before packaging.
- Existing bank-logo resources are retained; the legacy download script now only fills missing image sets.
- IPA packaging checks ZIP integrity. App bundle identifier and data models are unchanged.

## Still required on physical devices

All items below remain unverified until performed; passing CI is insufficient.

- [ ] Duo outer and inner screens: first/middle/last card tap, correct original size and exposed-strip hit regions, visible stack hint.
- [ ] Compare opening and closing footage against the native reference, including synchronized upper/lower background movement and frame pacing.
- [ ] Slow pull, short release, fast release, upward reversal, OS interruption, rapid close during opening, and toolbar close; confirm no jump or stranded overlay.
- [ ] Long-press reorder, search-filtered cards, list/grid mode, scrolled stack, and exact original order/scroll position after return.
- [ ] Transaction scrolling and editing, card-number/CVC controls, protected photo viewer, dynamic type, orientation/fold change while open, and Reduce Motion.
- [ ] Face ID/device passcode, account/security-card lookup, ledger editing, encrypted backup/restore and online update regression checks.
- [ ] All four currency covers in the installed app, including existing locally imported overrides.

The IPA is unsigned and requires the user's normal signing/provisioning process before device installation.
