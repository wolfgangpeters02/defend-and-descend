import Foundation
import CoreGraphics

// MARK: - Game State Factory

class GameStateFactory {
    static let shared = GameStateFactory()

    private init() {}

    /// Create a player instance
    private func createPlayer(x: CGFloat, y: CGFloat, weapon: Weapon) -> Player {
        return Player(
            x: x,
            y: y,
            health: BalanceConfig.Player.baseHealth,
            maxHealth: BalanceConfig.Player.baseHealth,
            speed: BalanceConfig.Player.baseSpeed,
            size: BalanceConfig.Player.size,
            weapons: [weapon],
            pickupRange: BalanceConfig.Player.pickupRange,
            armor: 0,
            regen: BalanceConfig.Player.baseRegen,
            abilities: nil,
            trail: [],
            invulnerable: false,
            invulnerableUntil: 0,
            velocityX: 0,
            velocityY: 0,
            moving: false
        )
    }

    /// Create a new game state for boss encounter mode
    func createBossGameState(
        gameProtocol: Protocol,
        bossType: String,
        difficulty: BossDifficulty = .normal,
        playerProfile: PlayerProfile? = nil
    ) -> GameState {
        let config = GameConfigLoader.shared

        // Boss arenas are simple circular arenas
        let arenaConfig = config.getArena("memory_core") ?? config.getArena(ArenaID.starter.rawValue) ?? ArenaConfig(id: "fallback", name: "Arena", rarity: "common", width: 1200, height: 900, backgroundColor: "#0a0a1a", theme: "default")
        var arena = config.createArenaData(from: arenaConfig)

        // Boss arena is larger for strategic movement
        arena.width = 1200
        arena.height = 900
        arena.obstacles = createBossPillars()  // Add destructible cover pillars

        // Apply player's protocol level before converting to weapon
        var leveledProtocol = gameProtocol
        if let profile = playerProfile {
            leveledProtocol.level = profile.protocolLevel(gameProtocol.id)
        }

        // Create weapon from Protocol (now with correct level for damage scaling)
        let weapon = leveledProtocol.toWeapon()

        // Create player at center of arena
        var player = createPlayer(
            x: arena.width / 2,
            y: arena.height / 2,  // Player starts in center
            weapon: weapon
        )

        // Apply difficulty modifiers
        player.maxHealth *= difficulty.playerHealthMultiplier
        player.health = player.maxHealth
        // Apply player damage multiplier to weapon
        player.weapons[0].damage *= difficulty.playerDamageMultiplier

        // Apply component upgrades from profile
        if let profile = playerProfile {
            player.maxHealth = profile.componentLevels.healthBonus * (player.maxHealth / 100)
            player.health = player.maxHealth
            let fireRateMultiplier = profile.componentLevels.attackSpeedMultiplier
            player.weapons[0].attackSpeed *= fireRateMultiplier
        }

        let now = Date().timeIntervalSince1970

        var state = GameState(
            sessionId: RandomUtils.generateId(),
            playerId: playerProfile?.id ?? "default",
            startTime: now,
            gameMode: .boss,
            arena: arena,
            player: player,
            currentWeaponType: gameProtocol.id,
            runStartTime: now
        )

        // Set up boss encounter
        state.activeBossId = bossType
        state.bossDifficulty = difficulty

        return state
    }

    /// Create destructible pillars for boss arena (1200x900)
    /// Layout: 4 inner ring + 4 outer ring = 8 total
    private func createBossPillars() -> [Obstacle] {
        let pillarSize: CGFloat = BalanceConfig.Pillar.defaultSize
        let pillarHealth: CGFloat = BalanceConfig.Pillar.defaultHealth

        // Pillar positions for 1200x900 arena
        // Inner ring (quadrant positions)
        let innerPositions: [(CGFloat, CGFloat)] = [
            (300, 300),   // Top-left quadrant
            (900, 300),   // Top-right quadrant
            (300, 600),   // Bottom-left quadrant
            (900, 600)    // Bottom-right quadrant
        ]

        // Outer ring (edge centers)
        let outerPositions: [(CGFloat, CGFloat)] = [
            (600, 150),   // Top center
            (150, 450),   // Left center
            (1050, 450),  // Right center
            (600, 750)    // Bottom center
        ]

        var pillars: [Obstacle] = []

        // Create inner pillars
        for (index, pos) in innerPositions.enumerated() {
            pillars.append(Obstacle(
                id: "pillar_inner_\(index)",
                x: pos.0 - pillarSize / 2,
                y: pos.1 - pillarSize / 2,
                width: pillarSize,
                height: pillarSize,
                color: "#4a5568",  // Gray color
                type: "pillar",

                health: pillarHealth,
                maxHealth: pillarHealth
            ))
        }

        // Create outer pillars
        for (index, pos) in outerPositions.enumerated() {
            pillars.append(Obstacle(
                id: "pillar_outer_\(index)",
                x: pos.0 - pillarSize / 2,
                y: pos.1 - pillarSize / 2,
                width: pillarSize,
                height: pillarSize,
                color: "#4a5568",  // Gray color
                type: "pillar",

                health: pillarHealth,
                maxHealth: pillarHealth
            ))
        }

        return pillars
    }
}

// MARK: - Default Player Profile
// Note: defaultProfile is now defined in GameTypes.swift with the unified progression system
