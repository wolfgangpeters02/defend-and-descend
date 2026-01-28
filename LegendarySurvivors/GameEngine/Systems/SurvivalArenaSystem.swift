import Foundation
import CoreGraphics

// MARK: - Survival Arena System
// Handles dynamic events for the Memory Core survival arena

class SurvivalArenaSystem {

    // MARK: - Event Configuration

    struct EventConfig {
        let type: SurvivalEventType
        let name: String
        let duration: TimeInterval
        let warningDuration: TimeInterval
        let minSurvivalTime: TimeInterval  // When this event unlocks
        let weight: Int  // Relative spawn chance
    }

    static let eventConfigs: [EventConfig] = [
        // Tier 1: Available from 60s
        EventConfig(type: .memorySurge, name: "MEMORY SURGE", duration: 8.0, warningDuration: 2.0, minSurvivalTime: 60, weight: 3),
        EventConfig(type: .bufferOverflow, name: "BUFFER OVERFLOW", duration: 15.0, warningDuration: 3.0, minSurvivalTime: 60, weight: 3),

        // Tier 2: Available from 180s (3 min)
        EventConfig(type: .thermalThrottle, name: "THERMAL THROTTLE", duration: 12.0, warningDuration: 2.0, minSurvivalTime: 180, weight: 2),
        EventConfig(type: .cacheFlush, name: "CACHE FLUSH", duration: 3.0, warningDuration: 2.0, minSurvivalTime: 180, weight: 1),

        // Tier 3: Available from 300s (5 min)
        EventConfig(type: .dataCorruption, name: "DATA CORRUPTION", duration: 10.0, warningDuration: 2.0, minSurvivalTime: 300, weight: 2),
        EventConfig(type: .virusSwarm, name: "VIRUS SWARM", duration: 5.0, warningDuration: 3.0, minSurvivalTime: 300, weight: 2),
        EventConfig(type: .systemRestore, name: "SYSTEM RESTORE", duration: 8.0, warningDuration: 2.0, minSurvivalTime: 300, weight: 1)
    ]

    // MARK: - State

    private var eventTimer: TimeInterval = 0
    private var nextEventTime: TimeInterval = 60  // First event at 60s
    private var activeEventConfig: EventConfig?
    private var eventStartTime: TimeInterval = 0
    private var isInWarningPhase: Bool = false
    private var lastCacheFlushTime: TimeInterval = -120  // Cooldown tracking

    // Event-specific state
    private var shrinkAmount: CGFloat = 0

    // Data earning
    private var dataAccumulator: CGFloat = 0
    private static let extractionTime: TimeInterval = 180  // 3 minutes
    private static let dataPerSecond: CGFloat = 2.0  // Base Data per second survived

    // MARK: - Update

    func update(state: inout GameState, deltaTime: TimeInterval) {
        // Only run in survival mode
        guard state.gameMode == .survival || state.gameMode == .arena else { return }

        eventTimer = state.timeElapsed

        // === ECONOMY: Earn Data over time ===
        updateDataEarnings(state: &state, deltaTime: deltaTime)

        // === EXTRACTION: Check if available ===
        if state.timeElapsed >= Self.extractionTime && !state.stats.extractionAvailable {
            state.stats.extractionAvailable = true
            print("[Survival] Extraction available! Player can now extract safely.")
        }

        // Check if we need to start a new event
        if state.activeEvent == nil && eventTimer >= nextEventTime {
            triggerRandomEvent(state: &state)
        }

        // Update active event
        if let config = activeEventConfig {
            let elapsed = eventTimer - eventStartTime

            if isInWarningPhase {
                // Still in warning phase
                if elapsed >= config.warningDuration {
                    isInWarningPhase = false
                    startEventEffect(state: &state, config: config)
                }
            } else {
                // Event is active
                updateEventEffect(state: &state, config: config, deltaTime: deltaTime)

                // Check if event ended
                if elapsed >= config.warningDuration + config.duration {
                    endEvent(state: &state, config: config)
                }
            }
        }
    }

