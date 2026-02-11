import SwiftUI
import SpriteKit

// MARK: - Embedded TD Game View (for BOARD tab)

struct EmbeddedTDGameView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var controller: EmbeddedTDGameController

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

            // Panel
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)

                    Text(L10n.Sector.encrypted)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)

                    Text(status?.displayName ?? L10n.Common.unknown)
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }

                // Description
                if let desc = status?.description {
                    Text(desc)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.gray)
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
                                .foregroundColor(.gray)

                            Text("Ħ \(status.unlockCost)")
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }

                        // Current balance
                        HStack(spacing: 8) {
                            Text(L10n.Sector.yourBalance)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.gray)

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
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(width: 120, height: 50)
                            .background(Color.gray.opacity(0.3))
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
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(status?.canUnlock == true ? .black : .gray)
                        .frame(width: 140, height: 50)
                        .background(status?.canUnlock == true ? Color.cyan : Color.gray.opacity(0.3))
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
}

// MARK: - Embedded Protocol Deck Card (with Drag Support)

struct EmbeddedProtocolDeckCard: View {
    let `protocol`: Protocol
    let hash: Int
    let onDragStart: () -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: () -> Void

    @State private var isDragging = false
    @State private var legendaryPulse = false

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
        VStack(spacing: 4) {
            // Tower icon container - circuit board aesthetic
            ZStack {
                // Outer glow for epic/legendary
                if isHighRarity && canAfford {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(rarityColor.opacity(0.15))
                        .frame(width: 64, height: 64)
                        .blur(radius: 8)
                        .scaleEffect(legendaryPulse ? 1.15 : 1.0)
                }

                // Background circuit pattern
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "0a0a12") ?? .black)
                    .frame(width: 56, height: 56)

                // Border with rarity-scaled glow effect
                RoundedRectangle(cornerRadius: 8)
                    .stroke(rarityColor.opacity(canAfford ? 0.9 : 0.3), lineWidth: isHighRarity ? 2.5 : 2)
                    .frame(width: 56, height: 56)
                    .shadow(color: canAfford ? rarityColor.opacity(glowOpacity) : .clear, radius: glowRadius)

                // Protocol icon - simplified, geometric
                Image(systemName: `protocol`.iconName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(canAfford ? .white : .gray)
                    .shadow(color: canAfford && isHighRarity ? rarityColor.opacity(0.5) : .clear, radius: 4)

                // Corner accent (circuit node) - larger for higher rarity
                Circle()
                    .fill(rarityColor)
                    .frame(width: isHighRarity ? 10 : 8, height: isHighRarity ? 10 : 8)
                    .offset(x: 22, y: -22)
                    .opacity(canAfford ? 1 : 0.3)

                // Opposite corner node for balance
                Circle()
                    .fill(rarityColor.opacity(0.5))
                    .frame(width: isHighRarity ? 8 : 6, height: isHighRarity ? 8 : 6)
                    .offset(x: -22, y: 22)
                    .opacity(canAfford ? 0.8 : 0.2)
            }
            .scaleEffect(isDragging ? 0.9 : 1.0)

            // Cost label - terminal/monospace aesthetic
            HStack(spacing: 2) {
                Text("Ħ")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                Text("\(cost)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            .foregroundColor(canAfford ? rarityColor : .red.opacity(0.7))

            // Stats row - power and damage
            HStack(spacing: 6) {
                // Power consumption
                HStack(spacing: 1) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8))
                    Text("\(`protocol`.firewallStats.powerDraw)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                }
                .foregroundColor(.yellow.opacity(0.8))

                // Damage
                HStack(spacing: 1) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 8))
                    Text("\(Int(`protocol`.firewallStats.damage))")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
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
            DragGesture(minimumDistance: 5, coordinateSpace: .named("motherboardGameArea"))
                .onChanged { value in
                    if canAfford {
                        if !isDragging {
                            isDragging = true
                            onDragStart()
                        }
                        onDragChanged(value)
                    }
                }
                .onEnded { _ in
                    isDragging = false
                    onDragEnded()
                }
        )
    }
}
