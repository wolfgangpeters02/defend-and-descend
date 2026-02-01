import SwiftUI

// MARK: - Blueprint Reveal Modal
// 4-tap "decoding" experience for blueprint drops
// Terminal/hacker aesthetic with progressive reveal

struct BlueprintRevealModal: View {
    let protocolId: String
    let isFirstKill: Bool
    let onDismiss: () -> Void

    // MARK: - State

    @State private var decodeProgress: Int = 0  // 0-4 taps
    @State private var isRevealed = false
    @State private var showParticles = false
    @State private var glitchOffset: CGFloat = 0
    @State private var scanLineOffset: CGFloat = 0
    @State private var rarityFlickerIndex: Int = 0
    @State private var autoAdvanceTimer: Timer?

    // Animation states
    @State private var cardScale: CGFloat = 0.8
    @State private var cardOpacity: Double = 0
    @State private var glowPulse: Bool = false

    // Lifecycle flag - prevents crashes from async callbacks after dismiss
    @State private var isViewActive = true

    // Extra celebration effects
    @State private var showCelebration = false
    @State private var screenFlashOpacity: Double = 0
    @State private var celebrationScale: CGFloat = 1.0

    // MARK: - Computed Properties

    private var protocolData: Protocol? {
        ProtocolLibrary.get(protocolId)
    }

    private var actualRarity: Rarity {
        protocolData?.rarity ?? .common
    }

    private var displayedRarity: Rarity {
        // During decode, flicker through rarities up to actual
        if isRevealed {
            return actualRarity
        }
        let rarities: [Rarity] = [.common, .rare, .epic, .legendary]
        let maxIndex = rarities.firstIndex(of: actualRarity) ?? 0
        let flickerIndex = min(rarityFlickerIndex, maxIndex)
        return rarities[flickerIndex]
    }

    private var rarityColor: Color {
        RarityColors.color(for: displayedRarity)
    }

    private var protocolColor: Color {
        guard let proto = protocolData else { return .cyan }
        return Color(hex: proto.color) ?? .cyan
    }

    private var decodePercentage: Int {
        min(decodeProgress * 25, 100)
    }

    private var progressBarWidth: CGFloat {
        CGFloat(decodeProgress) / 4.0 * 200
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

            // Scan line effect (moving down)
            scanLineOverlay

            // Background data streams
            dataStreamBackground

            // Main content
            VStack(spacing: 24) {
                // Header
                headerView

                // The card being decoded
                decodingCard

                // Progress section
                progressSection

                // Instruction or collect button
                bottomSection
            }
            .padding(24)

            // Particle burst on reveal
            if showParticles {
                ParticleBurstView(color: rarityColor)
            }

            // Celebration confetti for epic/legendary
            if showCelebration {
                CelebrationBurstView(rarity: actualRarity)
            }

            // Screen flash on reveal
            if screenFlashOpacity > 0 {
                Color.white
                    .opacity(screenFlashOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            isViewActive = true
            startRevealSequence()
        }
        .onDisappear {
            // Mark view as inactive to prevent async callback crashes
            isViewActive = false
            autoAdvanceTimer?.invalidate()
            autoAdvanceTimer = nil
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 8) {
            // Glitchy title
            Text(isRevealed ? L10n.Blueprint.decryptionComplete : L10n.Blueprint.dataFragmentFound)
                .font(.system(size: 24, weight: .black, design: .monospaced))
                .foregroundColor(isRevealed ? rarityColor : DesignColors.primary)
                .shadow(color: (isRevealed ? rarityColor : DesignColors.primary).opacity(0.8), radius: 10)
                .offset(x: glitchOffset)

            if isFirstKill && !isRevealed {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                    Text(L10n.Blueprint.firstKillBonus)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                }
                .foregroundColor(.yellow)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
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

    private var decodingCard: some View {
        ZStack {
            // Outer glow (intensifies with progress)
            RoundedRectangle(cornerRadius: 16)
                .fill(rarityColor.opacity(0.1 + Double(decodeProgress) * 0.05))
                .frame(width: 220, height: 280)
                .blur(radius: 30)
                .scaleEffect(glowPulse ? 1.1 : 1.0)

            // Card background
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "0d1117") ?? Color.black)
                .frame(width: 200, height: 260)
                .overlay(
                    // Circuit pattern overlay
                    CircuitPatternView()
                        .opacity(0.1)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                )
                .overlay(
                    // Rarity border
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            rarityColor.opacity(isRevealed ? 1.0 : 0.3 + Double(decodeProgress) * 0.2),
                            lineWidth: isRevealed ? 3 : 2
                        )
                )
                .shadow(color: rarityColor.opacity(0.3 + Double(decodeProgress) * 0.1), radius: 20)

            // Card content
            VStack(spacing: 16) {
                if isRevealed, let proto = protocolData {
                    // Fully revealed content
                    revealedContent(proto)
                } else {
                    // Decoding content
                    decodingContent
                }
            }
            .frame(width: 200, height: 260)
        }
        .scaleEffect(cardScale)
        .opacity(cardOpacity)
        .offset(x: isRevealed ? 0 : glitchOffset * 0.5)
    }

