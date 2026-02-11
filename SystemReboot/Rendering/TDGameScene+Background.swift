import SpriteKit
import SwiftUI

extension TDGameScene {

    /// Setup mega-board ghost sectors and encryption gates
    func setupMegaBoardVisuals() {
        guard isMotherboardMap else { return }

        // Clear existing gate nodes
        gateNodes.removeAll()

        let profile = AppState.shared.currentPlayer

        // Create and store renderer
        megaBoardRenderer = MegaBoardRenderer(scene: self)
        guard let renderer = megaBoardRenderer else { return }

        // Render ghost sectors (locked but adjacent to unlocked)
        let ghostSectors = MegaBoardSystem.shared.visibleLockedSectors(for: profile)
        for sector in ghostSectors {
            renderer.renderGhostSector(sector, in: backgroundLayer)
        }

        // Render encryption gates and store references for hit testing
        let gates = MegaBoardSystem.shared.visibleGates(for: profile)
        for gate in gates {
            if let sector = MegaBoardSystem.shared.sector(id: gate.sectorId) {
                renderer.renderEncryptionGate(gate, sector: sector, in: uiLayer)

                // Store gate node for hit testing (find by name)
                if let gateNode = uiLayer.childNode(withName: "gate_\(gate.id)") {
                    gateNodes[gate.sectorId] = gateNode
                }
            }
        }

        // Render data bus connections
        let connections = MegaBoardSystem.shared.connections
        for connection in connections {
            let isActive = connection.isActive(unlockedSectorIds: Set(profile.unlockedTDSectors))
            renderer.renderDataBus(connection, isActive: isActive, in: pathLayer)
        }
    }

    /// Refresh mega-board visuals after a sector is unlocked
    func refreshMegaBoardVisuals() {
        guard isMotherboardMap else { return }

        // Update state.paths with newly unlocked lanes
        let unlockedSectorIds = gameStateDelegate?.getUnlockedSectorIds() ?? Set([SectorID.power.rawValue])
        let activeLanes = MotherboardLaneConfig.getUnlockedLanes(unlockedSectorIds: unlockedSectorIds)
        let activePaths = activeLanes.map { lane -> EnemyPath in
            var path = lane.path
            path.sectorId = lane.sectorId
            return path
        }
        state?.paths = activePaths
        state?.basePaths = activePaths

        // Also update spawn points in map
        state?.map.spawnPoints = activeLanes.map { $0.spawnPoint }

        // Clear existing visuals
        megaBoardRenderer?.removeAllGhostSectors()
        megaBoardRenderer?.removeAllEncryptionGates()
        megaBoardRenderer?.removeAllDataBuses()
        gateNodes.removeAll()

        // Rebuild lane visuals (copper traces)
        pathLayer.removeAllChildren()
        setupMotherboardPaths()

        // Rebuild
        setupMegaBoardVisuals()
    }

    func setupBackground() {
        guard let state = state else { return }

        // Clear existing
        backgroundLayer.removeAllChildren()

        // Use different rendering based on map theme
        if isMotherboardMap {
            setupMotherboardBackground()
        } else {
            setupStandardBackground()
        }
    }

    /// Standard background rendering for non-motherboard maps
    func setupStandardBackground() {
        guard let state = state else { return }

        // Background color - deep terminal black
        let bg = SKSpriteNode(color: DesignColors.backgroundUI, size: size)
        bg.position = CGPoint(x: size.width/2, y: size.height/2)
        backgroundLayer.addChild(bg)

        // Add circuit board grid pattern
        let gridNode = SpriteKitDesign.createCircuitGridNode(size: size, gridSpacing: 40)
        gridNode.zPosition = 0.5
        backgroundLayer.addChild(gridNode)

        // Draw obstacles with circuit board style (darker surface)
        for obstacle in state.map.obstacles {
            let node = SKSpriteNode(
                color: DesignColors.surfaceUI,
                size: CGSize(width: obstacle.width, height: obstacle.height)
            )
            node.position = CGPoint(x: obstacle.x + obstacle.width/2, y: size.height - obstacle.y - obstacle.height/2)
            backgroundLayer.addChild(node)
        }

        // Draw hazards with danger color
        for hazard in state.map.hazards {
            let node = SKSpriteNode(
                color: DesignColors.dangerUI.withAlphaComponent(0.4),
                size: CGSize(width: hazard.width, height: hazard.height)
            )
            node.position = CGPoint(x: hazard.x + hazard.width/2, y: size.height - hazard.y - hazard.height/2)
            backgroundLayer.addChild(node)
        }

        // Setup parallax layers
        setupParallaxBackground()
    }

