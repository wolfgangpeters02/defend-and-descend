import SpriteKit
import SwiftUI

extension TDGameScene {

    // MARK: - PSU Sector Components ("Zoomed-In PSU City")
    // Creates realistic PSU internal components as sector background
    // Sector coordinates: 0-1400 range (sector size is 1400x1400)

    /// Cached colors for PSU components - parsed once, reused everywhere
    struct PSUColors {
        static let capacitorBody = UIColor(hex: "#2a2a35") ?? .darkGray
        static let capacitorBandBlue = UIColor(hex: "#3366aa") ?? .blue
        static let capacitorBandGreen = UIColor(hex: "#338855") ?? .green
        static let capacitorBandDarkBlue = UIColor(hex: "#2a2a55") ?? .blue
        static let copper = UIColor(hex: "#b87333") ?? .orange
        static let transformerBody = UIColor(hex: "#1a1a22") ?? .black
        static let lamination = UIColor(hex: "#252530") ?? .darkGray
        static let heatSinkFin = UIColor(hex: "#3a3a45") ?? .gray
        static let connectorBody = UIColor(hex: "#1a1a1a") ?? .black
        static let goldPin = UIColor(hex: "#d4a600") ?? .yellow
        static let mosfetTab = UIColor(hex: "#4a4a55") ?? .gray
        static let ferriteCore = UIColor(hex: "#15151a") ?? .black
        static let ceramicBody = UIColor(hex: "#c4a882") ?? .brown
        static let leadWire = UIColor(hex: "#888888") ?? .gray
        static let theme = UIColor(hex: "#ffdd00") ?? .yellow
    }

    /// Main entry point for PSU sector decorations
    func addCapacitorSymbols(to node: SKNode, in sector: MegaBoardSector, color: UIColor) {
        drawPSUComponents(to: node, in: sector, themeColor: color)
    }

    /// Draw all PSU components - creates a "zoomed-in PSU" cityscape
    func drawPSUComponents(to node: SKNode, in sector: MegaBoardSector, themeColor: UIColor) {
        // PERFORMANCE OPTIMIZED: Uses batched paths instead of individual nodes
        // Reduces node count from ~200+ to ~30 nodes
        psuCapacitorNodes.removeAll()

        let baseX = sector.worldX
        let baseY = sector.worldY
        let width = sector.width
        let height = sector.height
        let zPos: CGFloat = 3

        let isNearLane = Self.isNearLane

        // Pre-generate random positions (seeded for consistency)
        var ceramicPositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var mosfetPositions: [(x: CGFloat, y: CGFloat)] = []
        var heatSinkPositions: [(x: CGFloat, y: CGFloat, finCount: Int, finH: CGFloat)] = []

        for _ in 0..<80 {
            let x = CGFloat.random(in: 50...(width - 50))
            let y = CGFloat.random(in: 50...(height - 50))
            if !isNearLane(x, y) {
                ceramicPositions.append((x, y, CGFloat.random(in: 8...14), CGFloat.random(in: 6...10)))
            }
        }
        for _ in 0..<25 {
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 100...(height - 100))
            if !isNearLane(x, y) { mosfetPositions.append((x, y)) }
        }
        for _ in 0..<10 {
            let x = CGFloat.random(in: 80...(width - 80))
            let y = CGFloat.random(in: 80...(height - 80))
            if !isNearLane(x, y) {
                heatSinkPositions.append((x, y, Int.random(in: 8...14), CGFloat.random(in: 40...65)))
            }
        }

