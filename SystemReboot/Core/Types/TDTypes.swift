import Foundation
import CoreGraphics

// MARK: - Tower Defense Specific Types

// MARK: - TD Game State

struct TDGameState {
    // Session
    var sessionId: String
    var playerId: String
    var startTime: TimeInterval
    var gameTime: Double = 0

    // Map
    var map: TDMap
    var paths: [EnemyPath]

    // Motherboard City (component-based map system)
    // Will be implemented in MotherboardTypes.swift
    // var motherboardConfig: MotherboardConfig?

    // Core (The Guardian in TD mode)
    var core: TDCore

    // Towers (placed by player)
    var towers: [Tower]
    var towerSlots: [TowerSlot]

    // Enemies on the field
    var enemies: [TDEnemy]

    // Spatial partitioning for O(1) cell lookup in collision/targeting
    var enemyGrid: SpatialGrid<TDEnemy>?

    // Projectiles
    var projectiles: [Projectile]
    var particles: [Particle]

    // Stats tracking (used for UI and rewards even in idle mode)
    var currentWave: Int = 0
    var wavesCompleted: Int = 0

    // Wave progress tracking (for wave-based TD mode)
    var waveInProgress: Bool = false
    var waveEnemiesRemaining: Int = 0
    var waveEnemiesSpawned: Int = 0
    var nextWaveCountdown: TimeInterval = 0

    // MARK: - Idle TD Continuous Spawning
    // Enemies spawn continuously at a rate that scales with threat level
    // No waves, no game over - just efficiency management

    var idleSpawnEnabled: Bool = true              // Enable continuous spawning
    var idleSpawnTimer: TimeInterval = 0           // Timer for next spawn
    var idleSpawnRate: TimeInterval = BalanceConfig.ThreatLevel.baseIdleSpawnRate
    var idleThreatLevel: CGFloat = 1.0             // Scales enemy stats (increases over time)
    var idleThreatGrowthRate: CGFloat = BalanceConfig.ThreatLevel.onlineThreatGrowthRate
    var idleEnemiesSpawned: Int = 0                // Total enemies spawned this session
    var idleMaxEnemiesOnScreen: Int = BalanceConfig.ThreatLevel.maxEnemiesOnScreen

    // MARK: - Sector Pause System
    // Paused sectors don't spawn enemies, allowing tower redeployment
    var pausedSectorIds: Set<String> = []          // IDs of sectors currently paused

    /// Current spawn interval (decreases as threat increases, with floor)
    var idleCurrentSpawnInterval: TimeInterval {
        // Spawn faster as threat increases, minimum from BalanceConfig
        return max(
            BalanceConfig.ThreatLevel.minSpawnInterval,
            idleSpawnRate / Double(1 + idleThreatLevel * BalanceConfig.ThreatLevel.spawnRateThreatScaling)
        )
    }

    /// Enemy types available at current threat level (thresholds from BalanceConfig)
    var idleAvailableEnemyTypes: [String] {
        var types = ["basic"]
        if idleThreatLevel >= BalanceConfig.ThreatLevel.fastEnemyThreshold { types.append("fast") }
        if idleThreatLevel >= BalanceConfig.ThreatLevel.tankEnemyThreshold { types.append("tank") }
        if idleThreatLevel >= BalanceConfig.ThreatLevel.bossEnemyThreshold { types.append("boss") }
        return types
    }

    // Resources (System: Reboot currencies)
    var hash: Int = BalanceConfig.TDSession.startingHash  // Hash (Ħ) - soft currency for purchases

    // Power System (System: Reboot - PSU Capacity)
    // Power is a CEILING, not consumed. Towers allocate power while placed.
    var powerCapacity: Int = BalanceConfig.TDSession.startingPowerCapacity    // PSU capacity (upgradeable)
    var powerUsed: Int {
        // Sum of all placed towers' power draw
        return towers.reduce(0) { $0 + $1.powerDraw }
    }
    var powerAvailable: Int {
        return max(0, powerCapacity - powerUsed)
    }

    // Hash Storage Cap (System: Reboot)
    var hashStorageCapacity: Int = BalanceConfig.TDSession.defaultHashStorageCapacity  // Set from player's HDD level

    /// Add hash with storage cap enforcement
    /// Returns the actual amount added
    @discardableResult
    mutating func addHash(_ amount: Int) -> Int {
        let spaceAvailable = max(0, hashStorageCapacity - hash)
        let actualAdded = min(amount, spaceAvailable)
        hash += actualAdded
        return actualAdded
    }

    // Efficiency System (System: Reboot core mechanic)
    // Efficiency determines Hash income rate - no death, just reduced income
    var leakCounter: Int = 0           // Increments when virus reaches CPU
    var leakDecayTimer: TimeInterval = 0  // Timer for leak counter decay
    var efficiency: CGFloat {
        // efficiency = max(0, 100 - leakCounter * 5)
        // Each leaked virus reduces efficiency by 5%
        return max(0, min(100, 100 - CGFloat(leakCounter) * BalanceConfig.TDSession.efficiencyLossPerLeak))
    }
    var baseHashPerSecond: CGFloat = 1.0  // Base income rate at 100% efficiency (set from CPU level)
    var cpuMultiplier: CGFloat = 1.0      // CPU tier multiplier (1x, 2x, 4x, 8x, 16x)
    var cpuTier: Int = 1                  // Current CPU tier for display
    var efficiencyRegenMultiplier: CGFloat = 1.0  // RAM upgrade bonus to efficiency recovery
    var hashPerSecond: CGFloat {
        let baseRate = baseHashPerSecond * cpuMultiplier * (efficiency / 100)
        return overclockActive ? baseRate * overclockHashMultiplier : baseRate
    }
    var hashAccumulator: CGFloat = 0  // Accumulates fractional hash

