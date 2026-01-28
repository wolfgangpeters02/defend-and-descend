import Foundation

// MARK: - Frame Context

/// Contains frame-level data cached once per update loop.
/// Eliminates repeated Date() calls across systems (20-30 calls → 1 call per frame).
struct FrameContext {
    /// Current timestamp (seconds since 1970)
    let timestamp: TimeInterval

    /// Time elapsed since last frame (capped to prevent physics explosions)
    let deltaTime: TimeInterval

    /// Create a new frame context
    /// - Parameters:
    ///   - currentTime: The current time from the game loop
    ///   - lastUpdateTime: The timestamp of the previous frame
    ///   - maxDelta: Maximum allowed delta time (default: 1/30 second)
    init(currentTime: TimeInterval, lastUpdateTime: TimeInterval, maxDelta: TimeInterval = 1.0 / 30.0) {
        self.timestamp = currentTime
        let rawDelta = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 0
        self.deltaTime = min(rawDelta, maxDelta)
    }

    /// Create a frame context with explicit values (useful for testing)
    init(timestamp: TimeInterval, deltaTime: TimeInterval) {
        self.timestamp = timestamp
        self.deltaTime = deltaTime
    }
}
