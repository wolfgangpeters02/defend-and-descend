import SpriteKit
import CoreGraphics

// MARK: - Scrolling Combat Text System
// Shows floating damage numbers, healing, critical hits, and status effects

enum SCTType {
    case damage              // White, standard damage
    case critical            // Yellow/orange, larger, critical hit
    case healing             // Green, health restored
    case shield              // Cyan, shield/armor absorbed
    case freeze              // Light blue, slow/freeze applied
    case burn                // Orange, damage over time
    case chain               // Electric blue, chain lightning
    case execute             // Red, execute/instant kill
    case xp                  // Purple, XP gained
    case currency            // Gold, currency/hash gained
    case miss                // Gray, missed/dodged
    case levelUp             // Rainbow/golden, level up
    case immune              // Purple/magenta, immune to damage

    var color: UIColor {
        switch self {
        case .damage:   return UIColor.white
        case .critical: return UIColor(hex: "ffaa00") ?? .orange
        case .healing:  return UIColor(hex: "22c55e") ?? .green
        case .shield:   return UIColor(hex: "06b6d4") ?? .cyan
        case .freeze:   return UIColor(hex: "7dd3fc") ?? .cyan
        case .burn:     return UIColor(hex: "f97316") ?? .orange
        case .chain:    return UIColor(hex: "22d3ee") ?? .cyan
        case .execute:  return UIColor(hex: "ef4444") ?? .red
        case .xp:       return UIColor(hex: "a855f7") ?? .purple
        case .currency: return UIColor(hex: "fbbf24") ?? .yellow
        case .miss:     return UIColor(hex: "9eaab6") ?? .gray
        case .levelUp:  return UIColor(hex: "fbbf24") ?? .yellow
        case .immune:   return UIColor(hex: "d946ef") ?? .magenta
        }
    }

    var glowColor: UIColor {
        switch self {
        case .critical: return UIColor(hex: "ff6600") ?? .orange
        case .execute:  return UIColor(hex: "ff0000") ?? .red
        case .levelUp:  return UIColor(hex: "ffffff") ?? .white
        case .healing:  return UIColor(hex: "00ff00") ?? .green
        case .immune:   return UIColor(hex: "a855f7") ?? .purple
        default:        return color.withAlphaComponent(0.5)
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .critical, .execute, .levelUp: return 18
        case .damage, .healing, .shield:    return 14
        case .immune:                       return 16
        case .xp, .currency:                return 12
        default:                            return 13
        }
    }

    var fontWeight: UIFont.Weight {
        switch self {
        case .critical, .execute, .levelUp: return .heavy
        case .damage, .healing:             return .bold
        case .immune:                       return .heavy
        default:                            return .semibold
        }
    }

    var hasGlow: Bool {
        switch self {
        case .critical, .execute, .levelUp, .healing, .immune: return true
        default: return false
        }
    }

    var prefix: String {
        switch self {
        case .healing:  return "+"
        case .xp:       return "+XP "
        case .currency: return "+"
        case .miss:     return ""
        default:        return ""
        }
    }

    var suffix: String {
        switch self {
        case .currency: return " H"  // Hash currency
        default:        return ""
        }
    }
}

// MARK: - SCT Configuration

struct SCTConfig {
    var duration: TimeInterval = 0.8
    var riseDistance: CGFloat = 40
    var spreadRange: CGFloat = 25        // Random horizontal spread (11e: widened from 15 to reduce AoE clustering)
    var fadeStart: CGFloat = 0.6         // When to start fading (0-1)
    var scaleUp: CGFloat = 1.2           // Initial scale for emphasis
    var scaleDown: CGFloat = 0.8         // Final scale
    var zPosition: CGFloat = 1000        // Above most game elements

    static let standard = SCTConfig()

    static let quick = SCTConfig(
        duration: 0.5,
        riseDistance: 25,
        spreadRange: 10
    )

    static let dramatic = SCTConfig(
        duration: 1.2,
        riseDistance: 60,
        spreadRange: 20,
        scaleUp: 1.5
    )
}

// MARK: - Scrolling Combat Text Manager

class ScrollingCombatTextManager {

    weak var scene: SKScene?
    private var config: SCTConfig
    private var activeTexts: [SKNode] = []
    private let maxActiveTexts = 20  // Prevent performance issues during heavy combat

    init(scene: SKScene, config: SCTConfig = .standard) {
        self.scene = scene
        self.config = config
    }

    // MARK: - Public Methods

