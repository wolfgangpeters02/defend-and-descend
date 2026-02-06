import Foundation
import CoreGraphics

// MARK: - Boss Bot Protocol
// AI strategies for simulating player behavior in boss fights

protocol BossBot {
    var name: String { get }
    func decide(context: BossBotContext) -> BossBotAction
}

// MARK: - Context

struct BossBotContext {
    // Player state
    let playerX: CGFloat
    let playerY: CGFloat
    let playerHealth: CGFloat
    let playerMaxHealth: CGFloat

    // Boss state
    let bossX: CGFloat
    let bossY: CGFloat
    let bossHealth: CGFloat
    let bossMaxHealth: CGFloat
    let bossPhase: Int
    let bossInvulnerable: Bool

    // Arena
    let arenaWidth: CGFloat
    let arenaHeight: CGFloat

    // Hazards
    let puddles: [SimPuddle]
    let lasers: [SimLaser]
    let voidZones: [SimVoidZone]
    let projectiles: [SimProjectile]
    let minions: [SimMinion]
    let pylons: [SimPylon]
    let voidRifts: [SimVoidRift]
    let gravityWells: [SimGravityWell]
    let shrinkingArenaRadius: CGFloat
    let arenaCenter: CGPoint

    let currentTime: TimeInterval

    // Helper computed properties
    var distanceToBoss: CGFloat {
        let dx = bossX - playerX
        let dy = bossY - playerY
        return sqrt(dx * dx + dy * dy)
    }

    var bossHealthPercent: CGFloat {
        return bossHealth / bossMaxHealth
    }

    var playerHealthPercent: CGFloat {
        return playerHealth / playerMaxHealth
    }
}

// MARK: - Actions

enum BossBotAction {
    case move(dx: CGFloat, dy: CGFloat)  // Normalized direction
    case moveTowards(x: CGFloat, y: CGFloat)
    case idle
}

// MARK: - Aggressive Bot
// Maximizes DPS by staying close to boss, minimal dodging

struct AggressiveBot: BossBot {
    let name = "Aggressive"

    func decide(context: BossBotContext) -> BossBotAction {
        // If pylons exist and boss is invulnerable, attack closest pylon
        let activePylons = context.pylons.filter { !$0.destroyed }
        if !activePylons.isEmpty && context.bossInvulnerable {
            let closest = activePylons.min { pylon1, pylon2 in
                let d1 = distance(from: context.playerX, context.playerY, to: pylon1.x, pylon1.y)
                let d2 = distance(from: context.playerX, context.playerY, to: pylon2.x, pylon2.y)
                return d1 < d2
            }!
            return .moveTowards(x: closest.x, y: closest.y)
        }

        // Otherwise chase boss
        return .moveTowards(x: context.bossX, y: context.bossY)
    }

    private func distance(from x1: CGFloat, _ y1: CGFloat, to x2: CGFloat, _ y2: CGFloat) -> CGFloat {
        let dx = x2 - x1
        let dy = y2 - y1
        return sqrt(dx * dx + dy * dy)
    }
}

// MARK: - Defensive Bot
// Prioritizes survival - dodges all hazards, attacks only when safe

struct DefensiveBot: BossBot {
    let name = "Defensive"

