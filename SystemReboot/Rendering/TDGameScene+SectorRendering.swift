import SpriteKit
import SwiftUI

extension TDGameScene {

    // MARK: - Sector Ambient Effects System

    /// Start ambient effects for each sector to make districts feel alive
    func startSectorAmbientEffects() {
        let megaConfig = MegaBoardConfig.createDefault()

        for sector in megaConfig.sectors {
            // Skip CPU sector
            guard sector.id != SectorID.cpu.rawValue else { continue }

            switch sector.theme {
            case .power:
                startPSUSectorAmbient(sector: sector)
            case .graphics:
                startGPUSectorAmbient(sector: sector)
            case .memory:
                startRAMSectorAmbient(sector: sector)
            case .storage:
                startStorageSectorAmbient(sector: sector)
            case .network:
                startNetworkSectorAmbient(sector: sector)
            case .io:
                startIOSectorAmbient(sector: sector)
            case .processing:
                startCacheSectorAmbient(sector: sector)
            }
        }
    }

    // MARK: - PSU Sector Ambient (Power Theme)

    /// PSU sector: Minimal ambient effects - most visuals are static PSU components
    /// Power rails and capacitor sparks have been removed for cleaner aesthetic
    func startPSUSectorAmbient(sector: MegaBoardSector) {
        // PSU sector ambient effects are intentionally minimal
        // The "city" aesthetic comes from static PSU component decorations
        // Only very subtle voltage arcs remain (handled by startVoltageArcSystem)
    }

    // MARK: - GPU Sector Ambient (Heat Theme) - OPTIMIZED: No glow, slower spawn

    /// GPU sector: Simplified heat shimmer (no expensive glow effects)
    func startGPUSectorAmbient(sector: MegaBoardSector) {
        let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .red
        let center = CGPoint(x: sector.worldX + sector.width / 2, y: sector.worldY + sector.height / 2)

        // REMOVED: Thermal glow circle (expensive blur shader)
        // Heat shimmer emitter - slower spawn rate (was 0.15, now 0.4)
        let spawnShimmer = SKAction.run { [weak self] in
            self?.spawnHeatShimmer(at: center, color: themeColor)
        }

        let shimmerSequence = SKAction.repeatForever(SKAction.sequence([
            spawnShimmer,
            SKAction.wait(forDuration: 0.4)  // Slower spawn rate
        ]))

        backgroundLayer.run(shimmerSequence, withKey: "gpuHeat_\(sector.id)")
    }

