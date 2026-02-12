import Foundation
import CoreGraphics

// MARK: - Tower System
// Handles tower placement, targeting, and firing

class TowerSystem {

    // MARK: - Tower Placement

    /// Attempt to place a tower
    static func placeTower(
        state: inout TDGameState,
        weaponType: String,
        slotId: String,
        playerProfile: PlayerProfile
    ) -> TowerPlacementResult {
        // Find the slot
        guard let slotIndex = state.towerSlots.firstIndex(where: { $0.id == slotId }) else {
            return .invalidSlot
        }

        let slot = state.towerSlots[slotIndex]

        // Check if slot is occupied
        if slot.occupied {
            return .slotOccupied
        }

        // Check if weapon is unlocked
        guard playerProfile.unlocks.weapons.contains(weaponType) else {
            return .weaponLocked
        }

        // Get weapon config and create WeaponTower
        guard let weaponConfig = GameConfigLoader.shared.getWeapon(weaponType) else {
            return .invalidSlot
        }

        let weaponLevel = playerProfile.weaponLevels[weaponType] ?? 1
        let weaponTower = WeaponTower.from(config: weaponConfig, level: weaponLevel)

        // Calculate placement cost
        let placementCost = towerPlacementCost(rarity: weaponTower.rarity)

        // Check gold
        if state.hash < placementCost {
            return .insufficientGold(required: placementCost, available: state.hash)
        }

        // Create and place tower
        let tower = Tower.from(weapon: weaponTower, at: slot)

        // Update state
        state.towers.append(tower)
        state.towerSlots[slotIndex].occupied = true
        state.towerSlots[slotIndex].towerId = tower.id
        state.hash -= placementCost
        state.stats.towersPlaced += 1
        state.stats.hashSpent += placementCost

        return .success(tower: tower)
    }

    /// Calculate tower placement cost based on rarity
    static func towerPlacementCost(rarity: Rarity) -> Int {
        return BalanceConfig.towerCost(rarity: rarity)
    }

    // MARK: - Protocol-Based Tower Placement (System: Reboot)

    /// Place a tower from a Protocol (Firewall mode)
    static func placeTowerFromProtocol(
        state: inout TDGameState,
        protocolId: String,
        slotId: String,
        playerProfile: PlayerProfile
    ) -> TowerPlacementResult {
        // Find the slot
        guard let slotIndex = state.towerSlots.firstIndex(where: { $0.id == slotId }) else {
            return .invalidSlot
        }

        let slot = state.towerSlots[slotIndex]

        // Check if slot is occupied
        if slot.occupied {
            return .slotOccupied
        }

        // Check if protocol is compiled (unlocked)
        guard playerProfile.isProtocolCompiled(protocolId) else {
            return .weaponLocked
        }

        // Get protocol from library
        guard var proto = ProtocolLibrary.get(protocolId) else {
            return .invalidSlot
        }

        // Apply player's protocol level
        proto.level = playerProfile.protocolLevel(protocolId)

        // Calculate placement cost based on rarity
        let placementCost = towerPlacementCost(rarity: proto.rarity)

        // Check gold (Hash)
        if state.hash < placementCost {
            return .insufficientGold(required: placementCost, available: state.hash)
        }

        // Check power capacity (System: Reboot)
        let powerRequired = proto.firewallStats.powerDraw
        if state.powerAvailable < powerRequired {
            return .insufficientPower(required: powerRequired, available: state.powerAvailable)
        }

        // Create and place tower from protocol
        var tower = Tower.from(protocol: proto, at: slot)

        // Apply global upgrade bonuses (Cooling = fire rate)
        let fireRateMultiplier = playerProfile.globalUpgrades.fireRateMultiplier
        tower.attackSpeed *= fireRateMultiplier

        // Update state
        state.towers.append(tower)
        state.towerSlots[slotIndex].occupied = true
        state.towerSlots[slotIndex].towerId = tower.id
        state.hash -= placementCost
        state.stats.towersPlaced += 1
        state.stats.hashSpent += placementCost

        return .success(tower: tower)
    }

    /// Result of a tower upgrade (for blueprint-based system)
    struct TowerUpgradeResult {
        let success: Bool
        let weaponType: String?
        let newLevel: Int?
        let towersUpgraded: Int  // How many towers were upgraded
    }

