import SwiftUI
import SpriteKit

// MARK: - Tower Deck Card (Large Touch-Friendly)
// Extracted from TDGameContainerView.swift for maintainability

struct TowerDeckCard: View {
    let weapon: WeaponConfig
    let gold: Int
    let onDragStart: () -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: () -> Void

    @State private var isDragging = false
    @State private var pulseAnimation = false

    private var cost: Int {
        TowerSystem.towerPlacementCost(rarity: Rarity(rawValue: weapon.rarity) ?? .common)
    }

    private var canAfford: Bool {
        gold >= cost
    }

    private var rarityColor: Color {
        RarityColors.color(for: weapon.rarity)
    }

    private var archetypeColor: Color {
        DesignHelpers.archetypeColor(for: weapon.id)
    }

    var body: some View {
        VStack(spacing: 4) {
            // Enhanced tower icon with archetype styling
            ZStack {
                // Outer glow layer (for epic/legendary)
                if weapon.rarity.lowercased() == "legendary" || weapon.rarity.lowercased() == "epic" {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(rarityColor.opacity(0.2))
                        .frame(width: 64, height: 64)
                        .blur(radius: 4)
                        .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                }

                // Main card background
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                archetypeColor.opacity(canAfford ? 0.4 : 0.15),
                                rarityColor.opacity(canAfford ? 0.3 : 0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)

                // Circuit pattern overlay
                TowerCardCircuitPattern()
                    .stroke(archetypeColor.opacity(0.2), lineWidth: 0.5)
                    .frame(width: 56, height: 56)
                    .clipped()

                // Weapon type icon with archetype styling
                ZStack {
                    // Icon glow
                    Image(systemName: iconForWeapon(weapon.id))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(archetypeColor.opacity(0.5))
                        .blur(radius: 4)

                    // Main icon
                    Image(systemName: iconForWeapon(weapon.id))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(canAfford ? .white : .gray)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                rarityColor.opacity(canAfford ? 1 : 0.4),
                                archetypeColor.opacity(canAfford ? 0.7 : 0.3)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
            )
            .overlay(
                // Rarity indicator corners
                RarityCorners(rarity: weapon.rarity, color: rarityColor)
                    .opacity(canAfford ? 1 : 0.4)
            )
            .scaleEffect(isDragging ? 0.85 : 1.0)
            .shadow(color: canAfford ? archetypeColor.opacity(0.4) : .clear, radius: 6)

            // Cost label with enhanced styling
            HStack(spacing: 3) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.system(size: 11))
                Text("\(cost)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
            }
            .foregroundColor(canAfford ? .yellow : .red)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.5))
            .cornerRadius(4)
        }
        .opacity(canAfford ? 1.0 : 0.5)
        .animation(.easeOut(duration: 0.15), value: isDragging)
        .onAppear {
            if weapon.rarity.lowercased() == "legendary" {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .named("gameArea"))
                .onChanged { value in
                    if canAfford {
                        if !isDragging {
                            // Only start drag when pulling upward (toward the board)
                            let translation = value.translation
                            guard -translation.height > abs(translation.width) else { return }
                            isDragging = true
                            onDragStart()
                        }
                        onDragChanged(value)
                    }
                }
                .onEnded { _ in
                    if isDragging {
                        isDragging = false
                        onDragEnded()
                    }
                }
        )
    }

    private func iconForWeapon(_ weaponType: String) -> String {
        DesignHelpers.iconForWeapon(weaponType)
    }
}

// MARK: - Tower Card Circuit Pattern

struct TowerCardCircuitPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 12

        // Horizontal traces
        for y in stride(from: step, to: rect.height, by: step * 2) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width * 0.3, y: y))

            path.move(to: CGPoint(x: rect.width * 0.7, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }

        // Vertical traces
        for x in stride(from: step, to: rect.width, by: step * 2) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height * 0.25))

            path.move(to: CGPoint(x: x, y: rect.height * 0.75))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }

        return path
    }
}

// MARK: - Rarity Corner Indicators

struct RarityCorners: View {
    let rarity: String
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let cornerSize: CGFloat = rarity.lowercased() == "legendary" ? 8 : 6

            // Top-left corner
            Path { path in
                path.move(to: CGPoint(x: 2, y: cornerSize + 2))
                path.addLine(to: CGPoint(x: 2, y: 2))
                path.addLine(to: CGPoint(x: cornerSize + 2, y: 2))
            }
            .stroke(color, lineWidth: 2)

            // Top-right corner
            Path { path in
                path.move(to: CGPoint(x: geo.size.width - cornerSize - 2, y: 2))
                path.addLine(to: CGPoint(x: geo.size.width - 2, y: 2))
                path.addLine(to: CGPoint(x: geo.size.width - 2, y: cornerSize + 2))
            }
            .stroke(color, lineWidth: 2)

            // Bottom-left corner
            Path { path in
                path.move(to: CGPoint(x: 2, y: geo.size.height - cornerSize - 2))
                path.addLine(to: CGPoint(x: 2, y: geo.size.height - 2))
                path.addLine(to: CGPoint(x: cornerSize + 2, y: geo.size.height - 2))
            }
            .stroke(color, lineWidth: 2)

