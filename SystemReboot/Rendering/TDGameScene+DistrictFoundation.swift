import SpriteKit
import SwiftUI

extension TDGameScene {

    /// Add via holes scattered around a sector
    func addSectorVias(to node: SKNode, in sector: MegaBoardSector, color: UIColor) {
        let viaCount = 12
        let viaRadius: CGFloat = 4
        let margin: CGFloat = 100  // Keep vias away from edges

        for _ in 0..<viaCount {
            let x = sector.worldX + margin + CGFloat.random(in: 0...(sector.width - margin * 2))
            let y = sector.worldY + margin + CGFloat.random(in: 0...(sector.height - margin * 2))

            // Via hole (dark center with ring)
            let via = SKShapeNode(circleOfRadius: viaRadius)
            via.position = CGPoint(x: x, y: y)
            via.fillColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
            via.strokeColor = color
            via.lineWidth = 1.5
            via.zPosition = -3
            node.addChild(via)

            // Copper pad around via
            let pad = SKShapeNode(circleOfRadius: viaRadius + 3)
            pad.position = CGPoint(x: x, y: y)
            pad.fillColor = .clear
            pad.strokeColor = UIColor(hex: MotherboardColors.copperTrace)?.withAlphaComponent(0.2) ?? UIColor.orange.withAlphaComponent(0.2)
            pad.lineWidth = 2
            pad.zPosition = -3.1
            node.addChild(pad)
        }
    }

    /// Add IC footprint decorations based on sector type
    func addSectorICs(to node: SKNode, in sector: MegaBoardSector) {
        let themeColor = UIColor(hex: sector.theme.primaryColorHex)?.withAlphaComponent(0.3) ?? UIColor.gray.withAlphaComponent(0.3)

        switch sector.theme {
        case .power:
            // Capacitor symbols for PSU
            addCapacitorSymbols(to: node, in: sector, color: themeColor)

        case .graphics:
            // Heat sink pattern for GPU
            addHeatSinkPattern(to: node, in: sector, color: themeColor)

        case .memory:
            // Memory chip rows for RAM/Cache
            addMemoryChips(to: node, in: sector, color: themeColor)

        case .storage:
            // SSD chip outlines
            addStorageChips(to: node, in: sector, color: themeColor)

        case .io:
            // Port/connector outlines
            addIOConnectors(to: node, in: sector, color: themeColor)

        case .network:
            // Network jack outline
            addNetworkJack(to: node, in: sector, color: themeColor)

        case .processing:
            // Small processor cache blocks
            addCacheBlocks(to: node, in: sector, color: themeColor)
        }
    }

    // MARK: - District Foundation System
    // Shared visual elements for all districts: street grids, vias, labels, shadows
    // Creates the cohesive "motherboard city" feel across all sectors

    /// Shared colors used across all districts
    private struct DistrictFoundationColors {
        // PCB base colors
        static let copper = UIColor(hex: "#b87333") ?? .orange
        static let copperPad = UIColor(hex: "#c48940") ?? .orange
        static let soldermask = UIColor(hex: "#0a0f0a") ?? .black
        static let silkscreen = UIColor(hex: "#ffffff") ?? .white
        static let via = UIColor(hex: "#1a1a22") ?? .black
        static let shadow = UIColor.black
    }

