import Foundation
import CoreGraphics

// MARK: - Weapon System

class WeaponSystem {

    /// Update all weapons - auto-fire at nearest enemy
    static func update(state: inout GameState) {
        let player = state.player
        let now = Date().timeIntervalSince1970

        for i in 0..<state.player.weapons.count {
            let weapon = state.player.weapons[i]

            // Check cooldown
            let cooldown = 1.0 / weapon.attackSpeed // seconds between attacks
            if now - weapon.lastAttackTime < cooldown {
                continue
            }

            // Find nearest enemy in range
            guard let target = findNearestEnemy(
                x: player.x,
                y: player.y,
                enemies: state.enemies,
                range: weapon.range
            ) else {
                continue
            }

            // Fire weapon
            fireWeapon(state: &state, weaponIndex: i, target: target)
            state.player.weapons[i].lastAttackTime = now
        }
    }

    /// Find nearest enemy within range
    private static func findNearestEnemy(
        x: CGFloat,
        y: CGFloat,
        enemies: [Enemy],
        range: CGFloat
    ) -> Enemy? {
        var nearest: Enemy?
        var nearestDist: CGFloat = .infinity

        for enemy in enemies {
            if enemy.isDead { continue }

            let dx = enemy.x - x
            let dy = enemy.y - y
            let dist = sqrt(dx * dx + dy * dy)

            if dist <= range && dist < nearestDist {
                nearest = enemy
                nearestDist = dist
            }
        }

        return nearest
    }

    /// Fire weapon and create projectiles
    private static func fireWeapon(state: inout GameState, weaponIndex: Int, target: Enemy) {
        let player = state.player
        let weapon = player.weapons[weaponIndex]
        let projectileCount = weapon.projectileCount ?? 1

        for i in 0..<projectileCount {
            // Calculate angle to target
            let dx = target.x - player.x
            let dy = target.y - player.y
            let angle = atan2(dy, dx)

            // Spawn projectile outside player hitbox
            let spawnDistance = player.size + 10
            var startX = player.x + cos(angle) * spawnDistance
            var startY = player.y + sin(angle) * spawnDistance

            // Parallel projectiles for multi-shot
            if projectileCount > 1 {
                let perpendicularAngle = angle + .pi / 2
                let spacing: CGFloat = 10
                let offset = (CGFloat(i) - CGFloat(projectileCount - 1) / 2) * spacing
                startX += cos(perpendicularAngle) * offset
                startY += sin(perpendicularAngle) * offset
            }

            let projectileSpeed: CGFloat = 500

            state.projectiles.append(Projectile(
                id: "\(RandomUtils.generateId())-\(i)",
                weaponId: weapon.type,
                x: startX,
                y: startY,
                velocityX: cos(angle) * projectileSpeed,
                velocityY: sin(angle) * projectileSpeed,
                damage: weapon.damage,
                radius: 5,
                color: weapon.color,
                lifetime: Double(weapon.range / projectileSpeed),
                piercing: weapon.pierce ?? 0,
                hitEnemies: [],
                isHoming: weapon.homing ?? false,
                homingStrength: 5.0,
                targetId: (weapon.homing ?? false) ? target.id : nil,
                speed: projectileSpeed,
                createdAt: Date().timeIntervalSince1970,
                pierceRemaining: weapon.pierce,
                sourceType: weapon.type,
                splash: weapon.splash,
                slow: nil,
                slowDuration: nil,
                size: 5,
                trail: true
            ))
        }

        // Muzzle flash particles
        ParticleFactory.createMuzzleFlash(
            state: &state,
            x: player.x,
            y: player.y,
            angle: atan2(target.y - player.y, target.x - player.x),
            weaponType: weapon.type
        )
    }
}
