import SwiftUI
import SpriteKit

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
