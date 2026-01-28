import SpriteKit
import UIKit

// MARK: - Tower Visual Factory
// AAA Code-Only Tower Visual System
// Creates rich, multi-layered tower visuals with procedural effects

final class TowerVisualFactory {

    // MARK: - Tower Archetype

    enum TowerArchetype {
        case projectile     // Bow, TraceRoute, KernelPulse - Targeting reticle
        case artillery      // Cannon, Bomb, BurstProtocol - Heavy platform
        case frost          // IceShard - Crystalline spire
        case magic          // Staff, Wand - Arcane beacon
        case beam           // Laser, RootAccess - Tech emitter
        case tesla          // Lightning, Overflow - Tesla coil
        case pyro           // Flamethrower - Incinerator
        case legendary      // Excalibur - Divine altar
        case multishot      // ForkBomb - Replication array
        case execute        // NullPointer - System exception

        static func from(weaponType: String) -> TowerArchetype {
            switch weaponType.lowercased() {
            case "bow", "crossbow", "trace_route", "kernel_pulse":
                return .projectile
            case "cannon", "bomb", "burst_protocol":
                return .artillery
            case "ice_shard", "snowflake":
                return .frost
            case "staff", "wand":
                return .magic
            case "laser", "root_access":
                return .beam
            case "lightning", "overflow":
                return .tesla
            case "flamethrower":
                return .pyro
            case "excalibur", "sword", "katana":
                return .legendary
            case "fork_bomb":
                return .multishot
            case "null_pointer":
                return .execute
            default:
                return .projectile
            }
        }
    }

    // MARK: - Main Factory Method

    static func createTowerNode(
        weaponType: String,
        color: UIColor,
        range: CGFloat,
        mergeLevel: Int,
        level: Int,
        damage: CGFloat,
        attackSpeed: CGFloat,
        projectileCount: Int,
        rarity: String
    ) -> SKNode {
        let container = SKNode()
        let archetype = TowerArchetype.from(weaponType: weaponType)
        let rarityTier = RarityTier.from(rarity)

        // Layer 1: Outer glow aura (largest, softest)
        let outerGlow = createOuterGlow(color: color, archetype: archetype, rarity: rarityTier)
        outerGlow.name = "outerGlow"
        outerGlow.zPosition = -3
        container.addChild(outerGlow)

        // Layer 2: Mid glow (medium intensity)
        let midGlow = createMidGlow(color: color, archetype: archetype, rarity: rarityTier)
        midGlow.name = "midGlow"
        midGlow.zPosition = -2
        container.addChild(midGlow)

        // Layer 3: Core glow (tight, bright)
        let coreGlow = createCoreGlow(color: color, archetype: archetype)
        coreGlow.name = "glow"
        coreGlow.zPosition = -1
        container.addChild(coreGlow)

        // Layer 4: Base platform with circuit patterns
        let basePlatform = createBasePlatform(archetype: archetype, color: color, rarity: rarityTier)
        basePlatform.name = "basePlatform"
        basePlatform.zPosition = 0
        container.addChild(basePlatform)

        // Layer 5: Main body (archetype-specific)
        let body = createTowerBody(archetype: archetype, weaponType: weaponType, color: color, rarity: rarityTier)
        body.name = "body"
        body.zPosition = 1
        container.addChild(body)

        // Layer 6: Barrel/Emitter (archetype-specific)
        let barrel = createTowerBarrel(archetype: archetype, weaponType: weaponType, color: color)
        barrel.name = "barrel"
        barrel.anchorPoint = CGPoint(x: 0.5, y: 0)
        barrel.zPosition = 2
        container.addChild(barrel)

        // Layer 7: Muzzle flash system
        let muzzleFlash = createMuzzleFlash(archetype: archetype, color: color)
        muzzleFlash.name = "muzzleFlash"
        muzzleFlash.position = CGPoint(x: 0, y: 22)
        muzzleFlash.alpha = 0
        muzzleFlash.zPosition = 10
        barrel.addChild(muzzleFlash)

        // Layer 8: Archetype-specific detail elements
        let detailElements = createDetailElements(archetype: archetype, weaponType: weaponType, color: color, rarity: rarityTier)
        detailElements.name = "details"
        detailElements.zPosition = 3
        container.addChild(detailElements)

        // Merge level indicators
        let mergeIndicator = createMergeIndicator(count: mergeLevel, archetype: archetype, color: color)
        mergeIndicator.name = "stars"
        mergeIndicator.position = CGPoint(x: 0, y: -24)
        mergeIndicator.zPosition = 4
        container.addChild(mergeIndicator)

        // Range indicator (hidden by default)
        let rangeIndicator = createRangeIndicator(range: range, color: color)
        rangeIndicator.name = "range"
        rangeIndicator.isHidden = true
        rangeIndicator.zPosition = -5
        container.addChild(rangeIndicator)

        // Cooldown arc (hidden by default)
        let cooldownArc = createCooldownArc(color: color)
        cooldownArc.name = "cooldown"
        cooldownArc.isHidden = true
        cooldownArc.zPosition = 5
        container.addChild(cooldownArc)

        // Merge highlight
        let mergeHighlight = createMergeHighlight()
        mergeHighlight.name = "mergeHighlight"
        mergeHighlight.isHidden = true
        mergeHighlight.zPosition = 6
        container.addChild(mergeHighlight)

        // LOD detail container
        let lodDetail = createLODDetail(
            damage: damage,
            attackSpeed: attackSpeed,
            projectileCount: projectileCount,
            level: level,
            color: color
        )
        lodDetail.name = "lodDetail"
        lodDetail.alpha = 0
        lodDetail.zPosition = 20
        container.addChild(lodDetail)

        // Start idle animations
        TowerAnimations.startIdleAnimation(node: container, archetype: archetype, color: color)

        return container
    }

    // MARK: - Glow Layers

    private static func createOuterGlow(color: UIColor, archetype: TowerArchetype, rarity: RarityTier) -> SKNode {
        let container = SKNode()

        let baseRadius: CGFloat = archetype == .legendary ? 35 : 28
        let glowOpacity: CGFloat = rarity == .legendary ? 0.12 : 0.08

        let glow = SKShapeNode(circleOfRadius: baseRadius)
        glow.fillColor = color.withAlphaComponent(glowOpacity)
        glow.strokeColor = .clear
        glow.glowWidth = 15
        glow.blendMode = .add
        container.addChild(glow)

        // Add subtle rotating ring for epic+ rarity
        if rarity.rawValue >= RarityTier.epic.rawValue {
            let ring = SKShapeNode(circleOfRadius: baseRadius - 2)
            ring.fillColor = .clear
            ring.strokeColor = color.withAlphaComponent(0.1)
            ring.lineWidth = 1
            ring.glowWidth = 3
            ring.name = "outerRing"
            container.addChild(ring)
        }

        return container
    }

