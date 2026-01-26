import Foundation
import CoreGraphics

// MARK: - Arena System

class ArenaSystem {

    // MARK: - Obstacle Collision

    /// Check if a circle collides with a rectangle obstacle
    static func checkObstacleCollision(
        x: CGFloat, y: CGFloat, radius: CGFloat,
        obstacle: Obstacle
    ) -> Bool {
        // Find closest point on rectangle to circle center
        let closestX = max(obstacle.x, min(x, obstacle.x + obstacle.width))
        let closestY = max(obstacle.y, min(y, obstacle.y + obstacle.height))

        // Calculate distance from closest point to circle center
        let distanceX = x - closestX
        let distanceY = y - closestY
        let distanceSquared = distanceX * distanceX + distanceY * distanceY

        return distanceSquared < radius * radius
    }

    /// Check if a point is inside a rectangular zone
    static func isInsideZone(x: CGFloat, y: CGFloat, zone: ArenaEffectZone) -> Bool {
        return x >= zone.x && x <= zone.x + zone.width &&
               y >= zone.y && y <= zone.y + zone.height
    }

    /// Check if a point is inside a hazard
    static func isInsideHazard(x: CGFloat, y: CGFloat, hazard: Hazard) -> Bool {
        return x >= hazard.x && x <= hazard.x + hazard.width &&
               y >= hazard.y && y <= hazard.y + hazard.height
    }

    /// Resolve collision by sliding along obstacle
    static func resolveObstacleCollision(
        x: CGFloat, y: CGFloat, radius: CGFloat,
        velocityX: CGFloat, velocityY: CGFloat,
        obstacle: Obstacle
    ) -> (newX: CGFloat, newY: CGFloat, newVelX: CGFloat, newVelY: CGFloat) {
        // Find closest point on rectangle
        let closestX = max(obstacle.x, min(x, obstacle.x + obstacle.width))
        let closestY = max(obstacle.y, min(y, obstacle.y + obstacle.height))

        // Calculate penetration vector
        let dx = x - closestX
        let dy = y - closestY
        let distance = sqrt(dx * dx + dy * dy)

        if distance < 0.001 {
            // Point is inside rectangle, push out based on velocity
            return (x - velocityX, y - velocityY, 0, 0)
        }

        // Normalize and push out
        let penetration = radius - distance
        let nx = dx / distance
        let ny = dy / distance

        let newX = x + nx * penetration
        let newY = y + ny * penetration

        // Slide velocity along surface
        let dot = velocityX * nx + velocityY * ny
        let newVelX = velocityX - dot * nx
        let newVelY = velocityY - dot * ny

        return (newX, newY, newVelX, newVelY)
    }

    // MARK: - Hazard Damage

    /// Apply hazard damage to player
    static func applyHazardDamage(
        state: inout GameState,
        deltaTime: TimeInterval
    ) {
        guard let room = state.currentRoom else { return }

        for hazard in room.hazards {
            if isInsideHazard(x: state.player.x, y: state.player.y, hazard: hazard) {
                // Check invulnerability
                if state.player.invulnerableUntil > state.gameTime {
                    continue
                }

                // Apply damage based on type
                let damage = hazard.damage * CGFloat(deltaTime)
                state.player.health -= damage

                // Apply damage type effects
                switch hazard.damageType {
                case "fire", "lava":
                    // Fire damage over time effect
                    state.player.health -= damage * 0.5 // Extra burn damage

                case "cold", "ice":
                    // Slow effect
                    state.player.speedMultiplier = min(state.player.speedMultiplier, 0.6)

                case "poison":
                    // Poison stacks
                    state.player.health -= damage * 0.3

                case "corruption", "necrotic":
                    // Reduces healing
                    state.player.health -= damage

                case "laser":
                    // Instant high damage with brief invulnerability
                    state.player.health -= hazard.damage
                    state.player.invulnerableUntil = state.gameTime + 0.5

                default:
                    break
                }

                // Minimum health of 0
                state.player.health = max(0, state.player.health)
            }
        }
    }

    // MARK: - Effect Zones

    /// Apply effect zone buffs/debuffs to player
    static func applyEffectZones(state: inout GameState) {
        guard let room = state.currentRoom else { return }

        // Reset modifiers first
        state.player.speedMultiplier = 1.0
        state.player.damageReduction = 0

        for zone in room.effectZones {
            if isInsideZone(x: state.player.x, y: state.player.y, zone: zone) {
                // Apply each effect
                for (effectType, value) in zone.effects {
                    switch effectType {
                    case "healthRegeneration":
                        state.player.health = min(
                            state.player.maxHealth,
                            state.player.health + value / 60.0 // Per second regen
                        )

                    case "speedMultiplier":
                        state.player.speedMultiplier *= value

                    case "damageReduction":
                        state.player.damageReduction += value

                    case "damageBoost":
                        // Applied in weapon system
                        break

                    default:
                        break
                    }
                }
            }
        }
    }

