import Foundation
import SpriteKit

// MARK: - Mega-Board Renderer
// Renders ghost sectors, encryption gates, and data bus connections

final class MegaBoardRenderer {

    // MARK: - Properties

    private weak var scene: SKScene?
    private var ghostSectorNodes: [String: SKNode] = [:]
    private var gateNodes: [String: SKNode] = [:]
    private var connectionNodes: [String: SKShapeNode] = [:]

    // Animation timing
    private var noisePhase: CGFloat = 0
    private var pulsePhase: CGFloat = 0

    // Pre-generated binary strings to avoid per-frame allocation
    private let preGeneratedBinaryStrings: [String] = (0..<8).map { _ in
        (0..<8).map { _ in Bool.random() ? "1" : "0" }.joined(separator: "\n")
    }

    // MARK: - Initialization

    init(scene: SKScene) {
        self.scene = scene
    }

    // MARK: - Ghost Sector Rendering

    /// Render a locked sector as a ghost (dimmed with noise overlay)
    func renderGhostSector(_ sector: MegaBoardSector, in parentNode: SKNode) {
        // Remove existing ghost node if any
        ghostSectorNodes[sector.id]?.removeFromParent()

        let ghostNode = SKNode()
        ghostNode.name = "ghost_\(sector.id)"
        ghostNode.position = CGPoint(x: sector.worldX, y: sector.worldY)
        ghostNode.zPosition = 5

        // Dimmed background
        let background = SKShapeNode(rect: CGRect(x: 0, y: 0, width: sector.width, height: sector.height))
        background.fillColor = UIColor(hex: sector.theme.primaryColorHex)?.withAlphaComponent(0.1) ?? .darkGray.withAlphaComponent(0.1)
        background.strokeColor = UIColor(hex: sector.theme.primaryColorHex)?.withAlphaComponent(0.3) ?? .darkGray.withAlphaComponent(0.3)
        background.lineWidth = 2
        background.name = "background"
        ghostNode.addChild(background)

        // Noise overlay (scan lines effect)
        let noiseOverlay = createNoiseOverlay(size: CGSize(width: sector.width, height: sector.height))
        noiseOverlay.position = CGPoint(x: sector.width / 2, y: sector.height / 2)
        noiseOverlay.zPosition = 1
        ghostNode.addChild(noiseOverlay)

        // Lock icon in center
        let lockIcon = createLockIcon(for: sector)
        lockIcon.position = CGPoint(x: sector.width / 2, y: sector.height / 2)
        lockIcon.zPosition = 2
        ghostNode.addChild(lockIcon)

        // Sector name label
        let nameLabel = SKLabelNode(text: sector.displayName.uppercased())
        nameLabel.fontName = "Menlo-Bold"
        nameLabel.fontSize = 24
        nameLabel.fontColor = UIColor(hex: sector.theme.primaryColorHex)?.withAlphaComponent(0.5) ?? .gray
        nameLabel.position = CGPoint(x: sector.width / 2, y: sector.height / 2 + 60)
        nameLabel.zPosition = 2
        ghostNode.addChild(nameLabel)

        // Cost label
        let costLabel = SKLabelNode(text: "Ħ \(sector.unlockCost)")
        costLabel.fontName = "Menlo-Bold"
        costLabel.fontSize = 18
        costLabel.fontColor = .cyan.withAlphaComponent(0.7)
        costLabel.position = CGPoint(x: sector.width / 2, y: sector.height / 2 - 60)
        costLabel.zPosition = 2
        ghostNode.addChild(costLabel)

        parentNode.addChild(ghostNode)
        ghostSectorNodes[sector.id] = ghostNode
    }

    /// Create scan lines noise overlay
    private func createNoiseOverlay(size: CGSize) -> SKNode {
        let container = SKNode()
        container.name = "noiseOverlay"

        // Horizontal scan lines
        let lineCount = Int(size.height / 8)
        for i in 0..<lineCount {
            let y = CGFloat(i) * 8 - size.height / 2
            let line = SKShapeNode(rect: CGRect(x: -size.width / 2, y: y, width: size.width, height: 1))
            line.fillColor = .black.withAlphaComponent(0.15)
            line.strokeColor = .clear
            container.addChild(line)
        }

        // Moving scan line effect
        let scanLine = SKShapeNode(rect: CGRect(x: -size.width / 2, y: 0, width: size.width, height: 4))
        scanLine.fillColor = .white.withAlphaComponent(0.1)
        scanLine.strokeColor = .clear
        scanLine.name = "scanLine"

        let moveUp = SKAction.moveTo(y: size.height / 2, duration: 3.0)
        let reset = SKAction.moveTo(y: -size.height / 2, duration: 0)
        let sequence = SKAction.sequence([moveUp, reset])
        scanLine.run(SKAction.repeatForever(sequence))
        container.addChild(scanLine)

        return container
    }

