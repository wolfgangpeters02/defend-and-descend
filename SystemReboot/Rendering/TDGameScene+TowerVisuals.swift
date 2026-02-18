import SpriteKit
import SwiftUI

// MARK: - Tower Visual Updates

extension TDGameScene {

    func updateTowerVisuals(state: TDGameState) {
        // Remove old tower nodes (Set lookup: O(1) per node)
        let activeTowerIds = Set(state.towers.map { $0.id })
        for (id, node) in towerNodes where !activeTowerIds.contains(id) {
            node.removeFromParent()
            towerNodes.removeValue(forKey: id)
            towerNodeRefs.removeValue(forKey: id)
            towerLastAttackTimes.removeValue(forKey: id)
            towerBarrelRotations.removeValue(forKey: id)
            pausedTowerAnimations.remove(id)  // Clean up animation LOD tracking
        }

        // Performance: calculate visible rect once to skip off-screen tower updates
        let towerVisibleRect = calculateVisibleRect().insetBy(dx: -120, dy: -120)

        // Update/create tower nodes
        for tower in state.towers {
            if let node = towerNodes[tower.id] {
                // Update existing
                node.position = convertToScene(tower.position)

                // Skip expensive visual updates for off-screen towers
                guard towerVisibleRect.contains(node.position) || tower.id == selectedTowerId else {
                    towerLastAttackTimes[tower.id] = tower.lastAttackTime
                    continue
                }

                // Get or build cached refs
                var refs = towerNodeRefs[tower.id] ?? TowerNodeRefs()

                // Update range indicator visibility with lazy creation
                let shouldShowRange = tower.id == selectedTowerId || isDragging
                if shouldShowRange {
                    // Lazily create range indicator on first need
                    if refs.rangeNode == nil {
                        let towerColor = UIColor(hex: tower.color) ?? TowerColors.color(for: tower.protocolId)
                        let rangeIndicator = TowerVisualFactory.createRangeIndicator(range: tower.effectiveRange, color: towerColor)
                        rangeIndicator.name = "range"
                        rangeIndicator.isHidden = true
                        rangeIndicator.zPosition = -2  // Below tower body but above background (effective: 4-2=2)
                        node.addChild(rangeIndicator)
                        refs.rangeNode = rangeIndicator
                    }
                    if let rangeNode = refs.rangeNode, rangeNode.isHidden {
                        TowerAnimations.showRange(node: node, animated: true)
                    }
                } else if let rangeNode = refs.rangeNode, !rangeNode.isHidden {
                    TowerAnimations.hideRange(node: node, animated: true)
                }

                // Update rotation (barrel points to target) - Smooth interpolation
                // Use cached barrel ref, falling back to lookup if needed
                if refs.barrel == nil {
                    refs.barrel = node.childNode(withName: "barrel")
                }
                if let barrel = refs.barrel {
                    let targetRotation = tower.rotation - .pi/2

                    // Get current tracked rotation, or initialize from node
                    let currentRotation = towerBarrelRotations[tower.id] ?? barrel.zRotation

                    // Calculate angle difference (normalized to -pi to pi)
                    var angleDiff = targetRotation - currentRotation
                    while angleDiff > .pi { angleDiff -= 2 * .pi }
                    while angleDiff < -.pi { angleDiff += 2 * .pi }

                    // Calculate maximum rotation this frame (based on deltaTime if available, else assume 1/60)
                    let deltaTime = lastUpdateTime > 0 ? (state.gameTime - (towerLastAttackTimes[tower.id] ?? state.gameTime - 1/60)) : 1/60
                    let maxDelta = barrelRotationSpeed * CGFloat(abs(deltaTime) > 0 ? min(abs(deltaTime), 0.1) : 1/60)

                    // Clamp rotation to max speed
                    let actualDelta: CGFloat
                    if abs(angleDiff) <= maxDelta {
                        actualDelta = angleDiff  // Snap if close enough
                    } else {
                        actualDelta = angleDiff > 0 ? maxDelta : -maxDelta
                    }

                    let newRotation = currentRotation + actualDelta
                    barrel.zRotation = newRotation
                    towerBarrelRotations[tower.id] = newRotation
                }

                // Update level indicator if level changed (cached ref)
                if refs.levelLabel == nil {
                    if let levelNode = node.childNode(withName: "levelIndicator") {
                        refs.levelLabel = levelNode.childNode(withName: "levelLabel") as? SKLabelNode
                    }
                }
                if let levelLabel = refs.levelLabel {
                    if levelLabel.text != "\(tower.level)" {
                        levelLabel.text = "\(tower.level)"
                    }
                }

                // Update star indicator if star level changed
                if tower.starLevel > 0 {
                    if refs.starIndicator == nil {
                        // No star indicator yet — create one
                        let towerColor = UIColor(hex: tower.color) ?? TowerColors.color(for: tower.protocolId)
                        let starIndicator = TowerVisualFactory.createStarIndicator(starLevel: tower.starLevel, color: towerColor)
                        starIndicator.name = "starIndicator"
                        starIndicator.position = CGPoint(x: 0, y: -38)
                        starIndicator.zPosition = 25
                        node.addChild(starIndicator)
                        refs.starIndicator = starIndicator
                    } else if let existing = refs.starIndicator {
                        // Check if star label text changed
                        let expectedStars = String(repeating: "\u{2605}", count: tower.starLevel)
                        let currentLabel = existing.childNode(withName: "starChar") as? SKLabelNode
                        if currentLabel?.text != expectedStars {
                            existing.removeFromParent()
                            let towerColor = UIColor(hex: tower.color) ?? TowerColors.color(for: tower.protocolId)
                            let starIndicator = TowerVisualFactory.createStarIndicator(starLevel: tower.starLevel, color: towerColor)
                            starIndicator.name = "starIndicator"
                            starIndicator.position = CGPoint(x: 0, y: -38)
                            starIndicator.zPosition = 25
                            node.addChild(starIndicator)
                            refs.starIndicator = starIndicator
                        }
                    }
                } else if let existing = refs.starIndicator {
                    // Star level is 0 but indicator exists — clean up
                    existing.removeFromParent()
                    refs.starIndicator = nil
                }

                // Save refs before cooldown arc (which may lazily create the cooldown node)
                towerNodeRefs[tower.id] = refs

                // Update cooldown arc (lazy creation inside)
                updateCooldownArc(for: tower, node: node, currentTime: state.gameTime)

                // Detect firing (lastAttackTime changed) and trigger animation
                if let prevAttackTime = towerLastAttackTimes[tower.id] {
                    if tower.lastAttackTime > prevAttackTime {
                        triggerTowerFireAnimation(node: node, tower: tower)
                        AudioManager.shared.playTowerFire(protocolId: tower.protocolId, at: tower.position)
                    }
                }
                towerLastAttackTimes[tower.id] = tower.lastAttackTime

            } else {
                // Create new tower node
                let node = createTowerNode(tower: tower)
                node.position = convertToScene(tower.position)
                towerLayer.addChild(node)
                towerNodes[tower.id] = node

                // Populate cached refs from the freshly created node
                var refs = TowerNodeRefs()
                refs.barrel = node.childNode(withName: "barrel")
                refs.glowNode = node.childNode(withName: "glow")
                if let levelNode = node.childNode(withName: "levelIndicator") {
                    refs.levelLabel = levelNode.childNode(withName: "levelLabel") as? SKLabelNode
                }
                // rangeNode, cooldownNode, lodDetail are nil — created lazily on first need
                towerNodeRefs[tower.id] = refs

                // Spawn placement particles
                spawnPlacementParticles(at: convertToScene(tower.position), color: UIColor(hex: tower.color) ?? .blue)

                // Haptic feedback
                HapticsService.shared.play(.towerPlace)
            }
        }
    }

