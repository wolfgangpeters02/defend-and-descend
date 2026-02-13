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
                towerNodeRefs.removeValue(forKey: id)
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

                // Get or build cached refs
                var refs = towerNodeRefs[tower.id] ?? TowerNodeRefs()

                // Update range indicator visibility with lazy creation
                let shouldShowRange = tower.id == selectedTowerId || isDragging
                if shouldShowRange {
                    // Lazily create range indicator on first need
                    if refs.rangeNode == nil {
                        let towerColor = UIColor(hex: tower.color) ?? TowerColors.color(for: tower.protocolId)
                        let rangeIndicator = TowerVisualFactory.createRangeIndicator(range: tower.range, color: towerColor)
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

                // Save refs before cooldown arc (which may lazily create the cooldown node)
                towerNodeRefs[tower.id] = refs

                // Update cooldown arc (lazy creation inside)
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

        }
    }

    /// Cached cooldown progress per tower to avoid redundant arc path rebuilds
    private static var cachedCooldownProgress: [String: CGFloat] = [:]

    /// Update cooldown arc indicator on tower (cached refs + lazy creation + arc path caching)
    func updateCooldownArc(for tower: Tower, node: SKNode, currentTime: TimeInterval) {
        // Guard against invalid attack speed (prevents NaN/Infinity angles)
        guard tower.attackSpeed > 0 else {
            // Hide if it exists
            if let refs = towerNodeRefs[tower.id], let cooldownNode = refs.cooldownNode {
                cooldownNode.isHidden = true
            }
            return
        }

        let attackInterval = 1.0 / tower.attackSpeed
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
            // LOD detail visibility based on zoom (lazy creation)
            if showDetail {
                var refs = towerNodeRefs[towerId] ?? TowerNodeRefs()
                // Lazily create LOD detail on first zoom-in
                if refs.lodDetail == nil, let tower = state?.towers.first(where: { $0.id == towerId }) {
                    let towerColor = UIColor(hex: tower.color) ?? TowerColors.color(for: tower.protocolId)
                    let lodDetail = TowerVisualFactory.createLODDetail(
                        damage: tower.damage,
                        attackSpeed: tower.attackSpeed,
                        projectileCount: tower.projectileCount,
                        level: tower.level,
                        color: towerColor
                    )
                    lodDetail.name = "lodDetail"
                    lodDetail.alpha = 0
                    lodDetail.zPosition = 20
                    node.addChild(lodDetail)
                    refs.lodDetail = lodDetail
                    towerNodeRefs[towerId] = refs
                }
                if let lodDetail = refs.lodDetail {
                    if abs(lodDetail.alpha - targetAlpha) > 0.01 {
                        lodDetail.removeAction(forKey: "lodFade")
                        let fadeAction = SKAction.fadeAlpha(to: targetAlpha, duration: 0.2)
                        lodDetail.run(fadeAction, withKey: "lodFade")
                    }
                }
            } else {
                // Not zoomed in — only animate fade-out if LOD detail exists
                if let refs = towerNodeRefs[towerId], let lodDetail = refs.lodDetail {
                    if abs(lodDetail.alpha - targetAlpha) > 0.01 {
                        lodDetail.removeAction(forKey: "lodFade")
                        let fadeAction = SKAction.fadeAlpha(to: targetAlpha, duration: 0.2)
                        lodDetail.run(fadeAction, withKey: "lodFade")
                    }
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

    // MARK: - Background Detail LOD (Performance)

    /// Hide background decorations, parallax, and grid dots when zoomed out.
    /// These small details are invisible at high zoom levels and waste GPU rendering time.
    func updateBackgroundDetailLOD() {
        let shouldShow = currentScale < 0.55
        guard shouldShow != backgroundDetailVisible else { return }
        backgroundDetailVisible = shouldShow

        // Toggle parallax layers
        for (layer, _) in parallaxLayers {
            layer.isHidden = !shouldShow
        }

        // Toggle sector decoration nodes
        backgroundLayer.enumerateChildNodes(withName: "sectorDecor_*") { node, _ in
            node.isHidden = !shouldShow
        }

        // Toggle grid dots layer (small dots not visible when zoomed out)
        gridDotsLayer?.isHidden = !shouldShow
    }

    // MARK: - Glow LOD (Performance)

    /// Disable expensive glowWidth (Gaussian blur shader) when zoomed out.
    /// Each glowWidth > 0 node triggers a separate GPU blur pass per frame.
    /// At zoomed-out view, glows are sub-pixel and invisible — pure waste.
    func updateGlowLOD() {
        let shouldEnable = currentScale < 0.5
        guard shouldEnable != glowLODEnabled else { return }
        glowLODEnabled = shouldEnable

        for entry in glowNodes {
            entry.node.glowWidth = shouldEnable ? entry.normalGlowWidth : 0
        }
    }

    /// Hide/unhide path LEDs when zoomed out.
    /// LEDs are individual nodes with blendMode=.add — still cost draw calls even when frozen.
    func updateLEDVisibility() {
        let shouldHide = currentScale >= 0.8
        guard shouldHide != ledsHidden else { return }
        ledsHidden = shouldHide

        for (_, leds) in pathLEDNodes {
            for led in leds {
                led.isHidden = shouldHide
            }
        }
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

        let megaConfig = cachedMegaBoardConfig
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
        guard let sector = cachedMegaBoardConfig.sectors.first(where: { $0.id == sectorId }) else { return }

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

            } else {
                // Other bosses (Void Harbinger, Trojan Wyrm, generic): shape-based rendering
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

            } else if enemy.isBoss && enemy.type != EnemyID.cyberboss.rawValue && enemy.type != EnemyID.overclocker.rawValue {
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

        // Remove old enemy nodes with death animation
        for (id, node) in enemyNodes {
            if !state.enemies.contains(where: { $0.id == id && !$0.isDead }) {
                enemiesToRemove.append(id)
            }
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

                // Performance: skip expensive visual updates for off-screen enemies
                guard paddedRect.contains(node.position) else { continue }

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

        // Subtle pulsing glow
        let pulseGlow = SKAction.repeatForever(SKAction.sequence([
            SKAction.customAction(withDuration: 0.5) { node, elapsed in
                for child in node.children {
                    if let shape = child as? SKShapeNode {
                        shape.glowWidth = 0  // PERF: was 3 + 2 * sin(elapsed / 0.5 * .pi) (GPU Gaussian blur)
                    }
                }
            },
            SKAction.customAction(withDuration: 0.5) { node, elapsed in
                for child in node.children {
                    if let shape = child as? SKShapeNode {
                        shape.glowWidth = 0  // PERF: was 5 - 2 * sin(elapsed / 0.5 * .pi) (GPU Gaussian blur)
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
            cpuBody.glowWidth = 0  // PERF: was glowIntensity (GPU Gaussian blur)
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
            glowRing.glowWidth = 0  // PERF: was glowIntensity (GPU Gaussian blur)
        }

        // Pulse effect - more intense when efficiency is low
        let baseScale = CoreSystem.getCorePulseScale(state: state, currentTime: currentTime)
        let pulseIntensity: CGFloat = efficiency < 30 ? 1.15 : 1.0  // More intense pulse when critical
        coreContainer.setScale(baseScale * pulseIntensity)
    }

}