    // Passive Data generation (soft-lock prevention)
    var virusesKilledTotal: Int = 0    // Total viruses killed by firewalls
    var dataFromKills: Int {
        return virusesKilledTotal / BalanceConfig.TDSession.virusKillsPerData
    }

    // Stats
    var stats: TDSessionStats = TDSessionStats()

    // UI state
    var isGameOver: Bool = false
    var isPaused: Bool = false
    var victory: Bool = false
    var selectedTowerSlot: String?  // Currently selected slot for placement
    var selectedTowerId: String?    // Currently selected tower for info/upgrade

    // Scrolling combat text events (damage numbers, healing, etc.)
    var damageEvents: [DamageEvent] = []

    // System Freeze (0% efficiency state)
    var isSystemFrozen: Bool = false    // True when efficiency hits 0%
    var freezeCount: Int = 0             // Number of times system has frozen this session

    // Drag state for tower merging and placement
    var dragState: TowerDragState?

    // Blocker Nodes (System: Reboot - Path Control)
    // Player can place blockers to reroute viruses
    var blockerNodes: [BlockerNode] = []
    var blockerSlots: [BlockerSlot] = []
    var maxBlockerSlots: Int = BalanceConfig.TDSession.startingBlockerSlots  // Start with default, upgradeable

    // Base paths (original paths without blockers)
    var basePaths: [EnemyPath] = []

    /// Number of available blocker slots
    var availableBlockerSlots: Int {
        return maxBlockerSlots - blockerNodes.count
    }

    /// Check if a blocker can be placed
    var canPlaceBlocker: Bool {
        return availableBlockerSlots > 0
    }

    // MARK: - Integrated Boss System (Super Viruses)
    // Bosses spawn at threat milestones, immune to towers
    // Player must manually engage or let them pass (efficiency loss)

    var bossActive: Bool = false              // Is a boss currently on the board
    var activeBossId: String?                 // ID of the active boss enemy
    var activeBossType: String?               // "cyberboss" or "void_harbinger"
    var activeBossDistrictId: String?         // Which sector/district the boss spawned from
    var lastBossThreatMilestone: Int = 0      // Last threat milestone that triggered a boss
    var bossEngaged: Bool = false             // Player has tapped to engage this boss
    var bossSelectedDifficulty: BossDifficulty? // Selected difficulty for current boss
    var bossCooldownRemaining: TimeInterval = 0 // Cooldown after boss victory before next spawn

    /// Threat milestone for next boss spawn (6, 12, 18...)
    var nextBossThreatMilestone: Int {
        let interval = BalanceConfig.TDBoss.threatMilestoneInterval
        return lastBossThreatMilestone == 0 ? interval : lastBossThreatMilestone + interval
    }

    /// Check if threat has reached next boss milestone (respects post-victory cooldown)
    var shouldSpawnBoss: Bool {
        return !bossActive && bossCooldownRemaining <= 0 && Int(idleThreatLevel) >= nextBossThreatMilestone
    }

    /// Check if the active boss is still alive
    var isBossAlive: Bool {
        guard let bossId = activeBossId else { return false }
        return enemies.contains { $0.id == bossId && !$0.isDead && !$0.reachedCore }
    }

    // MARK: - Overclock System
    // Player can overclock CPU for double hash + 10x threat growth
    // Attracts bosses quickly, may disable towers if insufficient power

    var overclockActive: Bool = false         // Is overclock currently active
    var overclockTimeRemaining: TimeInterval = 0  // Seconds left in overclock
    var overclockDuration: TimeInterval = BalanceConfig.Overclock.duration
    var overclockThreatMultiplier: CGFloat = BalanceConfig.Overclock.threatMultiplier
    var overclockHashMultiplier: CGFloat = BalanceConfig.Overclock.hashMultiplier
    var overclockPowerDemandMultiplier: CGFloat = 2.0  // Power demand increase
    var disabledTowerIds: Set<String> = []    // Towers disabled due to power shortage

    /// Power required during overclock
    var overclockPowerRequired: Int {
        return overclockActive ? Int(CGFloat(powerUsed) * overclockPowerDemandMultiplier) : powerUsed
    }

    /// Power deficit during overclock (negative = shortage)
    var powerDeficit: Int {
        return powerCapacity - overclockPowerRequired
    }

    /// Can activate overclock (not already active)
    var canOverclock: Bool {
        return !overclockActive && !bossActive
    }

    // MARK: - District Boss Tracking
    // Track first defeat per district for progression unlocks

    var defeatedDistrictBosses: Set<String> = []  // District IDs where boss was defeated

    /// Check if a district boss has been defeated for the first time
    func hasDefeatedDistrictBoss(_ districtId: String) -> Bool {
        return defeatedDistrictBosses.contains(districtId)
    }
}

// MARK: - Tower Drag State

struct TowerDragState {
    enum DragSource {
        case existingTower(towerId: String, slotId: String)
        case deckProtocol(protocolId: String)
    }

    var source: DragSource
    var currentPosition: CGPoint
    var validPlacementSlotId: String?    // Slot ID for valid placement
}

// MARK: - Blocker Node (System: Reboot - Path Control)
// Player can place blockers at trace intersections to reroute viruses
// Start with 3 slots, upgradeable. Blockers are free to place/move.

struct BlockerNode: Identifiable, Codable {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat = 30  // Visual size (octagon)

    var position: CGPoint {
        CGPoint(x: x, y: y)
    }

    /// Create a blocker at a position
    static func create(at position: CGPoint) -> BlockerNode {
        BlockerNode(
            id: RandomUtils.generateId(),
            x: position.x,
            y: position.y
        )
    }
}

// MARK: - Blocker Slot (Available placement positions for blockers)
// Slots are at trace intersections where viruses can be rerouted

struct BlockerSlot: Identifiable, Codable {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat = 40  // Touch target size
    var occupied: Bool = false
    var blockerId: String?

    var position: CGPoint {
        CGPoint(x: x, y: y)
    }
}

