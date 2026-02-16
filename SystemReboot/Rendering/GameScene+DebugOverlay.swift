import SpriteKit

// MARK: - Debug Overlay (Boss / Survivor Scenes)
// Camera-attached overlay showing FPS, entity counts, and game state.
// Toggled via Settings > Debug > Debug Overlay.
// Fixed size, pinned to top-left corner of the visible screen.

extension GameScene {

    // MARK: - Constants
    // These are in SCREEN POINTS — they get scaled to scene coordinates at runtime.

    private enum DebugOverlayConfig {
        static let screenFontSize: CGFloat = 12
        static let screenLineSpacing: CGFloat = 15
        static let screenPadding: CGFloat = 8
        static let screenPanelWidth: CGFloat = 310
        static let screenMargin: CGFloat = 6
        static let screenHUDOffset: CGFloat = 80    // Below SwiftUI HUD (boss health bar is taller)
        static let fontName = "Menlo-Bold"
        static let backgroundColor = UIColor(white: 0, alpha: 0.85)
        static let cornerRadius: CGFloat = 6
        static let zPosition: CGFloat = 900
        static let maxLabelCount = 15
        static let frameBufferSize = 60
        static let updateInterval = 10
    }

    // MARK: - Setup / Teardown

    func setupDebugOverlay() {
        guard debugOverlayNode == nil, let cam = cameraNode else { return }

        let container = SKNode()
        container.name = "debugOverlay"
        container.zPosition = DebugOverlayConfig.zPosition
        cam.addChild(container)
        debugOverlayNode = container

        for i in 0..<DebugOverlayConfig.maxLabelCount {
            let label = SKLabelNode(fontNamed: DebugOverlayConfig.fontName)
            label.fontSize = 12
            label.fontColor = .white
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .top
            label.name = "debugLabel_\(i)"
            label.text = ""
            label.isHidden = true
            container.addChild(label)
        }

        let bg = SKShapeNode(rectOf: CGSize(width: 1, height: 1), cornerRadius: DebugOverlayConfig.cornerRadius)
        bg.fillColor = DebugOverlayConfig.backgroundColor
        bg.strokeColor = UIColor(white: 0.3, alpha: 0.5)
        bg.lineWidth = 0.5
        bg.name = "debugBackground"
        bg.zPosition = -1
        container.addChild(bg)
    }

    func removeDebugOverlay() {
        debugOverlayNode?.removeFromParent()
        debugOverlayNode = nil
        debugFrameTimes.removeAll()
        debugUpdateCounter = 0
    }

    func syncDebugOverlayVisibility() {
        if AppState.shared.showDebugOverlay {
            if debugOverlayNode == nil {
                setupDebugOverlay()
            }
        } else {
            if debugOverlayNode != nil {
                removeDebugOverlay()
            }
        }
    }

    // MARK: - Frame Time Recording

    func recordDebugFrameTime(_ deltaTime: TimeInterval) {
        guard deltaTime > 0, deltaTime < 1.0 else { return }
        debugFrameTimes.append(deltaTime)
        if debugFrameTimes.count > DebugOverlayConfig.frameBufferSize {
            debugFrameTimes.removeFirst()
        }
    }

    func shouldUpdateDebugOverlay() -> Bool {
        debugUpdateCounter += 1
        return debugUpdateCounter % DebugOverlayConfig.updateInterval == 0
    }

    // MARK: - Update

