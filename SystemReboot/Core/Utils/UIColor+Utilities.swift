import UIKit

// MARK: - UIColor Utilities

extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }

    /// Blend this color with another color
    func blended(with color: UIColor, ratio: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        self.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        let clampedRatio = max(0, min(1, ratio))
        return UIColor(
            red: r1 * (1 - clampedRatio) + r2 * clampedRatio,
            green: g1 * (1 - clampedRatio) + g2 * clampedRatio,
            blue: b1 * (1 - clampedRatio) + b2 * clampedRatio,
            alpha: a1 * (1 - clampedRatio) + a2 * clampedRatio
        )
    }

    /// Create a lighter version of this color
    func lighter(by percentage: CGFloat = 0.3) -> UIColor {
        return blended(with: .white, ratio: percentage)
    }

    /// Create a darker version of this color
    func darker(by percentage: CGFloat = 0.3) -> UIColor {
        return blended(with: .black, ratio: percentage)
    }

    /// Interpolate between this color and another (alias for blended)
    func interpolate(to color: UIColor, progress: CGFloat) -> UIColor {
        return blended(with: color, ratio: progress)
    }
}
