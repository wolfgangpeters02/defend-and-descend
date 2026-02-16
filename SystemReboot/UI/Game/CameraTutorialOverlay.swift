import SwiftUI

// MARK: - Camera Tutorial Overlay
// In-game camera-driven tutorial for first-time players
// Replaces the old 3-card intro sequence with a "learn in 15 seconds" camera sweep
//
// Flow:
//   0. Full board → "Your motherboard. Your battlefield."
//   1. Pan to PSU spawn edge → "PSU sector breached. Viruses incoming."
//   2. Pan to CPU center → "The CPU — your core. If it falls, the system crashes."
//   3. Pull back to play view, spawn one slow virus (no text)
//   4. "Deploy your first firewall. Drag it onto the grid." (waits for placement)

struct CameraTutorialOverlay: View {
    @ObservedObject var controller: EmbeddedTDGameController
    let onComplete: () -> Void

    @State private var currentStep: Int = 0
    @State private var showText: Bool = false
    @State private var tutorialText: String = ""
    @State private var isInteractiveStep: Bool = false
    @State private var scheduledWork: DispatchWorkItem?

    // Camera targets (SpriteKit coordinates — Y-up, board is 4200×4200)
    private let boardCenter = CGPoint(x: 2100, y: 2100)
    private let psuSpawnEdge = CGPoint(x: 3900, y: 2100)
    private let cpuCenter = CGPoint(x: 2100, y: 2100)
    private let psuSectorCenter = CGPoint(x: 3500, y: 2100)

    var body: some View {
        ZStack {
            // Dim overlay for text legibility (not during interactive step)
            if showText && !isInteractiveStep {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // Tutorial text
            if showText {
                VStack {
                    Spacer()
                    Text(tutorialText)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black, radius: 8, x: 0, y: 2)
                        .shadow(color: .black, radius: 16, x: 0, y: 4)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.6))
                        )
                    Spacer()
                }
                .padding(.bottom, isInteractiveStep ? 130 : 0)
                .transition(.opacity)
                .allowsHitTesting(false)
            }

            // Skip button (always visible, top-right)
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
        // Block touches during non-interactive steps, pass through during placement step
        .allowsHitTesting(!isInteractiveStep)
        .onAppear {
            startStep0()
        }
    }

    // MARK: - Tutorial Steps

    /// Step 0: Full board view — "Your motherboard. Your battlefield."
    private func startStep0() {
        currentStep = 0

        // Pause game logic
        controller.scene?.state?.isPaused = true

        // Camera should already be at board center, scale 1.8 (set by suppressIntroAnimation)
        // Show text with slight delay for scene to render
        let work = DispatchWorkItem { [self] in
            tutorialText = L10n.Tutorial.motherboard
            withAnimation(.easeIn(duration: 0.5)) {
                showText = true
            }

            scheduleAfter(2.5) {
                self.startStep1()
            }
        }
        scheduledWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// Step 1: Pan to PSU spawn edge — "PSU sector breached. Viruses incoming."
    private func startStep1() {
        currentStep = 1

        // Fade text
        withAnimation(.easeOut(duration: 0.3)) {
            showText = false
        }

        // Animate camera to PSU spawn edge
        controller.scene?.cameraController.animateTo(
            position: psuSpawnEdge,
            scale: 0.55,
            duration: 1.5
        ) {
            tutorialText = L10n.Tutorial.virusesIncoming
            withAnimation(.easeIn(duration: 0.4)) {
                showText = true
            }

            scheduleAfter(2.5) {
                self.startStep2()
            }
        }
    }

    /// Step 2: Pan to CPU center — "The CPU — your core. If it falls, the system crashes."
    private func startStep2() {
        currentStep = 2

        withAnimation(.easeOut(duration: 0.3)) {
            showText = false
        }

        controller.scene?.cameraController.animateTo(
            position: cpuCenter,
            scale: 0.55,
            duration: 2.0
        ) {
            tutorialText = L10n.Tutorial.cpuCore
            withAnimation(.easeIn(duration: 0.4)) {
                showText = true
            }

            scheduleAfter(3.0) {
                self.startStep3()
            }
        }
    }

    /// Step 3: Pull back to play view, spawn one virus (no text)
    private func startStep3() {
        currentStep = 3

        withAnimation(.easeOut(duration: 0.3)) {
            showText = false
        }

        // Unpause so game loop can spawn the virus
        controller.scene?.state?.isPaused = false

        controller.scene?.cameraController.animateTo(
            position: psuSectorCenter,
            scale: 1.0,
            duration: 1.5
        ) {
            scheduleAfter(1.5) {
                self.startStep4()
            }
        }
    }

    /// Step 4: "Deploy your first firewall. Drag it onto the grid." (interactive)
    private func startStep4() {
        currentStep = 4
        isInteractiveStep = true

        tutorialText = L10n.Tutorial.deployFirewall
        withAnimation(.easeIn(duration: 0.4)) {
            showText = true
        }

        // Activate deck card glow hint
        TutorialHintManager.shared.activateHint(.deckCard)
        TutorialHintManager.shared.activateHint(.towerSlot)
    }

    // MARK: - Completion

    /// Called when player places their first tower during tutorial
    func onTowerPlaced() {
        guard isInteractiveStep else { return }

        withAnimation(.easeOut(duration: 0.3)) {
            showText = false
        }

        // Small delay then complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onComplete()
        }
    }

    private func skipTutorial() {
        // Cancel any pending work
        scheduledWork?.cancel()
        scheduledWork = nil

        HapticsService.shared.play(.selection)

        // Ensure game is unpaused
        controller.scene?.state?.isPaused = false

        // Animate camera to default play position
        controller.scene?.cameraController.animateTo(
            position: psuSectorCenter,
            scale: 1.0,
            duration: 0.5
        ) {
            onComplete()
        }
    }

    // MARK: - Helpers

    private func scheduleAfter(_ delay: TimeInterval, action: @escaping () -> Void) {
        let work = DispatchWorkItem(block: action)
        scheduledWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}