    /// Create lock icon
    private func createLockIcon(for sector: MegaBoardSector) -> SKNode {
        let container = SKNode()
        container.name = "lockIcon"

        // Lock body
        let bodySize: CGFloat = 40
        let body = SKShapeNode(rect: CGRect(x: -bodySize / 2, y: -bodySize / 2, width: bodySize, height: bodySize), cornerRadius: 4)
        body.fillColor = .black.withAlphaComponent(0.8)
        body.strokeColor = UIColor(hex: sector.theme.glowColorHex) ?? .cyan
        body.lineWidth = 2
        body.glowWidth = 4
        container.addChild(body)

        // Lock shackle (arc)
        let shacklePath = UIBezierPath()
        shacklePath.move(to: CGPoint(x: -12, y: bodySize / 2))
        shacklePath.addLine(to: CGPoint(x: -12, y: bodySize / 2 + 10))
        shacklePath.addArc(withCenter: CGPoint(x: 0, y: bodySize / 2 + 10),
                          radius: 12,
                          startAngle: .pi,
                          endAngle: 0,
                          clockwise: true)
        shacklePath.addLine(to: CGPoint(x: 12, y: bodySize / 2))

        let shackle = SKShapeNode(path: shacklePath.cgPath)
        shackle.strokeColor = UIColor(hex: sector.theme.glowColorHex) ?? .cyan
        shackle.lineWidth = 4
        shackle.lineCap = .round
        shackle.fillColor = .clear
        container.addChild(shackle)

        // Keyhole
        let keyhole = SKShapeNode(circleOfRadius: 6)
        keyhole.fillColor = UIColor(hex: sector.theme.glowColorHex)?.withAlphaComponent(0.8) ?? .cyan
        keyhole.strokeColor = .clear
        keyhole.position = CGPoint(x: 0, y: 5)
        container.addChild(keyhole)

        // Pulse animation
        let pulseUp = SKAction.scale(to: 1.1, duration: 1.0)
        let pulseDown = SKAction.scale(to: 1.0, duration: 1.0)
        let pulse = SKAction.sequence([pulseUp, pulseDown])
        container.run(SKAction.repeatForever(pulse))

        return container
    }

    /// Remove ghost sector
    func removeGhostSector(_ sectorId: String) {
        ghostSectorNodes[sectorId]?.removeFromParent()
        ghostSectorNodes.removeValue(forKey: sectorId)
    }

    /// Remove all ghost sectors
    func removeAllGhostSectors() {
        for (_, node) in ghostSectorNodes {
            node.removeFromParent()
        }
        ghostSectorNodes.removeAll()
    }

    // MARK: - Encryption Gate Rendering

