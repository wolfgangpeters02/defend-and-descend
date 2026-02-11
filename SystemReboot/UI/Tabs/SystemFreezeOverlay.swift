import SwiftUI

// MARK: - System Freeze Overlay

struct SystemFreezeOverlay: View {
    let currentHash: Int
    let onFlushMemory: () -> Void
    let onManualOverride: () -> Void

    @State private var glitchOffset: CGFloat = 0
    @State private var scanLineOffset: CGFloat = 0

    private var flushCost: Int {
        max(1, currentHash / 10)  // 10% of current Hash
    }

    private var canAffordFlush: Bool {
        currentHash >= flushCost
    }

    var body: some View {
        ZStack {
            // Dark overlay with scan lines
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .overlay(
                    // Scan line effect
                    GeometryReader { geo in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .red.opacity(0.1), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 100)
                            .offset(y: scanLineOffset)
                            .onAppear {
                                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                                    scanLineOffset = geo.size.height
                                }
                            }
                    }
                )

            // Main content
            VStack(spacing: 24) {
                // Glitchy title
                ZStack {
                    Text(L10n.Freeze.header)
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundColor(.red.opacity(0.5))
                        .offset(x: glitchOffset, y: -glitchOffset)

                    Text(L10n.Freeze.header)
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.5))
                        .offset(x: -glitchOffset, y: glitchOffset)

                    Text(L10n.Freeze.header)
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.1).repeatForever(autoreverses: true)) {
                        glitchOffset = 2
                    }
                }

                // Error message
                VStack(spacing: 8) {
                    Text(L10n.Freeze.criticalError)
                        .font(DesignTypography.headline(16))
                        .foregroundColor(.red)

                    Text(L10n.Freeze.allSystemsHalted)
                        .font(DesignTypography.body(14))
                        .foregroundColor(DesignColors.muted)

                    Text(L10n.Freeze.chooseRecoveryMethod)
                        .font(DesignTypography.body(14))
                        .foregroundColor(.white)
                        .padding(.top, 8)
                }

                // Recovery options
                VStack(spacing: 16) {
                    // Option 1: Flush Memory (pay Hash)
                    Button {
                        HapticsService.shared.play(.medium)
                        onFlushMemory()
                    } label: {
                        VStack(spacing: 6) {
                            HStack {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.system(size: 24))
                                Text(L10n.Freeze.flushMemory)
                                    .font(DesignTypography.headline(18))
                            }

                            HStack(spacing: 4) {
                                Text(L10n.Common.cost)
                                    .foregroundColor(DesignColors.muted)
                                Image(systemName: "number.circle.fill")
                                    .foregroundColor(canAffordFlush ? DesignColors.primary : .red)
                                Text("\(flushCost)")
                                    .foregroundColor(canAffordFlush ? DesignColors.primary : .red)
                                Text(L10n.Freeze.hashPercent)
                                    .font(DesignTypography.caption(11))
                                    .foregroundColor(DesignColors.muted)
                            }
                            .font(DesignTypography.body(14))

                            Text(L10n.Freeze.restoresEfficiency)
                                .font(DesignTypography.caption(11))
                                .foregroundColor(DesignColors.muted)
                        }
                        .foregroundColor(canAffordFlush ? .white : DesignColors.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(canAffordFlush ? DesignColors.primary.opacity(0.2) : DesignColors.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(canAffordFlush ? DesignColors.primary : DesignColors.muted, lineWidth: 2)
                        )
                    }
                    .disabled(!canAffordFlush)

                    // Option 2: Manual Override (mini-game)
                    Button {
                        HapticsService.shared.play(.medium)
                        onManualOverride()
                    } label: {
                        VStack(spacing: 6) {
                            HStack {
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 24))
                                Text(L10n.Freeze.manualOverride)
                                    .font(DesignTypography.headline(18))
                            }

                            Text(L10n.Freeze.freeSurvive)
                                .font(DesignTypography.body(14))
                                .foregroundColor(DesignColors.success)

                            Text(L10n.Freeze.completeChallenge)
                                .font(DesignTypography.caption(11))
                                .foregroundColor(DesignColors.muted)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(DesignColors.success.opacity(0.2))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(DesignColors.success, lineWidth: 2)
                        )
                    }
                }
                .padding(.horizontal, 24)

                // Freeze count indicator
                Text(L10n.Freeze.frozenTimesSession(1))
                    .font(DesignTypography.caption(11))
                    .foregroundColor(DesignColors.muted)
                    .padding(.top, 8)
            }
            .padding()
        }
    }
}
