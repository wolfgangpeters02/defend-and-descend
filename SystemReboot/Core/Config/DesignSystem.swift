import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Design System
// System: Reboot - Terminal/Circuit Board Visual Theme
// You are an AI protecting a computer system from viruses
// Following progressive disclosure principles

// MARK: - Color Palette

enum DesignColors {
    // Core backgrounds - Dark terminal aesthetic
    static let background = Color(hex: "0a0a0f") ?? Color.black        // Deep black terminal background
    static let surface = Color(hex: "0d1117") ?? Color(white: 0.05)    // Slightly lighter surface
    static let surfaceElevated = Color(hex: "161b22") ?? Color(white: 0.1)  // Cards, panels

    // Primary actions - Cyan circuit traces
    static let primary = Color(hex: "00d4ff") ?? Color.cyan           // Cyan - primary actions, traces
    static let secondary = Color(hex: "8b5cf6") ?? Color.purple       // Purple - secondary accent

    // Semantic colors - System status
    static let success = Color(hex: "22c55e") ?? Color.green          // Green - valid, efficiency good
    static let warning = Color(hex: "f59e0b") ?? Color.orange         // Amber - caution, legendary
    static let danger = Color(hex: "ef4444") ?? Color.red             // Red - virus, damage, critical
    static let muted = Color(hex: "3a3a4a") ?? Color.gray             // Disabled, inactive, grid lines

    // Terminal text colors
    static let textPrimary = Color(hex: "e6edf3") ?? Color.white      // Primary text
    static let textSecondary = Color(hex: "7d8590") ?? Color.gray     // Secondary text
    static let textTerminal = Color(hex: "00ff41") ?? Color.green     // Terminal green text

    // UIKit versions for SpriteKit
    static let backgroundUI = UIColor(hex: "0a0a0f") ?? .black
    static let surfaceUI = UIColor(hex: "0d1117") ?? .darkGray
    static let surfaceElevatedUI = UIColor(hex: "161b22") ?? .darkGray
    static let primaryUI = UIColor(hex: "00d4ff") ?? .cyan
    static let secondaryUI = UIColor(hex: "8b5cf6") ?? .purple
    static let successUI = UIColor(hex: "22c55e") ?? .green
    static let warningUI = UIColor(hex: "f59e0b") ?? .orange
    static let dangerUI = UIColor(hex: "ef4444") ?? .red
    static let mutedUI = UIColor(hex: "3a3a4a") ?? .gray
    static let textTerminalUI = UIColor(hex: "00ff41") ?? .green

    // Circuit trace colors (paths in TD mode) - Copper/Gold aesthetic
    static let tracePrimary = Color(hex: "b87333") ?? Color.orange      // Main circuit trace - copper
    static let traceSecondary = Color(hex: "cd7f32") ?? Color.orange    // Bronze variant
    static let traceBorder = Color(hex: "8b5a2b") ?? Color.brown        // Dark copper outline
    static let traceGlow = Color(hex: "d4a84b") ?? Color.yellow         // Gold glow effect

    static let tracePrimaryUI = UIColor(hex: "b87333") ?? .orange
    static let traceSecondaryUI = UIColor(hex: "cd7f32") ?? .orange
    static let traceBorderUI = UIColor(hex: "8b5a2b") ?? .brown
    static let traceGlowUI = UIColor(hex: "d4a84b") ?? .systemYellow

    // Legacy path colors (kept for compatibility, now mapped to traces)
    static let pathFillLight = tracePrimary
    static let pathFillDark = traceSecondary
    static let pathBorder = traceBorder

    static let pathFillLightUI = tracePrimaryUI
    static let pathFillDarkUI = traceSecondaryUI
    static let pathBorderUI = traceBorderUI

    // Grid colors for circuit board pattern
    static let gridLine = Color(hex: "1a2332") ?? Color.gray          // Subtle grid lines
    static let gridDot = Color(hex: "2a3a4a") ?? Color.gray           // Grid intersection dots
    static let gridLineUI = UIColor(hex: "1a2332") ?? .darkGray
    static let gridDotUI = UIColor(hex: "2a3a4a") ?? .darkGray

