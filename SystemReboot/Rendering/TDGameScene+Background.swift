import SpriteKit
import SwiftUI

extension TDGameScene {

    /// Setup mega-board overlays: locked (corrupted data), unlockable (blueprint schematic),
    /// encryption gates, and data bus connections
    func setupMegaBoardVisuals() {
        guard isMotherboardMap else { return }

        // Clear existing gate nodes
        gateNodes.removeAll()

        let profile = AppState.shared.currentPlayer

        // Create and store renderer
        megaBoardRenderer = MegaBoardRenderer(scene: self)
        guard let renderer = megaBoardRenderer else { return }

        // Render locked and unlockable sectors with appropriate visual styles
        let (lockedSectors, unlockableSectors) = MegaBoardSystem.shared.visibleLockedSectorsByMode(for: profile)

        for sector in lockedSectors {
            renderer.renderLockedSector(sector, in: backgroundLayer)
        }

        for sector in unlockableSectors {
            renderer.renderUnlockableSector(sector, in: backgroundLayer)
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

        // Clear existing overlays
        megaBoardRenderer?.removeAllGhostSectors()
        megaBoardRenderer?.removeAllEncryptionGates()
        megaBoardRenderer?.removeAllDataBuses()
        gateNodes.removeAll()

        // Rebuild sector decorations to reflect new render modes
        // (e.g. unlockable → unlocked needs full-color components instead of wireframe)
        backgroundLayer.enumerateChildNodes(withName: "sectorDecor_*") { node, _ in
            node.removeFromParent()
        }
        drawSectorDecorations()

        // Rebuild lane visuals (copper traces)
        pathLayer.removeAllChildren()
        // Remove stale lane glow refs (keep CPU glow refs which are stable)
        glowNodes.removeAll(where: { $0.node.name?.hasPrefix("lane_") == true })
        setupMotherboardPaths()

        // Rebuild overlays
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

        // 5. Start sector ambient effects (makes sectors feel alive)
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
    /// PERF: IC components wrapped in LOD container — hidden when zoomed out
    /// Respects sector render mode: locked sectors skip rendering entirely,
    /// unlockable sectors render wireframe outlines, unlocked sectors get full detail.
    func drawSectorDecorations() {
        let megaConfig = cachedMegaBoardConfig
        let ghostColor = UIColor(hex: MotherboardColors.ghostMode)?.withAlphaComponent(0.15) ?? UIColor.gray.withAlphaComponent(0.15)
        let profile = AppState.shared.currentPlayer

        for sector in megaConfig.sectors {
            // Skip CPU sector - it has its own special rendering
            guard sector.id != SectorID.cpu.rawValue else { continue }

            let renderMode = MegaBoardSystem.shared.getRenderMode(for: sector.id, profile: profile)

            let sectorNode = SKNode()
            let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? ghostColor

            // === FOUNDATION LAYER (visible for unlocked & unlockable, skipped for locked) ===
            if renderMode != .locked {
                // 1. Secondary street grid (cosmetic PCB traces forming city blocks)
                drawSecondaryStreetGrid(to: sectorNode, in: sector, themeColor: themeColor)

                // 2. Via roundabouts at trace intersections
                addViaRoundabouts(to: sectorNode, in: sector, themeColor: themeColor)

                // 3. Silkscreen outlines (faint component footprints)
                addSilkscreenLabels(to: sectorNode, in: sector, themeColor: themeColor)
            }

            // === COMPONENT LAYER (LOD-gated: hidden when zoomed out) ===
            let detailContainer = SKNode()
            detailContainer.name = "sectorDetails_\(sector.id)"

            if renderMode != .locked {
                // Add vias (small filled circles) - legacy scattered vias
                addSectorVias(to: detailContainer, in: sector, color: ghostColor)

                // Add IC footprints — wireframe for unlockable, full for unlocked
                addSectorICs(to: detailContainer, in: sector, renderMode: renderMode)

                // Add trace bundles to edges
                addSectorTraces(to: detailContainer, in: sector, color: ghostColor)
            }

            sectorNode.addChild(detailContainer)

            sectorNode.zPosition = -3
            sectorNode.name = "sectorDecor_\(sector.id)"
            backgroundLayer.addChild(sectorNode)
        }
    }

    /// Update sector detail LOD based on camera zoom level.
    /// Hides IC component details when zoomed out (too small to see anyway).
    /// PERF: Saves ~200+ nodes worth of rendering at default zoom.
    func updateSectorLOD() {
        let showDetails = currentScale < 0.6  // Show details when zoomed in
        guard showDetails != sectorDetailsVisible else { return }
        sectorDetailsVisible = showDetails

        let targetAlpha: CGFloat = showDetails ? 1.0 : 0.0
        backgroundLayer.enumerateChildNodes(withName: "sectorDecor_*") { sectorNode, _ in
            for child in sectorNode.children where child.name?.hasPrefix("sectorDetails_") == true {
                child.removeAllActions()
                child.run(SKAction.fadeAlpha(to: targetAlpha, duration: 0.25))
            }
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

    // PERF: Removed drawMotherboardSectors() — dead code, replaced by MegaBoard system.
    // PERF: Removed drawCPUCore() — dead code, CPU rendered by setupCore() in TDGameScene.swift.

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

        // Batched star field: single compound path instead of 50 individual nodes
        let starCount = 50
        let layerSize = CGSize(width: size.width * 2, height: size.height * 2)
        let compoundPath = CGMutablePath()

        for _ in 0..<starCount {
            let radius = CGFloat.random(in: 1...2)
            let x = CGFloat.random(in: -layerSize.width/2...layerSize.width/2)
            let y = CGFloat.random(in: -layerSize.height/2...layerSize.height/2)
            compoundPath.addEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
        }

        let stars = SKShapeNode(path: compoundPath)
        stars.fillColor = UIColor.white.withAlphaComponent(0.35)
        stars.strokeColor = .clear

        // Single subtle pulse for entire star field
        let fadeOut = SKAction.fadeAlpha(to: 0.2, duration: 2.0)
        let fadeIn = SKAction.fadeAlpha(to: 0.5, duration: 2.0)
        fadeOut.timingMode = .easeInEaseOut
        fadeIn.timingMode = .easeInEaseOut
        stars.run(SKAction.repeatForever(SKAction.sequence([fadeOut, fadeIn])))

        layer.addChild(stars)
        layer.position = CGPoint(x: size.width / 2, y: size.height / 2)
        return layer
    }

    /// Create circuit pattern parallax layer
    func createCircuitPatternLayer() -> SKNode {
        let layer = SKNode()

        // Batched circuit traces: single compound path for traces + dots
        let traceCount = 15
        let layerSize = CGSize(width: size.width * 1.5, height: size.height * 1.5)
        let tracePath = CGMutablePath()
        let dotPath = CGMutablePath()
        let dotRadius: CGFloat = 3

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

            tracePath.move(to: startPoint)
            tracePath.addLine(to: endPoint)
            dotPath.addEllipse(in: CGRect(x: endPoint.x - dotRadius, y: endPoint.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
        }

        let traceNode = SKShapeNode(path: tracePath)
        traceNode.strokeColor = DesignColors.tracePrimaryUI.withAlphaComponent(0.15)
        traceNode.lineWidth = 2
        traceNode.lineCap = .round
        layer.addChild(traceNode)

        let dotNode = SKShapeNode(path: dotPath)
        dotNode.fillColor = DesignColors.tracePrimaryUI.withAlphaComponent(0.2)
        dotNode.strokeColor = .clear
        layer.addChild(dotNode)

        layer.position = CGPoint(x: size.width / 2, y: size.height / 2)
        return layer
    }

    /// Create data flow particles layer
    func createDataFlowLayer() -> SKNode {
        let layer = SKNode()

        // Batched data flow particles: single compound path with shared animation
        let particleCount = 20
        let compoundPath = CGMutablePath()

        for _ in 0..<particleCount {
            let x = CGFloat.random(in: 0...size.width)
            let y = CGFloat.random(in: 0...size.height)
            compoundPath.addRect(CGRect(x: x - 2, y: y - 2, width: 4, height: 4))
        }

        let particles = SKShapeNode(path: compoundPath)
        particles.fillColor = DesignColors.primaryUI.withAlphaComponent(0.3)
        particles.strokeColor = .clear

        // Single shared floating animation
        let moveUp = SKAction.moveBy(x: 0, y: 20, duration: 3.0)
        let moveDown = SKAction.moveBy(x: 0, y: -20, duration: 3.0)
        moveUp.timingMode = .easeInEaseOut
        moveDown.timingMode = .easeInEaseOut
        particles.run(SKAction.repeatForever(SKAction.sequence([moveUp, moveDown])))

        // Fade animation
        let fadeOut = SKAction.fadeAlpha(to: 0.1, duration: 2.0)
        let fadeIn = SKAction.fadeAlpha(to: 0.3, duration: 2.0)
        particles.run(SKAction.repeatForever(SKAction.sequence([fadeOut, fadeIn])))

        layer.addChild(particles)
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