    // MARK: - Player Obstacle Collision

    /// Process all obstacle collisions for player
    static func processPlayerObstacleCollisions(state: inout GameState) {
        guard let room = state.currentRoom else { return }

        let playerRadius: CGFloat = 15

        for obstacle in room.obstacles {
            if checkObstacleCollision(
                x: state.player.x, y: state.player.y,
                radius: playerRadius, obstacle: obstacle
            ) {
                let result = resolveObstacleCollision(
                    x: state.player.x, y: state.player.y,
                    radius: playerRadius,
                    velocityX: state.player.velocityX,
                    velocityY: state.player.velocityY,
                    obstacle: obstacle
                )

                state.player.x = result.newX
                state.player.y = result.newY
                state.player.velocityX = result.newVelX
                state.player.velocityY = result.newVelY
            }
        }
    }

    // MARK: - Enemy Obstacle Collision

    /// Process obstacle collisions for all enemies
    static func processEnemyObstacleCollisions(state: inout GameState) {
        guard let room = state.currentRoom else { return }

        for i in 0..<state.enemies.count {
            let enemyRadius: CGFloat = 12

            for obstacle in room.obstacles {
                if checkObstacleCollision(
                    x: state.enemies[i].x, y: state.enemies[i].y,
                    radius: enemyRadius, obstacle: obstacle
                ) {
                    let result = resolveObstacleCollision(
                        x: state.enemies[i].x, y: state.enemies[i].y,
                        radius: enemyRadius,
                        velocityX: state.enemies[i].velocityX,
                        velocityY: state.enemies[i].velocityY,
                        obstacle: obstacle
                    )

                    state.enemies[i].x = result.newX
                    state.enemies[i].y = result.newY
                    state.enemies[i].velocityX = result.newVelX
                    state.enemies[i].velocityY = result.newVelY
                }
            }
        }
    }

    // MARK: - Projectile Obstacle Collision

    /// Check if projectile hits an obstacle (destroys projectile)
    static func processProjectileObstacleCollisions(state: inout GameState) {
        guard let room = state.currentRoom else { return }

        state.projectiles = state.projectiles.filter { projectile in
            for obstacle in room.obstacles {
                // Simple point-in-rectangle check for projectiles
                if projectile.x >= obstacle.x &&
                   projectile.x <= obstacle.x + obstacle.width &&
                   projectile.y >= obstacle.y &&
                   projectile.y <= obstacle.y + obstacle.height {
                    return false // Remove projectile
                }
            }
            return true // Keep projectile
        }
    }

    // MARK: - Moving Hazard Updates

    /// Update positions of moving hazards (like laser fences)
    static func updateMovingHazards(room: inout DungeonRoom, deltaTime: TimeInterval) {
        for i in 0..<room.hazards.count {
            // Check if this is a moving hazard (laser fence)
            if room.hazards[i].type == "laser_fence" {
                // Get movement properties from the hazard
                // In a full implementation, we'd store these on the hazard
                let moveSpeed: CGFloat = 100
                let moveDirection = i % 2 == 0 ? 1 : -1

                room.hazards[i].y += CGFloat(moveDirection) * moveSpeed * CGFloat(deltaTime)

                // Bounce at boundaries
                if room.hazards[i].y < 0 {
                    room.hazards[i].y = 0
                }
                if room.hazards[i].y + room.hazards[i].height > room.height {
                    room.hazards[i].y = room.height - room.hazards[i].height
                }
            }
        }
    }

    // MARK: - Security Camera Updates

    /// Update security cameras and check for player detection
    static func updateSecurityCameras(
        cameras: inout [SecurityCamera],
        playerX: CGFloat, playerY: CGFloat,
        gameTime: Double,
        onAlarmTriggered: () -> Void
    ) {
        for i in 0..<cameras.count {
            // Rotate camera
            cameras[i].rotation += cameras[i].rotationSpeed / 60.0

            // Normalize rotation
            if cameras[i].rotation > 360 {
                cameras[i].rotation -= 360
            }
            if cameras[i].rotation < 0 {
                cameras[i].rotation += 360
            }

            // Check cooldown
            if cameras[i].isTriggered &&
               gameTime - cameras[i].lastTriggerTime < cameras[i].cooldown {
                continue
            }

            // Check if player is in detection cone
            if isPlayerInCameraView(
                camera: cameras[i],
                playerX: playerX, playerY: playerY
            ) {
                cameras[i].isTriggered = true
                cameras[i].lastTriggerTime = gameTime
                onAlarmTriggered()
            }
        }
    }

    /// Check if player is within camera detection cone
    private static func isPlayerInCameraView(
        camera: SecurityCamera,
        playerX: CGFloat, playerY: CGFloat
    ) -> Bool {
        // Distance check
        let dx = playerX - camera.x
        let dy = playerY - camera.y
        let distance = sqrt(dx * dx + dy * dy)

        if distance > camera.detectionRadius {
            return false
        }

        // Angle check
        let angleToPlayer = atan2(dy, dx) * 180 / .pi
        var angleDiff = angleToPlayer - camera.rotation

        // Normalize angle difference
        while angleDiff > 180 { angleDiff -= 360 }
        while angleDiff < -180 { angleDiff += 360 }

        return abs(angleDiff) < camera.detectionAngle / 2
    }