    private var decodingContent: some View {
        VStack(spacing: 20) {
            // Encrypted icon placeholder
            ZStack {
                // Glitchy background
                Circle()
                    .fill(rarityColor.opacity(0.15))
                    .frame(width: 80, height: 80)

                // Progressive reveal of icon
                if decodeProgress >= 2, let proto = protocolData {
                    Image(systemName: proto.iconName)
                        .font(.system(size: 40))
                        .foregroundColor(rarityColor.opacity(Double(decodeProgress - 1) * 0.4))
                        .blur(radius: CGFloat(4 - decodeProgress))
                } else {
                    // Encrypted placeholder
                    Image(systemName: "questionmark.square.dashed")
                        .font(.system(size: 40))
                        .foregroundColor(DesignColors.muted)
                }

                // Scan line across icon
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, rarityColor.opacity(0.5), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 80, height: 3)
                    .offset(y: scanLineOffset - 40)
                    .clipShape(Circle())
            }

            // Protocol name (garbled → clear)
            Text(garbledName)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5 + Double(decodeProgress) * 0.15))
                .lineLimit(1)

            // Rarity indicator
            Text(displayedRarity.rawValue.uppercased())
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(rarityColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(rarityColor.opacity(0.2))
                        .overlay(
                            Capsule()
                                .stroke(rarityColor.opacity(0.4), lineWidth: 1)
                        )
                )

            // Decryption progress visual
            VStack(spacing: 4) {
                Text(L10n.Blueprint.decrypting)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(DesignColors.muted)

                // Binary/hex gibberish
                Text(hexString)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(DesignColors.primary.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .padding(20)
    }

    private func revealedContent(_ proto: Protocol) -> some View {
        VStack(spacing: 12) {
            // Icon with glow
            ZStack {
                Circle()
                    .fill(rarityColor.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: proto.iconName)
                    .font(.system(size: 44))
                    .foregroundColor(protocolColor)
                    .shadow(color: protocolColor, radius: 15)
            }

            // Name
            Text(proto.name)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            // Rarity badge
            Text(proto.rarity.rawValue.uppercased())
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(rarityColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(rarityColor.opacity(0.25))
                        .overlay(
                            Capsule()
                                .stroke(rarityColor, lineWidth: 1.5)
                        )
                )

            // Quick stats
            HStack(spacing: 20) {
                statPill(icon: "bolt.fill", value: "\(Int(proto.firewallBaseStats.damage))", label: L10n.Stats.dmg)
                statPill(icon: "scope", value: "\(Int(proto.firewallBaseStats.range))", label: L10n.Stats.rng)
            }
            .padding(.top, 4)
        }
        .padding(16)
    }

    private func statPill(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(protocolColor.opacity(0.8))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(DesignColors.muted)
        }
    }

    private var progressSection: some View {
        VStack(spacing: 8) {
            // Progress bar
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: "1a1a24") ?? Color.gray)
                    .frame(width: 200, height: 8)

                // Progress fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [rarityColor.opacity(0.8), rarityColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: progressBarWidth, height: 8)
                    .animation(.easeOut(duration: 0.2), value: decodeProgress)

                // Glow on progress
                RoundedRectangle(cornerRadius: 4)
                    .fill(rarityColor)
                    .frame(width: progressBarWidth, height: 8)
                    .blur(radius: 4)
                    .opacity(0.5)
            }

            // Percentage
            Text(L10n.Blueprint.percentDecoded(decodePercentage))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(isRevealed ? rarityColor : DesignColors.muted)
        }
        .opacity(isRevealed ? 0 : 1)
    }

    private var bottomSection: some View {
        Group {
            if isRevealed {
                // Collect button
                Button(action: {
                    HapticsService.shared.play(.selection)
                    onDismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text(L10n.Common.collect)
                    }
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .frame(width: 180, height: 50)
                    .background(rarityColor)
                    .cornerRadius(10)
                    .shadow(color: rarityColor.opacity(0.5), radius: 10)
                }
            } else {
                // Tap instruction
                VStack(spacing: 4) {
                    Text(L10n.Blueprint.tapToDecode)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignColors.primary)

                    // Tap indicators
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .fill(index < decodeProgress ? rarityColor : Color(hex: "2a2a34") ?? Color.gray)
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Circle()
                                        .stroke(rarityColor.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
    }

    private var scanLineOverlay: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, DesignColors.primary.opacity(0.1), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 100)
                .offset(y: scanLineOffset * 3)
                .onAppear {
                    withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                        scanLineOffset = geo.size.height / 3
                    }
                }
        }
        .allowsHitTesting(false)
    }

    private var dataStreamBackground: some View {
        GeometryReader { geo in
            ForEach(0..<8, id: \.self) { index in
                DataStreamLine(
                    height: geo.size.height,
                    delay: Double(index) * 0.15,
                    color: rarityColor.opacity(0.15)
                )
                .offset(x: CGFloat(index) * (geo.size.width / 8) + 20)
            }
        }
        .allowsHitTesting(false)
        .opacity(isRevealed ? 0.3 : 0.6)
    }

    // MARK: - Helper Properties

    private var garbledName: String {
        guard let proto = protocolData else { return "????????" }
        let name = proto.name
        let revealCount = Int(Double(name.count) * Double(decodeProgress) / 4.0)

        // Use deterministic garble chars based on character index
        let garbleChars = ["#", "@", "%", "&", "?", "*"]
        var result = ""
        for (index, char) in name.enumerated() {
            if index < revealCount {
                result.append(char)
            } else if char == " " {
                result.append(" ")
            } else {
                // Deterministic based on index
                result.append(garbleChars[index % garbleChars.count])
            }
        }
        return result
    }

    private var hexString: String {
        // Fixed hex string that looks random but is stable
        "0x4F7A2B9E1C3D8F6A"
    }

    // MARK: - Actions

    private func handleTap() {
        guard !isRevealed, isViewActive else { return }

        // Cancel auto-advance timer
        autoAdvanceTimer?.invalidate()

        // Advance decode progress
        decodeProgress += 1

        // Haptic feedback - escalate intensity with progress
        switch decodeProgress {
        case 1: HapticsService.shared.play(.light)
        case 2: HapticsService.shared.play(.medium)
        case 3: HapticsService.shared.play(.heavy)
        case 4: HapticsService.shared.play(.legendary)
        default: break
        }

        // Glitch effect
        withAnimation(.easeInOut(duration: 0.05)) {
            glitchOffset = CGFloat.random(in: -5...5)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [self] in
            guard isViewActive else { return }
            withAnimation(.easeOut(duration: 0.1)) {
                glitchOffset = 0
            }
        }

        // Flicker rarity (for suspense)
        if decodeProgress < 4 {
            flickerRarity()
            startAutoAdvanceTimer()
        }

        // Check for completion
        if decodeProgress >= 4 {
            completeReveal()
        }
    }

    private func flickerRarity() {
        // Quick flicker through rarities for suspense
        let maxIndex = [Rarity.common, .rare, .epic, .legendary].firstIndex(of: actualRarity) ?? 0

        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) { [self] in
                guard isViewActive else { return }
                rarityFlickerIndex = Int.random(in: 0...maxIndex)
            }
        }

        // Settle on progress-appropriate rarity
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [self] in
            guard isViewActive else { return }
            let progressRatio = Double(decodeProgress) / 4.0
            rarityFlickerIndex = min(Int(Double(maxIndex) * progressRatio), maxIndex)
        }
    }

    private func completeReveal() {
        guard isViewActive else { return }

        // Screen flash for dramatic effect
        withAnimation(.easeOut(duration: 0.1)) {
            screenFlashOpacity = actualRarity == .legendary ? 0.8 : 0.4
        }

        // Final reveal animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isRevealed = true
            cardScale = 1.1
        }

        // Particle burst
        showParticles = true

        // Celebration effect for higher rarities
        if actualRarity == .epic || actualRarity == .legendary {
            showCelebration = true
        }

        // Flash fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            guard isViewActive else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                screenFlashOpacity = 0
            }
        }

        // Scale bounce sequence
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
            guard isViewActive else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                cardScale = 0.95
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [self] in
            guard isViewActive else { return }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                cardScale = 1.0
            }
        }

        // Extra haptic feedback based on rarity
        switch actualRarity {
        case .legendary:
            // Triple haptic burst for legendary
            HapticsService.shared.play(.legendary)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
                guard isViewActive else { return }
                HapticsService.shared.play(.heavy)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
                guard isViewActive else { return }
                HapticsService.shared.play(.legendary)
            }
        case .epic:
            // Double haptic for epic
            HapticsService.shared.play(.legendary)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
                guard isViewActive else { return }
                HapticsService.shared.play(.heavy)
            }
        case .rare:
            HapticsService.shared.play(.heavy)
        default:
            HapticsService.shared.play(.medium)
        }
    }

    private func startRevealSequence() {
        // Initial card animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            cardScale = 1.0
            cardOpacity = 1.0
        }

        // Start glow pulse
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            glowPulse = true
        }

        // Start auto-advance timer for slow players
        startAutoAdvanceTimer()
    }

    private func startAutoAdvanceTimer() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [self] _ in
            guard isViewActive, !isRevealed, decodeProgress < 4 else { return }
            handleTap()
        }
    }
}

