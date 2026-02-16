import SwiftUI

// MARK: - Boss Loot Modal
// Shows reward screen after boss fights with decrypt animation
// Each reward is a "data packet" that decrypts via taps

struct BossLootModal: View {
    let reward: BossLootReward
    let onCollect: () -> Void

    // MARK: - State

    @State private var currentItemIndex: Int = 0
    @State private var itemDecryptProgress: [Int] = []
    @State private var revealedItems: Set<Int> = []
    @State private var allDecrypted: Bool = false
    @State private var isViewActive: Bool = true
    @State private var autoAdvanceTimer: Timer?
    @State private var glitchOffset: CGFloat = 0
    @State private var headerGlow: Bool = false
    @State private var collectReady: Bool = false

    // MARK: - Computed

    private var tapsRequired: Int {
        BalanceConfig.BossLootReveal.tapsToDecrypt
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.95)
                .ignoresSafeArea()
                .onTapGesture {
                    handleTap()
                }

            // Scan line effect
            scanLineOverlay

            // Main content
            VStack(spacing: 32) {
                // Header
                headerView

                // Data packet cards
                cardRow

                // Progress indicator or collect button
                bottomSection
            }
            .padding(24)
        }
        .onAppear {
            isViewActive = true
            itemDecryptProgress = Array(repeating: 0, count: reward.items.count)
            startAutoAdvanceTimer()
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                headerGlow = true
            }
            HapticsService.shared.play(.warning)
        }
        .onDisappear {
            isViewActive = false
            autoAdvanceTimer?.invalidate()
            autoAdvanceTimer = nil
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 8) {
            Text(allDecrypted ? L10n.BossLoot.decryptionComplete : L10n.BossLoot.neutralized)
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .foregroundColor(allDecrypted ? .green : DesignColors.primary)
                .shadow(color: (allDecrypted ? Color.green : DesignColors.primary).opacity(headerGlow ? 0.8 : 0.4), radius: 10)
                .offset(x: glitchOffset)

            if !allDecrypted {
                Text(L10n.BossLoot.decryptingPackets)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(DesignColors.muted)
            }

            if reward.isFirstKill {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                    Text(L10n.BossLoot.firstDefeat)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                }
                .foregroundColor(.yellow)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.yellow.opacity(0.15))
                        .overlay(
                            Capsule()
                                .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
                        )
                )
            }
        }
    }

    private var cardRow: some View {
        HStack(spacing: 16) {
            ForEach(Array(reward.items.enumerated()), id: \.element.id) { index, item in
                DataPacketCard(
                    item: item,
                    index: index,
                    decryptProgress: itemDecryptProgress.indices.contains(index) ? itemDecryptProgress[index] : 0,
                    tapsRequired: tapsRequired,
                    isRevealed: revealedItems.contains(index),
                    isActive: index == currentItemIndex && !allDecrypted,
                    onTap: { handleCardTap(index: index) }
                )
            }
        }
    }

    private var bottomSection: some View {
        Group {
            if allDecrypted {
                // Collect button (disabled briefly to prevent accidental taps)
                Button(action: {
                    guard collectReady else { return }
                    HapticsService.shared.play(.selection)
                    onCollect()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text(L10n.Common.collect)
                    }
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .frame(width: 200, height: 56)
                    .background(collectReady ? Color.green : Color.green.opacity(0.4))
                    .cornerRadius(12)
                    .shadow(color: Color.green.opacity(collectReady ? 0.5 : 0.2), radius: 10)
                }
                .allowsHitTesting(collectReady)
                .transition(.scale.combined(with: .opacity))
            } else {
                // Tap instruction
                VStack(spacing: 8) {
                    Text(L10n.BossLoot.tapToDecrypt)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignColors.primary)

                    // Progress dots for current item
                    if currentItemIndex < reward.items.count {
                        HStack(spacing: 8) {
                            ForEach(0..<tapsRequired, id: \.self) { tapIndex in
                                let progress = itemDecryptProgress.indices.contains(currentItemIndex) ? itemDecryptProgress[currentItemIndex] : 0
                                Circle()
                                    .fill(tapIndex < progress ? DesignColors.primary : Color(hex: "2a2a34") ?? Color.gray)
                                    .frame(width: 10, height: 10)
                                    .overlay(
                                        Circle()
                                            .stroke(DesignColors.primary.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
            }
        }
    }

    private var scanLineOverlay: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                let height = max(geo.size.height, 1)
                let offset = CGFloat(Int(timeline.date.timeIntervalSince1970 * 50) % Int(height))
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, DesignColors.primary.opacity(0.08), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 80)
                    .offset(y: offset)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Actions

    private func handleTap() {
        guard !allDecrypted, isViewActive else { return }
        handleCardTap(index: currentItemIndex)
    }

    private func handleCardTap(index: Int) {
        guard index == currentItemIndex, !allDecrypted, isViewActive else { return }
        guard itemDecryptProgress.indices.contains(index) else { return }

        // Cancel auto-advance
        autoAdvanceTimer?.invalidate()

        // Increment progress
        itemDecryptProgress[index] += 1

        // Haptic feedback
        if itemDecryptProgress[index] < tapsRequired {
            HapticsService.shared.play(.light)
        }

        // Glitch effect
        withAnimation(.easeInOut(duration: 0.05)) {
            glitchOffset = CGFloat.random(in: BalanceConfig.BossLootReveal.glitchOffsetRange)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [self] in
            guard isViewActive else { return }
            withAnimation(.easeOut(duration: 0.1)) {
                glitchOffset = 0
            }
        }

        // Check for item completion
        if itemDecryptProgress[index] >= tapsRequired {
            completeItemReveal(index: index)
        } else {
            startAutoAdvanceTimer()
        }
    }

    private func completeItemReveal(index: Int) {
        guard isViewActive else { return }

        // Mark as revealed
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            revealedItems.insert(index)
        }

        // Haptic based on item type
        let item = reward.items[index]
        switch item.type {
        case .hash:
            HapticsService.shared.play(.medium)
        case .protocolBlueprint(_, let rarity):
            switch rarity {
            case .legendary: HapticsService.shared.play(.legendary)
            case .epic: HapticsService.shared.play(.heavy)
            default: HapticsService.shared.play(.medium)
            }
        case .sectorAccess:
            HapticsService.shared.play(.success)
        }

        // Move to next item or complete
        DispatchQueue.main.asyncAfter(deadline: .now() + BalanceConfig.BossLootReveal.revealDelay) { [self] in
            guard isViewActive else { return }

            if currentItemIndex < reward.items.count - 1 {
                currentItemIndex += 1
                startAutoAdvanceTimer()
            } else {
                // All items revealed
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    allDecrypted = true
                }
                HapticsService.shared.play(.success)

                // Delay before COLLECT becomes tappable so the player can see the last reward
                DispatchQueue.main.asyncAfter(deadline: .now() + BalanceConfig.BossLootReveal.collectButtonDelay) { [self] in
                    guard isViewActive else { return }
                    withAnimation(.easeIn(duration: 0.25)) {
                        collectReady = true
                    }
                }
            }
        }
    }

    private func startAutoAdvanceTimer() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: BalanceConfig.BossLootReveal.autoAdvanceDelay, repeats: false) { [self] _ in
            guard isViewActive, !allDecrypted, currentItemIndex < reward.items.count else { return }
            handleCardTap(index: currentItemIndex)
        }
    }
}

