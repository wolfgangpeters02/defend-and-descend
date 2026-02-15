import Foundation
import CoreGraphics

// MARK: - Overclocker AI

/// PSU/Cooling-themed Boss with 4 phases: Wind + Blades, Lava Grid, Steam Trail, Vacuum Suction
class OverclockerAI {

    // State types defined in BossStates.swift

    // MARK: - Initialization

    static func createInitialState(arenaCenter: CGPoint, arenaRect: CGRect) -> OverclockerState {
        var state = OverclockerState()
        state.arenaCenter = arenaCenter
        state.arenaRect = arenaRect
        state.phase = 1
        state.bladeAngle = 0
        state.tileStates = Array(repeating: .normal, count: 16)
        return state
    }

    // MARK: - Main Update

    static func update(
        boss: inout Enemy,
        bossState: inout OverclockerState,
        gameState: inout GameState,
        deltaTime: TimeInterval
    ) {
        let healthPercent = boss.health / boss.maxHealth
        let playerPos = CGPoint(x: gameState.player.x, y: gameState.player.y)
        let currentTime = gameState.gameTime
        let arenaRect = bossState.arenaRect

        // Determine phase based on health
        let oldPhase = bossState.phase
        if healthPercent <= BalanceConfig.Overclocker.phase4Threshold {
            bossState.phase = 4
        } else if healthPercent <= BalanceConfig.Overclocker.phase3Threshold {
            bossState.phase = 3
        } else if healthPercent <= BalanceConfig.Overclocker.phase2Threshold {
            bossState.phase = 2
        } else {
            bossState.phase = 1
        }

        // Handle phase transitions
        if bossState.phase != oldPhase {
            enterPhase(bossState.phase, bossState: &bossState, boss: boss)
        }

        // Execute phase behavior
        switch bossState.phase {
        case 1:
            updatePhase1(boss: &boss, bossState: &bossState, gameState: &gameState, deltaTime: deltaTime, currentTime: currentTime, arenaRect: arenaRect)
        case 2:
            updatePhase2(boss: &boss, bossState: &bossState, gameState: &gameState, deltaTime: deltaTime, currentTime: currentTime, arenaRect: arenaRect)
        case 3:
            updatePhase3(boss: &boss, bossState: &bossState, gameState: &gameState, playerPos: playerPos, deltaTime: deltaTime, currentTime: currentTime)
        case 4:
            updatePhase4(boss: &boss, bossState: &bossState, gameState: &gameState, deltaTime: deltaTime, currentTime: currentTime, arenaRect: arenaRect)
        default:
            break
        }

        // Check player contact damage from boss body
        checkContactDamage(bossState: &bossState, gameState: &gameState, bossPos: CGPoint(x: boss.x, y: boss.y), currentTime: currentTime, deltaTime: deltaTime)
    }

    // MARK: - Phase Transitions

    private static func enterPhase(_ phase: Int, bossState: inout OverclockerState, boss: Enemy) {
        switch phase {
        case 2:
            // Initialize tile grid
            bossState.tileStates = Array(repeating: .normal, count: 16)
            bossState.lastTileChangeTime = 0
            bossState.bossTargetTileIndex = nil

        case 3:
            // Clear tile states
            bossState.tileStates = Array(repeating: .normal, count: 16)
            // Start steam trail
            bossState.steamTrail = []
            bossState.lastSteamDropTime = 0

        case 4:
            // Keep steam trail active
            bossState.isSuctionActive = false
            bossState.suctionTimer = 0

        default:
            break
        }
    }

    // MARK: - Phase 1: Turbine (Stationary + Wind + Rotating Blades)

    private static func updatePhase1(
        boss: inout Enemy,
        bossState: inout OverclockerState,
        gameState: inout GameState,
        deltaTime: TimeInterval,
        currentTime: Double,
        arenaRect: CGRect
    ) {
        // Rotate blades
        let rotationSpeed = BalanceConfig.Overclocker.bladeRotationSpeed * (.pi / 180) // Convert to radians
        bossState.bladeAngle += CGFloat(rotationSpeed * deltaTime)
        if bossState.bladeAngle > .pi * 2 {
            bossState.bladeAngle -= .pi * 2
        }

        // Boss moves towards center
        let center = bossState.arenaCenter
        let bossPos = CGPoint(x: boss.x, y: boss.y)
        let newPos = moveTowards(current: bossPos, target: center, speed: BalanceConfig.Overclocker.phase1CenterSpeed * CGFloat(deltaTime))
        boss.x = newPos.x
        boss.y = newPos.y
    }