// MARK: - Sector Lane System (8-Lane Motherboard Map)
// Each peripheral sector has a lane that leads to the CPU in the center
// PSU sector starts unlocked, others unlock progressively

struct SectorLane: Identifiable, Codable {
    var id: String                      // Matches sector ID (e.g., "psu", "gpu")
    var sectorId: String                // The sector this lane originates from
    var displayName: String             // e.g., "PSU Power Bus"
    var path: EnemyPath                 // Waypoints from spawn to CPU
    var spawnPoint: CGPoint             // Where enemies spawn (map edge)
    var themeColorHex: String           // Visual theme color
    var unlockCost: Int                 // Hash cost to unlock
    var unlockOrder: Int                // 0 = starter, 1-7 = unlock order
    var prerequisites: [String]         // Sector IDs that must be unlocked first

    var isStarterLane: Bool { unlockOrder == 0 }
}

/// Configuration for the 8-lane motherboard map
struct MotherboardLaneConfig {
    static let canvasSize: CGFloat = BalanceConfig.Motherboard.canvasSize
    static let sectorSize: CGFloat = BalanceConfig.Motherboard.sectorSize
    static let cpuCenter = CGPoint(x: 2100, y: 2100)  // Center of center sector (1,1)
    static let cpuSize: CGFloat = BalanceConfig.Motherboard.cpuSize

    /// All 8 lanes (one per non-CPU sector)
    static func createAllLanes() -> [SectorLane] {
        return [
            // PSU Lane (Starter) - East, mid-right
            SectorLane(
                id: "lane_psu",
                sectorId: SectorID.power.rawValue,
                displayName: "PSU Power Bus",
                path: EnemyPath(id: "path_psu", waypoints: [
                    CGPoint(x: 4200, y: 2100),    // Spawn at right edge
                    CGPoint(x: 3700, y: 2100),    // West along bus
                    CGPoint(x: 3700, y: 2400),    // Turn north
                    CGPoint(x: 3200, y: 2400),    // Turn west
                    CGPoint(x: 3200, y: 2100),    // Turn south to CPU level
                    CGPoint(x: 2250, y: 2100),    // Approach CPU from east
                    CGPoint(x: 2150, y: 2100)     // End at CPU edge
                ]),
                spawnPoint: CGPoint(x: 4200, y: 2100),
                themeColorHex: "#ffdd00",  // Yellow (power)
                unlockCost: 0,
                unlockOrder: 0,
                prerequisites: []
            ),

            // GPU Lane - West, mid-left
            SectorLane(
                id: "lane_gpu",
                sectorId: SectorID.gpu.rawValue,
                displayName: "GPU Graphics Bus",
                path: EnemyPath(id: "path_gpu", waypoints: [
                    CGPoint(x: 0, y: 2100),       // Spawn at left edge
                    CGPoint(x: 500, y: 2100),     // East along bus
                    CGPoint(x: 500, y: 1800),     // Turn south
                    CGPoint(x: 1000, y: 1800),    // Turn east
                    CGPoint(x: 1000, y: 2100),    // Turn north to CPU level
                    CGPoint(x: 1950, y: 2100),    // Approach CPU from west
                    CGPoint(x: 2050, y: 2100)     // End at CPU edge
                ]),
                spawnPoint: CGPoint(x: 0, y: 2100),
                themeColorHex: "#ff4444",  // Red (graphics)
                unlockCost: 5000,
                unlockOrder: 2,
                prerequisites: [SectorID.power.rawValue]
            ),

            // RAM Lane - South, bottom-center
            SectorLane(
                id: "lane_ram",
                sectorId: SectorID.ram.rawValue,
                displayName: "RAM Memory Bus",
                path: EnemyPath(id: "path_ram", waypoints: [
                    CGPoint(x: 2100, y: 0),       // Spawn at bottom edge
                    CGPoint(x: 2100, y: 500),     // North along bus
                    CGPoint(x: 1800, y: 500),     // Turn west
                    CGPoint(x: 1800, y: 1000),    // Turn north
                    CGPoint(x: 2100, y: 1000),    // Turn east to CPU column
                    CGPoint(x: 2100, y: 1950),    // Approach CPU from south
                    CGPoint(x: 2100, y: 2050)     // End at CPU edge
                ]),
                spawnPoint: CGPoint(x: 2100, y: 0),
                themeColorHex: "#4488ff",  // Blue (memory)
                unlockCost: 3000,
                unlockOrder: 1,
                prerequisites: [SectorID.power.rawValue]
            ),

            // Cache Lane - North, top-center
            SectorLane(
                id: "lane_cache",
                sectorId: SectorID.cache.rawValue,
                displayName: "Cache Fast Bus",
                path: EnemyPath(id: "path_cache", waypoints: [
                    CGPoint(x: 2100, y: 4200),    // Spawn at top edge
                    CGPoint(x: 2100, y: 3700),    // South along bus
                    CGPoint(x: 2400, y: 3700),    // Turn east
                    CGPoint(x: 2400, y: 3200),    // Turn south
                    CGPoint(x: 2100, y: 3200),    // Turn west to CPU column
                    CGPoint(x: 2100, y: 2250),    // Approach CPU from north
                    CGPoint(x: 2100, y: 2150)     // End at CPU edge
                ]),
                spawnPoint: CGPoint(x: 2100, y: 4200),
                themeColorHex: "#44ff88",  // Green (cache/memory)
                unlockCost: 8000,
                unlockOrder: 3,
                prerequisites: [SectorID.ram.rawValue]
            ),

            // I/O Lane - Top-Left Corner (diagonal L-shape)
            SectorLane(
                id: "lane_io",
                sectorId: SectorID.io.rawValue,
                displayName: "I/O Controller Bus",
                path: EnemyPath(id: "path_io", waypoints: [
                    CGPoint(x: 0, y: 4200),       // Spawn at top-left corner
                    CGPoint(x: 0, y: 3500),       // Down along left edge
                    CGPoint(x: 500, y: 3500),     // Turn east
                    CGPoint(x: 500, y: 2800),     // Turn south
                    CGPoint(x: 1400, y: 2800),    // Turn east
                    CGPoint(x: 1400, y: 2100),    // Turn south to CPU level
                    CGPoint(x: 1950, y: 2100),    // Approach CPU from west
                    CGPoint(x: 2050, y: 2100)     // End at CPU edge
                ]),
                spawnPoint: CGPoint(x: 0, y: 4200),
                themeColorHex: "#ffaa00",  // Orange (I/O)
                unlockCost: 25000,
                unlockOrder: 7,
                prerequisites: [SectorID.gpu.rawValue, SectorID.storage.rawValue]
            ),

            // Network Lane - Top-Right Corner (diagonal L-shape)
            SectorLane(
                id: "lane_network",
                sectorId: SectorID.network.rawValue,
                displayName: "Network Data Bus",
                path: EnemyPath(id: "path_network", waypoints: [
                    CGPoint(x: 4200, y: 4200),    // Spawn at top-right corner
                    CGPoint(x: 4200, y: 3500),    // Down along right edge
                    CGPoint(x: 3700, y: 3500),    // Turn west
                    CGPoint(x: 3700, y: 2800),    // Turn south
                    CGPoint(x: 2800, y: 2800),    // Turn west
                    CGPoint(x: 2800, y: 2100),    // Turn south to CPU level
                    CGPoint(x: 2250, y: 2100),    // Approach CPU from east
                    CGPoint(x: 2150, y: 2100)     // End at CPU edge
                ]),
                spawnPoint: CGPoint(x: 4200, y: 4200),
                themeColorHex: "#00ffff",  // Cyan (network)
                unlockCost: 18000,
                unlockOrder: 6,
                prerequisites: [SectorID.cache.rawValue, SectorID.expansion.rawValue]
            ),

            // Storage Lane - Bottom-Left Corner (diagonal L-shape)
            SectorLane(
                id: "lane_storage",
                sectorId: SectorID.storage.rawValue,
                displayName: "Storage Data Bus",
                path: EnemyPath(id: "path_storage", waypoints: [
                    CGPoint(x: 0, y: 0),          // Spawn at bottom-left corner
                    CGPoint(x: 0, y: 700),        // Up along left edge
                    CGPoint(x: 500, y: 700),      // Turn east
                    CGPoint(x: 500, y: 1400),     // Turn north
                    CGPoint(x: 1400, y: 1400),    // Turn east
                    CGPoint(x: 1400, y: 2100),    // Turn north to CPU level
                    CGPoint(x: 1950, y: 2100),    // Approach CPU from west
                    CGPoint(x: 2050, y: 2100)     // End at CPU edge
                ]),
                spawnPoint: CGPoint(x: 0, y: 0),
                themeColorHex: "#8844ff",  // Purple (storage)
                unlockCost: 12000,
                unlockOrder: 5,
                prerequisites: [SectorID.gpu.rawValue]
            ),

            // Expansion Lane - Bottom-Right Corner (diagonal L-shape)
            SectorLane(
                id: "lane_expansion",
                sectorId: SectorID.expansion.rawValue,
                displayName: "Expansion PCIe Bus",
                path: EnemyPath(id: "path_expansion", waypoints: [
                    CGPoint(x: 4200, y: 0),       // Spawn at bottom-right corner
                    CGPoint(x: 4200, y: 700),     // Up along right edge
                    CGPoint(x: 3700, y: 700),     // Turn west
                    CGPoint(x: 3700, y: 1400),    // Turn north
                    CGPoint(x: 2800, y: 1400),    // Turn west
                    CGPoint(x: 2800, y: 2100),    // Turn north to CPU level
                    CGPoint(x: 2250, y: 2100),    // Approach CPU from east
                    CGPoint(x: 2150, y: 2100)     // End at CPU edge
                ]),
                spawnPoint: CGPoint(x: 4200, y: 0),
                themeColorHex: "#ff44ff",  // Magenta (expansion)
                unlockCost: 10000,
                unlockOrder: 4,
                prerequisites: [SectorID.power.rawValue]
            )
        ]
    }