    // MARK: - Economy

    private func updateDataEarnings(state: inout GameState, deltaTime: TimeInterval) {
        // Base Data earning: 2 Data per second survived
        // Bonus: +0.5 Data per minute survived (scales with time)
        let minutesSurvived = CGFloat(state.timeElapsed / 60)
        let dataRate = Self.dataPerSecond + (minutesSurvived * 0.5)

        dataAccumulator += dataRate * CGFloat(deltaTime)

        // Convert accumulated fractional Data to integer
        if dataAccumulator >= 1.0 {
            let earned = Int(dataAccumulator)
            state.stats.dataEarned += earned
            dataAccumulator -= CGFloat(earned)
        }
    }

    /// Called when player chooses to extract - ends the game with 100% rewards
    static func extract(state: inout GameState) {
        state.stats.extracted = true
        state.isGameOver = true
        state.victory = true  // Extraction counts as victory
        print("[Survival] Extracted! Data earned: \(state.stats.dataEarned)")
    }

    /// Get extraction status for UI
    static func canExtract(state: GameState) -> Bool {
        return state.stats.extractionAvailable && !state.stats.extracted
    }

    // MARK: - Event Triggering

    private func triggerRandomEvent(state: inout GameState) {
        let availableEvents = getAvailableEvents(survivalTime: state.timeElapsed)
        guard !availableEvents.isEmpty else { return }

        // Weighted random selection
        let totalWeight = availableEvents.reduce(0) { $0 + $1.weight }
        var randomValue = Int.random(in: 0..<totalWeight)

        var selectedConfig: EventConfig?
        for config in availableEvents {
            randomValue -= config.weight
            if randomValue < 0 {
                selectedConfig = config
                break
            }
        }

        guard let config = selectedConfig else { return }

        // Special cooldown check for cache flush
        if config.type == .cacheFlush {
            if state.timeElapsed - lastCacheFlushTime < 120 {
                // Pick different event
                let filteredEvents = availableEvents.filter { $0.type != .cacheFlush }
                if let altConfig = filteredEvents.randomElement() {
                    startEvent(state: &state, config: altConfig)
                    return
                }
            }
            lastCacheFlushTime = state.timeElapsed
        }

        startEvent(state: &state, config: config)
    }

    private func startEvent(state: inout GameState, config: EventConfig) {
        activeEventConfig = config
        eventStartTime = state.timeElapsed
        isInWarningPhase = true

        state.activeEvent = config.type
        state.eventEndTime = state.timeElapsed + config.warningDuration + config.duration

        // Initialize event data
        state.eventData = SurvivalEventData()

        print("[Survival] Event starting: \(config.name) (warning phase)")
    }

