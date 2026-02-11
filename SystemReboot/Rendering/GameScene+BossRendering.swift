import SpriteKit

// MARK: - Boss Systems & Rendering

extension GameScene {

    // MARK: - Boss Systems

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
            coinValue: 100,
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

    func updateBossAI(context: FrameContext) {
        guard let bossType = gameState.activeBossType else { return }

        // Find the boss enemy
        guard let bossIndex = gameState.enemies.firstIndex(where: { $0.isBoss && !$0.isDead }) else {
            // Boss is dead - trigger victory!
            if !gameState.isGameOver {
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
                // Extract boss to avoid overlapping inout access
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
                // Extract boss to avoid overlapping inout access
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

    func updateBossMechanics(context: FrameContext) {
        // NOTE: All damage is handled by the boss AI (CyberbossAI/VoidHarbingerAI)
        // This function now only handles rendering of boss mechanics
        renderBossMechanics()
    }

    // MARK: - Boss Mechanics Rendering

    /// Efficiently find boss mechanic keys to remove (avoids per-key string allocation)
    /// Uses dropFirst instead of replacingOccurrences for better performance
    func findKeysToRemove(prefix: String, activeIds: Set<String>) -> [String] {
        let prefixCount = prefix.count
        var keysToRemove: [String] = []
        keysToRemove.reserveCapacity(bossMechanicNodes.count / 4)  // Preallocate estimate

        for key in bossMechanicNodes.keys {
            guard key.hasPrefix(prefix) else { continue }
            let id = String(key.dropFirst(prefixCount))
            if !activeIds.contains(id) {
                keysToRemove.append(key)
            }
        }
        return keysToRemove
    }

    func renderBossMechanics() {
        // Render Cyberboss mechanics
        if let bossState = gameState.cyberbossState {
            renderCyberbossMechanics(bossState: bossState)
        } else {
            // Clean up cyberboss nodes if not in cyberboss fight
            cleanupBossNodes(prefix: "cyberboss_")
        }

        // Render Void Harbinger mechanics
        if let bossState = gameState.voidHarbingerState {
            renderVoidHarbingerMechanics(bossState: bossState)
        } else {
            // Clean up void harbinger nodes if not in void harbinger fight
            cleanupBossNodes(prefix: "voidharbinger_")
        }

        // Render Overclocker mechanics
        if let bossState = gameState.overclockerState {
            renderOverclockerMechanics(bossState: bossState)
        } else {
            cleanupBossNodes(prefix: "overclocker_")
        }

        // Render Trojan Wyrm mechanics
        if let bossState = gameState.trojanWyrmState {
            renderTrojanWyrmMechanics(bossState: bossState)
        } else {
            cleanupBossNodes(prefix: "trojanwyrm_")
        }
    }

    func cleanupBossNodes(prefix: String) {
        let keysToRemove = bossMechanicNodes.keys.filter { $0.hasPrefix(prefix) }
        for key in keysToRemove {
            if let node = bossMechanicNodes[key] {
                // Determine pool type from key prefix
                let poolType: String
                if key.contains("puddle") { poolType = "boss_puddle" }
                else if key.contains("laser") { poolType = "boss_laser" }
                else if key.contains("zone") { poolType = "boss_zone" }
                else if key.contains("pylon") { poolType = "boss_pylon" }
                else if key.contains("rift") { poolType = "boss_rift" }
                else if key.contains("well") { poolType = "boss_well" }
                else { poolType = "boss_misc" }
                nodePool.release(node, type: poolType)
            }
            bossMechanicNodes.removeValue(forKey: key)
        }
    }

    // MARK: - Cyberboss Rendering

    func renderCyberbossMechanics(bossState: CyberbossAI.CyberbossState) {
        guard let boss = gameState.enemies.first(where: { $0.isBoss && !$0.isDead }) else { return }

        // Render chainsaw effect for melee mode (Phase 1-2)
        renderChainsawEffect(bossState: bossState, boss: boss)

        // Render damage puddles (with state caching to avoid redundant color updates)
        var activePuddleIds = Set<String>()
        for puddle in bossState.damagePuddles {
            activePuddleIds.insert(puddle.id)
            let nodeKey = "cyberboss_puddle_\(puddle.id)"

            let isWarningPhase = puddle.lifetime < puddle.warningDuration
            let isAboutToPop = puddle.lifetime > puddle.maxLifetime - 0.5

            // Determine current phase for caching
            let currentPhase: String
            if isWarningPhase { currentPhase = "warning" }
            else if isAboutToPop { currentPhase = "pop" }
            else { currentPhase = "active" }

            if let node = bossMechanicNodes[nodeKey] as? SKShapeNode {
                // Only update colors if phase changed (avoids redundant fillColor/strokeColor sets)
                let cachedPhase = puddlePhaseCache[puddle.id]
                if cachedPhase != currentPhase {
                    puddlePhaseCache[puddle.id] = currentPhase

                    if isWarningPhase {
                        // Warning phase - amber outline, subtle pulse
                        node.fillColor = DesignColors.warningUI.withAlphaComponent(0.1)
                        node.strokeColor = DesignColors.warningUI
                        node.lineWidth = 3
                        node.glowWidth = 0  // Removed for performance
                    } else if isAboutToPop {
                        // About to pop - danger red, high intensity
                        node.fillColor = DesignColors.dangerUI.withAlphaComponent(0.5)
                        node.strokeColor = DesignColors.dangerUI
                        node.lineWidth = 5  // Thicker line instead of glow
                        node.glowWidth = 0  // Removed for performance
                    } else {
                        // Active phase - danger fill at lower intensity
                        node.fillColor = DesignColors.dangerUI.withAlphaComponent(0.25)
                        node.strokeColor = DesignColors.dangerUI.withAlphaComponent(0.8)
                        node.lineWidth = 3
                        node.glowWidth = 0  // Removed for performance
                    }
                }
            } else {
                // Create new puddle node (starts in warning phase)
                let puddleNode = SKShapeNode(circleOfRadius: puddle.radius)
                puddleNode.fillColor = DesignColors.warningUI.withAlphaComponent(0.1)
                puddleNode.strokeColor = DesignColors.warningUI
                puddleNode.lineWidth = 3
                puddleNode.glowWidth = 0  // Removed for performance
                // Convert to scene coordinates (flip Y)
                puddleNode.position = CGPoint(x: puddle.x, y: gameState.arena.height - puddle.y)
                puddleNode.zPosition = 5
                puddleNode.name = nodeKey

                // Add pulsing effect (use cached action)
                puddleNode.run(SKAction.repeatForever(puddlePulseAction), withKey: "pulse")

                addChild(puddleNode)
                bossMechanicNodes[nodeKey] = puddleNode
            }
        }

        // Remove puddles that no longer exist (release to pool for reuse)
        let puddlePrefix = "cyberboss_puddle_"
        for key in findKeysToRemove(prefix: puddlePrefix, activeIds: activePuddleIds) {
            if let node = bossMechanicNodes[key] {
                nodePool.release(node, type: "boss_puddle")
            }
            // Clear phase cache for removed puddle
            let puddleId = String(key.dropFirst(puddlePrefix.count))
            puddlePhaseCache.removeValue(forKey: puddleId)
            bossMechanicNodes.removeValue(forKey: key)
        }

        // Render laser beams (optimized: use rotation instead of path rebuild)
        var activeLaserIds = Set<String>()
        for beam in bossState.laserBeams {
            activeLaserIds.insert(beam.id)
            let nodeKey = "cyberboss_laser_\(beam.id)"

            // Convert to scene coordinates (flip Y)
            let bossSceneX = boss.x
            let bossSceneY = gameState.arena.height - boss.y

            // Determine color based on warning vs active state
            let laserColor: SKColor = beam.isActive ? DesignColors.dangerUI : SKColor.yellow
            let laserWidth: CGFloat = beam.isActive ? 8 : 4  // Thicker line instead of glow

            if let node = bossMechanicNodes[nodeKey] as? SKShapeNode {
                // Update existing laser: position, rotation, and color
                node.position = CGPoint(x: bossSceneX, y: bossSceneY)
                node.zRotation = beam.angle * .pi / 180
                node.strokeColor = laserColor
                node.lineWidth = laserWidth
            } else {
                // Create new laser beam node with horizontal path (rotated via zRotation)
                let path = CGMutablePath()
                path.move(to: CGPoint.zero)
                path.addLine(to: CGPoint(x: beam.length, y: 0))

                let laserNode = SKShapeNode(path: path)
                laserNode.strokeColor = laserColor
                laserNode.lineWidth = laserWidth
                laserNode.glowWidth = 0  // Removed for performance
                laserNode.zPosition = 100
                laserNode.name = nodeKey
                laserNode.position = CGPoint(x: bossSceneX, y: bossSceneY)
                laserNode.zRotation = beam.angle * .pi / 180

                // Add subtle flicker effect (use cached action)
                laserNode.run(SKAction.repeatForever(laserFlickerAction), withKey: "flicker")

                addChild(laserNode)
                bossMechanicNodes[nodeKey] = laserNode
            }
        }

        // Remove lasers that no longer exist (release to pool for reuse)
        for key in findKeysToRemove(prefix: "cyberboss_laser_", activeIds: activeLaserIds) {
            if let node = bossMechanicNodes[key] {
                nodePool.release(node, type: "boss_laser")
            }
            bossMechanicNodes.removeValue(forKey: key)
        }

        // Show phase indicator
        renderPhaseIndicator(phase: bossState.phase, bossType: "cyberboss")
    }

    // MARK: - Chainsaw Effect

    func renderChainsawEffect(bossState: CyberbossAI.CyberbossState, boss: Enemy) {
        let nodeKey = "cyberboss_chainsaw"

        // Only show chainsaw in melee mode (Phase 1-2)
        let showChainsaw = bossState.mode == .melee && bossState.phase <= 2

        if showChainsaw {
            let bossSceneY = gameState.arena.height - boss.y
            let bossSize = boss.size ?? 60

            if let existingNode = bossMechanicNodes[nodeKey] {
                // Update position
                existingNode.position = CGPoint(x: boss.x, y: bossSceneY)
            } else {
                // Create chainsaw visual - rotating saw teeth around boss
                let chainsawNode = SKNode()
                chainsawNode.name = nodeKey
                chainsawNode.position = CGPoint(x: boss.x, y: bossSceneY)
                chainsawNode.zPosition = 49 // Just below enemies

                // Create inner danger circle (subtle, design system colors)
                let dangerCircle = SKShapeNode(circleOfRadius: bossSize + 10)
                dangerCircle.fillColor = DesignColors.dangerUI.withAlphaComponent(0.15)
                dangerCircle.strokeColor = DesignColors.dangerUI.withAlphaComponent(0.6)
                dangerCircle.lineWidth = 2
                dangerCircle.glowWidth = 4
                dangerCircle.name = "dangerCircle"
                chainsawNode.addChild(dangerCircle)

                // Create saw teeth around the boss (smaller, less garish)
                let teethCount = 8
                let teethRadius = bossSize + 20
                for i in 0..<teethCount {
                    let angle = CGFloat(i) * (2 * .pi / CGFloat(teethCount))
                    let toothX = cos(angle) * teethRadius
                    let toothY = sin(angle) * teethRadius

                    // Create triangular saw tooth
                    let toothPath = CGMutablePath()
                    let toothSize: CGFloat = 12
                    toothPath.move(to: CGPoint(x: 0, y: toothSize / 2))
                    toothPath.addLine(to: CGPoint(x: toothSize, y: 0))
                    toothPath.addLine(to: CGPoint(x: 0, y: -toothSize / 2))
                    toothPath.closeSubpath()

                    let toothNode = SKShapeNode(path: toothPath)
                    toothNode.fillColor = DesignColors.dangerUI.withAlphaComponent(0.8)
                    toothNode.strokeColor = DesignColors.dangerUI
                    toothNode.lineWidth = 1
                    toothNode.glowWidth = 2
                    toothNode.position = CGPoint(x: toothX, y: toothY)
                    toothNode.zRotation = angle // Point outward
                    chainsawNode.addChild(toothNode)
                }

                // Add outer warning ring (using warning color)
                let outerRing = SKShapeNode(circleOfRadius: bossSize + 28)
                outerRing.fillColor = .clear
                outerRing.strokeColor = DesignColors.warningUI.withAlphaComponent(0.4)
                outerRing.lineWidth = 1.5
                outerRing.name = "outerRing"
                chainsawNode.addChild(outerRing)

                // Rotation animation - fast spinning saw (use cached action)
                chainsawNode.run(SKAction.repeatForever(chainsawRotateAction), withKey: "rotate")

                // Pulsing danger circle (use cached action)
                dangerCircle.run(SKAction.repeatForever(chainsawDangerPulseAction), withKey: "pulse")

                addChild(chainsawNode)
                bossMechanicNodes[nodeKey] = chainsawNode
            }
        } else {
            // Remove chainsaw when not in melee mode
            if let node = bossMechanicNodes[nodeKey] {
                // Fade out then remove
                node.run(SKAction.sequence([
                    SKAction.fadeOut(withDuration: 0.3),
                    SKAction.removeFromParent()
                ]))
                bossMechanicNodes.removeValue(forKey: nodeKey)
            }
        }
    }

    // MARK: - Void Harbinger Rendering

    func renderVoidHarbingerMechanics(bossState: VoidHarbingerAI.VoidHarbingerState) {
        // Render void zones (with state caching to avoid redundant color updates)
        var activeZoneIds = Set<String>()
        for zone in bossState.voidZones {
            activeZoneIds.insert(zone.id)
            let nodeKey = "voidharbinger_zone_\(zone.id)"

            if let node = bossMechanicNodes[nodeKey] as? SKShapeNode {
                // Only update colors if active state changed
                let cachedIsActive = zonePhaseCache[zone.id]
                if cachedIsActive != zone.isActive {
                    zonePhaseCache[zone.id] = zone.isActive

                    if zone.isActive {
                        node.fillColor = DesignColors.secondaryUI.withAlphaComponent(0.3)
                        node.strokeColor = DesignColors.secondaryUI.withAlphaComponent(0.8)
                        node.removeAction(forKey: "pulse")  // Stop warning pulse when active
                    } else {
                        // Warning phase - pulsing outline
                        node.fillColor = DesignColors.warningUI.withAlphaComponent(0.1)
                        node.strokeColor = DesignColors.warningUI
                    }
                }
            } else {
                // Create new void zone node
                let zoneNode = SKShapeNode(circleOfRadius: zone.radius)
                // Convert to scene coordinates (flip Y)
                zoneNode.position = CGPoint(x: zone.x, y: gameState.arena.height - zone.y)
                zoneNode.zPosition = 5
                zoneNode.lineWidth = 2
                zoneNode.name = nodeKey

                if zone.isActive {
                    zoneNode.fillColor = DesignColors.secondaryUI.withAlphaComponent(0.3)
                    zoneNode.strokeColor = DesignColors.secondaryUI.withAlphaComponent(0.8)
                    zoneNode.glowWidth = 4
                } else {
                    // Warning phase
                    zoneNode.fillColor = DesignColors.warningUI.withAlphaComponent(0.1)
                    zoneNode.strokeColor = DesignColors.warningUI
                    // Use cached action for pulse
                    zoneNode.run(SKAction.repeatForever(voidZonePulseAction), withKey: "pulse")
                }

                addChild(zoneNode)
                bossMechanicNodes[nodeKey] = zoneNode
            }
        }

        // Remove zones that no longer exist (release to pool for reuse)
        let zonePrefix = "voidharbinger_zone_"
        for key in findKeysToRemove(prefix: zonePrefix, activeIds: activeZoneIds) {
            if let node = bossMechanicNodes[key] {
                nodePool.release(node, type: "boss_zone")
            }
            // Clear phase cache for removed zone
            let zoneId = String(key.dropFirst(zonePrefix.count))
            zonePhaseCache.removeValue(forKey: zoneId)
            bossMechanicNodes.removeValue(forKey: key)
        }

        // Render pylons (Phase 2)
        var activePylonIds = Set<String>()
        for pylon in bossState.pylons where !pylon.isDestroyed {
            activePylonIds.insert(pylon.id)
            let nodeKey = "voidharbinger_pylon_\(pylon.id)"

            if let container = bossMechanicNodes[nodeKey] {
                // Update health bar
                if let healthBar = container.childNode(withName: "healthFill") as? SKShapeNode {
                    let healthPercent = pylon.health / pylon.maxHealth
                    healthBar.xScale = max(0.01, healthPercent)
                }
            } else {
                // Create new pylon node
                let container = SKNode()
                // Convert to scene coordinates (flip Y)
                container.position = CGPoint(x: pylon.x, y: gameState.arena.height - pylon.y)
                container.zPosition = 50
                container.name = nodeKey

                // Pylon body (using design system colors)
                let pylonBody = SKShapeNode(rectOf: CGSize(width: 40, height: 60), cornerRadius: 5)
                pylonBody.fillColor = DesignColors.secondaryUI.withAlphaComponent(0.8)
                pylonBody.strokeColor = DesignColors.secondaryUI
                pylonBody.lineWidth = 2
                pylonBody.glowWidth = 3
                container.addChild(pylonBody)

                // Crystal on top
                let crystal = SKShapeNode(circleOfRadius: 12)
                crystal.fillColor = DesignColors.secondaryUI
                crystal.strokeColor = DesignColors.primaryUI.withAlphaComponent(0.6)
                crystal.position = CGPoint(x: 0, y: 40)
                crystal.glowWidth = 6
                container.addChild(crystal)

                // Health bar background
                let healthBg = SKShapeNode(rectOf: CGSize(width: 50, height: 6))
                healthBg.fillColor = DesignColors.surfaceUI
                healthBg.strokeColor = DesignColors.mutedUI
                healthBg.position = CGPoint(x: 0, y: -45)
                container.addChild(healthBg)

                // Health bar fill
                let healthFill = SKShapeNode(rect: CGRect(x: -25, y: -3, width: 50, height: 6))
                healthFill.fillColor = DesignColors.successUI
                healthFill.strokeColor = SKColor.clear
                healthFill.position = CGPoint(x: 0, y: -45)
                healthFill.name = "healthFill"
                container.addChild(healthFill)

                // Pulsing effect on crystal (use cached action)
                crystal.run(SKAction.repeatForever(pylonCrystalPulseAction), withKey: "pulse")

                addChild(container)
                bossMechanicNodes[nodeKey] = container
            }
        }

        // Remove destroyed pylons (release to pool for reuse)
        for key in findKeysToRemove(prefix: "voidharbinger_pylon_", activeIds: activePylonIds) {
            if let node = bossMechanicNodes[key] {
                nodePool.release(node, type: "boss_pylon")
            }
            bossMechanicNodes.removeValue(forKey: key)
        }

        // Render shield around boss during Phase 2 (pylons provide shield)
        let shieldKey = "voidharbinger_shield"
        // Find boss position from enemies array
        let bossEnemy = gameState.enemies.first { $0.isBoss && !$0.isDead }
        if bossState.phase == 2 && bossState.isInvulnerable, let boss = bossEnemy {
            let bossScenePos = CGPoint(x: boss.x, y: gameState.arena.height - boss.y)

            if let shieldNode = bossMechanicNodes[shieldKey] as? SKShapeNode {
                shieldNode.position = bossScenePos
            } else {
                // Create hexagonal shield effect
                let shieldRadius: CGFloat = 80
                let hexPath = CGMutablePath()
                for i in 0..<6 {
                    let angle = CGFloat(i) * .pi / 3 - .pi / 6
                    let point = CGPoint(
                        x: cos(angle) * shieldRadius,
                        y: sin(angle) * shieldRadius
                    )
                    if i == 0 {
                        hexPath.move(to: point)
                    } else {
                        hexPath.addLine(to: point)
                    }
                }
                hexPath.closeSubpath()

                let shieldNode = SKShapeNode(path: hexPath)
                shieldNode.fillColor = DesignColors.secondaryUI.withAlphaComponent(0.15)
                shieldNode.strokeColor = DesignColors.secondaryUI.withAlphaComponent(0.8)
                shieldNode.lineWidth = 3
                shieldNode.glowWidth = 8
                shieldNode.position = bossScenePos
                shieldNode.zPosition = 45
                shieldNode.name = shieldKey

                // Pulsing shield animation
                let shieldPulse = SKAction.sequence([
                    SKAction.group([
                        SKAction.scale(to: 1.08, duration: 0.8),
                        SKAction.fadeAlpha(to: 0.7, duration: 0.8)
                    ]),
                    SKAction.group([
                        SKAction.scale(to: 1.0, duration: 0.8),
                        SKAction.fadeAlpha(to: 1.0, duration: 0.8)
                    ])
                ])
                shieldNode.run(SKAction.repeatForever(shieldPulse), withKey: "pulse")

                // Slow rotation
                let rotation = SKAction.rotate(byAngle: .pi * 2, duration: 12)
                shieldNode.run(SKAction.repeatForever(rotation), withKey: "rotate")

                addChild(shieldNode)
                bossMechanicNodes[shieldKey] = shieldNode
            }
        } else {
            // Remove shield when not in Phase 2 or not invulnerable
            if let shield = bossMechanicNodes[shieldKey] {
                shield.removeFromParent()
                bossMechanicNodes.removeValue(forKey: shieldKey)
            }
        }

        // Render energy lines from pylons to boss (Phase 2)
        var activeLineIds = Set<String>()
        if bossState.phase == 2, let boss = bossEnemy {
            let bossScenePos = CGPoint(x: boss.x, y: gameState.arena.height - boss.y)

            for pylon in bossState.pylons where !pylon.isDestroyed {
                activeLineIds.insert(pylon.id)
                let lineKey = "voidharbinger_pylonline_\(pylon.id)"
                let pylonScenePos = CGPoint(x: pylon.x, y: gameState.arena.height - pylon.y)

                if let lineNode = bossMechanicNodes[lineKey] as? SKShapeNode {
                    // Update line path to follow boss position
                    let linePath = CGMutablePath()
                    linePath.move(to: pylonScenePos)
                    linePath.addLine(to: bossScenePos)
                    lineNode.path = linePath
                } else {
                    // Create energy line from pylon to boss
                    let linePath = CGMutablePath()
                    linePath.move(to: pylonScenePos)
                    linePath.addLine(to: bossScenePos)

                    let lineNode = SKShapeNode(path: linePath)
                    lineNode.strokeColor = DesignColors.secondaryUI.withAlphaComponent(0.6)
                    lineNode.lineWidth = 2
                    lineNode.glowWidth = 4
                    lineNode.zPosition = 40
                    lineNode.name = lineKey

                    // Pulsing line animation (energy flow effect)
                    let linePulse = SKAction.sequence([
                        SKAction.fadeAlpha(to: 0.4, duration: 0.3),
                        SKAction.fadeAlpha(to: 1.0, duration: 0.3)
                    ])
                    lineNode.run(SKAction.repeatForever(linePulse), withKey: "pulse")

                    addChild(lineNode)
                    bossMechanicNodes[lineKey] = lineNode
                }
            }
        }

        // Remove lines for destroyed pylons or when not in Phase 2
        for key in findKeysToRemove(prefix: "voidharbinger_pylonline_", activeIds: activeLineIds) {
            if let node = bossMechanicNodes[key] {
                node.removeFromParent()
            }
            bossMechanicNodes.removeValue(forKey: key)
        }

        // Render pylon direction indicators (Phase 2 only) - help player find pylons
        if bossState.phase == 2 && !bossState.pylons.filter({ !$0.isDestroyed }).isEmpty {
            // Show hint text
            let hintKey = "voidharbinger_pylon_hint"
            if bossMechanicNodes[hintKey] == nil {
                let hintLabel = SKLabelNode(text: L10n.Boss.destroyPylons)
                hintLabel.fontName = "Menlo-Bold"
                hintLabel.fontSize = 20
                hintLabel.fontColor = DesignColors.warningUI
                hintLabel.position = CGPoint(x: gameState.arena.width / 2, y: gameState.arena.height - 90)
                hintLabel.zPosition = 200
                hintLabel.name = hintKey

                // Pulsing animation
                let pulse = SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.5, duration: 0.5),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.5)
                ])
                hintLabel.run(SKAction.repeatForever(pulse), withKey: "pulse")

                addChild(hintLabel)
                bossMechanicNodes[hintKey] = hintLabel
            }

            // Show arrow indicators pointing to each pylon
            let playerScenePos = CGPoint(x: gameState.player.x, y: gameState.arena.height - gameState.player.y)

            for pylon in bossState.pylons where !pylon.isDestroyed {
                let arrowKey = "voidharbinger_pylon_arrow_\(pylon.id)"
                let pylonScenePos = CGPoint(x: pylon.x, y: gameState.arena.height - pylon.y)

                // Calculate direction from player to pylon
                let dx = pylonScenePos.x - playerScenePos.x
                let dy = pylonScenePos.y - playerScenePos.y
                let distance = sqrt(dx * dx + dy * dy)

                // Only show arrow if pylon is far from player (off-screen or distant)
                if distance > 200 {
                    let angle = atan2(dy, dx)

                    // Position arrow at edge of view near player, pointing toward pylon
                    let arrowDistance: CGFloat = 120
                    let arrowX = playerScenePos.x + cos(angle) * arrowDistance
                    let arrowY = playerScenePos.y + sin(angle) * arrowDistance

                    // Clamp to screen bounds
                    let clampedX = max(50, min(gameState.arena.width - 50, arrowX))
                    let clampedY = max(50, min(gameState.arena.height - 50, arrowY))

                    if let arrow = bossMechanicNodes[arrowKey] as? SKShapeNode {
                        arrow.position = CGPoint(x: clampedX, y: clampedY)
                        arrow.zRotation = angle
                    } else {
                        // Create arrow pointing right (will be rotated)
                        let arrowPath = CGMutablePath()
                        arrowPath.move(to: CGPoint(x: -15, y: -8))
                        arrowPath.addLine(to: CGPoint(x: 15, y: 0))
                        arrowPath.addLine(to: CGPoint(x: -15, y: 8))
                        arrowPath.addLine(to: CGPoint(x: -10, y: 0))
                        arrowPath.closeSubpath()

                        let arrowNode = SKShapeNode(path: arrowPath)
                        arrowNode.fillColor = DesignColors.warningUI
                        arrowNode.strokeColor = DesignColors.warningUI.withAlphaComponent(0.8)
                        arrowNode.lineWidth = 2
                        arrowNode.glowWidth = 4
                        arrowNode.position = CGPoint(x: clampedX, y: clampedY)
                        arrowNode.zRotation = angle
                        arrowNode.zPosition = 150
                        arrowNode.name = arrowKey

                        // Pulsing animation
                        let arrowPulse = SKAction.sequence([
                            SKAction.scale(to: 1.2, duration: 0.3),
                            SKAction.scale(to: 1.0, duration: 0.3)
                        ])
                        arrowNode.run(SKAction.repeatForever(arrowPulse), withKey: "pulse")

                        addChild(arrowNode)
                        bossMechanicNodes[arrowKey] = arrowNode
                    }
                } else {
                    // Remove arrow if pylon is close
                    if let arrow = bossMechanicNodes[arrowKey] {
                        arrow.removeFromParent()
                        bossMechanicNodes.removeValue(forKey: arrowKey)
                    }
                }
            }
        } else {
            // Remove pylon indicators when not in Phase 2
            let hintKey = "voidharbinger_pylon_hint"
            if let hint = bossMechanicNodes[hintKey] {
                hint.removeFromParent()
                bossMechanicNodes.removeValue(forKey: hintKey)
            }

            // Remove all pylon arrows
            let arrowPrefix = "voidharbinger_pylon_arrow_"
            for key in bossMechanicNodes.keys where key.hasPrefix(arrowPrefix) {
                if let arrow = bossMechanicNodes[key] {
                    arrow.removeFromParent()
                }
                bossMechanicNodes.removeValue(forKey: key)
            }
        }