    func decide(context: BossBotContext) -> BossBotAction {
        // Calculate threat direction (sum of all hazard threats)
        var threatX: CGFloat = 0
        var threatY: CGFloat = 0

        // Avoid boss when in melee range
        let dx = context.bossX - context.playerX
        let dy = context.bossY - context.playerY
        let bossDist = sqrt(dx * dx + dy * dy)
        if bossDist < 200 {
            let weight: CGFloat = 2.0
            threatX -= (dx / bossDist) * weight
            threatY -= (dy / bossDist) * weight
        }

        // Avoid puddles
        for puddle in context.puddles {
            let threat = calculateThreat(context: context, hazardX: puddle.x, hazardY: puddle.y, radius: puddle.radius + 50)
            threatX += threat.dx
            threatY += threat.dy
        }

        // Avoid void zones
        for zone in context.voidZones {
            let threat = calculateThreat(context: context, hazardX: zone.x, hazardY: zone.y, radius: zone.radius + 50)
            threatX += threat.dx
            threatY += threat.dy
        }

        // Avoid incoming projectiles
        for proj in context.projectiles {
            // Predict where projectile will be
            let futureX = proj.x + proj.velocityX * 0.5
            let futureY = proj.y + proj.velocityY * 0.5
            let threat = calculateThreat(context: context, hazardX: futureX, hazardY: futureY, radius: 80)
            threatX += threat.dx * 1.5  // Higher weight for projectiles
            threatY += threat.dy * 1.5
        }

        // Avoid lasers (perpendicular movement)
        for laser in context.lasers where laser.lifetime >= 1.0 {
            let angleRad = laser.angle * .pi / 180
            let laserDirX = cos(angleRad)
            let laserDirY = -sin(angleRad)

            // Check if player is near laser line
            let toPlayerX = context.playerX - laser.originX
            let toPlayerY = context.playerY - laser.originY
            let dot = toPlayerX * laserDirX + toPlayerY * laserDirY

            if dot > 0 && dot < laser.length {
                // Player is along laser - move perpendicular
                let perpX = -laserDirY
                let perpY = laserDirX
                let cross = toPlayerX * perpY - toPlayerY * perpX
                if cross > 0 {
                    threatX += perpX * 3
                    threatY += perpY * 3
                } else {
                    threatX -= perpX * 3
                    threatY -= perpY * 3
                }
            }
        }

        // Avoid void rifts (perpendicular movement)
        for rift in context.voidRifts {
            let angleRad = rift.angle * .pi / 180
            let riftDirX = cos(angleRad)
            let riftDirY = sin(angleRad)

            let toPlayerX = context.playerX - context.arenaCenter.x
            let toPlayerY = context.playerY - context.arenaCenter.y
            let dot = toPlayerX * riftDirX + toPlayerY * riftDirY

            if dot > 0 && dot < rift.length {
                let perpX = -riftDirY
                let perpY = riftDirX
                let cross = toPlayerX * perpY - toPlayerY * perpX
                if cross > 0 {
                    threatX += perpX * 3
                    threatY += perpY * 3
                } else {
                    threatX -= perpX * 3
                    threatY -= perpY * 3
                }
            }
        }

        // Avoid minions
        for minion in context.minions where !minion.isDead {
            let threat = calculateThreat(context: context, hazardX: minion.x, hazardY: minion.y, radius: 60)
            threatX += threat.dx
            threatY += threat.dy
        }

        // Stay inside shrinking arena
        let toCenter_dx = context.arenaCenter.x - context.playerX
        let toCenter_dy = context.arenaCenter.y - context.playerY
        let distToCenter = sqrt(toCenter_dx * toCenter_dx + toCenter_dy * toCenter_dy)

        if distToCenter > context.shrinkingArenaRadius - 100 {
            threatX += toCenter_dx * 2
            threatY += toCenter_dy * 2
        }

        // Handle pylons in Phase 2
        let activePylons = context.pylons.filter { !$0.destroyed }
        if !activePylons.isEmpty && context.bossInvulnerable {
            let closest = activePylons.min { p1, p2 in
                let d1 = distance(x1: context.playerX, y1: context.playerY, x2: p1.x, y2: p1.y)
                let d2 = distance(x1: context.playerX, y1: context.playerY, x2: p2.x, y2: p2.y)
                return d1 < d2
            }!
            // Add slight pull towards pylon
            let toPylonX = closest.x - context.playerX
            let toPylonY = closest.y - context.playerY
            threatX += toPylonX * 0.3
            threatY += toPylonY * 0.3
        }

        // Normalize and move
        let magnitude = sqrt(threatX * threatX + threatY * threatY)
        if magnitude > 0.1 {
            return .move(dx: threatX / magnitude, dy: threatY / magnitude)
        }

        // If no threats, approach boss at safe distance
        if context.distanceToBoss > 250 {
            return .moveTowards(x: context.bossX, y: context.bossY)
        }

        return .idle
    }

    private func calculateThreat(context: BossBotContext, hazardX: CGFloat, hazardY: CGFloat, radius: CGFloat) -> (dx: CGFloat, dy: CGFloat) {
        let dx = context.playerX - hazardX
        let dy = context.playerY - hazardY
        let dist = sqrt(dx * dx + dy * dy)

        if dist < radius && dist > 0 {
            let strength = (radius - dist) / radius * 2
            return (dx / dist * strength, dy / dist * strength)
        }
        return (0, 0)
    }

