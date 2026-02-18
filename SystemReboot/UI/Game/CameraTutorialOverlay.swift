import SwiftUI

// MARK: - Camera Tutorial Overlay
// In-game camera-driven tutorial for first-time players
// Replaces the old 3-card intro sequence with a "learn in 15 seconds" camera sweep
//
// Flow:
//   0. Full board → "Your motherboard. Your battlefield." (game paused)
//   1. Pan to PSU spawn edge → "PSU sector breached. Viruses incoming." (game unpauses, batch 1 spawns)
//   2. Pan to CPU center → "The CPU — your core. If it falls, the system crashes." (batch 1 arrives, efficiency drops)
//   3. Pull back to play view (no text)
//   4. "Deploy your first firewall. Drag it onto the grid." (waits for placement, then batch 2 spawns via controller)

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
    private let psuPlayView = CGPoint(x: 3300, y: 2100)  // Centered on PSU sector for gameplay

    var body: some View {
        ZStack {
            // Dim overlay for text legibility (not during interactive step)
            if showText && !isInteractiveStep {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // Tutorial text (upper third of screen to avoid covering game action)
            if showText {
                VStack {
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
                .padding(.top, 100)
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
    /// Unpauses the game and spawns batch 1 (immune enemies that will leak to CPU).
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

            // Unpause game so enemies can move during camera pan to CPU
            self.controller.scene?.state?.isPaused = false

            // Spawn batch 1: immune enemies that will leak and drop efficiency
            self.spawnBatch1()

            // Short text display — the spawning enemies ARE the visual content
            scheduleAfter(1.5) {
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

        // Slow tracking pan — camera follows batch 1 enemies toward the CPU
        controller.scene?.cameraController.animateTo(
            position: cpuCenter,
            scale: 0.55,
            duration: 3.5
        ) {
            tutorialText = L10n.Tutorial.cpuCore
            withAnimation(.easeIn(duration: 0.4)) {
                showText = true
            }

            // Hold on CPU long enough for batch 1 to arrive and impact
            scheduleAfter(5.0) {
                self.startStep3()
            }
        }
    }

    /// Step 3: Pull back to play view (no text). Game already unpaused at step 1.
    private func startStep3() {
        currentStep = 3

        withAnimation(.easeOut(duration: 0.3)) {
            showText = false
        }

        // Game was already unpaused in step 1 for batch 1 enemies to move

        // Zoom into PSU sector — scale 0.55 keeps all IC details visible (threshold is 0.6)
        controller.scene?.cameraController.animateTo(
            position: psuPlayView,
            scale: 0.55,
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

        // Ensure game is unpaused and idle spawning enabled
        controller.scene?.state?.isPaused = false
        controller.scene?.state?.idleSpawnEnabled = true
        controller.scene?.state?.idleSpawnTimer = BalanceConfig.Tutorial.postTutorialSpawnTimer

        // Animate camera to PSU sector play position (scale 0.55 for IC details)
        controller.scene?.cameraController.animateTo(
            position: psuPlayView,
            scale: 0.55,
            duration: 0.5
        ) {
            onComplete()
        }
    }

    // MARK: - Tutorial Spawning

    /// Spawn batch 1 enemies with staggered timing (immune fast enemies that leak to CPU)
    private func spawnBatch1() {
        guard let scene = controller.scene else { return }

        let spawnPoint = CGPoint(x: 4200, y: 2100) // PSU spawn edge
        let enemies = TutorialSpawnSystem.createBatch1Enemies(spawnPoint: spawnPoint, pathIndex: 0)
        let stagger = BalanceConfig.Tutorial.batch1SpawnStagger

        for (index, enemy) in enemies.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + stagger * Double(index)) {
                scene.state?.enemies.append(enemy)
                scene.spawnPortalAnimation(at: scene.convertToScene(spawnPoint))
            }
        }
    }

    // MARK: - Helpers

    private func scheduleAfter(_ delay: TimeInterval, action: @escaping () -> Void) {
        let work = DispatchWorkItem(block: action)
        scheduledWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}
