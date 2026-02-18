import SwiftUI

// MARK: - Boss Tutorial Overlay
// Pre-boss tutorial for first-time players on the Motherboard view.
// Replaces the normal boss alert with a multi-step explanation
// before transitioning to the existing difficulty selector.
//
// Flow:
//   0. "CRITICAL THREAT DETECTED" / "Manual intervention required"
//   1. "Level up your firewalls — they become your weapons in combat"
//   2. Camera zooms to boss → boss info + "Immune to tower fire"
//   3. ENGAGE button → opens difficulty selector

struct BossTutorialOverlay: View {
    @ObservedObject var controller: EmbeddedTDGameController
    let bossType: String
    let onEngage: () -> Void

    @State private var currentStep: Int = 0
    @State private var showContent: Bool = false
    @State private var showEngageButton: Bool = false
    @State private var scheduledWork: DispatchWorkItem?

    /// Boss display name based on type
    private var bossDisplayName: String {
        switch bossType {
        case "cyberboss": return L10n.Boss.cyberboss
        case "voidharbinger": return L10n.Boss.voidHarbinger
        default: return bossType.replacingOccurrences(of: "_", with: " ").uppercased()
        }
    }

    /// Boss position in SpriteKit coords (Y-flipped from game coords)
    private var bossScenePosition: CGPoint {
        if let boss = controller.gameState?.enemies.first(where: { $0.isBoss && !$0.isDead }) {
            let mapHeight = controller.gameState?.map.height ?? 4200
            return CGPoint(x: boss.x, y: CGFloat(mapHeight) - boss.y)
        }
        return CGPoint(x: 2100, y: 2100)
    }

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(showContent ? 0.6 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.3), value: showContent)

            // Tutorial card
            if showContent {
                VStack {
                    Spacer()

                    VStack(spacing: 16) {
                        // Icon changes per step
                        stepIcon

                        // Main text
                        stepText

                        // Subtext
                        stepSubtext

                        // ENGAGE button (step 3 only)
                        if showEngageButton {
                            Button {
                                HapticsService.shared.play(.medium)
                                onEngage()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "target")
                                    Text(L10n.BossTutorial.engage)
                                }
                                .font(DesignTypography.headline(16))
                                .foregroundColor(.black)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(DesignColors.danger)
                                .cornerRadius(12)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(DesignColors.surface.opacity(0.95))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.red.opacity(0.5), lineWidth: 2)
                            )
                    )
                    .padding(.horizontal, 32)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))

                    Spacer()
                }
            }

            // Skip button (top-right)
            VStack {
                HStack {
                    Spacer()
                    Button(action: skipTutorial) {
                        Text(L10n.Tutorial.skip)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(DesignColors.muted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                }
                .padding(.top, 60)
                .padding(.horizontal, 20)
                Spacer()
            }
        }
        .onAppear {
            startStep0()
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepIcon: some View {
        switch currentStep {
        case 0:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
        case 1:
            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                .font(.system(size: 48))
                .foregroundColor(.cyan)
        default:
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
        }
    }

    @ViewBuilder
    private var stepText: some View {
        switch currentStep {
        case 0:
            Text(L10n.BossTutorial.criticalThreat)
                .font(DesignTypography.headline(20))
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
        case 1:
            Text(L10n.BossTutorial.upgradeFirewalls)
                .font(DesignTypography.headline(16))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        default:
            Text(bossDisplayName)
                .font(DesignTypography.headline(20))
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var stepSubtext: some View {
        switch currentStep {
        case 0:
            Text(L10n.BossTutorial.manualIntervention)
                .font(DesignTypography.caption(14))
                .foregroundColor(DesignColors.muted)
                .multilineTextAlignment(.center)
        case 1:
            EmptyView()
        default:
            Text(L10n.BossTutorial.immuneInfo)
                .font(DesignTypography.caption(14))
                .foregroundColor(DesignColors.muted)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Tutorial Steps

    /// Step 0: "CRITICAL THREAT DETECTED" / "Manual intervention required"
    private func startStep0() {
        currentStep = 0

        // Pause the TD game
        controller.scene?.state?.isPaused = true

        let work = DispatchWorkItem { [self] in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showContent = true
            }

            scheduleAfter(2.5) {
                self.startStep1()
            }
        }
        scheduledWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    /// Step 1: "Level up your firewalls — they become your weapons in combat"
    private func startStep1() {
        currentStep = 1

        withAnimation(.easeOut(duration: 0.2)) {
            showContent = false
        }

        let work = DispatchWorkItem { [self] in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showContent = true
            }

            scheduleAfter(3.0) {
                self.startStep2()
            }
        }
        scheduledWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    /// Step 2: Camera zooms to boss → boss info + ENGAGE button
    private func startStep2() {
        currentStep = 2

        withAnimation(.easeOut(duration: 0.2)) {
            showContent = false
        }

        // Zoom camera to boss position
        controller.scene?.cameraController.animateTo(
            position: bossScenePosition,
            scale: 0.5,
            duration: 1.5
        ) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showContent = true
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.3)) {
                showEngageButton = true
            }
        }
    }

    // MARK: - Skip / Helpers

    private func skipTutorial() {
        scheduledWork?.cancel()
        scheduledWork = nil
        HapticsService.shared.play(.selection)
        onEngage()
    }

    private func scheduleAfter(_ delay: TimeInterval, action: @escaping () -> Void) {
        let work = DispatchWorkItem(block: action)
        scheduledWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}