    // MARK: - Door Interactions

    /// Check if player is at a door and can transition
    static func checkDoorInteraction(
        playerX: CGFloat, playerY: CGFloat,
        room: DungeonRoom
    ) -> Door? {
        let interactionRadius: CGFloat = 50

        for door in room.doors {
            let doorCenterX = door.x + door.width / 2
            let doorCenterY = door.y + door.height / 2

            let distance = MathUtils.distance(
                from: CGPoint(x: playerX, y: playerY),
                to: CGPoint(x: doorCenterX, y: doorCenterY)
            )

            if distance < interactionRadius && !door.locked {
                return door
            }
        }

        return nil
    }

    /// Unlock a door (after clearing all enemies)
    static func unlockDoors(room: inout DungeonRoom) {
        for i in 0..<room.doors.count {
            room.doors[i].locked = false
        }
    }

    // MARK: - Arena Events

    struct ArenaEvent {
        let intervalMin: Double
        let intervalMax: Double
        var lastTriggered: Double
        var nextTrigger: Double
    }

    /// Initialize arena event timers
    static func initializeArenaEvents() -> [String: ArenaEvent] {
        return [
            "enemyWave": ArenaEvent(
                intervalMin: 30,
                intervalMax: 60,
                lastTriggered: 0,
                nextTrigger: Double.random(in: 30...60)
            ),
            "hazardSpawn": ArenaEvent(
                intervalMin: 45,
                intervalMax: 90,
                lastTriggered: 0,
                nextTrigger: Double.random(in: 45...90)
            ),
            "buffZone": ArenaEvent(
                intervalMin: 60,
                intervalMax: 120,
                lastTriggered: 0,
                nextTrigger: Double.random(in: 60...120)
            )
        ]
    }

    /// Check and trigger arena events
    static func triggerArenaEvents(
        events: inout [String: ArenaEvent],
        gameTime: Double,
        state: inout GameState
    ) {
        for (eventType, var event) in events {
            if gameTime >= event.nextTrigger {
                // Trigger event
                switch eventType {
                case "enemyWave":
                    // Spawn extra enemies
                    SpawnSystem.spawnWave(state: &state, count: 5 + Int(gameTime / 60))

                case "hazardSpawn":
                    // Add temporary hazard
                    if var room = state.currentRoom {
                        let hazard = Hazard(
                            id: RandomUtils.generateId(),
                            x: CGFloat.random(in: 200...(room.width - 200)),
                            y: CGFloat.random(in: 200...(room.height - 200)),
                            width: 100, height: 100,
                            damage: 15,
                            damageType: "generic",
                            type: "temporary_hazard"
                        )
                        room.hazards.append(hazard)
                        state.currentRoom = room
                    }

                case "buffZone":
                    // Spawn temporary buff zone
                    if var room = state.currentRoom {
                        let zone = ArenaEffectZone(
                            id: RandomUtils.generateId(),
                            x: CGFloat.random(in: 200...(room.width - 200)),
                            y: CGFloat.random(in: 200...(room.height - 200)),
                            width: 150, height: 150,
                            effects: ["damageBoost": 1.5, "speedMultiplier": 1.2],
                            type: "power_zone"
                        )
                        room.effectZones.append(zone)
                        state.currentRoom = room
                    }

                default:
                    break
                }

                // Update event timing
                event.lastTriggered = gameTime
                event.nextTrigger = gameTime + Double.random(in: event.intervalMin...event.intervalMax)
                events[eventType] = event
            }
        }
    }

    // MARK: - Spawn Alarm Enemies

    static func spawnAlarmEnemies(state: inout GameState, at cameraPosition: CGPoint) {
        // Spawn 8-10 enemies near camera position
        let count = Int.random(in: 8...10)

        for _ in 0..<count {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance: CGFloat = CGFloat.random(in: 100...200)

            let x = cameraPosition.x + cos(angle) * distance
            let y = cameraPosition.y + sin(angle) * distance

            // Mix of fast and basic enemies
            let type = Double.random(in: 0...1) < 0.6 ? "fast" : "basic"

            if let config = GameConfigLoader.shared.getEnemy(type) {
                let enemy = Enemy(
                    id: RandomUtils.generateId(),
                    type: type,
                    x: x,
                    y: y,
                    health: config.health,
                    maxHealth: config.health,
                    damage: config.damage,
                    speed: config.speed,
                    xpValue: config.coinValue, // XP derived from coin value
                    color: config.color,
                    velocityX: 0,
                    velocityY: 0
                )
                state.enemies.append(enemy)
            }
        }
    }
}