    /// Get lanes that are unlocked based on player's unlocked sectors
    static func getUnlockedLanes(unlockedSectorIds: Set<String>) -> [SectorLane] {
        let allLanes = createAllLanes()
        return allLanes.filter { lane in
            lane.isStarterLane || unlockedSectorIds.contains(lane.sectorId)
        }
    }

    /// Get lanes that are locked but visible (all non-starter, non-unlocked lanes)
    static func getLockedLanes(unlockedSectorIds: Set<String>) -> [SectorLane] {
        let allLanes = createAllLanes()
        return allLanes.filter { lane in
            !lane.isStarterLane && !unlockedSectorIds.contains(lane.sectorId)
        }
    }

    /// Get a specific lane by sector ID
    static func getLane(forSectorId sectorId: String) -> SectorLane? {
        return createAllLanes().first { $0.sectorId == sectorId }
    }
}

// MARK: - TD Map

struct TDMap {
    var id: String
    var name: String
    var width: CGFloat
    var height: CGFloat
    var backgroundColor: String
    var theme: String
    var particleEffect: String?

    var obstacles: [MapObstacle]
    var hazards: [MapHazard]
    var effectZones: [MapEffectZone]

    var spawnPoints: [CGPoint]  // Where enemies spawn
    var corePosition: CGPoint   // Where enemies are trying to reach

    var globalModifier: MapModifier?
}

// MARK: - Tower

struct Tower: Identifiable, Codable {
    var id: String
    var protocolId: String  // Links to Protocol in ProtocolLibrary
    var level: Int = 1
    var rarity: Rarity = .common  // Tower rarity for cost calculations

    // Position
    var x: CGFloat
    var y: CGFloat
    var slotId: String

