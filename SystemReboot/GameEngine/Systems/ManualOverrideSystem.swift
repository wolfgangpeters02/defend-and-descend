import Foundation

// MARK: - Manual Override System (Pure Domain Logic)

/// Extracted from ManualOverrideScene — pure game simulation with no SpriteKit dependencies.
/// The scene calls `ManualOverrideSystem.update()` each frame and renders the resulting state.
struct ManualOverrideSystem {

    // MARK: - Hazard Model

    enum HazardKind {
        case projectile(velocity: CGPoint)
        case expanding(currentRadius: CGFloat, maxRadius: CGFloat)
        case sweep(velocity: CGFloat, isHorizontal: Bool, gapStart: CGFloat, gapEnd: CGFloat)
    }

    struct Hazard: Identifiable {
        let id: UUID
        var position: CGPoint
        var kind: HazardKind
        var removed: Bool = false
    }

    // MARK: - Frame Events

    struct FrameEvents {
        var damageDealt: Bool = false
        var gameWon: Bool = false
        var gameLost: Bool = false
        var spawnedHazards: [Hazard] = []
        var removedHazardIDs: Set<UUID> = []
    }

    // MARK: - Simulation State

    struct State {
        var timeRemaining: TimeInterval
        var health: Int
        var isGameOver: Bool = false

        var playerPosition: CGPoint
        var playerVelocity: CGPoint = .zero

        var hazards: [Hazard] = []

        var invincibilityTimer: TimeInterval = 0
        var hazardSpawnTimer: TimeInterval = 0
        var hazardSpawnInterval: TimeInterval
        var difficultyTimer: TimeInterval = 0
    }

    // MARK: - Factory

