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
        if state.gold < placementCost {
            return .insufficientGold(required: placementCost, available: state.gold)
        }

        // Create and place tower
        let tower = Tower.from(weapon: weaponTower, at: slot)

        // Update state
        state.towers.append(tower)
        state.towerSlots[slotIndex].occupied = true
        state.towerSlots[slotIndex].towerId = tower.id
        state.gold -= placementCost
        state.stats.towersPlaced += 1
        state.stats.goldSpent += placementCost

        return .success(tower: tower)
    }

    /// Calculate tower placement cost based on rarity
    static func towerPlacementCost(rarity: Rarity) -> Int {
        switch rarity {
        case .common: return 50
        case .rare: return 100
        case .epic: return 200
        case .legendary: return 400
        }
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

        // Check gold (Watts)
        if state.gold < placementCost {
            return .insufficientGold(required: placementCost, available: state.gold)
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
        state.gold -= placementCost
        state.stats.towersPlaced += 1
        state.stats.goldSpent += placementCost

        return .success(tower: tower)
    }

    /// Upgrade a tower
    static func upgradeTower(state: inout TDGameState, towerId: String) -> Bool {
        guard let towerIndex = state.towers.firstIndex(where: { $0.id == towerId }) else {
            return false
        }

        let tower = state.towers[towerIndex]

        // Check if can upgrade
        guard tower.canUpgrade else { return false }

        // Check gold
        let cost = tower.upgradeCost
        guard state.gold >= cost else { return false }

        // Apply upgrade
        state.towers[towerIndex].upgrade()
        state.gold -= cost
        state.stats.towersUpgraded += 1
        state.stats.goldSpent += cost

        return true
    }

    /// Sell a tower
    static func sellTower(state: inout TDGameState, towerId: String) -> Int {
        guard let towerIndex = state.towers.firstIndex(where: { $0.id == towerId }) else {
            return 0
        }

        let tower = state.towers[towerIndex]

        // Calculate refund (50% of total investment)
        let baseCost = towerPlacementCost(rarity: tower.rarity)
        let upgradeInvestment = (tower.level - 1) * 75  // Approximate upgrade costs
        let refund = (baseCost + upgradeInvestment) / 2

        // Free up slot
        if let slotIndex = state.towerSlots.firstIndex(where: { $0.id == tower.slotId }) {
            state.towerSlots[slotIndex].occupied = false
            state.towerSlots[slotIndex].towerId = nil
        }

        // Remove tower and refund
        state.towers.remove(at: towerIndex)
        state.gold += refund

        return refund
    }

    // MARK: - Tower Merging

    /// Attempt to merge two towers (source merges INTO target)
    static func mergeTowers(
        state: inout TDGameState,
        sourceTowerId: String,
        targetTowerId: String
    ) -> TowerMergeResult {
        // Find both towers
        guard let sourceIndex = state.towers.firstIndex(where: { $0.id == sourceTowerId }),
              let targetIndex = state.towers.firstIndex(where: { $0.id == targetTowerId }) else {
            return .cannotMerge
        }

        let sourceTower = state.towers[sourceIndex]
        let targetTower = state.towers[targetIndex]

        // Validate merge
        if sourceTower.id == targetTower.id {
            return .sameTower
        }

        if sourceTower.weaponType != targetTower.weaponType {
            return .differentTypes
        }

        if sourceTower.mergeLevel != targetTower.mergeLevel {
            return .differentMergeLevels
        }

        if !targetTower.canMerge {
            return .maxMergeLevel
        }

        // Perform merge: upgrade target, remove source
        let sourceSlotId = sourceTower.slotId

        // Apply merge bonus to target tower
        state.towers[targetIndex].applyMerge()

        // Free up source slot
        if let slotIndex = state.towerSlots.firstIndex(where: { $0.id == sourceSlotId }) {
            state.towerSlots[slotIndex].occupied = false
            state.towerSlots[slotIndex].towerId = nil
        }

        // Remove source tower (get updated index since array may have shifted)
        if let newSourceIndex = state.towers.firstIndex(where: { $0.id == sourceTowerId }) {
            state.towers.remove(at: newSourceIndex)
        }

        // Update stats
        state.stats.towersUpgraded += 1

        // Return success with the merged tower
        let mergedTower = state.towers.first(where: { $0.id == targetTowerId })!
        return .success(mergedTower: mergedTower, freedSlotId: sourceSlotId)
    }

    /// Find valid merge targets for a tower
    static func findMergeTargets(state: TDGameState, towerId: String) -> [Tower] {
        guard let tower = state.towers.first(where: { $0.id == towerId }) else {
            return []
        }

        return state.towers.filter { tower.canMergeWith($0) }
    }

    /// Check if a tower can merge with any other tower
    static func canMergeWithAny(state: TDGameState, towerId: String) -> Bool {
        return !findMergeTargets(state: state, towerId: towerId).isEmpty
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

        // Find enemies in range
        var bestTarget: TDEnemy?
        var bestProgress: CGFloat = -1  // Target enemy furthest along path

        for enemy in state.enemies {
            if enemy.isDead || enemy.reachedCore { continue }

            // Skip Zero-Day enemies (immune to tower damage)
            if enemy.immuneToTowers || enemy.isZeroDay { continue }

            let dx = enemy.x - towerPos.x
            let dy = enemy.y - towerPos.y
            let distance = sqrt(dx*dx + dy*dy)

            if distance <= tower.range {
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

        // Fire projectile(s)
        let projectileCount = tower.projectileCount
        let spreadAngle: CGFloat = projectileCount > 1 ? 0.2 : 0  // Spread for multi-shot

        for p in 0..<projectileCount {
            let angleOffset = (CGFloat(p) - CGFloat(projectileCount - 1) / 2) * spreadAngle
            let angle = tower.rotation + angleOffset

            let projectile = createTowerProjectile(
                tower: tower,
                angle: angle,
                target: target,
                currentTime: currentTime
            )
            state.projectiles.append(projectile)
        }

        // Update last attack time
        state.towers[towerIndex].lastAttackTime = currentTime
    }

    /// Create projectile from tower
    private static func createTowerProjectile(
        tower: Tower,
        angle: CGFloat,
        target: TDEnemy,
        currentTime: TimeInterval
    ) -> Projectile {
        let speed: CGFloat = 400
        let velocityX = cos(angle) * speed
        let velocityY = sin(angle) * speed

        return Projectile(
            id: RandomUtils.generateId(),
            weaponId: tower.weaponType,
            x: tower.x,
            y: tower.y,
            velocityX: velocityX,
            velocityY: velocityY,
            damage: tower.damage,
            radius: 5,
            color: tower.color,
            lifetime: 3.0,
            piercing: tower.pierce,
            hitEnemies: [],
            isHoming: tower.homing,
            homingStrength: tower.homing ? 5.0 : 0,
            isEnemyProjectile: false,
            targetId: tower.homing ? target.id : nil,
            speed: speed,
            createdAt: currentTime,
            pierceRemaining: tower.pierce,
            splash: tower.splash > 0 ? tower.splash : nil,
            slow: tower.slow,
            slowDuration: tower.slowDuration
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