    // Enemy tier colors - virus classification (unified color language)
    static let enemyTier1 = Color(hex: "ff4444") ?? Color.red         // Red - basic viruses
    static let enemyTier2 = Color(hex: "ff8800") ?? Color.orange      // Orange - fast threats
    static let enemyTier3 = Color(hex: "8844ff") ?? Color.purple      // Purple - tank threats
    static let enemyTier4 = Color(hex: "ff00ff") ?? Color.pink        // Magenta - elite threats
    static let enemyBoss = Color.white                                // White (with color cycle) - boss

    static let enemyTier1UI = UIColor(hex: "ff4444") ?? .red
    static let enemyTier2UI = UIColor(hex: "ff8800") ?? .orange
    static let enemyTier3UI = UIColor(hex: "8844ff") ?? .purple
    static let enemyTier4UI = UIColor(hex: "ff00ff") ?? .magenta
    static let enemyBossUI = UIColor.white

    /// Get enemy color based on tier (1-4+)
    static func enemyColor(for tier: Int, isBoss: Bool = false) -> UIColor {
        if isBoss {
            return enemyBossUI
        }
        switch tier {
        case 1: return enemyTier1UI
        case 2: return enemyTier2UI
        case 3: return enemyTier3UI
        default: return enemyTier4UI
        }
    }

    // MARK: - Mega-Board Sector Theme Colors

    /// Get color for mega-board sector theme
    static func sectorThemeColor(_ theme: String) -> UIColor {
        switch theme.lowercased() {
        case "ram":
            return primaryUI                    // Cyan - memory module
        case "cpu":
            return tracePrimaryUI               // Copper - processor core
        case "gpu":
            return successUI                    // Green - graphics array
        case "ssd":
            return secondaryUI                  // Purple - storage controller
        case "network":
            return enemyTier2UI                 // Orange - network interface
        case "power":
            return dangerUI                     // Red - power supply
        default:
            return mutedUI                      // Gray - unknown
        }
    }

    /// Get SwiftUI color for mega-board sector theme
    static func sectorThemeSwiftUIColor(_ theme: String) -> Color {
        switch theme.lowercased() {
        case "ram":
            return primary
        case "cpu":
            return tracePrimary
        case "gpu":
            return success
        case "ssd":
            return secondary
        case "network":
            return enemyTier2
        case "power":
            return danger
        default:
            return muted
        }
    }
}

// MARK: - Rarity Colors

enum RarityColors {
    static let common = Color(hex: "9ca3af") ?? Color.gray            // Gray
    static let rare = Color(hex: "3b82f6") ?? Color.blue              // Blue
    static let epic = Color(hex: "a855f7") ?? Color.purple            // Purple
    static let legendary = Color(hex: "f59e0b") ?? Color.orange       // Amber/Gold

    static let commonUI = UIColor(hex: "9ca3af") ?? .gray
    static let rareUI = UIColor(hex: "3b82f6") ?? .blue
    static let epicUI = UIColor(hex: "a855f7") ?? .purple
    static let legendaryUI = UIColor(hex: "f59e0b") ?? .orange

    static func color(for rarity: String) -> Color {
        switch rarity.lowercased() {
        case "common": return common
        case "rare": return rare
        case "epic": return epic
        case "legendary": return legendary
        default: return common
        }
    }

    static func uiColor(for rarity: String) -> UIColor {
        switch rarity.lowercased() {
        case "common": return commonUI
        case "rare": return rareUI
        case "epic": return epicUI
        case "legendary": return legendaryUI
        default: return commonUI
        }
    }

    static func color(for rarity: Rarity) -> Color {
        switch rarity {
        case .common: return common
        case .rare: return rare
        case .epic: return epic
        case .legendary: return legendary
        }
    }

    static func uiColor(for rarity: Rarity) -> UIColor {
        switch rarity {
        case .common: return commonUI
        case .rare: return rareUI
        case .epic: return epicUI
        case .legendary: return legendaryUI
        }
    }
}

