import SwiftUI

// MARK: - Blueprint Discovery Modal
// Shows when a blueprint drops from a boss
// System: Reboot themed - terminal/tech aesthetic

struct BlueprintDiscoveryModal: View {
    let protocolId: String
    let isFirstKill: Bool
    let wasGuaranteed: Bool
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var showCard = false
    @State private var glowPulse = false
    @State private var isViewActive = true

    private var protocolData: Protocol? {
        ProtocolLibrary.get(protocolId)
    }

    private var protocolColor: Color {
        guard let proto = protocolData else { return .cyan }
        return Color(hex: proto.color) ?? .cyan
    }

    private var rarityColor: Color {
        guard let proto = protocolData else { return .gray }
        switch proto.rarity {
        case .common: return .gray
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }

    var body: some View {
        ZStack {
            // Dark overlay with glow effect
            Color.black.opacity(0.92)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Background glow pulse
            Circle()
                .fill(protocolColor.opacity(0.15))
                .frame(width: 400, height: 400)
                .blur(radius: 60)
                .scaleEffect(glowPulse ? 1.2 : 0.8)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: glowPulse)

            // Modal content
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text(L10n.Blueprint.found)
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundColor(protocolColor)
                        .shadow(color: protocolColor.opacity(0.8), radius: 10)

                    if isFirstKill {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                            Text(L10n.Blueprint.firstKillBonus)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.yellow.opacity(0.2))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
                                )
                        )
                    }
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : -30)

                // Protocol card
                if let proto = protocolData {
                    VStack(spacing: 20) {
                        // Icon with glow
                        ZStack {
                            Circle()
                                .fill(protocolColor.opacity(0.2))
                                .frame(width: 120, height: 120)

                            Image(systemName: proto.iconName)
                                .font(.system(size: 60))
                                .foregroundColor(protocolColor)
                                .shadow(color: protocolColor, radius: 20)
                        }

                        // Name
                        Text(proto.name)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)

                        // Rarity badge
                        Text(proto.rarity.rawValue.uppercased())
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(rarityColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(rarityColor.opacity(0.2))
                                    .overlay(
                                        Capsule()
                                            .stroke(rarityColor.opacity(0.5), lineWidth: 1)
                                    )
                            )

                        // Description
                        Text(proto.description)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)

                        // Stats preview
                        HStack(spacing: 32) {
                            statItem(icon: "bolt.fill", label: L10n.Stats.dmg, value: "\(Int(proto.firewallBaseStats.damage))")
                            statItem(icon: "scope", label: L10n.Stats.rng, value: "\(Int(proto.firewallBaseStats.range))")
                            statItem(icon: "bolt.horizontal.fill", label: L10n.Stats.pwr, value: "\(proto.firewallBaseStats.powerDraw)W")
                        }
                        .padding(.top, 8)
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(hex: "0d1117") ?? Color.black)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(protocolColor.opacity(0.5), lineWidth: 2)
                            )
                            .shadow(color: protocolColor.opacity(0.3), radius: 20)
                    )
                    .opacity(showCard ? 1 : 0)
                    .scaleEffect(showCard ? 1 : 0.7)
                }

                // Collect button
                Button(action: dismiss) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text(L10n.Common.collect)
                    }
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .frame(width: 200, height: 56)
                    .background(protocolColor)
                    .cornerRadius(12)
                    .shadow(color: protocolColor.opacity(0.5), radius: 10)
                }
                .opacity(showCard ? 1 : 0)
            }
            .padding(24)
        }
        .onAppear {
            isViewActive = true

            // Start glow pulse
            glowPulse = true

            // Animate in sequence
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showContent = true
            }

            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3)) {
                showCard = true
            }

            // Play haptic feedback
            HapticsService.shared.play(.legendary)
        }
        .onDisappear {
            isViewActive = false
        }
    }

    private func statItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(protocolColor.opacity(0.7))
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)
        }
    }

    private func dismiss() {
        HapticsService.shared.play(.selection)
        withAnimation(.easeOut(duration: 0.2)) {
            showContent = false
            showCard = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
            guard isViewActive else { return }
            onDismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    BlueprintDiscoveryModal(
        protocolId: "burst_protocol",
        isFirstKill: true,
        wasGuaranteed: true,
        onDismiss: {}
    )
}