    static func makeInitialState(sceneSize: CGSize) -> State {
        State(
            timeRemaining: BalanceConfig.ManualOverride.duration,
            health: BalanceConfig.ManualOverride.maxHealth,
            playerPosition: CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2),
            hazardSpawnInterval: BalanceConfig.ManualOverride.initialHazardSpawnInterval
        )
    }

    // MARK: - Main Update

    /// Advance the simulation by one frame. Returns events the renderer should react to.
    static func update(state: inout State, deltaTime: TimeInterval, sceneSize: CGSize) -> FrameEvents {
        guard !state.isGameOver else { return FrameEvents() }

        var events = FrameEvents()

        // Timer countdown
        state.timeRemaining -= deltaTime
        if state.timeRemaining <= 0 {
            state.isGameOver = true
            events.gameWon = true
            return events
        }

        // Invincibility tick
        if state.invincibilityTimer > 0 {
            state.invincibilityTimer -= deltaTime
        }

        // Difficulty escalation — spawn faster every 5 seconds
        state.difficultyTimer += deltaTime
        if state.difficultyTimer >= 5 {
            state.difficultyTimer = 0
            state.hazardSpawnInterval = max(0.5, state.hazardSpawnInterval - 0.2)
        }

        // Hazard spawning
        state.hazardSpawnTimer += deltaTime
        if state.hazardSpawnTimer >= state.hazardSpawnInterval {
            state.hazardSpawnTimer = 0
            let hazard = spawnHazard(sceneSize: sceneSize)
            state.hazards.append(hazard)
            events.spawnedHazards.append(hazard)
        }

        // Player movement
        updatePlayer(state: &state, deltaTime: deltaTime, sceneSize: sceneSize)

        // Hazard physics
        let removedIDs = updateHazards(state: &state, deltaTime: deltaTime, sceneSize: sceneSize)
        events.removedHazardIDs = removedIDs

        // Collision detection
        if checkCollisions(state: &state) {
            events.damageDealt = true
            if state.health <= 0 {
                state.isGameOver = true
                events.gameLost = true
            }
        }

        return events
    }

    // MARK: - Player Input

    static func applyJoystickInput(state: inout State, angle: CGFloat, distance: CGFloat) {
        let speed = BalanceConfig.ManualOverride.playerSpeed * distance
        state.playerVelocity = CGPoint(
            x: cos(angle) * speed,
            y: -sin(angle) * speed // Invert Y for screen coordinates
        )
    }

    static func stopPlayer(state: inout State) {
        state.playerVelocity = .zero
    }

    // MARK: - Player Movement (private)

    private static func updatePlayer(state: inout State, deltaTime: TimeInterval, sceneSize: CGSize) {
        var newX = state.playerPosition.x + state.playerVelocity.x * CGFloat(deltaTime)
        var newY = state.playerPosition.y + state.playerVelocity.y * CGFloat(deltaTime)

        let padding: CGFloat = 30
        newX = max(padding, min(sceneSize.width - padding, newX))
        newY = max(120, min(sceneSize.height - 120, newY))

        state.playerPosition = CGPoint(x: newX, y: newY)
    }

    // MARK: - Hazard Spawning (private)

    private static func spawnHazard(sceneSize: CGSize) -> Hazard {
        let hazardType = Int.random(in: 0...2)
        switch hazardType {
        case 0:
            return spawnProjectileHazard(sceneSize: sceneSize)
        case 1:
            return spawnExpandingHazard(sceneSize: sceneSize)
        default:
            return spawnSweepHazard(sceneSize: sceneSize)
        }
    }

    private static func spawnProjectileHazard(sceneSize: CGSize) -> Hazard {
        let edge = Int.random(in: 0...3)
        let speed = CGFloat.random(
            in: BalanceConfig.ManualOverride.hazardSpeedMin...BalanceConfig.ManualOverride.hazardSpeedMax
        )
        let variance = BalanceConfig.ManualOverride.hazardVelocityVariance
        var startPos: CGPoint
        var velocity: CGPoint

        switch edge {
        case 0: // Top
            startPos = CGPoint(x: CGFloat.random(in: 50...(sceneSize.width - 50)), y: sceneSize.height - 100)
            velocity = CGPoint(x: CGFloat.random(in: -variance...variance), y: -speed)
        case 1: // Bottom
            startPos = CGPoint(x: CGFloat.random(in: 50...(sceneSize.width - 50)), y: 120)
            velocity = CGPoint(x: CGFloat.random(in: -variance...variance), y: speed)
        case 2: // Left
            startPos = CGPoint(x: 30, y: CGFloat.random(in: 150...(sceneSize.height - 150)))
            velocity = CGPoint(x: speed, y: CGFloat.random(in: -variance...variance))
        default: // Right
            startPos = CGPoint(x: sceneSize.width - 30, y: CGFloat.random(in: 150...(sceneSize.height - 150)))
            velocity = CGPoint(x: -speed, y: CGFloat.random(in: -variance...variance))
        }

        return Hazard(id: UUID(), position: startPos, kind: .projectile(velocity: velocity))
    }

    private static func spawnExpandingHazard(sceneSize: CGSize) -> Hazard {
        let position = CGPoint(
            x: CGFloat.random(in: 60...(sceneSize.width - 60)),
            y: CGFloat.random(in: 160...(sceneSize.height - 160))
        )
        return Hazard(
            id: UUID(),
            position: position,
            kind: .expanding(currentRadius: 5, maxRadius: 60)
        )
    }

    private static func spawnSweepHazard(sceneSize: CGSize) -> Hazard {
        let isHorizontal = Bool.random()
        let gapSize: CGFloat = 70
        let direction: CGFloat = Bool.random() ? 1 : -1

        if isHorizontal {
            let startY = CGFloat.random(in: 150...(sceneSize.height - 150))
            let gapStart = CGFloat.random(in: 40...(sceneSize.width - 40 - gapSize))
            return Hazard(
                id: UUID(),
                position: CGPoint(x: 0, y: startY),
                kind: .sweep(velocity: 80 * direction, isHorizontal: true,
                             gapStart: gapStart, gapEnd: gapStart + gapSize)
            )
        } else {
            let startX = CGFloat.random(in: 50...(sceneSize.width - 50))
            let playAreaBottom: CGFloat = 120
            let playAreaTop = sceneSize.height - 120
            let gapStart = CGFloat.random(in: (playAreaBottom + 20)...(playAreaTop - 20 - gapSize))
            return Hazard(
                id: UUID(),
                position: CGPoint(x: startX, y: 0),
                kind: .sweep(velocity: 80 * direction, isHorizontal: false,
                             gapStart: gapStart, gapEnd: gapStart + gapSize)
            )
        }
    }

    // MARK: - Hazard Physics (private)

    /// Returns IDs of hazards removed this frame.
    private static func updateHazards(state: inout State, deltaTime: TimeInterval,
                                      sceneSize: CGSize) -> Set<UUID> {
        var removedIDs = Set<UUID>()

        for i in state.hazards.indices {
            switch state.hazards[i].kind {
            case .projectile(let velocity):
                state.hazards[i].position.x += velocity.x * CGFloat(deltaTime)
                state.hazards[i].position.y += velocity.y * CGFloat(deltaTime)

                let pos = state.hazards[i].position
                if pos.x < -50 || pos.x > sceneSize.width + 50 ||
                   pos.y < 50 || pos.y > sceneSize.height + 50 {
                    state.hazards[i].removed = true
                    removedIDs.insert(state.hazards[i].id)
                }

            case .expanding(var currentRadius, let maxRadius):
                currentRadius += 80 * CGFloat(deltaTime)
                if currentRadius >= maxRadius {
                    state.hazards[i].removed = true
                    removedIDs.insert(state.hazards[i].id)
                } else {
                    state.hazards[i].kind = .expanding(currentRadius: currentRadius, maxRadius: maxRadius)
                }

            case .sweep(let velocity, let isHorizontal, _, _):
                if isHorizontal {
                    state.hazards[i].position.y += velocity * CGFloat(deltaTime)
                    let y = state.hazards[i].position.y
                    if y < 100 || y > sceneSize.height - 100 {
                        state.hazards[i].removed = true
                        removedIDs.insert(state.hazards[i].id)
                    }
                } else {
                    state.hazards[i].position.x += velocity * CGFloat(deltaTime)
                    let x = state.hazards[i].position.x
                    if x < 20 || x > sceneSize.width - 20 {
                        state.hazards[i].removed = true
                        removedIDs.insert(state.hazards[i].id)
                    }
                }
            }
        }

        state.hazards.removeAll { $0.removed }
        return removedIDs
    }

    // MARK: - Collision Detection (private)

    /// Returns `true` if the player was hit this frame.
    private static func checkCollisions(state: inout State) -> Bool {
        guard state.invincibilityTimer <= 0 else { return false }

        let playerRadius: CGFloat = 15

        for hazard in state.hazards {
            switch hazard.kind {
            case .projectile:
                let hazardRadius: CGFloat = 15
                let dx = state.playerPosition.x - hazard.position.x
                let dy = state.playerPosition.y - hazard.position.y
                let distance = hypot(dx, dy)
                if distance < playerRadius + hazardRadius {
                    applyDamage(state: &state)
                    return true
                }

            case .expanding(let currentRadius, _):
                let dx = state.playerPosition.x - hazard.position.x
                let dy = state.playerPosition.y - hazard.position.y
                let distance = hypot(dx, dy)
                if distance < playerRadius + currentRadius {
                    applyDamage(state: &state)
                    return true
                }

            case .sweep(_, let isHorizontal, let gapStart, let gapEnd):
                if isHorizontal {
                    if abs(state.playerPosition.y - hazard.position.y) < playerRadius + 4 {
                        let inGap = state.playerPosition.x > gapStart && state.playerPosition.x < gapEnd
                        if !inGap {
                            applyDamage(state: &state)
                            return true
                        }
                    }
                } else {
                    if abs(state.playerPosition.x - hazard.position.x) < playerRadius + 4 {
                        let inGap = state.playerPosition.y > gapStart && state.playerPosition.y < gapEnd
                        if !inGap {
                            applyDamage(state: &state)
                            return true
                        }
                    }
                }
            }
        }

        return false
    }

    // MARK: - Damage (private)

    private static func applyDamage(state: inout State) {
        state.health -= 1
        state.invincibilityTimer = BalanceConfig.ManualOverride.invincibilityDuration
    }
}