        // Render void rifts (Phase 3+) - optimized: use rotation instead of path rebuild
        var activeRiftIds = Set<String>()
        for rift in bossState.voidRifts {
            activeRiftIds.insert(rift.id)
            let nodeKey = "voidharbinger_rift_\(rift.id)"

            // Convert to scene coordinates (flip Y)
            let centerSceneX = bossState.arenaCenter.x
            let centerSceneY = gameState.arena.height - bossState.arenaCenter.y

            if let node = bossMechanicNodes[nodeKey] as? SKShapeNode {
                // Update rift: just change rotation (no path rebuild)
                node.position = CGPoint(x: centerSceneX, y: centerSceneY)
                node.zRotation = rift.angle * .pi / 180
            } else {
                // Create new rift node with horizontal path (rotated via zRotation)
                let riftLength = BalanceConfig.VoidHarbinger.voidRiftLength
                let path = CGMutablePath()
                path.move(to: CGPoint.zero)
                path.addLine(to: CGPoint(x: riftLength, y: 0))

                let riftNode = SKShapeNode(path: path)
                riftNode.strokeColor = DesignColors.secondaryUI
                riftNode.lineWidth = rift.width
                riftNode.glowWidth = 6  // Reduced from 15 for performance
                riftNode.alpha = 0.8
                riftNode.zPosition = 10
                riftNode.name = nodeKey
                riftNode.position = CGPoint(x: centerSceneX, y: centerSceneY)
                riftNode.zRotation = rift.angle * .pi / 180

                addChild(riftNode)
                bossMechanicNodes[nodeKey] = riftNode
            }
        }

