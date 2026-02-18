import SwiftUI
import SpriteKit

// MARK: - Embedded TD Game View (for BOARD tab)

struct EmbeddedTDGameView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject var appState: AppState
    @ObservedObject var controller: EmbeddedTDGameController

    private var scale: CGFloat {
        DesignLayout.adaptiveScale(for: sizeClass)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark terminal background
                Color(hex: "0a0a0f")
                    .ignoresSafeArea()

                // SpriteKit scene
                if let scene = controller.scene {
                    SpriteView(scene: scene)
                        .ignoresSafeArea()
                } else {
                    // Loading state
                    VStack {
                        ProgressView()
                            .tint(DesignColors.primary)
                        Text(L10n.Motherboard.initializing)
                            .font(DesignTypography.caption(12))
                            .foregroundColor(DesignColors.muted)
                            .padding(.top, 8)
                    }
                }

                // Sector unlock panel overlay
                if controller.showSectorUnlockPanel, let sectorId = controller.selectedSectorForUnlock {
                    sectorUnlockPanel(sectorId: sectorId)
                }
            }
            .onChange(of: geometry.size) { newSize in
                if controller.scene == nil && newSize.width > 0 && newSize.height > 0 {
                    controller.setup(screenSize: newSize, playerProfile: appState.currentPlayer)
                }
            }
            .onAppear {
                if controller.scene == nil && geometry.size.width > 0 && geometry.size.height > 0 {
                    controller.setup(screenSize: geometry.size, playerProfile: appState.currentPlayer)
                }
            }
        }
    }

    // MARK: - Sector Unlock Panel

    @ViewBuilder
    private func sectorUnlockPanel(sectorId: String) -> some View {
        let status = SectorUnlockSystem.shared.getUnlockStatus(for: sectorId, profile: appState.currentPlayer)

        ZStack {
            // Dimmed background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    controller.dismissSectorUnlockPanel()
                }

            if status?.isComingSoon == true {
                // Coming Soon panel — distinct from unlock panel
                comingSoonPanel(status: status!)
            } else {
                // Standard unlock panel
                standardUnlockPanel(status: status, sectorId: sectorId)
            }
        }
    }

    @ViewBuilder
    private func comingSoonPanel(status: SectorUnlockSystem.UnlockStatus) -> some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 40 * scale))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.8))

                Text(L10n.Sector.comingSoon)
                    .font(.system(size: 24 * scale, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.8))

                Text(status.displayName)
                    .font(.system(size: 18 * scale, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
            }

            // Description
            Text(L10n.Sector.comingSoonDescription)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(DesignColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // OK button
            Button(action: {
                HapticsService.shared.play(.light)
                controller.dismissSectorUnlockPanel()
            }) {
                Text(L10n.Common.done)
                    .font(.system(size: 16 * scale, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 120 * scale, height: 50 * scale)
                    .background(Color(red: 0.3, green: 0.3, blue: 0.5).opacity(0.5))
                    .cornerRadius(8)
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "0a0a12") ?? .black)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(red: 0.4, green: 0.4, blue: 0.6).opacity(0.3), lineWidth: 2)
                )
        )
        .padding(20)
    }

    @ViewBuilder
    private func standardUnlockPanel(status: SectorUnlockSystem.UnlockStatus?, sectorId: String) -> some View {
        // Panel
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 40 * scale))
                    .foregroundColor(.red)

                Text(L10n.Sector.encrypted)
                    .font(.system(size: 24 * scale, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)

                Text(status?.displayName ?? L10n.Common.unknown)
                    .font(.system(size: 18 * scale, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
            }

            // Description
            if let desc = status?.description {
                Text(desc)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(DesignColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Cost display
            if let status = status {
                VStack(spacing: 12) {
                    // Cost
                    HStack(spacing: 8) {
                        Text(L10n.Sector.decryptCost)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(DesignColors.textSecondary)

                        Text("Ħ \(status.unlockCost)")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                    }

                    // Current balance
                    HStack(spacing: 8) {
                        Text(L10n.Sector.yourBalance)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(DesignColors.textSecondary)

                        Text("Ħ \(status.currentHash)")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(status.canAfford ? .green : .orange)
                    }

                    // Status message
                    Text(status.statusMessage)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(status.canUnlock ? .green : .orange)
                        .padding(.top, 4)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(status.canUnlock ? Color.cyan.opacity(0.5) : Color.red.opacity(0.3), lineWidth: 1)
                        )
                )
            }

            // Buttons
            HStack(spacing: 16) {
                // Cancel
                Button(action: {
                    HapticsService.shared.play(.light)
                    controller.dismissSectorUnlockPanel()
                }) {
                    Text(L10n.Common.cancel)
                        .font(.system(size: 16 * scale, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 120 * scale, height: 50 * scale)
                        .background(DesignColors.muted.opacity(0.3))
                        .cornerRadius(8)
                }

                // Decrypt
                Button(action: {
                    _ = controller.unlockSector(sectorId, appState: appState)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "key.fill")
                        Text(L10n.Sector.decrypt)
                    }
                    .font(.system(size: 16 * scale, weight: .bold, design: .monospaced))
                    .foregroundColor(status?.canUnlock == true ? .black : DesignColors.textSecondary)
                    .frame(width: 140 * scale, height: 50 * scale)
                    .background(status?.canUnlock == true ? DesignColors.primary : DesignColors.muted.opacity(0.3))
                    .cornerRadius(8)
                }
                .disabled(status?.canUnlock != true)
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "0a0a12") ?? .black)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 2)
                )
        )
        .padding(20)
    }
}