    // Stats (derived from Protocol + level)
    var damage: CGFloat
    var range: CGFloat
    var attackSpeed: CGFloat
    var lastAttackTime: TimeInterval = 0

    // Special effects
    var projectileCount: Int = 1
    var pierce: Int = 0
    var splash: CGFloat = 0
    var homing: Bool = false
    var slow: CGFloat?
    var slowDuration: TimeInterval?
    var chain: Int?

    // Visual
    var color: String
    var rotation: CGFloat = 0  // Current facing angle
    var targetId: String?      // Current target enemy

    // Tower name for display
    var towerName: String

    // Power consumption (System: Reboot)
    var powerDraw: Int = BalanceConfig.TowerPower.defaultPowerDraw  // Watts consumed while this tower is placed

    // Upgrade cost base (from Protocol's baseUpgradeCost, scales by rarity)
    var baseUpgradeCost: Int = BalanceConfig.Towers.placementCosts[.common] ?? 50

    // Backward-compatible CodingKeys: protocolId is stored as "weaponType" in saved sessions
    enum CodingKeys: String, CodingKey {
        case id
        case protocolId = "weaponType"
        case level, rarity, x, y, slotId
        case damage, range, attackSpeed, lastAttackTime
        case projectileCount, pierce, splash, homing, slow, slowDuration, chain
        case color, rotation, targetId, towerName
        case powerDraw, baseUpgradeCost
    }

    var position: CGPoint {
        CGPoint(x: x, y: y)
    }

    /// Calculate upgrade cost
    /// Uses centralized exponential formula from BalanceConfig
    var upgradeCost: Int {
        return BalanceConfig.exponentialUpgradeCost(baseCost: baseUpgradeCost, currentLevel: level)
    }

    /// Check if can upgrade
    var canUpgrade: Bool {
        return level < 10
    }

    /// Create tower from Protocol (System: Reboot - Firewall mode)
    static func from(protocol proto: Protocol, at slot: TowerSlot) -> Tower {
        let stats = proto.firewallStats
        return Tower(
            id: RandomUtils.generateId(),
            protocolId: proto.id,
            level: proto.level,
            rarity: proto.rarity,
            x: slot.x,
            y: slot.y,
            slotId: slot.id,
            damage: stats.damage,
            range: stats.range,
            attackSpeed: stats.fireRate,
            projectileCount: stats.projectileCount,
            pierce: stats.pierce,
            splash: stats.splash,
            homing: stats.special == .homing,
            slow: stats.slow > 0 ? stats.slow : nil,
            slowDuration: stats.slowDuration > 0 ? stats.slowDuration : nil,
            chain: stats.special == .chain ? 3 : nil,  // Chain hits 3 enemies
            color: proto.color,
            towerName: proto.name,
            powerDraw: stats.powerDraw,  // Power consumption from Protocol
            baseUpgradeCost: proto.baseUpgradeCost  // Exponential upgrade scaling
        )
    }

    /// Apply level upgrade
    mutating func upgrade() {
        guard canUpgrade else { return }
        level += 1
        damage *= BalanceConfig.TowerUpgrades.damageMultiplier
        range *= BalanceConfig.TowerUpgrades.rangeMultiplier
        attackSpeed *= BalanceConfig.TowerUpgrades.attackSpeedMultiplier
    }
}

// MARK: - TD Core (The Guardian)

struct TDCore {
    var x: CGFloat
    var y: CGFloat
    var health: CGFloat
    var maxHealth: CGFloat
    var armor: CGFloat = 0

    // Core can auto-attack (Guardian firing)
    var canAttack: Bool = true
    var damage: CGFloat = 10
    var range: CGFloat = 150
    var attackSpeed: CGFloat = 1.0
    var lastAttackTime: TimeInterval = 0

    var position: CGPoint {
        CGPoint(x: x, y: y)
    }

    var isDead: Bool {
        health <= 0
    }

    mutating func takeDamage(_ amount: CGFloat) {
        let reduced = amount * (1 - armor)
        health = max(0, health - reduced)
    }
}

// MARK: - TD Enemy

struct TDEnemy: Identifiable {
    var id: String
    var type: String

    // Position and movement
    var x: CGFloat
    var y: CGFloat
    var pathIndex: Int = 0      // Which path this enemy follows
    var pathProgress: CGFloat = 0  // Progress along path (0.0 to 1.0)

    // Stats
    var health: CGFloat
    var maxHealth: CGFloat
    var speed: CGFloat          // Units per second along path
    var damage: CGFloat         // Damage to core on arrival

    // Rewards
    var goldValue: Int
    var xpValue: Int

    // Visual
    var size: CGFloat
    var color: String
    var shape: String

    // Status effects
    var isSlowed: Bool = false
    var slowAmount: CGFloat = 0
    var slowEndTime: TimeInterval = 0

    // State
    var isDead: Bool = false
    var reachedCore: Bool = false
    var isBoss: Bool = false

    // Lane-based spawning (8-lane motherboard system)
    var laneId: String?  // Which lane this enemy spawned from (e.g., "power", "gpu")

    var immuneToTowers: Bool = false   // Cannot be damaged by Firewalls

    var position: CGPoint {
        CGPoint(x: x, y: y)
    }

    /// Current speed accounting for slow effects
    var currentSpeed: CGFloat {
        if isSlowed {
            return speed * (1 - slowAmount)
        }
        return speed
    }

    /// Apply slow effect
    mutating func applySlow(amount: CGFloat, duration: TimeInterval, currentTime: TimeInterval) {
        isSlowed = true
        slowAmount = max(slowAmount, amount)  // Keep strongest slow
        slowEndTime = max(slowEndTime, currentTime + duration)
    }

    /// Update slow status
    mutating func updateSlow(currentTime: TimeInterval) {
        if isSlowed && currentTime >= slowEndTime {
            isSlowed = false
            slowAmount = 0
        }
    }
}

