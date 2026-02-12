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
        level: Int,
        damage: CGFloat,
        attackSpeed: CGFloat,
        projectileCount: Int,
        rarity: String
    ) -> SKNode {
        let container = SKNode()
        let archetype = TowerArchetype.from(weaponType: weaponType)
        let rarityTier = RarityTier.from(rarity)

        // Single glow layer (Performance: collapsed from 3 layers to 1)
        let baseRadius: CGFloat = archetype == .legendary ? 22 : 18
        let glowOpacity: CGFloat = rarityTier == .legendary ? 0.35 : 0.25
        let glow = SKShapeNode(circleOfRadius: baseRadius)
        glow.fillColor = color.withAlphaComponent(glowOpacity)
        glow.strokeColor = color.withAlphaComponent(0.4)
        glow.lineWidth = 1.5
        glow.blendMode = .add
        glow.name = "glow"
        glow.zPosition = -1
        // Selective glow: Legendary/Epic get subtle halo, others stay flat
        switch rarityTier {
        case .legendary: glow.glowWidth = 2.5
        case .epic: glow.glowWidth = 1.5
        default: glow.glowWidth = 0
        }
        container.addChild(glow)

        // Layer 3.5: Rarity ring (colored outline around base)
        let rarityRing = createRarityRing(rarity: rarityTier)
        rarityRing.name = "rarityRing"
        rarityRing.zPosition = -0.5
        container.addChild(rarityRing)

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

        // Level indicators (show tower level 1-10)
        let levelIndicator = createLevelIndicator(level: level, archetype: archetype, color: color)
        levelIndicator.name = "levelIndicator"
        levelIndicator.position = CGPoint(x: 0, y: -24)
        levelIndicator.zPosition = 4
        container.addChild(levelIndicator)

        // NOTE: Range indicator, cooldown arc, and LOD detail are created lazily
        // on first access in TDGameScene+EntityVisuals.swift to save ~6 nodes per tower.
        // Muzzle flash is kept here because it's attached to barrel and used frequently.

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
        glow.glowWidth = 0  // Disabled for performance (GPU Gaussian blur)
        glow.blendMode = .add
        container.addChild(glow)

        // Add subtle rotating ring for epic+ rarity
        if rarity.rawValue >= RarityTier.epic.rawValue {
            let ring = SKShapeNode(circleOfRadius: baseRadius - 2)
            ring.fillColor = .clear
            ring.strokeColor = color.withAlphaComponent(0.1)
            ring.lineWidth = 1
            ring.glowWidth = 0
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
        glow.glowWidth = 0
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
        glow.glowWidth = 0
        glow.blendMode = .add
        container.addChild(glow)

        // Bright center highlight
        let highlight = SKShapeNode(circleOfRadius: 4)
        highlight.fillColor = UIColor.white.withAlphaComponent(0.8)
        highlight.strokeColor = .clear
        highlight.glowWidth = 0
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
        spike.glowWidth = 0
        spike.position = CGPoint(x: 0, y: 8)
        barrel.addChild(spike)

        // Ice crystal tip
        let tip = SKShapeNode(circleOfRadius: 4)
        tip.fillColor = .cyan
        tip.strokeColor = .white
        tip.lineWidth = 1
        tip.glowWidth = 0
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
        orb.glowWidth = 0
        orb.blendMode = .add
        orb.position = CGPoint(x: 0, y: 18)
        orb.name = "emitterOrb"
        barrel.addChild(orb)

        // Energy trail
        let trail = SKShapeNode(rectOf: CGSize(width: 2, height: 12), cornerRadius: 1)
        trail.fillColor = color.withAlphaComponent(0.5)
        trail.strokeColor = .clear
        trail.glowWidth = 0
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
        lens.glowWidth = 0
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
        antenna.glowWidth = 0
        antenna.position = CGPoint(x: 0, y: 11)
        barrel.addChild(antenna)

        // Top sphere
        let sphere = SKShapeNode(circleOfRadius: 5)
        sphere.fillColor = .cyan
        sphere.strokeColor = .white
        sphere.lineWidth = 1
        sphere.glowWidth = 0
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
        beam.glowWidth = 0
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
            emitter.glowWidth = 0
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
        glitch.glowWidth = 0
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
        flash.glowWidth = 0
        flash.blendMode = .add
        container.addChild(flash)

        // Outer ring
        let ring = SKShapeNode(circleOfRadius: 14)
        ring.fillColor = .clear
        ring.strokeColor = color
        ring.lineWidth = 2
        ring.glowWidth = 0
        ring.blendMode = .add
        container.addChild(ring)

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
