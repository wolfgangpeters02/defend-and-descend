import SpriteKit

// MARK: - Enemy Visual Updates

extension TDGameScene {

    // MARK: - Enemy Shape Paths

    /// Create hexagon path (used by enemy nodes)
    func createHexagonPath(radius: CGFloat) -> CGPath {
        let path = UIBezierPath()
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 6
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.close()
        return path.cgPath
    }

    /// Create diamond path
    func createDiamondPath(size: CGFloat) -> CGPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: size / 2))
        path.addLine(to: CGPoint(x: size / 2, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -size / 2))
        path.addLine(to: CGPoint(x: -size / 2, y: 0))
        path.close()
        return path.cgPath
    }

    func createEnemyNode(enemy: TDEnemy) -> SKNode {
        let container = SKNode()

        // Virus color based on enemy type/tier
        // Boss: white with warning glow
        // Tank: purple (tier 3)
        // Fast: orange (tier 2)
        // Basic: red (tier 1)
        let virusColor: UIColor
        if enemy.isBoss {
            virusColor = DesignColors.enemyBossUI
        } else {
            switch enemy.type {
            case EnemyID.fast.rawValue:
                virusColor = DesignColors.enemyTier2UI  // Orange
            case EnemyID.tank.rawValue:
                virusColor = DesignColors.enemyTier3UI  // Purple
            case EnemyID.elite.rawValue:
                virusColor = DesignColors.enemyTier4UI  // Magenta
            default:
                virusColor = DesignColors.enemyTier1UI  // Red (basic)
            }
        }

        // Virus body — archetype compositions for non-boss, legacy shapes for bosses
        let body: SKShapeNode

        if enemy.isBoss {
            // Boss-specific compositions based on type
            let innerNode: SKShapeNode?

            if enemy.type == EnemyID.cyberboss.rawValue {
                // Cyberboss — full 8-node "Corporate AI" composition
                let _ = EntityRenderer.createCyberbossComposition(in: container, size: enemy.size)
                body = (container.childNode(withName: "body") as? SKShapeNode)
                    ?? SKShapeNode(path: createHexagonPath(radius: enemy.size))
                if body.parent == nil {
                    body.name = "body"
                    container.addChild(body)
                }
                innerNode = nil  // Cyberboss has its own inner nodes

            } else if enemy.type == EnemyID.overclocker.rawValue {
                // Overclocker — 7-node "CPU Overheat" composition
                let _ = EntityRenderer.createOverclockerComposition(in: container, size: enemy.size)
                body = (container.childNode(withName: "body") as? SKShapeNode)
                    ?? SKShapeNode(path: createHexagonPath(radius: enemy.size))
                if body.parent == nil {
                    body.name = "body"
                    container.addChild(body)
                }
                innerNode = nil

            } else if enemy.type == "void_harbinger" {
                // Void Harbinger — full octagonal void core composition
                let _ = EntityRenderer.createVoidHarbingerComposition(in: container, size: enemy.size)
                body = (container.childNode(withName: "body") as? SKShapeNode)
                    ?? SKShapeNode(path: createHexagonPath(radius: enemy.size))
                if body.parent == nil {
                    body.name = "body"
                    container.addChild(body)
                }
                innerNode = nil

            } else if enemy.type == "trojan_wyrm" {
                // Trojan Wyrm — segmented worm head + trailing body
                let _ = EntityRenderer.createTrojanWyrmComposition(in: container, size: enemy.size)
                body = (container.childNode(withName: "body") as? SKShapeNode)
                    ?? SKShapeNode(path: createHexagonPath(radius: enemy.size))
                if body.parent == nil {
                    body.name = "body"
                    container.addChild(body)
                }
                innerNode = nil

            } else {
                // Generic/unknown bosses: shape-based rendering
                switch enemy.shape {
                case "triangle":
                    let path = UIBezierPath()
                    path.move(to: CGPoint(x: 0, y: enemy.size))
                    path.addLine(to: CGPoint(x: -enemy.size * 0.866, y: -enemy.size / 2))
                    path.addLine(to: CGPoint(x: enemy.size * 0.866, y: -enemy.size / 2))
                    path.close()
                    body = SKShapeNode(path: path.cgPath)
                case "diamond":
                    body = SKShapeNode(path: createDiamondPath(size: enemy.size * 2))
                default:
                    body = SKShapeNode(path: createHexagonPath(radius: enemy.size))
                }

                body.fillColor = virusColor.withAlphaComponent(0.85)
                body.strokeColor = DesignColors.warningUI
                body.lineWidth = 3
                body.glowWidth = 0
                body.name = "body"
                container.addChild(body)

                // Inner detail for legacy bosses
                let innerSize = enemy.size * 0.5
                let innerPath = createHexagonPath(radius: innerSize)
                let inner = SKShapeNode(path: innerPath)
                inner.fillColor = UIColor.black.withAlphaComponent(0.3)
                inner.strokeColor = virusColor.withAlphaComponent(0.8)
                inner.lineWidth = 1
                container.addChild(inner)
                innerNode = inner
            }

            // Boss effects
            if enemy.immuneToTowers && enemy.isBoss {
                body.strokeColor = UIColor.orange

                let superVirusLabel = SKLabelNode(text: L10n.Enemy.superVirusIndicator)
                superVirusLabel.fontName = "Menlo-Bold"
                superVirusLabel.fontSize = 12
                superVirusLabel.fontColor = .orange
                superVirusLabel.position = CGPoint(x: 0, y: enemy.size + 28)
                superVirusLabel.name = "bossIndicator"
                container.addChild(superVirusLabel)

                let immuneLabel = SKLabelNode(text: L10n.Enemy.immuneToTowers)
                immuneLabel.fontName = "Menlo-Bold"
                immuneLabel.fontSize = 9
                immuneLabel.fontColor = UIColor.cyan
                immuneLabel.position = CGPoint(x: 0, y: enemy.size + 16)
                immuneLabel.name = "immuneIndicator"
                container.addChild(immuneLabel)

                let shieldRing = SKShapeNode(circleOfRadius: enemy.size * 1.4)
                shieldRing.strokeColor = UIColor.orange.withAlphaComponent(0.7)
                shieldRing.fillColor = .clear
                shieldRing.lineWidth = 3
                shieldRing.glowWidth = 0
                shieldRing.zPosition = -1
                shieldRing.name = "shieldRing"
                container.addChild(shieldRing)

                let shieldPulse = SKAction.sequence([
                    SKAction.group([
                        SKAction.scale(to: 1.1, duration: 0.8),
                        SKAction.fadeAlpha(to: 0.4, duration: 0.8)
                    ]),
                    SKAction.group([
                        SKAction.scale(to: 1.0, duration: 0.8),
                        SKAction.fadeAlpha(to: 0.8, duration: 0.8)
                    ])
                ])
                shieldRing.run(SKAction.repeatForever(shieldPulse))

                let colorCycle = SKAction.sequence([
                    SKAction.colorize(with: .red, colorBlendFactor: 0.6, duration: 0.6),
                    SKAction.colorize(with: .orange, colorBlendFactor: 0.6, duration: 0.6)
                ])
                body.run(SKAction.repeatForever(colorCycle))

                let pulse = SKAction.sequence([
                    SKAction.scale(to: 1.1, duration: 0.6),
                    SKAction.scale(to: 0.95, duration: 0.6)
                ])
                body.run(SKAction.repeatForever(pulse), withKey: "bossPulse")

                let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 5.0)
                innerNode?.run(SKAction.repeatForever(rotate))

            } else if enemy.isBoss && enemy.type != EnemyID.cyberboss.rawValue && enemy.type != EnemyID.overclocker.rawValue && enemy.type != "void_harbinger" && enemy.type != "trojan_wyrm" {
                // Regular/legacy boss (not handled by archetype compositions)
                let bossLabel = SKLabelNode(text: L10n.Enemy.bossIndicator)
                bossLabel.fontName = "Menlo-Bold"
                bossLabel.fontSize = 10
                bossLabel.fontColor = DesignColors.warningUI
                bossLabel.position = CGPoint(x: 0, y: enemy.size + 16)
                bossLabel.name = "bossIndicator"
                container.addChild(bossLabel)

                let colorCycle = SKAction.sequence([
                    SKAction.colorize(with: .red, colorBlendFactor: 0.5, duration: 0.5),
                    SKAction.colorize(with: .orange, colorBlendFactor: 0.5, duration: 0.5),
                    SKAction.colorize(with: .yellow, colorBlendFactor: 0.5, duration: 0.5),
                    SKAction.colorize(with: .white, colorBlendFactor: 0.0, duration: 0.5)
                ])
                body.run(SKAction.repeatForever(colorCycle))

                let pulse = SKAction.sequence([
                    SKAction.scale(to: 1.15, duration: 0.4),
                    SKAction.scale(to: 0.95, duration: 0.4)
                ])
                body.run(SKAction.repeatForever(pulse), withKey: "bossPulse")

                let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 4.0)
                innerNode?.run(SKAction.repeatForever(rotate))
            }

        } else {
            // Non-boss enemies: full archetype compositions (Phase 3)
            switch enemy.shape {
            case "triangle":
                // Fast virus — "Packet Runner"
                body = EntityRenderer.createFastVirusComposition(in: container, size: enemy.size, color: virusColor)
                let fastRotate = SKAction.rotate(byAngle: .pi * 2, duration: 2.0)
                container.run(SKAction.repeatForever(fastRotate))

            case "square":
                // Tank virus — "Armored Payload"
                body = EntityRenderer.createTankVirusComposition(in: container, size: enemy.size, color: virusColor)
                let breathe = SKAction.sequence([
                    SKAction.scale(to: 1.03, duration: 1.0),
                    SKAction.scale(to: 1.0, duration: 1.0)
                ])
                body.run(SKAction.repeatForever(breathe))

            case "hexagon":
                // Elite virus
                body = EntityRenderer.createEliteVirusComposition(in: container, size: enemy.size, color: virusColor)
                let flicker = SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.9, duration: 0.15),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.15)
                ])
                body.run(SKAction.repeatForever(flicker))

            default:
                // Basic virus — "Malware Blob"
                body = EntityRenderer.createBasicVirusComposition(in: container, size: enemy.size, color: virusColor)
                let pulse = SKAction.sequence([
                    SKAction.scale(to: 1.05, duration: 0.8),
                    SKAction.scale(to: 0.95, duration: 0.8)
                ])
                body.run(SKAction.repeatForever(pulse))
                let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 4.0)
                container.run(SKAction.repeatForever(rotate))
            }
        }

        // Slow effect overlay (ice blue, hidden by default)
        let slowOverlay = SKShapeNode(circleOfRadius: enemy.size * 0.9)
        slowOverlay.fillColor = DesignColors.primaryUI.withAlphaComponent(0.2)
        slowOverlay.strokeColor = DesignColors.primaryUI.withAlphaComponent(0.5)
        slowOverlay.lineWidth = 2
        slowOverlay.name = "slowOverlay"
        slowOverlay.isHidden = true
        container.addChild(slowOverlay)

        // Health arc is created lazily in updateEnemyVisuals on first damage

        // Store metadata for death/spawn animation
        let deathShape = enemy.isBoss ? "boss" : enemy.shape
        container.userData = NSMutableDictionary()
        container.userData?["shape"] = deathShape
        container.userData?["size"] = enemy.size
        container.userData?["colorHex"] = enemy.color

        // Spawn animation (Phase 7C)
        EntityRenderer.runSpawnAnimation(on: container, shape: deathShape)

        return container
    }

    func updateEnemyVisuals(state: TDGameState) {
        // Track enemies to remove
        var enemiesToRemove: [String] = []

        // Remove old enemy nodes with death animation (Set lookup: O(1) per node)
        let livingEnemyIds = Set(state.enemies.lazy.filter { !$0.isDead }.map { $0.id })
        for (id, _) in enemyNodes where !livingEnemyIds.contains(id) {
            enemiesToRemove.append(id)
        }

        for id in enemiesToRemove {
            if let node = enemyNodes[id] {
                // Type-specific death animation (Phase 7B)
                let shape = node.userData?["shape"] as? String ?? "circle"
                let size = node.userData?["size"] as? CGFloat ?? 12
                let colorHex = node.userData?["colorHex"] as? String ?? "#ff4444"
                let color = UIColor(hex: String(colorHex.dropFirst())) ?? .red
                EntityRenderer.runDeathAnimation(on: node, shape: shape, color: color, size: size)
                enemyNodes.removeValue(forKey: id)
                enemyLastHealth.removeValue(forKey: id)
            }
        }

        // Performance: calculate visible rect once for off-screen throttling
        let visibleRect = calculateVisibleRect()
        let paddedRect = visibleRect.insetBy(dx: -80, dy: -80)

        // Update/create enemy nodes
        for enemy in state.enemies {
            if enemy.isDead || enemy.reachedCore { continue }

            if let node = enemyNodes[enemy.id] {
                // Update position (always, even off-screen)
                node.position = convertToScene(enemy.position)

                // Viewport culling: hide off-screen enemies (saves GPU draw calls)
                let isOnScreen = paddedRect.contains(node.position)
                node.isHidden = !isOnScreen
                guard isOnScreen else { continue }

                // Health arc indicator — lazy thin arc above enemy, only when damaged
                let healthFraction = enemy.health / enemy.maxHealth
                if healthFraction < 1.0 {
                    let healthArc: SKShapeNode
                    if let existing = node.childNode(withName: "healthArc") as? SKShapeNode {
                        healthArc = existing
                    } else {
                        healthArc = SKShapeNode()
                        healthArc.lineWidth = 2
                        healthArc.lineCap = .round
                        healthArc.zPosition = 0.2
                        healthArc.name = "healthArc"
                        node.addChild(healthArc)
                    }

                    // Arc centered above enemy, ~160° sweep
                    let arcRadius = enemy.size + 6
                    let fullStart: CGFloat = .pi / 2 + .pi * 0.44
                    let fullEnd: CGFloat = .pi / 2 - .pi * 0.44
                    let sweep = fullStart - fullEnd
                    let currentEnd = fullStart - sweep * healthFraction

                    let arcPath = CGMutablePath()
                    arcPath.addArc(center: .zero, radius: arcRadius,
                                   startAngle: fullStart, endAngle: currentEnd,
                                   clockwise: true)
                    healthArc.path = arcPath

                    // Green → Yellow → Red
                    if healthFraction > 0.6 {
                        healthArc.strokeColor = UIColor.green
                    } else if healthFraction > 0.3 {
                        healthArc.strokeColor = UIColor.yellow
                    } else {
                        healthArc.strokeColor = UIColor.red
                    }
                } else {
                    node.childNode(withName: "healthArc")?.removeFromParent()
                }

                // Update slow effect with orbiting ice crystals
                if let slowOverlay = node.childNode(withName: "slowOverlay") as? SKShapeNode {
                    slowOverlay.isHidden = !enemy.isSlowed
                }

                // Manage orbiting frost crystals (recycled: toggle visibility instead of create/destroy)
                let frostCrystals = node.childNode(withName: "frostCrystals")
                if enemy.isSlowed {
                    if let crystals = frostCrystals {
                        crystals.isHidden = false
                    } else {
                        let crystalContainer = createFrostCrystals(enemySize: enemy.size)
                        crystalContainer.name = "frostCrystals"
                        node.addChild(crystalContainer)
                    }

                    // Occasional frost particle effect
                    if Int.random(in: 0..<15) == 0 {
                        spawnSlowParticle(at: node.position)
                    }
                } else {
                    // Hide frost crystals when no longer slowed (reuse on next slow)
                    frostCrystals?.isHidden = true
                }

                // Hit flash — brief white tint when health drops
                let healthPercent = enemy.health / enemy.maxHealth
                if let body = node.childNode(withName: "body") as? SKShapeNode {
                    let prevHealth = enemyLastHealth[enemy.id] ?? enemy.maxHealth
                    if enemy.health < prevHealth {
                        // Flash white for 0.05s on hit
                        body.removeAction(forKey: "hitFlash")
                        let originalFill = body.fillColor
                        let flash = SKAction.sequence([
                            SKAction.run { body.fillColor = UIColor.white.withAlphaComponent(0.9) },
                            SKAction.wait(forDuration: 0.05),
                            SKAction.run { body.fillColor = originalFill }
                        ])
                        body.run(flash, withKey: "hitFlash")
                    }

                    // Tint body when slowed (only when not flashing)
                    if body.action(forKey: "hitFlash") == nil {
                        if enemy.isSlowed {
                            body.fillColor = (UIColor(hex: enemy.color) ?? .red).blended(with: .cyan, ratio: 0.3)
                        } else {
                            body.fillColor = (UIColor(hex: enemy.color) ?? .red).withAlphaComponent(0.85)
                        }
                    }

                    // Critical state (<20% HP): body stroke turns red + jitter
                    if healthPercent <= 0.2 && !enemy.isBoss {
                        body.strokeColor = UIColor.red
                        body.lineWidth = 3
                        if node.action(forKey: "criticalJitter") == nil {
                            let jitter = SKAction.repeatForever(SKAction.sequence([
                                SKAction.moveBy(x: CGFloat.random(in: -1.5...1.5), y: CGFloat.random(in: -1.5...1.5), duration: 0.05),
                                SKAction.move(to: .zero, duration: 0.05)
                            ]))
                            body.run(jitter, withKey: "criticalJitter")
                        }
                    } else if healthPercent > 0.2 {
                        body.removeAction(forKey: "criticalJitter")
                    }
                }
                enemyLastHealth[enemy.id] = enemy.health

                // Low health glitch effect (under 30% HP)
                let damageOverlay = node.childNode(withName: "damageOverlay")
                if healthPercent <= 0.3 {
                    if damageOverlay == nil {
                        // Add damage overlay with glitch jitter
                        let overlay = createDamageOverlay(enemySize: enemy.size)
                        overlay.name = "damageOverlay"
                        node.addChild(overlay)
                    }
                } else {
                    // Remove damage overlay when above threshold
                    damageOverlay?.removeFromParent()
                }

            } else {
                // Create new enemy node
                let node = createEnemyNode(enemy: enemy)
                node.position = convertToScene(enemy.position)
                enemyLayer.addChild(node)
                enemyNodes[enemy.id] = node
                enemyLastHealth[enemy.id] = enemy.health
            }
        }
    }

    /// Spawn frost particle for slowed enemies
    func spawnSlowParticle(at position: CGPoint) {
        let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...4))
        particle.fillColor = .cyan.withAlphaComponent(0.6)
        particle.strokeColor = .clear
        particle.position = CGPoint(
            x: position.x + CGFloat.random(in: -10...10),
            y: position.y + CGFloat.random(in: -10...10)
        )
        particle.zPosition = 47

        let moveUp = SKAction.moveBy(x: CGFloat.random(in: -5...5), y: 20, duration: 0.5)
        let fade = SKAction.fadeOut(withDuration: 0.5)
        let group = SKAction.group([moveUp, fade])
        let remove = SKAction.removeFromParent()
        particle.run(SKAction.sequence([group, remove]))

        particleLayer.addChild(particle)
    }

    /// Create orbiting frost crystals for slowed enemies
    func createFrostCrystals(enemySize: CGFloat) -> SKNode {
        let container = SKNode()
        container.zPosition = 50

        let crystalCount = 4
        let orbitRadius = enemySize * 0.9
        let crystalSize: CGFloat = 4

        for i in 0..<crystalCount {
            // Create diamond-shaped ice crystal
            let crystal = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: crystalSize))
            path.addLine(to: CGPoint(x: crystalSize * 0.6, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -crystalSize))
            path.addLine(to: CGPoint(x: -crystalSize * 0.6, y: 0))
            path.closeSubpath()
            crystal.path = path

            crystal.fillColor = UIColor.cyan.withAlphaComponent(0.7)
            crystal.strokeColor = UIColor.white.withAlphaComponent(0.9)
            crystal.lineWidth = 1
            crystal.glowWidth = 0  // PERF: was 3 (GPU Gaussian blur)
            crystal.blendMode = .add

            // Position in orbit
            let startAngle = CGFloat(i) * (2 * .pi / CGFloat(crystalCount))
            crystal.position = CGPoint(
                x: cos(startAngle) * orbitRadius,
                y: sin(startAngle) * orbitRadius
            )
            crystal.zRotation = startAngle

            container.addChild(crystal)
        }

        // Slow orbital rotation (3 seconds per revolution)
        let rotate = SKAction.repeatForever(SKAction.rotate(byAngle: 2 * .pi, duration: 3.0))
        container.run(rotate, withKey: "frostOrbit")

        return container
    }

    /// Create damage overlay for low health enemies (glitch effect)
    func createDamageOverlay(enemySize: CGFloat) -> SKNode {
        let container = SKNode()
        container.zPosition = 49

        // Semi-transparent red overlay
        let overlay = SKShapeNode(circleOfRadius: enemySize * 0.6)
        overlay.fillColor = UIColor.red.withAlphaComponent(0.2)
        overlay.strokeColor = UIColor.red.withAlphaComponent(0.5)
        overlay.lineWidth = 1
        overlay.glowWidth = 0  // PERF: was 4 (GPU Gaussian blur)
        overlay.blendMode = .add
        container.addChild(overlay)

        // Glitch jitter animation (±2px every 0.3s)
        let glitch = SKAction.repeatForever(SKAction.sequence([
            SKAction.run {
                container.position = CGPoint(
                    x: CGFloat.random(in: -2...2),
                    y: CGFloat.random(in: -2...2)
                )
                overlay.alpha = CGFloat.random(in: 0.3...0.7)
            },
            SKAction.wait(forDuration: TimeInterval.random(in: 0.15...0.35)),
            SKAction.run {
                container.position = .zero
            },
            SKAction.wait(forDuration: TimeInterval.random(in: 0.2...0.4))
        ]))
        container.run(glitch, withKey: "damageGlitch")

        // Flickering pulse
        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.8, duration: 0.15),
            SKAction.fadeAlpha(to: 0.4, duration: 0.15)
        ]))
        overlay.run(pulse, withKey: "damagePulse")

        return container
    }
}