// MARK: - Typography (Terminal/Monospace Theme)

enum DesignTypography {
    // Display - 32-48pt (titles) - Bold monospace for system headers
    static func display(_ size: CGFloat = 36) -> Font {
        .system(size: size, weight: .black, design: .monospaced)
    }

    // Headline - 18-24pt (section headers) - Semibold monospace
    static func headline(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }

    // Body - 14-16pt (content) - Regular monospace for readability
    static func body(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }

    // Caption - 11-12pt (secondary info) - Light monospace
    static func caption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }

    // Terminal - Special green terminal text style
    static func terminal(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }

    // Stats - Bold numbers for HUD displays
    static func stats(_ size: CGFloat = 18) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
}

// MARK: - Animations

enum DesignAnimations {
    // Spring animation for buttons, cards
    static let spring = Animation.spring(response: 0.5, dampingFraction: 0.8)

    // Quick state changes
    static let quick = Animation.easeOut(duration: 0.2)

    // Smooth transitions
    static let smooth = Animation.easeInOut(duration: 0.3)

    // Pulse for attention indicators (1.5s repeat)
    static func pulse() -> Animation {
        Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
    }

    // Timing constants for SpriteKit
    enum Timing {
        static let spring: TimeInterval = 0.5
        static let quick: TimeInterval = 0.2
        static let smooth: TimeInterval = 0.3
        static let pulse: TimeInterval = 1.5
    }
}

// MARK: - Layout Constants

enum DesignLayout {
    // Spacing
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 24

    // Corner radius
    static let cornerRadiusSM: CGFloat = 6
    static let cornerRadiusMD: CGFloat = 10
    static let cornerRadiusLG: CGFloat = 16

    // TD-specific
    static let pathWidth: CGFloat = 28                  // Narrower path for TD look
    static let pathBorderWidth: CGFloat = 2             // Path outline thickness
    static let gridDotSize: CGFloat = 8                 // Placement grid dot size
    static let gridDotOpacity: CGFloat = 0.4            // Grid dot opacity
    static let snapDistance: CGFloat = 50               // Tower snap distance
    static let towerPreviewOpacity: CGFloat = 0.7       // Dragged tower opacity
    static let rangeCircleFillOpacity: CGFloat = 0.15   // Range indicator fill
    static let rangeCircleStrokeOpacity: CGFloat = 0.3  // Range indicator stroke

    // Tower deck - larger for touch
    static let towerCardSize: CGFloat = 60
    static let towerDeckHeight: CGFloat = 110
}

// MARK: - TD Placement State

enum TDPlacementState {
    case idle                           // Clean map, no grid visible
    case dragging(weaponType: String)   // Grid visible, showing preview
    case placed                         // Brief placement animation
}

// MARK: - Color Extension for Hex

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - View Modifiers

extension View {
    /// Apply standard card styling
    func cardStyle() -> some View {
        self
            .background(DesignColors.surface)
            .cornerRadius(DesignLayout.cornerRadiusMD)
    }

    /// Apply rarity glow effect
    func rarityGlow(_ rarity: String) -> some View {
        self.shadow(color: RarityColors.color(for: rarity).opacity(0.5), radius: 8)
    }

    /// Standard button press effect
    func pressEffect(_ isPressed: Bool) -> some View {
        self
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(DesignAnimations.quick, value: isPressed)
    }
}

// MARK: - SpriteKit Helpers (Circuit Board Theme)

enum SpriteKitDesign {
    /// Create a grid dot node for placement mode (circuit board style)
    static func createGridDot(at position: CGPoint) -> SKShapeNode {
        let dot = SKShapeNode(circleOfRadius: DesignLayout.gridDotSize / 2)
        dot.fillColor = DesignColors.gridDotUI.withAlphaComponent(DesignLayout.gridDotOpacity)
        dot.strokeColor = .clear
        dot.position = position
        dot.zPosition = 1
        return dot
    }

