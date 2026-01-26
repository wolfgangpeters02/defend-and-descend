import Foundation
import CoreGraphics

// MARK: - Game State Factory

class GameStateFactory {
    static let shared = GameStateFactory()

    private init() {}

    /// Create a new game state for arena mode
    func createArenaGameState(
        weaponType: String = "bow",
        powerUpType: String = "tank",
        arenaType: String = "city",
        playerProfile: PlayerProfile? = nil
    ) -> GameState {
        let config = GameConfigLoader.shared

        // Get arena config
        guard let arenaConfig = config.getArena(arenaType) else {
            fatalError("Arena \(arenaType) not found in config")
        }

        // Create arena data
        let arena = config.createArenaData(from: arenaConfig)

        // Get weapon config
        guard let weaponConfig = config.getWeapon(weaponType) else {
            fatalError("Weapon \(weaponType) not found in config")
        }

        // Create weapon
        var weapon = config.createWeapon(from: weaponConfig)

        // Apply weapon level from profile
        if let profile = playerProfile {
            let level = profile.weaponLevels[weaponType] ?? 1
            let multiplier = getLevelMultiplier(level: level)
            weapon.damage *= multiplier
            weapon.level = level
        }

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

        let now = Date().timeIntervalSince1970

        return GameState(
            sessionId: RandomUtils.generateId(),
            playerId: playerProfile?.id ?? "default",
            startTime: now,
            gameMode: .arena,
            arena: arena,
            player: player,
            currentWeaponType: weaponType,
            currentPowerUpType: powerUpType,
            activeSynergy: nil,
            runStartTime: now
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
        let arenaType = sector.visualTheme
        let arenaConfig = config.getArena(arenaType) ?? config.getArena("city")!

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

    /// Create a new game state for dungeon mode
    func createDungeonGameState(
        weaponType: String = "bow",
        powerUpType: String = "tank",
        arenaType: String = "city",
        playerProfile: PlayerProfile? = nil
    ) -> GameState {
        // Start with arena state, then add dungeon features
        var state = createArenaGameState(
            weaponType: weaponType,
            powerUpType: powerUpType,
            arenaType: arenaType,
            playerProfile: playerProfile
        )

        // Change mode to dungeon
        state.gameMode = .dungeon

        // Create dungeon rooms
        state.rooms = DungeonSystem.createDungeonRooms(arenaId: arenaType)
        state.currentRoomIndex = 0

        // Set current room
        if let firstRoom = state.rooms?.first {
            state.currentRoom = firstRoom

            // Update arena dimensions to match room
            state.arena.width = firstRoom.width
            state.arena.height = firstRoom.height
            state.arena.backgroundColor = firstRoom.backgroundColor
            state.arena.obstacles = firstRoom.obstacles
            state.arena.hazards = firstRoom.hazards
            state.arena.effectZones = firstRoom.effectZones

            // Position player at room center
            state.player.x = firstRoom.width / 2
            state.player.y = firstRoom.height / 2
        }

        state.dungeonCountdown = nil
        state.dungeonCountdownActive = false

        return state
    }
}

// MARK: - Default Player Profile
// Note: defaultProfile is now defined in GameTypes.swift with the unified progression system