    func updateDebugOverlay() {
        guard let overlay = debugOverlayNode, let cam = cameraNode else { return }
        guard let view = self.view else { return }

        // Coordinate conversion: screen points → camera space
        let topLeftView = CGPoint(x: 0, y: 0)
        let refView = CGPoint(x: 100, y: 0)

        let topLeftScene = self.convertPoint(fromView: topLeftView)
        let refScene = self.convertPoint(fromView: refView)

        let topLeftCam = self.convert(topLeftScene, to: cam)
        let refCam = self.convert(refScene, to: cam)

        let ptScale = abs(refCam.x - topLeftCam.x) / 100.0
        guard ptScale > 0 else { return }

        let fontSize = DebugOverlayConfig.screenFontSize * ptScale
        let lineSpacing = DebugOverlayConfig.screenLineSpacing * ptScale
        let padding = DebugOverlayConfig.screenPadding * ptScale
        let panelWidth = DebugOverlayConfig.screenPanelWidth * ptScale
        let margin = DebugOverlayConfig.screenMargin * ptScale
        let safeTop = view.safeAreaInsets.top * ptScale
        let hudOffset = DebugOverlayConfig.screenHUDOffset * ptScale

        overlay.setScale(1.0)
        overlay.position = CGPoint(
            x: topLeftCam.x + margin,
            y: topLeftCam.y - safeTop - hudOffset - margin
        )

        // Build debug lines
        var lines: [DebugLine] = []

        let (fps, frameTimeMs) = computeDebugFPS()
        let fpsColor: UIColor = fps >= 55 ? .green : fps >= 40 ? .yellow : .red
        lines.append(DebugLine(
            text: String(format: "FPS: %d  (%.1fms)", fps, frameTimeMs),
            color: fpsColor
        ))

        let nodeCount = countNodes(in: self)
        lines.append(DebugLine(text: "Nodes: \(nodeCount)"))

        // Player health
        let hp = gameState.player.health
        let maxHp = gameState.player.maxHealth
        let hpColor: UIColor = hp / maxHp > 0.5 ? .green : hp / maxHp > 0.2 ? .yellow : .red
        lines.append(DebugLine(
            text: String(format: "HP: %.0f/%.0f", hp, maxHp),
            color: hpColor
        ))

        lines.append(DebugLine(
            text: "Enemies: \(gameState.enemies.count)  Proj: \(gameState.projectiles.count)"
        ))

        let minutes = Int(gameState.timeElapsed) / 60
        let seconds = Int(gameState.timeElapsed) % 60
        lines.append(DebugLine(
            text: String(format: "Time: %d:%02d  Kills: %d", minutes, seconds, gameState.stats.enemiesKilled)
        ))

        lines.append(DebugLine(
            text: "Mode: \(gameState.gameMode.rawValue)  Hash: \(gameState.stats.hashEarned)"
        ))

        // Boss info (lookup by .isBoss flag — activeBossId is the type string, not the enemy's unique id)
        if let bossType = gameState.activeBossType {
            let bossEnemy = gameState.enemies.first(where: { $0.isBoss && !$0.isDead })
            let hpText = bossEnemy.map { String(format: "%.0f/%.0f", $0.health, $0.maxHealth) } ?? "dead"
            let phaseText = bossEnemy?.bossPhase.map { "P\($0)" } ?? ""
            lines.append(DebugLine(
                text: "BOSS: \(bossType.rawValue)  HP: \(hpText)  \(phaseText)",
                color: .orange
            ))

            // Boss-specific state
            if let cyberboss = gameState.cyberbossState {
                let modeStr = cyberboss.mode == .melee ? "melee" : "ranged"
                lines.append(DebugLine(
                    text: "  Phase: \(cyberboss.phase)  Mode: \(modeStr)",
                    color: .orange
                ))
            }
            if let voidState = gameState.voidHarbingerState {
                lines.append(DebugLine(
                    text: "  Phase: \(voidState.phase)  Rifts: \(voidState.voidRifts.count)",
                    color: .orange
                ))
            }
            if let ocState = gameState.overclockerState {
                lines.append(DebugLine(
                    text: "  Phase: \(ocState.phase)  Steam: \(ocState.steamTrail.count)",
                    color: .orange
                ))
            }
            if let wyrmState = gameState.trojanWyrmState {
                lines.append(DebugLine(
                    text: "  Phase: \(wyrmState.phase)  Segments: \(wyrmState.segments.count)",
                    color: .orange
                ))
            }
        }

        if gameState.isGameOver {
            lines.append(DebugLine(
                text: gameState.victory ? "*** VICTORY ***" : "*** GAME OVER ***",
                color: gameState.victory ? .green : .red
            ))
        }

        // Apply lines to labels
        for i in 0..<DebugOverlayConfig.maxLabelCount {
            guard let label = overlay.childNode(withName: "debugLabel_\(i)") as? SKLabelNode else { continue }
            if i < lines.count {
                label.text = lines[i].text
                label.fontColor = lines[i].color
                label.fontSize = fontSize
                label.position = CGPoint(
                    x: padding,
                    y: -padding - CGFloat(i) * lineSpacing
                )
                label.isHidden = false
            } else {
                label.isHidden = true
            }
        }

        // Update background
        if let bg = overlay.childNode(withName: "debugBackground") as? SKShapeNode {
            let height = padding * 2 + CGFloat(lines.count) * lineSpacing
            let rect = CGRect(x: 0, y: -height, width: panelWidth, height: height)
            let cornerR = DebugOverlayConfig.cornerRadius * ptScale
            bg.path = UIBezierPath(roundedRect: rect, cornerRadius: cornerR).cgPath
        }
    }

    // MARK: - Helpers

    private struct DebugLine {
        let text: String
        var color: UIColor = .white
    }

    private func computeDebugFPS() -> (fps: Int, frameTimeMs: Double) {
        guard !debugFrameTimes.isEmpty else { return (0, 0) }
        let avg = debugFrameTimes.reduce(0, +) / Double(debugFrameTimes.count)
        let fps = avg > 0 ? Int(round(1.0 / avg)) : 0
        return (fps, avg * 1000)
    }

    private func countNodes(in node: SKNode) -> Int {
        var count = 1
        for child in node.children {
            count += countNodes(in: child)
        }
        return count
    }
}
