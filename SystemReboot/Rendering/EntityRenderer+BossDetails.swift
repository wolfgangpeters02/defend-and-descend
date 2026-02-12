import SpriteKit

// MARK: - Boss Archetype Visual Compositions
// Phase 4-6: Multi-node boss-specific visuals.
// Shared between EntityRenderer (survival mode) and TDGameScene (TD mode).

extension EntityRenderer {

    // MARK: - 4A. Cyberboss — "Corporate AI Gone Rogue"
    // Theme: Sleek, geometric, chrome. 8-node composition.
    // Nodes: threat ring, shield hex, inner chassis, core processor, eye scanner,
    //        data ports (compound), status LEDs (compound), label placeholder

    /// Creates the full Cyberboss body composition.
    /// - Returns: Dictionary of named nodes for phase-specific updates.
    static func createCyberbossComposition(in container: SKNode, size: CGFloat) -> [String: SKNode] {
        var refs: [String: SKNode] = [:]

        // 1. Outer threat ring — red pulsing danger indicator
        let threatRing = SKShapeNode(circleOfRadius: size * 1.35)
        threatRing.fillColor = .clear
        threatRing.strokeColor = UIColor.red.withAlphaComponent(0.5)
        threatRing.lineWidth = 2
        threatRing.zPosition = -0.2
        threatRing.name = "threatRing"
        container.addChild(threatRing)
        refs["threatRing"] = threatRing

        // Threat ring pulse
        let ringPulse = SKAction.sequence([
            SKAction.scale(to: 1.05, duration: 1.0),
            SKAction.scale(to: 1.0, duration: 1.0)
        ])
        threatRing.run(SKAction.repeatForever(ringPulse))

        // 2. Shield hexagon — main body outline, chrome/silver
        let shieldPath = hexagonPathStatic(size: size * 1.1)
        let shield = SKShapeNode(path: shieldPath)
        shield.fillColor = .clear
        shield.strokeColor = UIColor.white.withAlphaComponent(0.8)
        shield.lineWidth = 3
        shield.name = "shield"
        container.addChild(shield)
        refs["shield"] = shield

        // 3. Inner chassis — slightly smaller hexagon, dark with circuit-trace stroke
        let chassisPath = hexagonPathStatic(size: size * 0.9)
        let chassis = SKShapeNode(path: chassisPath)
        chassis.fillColor = UIColor(hex: "0d1117")?.withAlphaComponent(0.9) ?? UIColor.black.withAlphaComponent(0.9)
        chassis.strokeColor = UIColor(hex: "00d4ff")?.withAlphaComponent(0.4) ?? UIColor.cyan.withAlphaComponent(0.4)
        chassis.lineWidth = 1.5
        chassis.name = "chassis"
        container.addChild(chassis)
        refs["chassis"] = chassis

        // 4. Core processor — central square, bright fill, slow rotation
        let coreSize = size * 0.35
        let core = SKShapeNode(rectOf: CGSize(width: coreSize, height: coreSize), cornerRadius: 2)
        core.fillColor = UIColor(hex: "00d4ff") ?? UIColor.cyan
        core.strokeColor = UIColor.white.withAlphaComponent(0.6)
        core.lineWidth = 1.5
        core.zPosition = 0.1
        core.name = "core"
        container.addChild(core)
        refs["core"] = core

        // Core rotation (8s full turn)
        let coreRotate = SKAction.rotate(byAngle: .pi * 2, duration: 8.0)
        core.run(SKAction.repeatForever(coreRotate))

        // 5. Eye/scanner — horizontal line that sweeps vertically
        let eyeWidth = size * 0.6
        let eyePath = CGMutablePath()
        eyePath.move(to: CGPoint(x: -eyeWidth / 2, y: 0))
        eyePath.addLine(to: CGPoint(x: eyeWidth / 2, y: 0))
        let eye = SKShapeNode(path: eyePath)
        eye.strokeColor = UIColor.red.withAlphaComponent(0.8)
        eye.lineWidth = 2
        eye.lineCap = .round
        eye.zPosition = 0.2
        eye.name = "eye"
        container.addChild(eye)
        refs["eye"] = eye

        // Eye sweep animation (2s up, 2s down)
        let scanHeight = size * 0.4
        let eyeSweep = SKAction.sequence([
            SKAction.moveTo(y: scanHeight, duration: 2.0),
            SKAction.moveTo(y: -scanHeight, duration: 2.0)
        ])
        eye.run(SKAction.repeatForever(eyeSweep))

        // 6. Data ports — 6 small squares at hexagon vertices (compound path, 1 node)
        let portPath = CGMutablePath()
        let portSize: CGFloat = size * 0.1
        for i in 0..<6 {
            let angle = CGFloat(i) * (.pi / 3) - (.pi / 2)
            let px = cos(angle) * size * 1.05
            let py = sin(angle) * size * 1.05
            portPath.addRect(CGRect(x: px - portSize / 2, y: py - portSize / 2,
                                    width: portSize, height: portSize))
        }
        let ports = SKShapeNode(path: portPath)
        ports.fillColor = UIColor(hex: "00d4ff")?.withAlphaComponent(0.6) ?? UIColor.cyan.withAlphaComponent(0.6)
        ports.strokeColor = UIColor.white.withAlphaComponent(0.3)
        ports.lineWidth = 0.5
        ports.name = "dataPorts"
        container.addChild(ports)
        refs["dataPorts"] = ports

        // 7. Status LEDs — 3 dots on right side (compound path, 1 node)
        let ledPath = CGMutablePath()
        let ledRadius: CGFloat = size * 0.06
        let ledBaseX = size * 0.55
        let ledSpacing: CGFloat = size * 0.18
        for i in 0..<3 {
            let ly = CGFloat(i - 1) * ledSpacing
            ledPath.addArc(center: CGPoint(x: ledBaseX, y: ly), radius: ledRadius,
                           startAngle: 0, endAngle: .pi * 2, clockwise: false)
        }
        let leds = SKShapeNode(path: ledPath)
        leds.fillColor = UIColor.green  // Phase 1: all green
        leds.strokeColor = .clear
        leds.zPosition = 0.2
        leds.name = "statusLEDs"
        container.addChild(leds)
        refs["statusLEDs"] = leds

        // LED sequential blink
        let ledBlink = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.4, duration: 0.3),
            SKAction.fadeAlpha(to: 1.0, duration: 0.3),
            SKAction.wait(forDuration: 0.4)
        ])
        leds.run(SKAction.repeatForever(ledBlink))

        // Body node for name reference (use chassis as the "body" for hit detection)
        chassis.name = "body"

        return refs
    }

    // MARK: - 6A. Overclocker — "CPU Overheat"
    // Theme: Overheating CPU. Red/orange, industrial, heat distortion.
    // Nodes: body octagon, heat-sink fins (compound), heat gauge arc,
    //        thermal vents (compound), core clock, inner circuit, warning ring = 7

    /// Creates the full Overclocker body composition.
    static func createOverclockerComposition(in container: SKNode, size: CGFloat) -> [String: SKNode] {
        var refs: [String: SKNode] = [:]
        let heatOrange = UIColor(hex: "ff4400") ?? UIColor.orange
        let amber = UIColor(hex: "ffaa00") ?? UIColor.yellow

        // 1. Warning ring — outer pulsing danger indicator
        let warningRing = SKShapeNode(circleOfRadius: size * 1.3)
        warningRing.fillColor = .clear
        warningRing.strokeColor = heatOrange.withAlphaComponent(0.35)
        warningRing.lineWidth = 1.5
        warningRing.zPosition = -0.2
        warningRing.name = "warningRing"
        container.addChild(warningRing)
        refs["warningRing"] = warningRing

        let warnPulse = SKAction.sequence([
            SKAction.scale(to: 1.04, duration: 0.8),
            SKAction.scale(to: 1.0, duration: 0.8)
        ])
        warningRing.run(SKAction.repeatForever(warnPulse))

        // 2. Body — octagon (CPU die shape)
        let octPath = CGMutablePath()
        for i in 0..<8 {
            let angle = CGFloat(i) * (.pi / 4) - (.pi / 8)
            let pt = CGPoint(x: cos(angle) * size, y: sin(angle) * size)
            if i == 0 { octPath.move(to: pt) } else { octPath.addLine(to: pt) }
        }
        octPath.closeSubpath()
        let body = SKShapeNode(path: octPath)
        body.fillColor = UIColor(hex: "1a0800")?.withAlphaComponent(0.9) ?? UIColor.black.withAlphaComponent(0.9)
        body.strokeColor = heatOrange
        body.lineWidth = 3
        body.name = "body"
        container.addChild(body)
        refs["body"] = body

        // 3. Heat-sink fins — 4 rectangular fin pairs on edges (compound path)
        let finPath = CGMutablePath()
        let finLen: CGFloat = size * 0.3
        let finWidth: CGFloat = size * 0.06
        for i in 0..<4 {
            let angle = CGFloat(i) * (.pi / 2)
            let baseX = cos(angle) * size * 0.85
            let baseY = sin(angle) * size * 0.85
            // Two parallel fin lines
            let perpX = -sin(angle) * finLen / 2
            let perpY = cos(angle) * finLen / 2
            let outX = cos(angle) * finWidth
            let outY = sin(angle) * finWidth
            finPath.move(to: CGPoint(x: baseX + perpX, y: baseY + perpY))
            finPath.addLine(to: CGPoint(x: baseX - perpX, y: baseY - perpY))
            finPath.move(to: CGPoint(x: baseX + perpX + outX, y: baseY + perpY + outY))
            finPath.addLine(to: CGPoint(x: baseX - perpX + outX, y: baseY - perpY + outY))
        }
        let fins = SKShapeNode(path: finPath)
        fins.strokeColor = amber.withAlphaComponent(0.5)
        fins.lineWidth = 2
        fins.lineCap = .round
        container.addChild(fins)
        refs["fins"] = fins

        // 4. Heat gauge arc — temperature indicator around body
        let gaugePath = CGMutablePath()
        gaugePath.addArc(center: .zero, radius: size * 1.15,
                         startAngle: .pi * 0.75, endAngle: .pi * 0.25,
                         clockwise: true)
        let gauge = SKShapeNode(path: gaugePath)
        gauge.strokeColor = heatOrange.withAlphaComponent(0.6)
        gauge.lineWidth = 3
        gauge.lineCap = .round
        gauge.name = "heatGauge"
        container.addChild(gauge)
        refs["heatGauge"] = gauge

        // 5. Core clock — central spinning element
        let clockPath = CGMutablePath()
        let clockR = size * 0.25
        clockPath.move(to: CGPoint(x: 0, y: clockR))
        clockPath.addLine(to: CGPoint(x: 0, y: -clockR))
        clockPath.move(to: CGPoint(x: -clockR, y: 0))
        clockPath.addLine(to: CGPoint(x: clockR, y: 0))
        // Diagonal ticks
        let diagR = clockR * 0.7
        clockPath.move(to: CGPoint(x: diagR, y: diagR))
        clockPath.addLine(to: CGPoint(x: -diagR, y: -diagR))
        clockPath.move(to: CGPoint(x: -diagR, y: diagR))
        clockPath.addLine(to: CGPoint(x: diagR, y: -diagR))
        let clock = SKShapeNode(path: clockPath)
        clock.strokeColor = amber
        clock.lineWidth = 1.5
        clock.lineCap = .round
        clock.zPosition = 0.1
        clock.name = "coreClock"
        container.addChild(clock)
        refs["coreClock"] = clock

        // Clock spinning (gets faster with phases)
        let clockSpin = SKAction.rotate(byAngle: .pi * 2, duration: 4.0)
        clock.run(SKAction.repeatForever(clockSpin))

        // 6. Inner circuit pattern
        let circuitPath = CGMutablePath()
        let cr = size * 0.5
        circuitPath.addRect(CGRect(x: -cr / 2, y: -cr / 2, width: cr, height: cr))
        let circuit = SKShapeNode(path: circuitPath)
        circuit.fillColor = .clear
        circuit.strokeColor = heatOrange.withAlphaComponent(0.3)
        circuit.lineWidth = 1
        circuit.zPosition = 0.05
        container.addChild(circuit)
        refs["innerCircuit"] = circuit

        // 7. Thermal vents — 4 small openings (compound path)
        let ventPath = CGMutablePath()
        let ventSize: CGFloat = size * 0.08
        for i in 0..<4 {
            let angle = CGFloat(i) * (.pi / 2) + (.pi / 4)
            let vx = cos(angle) * size * 0.65
            let vy = sin(angle) * size * 0.65
            ventPath.addEllipse(in: CGRect(x: vx - ventSize, y: vy - ventSize / 2,
                                           width: ventSize * 2, height: ventSize))
        }
        let vents = SKShapeNode(path: ventPath)
        vents.fillColor = heatOrange.withAlphaComponent(0.4)
        vents.strokeColor = amber.withAlphaComponent(0.3)
        vents.lineWidth = 0.5
        vents.zPosition = 0.1
        vents.name = "thermalVents"
        container.addChild(vents)
        refs["thermalVents"] = vents

        return refs
    }

    // MARK: - 6B. Trojan Wyrm Head — "Parasitic Data Worm"
    // Theme: Organic worm, segmented, parasitic. Head detail node.
    // Adds jaw/mouth detail and eye dots to the existing head segment.

    /// Adds Trojan Wyrm head details to an existing head node.
    static func addTrojanWyrmHeadDetails(to container: SKNode, size: CGFloat) {
        let wyrmGreen = UIColor(hex: "00ff45") ?? UIColor.green
        let lime = UIColor(hex: "88ff00") ?? UIColor.yellow

        // Jaw/mouth — V-shaped opening at front
        let jawPath = CGMutablePath()
        jawPath.move(to: CGPoint(x: -size * 0.5, y: size * 0.6))
        jawPath.addLine(to: CGPoint(x: 0, y: size * 1.1))
        jawPath.addLine(to: CGPoint(x: size * 0.5, y: size * 0.6))
        let jaw = SKShapeNode(path: jawPath)
        jaw.strokeColor = lime
        jaw.fillColor = .clear
        jaw.lineWidth = 2.5
        jaw.lineCap = .round
        jaw.zPosition = 0.1
        container.addChild(jaw)

        // Eye dots — 2 small red dots
        let eyePath = CGMutablePath()
        let eyeRadius: CGFloat = size * 0.12
        eyePath.addArc(center: CGPoint(x: -size * 0.25, y: size * 0.3),
                       radius: eyeRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        eyePath.addArc(center: CGPoint(x: size * 0.25, y: size * 0.3),
                       radius: eyeRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        let eyes = SKShapeNode(path: eyePath)
        eyes.fillColor = UIColor.red
        eyes.strokeColor = .clear
        eyes.zPosition = 0.2
        container.addChild(eyes)

        // Inner mandible detail
        let mandiblePath = CGMutablePath()
        mandiblePath.move(to: CGPoint(x: -size * 0.2, y: size * 0.1))
        mandiblePath.addLine(to: CGPoint(x: 0, y: size * 0.5))
        mandiblePath.addLine(to: CGPoint(x: size * 0.2, y: size * 0.1))
        let mandible = SKShapeNode(path: mandiblePath)
        mandible.strokeColor = wyrmGreen.withAlphaComponent(0.5)
        mandible.fillColor = .clear
        mandible.lineWidth = 1
        mandible.zPosition = 0.1
        container.addChild(mandible)
    }

    // MARK: - Path Helper (Static)

    /// Hexagon path helper — static version for use in extensions
    static func hexagonPathStatic(size: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2
            let pt = CGPoint(x: cos(angle) * size, y: sin(angle) * size)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}
