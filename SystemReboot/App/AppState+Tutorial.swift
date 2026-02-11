import SwiftUI

// MARK: - AppState FTUE (First Time User Experience)
// Extracted from AppState.swift for maintainability

extension AppState {

    // MARK: - FTUE (First Time User Experience)

    /// Called when player completes the intro sequence
    func completeIntroSequence() {
        updatePlayer { profile in
            profile.hasCompletedIntro = true
        }
        showIntroSequence = false

        // Activate initial tutorial hints
        TutorialHintManager.shared.activateHint(.deckCard)
        TutorialHintManager.shared.activateHint(.towerSlot)
    }

    /// Called when player places their first tower
    func recordFirstTowerPlacement() {
        guard !currentPlayer.firstTowerPlaced else { return }

        updatePlayer { profile in
            profile.firstTowerPlaced = true
        }

        // Dismiss the deck card and tower slot hints
        markHintSeen(.deckCard)
        markHintSeen(.towerSlot)
    }

    /// Mark a tutorial hint as seen (permanently dismissed)
    func markHintSeen(_ hint: TutorialHintType) {
        TutorialHintManager.shared.markHintSeen(hint)

        updatePlayer { profile in
            if !profile.tutorialHintsSeen.contains(hint.rawValue) {
                profile.tutorialHintsSeen.append(hint.rawValue)
            }
        }
    }

    /// Check milestone and potentially show hints
    func checkMilestone(hashEarned: Int) {
        // Milestone: First 500 Hash earned - show PSU upgrade hint
        if hashEarned >= 500 && !currentPlayer.tutorialHintsSeen.contains(TutorialHintType.psuUpgrade.rawValue) {
            TutorialHintManager.shared.activateHint(.psuUpgrade)
        }
    }
}