// MARK: - Tower Placement Result

enum TowerPlacementResult {
    case success(tower: Tower)
    case insufficientHash(required: Int, available: Int)
    case insufficientPower(required: Int, available: Int)
    case slotOccupied
    case protocolLocked
    case invalidSlot
}

// MARK: - TD State Factory

class TDGameStateFactory {

    /// Create initial TD game state
    static func createTDGameState(
        mapId: String,
        playerProfile: PlayerProfile
    ) -> TDGameState? {
        // Use the 8-lane motherboard system for motherboard map
        if mapId == "motherboard" {
            return createMotherboardGameState(playerProfile: playerProfile)
        }

        let config = GameConfigLoader.shared

        // Get arena config (arenas = TD maps)
        guard let arenaConfig = config.getArena(mapId) else {
            return nil
        }

        // Create TD map from arena config
        let map = createTDMap(from: arenaConfig)

        // Create paths (for now, simple path from spawn to core)
        let paths = createDefaultPaths(for: map)

        // Create core at center bottom
        let core = TDCore(
            x: map.width / 2,
            y: map.height - 50,
            health: 100,
            maxHealth: 100
        )

        // Create tower slots around the map
        let slots = createTowerSlots(for: map, avoiding: paths)

        // Create blocker slots at path intersections (turns in the path)
        let blockerSlots = createBlockerSlots(for: paths)

        var state = TDGameState(
            sessionId: RandomUtils.generateId(),
            playerId: playerProfile.id,
            startTime: Date().timeIntervalSince1970,
            map: map,
            paths: paths,
            core: core,
            towers: [],
            towerSlots: slots,
            enemies: [],
            projectiles: [],
            particles: [],
            blockerSlots: blockerSlots,
            basePaths: paths  // Store original paths for rerouting
        )

        // Apply Global Upgrades
        // PSU level determines power capacity
        state.powerCapacity = playerProfile.globalUpgrades.powerCapacity
        // HDD level determines hash storage capacity
        state.hashStorageCapacity = playerProfile.globalUpgrades.hashStorageCapacity
        // CPU level determines base Hash generation rate
        state.baseHashPerSecond = playerProfile.globalUpgrades.hashPerSecond
        state.cpuMultiplier = 1.0  // Level scaling is now in baseHashPerSecond
        state.cpuTier = playerProfile.globalUpgrades.cpuLevel
        // RAM level determines efficiency recovery speed
        state.efficiencyRegenMultiplier = playerProfile.globalUpgrades.efficiencyRegenMultiplier

        return state
    }

    /// Create blocker slots at path intersections (turns)
    /// Blockers can be placed here to reroute viruses
    private static func createBlockerSlots(for paths: [EnemyPath]) -> [BlockerSlot] {
        var slots: [BlockerSlot] = []

        for path in paths {
            // Create slots at each waypoint (except start and end)
            guard path.waypoints.count > 2 else { continue }

            for i in 1..<(path.waypoints.count - 1) {
                let waypoint = path.waypoints[i]
                slots.append(BlockerSlot(
                    id: "blocker_slot_\(path.id)_\(i)",
                    x: waypoint.x,
                    y: waypoint.y
                ))
            }
        }

        return slots
    }

    /// Create TD map from arena config
    private static func createTDMap(from config: ArenaConfig) -> TDMap {
        let obstacles = config.obstacles?.map { obs in
            MapObstacle(
                id: RandomUtils.generateId(),
                x: CGFloat(obs.x),
                y: CGFloat(obs.y),
                width: CGFloat(obs.width),
                height: CGFloat(obs.height),
                color: obs.color,
                type: obs.type
            )
        } ?? []

        let hazards = config.hazards?.map { haz in
            MapHazard(
                id: RandomUtils.generateId(),
                x: CGFloat(haz.x),
                y: CGFloat(haz.y),
                width: CGFloat(haz.width),
                height: CGFloat(haz.height),
                damage: CGFloat(haz.damage),
                type: haz.type
            )
        } ?? []

        let effectZones = config.effectZones?.map { zone in
            MapEffectZone(
                id: RandomUtils.generateId(),
                x: CGFloat(zone.x),
                y: CGFloat(zone.y),
                width: CGFloat(zone.width),
                height: CGFloat(zone.height),
                type: zone.type,
                speedMultiplier: zone.speedMultiplier.map { CGFloat($0) },
                healPerSecond: zone.healPerSecond.map { CGFloat($0) },
                visualEffect: zone.visualEffect
            )
        } ?? []

        let globalMod = config.globalModifier.map { mod in
            MapModifier(
                playerSpeedMultiplier: mod.playerSpeedMultiplier.map { CGFloat($0) },
                enemySpeedMultiplier: mod.enemySpeedMultiplier.map { CGFloat($0) },
                damageMultiplier: mod.damageMultiplier.map { CGFloat($0) },
                enemyDamageMultiplier: mod.enemyDamageMultiplier.map { CGFloat($0) },
                projectileSpeedMultiplier: mod.projectileSpeedMultiplier.map { CGFloat($0) },
                description: mod.description
            )
        }

        return TDMap(
            id: config.id,
            name: config.name,
            width: CGFloat(config.width),
            height: CGFloat(config.height),
            backgroundColor: config.backgroundColor,
            theme: config.theme,
            particleEffect: config.particleEffect,
            obstacles: obstacles,
            hazards: hazards,
            effectZones: effectZones,
            spawnPoints: [CGPoint(x: CGFloat(config.width) / 2, y: 40)],  // Top center spawn (below safe area)
            corePosition: CGPoint(x: CGFloat(config.width) / 2, y: CGFloat(config.height) - 80),  // Above tower deck
            globalModifier: globalMod
        )
    }

