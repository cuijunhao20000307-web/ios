import Foundation
import CoreGraphics

// Shared geometry for selection, interactive return and release decisions.
// This contains no wallet data and can also run in the command-line regression check.
enum WalletCardMotion {
    static let duration = 0.36

    static func frame(source: CGRect, destination: CGRect, progress: CGFloat) -> CGRect {
        let p = min(1, max(0, progress))
        return CGRect(x: source.minX + (destination.minX - source.minX) * p,
                      y: source.minY + (destination.minY - source.minY) * p,
                      width: source.width + (destination.width - source.width) * p,
                      height: source.height + (destination.height - source.height) * p)
    }

    static func visibleHeight(source: CGRect, current: CGRect, visibleFraction: CGFloat,
                              retreat: CGFloat, progress: CGFloat) -> CGFloat {
        guard visibleFraction < 1 else { return current.height }
        let occludingEdge = source.minY + source.height * visibleFraction + retreat * progress
        return min(current.height, max(0, occludingEdge - current.minY))
    }

    static func returnDistance(source: CGRect?, destination: CGRect) -> CGFloat {
        guard let source else { return 180 }
        let distance = abs(source.minY - destination.minY)
        return distance > 1 ? distance : 180
    }

    static func progress(translation: CGFloat, distance: CGFloat) -> CGFloat {
        1 - min(1, max(0, translation) / max(1, distance))
    }

    static func shouldDismiss(translation: CGFloat, velocity: CGFloat, distance: CGFloat) -> Bool {
        let threshold = min(105, max(24, distance * 0.4))
        // An intentional reversal cancels a projected fling.
        if velocity < -180 { return false }
        return translation >= threshold ||
            (translation >= min(48, threshold) && velocity > 350 && translation + velocity * 0.18 >= threshold)
    }
}

// A retargetable linear track holds the *displayed* value, not an implicit
// animation's destination. It cannot keep an invisible deck at the old endpoint.
struct WalletLinearTrack {
    private(set) var value: CGFloat = 0
    private var origin: CGFloat = 0
    private var target: CGFloat = 0
    private var start: TimeInterval = 0
    private var duration: TimeInterval = 0
    private(set) var running = false

    mutating func set(_ value: CGFloat) {
        self.value = value
        running = false
    }
    mutating func animate(to target: CGFloat, at time: TimeInterval, duration: TimeInterval) {
        origin = value
        self.target = target
        start = time
        self.duration = max(0, duration)
        running = duration > 0 && origin != target
        if !running { value = target }
    }
    @discardableResult mutating func advance(to time: TimeInterval) -> Bool {
        guard running else { return false }
        let fraction = min(1, max(0, (time - start) / duration))
        value = origin + (target - origin) * fraction
        if fraction == 1 { value = target; running = false }
        return !running
    }
}

enum WalletDeckFan {
    static func offset(index: Int, anchor: Int, translation: CGFloat, height: CGFloat, step: CGFloat) -> CGFloat {
        let travel = min(height, max(-height, translation))
        let spread = min(height - step, abs(travel) * 0.65)
        return travel + CGFloat(index - anchor) * spread
    }
    static func anchor(at y: CGFloat, step: CGFloat, count: Int) -> Int {
        min(max(0, Int(max(0, y) / max(1, step))), max(0, count - 1))
    }
}