    // MARK: - Phase 2: Heat Sink (4x4 Lava Grid)

    private static func updatePhase2(
        boss: inout Enemy,
        bossState: inout OverclockerState,
        gameState: inout GameState,
        deltaTime: TimeInterval,
        currentTime: Double,
        arenaRect: CGRect
    ) {
        let config = BalanceConfig.Overclocker.self

        // Timer for floor pattern changes
        if bossState.lastTileChangeTime == 0 || currentTime - bossState.lastTileChangeTime > config.tileChangeInterval {
            bossState.lastTileChangeTime = currentTime

            // Reset Grid
            var newTiles = Array(repeating: TileState.normal, count: 16)

            // Pick 2 Safe Zones
            var availableIndices = Array(0..<16)
            let safe1 = availableIndices.randomElement()!
            availableIndices.removeAll { $0 == safe1 }
            let safe2 = availableIndices.randomElement()!
            availableIndices.removeAll { $0 == safe2 }

            newTiles[safe1] = .safe
            newTiles[safe2] = .safe

            // Pick 4 Warning Zones (will become Lava)
            for _ in 0..<4 {
                if let lavaIndex = availableIndices.randomElement() {
                    newTiles[lavaIndex] = .warning
                    availableIndices.removeAll { $0 == lavaIndex }
                }
            }

            bossState.tileStates = newTiles

            // Target the nearest safe zone
            let bossPos = CGPoint(x: boss.x, y: boss.y)
            let p1 = getTileCenter(index: safe1, arenaRect: arenaRect)
            let p2 = getTileCenter(index: safe2, arenaRect: arenaRect)
            let dist1 = hypot(bossPos.x - p1.x, bossPos.y - p1.y)
            let dist2 = hypot(bossPos.x - p2.x, bossPos.y - p2.y)
            bossState.bossTargetTileIndex = (dist1 < dist2) ? safe1 : safe2
        }

        // Resolve Warnings to Lava after warning duration
        let timeSinceChange = currentTime - bossState.lastTileChangeTime
        if timeSinceChange > config.tileWarningDuration {
            for i in 0..<16 {
                if bossState.tileStates[i] == .warning {
                    bossState.tileStates[i] = .lava
                }
            }
        }

        // Move Boss to Safe Zone
        if let targetIndex = bossState.bossTargetTileIndex {
            let targetPos = getTileCenter(index: targetIndex, arenaRect: arenaRect)
            let bossPos = CGPoint(x: boss.x, y: boss.y)
            let speed = config.phase2BossMoveSpeed
            let newPos = moveTowards(current: bossPos, target: targetPos, speed: speed * CGFloat(deltaTime))
            boss.x = newPos.x
            boss.y = newPos.y
        }
    }

    // MARK: - Phase 3: Overheat (Chase + Steam Trail)

    private static func updatePhase3(
        boss: inout Enemy,
        bossState: inout OverclockerState,
        gameState: inout GameState,
        playerPos: CGPoint,
        deltaTime: TimeInterval,
        currentTime: Double
    ) {
        let config = BalanceConfig.Overclocker.self

        // Chase Player
        let bossPos = CGPoint(x: boss.x, y: boss.y)
        let newPos = moveTowards(current: bossPos, target: playerPos, speed: config.chaseSpeed * CGFloat(deltaTime))
        boss.x = newPos.x
        boss.y = newPos.y

        // Drop Steam
        if currentTime - bossState.lastSteamDropTime > config.steamDropInterval {
            bossState.lastSteamDropTime = currentTime
            let segment = SteamSegment(
                id: RandomUtils.generateId(),
                x: newPos.x,
                y: newPos.y,
                createdAt: currentTime
            )
            bossState.steamTrail.append(segment)

            // Cap trail length
            if bossState.steamTrail.count > config.maxSteamSegments {
                bossState.steamTrail.removeFirst()
            }
        }
    }