    /// Render an encryption gate
    func renderEncryptionGate(_ gate: EncryptionGate, sector: MegaBoardSector, in parentNode: SKNode) {
        // Remove existing gate node if any
        gateNodes[gate.id]?.removeFromParent()

        let gateNode = SKNode()
        gateNode.name = "gate_\(gate.id)"
        gateNode.position = gate.position
        gateNode.zPosition = 50

        // Gate frame
        let frameRect = CGRect(
            x: -gate.gateWidth / 2,
            y: -gate.gateHeight / 2,
            width: gate.gateWidth,
            height: gate.gateHeight
        )
        let frame = SKShapeNode(rect: frameRect, cornerRadius: 8)
        frame.fillColor = .black.withAlphaComponent(0.9)
        frame.strokeColor = .red
        frame.lineWidth = 3
        frame.glowWidth = 6
        gateNode.addChild(frame)

        // "ENCRYPTED" label
        let encryptedLabel = SKLabelNode(text: L10n.Sector.encrypted)
        encryptedLabel.fontName = "Menlo-Bold"
        encryptedLabel.fontSize = 12
        encryptedLabel.fontColor = .red
        encryptedLabel.position = CGPoint(x: 0, y: gate.gateHeight / 2 - 20)
        gateNode.addChild(encryptedLabel)

        // Binary data effect (vertical lines of 0s and 1s)
        let binaryContainer = SKNode()
        binaryContainer.name = "binaryEffect"
        for col in 0..<4 {
            let x = CGFloat(col - 2) * 18 + 9
            let binaryLabel = SKLabelNode(text: preGeneratedBinaryStrings[col])
            binaryLabel.fontName = "Menlo"
            binaryLabel.fontSize = 10
            binaryLabel.fontColor = .green.withAlphaComponent(0.6)
            binaryLabel.position = CGPoint(x: x, y: 0)
            binaryLabel.verticalAlignmentMode = .center
            binaryLabel.numberOfLines = 8
            binaryContainer.addChild(binaryLabel)

            // Animate binary scroll - cycle through pre-generated strings (no allocation)
            var stringIndex = col
            let updateBinary = SKAction.run { [weak self] in
                guard let self = self else { return }
                stringIndex = (stringIndex + 1) % self.preGeneratedBinaryStrings.count
                binaryLabel.text = self.preGeneratedBinaryStrings[stringIndex]
            }
            let wait = SKAction.wait(forDuration: 0.15)  // Slightly slower for visual appeal
            binaryLabel.run(SKAction.repeatForever(SKAction.sequence([updateBinary, wait])))
        }
        gateNode.addChild(binaryContainer)

        // Cost display
        if let sectorConfig = MegaBoardSystem.shared.sector(id: sector.id) {
            let costLabel = SKLabelNode(text: "Ħ \(sectorConfig.unlockCost)")
            costLabel.fontName = "Menlo-Bold"
            costLabel.fontSize = 14
            costLabel.fontColor = .cyan
            costLabel.position = CGPoint(x: 0, y: -gate.gateHeight / 2 + 15)
            gateNode.addChild(costLabel)
        }

        // Pulsing glow
        let glowPulse = SKAction.sequence([
            SKAction.run { frame.glowWidth = 10 },
            SKAction.wait(forDuration: 0.5),
            SKAction.run { frame.glowWidth = 6 },
            SKAction.wait(forDuration: 0.5)
        ])
        frame.run(SKAction.repeatForever(glowPulse))

        parentNode.addChild(gateNode)
        gateNodes[gate.id] = gateNode
    }

    /// Generate random binary string
    private func randomBinaryString(length: Int) -> String {
        var result = ""
        for i in 0..<length {
            result += Bool.random() ? "1" : "0"
            if i < length - 1 {
                result += "\n"
            }
        }
        return result
    }

    /// Remove encryption gate
    func removeEncryptionGate(_ gateId: String) {
        gateNodes[gateId]?.removeFromParent()
        gateNodes.removeValue(forKey: gateId)
    }

    /// Remove all encryption gates
    func removeAllEncryptionGates() {
        for (_, node) in gateNodes {
            node.removeFromParent()
        }
        gateNodes.removeAll()
    }

    // MARK: - Data Bus Rendering

    /// Render a data bus connection
    func renderDataBus(_ connection: DataBusConnection, isActive: Bool, in parentNode: SKNode) {
        // Remove existing connection node if any
        connectionNodes[connection.id]?.removeFromParent()

        guard connection.waypoints.count >= 2 else { return }

        let path = UIBezierPath()
        path.move(to: connection.waypoints[0])

        for i in 1..<connection.waypoints.count {
            path.addLine(to: connection.waypoints[i])
        }

        let busNode = SKShapeNode(path: path.cgPath)
        busNode.name = "connection_\(connection.id)"
        busNode.strokeColor = isActive ? .cyan : .gray.withAlphaComponent(0.3)
        busNode.lineWidth = connection.busWidth / 4  // Scale down for visual
        busNode.lineCap = .round
        busNode.lineJoin = .round
        busNode.zPosition = 2

        if isActive {
            busNode.glowWidth = 4

            // Data flow animation - use opacity pulse instead of per-frame CGPath rebuild
            let dashPattern: [CGFloat] = [10, 10]
            busNode.path = path.cgPath.copy(dashingWithPhase: 0, lengths: dashPattern)

            // Simple pulse animation (much cheaper than rebuilding CGPath every frame)
            let pulseUp = SKAction.fadeAlpha(to: 1.0, duration: 0.5)
            let pulseDown = SKAction.fadeAlpha(to: 0.6, duration: 0.5)
            let pulse = SKAction.sequence([pulseUp, pulseDown])
            busNode.run(SKAction.repeatForever(pulse))
        }

        parentNode.addChild(busNode)
        connectionNodes[connection.id] = busNode
    }

    /// Remove data bus connection
    func removeDataBus(_ connectionId: String) {
        connectionNodes[connectionId]?.removeFromParent()
        connectionNodes.removeValue(forKey: connectionId)
    }

    /// Remove all data bus connections
    func removeAllDataBuses() {
        for (_, node) in connectionNodes {
            node.removeFromParent()
        }
        connectionNodes.removeAll()
    }

