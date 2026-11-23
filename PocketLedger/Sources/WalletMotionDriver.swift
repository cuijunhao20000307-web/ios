import SwiftUI
import QuartzCore

extension AnimationConfig {
    static var spring: Animation { .spring(response: response, dampingFraction: damping) }
    static var reorderSpring: Animation {
        .spring(response: reorderResponse, dampingFraction: reorderDamping)
    }
}

// One frame clock updates all card layers in the same non-animated transaction.
// SwiftUI therefore never has independent opacity/offset animations to finish
// after the detail has already been removed (the Build 55 blank-deck regression).
@MainActor
final class WalletMotionDriver: ObservableObject {
    @Published private(set) var value: CGFloat = 0
    private(set) var elapsed: TimeInterval = 0
    private var track = WalletLinearTrack()
    private var link: CADisplayLink?
    private var completion: (() -> Void)?

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
    func animate(to value: CGFloat, duration: TimeInterval, spring: Bool = false, completion: @escaping () -> Void) {
        invalidate()
        track.animate(to: value, at: CACurrentMediaTime(), duration: duration, spring: spring)
        elapsed = 0
        self.completion = completion
        if !track.running { finish(); return }
        target.owner = self
        let link = CADisplayLink(target: target, selector: #selector(Target.tick(_:)))
        self.link = link
        link.add(to: .main, forMode: .common)
    }
    private func tick(_ link: CADisplayLink) {
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
            elapsed = track.elapsed
            value = track.value
            action?()
        }
    }
    private func publish(_ value: CGFloat) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            elapsed = track.elapsed
            self.value = value
        }
    }
    private func invalidate() {
        link?.invalidate()
        link = nil
        completion = nil
    }
    deinit { link?.invalidate() }
}