    /// Create default enemy paths
    private static func createDefaultPaths(for map: TDMap) -> [EnemyPath] {
        // TD-style zig-zag path that stays within screen bounds
        // Use 15% margin on sides to keep path visible
        let marginX: CGFloat = map.width * 0.15
        let leftX = marginX
        let rightX = map.width - marginX
        let centerX = map.width / 2

        // Vertical segments at 20% intervals
        let topY: CGFloat = 40  // Start below safe area
        let seg1Y = map.height * 0.2
        let seg2Y = map.height * 0.4
        let seg3Y = map.height * 0.6
        let seg4Y = map.height * 0.8
        let bottomY = map.height - 80  // End above tower deck

        // Classic TD zig-zag pattern
        let waypoints: [CGPoint] = [
            CGPoint(x: centerX, y: topY),       // Start top center
            CGPoint(x: centerX, y: seg1Y),      // Down to first turn
            CGPoint(x: rightX, y: seg1Y),       // Right
            CGPoint(x: rightX, y: seg2Y),       // Down
            CGPoint(x: leftX, y: seg2Y),        // Left
            CGPoint(x: leftX, y: seg3Y),        // Down
            CGPoint(x: rightX, y: seg3Y),       // Right
            CGPoint(x: rightX, y: seg4Y),       // Down
            CGPoint(x: centerX, y: seg4Y),      // Center
            CGPoint(x: centerX, y: bottomY)     // End at core
        ]

        return [EnemyPath(id: "path_main", waypoints: waypoints)]
    }

    /// Create tower placement slots
    private static func createTowerSlots(for map: TDMap, avoiding paths: [EnemyPath]) -> [TowerSlot] {
        var slots: [TowerSlot] = []
        let slotSize: CGFloat = 40
        let margin: CGFloat = 60

        // Create grid of potential slots
        let cols = Int((map.width - margin * 2) / slotSize)
        let rows = Int((map.height - margin * 2) / slotSize)

        for row in 0..<rows {
            for col in 0..<cols {
                let x = margin + CGFloat(col) * slotSize + slotSize / 2
                let y = margin + CGFloat(row) * slotSize + slotSize / 2
                let point = CGPoint(x: x, y: y)

                // Check if slot overlaps with path
                var tooCloseToPath = false
                for path in paths {
                    for waypoint in path.waypoints {
                        let dx = point.x - waypoint.x
                        let dy = point.y - waypoint.y
                        if sqrt(dx*dx + dy*dy) < 50 {
                            tooCloseToPath = true
                            break
                        }
                    }
                }

                // Check if slot overlaps with obstacles
                var overlapsObstacle = false
                for obs in map.obstacles {
                    if obs.rect.contains(point) {
                        overlapsObstacle = true
                        break
                    }
                }

                if !tooCloseToPath && !overlapsObstacle {
                    slots.append(TowerSlot(
                        id: "slot_\(row)_\(col)",
                        x: x,
                        y: y,
                        size: slotSize
                    ))
                }
            }
        }

        return slots
    }

    // MARK: - Motherboard City Map (8-Lane System)

    /// Create game state for the Motherboard City map (4200x4200 PCB canvas)
    /// Uses the 8-lane sector system with PSU as starter
    static func createMotherboardGameState(
        playerProfile: PlayerProfile
    ) -> TDGameState? {
        // Get unlocked sectors from player profile
        let unlockedSectorIds = playerProfile.unlockedSectorIds

        // Get all lanes for rendering (all 8 lanes visible)
        let allLanes = MotherboardLaneConfig.createAllLanes()

        // Get only unlocked lanes for active enemy paths
        let activeLanes = MotherboardLaneConfig.getUnlockedLanes(unlockedSectorIds: unlockedSectorIds)
        let activePaths = activeLanes.map { lane -> EnemyPath in
            var path = lane.path
            path.sectorId = lane.sectorId
            return path
        }

        // Collect spawn points from active lanes only
        let activeSpawnPoints = activeLanes.map { $0.spawnPoint }

        // Create the map
        let map = TDMap(
            id: "motherboard",
            name: "Motherboard City",
            width: MotherboardLaneConfig.canvasSize,
            height: MotherboardLaneConfig.canvasSize,
            backgroundColor: MotherboardColors.substrate,
            theme: "motherboard",
            particleEffect: nil,
            obstacles: [],
            hazards: [],
            effectZones: [],
            spawnPoints: activeSpawnPoints,
            corePosition: MotherboardLaneConfig.cpuCenter,
            globalModifier: nil
        )

        // Create core at CPU center (center of the 3x3 grid)
        let core = TDCore(
            x: MotherboardLaneConfig.cpuCenter.x,
            y: MotherboardLaneConfig.cpuCenter.y,
            health: 100,
            maxHealth: 100
        )

        // Create tower slots along ALL paths (so slots exist when lanes unlock)
        let allPaths = allLanes.map { lane -> EnemyPath in
            var path = lane.path
            path.sectorId = lane.sectorId
            return path
        }
        let slots = createMotherboardTowerSlots(avoiding: allPaths)

        // Create blocker slots at path turns
        let blockerSlots = createBlockerSlots(for: activePaths)

        var state = TDGameState(
            sessionId: RandomUtils.generateId(),
            playerId: playerProfile.id,
            startTime: Date().timeIntervalSince1970,
            map: map,
            paths: activePaths,
            core: core,
            towers: [],
            towerSlots: slots,
            enemies: [],
            projectiles: [],
            particles: [],
            blockerSlots: blockerSlots,
            basePaths: activePaths
        )

        // Apply Global Upgrades
        state.baseHashPerSecond = playerProfile.globalUpgrades.hashPerSecond
        state.cpuMultiplier = 1.0
        state.cpuTier = playerProfile.globalUpgrades.cpuLevel
        state.efficiencyRegenMultiplier = playerProfile.globalUpgrades.efficiencyRegenMultiplier
        state.hashStorageCapacity = playerProfile.globalUpgrades.hashStorageCapacity
        state.powerCapacity = playerProfile.globalUpgrades.powerCapacity
        // Initialize hash from player profile (allows spending earned hash on towers)
        state.hash = min(playerProfile.hash, playerProfile.globalUpgrades.hashStorageCapacity)

        return state
    }

