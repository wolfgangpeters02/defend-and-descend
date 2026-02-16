import SpriteKit

// MARK: - Entity Rendering

extension GameScene {

    func renderDamageEvents() {
        // Process and display new damage events
        for i in 0..<gameState.damageEvents.count {
            guard !gameState.damageEvents[i].displayed else { continue }

            let event = gameState.damageEvents[i]

            // Convert game position to scene position (flip Y)
            let scenePosition = CGPoint(
                x: event.position.x,
                y: gameState.arena.height - event.position.y
            )

            // Map DamageEventType to SCTType and display
            switch event.type {
            case .damage:
                combatText.showDamage(event.amount, at: scenePosition, isCritical: false)
            case .critical:
                combatText.showDamage(event.amount, at: scenePosition, isCritical: true)
            case .healing:
                combatText.showHealing(event.amount, at: scenePosition)
            case .playerDamage:
                combatText.show("-\(event.amount)", type: .damage, at: scenePosition)
            case .freeze:
                combatText.showFreeze(at: scenePosition)
            case .burn:
                combatText.showBurn(event.amount, at: scenePosition)
            case .chain:
                combatText.showChain(event.amount, at: scenePosition)
            case .execute:
                combatText.showExecute(at: scenePosition)
            case .xp:
                combatText.showXP(event.amount, at: scenePosition)
            case .currency:
                combatText.showCurrency(event.amount, at: scenePosition)
            case .miss:
                combatText.showMiss(at: scenePosition)
            case .shield:
                combatText.show("BLOCKED", type: .shield, at: scenePosition)
            case .immune:
                combatText.show("IMMUNE", type: .immune, at: scenePosition)
            }

            gameState.damageEvents[i].displayed = true
        }

        // Clean up old damage events in-place
        let currentTime = gameState.startTime + gameState.timeElapsed
        var writeIdx = 0
        for idx in 0..<gameState.damageEvents.count {
            if currentTime - gameState.damageEvents[idx].timestamp <= 2.0 {
                gameState.damageEvents[writeIdx] = gameState.damageEvents[idx]
                writeIdx += 1
            }
        }
        gameState.damageEvents.removeSubrange(writeIdx..<gameState.damageEvents.count)
    }

    func renderPlayer() {
        let player = gameState.player

        if playerNode == nil {
            playerNode = entityRenderer.createPlayerNode(size: player.size)
            playerLayer.addChild(playerNode!) // Use player layer (Phase 5)
        }

        // Update position (flip Y coordinate)
        playerNode?.position = CGPoint(
            x: player.x,
            y: gameState.arena.height - player.y
        )

        // Invulnerability flash using SKAction (Phase 1.4)
        if player.invulnerable {
            if !isPlayingInvulnerability, let action = invulnerabilityAction {
                playerNode?.run(action, withKey: "invulnerability")
                isPlayingInvulnerability = true
            }
        } else {
            if isPlayingInvulnerability {
                playerNode?.removeAction(forKey: "invulnerability")
                playerNode?.alpha = 1.0
                isPlayingInvulnerability = false
            }
        }
    }

    func renderEnemies() {
        var activeIds = Set<String>()

        for enemy in gameState.enemies where !enemy.isDead {
            activeIds.insert(enemy.id)

            // Get or create node using pool (Phase 5)
            let node = nodePool.acquireEnemyNode(
                id: enemy.id,
                existing: &enemyNodes,
                renderer: entityRenderer,
                enemy: enemy
            )

            // Add to layer if new, with spawn animation
            if node.parent == nil {
                enemyLayer.addChild(node)
                let shape = node.userData?["shape"] as? String ?? "circle"
                EntityRenderer.runSpawnAnimation(on: node, shape: shape)
            }

            // Update position
            node.position = CGPoint(
                x: enemy.x,
                y: gameState.arena.height - enemy.y
            )

            // Slow effect visual
            node.alpha = enemy.isSlowed ? 0.7 : 1.0
        }

        // Death effects for enemies about to be released (Phase 7B)
        for (id, node) in enemyNodes where !activeIds.contains(id) {
            // Find the enemy to get its shape/color for death animation
            let shape = node.userData?["shape"] as? String ?? "circle"
            let size = node.userData?["size"] as? CGFloat ?? 12
            let color = node.userData?["color"] as? UIColor ?? .red
            // Spawn lightweight death fragments at enemy position
            EntityRenderer.spawnDeathEffect(
                at: node.position, in: enemyLayer,
                shape: shape, color: color, size: size
            )
        }

        // Release unused nodes back to pool (Phase 5)
        nodePool.releaseInactive(type: .enemy, nodes: &enemyNodes, activeIds: activeIds)
    }

