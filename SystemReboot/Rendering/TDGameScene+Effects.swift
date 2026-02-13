import SpriteKit
import SwiftUI

extension TDGameScene {

    // MARK: - PCB Trace Helper

    /// Draw a single PCB trace path
    /// - Parameters:
    ///   - points: Array of (x, y) offsets from sector origin
    ///   - node: Parent node to add trace to
    ///   - baseX/baseY: Sector world origin
    ///   - zPos: Z position for layering
    ///   - lineWidth: Trace thickness (6pt for main, 3pt for secondary)
    ///   - alpha: Copper color alpha (0.15 for main, 0.1 for secondary)
    func drawPCBTrace(points: [(x: CGFloat, y: CGFloat)], to node: SKNode,
                              baseX: CGFloat, baseY: CGFloat, zPos: CGFloat,
                              lineWidth: CGFloat, alpha: CGFloat) {
        guard !points.isEmpty else { return }
        let tracePath = CGMutablePath()
        for (index, point) in points.enumerated() {
            let pos = CGPoint(x: baseX + point.x, y: baseY + point.y)
            if index == 0 {
                tracePath.move(to: pos)
            } else {
                tracePath.addLine(to: pos)
            }
        }
        let traceNode = SKShapeNode(path: tracePath)
        traceNode.strokeColor = PSUColors.copper.withAlphaComponent(alpha)
        traceNode.lineWidth = lineWidth
        traceNode.lineCap = .round
        traceNode.lineJoin = .round
        traceNode.zPosition = zPos
        node.addChild(traceNode)
    }

    /// Add PCB power traces connecting PSU components
    func addPSUTraces(to node: SKNode, baseX: CGFloat, baseY: CGFloat, zPos: CGFloat) {
        // Main power traces (thick, connecting major components)
        let mainTraces: [[(x: CGFloat, y: CGFloat)]] = [
            // Trace from transformer to 24-pin connector
            [(x: 725, y: 400), (x: 900, y: 350), (x: 1100, y: 200), (x: 1200, y: 175)],
            // Trace from transformer to caps
            [(x: 575, y: 400), (x: 400, y: 380), (x: 200, y: 340)],
            // Vertical trace
            [(x: 650, y: 500), (x: 650, y: 700), (x: 400, y: 850), (x: 300, y: 950)]
        ]

        for trace in mainTraces {
            drawPCBTrace(points: trace, to: node, baseX: baseX, baseY: baseY,
                        zPos: zPos, lineWidth: 6, alpha: 0.15)
        }

        // Secondary traces (thinner)
        let secondaryTraces: [[(x: CGFloat, y: CGFloat)]] = [
            [(x: 280, y: 620), (x: 350, y: 620)],  // Between MOSFETs
            [(x: 500, y: 250), (x: 580, y: 280), (x: 650, y: 340)],  // Inductors to transformer
            [(x: 850, y: 300), (x: 780, y: 350), (x: 725, y: 380)]   // Other inductor
        ]

        for trace in secondaryTraces {
            drawPCBTrace(points: trace, to: node, baseX: baseX, baseY: baseY,
                        zPos: zPos, lineWidth: 3, alpha: 0.1)
        }
    }

    /// Trigger capacitor discharge effect (call when nearby tower fires)
    /// Now creates a subtle pulse on nearby electrolytic capacitors
    func triggerCapacitorDischarge(near position: CGPoint) {
        // Rate limit: max 1 discharge per 0.5 seconds (reduced frequency)
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastCapacitorDischargeTime > 0.5 else { return }
        lastCapacitorDischargeTime = currentTime

        // Find capacitors near the position
        for container in psuCapacitorNodes {
            let distance = hypot(container.position.x - position.x,
                                container.position.y - position.y)

            // Only affect capacitors within 300 points
            guard distance < 300 else { continue }

            // Use separate dischargeGlow node (doesn't conflict with breathing animation)
            if let dischargeGlow = container.childNode(withName: "dischargeGlow") as? SKShapeNode {
                let pulseUp = SKAction.customAction(withDuration: 0.1) { [weak dischargeGlow] _, elapsed in
                    let progress = elapsed / 0.1
                    dischargeGlow?.fillColor = PSUColors.theme.withAlphaComponent(0.2 * progress)
                }
                let pulseDown = SKAction.customAction(withDuration: 0.2) { [weak dischargeGlow] _, elapsed in
                    let progress = elapsed / 0.2
                    dischargeGlow?.fillColor = PSUColors.theme.withAlphaComponent(0.2 * (1 - progress))
                }
                dischargeGlow.run(SKAction.sequence([pulseUp, pulseDown]), withKey: "discharge")
            }
        }
    }