// MARK: - Data Packet Card

struct DataPacketCard: View {
    let item: BossLootReward.RewardItem
    let index: Int
    let decryptProgress: Int
    let tapsRequired: Int
    let isRevealed: Bool
    let isActive: Bool
    let onTap: () -> Void

    @State private var glowPulse: Bool = false

    private var itemColor: Color {
        Color(hex: item.displayColor) ?? .cyan
    }

    private var progressRatio: CGFloat {
        CGFloat(decryptProgress) / CGFloat(tapsRequired)
    }

    var body: some View {
        ZStack {
            // Glow background
            RoundedRectangle(cornerRadius: 12)
                .fill(itemColor.opacity(isRevealed ? 0.2 : 0.1 * Double(decryptProgress + 1)))
                .frame(width: 100, height: 140)
                .blur(radius: 20)
                .scaleEffect(glowPulse && isActive ? 1.1 : 1.0)

            // Card background
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "0d1117") ?? Color.black)
                .frame(width: 90, height: 130)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isRevealed ? itemColor : (isActive ? DesignColors.primary : Color.gray.opacity(0.3)),
                            lineWidth: isRevealed ? 2 : 1
                        )
                )
                .shadow(color: isRevealed ? itemColor.opacity(0.4) : .clear, radius: 10)

            // Content
            VStack(spacing: 8) {
                if isRevealed {
                    revealedContent
                } else {
                    encryptedContent
                }
            }
            .frame(width: 90, height: 130)
        }
        .scaleEffect(isRevealed ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRevealed)
        .onTapGesture {
            onTap()
        }
        .onAppear {
            if isActive {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    glowPulse = true
                }
            }
        }
        .onChange(of: isActive) { active in
            if active {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    glowPulse = true
                }
            }
        }
    }

    private var encryptedContent: some View {
        VStack(spacing: 12) {
            // Encrypted icon
            ZStack {
                Circle()
                    .fill(itemColor.opacity(0.15))
                    .frame(width: 50, height: 50)

                if decryptProgress > 0 {
                    Image(systemName: item.iconName)
                        .font(.system(size: 24))
                        .foregroundColor(itemColor.opacity(progressRatio))
                        .blur(radius: CGFloat(tapsRequired - decryptProgress) * 2)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20))
                        .foregroundColor(DesignColors.muted)
                }
            }

            // Encrypted text
            Text(garbledText)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(itemColor.opacity(0.5 + progressRatio * 0.3))
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // Progress bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "1a1a24") ?? Color.gray)
                    .frame(width: 70, height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(itemColor)
                    .frame(width: 70 * progressRatio, height: 4)
            }
        }
        .padding(8)
    }

    private var revealedContent: some View {
        VStack(spacing: 8) {
            // Icon
            ZStack {
                Circle()
                    .fill(itemColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: item.iconName)
                    .font(.system(size: 26))
                    .foregroundColor(itemColor)
                    .shadow(color: itemColor, radius: 8)
            }

            // Title
            Text(item.decryptedTitle)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // Subtitle
            Text(item.decryptedSubtitle)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(itemColor)
                .lineLimit(1)
        }
        .padding(8)
    }

    private var garbledText: String {
        let garbleChars = ["▓", "░", "█", "▒"]
        return (0..<8).map { garbleChars[$0 % garbleChars.count] }.joined()
    }
}

// MARK: - Preview

#Preview {
    BossLootModal(
        reward: BossLootReward.create(
            difficulty: .hard,
            hashReward: 5000,
            protocolId: "burst_protocol",
            protocolRarity: .epic,
            unlockedSector: (id: "ram", name: "RAM Banks", themeColor: "#4488ff"),
            isFirstKill: true
        ),
        onCollect: {}
    )
}
