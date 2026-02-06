import Foundation
import CoreGraphics
import GameplayKit

// MARK: - Seeded RNG

/// Deterministic random number generator for reproducible simulations
class SeededRNG {
    private let source: GKMersenneTwisterRandomSource

    init(seed: UInt64) {
        source = GKMersenneTwisterRandomSource(seed: seed)
    }

    func nextInt(in range: Range<Int>) -> Int {
        let count = range.upperBound - range.lowerBound
        guard count > 0 else { return range.lowerBound }
        return range.lowerBound + abs(source.nextInt()) % count
    }

    func nextInt(in range: ClosedRange<Int>) -> Int {
        return nextInt(in: range.lowerBound..<(range.upperBound + 1))
    }

    func nextDouble() -> Double {
        return Double(source.nextUniform())
    }

    func nextCGFloat() -> CGFloat {
        return CGFloat(source.nextUniform())
    }

    func nextBool(probability: Double = 0.5) -> Bool {
        return nextDouble() < probability
    }

    func randomElement<T>(from array: [T]) -> T? {
        guard !array.isEmpty else { return nil }
        let index = nextInt(in: 0..<array.count)
        return array[index]
    }
}

// MARK: - Extended Enemy Status Effects
// TDEnemy only has slow effects built-in. We track additional effects here.

struct EnemyStatusEffects {
    var isTagged: Bool = false
    var tagEndTime: TimeInterval = 0

    var isMarkedForDeletion: Bool = false
    var markEndTime: TimeInterval = 0

    var isStunned: Bool = false
    var stunEndTime: TimeInterval = 0
    var stunImmunityEndTime: TimeInterval = 0

    var burnDamage: CGFloat = 0
    var burnEndTime: TimeInterval = 0
    var burnTickAccumulator: TimeInterval = 0
}

// MARK: - TD Simulator

/// Headless game loop for automated balance testing
/// Runs the TD game without SpriteKit rendering, driven by AI bots
class TDSimulator {
    var state: TDGameState
    var profile: PlayerProfile
    var rng: SeededRNG
    var unlockedSectorIds: Set<String>

    // Tracking
    var elapsedTime: TimeInterval = 0
    var projectilePrevPositions: [String: CGPoint] = [:]

    // Extended status effects (not on TDEnemy struct)
    var enemyStatusEffects: [String: EnemyStatusEffects] = [:]

    // Stats
    var totalKills: Int = 0
    var totalHashEarned: Int = 0
    var freezeCount: Int = 0
    var timeToFirstFreeze: TimeInterval?
    var overclockCount: Int = 0
    var hasFrozen: Bool = false

    init(
        state: TDGameState,
        profile: PlayerProfile,
        unlockedSectorIds: Set<String>,
        seed: UInt64
    ) {
        self.state = state
        self.profile = profile
        self.unlockedSectorIds = unlockedSectorIds
        self.rng = SeededRNG(seed: seed)
    }

    /// Convenience initializer with SimulationConfig
    convenience init(config: SimulationConfig) {
        // Create player profile
        var simProfile = PlayerProfile.defaultProfile
        simProfile.compiledProtocols = config.compiledProtocols
        simProfile.globalUpgrades = config.componentLevels

        // Create initial game state
        guard var gameState = TDGameStateFactory.createMotherboardGameState(playerProfile: simProfile) else {
            fatalError("Failed to create game state")
        }

        gameState.hash = config.startingHash

        // Apply component levels to state
        let components = config.componentLevels
        gameState.powerCapacity = components.powerCapacity
        gameState.hashStorageCapacity = components.hashStorageCapacity
        gameState.baseHashPerSecond = CGFloat(components.hashPerSecond)

        // Set starting efficiency via leakCounter
        // efficiency = 100 - leakCounter * 5, so leakCounter = (100 - efficiency) / 5
        let targetEfficiency = config.startingEfficiency
        gameState.leakCounter = Int((100 - targetEfficiency) / 5)

        self.init(
            state: gameState,
            profile: simProfile,
            unlockedSectorIds: config.unlockedSectors,
            seed: config.seed
        )
    }

    // MARK: - Main Tick