    /// Upgrade a tower (blueprint-based: upgrades ALL towers of the same type)
    static func upgradeTower(state: inout TDGameState, towerId: String) -> TowerUpgradeResult {
        guard let towerIndex = state.towers.firstIndex(where: { $0.id == towerId }) else {
            return TowerUpgradeResult(success: false, weaponType: nil, newLevel: nil, towersUpgraded: 0)
        }

        let tower = state.towers[towerIndex]
        let weaponType = tower.weaponType

        // Check if can upgrade
        guard tower.canUpgrade else {
            return TowerUpgradeResult(success: false, weaponType: weaponType, newLevel: nil, towersUpgraded: 0)
        }

        // Check hash (cost is based on original tower's level)
        let cost = tower.upgradeCost
        guard state.hash >= cost else {
            return TowerUpgradeResult(success: false, weaponType: weaponType, newLevel: nil, towersUpgraded: 0)
        }

        // Blueprint-based: Upgrade ALL towers of the same type
        var upgradeCount = 0
        var newLevel = tower.level + 1

        for i in 0..<state.towers.count {
            if state.towers[i].weaponType == weaponType && state.towers[i].canUpgrade {
                state.towers[i].upgrade()
                upgradeCount += 1
                newLevel = state.towers[i].level  // All should be same level now
            }
        }

        // Deduct cost (only once, regardless of how many towers)
        state.hash -= cost
        state.stats.towersUpgraded += upgradeCount
        state.stats.hashSpent += cost

        return TowerUpgradeResult(
            success: true,
            weaponType: weaponType,
            newLevel: newLevel,
            towersUpgraded: upgradeCount
        )
    }

    /// Sell a tower
    static func sellTower(state: inout TDGameState, towerId: String) -> Int {
        guard let towerIndex = state.towers.firstIndex(where: { $0.id == towerId }) else {
            return 0
        }

        let tower = state.towers[towerIndex]

        // Calculate refund based on total investment
        let baseCost = towerPlacementCost(rarity: tower.rarity)
        let upgradeInvestment = (tower.level - 1) * BalanceConfig.Towers.upgradeInvestmentPerLevel
        let refund = Int(CGFloat(baseCost + upgradeInvestment) * BalanceConfig.Towers.refundRate)

        // Free up slot
        if let slotIndex = state.towerSlots.firstIndex(where: { $0.id == tower.slotId }) {
            state.towerSlots[slotIndex].occupied = false
            state.towerSlots[slotIndex].towerId = nil
        }

        // Remove tower and refund (subject to Hash storage cap)
        state.towers.remove(at: towerIndex)
        let actualRefund = state.addHash(refund)

        return actualRefund
    }

    // MARK: - Tower Targeting

    /// Update all tower targets
    static func updateTargets(state: inout TDGameState) {
        for i in 0..<state.towers.count {
            updateTowerTarget(state: &state, towerIndex: i)
        }
    }

    /// Find best target for a tower
    private static func updateTowerTarget(state: inout TDGameState, towerIndex: Int) {
        let tower = state.towers[towerIndex]
        let towerPos = tower.position

        // Use spatial grid for range query (O(1) cell lookup vs O(n) brute force)
        let candidates: [TDEnemy]
        if let grid = state.enemyGrid {
            candidates = grid.query(x: towerPos.x, y: towerPos.y, radius: tower.range)
        } else {
            candidates = state.enemies
        }

        // Find enemies in range
        var bestTarget: TDEnemy?
        var bestProgress: CGFloat = -1  // Target enemy furthest along path
        let rangeSq = tower.range * tower.range

        for enemy in candidates {
            if enemy.isDead || enemy.reachedCore { continue }

            // Skip Zero-Day enemies (immune to tower damage)
            if enemy.immuneToTowers || enemy.isZeroDay { continue }

            let dx = enemy.x - towerPos.x
            let dy = enemy.y - towerPos.y
            let distSq = dx*dx + dy*dy

            if distSq <= rangeSq {
                // Prioritize enemies further along path (closer to core)
                if enemy.pathProgress > bestProgress {
                    bestProgress = enemy.pathProgress
                    bestTarget = enemy
                }
            }
        }

        state.towers[towerIndex].targetId = bestTarget?.id

        // Update tower rotation to face target
        if let target = bestTarget {
            let dx = target.x - towerPos.x
            let dy = target.y - towerPos.y
            state.towers[towerIndex].rotation = atan2(dy, dx)
        }
    }

    // MARK: - Tower Firing

    /// Process tower attacks
    static func processTowerAttacks(state: inout TDGameState, currentTime: TimeInterval, deltaTime: TimeInterval) {
        for i in 0..<state.towers.count {
            processTowerAttack(state: &state, towerIndex: i, currentTime: currentTime)
        }
    }