    /// Trigger tower firing animation (recoil + muzzle flash)
    func triggerTowerFireAnimation(node: SKNode, tower: Tower) {
        let towerColor = UIColor(hex: tower.color) ?? TowerColors.color(for: tower.protocolId)
        let archetype = TowerVisualFactory.TowerArchetype.from(protocolId: tower.protocolId)

        // Use enhanced archetype-specific muzzle flash
        TowerAnimations.playEnhancedMuzzleFlash(node: node, archetype: archetype, color: towerColor)
        TowerAnimations.playRecoil(node: node, intensity: archetype == .payload ? 5.0 : 3.0)

        // Special effects for certain archetypes
        switch archetype {
        case .exception:
            // Null pointer glitch effect — probability gate (fires ~30% of shots)
            if RandomUtils.randomBool(probability: 0.3) {
                TowerAnimations.playExecuteEffect(node: node)
            }
        case .rootkit:
            // Sustained beam flash from barrel toward target direction
            TowerAnimations.playBeamLine(
                node: node,
                color: towerColor,
                range: tower.effectiveRange,
                rotation: tower.rotation
            )
        case .overload:
            // Overload arc flash handled by idle animation
            break
        default:
            break
        }

        // Glow intensify on fire
        if let glow = node.childNode(withName: "glow") {
            glow.removeAction(forKey: "fireGlow")
            let intensify = SKAction.group([
                SKAction.scale(to: 1.3, duration: 0.05),
                SKAction.fadeAlpha(to: 1.3, duration: 0.05)
            ])
            let restore = SKAction.group([
                SKAction.scale(to: 1.0, duration: 0.15),
                SKAction.fadeAlpha(to: 1.0, duration: 0.15)
            ])
            restore.timingMode = .easeOut
            glow.run(SKAction.sequence([intensify, restore]), withKey: "fireGlow")
        }

        // Motherboard-specific effects
        if isMotherboardMap {
            let towerPos = CGPoint(x: tower.x, y: tower.y)

            // Trigger capacitor discharge if tower is in PSU sector area
            triggerCapacitorDischarge(near: convertToScene(towerPos))

        }
    }

