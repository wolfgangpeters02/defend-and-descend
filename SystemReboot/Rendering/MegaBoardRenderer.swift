import Foundation
import SpriteKit

// MARK: - Mega-Board Renderer
// Renders locked sectors (corrupted data) and unlockable sectors (blueprint schematic)

final class MegaBoardRenderer {

    // MARK: - Properties

    private weak var scene: SKScene?
    private var lockedSectorNodes: [String: SKNode] = [:]
    private var unlockableSectorNodes: [String: SKNode] = [:]
    // Animation timing
    private var noisePhase: CGFloat = 0
    private var pulsePhase: CGFloat = 0

    // Pre-generated binary strings to avoid per-frame allocation
    private let preGeneratedBinaryStrings: [String] = (0..<8).map { _ in
        (0..<8).map { _ in Bool.random() ? "1" : "0" }.joined(separator: "\n")
    }

    // Pre-generated hex strings for corruption effect
    private let preGeneratedHexStrings: [String] = (0..<8).map { _ in
        (0..<6).map { _ in String(format: "%02X", Int.random(in: 0...255)) }.joined(separator: " ")
    }

    // MARK: - Initialization

    init(scene: SKScene) {
        self.scene = scene
    }

    // MARK: - Locked Sector Rendering ("Corrupted Data")
    // Blueprint NOT found — mystery, visually unclear what sector contains

    /// Render a locked sector with corrupted data visuals
    func renderLockedSector(_ sector: MegaBoardSector, in parentNode: SKNode) {
        // Remove existing node if any
        lockedSectorNodes[sector.id]?.removeFromParent()

        let containerNode = SKNode()
        containerNode.name = "locked_\(sector.id)"
        containerNode.position = CGPoint(x: sector.worldX, y: sector.worldY)
        containerNode.zPosition = 5

        // 1. Dark background — barely tinted, no theme identity
        let background = SKShapeNode(rect: CGRect(x: 0, y: 0, width: sector.width, height: sector.height))
        background.fillColor = UIColor(red: 0.06, green: 0.06, blue: 0.10, alpha: 0.85)
        background.strokeColor = UIColor(red: 0.15, green: 0.15, blue: 0.20, alpha: 0.25)
        background.lineWidth = 1
        containerNode.addChild(background)

        // 2. Heavy scan lines (denser than unlockable)
        let scanOverlay = createLockedScanLines(size: CGSize(width: sector.width, height: sector.height))
        scanOverlay.position = CGPoint(x: sector.width / 2, y: sector.height / 2)
        scanOverlay.zPosition = 1
        containerNode.addChild(scanOverlay)

        // 3. Corruption bars — vertical glitch stripes that shift periodically
        let corruptionBars = createCorruptionBars(size: CGSize(width: sector.width, height: sector.height))
        corruptionBars.zPosition = 1.5
        containerNode.addChild(corruptionBars)

        // 4. Binary noise clusters — scattered encrypted data
        let binaryNoise = createBinaryNoiseClusters(size: CGSize(width: sector.width, height: sector.height))
        binaryNoise.zPosition = 2
        containerNode.addChild(binaryNoise)

        // 5. Central "?" glyph — unknown contents
        let questionMark = SKLabelNode(text: "?")
        questionMark.fontName = "Menlo-Bold"
        questionMark.fontSize = 60
        questionMark.fontColor = UIColor(red: 0.25, green: 0.25, blue: 0.35, alpha: 0.4)
        questionMark.position = CGPoint(x: sector.width / 2, y: sector.height / 2)
        questionMark.horizontalAlignmentMode = .center
        questionMark.verticalAlignmentMode = .center
        questionMark.zPosition = 3

        // Slow pulse on "?"
        let pulseUp = SKAction.fadeAlpha(to: 0.5, duration: 2.0)
        let pulseDown = SKAction.fadeAlpha(to: 0.2, duration: 2.0)
        questionMark.run(SKAction.repeatForever(SKAction.sequence([pulseUp, pulseDown])))
        containerNode.addChild(questionMark)

        parentNode.addChild(containerNode)
        lockedSectorNodes[sector.id] = containerNode
    }