        // Remove rifts that no longer exist (release to pool for reuse)
        for key in findKeysToRemove(prefix: "voidharbinger_rift_", activeIds: activeRiftIds) {
            if let node = bossMechanicNodes[key] {
                nodePool.release(node, type: "boss_rift")
            }
            bossMechanicNodes.removeValue(forKey: key)
        }

        // Render gravity wells (Phase 3+)
        var activeWellIds = Set<String>()
        for well in bossState.gravityWells {
            activeWellIds.insert(well.id)
            let nodeKey = "voidharbinger_well_\(well.id)"

            if bossMechanicNodes[nodeKey] == nil {
                // Create gravity well visual
                let wellNode = SKShapeNode(circleOfRadius: well.pullRadius)
                wellNode.fillColor = SKColor.black.withAlphaComponent(0.25)
                wellNode.strokeColor = DesignColors.secondaryUI.withAlphaComponent(0.7)
                wellNode.lineWidth = 2
                // Convert to scene coordinates (flip Y)
                wellNode.position = CGPoint(x: well.x, y: gameState.arena.height - well.y)
                wellNode.zPosition = 4
                wellNode.name = nodeKey

                // Inner spiral effect
                let innerCircle = SKShapeNode(circleOfRadius: 30)
                innerCircle.fillColor = SKColor.black.withAlphaComponent(0.7)
                innerCircle.strokeColor = DesignColors.secondaryUI
                innerCircle.glowWidth = 8
                wellNode.addChild(innerCircle)

                // Rotation animation (use cached action)
                wellNode.run(SKAction.repeatForever(gravityWellRotateAction), withKey: "rotate")

                addChild(wellNode)
                bossMechanicNodes[nodeKey] = wellNode
            }
        }