    /// Run one simulation tick
    func tick(deltaTime: TimeInterval) {
        elapsedTime += deltaTime
        let currentTime = elapsedTime

        // Check for freeze (efficiency hits 0)
        if state.efficiency <= 0 && !hasFrozen {
            hasFrozen = true
            freezeCount += 1
            if timeToFirstFreeze == nil {
                timeToFirstFreeze = elapsedTime
            }
            // Reset for recovery (reduce leak counter)
            state.leakCounter = 10  // 50% efficiency after freeze
            hasFrozen = false
        }

        // 1. Idle spawn system - add spawned enemies to state
        if let enemy = IdleSpawnSystem.update(
            state: &state,
            deltaTime: deltaTime,
            currentTime: currentTime,
            unlockedSectorIds: unlockedSectorIds
        ) {
            state.enemies.append(enemy)
        }

        // 2. Overclock system
        let _ = OverclockSystem.update(state: &state, deltaTime: deltaTime)

        // 3. Skip boss system in headless sim (handled probabilistically by bot)

        // 4. Path system - move enemies
        PathSystem.updateEnemyPositions(state: &state, deltaTime: deltaTime, currentTime: currentTime)

        // 5. Tower targeting
        TowerSystem.updateTargets(state: &state)

        // 6. Tower attacks
        TowerSystem.processTowerAttacks(state: &state, currentTime: currentTime, deltaTime: deltaTime)

        // 7. Core attack
        CoreSystem.processCoreAttack(state: &state, currentTime: currentTime)

        // 8. Update projectiles (inline)
        updateProjectiles(deltaTime: deltaTime)

        // 9. Process enemies that reached core
        PathSystem.processReachedCore(state: &state)

        // 10. Process collisions (inline)
        processCollisions(currentTime: currentTime, deltaTime: deltaTime)

        // 11. Update status effects
        updateStatusEffects(currentTime: currentTime, deltaTime: deltaTime)

        // 12. Cleanup dead entities
        cleanupDeadEntities()

        // 13. Leak decay
        PathSystem.updateLeakDecay(state: &state, deltaTime: deltaTime)

        // 14. Hash income
        let hashBefore = state.hash
        PathSystem.updateHashIncome(state: &state, deltaTime: deltaTime)
        totalHashEarned += state.hash - hashBefore
    }

    // MARK: - Projectile Update (Inline)

    private func updateProjectiles(deltaTime: TimeInterval) {
        let boundaryMargin: CGFloat = 50

        for i in (0..<state.projectiles.count).reversed() {
            var proj = state.projectiles[i]

            // Store previous position for swept collision
            projectilePrevPositions[proj.id] = CGPoint(x: proj.x, y: proj.y)

            // Update lifetime
            proj.lifetime -= deltaTime
            if proj.lifetime <= 0 {
                state.projectiles.remove(at: i)
                continue
            }

            // Move projectile
            proj.x += proj.velocityX * CGFloat(deltaTime)
            proj.y += proj.velocityY * CGFloat(deltaTime)

            // Homing behavior
            if proj.isHoming, let targetId = proj.targetId {
                if let target = state.enemies.first(where: { $0.id == targetId && !$0.isDead }) {
                    let dx = target.position.x - proj.x
                    let dy = target.position.y - proj.y
                    let targetAngle = atan2(dy, dx)

                    let currentAngle = atan2(proj.velocityY, proj.velocityX)
                    var angleDiff = targetAngle - currentAngle
                    while angleDiff > .pi { angleDiff -= 2 * .pi }
                    while angleDiff < -.pi { angleDiff += 2 * .pi }

                    let speed = sqrt(proj.velocityX * proj.velocityX + proj.velocityY * proj.velocityY)
                    let turnSpeed = proj.homingStrength * CGFloat(deltaTime)

                    var newAngle = currentAngle
                    if abs(angleDiff) < turnSpeed {
                        newAngle = targetAngle
                    } else {
                        newAngle += angleDiff > 0 ? turnSpeed : -turnSpeed
                    }

                    proj.velocityX = cos(newAngle) * speed
                    proj.velocityY = sin(newAngle) * speed
                }
            }

            // Bounds check (use motherboard canvas size)
            let arenaSize: CGFloat = MotherboardLaneConfig.canvasSize
            if proj.x < -boundaryMargin || proj.x > arenaSize + boundaryMargin ||
               proj.y < -boundaryMargin || proj.y > arenaSize + boundaryMargin {
                state.projectiles.remove(at: i)
                continue
            }

            state.projectiles[i] = proj
        }
    }

    // MARK: - Collision Processing (Inline)