// MARK: - Supporting Views

/// Vertical data stream animation
struct DataStreamLine: View {
    let height: CGFloat
    let delay: Double
    let color: Color

    @State private var offset: CGFloat = -100

    // Pre-generate stable binary string
    private let binaryChars: [String] = (0..<20).map { _ in
        ["0", "1"].randomElement()!
    }

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<binaryChars.count, id: \.self) { index in
                Text(binaryChars[index])
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(color)
            }
        }
        .offset(y: offset)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                    offset = height + 100
                }
            }
        }
    }
}

/// Circuit board pattern for card background
struct CircuitPatternView: View {
    var body: some View {
        Canvas { context, size in
            // Draw circuit-like pattern with deterministic placement
            let gridSize: CGFloat = 20

            var cellIndex = 0
            for x in stride(from: 0, to: size.width, by: gridSize) {
                for y in stride(from: 0, to: size.height, by: gridSize) {
                    // Deterministic based on cell position
                    let hash = cellIndex * 7 + Int(x) * 3 + Int(y) * 11

                    // Circuit nodes at every 4th cell (deterministic)
                    if hash % 4 == 0 {
                        let rect = CGRect(x: x + 8, y: y + 8, width: 4, height: 4)
                        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.3)))
                    }

                    // Horizontal traces (deterministic)
                    if hash % 6 == 1 {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: y + 10))
                        path.addLine(to: CGPoint(x: x + gridSize, y: y + 10))
                        context.stroke(path, with: .color(.white.opacity(0.15)), lineWidth: 1)
                    }

                    // Vertical traces (deterministic)
                    if hash % 6 == 2 {
                        var path = Path()
                        path.move(to: CGPoint(x: x + 10, y: y))
                        path.addLine(to: CGPoint(x: x + 10, y: y + gridSize))
                        context.stroke(path, with: .color(.white.opacity(0.15)), lineWidth: 1)
                    }

                    cellIndex += 1
                }
            }
        }
    }
}

