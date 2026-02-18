import SwiftUI

// MARK: - Intro Sequence View
// First-time user experience: 3-card story-driven intro
// Terminal/hacker aesthetic matching the game theme

struct IntroSequenceView: View {
    let onComplete: () -> Void

    // MARK: - State

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var currentCard: Int = 0
    @State private var showContent = false
    @State private var typewriterText: String = ""
    @State private var hashFlowOffset: CGFloat = 0
    @State private var virusOffset: CGFloat = -200
    @State private var pulseScale: CGFloat = 1.0
    @State private var scanLineOffset: CGFloat = 0
    @State private var glitchOffset: CGFloat = 0

    private let totalCards = 3

    private var scale: CGFloat {
        DesignLayout.adaptiveScale(for: sizeClass)
    }

    // MARK: - Card Data

    private struct IntroCard {
        let header: String
        let lines: [String]
        let icon: String
        let accentColor: Color
    }

    private var cards: [IntroCard] {
        [
            IntroCard(
                header: L10n.Intro.SystemBoot.header,
                lines: [
                    L10n.Intro.SystemBoot.line1,
                    "",
                    L10n.Intro.SystemBoot.line2,
                    L10n.Intro.SystemBoot.line3,
                    L10n.Intro.SystemBoot.line4
                ],
                icon: "cpu.fill",
                accentColor: DesignColors.primary
            ),
            IntroCard(
                header: L10n.Intro.ThreatDetected.header,
                lines: [
                    L10n.Intro.ThreatDetected.line1,
                    "",
                    L10n.Intro.ThreatDetected.line2,
                    L10n.Intro.ThreatDetected.line3,
                    "",
                    L10n.Intro.ThreatDetected.line4
                ],
                icon: "shield.lefthalf.filled",
                accentColor: DesignColors.danger
            ),
            IntroCard(
                header: L10n.Intro.AlwaysRunning.header,
                lines: [
                    L10n.Intro.AlwaysRunning.line1,
                    "",
                    L10n.Intro.AlwaysRunning.line2,
                    L10n.Intro.AlwaysRunning.line3,
                    L10n.Intro.AlwaysRunning.line4,
                    "",
                    L10n.Intro.AlwaysRunning.line5
                ],
                icon: "clock.badge.checkmark.fill",
                accentColor: DesignColors.success
            )
        ]
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            // Scan line effect
            scanLineOverlay

            // Card content
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button(action: skipIntro) {
                        Text(L10n.Intro.skip)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(DesignColors.muted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .accessibilityLabel("Skip introduction")
                }
                .padding(.top, 16)
                .padding(.horizontal, 20)

                Spacer()

                // Main card content
                cardContent
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)

                Spacer()

                // Navigation
                navigationSection
                    .padding(.bottom, 50)
            }
        }
        .onAppear {
            startCardAnimation()
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -50 {
                        nextCard()
                    } else if value.translation.width > 50 {
                        previousCard()
                    }
                }
        )
    }

    // MARK: - Card Content

    @ViewBuilder
    private var cardContent: some View {
        let card = cards[currentCard]

        VStack(spacing: 32) {
            // Header with glitch effect
            Text(card.header)
                .font(.system(size: 28 * scale, weight: .black, design: .monospaced))
                .foregroundColor(card.accentColor)
                .shadow(color: card.accentColor.opacity(0.8), radius: 10)
                .offset(x: glitchOffset)

            // Visual element based on card
            cardVisual(for: currentCard, color: card.accentColor)
                .frame(height: 140 * scale)

            // Typewriter text
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(card.lines.enumerated()), id: \.offset) { index, line in
                    Text(line)
                        .font(.system(size: 16 * scale, weight: line.hasPrefix(">") ? .bold : .regular, design: .monospaced))
                        .foregroundColor(line.hasPrefix(">") ? card.accentColor : .white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Card Visuals

    @ViewBuilder
    private func cardVisual(for index: Int, color: Color) -> some View {
        switch index {
        case 0:
            // CPU with Hash flowing out
            cpuVisual(color: color)
        case 1:
            // Viruses attacking
            virusVisual(color: color)
        case 2:
            // Offline earning visualization
            offlineVisual(color: color)
        default:
            EmptyView()
        }
    }

    private func cpuVisual(color: Color) -> some View {
        ZStack {
            // Glow background
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 120 * scale, height: 120 * scale)
                .blur(radius: 20)
                .scaleEffect(pulseScale)

            // CPU icon
            Image(systemName: "cpu.fill")
                .font(.system(size: 60 * scale))
                .foregroundColor(color)
                .shadow(color: color, radius: 15)

            // Hash symbols flowing out
            ForEach(0..<6, id: \.self) { i in
                let angle = Double(i) * 60 * .pi / 180
                let distance: CGFloat = 60 + hashFlowOffset

                Text("\u{0126}")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(color.opacity(Double(max(0, 1 - hashFlowOffset / 40))))
                    .offset(
                        x: cos(angle) * distance,
                        y: sin(angle) * distance
                    )
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                hashFlowOffset = 40
            }
        }
    }

    private func virusVisual(color: Color) -> some View {
        ZStack {
            // CPU being attacked
            Image(systemName: "cpu.fill")
                .font(.system(size: 50))
                .foregroundColor(DesignColors.primary.opacity(0.5))
                .offset(x: 60)

            // Warning flash
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
                .frame(width: 200 * scale, height: 100 * scale)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.4), lineWidth: 1)
                )
                .scaleEffect(pulseScale)

            // Viruses approaching
            HStack(spacing: 20) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: "ladybug.fill")
                        .font(.system(size: 28))
                        .foregroundColor(color)
                        .shadow(color: color, radius: 8)
                        .offset(x: virusOffset + CGFloat(i) * 15)
                }
            }
            .offset(x: -30)

            // Shield icon (defense)
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 36))
                .foregroundColor(DesignColors.primary)
                .offset(x: 20)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                virusOffset = -160
            }
        }
    }

    private func offlineVisual(color: Color) -> some View {
        HStack(spacing: 30) {
            // Phone sleeping
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(DesignColors.surface)
                        .frame(width: 50 * scale, height: 80 * scale)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(DesignColors.muted, lineWidth: 1)
                        )

                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 24))
                        .foregroundColor(DesignColors.secondary)
                }

                Text(L10n.Intro.offline)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignColors.muted)
            }

            // Arrow
            Image(systemName: "arrow.right")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color.opacity(0.6))

            // Hash accumulating
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.15))
                        .frame(width: 80 * scale, height: 80 * scale)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(color.opacity(0.4), lineWidth: 1)
                        )

                    VStack(spacing: 4) {
                        Text("+\u{0126}")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(color)

                        Text(L10n.Intro.operatingHours)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(color.opacity(0.7))
                    }
                    .scaleEffect(pulseScale)
                }

                Text(L10n.Intro.earning)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
            }
        }
    }

    // MARK: - Navigation Section

    private var navigationSection: some View {
        VStack(spacing: 20) {
            // Page dots
            HStack(spacing: 10) {
                ForEach(0..<totalCards, id: \.self) { index in
                    Circle()
                        .fill(index == currentCard ? cards[currentCard].accentColor : DesignColors.muted)
                        .frame(width: 10, height: 10)
                        .scaleEffect(index == currentCard ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3), value: currentCard)
                }
            }

            // Action button
            if currentCard == totalCards - 1 {
                // Final card - Enter button
                Button(action: completeIntro) {
                    HStack(spacing: 10) {
                        Image(systemName: "power")
                        Text(L10n.Intro.enterSystem)
                    }
                    .font(.system(size: 16 * scale, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .frame(width: 220 * scale, height: 54 * scale)
                    .background(DesignColors.primary)
                    .cornerRadius(12)
                    .shadow(color: DesignColors.primary.opacity(0.5), radius: 15)
                }
            } else {
                // Swipe hint
                Text(L10n.Intro.swipeHint)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(DesignColors.muted)
                    .onTapGesture {
                        nextCard()
                    }
            }
        }
    }

    // MARK: - Scan Line Overlay

    private var scanLineOverlay: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, DesignColors.primary.opacity(0.08), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 150)
                .offset(y: scanLineOffset)
                .onAppear {
                    withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                        scanLineOffset = geo.size.height
                    }
                }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Actions

    private func startCardAnimation() {
        showContent = false
        hashFlowOffset = 0
        virusOffset = -200
        pulseScale = 1.0

        // Glitch effect on card transition
        withAnimation(.easeInOut(duration: 0.05)) {
            glitchOffset = CGFloat.random(in: -8...8)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.1)) {
                glitchOffset = 0
            }
        }

        // Fade in content
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
            showContent = true
        }

        HapticsService.shared.play(.selection)
    }

    private func nextCard() {
        guard currentCard < totalCards - 1 else { return }
        currentCard += 1
        startCardAnimation()
    }

    private func previousCard() {
        guard currentCard > 0 else { return }
        currentCard -= 1
        startCardAnimation()
    }

    private func skipIntro() {
        HapticsService.shared.play(.selection)
        completeIntro()
    }

    private func completeIntro() {
        HapticsService.shared.play(.success)

        withAnimation(.easeOut(duration: 0.3)) {
            showContent = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onComplete()
        }
    }
}

// MARK: - Preview

#Preview {
    IntroSequenceView(onComplete: {})
}