    private func processCollisions(currentTime: TimeInterval, deltaTime: TimeInterval) {
        var projectilesToRemove: Set<Int> = []

        for projIndex in 0..<state.projectiles.count {
            if projectilesToRemove.contains(projIndex) { continue }

            let proj = state.projectiles[projIndex]
            let prevPos = projectilePrevPositions[proj.id] ?? CGPoint(x: proj.x, y: proj.y)
            let currentPos = CGPoint(x: proj.x, y: proj.y)
            let hitRadius = BalanceConfig.Towers.projectileHitboxRadius

            for enemyIndex in 0..<state.enemies.count {
                var enemy = state.enemies[enemyIndex]
                if enemy.isDead || enemy.reachedCore { continue }

                // Line-circle intersection for swept collision
                let enemyRadius: CGFloat = 15
                if lineIntersectsCircle(
                    lineStart: prevPos,
                    lineEnd: currentPos,
                    circleCenter: enemy.position,
                    circleRadius: enemyRadius + hitRadius
                ) {
                    // Hit! Apply damage
                    var damage = proj.damage

                    // Apply Pinger tag bonus
                    if let effects = enemyStatusEffects[enemy.id], effects.isTagged {
                        damage *= (1 + BalanceConfig.Pinger.tagDamageBonus)
                    }

                    enemy.health -= damage

                    // Apply status effects based on weapon type
                    applyStatusEffects(to: enemy.id, from: proj, currentTime: currentTime)

                    // Check for death
                    if enemy.health <= 0 {
                        enemy.isDead = true
                        totalKills += 1

                        // Hash reward (use goldValue as hash reward)
                        var hashReward = enemy.goldValue
                        if let effects = enemyStatusEffects[enemy.id], effects.isMarkedForDeletion {
                            hashReward += BalanceConfig.GarbageCollector.hashBonus
                        }
                        state.addHash(hashReward)

                        // Cleanup status effects for dead enemy
                        enemyStatusEffects.removeValue(forKey: enemy.id)
                    }

                    state.enemies[enemyIndex] = enemy

                    // Handle pierce
                    var updatedProj = state.projectiles[projIndex]
                    if updatedProj.piercing > 0 {
                        updatedProj.piercing -= 1
                        state.projectiles[projIndex] = updatedProj
                    } else {
                        projectilesToRemove.insert(projIndex)
                    }

                    // Handle splash damage
                    if let splashRadius = proj.splash, splashRadius > 0 {
                        applySplashDamage(
                            center: enemy.position,
                            radius: splashRadius,
                            damage: proj.damage * 0.5,
                            excludeIndex: enemyIndex
                        )
                    }

                    // Handle fork_bomb children
                    if proj.weaponId == "fork_bomb" && proj.sourceType != "recursion_child" {
                        spawnForkBombChildren(from: proj, at: enemy.position)
                    }

                    break // Move to next projectile
                }
            }
        }

        // Remove hit projectiles (reverse order to preserve indices)
        for index in projectilesToRemove.sorted().reversed() {
            if index < state.projectiles.count {
                let proj = state.projectiles[index]
                projectilePrevPositions.removeValue(forKey: proj.id)
                state.projectiles.remove(at: index)
            }
        }
    }

