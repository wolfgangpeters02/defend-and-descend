import Foundation
import CoreGraphics

// MARK: - Synergy System

struct SynergyDefinition {
    let weapon: String // "any" for any weapon
    let powerup: String // "any" for any powerup
    let name: String
    let description: String
    let apply: (inout Player) -> Void
}

class SynergySystem {

    // Pre-defined synergies
    static let synergies: [SynergyDefinition] = [
        // Bow + Sniper = Precision Strike
        SynergyDefinition(
            weapon: "bow",
            powerup: "sniper",
            name: "Precision Strike",
            description: "+50% damage, +30% range"
        ) { player in
            for i in 0..<player.weapons.count {
                player.weapons[i].damage *= 1.5
                player.weapons[i].range *= 1.3
            }
        },

        // Sword + Berserker = Blood Rage
        SynergyDefinition(
            weapon: "sword",
            powerup: "berserker",
            name: "Blood Rage",
            description: "+100% damage, +50% attack speed"
        ) { player in
            for i in 0..<player.weapons.count {
                player.weapons[i].damage *= 2.0
                player.weapons[i].attackSpeed *= 1.5
            }
        },

        // Wand + Mage = Arcane Mastery
        SynergyDefinition(
            weapon: "wand",
            powerup: "mage",
            name: "Arcane Mastery",
            description: "+3 projectiles, homing enabled"
        ) { player in
            for i in 0..<player.weapons.count {
                let current = player.weapons[i].projectileCount ?? 1
                player.weapons[i].projectileCount = current + 3
                player.weapons[i].homing = true
            }
        },

        // Flamethrower + Flame Aura = Inferno
        SynergyDefinition(
            weapon: "flamethrower",
            powerup: "flame_aura",
            name: "Inferno",
            description: "+80% damage, enemies burn"
        ) { player in
            for i in 0..<player.weapons.count {
                player.weapons[i].damage *= 1.8
                let current = player.weapons[i].splash ?? 0
                player.weapons[i].splash = current + 50
            }
        },

        // Ice Shard + Ice Walker = Frozen Dominion
        SynergyDefinition(
            weapon: "ice_shard",
            powerup: "ice_walker",
            name: "Frozen Dominion",
            description: "Enemies permanently slowed, +40% damage"
        ) { player in
            for i in 0..<player.weapons.count {
                player.weapons[i].damage *= 1.4
            }
        },

        // Lightning + Thor = Storm Lord
        SynergyDefinition(
            weapon: "lightning",
            powerup: "thor",
            name: "Storm Lord",
            description: "+5 pierce, chain lightning"
        ) { player in
            for i in 0..<player.weapons.count {
                let current = player.weapons[i].pierce ?? 0
                player.weapons[i].pierce = current + 5
                player.weapons[i].damage *= 1.3
            }
        },

        // Scythe + Necromancer = Death's Embrace
        SynergyDefinition(
            weapon: "scythe",
            powerup: "necromancer",
            name: "Death's Embrace",
            description: "+15% lifesteal, explosion on kill"
        ) { player in
            if player.abilities == nil {
                player.abilities = PlayerAbilities()
            }
            let currentLifesteal = player.abilities?.lifesteal ?? 0
            player.abilities?.lifesteal = currentLifesteal + 0.15
            let currentExplosion = player.abilities?.explosionOnKill ?? 0
            player.abilities?.explosionOnKill = currentExplosion + 80
        },

        // Excalibur + Paladin = Divine Champion
        SynergyDefinition(
            weapon: "excalibur",
            powerup: "paladin",
            name: "Divine Champion",
            description: "+100% damage, +1 revive"
        ) { player in
            for i in 0..<player.weapons.count {
                player.weapons[i].damage *= 2.0
            }
            if player.abilities == nil {
                player.abilities = PlayerAbilities()
            }
            let currentRevives = player.abilities?.revive ?? 0
            player.abilities?.revive = currentRevives + 1
        },

        // Dual Guns + Gunslinger = Bullet Storm
        SynergyDefinition(
            weapon: "dual_guns",
            powerup: "gunslinger",
            name: "Bullet Storm",
            description: "+4 projectiles, +100% attack speed"
        ) { player in
            for i in 0..<player.weapons.count {
                let current = player.weapons[i].projectileCount ?? 1
                player.weapons[i].projectileCount = current + 4
                player.weapons[i].attackSpeed *= 2.0
            }
        },

        // Bomb + Bomber = Demolition Expert
        SynergyDefinition(
            weapon: "bomb",
            powerup: "bomber",
            name: "Demolition Expert",
            description: "+200% splash radius, screen shake"
        ) { player in
            for i in 0..<player.weapons.count {
                let current = player.weapons[i].splash ?? 50
                player.weapons[i].splash = current * 3.0
            }
        },

        // Staff + Time Lord = Temporal Master
        SynergyDefinition(
            weapon: "staff",
            powerup: "time_lord",
            name: "Temporal Master",
            description: "Time freeze on hit, +50% damage"
        ) { player in
            for i in 0..<player.weapons.count {
                player.weapons[i].damage *= 1.5
            }
            if player.abilities == nil {
                player.abilities = PlayerAbilities()
            }
            let current = player.abilities?.timeFreeze ?? 0
            player.abilities?.timeFreeze = current + 2
        },

        // Any + Phoenix = Undying Flame
        SynergyDefinition(
            weapon: "any",
            powerup: "phoenix",
            name: "Undying Flame",
            description: "+2 revives, fire trail"
        ) { player in
            if player.abilities == nil {
                player.abilities = PlayerAbilities()
            }
            let current = player.abilities?.revive ?? 0
            player.abilities?.revive = current + 2
        }
    ]

    /// Find and apply synergy for weapon + powerup combination
    static func applySynergy(player: inout Player, weaponType: String, powerupType: String) -> Synergy? {
        // Find matching synergy
        for definition in synergies {
            let weaponMatch = definition.weapon == "any" || definition.weapon == weaponType
            let powerupMatch = definition.powerup == "any" || definition.powerup == powerupType

            if weaponMatch && powerupMatch {
                // Apply the synergy
                definition.apply(&player)

                return Synergy(
                    name: definition.name,
                    description: definition.description,
                    effects: [:] // Effects are applied directly
                )
            }
        }

        return nil
    }

    /// Get synergy preview (without applying)
    static func getSynergy(weaponType: String, powerupType: String) -> (name: String, description: String)? {
        for definition in synergies {
            let weaponMatch = definition.weapon == "any" || definition.weapon == weaponType
            let powerupMatch = definition.powerup == "any" || definition.powerup == powerupType

            if weaponMatch && powerupMatch {
                return (definition.name, definition.description)
            }
        }

        return nil
    }
}