    func renderProjectiles() {
        var activeIds = Set<String>()

        for projectile in gameState.projectiles {
            activeIds.insert(projectile.id)

            // Get or create node using pool (Phase 5)
            let node = nodePool.acquireProjectileNode(
                id: projectile.id,
                existing: &projectileNodes,
                renderer: entityRenderer,
                projectile: projectile
            )

            // Add to layer if new
            if node.parent == nil {
                projectileLayer.addChild(node)
            }

            // Update position
            node.position = CGPoint(
                x: projectile.x,
                y: gameState.arena.height - projectile.y
            )
        }

        // Release unused nodes back to pool (Phase 5)
        nodePool.releaseInactive(type: .projectile, nodes: &projectileNodes, activeIds: activeIds)
    }

    func renderPickups() {
        var activeIds = Set<String>()

        for pickup in gameState.pickups {
            activeIds.insert(pickup.id)

            // Get or create node using pool (Phase 5)
            let node = nodePool.acquirePickupNode(
                id: pickup.id,
                existing: &pickupNodes,
                renderer: entityRenderer,
                pickup: pickup
            )

            // Add to layer if new
            if node.parent == nil {
                pickupLayer.addChild(node)
            }

            // Update position
            node.position = CGPoint(
                x: pickup.x,
                y: gameState.arena.height - pickup.y
            )
        }

        // Release unused nodes back to pool (Phase 5)
        nodePool.releaseInactive(type: .pickup, nodes: &pickupNodes, activeIds: activeIds)
    }

    func renderParticles() {
        var activeIds = Set<String>()
        // Use gameTime for particle fade calculations (avoids Date() call)
        let now = gameState.startTime + gameState.timeElapsed

        for particle in gameState.particles {
            activeIds.insert(particle.id)

            // Get or create node using pool (Phase 5)
            let node = nodePool.acquireParticleNode(
                id: particle.id,
                existing: &particleNodes,
                renderer: entityRenderer,
                particle: particle
            )

            // Add to layer if new
            if node.parent == nil {
                particleLayer.addChild(node)
            }

            // Update position
            node.position = CGPoint(
                x: particle.x,
                y: gameState.arena.height - particle.y
            )

            // Fade out based on lifetime
            let progress = CGFloat((now - particle.createdAt) / particle.lifetime)
            node.alpha = max(0, 1.0 - progress)

            // Apply rotation if specified
            if let rotation = particle.rotation {
                node.zRotation = rotation
            }
        }

        // Release unused nodes back to pool (Phase 5)
        nodePool.releaseInactive(type: .particle, nodes: &particleNodes, activeIds: activeIds)
    }

    // MARK: - Pillar Rendering (Boss Mode)

