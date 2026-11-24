import SwiftUI
import QuartzCore
import UIKit

// One frame clock updates all card layers in the same non-animated transaction.
// SwiftUI therefore never has independent opacity/offset animations to finish
// after the detail has already been removed (the Build 55 blank-deck regression).
@MainActor
final class WalletMotionDriver: ObservableObject {
    @Published private(set) var value: CGFloat = 0
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
    func animate(to value: CGFloat, duration: TimeInterval, eased: Bool = false, completion: @escaping () -> Void) {
        invalidate()
        track.animate(to: value, at: CACurrentMediaTime(), duration: duration, eased: eased)
        self.completion = completion
        if !track.running { finish(); return }
        target.owner = self
        let link = CADisplayLink(target: target, selector: #selector(Target.tick(_:)))
        self.link = link
        // Follow the current display rate rather than CADisplayLink's default.
        // This is a scheduling preference, not proof of achieved frame rate.
        let maximum = Float(UIScreen.main.maximumFramesPerSecond)
        link.preferredFrameRateRange = CAFrameRateRange(minimum: min(60, maximum), maximum: maximum, preferred: maximum)
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
    }
    deinit { link?.invalidate() }
}
