import SpriteKit
import UIKit

// MARK: - Tower Animation System
// Rich, multi-stage animations for AAA tower visuals

final class TowerAnimations {

    // MARK: - Animation State

    enum TowerState {
        case idle
        case targeting
        case charging
        case firing
        case cooldown
    }

    // MARK: - Animation Keys

    enum AnimationKey {
        static let idlePulse = "idlePulse"
        static let idleRotation = "idleRotation"
        static let idleFloat = "idleFloat"
        static let orbiting = "orbiting"
        static let electricArcs = "electricArcs"
        static let frostParticles = "frostParticles"
        static let divineParticles = "divineParticles"
        static let glitchEffect = "glitchEffect"
        static let bracketPulse = "bracketPulse"
        static let flameFlicker = "flameFlicker"
        static let dataFlow = "dataFlow"
        static let runeOrbit = "runeOrbit"
    }
}
