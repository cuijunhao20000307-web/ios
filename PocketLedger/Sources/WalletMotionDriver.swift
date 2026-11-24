import SwiftUI
import QuartzCore

// One frame clock updates all card layers in the same non-animated transaction.
// SwiftUI therefore never has independent opacity/offset animations to finish
// after the detail has already been removed (the Build 55 blank-deck regression).
@MainActor
final class WalletMotionDriver: ObservableObject {
    @Published private(set) var value: CGFloat = 0
    private var track = WalletLinearTrack()
    private var link: CADisplayLink?
    private var completion: (() -> Void)?
    private var pendingStart: (target: CGFloat, duration: TimeInterval)?

    @MainActor private final class Target: NSObject {
        weak var owner: WalletMotionDriver?
        @objc func tick(_ link: CADisplayLink) { owner?.tick(link) }
    }
    private let target = Target()

    func set(_ value: CGFloat) {
        invalidate()
        track.set(value)
        publish(value)
    }
    func animate(to value: CGFloat, duration: TimeInterval, completion: @escaping () -> Void) {
        invalidate()
        self.completion = completion
        if duration <= 0 || track.value == value {
            track.set(value)
            finish()
            return
        }
        pendingStart = (value, duration)
        target.owner = self
        let link = CADisplayLink(target: target, selector: #selector(Target.tick(_:)))
        self.link = link
        link.add(to: .main, forMode: .common)
    }
    private func tick(_ link: CADisplayLink) {
        if let start = pendingStart {
            pendingStart = nil
            track.animate(to: start.target, at: link.targetTimestamp, duration: start.duration)
            publish(track.value)
            return
        }
        if track.advance(to: link.targetTimestamp) { finish() }
        else { publish(track.value) }
    }
    private func finish() {
        link?.invalidate()
        link = nil
        let action = completion
        completion = nil
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            value = track.value
            action?()
        }
    }
    private func publish(_ value: CGFloat) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { self.value = value }
    }
    private func invalidate() {
        link?.invalidate()
        link = nil
        completion = nil
        pendingStart = nil
    }
    deinit { link?.invalidate() }
}