    private func startEventEffect(state: inout GameState, config: EventConfig) {
        print("[Survival] Event active: \(config.name)")

        switch config.type {
        case .memorySurge:
            // Speed boost is handled in render/movement code via activeEvent check
            break

        case .bufferOverflow:
            // Kill zone approach: Don't physically shrink arena
            // Instead, store danger zone depth - player takes damage in these zones
            shrinkAmount = 100
            state.eventData?.shrinkAmount = shrinkAmount
            // Damage is applied in updateEventEffect

        case .thermalThrottle:
            // Slow + damage boost handled via activeEvent check
            break

        case .cacheFlush:
            // Clear all enemies!
            state.enemies.removeAll()
            // Brief invulnerability
            state.player.invulnerable = true
            state.player.invulnerableUntil = state.timeElapsed + 1.0

        case .dataCorruption:
            // Mark random obstacles as corrupted (hazardous)
            let obstacleCount = min(3, state.arena.obstacles.count)
            var corruptedIds: [String] = []
            var indices = Array(0..<state.arena.obstacles.count).shuffled()

            for i in 0..<obstacleCount {
                if i < indices.count {
                    let idx = indices[i]
                    state.arena.obstacles[idx].isCorrupted = true
                    corruptedIds.append(state.arena.obstacles[idx].id ?? "obs_\(idx)")
                }
            }
            state.eventData?.corruptedObstacles = corruptedIds

        case .virusSwarm:
            // Spawn 50 fast weak enemies from one direction
            let angle = CGFloat.random(in: 0...(2 * .pi))
            state.eventData?.swarmDirection = angle
            spawnVirusSwarm(state: &state, angle: angle)

        case .systemRestore:
            // Spawn healing zone at random edge
            let margin: CGFloat = 80
            let edge = Int.random(in: 0...3)
            var position: CGPoint

            switch edge {
            case 0: // Top
                position = CGPoint(x: CGFloat.random(in: margin...(state.arena.width - margin)), y: margin)
            case 1: // Right
                position = CGPoint(x: state.arena.width - margin, y: CGFloat.random(in: margin...(state.arena.height - margin)))
            case 2: // Bottom
                position = CGPoint(x: CGFloat.random(in: margin...(state.arena.width - margin)), y: state.arena.height - margin)
            default: // Left
                position = CGPoint(x: margin, y: CGFloat.random(in: margin...(state.arena.height - margin)))
            }

            state.eventData?.healingZonePosition = position
        }
    }

    private func updateEventEffect(state: inout GameState, config: EventConfig, deltaTime: TimeInterval) {
        switch config.type {
        case .systemRestore:
            // Heal player if in zone
            if let zonePos = state.eventData?.healingZonePosition {
                let dx = state.player.x - zonePos.x
                let dy = state.player.y - zonePos.y
                let distance = sqrt(dx * dx + dy * dy)

                if distance < 60 {  // Zone radius
                    let healAmount = 5.0 * CGFloat(deltaTime)
                    state.player.health = min(state.player.maxHealth, state.player.health + healAmount)
                }
            }

        case .dataCorruption:
            // Damage player if touching corrupted obstacle
            for obstacle in state.arena.obstacles where obstacle.isCorrupted == true {
                if ArenaSystem.checkObstacleCollision(
                    x: state.player.x, y: state.player.y,
                    radius: state.player.size, obstacle: obstacle
                ) {
                    let damage = 15.0 * CGFloat(deltaTime)
                    state.player.health -= damage
                }
            }

        case .bufferOverflow:
            // Kill zones at arena edges - damage player if in danger zone
            if let zoneDepth = state.eventData?.shrinkAmount {
                let inDangerZone =
                    state.player.x < zoneDepth ||
                    state.player.x > state.arena.width - zoneDepth ||
                    state.player.y < zoneDepth ||
                    state.player.y > state.arena.height - zoneDepth

                if inDangerZone {
                    // "Static" damage - rapid ticks
                    let damage = 25.0 * CGFloat(deltaTime)
                    state.player.health -= damage
                }
            }

        default:
            break
        }
    }

    private func endEvent(state: inout GameState, config: EventConfig) {
        print("[Survival] Event ended: \(config.name)")

        switch config.type {
        case .bufferOverflow:
            // Kill zones automatically disappear - no cleanup needed
            break

        case .dataCorruption:
            // Clear corruption from obstacles
            for i in 0..<state.arena.obstacles.count {
                state.arena.obstacles[i].isCorrupted = false
            }

        default:
            break
        }

        // Clear event state
        activeEventConfig = nil
        state.activeEvent = nil
        state.eventEndTime = nil
        state.eventData = nil

        // Schedule next event
        scheduleNextEvent(state: state)
    }

    // MARK: - Helpers

    private func getAvailableEvents(survivalTime: TimeInterval) -> [EventConfig] {
        return Self.eventConfigs.filter { $0.minSurvivalTime <= survivalTime }
    }

