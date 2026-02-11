import SpriteKit
import SwiftUI

extension TDGameScene {

    // MARK: - Scrolling Combat Text

    func renderDamageEvents(state: inout TDGameState) {
        // Process and display new damage events
        for i in 0..<state.damageEvents.count {
            guard !state.damageEvents[i].displayed else { continue }

            let event = state.damageEvents[i]

            // Convert game position to scene position
            let scenePosition = convertToScene(event.position)

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
                combatText.show("IMMUNE", type: .shield, at: scenePosition)
            }

            state.damageEvents[i].displayed = true
        }

        // Clean up old damage events (older than 2 seconds)
        state.damageEvents.removeAll { state.gameTime - $0.timestamp > 2.0 }
    }

    // MARK: - Visual Updates

    func updateTowerVisuals(state: TDGameState) {
        // Remove old tower nodes
        for (id, node) in towerNodes {
            if !state.towers.contains(where: { $0.id == id }) {
                node.removeFromParent()
                towerNodes.removeValue(forKey: id)
                towerLastAttackTimes.removeValue(forKey: id)
                towerBarrelRotations.removeValue(forKey: id)
                pausedTowerAnimations.remove(id)  // Clean up animation LOD tracking
            }
        }

        // Update/create tower nodes
        for tower in state.towers {
            if let node = towerNodes[tower.id] {
                // Update existing
                node.position = convertToScene(tower.position)

                // Update range indicator visibility with animation
                let shouldShowRange = tower.id == selectedTowerId || isDragging
                if let rangeNode = node.childNode(withName: "range") {
                    if shouldShowRange && rangeNode.isHidden {
                        TowerAnimations.showRange(node: node, animated: true)
                    } else if !shouldShowRange && !rangeNode.isHidden {
                        TowerAnimations.hideRange(node: node, animated: true)
                    }
                }

                // Update rotation (barrel points to target) - Smooth interpolation
                if let barrel = node.childNode(withName: "barrel") {
                    let targetRotation = tower.rotation - .pi/2

                    // Get current tracked rotation, or initialize from node
                    let currentRotation = towerBarrelRotations[tower.id] ?? barrel.zRotation

                    // Calculate angle difference (normalized to -π to π)
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

                // Update level indicator if level changed
                if let levelNode = node.childNode(withName: "levelIndicator") {
                    if let levelLabel = levelNode.childNode(withName: "levelLabel") as? SKLabelNode {
                        if levelLabel.text != "\(tower.level)" {
                            levelLabel.text = "\(tower.level)"
                        }
                    }
                }

                // Update cooldown arc
                updateCooldownArc(for: tower, node: node, currentTime: state.gameTime)

                // Detect firing (lastAttackTime changed) and trigger animation
                if let prevAttackTime = towerLastAttackTimes[tower.id] {
                    if tower.lastAttackTime > prevAttackTime {
                        triggerTowerFireAnimation(node: node, tower: tower)
                    }
                }
                towerLastAttackTimes[tower.id] = tower.lastAttackTime

            } else {
                // Create new tower node
                let node = createTowerNode(tower: tower)
                node.position = convertToScene(tower.position)
                towerLayer.addChild(node)
                towerNodes[tower.id] = node

                // Spawn placement particles
                spawnPlacementParticles(at: convertToScene(tower.position), color: UIColor(hex: tower.color) ?? .blue)

                // Haptic feedback
                HapticsService.shared.play(.towerPlace)
            }
        }
    }

    /// Trigger tower firing animation (recoil + muzzle flash)
    func triggerTowerFireAnimation(node: SKNode, tower: Tower) {
        let towerColor = UIColor(hex: tower.color) ?? TowerColors.color(for: tower.weaponType)
        let archetype = TowerVisualFactory.TowerArchetype.from(weaponType: tower.weaponType)

        // Use enhanced archetype-specific muzzle flash
        TowerAnimations.playEnhancedMuzzleFlash(node: node, archetype: archetype, color: towerColor)
        TowerAnimations.playRecoil(node: node, intensity: archetype == .artillery ? 5.0 : 3.0)

        // Special effects for certain archetypes
        switch archetype {
        case .legendary:
            // Excalibur golden flash on attack
            if Bool.random() && Bool.random() {  // ~25% chance for special effect
                TowerAnimations.playLegendarySpecialEffect(node: node)
            }
        case .execute:
            // Null pointer glitch effect
            TowerAnimations.playExecuteEffect(node: node)
        case .tesla:
            // Tesla arc flash handled by idle animation
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

            // NOTE: Trace pulses removed - lanes should only have LEDs
            // let towerColor = UIColor(hex: tower.color) ?? UIColor.yellow
            // spawnTracePulse(at: towerPos, color: towerColor)
        }
    }

    /// Update cooldown arc indicator on tower
    func updateCooldownArc(for tower: Tower, node: SKNode, currentTime: TimeInterval) {
        guard let cooldownNode = node.childNode(withName: "cooldown") as? SKShapeNode else { return }

        // Guard against invalid attack speed (prevents NaN/Infinity angles)
        guard tower.attackSpeed > 0 else {
            cooldownNode.isHidden = true
            return
        }

        let attackInterval = 1.0 / tower.attackSpeed
        let timeSinceAttack = currentTime - tower.lastAttackTime
        let cooldownProgress = min(1.0, max(0.0, timeSinceAttack / attackInterval))

        // Guard against NaN progress values
        guard cooldownProgress.isFinite else {
            cooldownNode.isHidden = true
            return
        }

        if cooldownProgress < 1.0 && cooldownProgress > 0.0 {
            // Show and update cooldown arc
            cooldownNode.isHidden = false

            let radius: CGFloat = 18
            let startAngle = -CGFloat.pi / 2
            let endAngle = startAngle + (CGFloat.pi * 2 * CGFloat(cooldownProgress))

            let path = UIBezierPath(arcCenter: .zero, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            cooldownNode.path = path.cgPath
        } else {
            cooldownNode.isHidden = true
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
        let towerColor = UIColor(hex: tower.color) ?? TowerColors.color(for: tower.weaponType)
        let rarityString: String
        switch tower.rarity {
        case .common: rarityString = "common"
        case .rare: rarityString = "rare"
        case .epic: rarityString = "epic"
        case .legendary: rarityString = "legendary"
        }

        return TowerVisualFactory.createTowerNode(
            weaponType: tower.weaponType,
            color: towerColor,
            range: tower.range,
            level: tower.level,
            damage: tower.damage,
            attackSpeed: tower.attackSpeed,
            projectileCount: tower.projectileCount,
            rarity: rarityString
        )
    }

    /// Update Level of Detail visibility based on camera zoom and viewport culling
    func updateTowerLOD() {
        // Show details when zoomed in (scale < 0.4 means close-up)
        let showDetail = currentScale < 0.4
        let targetAlpha: CGFloat = showDetail ? 1.0 : 0.0

        // Calculate visible rect once for performance
        let visibleRect = calculateVisibleRect()
        // Expand rect slightly to avoid animation pop-in at edges
        let paddedRect = visibleRect.insetBy(dx: -100, dy: -100)

        for (towerId, node) in towerNodes {
            // LOD detail visibility based on zoom
            if let lodDetail = node.childNode(withName: "lodDetail") {
                // Only animate if needed
                if abs(lodDetail.alpha - targetAlpha) > 0.01 {
                    lodDetail.removeAction(forKey: "lodFade")
                    let fadeAction = SKAction.fadeAlpha(to: targetAlpha, duration: 0.2)
                    lodDetail.run(fadeAction, withKey: "lodFade")
                }
            }

            // Animation LOD: Pause animations for off-screen towers
            let isVisible = paddedRect.contains(node.position)

            if isVisible && pausedTowerAnimations.contains(towerId) {
                // Tower came into view - resume animations
                node.isPaused = false
                pausedTowerAnimations.remove(towerId)
            } else if !isVisible && !pausedTowerAnimations.contains(towerId) {
                // Tower went off-screen - pause animations
                node.isPaused = true
                pausedTowerAnimations.insert(towerId)
            }
        }
    }

    /// Calculate the visible rectangle in scene coordinates
    func calculateVisibleRect() -> CGRect {
        guard let camera = cameraNode, let view = self.view else {
            return CGRect(x: 0, y: 0, width: size.width, height: size.height)
        }

        let viewWidth = view.bounds.width * currentScale
        let viewHeight = view.bounds.height * currentScale

        return CGRect(
            x: camera.position.x - viewWidth / 2,
            y: camera.position.y - viewHeight / 2,
            width: viewWidth,
            height: viewHeight
        )
    }

    // MARK: - Sector Visibility Culling (Performance)

    /// Update which sectors are visible and pause/resume ambient effects accordingly
    func updateSectorVisibility(currentTime: TimeInterval) {
        // Only update every 0.5 seconds to avoid per-frame overhead
        guard currentTime - lastVisibilityUpdate >= visibilityUpdateInterval else { return }
        lastVisibilityUpdate = currentTime

        let visibleRect = calculateVisibleRect()
        // Expand rect to include sectors partially visible (sector size is 1400)
        let paddedRect = visibleRect.insetBy(dx: -700, dy: -700)

        let megaConfig = MegaBoardConfig.createDefault()
        var newVisibleSectors = Set<String>()

        for sector in megaConfig.sectors {
            let sectorRect = CGRect(
                x: sector.worldX,
                y: sector.worldY,
                width: sector.width,
                height: sector.height
            )

            if paddedRect.intersects(sectorRect) {
                newVisibleSectors.insert(sector.id)
            }
        }

        // Resume effects for sectors that came into view
        let sectorsNowVisible = newVisibleSectors.subtracting(visibleSectorIds)
        for sectorId in sectorsNowVisible {
            resumeSectorAmbientEffects(sectorId: sectorId)
        }

        // Pause effects for sectors that went out of view
        let sectorsNowHidden = visibleSectorIds.subtracting(newVisibleSectors)
        for sectorId in sectorsNowHidden {
            pauseSectorAmbientEffects(sectorId: sectorId)
        }

        visibleSectorIds = newVisibleSectors
    }

    /// Pause ambient effect actions for a sector
    func pauseSectorAmbientEffects(sectorId: String) {
        // Each sector has actions with keys like "gpuHeat_gpu", "ramPulse_ram", etc.
        let actionKeys = [
            "gpuHeat_\(sectorId)",
            "ramPulse_\(sectorId)",
            "storageTrail_\(sectorId)",
            "networkRings_\(sectorId)",
            "ioBurst_\(sectorId)",
            "cacheFlash_\(sectorId)",
            "cacheLines_\(sectorId)"
        ]

        for key in actionKeys {
            backgroundLayer.removeAction(forKey: key)
        }
    }

    /// Resume ambient effect actions for a sector (re-start them)
    func resumeSectorAmbientEffects(sectorId: String) {
        guard let sector = MegaBoardConfig.createDefault().sectors.first(where: { $0.id == sectorId }) else { return }

        // Re-start the appropriate ambient effects based on sector theme
        switch sector.theme {
        case .graphics:
            // GPU: Re-add heat shimmer spawning
            let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .red
            let center = CGPoint(x: sector.worldX + sector.width / 2, y: sector.worldY + sector.height / 2)
            let spawnShimmer = SKAction.run { [weak self] in
                guard let self = self else { return }
                self.spawnHeatShimmer(at: center, color: themeColor)
            }
            let shimmerSequence = SKAction.repeatForever(SKAction.sequence([
                spawnShimmer,
                SKAction.wait(forDuration: 0.15)
            ]))
            backgroundLayer.run(shimmerSequence, withKey: "gpuHeat_\(sectorId)")

        case .memory:
            // RAM: Re-add data pulse
            let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .green
            startRAMDataPulse(sector: sector, color: themeColor)

        case .storage:
            // Storage: Re-add data trail
            let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .purple
            startStorageDataTrail(sector: sector, color: themeColor)

        case .network:
            // Network: Re-add signal rings
            startNetworkSectorAmbient(sector: sector)

        case .io:
            // I/O: Re-add data bursts
            let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .orange
            startIODataBurst(sector: sector, color: themeColor)

        case .processing:
            // Cache: Re-add flash and speed lines
            startCacheSectorAmbient(sector: sector)

        case .power:
            // PSU has minimal effects, nothing to resume
            break
        }
    }

    // MARK: - Deprecated Tower Methods (Now handled by TowerVisualFactory)
    // The following methods have been replaced by TowerVisualFactory.swift:
    // - createWeaponBody() -> TowerVisualFactory.createTowerBody()
    // - createWeaponBarrel() -> TowerVisualFactory.createTowerBarrel()
    // - createMergeStars() -> TowerVisualFactory.createMergeIndicator()

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
        // Zero-Day: deep purple with white corona
        // Boss: white with warning glow
        // Tank: purple (tier 3)
        // Fast: orange (tier 2)
        // Basic: red (tier 1)
        let virusColor: UIColor
        if enemy.isZeroDay {
            virusColor = DesignColors.zeroDayVirusUI
        } else if enemy.isBoss {
            virusColor = DesignColors.enemyTier4UI
        } else {
            switch enemy.type {
            case "tank":
                virusColor = DesignColors.enemyTier3UI  // Purple
            case "fast":
                virusColor = DesignColors.enemyTier2UI  // Orange
            default:
                virusColor = DesignColors.enemyTier1UI  // Red
            }
        }

        // Virus body - hexagonal shape for tech aesthetic
        let body: SKShapeNode
        switch enemy.shape {
        case "triangle":
            // Triangle virus - fast/small
            let path = UIBezierPath()
            let size = enemy.size
            path.move(to: CGPoint(x: 0, y: size))
            path.addLine(to: CGPoint(x: -size * 0.866, y: -size/2))
            path.addLine(to: CGPoint(x: size * 0.866, y: -size/2))
            path.close()
            body = SKShapeNode(path: path.cgPath)
        case "hexagon":
            // Hexagon virus - standard
            body = SKShapeNode(path: createHexagonPath(radius: enemy.size))
        case "diamond":
            // Diamond virus - armored
            body = SKShapeNode(path: createDiamondPath(size: enemy.size * 2))
        default:
            // Default hexagon virus
            body = SKShapeNode(path: createHexagonPath(radius: enemy.size))
        }

        body.fillColor = virusColor.withAlphaComponent(0.85)
        body.strokeColor = enemy.isBoss ? DesignColors.warningUI : virusColor
        body.lineWidth = enemy.isBoss ? 3 : 2
        body.glowWidth = enemy.isBoss ? 6 : 3
        body.name = "body"
        container.addChild(body)

        // Inner detail - digital corruption pattern
        let innerSize = enemy.size * 0.5
        let innerPath = createHexagonPath(radius: innerSize)
        let innerNode = SKShapeNode(path: innerPath)
        innerNode.fillColor = UIColor.black.withAlphaComponent(0.3)
        innerNode.strokeColor = virusColor.withAlphaComponent(0.8)
        innerNode.lineWidth = 1
        container.addChild(innerNode)

        // Boss effects - different for Zero-Day vs regular boss
        if enemy.isZeroDay {
            // Zero-Day: Deep purple with white corona effect
            body.glowWidth = 15
            body.strokeColor = UIColor.white

            // Add white corona/ring effect
            let corona = SKShapeNode(circleOfRadius: enemy.size * 1.3)
            corona.strokeColor = UIColor.white.withAlphaComponent(0.6)
            corona.fillColor = .clear
            corona.lineWidth = 2
            corona.glowWidth = 10
            corona.zPosition = -1
            container.addChild(corona)

            // Corona pulse animation
            let coronaPulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 0.6),
                SKAction.fadeAlpha(to: 0.8, duration: 0.6)
            ])
            corona.run(SKAction.repeatForever(coronaPulse))

            // Zero-Day indicator
            let zeroDayLabel = SKLabelNode(text: L10n.ZeroDay.indicator)
            zeroDayLabel.fontName = "Menlo-Bold"
            zeroDayLabel.fontSize = 10
            zeroDayLabel.fontColor = DesignColors.zeroDayVirusUI
            zeroDayLabel.position = CGPoint(x: 0, y: enemy.size + 20)
            zeroDayLabel.name = "bossIndicator"
            container.addChild(zeroDayLabel)

            // Menacing slow rotation
            let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 6.0)
            body.run(SKAction.repeatForever(rotate))

        } else if enemy.immuneToTowers && enemy.isBoss {
            // Super Virus: TD boss immune to towers - orange/red with shield effect
            body.glowWidth = 15
            body.strokeColor = UIColor.orange

            // Super Virus indicator (top)
            let superVirusLabel = SKLabelNode(text: L10n.Enemy.superVirusIndicator)
            superVirusLabel.fontName = "Menlo-Bold"
            superVirusLabel.fontSize = 12
            superVirusLabel.fontColor = .orange
            superVirusLabel.position = CGPoint(x: 0, y: enemy.size + 28)
            superVirusLabel.name = "bossIndicator"
            container.addChild(superVirusLabel)

            // Immune indicator (below super virus label)
            let immuneLabel = SKLabelNode(text: L10n.Enemy.immuneToTowers)
            immuneLabel.fontName = "Menlo-Bold"
            immuneLabel.fontSize = 9
            immuneLabel.fontColor = UIColor.cyan
            immuneLabel.position = CGPoint(x: 0, y: enemy.size + 16)
            immuneLabel.name = "immuneIndicator"
            container.addChild(immuneLabel)

            // Shield ring effect (shows immunity)
            let shieldRing = SKShapeNode(circleOfRadius: enemy.size * 1.4)
            shieldRing.strokeColor = UIColor.orange.withAlphaComponent(0.7)
            shieldRing.fillColor = .clear
            shieldRing.lineWidth = 3
            shieldRing.glowWidth = 8
            shieldRing.zPosition = -1
            shieldRing.name = "shieldRing"
            container.addChild(shieldRing)

            // Shield pulse animation
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

            // Color cycle between red and orange
            let colorCycle = SKAction.sequence([
                SKAction.colorize(with: .red, colorBlendFactor: 0.6, duration: 0.6),
                SKAction.colorize(with: .orange, colorBlendFactor: 0.6, duration: 0.6)
            ])
            body.run(SKAction.repeatForever(colorCycle))

            // Slow menacing pulse
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.1, duration: 0.6),
                SKAction.scale(to: 0.95, duration: 0.6)
            ])
            body.run(SKAction.repeatForever(pulse), withKey: "bossPulse")

            // Rotation for inner detail
            let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 5.0)
            innerNode.run(SKAction.repeatForever(rotate))

        } else if enemy.isBoss {
            // Regular boss: White with warning glow and color cycle
            body.glowWidth = 10

            // Boss indicator
            let bossLabel = SKLabelNode(text: L10n.Enemy.bossIndicator)
            bossLabel.fontName = "Menlo-Bold"
            bossLabel.fontSize = 10
            bossLabel.fontColor = DesignColors.warningUI
            bossLabel.position = CGPoint(x: 0, y: enemy.size + 16)
            bossLabel.name = "bossIndicator"
            container.addChild(bossLabel)

            // Color cycle effect for boss
            let colorCycle = SKAction.sequence([
                SKAction.colorize(with: .red, colorBlendFactor: 0.5, duration: 0.5),
                SKAction.colorize(with: .orange, colorBlendFactor: 0.5, duration: 0.5),
                SKAction.colorize(with: .yellow, colorBlendFactor: 0.5, duration: 0.5),
                SKAction.colorize(with: .white, colorBlendFactor: 0.0, duration: 0.5)
            ])
            body.run(SKAction.repeatForever(colorCycle))

            // Menacing pulse animation
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.15, duration: 0.4),
                SKAction.scale(to: 0.95, duration: 0.4)
            ])
            body.run(SKAction.repeatForever(pulse), withKey: "bossPulse")

            // Rotation for boss inner
            let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 4.0)
            innerNode.run(SKAction.repeatForever(rotate))
        }

        // Slow effect overlay (ice blue, hidden by default)
        let slowOverlay = SKShapeNode(circleOfRadius: enemy.size * 0.9)
        slowOverlay.fillColor = DesignColors.primaryUI.withAlphaComponent(0.2)
        slowOverlay.strokeColor = DesignColors.primaryUI.withAlphaComponent(0.5)
        slowOverlay.lineWidth = 2
        slowOverlay.name = "slowOverlay"
        slowOverlay.isHidden = true
        container.addChild(slowOverlay)

        // Health bar background - dark
        let healthBarWidth = enemy.size * 1.5
        let healthBg = SKSpriteNode(color: DesignColors.backgroundUI.withAlphaComponent(0.8), size: CGSize(width: healthBarWidth + 2, height: 5))
        healthBg.position = CGPoint(x: 0, y: enemy.size + 8)
        container.addChild(healthBg)

        // Health bar - red for virus health
        let healthBar = SKSpriteNode(color: virusColor, size: CGSize(width: healthBarWidth, height: 3))
        healthBar.anchorPoint = CGPoint(x: 0, y: 0.5)
        healthBar.position = CGPoint(x: -healthBarWidth / 2, y: enemy.size + 8)
        healthBar.name = "healthBar"
        container.addChild(healthBar)

        return container
    }

    func updateEnemyVisuals(state: TDGameState) {
        // Track enemies to remove
        var enemiesToRemove: [String] = []

        // Remove old enemy nodes with death animation
        for (id, node) in enemyNodes {
            if !state.enemies.contains(where: { $0.id == id && !$0.isDead }) {
                enemiesToRemove.append(id)
            }
        }

        for id in enemiesToRemove {
            if let node = enemyNodes[id] {
                // Death animation
                let shrink = SKAction.scale(to: 0.1, duration: 0.2)
                let fade = SKAction.fadeOut(withDuration: 0.2)
                let group = SKAction.group([shrink, fade])
                let remove = SKAction.removeFromParent()
                node.run(SKAction.sequence([group, remove]))
                enemyNodes.removeValue(forKey: id)
            }
        }

        // Update/create enemy nodes
        for enemy in state.enemies {
            if enemy.isDead || enemy.reachedCore { continue }

            if let node = enemyNodes[enemy.id] {
                // Update position
                node.position = convertToScene(enemy.position)

                // Update health bar
                if let healthBar = node.childNode(withName: "healthBar") as? SKSpriteNode {
                    let healthPercent = enemy.health / enemy.maxHealth
                    healthBar.xScale = healthPercent

                    // Color based on health
                    if healthPercent > 0.6 {
                        healthBar.color = .green
                    } else if healthPercent > 0.3 {
                        healthBar.color = .yellow
                    } else {
                        healthBar.color = .red
                    }
                }

                // Update slow effect with orbiting ice crystals
                if let slowOverlay = node.childNode(withName: "slowOverlay") as? SKShapeNode {
                    slowOverlay.isHidden = !enemy.isSlowed
                }

                // Manage orbiting frost crystals
                let frostCrystals = node.childNode(withName: "frostCrystals")
                if enemy.isSlowed {
                    if frostCrystals == nil {
                        // Create frost crystal container
                        let crystalContainer = createFrostCrystals(enemySize: enemy.size)
                        crystalContainer.name = "frostCrystals"
                        node.addChild(crystalContainer)
                    }

                    // Occasional frost particle effect
                    if Int.random(in: 0..<15) == 0 {
                        spawnSlowParticle(at: node.position)
                    }
                } else {
                    // Remove frost crystals when no longer slowed
                    frostCrystals?.removeFromParent()
                }

                // Tint body when slowed
                if let body = node.childNode(withName: "body") as? SKShapeNode {
                    if enemy.isSlowed {
                        body.fillColor = (UIColor(hex: enemy.color) ?? .red).blended(with: .cyan, ratio: 0.3)
                    } else {
                        body.fillColor = UIColor(hex: enemy.color) ?? .red
                    }
                }

                // Low health glitch effect (under 30% HP)
                let healthPercent = enemy.health / enemy.maxHealth
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
            crystal.glowWidth = 3
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

        // Subtle pulsing glow
        let pulseGlow = SKAction.repeatForever(SKAction.sequence([
            SKAction.customAction(withDuration: 0.5) { node, elapsed in
                for child in node.children {
                    if let shape = child as? SKShapeNode {
                        shape.glowWidth = 3 + 2 * sin(elapsed / 0.5 * .pi)
                    }
                }
            },
            SKAction.customAction(withDuration: 0.5) { node, elapsed in
                for child in node.children {
                    if let shape = child as? SKShapeNode {
                        shape.glowWidth = 5 - 2 * sin(elapsed / 0.5 * .pi)
                    }
                }
            }
        ]))
        container.run(pulseGlow, withKey: "frostPulse")

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
        overlay.glowWidth = 4
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

    func updateProjectileVisuals(state: TDGameState) {
        // Remove old projectile nodes and trails
        for (id, node) in projectileNodes {
            if !state.projectiles.contains(where: { $0.id == id }) {
                node.removeFromParent()
                projectileNodes.removeValue(forKey: id)
                projectileTrails.removeValue(forKey: id)
            }
        }

        // Update/create projectile nodes and trails
        for proj in state.projectiles {
            let scenePos = convertToScene(CGPoint(x: proj.x, y: proj.y))

            if let node = projectileNodes[proj.id] {
                node.position = scenePos

                // Update trail (optimized - single path node)
                updateProjectileTrail(projId: proj.id, position: scenePos, color: UIColor(hex: proj.color) ?? .yellow)
            } else {
                // Create new projectile node
                let container = SKNode()
                container.position = scenePos

                let projectile = SKShapeNode(circleOfRadius: proj.radius)
                projectile.fillColor = UIColor(hex: proj.color) ?? .yellow
                projectile.strokeColor = .white
                projectile.lineWidth = 1
                projectile.name = "projectile"
                // REMOVED: glowWidth = 3 (expensive blur shader)
                container.addChild(projectile)

                // Trail: single SKShapeNode (will update path, not recreate nodes)
                let trailNode = SKShapeNode()
                trailNode.name = "trail"
                trailNode.zPosition = -1
                trailNode.lineCap = .round
                trailNode.lineJoin = .round
                // REMOVED: glowWidth, blendMode = .add
                container.addChild(trailNode)

                projectileLayer.addChild(container)
                projectileNodes[proj.id] = container

                // Initialize trail
                projectileTrails[proj.id] = [scenePos]
            }
        }
    }

    /// Update projectile trail - OPTIMIZED: single path instead of multiple nodes
    func updateProjectileTrail(projId: String, position: CGPoint, color: UIColor) {
        // Get or create trail array
        var trail = projectileTrails[projId] ?? []

        // Add current position
        trail.append(position)

        // Limit trail length
        if trail.count > maxTrailLength {
            trail = Array(trail.suffix(maxTrailLength))
        }

        projectileTrails[projId] = trail

        // Update trail visual - OPTIMIZED: update single path instead of recreating nodes
        guard let node = projectileNodes[projId],
              let trailNode = node.childNode(withName: "trail") as? SKShapeNode,
              trail.count >= 2 else { return }

        // Build single path for entire trail (relative to projectile position)
        let path = CGMutablePath()
        let nodePos = node.position

        path.move(to: CGPoint(x: trail[0].x - nodePos.x, y: trail[0].y - nodePos.y))
        for i in 1..<trail.count {
            path.addLine(to: CGPoint(x: trail[i].x - nodePos.x, y: trail[i].y - nodePos.y))
        }

        // Update the single trail node's path (no node creation!)
        trailNode.path = path
        trailNode.strokeColor = color.withAlphaComponent(0.4)
        trailNode.lineWidth = 2
    }

    func updateCoreVisual(state: TDGameState, currentTime: TimeInterval) {
        guard let coreContainer = backgroundLayer.childNode(withName: "core") else { return }

        // Get efficiency for color updates
        let efficiency = state.efficiency

        // Determine color based on efficiency
        let efficiencyColor: UIColor
        let glowIntensity: CGFloat
        if efficiency >= 70 {
            efficiencyColor = DesignColors.successUI  // Green
            glowIntensity = 15
        } else if efficiency >= 40 {
            efficiencyColor = DesignColors.warningUI  // Yellow/Amber
            glowIntensity = 10
        } else if efficiency >= 20 {
            efficiencyColor = UIColor.orange
            glowIntensity = 8
        } else {
            efficiencyColor = DesignColors.dangerUI   // Red - critical
            glowIntensity = 20  // More intense glow when critical
        }

        // Update CPU body stroke color
        if let cpuBody = coreContainer.childNode(withName: "cpuBody") as? SKShapeNode {
            cpuBody.strokeColor = efficiencyColor
            cpuBody.glowWidth = glowIntensity
        }

        // Update inner chip
        if let innerChip = coreContainer.childNode(withName: "innerChip") as? SKShapeNode {
            innerChip.strokeColor = efficiencyColor.withAlphaComponent(0.6)
        }

        // Update efficiency label
        if let efficiencyLabel = coreContainer.childNode(withName: "efficiencyLabel") as? SKLabelNode {
            efficiencyLabel.text = "\(Int(efficiency))%"
            efficiencyLabel.fontColor = efficiencyColor
        }

        // Update glow ring
        if let glowRing = coreContainer.childNode(withName: "glowRing") as? SKShapeNode {
            glowRing.strokeColor = efficiencyColor.withAlphaComponent(0.3)
            glowRing.glowWidth = glowIntensity
        }

        // Pulse effect - more intense when efficiency is low
        let baseScale = CoreSystem.getCorePulseScale(state: state, currentTime: currentTime)
        let pulseIntensity: CGFloat = efficiency < 30 ? 1.15 : 1.0  // More intense pulse when critical
        coreContainer.setScale(baseScale * pulseIntensity)
    }

}