    func renderPillars() {
        // Only render pillar health bars in boss mode
        guard gameState.gameMode == .boss else {
            // Clean up any existing health bars when not in boss mode
            for (_, node) in pillarHealthBars {
                node.removeFromParent()
            }
            pillarHealthBars.removeAll()
            return
        }

        for (index, obstacle) in gameState.arena.obstacles.enumerated() {
            guard index < obstacleNodes.count else { continue }

            let obstacleNode = obstacleNodes[index]
            let pillarId = obstacle.id

            // Check if pillar is destructible and alive
            guard PillarSystem.isPillarAlive(obstacle: obstacle),
                  let healthPercent = PillarSystem.getPillarHealthPercent(obstacle: obstacle) else {
                // Pillar destroyed or not destructible — remove from scene graph (11d)
                if obstacle.isDestructible, let health = obstacle.health, health <= 0 {
                    if obstacleNode.alpha > 0 {
                        // Animate destruction then remove entirely
                        obstacleNode.run(SKAction.sequence([
                            SKAction.group([
                                SKAction.fadeOut(withDuration: 0.25),
                                SKAction.scale(to: 0.85, duration: 0.25)
                            ]),
                            SKAction.removeFromParent()
                        ]))
                    }
                    // Remove health bar if exists
                    if let healthBar = pillarHealthBars[pillarId] {
                        healthBar.removeFromParent()
                        pillarHealthBars.removeValue(forKey: pillarId)
                    }
                }
                continue
            }

            // Update or create health bar
            if let healthBarContainer = pillarHealthBars[pillarId] {
                // Update existing health bar
                if let fillNode = healthBarContainer.childNode(withName: "fill") as? SKShapeNode {
                    fillNode.xScale = max(0.01, healthPercent)

                    // Color based on health
                    if healthPercent > 0.6 {
                        fillNode.fillColor = SKColor(red: 0.4, green: 0.4, blue: 0.45, alpha: 1)
                    } else if healthPercent > 0.3 {
                        fillNode.fillColor = SKColor(red: 0.7, green: 0.5, blue: 0.2, alpha: 1)
                    } else {
                        fillNode.fillColor = SKColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1)
                    }
                }
            } else {
                // Create new health bar
                let healthBar = createPillarHealthBar(width: obstacle.width * 0.8)
                healthBar.position = CGPoint(
                    x: obstacleNode.position.x,
                    y: obstacleNode.position.y + obstacle.height / 2 + 15
                )
                healthBar.zPosition = 150
                addChild(healthBar)
                pillarHealthBars[pillarId] = healthBar
            }

            // Update pillar visual based on damage and phase
            if let shapeNode = obstacleNode as? SKShapeNode {
                let damageAlpha = 0.6 + (healthPercent * 0.4)
                shapeNode.alpha = damageAlpha

                // Base stroke color from health state
                var strokeColor: SKColor
                if healthPercent < 0.3 {
                    strokeColor = SKColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 1)
                    shapeNode.lineWidth = 3
                } else {
                    strokeColor = SKColor(red: 0.29, green: 0.33, blue: 0.41, alpha: 1)
                    shapeNode.lineWidth = 2
                }

                // 9b: Phase-based pillar escalation — tint stroke toward boss theme
                if gameState.activeBossType != nil {
                    let phase = currentBossPhase()
                    let themeColor = bossThemeColor()
                    let blendFraction: CGFloat
                    let glow: CGFloat
                    switch phase {
                    case 2: blendFraction = 0.1; glow = 0
                    case 3: blendFraction = 0.25; glow = 2
                    case 4: blendFraction = 0.4; glow = 4
                    default: blendFraction = 0; glow = 0
                    }
                    if blendFraction > 0 {
                        strokeColor = blendColor(strokeColor, toward: themeColor, fraction: blendFraction)
                    }
                    shapeNode.glowWidth = glow
                }

                shapeNode.strokeColor = strokeColor
            }
        }

        // 9c: Update vignette intensity based on boss phase
        if gameState.activeBossType != nil {
            updateVignetteForPhase(currentBossPhase())
        }
    }

    func createPillarHealthBar(width: CGFloat) -> SKNode {
        let container = SKNode()

        // Background
        let bgNode = SKShapeNode(rectOf: CGSize(width: width, height: 6), cornerRadius: 2)
        bgNode.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.8)
        bgNode.strokeColor = SKColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)
        bgNode.lineWidth = 1
        container.addChild(bgNode)

        // Fill (starts full)
        let fillNode = SKShapeNode(rect: CGRect(x: -width / 2, y: -3, width: width, height: 6), cornerRadius: 2)
        fillNode.fillColor = SKColor(red: 0.4, green: 0.4, blue: 0.45, alpha: 1)
        fillNode.strokeColor = .clear
        fillNode.name = "fill"
        container.addChild(fillNode)

        return container
    }

    /// Linearly interpolate between two colors.
    private func blendColor(_ base: SKColor, toward target: SKColor, fraction: CGFloat) -> SKColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        base.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        target.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return SKColor(
            red: r1 + (r2 - r1) * fraction,
            green: g1 + (g2 - g1) * fraction,
            blue: b1 + (b2 - b1) * fraction,
            alpha: a1
        )
    }
}