    private func scheduleNextEvent(state: GameState) {
        // Events get more frequent over time
        let baseInterval: TimeInterval = 60
        let minInterval: TimeInterval = 40
        let reductionPerMinute: TimeInterval = 5

        let minutesSurvived = state.timeElapsed / 60
        let interval = max(minInterval, baseInterval - (minutesSurvived * reductionPerMinute))

        nextEventTime = state.timeElapsed + interval + Double.random(in: -5...5)
    }

    private func spawnVirusSwarm(state: inout GameState, angle: CGFloat) {
        let config = GameConfigLoader.shared

        // Get a fast, weak enemy config or create one
        let swarmConfig = config.getEnemy("fast") ?? EnemyConfig(
            type: "swarm_virus",
            name: "Swarm Virus",
            health: 5,
            damage: 5,
            speed: 200,
            color: "#ff00ff",
            size: 8,
            coinValue: 1,
            isBoss: false,
            shape: "diamond"
        )

        // Spawn position at arena edge
        let centerX = state.arena.width / 2
        let centerY = state.arena.height / 2
        let spawnDistance = max(state.arena.width, state.arena.height) * 0.6

        let baseX = centerX + cos(angle) * spawnDistance
        let baseY = centerY + sin(angle) * spawnDistance

        // Spawn 50 enemies in a formation
        for i in 0..<50 {
            // Spread perpendicular to direction
            let perpAngle = angle + .pi / 2
            let offset = CGFloat(i % 10 - 5) * 20
            let rowOffset = CGFloat(i / 10) * 15

            let spawnX = baseX + cos(perpAngle) * offset - cos(angle) * rowOffset
            let spawnY = baseY + sin(perpAngle) * offset - sin(angle) * rowOffset

            let spawnOptions = SpawnOptions(
                x: spawnX,
                y: spawnY,
                inactive: false,
                activationRadius: nil
            )

            let enemy = EnemySystem.spawnEnemy(
                state: &state,
                type: "swarm_virus",
                config: swarmConfig,
                spawnOptions: spawnOptions
            )
            state.enemies.append(enemy)
        }
    }

    // MARK: - Event Modifiers (Called by other systems)

    /// Get player speed modifier based on active event
    static func getSpeedModifier(state: GameState) -> CGFloat {
        guard let event = state.activeEvent else { return 1.0 }

        switch event {
        case .memorySurge:
            return 1.5  // +50% speed
        case .thermalThrottle:
            return 0.7  // -30% speed
        default:
            return 1.0
        }
    }

    /// Get player damage modifier based on active event
    static func getDamageModifier(state: GameState) -> CGFloat {
        guard let event = state.activeEvent else { return 1.0 }

        switch event {
        case .thermalThrottle:
            return 1.5  // +50% damage
        default:
            return 1.0
        }
    }

    /// Get spawn rate modifier based on active event
    static func getSpawnRateModifier(state: GameState) -> CGFloat {
        guard let event = state.activeEvent else { return 1.0 }

        switch event {
        case .memorySurge:
            return 2.0  // 2x spawn rate
        default:
            return 1.0
        }
    }

    /// Check if player is in warning phase (for UI)
    static func isInWarningPhase(state: GameState) -> Bool {
        guard state.activeEvent != nil, let endTime = state.eventEndTime else { return false }
        // Warning phase is first 2-3 seconds
        return state.timeElapsed < endTime - 10  // Approximation
    }

    /// Get event border color for UI
    static func getEventBorderColor(state: GameState) -> String? {
        guard let event = state.activeEvent else { return nil }

        switch event {
        case .memorySurge:
            return "#00d4ff"  // Cyan - positive
        case .bufferOverflow, .thermalThrottle:
            return "#ff4444"  // Red - challenge
        case .dataCorruption, .virusSwarm:
            return "#a855f7"  // Purple - danger
        case .systemRestore:
            return "#22c55e"  // Green - opportunity
        case .cacheFlush:
            return "#ffffff"  // White - neutral
        }
    }
}