    private static func createMidGlow(color: UIColor, archetype: TowerArchetype, rarity: RarityTier) -> SKNode {
        let container = SKNode()

        let baseRadius: CGFloat = archetype == .legendary ? 26 : 22
        let glowOpacity: CGFloat = rarity == .legendary ? 0.25 : 0.18

        let glow = SKShapeNode(circleOfRadius: baseRadius)
        glow.fillColor = color.withAlphaComponent(glowOpacity)
        glow.strokeColor = color.withAlphaComponent(0.15)
        glow.lineWidth = 1
        glow.glowWidth = 8
        glow.blendMode = .add
        container.addChild(glow)

        return container
    }

    private static func createCoreGlow(color: UIColor, archetype: TowerArchetype) -> SKNode {
        let container = SKNode()

        let baseRadius: CGFloat = archetype == .legendary ? 20 : 16

        let glow = SKShapeNode(circleOfRadius: baseRadius)
        glow.fillColor = color.withAlphaComponent(0.4)
        glow.strokeColor = color.withAlphaComponent(0.6)
        glow.lineWidth = 2
        glow.glowWidth = 5
        glow.blendMode = .add
        container.addChild(glow)

        // Bright center highlight
        let highlight = SKShapeNode(circleOfRadius: 4)
        highlight.fillColor = UIColor.white.withAlphaComponent(0.8)
        highlight.strokeColor = .clear
        highlight.glowWidth = 3
        highlight.blendMode = .add
        highlight.name = "coreHighlight"
        container.addChild(highlight)

        return container
    }

    // MARK: - Base Platform

    private static func createBasePlatform(archetype: TowerArchetype, color: UIColor, rarity: RarityTier) -> SKNode {
        let container = SKNode()

        switch archetype {
        case .projectile:
            // Octagonal tech platform with circuit traces
            let platform = createOctagonPlatform(radius: 18, color: color)
            container.addChild(platform)
            addCircuitTraces(to: container, style: .targeting, color: color)

        case .artillery:
            // Reinforced square platform with corner bolts
            let platform = createReinforcedSquare(size: 36, color: color)
            container.addChild(platform)
            addCornerBolts(to: container, size: 36, color: color)

        case .frost:
            // Crystalline base with frost emanation
            let platform = createCrystalBase(size: 32, color: color)
            container.addChild(platform)
            addFrostParticles(to: container, color: color)

        case .magic:
            // Arcane circle with rotating runes
            let platform = createArcaneCircle(radius: 20, color: color)
            container.addChild(platform)

        case .beam:
            // Tech grid platform with capacitor nodes
            let platform = createTechGrid(size: 32, color: color)
            container.addChild(platform)
            addCapacitorNodes(to: container, color: color)

        case .tesla:
            // Insulator base with coil foundation
            let platform = createInsulatorBase(radius: 18, color: color)
            container.addChild(platform)

        case .pyro:
            // Industrial base with hazard markings
            let platform = createIndustrialBase(size: 34, color: color)
            container.addChild(platform)
            addHazardStripes(to: container)

        case .legendary:
            // Ornate golden platform with sacred geometry
            let platform = createSacredPlatform(radius: 24, color: color)
            container.addChild(platform)
            addDivineRays(to: container, color: color)

        case .multishot:
            // Server rack style base
            let platform = createServerRackBase(size: 32, color: color)
            container.addChild(platform)

        case .execute:
            // Corrupted/glitched platform
            let platform = createCorruptedPlatform(size: 30, color: color)
            container.addChild(platform)
        }

        return container
    }

    // MARK: - Tower Bodies

    private static func createTowerBody(archetype: TowerArchetype, weaponType: String, color: UIColor, rarity: RarityTier) -> SKShapeNode {
        switch archetype {
        case .projectile:
            return createReticleBody(color: color, rarity: rarity)
        case .artillery:
            return createArtilleryBody(color: color, rarity: rarity)
        case .frost:
            return createCrystalBody(color: color, rarity: rarity)
        case .magic:
            return createArcaneBody(color: color, rarity: rarity)
        case .beam:
            return createEmitterBody(color: color, rarity: rarity)
        case .tesla:
            return createTeslaBody(color: color, rarity: rarity)
        case .pyro:
            return createIncineratorBody(color: color, rarity: rarity)
        case .legendary:
            return createDivineBody(color: color)
        case .multishot:
            return createReplicatorBody(color: color, rarity: rarity)
        case .execute:
            return createExceptionBody(color: color)
        }
    }

    // MARK: - Projectile Archetype (Reticle)

    private static func createReticleBody(color: UIColor, rarity: RarityTier) -> SKShapeNode {
        let container = SKShapeNode()
        container.fillColor = .clear
        container.strokeColor = .clear

        // Outer targeting ring
        let outerRing = SKShapeNode(circleOfRadius: 16)
        outerRing.fillColor = .clear
        outerRing.strokeColor = color
        outerRing.lineWidth = 2
        outerRing.glowWidth = 2
        outerRing.name = "outerRing"
        container.addChild(outerRing)

        // Inner targeting ring
        let innerRing = SKShapeNode(circleOfRadius: 10)
        innerRing.fillColor = color.withAlphaComponent(0.2)
        innerRing.strokeColor = color.withAlphaComponent(0.8)
        innerRing.lineWidth = 1.5
        container.addChild(innerRing)

        // Crosshairs (4 lines)
        for i in 0..<4 {
            let angle = CGFloat(i) * .pi / 2
            let crosshair = createCrosshairLine(angle: angle, innerRadius: 12, outerRadius: 18, color: color)
            crosshair.name = "crosshair_\(i)"
            container.addChild(crosshair)
        }

        // Corner brackets (4)
        for i in 0..<4 {
            let angle = CGFloat(i) * .pi / 2 + .pi / 4
            let bracket = createCornerBracket(angle: angle, radius: 14, color: color)
            bracket.name = "bracket_\(i)"
            container.addChild(bracket)
        }

        // Center dot
        let centerDot = SKShapeNode(circleOfRadius: 3)
        centerDot.fillColor = color
        centerDot.strokeColor = .white
        centerDot.lineWidth = 1
        centerDot.glowWidth = 4
        centerDot.name = "centerDot"
        container.addChild(centerDot)

        return container
    }

    private static func createCrosshairLine(angle: CGFloat, innerRadius: CGFloat, outerRadius: CGFloat, color: UIColor) -> SKShapeNode {
        let path = UIBezierPath()
        let innerPoint = CGPoint(x: cos(angle) * innerRadius, y: sin(angle) * innerRadius)
        let outerPoint = CGPoint(x: cos(angle) * outerRadius, y: sin(angle) * outerRadius)
        path.move(to: innerPoint)
        path.addLine(to: outerPoint)

        let line = SKShapeNode(path: path.cgPath)
        line.strokeColor = color
        line.lineWidth = 2
        line.lineCap = .round
        return line
    }

    private static func createCornerBracket(angle: CGFloat, radius: CGFloat, color: UIColor) -> SKShapeNode {
        let path = UIBezierPath()
        let bracketLength: CGFloat = 6
        let bracketWidth: CGFloat = 4

        let center = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)