    // MARK: - Decrypt Animation

    /// Play decrypt animation when a sector is unlocked
    func playDecryptAnimation(for sector: MegaBoardSector, from cpuPosition: CGPoint, completion: @escaping () -> Void) {
        guard let scene = scene else {
            completion()
            return
        }

        let animationDuration: TimeInterval = 1.5

        // Power surge line from CPU to gate
        let gatePosition = MegaBoardSystem.shared.gate(forSectorId: sector.id)?.position ?? sector.center
        let surgePath = UIBezierPath()
        surgePath.move(to: cpuPosition)
        surgePath.addLine(to: gatePosition)

        let surgeLine = SKShapeNode(path: surgePath.cgPath)
        surgeLine.strokeColor = .cyan
        surgeLine.lineWidth = 4
        surgeLine.glowWidth = 12
        surgeLine.alpha = 0
        surgeLine.zPosition = 100
        scene.addChild(surgeLine)

        // Surge particle
        let surgeParticle = SKShapeNode(circleOfRadius: 8)
        surgeParticle.fillColor = .white
        surgeParticle.strokeColor = .cyan
        surgeParticle.lineWidth = 2
        surgeParticle.glowWidth = 10
        surgeParticle.position = cpuPosition
        surgeParticle.zPosition = 101
        scene.addChild(surgeParticle)

        // Animation sequence
        let showSurge = SKAction.fadeIn(withDuration: 0.2)
        let moveSurge = SKAction.move(to: gatePosition, duration: 0.8)
        moveSurge.timingMode = .easeIn

        surgeParticle.run(moveSurge)
        surgeLine.run(showSurge)

        // After surge reaches gate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self else { return }

            // Remove surge
            surgeParticle.removeFromParent()

            // Explosion at gate
            self.playGateExplosion(at: gatePosition, in: scene)

            // Fade out ghost sector
            if let ghostNode = self.ghostSectorNodes[sector.id] {
                let fadeOut = SKAction.fadeOut(withDuration: 0.5)
                let remove = SKAction.removeFromParent()
                ghostNode.run(SKAction.sequence([fadeOut, remove]))
                self.ghostSectorNodes.removeValue(forKey: sector.id)
            }

            // Remove gate
            if let gateNode = self.gateNodes["gate_\(sector.id)"] {
                let fadeOut = SKAction.fadeOut(withDuration: 0.3)
                let remove = SKAction.removeFromParent()
                gateNode.run(SKAction.sequence([fadeOut, remove]))
            }
            self.removeEncryptionGate("gate_\(sector.id)")

            // Fade out surge line
            let fadeOut = SKAction.fadeOut(withDuration: 0.3)
            let remove = SKAction.removeFromParent()
            surgeLine.run(SKAction.sequence([fadeOut, remove]))

            // Haptic feedback
            HapticsService.shared.play(.legendary)
        }

        // Completion after full animation
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            completion()
        }
    }

    /// Play explosion effect at gate position
    private func playGateExplosion(at position: CGPoint, in scene: SKScene) {
        // Expanding ring
        let ring = SKShapeNode(circleOfRadius: 10)
        ring.position = position
        ring.strokeColor = .cyan
        ring.fillColor = .clear
        ring.lineWidth = 4
        ring.glowWidth = 8
        ring.zPosition = 102
        scene.addChild(ring)

        let expand = SKAction.scale(to: 10, duration: 0.5)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        let group = SKAction.group([expand, fadeOut])
        let remove = SKAction.removeFromParent()
        ring.run(SKAction.sequence([group, remove]))

        // Particle burst
        for _ in 0..<12 {
            let particle = SKShapeNode(circleOfRadius: 3)
            particle.position = position
            particle.fillColor = .cyan
            particle.strokeColor = .white
            particle.lineWidth = 1
            particle.zPosition = 102
            scene.addChild(particle)

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 80...150)
            let endPoint = CGPoint(
                x: position.x + cos(angle) * distance,
                y: position.y + sin(angle) * distance
            )

            let move = SKAction.move(to: endPoint, duration: 0.5)
            move.timingMode = .easeOut
            let fade = SKAction.fadeOut(withDuration: 0.5)
            let group = SKAction.group([move, fade])
            let remove = SKAction.removeFromParent()
            particle.run(SKAction.sequence([group, remove]))
        }
    }

    // MARK: - Update

    /// Update animations (call from game loop)
    func update(deltaTime: TimeInterval) {
        noisePhase += CGFloat(deltaTime)
        pulsePhase += CGFloat(deltaTime)
    }
}
