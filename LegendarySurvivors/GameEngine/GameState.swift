import Foundation
import CoreGraphics

// MARK: - Game State Factory

class GameStateFactory {
    static let shared = GameStateFactory()

    private init() {}

    /// Create a new game state for arena mode using a Protocol
    func createArenaGameState(
        gameProtocol: Protocol,
        powerUpType: String = "tank",
        arenaType: String = "grasslands",
        playerProfile: PlayerProfile? = nil
    ) -> GameState {
        let config = GameConfigLoader.shared

        // Get arena config
        guard let arenaConfig = config.getArena(arenaType) else {
            fatalError("Arena \(arenaType) not found in config")
        }

        // Create arena data
        let arena = config.createArenaData(from: arenaConfig)

        // Create weapon from Protocol (unified weapon system)
        let weapon = gameProtocol.toWeapon()

        // Create player at arena center
        var player = createPlayer(
            x: arena.width / 2,
            y: arena.height / 2,
            weapon: weapon
        )

        // Apply powerup effects
        if let powerUpConfig = config.getPowerUp(powerUpType) {
            applyPowerUpEffects(to: &player, powerUp: powerUpConfig, profile: playerProfile)
        }

        // Apply arena global modifier
        if let modifier = arena.globalModifier {
            if let speedMult = modifier.playerSpeedMultiplier {
                player.speed *= speedMult
            }
        }

        // Apply global upgrades from profile
        if let profile = playerProfile {
            player.maxHealth = profile.globalUpgrades.healthBonus
            player.health = player.maxHealth
            let fireRateMultiplier = profile.globalUpgrades.fireRateMultiplier
            player.weapons[0].attackSpeed *= fireRateMultiplier
        }

        let now = Date().timeIntervalSince1970

        return GameState(
            sessionId: RandomUtils.generateId(),
            playerId: playerProfile?.id ?? "default",
            startTime: now,
            gameMode: .arena,
            arena: arena,
            player: player,
            currentWeaponType: gameProtocol.id,
            currentPowerUpType: powerUpType,
            activeSynergy: nil,
            runStartTime: now
        )
    }

    /// Legacy arena creation - kept for backward compatibility, defaults to kernel_pulse
    @available(*, deprecated, message: "Use createArenaGameState(gameProtocol:) instead")
    func createArenaGameState(
        weaponType: String = "kernel_pulse",
        powerUpType: String = "tank",
        arenaType: String = "grasslands",
        playerProfile: PlayerProfile? = nil
    ) -> GameState {
        // Find the Protocol matching the weaponType, default to kernel_pulse
        let proto = ProtocolLibrary.all.first { $0.id == weaponType } ?? ProtocolLibrary.kernelPulse
        return createArenaGameState(
            gameProtocol: proto,
            powerUpType: powerUpType,
            arenaType: arenaType,
            playerProfile: playerProfile
        )
    }

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

        // Create weapon from Protocol
        let weapon = gameProtocol.toWeapon()

        // Create player at arena center
        var player = createPlayer(
            x: arena.width / 2,
            y: arena.height / 2,
            weapon: weapon
        )

        // Apply RAM upgrade (health bonus) from global upgrades
        // healthBonus returns absolute value (100, 120, 140...) so we use it directly
        player.maxHealth = playerProfile.globalUpgrades.healthBonus
        player.health = player.maxHealth

        // Apply Cooling upgrade (fire rate bonus) to weapon
        let fireRateMultiplier = playerProfile.globalUpgrades.fireRateMultiplier
        player.weapons[0].attackSpeed *= fireRateMultiplier

        let now = Date().timeIntervalSince1970