            // Bottom-right corner
            Path { path in
                path.move(to: CGPoint(x: geo.size.width - cornerSize - 2, y: geo.size.height - 2))
                path.addLine(to: CGPoint(x: geo.size.width - 2, y: geo.size.height - 2))
                path.addLine(to: CGPoint(x: geo.size.width - 2, y: geo.size.height - cornerSize - 2))
            }
            .stroke(color, lineWidth: 2)
        }
    }
}

// MARK: - Protocol Deck Card (System: Reboot - Firewall selection)

struct ProtocolDeckCard: View {
    let `protocol`: Protocol
    let hash: Int
    let onDragStart: () -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: () -> Void

    @State private var isDragging = false
    @State private var pulseAnimation = false
    @State private var glitchOffset: CGFloat = 0
    @State private var glitchTimer: Timer?

    private var cost: Int {
        TowerSystem.towerPlacementCost(rarity: `protocol`.rarity)
    }

    private var canAfford: Bool {
        hash >= cost
    }

    private var rarityColor: Color {
        RarityColors.color(for: `protocol`.rarity)
    }

    private var archetypeColor: Color {
        DesignHelpers.archetypeColor(for: `protocol`.id)
    }

    private var enhancedIcon: String {
        // Enhanced icons for protocols
        switch `protocol`.id.lowercased() {
        case "kernel_pulse":
            return "dot.circle.and.hand.point.up.left.fill"
        case "burst_protocol":
            return "burst.fill"
        case "trace_route":
            return "scope"
        case "ice_shard":
            return "snowflake"
        case "fork_bomb":
            return "arrow.triangle.branch"
        case "root_access":
            return "terminal.fill"
        case "overflow":
            return "bolt.horizontal.fill"
        case "null_pointer":
            return "exclamationmark.triangle.fill"
        default:
            return `protocol`.iconName
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            // Enhanced firewall icon with protocol styling
            ZStack {
                // Outer glow for epic/legendary
                if `protocol`.rarity == .legendary || `protocol`.rarity == .epic {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(rarityColor.opacity(0.2))
                        .frame(width: 64, height: 64)
                        .blur(radius: 4)
                        .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                }

                // Main card with gradient
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                archetypeColor.opacity(canAfford ? 0.4 : 0.15),
                                rarityColor.opacity(canAfford ? 0.3 : 0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)

                // Circuit pattern
                TowerCardCircuitPattern()
                    .stroke(archetypeColor.opacity(0.2), lineWidth: 0.5)
                    .frame(width: 56, height: 56)
                    .clipped()

                // Glitch effect for null_pointer
                if `protocol`.id.lowercased() == "null_pointer" {
                    Image(systemName: enhancedIcon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.red.opacity(0.5))
                        .offset(x: glitchOffset, y: 0)
                }

                // Protocol icon with glow
                ZStack {
                    Image(systemName: enhancedIcon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(archetypeColor.opacity(0.5))
                        .blur(radius: 4)

                    Image(systemName: enhancedIcon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(canAfford ? .white : .gray)
                }

                // Level badge (enhanced)
                if `protocol`.level > 1 {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 7, weight: .bold))
                        Text("\(`protocol`.level)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [archetypeColor.opacity(0.8), rarityColor.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(4)
                    .offset(x: 18, y: -22)
                }

                // Compiled indicator
                if `protocol`.isCompiled {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                        )
                        .offset(x: -22, y: -22)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                rarityColor.opacity(canAfford ? 1 : 0.4),
                                archetypeColor.opacity(canAfford ? 0.7 : 0.3)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
            )
            .overlay(
                RarityCorners(rarity: rarityString, color: rarityColor)
                    .opacity(canAfford ? 1 : 0.4)
            )
            .scaleEffect(isDragging ? 0.85 : 1.0)
            .shadow(color: canAfford ? archetypeColor.opacity(0.4) : .clear, radius: 6)

            // Cost label (Hash)
            HStack(spacing: 3) {
                Text("Ħ")
                    .font(.system(size: 11, weight: .bold))
                Text("\(cost)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
            }
            .foregroundColor(canAfford ? DesignColors.primary : .red)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.5))
            .cornerRadius(4)
        }
        .opacity(canAfford ? 1.0 : 0.5)
        .animation(.easeOut(duration: 0.15), value: isDragging)
        .onAppear {
            if `protocol`.rarity == .legendary {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            }
            if `protocol`.id.lowercased() == "null_pointer" {
                startGlitchAnimation()
            }
        }
        .onDisappear {
            glitchTimer?.invalidate()
            glitchTimer = nil
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .named("gameArea"))
                .onChanged { value in
                    if canAfford {
                        if !isDragging {
                            // Only start drag when pulling upward (toward the board)
                            let translation = value.translation
                            guard -translation.height > abs(translation.width) else { return }
                            isDragging = true
                            onDragStart()
                        }
                        onDragChanged(value)
                    }
                }
                .onEnded { _ in
                    if isDragging {
                        isDragging = false
                        onDragEnded()
                    }
                }
        )
    }

    private var rarityString: String {
        switch `protocol`.rarity {
        case .common: return "common"
        case .rare: return "rare"
        case .epic: return "epic"
        case .legendary: return "legendary"
        }
    }

    private func startGlitchAnimation() {
        glitchTimer?.invalidate()
        glitchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            if Bool.random() {
                withAnimation(.linear(duration: 0.05)) {
                    glitchOffset = CGFloat.random(in: -2...2)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.linear(duration: 0.05)) {
                        glitchOffset = 0
                    }
                }
            }
        }
    }
}
