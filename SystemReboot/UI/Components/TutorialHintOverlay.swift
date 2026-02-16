import SwiftUI

// MARK: - Tutorial Hint Types

enum TutorialHintType: String, CaseIterable {
    case deckCard = "deck_card_hint"           // Glow on first protocol card in deck
    case towerSlot = "tower_slot_hint"         // Ghost preview on optimal placement slot
    case psuUpgrade = "psu_upgrade_hint"       // Pulse on PSU upgrade button
    case bossTab = "boss_tab_hint"             // "NEW" badge on boss tab

    var autoFadeDelay: TimeInterval {
        30.0  // All hints fade after 30 seconds if not interacted with
    }
}

// MARK: - Tutorial Hint Manager

class TutorialHintManager: ObservableObject {
    static let shared = TutorialHintManager()

    @Published var activeHints: Set<TutorialHintType> = []

    // MARK: - Unseen Blueprints (pulse until viewed in Arsenal)

    private static let unseenBlueprintsKey = "unseenBlueprintIds"

    @Published var unseenBlueprintIds: Set<String> = []

    var hasUnseenBlueprints: Bool { !unseenBlueprintIds.isEmpty }

    private init() {
        // Restore unseen blueprints from UserDefaults
        if let saved = UserDefaults.standard.array(forKey: Self.unseenBlueprintsKey) as? [String] {
            unseenBlueprintIds = Set(saved)
        }
    }

    func addUnseenBlueprint(_ protocolId: String) {
        unseenBlueprintIds.insert(protocolId)
        persistUnseenBlueprints()
    }

    func markBlueprintSeen(_ protocolId: String) {
        unseenBlueprintIds.remove(protocolId)
        persistUnseenBlueprints()
    }

    private func persistUnseenBlueprints() {
        UserDefaults.standard.set(Array(unseenBlueprintIds), forKey: Self.unseenBlueprintsKey)
    }

    /// Check if a hint should be shown (not seen before and is active)
    func shouldShowHint(_ hint: TutorialHintType, profile: PlayerProfile) -> Bool {
        guard !profile.tutorialHintsSeen.contains(hint.rawValue) else { return false }
        return activeHints.contains(hint)
    }

    /// Activate a hint (make it visible)
    func activateHint(_ hint: TutorialHintType) {
        guard !activeHints.contains(hint) else { return }
        activeHints.insert(hint)

        // Auto-fade after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + hint.autoFadeDelay) { [weak self] in
            self?.deactivateHint(hint)
        }
    }

    /// Deactivate a hint (hide it)
    func deactivateHint(_ hint: TutorialHintType) {
        activeHints.remove(hint)
    }

    /// Mark a hint as seen (permanently dismissed)
    func markHintSeen(_ hint: TutorialHintType) {
        deactivateHint(hint)
        // The actual persistence happens through AppState.updatePlayer
    }
}

// MARK: - Glow Pulse Modifier

struct GlowPulseModifier: ViewModifier {
    let color: Color
    let isActive: Bool

    @State private var glowIntensity: CGFloat = 0.3

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color, lineWidth: 2)
                    .blur(radius: 4)
                    .opacity(isActive ? glowIntensity : 0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.6), lineWidth: 1)
                    .opacity(isActive ? 1 : 0)
            )
            .onAppear {
                if isActive {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        glowIntensity = 0.8
                    }
                }
            }
    }
}

extension View {
    func tutorialGlow(color: Color = DesignColors.primary, isActive: Bool) -> some View {
        modifier(GlowPulseModifier(color: color, isActive: isActive))
    }
}

// MARK: - Ghost Tower Preview

struct GhostTowerPreview: View {
    let isVisible: Bool
    let position: CGPoint
    let size: CGSize

    @State private var opacity: Double = 0.3

    var body: some View {
        if isVisible {
            ZStack {
                // Ghost tower shape
                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignColors.primary.opacity(0.1))
                    .frame(width: size.width, height: size.height)

                // Tower icon
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: size.width * 0.4))
                    .foregroundColor(DesignColors.primary.opacity(opacity))

                // Dashed border
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                    )
                    .foregroundColor(DesignColors.primary.opacity(opacity))
                    .frame(width: size.width, height: size.height)
            }
            .position(position)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    opacity = 0.7
                }
            }
        }
    }
}

// MARK: - "NEW" Badge

struct NewBadge: View {
    let isVisible: Bool

    @State private var scale: CGFloat = 1.0

    var body: some View {
        if isVisible {
            Text(L10n.UI.newBadge)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(DesignColors.danger)
                )
                .scaleEffect(scale)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        scale = 1.15
                    }
                }
        }
    }
}

// MARK: - Pulse Ring Effect

struct PulseRingEffect: View {
    let color: Color
    let isActive: Bool

    @State private var ringScale: CGFloat = 1.0
    @State private var ringOpacity: Double = 0.6

    var body: some View {
        if isActive {
            Circle()
                .stroke(color, lineWidth: 2)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)
                .onAppear {
                    withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                        ringScale = 1.8
                        ringOpacity = 0
                    }
                }
        }
    }
}

// MARK: - Tutorial Hint Overlay Container

struct TutorialHintOverlay: View {
    @ObservedObject var hintManager = TutorialHintManager.shared
    let profile: PlayerProfile

    // Customizable hint positions and visibility
    var deckCardFrame: CGRect?
    var towerSlotPosition: CGPoint?
    var towerSlotSize: CGSize = CGSize(width: 60, height: 60)

    var body: some View {
        ZStack {
            // Ghost tower slot preview
            if let position = towerSlotPosition,
               hintManager.shouldShowHint(.towerSlot, profile: profile) {
                GhostTowerPreview(
                    isVisible: true,
                    position: position,
                    size: towerSlotSize
                )
            }
        }
        .allowsHitTesting(false)  // Don't block interactions
    }
}

// MARK: - Deck Card Hint Wrapper

struct DeckCardWithHint<Content: View>: View {
    let isFirstCard: Bool
    let profile: PlayerProfile
    let content: Content

    @ObservedObject private var hintManager = TutorialHintManager.shared

    init(isFirstCard: Bool, profile: PlayerProfile, @ViewBuilder content: () -> Content) {
        self.isFirstCard = isFirstCard
        self.profile = profile
        self.content = content()
    }

    var body: some View {
        content
            .tutorialGlow(
                color: DesignColors.primary,
                isActive: isFirstCard && hintManager.shouldShowHint(.deckCard, profile: profile)
            )
    }
}

// MARK: - Preview

#Preview("Glow Pulse") {
    VStack(spacing: 40) {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(hex: "0d1117") ?? Color.black)
            .frame(width: 100, height: 140)
            .tutorialGlow(color: DesignColors.primary, isActive: true)

        Text("Tutorial Hint Active")
            .foregroundColor(.white)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
}

#Preview("Ghost Tower") {
    ZStack {
        Color.black.ignoresSafeArea()

        GhostTowerPreview(
            isVisible: true,
            position: CGPoint(x: 200, y: 400),
            size: CGSize(width: 60, height: 60)
        )
    }
}

#Preview("NEW Badge") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            HStack {
                Text("BOSS")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                NewBadge(isVisible: true)
            }
        }
    }
}