        return GameState(
            sessionId: RandomUtils.generateId(),
            playerId: playerProfile.id,
            startTime: now,
            gameMode: .arena,  // Debug mode uses arena gameplay
            arena: arena,
            player: player,
            currentWeaponType: gameProtocol.id,
            currentPowerUpType: "none",
            activeSynergy: nil,
            runStartTime: now,
            dataMultiplier: sector.dataMultiplier  // Apply sector's data multiplier
        )
    }

    /// Create a player instance
    private func createPlayer(x: CGFloat, y: CGFloat, weapon: Weapon) -> Player {
        return Player(
            x: x,
            y: y,
            health: GameConstants.defaultPlayerHealth,
            maxHealth: GameConstants.defaultPlayerHealth,
            speed: GameConstants.defaultPlayerSpeed,
            size: GameConstants.defaultPlayerSize,
            weapons: [weapon],
            pickupRange: GameConstants.defaultPickupRange,
            armor: 0,
            regen: GameConstants.defaultRegen,
            abilities: nil,
            trail: [],
            invulnerable: false,
            invulnerableUntil: 0,
            velocityX: 0,
            velocityY: 0,
            moving: false
        )
    }

    /// Apply powerup effects to player
    private func applyPowerUpEffects(to player: inout Player, powerUp: PowerUpConfig, profile: PlayerProfile?) {
        let effects = powerUp.effects

        // Apply multipliers
        if let healthMult = effects.healthMultiplier {
            player.maxHealth *= CGFloat(healthMult)
            player.health = player.maxHealth
        }

        if let damageMult = effects.damageMultiplier {
            for i in 0..<player.weapons.count {
                player.weapons[i].damage *= CGFloat(damageMult)
            }
        }

        if let speedMult = effects.speedMultiplier {
            player.speed *= CGFloat(speedMult)
        }

        // Apply starting abilities
        if let ability = effects.startWithAbility {
            if player.abilities == nil {
                player.abilities = PlayerAbilities()
            }

            switch ability {
            case "lifesteal":
                player.abilities?.lifesteal = 0.15
            case "revive":
                player.abilities?.revive = 1
            case "explosionOnKill":
                player.abilities?.explosionOnKill = 60
            case "regen":
                player.regen += 3
            case "rangeBoost":
                for i in 0..<player.weapons.count {
                    player.weapons[i].range *= 1.5
                }
            case "attackSpeedBoost":
                for i in 0..<player.weapons.count {
                    player.weapons[i].attackSpeed *= 1.3
                }
            case "armorBoost":
                player.armor += 0.3
            case "magnet":
                player.pickupRange *= 2
            case "healing":
                player.regen += 2
            case "thorns":
                player.abilities?.thorns = 0.3
            case "lightning":
                player.abilities?.orbitalStrike = 100
            case "timeFreeze":
                player.abilities?.timeFreeze = 3
            default:
                break
            }
        }

        // Apply powerup level bonus from profile
        if let profile = profile {
            let level = profile.powerupLevels[powerUp.id] ?? 1
            if level > 1 {
                let bonus = CGFloat(level - 1) * 0.05 // 5% per level
                player.maxHealth *= (1 + bonus)
                player.health = player.maxHealth
                for i in 0..<player.weapons.count {
                    player.weapons[i].damage *= (1 + bonus)
                }
            }
        }
    }

    /// Get level damage multiplier
    private func getLevelMultiplier(level: Int) -> CGFloat {
        return WeaponMasteryConstants.baseDamageMultiplier +
               CGFloat(level - 1) * WeaponMasteryConstants.damagePerLevel
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

        // Boss arena is smaller and more intense
        arena.width = 600
        arena.height = 600
        arena.obstacles = []  // No obstacles in boss fights - mechanics ARE the challenge

        // Create weapon from Protocol
        let weapon = gameProtocol.toWeapon()

        // Create player at arena center
        var player = createPlayer(
            x: arena.width / 2,
            y: arena.height * 0.75,  // Player starts in bottom half
            weapon: weapon
        )

        // Apply difficulty modifiers
        switch difficulty {
        case .normal:
            break  // No changes
        case .hard:
            player.maxHealth *= 0.8  // 20% less health
            player.health = player.maxHealth
        case .nightmare:
            player.maxHealth *= 0.6  // 40% less health
            player.health = player.maxHealth
        }

        // Apply global upgrades from profile
        if let profile = playerProfile {
            player.maxHealth = profile.globalUpgrades.healthBonus * (player.maxHealth / 100)
            player.health = player.maxHealth
            let fireRateMultiplier = profile.globalUpgrades.fireRateMultiplier
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
            currentPowerUpType: "none",
            activeSynergy: nil,
            runStartTime: now
        )

        // Set up boss encounter
        state.activeBossId = bossType
        state.bossDifficulty = difficulty

        return state
    }
}

// MARK: - Default Player Profile
// Note: defaultProfile is now defined in GameTypes.swift with the unified progression system
