import SwiftUI

// MARK: - AppState FTUE (First Time User Experience)
// Extracted from AppState.swift for maintainability

extension AppState {

    // MARK: - FTUE (First Time User Experience)

    /// Called when player completes the camera tutorial (or skips it)
    func completeIntroSequence() {
        updatePlayer { profile in
            profile.hasCompletedIntro = true
        }
        AnalyticsService.shared.trackTutorialCompleted(type: "camera_intro")
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

        AnalyticsService.shared.trackFirstTowerPlaced()
    }

    /// Called when player completes the boss fight tutorial (taps START in boss fight)
    func completeBossTutorial() {
        updatePlayer { profile in
            profile.hasSeenBossTutorial = true
        }
        AnalyticsService.shared.trackTutorialCompleted(type: "boss_fight")
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