    /// Create heavy scan lines for locked sector
    private func createLockedScanLines(size: CGSize) -> SKNode {
        let container = SKNode()

        // Horizontal scan lines — batched into single path
        let linePath = CGMutablePath()
        let lineSpacing: CGFloat = 6
        let lineCount = Int(size.height / lineSpacing)
        for i in 0..<lineCount {
            let y = CGFloat(i) * lineSpacing - size.height / 2
            linePath.addRect(CGRect(x: -size.width / 2, y: y, width: size.width, height: 1))
        }
        let linesNode = SKShapeNode(path: linePath)
        linesNode.fillColor = .black.withAlphaComponent(0.25)
        linesNode.strokeColor = .clear
        container.addChild(linesNode)

        // Moving scan line
        let scanLine = SKShapeNode(rect: CGRect(x: -size.width / 2, y: 0, width: size.width, height: 4))
        scanLine.fillColor = UIColor(red: 0.2, green: 0.3, blue: 0.2, alpha: 0.15)
        scanLine.strokeColor = .clear

        let moveUp = SKAction.moveTo(y: size.height / 2, duration: 3.0)
        let reset = SKAction.moveTo(y: -size.height / 2, duration: 0)
        scanLine.run(SKAction.repeatForever(SKAction.sequence([moveUp, reset])))
        container.addChild(scanLine)

        return container
    }

    /// Create vertical corruption bars that shift periodically
    private func createCorruptionBars(size: CGSize) -> SKNode {
        let container = SKNode()
        container.name = "corruptionBars"

        // 4 corruption bars
        for i in 0..<4 {
            let barWidth = CGFloat.random(in: 40...120)
            let barX = CGFloat.random(in: 0...(size.width - barWidth))
            let bar = SKShapeNode(rect: CGRect(x: barX, y: 0, width: barWidth, height: size.height))
            bar.fillColor = UIColor(red: 0.1, green: 0.15, blue: 0.1, alpha: 0.08)
            bar.strokeColor = UIColor(red: 0.2, green: 0.3, blue: 0.2, alpha: 0.06)
            bar.lineWidth = 1
            bar.name = "corruptBar_\(i)"

            // Each bar shifts position every 2-3 seconds
            let shiftDuration = TimeInterval.random(in: 2.0...3.5)
            let shiftAction = SKAction.run {
                let newX = CGFloat.random(in: 0...(size.width - barWidth))
                let newWidth = CGFloat.random(in: 40...120)
                bar.path = CGPath(rect: CGRect(x: newX, y: 0, width: newWidth, height: size.height), transform: nil)
            }
            let wait = SKAction.wait(forDuration: shiftDuration)
            bar.run(SKAction.repeatForever(SKAction.sequence([wait, shiftAction])))

            container.addChild(bar)
        }

        return container
    }

    /// Create scattered binary text noise clusters
    private func createBinaryNoiseClusters(size: CGSize) -> SKNode {
        let container = SKNode()

        // 6 binary text clusters at random positions
        for i in 0..<6 {
            let x = CGFloat.random(in: 100...(size.width - 100))
            let y = CGFloat.random(in: 100...(size.height - 100))

            let binaryLabel = SKLabelNode(text: preGeneratedBinaryStrings[i % preGeneratedBinaryStrings.count])
            binaryLabel.fontName = "Menlo"
            binaryLabel.fontSize = 9
            binaryLabel.fontColor = UIColor(red: 0.2, green: 0.4, blue: 0.2, alpha: 0.25)
            binaryLabel.position = CGPoint(x: x, y: y)
            binaryLabel.verticalAlignmentMode = .center
            binaryLabel.numberOfLines = 8

            // Cycle through binary strings
            var stringIndex = i
            let updateBinary = SKAction.run { [weak self] in
                guard let self = self else { return }
                stringIndex = (stringIndex + 1) % self.preGeneratedBinaryStrings.count
                binaryLabel.text = self.preGeneratedBinaryStrings[stringIndex]
            }
            let wait = SKAction.wait(forDuration: TimeInterval.random(in: 0.3...0.8))
            binaryLabel.run(SKAction.repeatForever(SKAction.sequence([updateBinary, wait])))

            container.addChild(binaryLabel)
        }

        return container
    }