        // ========== BATCHED CERAMIC CAPACITORS (1 node for all) ==========
        let ceramicPath = CGMutablePath()
        for pos in ceramicPositions {
            ceramicPath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let ceramicNode = SKShapeNode(path: ceramicPath)
        ceramicNode.fillColor = PSUColors.ceramicBody.withAlphaComponent(0.5)
        ceramicNode.strokeColor = themeColor.withAlphaComponent(0.15)
        ceramicNode.lineWidth = 0.5
        ceramicNode.zPosition = zPos - 0.2
        node.addChild(ceramicNode)

        // ========== BATCHED MOSFET BODIES (1 node for all) ==========
        let mosfetBodyPath = CGMutablePath()
        let mosfetTabPath = CGMutablePath()
        for pos in mosfetPositions {
            mosfetBodyPath.addRect(CGRect(x: baseX + pos.x - 12, y: baseY + pos.y - 16, width: 24, height: 32))
            mosfetTabPath.addRect(CGRect(x: baseX + pos.x - 16, y: baseY + pos.y + 16, width: 32, height: 8))
        }
        let mosfetBody = SKShapeNode(path: mosfetBodyPath)
        mosfetBody.fillColor = UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1.0)
        mosfetBody.strokeColor = themeColor.withAlphaComponent(0.2)
        mosfetBody.lineWidth = 0.5
        mosfetBody.zPosition = zPos - 0.1
        node.addChild(mosfetBody)

        let mosfetTab = SKShapeNode(path: mosfetTabPath)
        mosfetTab.fillColor = PSUColors.mosfetTab
        mosfetTab.strokeColor = .clear
        mosfetTab.zPosition = zPos - 0.05
        node.addChild(mosfetTab)

        // ========== BATCHED HEAT SINK FINS (1 node per heat sink) ==========
        for hs in heatSinkPositions {
            let finsPath = CGMutablePath()
            let finW: CGFloat = 4
            let spacing = finW + 3
            let totalW = CGFloat(hs.finCount) * spacing
            for f in 0..<hs.finCount {
                let fx = baseX + hs.x - totalW/2 + CGFloat(f) * spacing
                finsPath.addRect(CGRect(x: fx, y: baseY + hs.y - hs.finH/2, width: finW, height: hs.finH))
            }
            let fins = SKShapeNode(path: finsPath)
            fins.fillColor = UIColor(red: 0.22, green: 0.22, blue: 0.26, alpha: 1.0)
            fins.strokeColor = themeColor.withAlphaComponent(0.15)
            fins.lineWidth = 0.5
            fins.zPosition = zPos
            node.addChild(fins)
        }

