import SpriteKit

// MARK: - Debug Overlay
// Camera-attached overlay showing FPS, entity counts, and game state.
// Toggled via Settings > Debug > Debug Overlay.
// Fixed size, pinned to top-left corner of the visible screen.

extension TDGameScene {

    // MARK: - Constants
    // These are in SCREEN POINTS — they get scaled to scene coordinates at runtime.

    private enum DebugOverlayConfig {
        static let screenFontSize: CGFloat = 12       // Desired font size in screen points
        static let screenLineSpacing: CGFloat = 15    // Line spacing in screen points
        static let screenPadding: CGFloat = 8         // Padding in screen points
        static let screenPanelWidth: CGFloat = 310    // Panel width in screen points
        static let screenMargin: CGFloat = 6          // Margin from screen edge
        static let screenHUDOffset: CGFloat = 52       // Offset below SwiftUI HUD bar
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
        guard debugOverlayNode == nil else { return }

        let container = SKNode()
        container.name = "debugOverlay"
        container.zPosition = DebugOverlayConfig.zPosition
        cameraNode.addChild(container)
        debugOverlayNode = container

        // Pre-allocate label nodes (font size set dynamically in update)
        for i in 0..<DebugOverlayConfig.maxLabelCount {
            let label = SKLabelNode(fontNamed: DebugOverlayConfig.fontName)
            label.fontSize = 12 // placeholder, updated each frame
            label.fontColor = .white
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .top
            label.name = "debugLabel_\(i)"
            label.text = ""
            label.isHidden = true
            container.addChild(label)
        }

        // Background panel
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
        guard let overlay = debugOverlayNode, let state = state else { return }
        guard let view = self.view else { return }

        // Use SpriteKit's coordinate conversion to find:
        // 1. Where the screen top-left is in camera space
        // 2. How many camera-space points = 1 screen point
        let topLeftView = CGPoint(x: 0, y: 0)  // UIKit: top-left of screen
        let refView = CGPoint(x: 100, y: 0)     // 100 screen points to the right

        let topLeftScene = self.convertPoint(fromView: topLeftView)
        let refScene = self.convertPoint(fromView: refView)

        let topLeftCam = self.convert(topLeftScene, to: cameraNode)
        let refCam = self.convert(refScene, to: cameraNode)

        // How many camera-space points per screen point
        let ptScale = abs(refCam.x - topLeftCam.x) / 100.0

        // Scale all config values from screen points to camera-space points
        let fontSize = DebugOverlayConfig.screenFontSize * ptScale
        let lineSpacing = DebugOverlayConfig.screenLineSpacing * ptScale
        let padding = DebugOverlayConfig.screenPadding * ptScale
        let panelWidth = DebugOverlayConfig.screenPanelWidth * ptScale
        let margin = DebugOverlayConfig.screenMargin * ptScale
        let safeTop = view.safeAreaInsets.top * ptScale
        let hudOffset = DebugOverlayConfig.screenHUDOffset * ptScale

        // Position at top-left of screen, below safe area + SwiftUI HUD bar
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

        lines.append(DebugLine(
            text: "Enemies: \(state.enemies.count)  Towers: \(state.towers.count)  Proj: \(state.projectiles.count)"
        ))

        if state.idleSpawnEnabled {
            lines.append(DebugLine(
                text: String(format: "Threat: %.1f  Spawn: %.2fs", state.idleThreatLevel, state.idleCurrentSpawnInterval)
            ))
        }

        if state.waveInProgress {
            lines.append(DebugLine(
                text: "Wave: \(state.currentWave)  Left: \(state.waveEnemiesRemaining)"
            ))
        }

        let effColor: UIColor = state.efficiency >= 70 ? .green : state.efficiency >= 30 ? .yellow : .red
        lines.append(DebugLine(
            text: String(format: "Efficiency: %.0f%%  Leaks: %d", state.efficiency, state.leakCounter),
            color: effColor
        ))

        lines.append(DebugLine(
            text: "Power: \(state.powerUsed)/\(state.powerCapacity)W"
        ))

        lines.append(DebugLine(
            text: String(format: "Hash: %d/%d  (%.1f/s)", state.hash, state.hashStorageCapacity, state.hashPerSecond)
        ))

        if state.bossActive {
            let bossHP = state.enemies.first(where: { $0.id == state.activeBossId })
            let hpText = bossHP.map { String(format: "%.0f/%.0f", $0.health, $0.maxHealth) } ?? "?"
            lines.append(DebugLine(
                text: "BOSS: \(state.activeBossType ?? "?")  HP: \(hpText)  Engaged: \(state.bossEngaged ? "Y" : "N")",
                color: .orange
            ))
        }

        if state.overclockActive {
            lines.append(DebugLine(
                text: String(format: "OVERCLOCK: %.1fs left", state.overclockTimeRemaining),
                color: .cyan
            ))
        }

        if state.isSystemFrozen {
            lines.append(DebugLine(text: "*** SYSTEM FROZEN ***", color: .red))
        }

        // Apply lines to labels with dynamically computed sizes
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