/// Particle burst effect on reveal - enhanced for more impact
struct ParticleBurstView: View {
    let color: Color

    @State private var animate = false

    // Pre-generate stable particle data - more particles for dramatic effect
    private let particleData: [ParticleData] = (0..<35).map { _ in
        let angle = Double.random(in: 0...(2 * .pi))
        let distance = CGFloat.random(in: 80...220)
        return ParticleData(
            angle: angle,
            distance: distance,
            scale: CGFloat.random(in: 0.6...2.0),
            rotation: Double.random(in: 0...360),
            rotationEnd: Double.random(in: 180...540),
            icon: ["sparkle", "star.fill", "circle.fill", "square.fill"].randomElement()!,
            delay: Double.random(in: 0...0.1)
        )
    }

    struct ParticleData {
        let angle: Double
        let distance: CGFloat
        let scale: CGFloat
        let rotation: Double
        let rotationEnd: Double
        let icon: String
        let delay: Double
    }

    var body: some View {
        GeometryReader { geo in
            let centerX = geo.size.width / 2
            let centerY = geo.size.height / 2

            ZStack {
                ForEach(0..<particleData.count, id: \.self) { index in
                    let data = particleData[index]
                    let endX = centerX + cos(data.angle) * data.distance
                    let endY = centerY + sin(data.angle) * data.distance

                    Image(systemName: data.icon)
                        .font(.system(size: 10))
                        .foregroundColor(color)
                        .scaleEffect(data.scale)
                        .opacity(animate ? 0 : 1)
                        .rotationEffect(.degrees(animate ? data.rotation + data.rotationEnd : data.rotation))
                        .position(
                            x: animate ? endX : centerX,
                            y: animate ? endY : centerY
                        )
                        .animation(
                            .easeOut(duration: 0.7).delay(data.delay),
                            value: animate
                        )
                }
            }
        }
        .onAppear {
            animate = true
        }
    }
}