    private func applyStatusEffects(to enemyId: String, from proj: Projectile, currentTime: TimeInterval) {
        // Initialize effects if needed
        if enemyStatusEffects[enemyId] == nil {
            enemyStatusEffects[enemyId] = EnemyStatusEffects()
        }

        switch proj.weaponId {
        case "ice_shard":
            // Throttler: slow + stun chance
            // Apply slow via TDEnemy's built-in slow system
            if let idx = state.enemies.firstIndex(where: { $0.id == enemyId }) {
                state.enemies[idx].applySlow(
                    amount: BalanceConfig.Throttler.slowAmount,
                    duration: BalanceConfig.Throttler.slowDuration,
                    currentTime: currentTime
                )

                // Stun chance (only if not immune)
                if var effects = enemyStatusEffects[enemyId] {
                    let isImmune = currentTime < effects.stunImmunityEndTime
                    if !isImmune && rng.nextBool(probability: BalanceConfig.Throttler.stunChance) {
                        effects.isStunned = true
                        effects.stunEndTime = currentTime + BalanceConfig.Throttler.stunDuration
                        effects.stunImmunityEndTime = effects.stunEndTime + BalanceConfig.Throttler.stunImmunityDuration
                        enemyStatusEffects[enemyId] = effects
                    }
                }
            }

        case "trace_route":
            // Pinger: tag for bonus damage
            if var effects = enemyStatusEffects[enemyId] {
                effects.isTagged = true
                effects.tagEndTime = currentTime + BalanceConfig.Pinger.tagDuration
                enemyStatusEffects[enemyId] = effects
            }

        case "null_pointer":
            // Garbage Collector: mark for hash bonus on death
            if var effects = enemyStatusEffects[enemyId] {
                effects.isMarkedForDeletion = true
                effects.markEndTime = currentTime + BalanceConfig.GarbageCollector.markDuration
                enemyStatusEffects[enemyId] = effects
            }

        case "burst_protocol":
            // Fragmenter: DoT burn
            if var effects = enemyStatusEffects[enemyId] {
                effects.burnDamage = proj.damage * BalanceConfig.Fragmenter.burnDamagePercent
                effects.burnEndTime = currentTime + BalanceConfig.Fragmenter.burnDuration
                effects.burnTickAccumulator = 0
                enemyStatusEffects[enemyId] = effects
            }

        default:
            break
        }
    }

    private func updateStatusEffects(currentTime: TimeInterval, deltaTime: TimeInterval) {
        for enemyIndex in 0..<state.enemies.count {
            let enemy = state.enemies[enemyIndex]
            if enemy.isDead || enemy.reachedCore { continue }

            guard var effects = enemyStatusEffects[enemy.id] else { continue }
            var modified = false

            // Update tag
            if effects.isTagged && currentTime >= effects.tagEndTime {
                effects.isTagged = false
                modified = true
            }

            // Update mark
            if effects.isMarkedForDeletion && currentTime >= effects.markEndTime {
                effects.isMarkedForDeletion = false
                modified = true
            }

            // Update stun
            if effects.isStunned && currentTime >= effects.stunEndTime {
                effects.isStunned = false
                modified = true
            }

            // Update burn (tick-based damage)
            if effects.burnDamage > 0 && currentTime < effects.burnEndTime {
                effects.burnTickAccumulator += deltaTime
                if effects.burnTickAccumulator >= BalanceConfig.Fragmenter.burnTickInterval {
                    effects.burnTickAccumulator -= BalanceConfig.Fragmenter.burnTickInterval

                    // Apply burn tick damage
                    var updatedEnemy = state.enemies[enemyIndex]
                    let tickDamage = effects.burnDamage / CGFloat(BalanceConfig.Fragmenter.burnDuration / BalanceConfig.Fragmenter.burnTickInterval)
                    updatedEnemy.health -= tickDamage

                    if updatedEnemy.health <= 0 {
                        updatedEnemy.isDead = true
                        totalKills += 1
                        state.addHash(updatedEnemy.goldValue)
                        enemyStatusEffects.removeValue(forKey: enemy.id)
                    }
                    state.enemies[enemyIndex] = updatedEnemy
                }
                modified = true
            } else if effects.burnDamage > 0 && currentTime >= effects.burnEndTime {
                effects.burnDamage = 0
                modified = true
            }

            if modified {
                enemyStatusEffects[enemy.id] = effects
            }
        }
    }

    private func applySplashDamage(center: CGPoint, radius: CGFloat, damage: CGFloat, excludeIndex: Int) {
        for i in 0..<state.enemies.count {
            if i == excludeIndex { continue }
            var enemy = state.enemies[i]
            if enemy.isDead || enemy.reachedCore { continue }

            let dx = enemy.position.x - center.x
            let dy = enemy.position.y - center.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance <= radius {
                let falloff = 1 - (distance / radius)
                let splashDamage = damage * falloff
                enemy.health -= splashDamage

                if enemy.health <= 0 {
                    enemy.isDead = true
                    totalKills += 1
                    state.addHash(enemy.goldValue)
                    enemyStatusEffects.removeValue(forKey: enemy.id)
                }

                state.enemies[i] = enemy
            }
        }
    }