        // Remove wells that no longer exist (release to pool for reuse)
        for key in findKeysToRemove(prefix: "voidharbinger_well_", activeIds: activeWellIds) {
            if let node = bossMechanicNodes[key] {
                nodePool.release(node, type: "boss_well")
            }
            bossMechanicNodes.removeValue(forKey: key)
        }

        // Render shrinking arena boundary (Phase 4) - optimized: use scale instead of path rebuild
        if bossState.phase == 4 {
            let arenaKey = "voidharbinger_arena"
            // Convert to scene coordinates (flip Y)
            let centerSceneY = gameState.arena.height - bossState.arenaCenter.y

            // Calculate scale based on current radius vs initial radius
            let initialRadius = BalanceConfig.VoidHarbinger.arenaStartRadius
            let currentScale = bossState.arenaRadius / initialRadius

            if let node = bossMechanicNodes[arenaKey] as? SKShapeNode {
                // Update arena size using scale (no path rebuild)
                node.xScale = currentScale
                node.yScale = currentScale
            } else {
                // Create arena boundary at full size (will be scaled down)
                let arenaNode = SKShapeNode(circleOfRadius: initialRadius)
                arenaNode.fillColor = SKColor.clear
                arenaNode.strokeColor = DesignColors.dangerUI
                arenaNode.lineWidth = 4
                arenaNode.glowWidth = 4  // Reduced from 8 for performance
                arenaNode.zPosition = 3
                arenaNode.name = arenaKey
                arenaNode.position = CGPoint(x: bossState.arenaCenter.x, y: centerSceneY)
                arenaNode.xScale = currentScale
                arenaNode.yScale = currentScale

                // Pulsing warning effect (use cached action)
                arenaNode.run(SKAction.repeatForever(arenaBoundaryPulseAction), withKey: "pulse")

                addChild(arenaNode)
                bossMechanicNodes[arenaKey] = arenaNode
            }
        } else {
            // Remove arena boundary if not in phase 4
            if let node = bossMechanicNodes["voidharbinger_arena"] {
                node.removeFromParent()
                bossMechanicNodes.removeValue(forKey: "voidharbinger_arena")
            }
        }