    private func distance(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat) -> CGFloat {
        let dx = x2 - x1
        let dy = y2 - y1
        return sqrt(dx * dx + dy * dy)
    }
}

// MARK: - Balanced Bot
// Mix of offense and defense - moderate dodging, good DPS

struct BalancedBot: BossBot {
    let name = "Balanced"

    func decide(context: BossBotContext) -> BossBotAction {
        // Check for immediate threats
        let immediateThreat = checkImmediateThreat(context: context)
        if let dodgeDir = immediateThreat {
            return .move(dx: dodgeDir.0, dy: dodgeDir.1)
        }

        // Handle pylons
        let activePylons = context.pylons.filter { !$0.destroyed }
        if !activePylons.isEmpty && context.bossInvulnerable {
            let closest = activePylons.min { p1, p2 in
                let d1 = dist(context.playerX, context.playerY, p1.x, p1.y)
                let d2 = dist(context.playerX, context.playerY, p2.x, p2.y)
                return d1 < d2
            }!
            return .moveTowards(x: closest.x, y: closest.y)
        }

        // Maintain optimal range (150-250 from boss)
        let bossDistance = context.distanceToBoss
        if bossDistance < 150 {
            // Too close, back away
            let dx = context.playerX - context.bossX
            let dy = context.playerY - context.bossY
            let d = sqrt(dx * dx + dy * dy)
            return .move(dx: dx / d, dy: dy / d)
        } else if bossDistance > 280 {
            // Too far, get closer
            return .moveTowards(x: context.bossX, y: context.bossY)
        }

        // Circle strafe around boss
        let dx = context.playerX - context.bossX
        let dy = context.playerY - context.bossY
        let d = sqrt(dx * dx + dy * dy)
        // Perpendicular direction (clockwise)
        return .move(dx: dy / d, dy: -dx / d)
    }

    private func checkImmediateThreat(context: BossBotContext) -> (CGFloat, CGFloat)? {
        // Check projectiles
        for proj in context.projectiles {
            let futureX = proj.x + proj.velocityX * 0.3
            let futureY = proj.y + proj.velocityY * 0.3
            let d = dist(context.playerX, context.playerY, futureX, futureY)
            if d < 60 {
                // Dodge perpendicular to projectile direction
                let velMag = sqrt(proj.velocityX * proj.velocityX + proj.velocityY * proj.velocityY)
                if velMag > 0 {
                    return (-proj.velocityY / velMag, proj.velocityX / velMag)
                }
            }
        }

        // Check puddles/zones about to activate
        for puddle in context.puddles {
            let d = dist(context.playerX, context.playerY, puddle.x, puddle.y)
            if d < puddle.radius + 30 {
                let dx = context.playerX - puddle.x
                let dy = context.playerY - puddle.y
                return (dx / d, dy / d)
            }
        }

        for zone in context.voidZones where zone.isActive || zone.lifetime > zone.warningTime - 0.5 {
            let d = dist(context.playerX, context.playerY, zone.x, zone.y)
            if d < zone.radius + 30 {
                let dx = context.playerX - zone.x
                let dy = context.playerY - zone.y
                return (dx / d, dy / d)
            }
        }

        // Check lasers
        for laser in context.lasers where laser.lifetime >= 0.5 {
            let angleRad = laser.angle * .pi / 180
            let laserEndX = laser.originX + cos(angleRad) * laser.length
            let laserEndY = laser.originY - sin(angleRad) * laser.length

            let d = pointToLineDist(
                px: context.playerX, py: context.playerY,
                x1: laser.originX, y1: laser.originY,
                x2: laserEndX, y2: laserEndY
            )
            if d < 50 {
                // Move perpendicular
                let perpX = -sin(angleRad)
                let perpY = -cos(angleRad)
                return (perpX, perpY)
            }
        }

        return nil
    }

    private func dist(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> CGFloat {
        let dx = x2 - x1
        let dy = y2 - y1
        return sqrt(dx * dx + dy * dy)
    }

    private func pointToLineDist(px: CGFloat, py: CGFloat, x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat) -> CGFloat {
        let dx = x2 - x1
        let dy = y2 - y1
        let lengthSq = dx * dx + dy * dy
        guard lengthSq > 0 else { return dist(px, py, x1, y1) }

        var t = ((px - x1) * dx + (py - y1) * dy) / lengthSq
        t = max(0, min(1, t))
        let nearestX = x1 + t * dx
        let nearestY = y1 + t * dy
        return dist(px, py, nearestX, nearestY)
    }
}

// MARK: - Phase-Aware Bot
// Adapts strategy based on boss phase

struct PhaseAwareBot: BossBot {
    let name = "PhaseAware"