    /// Create active slot highlight with cyan glow (circuit node style)
    static func createActiveSlotHighlight() -> SKShapeNode {
        let highlight = SKShapeNode(circleOfRadius: 20)
        highlight.fillColor = DesignColors.primaryUI.withAlphaComponent(0.15)
        highlight.strokeColor = DesignColors.primaryUI
        highlight.lineWidth = 2
        highlight.glowWidth = 10
        return highlight
    }

    /// Create path chevron for direction indication (data flow arrows)
    static func createPathChevron() -> SKShapeNode {
        let path = UIBezierPath()
        let size: CGFloat = 10
        path.move(to: CGPoint(x: -size, y: size * 0.6))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: -size, y: -size * 0.6))

        let chevron = SKShapeNode(path: path.cgPath)
        chevron.strokeColor = DesignColors.traceBorderUI.withAlphaComponent(0.6)
        chevron.lineWidth = 2
        chevron.lineCap = .round
        return chevron
    }

    /// Create circuit board grid pattern for background
    static func createCircuitGridNode(size: CGSize, gridSpacing: CGFloat = 40) -> SKNode {
        let container = SKNode()

        // Horizontal lines
        var y: CGFloat = 0
        while y < size.height {
            let line = SKShapeNode()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            line.path = path.cgPath
            line.strokeColor = DesignColors.gridLineUI
            line.lineWidth = 0.5
            line.alpha = 0.3
            container.addChild(line)
            y += gridSpacing
        }

        // Vertical lines
        var x: CGFloat = 0
        while x < size.width {
            let line = SKShapeNode()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            line.path = path.cgPath
            line.strokeColor = DesignColors.gridLineUI
            line.lineWidth = 0.5
            line.alpha = 0.3
            container.addChild(line)
            x += gridSpacing
        }

        // Junction dots at intersections
        y = 0
        while y < size.height {
            x = 0
            while x < size.width {
                let dot = SKShapeNode(circleOfRadius: 1.5)
                dot.position = CGPoint(x: x, y: y)
                dot.fillColor = DesignColors.gridDotUI
                dot.strokeColor = .clear
                dot.alpha = 0.4
                container.addChild(dot)
                x += gridSpacing
            }
            y += gridSpacing
        }

        return container
    }

    /// Create scan line effect overlay (for active/alert states)
    static func createScanLineEffect(size: CGSize) -> SKNode {
        let container = SKNode()
        let lineSpacing: CGFloat = 3

        var y: CGFloat = 0
        while y < size.height {
            let line = SKShapeNode()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            line.path = path.cgPath
            line.strokeColor = UIColor.black.withAlphaComponent(0.15)
            line.lineWidth = 1
            container.addChild(line)
            y += lineSpacing
        }

        return container
    }

    /// Create circuit trace path (glowing cyan line)
    static func createCircuitTrace(from: CGPoint, to: CGPoint, width: CGFloat = 4) -> SKShapeNode {
        let path = UIBezierPath()
        path.move(to: from)
        path.addLine(to: to)

        let trace = SKShapeNode(path: path.cgPath)
        trace.strokeColor = DesignColors.tracePrimaryUI
        trace.lineWidth = width
        trace.lineCap = .round
        trace.glowWidth = width * 0.5
        return trace
    }

    /// Create virus/enemy node (red hostile indicator)
    static func createVirusIndicator(size: CGFloat = 20) -> SKShapeNode {
        // Hexagonal virus shape
        let path = UIBezierPath()
        let radius = size / 2
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 6
            let point = CGPoint(x: radius * cos(angle), y: radius * sin(angle))
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.close()

        let virus = SKShapeNode(path: path.cgPath)
        virus.fillColor = DesignColors.dangerUI.withAlphaComponent(0.8)
        virus.strokeColor = DesignColors.dangerUI
        virus.lineWidth = 2
        virus.glowWidth = 4
        return virus
    }
}

// MARK: - Tower Visual Colors

enum TowerColors {
    // MARK: - Archetype Base Colors

    /// Projectile towers (Bow, TraceRoute, KernelPulse) - Precision cyan
    static let projectile = UIColor(hex: "00d4ff") ?? .cyan
    static let projectileAccent = UIColor(hex: "67e8f9") ?? .cyan