    /// Show damage number at position
    func showDamage(_ damage: Int, at position: CGPoint, isCritical: Bool = false) {
        let type: SCTType = isCritical ? .critical : .damage
        let text = isCritical ? "\(damage)!" : "\(damage)"
        spawn(text: text, type: type, at: position)
    }

    /// Show healing number at position
    func showHealing(_ amount: Int, at position: CGPoint) {
        spawn(text: "+\(amount)", type: .healing, at: position)
    }

    /// Show XP gain
    func showXP(_ amount: Int, at position: CGPoint) {
        spawn(text: "+\(amount) XP", type: .xp, at: position)
    }

    /// Show currency/hash gain
    func showCurrency(_ amount: Int, at position: CGPoint) {
        spawn(text: "+\(amount) H", type: .currency, at: position)
    }

    /// Show status effect text
    func showStatus(_ text: String, type: SCTType, at position: CGPoint) {
        spawn(text: text, type: type, at: position)
    }

    /// Show miss/dodge
    func showMiss(at position: CGPoint) {
        spawn(text: "MISS", type: .miss, at: position)
    }

    /// Show execute/instant kill
    func showExecute(at position: CGPoint) {
        spawn(text: "EXECUTE!", type: .execute, at: position, config: .dramatic)
    }

    /// Show level up
    func showLevelUp(at position: CGPoint) {
        spawn(text: "LEVEL UP!", type: .levelUp, at: position, config: .dramatic)
    }

    /// Show chain lightning hit
    func showChain(_ damage: Int, at position: CGPoint) {
        spawn(text: "\(damage)", type: .chain, at: position, config: .quick)
    }

    /// Show freeze/slow applied
    func showFreeze(at position: CGPoint) {
        spawn(text: "FROZEN", type: .freeze, at: position)
    }

    /// Show burn damage
    func showBurn(_ damage: Int, at position: CGPoint) {
        spawn(text: "\(damage)", type: .burn, at: position, config: .quick)
    }

    /// Show generic text with custom type and optional config
    func show(_ text: String, type: SCTType, at position: CGPoint, config: SCTConfig? = nil) {
        spawn(text: text, type: type, at: position, config: config)
    }