    // MARK: - Unlockable Sector Rendering ("Blueprint Schematic")
    // Blueprint found — wireframe preview of sector contents

    /// Render an unlockable sector with blueprint schematic overlay
    func renderUnlockableSector(_ sector: MegaBoardSector, in parentNode: SKNode) {
        // Remove existing node if any
        unlockableSectorNodes[sector.id]?.removeFromParent()

        let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .gray
        let glowColor = UIColor(hex: sector.theme.glowColorHex) ?? .cyan

        let containerNode = SKNode()
        containerNode.name = "unlockable_\(sector.id)"
        containerNode.position = CGPoint(x: sector.worldX, y: sector.worldY)
        containerNode.zPosition = 5

        // 1. Subtle tinted background
        let background = SKShapeNode(rect: CGRect(x: 0, y: 0, width: sector.width, height: sector.height))
        background.fillColor = themeColor.withAlphaComponent(0.04)
        background.strokeColor = glowColor.withAlphaComponent(0.25)
        background.lineWidth = 2
        containerNode.addChild(background)

        // 2. Blueprint grid paper pattern
        let gridPaper = createBlueprintGrid(size: CGSize(width: sector.width, height: sector.height), color: glowColor)
        gridPaper.zPosition = 0.5
        containerNode.addChild(gridPaper)

        // 3. Dimension annotation lines at edges
        let annotations = createDimensionAnnotations(size: CGSize(width: sector.width, height: sector.height), color: glowColor)
        annotations.zPosition = 1
        containerNode.addChild(annotations)

        // 4. "SCHEMATIC:" prefix + sector name
        let schematicLabel = SKLabelNode(text: "\(L10n.Sector.schematic): \(sector.displayName.uppercased())")
        schematicLabel.fontName = "Menlo-Bold"
        schematicLabel.fontSize = 18
        schematicLabel.fontColor = glowColor.withAlphaComponent(0.7)
        schematicLabel.position = CGPoint(x: sector.width / 2, y: sector.height - 60)
        schematicLabel.horizontalAlignmentMode = .center
        schematicLabel.verticalAlignmentMode = .center
        schematicLabel.zPosition = 3
        containerNode.addChild(schematicLabel)

        // 5. Cost label
        let costLabel = SKLabelNode(text: "\(L10n.Sector.decryptCost): Ħ \(sector.unlockCost)")
        costLabel.fontName = "Menlo-Bold"
        costLabel.fontSize = 14
        costLabel.fontColor = .cyan.withAlphaComponent(0.6)
        costLabel.position = CGPoint(x: sector.width / 2, y: 50)
        costLabel.horizontalAlignmentMode = .center
        costLabel.verticalAlignmentMode = .center
        costLabel.zPosition = 3
        containerNode.addChild(costLabel)

        // 6. Light scan line (subtler than locked)
        let scanLine = SKShapeNode(rect: CGRect(x: 0, y: 0, width: sector.width, height: 2))
        scanLine.fillColor = glowColor.withAlphaComponent(0.06)
        scanLine.strokeColor = .clear
        scanLine.zPosition = 2

        let moveUp = SKAction.moveTo(y: sector.height, duration: 4.0)
        let reset = SKAction.moveTo(y: 0, duration: 0)
        scanLine.run(SKAction.repeatForever(SKAction.sequence([moveUp, reset])))
        containerNode.addChild(scanLine)

        parentNode.addChild(containerNode)
        unlockableSectorNodes[sector.id] = containerNode
    }