    func decide(context: BossBotContext) -> BossBotAction {
        switch context.bossPhase {
        case 1:
            // Phase 1: Aggressive positioning, boss is mobile
            return aggressiveApproach(context: context)
        case 2:
            // Phase 2: Pylon priority (Void Harbinger) or minion kiting (Cyberboss)
            return phase2Strategy(context: context)
        case 3:
            // Phase 3: Hazard focus - puddles, rifts
            return defensiveKiting(context: context)
        case 4:
            // Phase 4: Maximum survival - lasers, enrage
            return survivalMode(context: context)
        default:
            return BalancedBot().decide(context: context)
        }
    }

    private func aggressiveApproach(context: BossBotContext) -> BossBotAction {
        // Check projectiles
        if let dodge = dodgeProjectiles(context: context) {
            return dodge
        }

        // Stay at medium range
        if context.distanceToBoss > 200 {
            return .moveTowards(x: context.bossX, y: context.bossY)
        } else if context.distanceToBoss < 120 {
            let dx = context.playerX - context.bossX
            let dy = context.playerY - context.bossY
            let d = sqrt(dx * dx + dy * dy)
            return .move(dx: dx / d, dy: dy / d)
        }
        return .idle
    }

    private func phase2Strategy(context: BossBotContext) -> BossBotAction {
        // Priority: destroy pylons
        let activePylons = context.pylons.filter { !$0.destroyed }
        if !activePylons.isEmpty {
            // Dodge homing beams first
            if let dodge = dodgeProjectiles(context: context) {
                return dodge
            }

            // Attack closest pylon
            let closest = activePylons.min { p1, p2 in
                dist(context.playerX, context.playerY, p1.x, p1.y) <
                dist(context.playerX, context.playerY, p2.x, p2.y)
            }!
            return .moveTowards(x: closest.x, y: closest.y)
        }

        // Kite minions if no pylons
        return kiteMinions(context: context)
    }

    private func defensiveKiting(context: BossBotContext) -> BossBotAction {
        // Avoid hazards as priority
        var moveX: CGFloat = 0
        var moveY: CGFloat = 0

        // Avoid puddles
        for puddle in context.puddles where puddle.lifetime >= puddle.warningTime - 0.3 {
            let d = dist(context.playerX, context.playerY, puddle.x, puddle.y)
            if d < puddle.radius + 80 {
                let dx = context.playerX - puddle.x
                let dy = context.playerY - puddle.y
                moveX += dx / d * 2
                moveY += dy / d * 2
            }
        }

        // Avoid void zones
        for zone in context.voidZones where zone.isActive || zone.lifetime > zone.warningTime - 0.5 {
            let d = dist(context.playerX, context.playerY, zone.x, zone.y)
            if d < zone.radius + 80 {
                let dx = context.playerX - zone.x
                let dy = context.playerY - zone.y
                moveX += dx / d * 2
                moveY += dy / d * 2
            }
        }

        // Avoid void rifts
        for rift in context.voidRifts {
            let angleRad = rift.angle * .pi / 180
            let endX = context.arenaCenter.x + cos(angleRad) * rift.length
            let endY = context.arenaCenter.y + sin(angleRad) * rift.length

            let d = pointToLineDist(
                px: context.playerX, py: context.playerY,
                x1: context.arenaCenter.x, y1: context.arenaCenter.y,
                x2: endX, y2: endY
            )
            if d < 60 {
                // Move perpendicular
                moveX += -sin(angleRad) * 3
                moveY += cos(angleRad) * 3
            }
        }

        let magnitude = sqrt(moveX * moveX + moveY * moveY)
        if magnitude > 0.5 {
            return .move(dx: moveX / magnitude, dy: moveY / magnitude)
        }

        // Maintain distance from boss
        if context.distanceToBoss < 200 {
            let dx = context.playerX - context.bossX
            let dy = context.playerY - context.bossY
            let d = sqrt(dx * dx + dy * dy)
            return .move(dx: dx / d, dy: dy / d)
        }

        return .idle
    }