    /// Artillery towers (Cannon, Bomb, BurstProtocol) - Industrial orange/gray
    static let artillery = UIColor(hex: "f97316") ?? .orange
    static let artilleryAccent = UIColor(hex: "94a3b8") ?? .gray

    /// Frost towers (IceShard) - Ice blue/cyan
    static let frost = UIColor(hex: "06b6d4") ?? .cyan
    static let frostAccent = UIColor(hex: "a5f3fc") ?? .white

    /// Magic towers (Staff, Wand) - Arcane purple
    static let magic = UIColor(hex: "a855f7") ?? .purple
    static let magicAccent = UIColor(hex: "e879f9") ?? .magenta

    /// Beam towers (Laser, RootAccess) - Tech red/orange
    static let beam = UIColor(hex: "ef4444") ?? .red
    static let beamAccent = UIColor(hex: "fca5a5") ?? .systemPink

    /// Tesla towers (Lightning, Overflow) - Electric cyan/white
    static let tesla = UIColor(hex: "22d3ee") ?? .cyan
    static let teslaAccent = UIColor.white

    /// Pyro towers (Flamethrower) - Fire orange/red
    static let pyro = UIColor(hex: "f97316") ?? .orange
    static let pyroAccent = UIColor(hex: "fbbf24") ?? .yellow

    /// Legendary towers (Excalibur) - Divine gold
    static let legendary = UIColor(hex: "f59e0b") ?? .orange
    static let legendaryAccent = UIColor(hex: "fbbf24") ?? .yellow

    /// Multishot towers (ForkBomb) - Tech purple
    static let multishot = UIColor(hex: "8b5cf6") ?? .purple
    static let multishotAccent = UIColor(hex: "c4b5fd") ?? .systemIndigo

    /// Execute towers (NullPointer) - Error red
    static let execute = UIColor(hex: "ef4444") ?? .red
    static let executeAccent = UIColor(hex: "fecaca") ?? .systemPink

    // MARK: - Get Color for Weapon Type

    static func color(for weaponType: String) -> UIColor {
        switch weaponType.lowercased() {
        case "bow", "crossbow", "trace_route", "kernel_pulse":
            return projectile
        case "cannon", "bomb", "burst_protocol":
            return artillery
        case "ice_shard", "snowflake":
            return frost
        case "staff", "wand":
            return magic
        case "laser", "root_access":
            return beam
        case "lightning", "overflow":
            return tesla
        case "flamethrower":
            return pyro
        case "excalibur", "sword", "katana":
            return legendary
        case "fork_bomb":
            return multishot
        case "null_pointer":
            return execute
        default:
            return projectile
        }
    }

    static func accentColor(for weaponType: String) -> UIColor {
        switch weaponType.lowercased() {
        case "bow", "crossbow", "trace_route", "kernel_pulse":
            return projectileAccent
        case "cannon", "bomb", "burst_protocol":
            return artilleryAccent
        case "ice_shard", "snowflake":
            return frostAccent
        case "staff", "wand":
            return magicAccent
        case "laser", "root_access":
            return beamAccent
        case "lightning", "overflow":
            return teslaAccent
        case "flamethrower":
            return pyroAccent
        case "excalibur", "sword", "katana":
            return legendaryAccent
        case "fork_bomb":
            return multishotAccent
        case "null_pointer":
            return executeAccent
        default:
            return projectileAccent
        }
    }
}

// MARK: - Tower Effect Constants

enum TowerEffects {
    // Glow intensities by rarity
    static let commonGlow: CGFloat = 4
    static let rareGlow: CGFloat = 6
    static let epicGlow: CGFloat = 8
    static let legendaryGlow: CGFloat = 12

    // Animation durations
    static let idlePulseDuration: TimeInterval = 1.8
    static let targetingLockDuration: TimeInterval = 0.15
    static let muzzleFlashDuration: TimeInterval = 0.12
    static let recoilDuration: TimeInterval = 0.2

    // Particle counts
    static let frostParticleRate: TimeInterval = 0.3
    static let divineParticleRate: TimeInterval = 0.2
    static let electricArcRate: TimeInterval = 0.4