        // ========== LARGE ELECTROLYTIC CAPACITORS (PERF: batched static geometry) ==========
        // Pre-generate positions and sizes
        let bandColors = [PSUColors.capacitorBandBlue, PSUColors.capacitorBandGreen, PSUColors.capacitorBandDarkBlue]
        let capWidth: CGFloat = 55
        struct CapData {
            let worldX: CGFloat; let worldY: CGFloat; let h: CGFloat; let bandColor: UIColor
        }
        var caps: [CapData] = []
        for _ in 0..<15 {
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 100...(height - 100))
            guard !isNearLane(x, y), caps.count < 12 else { continue }
            caps.append(CapData(worldX: baseX + x, worldY: baseY + y,
                                h: CGFloat.random(in: 65...110),
                                bandColor: bandColors[caps.count % bandColors.count]))
        }

        // Batch all static geometry into compound paths
        let shadowPath = CGMutablePath()
        let bodyPath = CGMutablePath()
        let topCapPath = CGMutablePath()
        let leadsPath = CGMutablePath()
        var bandPaths: [UIColor: CGMutablePath] = [:]
        for color in bandColors { bandPaths[color] = CGMutablePath() }

        for cap in caps {
            let cx = cap.worldX
            let cy = cap.worldY

            // Shadow (offset by 4, -4)
            shadowPath.addRoundedRect(in: CGRect(x: cx - capWidth/2 + 4, y: cy - cap.h/2 - 4,
                                                  width: capWidth, height: cap.h),
                                       cornerWidth: 8, cornerHeight: 8)
            // Body
            bodyPath.addRoundedRect(in: CGRect(x: cx - capWidth/2, y: cy - cap.h/2,
                                                width: capWidth, height: cap.h),
                                     cornerWidth: 8, cornerHeight: 8)
            // Band
            let bandHeight = cap.h * 0.25
            bandPaths[cap.bandColor]?.addRoundedRect(
                in: CGRect(x: cx - capWidth/2 + 2, y: cy + cap.h/2 - bandHeight - 4,
                           width: capWidth - 4, height: bandHeight),
                cornerWidth: 4, cornerHeight: 4)
            // Top cap
            topCapPath.addEllipse(in: CGRect(x: cx - capWidth/2 + 3, y: cy + cap.h/2 - 8,
                                              width: capWidth - 6, height: 12))
            // Leads
            leadsPath.move(to: CGPoint(x: cx - 12, y: cy - cap.h/2))
            leadsPath.addLine(to: CGPoint(x: cx - 12, y: cy - cap.h/2 - 15))
            leadsPath.move(to: CGPoint(x: cx + 12, y: cy - cap.h/2))
            leadsPath.addLine(to: CGPoint(x: cx + 12, y: cy - cap.h/2 - 15))
        }

        // Add batched static nodes (6 nodes instead of ~60)
        let shadowNode = SKShapeNode(path: shadowPath)
        shadowNode.fillColor = .black.withAlphaComponent(0.12)
        shadowNode.strokeColor = .clear
        shadowNode.zPosition = zPos + 0.15
        node.addChild(shadowNode)

        let bodyNode = SKShapeNode(path: bodyPath)
        bodyNode.fillColor = PSUColors.capacitorBody
        bodyNode.strokeColor = themeColor.withAlphaComponent(0.15)
        bodyNode.lineWidth = 1
        bodyNode.zPosition = zPos + 0.2
        node.addChild(bodyNode)

        for (color, path) in bandPaths {
            let bandNode = SKShapeNode(path: path)
            bandNode.fillColor = color.withAlphaComponent(0.6)
            bandNode.strokeColor = color.withAlphaComponent(0.3)
            bandNode.lineWidth = 1
            bandNode.zPosition = zPos + 0.21
            node.addChild(bandNode)
        }

        let topCapNode = SKShapeNode(path: topCapPath)
        topCapNode.fillColor = PSUColors.capacitorBody.withAlphaComponent(0.8)
        topCapNode.strokeColor = themeColor.withAlphaComponent(0.1)
        topCapNode.lineWidth = 1
        topCapNode.zPosition = zPos + 0.22
        node.addChild(topCapNode)

        let leadsNode = SKShapeNode(path: leadsPath)
        leadsNode.strokeColor = PSUColors.leadWire.withAlphaComponent(0.5)
        leadsNode.lineWidth = 2
        leadsNode.zPosition = zPos + 0.18
        node.addChild(leadsNode)

        // Per-cap animation containers (lightweight: container + breatheGlow + dischargeGlow)
        for cap in caps {
            let container = SKNode()
            container.position = CGPoint(x: cap.worldX, y: cap.worldY)
            container.zPosition = zPos + 0.25

            let glowRect = CGRect(x: -capWidth/2, y: -cap.h/2, width: capWidth, height: cap.h)
            let glowPath = CGMutablePath()
            glowPath.addRoundedRect(in: glowRect, cornerWidth: 8, cornerHeight: 8)

            let breatheGlow = SKShapeNode(path: glowPath)
            breatheGlow.fillColor = themeColor.withAlphaComponent(0.0)
            breatheGlow.strokeColor = .clear
            breatheGlow.name = "breatheGlow"
            container.addChild(breatheGlow)

            let dischargeGlow = SKShapeNode(path: glowPath)
            dischargeGlow.fillColor = .clear
            dischargeGlow.strokeColor = .clear
            dischargeGlow.name = "dischargeGlow"
            container.addChild(dischargeGlow)

            let breatheIn = SKAction.customAction(withDuration: 3.0) { [weak breatheGlow] _, elapsed in
                breatheGlow?.fillColor = themeColor.withAlphaComponent(0.08 * elapsed / 3.0)
            }
            let breatheOut = SKAction.customAction(withDuration: 3.0) { [weak breatheGlow] _, elapsed in
                breatheGlow?.fillColor = themeColor.withAlphaComponent(0.08 * (1 - elapsed / 3.0))
            }
            breatheGlow.run(SKAction.repeatForever(SKAction.sequence([breatheIn, breatheOut])),
                           withKey: "breathing")

            node.addChild(container)
            psuCapacitorNodes.append(container)
        }

        // ========== TRANSFORMERS (3 units - reduced) ==========
        let transformerPositions: [(x: CGFloat, y: CGFloat)] = [(200, 250), (1050, 350), (350, 1000)]
        for pos in transformerPositions {
            if !isNearLane(pos.x, pos.y) {
                let transformer = createTransformer(themeColor: themeColor)
                transformer.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                transformer.zPosition = zPos
                transformer.setScale(CGFloat.random(in: 0.75...1.0))
                node.addChild(transformer)
            }
        }

        // ========== 24-PIN CONNECTOR (1 unit) ==========
        let connector = create24PinConnector(themeColor: themeColor)
        connector.position = CGPoint(x: baseX + 1150, y: baseY + 200)
        connector.zPosition = zPos
        node.addChild(connector)

        // ========== INDUCTOR COILS (6 units - reduced) ==========
        for i in 0..<8 {
            let x = CGFloat.random(in: 150...(width - 150))
            let y = CGFloat.random(in: 150...(height - 150))
            guard !isNearLane(x, y) else { continue }
            if i >= 6 { break }

            let coil = createInductorCoil(themeColor: themeColor)
            coil.position = CGPoint(x: baseX + x, y: baseY + y)
            coil.zPosition = zPos
            coil.setScale(CGFloat.random(in: 0.7...1.0))
            node.addChild(coil)
        }

        // ========== PCB TRACES ==========
        addPSUTraces(to: node, baseX: baseX, baseY: baseY, zPos: zPos - 0.3)
    }

    // MARK: - PSU Component Factories

    /// Create a tall electrolytic capacitor with colored band
    /// - Parameters:
    ///   - height: Height of the capacitor body (85-110pt typical)
    ///   - bandColor: Pre-parsed UIColor for the manufacturer band
    ///   - themeColor: Theme accent color for subtle highlights
    func createElectrolyticCapacitor(height: CGFloat, bandColor: UIColor, themeColor: UIColor) -> SKNode {
        let container = SKNode()
        let width: CGFloat = 55

        // Main cylindrical body (drawn as rounded rect)
        let bodyPath = CGMutablePath()
        bodyPath.addRoundedRect(in: CGRect(x: -width/2, y: -height/2, width: width, height: height),
                                 cornerWidth: 8, cornerHeight: 8)

        // Add shadow first (behind body)
        addComponentShadow(to: container, shape: bodyPath, offset: CGPoint(x: 4, y: -4), alpha: 0.12)

        let body = SKShapeNode(path: bodyPath)
        body.fillColor = PSUColors.capacitorBody
        body.strokeColor = themeColor.withAlphaComponent(0.15)
        body.lineWidth = 1
        container.addChild(body)

        // Colored band at top (manufacturer marking)
        let bandHeight: CGFloat = height * 0.25
        let bandPath = CGMutablePath()
        bandPath.addRoundedRect(in: CGRect(x: -width/2 + 2, y: height/2 - bandHeight - 4, width: width - 4, height: bandHeight),
                                 cornerWidth: 4, cornerHeight: 4)
        let band = SKShapeNode(path: bandPath)
        band.fillColor = bandColor.withAlphaComponent(0.6)
        band.strokeColor = bandColor.withAlphaComponent(0.3)
        band.lineWidth = 1
        container.addChild(band)

        // Top cap (slightly lighter)
        let topCap = SKShapeNode(ellipseIn: CGRect(x: -width/2 + 3, y: height/2 - 8, width: width - 6, height: 12))
        topCap.fillColor = PSUColors.capacitorBody.withAlphaComponent(0.8)
        topCap.strokeColor = themeColor.withAlphaComponent(0.1)
        topCap.lineWidth = 1
        container.addChild(topCap)

        // Leads (both in single path for efficiency)
        let leads = SKShapeNode()
        let leadsPath = CGMutablePath()
        leadsPath.move(to: CGPoint(x: -12, y: -height/2))
        leadsPath.addLine(to: CGPoint(x: -12, y: -height/2 - 15))
        leadsPath.move(to: CGPoint(x: 12, y: -height/2))
        leadsPath.addLine(to: CGPoint(x: 12, y: -height/2 - 15))
        leads.path = leadsPath
        leads.strokeColor = PSUColors.leadWire.withAlphaComponent(0.5)
        leads.lineWidth = 2
        container.addChild(leads)

        // Glow overlay for breathing animation (separate from discharge effect)
        let breatheGlow = SKShapeNode(path: bodyPath)
        breatheGlow.fillColor = themeColor.withAlphaComponent(0.0)
        breatheGlow.strokeColor = .clear
        breatheGlow.name = "breatheGlow"
        container.addChild(breatheGlow)

        // Discharge overlay (separate node to avoid animation conflicts)
        let dischargeGlow = SKShapeNode(path: bodyPath)
        dischargeGlow.fillColor = .clear
        dischargeGlow.strokeColor = .clear
        dischargeGlow.name = "dischargeGlow"
        container.addChild(dischargeGlow)

        // Subtle breathing animation (runs continuously, doesn't conflict with discharge)
        let breatheIn = SKAction.customAction(withDuration: 3.0) { [weak breatheGlow] _, elapsed in
            let progress = elapsed / 3.0
            breatheGlow?.fillColor = themeColor.withAlphaComponent(0.08 * progress)
        }
        let breatheOut = SKAction.customAction(withDuration: 3.0) { [weak breatheGlow] _, elapsed in
            let progress = elapsed / 3.0
            breatheGlow?.fillColor = themeColor.withAlphaComponent(0.08 * (1 - progress))
        }
        let breatheCycle = SKAction.sequence([breatheIn, breatheOut])
        breatheGlow.run(SKAction.repeatForever(breatheCycle), withKey: "breathing")

        return container
    }

    /// Create main transformer with E-I core and copper windings
    func createTransformer(themeColor: UIColor) -> SKNode {
        let container = SKNode()
        let width: CGFloat = 150
        let height: CGFloat = 100

        // Main body (E-I core)
        let bodyPath = CGMutablePath()
        bodyPath.addRect(CGRect(x: -width/2, y: -height/2, width: width, height: height))

        // Add shadow (larger component = more prominent shadow)
        addComponentShadow(to: container, shape: bodyPath, offset: CGPoint(x: 5, y: -5), alpha: 0.15)

        let body = SKShapeNode(path: bodyPath)
        body.fillColor = PSUColors.transformerBody
        body.strokeColor = themeColor.withAlphaComponent(0.12)
        body.lineWidth = 2
        container.addChild(body)

        // E-core laminations (all in single path for efficiency)
        let laminations = SKShapeNode()
        let lamPath = CGMutablePath()
        for i in 0..<4 {
            let y = -height/2 + 20 + CGFloat(i) * 20
            lamPath.move(to: CGPoint(x: -width/2 + 10, y: y))
            lamPath.addLine(to: CGPoint(x: width/2 - 10, y: y))
        }
        laminations.path = lamPath
        laminations.strokeColor = PSUColors.lamination.withAlphaComponent(0.8)
        laminations.lineWidth = 1
        container.addChild(laminations)

        // Copper windings (all in single path for efficiency)
        let windings = SKShapeNode()
        let windingsPath = CGMutablePath()
        let windingWidth: CGFloat = 80
        let windingHeight: CGFloat = 50
        for row in 0..<3 {
            let y = -windingHeight/2 + CGFloat(row) * 18
            windingsPath.move(to: CGPoint(x: -windingWidth/2, y: y))
            // Create wavy pattern
            for i in 0..<8 {
                let x = -windingWidth/2 + CGFloat(i + 1) * (windingWidth / 8)
                let yOffset: CGFloat = (i % 2 == 0) ? 4 : -4
                windingsPath.addLine(to: CGPoint(x: x, y: y + yOffset))
            }
        }
        windings.path = windingsPath
        windings.strokeColor = PSUColors.copper.withAlphaComponent(0.3)
        windings.lineWidth = 3
        container.addChild(windings)

        return container
    }

    /// Create heat sink with aluminum fins
    func createHeatSink(finCount: Int, finHeight: CGFloat) -> SKNode {
        let container = SKNode()
        let finSpacing: CGFloat = 8
        let finWidth: CGFloat = 4
        let totalWidth = CGFloat(finCount) * finSpacing
        let baseHeight: CGFloat = 8

        // Overall shadow footprint (covers base and fins area)
        let shadowPath = CGMutablePath()
        shadowPath.addRect(CGRect(x: -totalWidth/2, y: -baseHeight/2, width: totalWidth, height: finHeight + baseHeight))
        addComponentShadow(to: container, shape: shadowPath, offset: CGPoint(x: 4, y: -4), alpha: 0.1)

        // Base plate
        let basePath = CGMutablePath()
        basePath.addRect(CGRect(x: -totalWidth/2, y: -baseHeight/2, width: totalWidth, height: baseHeight))
        let base = SKShapeNode(path: basePath)
        base.fillColor = PSUColors.heatSinkFin
        base.strokeColor = PSUColors.heatSinkFin.withAlphaComponent(0.8)
        base.lineWidth = 1
        container.addChild(base)

        // All fins in single path for efficiency
        let fins = SKShapeNode()
        let finsPath = CGMutablePath()
        for i in 0..<finCount {
            let x = -totalWidth/2 + CGFloat(i) * finSpacing + finSpacing/2
            finsPath.addRect(CGRect(x: x - finWidth/2, y: baseHeight/2, width: finWidth, height: finHeight))
        }
        fins.path = finsPath
        fins.fillColor = PSUColors.heatSinkFin.withAlphaComponent(0.9)
        fins.strokeColor = PSUColors.heatSinkFin.withAlphaComponent(0.5)
        fins.lineWidth = 0.5
        container.addChild(fins)

        return container
    }

    /// Create 24-pin main connector with gold pins
    /// Uses single path for all 24 pins to reduce node count
    func create24PinConnector(themeColor: UIColor) -> SKNode {
        let container = SKNode()
        let width: CGFloat = 180
        let height: CGFloat = 45

        // Connector body (black plastic housing)
        let bodyPath = CGMutablePath()
        bodyPath.addRoundedRect(in: CGRect(x: -width/2, y: -height/2, width: width, height: height),
                                 cornerWidth: 4, cornerHeight: 4)

        // Add shadow
        addComponentShadow(to: container, shape: bodyPath, offset: CGPoint(x: 4, y: -4), alpha: 0.12)

        let body = SKShapeNode(path: bodyPath)
        body.fillColor = PSUColors.connectorBody
        body.strokeColor = themeColor.withAlphaComponent(0.1)
        body.lineWidth = 1
        container.addChild(body)

        // Pin grid (12 x 2 = 24 pins) - all in single path for efficiency
        let pinRadius: CGFloat = 3
        let pinSpacingX: CGFloat = 13
        let pinSpacingY: CGFloat = 14

        let pins = SKShapeNode()
        let pinsPath = CGMutablePath()
        for row in 0..<2 {
            for col in 0..<12 {
                let x = -width/2 + 15 + CGFloat(col) * pinSpacingX
                let y = -pinSpacingY/2 + CGFloat(row) * pinSpacingY
                pinsPath.addEllipse(in: CGRect(x: x - pinRadius, y: y - pinRadius,
                                               width: pinRadius * 2, height: pinRadius * 2))
            }
        }
        pins.path = pinsPath
        pins.fillColor = PSUColors.goldPin.withAlphaComponent(0.35)
        pins.strokeColor = PSUColors.goldPin.withAlphaComponent(0.2)
        pins.lineWidth = 0.5
        container.addChild(pins)

        return container
    }

    /// Create MOSFET (power transistor)
    func createMOSFET(themeColor: UIColor) -> SKNode {
        let container = SKNode()
        let width: CGFloat = 22
        let height: CGFloat = 32

        // Main body
        let bodyPath = CGMutablePath()
        bodyPath.addRect(CGRect(x: -width/2, y: -height/2 + 8, width: width, height: height - 8))

        // Add shadow
        addComponentShadow(to: container, shape: bodyPath, offset: CGPoint(x: 2, y: -2), alpha: 0.1)

        let body = SKShapeNode(path: bodyPath)
        body.fillColor = PSUColors.connectorBody
        body.strokeColor = themeColor.withAlphaComponent(0.1)
        body.lineWidth = 1
        container.addChild(body)

        // Heat sink tab (top)
        let tabPath = CGMutablePath()
        tabPath.addRect(CGRect(x: -width/2 - 4, y: height/2 - 4, width: width + 8, height: 10))
        let tab = SKShapeNode(path: tabPath)
        tab.fillColor = PSUColors.mosfetTab
        tab.strokeColor = PSUColors.mosfetTab.withAlphaComponent(0.6)
        tab.lineWidth = 1
        container.addChild(tab)

        // Mounting hole in tab
        let hole = SKShapeNode(circleOfRadius: 3)
        hole.position = CGPoint(x: 0, y: height/2 + 1)
        hole.fillColor = PSUColors.connectorBody.withAlphaComponent(0.8)
        hole.strokeColor = PSUColors.mosfetTab.withAlphaComponent(0.4)
        hole.lineWidth = 0.5
        container.addChild(hole)

        // Legs (3 pins) - all in single path
        let legs = SKShapeNode()
        let legsPath = CGMutablePath()
        for i in 0..<3 {
            let x = -8 + CGFloat(i) * 8
            legsPath.move(to: CGPoint(x: x, y: -height/2 + 8))
            legsPath.addLine(to: CGPoint(x: x, y: -height/2 - 6))
        }
        legs.path = legsPath
        legs.strokeColor = PSUColors.leadWire.withAlphaComponent(0.4)
        legs.lineWidth = 2
        container.addChild(legs)

        return container
    }

    /// Create inductor coil with ferrite core
    func createInductorCoil(themeColor: UIColor) -> SKNode {
        let container = SKNode()
        let width: CGFloat = 55
        let height: CGFloat = 35

        // Ferrite core (dark block)
        let corePath = CGMutablePath()
        corePath.addRoundedRect(in: CGRect(x: -width/2, y: -height/2, width: width, height: height),
                                 cornerWidth: 6, cornerHeight: 6)

        // Add shadow
        addComponentShadow(to: container, shape: corePath, offset: CGPoint(x: 3, y: -3), alpha: 0.1)

        let core = SKShapeNode(path: corePath)
        core.fillColor = PSUColors.ferriteCore
        core.strokeColor = themeColor.withAlphaComponent(0.08)
        core.lineWidth = 1
        container.addChild(core)

        // Copper windings (all in single path)
        let windings = SKShapeNode()
        let windingsPath = CGMutablePath()
        for i in 0..<6 {
            let x = -width/2 + 8 + CGFloat(i) * 8
            windingsPath.move(to: CGPoint(x: x, y: height/2 - 5))
            windingsPath.addLine(to: CGPoint(x: x + 5, y: -height/2 + 5))
        }
        windings.path = windingsPath
        windings.strokeColor = PSUColors.copper.withAlphaComponent(0.25)
        windings.lineWidth = 2
        container.addChild(windings)

        return container
    }

    /// Create small ceramic capacitor
    func createCeramicCapacitor() -> SKNode {
        let container = SKNode()
        let width: CGFloat = 10
        let height: CGFloat = 6

        // Main body with end caps (all in single node for efficiency)
        let body = SKShapeNode()
        let bodyPath = CGMutablePath()
        bodyPath.addRoundedRect(in: CGRect(x: -width/2, y: -height/2, width: width, height: height),
                                 cornerWidth: 1, cornerHeight: 1)

        // Tiny shadow for small components
        addComponentShadow(to: container, shape: bodyPath, offset: CGPoint(x: 1, y: -1), alpha: 0.08)

        body.path = bodyPath
        body.fillColor = PSUColors.ceramicBody.withAlphaComponent(0.2)
        body.strokeColor = PSUColors.ceramicBody.withAlphaComponent(0.15)
        body.lineWidth = 0.5
        container.addChild(body)

        // End caps overlay (combined into single path)
        let endCapWidth: CGFloat = 2
        let endCaps = SKShapeNode()
        let endCapsPath = CGMutablePath()
        endCapsPath.addRect(CGRect(x: -width/2, y: -height/2, width: endCapWidth, height: height))
        endCapsPath.addRect(CGRect(x: width/2 - endCapWidth, y: -height/2, width: endCapWidth, height: height))
        endCaps.path = endCapsPath
        endCaps.fillColor = PSUColors.ceramicBody.withAlphaComponent(0.25)
        endCaps.strokeColor = .clear
        container.addChild(endCaps)

        return container
    }

}