    // MARK: - Motherboard PCB Rendering

    /// PCB substrate background for motherboard map
    func setupMotherboardBackground() {
        // PCB Colors
        let substrateColor = UIColor(hex: MotherboardColors.substrate) ?? UIColor(red: 0.1, green: 0.1, blue: 0.18, alpha: 1.0)

        // 1. PCB Substrate (dark blue-black base)
        let substrate = SKSpriteNode(color: substrateColor, size: size)
        substrate.position = CGPoint(x: size.width/2, y: size.height/2)
        substrate.zPosition = -5
        backgroundLayer.addChild(substrate)

        // 2. Ground plane hatch pattern (diagonal lines)
        let hatchNode = createGroundPlaneHatch()
        hatchNode.zPosition = -4.5
        backgroundLayer.addChild(hatchNode)

        // 3. PCB Grid pattern (subtle copper grid)
        let gridNode = createPCBGridNode()
        gridNode.zPosition = -4
        backgroundLayer.addChild(gridNode)

        // 4. Draw sector decorations (ICs, vias, traces, labels)
        drawSectorDecorations()

        // 5. Start sector ambient effects (makes districts feel alive)
        startSectorAmbientEffects()

        // 6. Draw silkscreen labels
        drawSilkscreenLabels()

        // Note: CPU core is drawn by setupCore() in loadState() - no duplicate needed
    }

    /// Create subtle PCB grid pattern - OPTIMIZED: single path instead of 84 separate nodes
    func createPCBGridNode() -> SKNode {
        let gridNode = SKShapeNode()
        let gridSpacing: CGFloat = 100  // 100pt grid cells
        let lineColor = UIColor(hex: MotherboardColors.ghostMode)?.withAlphaComponent(0.3) ?? UIColor.darkGray.withAlphaComponent(0.3)

        // Combine ALL lines into a single CGPath for 1 draw call instead of 84
        let path = CGMutablePath()

        // Vertical lines
        for x in stride(from: 0, through: size.width, by: gridSpacing) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
        }

