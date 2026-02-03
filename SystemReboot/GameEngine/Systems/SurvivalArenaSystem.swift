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
        EventConfig(type: .memorySurge, name: "MEMORY SURGE", duration: BalanceConfig.SurvivalEvents.memorySurgeDuration, warningDuration: BalanceConfig.SurvivalEvents.memorySurgeWarningDuration, minSurvivalTime: BalanceConfig.SurvivalEvents.tier1MinTime, weight: 3),
        EventConfig(type: .bufferOverflow, name: "BUFFER OVERFLOW", duration: BalanceConfig.SurvivalEvents.bufferOverflowDuration, warningDuration: BalanceConfig.SurvivalEvents.bufferOverflowWarningDuration, minSurvivalTime: BalanceConfig.SurvivalEvents.tier1MinTime, weight: 3),

        // Tier 2: Available from 180s (3 min)
        EventConfig(type: .thermalThrottle, name: "THERMAL THROTTLE", duration: BalanceConfig.SurvivalEvents.thermalThrottleDuration, warningDuration: BalanceConfig.SurvivalEvents.thermalThrottleWarningDuration, minSurvivalTime: BalanceConfig.SurvivalEvents.tier2MinTime, weight: 2),
        EventConfig(type: .cacheFlush, name: "CACHE FLUSH", duration: BalanceConfig.SurvivalEvents.cacheFlushDuration, warningDuration: BalanceConfig.SurvivalEvents.cacheFlushWarningDuration, minSurvivalTime: BalanceConfig.SurvivalEvents.tier2MinTime, weight: 1),

        // Tier 3: Available from 300s (5 min)
        EventConfig(type: .dataCorruption, name: "DATA CORRUPTION", duration: BalanceConfig.SurvivalEvents.dataCorruptionDuration, warningDuration: BalanceConfig.SurvivalEvents.dataCorruptionWarningDuration, minSurvivalTime: BalanceConfig.SurvivalEvents.tier3MinTime, weight: 2),
        EventConfig(type: .virusSwarm, name: "VIRUS SWARM", duration: BalanceConfig.SurvivalEvents.virusSwarmDuration, warningDuration: BalanceConfig.SurvivalEvents.virusSwarmWarningDuration, minSurvivalTime: BalanceConfig.SurvivalEvents.tier3MinTime, weight: 2),
        EventConfig(type: .systemRestore, name: "SYSTEM RESTORE", duration: BalanceConfig.SurvivalEvents.systemRestoreDuration, warningDuration: BalanceConfig.SurvivalEvents.systemRestoreWarningDuration, minSurvivalTime: BalanceConfig.SurvivalEvents.tier3MinTime, weight: 1)
    ]

    // MARK: - State

    private var eventTimer: TimeInterval = 0
    private var nextEventTime: TimeInterval = BalanceConfig.SurvivalEvents.firstEventTime
    private var activeEventConfig: EventConfig?
    private var eventStartTime: TimeInterval = 0
    private var isInWarningPhase: Bool = false
    private var lastCacheFlushTime: TimeInterval = -120  // Cooldown tracking

    // Event-specific state
    private var shrinkAmount: CGFloat = 0

    // Data earning
    private var dataAccumulator: CGFloat = 0
    private static var extractionTime: TimeInterval { BalanceConfig.SurvivalEconomy.extractionTime }
    private static var dataPerSecond: CGFloat { BalanceConfig.SurvivalEconomy.hashPerSecond }

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
        // Base Data earning + bonus per minute survived
        let minutesSurvived = CGFloat(state.timeElapsed / 60)
        let dataRate = Self.dataPerSecond + (minutesSurvived * BalanceConfig.SurvivalEconomy.hashBonusPerMinute)

        dataAccumulator += dataRate * CGFloat(deltaTime)

        // Convert accumulated fractional Hash to integer
        if dataAccumulator >= 1.0 {
            let earned = Int(dataAccumulator)
            state.stats.hashEarned += earned
            dataAccumulator -= CGFloat(earned)
        }
    }

    /// Called when player chooses to extract - ends the game with 100% rewards
    static func extract(state: inout GameState) {
        state.stats.extracted = true
        state.isGameOver = true
        state.victory = true  // Extraction counts as victory
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
            if state.timeElapsed - lastCacheFlushTime < BalanceConfig.SurvivalEvents.cacheFlushCooldown {
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
    }

    private func startEventEffect(state: inout GameState, config: EventConfig) {
        switch config.type {
        case .memorySurge:
            // Speed boost is handled in render/movement code via activeEvent check
            break

        case .bufferOverflow:
            // Kill zone approach: Don't physically shrink arena
            // Instead, store danger zone depth - player takes damage in these zones
            shrinkAmount = BalanceConfig.SurvivalEvents.bufferOverflowZoneDepth
            state.eventData?.shrinkAmount = shrinkAmount
            // Damage is applied in updateEventEffect

        case .thermalThrottle:
            // Slow + damage boost handled via activeEvent check
            break

        case .cacheFlush:
            // Clear all enemies!
            state.enemies.removeAll()
            // Brief invulnerability (use currentFrameTime for consistent time base)
            state.player.invulnerable = true
            state.player.invulnerableUntil = state.currentFrameTime + BalanceConfig.Arena.cacheFlushInvulnerability

        case .dataCorruption:
            // Mark random obstacles as corrupted (hazardous)
            let obstacleCount = min(BalanceConfig.SurvivalEvents.maxCorruptedObstacles, state.arena.obstacles.count)
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
            let margin = BalanceConfig.SurvivalEvents.healingZoneSpawnMargin
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

                if distance < BalanceConfig.SurvivalEvents.systemRestoreZoneRadius {
                    let healAmount = BalanceConfig.SurvivalEvents.systemRestoreHealPerSecond * CGFloat(deltaTime)
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
                    let damage = BalanceConfig.SurvivalEvents.dataCorruptionDamagePerSecond * CGFloat(deltaTime)
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
                    let damage = BalanceConfig.SurvivalEvents.bufferOverflowDamagePerSecond * CGFloat(deltaTime)
                    state.player.health -= damage
                }
            }

        default:
            break
        }
    }

    private func endEvent(state: inout GameState, config: EventConfig) {
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
        let baseInterval = BalanceConfig.SurvivalEvents.baseEventInterval
        let minInterval = BalanceConfig.SurvivalEvents.minEventInterval
        let reductionPerMinute = BalanceConfig.SurvivalEvents.intervalReductionPerMinute

        let minutesSurvived = state.timeElapsed / 60
        let interval = max(minInterval, baseInterval - (minutesSurvived * reductionPerMinute))

        nextEventTime = state.timeElapsed + interval + Double.random(in: BalanceConfig.SurvivalEvents.intervalRandomRange)
    }

    private func spawnVirusSwarm(state: inout GameState, angle: CGFloat) {
        let config = GameConfigLoader.shared

        // Get a fast, weak enemy config or create one
        let swarmConfig = config.getEnemy("fast") ?? EnemyConfig(
            id: "swarm_virus",
            name: "Swarm Virus",
            health: BalanceConfig.SurvivalEvents.swarmVirusHealth,
            speed: BalanceConfig.SurvivalEvents.swarmVirusSpeed,
            damage: BalanceConfig.SurvivalEvents.swarmVirusDamage,
            coinValue: 1,
            size: 8,
            color: "#ff00ff",
            shape: "diamond",
            isBoss: false
        )

        // Spawn position at arena edge
        let centerX = state.arena.width / 2
        let centerY = state.arena.height / 2
        let spawnDistance = max(state.arena.width, state.arena.height) * BalanceConfig.Arena.spawnDistanceMultiplier

        let baseX = centerX + cos(angle) * spawnDistance
        let baseY = centerY + sin(angle) * spawnDistance

        // Spawn enemies in a formation
        for i in 0..<BalanceConfig.SurvivalEvents.virusSwarmCount {
            // Spread perpendicular to direction
            let perpAngle = angle + .pi / 2
            let offset = CGFloat(i % 10 - 5) * BalanceConfig.SurvivalEvents.virusSpreadOffset
            let rowOffset = CGFloat(i / 10) * BalanceConfig.SurvivalEvents.virusRowOffset

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
            return BalanceConfig.SurvivalEvents.memorySurgeSpeedBoost
        case .thermalThrottle:
            return BalanceConfig.SurvivalEvents.thermalThrottleSpeedMult
        default:
            return 1.0
        }
    }

    /// Get player damage modifier based on active event
    static func getDamageModifier(state: GameState) -> CGFloat {
        guard let event = state.activeEvent else { return 1.0 }

        switch event {
        case .thermalThrottle:
            return BalanceConfig.SurvivalEvents.thermalThrottleDamageMult
        default:
            return 1.0
        }
    }

    /// Get spawn rate modifier based on active event
    static func getSpawnRateModifier(state: GameState) -> CGFloat {
        guard let event = state.activeEvent else { return 1.0 }

        switch event {
        case .memorySurge:
            return BalanceConfig.SurvivalEvents.memorySurgeSpawnRate
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
