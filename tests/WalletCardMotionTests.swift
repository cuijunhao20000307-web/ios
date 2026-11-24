import Foundation
import CoreGraphics

@main
struct WalletCardMotionTests {
    static func main() {
        // Curved depth is centered, monotonic and has one shared front width.
        for count in [0, 1, 2, 6, 30] {
            for index in 0..<count {
                let scale = AnimationConfig.scale(forIndex: index, count: count)
                precondition(scale >= 0.92 && scale <= 1)
                if index > 0 {
                    precondition(scale >= AnimationConfig.scale(forIndex: index - 1, count: count))
                }
                let width: CGFloat = 320
                let x = (width - width * scale) / 2
                precondition(abs((x + width * scale / 2) - width / 2) < 0.00001)
                precondition(AnimationConfig.returnProgress(elapsed: 0.45, index: index, count: count) == 1)
            }
        }
        precondition(AnimationConfig.scale(forIndex: 0, count: 6) == 0.92)
        precondition(AnimationConfig.scale(forIndex: 5, count: 6) == 1)
        precondition(AnimationConfig.returnProgress(elapsed: 0.179, index: 1, count: 6) == 0)
        var springTrack = WalletLinearTrack()
        for _ in 0..<100 {
            springTrack.set(0)
            springTrack.animate(to: 1, at: 1, duration: 0.45, spring: true)
            springTrack.advance(to: 1.12)
            let interrupted = springTrack.value
            precondition(interrupted > 0 && interrupted < 1)
            springTrack.animate(to: 0, at: 1.12, duration: 0.45, spring: true)
            precondition(springTrack.value == interrupted)
            springTrack.advance(to: 2)
            precondition(springTrack.value == 0 && !springTrack.running)
            springTrack.animate(to: 1, at: 3, duration: 0, spring: true)
            precondition(springTrack.value == 1 && !springTrack.running)
        }
        // Device-video regression: every measured source previously shared
        // the first slot Y. That erased sibling strips and snapped the last
        // card from the first slot to the last when the real deck reappeared.
        for count in [1, 6, 8] {
            for width: CGFloat in [240, 280, 320] {
                for scrollY: CGFloat in [-180, 0, 145] {
                    let deck = CGRect(x: 34, y: scrollY, width: width, height: 700)
                    let step = max(35, min(46, width * 0.14))
                    let frames = (0..<count).map {
                        WalletCardMotion.stackFrame(deck: deck, width: width, index: $0, count: count)
                    }
                    for index in 0..<count {
                        let frame = frames[index]
                        precondition(abs(frame.minY - (scrollY + CGFloat(index) * step)) < 0.000001)
                        precondition(abs(frame.midX - (34 + width / 2)) < 0.000001)
                        let next = index + 1 < count ? frames[index + 1] : nil
                        let exposed = WalletCardMotion.stackVisibleHeight(current: frame, next: next)
                        precondition(abs(exposed - (next == nil ? frame.height : step)) < 0.000001)
                        let returned = WalletCardMotion.frame(source: frame,
                            destination: CGRect(x: 20, y: 20, width: 380, height: 380 / 1.586), progress: 0)
                        precondition(returned == frame)
                    }
                }
            }
        }
        // First/middle/last cards, a scrolled stack, narrow and expanded layouts.
        for width: CGFloat in [280, 320, 393, 880] {
            for y: CGFloat in [-80, 140, 280, 500] {
                let source = CGRect(x: 20, y: y, width: min(320, width), height: min(320, width) / 1.586)
                let targetWidth = width >= 620 ? (width - 64) / 2 : width - 40
                let target = CGRect(x: 20, y: 92, width: targetWidth, height: targetWidth / 1.586)
                precondition(WalletCardMotion.frame(source: source, destination: target, progress: 0) == source)
                precondition(WalletCardMotion.frame(source: source, destination: target, progress: 1) == target)
                for step in 0...100 {
                    let p = CGFloat(step) / 100
                    let forward = WalletCardMotion.frame(source: source, destination: target, progress: p)
                    let reverse = WalletCardMotion.frame(source: target, destination: source, progress: 1 - p)
                    precondition(abs(forward.minY - reverse.minY) < 0.00001)
                    precondition(abs(forward.width / forward.height - 1.586) < 0.00001)
                }
            }
        }
        // No two complete image/page layers can overlap on any frame.
        precondition(WalletCardMotion.siblingOpacity(0) == 1)
        precondition(WalletCardMotion.siblingOpacity(1) == 0)
        precondition(WalletCardMotion.detailOpacity(0) == 0)
        precondition(WalletCardMotion.detailOpacity(1) == 1)
        for i in 0...1000 {
            let progress = CGFloat(i) / 1000
            let siblings = WalletCardMotion.siblingOpacity(progress)
            let detail = WalletCardMotion.detailOpacity(progress)
            precondition(siblings >= 0 && siblings <= 1 && detail >= 0 && detail <= 1)
            precondition(siblings * detail == 0, "Ghosted foreground/background")
        }
        // Regression: fade is continuous, reversible, and no duplicate page
        // is visible at any point in the selection/return transition.
        precondition(WalletCardMotion.siblingOpacity(0.06) == 1)
        precondition(WalletCardMotion.siblingOpacity(0.55) == 0)
        precondition(WalletCardMotion.detailOpacity(0.72) == 0)
        precondition(WalletCardMotion.siblingRetreatProgress(0) == 0)
        precondition(WalletCardMotion.siblingRetreatProgress(0.48) == 1)
        precondition(WalletCardMotion.siblingRetreatProgress(1) == 1)
        for i in 1...1000 {
            let before = CGFloat(i - 1) / 1000
            let after = CGFloat(i) / 1000
            precondition(WalletCardMotion.siblingOpacity(after) <= WalletCardMotion.siblingOpacity(before) + 0.00001)
            precondition(WalletCardMotion.detailOpacity(after) + 0.00001 >= WalletCardMotion.detailOpacity(before))
            precondition(WalletCardMotion.siblingRetreatProgress(after) + 0.00001 >= WalletCardMotion.siblingRetreatProgress(before))
        }
        let strip = CGRect(x: 20, y: 180, width: 320, height: 202)
        let nextStrip = CGRect(x: 20, y: 225, width: 320, height: 202)
        precondition(WalletCardMotion.stackVisibleHeight(current: strip, next: nextStrip) == 45)
        precondition(WalletCardMotion.stackVisibleHeight(current: strip, next: nil) == 202)
        let small = CGRect(x: 20, y: 220, width: 320, height: 320 / 1.586)
        let large = CGRect(x: 20, y: 80, width: 400, height: 400 / 1.586)
        precondition(WalletCardMotion.flightScale(source: small, destination: large, progress: 0) == 1)
        precondition(abs(WalletCardMotion.flightScale(source: small, destination: large, progress: 0.5) - 1.125) < 0.0001)
        precondition(abs(WalletCardMotion.flightScale(source: small, destination: large, progress: 1) - 1.25) < 0.0001)
        let distance: CGFloat = 300
        precondition(WalletCardMotion.progress(translation: 90, distance: distance) == 0.7)
        precondition(WalletCardMotion.progress(translation: -10, distance: distance) == 1)
        precondition(WalletCardMotion.progress(translation: 1000, distance: distance) == 0)
        precondition(!WalletCardMotion.shouldDismiss(translation: 30, velocity: 0, distance: distance))
        precondition(WalletCardMotion.shouldDismiss(translation: 110, velocity: 0, distance: distance))
        precondition(WalletCardMotion.shouldDismiss(translation: 50, velocity: 800, distance: distance))
        precondition(!WalletCardMotion.shouldDismiss(translation: 5, velocity: 800, distance: distance))
        precondition(!WalletCardMotion.shouldDismiss(translation: 110, velocity: -300, distance: distance))
        // Regression: close halfway through opening must start at the displayed
        // frame; completed/cancelled tracks must never leave progress at one.
        var track = WalletLinearTrack()
        for _ in 0..<100 {
            track.set(0)
            track.animate(to: 1, at: 10, duration: 0.36)
            track.advance(to: 10.18)
            precondition(abs(track.value - 0.5) < 0.00001)
            track.animate(to: 0, at: 10.18, duration: 0.18)
            track.advance(to: 10.27)
            precondition(abs(track.value - 0.25) < 0.00001)
            track.advance(to: 11)
            precondition(track.value == 0 && !track.running)
            track.animate(to: 1, at: 12, duration: 0)
            precondition(track.value == 1 && !track.running)
            track.set(0.7)
            track.animate(to: 1, at: 13, duration: 0.2)
            track.advance(to: 14)
            precondition(track.value == 1)
            track.set(0)
        }
        for anchor in 0..<6 {
            for translation: CGFloat in [-150, -50, 0, 50, 150] {
                let values = (0..<6).map { WalletDeckFan.offset(index: $0, anchor: anchor,
                    translation: translation, height: 202, step: 45) }
                precondition(values[anchor] == translation)
                if translation == 0 { precondition(values.allSatisfy { $0 == 0 }) }
                for i in 1..<6 { precondition(values[i] >= values[i - 1]) }
            }
        }
        let original = CGRect(x: 0, y: 200, width: 320, height: 202)
        let destination = CGRect(x: 0, y: 80, width: 320, height: 202)
        precondition(abs(WalletCardMotion.visibleHeight(source: original, current: original,
            visibleFraction: 45 / 202, retreat: 700, progress: 0) - 45) < 0.00001)
        let middle = WalletCardMotion.frame(source: original, destination: destination, progress: 0.3)
        precondition(WalletCardMotion.visibleHeight(source: original, current: middle,
            visibleFraction: 45 / 202, retreat: 700, progress: 0.3) == middle.height)
        print("Wallet motion: geometry endpoints, reverse path, aspect ratio, pull progress and release thresholds passed")
    }
}