    // MARK: - ParticleEffectService Forwarding
    // Thin wrappers delegating to particleEffectService (extracted in Step 4.3)

    func startPowerFlowParticles() {
        particleEffectService.startPowerFlowParticles()
    }

    func spawnPowerFlowParticle(along path: EnemyPath) {
        particleEffectService.spawnPowerFlowParticle(along: path)
    }

    func calculatePathLength(_ path: EnemyPath) -> CGFloat {
        particleEffectService.calculatePathLength(path)
    }

    func spawnTracePulse(at towerPosition: CGPoint, color: UIColor) {
        particleEffectService.spawnTracePulse(at: towerPosition, color: color)
    }

    func closestPointOnSegment(point: CGPoint, segmentStart: CGPoint, segmentEnd: CGPoint) -> (t: CGFloat, distance: CGFloat) {
        particleEffectService.closestPointOnSegment(point: point, segmentStart: segmentStart, segmentEnd: segmentEnd)
    }

    func distance(from a: CGPoint, to b: CGPoint) -> CGFloat {
        particleEffectService.distance(from: a, to: b)
    }

    func startVoltageArcSystem() {
        particleEffectService.startVoltageArcSystem()
    }

    func spawnVoltageArc(from start: CGPoint, to end: CGPoint) {
        particleEffectService.spawnVoltageArc(from: start, to: end)
    }

    func triggerScreenShake(intensity: CGFloat, duration: TimeInterval, position: CGPoint? = nil) {
        particleEffectService.triggerScreenShake(intensity: intensity, duration: duration, position: position)
    }

    func isPositionVisible(_ scenePosition: CGPoint) -> Bool {
        particleEffectService.isPositionVisible(scenePosition)
    }

    func flashOverlay(color: UIColor, alpha: CGFloat = 0.15, duration: TimeInterval = 0.15) {
        particleEffectService.flashOverlay(color: color, alpha: alpha, duration: duration)
    }

    func triggerBossEntranceEffect(at position: CGPoint, bossColor: UIColor = .red) {
        particleEffectService.triggerBossEntranceEffect(at: position, bossColor: bossColor)
    }

    func triggerBossDeathEffect(at position: CGPoint, bossColor: UIColor = .red) {
        particleEffectService.triggerBossDeathEffect(at: position, bossColor: bossColor)
    }

    func triggerDamageFlash() {
        particleEffectService.triggerDamageFlash()
    }

    func spawnPortalAnimation(at position: CGPoint, completion: (() -> Void)? = nil) {
        particleEffectService.spawnPortalAnimation(at: position, completion: completion)
    }

    func spawnDeathParticles(at position: CGPoint, color: UIColor, isBoss: Bool = false) {
        particleEffectService.spawnDeathParticles(at: position, color: color, isBoss: isBoss)
    }

    func spawnHashFloaties(at position: CGPoint, hashValue: Int) {
        particleEffectService.spawnHashFloaties(at: position, hashValue: hashValue)
    }

    func spawnImpactSparks(at position: CGPoint, color: UIColor) {
        particleEffectService.spawnImpactSparks(at: position, color: color)
    }

    func spawnCoreHitEffect(at position: CGPoint) {
        particleEffectService.spawnCoreHitEffect(at: position)
    }
}
