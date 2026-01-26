import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Design System
// Native iOS design system for Legendary Survivors
// Following progressive disclosure principles

// MARK: - Color Palette

enum DesignColors {
    // Core backgrounds
    static let background = Color(hex: "0a0a0f") ?? Color.black        // Primary dark background
    static let surface = Color(hex: "1a1a24") ?? Color(white: 0.1)     // Cards, panels, elevated surfaces

    // Primary actions
    static let primary = Color(hex: "00d4ff") ?? Color.cyan           // Cyan - primary actions, highlights
    static let secondary = Color(hex: "8b5cf6") ?? Color.purple       // Purple - TD mode accent, magic effects

    // Semantic colors
    static let success = Color(hex: "22c55e") ?? Color.green          // Green - valid, health, Survivor mode
    static let warning = Color(hex: "f59e0b") ?? Color.orange         // Amber - gold, caution, legendary
    static let danger = Color(hex: "ef4444") ?? Color.red             // Red - damage, invalid, critical
    static let muted = Color(hex: "4a4a5a") ?? Color.gray             // Disabled, inactive, subtle

    // UIKit versions for SpriteKit
    static let backgroundUI = UIColor(hex: "0a0a0f") ?? .black
    static let surfaceUI = UIColor(hex: "1a1a24") ?? .darkGray
    static let primaryUI = UIColor(hex: "00d4ff") ?? .cyan
    static let secondaryUI = UIColor(hex: "8b5cf6") ?? .purple
    static let successUI = UIColor(hex: "22c55e") ?? .green
    static let warningUI = UIColor(hex: "f59e0b") ?? .orange
    static let dangerUI = UIColor(hex: "ef4444") ?? .red
    static let mutedUI = UIColor(hex: "4a4a5a") ?? .gray

    // Path colors
    static let pathFillLight = Color(hex: "d4a574") ?? Color.brown    // Tan light
    static let pathFillDark = Color(hex: "c4956a") ?? Color.brown     // Tan dark
    static let pathBorder = Color(hex: "8b6914") ?? Color.brown       // Darker outline

    static let pathFillLightUI = UIColor(hex: "d4a574") ?? .brown
    static let pathFillDarkUI = UIColor(hex: "c4956a") ?? .brown
    static let pathBorderUI = UIColor(hex: "8b6914") ?? .brown
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

// MARK: - Typography

enum DesignTypography {
    // Display - 32-48pt (titles)
    static func display(_ size: CGFloat = 36) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    // Headline - 18-24pt (section headers)
    static func headline(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    // Body - 14-16pt (content)
    static func body(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    // Caption - 11-12pt (secondary info)
    static func caption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .regular, design: .default)
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
// Note: Using the init?(hex:) from TDMapSelectView.swift for SwiftUI Colors
// For UIKit UIColor hex init, see TDGameScene.swift

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

// MARK: - SpriteKit Helpers

enum SpriteKitDesign {
    /// Create a grid dot node for placement mode
    static func createGridDot(at position: CGPoint) -> SKShapeNode {
        let dot = SKShapeNode(circleOfRadius: DesignLayout.gridDotSize / 2)
        dot.fillColor = DesignColors.mutedUI.withAlphaComponent(DesignLayout.gridDotOpacity)
        dot.strokeColor = .clear
        dot.position = position
        dot.zPosition = 1
        return dot
    }

    /// Create active slot highlight with glow
    static func createActiveSlotHighlight() -> SKShapeNode {
        let highlight = SKShapeNode(circleOfRadius: 20)
        highlight.fillColor = DesignColors.primaryUI.withAlphaComponent(0.2)
        highlight.strokeColor = DesignColors.primaryUI
        highlight.lineWidth = 3
        highlight.glowWidth = 8
        return highlight
    }

    /// Create path chevron for direction indication
    static func createPathChevron() -> SKShapeNode {
        let path = UIBezierPath()
        let size: CGFloat = 12
        path.move(to: CGPoint(x: -size, y: size))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: -size, y: -size))

        let chevron = SKShapeNode(path: path.cgPath)
        chevron.strokeColor = DesignColors.pathBorderUI.withAlphaComponent(0.5)
        chevron.lineWidth = 2
        chevron.lineCap = .round
        return chevron
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
