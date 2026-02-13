import Foundation
import CoreGraphics

// MARK: - Game State Factory

class GameStateFactory {
    static let shared = GameStateFactory()

    private init() {}

    // MARK: - Debug Mode (System: Reboot)

    /// Create a game state for Debug mode using a Protocol as the weapon
    func createDebugGameState(
        gameProtocol: Protocol,
        sector: Sector,
        playerProfile: PlayerProfile
    ) -> GameState {
        let config = GameConfigLoader.shared

        // Use sector's visual theme to determine arena (or use a default debug arena)
        // Map sector themes to actual arena configs, falling back to "grasslands"
        let themeToArena: [String: String] = [
            "ram": "ice_cave",      // RAM = cool blue memory banks
            "drive": "castle",      // Drive = structured storage
            "gpu": "volcano",       // GPU = hot processing
            "bios": "space"         // BIOS = deep system space
        ]
        let arenaType = themeToArena[sector.visualTheme] ?? "grasslands"
        guard let arenaConfig = config.getArena(arenaType) else {
            fatalError("Arena \(arenaType) not found in config")
        }

        // Create arena data
        var arena = config.createArenaData(from: arenaConfig)
        arena.name = sector.name

        // Apply player's protocol level before converting to weapon
        var leveledProtocol = gameProtocol
        leveledProtocol.level = playerProfile.protocolLevel(gameProtocol.id)

        // Create weapon from Protocol (now with correct level for damage scaling)
        let weapon = leveledProtocol.toWeapon()

        // Create player at arena center
        var player = createPlayer(
            x: arena.width / 2,
            y: arena.height / 2,
            weapon: weapon
        )

        // Apply RAM upgrade (health bonus) from component levels
        // healthBonus returns absolute value (100, 120, 140...) so we use it directly
        player.maxHealth = playerProfile.componentLevels.healthBonus
        player.health = player.maxHealth

        // Apply Cache upgrade (attack speed bonus) to weapon
        let fireRateMultiplier = playerProfile.componentLevels.attackSpeedMultiplier
        player.weapons[0].attackSpeed *= fireRateMultiplier

        let now = Date().timeIntervalSince1970

        return GameState(
            sessionId: RandomUtils.generateId(),
            playerId: playerProfile.id,
            startTime: now,
            gameMode: .boss,  // Debug mode uses boss gameplay
            arena: arena,
            player: player,
            currentWeaponType: gameProtocol.id,
            runStartTime: now,
            hashMultiplier: sector.hashMultiplier  // Apply sector's hash multiplier
        )
    }

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

    /// Get level damage multiplier
    private func getLevelMultiplier(level: Int) -> CGFloat {
        return BalanceConfig.Leveling.baseDamageMultiplier +
               CGFloat(level - 1) * BalanceConfig.Leveling.damagePerLevel
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
        let arenaConfig = config.getArena("memory_core") ?? config.getArena("grasslands")!
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
                isCorrupted: false,
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
                isCorrupted: false,
                health: pillarHealth,
                maxHealth: pillarHealth
            ))
        }

        return pillars
    }
}

// MARK: - Default Player Profile
// Note: defaultProfile is now defined in GameTypes.swift with the unified progression system