    /// Create tower slots for the motherboard map dynamically along paths
    /// Slots are placed adjacent to paths (within range to hit enemies)
    /// Uses path-proximity algorithm for dynamic slot generation
    private static func createMotherboardTowerSlots(avoiding paths: [EnemyPath]) -> [TowerSlot] {
        var slots: [TowerSlot] = []
        let slotSpacing: CGFloat = 80     // Distance between slots along path
        let pathDistance: CGFloat = 100   // Max distance from path center to slot
        let slotSize: CGFloat = 60
        let minSlotDistance: CGFloat = 70 // Minimum distance between slots

        // CPU exclusion zone (don't place slots on the CPU)
        // CPU is at center of 3x3 grid: (1.5 * 1400, 1.5 * 1400) = (2100, 2100)
        let cpuCenter = MotherboardLaneConfig.cpuCenter
        let cpuRadius: CGFloat = 200

        for path in paths {
            // Walk along each path segment
            guard path.waypoints.count > 1 else { continue }

            for i in 0..<path.waypoints.count - 1 {
                let start = path.waypoints[i]
                let end = path.waypoints[i + 1]

                // Calculate segment properties
                let dx = end.x - start.x
                let dy = end.y - start.y
                let segmentLength = sqrt(dx * dx + dy * dy)

                guard segmentLength > 0 else { continue }

                // Direction along segment (normalized)
                let dirX = dx / segmentLength
                let dirY = dy / segmentLength

                // Perpendicular direction (for placing slots on both sides)
                let perpX = -dirY
                let perpY = dirX

                // Walk along segment
                var distance: CGFloat = slotSpacing / 2  // Start slightly offset from corner
                while distance < segmentLength - slotSpacing / 2 {
                    // Center point on path at this distance
                    let centerX = start.x + dirX * distance
                    let centerY = start.y + dirY * distance

                    // Place slots on both sides of path
                    for side in [-1.0, 1.0] as [CGFloat] {
                        let slotX = centerX + perpX * pathDistance * side
                        let slotY = centerY + perpY * pathDistance * side
                        let slotCenter = CGPoint(x: slotX, y: slotY)

                        // Skip if too close to CPU
                        let cpuDist = sqrt(pow(slotX - cpuCenter.x, 2) + pow(slotY - cpuCenter.y, 2))
                        if cpuDist < cpuRadius {
                            continue
                        }

                        // Skip if too close to existing slots
                        if tooCloseToExisting(slotCenter, slots, minDistance: minSlotDistance) {
                            continue
                        }

                        // Skip if too close to the path itself (for safety)
                        var tooCloseToPath = false
                        for checkPath in paths {
                            for j in 0..<checkPath.waypoints.count - 1 {
                                let p1 = checkPath.waypoints[j]
                                let p2 = checkPath.waypoints[j + 1]
                                let dist = distanceToSegment(point: slotCenter, segStart: p1, segEnd: p2)
                                if dist < 60 {  // Minimum clearance from path
                                    tooCloseToPath = true
                                    break
                                }
                            }
                            if tooCloseToPath { break }
                        }

                        if tooCloseToPath { continue }

                        slots.append(TowerSlot(
                            id: "mb_slot_\(slots.count)",
                            x: slotX,
                            y: slotY,
                            size: slotSize
                        ))
                    }

                    distance += slotSpacing
                }
            }
        }

        // Add CPU defense area slots (around CPU perimeter in all 8 directions)
        let cpuDefenseSlots: [(CGFloat, CGFloat)] = [
            // Cardinals
            (cpuCenter.x - 220, cpuCenter.y),        // West of CPU
            (cpuCenter.x + 220, cpuCenter.y),        // East of CPU
            (cpuCenter.x, cpuCenter.y - 220),        // South of CPU
            (cpuCenter.x, cpuCenter.y + 220),        // North of CPU
            // Diagonals
            (cpuCenter.x - 180, cpuCenter.y - 180),  // Southwest
            (cpuCenter.x + 180, cpuCenter.y - 180),  // Southeast
            (cpuCenter.x - 180, cpuCenter.y + 180),  // Northwest
            (cpuCenter.x + 180, cpuCenter.y + 180),  // Northeast
        ]

        for (x, y) in cpuDefenseSlots {
            let point = CGPoint(x: x, y: y)
            if !tooCloseToExisting(point, slots, minDistance: minSlotDistance) {
                slots.append(TowerSlot(
                    id: "mb_slot_\(slots.count)",
                    x: x,
                    y: y,
                    size: slotSize
                ))
            }
        }

        return slots
    }

    /// Check if a point is too close to existing slots
    private static func tooCloseToExisting(_ point: CGPoint, _ slots: [TowerSlot], minDistance: CGFloat) -> Bool {
        for slot in slots {
            let dx = point.x - slot.x
            let dy = point.y - slot.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < minDistance {
                return true
            }
        }
        return false
    }

    /// Calculate distance from a point to a line segment
    private static func distanceToSegment(point: CGPoint, segStart: CGPoint, segEnd: CGPoint) -> CGFloat {
        let dx = segEnd.x - segStart.x
        let dy = segEnd.y - segStart.y

        if dx == 0 && dy == 0 {
            // Segment is a point
            let px = point.x - segStart.x
            let py = point.y - segStart.y
            return sqrt(px * px + py * py)
        }

        // Calculate projection
        let t = max(0, min(1, ((point.x - segStart.x) * dx + (point.y - segStart.y) * dy) / (dx * dx + dy * dy)))
        let projX = segStart.x + t * dx
        let projY = segStart.y + t * dy

        let px = point.x - projX
        let py = point.y - projY
        return sqrt(px * px + py * py)
    }
}
