import Foundation
import CoreGraphics

@main
struct WalletCardMotionTests {
    static func main() {
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
