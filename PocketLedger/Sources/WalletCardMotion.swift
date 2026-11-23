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
