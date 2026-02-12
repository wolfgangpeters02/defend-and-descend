import SwiftUI
import SpriteKit

// MARK: - TD Stat Row
// Extracted from TDGameContainerView.swift for maintainability

struct TDStatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(DesignTypography.caption(10))
            Text("\(label):")
                .foregroundColor(.gray)
            Text(value)
                .foregroundColor(.white)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Resource Indicator

struct ResourceIndicator: View {
    let icon: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(DesignTypography.caption(12))
            Text("\(value)")
                .foregroundColor(.white)
                .fontWeight(.bold)
                .font(DesignTypography.body(14))
        }
    }
}

// MARK: - Wave Progress Bar

struct WaveProgressBar: View {
    let current: Int
    let total: Int

    private var progress: CGFloat {
        guard total > 0 else { return 1.0 }
        return CGFloat(total - current) / CGFloat(total)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))

                // Progress fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.green, .yellow]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Countdown Bar

struct CountdownBar: View {
    let seconds: TimeInterval
    let maxSeconds: TimeInterval

    private var progress: CGFloat {
        CGFloat(seconds / maxSeconds)
    }

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))

                    // Progress fill
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.yellow)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 4)

            Text(L10n.Stats.nextSeconds(Int(seconds)))
                .font(DesignTypography.caption(10))
                .foregroundColor(.yellow)
        }
    }
}

// MARK: - Game End Stat Row

struct GameEndStatRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(DesignTypography.headline(22))
                .foregroundColor(color)
                .frame(width: 32)
            Text(label)
                .font(.system(size: 18))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Boss Loot Modal Wrapper
// Wrapper to handle optional reward gracefully in fullScreenCover

struct BossLootModalWrapper: View {
    let reward: BossLootReward?
    let onCollect: () -> Void

    var body: some View {
        if let reward = reward {
            BossLootModal(reward: reward, onCollect: onCollect)
        } else {
            // Fallback - should never happen but prevents empty content issues
            Color.black.ignoresSafeArea()
                .onAppear {
                    onCollect()  // Dismiss immediately
                }
        }
    }
}

