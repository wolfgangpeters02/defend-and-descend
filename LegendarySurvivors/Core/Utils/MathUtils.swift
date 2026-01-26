import Foundation
import CoreGraphics

// MARK: - Math Utilities

enum MathUtils {
    /// Calculate Euclidean distance between two points
    static func distance(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat) -> CGFloat {
        let dx = x2 - x1
        let dy = y2 - y1
        return sqrt(dx * dx + dy * dy)
    }

    /// Calculate distance between two CGPoints
    static func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        return distance(x1: p1.x, y1: p1.y, x2: p2.x, y2: p2.y)
    }

    /// Calculate squared distance (faster, useful for comparisons)
    static func distanceSquared(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat) -> CGFloat {
        let dx = x2 - x1
        let dy = y2 - y1
        return dx * dx + dy * dy
    }

    /// Linear interpolation between two values
    static func lerp(start: CGFloat, end: CGFloat, t: CGFloat) -> CGFloat {
        return start + (end - start) * t
    }

    /// Clamp a value between min and max
    static func clamp(value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        return Swift.min(Swift.max(value, min), max)
    }

    /// Normalize an angle to 0-2π range
    static func normalizeAngle(_ angle: CGFloat) -> CGFloat {
        var normalized = angle
        while normalized < 0 {
            normalized += .pi * 2
        }
        while normalized >= .pi * 2 {
            normalized -= .pi * 2
        }
        return normalized
    }

    /// Calculate angle between two points
    static func angleBetween(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat) -> CGFloat {
        return atan2(y2 - y1, x2 - x1)
    }

    /// Calculate angle between two CGPoints
    static func angleBetween(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        return atan2(p2.y - p1.y, p2.x - p1.x)
    }

    /// Normalize a vector
    static func normalize(x: CGFloat, y: CGFloat) -> (x: CGFloat, y: CGFloat) {
        let length = sqrt(x * x + y * y)
        guard length > 0 else { return (0, 0) }
        return (x / length, y / length)
    }

    /// Check if a point is inside a rectangle
    static func pointInRect(_ point: CGPoint, rect: CGRect) -> Bool {
        return point.x >= rect.minX && point.x <= rect.maxX &&
               point.y >= rect.minY && point.y <= rect.maxY
    }

    /// Check if two circles overlap
    static func circlesOverlap(
        x1: CGFloat, y1: CGFloat, r1: CGFloat,
        x2: CGFloat, y2: CGFloat, r2: CGFloat
    ) -> Bool {
        let distSq = distanceSquared(x1: x1, y1: y1, x2: x2, y2: y2)
        let minDist = r1 + r2
        return distSq < minDist * minDist
    }

    /// Check if a circle overlaps with a rectangle
    static func circleRectOverlap(
        circleX: CGFloat, circleY: CGFloat, radius: CGFloat,
        rectX: CGFloat, rectY: CGFloat, rectWidth: CGFloat, rectHeight: CGFloat
    ) -> Bool {
        // Find closest point on rectangle to circle center
        let closestX = clamp(value: circleX, min: rectX, max: rectX + rectWidth)
        let closestY = clamp(value: circleY, min: rectY, max: rectY + rectHeight)

        let distSq = distanceSquared(x1: circleX, y1: circleY, x2: closestX, y2: closestY)
        return distSq < radius * radius
    }
}

// MARK: - Color Utilities

enum ColorUtils {
    /// Parse hex color string to RGB components
    static func hexToRGB(_ hex: String) -> (r: CGFloat, g: CGFloat, b: CGFloat)? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0

        return (r, g, b)
    }

    /// Darken a hex color by a percentage (0-1)
    static func darken(_ hex: String, by percent: CGFloat) -> String {
        guard let (r, g, b) = hexToRGB(hex) else { return hex }

        let newR = Int(max(0, r * (1 - percent)) * 255)
        let newG = Int(max(0, g * (1 - percent)) * 255)
        let newB = Int(max(0, b * (1 - percent)) * 255)

        return String(format: "#%02x%02x%02x", newR, newG, newB)
    }

    /// Lighten a hex color by a percentage (0-1)
    static func lighten(_ hex: String, by percent: CGFloat) -> String {
        guard let (r, g, b) = hexToRGB(hex) else { return hex }

        let newR = Int(min(255, (r + (1 - r) * percent) * 255))
        let newG = Int(min(255, (g + (1 - g) * percent) * 255))
        let newB = Int(min(255, (b + (1 - b) * percent) * 255))

        return String(format: "#%02x%02x%02x", newR, newG, newB)
    }
}
