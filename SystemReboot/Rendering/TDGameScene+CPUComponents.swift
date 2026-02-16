import SpriteKit
import SwiftUI

extension TDGameScene {

    // MARK: - CPU Sector Components ("CPU Socket City")
    // Creates realistic CPU socket area with VRMs, pin array, retention bracket
    // Sector coordinates: 0-1400 range (sector size is 1400x1400)

    /// Cached colors for CPU sector components
    struct CPUSectorColors {
        static let copper = UIColor(hex: "#b87333") ?? .orange
        static let chipBody = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)
        static let vrmBody = UIColor(red: 0.06, green: 0.06, blue: 0.09, alpha: 1.0)
        static let capacitorBody = UIColor(red: 0.10, green: 0.10, blue: 0.14, alpha: 1.0)
        static let socketFrame = UIColor(hex: "#b87333")?.withAlphaComponent(0.3) ?? .orange.withAlphaComponent(0.3)
    }

    /// Main entry point for CPU sector decorations
    func addCPUSocketComponents(to node: SKNode, in sector: MegaBoardSector, color: UIColor) {
        let baseX = sector.worldX
        let baseY = sector.worldY
        let width = sector.width
        let height = sector.height
        let zPos: CGFloat = 3

        // CPU is centered in sector — avoid placing components where the core sits
        let cpuCenterLocalX = width / 2
        let cpuCenterLocalY = height / 2
        let cpuExclusionLocal: CGFloat = BalanceConfig.TowerPlacement.cpuExclusionRadius + 50

        func isNearCPUOrLane(_ x: CGFloat, _ y: CGFloat) -> Bool {
            // Avoid CPU center area
            let dx = x - cpuCenterLocalX
            let dy = y - cpuCenterLocalY
            if (dx * dx + dy * dy) < cpuExclusionLocal * cpuExclusionLocal { return true }
            // Avoid lane paths (standard exclusion zones)
            if Self.isNearLane(x, y) { return true }
            return false
        }

        // ========== 1. LGA SOCKET PIN ARRAY (batched) ==========
        drawSocketPinArray(to: node, baseX: baseX, baseY: baseY, width: width, height: height,
                           cpuCenterLocalX: cpuCenterLocalX, cpuCenterLocalY: cpuCenterLocalY,
                           color: color, zPos: zPos)

        // ========== 2. VRM INDUCTOR ARRAY (batched) ==========
        drawVRMInductors(to: node, baseX: baseX, baseY: baseY, width: width, height: height,
                         isExcluded: isNearCPUOrLane, color: color, zPos: zPos)

        // ========== 3. VRM MOSFETS (batched) ==========
        drawVRMMosfets(to: node, baseX: baseX, baseY: baseY, width: width, height: height,
                       isExcluded: isNearCPUOrLane, color: color, zPos: zPos)

        // ========== 4. MLCC CAPACITORS (batched, dense) ==========
        drawMLCCCapacitors(to: node, baseX: baseX, baseY: baseY, width: width, height: height,
                           isExcluded: isNearCPUOrLane, color: color, zPos: zPos)

        // ========== 5. SOLID CAPACITORS (batched) ==========
        drawSolidCapacitors(to: node, baseX: baseX, baseY: baseY, width: width, height: height,
                            isExcluded: isNearCPUOrLane, color: color, zPos: zPos)

        // ========== 6. CPU SOCKET RETENTION FRAME ==========
        drawSocketFrame(to: node, baseX: baseX, baseY: baseY,
                        cpuCenterLocalX: cpuCenterLocalX, cpuCenterLocalY: cpuCenterLocalY,
                        color: color, zPos: zPos)

        // ========== 7. SUBSTRATE TRACE BUNDLES (batched) ==========
        drawSubstrateTraces(to: node, baseX: baseX, baseY: baseY, width: width, height: height,
                            cpuCenterLocalX: cpuCenterLocalX, cpuCenterLocalY: cpuCenterLocalY,
                            color: color, zPos: zPos)

        // ========== 8. SILKSCREEN LABELS ==========
        drawCPUSilkscreenLabels(to: node, baseX: baseX, baseY: baseY, width: width, height: height,
                                isExcluded: isNearCPUOrLane, color: color, zPos: zPos)
    }

    // MARK: - Socket Pin Array

    private func drawSocketPinArray(to node: SKNode, baseX: CGFloat, baseY: CGFloat,
                                     width: CGFloat, height: CGFloat,
                                     cpuCenterLocalX: CGFloat, cpuCenterLocalY: CGFloat,
                                     color: UIColor, zPos: CGFloat) {
        let pinPath = CGMutablePath()
        let pinSize: CGFloat = 3
        let pinSpacing: CGFloat = 8
        let gridRadius: CGFloat = 200  // Pin grid extends 200pt from CPU center

        let startX = cpuCenterLocalX - gridRadius
        let startY = cpuCenterLocalY - gridRadius
        let endX = cpuCenterLocalX + gridRadius
        let endY = cpuCenterLocalY + gridRadius

        // Inner exclusion (IHS area) — don't draw pins under the CPU body itself
        let ihsHalf = BalanceConfig.Motherboard.cpuSize / 2 + 10

        var x = startX
        while x < endX {
            var y = startY
            while y < endY {
                let dx = x - cpuCenterLocalX
                let dy = y - cpuCenterLocalY
                // Skip pins under the IHS
                if abs(dx) < ihsHalf && abs(dy) < ihsHalf {
                    y += pinSpacing
                    continue
                }
                pinPath.addRect(CGRect(x: baseX + x, y: baseY + y, width: pinSize, height: pinSize))
                y += pinSpacing
            }
            x += pinSpacing
        }

        let pinNode = SKShapeNode(path: pinPath)
        pinNode.fillColor = CPUSectorColors.copper.withAlphaComponent(0.5)
        pinNode.strokeColor = CPUSectorColors.copper.withAlphaComponent(0.25)
        pinNode.lineWidth = 0.5
        pinNode.zPosition = zPos - 0.3
        node.addChild(pinNode)
    }

    // MARK: - VRM Inductors

    private func drawVRMInductors(to node: SKNode, baseX: CGFloat, baseY: CGFloat,
                                   width: CGFloat, height: CGFloat,
                                   isExcluded: (CGFloat, CGFloat) -> Bool,
                                   color: UIColor, zPos: CGFloat) {
        let inductorPath = CGMutablePath()
        let coilPath = CGMutablePath()

        // Top edge VRM row
        for i in 0..<8 {
            let x = 120 + CGFloat(i) * 150
            let y = height - 100
            guard !isExcluded(x, y) else { continue }
            // Inductor body
            inductorPath.addRoundedRect(in: CGRect(x: baseX + x - 20, y: baseY + y - 12, width: 40, height: 25),
                                        cornerWidth: 4, cornerHeight: 4)
            // Copper coil traces inside
            for c in 0..<3 {
                let cx = x - 12 + CGFloat(c) * 12
                coilPath.addRect(CGRect(x: baseX + cx, y: baseY + y - 6, width: 8, height: 2))
            }
        }

        // Left edge VRM column
        for i in 0..<6 {
            let x: CGFloat = 80
            let y = 200 + CGFloat(i) * 160
            guard !isExcluded(x, y) else { continue }
            inductorPath.addRoundedRect(in: CGRect(x: baseX + x - 12, y: baseY + y - 20, width: 25, height: 40),
                                        cornerWidth: 4, cornerHeight: 4)
            for c in 0..<3 {
                let cy = y - 12 + CGFloat(c) * 12
                coilPath.addRect(CGRect(x: baseX + x - 6, y: baseY + cy, width: 2, height: 8))
            }
        }

        let inductorNode = SKShapeNode(path: inductorPath)
        inductorNode.fillColor = CPUSectorColors.vrmBody
        inductorNode.strokeColor = color.withAlphaComponent(0.35)
        inductorNode.lineWidth = 1
        inductorNode.zPosition = zPos
        node.addChild(inductorNode)

        let coilNode = SKShapeNode(path: coilPath)
        coilNode.fillColor = CPUSectorColors.copper.withAlphaComponent(0.6)
        coilNode.strokeColor = .clear
        coilNode.zPosition = zPos + 0.05
        node.addChild(coilNode)
    }

    // MARK: - VRM MOSFETs

    private func drawVRMMosfets(to node: SKNode, baseX: CGFloat, baseY: CGFloat,
                                 width: CGFloat, height: CGFloat,
                                 isExcluded: (CGFloat, CGFloat) -> Bool,
                                 color: UIColor, zPos: CGFloat) {
        let mosfetBodyPath = CGMutablePath()
        let mosfetTabPath = CGMutablePath()

        // Between top-edge inductors
        for i in 0..<7 {
            let x = 190 + CGFloat(i) * 150
            let y = height - 105
            guard !isExcluded(x, y) else { continue }
            mosfetBodyPath.addRect(CGRect(x: baseX + x - 8, y: baseY + y - 10, width: 16, height: 20))
            mosfetTabPath.addRect(CGRect(x: baseX + x - 10, y: baseY + y + 10, width: 20, height: 5))
        }

        // Between left-edge inductors
        for i in 0..<5 {
            let x: CGFloat = 75
            let y = 280 + CGFloat(i) * 160
            guard !isExcluded(x, y) else { continue }
            mosfetBodyPath.addRect(CGRect(x: baseX + x - 10, y: baseY + y - 8, width: 20, height: 16))
            mosfetTabPath.addRect(CGRect(x: baseX + x - 14, y: baseY + y - 10, width: 5, height: 20))
        }

        // Scattered power-delivery MOSFETs near CPU
        for _ in 0..<10 {
            let x = CGFloat.random(in: 200...(width - 200))
            let y = CGFloat.random(in: 200...(height - 200))
            guard !isExcluded(x, y) else { continue }
            mosfetBodyPath.addRect(CGRect(x: baseX + x - 8, y: baseY + y - 10, width: 16, height: 20))
            mosfetTabPath.addRect(CGRect(x: baseX + x - 10, y: baseY + y + 10, width: 20, height: 5))
        }

        let mosfetBody = SKShapeNode(path: mosfetBodyPath)
        mosfetBody.fillColor = CPUSectorColors.chipBody
        mosfetBody.strokeColor = color.withAlphaComponent(0.2)
        mosfetBody.lineWidth = 0.5
        mosfetBody.zPosition = zPos - 0.1
        node.addChild(mosfetBody)

        let mosfetTab = SKShapeNode(path: mosfetTabPath)
        mosfetTab.fillColor = UIColor(red: 0.25, green: 0.25, blue: 0.30, alpha: 1.0)
        mosfetTab.strokeColor = .clear
        mosfetTab.zPosition = zPos - 0.1
        node.addChild(mosfetTab)
    }

    // MARK: - MLCC Capacitors

    private func drawMLCCCapacitors(to node: SKNode, baseX: CGFloat, baseY: CGFloat,
                                     width: CGFloat, height: CGFloat,
                                     isExcluded: (CGFloat, CGFloat) -> Bool,
                                     color: UIColor, zPos: CGFloat) {
        let capPath = CGMutablePath()
        for _ in 0..<60 {
            let x = CGFloat.random(in: 50...(width - 50))
            let y = CGFloat.random(in: 50...(height - 50))
            guard !isExcluded(x, y) else { continue }
            let w = CGFloat.random(in: 3...6)
            let h = CGFloat.random(in: 2...4)
            capPath.addRect(CGRect(x: baseX + x - w / 2, y: baseY + y - h / 2, width: w, height: h))
        }

        let capNode = SKShapeNode(path: capPath)
        capNode.fillColor = CPUSectorColors.capacitorBody
        capNode.strokeColor = color.withAlphaComponent(0.15)
        capNode.lineWidth = 0.5
        capNode.zPosition = zPos - 0.2
        node.addChild(capNode)
    }

    // MARK: - Solid Capacitors

    private func drawSolidCapacitors(to node: SKNode, baseX: CGFloat, baseY: CGFloat,
                                      width: CGFloat, height: CGFloat,
                                      isExcluded: (CGFloat, CGFloat) -> Bool,
                                      color: UIColor, zPos: CGFloat) {
        let solidPath = CGMutablePath()

        // Near top VRM bank
        for i in 0..<4 {
            let x = 150 + CGFloat(i) * 200
            let y = height - 160
            guard !isExcluded(x, y) else { continue }
            let radius: CGFloat = CGFloat.random(in: 6...8)
            solidPath.addEllipse(in: CGRect(x: baseX + x - radius, y: baseY + y - radius,
                                            width: radius * 2, height: radius * 2))
        }

        // Near left VRM bank
        for i in 0..<3 {
            let x: CGFloat = 140
            let y = 300 + CGFloat(i) * 200
            guard !isExcluded(x, y) else { continue }
            let radius: CGFloat = CGFloat.random(in: 6...8)
            solidPath.addEllipse(in: CGRect(x: baseX + x - radius, y: baseY + y - radius,
                                            width: radius * 2, height: radius * 2))
        }

        // Scattered near CPU
        for _ in 0..<4 {
            let x = CGFloat.random(in: 200...(width - 200))
            let y = CGFloat.random(in: 200...(height - 200))
            guard !isExcluded(x, y) else { continue }
            let radius: CGFloat = CGFloat.random(in: 5...7)
            solidPath.addEllipse(in: CGRect(x: baseX + x - radius, y: baseY + y - radius,
                                            width: radius * 2, height: radius * 2))
        }

        let solidNode = SKShapeNode(path: solidPath)
        solidNode.fillColor = CPUSectorColors.chipBody
        solidNode.strokeColor = color.withAlphaComponent(0.3)
        solidNode.lineWidth = 1
        solidNode.zPosition = zPos - 0.1
        node.addChild(solidNode)
    }

    // MARK: - Socket Retention Frame

    private func drawSocketFrame(to node: SKNode, baseX: CGFloat, baseY: CGFloat,
                                  cpuCenterLocalX: CGFloat, cpuCenterLocalY: CGFloat,
                                  color: UIColor, zPos: CGFloat) {
        let frameSize = BalanceConfig.Motherboard.cpuSocketFrameSize  // 800
        let half = frameSize / 2
        let cx = baseX + cpuCenterLocalX
        let cy = baseY + cpuCenterLocalY

        // Main frame outline
        let framePath = CGMutablePath()
        framePath.addRoundedRect(in: CGRect(x: cx - half, y: cy - half, width: frameSize, height: frameSize),
                                 cornerWidth: 6, cornerHeight: 6)

        let frameNode = SKShapeNode(path: framePath)
        frameNode.fillColor = .clear
        frameNode.strokeColor = CPUSectorColors.socketFrame
        frameNode.lineWidth = 2
        frameNode.zPosition = zPos - 0.4
        node.addChild(frameNode)

        // Corner retention clamps (L-shaped brackets)
        let clampPath = CGMutablePath()
        let clampLen: CGFloat = 40
        let clampW: CGFloat = 6

        // Top-left clamp
        clampPath.addRect(CGRect(x: cx - half - clampW, y: cy + half - clampLen, width: clampW, height: clampLen))
        clampPath.addRect(CGRect(x: cx - half - clampW, y: cy + half, width: clampLen, height: clampW))
        // Top-right clamp
        clampPath.addRect(CGRect(x: cx + half, y: cy + half - clampLen, width: clampW, height: clampLen))
        clampPath.addRect(CGRect(x: cx + half - clampLen + clampW, y: cy + half, width: clampLen, height: clampW))
        // Bottom-left clamp
        clampPath.addRect(CGRect(x: cx - half - clampW, y: cy - half, width: clampW, height: clampLen))
        clampPath.addRect(CGRect(x: cx - half - clampW, y: cy - half - clampW, width: clampLen, height: clampW))
        // Bottom-right clamp
        clampPath.addRect(CGRect(x: cx + half, y: cy - half, width: clampW, height: clampLen))
        clampPath.addRect(CGRect(x: cx + half - clampLen + clampW, y: cy - half - clampW, width: clampLen, height: clampW))

        let clampNode = SKShapeNode(path: clampPath)
        clampNode.fillColor = CPUSectorColors.copper.withAlphaComponent(0.4)
        clampNode.strokeColor = CPUSectorColors.copper.withAlphaComponent(0.2)
        clampNode.lineWidth = 0.5
        clampNode.zPosition = zPos - 0.3
        node.addChild(clampNode)
    }

    // MARK: - Substrate Traces

    private func drawSubstrateTraces(to node: SKNode, baseX: CGFloat, baseY: CGFloat,
                                      width: CGFloat, height: CGFloat,
                                      cpuCenterLocalX: CGFloat, cpuCenterLocalY: CGFloat,
                                      color: UIColor, zPos: CGFloat) {
        let tracePath = CGMutablePath()
        let cx = baseX + cpuCenterLocalX
        let cy = baseY + cpuCenterLocalY
        let startOffset: CGFloat = BalanceConfig.Motherboard.cpuSize / 2 + 30  // Start just outside IHS

        // Trace bundles radiating toward sector edges (8 directions)
        let directions: [(dx: CGFloat, dy: CGFloat, length: CGFloat)] = [
            (0, 1, height / 2 - 60),       // North
            (0, -1, height / 2 - 60),      // South
            (1, 0, width / 2 - 60),        // East
            (-1, 0, width / 2 - 60),       // West
            (0.707, 0.707, 300),            // NE
            (-0.707, 0.707, 300),           // NW
            (0.707, -0.707, 300),           // SE
            (-0.707, -0.707, 300),          // SW
        ]

        for dir in directions {
            let tracesInBundle = 4
            let spacing: CGFloat = 4
            for t in 0..<tracesInBundle {
                let offset = (CGFloat(t) - CGFloat(tracesInBundle - 1) / 2) * spacing
                let perpX = -dir.dy * offset
                let perpY = dir.dx * offset
                let startX = cx + dir.dx * startOffset + perpX
                let startY = cy + dir.dy * startOffset + perpY
                let endX = cx + dir.dx * (startOffset + dir.length) + perpX
                let endY = cy + dir.dy * (startOffset + dir.length) + perpY
                tracePath.move(to: CGPoint(x: startX, y: startY))
                tracePath.addLine(to: CGPoint(x: endX, y: endY))
            }
        }

        let traceNode = SKShapeNode(path: tracePath)
        traceNode.strokeColor = CPUSectorColors.copper.withAlphaComponent(0.15)
        traceNode.lineWidth = 1.5
        traceNode.zPosition = zPos - 0.5
        node.addChild(traceNode)
    }

    // MARK: - Silkscreen Labels

    private func drawCPUSilkscreenLabels(to node: SKNode, baseX: CGFloat, baseY: CGFloat,
                                          width: CGFloat, height: CGFloat,
                                          isExcluded: (CGFloat, CGFloat) -> Bool,
                                          color: UIColor, zPos: CGFloat) {
        let labels: [(text: String, x: CGFloat, y: CGFloat)] = [
            ("LGA 1700", width / 2, 60),
            ("14nm", width - 120, height - 50),
            ("12-CORE", width - 100, 80),
            ("VRM", 80, height - 50),
            ("PHASE", 80, height - 140),
            ("CPU_SOCKET", width / 2, height - 50),
            ("PWR", 140, 100),
            ("VCORE", width - 150, height / 2),
        ]

        for lbl in labels {
            guard !isExcluded(lbl.x, lbl.y) else { continue }
            let label = SKLabelNode(text: lbl.text)
            label.fontName = "Menlo"
            label.fontSize = CGFloat.random(in: 7...10)
            label.fontColor = UIColor.white.withAlphaComponent(CGFloat.random(in: 0.2...0.35))
            label.position = CGPoint(x: baseX + lbl.x, y: baseY + lbl.y)
            label.horizontalAlignmentMode = .center
            label.zPosition = zPos + 0.2
            node.addChild(label)
        }
    }
}
