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

    /// Triggers a screen shake effect using offset (works with camera follow)
    func shakeScreen(intensity: CGFloat = 5, duration: TimeInterval = 0.2) {
        shakeIntensity = intensity
        shakeDuration = duration
        shakeElapsed = 0
    }

    /// Update shake offset each frame (called from updateGameState)
    func updateShake(deltaTime: TimeInterval) {
        guard shakeDuration > 0, shakeElapsed < shakeDuration else {
            shakeOffset = .zero
            return
        }

        shakeElapsed += deltaTime
        let decayFactor = max(0, 1.0 - CGFloat(shakeElapsed / shakeDuration))
        shakeOffset = CGPoint(
            x: CGFloat.random(in: -shakeIntensity...shakeIntensity) * decayFactor,
            y: CGFloat.random(in: -shakeIntensity...shakeIntensity) * decayFactor
        )

        if shakeElapsed >= shakeDuration {
            shakeOffset = .zero
            shakeDuration = 0
        }
    }
}
