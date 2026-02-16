import SpriteKit
import UIKit

// MARK: - Special Effects

extension TowerAnimations {

    /// Play execute effect (NullPointer)
    static func playExecuteEffect(node: SKNode) {
        // Fatal error flash
        let flash = SKShapeNode(circleOfRadius: 50)
        flash.fillColor = UIColor(hex: "ef4444")?.withAlphaComponent(0.5) ?? .red.withAlphaComponent(0.5)
        flash.strokeColor = .clear
        flash.glowWidth = 0
        flash.blendMode = .add
        flash.zPosition = 100

        node.addChild(flash)

        let effect = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 2.0, duration: 0.2),
                SKAction.fadeOut(withDuration: 0.2)
            ]),
            SKAction.removeFromParent()
        ])
        flash.run(effect)

        // Glitch intensify
        if let body = node.childNode(withName: "body") {
            let glitchIntense = SKAction.sequence([
                SKAction.moveBy(x: 3, y: 0, duration: 0.02),
                SKAction.moveBy(x: -6, y: 0, duration: 0.02),
                SKAction.moveBy(x: 3, y: 0, duration: 0.02),
                SKAction.moveBy(x: 0, y: 3, duration: 0.02),
                SKAction.moveBy(x: 0, y: -3, duration: 0.02)
            ])
            body.run(glitchIntense)
        }
    }
}