    /// Draw secondary street grid (cosmetic PCB traces) for a sector
    /// Creates the "city streets" pattern that connects to main lane
    func drawSecondaryStreetGrid(to node: SKNode, in sector: MegaBoardSector, themeColor: UIColor) {
        let baseX = sector.worldX
        let baseY = sector.worldY
        let width = sector.width
        let height = sector.height
        let zPos: CGFloat = 1  // Above substrate/grid, below components

        // Main arterial traces - copper color, clearly visible
        let arteryWidth: CGFloat = 6
        let arteryAlpha: CGFloat = 0.50

        // Side street traces - slightly thinner and dimmer
        let streetWidth: CGFloat = 4
        let streetAlpha: CGFloat = 0.35

        // Create arterial grid pattern using single path for efficiency
        let arteryPath = CGMutablePath()

        // Horizontal arteries (3 lines across sector)
        let hSpacing = height / 4
        for i in 1...3 {
            let y = baseY + hSpacing * CGFloat(i)
            // Add slight organic curve to avoid rigid grid look
            let curveOffset = CGFloat.random(in: -20...20)
            arteryPath.move(to: CGPoint(x: baseX + 50, y: y + curveOffset))
            arteryPath.addLine(to: CGPoint(x: baseX + width * 0.3, y: y))
            arteryPath.addLine(to: CGPoint(x: baseX + width * 0.7, y: y + curveOffset * 0.5))
            arteryPath.addLine(to: CGPoint(x: baseX + width - 50, y: y))
        }

        // Vertical arteries (3 lines down sector)
        let vSpacing = width / 4
        for i in 1...3 {
            let x = baseX + vSpacing * CGFloat(i)
            let curveOffset = CGFloat.random(in: -20...20)
            arteryPath.move(to: CGPoint(x: x + curveOffset, y: baseY + 50))
            arteryPath.addLine(to: CGPoint(x: x, y: baseY + height * 0.3))
            arteryPath.addLine(to: CGPoint(x: x + curveOffset * 0.5, y: baseY + height * 0.7))
            arteryPath.addLine(to: CGPoint(x: x, y: baseY + height - 50))
        }

        let arteryNode = SKShapeNode(path: arteryPath)
        arteryNode.strokeColor = DistrictFoundationColors.copper.withAlphaComponent(arteryAlpha)
        arteryNode.lineWidth = arteryWidth
        arteryNode.lineCap = .round
        arteryNode.lineJoin = .round
        arteryNode.zPosition = zPos
        node.addChild(arteryNode)

        // Side streets (smaller traces between arteries)
        let streetPath = CGMutablePath()

        // Horizontal side streets
        let hSideSpacing = height / 8
        for i in [1, 3, 5, 7] {
            let y = baseY + hSideSpacing * CGFloat(i)
            streetPath.move(to: CGPoint(x: baseX + 80, y: y))
            streetPath.addLine(to: CGPoint(x: baseX + width * 0.4, y: y))
            // Skip middle (where main lane typically runs)
            streetPath.move(to: CGPoint(x: baseX + width * 0.6, y: y))
            streetPath.addLine(to: CGPoint(x: baseX + width - 80, y: y))
        }

        // Vertical side streets
        let vSideSpacing = width / 8
        for i in [1, 3, 5, 7] {
            let x = baseX + vSideSpacing * CGFloat(i)
            streetPath.move(to: CGPoint(x: x, y: baseY + 80))
            streetPath.addLine(to: CGPoint(x: x, y: baseY + height * 0.4))
            streetPath.move(to: CGPoint(x: x, y: baseY + height * 0.6))
            streetPath.addLine(to: CGPoint(x: x, y: baseY + height - 80))
        }

        let streetNode = SKShapeNode(path: streetPath)
        streetNode.strokeColor = DistrictFoundationColors.copper.withAlphaComponent(streetAlpha)
        streetNode.lineWidth = streetWidth
        streetNode.lineCap = .round
        streetNode.zPosition = zPos - 0.1
        node.addChild(streetNode)
    }

