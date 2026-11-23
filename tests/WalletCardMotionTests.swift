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
        print("Wallet motion: geometry endpoints, reverse path, aspect ratio, pull progress and release thresholds passed")
    }
}
