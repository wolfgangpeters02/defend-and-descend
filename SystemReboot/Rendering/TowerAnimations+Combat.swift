import SpriteKit
import UIKit

// MARK: - Combat Animations

extension TowerAnimations {

    // MARK: - Muzzle Flash

    /// Play muzzle flash animation
    static func playMuzzleFlash(node: SKNode, duration: TimeInterval = 0.15) {
        guard let barrel = node.childNode(withName: "barrel"),
              let flash = barrel.childNode(withName: "muzzleFlash") else { return }

        flash.removeAllActions()
        flash.alpha = 1.0
        flash.setScale(1.0)

        let flashSequence = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.3, duration: duration * 0.3),
                SKAction.fadeAlpha(to: 0.8, duration: duration * 0.3)
            ]),
            SKAction.group([
                SKAction.scale(to: 0.8, duration: duration * 0.7),
                SKAction.fadeAlpha(to: 0, duration: duration * 0.7)
            ])
        ])

        flash.run(flashSequence)
    }

    /// Enhanced muzzle flash with archetype-specific effects
    static func playEnhancedMuzzleFlash(node: SKNode, archetype: TowerVisualFactory.TowerArchetype, color: UIColor) {
        guard let barrel = node.childNode(withName: "barrel") else { return }

        // Base muzzle flash
        if let flash = barrel.childNode(withName: "muzzleFlash") {
            flash.removeAllActions()
            flash.alpha = 1.0
            flash.setScale(1.0)
        }

        // Archetype-specific enhanced effects
        switch archetype {
        case .artillery:
            playArtilleryMuzzleFlash(barrel: barrel, color: color)
        case .beam:
            playBeamMuzzleFlash(barrel: barrel, color: color)
        case .tesla:
            playTeslaMuzzleFlash(barrel: barrel, color: color)
        case .frost:
            playFrostMuzzleFlash(barrel: barrel, color: color)
        default:
            // Standard flash for other archetypes
            playStandardMuzzleFlash(barrel: barrel, color: color)
        }
    }

    /// Standard muzzle flash (default for most towers)
    private static func playStandardMuzzleFlash(barrel: SKNode, color: UIColor) {
        guard let flash = barrel.childNode(withName: "muzzleFlash") else { return }

        let flashSequence = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.3, duration: 0.05),
                SKAction.fadeAlpha(to: 0.9, duration: 0.05)
            ]),
            SKAction.group([
                SKAction.scale(to: 0.8, duration: 0.12),
                SKAction.fadeAlpha(to: 0, duration: 0.12)
            ])
        ])

        flash.run(flashSequence)
    }

    /// Artillery: Large smoke ring expansion with smoke particles
    private static func playArtilleryMuzzleFlash(barrel: SKNode, color: UIColor) {
        // Main flash with larger expansion
        if let flash = barrel.childNode(withName: "muzzleFlash") {
            let flashSequence = SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 2.0, duration: 0.08),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.05)
                ]),
                SKAction.group([
                    SKAction.scale(to: 0.5, duration: 0.2),
                    SKAction.fadeAlpha(to: 0, duration: 0.25)
                ])
            ])
            flash.run(flashSequence)
        }

        // Skip smoke particles when zoomed out (not visible at distance)
        guard TowerAnimations.currentCameraScale < 0.5 else { return }

        // Smoke ring effect
        let smokeRing = SKShapeNode(circleOfRadius: 8)
        smokeRing.position = CGPoint(x: 0, y: 22)  // Muzzle position
        smokeRing.fillColor = UIColor.gray.withAlphaComponent(0.4)
        smokeRing.strokeColor = UIColor.darkGray.withAlphaComponent(0.5)
        smokeRing.lineWidth = 2
        smokeRing.zPosition = 15
        barrel.addChild(smokeRing)

        let ringExpand = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 2.5, duration: 0.3),
                SKAction.fadeOut(withDuration: 0.35)
            ]),
            SKAction.removeFromParent()
        ])
        smokeRing.run(ringExpand)

        // Spawn smoke particles
        for _ in 0..<Int.random(in: 3...5) {
            let smoke = SKShapeNode(circleOfRadius: CGFloat.random(in: 4...8))
            smoke.position = CGPoint(x: CGFloat.random(in: -8...8), y: 22 + CGFloat.random(in: 0...5))
            smoke.fillColor = UIColor.gray.withAlphaComponent(CGFloat.random(in: 0.3...0.5))
            smoke.strokeColor = .clear
            smoke.zPosition = 14
            barrel.addChild(smoke)

            let rise = SKAction.moveBy(x: CGFloat.random(in: -15...15), y: CGFloat.random(in: 20...40), duration: 0.5)
            let fade = SKAction.fadeOut(withDuration: 0.5)
            let expand = SKAction.scale(to: 1.5, duration: 0.5)
            smoke.run(SKAction.sequence([
                SKAction.group([rise, fade, expand]),
                SKAction.removeFromParent()
            ]))
        }
    }

    /// Beam: Lens flare overexposure effect
    private static func playBeamMuzzleFlash(barrel: SKNode, color: UIColor) {
        // Overexposure flash (alpha > 1 simulated with additive blending)
        if let flash = barrel.childNode(withName: "muzzleFlash") as? SKShapeNode {
            flash.blendMode = .add
            let flashSequence = SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 1.8, duration: 0.03),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.02)
                ]),
                SKAction.group([
                    SKAction.scale(to: 1.0, duration: 0.1),
                    SKAction.fadeAlpha(to: 0, duration: 0.1)
                ])
            ])
            flash.run(flashSequence)
        }

        // Lens flare streaks
        for i in 0..<4 {
            let streak = SKShapeNode(rect: CGRect(x: -15, y: -1, width: 30, height: 2))
            streak.position = CGPoint(x: 0, y: 22)
            streak.fillColor = color.withAlphaComponent(0.6)
            streak.strokeColor = .clear
            streak.zRotation = CGFloat(i) * .pi / 4
            streak.blendMode = .add
            streak.zPosition = 15
            streak.alpha = 0.8
            barrel.addChild(streak)

            let flare = SKAction.sequence([
                SKAction.group([
                    SKAction.scaleX(to: 1.5, duration: 0.05),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.05)
                ]),
                SKAction.group([
                    SKAction.scaleX(to: 0.5, duration: 0.15),
                    SKAction.fadeOut(withDuration: 0.15)
                ]),
                SKAction.removeFromParent()
            ])
            streak.run(flare)
        }
    }

    /// Tesla: Electric spark burst
    private static func playTeslaMuzzleFlash(barrel: SKNode, color: UIColor) {
        // Base flash
        if let flash = barrel.childNode(withName: "muzzleFlash") {
            let flashSequence = SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 1.5, duration: 0.03),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.02)
                ]),
                SKAction.group([
                    SKAction.scale(to: 0.8, duration: 0.08),
                    SKAction.fadeAlpha(to: 0, duration: 0.08)
                ])
            ])
            flash.run(flashSequence)
        }

        // Electric sparks radiating outward
        let sparkCount = Int.random(in: 6...8)
        for i in 0..<sparkCount {
            let spark = SKShapeNode(rect: CGRect(x: 0, y: -1, width: CGFloat.random(in: 12...20), height: 2))
            spark.position = CGPoint(x: 0, y: 22)
            spark.fillColor = UIColor.cyan
            spark.strokeColor = .clear
            spark.glowWidth = 0
            spark.blendMode = .add
            spark.zPosition = 15

            let angle = CGFloat(i) * (2 * .pi / CGFloat(sparkCount)) + CGFloat.random(in: -0.2...0.2)
            spark.zRotation = angle

            barrel.addChild(spark)

            // Spark shoots out and fades
            let distance = CGFloat.random(in: 15...25)
            let moveOut = SKAction.move(by: CGVector(dx: cos(angle) * distance, dy: sin(angle) * distance + 22), duration: 0.1)
            let fade = SKAction.fadeOut(withDuration: 0.12)
            let flicker = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.5, duration: 0.02),
                SKAction.fadeAlpha(to: 1.0, duration: 0.02)
            ])

            spark.run(SKAction.sequence([
                SKAction.repeat(flicker, count: 2),
                SKAction.group([moveOut, fade]),
                SKAction.removeFromParent()
            ]))
        }
    }

    /// Frost: Ice crystal burst
    private static func playFrostMuzzleFlash(barrel: SKNode, color: UIColor) {
        // Cyan flash
        if let flash = barrel.childNode(withName: "muzzleFlash") as? SKShapeNode {
            flash.fillColor = UIColor.cyan
            let flashSequence = SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 1.5, duration: 0.04),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.03)
                ]),
                SKAction.group([
                    SKAction.scale(to: 0.8, duration: 0.12),
                    SKAction.fadeAlpha(to: 0, duration: 0.15)
                ])
            ])
            flash.run(flashSequence)
        }

        // Ice crystal shards
        for _ in 0..<Int.random(in: 4...6) {
            // Diamond/crystal shape
            let crystalPath = UIBezierPath()
            let size: CGFloat = CGFloat.random(in: 4...8)
            crystalPath.move(to: CGPoint(x: 0, y: size))
            crystalPath.addLine(to: CGPoint(x: size * 0.6, y: 0))
            crystalPath.addLine(to: CGPoint(x: 0, y: -size))
            crystalPath.addLine(to: CGPoint(x: -size * 0.6, y: 0))
            crystalPath.close()

            let crystal = SKShapeNode(path: crystalPath.cgPath)
            crystal.position = CGPoint(x: CGFloat.random(in: -8...8), y: 22)
            crystal.fillColor = UIColor.cyan.withAlphaComponent(CGFloat.random(in: 0.5...0.8))
            crystal.strokeColor = UIColor.white.withAlphaComponent(0.6)
            crystal.lineWidth = 1
            crystal.glowWidth = 0
            crystal.blendMode = .add
            crystal.zPosition = 15
            barrel.addChild(crystal)

            let angle = CGFloat.random(in: -CGFloat.pi/3...CGFloat.pi/3)
            let distance = CGFloat.random(in: 20...35)
            let moveOut = SKAction.move(by: CGVector(dx: sin(angle) * distance, dy: cos(angle) * distance), duration: 0.2)
            let fade = SKAction.fadeOut(withDuration: 0.25)
            let spin = SKAction.rotate(byAngle: CGFloat.random(in: -1...1), duration: 0.25)

            crystal.run(SKAction.sequence([
                SKAction.group([moveOut, fade, spin]),
                SKAction.removeFromParent()
            ]))
        }
    }

    // MARK: - Beam Line

    /// Sustained beam line from barrel tip toward target direction. Fades over 0.2s.
    static func playBeamLine(node: SKNode, color: UIColor, range: CGFloat, rotation: CGFloat) {
        guard let barrel = node.childNode(withName: "barrel") else { return }

        // Remove any existing beam to avoid stacking
        barrel.childNode(withName: "beamLine")?.removeFromParent()

        // Create beam from barrel tip toward target direction
        let beamLength = range * 0.9
        let beamPath = CGMutablePath()
        beamPath.move(to: CGPoint(x: 0, y: 22))  // Barrel tip
        beamPath.addLine(to: CGPoint(x: 0, y: 22 + beamLength))

        let beam = SKShapeNode(path: beamPath)
        beam.strokeColor = color
        beam.lineWidth = 3
        beam.glowWidth = 3
        beam.blendMode = .add
        beam.alpha = 0.8
        beam.zPosition = 14
        beam.name = "beamLine"
        barrel.addChild(beam)

        let fadeOut = SKAction.sequence([
            SKAction.wait(forDuration: 0.05),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.15),
                SKAction.run { beam.lineWidth = 1.5 }
            ]),
            SKAction.removeFromParent()
        ])
        fadeOut.timingMode = .easeOut
        beam.run(fadeOut)
    }

    // MARK: - Recoil

    /// Play recoil animation
    static func playRecoil(node: SKNode, intensity: CGFloat = 3.0) {
        guard let body = node.childNode(withName: "body"),
              let barrel = node.childNode(withName: "barrel") else { return }

        let originalBarrelY = barrel.position.y

        // Barrel recoil
        let recoil = SKAction.sequence([
            SKAction.moveBy(x: 0, y: -intensity, duration: 0.05),
            SKAction.move(to: CGPoint(x: barrel.position.x, y: originalBarrelY), duration: 0.15)
        ])
        recoil.timingMode = .easeOut
        barrel.run(recoil)

        // Body shake
        let shake = SKAction.sequence([
            SKAction.moveBy(x: 0, y: -intensity * 0.5, duration: 0.03),
            SKAction.moveBy(x: 0, y: intensity * 0.5, duration: 0.07)
        ])
        body.run(shake)
    }

    // MARK: - Range Indicator

    /// Show range indicator
    static func showRange(node: SKNode, animated: Bool = true) {
        guard let range = node.childNode(withName: "range") else { return }

        range.isHidden = false

        if animated {
            range.alpha = 0
            range.setScale(0.8)
            let show = SKAction.group([
                SKAction.fadeIn(withDuration: 0.2),
                SKAction.scale(to: 1.0, duration: 0.2)
            ])
            range.run(show)
        }
    }

    /// Hide range indicator
    static func hideRange(node: SKNode, animated: Bool = true) {
        guard let range = node.childNode(withName: "range") else { return }

        if animated {
            let hide = SKAction.sequence([
                SKAction.group([
                    SKAction.fadeOut(withDuration: 0.15),
                    SKAction.scale(to: 0.9, duration: 0.15)
                ]),
                SKAction.run { range.isHidden = true }
            ])
            range.run(hide)
        } else {
            range.isHidden = true
        }
    }

    // MARK: - Cooldown

    /// Update cooldown arc
    static func updateCooldownArc(node: SKNode, progress: CGFloat, color: UIColor) {
        guard let cooldown = node.childNode(withName: "cooldown") as? SKShapeNode else { return }

        // Guard against invalid progress values (NaN, Infinity, or out of range)
        if !progress.isFinite || progress <= 0 || progress >= 1 {
            cooldown.isHidden = true
            return
        }

        cooldown.isHidden = false

        let radius: CGFloat = 20
        let startAngle: CGFloat = .pi / 2
        let endAngle = startAngle - (progress * .pi * 2)

        let path = UIBezierPath(
            arcCenter: .zero,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )

        cooldown.path = path.cgPath
    }

    // MARK: - Targeting

    /// Play targeting lock-on animation
    static func playTargetingLockOn(node: SKNode, color: UIColor) {
        guard let body = node.childNode(withName: "body") else { return }

        // Contract brackets inward (for projectile types)
        for i in 0..<4 {
            if let bracket = body.childNode(withName: "bracket_\(i)") {
                let contractIn = SKAction.scale(to: 0.85, duration: 0.1)
                contractIn.timingMode = .easeOut
                bracket.run(contractIn)
            }
        }

        // Intensify glow
        if let glow = node.childNode(withName: "glow") {
            let intensify = SKAction.sequence([
                SKAction.run {
                    if let shape = glow.children.first as? SKShapeNode {
                        shape.glowWidth = 0
                    }
                },
                SKAction.wait(forDuration: 0.3),
                SKAction.run {
                    if let shape = glow.children.first as? SKShapeNode {
                        shape.glowWidth = 0
                    }
                }
            ])
            glow.run(intensify)
        }
    }

    /// Reset targeting animation
    static func resetTargeting(node: SKNode) {
        guard let body = node.childNode(withName: "body") else { return }

        for i in 0..<4 {
            if let bracket = body.childNode(withName: "bracket_\(i)") {
                let expand = SKAction.scale(to: 1.0, duration: 0.15)
                expand.timingMode = .easeOut
                bracket.run(expand)
            }
        }
    }

    // MARK: - Charging

    /// Play charging animation (for beam/laser types)
    static func playChargingAnimation(node: SKNode, duration: TimeInterval, color: UIColor) {
        // Capacitor fill animation (batched node)
        if let platform = node.childNode(withName: "basePlatform"),
           let capacitors = platform.childNode(withName: "capacitors") as? SKShapeNode {
            let charge = SKAction.sequence([
                SKAction.wait(forDuration: duration * 0.25),
                SKAction.run {
                    capacitors.fillColor = color
                    capacitors.glowWidth = 0
                }
            ])
            capacitors.run(charge)
        }

        // Lens intensify
        if let body = node.childNode(withName: "body") as? SKShapeNode {
            if let lens = body.childNode(withName: "lens") as? SKShapeNode {
                let charge = SKAction.sequence([
                    SKAction.group([
                        SKAction.scale(to: 1.3, duration: duration),
                        SKAction.run { lens.glowWidth = 0 }
                    ])
                ])
                lens.run(charge)
            }
        }
    }

    /// Reset charging animation
    static func resetChargingAnimation(node: SKNode, color: UIColor) {
        if let platform = node.childNode(withName: "basePlatform"),
           let capacitors = platform.childNode(withName: "capacitors") as? SKShapeNode {
            capacitors.fillColor = color.withAlphaComponent(0.5)
            capacitors.glowWidth = 0
        }

        if let body = node.childNode(withName: "body") as? SKShapeNode {
            if let lens = body.childNode(withName: "lens") as? SKShapeNode {
                lens.run(SKAction.scale(to: 1.0, duration: 0.2))
                lens.glowWidth = 0
            }
        }
    }
}
