import Foundation
import CoreGraphics

// All timing and geometry controls for the wallet presentation live here.
// Reordering deliberately uses the user's faster 0.35 / 0.8 spring.
struct AnimationConfig {
    static let duration: TimeInterval = 0.45
    static let response: TimeInterval = 0.45
    static let damping: Double = 0.82
    static let reorderResponse: TimeInterval = 0.35
    static let reorderDamping: Double = 0.8
    static let detailFadeOut: TimeInterval = 0.15
    static let chromeFade: TimeInterval = 0.20
    static let stagger: TimeInterval = 0.03
    static let cardBlur: CGFloat = 10
    static let detailBlur: CGFloat = 8
    static let iconBlur: CGFloat = 4
    static let iconScale: CGFloat = 0.8
    static let backScale: CGFloat = 0.92
    static let liftedScale: CGFloat = 1.04
    static let dimming: Double = 0.08
    static let cornerRadius: CGFloat = 14
    static let shadowRadius: CGFloat = 6
    static let shadowOpacity: Double = 0.12
    static let returnOffset: CGFloat = 64

    static func easeOut(_ value: CGFloat) -> CGFloat {
        let t = min(1, max(0, value))
        return 1 - (1 - t) * (1 - t)
    }
    static func scale(forIndex index: Int, count: Int) -> CGFloat {
        guard count > 1 else { return 1 }
        return backScale + (1 - backScale) * easeOut(CGFloat(index) / CGFloat(count - 1))
    }
    // Same damped spring parameters as SwiftUI; normalize the small remaining
    // tail so the frame clock reaches an exact endpoint at 0.45 seconds.
    static func springProgress(_ fraction: CGFloat) -> CGFloat {
        let t = Double(min(1, max(0, fraction)))
        let omega = 2 * Double.pi / response
        let wd = omega * sqrt(1 - damping * damping)
        func sample(_ time: Double) -> Double {
            1 - exp(-damping * omega * time) *
                (cos(wd * time) + damping * omega / wd * sin(wd * time))
        }
        return min(1, max(0, CGFloat(sample(t * duration) / sample(duration))))
    }
    static func returnDelay(index: Int, count: Int) -> TimeInterval {
        let interval = min(stagger, 0.15 / Double(max(1, count - 1)))
        return detailFadeOut + Double(index) * interval
    }
    static func returnProgress(elapsed: TimeInterval, index: Int, count: Int) -> CGFloat {
        // Detail fades first. Six cards then start at 30ms intervals and all
        // reach their exact home slots within the same 450ms budget.
        let delay = returnDelay(index: index, count: count)
        return springProgress(CGFloat((elapsed - delay) / max(0.01, duration - delay)))
    }
    static func fade(_ fraction: CGFloat) -> CGFloat {
        let t = min(1, max(0, fraction))
        return t * t * (3 - 2 * t)
    }
}

// Shared geometry for selection, interactive return and release decisions.
// This contains no wallet data and can also run in the command-line regression check.
enum WalletCardMotion {
    static let duration = AnimationConfig.duration

    // Apply a compositor scale to fixed-size card content instead of changing
    // the SwiftUI layout size on every animation frame.
    static func flightScale(source: CGRect, destination: CGRect, progress: CGFloat) -> CGFloat {
        frame(source: source, destination: destination, progress: progress).width / max(source.width, 1)
    }

    // Smoothstep eases both fade endpoints while preserving disjoint
    // visibility windows: never alpha-blend two complete wallet screens.
    private static func smoothstep(_ value: CGFloat) -> CGFloat {
        let t = min(1, max(0, value))
        return t * t * (3 - 2 * t)
    }
    static func siblingOpacity(_ progress: CGFloat) -> CGFloat {
        1 - smoothstep((progress - 0.06) / 0.49)
    }
    static func detailOpacity(_ progress: CGFloat) -> CGFloat {
        smoothstep((progress - 0.72) / 0.28)
    }
    // Selected card returns along its original path while siblings remain
    // offscreen. They slide back only during the final part of dismissal.
    static func siblingRetreatProgress(_ progress: CGFloat) -> CGFloat {
        smoothstep(progress / 0.48)
    }
    static func stackVisibleHeight(current: CGRect, next: CGRect?) -> CGFloat {
        guard let next else { return current.height }
        return min(current.height, max(0, next.minY - current.minY))
    }

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
    private var spring = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var running = false

    mutating func set(_ value: CGFloat) {
        self.value = value
        elapsed = 0
        running = false
    }
    mutating func animate(to target: CGFloat, at time: TimeInterval, duration: TimeInterval, spring: Bool = false) {
        self.spring = spring
        elapsed = 0
        origin = value
        self.target = target
        start = time
        self.duration = max(0, duration)
        running = duration > 0 && origin != target
        if !running { value = target }
    }
    @discardableResult mutating func advance(to time: TimeInterval) -> Bool {
        guard running else { return false }
        elapsed = min(duration, max(0, time - start))
        let fraction = min(1, max(0, elapsed / duration))
        let curved = spring ? AnimationConfig.springProgress(CGFloat(fraction)) : CGFloat(fraction)
        value = origin + (target - origin) * curved
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