    /// Add via "roundabouts" at trace intersections
    /// Creates small circular vias where streets cross - like traffic circles
    func addViaRoundabouts(to node: SKNode, in sector: MegaBoardSector, themeColor: UIColor) {
        let baseX = sector.worldX
        let baseY = sector.worldY
        let width = sector.width
        let height = sector.height
        let zPos: CGFloat = 1.5  // Just above streets, below components

        let viaRadius: CGFloat = 10
        let padRadius: CGFloat = 14

        // Place vias at grid intersections (where arteries cross)
        let hSpacing = height / 4
        let vSpacing = width / 4

        // Create single path for all via holes (efficiency)
        let viaHolePath = CGMutablePath()
        let viaPadPath = CGMutablePath()

        for row in 1...3 {
            for col in 1...3 {
                let x = baseX + vSpacing * CGFloat(col)
                let y = baseY + hSpacing * CGFloat(row)

                // Add slight offset for organic feel
                let offset = CGPoint(
                    x: CGFloat.random(in: -15...15),
                    y: CGFloat.random(in: -15...15)
                )

                let center = CGPoint(x: x + offset.x, y: y + offset.y)

                // Via hole (dark center)
                viaHolePath.addEllipse(in: CGRect(
                    x: center.x - viaRadius,
                    y: center.y - viaRadius,
                    width: viaRadius * 2,
                    height: viaRadius * 2
                ))

                // Copper pad around via
                viaPadPath.addEllipse(in: CGRect(
                    x: center.x - padRadius,
                    y: center.y - padRadius,
                    width: padRadius * 2,
                    height: padRadius * 2
                ))
            }
        }

        // Pad layer (behind holes) - copper pads around vias
        let padNode = SKShapeNode(path: viaPadPath)
        padNode.fillColor = .clear
        padNode.strokeColor = DistrictFoundationColors.copperPad.withAlphaComponent(0.50)
        padNode.lineWidth = 4
        padNode.zPosition = zPos - 0.1
        node.addChild(padNode)

        // Via holes (dark centers with theme accent ring)
        let holeNode = SKShapeNode(path: viaHolePath)
        holeNode.fillColor = DistrictFoundationColors.via
        holeNode.strokeColor = themeColor.withAlphaComponent(0.60)
        holeNode.lineWidth = 2
        holeNode.zPosition = zPos
        node.addChild(holeNode)
    }

    /// Add silkscreen labels (faint component markings)
    /// Creates the "text" feel of real PCBs - very subtle
    func addSilkscreenLabels(to node: SKNode, in sector: MegaBoardSector, themeColor: UIColor) {
        let baseX = sector.worldX
        let baseY = sector.worldY
        let zPos: CGFloat = 2  // Above streets/vias, below components

        // Silkscreen labels - subtle but visible
        let labelAlpha: CGFloat = 0.35

        // Component reference designators scattered around
        let designators: [(text: String, x: CGFloat, y: CGFloat, rotation: CGFloat)] = [
            ("C1", 150, 200, 0),
            ("C2", 1200, 180, 0),
            ("R12", 400, 550, CGFloat.pi / 12),
            ("U3", 800, 700, 0),
            ("L1", 250, 850, -CGFloat.pi / 8),
            ("Q4", 1050, 450, CGFloat.pi / 6),
            ("D7", 600, 300, 0),
            ("T1", 700, 950, 0)
        ]

        for designator in designators {
            let label = SKLabelNode(text: designator.text)
            label.fontName = "Menlo"
            label.fontSize = 10
            label.fontColor = DistrictFoundationColors.silkscreen.withAlphaComponent(labelAlpha)
            label.position = CGPoint(x: baseX + designator.x, y: baseY + designator.y)
            label.zRotation = designator.rotation
            label.horizontalAlignmentMode = .left
            label.zPosition = zPos
            node.addChild(label)
        }

        // Add a few small silkscreen lines/boxes (component outlines)
        let outlinePath = CGMutablePath()

        // Small component outline boxes
        let outlines: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = [
            (160, 210, 30, 15),
            (1210, 190, 25, 12),
            (610, 310, 20, 10),
            (260, 860, 35, 18)
        ]

        for outline in outlines {
            outlinePath.addRect(CGRect(
                x: baseX + outline.x,
                y: baseY + outline.y,
                width: outline.w,
                height: outline.h
            ))
        }

        let outlineNode = SKShapeNode(path: outlinePath)
        outlineNode.fillColor = .clear
        outlineNode.strokeColor = DistrictFoundationColors.silkscreen.withAlphaComponent(labelAlpha * 0.8)
        outlineNode.lineWidth = 1
        outlineNode.zPosition = zPos
        node.addChild(outlineNode)
    }

    /// Add a drop shadow to a component for depth
    /// Creates subtle "building" shadow effect
    func addComponentShadow(to parent: SKNode, shape: CGPath, offset: CGPoint = CGPoint(x: 3, y: -3), alpha: CGFloat = 0.15) {
        let shadow = SKShapeNode(path: shape)
        shadow.fillColor = DistrictFoundationColors.shadow.withAlphaComponent(alpha)
        shadow.strokeColor = .clear
        shadow.position = offset
        shadow.zPosition = -0.5  // Behind the component
        parent.addChild(shadow)
    }
}
