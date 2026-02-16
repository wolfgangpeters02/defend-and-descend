import Foundation
import CoreGraphics

// MARK: - Upgrade System

class UpgradeSystem {

    // Rarity weights (from BalanceConfig)
    private static let rarityWeights: [(rarity: Rarity, weight: Double)] = [
        (.common, BalanceConfig.UpgradeRarity.commonWeight),
        (.rare, BalanceConfig.UpgradeRarity.rareWeight),
        (.epic, BalanceConfig.UpgradeRarity.epicWeight),
        (.legendary, BalanceConfig.UpgradeRarity.legendaryWeight)
    ]

    /// Generate upgrade choices for player selection
    /// In dungeon mode, includes dungeon-only abilities (lifesteal, thorns, phoenix, etc.)
    /// In arena mode, only uses shared upgrades that work in both modes
    static func generateUpgradeChoices(state: GameState, count: Int = 3) -> [UpgradeChoice] {
        let config = GameConfigLoader.shared
        var choices: [UpgradeChoice] = []
        var usedIds = Set<String>()
        var attempts = 0
        let maxAttempts = 50

        let includeDungeonUpgrades = state.gameMode == .boss

        while choices.count < count && attempts < maxAttempts {
            attempts += 1

            // Pick random rarity
            guard let rarity = pickRarity() else { continue }

            // Get upgrades for this rarity (shared upgrades always available)
            var upgrades = config.getUpgrades(rarity: rarity)

            // In dungeon mode, also include dungeon-only upgrades
            if includeDungeonUpgrades {
                let dungeonUpgrades = config.getDungeonUpgrades(rarity: rarity)
                upgrades.append(contentsOf: dungeonUpgrades)
            }

            guard !upgrades.isEmpty else { continue }

            // Pick random upgrade
            guard let upgrade = upgrades.randomElement() else { continue }

            // Check for duplicates
            if usedIds.contains(upgrade.id) { continue }
            usedIds.insert(upgrade.id)

            // Convert to UpgradeChoice
            choices.append(UpgradeChoice(
                id: upgrade.id,
                name: upgrade.name,
                description: upgrade.description,
                icon: upgrade.icon,
                rarity: rarity,
                effect: UpgradeEffect(
                    type: UpgradeEffectType(rawValue: upgrade.effect.type) ?? .stat,
                    target: upgrade.effect.target,
                    value: CGFloat(upgrade.effect.value),
                    isMultiplier: upgrade.effect.isMultiplier
                )
            ))
        }

        return choices
    }

    /// Pick a rarity based on weights
    private static func pickRarity() -> Rarity? {
        let totalWeight = rarityWeights.reduce(0) { $0 + $1.weight }
        var random = Double.random(in: 0...totalWeight)

        for (rarity, weight) in rarityWeights {
            random -= weight
            if random <= 0 {
                return rarity
            }
        }

        return .common
    }

    /// Apply selected upgrade to game state
    static func applyUpgrade(state: inout GameState, choice: UpgradeChoice) {
        switch choice.effect.type {
        case .stat:
            applyStatUpgrade(state: &state, target: choice.effect.target, value: choice.effect.value, isMultiplier: choice.effect.isMultiplier ?? false)
        case .weapon:
            applyWeaponUpgrade(state: &state, target: choice.effect.target, value: choice.effect.value, isMultiplier: choice.effect.isMultiplier ?? false)
        case .ability:
            applyAbilityUpgrade(state: &state, target: choice.effect.target, value: choice.effect.value)
        }

        state.stats.upgradesChosen += 1
        state.upgradeLevel += 1
        state.pendingUpgrade = false
        state.upgradeChoices = []
    }