        // Show phase indicator and invulnerability
        renderPhaseIndicator(phase: bossState.phase, bossType: "voidharbinger", isInvulnerable: bossState.isInvulnerable)
    }

    // MARK: - Phase Indicator

    func renderPhaseIndicator(phase: Int, bossType: String, isInvulnerable: Bool = false) {
        let nodeKey = "\(bossType)_phase_indicator"

        if let label = bossMechanicNodes[nodeKey] as? SKLabelNode {
            label.text = isInvulnerable ? L10n.Boss.phaseInvulnerable(phase) : L10n.Boss.phase(phase)
            label.fontColor = isInvulnerable ? DesignColors.warningUI : DesignColors.primaryUI
        } else {
            let label = SKLabelNode(text: L10n.Boss.phase(phase))
            label.fontName = "Menlo-Bold"
            label.fontSize = 18
            label.fontColor = DesignColors.primaryUI
            label.position = CGPoint(x: gameState.arena.width / 2, y: gameState.arena.height - 60)
            label.zPosition = 200
            label.name = nodeKey

            addChild(label)
            bossMechanicNodes[nodeKey] = label
        }
    }

    func pointToLineDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lengthSquared = dx * dx + dy * dy

        if lengthSquared == 0 {
            return sqrt(pow(point.x - lineStart.x, 2) + pow(point.y - lineStart.y, 2))
        }

        let t = max(0, min(1, ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / lengthSquared))
        let projX = lineStart.x + t * dx
        let projY = lineStart.y + t * dy

        return sqrt(pow(point.x - projX, 2) + pow(point.y - projY, 2))
    }

    // MARK: - Overclocker Rendering

    func renderOverclockerMechanics(bossState: OverclockerAI.OverclockerState) {
        guard let boss = gameState.enemies.first(where: { $0.isBoss && !$0.isDead }) else { return }
        let bossPos = CGPoint(x: boss.x, y: boss.y)
        let arenaH = gameState.arena.height

        // Phase 1: Render rotating blades
        if bossState.phase == 1 {
            let bladeCount = BalanceConfig.Overclocker.bladeCount
            let bladeRadius = BalanceConfig.Overclocker.bladeOrbitRadius

            for i in 0..<bladeCount {
                let nodeKey = "overclocker_blade_\(i)"
                let angleOffset = CGFloat(i) * (2 * .pi / CGFloat(bladeCount))
                let currentAngle = bossState.bladeAngle + angleOffset

                let bladeNode: SKShapeNode
                if let existing = bossMechanicNodes[nodeKey] as? SKShapeNode {
                    bladeNode = existing
                } else {
                    // Create blade as a line
                    let path = CGMutablePath()
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(x: bladeRadius, y: 0))
                    bladeNode = SKShapeNode(path: path)
                    bladeNode.strokeColor = SKColor.orange
                    bladeNode.lineWidth = BalanceConfig.Overclocker.bladeWidth
                    bladeNode.lineCap = .round
                    bladeNode.zPosition = 100
                    addChild(bladeNode)
                    bossMechanicNodes[nodeKey] = bladeNode
                }

                bladeNode.position = CGPoint(x: bossPos.x, y: arenaH - bossPos.y)
                bladeNode.zRotation = -currentAngle // Negative for Y-flip
            }
        } else {
            // Clean up blades if not in Phase 1
            for i in 0..<3 {
                let nodeKey = "overclocker_blade_\(i)"
                if let node = bossMechanicNodes[nodeKey] {
                    node.removeFromParent()
                    bossMechanicNodes.removeValue(forKey: nodeKey)
                }
            }
        }

        // Phase 2: Render lava tiles
        if bossState.phase == 2 {
            let arenaRect = bossState.arenaRect
            let tileW = arenaRect.width / 4
            let tileH = arenaRect.height / 4

            for i in 0..<16 {
                let nodeKey = "overclocker_tile_\(i)"
                let col = i % 4
                let row = i / 4

                let tileNode: SKShapeNode
                if let existing = bossMechanicNodes[nodeKey] as? SKShapeNode {
                    tileNode = existing
                } else {
                    tileNode = SKShapeNode(rectOf: CGSize(width: tileW - 4, height: tileH - 4), cornerRadius: 4)
                    tileNode.zPosition = 1
                    tileNode.lineWidth = 2
                    addChild(tileNode)
                    bossMechanicNodes[nodeKey] = tileNode
                }

                let tileX = arenaRect.minX + CGFloat(col) * tileW + tileW / 2
                let tileY = arenaRect.minY + CGFloat(row) * tileH + tileH / 2
                tileNode.position = CGPoint(x: tileX, y: arenaH - tileY)

                // Color based on state
                switch bossState.tileStates[i] {
                case .normal:
                    tileNode.fillColor = SKColor.darkGray.withAlphaComponent(0.3)
                    tileNode.strokeColor = SKColor.gray
                case .warning:
                    tileNode.fillColor = SKColor.orange.withAlphaComponent(0.5)
                    tileNode.strokeColor = SKColor.yellow
                case .lava:
                    tileNode.fillColor = SKColor.red.withAlphaComponent(0.7)
                    tileNode.strokeColor = SKColor.orange
                case .safe:
                    tileNode.fillColor = SKColor.cyan.withAlphaComponent(0.4)
                    tileNode.strokeColor = SKColor.blue
                }
            }
        } else {
            // Clean up tiles if not in Phase 2
            for i in 0..<16 {
                let nodeKey = "overclocker_tile_\(i)"
                if let node = bossMechanicNodes[nodeKey] {
                    node.removeFromParent()
                    bossMechanicNodes.removeValue(forKey: nodeKey)
                }
            }
        }

        // Phase 3 & 4: Render steam trail
        if bossState.phase >= 3 {
            var activeSteamIds = Set<String>()
            for segment in bossState.steamTrail {
                activeSteamIds.insert(segment.id)
                let nodeKey = "overclocker_steam_\(segment.id)"

                let steamNode: SKShapeNode
                if let existing = bossMechanicNodes[nodeKey] as? SKShapeNode {
                    steamNode = existing
                } else {
                    steamNode = SKShapeNode(circleOfRadius: BalanceConfig.Overclocker.steamRadius)
                    steamNode.fillColor = SKColor.white.withAlphaComponent(0.3)
                    steamNode.strokeColor = SKColor.gray.withAlphaComponent(0.5)
                    steamNode.zPosition = 50
                    addChild(steamNode)
                    bossMechanicNodes[nodeKey] = steamNode
                }

                steamNode.position = CGPoint(x: segment.x, y: arenaH - segment.y)
            }

            // Clean up old steam segments
            let keysToRemove = bossMechanicNodes.keys.filter { $0.hasPrefix("overclocker_steam_") && !activeSteamIds.contains(String($0.dropFirst("overclocker_steam_".count))) }
            for key in keysToRemove {
                bossMechanicNodes[key]?.removeFromParent()
                bossMechanicNodes.removeValue(forKey: key)
            }
        }

        // Phase 4: Render shredder ring
        if bossState.phase == 4 {
            let nodeKey = "overclocker_shredder"
            let shredderNode: SKShapeNode
            if let existing = bossMechanicNodes[nodeKey] as? SKShapeNode {
                shredderNode = existing
            } else {
                shredderNode = SKShapeNode(circleOfRadius: BalanceConfig.Overclocker.shredderRadius)
                shredderNode.fillColor = SKColor.red.withAlphaComponent(0.2)
                shredderNode.strokeColor = bossState.isSuctionActive ? SKColor.red : SKColor.orange
                shredderNode.lineWidth = 4
                shredderNode.zPosition = 99
                addChild(shredderNode)
                bossMechanicNodes[nodeKey] = shredderNode
            }

            shredderNode.position = CGPoint(x: bossPos.x, y: arenaH - bossPos.y)
            shredderNode.strokeColor = bossState.isSuctionActive ? SKColor.red : SKColor.orange
        } else {
            if let node = bossMechanicNodes["overclocker_shredder"] {
                node.removeFromParent()
                bossMechanicNodes.removeValue(forKey: "overclocker_shredder")
            }
        }
    }

    // MARK: - Trojan Wyrm Rendering

    func renderTrojanWyrmMechanics(bossState: TrojanWyrmAI.TrojanWyrmState) {
        let arenaH = gameState.arena.height

        // Main head is rendered by standard enemy rendering, but we can add glow
        guard let boss = gameState.enemies.first(where: { $0.isBoss && !$0.isDead }) else { return }

        // Render body segments (Phase 1, 2, 4)
        if bossState.phase != 3 {
            for (i, segment) in bossState.segments.enumerated() {
                let nodeKey = "trojanwyrm_seg_\(i)"
                let segNode: SKShapeNode
                if let existing = bossMechanicNodes[nodeKey] as? SKShapeNode {
                    segNode = existing
                } else {
                    segNode = SKShapeNode(circleOfRadius: BalanceConfig.TrojanWyrm.bodyCollisionRadius)
                    segNode.lineWidth = 2
                    segNode.zPosition = 100
                    addChild(segNode)
                    bossMechanicNodes[nodeKey] = segNode
                }

                segNode.position = CGPoint(x: segment.x, y: arenaH - segment.y)

                // Phase 2: Ghost segment is cyan/transparent
                if bossState.phase == 2 && i == bossState.ghostSegmentIndex {
                    segNode.fillColor = SKColor.cyan.withAlphaComponent(0.2)
                    segNode.strokeColor = SKColor.cyan
                } else {
                    segNode.fillColor = SKColor(red: 0, green: 1, blue: 0.27, alpha: 0.7) // Hacker green
                    segNode.strokeColor = SKColor(red: 0, green: 0.8, blue: 0.2, alpha: 1.0)
                }
            }

            // Render head glow
            let headKey = "trojanwyrm_head"
            let headNode: SKShapeNode
            if let existing = bossMechanicNodes[headKey] as? SKShapeNode {
                headNode = existing
            } else {
                headNode = SKShapeNode(circleOfRadius: BalanceConfig.TrojanWyrm.headCollisionRadius + 5)
                headNode.fillColor = SKColor(red: 0, green: 1, blue: 0.27, alpha: 0.9)
                headNode.strokeColor = SKColor.white
                headNode.lineWidth = 3
                headNode.zPosition = 101
                addChild(headNode)
                bossMechanicNodes[headKey] = headNode
            }
            headNode.position = CGPoint(x: boss.x, y: arenaH - boss.y)
        } else {
            // Clean up main body in Phase 3
            for i in 0..<BalanceConfig.TrojanWyrm.segmentCount {
                let nodeKey = "trojanwyrm_seg_\(i)"
                if let node = bossMechanicNodes[nodeKey] {
                    node.removeFromParent()
                    bossMechanicNodes.removeValue(forKey: nodeKey)
                }
            }
            if let node = bossMechanicNodes["trojanwyrm_head"] {
                node.removeFromParent()
                bossMechanicNodes.removeValue(forKey: "trojanwyrm_head")
            }
        }

        // Phase 3: Render sub-worms
        if bossState.phase == 3 {
            for (wi, worm) in bossState.subWorms.enumerated() {
                // Sub-worm head
                let headKey = "trojanwyrm_sw_\(wi)_head"
                let swHeadNode: SKShapeNode
                if let existing = bossMechanicNodes[headKey] as? SKShapeNode {
                    swHeadNode = existing
                } else {
                    swHeadNode = SKShapeNode(circleOfRadius: BalanceConfig.TrojanWyrm.subWormHeadSize)
                    swHeadNode.fillColor = SKColor(red: 0, green: 1, blue: 0.27, alpha: 0.9)
                    swHeadNode.strokeColor = SKColor.white
                    swHeadNode.lineWidth = 2
                    swHeadNode.zPosition = 101
                    addChild(swHeadNode)
                    bossMechanicNodes[headKey] = swHeadNode
                }
                swHeadNode.position = CGPoint(x: worm.head.x, y: arenaH - worm.head.y)

                // Sub-worm body
                for (si, seg) in worm.body.enumerated() {
                    let segKey = "trojanwyrm_sw_\(wi)_seg_\(si)"
                    let swSegNode: SKShapeNode
                    if let existing = bossMechanicNodes[segKey] as? SKShapeNode {
                        swSegNode = existing
                    } else {
                        swSegNode = SKShapeNode(circleOfRadius: BalanceConfig.TrojanWyrm.subWormBodySize)
                        swSegNode.fillColor = SKColor(red: 0, green: 1, blue: 0.27, alpha: 0.6)
                        swSegNode.strokeColor = SKColor(red: 0, green: 0.8, blue: 0.2, alpha: 1.0)
                        swSegNode.lineWidth = 1
                        swSegNode.zPosition = 100
                        addChild(swSegNode)
                        bossMechanicNodes[segKey] = swSegNode
                    }
                    swSegNode.position = CGPoint(x: seg.x, y: arenaH - seg.y)
                }
            }
        } else {
            // Clean up sub-worms if not in Phase 3
            for wi in 0..<4 {
                if let node = bossMechanicNodes["trojanwyrm_sw_\(wi)_head"] {
                    node.removeFromParent()
                    bossMechanicNodes.removeValue(forKey: "trojanwyrm_sw_\(wi)_head")
                }
                for si in 0..<5 {
                    let segKey = "trojanwyrm_sw_\(wi)_seg_\(si)"
                    if let node = bossMechanicNodes[segKey] {
                        node.removeFromParent()
                        bossMechanicNodes.removeValue(forKey: segKey)
                    }
                }
            }
        }

        // Phase 4: Render aim line during aiming state
        if bossState.phase == 4 && bossState.phase4SubState == .aiming {
            let aimKey = "trojanwyrm_aimline"
            let playerPos = CGPoint(x: gameState.player.x, y: gameState.player.y)
            let headPos = CGPoint(x: boss.x, y: boss.y)

            let aimNode: SKShapeNode
            if let existing = bossMechanicNodes[aimKey] as? SKShapeNode {
                aimNode = existing
            } else {
                aimNode = SKShapeNode()
                aimNode.strokeColor = SKColor.red
                aimNode.lineWidth = 3
                aimNode.zPosition = 102
                addChild(aimNode)
                bossMechanicNodes[aimKey] = aimNode
            }

            let path = CGMutablePath()
            path.move(to: CGPoint(x: headPos.x, y: arenaH - headPos.y))
            path.addLine(to: CGPoint(x: playerPos.x, y: arenaH - playerPos.y))
            aimNode.path = path
        } else {
            if let node = bossMechanicNodes["trojanwyrm_aimline"] {
                node.removeFromParent()
                bossMechanicNodes.removeValue(forKey: "trojanwyrm_aimline")
            }
        }
    }
}