    /// Spawn a heat shimmer particle - OPTIMIZED: no glow, simpler animation
    func spawnHeatShimmer(at center: CGPoint, color: UIColor) {
        guard ambientParticleCount < maxAmbientParticles else { return }
        ambientParticleCount += 1

        let shimmer = SKShapeNode(rectOf: CGSize(width: 3, height: 8))
        shimmer.position = CGPoint(
            x: center.x + CGFloat.random(in: -100...100),
            y: center.y - 100 + CGFloat.random(in: -50...50)
        )
        shimmer.fillColor = color.withAlphaComponent(0.4)
        shimmer.strokeColor = .clear
        shimmer.zPosition = -2.7
        // REMOVED: blendMode = .add (causes extra render pass)
        particleLayer.addChild(shimmer)

        // Simple rise and fade
        shimmer.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 80, duration: 1.5),
                SKAction.fadeOut(withDuration: 1.5)
            ]),
            SKAction.run { [weak self] in self?.ambientParticleCount -= 1 },
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - RAM Sector Ambient (Memory Theme)

    /// RAM sector: OPTIMIZED - Static LEDs with simple shared blink, no glow
    func startRAMSectorAmbient(sector: MegaBoardSector) {
        let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .green

        // Create static LED nodes (no individual animations)
        let chipBaseY = sector.worldY + sector.height / 2
        let chipX = sector.worldX + 150

        // Pre-defined blink pattern (which LEDs are "on" at each step)
        // Pattern cycles through showing different LEDs lit
        let blinkPatterns: [[Bool]] = [
            [true, false, false, true, false, true, false, false, true, false, false, true],
            [false, true, false, false, true, false, true, false, false, true, false, false],
            [true, true, false, false, false, true, false, true, false, false, true, false],
            [false, false, true, true, false, false, false, false, true, true, false, true],
        ]

        var allLEDs: [SKShapeNode] = []
        for chipIndex in 0..<4 {
            let yOffset = CGFloat(chipIndex) * 100 - 150
            for ledIndex in 0..<3 {
                let ledX = chipX + 50 + CGFloat(ledIndex) * 50
                let ledY = chipBaseY + yOffset + 30

                let led = SKShapeNode(circleOfRadius: 3)
                led.position = CGPoint(x: ledX, y: ledY)
                led.fillColor = themeColor.withAlphaComponent(0.2)
                led.strokeColor = themeColor.withAlphaComponent(0.4)
                led.lineWidth = 1
                // REMOVED: glowWidth, blendMode
                led.zPosition = -2.3
                backgroundLayer.addChild(led)
                allLEDs.append(led)
            }
        }

        // Single timer updates all LEDs with pre-defined pattern
        var patternIndex = 0
        let updateLEDs = SKAction.run { [weak self] in
            guard self != nil else { return }
            let pattern = blinkPatterns[patternIndex % blinkPatterns.count]
            for (i, led) in allLEDs.enumerated() {
                let isOn = pattern[i % pattern.count]
                led.fillColor = themeColor.withAlphaComponent(isOn ? 0.8 : 0.15)
            }
            patternIndex += 1
        }

        let blinkSequence = SKAction.repeatForever(SKAction.sequence([
            updateLEDs,
            SKAction.wait(forDuration: 0.3)  // Update every 0.3s (was random 0.05-0.15)
        ]))
        backgroundLayer.run(blinkSequence, withKey: "ramBlink_\(sector.id)")

        // Simplified data pulse (less frequent, no glow)
        startRAMDataPulse(sector: sector, color: themeColor)
    }

    /// RAM sector: Simplified data pulse - no glow, less frequent
    func startRAMDataPulse(sector: MegaBoardSector, color: UIColor) {
        let spawnPulse = SKAction.run { [weak self] in
            guard let self = self, self.ambientParticleCount < self.maxAmbientParticles else { return }
            self.ambientParticleCount += 1

            let pulseY = sector.worldY + sector.height / 2 + CGFloat.random(in: -100...100)
            let pulse = SKShapeNode(rectOf: CGSize(width: 300, height: 3))
            pulse.position = CGPoint(x: sector.worldX, y: pulseY)
            pulse.fillColor = color.withAlphaComponent(0.5)
            pulse.strokeColor = .clear
            // REMOVED: glowWidth, blendMode
            pulse.zPosition = -2.2
            self.particleLayer.addChild(pulse)

            pulse.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveTo(x: sector.worldX + sector.width, duration: 0.5),
                    SKAction.fadeOut(withDuration: 0.5)
                ]),
                SKAction.run { [weak self] in self?.ambientParticleCount -= 1 },
                SKAction.removeFromParent()
            ]))
        }

        let pulseSequence = SKAction.repeatForever(SKAction.sequence([
            SKAction.wait(forDuration: 4.0),  // Less frequent (was 2-5s random)
            spawnPulse
        ]))
        backgroundLayer.run(pulseSequence, withKey: "ramPulse_\(sector.id)")
    }

    // MARK: - Storage Sector Ambient - OPTIMIZED: No glow, simpler LED

    /// Storage sector: Simple activity LED, no trail particles
    func startStorageSectorAmbient(sector: MegaBoardSector) {
        let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .purple
        let chipCenter = CGPoint(x: sector.worldX + 325, y: sector.worldY + sector.height / 2)

        // Simple activity LED (no glow)
        let activityLED = SKShapeNode(circleOfRadius: 5)
        activityLED.position = CGPoint(x: chipCenter.x + 100, y: chipCenter.y + 50)
        activityLED.fillColor = themeColor.withAlphaComponent(0.3)
        activityLED.strokeColor = themeColor.withAlphaComponent(0.6)
        activityLED.lineWidth = 1
        // REMOVED: glowWidth, blendMode
        activityLED.zPosition = -2.3
        backgroundLayer.addChild(activityLED)

        // Simple on/off blink (not complex random pattern)
        let activityBlink = SKAction.repeatForever(SKAction.sequence([
            SKAction.run { activityLED.fillColor = themeColor.withAlphaComponent(0.8) },
            SKAction.wait(forDuration: 0.1),
            SKAction.run { activityLED.fillColor = themeColor.withAlphaComponent(0.2) },
            SKAction.wait(forDuration: 0.8)
        ]))
        activityLED.run(activityBlink, withKey: "storageActivity")

        // REMOVED: Data trail particles (too expensive, minimal visual impact)
    }

    /// Storage sector: Data trail - DISABLED for performance
    func startStorageDataTrail(sector: MegaBoardSector, color: UIColor) {
        // Disabled - particles were expensive for minimal visual impact
    }

    // MARK: - Network Sector Ambient - OPTIMIZED: No glow, less frequent rings

    /// Network sector: Simplified rings, static LEDs
    func startNetworkSectorAmbient(sector: MegaBoardSector) {
        let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .cyan
        let center = CGPoint(x: sector.worldX + sector.width / 2, y: sector.worldY + sector.height / 2)

        // Expanding signal rings (no glow, less frequent)
        let spawnRing = SKAction.run { [weak self] in
            guard let self = self, self.ambientParticleCount < self.maxAmbientParticles else { return }
            self.ambientParticleCount += 1

            let ring = SKShapeNode(circleOfRadius: 20)
            ring.position = center
            ring.fillColor = .clear
            ring.strokeColor = themeColor.withAlphaComponent(0.4)
            ring.lineWidth = 2
            // REMOVED: glowWidth, blendMode
            ring.zPosition = -2.8
            self.particleLayer.addChild(ring)

            ring.run(SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 8, duration: 2.0),
                    SKAction.fadeOut(withDuration: 2.0)
                ]),
                SKAction.run { [weak self] in self?.ambientParticleCount -= 1 },
                SKAction.removeFromParent()
            ]))
        }

        let ringSequence = SKAction.repeatForever(SKAction.sequence([
            spawnRing,
            SKAction.wait(forDuration: 2.5)  // Less frequent (was 1.5)
        ]))
        backgroundLayer.run(ringSequence, withKey: "networkRings_\(sector.id)")

        // Static packet LEDs with shared blink timer (no individual animations)
        var packetLEDs: [SKShapeNode] = []
        for i in 0..<4 {
            let led = SKShapeNode(rectOf: CGSize(width: 8, height: 4))
            led.position = CGPoint(x: center.x - 50 + CGFloat(i) * 30, y: center.y + 150)
            led.fillColor = themeColor.withAlphaComponent(0.2)
            led.strokeColor = .clear
            // REMOVED: glowWidth, blendMode
            led.zPosition = -2.3
            backgroundLayer.addChild(led)
            packetLEDs.append(led)
        }

        // Single timer updates all LEDs
        var blinkState = 0
        let blinkPattern: [[Bool]] = [[true, false, true, false], [false, true, false, true], [true, true, false, false], [false, false, true, true]]
        let updateLEDs = SKAction.run {
            let pattern = blinkPattern[blinkState % blinkPattern.count]
            for (i, led) in packetLEDs.enumerated() {
                led.fillColor = themeColor.withAlphaComponent(pattern[i] ? 0.8 : 0.15)
            }
            blinkState += 1
        }
        backgroundLayer.run(SKAction.repeatForever(SKAction.sequence([updateLEDs, SKAction.wait(forDuration: 0.4)])), withKey: "networkLEDs_\(sector.id)")
    }

    // MARK: - I/O Sector Ambient - OPTIMIZED: Static LEDs, no burst particles

    /// I/O sector: Static LEDs with simple shared blink
    func startIOSectorAmbient(sector: MegaBoardSector) {
        // Static USB LEDs (no individual animations, no glow)
        var usbLEDs: [SKShapeNode] = []
        for i in 0..<3 {
            let ledX = sector.worldX + 100 + CGFloat(i) * 120 + 40
            let ledY = sector.worldY + 200 + 25

            let led = SKShapeNode(circleOfRadius: 3)
            led.position = CGPoint(x: ledX, y: ledY)
            led.fillColor = UIColor.green.withAlphaComponent(0.2)
            led.strokeColor = .clear
            // REMOVED: glowWidth, blendMode
            led.zPosition = -2.3
            backgroundLayer.addChild(led)
            usbLEDs.append(led)
        }

        // Single timer updates all LEDs with rotating pattern
        var ledState = 0
        let updateLEDs = SKAction.run {
            for (i, led) in usbLEDs.enumerated() {
                let isOn = (i == ledState % 3)
                led.fillColor = UIColor.green.withAlphaComponent(isOn ? 0.8 : 0.15)
            }
            ledState += 1
        }
        backgroundLayer.run(SKAction.repeatForever(SKAction.sequence([updateLEDs, SKAction.wait(forDuration: 0.5)])), withKey: "ioLEDs_\(sector.id)")

        // REMOVED: Data burst particles (too expensive)
    }

    /// I/O sector: Data burst - DISABLED for performance
    func startIODataBurst(sector: MegaBoardSector, color: UIColor) {
        // Disabled - particles were expensive for minimal visual impact
    }

    // MARK: - Cache Sector Ambient - OPTIMIZED: No flash particles, simple speed lines

    /// Cache sector: Simplified - just occasional speed lines, no flash particles
    func startCacheSectorAmbient(sector: MegaBoardSector) {
        let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .blue

        // REMOVED: Cache hit flash particles (very expensive with glowWidth=15)
        // Only keep speed lines, but less frequent
        startCacheSpeedLines(sector: sector, color: themeColor)
    }

    /// Cache sector: Speed lines - simplified, no glow, less frequent
    func startCacheSpeedLines(sector: MegaBoardSector, color: UIColor) {
        let spawnLine = SKAction.run { [weak self] in
            guard let self = self, self.ambientParticleCount < self.maxAmbientParticles else { return }
            self.ambientParticleCount += 1

            let y = sector.worldY + CGFloat.random(in: 100...(sector.height - 100))
            let lineLength: CGFloat = 100  // Fixed length instead of random

            let line = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: sector.worldX, y: y))
            path.addLine(to: CGPoint(x: sector.worldX + lineLength, y: y))
            line.path = path
            line.strokeColor = color.withAlphaComponent(0.6)
            line.lineWidth = 2
            // REMOVED: glowWidth, blendMode
            line.zPosition = -2.6
            self.particleLayer.addChild(line)

            line.run(SKAction.sequence([
                SKAction.moveBy(x: sector.width + lineLength, y: 0, duration: 0.2),
                SKAction.run { [weak self] in self?.ambientParticleCount -= 1 },
                SKAction.removeFromParent()
            ]))
        }

        let lineSequence = SKAction.repeatForever(SKAction.sequence([
            SKAction.wait(forDuration: 0.8),  // Less frequent (was 0.2-0.6)
            spawnLine
        ]))
        backgroundLayer.run(lineSequence, withKey: "cacheLines_\(sector.id)")
    }

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

    // MARK: - PSU District Components ("Zoomed-In PSU City")
    // Creates realistic PSU internal components as district background
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

    /// Main entry point for PSU district decorations
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

        func isNearLane(_ x: CGFloat, _ y: CGFloat) -> Bool {
            if y > 500 && y < 900 && x > 300 && x < 1100 { return true }
            if x > 1000 && y > 400 && y < 700 { return true }
            return false
        }

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

        // ========== LARGE ELECTROLYTIC CAPACITORS (keep as individual - 12 units) ==========
        let bandColors = [PSUColors.capacitorBandBlue, PSUColors.capacitorBandGreen, PSUColors.capacitorBandDarkBlue]
        var capIndex = 0
        for _ in 0..<15 {
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 100...(height - 100))
            guard !isNearLane(x, y) else { continue }
            if capIndex >= 12 { break }

            let container = createElectrolyticCapacitor(
                height: CGFloat.random(in: 65...110),
                bandColor: bandColors[capIndex % bandColors.count],
                themeColor: themeColor
            )
            container.position = CGPoint(x: baseX + x, y: baseY + y)
            container.zPosition = zPos + 0.2
            node.addChild(container)
            psuCapacitorNodes.append(container)
            capIndex += 1
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


    /// Add heat sink pattern for GPU sector
    func addHeatSinkPattern(to node: SKNode, in sector: MegaBoardSector, color: UIColor) {
        // PERFORMANCE OPTIMIZED: Batched paths for GPU district
        let baseX = sector.worldX
        let baseY = sector.worldY
        let width = sector.width
        let height = sector.height
        let zPos: CGFloat = 3

        func isNearLane(_ x: CGFloat, _ y: CGFloat) -> Bool {
            if y > 500 && y < 900 && x > 300 && x < 1100 { return true }
            if x > 1000 && y > 400 && y < 700 { return true }
            return false
        }

        let heatSinkColor = UIColor(red: 0.25, green: 0.25, blue: 0.30, alpha: 1.0)
        let vramColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)
        let thermalPadColor = UIColor(red: 0.4, green: 0.35, blue: 0.5, alpha: 0.6)
        let copperColor = UIColor(hex: "#b87333") ?? .orange

        // Pre-generate positions
        var vramPositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var thermalPositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var vrmPositions: [(x: CGFloat, y: CGFloat)] = []
        var capPositions: [(x: CGFloat, y: CGFloat, r: CGFloat)] = []
        var heatSinkData: [(x: CGFloat, y: CGFloat, finCount: Int, finW: CGFloat, finH: CGFloat)] = []

        for _ in 0..<25 {
            let x = CGFloat.random(in: 60...(width - 60))
            let y = CGFloat.random(in: 60...(height - 60))
            if !isNearLane(x, y) {
                vramPositions.append((x, y, CGFloat.random(in: 28...42), CGFloat.random(in: 22...32)))
            }
        }
        for _ in 0..<20 {
            let x = CGFloat.random(in: 50...(width - 50))
            let y = CGFloat.random(in: 50...(height - 50))
            if !isNearLane(x, y) {
                thermalPositions.append((x, y, CGFloat.random(in: 18...35), CGFloat.random(in: 18...35)))
            }
        }
        for _ in 0..<10 {
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 100...(height - 100))
            if !isNearLane(x, y) { vrmPositions.append((x, y)) }
        }
        for _ in 0..<50 {
            let x = CGFloat.random(in: 40...(width - 40))
            let y = CGFloat.random(in: 40...(height - 40))
            if !isNearLane(x, y) { capPositions.append((x, y, CGFloat.random(in: 4...7))) }
        }
        for _ in 0..<10 {
            let x = CGFloat.random(in: 80...(width - 80))
            let y = CGFloat.random(in: 80...(height - 80))
            if !isNearLane(x, y) {
                heatSinkData.append((x, y, Int.random(in: 10...14), CGFloat.random(in: 4...5), CGFloat.random(in: 50...80)))
            }
        }

        // ========== BATCHED THERMAL PADS ==========
        let thermalPath = CGMutablePath()
        for pos in thermalPositions {
            thermalPath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let thermalNode = SKShapeNode(path: thermalPath)
        thermalNode.fillColor = thermalPadColor
        thermalNode.strokeColor = .clear
        thermalNode.zPosition = zPos - 0.2
        node.addChild(thermalNode)

        // ========== BATCHED VRAM CHIPS ==========
        let vramPath = CGMutablePath()
        for pos in vramPositions {
            vramPath.addRoundedRect(in: CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h), cornerWidth: 2, cornerHeight: 2)
        }
        let vramNode = SKShapeNode(path: vramPath)
        vramNode.fillColor = vramColor
        vramNode.strokeColor = color.withAlphaComponent(0.4)
        vramNode.lineWidth = 0.5
        vramNode.zPosition = zPos - 0.1
        node.addChild(vramNode)

        // ========== BATCHED VRMs ==========
        let vrmPath = CGMutablePath()
        for pos in vrmPositions {
            vrmPath.addRect(CGRect(x: baseX + pos.x - 8, y: baseY + pos.y - 12, width: 16, height: 24))
        }
        let vrmNode = SKShapeNode(path: vrmPath)
        vrmNode.fillColor = UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0)
        vrmNode.strokeColor = copperColor.withAlphaComponent(0.3)
        vrmNode.lineWidth = 0.5
        vrmNode.zPosition = zPos - 0.1
        node.addChild(vrmNode)

        // ========== BATCHED CAPACITORS ==========
        let capPath = CGMutablePath()
        for pos in capPositions {
            capPath.addEllipse(in: CGRect(x: baseX + pos.x - pos.r, y: baseY + pos.y - pos.r, width: pos.r * 2, height: pos.r * 2))
        }
        let capNode = SKShapeNode(path: capPath)
        capNode.fillColor = UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0)
        capNode.strokeColor = color.withAlphaComponent(0.15)
        capNode.lineWidth = 0.5
        capNode.zPosition = zPos - 0.3
        node.addChild(capNode)

        // ========== HEAT SINKS (batched fins per sink) ==========
        for hs in heatSinkData {
            let finsPath = CGMutablePath()
            let spacing = hs.finW + 3
            let totalW = CGFloat(hs.finCount) * spacing
            for f in 0..<hs.finCount {
                let fx = baseX + hs.x - totalW/2 + CGFloat(f) * spacing
                finsPath.addRect(CGRect(x: fx, y: baseY + hs.y - hs.finH/2, width: hs.finW, height: hs.finH))
            }
            let finsNode = SKShapeNode(path: finsPath)
            finsNode.fillColor = heatSinkColor
            finsNode.strokeColor = color.withAlphaComponent(0.2)
            finsNode.lineWidth = 0.5
            finsNode.zPosition = zPos
            node.addChild(finsNode)
        }

        // ========== GPU DIE (individual - 2 units) ==========
        let gpuDiePositions: [(x: CGFloat, y: CGFloat, label: String)] = [(350, 300, "GPU"), (900, 950, "VRAM")]
        for pos in gpuDiePositions {
            if !isNearLane(pos.x, pos.y) {
                let dieSize: CGFloat = 90
                let die = SKShapeNode(rect: CGRect(x: -dieSize/2, y: -dieSize/2, width: dieSize, height: dieSize), cornerRadius: 3)
                die.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                die.fillColor = UIColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1.0)
                die.strokeColor = color
                die.lineWidth = 2
                die.zPosition = zPos + 0.2
                node.addChild(die)

                let label = SKLabelNode(text: pos.label)
                label.fontName = "Menlo-Bold"
                label.fontSize = 12
                label.fontColor = color.withAlphaComponent(0.7)
                label.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                label.zPosition = zPos + 0.3
                node.addChild(label)
            }
        }
    }

    /// Add memory chip rows for RAM/Cache sectors - Dense "memory city"
    func addMemoryChips(to node: SKNode, in sector: MegaBoardSector, color: UIColor) {
        // PERFORMANCE OPTIMIZED: Uses batched paths instead of individual nodes
        let baseX = sector.worldX
        let baseY = sector.worldY
        let width = sector.width
        let height = sector.height
        let zPos: CGFloat = 3

        func isNearLane(_ x: CGFloat, _ y: CGFloat) -> Bool {
            if y > 500 && y < 900 && x > 300 && x < 1100 { return true }
            if x > 1000 && y > 400 && y < 700 { return true }
            return false
        }

        let chipColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)
        let goldColor = UIColor(hex: "#d4a600") ?? .yellow
        let pcbGreen = UIColor(red: 0.05, green: 0.12, blue: 0.08, alpha: 1.0)

        // Pre-generate positions for batching
        var dimmSlots: [(y: CGFloat, slotW: CGFloat, index: Int)] = []
        var contactPositions: [(x: CGFloat, y: CGFloat)] = []
        var dramChips: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var pinPositions: [(x: CGFloat, y: CGFloat)] = []
        var spdPositions: [(x: CGFloat, y: CGFloat)] = []
        var capPositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []

        // ========== Generate DIMM slot positions ==========
        let dimmSlotY: [CGFloat] = [150, 300, 450, 850, 1000, 1150]
        for (index, slotY) in dimmSlotY.enumerated() {
            if !isNearLane(width/2, slotY) {
                let slotW: CGFloat = width - 200
                dimmSlots.append((y: slotY, slotW: slotW, index: index))
                let contactCount = Int(slotW / 8)
                for c in 0..<contactCount {
                    contactPositions.append((x: 105 + CGFloat(c) * 8, y: slotY + 4))
                }
            }
        }

        // ========== Generate DRAM chip positions ==========
        for _ in 0..<50 {
            let x = CGFloat.random(in: 80...(width - 80))
            let y = CGFloat.random(in: 80...(height - 80))
            guard !isNearLane(x, y) else { continue }
            let chipW = CGFloat.random(in: 30...60)
            let chipH = CGFloat.random(in: 20...35)
            dramChips.append((x: x, y: y, w: chipW, h: chipH))
            let pinCount = Int(chipW / 6)
            for p in 0..<pinCount {
                pinPositions.append((x: x - chipW/2 + 3 + CGFloat(p) * 6, y: y + chipH/2))
                pinPositions.append((x: x - chipW/2 + 3 + CGFloat(p) * 6, y: y - chipH/2 - 4))
            }
        }

        // ========== Generate SPD positions ==========
        for _ in 0..<20 {
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 100...(height - 100))
            guard !isNearLane(x, y) else { continue }
            spdPositions.append((x: x, y: y))
        }

        // ========== Generate capacitor positions ==========
        for _ in 0..<100 {
            let x = CGFloat.random(in: 40...(width - 40))
            let y = CGFloat.random(in: 40...(height - 40))
            guard !isNearLane(x, y) else { continue }
            let capW = CGFloat.random(in: 4...8)
            let capH = CGFloat.random(in: 3...5)
            capPositions.append((x: x, y: y, w: capW, h: capH))
        }

        // ========== BATCHED DIMM SLOTS ==========
        let slotPath = CGMutablePath()
        for slot in dimmSlots {
            slotPath.addRoundedRect(in: CGRect(x: baseX + 100, y: baseY + slot.y, width: slot.slotW, height: 20), cornerWidth: 2, cornerHeight: 2)
        }
        let slotNode = SKShapeNode(path: slotPath)
        slotNode.fillColor = pcbGreen
        slotNode.strokeColor = color.withAlphaComponent(0.4)
        slotNode.lineWidth = 1
        slotNode.zPosition = zPos - 0.2
        node.addChild(slotNode)

        // ========== BATCHED GOLD CONTACTS ==========
        let contactPath = CGMutablePath()
        for pos in contactPositions {
            contactPath.addRect(CGRect(x: baseX + pos.x, y: baseY + pos.y, width: 4, height: 12))
        }
        let contactNode = SKShapeNode(path: contactPath)
        contactNode.fillColor = goldColor.withAlphaComponent(0.5)
        contactNode.strokeColor = .clear
        contactNode.zPosition = zPos - 0.1
        node.addChild(contactNode)

        // ========== BATCHED DRAM CHIPS ==========
        let chipPath = CGMutablePath()
        for chip in dramChips {
            chipPath.addRoundedRect(in: CGRect(x: baseX + chip.x - chip.w/2, y: baseY + chip.y - chip.h/2, width: chip.w, height: chip.h), cornerWidth: 2, cornerHeight: 2)
        }
        let chipNode = SKShapeNode(path: chipPath)
        chipNode.fillColor = chipColor
        chipNode.strokeColor = color.withAlphaComponent(0.4)
        chipNode.lineWidth = 1
        chipNode.zPosition = zPos
        node.addChild(chipNode)

        // ========== BATCHED CHIP PINS ==========
        let pinPath = CGMutablePath()
        for pos in pinPositions {
            pinPath.addRect(CGRect(x: baseX + pos.x, y: baseY + pos.y, width: 3, height: 4))
        }
        let pinNode = SKShapeNode(path: pinPath)
        pinNode.fillColor = goldColor.withAlphaComponent(0.3)
        pinNode.strokeColor = .clear
        pinNode.zPosition = zPos + 0.1
        node.addChild(pinNode)

        // ========== BATCHED SPD CHIPS ==========
        let spdPath = CGMutablePath()
        for pos in spdPositions {
            spdPath.addRoundedRect(in: CGRect(x: baseX + pos.x - 8, y: baseY + pos.y - 5, width: 16, height: 10), cornerWidth: 1, cornerHeight: 1)
        }
        let spdNode = SKShapeNode(path: spdPath)
        spdNode.fillColor = chipColor
        spdNode.strokeColor = color.withAlphaComponent(0.3)
        spdNode.lineWidth = 0.5
        spdNode.zPosition = zPos - 0.1
        node.addChild(spdNode)

        // ========== BATCHED CAPACITORS ==========
        let capPath = CGMutablePath()
        for pos in capPositions {
            capPath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let capNode = SKShapeNode(path: capPath)
        capNode.fillColor = UIColor(red: 0.6, green: 0.55, blue: 0.4, alpha: 0.4)
        capNode.strokeColor = .clear
        capNode.zPosition = zPos - 0.3
        node.addChild(capNode)

        // ========== DIMM LABELS (individual - few nodes) ==========
        for slot in dimmSlots {
            let label = SKLabelNode(text: "DIMM\(slot.index + 1)")
            label.fontName = "Menlo"
            label.fontSize = 8
            label.fontColor = color.withAlphaComponent(0.4)
            label.position = CGPoint(x: baseX + 80, y: baseY + slot.y + 5)
            label.horizontalAlignmentMode = .right
            label.zPosition = zPos
            node.addChild(label)
        }

        // ========== DDR5 LABELS (individual - few nodes) ==========
        let labels = ["DDR5", "16GB", "4800", "CL40", "1.1V"]
        for i in 0..<8 {
            let x = CGFloat.random(in: 150...(width - 150))
            let y = CGFloat.random(in: 150...(height - 150))
            guard !isNearLane(x, y) else { continue }
            let label = SKLabelNode(text: labels[i % labels.count])
            label.fontName = "Menlo"
            label.fontSize = CGFloat.random(in: 8...12)
            label.fontColor = color.withAlphaComponent(CGFloat.random(in: 0.2...0.4))
            label.position = CGPoint(x: baseX + x, y: baseY + y)
            label.zRotation = CGFloat.random(in: -0.1...0.1)
            label.zPosition = zPos + 0.2
            node.addChild(label)
        }
    }

    /// Add SSD chip outlines for Storage sector - Dense "storage city"
    func addStorageChips(to node: SKNode, in sector: MegaBoardSector, color: UIColor) {
        // PERFORMANCE OPTIMIZED: Uses batched paths instead of individual nodes
        let baseX = sector.worldX
        let baseY = sector.worldY
        let width = sector.width
        let height = sector.height
        let zPos: CGFloat = 3

        func isNearLane(_ x: CGFloat, _ y: CGFloat) -> Bool {
            if y > 500 && y < 900 && x > 300 && x < 1100 { return true }
            if x > 1000 && y > 400 && y < 700 { return true }
            return false
        }

        let chipColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)
        let goldColor = UIColor(hex: "#d4a600") ?? .yellow
        let controllerColor = UIColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1.0)

        // Pre-generate positions for batching
        var nandChips: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, hasLabel: Bool)] = []
        var cacheChips: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var pmicChips: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var ceramicCaps: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var resistors: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var m2Contacts: [(x: CGFloat, y: CGFloat)] = []

        // ========== Generate NAND positions ==========
        for _ in 0..<15 {
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 100...(height - 100))
            guard !isNearLane(x, y) else { continue }
            let chipW = CGFloat.random(in: 50...90)
            let chipH = CGFloat.random(in: 40...70)
            nandChips.append((x: x, y: y, w: chipW, h: chipH, hasLabel: Bool.random()))
        }

        // ========== Generate cache chip positions ==========
        for _ in 0..<10 {
            let x = CGFloat.random(in: 80...(width - 80))
            let y = CGFloat.random(in: 80...(height - 80))
            guard !isNearLane(x, y) else { continue }
            let cacheW: CGFloat = CGFloat.random(in: 25...40)
            let cacheH: CGFloat = CGFloat.random(in: 18...28)
            cacheChips.append((x: x, y: y, w: cacheW, h: cacheH))
        }

        // ========== Generate M.2 contact positions ==========
        let m2Y: CGFloat = 100
        if !isNearLane(width/2, m2Y) {
            let connW: CGFloat = 300
            for c in 0..<Int(connW / 5) {
                m2Contacts.append((x: 205 + CGFloat(c) * 5, y: m2Y + 5))
            }
        }

        // ========== Generate PMIC positions ==========
        for _ in 0..<20 {
            let x = CGFloat.random(in: 60...(width - 60))
            let y = CGFloat.random(in: 60...(height - 60))
            guard !isNearLane(x, y) else { continue }
            let pmicW: CGFloat = CGFloat.random(in: 12...20)
            let pmicH: CGFloat = CGFloat.random(in: 10...16)
            pmicChips.append((x: x, y: y, w: pmicW, h: pmicH))
        }

        // ========== Generate passive component positions ==========
        for _ in 0..<120 {
            let x = CGFloat.random(in: 30...(width - 30))
            let y = CGFloat.random(in: 30...(height - 30))
            guard !isNearLane(x, y) else { continue }
            let compW = CGFloat.random(in: 3...7)
            let compH = CGFloat.random(in: 2...5)
            if Bool.random() {
                ceramicCaps.append((x: x, y: y, w: compW, h: compH))
            } else {
                resistors.append((x: x, y: y, w: compW, h: compH))
            }
        }

        // ========== BATCHED NAND CHIPS ==========
        let nandPath = CGMutablePath()
        for chip in nandChips {
            nandPath.addRoundedRect(in: CGRect(x: baseX + chip.x - chip.w/2, y: baseY + chip.y - chip.h/2, width: chip.w, height: chip.h), cornerWidth: 3, cornerHeight: 3)
        }
        let nandNode = SKShapeNode(path: nandPath)
        nandNode.fillColor = chipColor
        nandNode.strokeColor = color.withAlphaComponent(0.5)
        nandNode.lineWidth = 1.5
        nandNode.zPosition = zPos
        node.addChild(nandNode)

        // NAND labels (individual - few nodes)
        for chip in nandChips where chip.hasLabel {
            let label = SKLabelNode(text: ["NAND", "3D", "TLC", "QLC"].randomElement()!)
            label.fontName = "Menlo"
            label.fontSize = 8
            label.fontColor = color.withAlphaComponent(0.5)
            label.position = CGPoint(x: baseX + chip.x, y: baseY + chip.y)
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.zPosition = zPos + 0.1
            node.addChild(label)
        }

        // ========== SSD CONTROLLER ICs (individual - large labeled) ==========
        let controllerPositions: [(x: CGFloat, y: CGFloat)] = [(250, 250), (900, 350), (400, 950)]
        for pos in controllerPositions {
            if !isNearLane(pos.x, pos.y) {
                let size: CGFloat = CGFloat.random(in: 60...80)
                let controller = SKShapeNode(rect: CGRect(x: -size/2, y: -size/2, width: size, height: size), cornerRadius: 4)
                controller.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                controller.fillColor = controllerColor
                controller.strokeColor = color
                controller.lineWidth = 2
                controller.zPosition = zPos + 0.2
                node.addChild(controller)

                let label = SKLabelNode(text: "CTRL")
                label.fontName = "Menlo-Bold"
                label.fontSize = 10
                label.fontColor = color.withAlphaComponent(0.6)
                label.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                label.zPosition = zPos + 0.3
                node.addChild(label)
            }
        }

        // ========== BATCHED CACHE CHIPS ==========
        let cachePath = CGMutablePath()
        for chip in cacheChips {
            cachePath.addRoundedRect(in: CGRect(x: baseX + chip.x - chip.w/2, y: baseY + chip.y - chip.h/2, width: chip.w, height: chip.h), cornerWidth: 1, cornerHeight: 1)
        }
        let cacheNode = SKShapeNode(path: cachePath)
        cacheNode.fillColor = chipColor
        cacheNode.strokeColor = UIColor.cyan.withAlphaComponent(0.3)
        cacheNode.lineWidth = 1
        cacheNode.zPosition = zPos
        node.addChild(cacheNode)

        // ========== M.2 CONNECTOR (single node) ==========
        if !isNearLane(width/2, m2Y) {
            let connW: CGFloat = 300
            let connH: CGFloat = 25
            let connector = SKShapeNode(rect: CGRect(x: 0, y: 0, width: connW, height: connH), cornerRadius: 2)
            connector.position = CGPoint(x: baseX + 200, y: baseY + m2Y)
            connector.fillColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
            connector.strokeColor = goldColor.withAlphaComponent(0.5)
            connector.lineWidth = 1
            connector.zPosition = zPos - 0.1
            node.addChild(connector)
        }

        // ========== BATCHED M.2 CONTACTS ==========
        if !m2Contacts.isEmpty {
            let contactPath = CGMutablePath()
            for pos in m2Contacts {
                contactPath.addRect(CGRect(x: baseX + pos.x, y: baseY + pos.y, width: 3, height: 15))
            }
            let contactNode = SKShapeNode(path: contactPath)
            contactNode.fillColor = goldColor.withAlphaComponent(0.4)
            contactNode.strokeColor = .clear
            contactNode.zPosition = zPos
            node.addChild(contactNode)
        }

        // ========== BATCHED PMIC CHIPS ==========
        let pmicPath = CGMutablePath()
        for chip in pmicChips {
            pmicPath.addRoundedRect(in: CGRect(x: baseX + chip.x - chip.w/2, y: baseY + chip.y - chip.h/2, width: chip.w, height: chip.h), cornerWidth: 1, cornerHeight: 1)
        }
        let pmicNode = SKShapeNode(path: pmicPath)
        pmicNode.fillColor = chipColor
        pmicNode.strokeColor = color.withAlphaComponent(0.2)
        pmicNode.lineWidth = 0.5
        pmicNode.zPosition = zPos - 0.1
        node.addChild(pmicNode)

        // ========== BATCHED CERAMIC CAPS ==========
        let capPath = CGMutablePath()
        for pos in ceramicCaps {
            capPath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let capNode = SKShapeNode(path: capPath)
        capNode.fillColor = UIColor(red: 0.6, green: 0.55, blue: 0.4, alpha: 0.3)
        capNode.strokeColor = .clear
        capNode.zPosition = zPos - 0.3
        node.addChild(capNode)

        // ========== BATCHED RESISTORS ==========
        let resPath = CGMutablePath()
        for pos in resistors {
            resPath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let resNode = SKShapeNode(path: resPath)
        resNode.fillColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.4)
        resNode.strokeColor = .clear
        resNode.zPosition = zPos - 0.3
        node.addChild(resNode)

        // ========== STORAGE LABELS (individual - few nodes) ==========
        let storageLabels = ["1TB", "2TB", "NVMe", "PCIe", "Gen4", "7000MB/s"]
        for i in 0..<6 {
            let x = CGFloat.random(in: 150...(width - 150))
            let y = CGFloat.random(in: 150...(height - 150))
            guard !isNearLane(x, y) else { continue }
            let label = SKLabelNode(text: storageLabels[i % storageLabels.count])
            label.fontName = "Menlo"
            label.fontSize = CGFloat.random(in: 7...10)
            label.fontColor = color.withAlphaComponent(CGFloat.random(in: 0.2...0.35))
            label.position = CGPoint(x: baseX + x, y: baseY + y)
            label.zPosition = zPos + 0.2
            node.addChild(label)
        }
    }

    /// Add I/O connector outlines - Dense "I/O hub city"
    func addIOConnectors(to node: SKNode, in sector: MegaBoardSector, color: UIColor) {
        // PERFORMANCE OPTIMIZED: Uses batched paths instead of individual nodes
        let baseX = sector.worldX
        let baseY = sector.worldY
        let width = sector.width
        let height = sector.height
        let zPos: CGFloat = 3

        func isNearLane(_ x: CGFloat, _ y: CGFloat) -> Bool {
            if y > 500 && y < 900 && x > 300 && x < 1100 { return true }
            if x > 1000 && y > 400 && y < 700 { return true }
            return false
        }

        let portColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
        let chipColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)
        let blueUSB = UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.6)

        // Pre-generate positions for batching
        var usbAPorts: [(x: CGFloat, y: CGFloat)] = []
        var usbATongues: [(x: CGFloat, y: CGFloat)] = []
        var usbCPorts: [(x: CGFloat, y: CGFloat)] = []
        var hdmiPorts: [(x: CGFloat, y: CGFloat)] = []
        var audioPorts: [(x: CGFloat, y: CGFloat, colorIndex: Int)] = []
        var diodePositions: [(x: CGFloat, y: CGFloat)] = []
        var ferritePositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var ceramicPositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []

        // ========== Generate USB-A positions ==========
        let usbARows: [(y: CGFloat, count: Int)] = [(150, 5), (250, 4), (1050, 5), (1150, 4)]
        for row in usbARows {
            if !isNearLane(400, row.y) {
                for i in 0..<row.count {
                    usbAPorts.append((x: 100 + CGFloat(i) * 80, y: row.y))
                    usbATongues.append((x: 105 + CGFloat(i) * 80, y: row.y + 9))
                }
            }
        }

        // ========== Generate USB-C positions ==========
        for _ in 0..<10 {
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 350...500)
            guard !isNearLane(x, y) else { continue }
            usbCPorts.append((x: x, y: y))
        }

        // ========== Generate HDMI positions ==========
        let hdmiPositions: [(x: CGFloat, y: CGFloat)] = [(150, 400), (250, 400), (1050, 400), (1150, 400), (200, 900), (300, 900)]
        for pos in hdmiPositions {
            if !isNearLane(pos.x, pos.y) {
                hdmiPorts.append(pos)
            }
        }

        // ========== Generate audio jack positions ==========
        for i in 0..<8 {
            let x = CGFloat.random(in: 600...(width - 100))
            let y = CGFloat.random(in: 200...400)
            guard !isNearLane(x, y) else { continue }
            audioPorts.append((x: x, y: y, colorIndex: i % 6))
        }

        // ========== Generate diode positions ==========
        for _ in 0..<30 {
            let x = CGFloat.random(in: 80...(width - 80))
            let y = CGFloat.random(in: 80...(height - 80))
            guard !isNearLane(x, y) else { continue }
            diodePositions.append((x: x, y: y))
        }

        // ========== Generate passive component positions ==========
        for _ in 0..<100 {
            let x = CGFloat.random(in: 40...(width - 40))
            let y = CGFloat.random(in: 40...(height - 40))
            guard !isNearLane(x, y) else { continue }
            let compW = CGFloat.random(in: 3...6)
            let compH = CGFloat.random(in: 2...4)
            if Bool.random() {
                ferritePositions.append((x: x, y: y, w: compW, h: compH))
            } else {
                ceramicPositions.append((x: x, y: y, w: compW, h: compH))
            }
        }

        // ========== BATCHED USB-A PORTS ==========
        let usbAPath = CGMutablePath()
        for pos in usbAPorts {
            usbAPath.addRoundedRect(in: CGRect(x: baseX + pos.x, y: baseY + pos.y, width: 55, height: 30), cornerWidth: 2, cornerHeight: 2)
        }
        let usbANode = SKShapeNode(path: usbAPath)
        usbANode.fillColor = portColor
        usbANode.strokeColor = blueUSB
        usbANode.lineWidth = 1.5
        usbANode.zPosition = zPos
        node.addChild(usbANode)

        // ========== BATCHED USB-A TONGUES ==========
        let tonguePath = CGMutablePath()
        for pos in usbATongues {
            tonguePath.addRect(CGRect(x: baseX + pos.x, y: baseY + pos.y, width: 45, height: 12))
        }
        let tongueNode = SKShapeNode(path: tonguePath)
        tongueNode.fillColor = blueUSB.withAlphaComponent(0.3)
        tongueNode.strokeColor = .clear
        tongueNode.zPosition = zPos + 0.1
        node.addChild(tongueNode)

        // ========== BATCHED USB-C PORTS ==========
        let usbCPath = CGMutablePath()
        for pos in usbCPorts {
            usbCPath.addRoundedRect(in: CGRect(x: baseX + pos.x - 17.5, y: baseY + pos.y - 7, width: 35, height: 14), cornerWidth: 7, cornerHeight: 7)
        }
        let usbCNode = SKShapeNode(path: usbCPath)
        usbCNode.fillColor = portColor
        usbCNode.strokeColor = color.withAlphaComponent(0.6)
        usbCNode.lineWidth = 1
        usbCNode.zPosition = zPos
        node.addChild(usbCNode)

        // ========== BATCHED HDMI PORTS ==========
        let hdmiPath = CGMutablePath()
        for pos in hdmiPorts {
            hdmiPath.addRoundedRect(in: CGRect(x: baseX + pos.x - 30, y: baseY + pos.y - 12.5, width: 60, height: 25), cornerWidth: 3, cornerHeight: 3)
        }
        let hdmiNode = SKShapeNode(path: hdmiPath)
        hdmiNode.fillColor = portColor
        hdmiNode.strokeColor = color.withAlphaComponent(0.5)
        hdmiNode.lineWidth = 1.5
        hdmiNode.zPosition = zPos
        node.addChild(hdmiNode)

        // ========== AUDIO JACKS (individual - few nodes with different colors) ==========
        let audioColors: [UIColor] = [.green, .blue, .systemPink, .orange, .gray, .black]
        for port in audioPorts {
            let jack = SKShapeNode(circleOfRadius: 12)
            jack.position = CGPoint(x: baseX + port.x, y: baseY + port.y)
            jack.fillColor = portColor
            jack.strokeColor = audioColors[port.colorIndex].withAlphaComponent(0.5)
            jack.lineWidth = 2
            jack.zPosition = zPos
            node.addChild(jack)
        }

        // ========== BATCHED AUDIO HOLES ==========
        let holePath = CGMutablePath()
        for port in audioPorts {
            holePath.addEllipse(in: CGRect(x: baseX + port.x - 5, y: baseY + port.y - 5, width: 10, height: 10))
        }
        let holeNode = SKShapeNode(path: holePath)
        holeNode.fillColor = .black
        holeNode.strokeColor = .clear
        holeNode.zPosition = zPos + 0.1
        node.addChild(holeNode)

        // ========== USB CONTROLLER ICs (individual - large labeled) ==========
        let controllerPositions: [(x: CGFloat, y: CGFloat)] = [(400, 200), (800, 250), (500, 1000), (900, 950)]
        for (index, pos) in controllerPositions.enumerated() {
            if !isNearLane(pos.x, pos.y) {
                let size: CGFloat = CGFloat.random(in: 45...65)
                let ctrl = SKShapeNode(rect: CGRect(x: -size/2, y: -size/2, width: size, height: size), cornerRadius: 3)
                ctrl.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                ctrl.fillColor = chipColor
                ctrl.strokeColor = color
                ctrl.lineWidth = 1.5
                ctrl.zPosition = zPos + 0.1
                node.addChild(ctrl)

                let label = SKLabelNode(text: ["USB", "HUB", "xHCI", "PHY"][index % 4])
                label.fontName = "Menlo"
                label.fontSize = 8
                label.fontColor = color.withAlphaComponent(0.5)
                label.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                label.zPosition = zPos + 0.2
                node.addChild(label)
            }
        }

        // ========== BATCHED ESD DIODES ==========
        let diodePath = CGMutablePath()
        for pos in diodePositions {
            diodePath.addRoundedRect(in: CGRect(x: baseX + pos.x - 6, y: baseY + pos.y - 4, width: 12, height: 8), cornerWidth: 1, cornerHeight: 1)
        }
        let diodeNode = SKShapeNode(path: diodePath)
        diodeNode.fillColor = chipColor
        diodeNode.strokeColor = color.withAlphaComponent(0.2)
        diodeNode.lineWidth = 0.5
        diodeNode.zPosition = zPos - 0.1
        node.addChild(diodeNode)

        // ========== BATCHED FERRITE BEADS ==========
        let ferritePath = CGMutablePath()
        for pos in ferritePositions {
            ferritePath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let ferriteNode = SKShapeNode(path: ferritePath)
        ferriteNode.fillColor = UIColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 0.4)
        ferriteNode.strokeColor = .clear
        ferriteNode.zPosition = zPos - 0.3
        node.addChild(ferriteNode)

        // ========== BATCHED CERAMIC CAPS ==========
        let ceramicPath = CGMutablePath()
        for pos in ceramicPositions {
            ceramicPath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let ceramicNode = SKShapeNode(path: ceramicPath)
        ceramicNode.fillColor = UIColor(red: 0.6, green: 0.55, blue: 0.4, alpha: 0.3)
        ceramicNode.strokeColor = .clear
        ceramicNode.zPosition = zPos - 0.3
        node.addChild(ceramicNode)

        // ========== I/O LABELS (individual - few nodes) ==========
        let ioLabels = ["USB 3.2", "USB-C", "HDMI", "DP", "AUDIO", "10Gbps"]
        for i in 0..<8 {
            let x = CGFloat.random(in: 150...(width - 150))
            let y = CGFloat.random(in: 150...(height - 150))
            guard !isNearLane(x, y) else { continue }
            let label = SKLabelNode(text: ioLabels[i % ioLabels.count])
            label.fontName = "Menlo"
            label.fontSize = CGFloat.random(in: 7...10)
            label.fontColor = color.withAlphaComponent(CGFloat.random(in: 0.2...0.35))
            label.position = CGPoint(x: baseX + x, y: baseY + y)
            label.zPosition = zPos + 0.2
            node.addChild(label)
        }
    }

    /// Add network jack outline
    func addNetworkJack(to node: SKNode, in sector: MegaBoardSector, color: UIColor) {
        // PERFORMANCE OPTIMIZED: Uses batched paths instead of individual nodes
        let baseX = sector.worldX
        let baseY = sector.worldY
        let width = sector.width
        let height = sector.height
        let zPos: CGFloat = 3

        func isNearLane(_ x: CGFloat, _ y: CGFloat) -> Bool {
            if y > 500 && y < 900 && x > 300 && x < 1100 { return true }
            if x > 1000 && y > 400 && y < 700 { return true }
            return false
        }

        let portColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
        let goldColor = UIColor(hex: "#d4a600") ?? .yellow
        let chipColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)
        let greenLED = UIColor.green
        let orangeLED = UIColor.orange

        // Pre-generate positions for batching
        var rj45Jacks: [(x: CGFloat, y: CGFloat)] = []
        var rj45Pins: [(x: CGFloat, y: CGFloat)] = []
        var greenLEDs: [(x: CGFloat, y: CGFloat)] = []
        var orangeLEDs: [(x: CGFloat, y: CGFloat)] = []
        var transformerPositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var smallICPositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var statusLEDs: [(x: CGFloat, y: CGFloat, r: CGFloat, colorType: Int)] = []
        var ferritePositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var ceramicPositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []

        // ========== Generate RJ45 positions ==========
        let jackPositions: [(x: CGFloat, y: CGFloat)] = [
            (150, 200), (280, 200), (410, 200),
            (150, 350), (280, 350),
            (150, 950), (280, 950), (410, 950)
        ]
        let jackW: CGFloat = 70
        let jackH: CGFloat = 55
        for pos in jackPositions {
            if !isNearLane(pos.x, pos.y) {
                rj45Jacks.append(pos)
                for p in 0..<8 {
                    rj45Pins.append((x: pos.x + 8 + CGFloat(p) * 7, y: pos.y + jackH - 15))
                }
                greenLEDs.append((x: pos.x + 12, y: pos.y + 8))
                orangeLEDs.append((x: pos.x + jackW - 12, y: pos.y + 8))
            }
        }

        // ========== Generate transformer positions ==========
        for _ in 0..<8 {
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 100...(height - 100))
            guard !isNearLane(x, y) else { continue }
            let magW: CGFloat = CGFloat.random(in: 35...55)
            let magH: CGFloat = CGFloat.random(in: 25...40)
            transformerPositions.append((x: x, y: y, w: magW, h: magH))
        }

        // ========== Generate small IC positions ==========
        for _ in 0..<25 {
            let x = CGFloat.random(in: 80...(width - 80))
            let y = CGFloat.random(in: 80...(height - 80))
            guard !isNearLane(x, y) else { continue }
            let icW: CGFloat = CGFloat.random(in: 15...28)
            let icH: CGFloat = CGFloat.random(in: 12...22)
            smallICPositions.append((x: x, y: y, w: icW, h: icH))
        }

        // ========== Generate status LED positions ==========
        for _ in 0..<15 {
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 100...(height - 100))
            guard !isNearLane(x, y) else { continue }
            let r = CGFloat.random(in: 3...5)
            statusLEDs.append((x: x, y: y, r: r, colorType: Int.random(in: 0..<3)))
        }

        // ========== Generate passive component positions ==========
        for _ in 0..<120 {
            let x = CGFloat.random(in: 40...(width - 40))
            let y = CGFloat.random(in: 40...(height - 40))
            guard !isNearLane(x, y) else { continue }
            let compW = CGFloat.random(in: 3...6)
            let compH = CGFloat.random(in: 2...4)
            if Bool.random() {
                ferritePositions.append((x: x, y: y, w: compW, h: compH))
            } else {
                ceramicPositions.append((x: x, y: y, w: compW, h: compH))
            }
        }

        // ========== BATCHED RJ45 JACKS ==========
        let jackPath = CGMutablePath()
        for pos in rj45Jacks {
            jackPath.addRoundedRect(in: CGRect(x: baseX + pos.x, y: baseY + pos.y, width: jackW, height: jackH), cornerWidth: 3, cornerHeight: 3)
        }
        let jackNode = SKShapeNode(path: jackPath)
        jackNode.fillColor = portColor
        jackNode.strokeColor = color.withAlphaComponent(0.6)
        jackNode.lineWidth = 1.5
        jackNode.zPosition = zPos
        node.addChild(jackNode)

        // ========== BATCHED RJ45 PINS ==========
        let pinPath = CGMutablePath()
        for pos in rj45Pins {
            pinPath.addRect(CGRect(x: baseX + pos.x, y: baseY + pos.y, width: 4, height: 12))
        }
        let pinNode = SKShapeNode(path: pinPath)
        pinNode.fillColor = goldColor.withAlphaComponent(0.5)
        pinNode.strokeColor = .clear
        pinNode.zPosition = zPos + 0.1
        node.addChild(pinNode)

        // ========== BATCHED GREEN LEDs ==========
        let greenPath = CGMutablePath()
        for pos in greenLEDs {
            greenPath.addEllipse(in: CGRect(x: baseX + pos.x - 4, y: baseY + pos.y - 4, width: 8, height: 8))
        }
        let greenNode = SKShapeNode(path: greenPath)
        greenNode.fillColor = greenLED.withAlphaComponent(0.4)
        greenNode.strokeColor = .clear
        greenNode.zPosition = zPos + 0.1
        node.addChild(greenNode)

        // ========== BATCHED ORANGE LEDs ==========
        let orangePath = CGMutablePath()
        for pos in orangeLEDs {
            orangePath.addEllipse(in: CGRect(x: baseX + pos.x - 4, y: baseY + pos.y - 4, width: 8, height: 8))
        }
        let orangeNode = SKShapeNode(path: orangePath)
        orangeNode.fillColor = orangeLED.withAlphaComponent(0.4)
        orangeNode.strokeColor = .clear
        orangeNode.zPosition = zPos + 0.1
        node.addChild(orangeNode)

        // ========== ETHERNET PHY CHIPS (individual - large labeled) ==========
        let phyPositions: [(x: CGFloat, y: CGFloat)] = [(600, 200), (900, 300), (550, 950), (850, 1000)]
        for (index, pos) in phyPositions.enumerated() {
            if !isNearLane(pos.x, pos.y) {
                let size: CGFloat = CGFloat.random(in: 50...70)
                let phy = SKShapeNode(rect: CGRect(x: -size/2, y: -size/2, width: size, height: size), cornerRadius: 3)
                phy.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                phy.fillColor = chipColor
                phy.strokeColor = color
                phy.lineWidth = 2
                phy.zPosition = zPos + 0.1
                node.addChild(phy)

                let label = SKLabelNode(text: ["PHY", "MAC", "ETH", "NIC"][index % 4])
                label.fontName = "Menlo-Bold"
                label.fontSize = 9
                label.fontColor = color.withAlphaComponent(0.5)
                label.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                label.zPosition = zPos + 0.2
                node.addChild(label)
            }
        }

        // ========== BATCHED TRANSFORMERS ==========
        let transPath = CGMutablePath()
        for pos in transformerPositions {
            transPath.addRoundedRect(in: CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h), cornerWidth: 2, cornerHeight: 2)
        }
        let transNode = SKShapeNode(path: transPath)
        transNode.fillColor = UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0)
        transNode.strokeColor = color.withAlphaComponent(0.3)
        transNode.lineWidth = 1
        transNode.zPosition = zPos
        node.addChild(transNode)

        // ========== BATCHED SMALL ICs ==========
        let icPath = CGMutablePath()
        for pos in smallICPositions {
            icPath.addRoundedRect(in: CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h), cornerWidth: 1, cornerHeight: 1)
        }
        let icNode = SKShapeNode(path: icPath)
        icNode.fillColor = chipColor
        icNode.strokeColor = color.withAlphaComponent(0.25)
        icNode.lineWidth = 0.5
        icNode.zPosition = zPos - 0.1
        node.addChild(icNode)

        // ========== BATCHED STATUS LEDs (by color) ==========
        let statusGreenPath = CGMutablePath()
        let statusOrangePath = CGMutablePath()
        let statusYellowPath = CGMutablePath()
        for led in statusLEDs {
            let rect = CGRect(x: baseX + led.x - led.r, y: baseY + led.y - led.r, width: led.r * 2, height: led.r * 2)
            switch led.colorType {
            case 0: statusGreenPath.addEllipse(in: rect)
            case 1: statusOrangePath.addEllipse(in: rect)
            default: statusYellowPath.addEllipse(in: rect)
            }
        }
        let statusGreenNode = SKShapeNode(path: statusGreenPath)
        statusGreenNode.fillColor = greenLED.withAlphaComponent(0.3)
        statusGreenNode.strokeColor = .clear
        statusGreenNode.zPosition = zPos
        node.addChild(statusGreenNode)

        let statusOrangeNode = SKShapeNode(path: statusOrangePath)
        statusOrangeNode.fillColor = orangeLED.withAlphaComponent(0.3)
        statusOrangeNode.strokeColor = .clear
        statusOrangeNode.zPosition = zPos
        node.addChild(statusOrangeNode)

        let statusYellowNode = SKShapeNode(path: statusYellowPath)
        statusYellowNode.fillColor = UIColor.yellow.withAlphaComponent(0.3)
        statusYellowNode.strokeColor = .clear
        statusYellowNode.zPosition = zPos
        node.addChild(statusYellowNode)

        // ========== BATCHED FERRITES ==========
        let ferritePath = CGMutablePath()
        for pos in ferritePositions {
            ferritePath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let ferriteNode = SKShapeNode(path: ferritePath)
        ferriteNode.fillColor = UIColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 0.4)
        ferriteNode.strokeColor = .clear
        ferriteNode.zPosition = zPos - 0.3
        node.addChild(ferriteNode)

        // ========== BATCHED CERAMICS ==========
        let ceramicPath = CGMutablePath()
        for pos in ceramicPositions {
            ceramicPath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let ceramicNode = SKShapeNode(path: ceramicPath)
        ceramicNode.fillColor = UIColor(red: 0.6, green: 0.55, blue: 0.4, alpha: 0.3)
        ceramicNode.strokeColor = .clear
        ceramicNode.zPosition = zPos - 0.3
        node.addChild(ceramicNode)

        // ========== NETWORK LABELS (individual - few nodes) ==========
        let netLabels = ["1G LAN", "2.5G", "ETH", "RJ45", "Cat6", "PoE"]
        for i in 0..<8 {
            let x = CGFloat.random(in: 150...(width - 150))
            let y = CGFloat.random(in: 150...(height - 150))
            guard !isNearLane(x, y) else { continue }
            let label = SKLabelNode(text: netLabels[i % netLabels.count])
            label.fontName = "Menlo"
            label.fontSize = CGFloat.random(in: 7...10)
            label.fontColor = color.withAlphaComponent(CGFloat.random(in: 0.2...0.35))
            label.position = CGPoint(x: baseX + x, y: baseY + y)
            label.zPosition = zPos + 0.2
            node.addChild(label)
        }
    }

    /// Add cache memory blocks for processing sectors - Dense "processor city"
    func addCacheBlocks(to node: SKNode, in sector: MegaBoardSector, color: UIColor) {
        // PERFORMANCE OPTIMIZED: Uses batched paths instead of individual nodes
        let baseX = sector.worldX
        let baseY = sector.worldY
        let width = sector.width
        let height = sector.height
        let zPos: CGFloat = 3

        func isNearLane(_ x: CGFloat, _ y: CGFloat) -> Bool {
            if y > 500 && y < 900 && x > 300 && x < 1100 { return true }
            if x > 1000 && y > 400 && y < 700 { return true }
            return false
        }

        let chipColor = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
        let cacheColor = UIColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 1.0)

        // Pre-generate positions for batching
        var cacheBlocks: [(x: CGFloat, y: CGFloat)] = []
        var cacheGridLabels: [(x: CGFloat, y: CGFloat, text: String)] = []
        var processorUnits: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var registerBlocks: [(x: CGFloat, y: CGFloat)] = []
        var busLines: [(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat)] = []
        var gatePositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []

        // ========== Generate cache grid positions ==========
        let cacheGridPositions: [(x: CGFloat, y: CGFloat, rows: Int, cols: Int)] = [
            (150, 200, 5, 8), (800, 150, 4, 6),
            (200, 900, 4, 7), (850, 950, 5, 5)
        ]
        let blockSize: CGFloat = 22
        for grid in cacheGridPositions {
            if !isNearLane(grid.x + CGFloat(grid.cols) * 20, grid.y + CGFloat(grid.rows) * 20) {
                for row in 0..<grid.rows {
                    for col in 0..<grid.cols {
                        cacheBlocks.append((x: grid.x + CGFloat(col) * blockSize, y: grid.y + CGFloat(row) * blockSize))
                    }
                }
                cacheGridLabels.append((x: grid.x + CGFloat(grid.cols) * blockSize / 2, y: grid.y - 15, text: ["L3", "L2", "SRAM", "CACHE"].randomElement()!))
            }
        }

        // ========== Generate processor unit positions ==========
        for _ in 0..<20 {
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 100...(height - 100))
            guard !isNearLane(x, y) else { continue }
            let unitW = CGFloat.random(in: 30...50)
            let unitH = CGFloat.random(in: 25...40)
            processorUnits.append((x: x, y: y, w: unitW, h: unitH))
        }

        // ========== Generate register block positions ==========
        for _ in 0..<10 {
            let x = CGFloat.random(in: 150...(width - 150))
            let y = CGFloat.random(in: 150...(height - 150))
            guard !isNearLane(x, y) else { continue }
            registerBlocks.append((x: x, y: y))
        }

        // ========== Generate bus line positions ==========
        for _ in 0..<8 {
            let isHorizontal = Bool.random()
            let lineLength = CGFloat.random(in: 100...300)
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 100...(height - 100))
            guard !isNearLane(x, y) else { continue }
            if isHorizontal {
                busLines.append((x1: x, y1: y, x2: x + lineLength, y2: y))
            } else {
                busLines.append((x1: x, y1: y, x2: x, y2: y + lineLength))
            }
        }

        // ========== Generate gate positions ==========
        for _ in 0..<100 {
            let x = CGFloat.random(in: 50...(width - 50))
            let y = CGFloat.random(in: 50...(height - 50))
            guard !isNearLane(x, y) else { continue }
            let gateW = CGFloat.random(in: 5...10)
            let gateH = CGFloat.random(in: 4...8)
            gatePositions.append((x: x, y: y, w: gateW, h: gateH))
        }

        // ========== BATCHED CACHE BLOCKS ==========
        let cachePath = CGMutablePath()
        for pos in cacheBlocks {
            cachePath.addRoundedRect(in: CGRect(x: baseX + pos.x, y: baseY + pos.y, width: blockSize - 3, height: blockSize - 3), cornerWidth: 1, cornerHeight: 1)
        }
        let cacheNode = SKShapeNode(path: cachePath)
        cacheNode.fillColor = cacheColor
        cacheNode.strokeColor = color.withAlphaComponent(0.4)
        cacheNode.lineWidth = 0.5
        cacheNode.zPosition = zPos
        node.addChild(cacheNode)

        // Cache grid labels (individual - few nodes)
        for lbl in cacheGridLabels {
            let label = SKLabelNode(text: lbl.text)
            label.fontName = "Menlo"
            label.fontSize = 8
            label.fontColor = color.withAlphaComponent(0.4)
            label.position = CGPoint(x: baseX + lbl.x, y: baseY + lbl.y)
            label.horizontalAlignmentMode = .center
            label.zPosition = zPos + 0.1
            node.addChild(label)
        }

        // ========== BATCHED PROCESSOR UNITS ==========
        let unitPath = CGMutablePath()
        for pos in processorUnits {
            unitPath.addRoundedRect(in: CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h), cornerWidth: 2, cornerHeight: 2)
        }
        let unitNode = SKShapeNode(path: unitPath)
        unitNode.fillColor = chipColor
        unitNode.strokeColor = color.withAlphaComponent(0.5)
        unitNode.lineWidth = 1
        unitNode.zPosition = zPos
        node.addChild(unitNode)

        // ========== ALU/FPU BLOCKS (individual - large labeled) ==========
        let aluPositions: [(x: CGFloat, y: CGFloat)] = [
            (500, 300), (700, 350), (400, 450),
            (600, 850), (750, 900), (500, 1000)
        ]
        for (index, pos) in aluPositions.enumerated() {
            if !isNearLane(pos.x, pos.y) {
                let size: CGFloat = CGFloat.random(in: 40...60)
                let alu = SKShapeNode(rect: CGRect(x: -size/2, y: -size/2, width: size, height: size), cornerRadius: 3)
                alu.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                alu.fillColor = cacheColor
                alu.strokeColor = color
                alu.lineWidth = 1.5
                alu.zPosition = zPos + 0.1
                node.addChild(alu)

                let label = SKLabelNode(text: ["ALU", "FPU", "CU", "REG"][index % 4])
                label.fontName = "Menlo-Bold"
                label.fontSize = 9
                label.fontColor = color.withAlphaComponent(0.5)
                label.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                label.zPosition = zPos + 0.2
                node.addChild(label)
            }
        }

        // ========== BATCHED REGISTER FILES ==========
        let regW: CGFloat = 8
        let regH: CGFloat = 6
        let regPath = CGMutablePath()
        for pos in registerBlocks {
            for row in 0..<2 {
                for col in 0..<4 {
                    regPath.addRect(CGRect(x: baseX + pos.x + CGFloat(col) * regW, y: baseY + pos.y + CGFloat(row) * regH, width: regW - 1, height: regH - 1))
                }
            }
        }
        let regNode = SKShapeNode(path: regPath)
        regNode.fillColor = chipColor
        regNode.strokeColor = color.withAlphaComponent(0.3)
        regNode.lineWidth = 0.5
        regNode.zPosition = zPos - 0.1
        node.addChild(regNode)

        // ========== BATCHED BUS LINES ==========
        let busPath = CGMutablePath()
        for line in busLines {
            busPath.move(to: CGPoint(x: baseX + line.x1, y: baseY + line.y1))
            busPath.addLine(to: CGPoint(x: baseX + line.x2, y: baseY + line.y2))
        }
        let busNode = SKShapeNode(path: busPath)
        busNode.strokeColor = color.withAlphaComponent(0.2)
        busNode.lineWidth = 2
        busNode.zPosition = zPos - 0.2
        node.addChild(busNode)

        // ========== BATCHED LOGIC GATES ==========
        let gatePath = CGMutablePath()
        for pos in gatePositions {
            gatePath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let gateNode = SKShapeNode(path: gatePath)
        gateNode.fillColor = chipColor.withAlphaComponent(0.6)
        gateNode.strokeColor = color.withAlphaComponent(0.15)
        gateNode.lineWidth = 0.5
        gateNode.zPosition = zPos - 0.3
        node.addChild(gateNode)

        // ========== PROCESSOR LABELS (individual - few nodes) ==========
        let procLabels = ["L3 CACHE", "32MB", "SRAM", "12-core", "REG", "ALU"]
        for i in 0..<6 {
            let x = CGFloat.random(in: 150...(width - 150))
            let y = CGFloat.random(in: 150...(height - 150))
            guard !isNearLane(x, y) else { continue }
            let label = SKLabelNode(text: procLabels[i % procLabels.count])
            label.fontName = "Menlo"
            label.fontSize = CGFloat.random(in: 7...10)
            label.fontColor = color.withAlphaComponent(CGFloat.random(in: 0.2...0.35))
            label.position = CGPoint(x: baseX + x, y: baseY + y)
            label.zPosition = zPos + 0.2
            node.addChild(label)
        }
    }

    /// Add trace bundles connecting to sector edges
    func addSectorTraces(to node: SKNode, in sector: MegaBoardSector, color: UIColor) {
        let traceColor = UIColor(hex: MotherboardColors.copperTrace)?.withAlphaComponent(0.15) ?? UIColor.orange.withAlphaComponent(0.15)
        let traceCount = 6
        let traceSpacing: CGFloat = 8
        let traceWidth: CGFloat = 2

        // Add trace bundle going toward CPU (center of map)
        let sectorCenter = CGPoint(x: sector.worldX + sector.width / 2, y: sector.worldY + sector.height / 2)
        let cpuCenter = MotherboardLaneConfig.cpuCenter

        // Determine edge closest to CPU
        let dx = cpuCenter.x - sectorCenter.x
        let dy = cpuCenter.y - sectorCenter.y

        var startPoint: CGPoint
        var endPoint: CGPoint

        if abs(dx) > abs(dy) {
            // Horizontal traces
            if dx > 0 {
                // Traces go right
                startPoint = CGPoint(x: sector.worldX + sector.width - 100, y: sectorCenter.y)
                endPoint = CGPoint(x: sector.worldX + sector.width, y: sectorCenter.y)
            } else {
                // Traces go left
                startPoint = CGPoint(x: sector.worldX + 100, y: sectorCenter.y)
                endPoint = CGPoint(x: sector.worldX, y: sectorCenter.y)
            }
        } else {
            // Vertical traces
            if dy > 0 {
                // Traces go up
                startPoint = CGPoint(x: sectorCenter.x, y: sector.worldY + sector.height - 100)
                endPoint = CGPoint(x: sectorCenter.x, y: sector.worldY + sector.height)
            } else {
                // Traces go down
                startPoint = CGPoint(x: sectorCenter.x, y: sector.worldY + 100)
                endPoint = CGPoint(x: sectorCenter.x, y: sector.worldY)
            }
        }

        // Draw parallel traces
        let isHorizontal = abs(dx) > abs(dy)
        for i in 0..<traceCount {
            let offset = CGFloat(i - traceCount/2) * traceSpacing

            let trace = SKShapeNode()
            let path = CGMutablePath()

            if isHorizontal {
                path.move(to: CGPoint(x: startPoint.x, y: startPoint.y + offset))
                path.addLine(to: CGPoint(x: endPoint.x, y: endPoint.y + offset))
            } else {
                path.move(to: CGPoint(x: startPoint.x + offset, y: startPoint.y))
                path.addLine(to: CGPoint(x: endPoint.x + offset, y: endPoint.y))
            }

            trace.path = path
            trace.strokeColor = traceColor
            trace.lineWidth = traceWidth
            trace.zPosition = -3.5
            node.addChild(trace)
        }
    }

}