// MARK: - Embedded Protocol Deck Card (with Drag Support)

struct EmbeddedProtocolDeckCard: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    let `protocol`: Protocol
    let playerLevel: Int
    let hash: Int
    let onDragStart: () -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: () -> Void

    @State private var isDragging = false
    @State private var legendaryPulse = false

    private var scale: CGFloat {
        DesignLayout.adaptiveScale(for: sizeClass)
    }

    /// Protocol with player's level applied for accurate stat display
    private var leveledProtocol: Protocol {
        var p = `protocol`
        p.level = playerLevel
        return p
    }

    private var cost: Int {
        TowerSystem.towerPlacementCost(rarity: `protocol`.rarity)
    }

    private var canAfford: Bool {
        hash >= cost
    }

    private var rarityColor: Color {
        RarityColors.color(for: `protocol`.rarity)
    }

    // Glow intensity scales with rarity
    private var glowRadius: CGFloat {
        switch `protocol`.rarity {
        case .common: return 4
        case .rare: return 8
        case .epic: return 12
        case .legendary: return 16
        }
    }

    private var glowOpacity: Double {
        switch `protocol`.rarity {
        case .common: return 0.3
        case .rare: return 0.5
        case .epic: return 0.6
        case .legendary: return 0.7
        }
    }

    private var isHighRarity: Bool {
        `protocol`.rarity == .epic || `protocol`.rarity == .legendary
    }

    var body: some View {
        VStack(spacing: 2) {
            // Tower icon container - circuit board aesthetic
            ZStack {
                // Outer glow for epic/legendary
                if isHighRarity && canAfford {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(rarityColor.opacity(0.15))
                        .frame(width: 52 * scale, height: 52 * scale)
                        .blur(radius: 6)
                        .scaleEffect(legendaryPulse ? 1.15 : 1.0)
                }

                // Background circuit pattern
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(hex: "0a0a12") ?? .black)
                    .frame(width: 46 * scale, height: 46 * scale)

                // Border with rarity-scaled glow effect
                RoundedRectangle(cornerRadius: 7)
                    .stroke(rarityColor.opacity(canAfford ? 0.9 : 0.3), lineWidth: isHighRarity ? 2.5 : 2)
                    .frame(width: 46 * scale, height: 46 * scale)
                    .shadow(color: canAfford ? rarityColor.opacity(glowOpacity) : .clear, radius: glowRadius)

                // Protocol icon - simplified, geometric
                Image(systemName: `protocol`.iconName)
                    .font(.system(size: 20 * scale, weight: .medium))
                    .foregroundColor(canAfford ? .white : DesignColors.textSecondary)
                    .shadow(color: canAfford && isHighRarity ? rarityColor.opacity(0.5) : .clear, radius: 4)

                // Corner accent (circuit node) - larger for higher rarity
                Circle()
                    .fill(rarityColor)
                    .frame(width: isHighRarity ? 8 : 6, height: isHighRarity ? 8 : 6)
                    .offset(x: 18, y: -18)
                    .opacity(canAfford ? 1 : 0.3)

                // Opposite corner node for balance
                Circle()
                    .fill(rarityColor.opacity(0.5))
                    .frame(width: isHighRarity ? 6 : 5, height: isHighRarity ? 6 : 5)
                    .offset(x: -18, y: 18)
                    .opacity(canAfford ? 0.8 : 0.2)

                // Level badge (top-left corner)
                if playerLevel > 1 {
                    Text(L10n.Common.lv(playerLevel))
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 2)
                        .padding(.vertical, 1)
                        .background(rarityColor.opacity(0.8))
                        .cornerRadius(3)
                        .offset(x: -15, y: -18)
                }

                // Special ability badge (bottom-right corner)
                if let special = `protocol`.firewallBaseStats.special {
                    Image(systemName: DesignHelpers.iconForFirewallAbility(special))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(2.5)
                        .background(
                            Circle()
                                .fill(rarityColor.opacity(0.85))
                        )
                        .offset(x: 18, y: 15)
                }
            }
            .scaleEffect(isDragging ? 0.9 : 1.0)

            // Protocol name (truncated)
            Text(`protocol`.name)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(canAfford ? .white.opacity(0.8) : DesignColors.muted)
                .lineLimit(1)
                .frame(width: 50 * scale)

            // Cost label - terminal/monospace aesthetic
            HStack(spacing: 2) {
                Text("Ħ")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                Text("\(cost)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
            .foregroundColor(canAfford ? rarityColor : .red.opacity(0.7))

            // Stats row - power and damage
            HStack(spacing: 4) {
                // Power consumption
                HStack(spacing: 1) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 7))
                    Text("\(`protocol`.firewallStats.powerDraw)")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                }
                .foregroundColor(.yellow.opacity(0.8))

                // Damage
                HStack(spacing: 1) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 7))
                    Text("\(Int(leveledProtocol.firewallStats.damage))")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                }
                .foregroundColor(.orange.opacity(0.8))
            }
        }
        .opacity(canAfford ? 1.0 : 0.5)
        .animation(.easeOut(duration: 0.15), value: isDragging)
        .onAppear {
            // Subtle pulse for legendary cards
            if `protocol`.rarity == .legendary {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    legendaryPulse = true
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .named("motherboardGameArea"))
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
}