    /// Cached cooldown progress per tower to avoid redundant arc path rebuilds
    private static var cachedCooldownProgress: [String: CGFloat] = [:]

    /// Clear static caches on scene teardown to prevent stale data across sessions
    static func resetCaches() {
        cachedCooldownProgress.removeAll()
    }

    /// Update cooldown arc indicator on tower (cached refs + lazy creation + arc path caching)
    func updateCooldownArc(for tower: Tower, node: SKNode, currentTime: TimeInterval) {
        // Guard against invalid attack speed (prevents NaN/Infinity angles)
        guard tower.effectiveAttackSpeed > 0 else {
            // Hide if it exists
            if let refs = towerNodeRefs[tower.id], let cooldownNode = refs.cooldownNode {
                cooldownNode.isHidden = true
            }
            return
        }

        let attackInterval = 1.0 / tower.effectiveAttackSpeed
        let timeSinceAttack = currentTime - tower.lastAttackTime
        let cooldownProgress = min(1.0, max(0.0, timeSinceAttack / attackInterval))

        // Guard against NaN progress values
        guard cooldownProgress.isFinite else {
            if let refs = towerNodeRefs[tower.id], let cooldownNode = refs.cooldownNode {
                cooldownNode.isHidden = true
            }
            return
        }

        if cooldownProgress < 1.0 && cooldownProgress > 0.0 {
            // Lazily create cooldown node on first need
            var refs = towerNodeRefs[tower.id] ?? TowerNodeRefs()
            if refs.cooldownNode == nil {
                let towerColor = UIColor(hex: tower.color) ?? TowerColors.color(for: tower.protocolId)
                let cooldownArc = TowerVisualFactory.createCooldownArc(color: towerColor)
                cooldownArc.name = "cooldown"
                cooldownArc.isHidden = true
                cooldownArc.zPosition = 5
                node.addChild(cooldownArc)
                refs.cooldownNode = cooldownArc
                towerNodeRefs[tower.id] = refs
            }

            guard let cooldownNode = refs.cooldownNode else { return }
            cooldownNode.isHidden = false

            // Only rebuild arc path when progress changes by a visible amount (~2% arc step)
            let lastProgress = Self.cachedCooldownProgress[tower.id] ?? -1
            if abs(cooldownProgress - lastProgress) > 0.02 {
                Self.cachedCooldownProgress[tower.id] = cooldownProgress

                let radius: CGFloat = 18
                let startAngle = -CGFloat.pi / 2
                let endAngle = startAngle + (CGFloat.pi * 2 * CGFloat(cooldownProgress))

                let path = UIBezierPath(arcCenter: .zero, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                cooldownNode.path = path.cgPath
            }
        } else {
            if let refs = towerNodeRefs[tower.id], let cooldownNode = refs.cooldownNode {
                cooldownNode.isHidden = true
            }
            Self.cachedCooldownProgress.removeValue(forKey: tower.id)
        }
    }

    /// Spawn particles when tower is placed
    func spawnPlacementParticles(at position: CGPoint, color: UIColor) {
        let particleCount = 12

        for i in 0..<particleCount {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...4))
            particle.fillColor = color
            particle.strokeColor = .white
            particle.lineWidth = 1
            particle.position = position
            particle.zPosition = 50

            let angle = CGFloat(i) * (.pi * 2 / CGFloat(particleCount))
            let distance: CGFloat = 40

            let moveAction = SKAction.move(by: CGVector(dx: cos(angle) * distance, dy: sin(angle) * distance), duration: 0.3)
            moveAction.timingMode = .easeOut
            let fadeAction = SKAction.fadeOut(withDuration: 0.3)
            let group = SKAction.group([moveAction, fadeAction])
            let sequence = SKAction.sequence([group, SKAction.removeFromParent()])

            particle.run(sequence)
            particleLayer.addChild(particle)
        }
    }

    func createTowerNode(tower: Tower) -> SKNode {
        // Use the new AAA Tower Visual Factory for rich, multi-layered visuals
        let towerColor = UIColor(hex: tower.color) ?? TowerColors.color(for: tower.protocolId)
        let rarityString: String
        switch tower.rarity {
        case .common: rarityString = "common"
        case .rare: rarityString = "rare"
        case .epic: rarityString = "epic"
        case .legendary: rarityString = "legendary"
        }

        return TowerVisualFactory.createTowerNode(
            protocolId: tower.protocolId,
            color: towerColor,
            range: tower.effectiveRange,
            level: tower.level,
            starLevel: tower.starLevel,
            damage: tower.effectiveDamage,
            attackSpeed: tower.effectiveAttackSpeed,
            projectileCount: tower.projectileCount,
            rarity: rarityString
        )
    }
}