    /// Apply stat upgrade (works in all modes)
    private static func applyStatUpgrade(state: inout GameState, target: String, value: CGFloat, isMultiplier: Bool) {
        // Convert string to enum for type safety
        guard let targetType = UpgradeTargetType(rawValue: target) else { return }

        switch targetType {
        case .damage:
            for i in 0..<state.player.weapons.count {
                if isMultiplier {
                    state.player.weapons[i].damage *= value
                } else {
                    state.player.weapons[i].damage += value
                }
            }

        case .maxHealth:
            let oldMax = state.player.maxHealth
            if isMultiplier {
                state.player.maxHealth *= value
            } else {
                state.player.maxHealth += value
            }
            // Scale current health proportionally
            let healthRatio = state.player.health / oldMax
            state.player.health = state.player.maxHealth * healthRatio

        case .speed:
            if isMultiplier {
                state.player.speed *= value
            } else {
                state.player.speed += value
            }

        case .regen:
            state.player.regen += value

        case .armor:
            state.player.armor += value
            // Cap armor at configured maximum
            state.player.armor = min(BalanceConfig.Player.maxArmor, state.player.armor)

        case .pickupRange:
            if isMultiplier {
                state.player.pickupRange *= value
            } else {
                state.player.pickupRange += value
            }

        default:
            break // Non-stat upgrades handled elsewhere
        }
    }

    /// Apply weapon upgrade (works in all modes - shared between survivor and TD)
    private static func applyWeaponUpgrade(state: inout GameState, target: String, value: CGFloat, isMultiplier: Bool) {
        // Convert string to enum for type safety
        guard let targetType = UpgradeTargetType(rawValue: target) else { return }

        for i in 0..<state.player.weapons.count {
            switch targetType {
            case .attackSpeed:
                if isMultiplier {
                    state.player.weapons[i].attackSpeed *= value
                } else {
                    state.player.weapons[i].attackSpeed += value
                }

            case .range:
                if isMultiplier {
                    state.player.weapons[i].range *= value
                } else {
                    state.player.weapons[i].range += value
                }

            case .projectileCount:
                let current = state.player.weapons[i].projectileCount ?? 1
                state.player.weapons[i].projectileCount = current + Int(value)

            case .pierce:
                let current = state.player.weapons[i].pierce ?? 0
                state.player.weapons[i].pierce = current + Int(value)

            case .splash:
                let current = state.player.weapons[i].splash ?? 0
                state.player.weapons[i].splash = current + value

            case .homing:
                state.player.weapons[i].homing = true

            default:
                break // Non-weapon upgrades handled elsewhere
            }
        }
    }

    /// Apply ability upgrade (dungeon-only abilities like lifesteal, thorns, phoenix)
    private static func applyAbilityUpgrade(state: inout GameState, target: String, value: CGFloat) {
        // Convert string to enum for type safety
        guard let targetType = UpgradeTargetType(rawValue: target) else { return }

        if state.player.abilities == nil {
            state.player.abilities = PlayerAbilities()
        }

        switch targetType {
        case .lifesteal:
            // Dungeon only - heal on damage dealt
            let current = state.player.abilities?.lifesteal ?? 0
            state.player.abilities?.lifesteal = current + value

        case .revive:
            // Dungeon only - phoenix rebirth
            let current = state.player.abilities?.revive ?? 0
            state.player.abilities?.revive = current + Int(value)

        case .thorns:
            // Dungeon only - reflect damage
            let current = state.player.abilities?.thorns ?? 0
            state.player.abilities?.thorns = current + value

        case .explosionOnKill:
            // Dungeon only - enemies explode
            let current = state.player.abilities?.explosionOnKill ?? 0
            state.player.abilities?.explosionOnKill = current + value

        case .orbitalStrike:
            // Dungeon only - periodic screen damage
            let current = state.player.abilities?.orbitalStrike ?? 0
            state.player.abilities?.orbitalStrike = current + value

        case .timeFreeze:
            // Dungeon only - freeze enemies
            let current = state.player.abilities?.timeFreeze ?? 0
            state.player.abilities?.timeFreeze = current + value

        case .allStats:
            // Universal - boost all stats (shared upgrade)
            for i in 0..<state.player.weapons.count {
                state.player.weapons[i].damage *= value
            }
            state.player.maxHealth *= value
            state.player.health *= value
            state.player.speed *= value

        default:
            break // Non-ability upgrades handled elsewhere
        }
    }

    /// Check if upgrade should trigger
    static func shouldTriggerUpgrade(state: GameState) -> Bool {
        // TD mode: no mid-game upgrades (towers are pre-placed)
        // Boss mode: upgrades come from XP level-ups
        return false
    }

    /// Trigger upgrade selection
    static func triggerUpgrade(state: inout GameState) {
        state.pendingUpgrade = true
        state.upgradeChoices = generateUpgradeChoices(state: state)
    }
}