    /// Batch show multiple damage numbers (for AoE attacks)
    /// 11e: Throttles to max 5 entries per burst (largest hits first), with increased spatial jitter
    func showDamageBatch(_ damages: [(damage: Int, position: CGPoint, isCritical: Bool)]) {
        guard let scene = scene else { return }
        // Sort by damage descending, cap at 5 to prevent cluster overlap
        let sorted = damages.sorted { $0.damage > $1.damage }
        let capped = Array(sorted.prefix(5))

        for (index, info) in capped.enumerated() {
            let delay = Double(index) * 0.05
            let stagger = SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.run { [weak self] in
                    self?.showDamage(info.damage, at: info.position, isCritical: info.isCritical)
                }
            ])
            scene.run(stagger)
        }
    }

    // MARK: - Private Methods

    private func spawn(text: String, type: SCTType, at position: CGPoint, config: SCTConfig? = nil) {
        guard let scene = scene else { return }

        // Cleanup old texts if needed
        cleanupIfNeeded()

        let cfg = config ?? self.config

        // Create the text node
        let textNode = createTextNode(text: text, type: type)

        // Random horizontal offset for variety
        let xOffset = CGFloat.random(in: -cfg.spreadRange...cfg.spreadRange)
        textNode.position = CGPoint(x: position.x + xOffset, y: position.y)
        textNode.zPosition = cfg.zPosition

        // Initial scale for pop effect
        textNode.setScale(0.5)

        scene.addChild(textNode)
        activeTexts.append(textNode)

        // Animate
        animateText(textNode, type: type, config: cfg)
    }

    private func createTextNode(text: String, type: SCTType) -> SKNode {
        let container = SKNode()

        // Main text label
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = type.fontSize
        label.fontColor = type.color
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center

        // Add glow effect for important types
        if type.hasGlow {
            let glow = SKLabelNode(fontNamed: "Menlo-Bold")
            glow.text = text
            glow.fontSize = type.fontSize
            glow.fontColor = type.glowColor
            glow.verticalAlignmentMode = .center
            glow.horizontalAlignmentMode = .center
            glow.alpha = 0.6
            glow.setScale(1.15)
            glow.zPosition = -1

            // Add blur effect via multiple offset copies
            for offset in [CGPoint(x: -1, y: 0), CGPoint(x: 1, y: 0),
                          CGPoint(x: 0, y: -1), CGPoint(x: 0, y: 1)] {
                let glowCopy = glow.copy() as! SKLabelNode
                glowCopy.position = offset
                glowCopy.alpha = 0.3
                container.addChild(glowCopy)
            }

            container.addChild(glow)
        }

        // Add shadow for readability
        let shadow = SKLabelNode(fontNamed: "Menlo-Bold")
        shadow.text = text
        shadow.fontSize = type.fontSize
        shadow.fontColor = UIColor.black.withAlphaComponent(0.5)
        shadow.verticalAlignmentMode = .center
        shadow.horizontalAlignmentMode = .center
        shadow.position = CGPoint(x: 1, y: -1)
        shadow.zPosition = -2
        container.addChild(shadow)

        container.addChild(label)

        return container
    }

    private func animateText(_ node: SKNode, type: SCTType, config: SCTConfig) {
        // Pop in
        let scaleUp = SKAction.scale(to: config.scaleUp, duration: 0.1)
        scaleUp.timingMode = .easeOut

        // Settle to normal
        let scaleNormal = SKAction.scale(to: 1.0, duration: 0.1)
        scaleNormal.timingMode = .easeInEaseOut

        // Rise up
        let riseAction = SKAction.moveBy(x: 0, y: config.riseDistance, duration: config.duration)
        riseAction.timingMode = .easeOut

        // Fade out (starts after fadeStart percentage of duration)
        let fadeDelay = SKAction.wait(forDuration: config.duration * Double(config.fadeStart))
        let fadeOut = SKAction.fadeOut(withDuration: config.duration * Double(1.0 - config.fadeStart))
        let fadeSequence = SKAction.sequence([fadeDelay, fadeOut])

        // Slight scale down at end
        let scaleDelay = SKAction.wait(forDuration: config.duration * 0.5)
        let scaleDown = SKAction.scale(to: config.scaleDown, duration: config.duration * 0.5)
        let scaleSequence = SKAction.sequence([scaleDelay, scaleDown])

        // Combine animations
        let popIn = SKAction.sequence([scaleUp, scaleNormal])
        let mainAnimation = SKAction.group([riseAction, fadeSequence, scaleSequence])
        let fullAnimation = SKAction.sequence([popIn, mainAnimation])

        // Add slight wobble for critical/execute
        if type == .critical || type == .execute || type == .levelUp {
            let wobble = SKAction.sequence([
                SKAction.rotate(byAngle: 0.05, duration: 0.05),
                SKAction.rotate(byAngle: -0.1, duration: 0.1),
                SKAction.rotate(byAngle: 0.05, duration: 0.05)
            ])
            node.run(wobble)
        }

        // Run animation and remove when done
        node.run(fullAnimation) { [weak self, weak node] in
            node?.removeFromParent()
            if let node = node {
                self?.activeTexts.removeAll { $0 === node }
            }
        }
    }

    private func cleanupIfNeeded() {
        // Remove oldest texts if we have too many
        while activeTexts.count >= maxActiveTexts {
            if let oldest = activeTexts.first {
                oldest.removeAllActions()
                oldest.removeFromParent()
                activeTexts.removeFirst()
            }
        }

        // Clean up detached nodes in-place
        var w = 0
        for idx in 0..<activeTexts.count {
            if activeTexts[idx].parent != nil {
                activeTexts[w] = activeTexts[idx]
                w += 1
            }
        }
        if w < activeTexts.count {
            activeTexts.removeSubrange(w..<activeTexts.count)
        }
    }

    /// Clear all active combat text
    func clearAll() {
        for text in activeTexts {
            text.removeFromParent()
        }
        activeTexts.removeAll()
    }
}

// MARK: - SKScene Extension for Easy Access

extension SKScene {

    private static var sctManagerKey = "ScrollingCombatTextManager"

    /// Get or create the SCT manager for this scene
    var combatText: ScrollingCombatTextManager {
        if let manager = objc_getAssociatedObject(self, &SKScene.sctManagerKey) as? ScrollingCombatTextManager {
            return manager
        }
        let manager = ScrollingCombatTextManager(scene: self)
        objc_setAssociatedObject(self, &SKScene.sctManagerKey, manager, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return manager
    }

    /// Initialize SCT with custom config
    func setupCombatText(config: SCTConfig = .standard) {
        let manager = ScrollingCombatTextManager(scene: self, config: config)
        objc_setAssociatedObject(self, &SKScene.sctManagerKey, manager, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