    // MARK: - Phase 4: Suction (Vacuum + Shredder)

    private static func updatePhase4(
        boss: inout Enemy,
        bossState: inout OverclockerState,
        gameState: inout GameState,
        deltaTime: TimeInterval,
        currentTime: Double,
        arenaRect: CGRect
    ) {
        let config = BalanceConfig.Overclocker.self

        // Move towards center slowly
        let center = bossState.arenaCenter
        let bossPos = CGPoint(x: boss.x, y: boss.y)
        let newPos = moveTowards(current: bossPos, target: center, speed: BalanceConfig.Overclocker.phase4CenterSpeed * CGFloat(deltaTime))
        boss.x = newPos.x
        boss.y = newPos.y

        // Toggle Suction
        bossState.suctionTimer += deltaTime
        if bossState.isSuctionActive {
            if bossState.suctionTimer > config.suctionPullDuration {
                bossState.isSuctionActive = false
                bossState.suctionTimer = 0
            }
        } else {
            if bossState.suctionTimer > config.suctionPauseDuration {
                bossState.isSuctionActive = true
                bossState.suctionTimer = 0
            }
        }

        // Continue dropping steam at boss position
        if currentTime - bossState.lastSteamDropTime > config.steamDropInterval {
            bossState.lastSteamDropTime = currentTime
            let segment = SteamSegment(
                id: RandomUtils.generateId(),
                x: newPos.x,
                y: newPos.y,
                createdAt: currentTime
            )
            bossState.steamTrail.append(segment)

            // Cap trail length
            if bossState.steamTrail.count > config.maxSteamSegments {
                bossState.steamTrail.removeFirst()
            }
        }
    }

    // MARK: - Player Interaction

    /// Calculates wind force vector to apply to player (Phase 1)
    static func calculateWindForce(playerPos: CGPoint, bossPos: CGPoint, state: OverclockerState) -> CGVector {
        guard state.phase == 1 else { return .zero }

        let dx = playerPos.x - bossPos.x
        let dy = playerPos.y - bossPos.y
        let dist = sqrt(dx * dx + dy * dy)
        let maxDist: CGFloat = BalanceConfig.Overclocker.windMaxDistance

        if dist > maxDist || dist < 1 { return .zero }

        // Force weakens with distance (linear falloff)
        let strength = BalanceConfig.Overclocker.windForce * (1.0 - (dist / maxDist))
        let angle = atan2(dy, dx)

        return CGVector(dx: cos(angle) * strength, dy: sin(angle) * strength)
    }

    /// Calculates vacuum force vector to apply to player (Phase 4)
    static func calculateVacuumForce(playerPos: CGPoint, bossPos: CGPoint, state: OverclockerState) -> CGVector {
        guard state.phase == 4 && state.isSuctionActive else { return .zero }

        let dx = bossPos.x - playerPos.x // Pull TOWARD boss
        let dy = bossPos.y - playerPos.y
        let angle = atan2(dy, dx)
        let strength = BalanceConfig.Overclocker.vacuumPullStrength

        return CGVector(dx: cos(angle) * strength, dy: sin(angle) * strength)
    }

