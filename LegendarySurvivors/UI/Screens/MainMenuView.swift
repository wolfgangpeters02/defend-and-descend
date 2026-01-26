import SwiftUI

// MARK: - Main Menu View

struct MainMenuView: View {
    @ObservedObject var appState = AppState.shared
    let onPlay: () -> Void
    let onCollection: () -> Void
    let onStats: () -> Void

    @State private var showTitle = false
    @State private var showButtons = false

    var body: some View {
        GeometryReader { geometry in
            let isPortrait = geometry.size.height > geometry.size.width

            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.1),
                        Color(red: 0.1, green: 0.05, blue: 0.15)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Animated particles background
                ParticleBackgroundView()

                // Content
                VStack(spacing: isPortrait ? 40 : 25) {
                    Spacer()

                    // Title
                    VStack(spacing: 5) {
                        Text("LEGENDARY")
                            .font(.system(size: isPortrait ? 48 : 40, weight: .black))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.cyan, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        Text("SURVIVORS")
                            .font(.system(size: isPortrait ? 36 : 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : -20)

                    Spacer()

                    // Stats preview
                    HStack(spacing: 20) {
                        StatBadge(
                            icon: "flame.fill",
                            value: "\(appState.currentPlayer.totalKills)",
                            label: "Kills"
                        )
                        StatBadge(
                            icon: "clock.fill",
                            value: formatTime(appState.currentPlayer.bestTime),
                            label: "Best"
                        )
                        StatBadge(
                            icon: "star.fill",
                            value: "\(appState.currentPlayer.legendariesUnlocked)",
                            label: "Legendary"
                        )
                    }
                    .opacity(showButtons ? 1 : 0)

                    Spacer()

                    // Menu buttons
                    VStack(spacing: 15) {
                        MenuButton(title: "PLAY", color: .cyan, isPrimary: true) {
                            HapticsService.shared.play(.selection)
                            onPlay()
                        }

                        HStack(spacing: 15) {
                            MenuButton(title: "COLLECTION", color: .purple) {
                                HapticsService.shared.play(.selection)
                                onCollection()
                            }

                            MenuButton(title: "STATS", color: .orange) {
                                HapticsService.shared.play(.selection)
                                onStats()
                            }
                        }
                    }
                    .opacity(showButtons ? 1 : 0)
                    .offset(y: showButtons ? 0 : 20)

                    Spacer()

                    // Version
                    Text("v1.0.0")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.5))
                }
                .padding()
            }
        }
        .onAppear {
            // Spring animated entrance
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showTitle = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3)) {
                showButtons = true
            }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Menu Button

struct MenuButton: View {
    let title: String
    let color: Color
    var isPrimary: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: isPrimary ? 24 : 16, weight: .bold))
                .foregroundColor(isPrimary ? .black : .white)
                .frame(maxWidth: isPrimary ? 280 : 130)
                .padding(.vertical, isPrimary ? 18 : 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isPrimary ? color : color.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(color, lineWidth: isPrimary ? 0 : 2)
                        )
                )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.cyan)
                .font(.system(size: 16))

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .frame(width: 70)
    }
}

// MARK: - Particle Background

struct ParticleBackgroundView: View {
    @State private var particles: [(id: UUID, x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles, id: \.id) { particle in
                    Circle()
                        .fill(Color.cyan.opacity(particle.opacity))
                        .frame(width: particle.size, height: particle.size)
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onAppear {
                // Generate particles
                for _ in 0..<20 {
                    particles.append((
                        id: UUID(),
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: CGFloat.random(in: 0...geometry.size.height),
                        size: CGFloat.random(in: 2...6),
                        opacity: Double.random(in: 0.1...0.3)
                    ))
                }

                // Animate particles
                withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                    for i in 0..<particles.count {
                        particles[i].y -= 100
                    }
                }
            }
        }
    }
}

#Preview {
    MainMenuView(
        onPlay: {},
        onCollection: {},
        onStats: {}
    )
}