        // L-shaped bracket
        let perpAngle1 = angle + .pi / 2
        let perpAngle2 = angle

        let p1 = CGPoint(x: center.x + cos(perpAngle1) * bracketLength, y: center.y + sin(perpAngle1) * bracketLength)
        let p2 = center
        let p3 = CGPoint(x: center.x + cos(perpAngle2) * bracketWidth, y: center.y + sin(perpAngle2) * bracketWidth)

        path.move(to: p1)
        path.addLine(to: p2)
        path.addLine(to: p3)

        let bracket = SKShapeNode(path: path.cgPath)
        bracket.strokeColor = color
        bracket.lineWidth = 2
        bracket.lineCap = .square
        return bracket
    }

    // MARK: - Artillery Archetype

    private static func createArtilleryBody(color: UIColor, rarity: RarityTier) -> SKShapeNode {
        let body = SKShapeNode(rectOf: CGSize(width: 28, height: 28), cornerRadius: 4)
        body.fillColor = color
        body.strokeColor = UIColor.gray
        body.lineWidth = 3

        // Armored plating lines
        let platePath = UIBezierPath()
        platePath.move(to: CGPoint(x: -14, y: 8))
        platePath.addLine(to: CGPoint(x: 14, y: 8))
        platePath.move(to: CGPoint(x: -14, y: -8))
        platePath.addLine(to: CGPoint(x: 14, y: -8))

        let plates = SKShapeNode(path: platePath.cgPath)
        plates.strokeColor = color.darker(by: 0.3)
        plates.lineWidth = 2
        body.addChild(plates)

        // Central ammo indicator
        let ammoGlow = SKShapeNode(circleOfRadius: 6)
        ammoGlow.fillColor = color.lighter(by: 0.3)
        ammoGlow.strokeColor = .clear
        ammoGlow.glowWidth = 4
        ammoGlow.blendMode = .add
        ammoGlow.name = "ammoGlow"
        body.addChild(ammoGlow)

        return body
    }

    // MARK: - Frost Archetype (Crystal)

    private static func createCrystalBody(color: UIColor, rarity: RarityTier) -> SKShapeNode {
        // Multi-faceted crystal shape
        let path = UIBezierPath()
        let size: CGFloat = 16

        // 6-pointed crystal
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2
            let radius = (i % 2 == 0) ? size : size * 0.6
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.close()

        let crystal = SKShapeNode(path: path.cgPath)
        crystal.fillColor = color.withAlphaComponent(0.7)
        crystal.strokeColor = UIColor.cyan
        crystal.lineWidth = 2
        crystal.glowWidth = 6

        // Inner crystal facet
        let innerPath = UIBezierPath()
        let innerSize: CGFloat = 8
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2 + .pi / 6
            let point = CGPoint(x: cos(angle) * innerSize, y: sin(angle) * innerSize)
            if i == 0 {
                innerPath.move(to: point)
            } else {
                innerPath.addLine(to: point)
            }
        }
        innerPath.close()

        let innerCrystal = SKShapeNode(path: innerPath.cgPath)
        innerCrystal.fillColor = UIColor.white.withAlphaComponent(0.3)
        innerCrystal.strokeColor = UIColor.cyan.withAlphaComponent(0.8)
        innerCrystal.lineWidth = 1
        crystal.addChild(innerCrystal)

        return crystal
    }

    // MARK: - Magic Archetype (Arcane)

    private static func createArcaneBody(color: UIColor, rarity: RarityTier) -> SKShapeNode {
        let container = SKShapeNode()
        container.fillColor = .clear
        container.strokeColor = .clear

        // Floating orb platform
        let orbPlatform = SKShapeNode(circleOfRadius: 12)
        orbPlatform.fillColor = color.withAlphaComponent(0.3)
        orbPlatform.strokeColor = color
        orbPlatform.lineWidth = 2
        orbPlatform.glowWidth = 4
        container.addChild(orbPlatform)

        // Central power orb
        let orb = SKShapeNode(circleOfRadius: 8)
        orb.fillColor = color
        orb.strokeColor = .white
        orb.lineWidth = 1
        orb.glowWidth = 8
        orb.blendMode = .add
        orb.name = "powerOrb"
        container.addChild(orb)

        // Orbiting rune symbols (3)
        for i in 0..<3 {
            let angle = CGFloat(i) * 2 * .pi / 3
            let runeOrbit = SKNode()
            runeOrbit.name = "runeOrbit_\(i)"

            let rune = createRuneSymbol(index: i, color: color)
            rune.position = CGPoint(x: cos(angle) * 16, y: sin(angle) * 16)
            runeOrbit.addChild(rune)
            container.addChild(runeOrbit)
        }

        return container
    }

    private static func createRuneSymbol(index: Int, color: UIColor) -> SKShapeNode {
        let rune = SKShapeNode(circleOfRadius: 4)
        rune.fillColor = color.withAlphaComponent(0.8)
        rune.strokeColor = .white
        rune.lineWidth = 1
        rune.glowWidth = 3
        rune.name = "rune_\(index)"
        return rune
    }

    // MARK: - Beam Archetype (Tech Emitter)

    private static func createEmitterBody(color: UIColor, rarity: RarityTier) -> SKShapeNode {
        let body = SKShapeNode(rectOf: CGSize(width: 26, height: 26), cornerRadius: 6)
        body.fillColor = color.withAlphaComponent(0.8)
        body.strokeColor = .white
        body.lineWidth = 2

        // Central lens
        let lens = SKShapeNode(circleOfRadius: 8)
        lens.fillColor = color.lighter(by: 0.4)
        lens.strokeColor = .white
        lens.lineWidth = 2
        lens.glowWidth = 6
        lens.name = "lens"
        body.addChild(lens)

        // Lens inner ring
        let lensInner = SKShapeNode(circleOfRadius: 4)
        lensInner.fillColor = .white.withAlphaComponent(0.5)
        lensInner.strokeColor = .clear
        lensInner.glowWidth = 3
        lens.addChild(lensInner)

        return body
    }

    // MARK: - Tesla Archetype

    private static func createTeslaBody(color: UIColor, rarity: RarityTier) -> SKShapeNode {
        let container = SKShapeNode()
        container.fillColor = .clear
        container.strokeColor = .clear

        // Cylindrical base representation
        let base = SKShapeNode(ellipseOf: CGSize(width: 28, height: 14))
        base.fillColor = color.withAlphaComponent(0.6)
        base.strokeColor = .white
        base.lineWidth = 2
        base.position = CGPoint(x: 0, y: -4)
        container.addChild(base)

        // Central conductor spike
        let spike = SKShapeNode(rectOf: CGSize(width: 6, height: 20), cornerRadius: 2)
        spike.fillColor = color
        spike.strokeColor = UIColor.cyan
        spike.lineWidth = 2
        spike.glowWidth = 4
        spike.position = CGPoint(x: 0, y: 4)
        spike.name = "conductor"
        container.addChild(spike)

        // Discharge nodes (4)
        for i in 0..<4 {
            let angle = CGFloat(i) * .pi / 2
            let node = SKShapeNode(circleOfRadius: 3)
            node.fillColor = UIColor.cyan
            node.strokeColor = .white
            node.lineWidth = 1
            node.glowWidth = 4
            node.position = CGPoint(x: cos(angle) * 12, y: sin(angle) * 12 + 4)
            node.name = "dischargeNode_\(i)"
            container.addChild(node)
        }

        return container
    }

    // MARK: - Pyro Archetype (Incinerator)

    private static func createIncineratorBody(color: UIColor, rarity: RarityTier) -> SKShapeNode {
        let body = SKShapeNode(rectOf: CGSize(width: 28, height: 24), cornerRadius: 4)
        body.fillColor = color.withAlphaComponent(0.8)
        body.strokeColor = .gray
        body.lineWidth = 3

        // Fuel tanks (2 cylinders)
        let leftTank = SKShapeNode(ellipseOf: CGSize(width: 8, height: 16))
        leftTank.fillColor = UIColor.darkGray
        leftTank.strokeColor = color
        leftTank.lineWidth = 1
        leftTank.position = CGPoint(x: -8, y: 0)
        leftTank.name = "leftTank"
        body.addChild(leftTank)

        let rightTank = SKShapeNode(ellipseOf: CGSize(width: 8, height: 16))
        rightTank.fillColor = UIColor.darkGray
        rightTank.strokeColor = color
        rightTank.lineWidth = 1
        rightTank.position = CGPoint(x: 8, y: 0)
        rightTank.name = "rightTank"
        body.addChild(rightTank)

        // Pilot flame indicator
        let pilotFlame = SKShapeNode(circleOfRadius: 4)
        pilotFlame.fillColor = UIColor.orange
        pilotFlame.strokeColor = UIColor.yellow
        pilotFlame.lineWidth = 1
        pilotFlame.glowWidth = 5
        pilotFlame.blendMode = .add
        pilotFlame.name = "pilotFlame"
        body.addChild(pilotFlame)

        return body
    }

    // MARK: - Legendary Archetype (Divine)

    private static func createDivineBody(color: UIColor) -> SKShapeNode {
        let container = SKShapeNode()
        container.fillColor = .clear
        container.strokeColor = .clear

        // Sacred circle base
        let circle = SKShapeNode(circleOfRadius: 18)
        circle.fillColor = UIColor(hex: "f59e0b")?.withAlphaComponent(0.3) ?? color.withAlphaComponent(0.3)
        circle.strokeColor = UIColor(hex: "f59e0b") ?? color
        circle.lineWidth = 2
        circle.glowWidth = 6
        container.addChild(circle)

        // Floating sword silhouette
        let swordPath = createSwordPath()
        let sword = SKShapeNode(path: swordPath)
        sword.fillColor = UIColor(hex: "fbbf24") ?? .yellow
        sword.strokeColor = .white
        sword.lineWidth = 1
        sword.glowWidth = 8
        sword.name = "sword"
        container.addChild(sword)

        // Divine aura particles (handled in detail elements)

        return container
    }

    private static func createSwordPath() -> CGPath {
        let path = UIBezierPath()
        // Simplified sword shape
        path.move(to: CGPoint(x: 0, y: 14))     // Tip
        path.addLine(to: CGPoint(x: 3, y: 4))   // Right edge
        path.addLine(to: CGPoint(x: 6, y: 2))   // Right guard
        path.addLine(to: CGPoint(x: 6, y: 0))
        path.addLine(to: CGPoint(x: 2, y: 0))   // Handle top
        path.addLine(to: CGPoint(x: 2, y: -10)) // Handle
        path.addLine(to: CGPoint(x: 4, y: -12)) // Pommel
        path.addLine(to: CGPoint(x: 0, y: -14)) // Pommel bottom
        path.addLine(to: CGPoint(x: -4, y: -12))
        path.addLine(to: CGPoint(x: -2, y: -10))
        path.addLine(to: CGPoint(x: -2, y: 0))
        path.addLine(to: CGPoint(x: -6, y: 0))
        path.addLine(to: CGPoint(x: -6, y: 2))  // Left guard
        path.addLine(to: CGPoint(x: -3, y: 4))  // Left edge
        path.close()
        return path.cgPath
    }

    // MARK: - Multishot Archetype (Replicator)

    private static func createReplicatorBody(color: UIColor, rarity: RarityTier) -> SKShapeNode {
        let container = SKShapeNode()
        container.fillColor = .clear
        container.strokeColor = .clear

        // Central hub
        let hub = SKShapeNode(circleOfRadius: 8)
        hub.fillColor = color
        hub.strokeColor = .white
        hub.lineWidth = 2
        hub.glowWidth = 4
        hub.name = "hub"
        container.addChild(hub)

        // Process nodes (5 in pentagon)
        for i in 0..<5 {
            let angle = CGFloat(i) * 2 * .pi / 5 - .pi / 2
            let node = SKShapeNode(circleOfRadius: 5)
            node.fillColor = color.withAlphaComponent(0.7)
            node.strokeColor = color
            node.lineWidth = 1
            node.glowWidth = 3
            node.position = CGPoint(x: cos(angle) * 14, y: sin(angle) * 14)
            node.name = "processNode_\(i)"
            container.addChild(node)

            // Connection line to hub
            let linePath = UIBezierPath()
            linePath.move(to: .zero)
            linePath.addLine(to: node.position)
            let line = SKShapeNode(path: linePath.cgPath)
            line.strokeColor = color.withAlphaComponent(0.5)
            line.lineWidth = 1
            line.name = "connection_\(i)"
            container.addChild(line)
        }

        return container
    }

    // MARK: - Execute Archetype (Exception)

    private static func createExceptionBody(color: UIColor) -> SKShapeNode {
        let container = SKShapeNode()
        container.fillColor = .clear
        container.strokeColor = .clear

        // Warning triangle
        let trianglePath = UIBezierPath()
        let size: CGFloat = 18
        trianglePath.move(to: CGPoint(x: 0, y: size))
        trianglePath.addLine(to: CGPoint(x: -size * 0.866, y: -size * 0.5))
        trianglePath.addLine(to: CGPoint(x: size * 0.866, y: -size * 0.5))
        trianglePath.close()

        let triangle = SKShapeNode(path: trianglePath.cgPath)
        triangle.fillColor = UIColor(hex: "ef4444")?.withAlphaComponent(0.8) ?? .red.withAlphaComponent(0.8)
        triangle.strokeColor = UIColor(hex: "ef4444") ?? .red
        triangle.lineWidth = 2
        triangle.glowWidth = 6
        triangle.name = "warningTriangle"
        container.addChild(triangle)

        // Exclamation mark
        let exclamation = SKLabelNode(text: "!")
        exclamation.fontName = "Menlo-Bold"
        exclamation.fontSize = 16
        exclamation.fontColor = .white
        exclamation.verticalAlignmentMode = .center
        exclamation.horizontalAlignmentMode = .center
        exclamation.position = CGPoint(x: 0, y: 2)
        exclamation.name = "exclamation"
        container.addChild(exclamation)

        return container
    }

    // MARK: - Tower Barrels

    private static func createTowerBarrel(archetype: TowerArchetype, weaponType: String, color: UIColor) -> SKSpriteNode {
        switch archetype {
        case .projectile:
            return createPrecisionBarrel(color: color)
        case .artillery:
            return createHeavyBarrel(color: color)
        case .frost:
            return createCrystalEmitter(color: color)
        case .magic:
            return createOrbEmitter(color: color)
        case .beam:
            return createLensArray(color: color)
        case .tesla:
            return createTeslaAntenna(color: color)
        case .pyro:
            return createFlameNozzle(color: color)
        case .legendary:
            return createDivineBeam(color: color)
        case .multishot:
            return createMultiEmitter(color: color)
        case .execute:
            return createExceptionEmitter(color: color)
        }
    }

    private static func createPrecisionBarrel(color: UIColor) -> SKSpriteNode {
        let barrel = SKSpriteNode(color: .darkGray, size: CGSize(width: 6, height: 22))

        // Barrel tip highlight
        let tip = SKShapeNode(rectOf: CGSize(width: 8, height: 4), cornerRadius: 1)
        tip.fillColor = color
        tip.strokeColor = .white
        tip.lineWidth = 1
        tip.position = CGPoint(x: 0, y: 11)
        barrel.addChild(tip)

        return barrel
    }

    private static func createHeavyBarrel(color: UIColor) -> SKSpriteNode {
        let barrel = SKSpriteNode(color: .darkGray, size: CGSize(width: 12, height: 18))

        // Muzzle brake
        let brake = SKShapeNode(rectOf: CGSize(width: 16, height: 4), cornerRadius: 1)
        brake.fillColor = .gray
        brake.strokeColor = color.withAlphaComponent(0.5)
        brake.lineWidth = 1
        brake.position = CGPoint(x: 0, y: 9)
        barrel.addChild(brake)

        return barrel
    }

    private static func createCrystalEmitter(color: UIColor) -> SKSpriteNode {
        let barrel = SKSpriteNode(color: .clear, size: CGSize(width: 8, height: 20))

        // Central crystal spike
        let spike = SKShapeNode(rectOf: CGSize(width: 4, height: 16), cornerRadius: 1)
        spike.fillColor = color.withAlphaComponent(0.8)
        spike.strokeColor = .cyan
        spike.lineWidth = 1
        spike.glowWidth = 4
        spike.position = CGPoint(x: 0, y: 8)
        barrel.addChild(spike)

        // Ice crystal tip
        let tip = SKShapeNode(circleOfRadius: 4)
        tip.fillColor = .cyan
        tip.strokeColor = .white
        tip.lineWidth = 1
        tip.glowWidth = 6
        tip.position = CGPoint(x: 0, y: 18)
        barrel.addChild(tip)

        return barrel
    }

    private static func createOrbEmitter(color: UIColor) -> SKSpriteNode {
        let barrel = SKSpriteNode(color: .clear, size: CGSize(width: 6, height: 18))

        // Floating orb at top
        let orb = SKShapeNode(circleOfRadius: 6)
        orb.fillColor = color
        orb.strokeColor = .white
        orb.lineWidth = 1
        orb.glowWidth = 8
        orb.blendMode = .add
        orb.position = CGPoint(x: 0, y: 18)
        orb.name = "emitterOrb"
        barrel.addChild(orb)

        // Energy trail
        let trail = SKShapeNode(rectOf: CGSize(width: 2, height: 12), cornerRadius: 1)
        trail.fillColor = color.withAlphaComponent(0.5)
        trail.strokeColor = .clear
        trail.glowWidth = 3
        trail.position = CGPoint(x: 0, y: 6)
        barrel.addChild(trail)

        return barrel
    }

    private static func createLensArray(color: UIColor) -> SKSpriteNode {
        let barrel = SKSpriteNode(color: color.withAlphaComponent(0.6), size: CGSize(width: 8, height: 24))

        // Focusing lens at top
        let lens = SKShapeNode(circleOfRadius: 5)
        lens.fillColor = color.lighter(by: 0.3)
        lens.strokeColor = .white
        lens.lineWidth = 2
        lens.glowWidth = 4
        lens.position = CGPoint(x: 0, y: 12)
        lens.name = "focusLens"
        barrel.addChild(lens)

        return barrel
    }

    private static func createTeslaAntenna(color: UIColor) -> SKSpriteNode {
        let barrel = SKSpriteNode(color: .clear, size: CGSize(width: 10, height: 26))

        // Central antenna
        let antenna = SKShapeNode(rectOf: CGSize(width: 4, height: 22), cornerRadius: 1)
        antenna.fillColor = color
        antenna.strokeColor = .cyan
        antenna.lineWidth = 1
        antenna.glowWidth = 3
        antenna.position = CGPoint(x: 0, y: 11)
        barrel.addChild(antenna)

        // Top sphere
        let sphere = SKShapeNode(circleOfRadius: 5)
        sphere.fillColor = .cyan
        sphere.strokeColor = .white
        sphere.lineWidth = 1
        sphere.glowWidth = 8
        sphere.position = CGPoint(x: 0, y: 24)
        sphere.name = "teslaSphere"
        barrel.addChild(sphere)

        return barrel
    }

    private static func createFlameNozzle(color: UIColor) -> SKSpriteNode {
        let barrel = SKSpriteNode(color: .darkGray, size: CGSize(width: 14, height: 16))

        // Triple nozzle tips
        for i in -1...1 {
            let nozzle = SKShapeNode(rectOf: CGSize(width: 4, height: 6), cornerRadius: 1)
            nozzle.fillColor = .gray
            nozzle.strokeColor = color
            nozzle.lineWidth = 1
            nozzle.position = CGPoint(x: CGFloat(i) * 5, y: 10)
            barrel.addChild(nozzle)
        }

        return barrel
    }

    private static func createDivineBeam(color: UIColor) -> SKSpriteNode {
        let barrel = SKSpriteNode(color: .clear, size: CGSize(width: 8, height: 20))

        // Vertical light beam
        let beam = SKShapeNode(rectOf: CGSize(width: 4, height: 40), cornerRadius: 2)
        beam.fillColor = UIColor(hex: "fbbf24")?.withAlphaComponent(0.3) ?? .yellow.withAlphaComponent(0.3)
        beam.strokeColor = .clear
        beam.glowWidth = 8
        beam.blendMode = .add
        beam.position = CGPoint(x: 0, y: 20)
        beam.name = "divineBeam"
        barrel.addChild(beam)

        return barrel
    }

    private static func createMultiEmitter(color: UIColor) -> SKSpriteNode {
        let barrel = SKSpriteNode(color: .clear, size: CGSize(width: 16, height: 18))

        // Multiple small emitters
        let positions: [CGPoint] = [
            CGPoint(x: -5, y: 9),
            CGPoint(x: 0, y: 12),
            CGPoint(x: 5, y: 9)
        ]

        for (i, pos) in positions.enumerated() {
            let emitter = SKShapeNode(circleOfRadius: 3)
            emitter.fillColor = color
            emitter.strokeColor = .white
            emitter.lineWidth = 1
            emitter.glowWidth = 3
            emitter.position = pos
            emitter.name = "emitter_\(i)"
            barrel.addChild(emitter)
        }

        return barrel
    }

    private static func createExceptionEmitter(color: UIColor) -> SKSpriteNode {
        let barrel = SKSpriteNode(color: .clear, size: CGSize(width: 10, height: 16))

        // Glitched emitter
        let glitch = SKShapeNode(rectOf: CGSize(width: 8, height: 14), cornerRadius: 2)
        glitch.fillColor = UIColor(hex: "ef4444")?.withAlphaComponent(0.8) ?? .red.withAlphaComponent(0.8)
        glitch.strokeColor = .white
        glitch.lineWidth = 1
        glitch.glowWidth = 4
        glitch.position = CGPoint(x: 0, y: 7)
        glitch.name = "glitchEmitter"
        barrel.addChild(glitch)

        return barrel
    }

    // MARK: - Muzzle Flash

    private static func createMuzzleFlash(archetype: TowerArchetype, color: UIColor) -> SKNode {
        let container = SKNode()

        // Core flash
        let flash = SKShapeNode(circleOfRadius: 10)
        flash.fillColor = color.lighter(by: 0.4)
        flash.strokeColor = .white
        flash.lineWidth = 2
        flash.glowWidth = 15
        flash.blendMode = .add
        container.addChild(flash)

        // Outer ring
        let ring = SKShapeNode(circleOfRadius: 14)
        ring.fillColor = .clear
        ring.strokeColor = color
        ring.lineWidth = 2
        ring.glowWidth = 8
        ring.blendMode = .add
        container.addChild(ring)

        return container
    }

    // MARK: - Detail Elements

    private static func createDetailElements(archetype: TowerArchetype, weaponType: String, color: UIColor, rarity: RarityTier) -> SKNode {
        let container = SKNode()

        switch archetype {
        case .frost:
            // Orbiting ice shards
            for i in 0..<3 {
                let shard = createIceShard(index: i, color: color)
                shard.name = "iceShard_\(i)"
                container.addChild(shard)
            }

        case .tesla:
            // Electric arc nodes
            addElectricArcs(to: container, color: color)

        case .legendary:
            // Divine particles and light rays
            addDivineParticles(to: container)

        case .execute:
            // Glitch artifacts
            addGlitchArtifacts(to: container)

        default:
            break
        }

        return container
    }

    private static func createIceShard(index: Int, color: UIColor) -> SKNode {
        let container = SKNode()

        let angle = CGFloat(index) * 2 * .pi / 3
        let radius: CGFloat = 22

        let shard = SKShapeNode(rectOf: CGSize(width: 4, height: 10), cornerRadius: 1)
        shard.fillColor = color.withAlphaComponent(0.8)
        shard.strokeColor = .cyan
        shard.lineWidth = 1
        shard.glowWidth = 3
        shard.position = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
        shard.zRotation = angle + .pi / 2
        container.addChild(shard)

        return container
    }

    private static func addElectricArcs(to container: SKNode, color: UIColor) {
        // Static arc placeholder - animation will create dynamic arcs
        let arcIndicator = SKNode()
        arcIndicator.name = "arcContainer"
        container.addChild(arcIndicator)
    }

    private static func addDivineParticles(to container: SKNode) {
        // Particle container for animation
        let particleContainer = SKNode()
        particleContainer.name = "divineParticles"
        container.addChild(particleContainer)
    }

    private static func addGlitchArtifacts(to container: SKNode) {
        // Glitch container for animation
        let glitchContainer = SKNode()
        glitchContainer.name = "glitchContainer"
        container.addChild(glitchContainer)
    }

    // MARK: - Platform Helpers

    private static func createOctagonPlatform(radius: CGFloat, color: UIColor) -> SKShapeNode {
        let path = UIBezierPath()
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4 - .pi / 8
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.close()

        let platform = SKShapeNode(path: path.cgPath)
        platform.fillColor = color.withAlphaComponent(0.15)
        platform.strokeColor = color.withAlphaComponent(0.4)
        platform.lineWidth = 1
        return platform
    }

    private static func createReinforcedSquare(size: CGFloat, color: UIColor) -> SKShapeNode {
        let platform = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 3)
        platform.fillColor = color.withAlphaComponent(0.15)
        platform.strokeColor = color.withAlphaComponent(0.5)
        platform.lineWidth = 2
        return platform
    }

    private static func createCrystalBase(size: CGFloat, color: UIColor) -> SKShapeNode {
        let path = createDiamondPath(size: size)
        let platform = SKShapeNode(path: path)
        platform.fillColor = color.withAlphaComponent(0.1)
        platform.strokeColor = UIColor.cyan.withAlphaComponent(0.4)
        platform.lineWidth = 1
        platform.glowWidth = 3
        return platform
    }

    private static func createArcaneCircle(radius: CGFloat, color: UIColor) -> SKShapeNode {
        let container = SKShapeNode()
        container.fillColor = .clear
        container.strokeColor = .clear

        // Outer circle
        let outer = SKShapeNode(circleOfRadius: radius)
        outer.fillColor = .clear
        outer.strokeColor = color.withAlphaComponent(0.5)
        outer.lineWidth = 2
        outer.glowWidth = 3
        container.addChild(outer)

        // Inner circle
        let inner = SKShapeNode(circleOfRadius: radius * 0.7)
        inner.fillColor = color.withAlphaComponent(0.1)
        inner.strokeColor = color.withAlphaComponent(0.3)
        inner.lineWidth = 1
        container.addChild(inner)

        // Rune markers
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3
            let marker = SKShapeNode(circleOfRadius: 2)
            marker.fillColor = color
            marker.strokeColor = .clear
            marker.glowWidth = 2
            marker.position = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            container.addChild(marker)
        }

        return container
    }

    private static func createTechGrid(size: CGFloat, color: UIColor) -> SKShapeNode {
        let platform = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 4)
        platform.fillColor = color.withAlphaComponent(0.1)
        platform.strokeColor = color.withAlphaComponent(0.4)
        platform.lineWidth = 1

        // Grid lines
        let gridPath = UIBezierPath()
        let half = size / 2
        let third = size / 3

        // Horizontal
        gridPath.move(to: CGPoint(x: -half, y: third - half))
        gridPath.addLine(to: CGPoint(x: half, y: third - half))
        gridPath.move(to: CGPoint(x: -half, y: 2 * third - half))
        gridPath.addLine(to: CGPoint(x: half, y: 2 * third - half))

        // Vertical
        gridPath.move(to: CGPoint(x: third - half, y: -half))
        gridPath.addLine(to: CGPoint(x: third - half, y: half))
        gridPath.move(to: CGPoint(x: 2 * third - half, y: -half))
        gridPath.addLine(to: CGPoint(x: 2 * third - half, y: half))

        let grid = SKShapeNode(path: gridPath.cgPath)
        grid.strokeColor = color.withAlphaComponent(0.2)
        grid.lineWidth = 0.5
        platform.addChild(grid)

        return platform
    }

    private static func createInsulatorBase(radius: CGFloat, color: UIColor) -> SKShapeNode {
        let platform = SKShapeNode(circleOfRadius: radius)
        platform.fillColor = UIColor.darkGray.withAlphaComponent(0.8)
        platform.strokeColor = color.withAlphaComponent(0.6)
        platform.lineWidth = 2

        // Insulator rings
        let ringPath = UIBezierPath()
        ringPath.addArc(withCenter: .zero, radius: radius * 0.7, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        let ring = SKShapeNode(path: ringPath.cgPath)
        ring.strokeColor = color.withAlphaComponent(0.3)
        ring.lineWidth = 1
        platform.addChild(ring)

        return platform
    }

    private static func createIndustrialBase(size: CGFloat, color: UIColor) -> SKShapeNode {
        let platform = SKShapeNode(rectOf: CGSize(width: size, height: size - 4), cornerRadius: 2)
        platform.fillColor = UIColor.darkGray.withAlphaComponent(0.8)
        platform.strokeColor = .gray
        platform.lineWidth = 2
        return platform
    }

    private static func createSacredPlatform(radius: CGFloat, color: UIColor) -> SKShapeNode {
        let container = SKShapeNode()
        container.fillColor = .clear
        container.strokeColor = .clear

        // Outer ring
        let outer = SKShapeNode(circleOfRadius: radius)
        outer.fillColor = UIColor(hex: "f59e0b")?.withAlphaComponent(0.15) ?? color.withAlphaComponent(0.15)
        outer.strokeColor = UIColor(hex: "fbbf24") ?? .yellow
        outer.lineWidth = 2
        outer.glowWidth = 4
        container.addChild(outer)

        // Inner sacred geometry (hexagram)
        let innerPath = UIBezierPath()
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2
            let point = CGPoint(x: cos(angle) * radius * 0.8, y: sin(angle) * radius * 0.8)
            if i == 0 {
                innerPath.move(to: point)
            } else {
                innerPath.addLine(to: point)
            }
        }
        innerPath.close()

        let inner = SKShapeNode(path: innerPath.cgPath)
        inner.fillColor = .clear
        inner.strokeColor = UIColor(hex: "fbbf24")?.withAlphaComponent(0.5) ?? .yellow.withAlphaComponent(0.5)
        inner.lineWidth = 1
        inner.name = "sacredGeometry"
        container.addChild(inner)

        return container
    }

    private static func createServerRackBase(size: CGFloat, color: UIColor) -> SKShapeNode {
        let platform = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 3)
        platform.fillColor = UIColor.darkGray.withAlphaComponent(0.7)
        platform.strokeColor = color.withAlphaComponent(0.5)
        platform.lineWidth = 1

        // Server rack slots
        for i in 0..<3 {
            let slot = SKShapeNode(rectOf: CGSize(width: size - 8, height: 4), cornerRadius: 1)
            slot.fillColor = color.withAlphaComponent(0.2)
            slot.strokeColor = color.withAlphaComponent(0.4)
            slot.lineWidth = 0.5
            slot.position = CGPoint(x: 0, y: CGFloat(i - 1) * 8)
            platform.addChild(slot)
        }

        return platform
    }

    private static func createCorruptedPlatform(size: CGFloat, color: UIColor) -> SKShapeNode {
        let platform = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 2)
        platform.fillColor = UIColor.black.withAlphaComponent(0.8)
        platform.strokeColor = UIColor(hex: "ef4444") ?? .red
        platform.lineWidth = 2
        platform.glowWidth = 4

        return platform
    }

    // MARK: - Circuit Traces

    private static func addCircuitTraces(to container: SKNode, style: CircuitStyle, color: UIColor) {
        let tracePath = UIBezierPath()

        switch style {
        case .targeting:
            // Cross pattern traces
            tracePath.move(to: CGPoint(x: -20, y: 0))
            tracePath.addLine(to: CGPoint(x: -8, y: 0))
            tracePath.move(to: CGPoint(x: 8, y: 0))
            tracePath.addLine(to: CGPoint(x: 20, y: 0))
            tracePath.move(to: CGPoint(x: 0, y: -20))
            tracePath.addLine(to: CGPoint(x: 0, y: -8))
            tracePath.move(to: CGPoint(x: 0, y: 8))
            tracePath.addLine(to: CGPoint(x: 0, y: 20))
        }

        let traces = SKShapeNode(path: tracePath.cgPath)
        traces.strokeColor = color.withAlphaComponent(0.3)
        traces.lineWidth = 1
        traces.name = "circuitTraces"
        container.addChild(traces)
    }

    private enum CircuitStyle {
        case targeting
    }

    // MARK: - Corner Bolts

    private static func addCornerBolts(to container: SKNode, size: CGFloat, color: UIColor) {
        let offset = size / 2 - 4
        let positions = [
            CGPoint(x: -offset, y: -offset),
            CGPoint(x: offset, y: -offset),
            CGPoint(x: -offset, y: offset),
            CGPoint(x: offset, y: offset)
        ]

        for (i, pos) in positions.enumerated() {
            let bolt = SKShapeNode(circleOfRadius: 3)
            bolt.fillColor = .gray
            bolt.strokeColor = color.withAlphaComponent(0.5)
            bolt.lineWidth = 1
            bolt.position = pos
            bolt.name = "bolt_\(i)"
            container.addChild(bolt)
        }
    }

    // MARK: - Frost Particles

    private static func addFrostParticles(to container: SKNode, color: UIColor) {
        let particleContainer = SKNode()
        particleContainer.name = "frostParticles"
        container.addChild(particleContainer)
    }

    // MARK: - Capacitor Nodes

    private static func addCapacitorNodes(to container: SKNode, color: UIColor) {
        let positions = [
            CGPoint(x: -14, y: -14),
            CGPoint(x: 14, y: -14),
            CGPoint(x: -14, y: 14),
            CGPoint(x: 14, y: 14)
        ]

        for (i, pos) in positions.enumerated() {
            let capacitor = SKShapeNode(rectOf: CGSize(width: 6, height: 8), cornerRadius: 1)
            capacitor.fillColor = color.withAlphaComponent(0.5)
            capacitor.strokeColor = color
            capacitor.lineWidth = 1
            capacitor.glowWidth = 2
            capacitor.position = pos
            capacitor.name = "capacitor_\(i)"
            container.addChild(capacitor)
        }
    }

    // MARK: - Hazard Stripes

    private static func addHazardStripes(to container: SKNode) {
        let stripePath = UIBezierPath()
        for i in 0..<4 {
            let x = CGFloat(i - 2) * 8 + 4
            stripePath.move(to: CGPoint(x: x, y: -15))
            stripePath.addLine(to: CGPoint(x: x + 4, y: -15))
            stripePath.addLine(to: CGPoint(x: x - 4, y: -11))
            stripePath.addLine(to: CGPoint(x: x - 8, y: -11))
            stripePath.close()
        }

        let stripes = SKShapeNode(path: stripePath.cgPath)
        stripes.fillColor = .yellow
        stripes.strokeColor = .clear
        stripes.alpha = 0.5
        stripes.name = "hazardStripes"
        container.addChild(stripes)
    }

    // MARK: - Divine Rays

    private static func addDivineRays(to container: SKNode, color: UIColor) {
        for i in 0..<4 {
            let angle = CGFloat(i) * .pi / 2
            let rayPath = UIBezierPath()
            rayPath.move(to: CGPoint(x: cos(angle) * 20, y: sin(angle) * 20))
            rayPath.addLine(to: CGPoint(x: cos(angle) * 40, y: sin(angle) * 40))

            let ray = SKShapeNode(path: rayPath.cgPath)
            ray.strokeColor = UIColor(hex: "fbbf24")?.withAlphaComponent(0.3) ?? .yellow.withAlphaComponent(0.3)
            ray.lineWidth = 3
            ray.glowWidth = 5
            ray.blendMode = .add
            ray.name = "divineRay_\(i)"
            container.addChild(ray)
        }
    }

    // MARK: - Utility Helpers

    private static func createDiamondPath(size: CGFloat) -> CGPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: size / 2))
        path.addLine(to: CGPoint(x: size / 2, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -size / 2))
        path.addLine(to: CGPoint(x: -size / 2, y: 0))
        path.close()
        return path.cgPath
    }

    // MARK: - Merge Indicator

    static func createMergeIndicator(count: Int, archetype: TowerArchetype, color: UIColor) -> SKNode {
        let container = SKNode()
        let spacing: CGFloat = 10

        for i in 0..<count {
            let xOffset = CGFloat(i) - CGFloat(count - 1) / 2

            // Create rune-style merge indicator instead of stars
            let indicator: SKShapeNode

            switch archetype {
            case .legendary:
                // Golden diamonds for legendary
                indicator = SKShapeNode(path: createDiamondPath(size: 8))
                indicator.fillColor = UIColor(hex: "fbbf24") ?? .yellow
                indicator.strokeColor = .white
            case .frost:
                // Ice crystals
                indicator = SKShapeNode(path: createDiamondPath(size: 8))
                indicator.fillColor = .cyan
                indicator.strokeColor = .white
            default:
                // Circuit nodes
                indicator = SKShapeNode(circleOfRadius: 4)
                indicator.fillColor = color
                indicator.strokeColor = .white
            }

            indicator.lineWidth = 1
            indicator.glowWidth = 3
            indicator.position = CGPoint(x: xOffset * spacing, y: 0)
            indicator.name = "mergeIndicator_\(i)"
            container.addChild(indicator)
        }

        return container
    }

    // MARK: - Range Indicator

    private static func createRangeIndicator(range: CGFloat, color: UIColor) -> SKShapeNode {
        let rangeCircle = SKShapeNode(circleOfRadius: range)
        rangeCircle.fillColor = color.withAlphaComponent(0.1)
        rangeCircle.strokeColor = color.withAlphaComponent(0.4)
        rangeCircle.lineWidth = 2

        // Dashed outer ring
        let dashPattern: [CGFloat] = [8, 4]
        let dashedPath = UIBezierPath(arcCenter: .zero, radius: range, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        dashedPath.setLineDash(dashPattern, count: dashPattern.count, phase: 0)

        return rangeCircle
    }

    // MARK: - Cooldown Arc

    private static func createCooldownArc(color: UIColor) -> SKShapeNode {
        let arc = SKShapeNode()
        arc.strokeColor = color.withAlphaComponent(0.8)
        arc.lineWidth = 3
        arc.lineCap = .round
        return arc
    }

    // MARK: - Merge Highlight

    private static func createMergeHighlight() -> SKShapeNode {
        let highlight = SKShapeNode(circleOfRadius: 28)
        highlight.fillColor = .clear
        highlight.strokeColor = .green
        highlight.lineWidth = 3
        highlight.glowWidth = 8

        // Animated dashes
        return highlight
    }

    // MARK: - LOD Detail

    private static func createLODDetail(damage: CGFloat, attackSpeed: CGFloat, projectileCount: Int, level: Int, color: UIColor) -> SKNode {
        let container = SKNode()

        // DPS calculation
        let dps = damage * attackSpeed * CGFloat(projectileCount)

        // DPS label background
        let dpsBg = SKShapeNode(rectOf: CGSize(width: 54, height: 16), cornerRadius: 3)
        dpsBg.fillColor = UIColor.black.withAlphaComponent(0.8)
        dpsBg.strokeColor = color.withAlphaComponent(0.6)
        dpsBg.lineWidth = 1
        dpsBg.position = CGPoint(x: 0, y: 30)
        container.addChild(dpsBg)

        // DPS label
        let dpsLabel = SKLabelNode(text: String(format: "%.0f DPS", dps))
        dpsLabel.fontSize = 10
        dpsLabel.fontName = "Menlo-Bold"
        dpsLabel.fontColor = .white
        dpsLabel.verticalAlignmentMode = .center
        dpsLabel.horizontalAlignmentMode = .center
        dpsLabel.position = CGPoint(x: 0, y: 30)
        dpsLabel.name = "dpsLabel"
        container.addChild(dpsLabel)

        // Level badge
        let levelBadge = SKShapeNode(circleOfRadius: 9)
        levelBadge.fillColor = UIColor.black.withAlphaComponent(0.9)
        levelBadge.strokeColor = color
        levelBadge.lineWidth = 1.5
        levelBadge.position = CGPoint(x: 22, y: 16)
        container.addChild(levelBadge)

        let levelLabel = SKLabelNode(text: "\(level)")
        levelLabel.fontSize = 10
        levelLabel.fontName = "Menlo-Bold"
        levelLabel.fontColor = .white
        levelLabel.verticalAlignmentMode = .center
        levelLabel.horizontalAlignmentMode = .center
        levelLabel.position = CGPoint(x: 22, y: 16)
        levelLabel.name = "levelLabel"
        container.addChild(levelLabel)

        return container
    }
}

// MARK: - Rarity Tier

enum RarityTier: Int {
    case common = 0
    case rare = 1
    case epic = 2
    case legendary = 3

    static func from(_ rarity: String) -> RarityTier {
        switch rarity.lowercased() {
        case "rare": return .rare
        case "epic": return .epic
        case "legendary": return .legendary
        default: return .common
        }
    }
}

// UIColor extensions (hex, lighter, darker) are defined in TDGameScene.swift