    /// Check and apply damage from Overclocker mechanics
    static func checkMechanicsDamage(
        playerPos: CGPoint,
        state: OverclockerState,
        bossPos: CGPoint,
        arenaRect: CGRect,
        deltaTime: TimeInterval
    ) -> CGFloat {
        var damage: CGFloat = 0.0
        let config = BalanceConfig.Overclocker.self

        // Phase 1: Rotating Blades (Instant damage on contact)
        if state.phase == 1 {
            let bladeCount = config.bladeCount
            let radius = config.bladeOrbitRadius

            for i in 0..<bladeCount {
                let angleOffset = (CGFloat(i) * (2 * .pi / CGFloat(bladeCount)))
                let currentAngle = state.bladeAngle + angleOffset

                let bladeTip = CGPoint(
                    x: bossPos.x + cos(currentAngle) * radius,
                    y: bossPos.y + sin(currentAngle) * radius
                )

                // Check distance from player to blade line segment
                let dist = pointToSegmentDistance(p: playerPos, a: bossPos, b: bladeTip)
                if dist < config.bladeWidth {
                    damage += config.bladeDamage
                    break // Only take blade damage once per frame
                }
            }
        }

        // Phase 2: Lava Tiles (DPS)
        if state.phase == 2 {
            let col = Int((playerPos.x - arenaRect.minX) / (arenaRect.width / 4))
            let row = Int((playerPos.y - arenaRect.minY) / (arenaRect.height / 4))

            if col >= 0 && col < 4 && row >= 0 && row < 4 {
                let index = row * 4 + col
                if index < state.tileStates.count && state.tileStates[index] == .lava {
                    damage += config.lavaTileDPS * CGFloat(deltaTime)
                }
            }
        }

        // Phase 3 & 4: Steam Trail (DPS)
        if state.phase == 3 || state.phase == 4 {
            for segment in state.steamTrail {
                let dist = hypot(playerPos.x - segment.x, playerPos.y - segment.y)
                if dist < config.steamRadius {
                    damage += config.steamDPS * CGFloat(deltaTime)
                    break // Take damage once per frame max from steam
                }
            }
        }

        // Phase 4: Shredder Ring (DPS when close to boss)
        if state.phase == 4 {
            let dist = hypot(playerPos.x - bossPos.x, playerPos.y - bossPos.y)
            if dist < config.shredderRadius {
                damage += config.shredderDPS * CGFloat(deltaTime)
            }
        }

        return damage
    }

    /// Check contact damage from boss body
    private static func checkContactDamage(
        bossState: inout OverclockerState,
        gameState: inout GameState,
        bossPos: CGPoint,
        currentTime: Double,
        deltaTime: TimeInterval
    ) {
        let contactCooldown = BalanceConfig.Overclocker.contactCooldown
        guard currentTime - bossState.lastContactDamageTime > contactCooldown else { return }

        let playerPos = CGPoint(x: gameState.player.x, y: gameState.player.y)
        let contactRadius = BalanceConfig.Overclocker.contactRadius

        let dist = hypot(playerPos.x - bossPos.x, playerPos.y - bossPos.y)
        if dist < contactRadius {
            let contactDamage = BalanceConfig.Overclocker.contactDamage
            PlayerSystem.damagePlayer(state: &gameState, rawDamage: contactDamage)
            bossState.lastContactDamageTime = currentTime

            // Knockback
            let angle = atan2(playerPos.y - bossPos.y, playerPos.x - bossPos.x)
            let knockback = BalanceConfig.Overclocker.contactKnockback
            gameState.player.x += cos(angle) * knockback
            gameState.player.y += sin(angle) * knockback
        }
    }

    // MARK: - Helpers

    private static func moveTowards(current: CGPoint, target: CGPoint, speed: CGFloat) -> CGPoint {
        let dx = target.x - current.x
        let dy = target.y - current.y
        let dist = sqrt(dx * dx + dy * dy)

        if dist <= speed { return target }
        return CGPoint(x: current.x + (dx / dist) * speed, y: current.y + (dy / dist) * speed)
    }

    static func getTileCenter(index: Int, arenaRect: CGRect) -> CGPoint {
        let col = index % 4
        let row = index / 4
        let tileW = arenaRect.width / 4
        let tileH = arenaRect.height / 4

        return CGPoint(
            x: arenaRect.minX + (CGFloat(col) * tileW) + (tileW / 2),
            y: arenaRect.minY + (CGFloat(row) * tileH) + (tileH / 2)
        )
    }

    private static func pointToSegmentDistance(p: CGPoint, a: CGPoint, b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        if dx == 0 && dy == 0 { return hypot(p.x - a.x, p.y - a.y) }

        let t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / (dx * dx + dy * dy)

        let closest: CGPoint
        if t < 0 { closest = a }
        else if t > 1 { closest = b }
        else { closest = CGPoint(x: a.x + t * dx, y: a.y + t * dy) }

        return hypot(p.x - closest.x, p.y - closest.y)
    }
}
