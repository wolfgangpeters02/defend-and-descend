import SpriteKit

// MARK: - Boss Systems (AI & Logic)
// Rendering delegated to BossRenderingManager (Step 4.1)

extension GameScene {

    // MARK: - Boss Initialization

    /// Initialize a boss encounter (called when entering boss mode)
    func initializeBoss(bossId: String) {
        // Determine boss type and create state
        let arenaCenter = CGPoint(
            x: gameState.arena.width / 2,
            y: gameState.arena.height / 2
        )

        let arenaRect = CGRect(x: 0, y: 0, width: gameState.arena.width, height: gameState.arena.height)

        if bossId.contains("cyberboss") || bossId.contains("server") {
            gameState.activeBossType = .cyberboss
            gameState.cyberbossState = CyberbossAI.createInitialState()
        } else if bossId.contains("void") || bossId.contains("harbinger") {
            gameState.activeBossType = .voidHarbinger
            gameState.voidHarbingerState = VoidHarbingerAI.createInitialState(arenaCenter: arenaCenter)
        } else if bossId.contains("overclocker") || bossId.contains("thermal") {
            gameState.activeBossType = .overclocker
            gameState.overclockerState = OverclockerAI.createInitialState(arenaCenter: arenaCenter, arenaRect: arenaRect)
        } else if bossId.contains("trojan") || bossId.contains("wyrm") || bossId.contains("packet") {
            gameState.activeBossType = .trojanWyrm
            gameState.trojanWyrmState = TrojanWyrmAI.createInitialState(arenaCenter: arenaCenter, arenaRect: arenaRect)
        }

        gameState.activeBossId = bossId

        // Spawn the boss enemy
        let config = GameConfigLoader.shared

        // Get boss config from JSON or use fallback
        let bossConfig = config.getEnemy(bossId) ?? EnemyConfig(
            id: bossId,
            name: "Boss",
            health: 5000,
            speed: 80,
            damage: 50,
            hashValue: 100,
            size: 60,
            color: "#ff0000",
            shape: "hexagon",
            isBoss: true
        )

        // Apply difficulty scaling
        var scaledConfig = bossConfig
        if let difficulty = gameState.bossDifficulty {
            scaledConfig.health *= Double(difficulty.healthMultiplier)
            scaledConfig.damage *= Double(difficulty.damageMultiplier)
        }

        let spawnOptions = SpawnOptions(
            x: gameState.arena.width / 2,
            y: gameState.arena.height / 4,  // Boss spawns in top quarter
            inactive: false,
            activationRadius: nil
        )

        let bossEnemy = EnemySystem.spawnEnemy(
            state: &gameState,
            type: bossId,
            config: scaledConfig,
            spawnOptions: spawnOptions
        )

        gameState.enemies.append(bossEnemy)
    }

    // MARK: - Boss AI Update