    // Size multipliers by merge level
    static func sizeMultiplier(for mergeLevel: Int) -> CGFloat {
        switch mergeLevel {
        case 1: return 1.0
        case 2: return 1.1
        case 3: return 1.2
        default: return 1.0
        }
    }

    // Glow multiplier by rarity
    static func glowMultiplier(for rarity: String) -> CGFloat {
        switch rarity.lowercased() {
        case "common": return 1.0
        case "rare": return 1.25
        case "epic": return 1.5
        case "legendary": return 2.0
        default: return 1.0
        }
    }
}

// MARK: - Shared UI Helpers

enum DesignHelpers {
    /// Format seconds as "M:SS" time string
    static func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    /// Color for boss difficulty level
    static func difficultyColor(_ difficulty: BossDifficulty) -> Color {
        switch difficulty {
        case .easy: return .green
        case .normal: return .blue
        case .hard: return .orange
        case .nightmare: return .red
        }
    }

    /// SF Symbol name for a weapon/protocol type
    static func iconForWeapon(_ weaponType: String) -> String {
        switch weaponType.lowercased() {
        case "bow", "crossbow":
            return "scope"
        case "trace_route":
            return "scope"
        case "kernel_pulse":
            return "dot.circle.and.hand.point.up.left.fill"
        case "wand", "staff":
            return "wand.and.stars"
        case "cannon":
            return "cylinder.split.1x2.fill"
        case "bomb":
            return "burst.fill"
        case "burst_protocol":
            return "burst.fill"
        case "ice_shard", "snowflake":
            return "snowflake"
        case "laser":
            return "rays"
        case "root_access":
            return "terminal.fill"
        case "lightning", "overflow":
            return "bolt.horizontal.fill"
        case "flamethrower":
            return "flame.fill"
        case "excalibur", "sword", "katana":
            return "sparkle"
        case "fork_bomb":
            return "arrow.triangle.branch"
        case "null_pointer":
            return "exclamationmark.triangle.fill"
        default:
            return "square.fill"
        }
    }

    /// Color for weapon/protocol archetype
    static func archetypeColor(for id: String) -> Color {
        switch id.lowercased() {
        case "bow", "crossbow", "trace_route", "kernel_pulse":
            return Color(hex: "00d4ff") ?? .cyan
        case "cannon", "bomb", "burst_protocol", "flamethrower":
            return Color(hex: "f97316") ?? .orange
        case "ice_shard", "snowflake":
            return Color(hex: "06b6d4") ?? .cyan
        case "staff", "wand":
            return Color(hex: "a855f7") ?? .purple
        case "laser", "root_access", "null_pointer":
            return Color(hex: "ef4444") ?? .red
        case "lightning", "overflow":
            return Color(hex: "22d3ee") ?? .cyan
        case "excalibur", "sword", "katana":
            return Color(hex: "f59e0b") ?? .orange
        case "fork_bomb":
            return Color(hex: "8b5cf6") ?? .purple
        default:
            return .cyan
        }
    }
}

// MARK: - SKShapeNode Extension

import SpriteKit

extension SKShapeNode {
    /// Fade in with quick animation
    func fadeInQuick() {
        self.alpha = 0
        self.run(SKAction.fadeIn(withDuration: DesignAnimations.Timing.quick))
    }

    /// Fade out and remove
    func fadeOutAndRemove() {
        self.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: DesignAnimations.Timing.quick),
            SKAction.removeFromParent()
        ]))
    }

    /// Pulse animation for attention
    func startPulse() {
        let scaleUp = SKAction.scale(to: 1.1, duration: 0.75)
        let scaleDown = SKAction.scale(to: 0.9, duration: 0.75)
        let pulse = SKAction.sequence([scaleUp, scaleDown])
        self.run(SKAction.repeatForever(pulse), withKey: "pulse")
    }

    /// Stop pulse animation
    func stopPulse() {
        self.removeAction(forKey: "pulse")
        self.run(SKAction.scale(to: 1.0, duration: 0.1))
    }
}
