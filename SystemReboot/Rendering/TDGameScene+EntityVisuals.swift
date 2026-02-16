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
        // Early-exit: events are appended chronologically, so if oldest is recent, skip scan
        if let oldest = state.damageEvents.first, state.gameTime - oldest.timestamp > 2.0 {
            state.damageEvents.removeAll { state.gameTime - $0.timestamp > 2.0 }
        }
    }

    // MARK: - Projectile Visuals

    func updateProjectileVisuals(state: TDGameState) {
        // Remove old projectile nodes and trails (Set lookup: O(1) per node)
        let activeProjectileIds = Set(state.projectiles.map { $0.id })
        for (id, node) in projectileNodes where !activeProjectileIds.contains(id) {
            tdNodePool.release(node, type: .tdProjectile)
            projectileNodes.removeValue(forKey: id)
            projectileTrails.removeValue(forKey: id)
        }

        // Update/create projectile nodes and trails
        for proj in state.projectiles {
            let scenePos = convertToScene(CGPoint(x: proj.x, y: proj.y))

            if let node = projectileNodes[proj.id] {
                node.position = scenePos

                // Update trail (optimized - single path node)
                updateProjectileTrail(projId: proj.id, position: scenePos, color: UIColor(hex: proj.color) ?? .yellow)
            } else {
                // Acquire from pool (reuses nodes instead of alloc/dealloc)
                let container = tdNodePool.acquire(type: .tdProjectile) {
                    let c = SKNode()
                    let projectile = SKShapeNode(circleOfRadius: BalanceConfig.Towers.projectileHitboxRadius)
                    projectile.strokeColor = .white
                    projectile.lineWidth = 1
                    projectile.name = "projectile"
                    c.addChild(projectile)

                    let trailNode = SKShapeNode()
                    trailNode.name = "trail"
                    trailNode.zPosition = -1
                    trailNode.lineCap = .round
                    trailNode.lineJoin = .round
                    c.addChild(trailNode)
                    return c
                }

                container.position = scenePos

                // Reset color for this projectile
                if let projectileShape = container.childNode(withName: "projectile") as? SKShapeNode {
                    projectileShape.fillColor = UIColor(hex: proj.color) ?? .yellow
                }

                // Clear stale trail path
                if let trailNode = container.childNode(withName: "trail") as? SKShapeNode {
                    trailNode.path = nil
                }

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

    // MARK: - Core Visual

    func updateCoreVisual(state: TDGameState, currentTime: TimeInterval) {
        guard let coreContainer = backgroundLayer.childNode(withName: "core") else { return }

        let efficiency = state.efficiency
        let cpuTier = state.cpuTier
        let tierColor = CPUTierColors.color(for: cpuTier)

        // Determine color based on efficiency (overrides tier color for critical elements)
        let efficiencyColor: UIColor
        if efficiency >= 70 {
            efficiencyColor = DesignColors.successUI  // Green
        } else if efficiency >= 40 {
            efficiencyColor = DesignColors.warningUI  // Yellow/Amber
        } else if efficiency >= 20 {
            efficiencyColor = UIColor.orange
        } else {
            efficiencyColor = DesignColors.dangerUI   // Red - critical
        }

        // IHS body uses tier color at high efficiency, efficiency color when under stress
        let bodyStrokeColor = efficiency >= 70 ? tierColor : efficiencyColor
        if let cpuBody = coreContainer.childNode(withName: "cpuBody") as? SKShapeNode {
            cpuBody.strokeColor = bodyStrokeColor
        }

        // Inner chip uses efficiency color (always shows health status)
        if let innerChip = coreContainer.childNode(withName: "innerChip") as? SKShapeNode {
            innerChip.strokeColor = efficiencyColor.withAlphaComponent(0.6)
        }

        // Efficiency label
        if let efficiencyLabel = coreContainer.childNode(withName: "efficiencyLabel") as? SKLabelNode {
            efficiencyLabel.text = "\(Int(efficiency))%"
            efficiencyLabel.fontColor = efficiencyColor
        }

        // Tier label
        if let tierLabel = coreContainer.childNode(withName: "tierLabel") as? SKLabelNode {
            tierLabel.text = "T\(cpuTier)"
            tierLabel.fontColor = tierColor.withAlphaComponent(0.6)
        }

        // Glow ring — blends efficiency + tier color
        if let glowRing = coreContainer.childNode(withName: "glowRing") as? SKShapeNode {
            let glowColor = efficiency >= 70 ? tierColor : efficiencyColor
            glowRing.strokeColor = glowColor.withAlphaComponent(0.3)
        }

        // Inner glow uses tier color
        if let innerGlow = coreContainer.childNode(withName: "innerGlow") as? SKShapeNode {
            innerGlow.strokeColor = tierColor.withAlphaComponent(0.35)
        }

        // Update core block visibility based on tier
        let coresVisible = min(cpuTier * 2, 8)
        for i in 0..<8 {
            if let block = coreContainer.childNode(withName: "coreBlock_\(i)") as? SKShapeNode {
                block.isHidden = i >= coresVisible
                block.strokeColor = tierColor.withAlphaComponent(0.5)
            }
        }

        // Update cache bar visibility based on tier
        for i in 0..<2 {
            if let bar = coreContainer.childNode(withName: "cacheBar_L2_\(i)") as? SKShapeNode {
                bar.isHidden = cpuTier < 3
                bar.strokeColor = tierColor.withAlphaComponent(0.35)
            }
        }
        if let l3 = coreContainer.childNode(withName: "cacheBar_L3") as? SKShapeNode {
            l3.isHidden = cpuTier < 4
            l3.strokeColor = tierColor.withAlphaComponent(0.3)
        }

        // Pulse effect — more intense when efficiency is low
        let baseScale = CoreSystem.getCorePulseScale(state: state, currentTime: currentTime)
        let pulseIntensity: CGFloat = efficiency < 30 ? 1.15 : 1.0
        coreContainer.setScale(baseScale * pulseIntensity)
    }

}