        // Horizontal lines
        for y in stride(from: 0, through: size.height, by: gridSpacing) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }

        gridNode.path = path
        gridNode.strokeColor = lineColor
        gridNode.lineWidth = 1

        return gridNode
    }

    /// Create diagonal ground plane hatch pattern - OPTIMIZED: single path instead of ~141 nodes
    func createGroundPlaneHatch() -> SKNode {
        let hatchNode = SKShapeNode()
        let hatchSpacing: CGFloat = 80  // Increased spacing (was 40) - subtle pattern doesn't need density
        let hatchColor = UIColor(hex: "#1a2a3a")?.withAlphaComponent(0.08) ?? UIColor.gray.withAlphaComponent(0.08)

        // Combine ALL diagonal lines into a single CGPath
        let path = CGMutablePath()
        let diagonalLength = sqrt(size.width * size.width + size.height * size.height)
        let lineCount = Int(diagonalLength / hatchSpacing)

        for i in -lineCount..<lineCount {
            let offset = CGFloat(i) * hatchSpacing
            path.move(to: CGPoint(x: offset, y: 0))
            path.addLine(to: CGPoint(x: offset + size.height, y: size.height))
        }

        hatchNode.path = path
        hatchNode.strokeColor = hatchColor
        hatchNode.lineWidth = 1

        return hatchNode
    }

    /// Draw decorative elements for each sector (ICs, vias, traces)
    func drawSectorDecorations() {
        let megaConfig = MegaBoardConfig.createDefault()
        let ghostColor = UIColor(hex: MotherboardColors.ghostMode)?.withAlphaComponent(0.15) ?? UIColor.gray.withAlphaComponent(0.15)

        for sector in megaConfig.sectors {
            // Skip CPU sector - it has its own special rendering
            guard sector.id != SectorID.cpu.rawValue else { continue }

            let sectorNode = SKNode()
            let sectorCenter = CGPoint(
                x: sector.worldX + sector.width / 2,
                y: sector.worldY + sector.height / 2
            )

            let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? ghostColor

            // === FOUNDATION LAYER (Phase 1: City Streets) ===

            // 1. Secondary street grid (cosmetic PCB traces forming city blocks)
            drawSecondaryStreetGrid(to: sectorNode, in: sector, themeColor: themeColor)

            // 2. Via roundabouts at trace intersections
            addViaRoundabouts(to: sectorNode, in: sector, themeColor: themeColor)

            // 3. Silkscreen labels (faint component markings)
            addSilkscreenLabels(to: sectorNode, in: sector, themeColor: themeColor)

            // === COMPONENT LAYER (District-specific) ===

            // Add vias (small filled circles) - legacy scattered vias
            addSectorVias(to: sectorNode, in: sector, color: ghostColor)

            // Add IC footprints based on sector type
            addSectorICs(to: sectorNode, in: sector)

            // Add trace bundles to edges
            addSectorTraces(to: sectorNode, in: sector, color: ghostColor)

            // Sector name label (silkscreen style)
            let nameLabel = SKLabelNode(text: sector.displayName.uppercased())
            nameLabel.fontName = "Menlo"
            nameLabel.fontSize = 18
            nameLabel.fontColor = UIColor(hex: sector.theme.primaryColorHex)?.withAlphaComponent(0.4) ?? ghostColor
            nameLabel.position = CGPoint(x: sectorCenter.x, y: sector.worldY + sector.height - 40)
            nameLabel.horizontalAlignmentMode = .center
            nameLabel.zPosition = -2
            sectorNode.addChild(nameLabel)

            sectorNode.zPosition = -3
            backgroundLayer.addChild(sectorNode)
        }
    }


    /// Draw silkscreen-style labels around the board
    func drawSilkscreenLabels() {
        let silkColor = UIColor.white.withAlphaComponent(0.25)

        // REV label in corner
        let revLabel = SKLabelNode(text: "REV 2.0")
        revLabel.fontName = "Menlo"
        revLabel.fontSize = 14
        revLabel.fontColor = silkColor
        revLabel.position = CGPoint(x: 80, y: 30)
        revLabel.horizontalAlignmentMode = .left
        revLabel.zPosition = -2
        backgroundLayer.addChild(revLabel)

        // Board name
        let boardLabel = SKLabelNode(text: "LEGENDARY_SURVIVORS_MB")
        boardLabel.fontName = "Menlo-Bold"
        boardLabel.fontSize = 12
        boardLabel.fontColor = silkColor
        boardLabel.position = CGPoint(x: size.width / 2, y: 30)
        boardLabel.horizontalAlignmentMode = .center
        boardLabel.zPosition = -2
        backgroundLayer.addChild(boardLabel)

        // PWR and GND labels near power sector
        let pwrLabel = SKLabelNode(text: "PWR +12V")
        pwrLabel.fontName = "Menlo"
        pwrLabel.fontSize = 10
        pwrLabel.fontColor = UIColor(hex: "#ffdd00")?.withAlphaComponent(0.4) ?? silkColor
        pwrLabel.position = CGPoint(x: 3100, y: 1500)  // Near PSU sector
        pwrLabel.horizontalAlignmentMode = .center
        pwrLabel.zPosition = -2
        backgroundLayer.addChild(pwrLabel)

        let gndLabel = SKLabelNode(text: "GND")
        gndLabel.fontName = "Menlo"
        gndLabel.fontSize = 10
        gndLabel.fontColor = silkColor
        gndLabel.position = CGPoint(x: 3100, y: 1480)
        gndLabel.horizontalAlignmentMode = .center
        gndLabel.zPosition = -2
        backgroundLayer.addChild(gndLabel)

        // Copyright/brand in opposite corner
        let brandLabel = SKLabelNode(text: "© LEGENDARY TECH")
        brandLabel.fontName = "Menlo"
        brandLabel.fontSize = 10
        brandLabel.fontColor = silkColor.withAlphaComponent(0.5)
        brandLabel.position = CGPoint(x: size.width - 80, y: 30)
        brandLabel.horizontalAlignmentMode = .right
        brandLabel.zPosition = -2
        backgroundLayer.addChild(brandLabel)
    }

    /// Draw motherboard districts as ghost outlines (locked) or lit (unlocked)
    func drawMotherboardDistricts() {
        let config = MotherboardConfig.createDefault()
        let ghostColor = UIColor(hex: MotherboardColors.ghostMode) ?? UIColor.darkGray

        for district in config.districts {
            let districtNode = SKNode()

            // District outline
            let rect = CGRect(x: 0, y: 0, width: district.width, height: district.height)
            let outline = SKShapeNode(rect: rect, cornerRadius: 8)

            // Check if this is the CPU district (always active)
            let isActive = district.id == "cpu_district"

            if isActive {
                // Active district - full brightness
                outline.strokeColor = UIColor(hex: district.primaryColor) ?? UIColor.blue
                outline.lineWidth = 3
                outline.fillColor = UIColor(hex: district.primaryColor)?.withAlphaComponent(0.1) ?? UIColor.blue.withAlphaComponent(0.1)
                outline.glowWidth = 5
            } else {
                // Ghost district - dimmed at 15%
                outline.strokeColor = ghostColor.withAlphaComponent(0.4)
                outline.lineWidth = 1
                outline.fillColor = ghostColor.withAlphaComponent(0.05)
            }

            districtNode.addChild(outline)

            // District label (silkscreen text)
            let label = SKLabelNode(text: district.name.uppercased())
            label.fontName = "Menlo-Bold"
            label.fontSize = isActive ? 16 : 12
            label.fontColor = isActive ? UIColor.white : ghostColor
            label.position = CGPoint(x: district.width/2, y: district.height + 10)
            label.horizontalAlignmentMode = .center
            districtNode.addChild(label)

            // For locked districts, add "LOCKED" or cost text
            if !isActive {
                let lockedLabel = SKLabelNode(text: L10n.Common.locked)
                lockedLabel.fontName = "Menlo"
                lockedLabel.fontSize = 10
                lockedLabel.fontColor = ghostColor.withAlphaComponent(0.6)
                lockedLabel.position = CGPoint(x: district.width/2, y: district.height/2)
                lockedLabel.horizontalAlignmentMode = .center
                districtNode.addChild(lockedLabel)
            }

            // Position in scene (convert from game coords)
            districtNode.position = CGPoint(x: district.x, y: district.y)
            districtNode.zPosition = -3
            backgroundLayer.addChild(districtNode)
        }
    }

    /// Draw glowing CPU core at center
    func drawCPUCore() {
        let cpuColor = UIColor(hex: MotherboardColors.cpuCore) ?? UIColor.blue
        let glowColor = UIColor(hex: MotherboardColors.activeGlow) ?? UIColor.green

        let cpuSize: CGFloat = MotherboardLaneConfig.cpuSize
        let cpuPosition = MotherboardLaneConfig.cpuCenter

        // Outer glow
        let outerGlow = SKShapeNode(rectOf: CGSize(width: cpuSize + 60, height: cpuSize + 60), cornerRadius: 20)
        outerGlow.position = cpuPosition
        outerGlow.fillColor = cpuColor.withAlphaComponent(0.1)
        outerGlow.strokeColor = glowColor.withAlphaComponent(0.5)
        outerGlow.lineWidth = 3
        outerGlow.glowWidth = 10  // Reduced from 20 for performance
        outerGlow.zPosition = -1
        outerGlow.blendMode = .add
        backgroundLayer.addChild(outerGlow)

        // CPU body
        let cpuBody = SKShapeNode(rectOf: CGSize(width: cpuSize, height: cpuSize), cornerRadius: 10)
        cpuBody.position = cpuPosition
        cpuBody.fillColor = UIColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 1.0)
        cpuBody.strokeColor = cpuColor
        cpuBody.lineWidth = 4
        cpuBody.zPosition = 0
        backgroundLayer.addChild(cpuBody)

        // CPU die (inner bright square)
        let dieSize: CGFloat = 150
        let cpuDie = SKShapeNode(rectOf: CGSize(width: dieSize, height: dieSize), cornerRadius: 5)
        cpuDie.position = cpuPosition
        cpuDie.fillColor = cpuColor.withAlphaComponent(0.3)
        cpuDie.strokeColor = cpuColor
        cpuDie.lineWidth = 2
        cpuDie.zPosition = 1
        backgroundLayer.addChild(cpuDie)

        // CPU label
        let label = SKLabelNode(text: "CPU")
        label.fontName = "Menlo-Bold"
        label.fontSize = 32
        label.fontColor = UIColor.white
        label.position = CGPoint(x: cpuPosition.x, y: cpuPosition.y - 10)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zPosition = 2
        backgroundLayer.addChild(label)

        // Pulse animation for glow
        let pulseUp = SKAction.scale(to: 1.05, duration: 1.5)
        let pulseDown = SKAction.scale(to: 1.0, duration: 1.5)
        pulseUp.timingMode = .easeInEaseOut
        pulseDown.timingMode = .easeInEaseOut
        let pulse = SKAction.sequence([pulseUp, pulseDown])
        outerGlow.run(SKAction.repeatForever(pulse))
    }

    /// Setup parallax background layers for depth effect
    func setupParallaxBackground() {
        // Clear existing parallax layers
        for (node, _) in parallaxLayers {
            node.removeFromParent()
        }
        parallaxLayers.removeAll()

        // Layer 1: Slow star field (z=-3, speed factor 0.1)
        let starLayer = createStarFieldLayer()
        starLayer.zPosition = -3
        backgroundLayer.addChild(starLayer)
        parallaxLayers.append((starLayer, 0.1))

        // Layer 2: Circuit grid pattern (z=-2, speed factor 0.3)
        let circuitLayer = createCircuitPatternLayer()
        circuitLayer.zPosition = -2
        backgroundLayer.addChild(circuitLayer)
        parallaxLayers.append((circuitLayer, 0.3))

        // Layer 3: Data flow particles (z=-1, speed factor 0.6)
        let dataFlowLayer = createDataFlowLayer()
        dataFlowLayer.zPosition = -1
        backgroundLayer.addChild(dataFlowLayer)
        parallaxLayers.append((dataFlowLayer, 0.6))

        // Initialize camera position tracking
        lastCameraPosition = cameraNode?.position ?? CGPoint(x: size.width / 2, y: size.height / 2)
    }

    /// Create star field background layer
    func createStarFieldLayer() -> SKNode {
        let layer = SKNode()

        // Create small dots as distant stars
        let starCount = 50
        let layerSize = CGSize(width: size.width * 2, height: size.height * 2)

        for _ in 0..<starCount {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...2))
            star.fillColor = UIColor.white.withAlphaComponent(CGFloat.random(in: 0.2...0.5))
            star.strokeColor = .clear
            star.position = CGPoint(
                x: CGFloat.random(in: -layerSize.width/2...layerSize.width/2),
                y: CGFloat.random(in: -layerSize.height/2...layerSize.height/2)
            )

            // Subtle twinkle animation
            let fadeOut = SKAction.fadeAlpha(to: 0.1, duration: Double.random(in: 1...3))
            let fadeIn = SKAction.fadeAlpha(to: star.alpha, duration: Double.random(in: 1...3))
            let delay = SKAction.wait(forDuration: Double.random(in: 0...2))
            star.run(SKAction.repeatForever(SKAction.sequence([delay, fadeOut, fadeIn])))

            layer.addChild(star)
        }

        layer.position = CGPoint(x: size.width / 2, y: size.height / 2)
        return layer
    }

    /// Create circuit pattern parallax layer
    func createCircuitPatternLayer() -> SKNode {
        let layer = SKNode()

        // Create faint circuit traces in background
        let traceCount = 15
        let layerSize = CGSize(width: size.width * 1.5, height: size.height * 1.5)

        for _ in 0..<traceCount {
            let startPoint = CGPoint(
                x: CGFloat.random(in: -layerSize.width/2...layerSize.width/2),
                y: CGFloat.random(in: -layerSize.height/2...layerSize.height/2)
            )

            let isHorizontal = Bool.random()
            let length = CGFloat.random(in: 50...150)
            let endPoint = isHorizontal
                ? CGPoint(x: startPoint.x + length, y: startPoint.y)
                : CGPoint(x: startPoint.x, y: startPoint.y + length)

            let path = UIBezierPath()
            path.move(to: startPoint)
            path.addLine(to: endPoint)

            let trace = SKShapeNode(path: path.cgPath)
            trace.strokeColor = DesignColors.tracePrimaryUI.withAlphaComponent(0.15)
            trace.lineWidth = 2
            trace.lineCap = .round
            layer.addChild(trace)

            // Add junction dot at end
            let dot = SKShapeNode(circleOfRadius: 3)
            dot.fillColor = DesignColors.tracePrimaryUI.withAlphaComponent(0.2)
            dot.strokeColor = .clear
            dot.position = endPoint
            layer.addChild(dot)
        }

        layer.position = CGPoint(x: size.width / 2, y: size.height / 2)
        return layer
    }

    /// Create data flow particles layer
    func createDataFlowLayer() -> SKNode {
        let layer = SKNode()

        // Create floating data particles
        let particleCount = 20

        for _ in 0..<particleCount {
            let particle = SKShapeNode(rectOf: CGSize(width: 4, height: 4), cornerRadius: 1)
            particle.fillColor = DesignColors.primaryUI.withAlphaComponent(0.3)
            particle.strokeColor = .clear
            particle.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )

            // Floating animation
            let moveUp = SKAction.moveBy(x: 0, y: 30, duration: Double.random(in: 2...4))
            let moveDown = SKAction.moveBy(x: 0, y: -30, duration: Double.random(in: 2...4))
            moveUp.timingMode = .easeInEaseOut
            moveDown.timingMode = .easeInEaseOut
            particle.run(SKAction.repeatForever(SKAction.sequence([moveUp, moveDown])))

            // Fade animation
            let fade = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.1, duration: Double.random(in: 1.5...3)),
                SKAction.fadeAlpha(to: 0.3, duration: Double.random(in: 1.5...3))
            ])
            particle.run(SKAction.repeatForever(fade))

            layer.addChild(particle)
        }

        return layer
    }

    /// Update parallax layers based on camera movement
    func updateParallaxLayers() {
        guard let cameraNode = cameraNode else { return }

        let cameraDelta = CGPoint(
            x: cameraNode.position.x - lastCameraPosition.x,
            y: cameraNode.position.y - lastCameraPosition.y
        )

        // Move each layer based on its speed factor (opposite to camera movement)
        for (layer, speedFactor) in parallaxLayers {
            layer.position.x -= cameraDelta.x * speedFactor
            layer.position.y -= cameraDelta.y * speedFactor
        }

        lastCameraPosition = cameraNode.position
    }

}