    private func survivalMode(context: BossBotContext) -> BossBotAction {
        var moveX: CGFloat = 0
        var moveY: CGFloat = 0

        // Stay inside shrinking arena (highest priority)
        let toCenter_dx = context.arenaCenter.x - context.playerX
        let toCenter_dy = context.arenaCenter.y - context.playerY
        let distToCenter = sqrt(toCenter_dx * toCenter_dx + toCenter_dy * toCenter_dy)

        if distToCenter > context.shrinkingArenaRadius - 80 {
            return .move(dx: toCenter_dx / distToCenter, dy: toCenter_dy / distToCenter)
        }

        // Avoid lasers (critical)
        for laser in context.lasers where laser.lifetime >= 0.8 {
            let angleRad = laser.angle * .pi / 180
            let endX = laser.originX + cos(angleRad) * laser.length
            let endY = laser.originY - sin(angleRad) * laser.length

            let d = pointToLineDist(
                px: context.playerX, py: context.playerY,
                x1: laser.originX, y1: laser.originY,
                x2: endX, y2: endY
            )
            if d < 70 {
                // Strong perpendicular dodge
                let perpX = -sin(angleRad)
                let perpY = -cos(angleRad)
                moveX += perpX * 4
                moveY += perpY * 4
            }
        }

        // Apply defensive kiting on top
        let defensiveResult = defensiveKiting(context: context)
        if case .move(let dx, let dy) = defensiveResult {
            moveX += dx
            moveY += dy
        }

        let magnitude = sqrt(moveX * moveX + moveY * moveY)
        if magnitude > 0.5 {
            return .move(dx: moveX / magnitude, dy: moveY / magnitude)
        }

        return .idle
    }

    private func kiteMinions(context: BossBotContext) -> BossBotAction {
        var threatX: CGFloat = 0
        var threatY: CGFloat = 0

        for minion in context.minions where !minion.isDead {
            let d = dist(context.playerX, context.playerY, minion.x, minion.y)
            if d < 100 && d > 0 {
                threatX += (context.playerX - minion.x) / d
                threatY += (context.playerY - minion.y) / d
            }
        }

        let magnitude = sqrt(threatX * threatX + threatY * threatY)
        if magnitude > 0.5 {
            return .move(dx: threatX / magnitude, dy: threatY / magnitude)
        }
        return .idle
    }

    private func dodgeProjectiles(context: BossBotContext) -> BossBotAction? {
        for proj in context.projectiles {
            let futureX = proj.x + proj.velocityX * 0.4
            let futureY = proj.y + proj.velocityY * 0.4
            let d = dist(context.playerX, context.playerY, futureX, futureY)

            if d < 70 {
                let velMag = sqrt(proj.velocityX * proj.velocityX + proj.velocityY * proj.velocityY)
                if velMag > 0 {
                    return .move(dx: -proj.velocityY / velMag, dy: proj.velocityX / velMag)
                }
            }
        }
        return nil
    }

    private func dist(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> CGFloat {
        let dx = x2 - x1
        let dy = y2 - y1
        return sqrt(dx * dx + dy * dy)
    }

    private func pointToLineDist(px: CGFloat, py: CGFloat, x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat) -> CGFloat {
        let dx = x2 - x1
        let dy = y2 - y1
        let lengthSq = dx * dx + dy * dy
        guard lengthSq > 0 else { return dist(px, py, x1, y1) }

        var t = ((px - x1) * dx + (py - y1) * dy) / lengthSq
        t = max(0, min(1, t))
        return dist(px, py, x1 + t * dx, y1 + t * dy)
    }
}

// MARK: - Standing Still Bot
// Control group - doesn't move at all (tests baseline difficulty)

struct StandingStillBot: BossBot {
    let name = "StandingStill"

    func decide(context: BossBotContext) -> BossBotAction {
        return .idle
    }
}

// MARK: - Random Bot
// Moves randomly - tests if strategy matters

struct RandomBot: BossBot {
    let name = "Random"

    func decide(context: BossBotContext) -> BossBotAction {
        let dx = CGFloat.random(in: -1...1)
        let dy = CGFloat.random(in: -1...1)
        let mag = sqrt(dx * dx + dy * dy)
        if mag > 0 {
            return .move(dx: dx / mag, dy: dy / mag)
        }
        return .idle
    }
}
