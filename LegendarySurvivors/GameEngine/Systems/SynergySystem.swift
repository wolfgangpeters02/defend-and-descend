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

    // Pre-defined synergies (Protocol-based unified system)
    static let synergies: [SynergyDefinition] = [
        // kernel_pulse + sniper = Targeted Kill
        SynergyDefinition(
            weapon: "kernel_pulse",
            powerup: "sniper",
            name: "Targeted Kill",
            description: "+50% damage, +30% range"
        ) { player in
            for i in 0..<player.weapons.count {
                player.weapons[i].damage *= 1.5
                player.weapons[i].range *= 1.3
            }
        },

        // kernel_pulse + tank = Hardened Protocol
        SynergyDefinition(
            weapon: "kernel_pulse",
            powerup: "tank",
            name: "Hardened Protocol",
            description: "+30% damage, +20% armor"
        ) { player in
            for i in 0..<player.weapons.count {
                player.weapons[i].damage *= 1.3
            }
            player.armor += 0.2
        },

        // burst_protocol + tank = Suppression Fire
        SynergyDefinition(
            weapon: "burst_protocol",
            powerup: "tank",
            name: "Suppression Fire",
            description: "+100% splash radius, +20% damage"
        ) { player in
            for i in 0..<player.weapons.count {
                let current = player.weapons[i].splash ?? 30
                player.weapons[i].splash = current * 2.0
                player.weapons[i].damage *= 1.2
            }
        },

        // trace_route + sniper = Memory Dump
        SynergyDefinition(
            weapon: "trace_route",
            powerup: "sniper",
            name: "Memory Dump",
            description: "+100% damage, +3 pierce"
        ) { player in
            for i in 0..<player.weapons.count {
                player.weapons[i].damage *= 2.0
                let current = player.weapons[i].pierce ?? 1
                player.weapons[i].pierce = current + 3
            }
        },

        // ice_shard + ice_walker = System Freeze
        SynergyDefinition(
            weapon: "ice_shard",
            powerup: "ice_walker",
            name: "System Freeze",
            description: "Enemies permanently slowed, +40% damage"
        ) { player in
            for i in 0..<player.weapons.count {
                player.weapons[i].damage *= 1.4
            }
        },

        // fork_bomb + berserker = Process Explosion
        SynergyDefinition(
            weapon: "fork_bomb",
            powerup: "berserker",
            name: "Process Explosion",
            description: "+3 projectiles, +50% attack speed"
        ) { player in
            for i in 0..<player.weapons.count {
                let current = player.weapons[i].projectileCount ?? 3
                player.weapons[i].projectileCount = current + 3
                player.weapons[i].attackSpeed *= 1.5
            }
        },

        // root_access + sniper = Kernel Panic
        SynergyDefinition(
            weapon: "root_access",
            powerup: "sniper",
            name: "Kernel Panic",
            description: "+150% damage, enemies stunned"
        ) { player in
            for i in 0..<player.weapons.count {
                player.weapons[i].damage *= 2.5
            }
        },

        // overflow + thor = Stack Overflow
        SynergyDefinition(
            weapon: "overflow",
            powerup: "thor",
            name: "Stack Overflow",
            description: "+5 chain targets, +60% damage"
        ) { player in
            for i in 0..<player.weapons.count {
                let current = player.weapons[i].pierce ?? 3
                player.weapons[i].pierce = current + 5
                player.weapons[i].damage *= 1.6
            }
        },

        // null_pointer + berserker = Fatal Exception
        SynergyDefinition(
            weapon: "null_pointer",
            powerup: "berserker",
            name: "Fatal Exception",
            description: "Execute threshold +20%, +100% damage"
        ) { player in
            for i in 0..<player.weapons.count {
                player.weapons[i].damage *= 2.0
            }
            // Execute threshold is handled separately in combat
        },

        // Any + phoenix = Auto Recovery
        SynergyDefinition(
            weapon: "any",
            powerup: "phoenix",
            name: "Auto Recovery",
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