    /// Create blueprint grid paper pattern
    private func createBlueprintGrid(size: CGSize, color: UIColor) -> SKNode {
        let gridPath = CGMutablePath()
        let gridSpacing: CGFloat = 50

        // Vertical lines
        for x in stride(from: gridSpacing, to: size.width, by: gridSpacing) {
            gridPath.move(to: CGPoint(x: x, y: 0))
            gridPath.addLine(to: CGPoint(x: x, y: size.height))
        }

        // Horizontal lines
        for y in stride(from: gridSpacing, to: size.height, by: gridSpacing) {
            gridPath.move(to: CGPoint(x: 0, y: y))
            gridPath.addLine(to: CGPoint(x: size.width, y: y))
        }

        let gridNode = SKShapeNode(path: gridPath)
        gridNode.strokeColor = color.withAlphaComponent(0.06)
        gridNode.lineWidth = 1
        return gridNode
    }

    /// Create dimension annotation lines at sector edges (architectural drawing style)
    private func createDimensionAnnotations(size: CGSize, color: UIColor) -> SKNode {
        let container = SKNode()
        let annotColor = color.withAlphaComponent(0.15)
        let tickSize: CGFloat = 8
        let offset: CGFloat = 25  // Distance from edge

        // Bottom edge dimension line
        let bottomPath = CGMutablePath()
        bottomPath.move(to: CGPoint(x: 50, y: offset))
        bottomPath.addLine(to: CGPoint(x: size.width - 50, y: offset))
        // Tick marks
        bottomPath.move(to: CGPoint(x: 50, y: offset - tickSize / 2))
        bottomPath.addLine(to: CGPoint(x: 50, y: offset + tickSize / 2))
        bottomPath.move(to: CGPoint(x: size.width - 50, y: offset - tickSize / 2))
        bottomPath.addLine(to: CGPoint(x: size.width - 50, y: offset + tickSize / 2))

        let bottomNode = SKShapeNode(path: bottomPath)
        bottomNode.strokeColor = annotColor
        bottomNode.lineWidth = 1
        container.addChild(bottomNode)

        // Left edge dimension line
        let leftPath = CGMutablePath()
        leftPath.move(to: CGPoint(x: offset, y: 80))
        leftPath.addLine(to: CGPoint(x: offset, y: size.height - 80))
        leftPath.move(to: CGPoint(x: offset - tickSize / 2, y: 80))
        leftPath.addLine(to: CGPoint(x: offset + tickSize / 2, y: 80))
        leftPath.move(to: CGPoint(x: offset - tickSize / 2, y: size.height - 80))
        leftPath.addLine(to: CGPoint(x: offset + tickSize / 2, y: size.height - 80))

        let leftNode = SKShapeNode(path: leftPath)
        leftNode.strokeColor = annotColor
        leftNode.lineWidth = 1
        container.addChild(leftNode)

        return container
    }

    // MARK: - Legacy Support

    /// Render a ghost sector (routes to locked or unlockable based on mode)
    func renderGhostSector(_ sector: MegaBoardSector, in parentNode: SKNode) {
        // Default to locked for backward compatibility
        renderLockedSector(sector, in: parentNode)
    }

    // MARK: - Node Removal

    /// Remove a locked sector overlay
    func removeLockedSector(_ sectorId: String) {
        lockedSectorNodes[sectorId]?.removeFromParent()
        lockedSectorNodes.removeValue(forKey: sectorId)
    }

    /// Remove an unlockable sector overlay
    func removeUnlockableSector(_ sectorId: String) {
        unlockableSectorNodes[sectorId]?.removeFromParent()
        unlockableSectorNodes.removeValue(forKey: sectorId)
    }

    /// Remove ghost sector (removes from both locked and unlockable)
    func removeGhostSector(_ sectorId: String) {
        removeLockedSector(sectorId)
        removeUnlockableSector(sectorId)
    }

    /// Remove all ghost sectors (both locked and unlockable)
    func removeAllGhostSectors() {
        for (_, node) in lockedSectorNodes {
            node.removeFromParent()
        }
        lockedSectorNodes.removeAll()

        for (_, node) in unlockableSectorNodes {
            node.removeFromParent()
        }
        unlockableSectorNodes.removeAll()
    }

    // MARK: - Update

    /// Update animations (call from game loop)
    func update(deltaTime: TimeInterval) {
        noisePhase += CGFloat(deltaTime)
        pulsePhase += CGFloat(deltaTime)
    }
}
