import SpriteKit

// MARK: - Screen Effects

extension GameScene {

    // MARK: - Screen Effects Setup (Phase 1.4)

    func setupScreenFlash() {
        screenFlashNode = SKShapeNode(rectOf: CGSize(width: gameState.arena.width * 2, height: gameState.arena.height * 2))
        screenFlashNode?.fillColor = .white
        screenFlashNode?.strokeColor = .clear
        screenFlashNode?.alpha = 0
        screenFlashNode?.zPosition = 999
        screenFlashNode?.position = CGPoint(x: gameState.arena.width / 2, y: gameState.arena.height / 2)
        addChild(screenFlashNode!)
    }

    func setupInvulnerabilityAnimation() {
        // Pre-create the invulnerability flash action
        invulnerabilityAction = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 0.05),
                SKAction.fadeAlpha(to: 1.0, duration: 0.05)
            ])
        )
    }

    // MARK: - Screen Effects (Phase 1.4 - SKAction-based)

    /// Triggers a screen flash effect
    func flashScreen(color: SKColor = .white, intensity: CGFloat = 0.3, duration: TimeInterval = 0.1) {
        guard let flash = screenFlashNode else { return }

        flash.fillColor = color
        flash.removeAllActions()

        let flashAction = SKAction.sequence([
            SKAction.fadeAlpha(to: intensity, duration: 0.01),
            SKAction.fadeAlpha(to: 0, duration: duration)
        ])
        flash.run(flashAction)
    }

    /// Triggers a screen shake effect
    func shakeScreen(intensity: CGFloat = 5, duration: TimeInterval = 0.2) {
        guard let camera = cameraNode else { return }

        let originalPosition = CGPoint(x: gameState.arena.width / 2, y: gameState.arena.height / 2)
        camera.removeAction(forKey: "shake")

        let shakeCount = Int(duration / 0.02)
        var shakeActions: [SKAction] = []

        for i in 0..<shakeCount {
            let decayFactor = 1.0 - (CGFloat(i) / CGFloat(shakeCount))
            let offsetX = CGFloat.random(in: -intensity...intensity) * decayFactor
            let offsetY = CGFloat.random(in: -intensity...intensity) * decayFactor
            shakeActions.append(SKAction.move(to: CGPoint(
                x: originalPosition.x + offsetX,
                y: originalPosition.y + offsetY
            ), duration: 0.02))
        }

        shakeActions.append(SKAction.move(to: originalPosition, duration: 0.02))
        camera.run(SKAction.sequence(shakeActions), withKey: "shake")
    }
}
