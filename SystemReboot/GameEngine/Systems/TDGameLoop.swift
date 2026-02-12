import Foundation
import CoreGraphics

// MARK: - TD Game Loop
// Extracted from TDGameScene.update() (Step 4.5)
// Pure game logic: spawning, movement, targeting, collision, economy.
// Zero SpriteKit dependencies — unit-testable without a scene.

struct TDGameLoop {

    // MARK: - Frame Context (mutable tracking state between frames)

    struct FrameContext {
        var hasStartedFirstWave: Bool = false
        var gameStartDelay: TimeInterval = BalanceConfig.TDRendering.gameStartDelay
        var projectilePrevPositions: [String: CGPoint] = [:]
        var previousEfficiency: CGFloat = 100
    }

    // MARK: - Frame Result (visual events for the scene to render)

    struct FrameResult {
        /// An enemy that appeared on the map and needs visual effects.
        struct SpawnVisual {
            let position: CGPoint
            let isBoss: Bool
            let color: String
            let needsPortal: Bool  // Idle spawns get portal; boss system spawns don't
        }

        var spawnVisuals: [SpawnVisual] = []
        var bossSpawnedType: String?
        var bossReachedCPU: Bool = false
        var collisionVisuals: [TDCollisionSystem.VisualEvent] = []
        var efficiencyDropped: Bool = false
        var systemJustFroze: Bool = false
    }

    // MARK: - Main Update

    /// Run one frame of game logic. Mutates state and context; returns visual events.
    static func update(
        state: inout TDGameState,
        deltaTime: TimeInterval,
        currentTime: TimeInterval,
        context: inout FrameContext,
        unlockedSectorIds: Set<String>
    ) -> FrameResult {
        var result = FrameResult()

        // Update game time
        state.gameTime += deltaTime

        // MARK: Idle TD Continuous Spawning
        if state.idleSpawnEnabled {
            if !context.hasStartedFirstWave {
                context.gameStartDelay -= deltaTime
                if context.gameStartDelay <= 0 {
                    context.hasStartedFirstWave = true
                }
            }

            if context.hasStartedFirstWave {
                if let enemy = IdleSpawnSystem.update(
                    state: &state,
                    deltaTime: deltaTime,
                    currentTime: currentTime,
                    unlockedSectorIds: unlockedSectorIds
                ) {
                    state.enemies.append(enemy)
                    result.spawnVisuals.append(FrameResult.SpawnVisual(
                        position: enemy.position,
                        isBoss: enemy.isBoss,
                        color: enemy.color,
                        needsPortal: true
                    ))
                }
            }
        }

        // MARK: Overclock System
        OverclockSystem.update(state: &state, deltaTime: deltaTime)

        // MARK: Boss System
        let bossResult = TDBossSystem.update(state: &state, deltaTime: deltaTime)
        if bossResult.bossSpawned {
            if let bossId = state.activeBossId,
               let boss = state.enemies.first(where: { $0.id == bossId }) {
                result.spawnVisuals.append(FrameResult.SpawnVisual(
                    position: boss.position,
                    isBoss: true,
                    color: boss.color,
                    needsPortal: false
                ))
            }
            result.bossSpawnedType = bossResult.spawnedBossType ?? "unknown"
        }
        if bossResult.bossReachedCPU {
            result.bossReachedCPU = true
        }

        // MARK: Core Systems
        PathSystem.updateEnemyPositions(state: &state, deltaTime: deltaTime, currentTime: currentTime)

        // Rebuild spatial grid after enemy positions update (O(n) instead of O(n²) for targeting/collisions)
        if state.enemyGrid == nil {
            state.enemyGrid = SpatialGrid<TDEnemy>(cellSize: 100)
        }
        state.enemyGrid?.rebuild(from: state.enemies)

        TowerSystem.updateTargets(state: &state)
        TowerSystem.processTowerAttacks(state: &state, currentTime: currentTime, deltaTime: deltaTime)
        CoreSystem.processCoreAttack(state: &state, currentTime: currentTime)
        updateProjectiles(state: &state, deltaTime: deltaTime, prevPositions: &context.projectilePrevPositions)
        PathSystem.processReachedCore(state: &state)

        // MARK: Collision Detection
        result.collisionVisuals = TDCollisionSystem.processCollisions(
            state: &state,
            prevPositions: context.projectilePrevPositions
        )

        // MARK: Cleanup
        state.enemies.removeAll { $0.isDead || $0.reachedCore }
        let activeProjectileIds = Set(state.projectiles.map { $0.id })
        context.projectilePrevPositions = context.projectilePrevPositions.filter {
            activeProjectileIds.contains($0.key)
        }

        // MARK: Efficiency Tracking
        if state.efficiency < context.previousEfficiency {
            result.efficiencyDropped = true
        }
        context.previousEfficiency = state.efficiency

        // Check for system freeze
        if state.isSystemFrozen {
            result.systemJustFroze = true
            return result
        }

        // MARK: Economy
        PathSystem.updateLeakDecay(state: &state, deltaTime: deltaTime)
        PathSystem.updateHashIncome(state: &state, deltaTime: deltaTime)

        // MARK: Zero-Day Events
        _ = ZeroDaySystem.update(state: &state, deltaTime: deltaTime)

        return result
    }

    // MARK: - Projectile Movement

    /// Move projectiles, apply homing, expire out-of-bounds. Pure math.
    private static func updateProjectiles(
        state: inout TDGameState,
        deltaTime: TimeInterval,
        prevPositions: inout [String: CGPoint]
    ) {
        for i in (0..<state.projectiles.count).reversed() {
            var proj = state.projectiles[i]

            // Store previous position for swept collision detection
            prevPositions[proj.id] = CGPoint(x: proj.x, y: proj.y)

            // Move projectile
            proj.x += proj.velocityX * CGFloat(deltaTime)
            proj.y += proj.velocityY * CGFloat(deltaTime)

            // Homing behavior
            if proj.isHoming, let targetId = proj.targetId,
               let target = state.enemies.first(where: { $0.id == targetId && !$0.isDead }) {
                let dx = target.x - proj.x
                let dy = target.y - proj.y
                let distance = sqrt(dx * dx + dy * dy)
                if distance > 0 {
                    let currentAngle = atan2(proj.velocityY, proj.velocityX)
                    let targetAngle = atan2(dy, dx)
                    var angleDiff = targetAngle - currentAngle
                    while angleDiff > .pi { angleDiff -= 2 * .pi }
                    while angleDiff < -.pi { angleDiff += 2 * .pi }

                    let turnSpeed = proj.homingStrength * CGFloat(deltaTime)
                    let newAngle = currentAngle + max(-turnSpeed, min(turnSpeed, angleDiff))
                    let speed = proj.speed ?? 400
                    proj.velocityX = cos(newAngle) * speed
                    proj.velocityY = sin(newAngle) * speed
                }
            }

            // Update lifetime
            proj.lifetime -= deltaTime

            // Check bounds and lifetime
            if proj.lifetime <= 0 ||
               proj.x < -50 || proj.x > state.map.width + 50 ||
               proj.y < -50 || proj.y > state.map.height + 50 {
                state.projectiles.remove(at: i)
                continue
            }

            state.projectiles[i] = proj
        }
    }
}