    /// Process single tower attack
    private static func processTowerAttack(state: inout TDGameState, towerIndex: Int, currentTime: TimeInterval) {
        var tower = state.towers[towerIndex]

        // Check if has target
        guard let targetId = tower.targetId,
              let target = state.enemies.first(where: { $0.id == targetId && !$0.isDead }) else {
            return
        }

        // Check attack cooldown
        let attackInterval = 1.0 / tower.attackSpeed
        guard currentTime - tower.lastAttackTime >= attackInterval else { return }

        // Calculate lead targeting (predict where enemy will be)
        let projectileSpeed = BalanceConfig.Towers.projectileSpeed

        // Estimate enemy velocity from path direction
        let path = state.paths.indices.contains(target.pathIndex) ? state.paths[target.pathIndex] : nil
        let targetVelocity = estimateEnemyVelocity(enemy: target, path: path)

        let leadPosition = calculateLeadPosition(
            towerPos: tower.position,
            targetPos: CGPoint(x: target.x, y: target.y),
            targetVelocity: targetVelocity,
            projectileSpeed: projectileSpeed
        )

        // Calculate angle to lead position
        let dx = leadPosition.x - tower.x
        let dy = leadPosition.y - tower.y
        let leadAngle = atan2(dy, dx)

        // Update tower rotation to face lead position
        state.towers[towerIndex].rotation = leadAngle

        // Fire projectile(s)
        let projectileCount = tower.projectileCount
        let spreadAngle: CGFloat = projectileCount > 1 ? BalanceConfig.Towers.multiShotSpreadAngle : 0

        for p in 0..<projectileCount {
            let angleOffset = (CGFloat(p) - CGFloat(projectileCount - 1) / 2) * spreadAngle
            let angle = leadAngle + angleOffset

            let projectile = createTowerProjectile(
                tower: tower,
                angle: angle,
                target: target,
                projectileSpeed: projectileSpeed,
                currentTime: currentTime
            )
            state.projectiles.append(projectile)
        }

        // Update last attack time
        state.towers[towerIndex].lastAttackTime = currentTime
    }

    /// Estimate enemy velocity from their path direction
    private static func estimateEnemyVelocity(enemy: TDEnemy, path: EnemyPath?) -> CGPoint {
        guard let path = path, path.waypoints.count >= 2 else {
            return .zero
        }

        // Get direction from current position toward next waypoint
        let currentProgress = enemy.pathProgress
        let lookAheadProgress = min(1.0, currentProgress + BalanceConfig.Towers.leadTargetingLookAhead)  // Look slightly ahead

        let currentPos = path.positionAt(progress: currentProgress)
        let aheadPos = path.positionAt(progress: lookAheadProgress)

        let dx = aheadPos.x - currentPos.x
        let dy = aheadPos.y - currentPos.y
        let distance = sqrt(dx*dx + dy*dy)

        guard distance > 0 else { return .zero }

        // Normalize direction and multiply by speed
        let speed = enemy.currentSpeed
        return CGPoint(
            x: (dx / distance) * speed,
            y: (dy / distance) * speed
        )
    }

    /// Calculate lead position for predictive targeting
    private static func calculateLeadPosition(
        towerPos: CGPoint,
        targetPos: CGPoint,
        targetVelocity: CGPoint,
        projectileSpeed: CGFloat
    ) -> CGPoint {
        // Distance to current target position
        let dx = targetPos.x - towerPos.x
        let dy = targetPos.y - towerPos.y
        let distance = sqrt(dx*dx + dy*dy)

        // Time for projectile to reach current position
        let timeToTarget = distance / projectileSpeed

        // Predict where enemy will be (with a cap to avoid overshooting)
        let predictionTime = min(timeToTarget, BalanceConfig.Towers.maxPredictionTime)
        let predictedX = targetPos.x + targetVelocity.x * predictionTime
        let predictedY = targetPos.y + targetVelocity.y * predictionTime

        return CGPoint(x: predictedX, y: predictedY)
    }

    /// Create projectile from tower
    private static func createTowerProjectile(
        tower: Tower,
        angle: CGFloat,
        target: TDEnemy,
        projectileSpeed: CGFloat,
        currentTime: TimeInterval
    ) -> Projectile {
        let velocityX = cos(angle) * projectileSpeed
        let velocityY = sin(angle) * projectileSpeed

        return Projectile(
            id: RandomUtils.generateId(),
            weaponId: tower.weaponType,
            x: tower.x,
            y: tower.y,
            velocityX: velocityX,
            velocityY: velocityY,
            damage: tower.damage,
            radius: BalanceConfig.Towers.projectileHitboxRadius,
            color: tower.color,
            lifetime: BalanceConfig.Towers.projectileLifetime,
            piercing: tower.pierce,
            hitEnemies: [],
            isHoming: tower.homing,
            homingStrength: tower.homing ? BalanceConfig.Towers.homingStrength : 0,
            isEnemyProjectile: false,
            targetId: tower.homing ? target.id : nil,
            speed: projectileSpeed,
            createdAt: currentTime,
            pierceRemaining: tower.pierce,
            splash: tower.splash > 0 ? tower.splash : nil,
            slow: tower.slow,
            slowDuration: tower.slowDuration,
            chain: tower.chain
        )
    }

    // MARK: - Tower Info

    /// Get tower stats for UI display
    static func getTowerStats(tower: Tower) -> [String: String] {
        return [
            "name": tower.towerName,
            "level": "\(tower.level)/10",
            "damage": String(format: "%.1f", tower.damage),
            "range": String(format: "%.0f", tower.range),
            "speed": String(format: "%.2f/s", tower.attackSpeed),
            "dps": String(format: "%.1f", tower.damage * tower.attackSpeed * CGFloat(tower.projectileCount))
        ]
    }
}
