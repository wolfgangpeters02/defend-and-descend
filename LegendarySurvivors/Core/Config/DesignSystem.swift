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

    // Circuit trace colors (paths in TD mode)
    static let tracePrimary = Color(hex: "00d4ff") ?? Color.cyan      // Main circuit trace - cyan
    static let traceSecondary = Color(hex: "0099cc") ?? Color.cyan    // Darker trace variant
    static let traceBorder = Color(hex: "006688") ?? Color.cyan       // Trace outline
    static let traceGlow = Color(hex: "00d4ff") ?? Color.cyan         // Glow effect color

    static let tracePrimaryUI = UIColor(hex: "00d4ff") ?? .cyan
    static let traceSecondaryUI = UIColor(hex: "0099cc") ?? .cyan
    static let traceBorderUI = UIColor(hex: "006688") ?? .cyan
    static let traceGlowUI = UIColor(hex: "00d4ff") ?? .cyan

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