/// Celebration burst effect for epic/legendary drops - confetti-like particles
struct CelebrationBurstView: View {
    let rarity: Rarity

    @State private var animate = false

    // Colors based on rarity
    private var celebrationColors: [Color] {
        switch rarity {
        case .legendary:
            return [.yellow, .orange, .white, Color(hex: "ffd700") ?? .yellow]
        case .epic:
            return [.purple, .pink, .blue, .cyan]
        default:
            return [.cyan, .green, .blue]
        }
    }

    // Pre-generate confetti particles
    private let confettiData: [ConfettiData] = (0..<40).map { _ in
        let angle = Double.random(in: 0...(2 * .pi))
        let distance = CGFloat.random(in: 100...300)
        return ConfettiData(
            angle: angle,
            distance: distance,
            size: CGFloat.random(in: 4...12),
            rotation: Double.random(in: 0...360),
            rotationEnd: Double.random(in: 180...720),
            delay: Double.random(in: 0...0.15),
            shape: Int.random(in: 0...2)  // 0=square, 1=circle, 2=diamond
        )
    }

    struct ConfettiData {
        let angle: Double
        let distance: CGFloat
        let size: CGFloat
        let rotation: Double
        let rotationEnd: Double
        let delay: Double
        let shape: Int
    }

    var body: some View {
        GeometryReader { geo in
            let centerX = geo.size.width / 2
            let centerY = geo.size.height / 2

            ZStack {
                ForEach(0..<confettiData.count, id: \.self) { index in
                    let data = confettiData[index]
                    let endX = centerX + cos(data.angle) * data.distance
                    let endY = centerY + sin(data.angle) * data.distance
                    let color = celebrationColors[index % celebrationColors.count]

                    confettiShape(data.shape)
                        .fill(color)
                        .frame(width: data.size, height: data.size)
                        .opacity(animate ? 0 : 1)
                        .rotationEffect(.degrees(animate ? data.rotation + data.rotationEnd : data.rotation))
                        .position(
                            x: animate ? endX : centerX,
                            y: animate ? endY : centerY
                        )
                        .animation(
                            .easeOut(duration: 0.8).delay(data.delay),
                            value: animate
                        )
                }
            }
        }
        .onAppear {
            animate = true
        }
    }

    private func confettiShape(_ type: Int) -> AnyShape {
        switch type {
        case 0: return AnyShape(Rectangle())
        case 1: return AnyShape(Circle())
        default: return AnyShape(Diamond())
        }
    }
}

/// Diamond shape for confetti
struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

/// Type-erased shape wrapper for SwiftUI
struct AnyShape: Shape {
    private let _path: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        _path = shape.path(in:)
    }

    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

// MARK: - Preview

#Preview {
    BlueprintRevealModal(
        protocolId: "trace_route",
        isFirstKill: true,
        onDismiss: {}
    )
}
