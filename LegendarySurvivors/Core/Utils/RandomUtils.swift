import Foundation

// MARK: - Random Utilities

enum RandomUtils {
    /// Generate random integer between min (inclusive) and max (inclusive)
    static func randomInt(min: Int, max: Int) -> Int {
        return Int.random(in: min...max)
    }

    /// Generate random float between min and max
    static func randomFloat(min: Double, max: Double) -> Double {
        return Double.random(in: min...max)
    }

    /// Generate random CGFloat between min and max
    static func randomCGFloat(min: CGFloat, max: CGFloat) -> CGFloat {
        return CGFloat.random(in: min...max)
    }

    /// Pick random element from array
    static func randomChoice<T>(_ array: [T]) -> T? {
        return array.randomElement()
    }

    /// Shuffle array (returns new array)
    static func shuffle<T>(_ array: [T]) -> [T] {
        return array.shuffled()
    }

    /// Generate a unique ID
    static func generateId() -> String {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let random = String(Int.random(in: 0...Int.max), radix: 36).prefix(9)
        return "\(timestamp)-\(random)"
    }

    /// Random boolean with optional probability
    static func randomBool(probability: Double = 0.5) -> Bool {
        return Double.random(in: 0...1) < probability
    }

    /// Generate random angle in radians (0 to 2π)
    static func randomAngle() -> CGFloat {
        return CGFloat.random(in: 0...(2 * .pi))
    }

    /// Generate random point on a circle edge
    static func randomPointOnCircle(centerX: CGFloat, centerY: CGFloat, radius: CGFloat) -> (x: CGFloat, y: CGFloat) {
        let angle = randomAngle()
        return (
            centerX + cos(angle) * radius,
            centerY + sin(angle) * radius
        )
    }

    /// Generate random point within a rectangle
    static func randomPointInRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> (x: CGFloat, y: CGFloat) {
        return (
            CGFloat.random(in: x...(x + width)),
            CGFloat.random(in: y...(y + height))
        )
    }

    /// Weighted random selection
    static func weightedChoice<T>(_ items: [(item: T, weight: Double)]) -> T? {
        let totalWeight = items.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return nil }

        var random = Double.random(in: 0...totalWeight)
        for (item, weight) in items {
            random -= weight
            if random <= 0 {
                return item
            }
        }
        return items.last?.item
    }
}