    private func spawnForkBombChildren(from parent: Projectile, at position: CGPoint) {
        let childCount = BalanceConfig.Recursion.childCount
        let childDamage = parent.damage * BalanceConfig.Recursion.childDamagePercent
        let parentSpeed = sqrt(parent.velocityX * parent.velocityX + parent.velocityY * parent.velocityY)
        let parentAngle = atan2(parent.velocityY, parent.velocityX)
        let spreadAngle = CGFloat.pi * 2 / CGFloat(childCount)

        for i in 0..<childCount {
            let angle = parentAngle + spreadAngle * CGFloat(i) - CGFloat.pi
            var child = Projectile(
                id: UUID().uuidString,
                weaponId: "fork_bomb",
                x: position.x,
                y: position.y,
                velocityX: cos(angle) * parentSpeed,
                velocityY: sin(angle) * parentSpeed,
                damage: childDamage,
                radius: parent.radius,
                color: parent.color,
                lifetime: 1.0,
                piercing: 0,
                hitEnemies: [],
                isHoming: false,
                homingStrength: 0
            )
            child.sourceType = "recursion_child"
            state.projectiles.append(child)
        }
    }

    private func lineIntersectsCircle(lineStart: CGPoint, lineEnd: CGPoint, circleCenter: CGPoint, circleRadius: CGFloat) -> Bool {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let fx = lineStart.x - circleCenter.x
        let fy = lineStart.y - circleCenter.y

        let a = dx * dx + dy * dy
        let b = 2 * (fx * dx + fy * dy)
        let c = fx * fx + fy * fy - circleRadius * circleRadius

        var discriminant = b * b - 4 * a * c

        if discriminant < 0 {
            return false
        }

        discriminant = sqrt(discriminant)
        let t1 = (-b - discriminant) / (2 * a)
        let t2 = (-b + discriminant) / (2 * a)

        return (t1 >= 0 && t1 <= 1) || (t2 >= 0 && t2 <= 1)
    }

    // MARK: - Cleanup

    private func cleanupDeadEntities() {
        // Remove status effects for dead/reached enemies
        for enemy in state.enemies where enemy.isDead || enemy.reachedCore {
            enemyStatusEffects.removeValue(forKey: enemy.id)
        }
        state.enemies.removeAll { $0.isDead || $0.reachedCore }
    }

    // MARK: - Bot Actions

    func placeTower(protocolId: String, slotId: String) -> Bool {
        guard let proto = ProtocolLibrary.get(protocolId) else { return false }
        guard let slotIndex = state.towerSlots.firstIndex(where: { $0.id == slotId && !$0.occupied }) else { return false }

        let cost = BalanceConfig.Towers.placementCosts[proto.rarity] ?? 50
        let powerDraw = proto.firewallStats.powerDraw

        guard state.hash >= cost else { return false }
        guard state.powerAvailable >= powerDraw else { return false }

        // Create tower using the existing Tower.from(protocol:at:) factory
        let slot = state.towerSlots[slotIndex]
        let tower = Tower.from(protocol: proto, at: slot)

        state.towers.append(tower)
        state.towerSlots[slotIndex].occupied = true
        state.towerSlots[slotIndex].towerId = tower.id
        state.hash -= cost

        return true
    }

    func upgradeTower(towerId: String) -> Bool {
        guard let towerIndex = state.towers.firstIndex(where: { $0.id == towerId }) else { return false }
        var tower = state.towers[towerIndex]

        guard tower.canUpgrade else { return false }

        let cost = tower.upgradeCost
        guard state.hash >= cost else { return false }

        tower.upgrade()
        state.towers[towerIndex] = tower
        state.hash -= cost

        return true
    }

    func sellTower(towerId: String) -> Bool {
        guard let towerIndex = state.towers.firstIndex(where: { $0.id == towerId }) else { return false }
        let tower = state.towers[towerIndex]

        // Find and free the slot
        if let slotIndex = state.towerSlots.firstIndex(where: { $0.towerId == towerId }) {
            state.towerSlots[slotIndex].occupied = false
            state.towerSlots[slotIndex].towerId = nil
        }

        // Refund hash (use placement cost as base investment)
        let baseCost = BalanceConfig.Towers.placementCosts[tower.rarity] ?? 50
        let refund = Int(CGFloat(baseCost) * BalanceConfig.Towers.refundRate)
        state.addHash(refund)

        state.towers.remove(at: towerIndex)
        return true
    }

    func activateOverclock() -> Bool {
        guard state.canOverclock else { return false }
        state.overclockActive = true
        state.overclockTimeRemaining = BalanceConfig.Overclock.duration
        overclockCount += 1
        return true
    }
}