    func updateBossAI(context: FrameContext) {
        guard let bossType = gameState.activeBossType else { return }

        // Find the boss enemy
        guard let bossIndex = gameState.enemies.firstIndex(where: { $0.isBoss && !$0.isDead }) else {
            // Boss is dead - trigger victory with death effects!
            if !gameState.isGameOver {
                // Trigger boss death explosion before setting game over
                if let deadBoss = gameState.enemies.first(where: { $0.isBoss }) {
                    triggerBossDeathEffects(
                        boss: deadBoss,
                        bossType: bossType
                    )
                }

                gameState.isGameOver = true
                gameState.victory = true
            }

            // Clear boss state
            gameState.activeBossType = nil
            gameState.activeBossId = nil
            gameState.cyberbossState = nil
            gameState.voidHarbingerState = nil
            gameState.overclockerState = nil
            gameState.trojanWyrmState = nil
            return
        }

        switch bossType {
        case .cyberboss:
            if var bossState = gameState.cyberbossState {
                var boss = gameState.enemies[bossIndex]
                CyberbossAI.update(
                    boss: &boss,
                    bossState: &bossState,
                    gameState: &gameState,
                    deltaTime: context.deltaTime
                )
                gameState.enemies[bossIndex] = boss
                gameState.cyberbossState = bossState
            }

        case .voidHarbinger:
            if var bossState = gameState.voidHarbingerState {
                var boss = gameState.enemies[bossIndex]
                VoidHarbingerAI.update(
                    boss: &boss,
                    bossState: &bossState,
                    gameState: &gameState,
                    deltaTime: context.deltaTime
                )
                gameState.enemies[bossIndex] = boss
                gameState.voidHarbingerState = bossState
            }

        case .overclocker:
            if var bossState = gameState.overclockerState {
                var boss = gameState.enemies[bossIndex]
                OverclockerAI.update(
                    boss: &boss,
                    bossState: &bossState,
                    gameState: &gameState,
                    deltaTime: context.deltaTime
                )

                // Apply wind/vacuum forces to player
                let bossPos = CGPoint(x: boss.x, y: boss.y)
                let playerPos = CGPoint(x: gameState.player.x, y: gameState.player.y)
                let wind = OverclockerAI.calculateWindForce(playerPos: playerPos, bossPos: bossPos, state: bossState)
                let vacuum = OverclockerAI.calculateVacuumForce(playerPos: playerPos, bossPos: bossPos, state: bossState)

                gameState.player.x += (wind.dx + vacuum.dx) * CGFloat(context.deltaTime)
                gameState.player.y += (wind.dy + vacuum.dy) * CGFloat(context.deltaTime)

                // Clamp player to arena
                let padding: CGFloat = 30
                gameState.player.x = max(padding, min(gameState.arena.width - padding, gameState.player.x))
                gameState.player.y = max(padding, min(gameState.arena.height - padding, gameState.player.y))

                // Check mechanics damage
                let arenaRect = CGRect(x: 0, y: 0, width: gameState.arena.width, height: gameState.arena.height)
                let mechanicsDamage = OverclockerAI.checkMechanicsDamage(
                    playerPos: CGPoint(x: gameState.player.x, y: gameState.player.y),
                    state: bossState,
                    bossPos: bossPos,
                    arenaRect: arenaRect,
                    deltaTime: context.deltaTime
                )
                if mechanicsDamage > 0 {
                    gameState.player.health -= mechanicsDamage
                }

                gameState.enemies[bossIndex] = boss
                gameState.overclockerState = bossState
            }

        case .trojanWyrm:
            if var bossState = gameState.trojanWyrmState {
                var boss = gameState.enemies[bossIndex]
                TrojanWyrmAI.update(
                    boss: &boss,
                    bossState: &bossState,
                    gameState: &gameState,
                    deltaTime: context.deltaTime
                )

                // Custom body segment collision (runs AFTER ProjectileSystem)
                TrojanWyrmAI.checkBodySegmentCollisions(
                    bossState: &bossState,
                    gameState: &gameState,
                    boss: &boss
                )

                gameState.enemies[bossIndex] = boss
                gameState.trojanWyrmState = bossState
            }
        }
    }

    // MARK: - Boss Death Effects

    private func triggerBossDeathEffects(boss: Enemy, bossType: BossType) {
        // Boss-specific theme colors
        let colorHex: String
        let flashColor: SKColor
        switch bossType {
        case .cyberboss:     colorHex = "#00ffff"; flashColor = SKColor.cyan
        case .voidHarbinger: colorHex = "#ff00ff"; flashColor = SKColor.magenta
        case .overclocker:   colorHex = "#ff6600"; flashColor = SKColor.orange
        case .trojanWyrm:    colorHex = "#00ff41"; flashColor = SKColor.green
        }

        // 1. Particle explosion at boss position (16 particles in boss color)
        ParticleFactory.createExplosion(
            state: &gameState,
            x: boss.x,
            y: boss.y,
            color: colorHex,
            count: 16,
            size: 8
        )

        // 2. Screen flash in boss theme color
        flashScreen(color: flashColor, intensity: 0.25, duration: 0.3)

        // 3. Screen shake
        shakeScreen(intensity: 8, duration: 0.35)

        // 4. Scale-up boss node before it's cleaned up
        let bossScenePos = CGPoint(x: boss.x, y: gameState.arena.height - boss.y)
        if let bossNode = enemyLayer.children.first(where: {
            abs($0.position.x - bossScenePos.x) < 5 && abs($0.position.y - bossScenePos.y) < 5
        }) {
            let scaleUp = SKAction.scale(to: 1.3, duration: 0.15)
            scaleUp.timingMode = .easeOut
            let fadeOut = SKAction.fadeOut(withDuration: 0.2)
            bossNode.run(SKAction.group([scaleUp, fadeOut]))
        }
    }

    // MARK: - Boss Mechanics Rendering (delegated)

    func updateBossMechanics(context: FrameContext) {
        // NOTE: All damage is handled by the boss AI (CyberbossAI/VoidHarbingerAI)
        // Rendering delegated to BossRenderingManager (Step 4.1)
        bossRenderingManager.renderFrame(gameState: gameState)
    }
}
