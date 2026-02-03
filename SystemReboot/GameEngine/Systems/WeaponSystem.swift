import Foundation
import CoreGraphics

// MARK: - Weapon System

class WeaponSystem {

    /// Update all weapons - auto-fire at nearest enemy
    static func update(state: inout GameState, context: FrameContext) {
        let player = state.player

        for i in 0..<state.player.weapons.count {
            let weapon = state.player.weapons[i]

            // Check cooldown
            let cooldown = 1.0 / weapon.attackSpeed // seconds between attacks
            if context.timestamp - weapon.lastAttackTime < cooldown {
                continue
            }

            // Find nearest enemy in range (uses spatial grid for O(n) lookup)
            guard let target = findNearestEnemy(
                x: player.x,
                y: player.y,
                enemies: state.enemies,
                range: weapon.range,
                grid: state.enemyGrid
            ) else {
                continue
            }

            // Fire weapon
            fireWeapon(state: &state, weaponIndex: i, target: target, timestamp: context.timestamp)
            state.player.weapons[i].lastAttackTime = context.timestamp
        }
    }

    /// Find nearest enemy within range (uses spatial grid if available)
    private static func findNearestEnemy(
        x: CGFloat,
        y: CGFloat,
        enemies: [Enemy],
        range: CGFloat,
        grid: SpatialGrid<Enemy>? = nil
    ) -> Enemy? {
        // Use spatial grid if available (Phase 3: O(n) instead of O(n×m))
        if let grid = grid {
            return grid.findNearest(x: x, y: y, range: range)
        }

        // Fall back to brute force search
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
    private static func fireWeapon(state: inout GameState, weaponIndex: Int, target: Enemy, timestamp: TimeInterval) {
        let player = state.player
        let weapon = player.weapons[weaponIndex]
        let projectileCount = weapon.projectileCount ?? 1

        for i in 0..<projectileCount {
            // Calculate angle to target
            let dx = target.x - player.x
            let dy = target.y - player.y
            let angle = atan2(dy, dx)

            // Spawn projectile outside player hitbox
            let spawnDistance = player.size + BalanceConfig.ProjectileSystem.spawnOffset
            var startX = player.x + cos(angle) * spawnDistance
            var startY = player.y + sin(angle) * spawnDistance

            // Parallel projectiles for multi-shot
            if projectileCount > 1 {
                let perpendicularAngle = angle + .pi / 2
                let spacing = BalanceConfig.ProjectileSystem.multiShotSpacing
                let offset = (CGFloat(i) - CGFloat(projectileCount - 1) / 2) * spacing
                startX += cos(perpendicularAngle) * offset
                startY += sin(perpendicularAngle) * offset
            }

            let projectileSpeed: CGFloat = BalanceConfig.Player.weaponProjectileSpeed
            let survivalDamageModifier = SurvivalArenaSystem.getDamageModifier(state: state)

            state.projectiles.append(Projectile(
                id: "\(RandomUtils.generateId())-\(i)",
                weaponId: weapon.type,
                x: startX,
                y: startY,
                velocityX: cos(angle) * projectileSpeed,
                velocityY: sin(angle) * projectileSpeed,
                damage: weapon.damage * survivalDamageModifier,
                radius: BalanceConfig.ProjectileSystem.playerProjectileRadius,
                color: weapon.color,
                lifetime: Double(weapon.range / projectileSpeed),
                piercing: weapon.pierce ?? 0,
                hitEnemies: [],
                isHoming: weapon.homing ?? false,
                homingStrength: BalanceConfig.Towers.homingStrength,
                targetId: (weapon.homing ?? false) ? target.id : nil,
                speed: projectileSpeed,
                createdAt: timestamp,
                pierceRemaining: weapon.pierce,
                sourceType: weapon.type,
                splash: weapon.splash,
                slow: nil,
                slowDuration: nil,
                size: BalanceConfig.ProjectileSystem.playerProjectileRadius,
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
