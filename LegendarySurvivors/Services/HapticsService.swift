import UIKit
import CoreHaptics

// MARK: - Haptics Service

class HapticsService {
    static let shared = HapticsService()

    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool = false

    enum HapticType {
        case light
        case medium
        case heavy
        case success
        case warning
        case error
        case selection
        case legendary
        case bossDeath
        case criticalHit
        case defeat
        // TD-specific haptics
        case towerPlace
        case towerMerge
        case waveStart
        case waveComplete
        case coreHit
        case slotSnap          // Haptic when dragged tower snaps to a valid slot
        case invalidAction     // Haptic for invalid placement attempts
    }

    private init() {
        setupHaptics()
    }

    private func setupHaptics() {
        // Check device support
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

        guard supportsHaptics else { return }

        do {
            engine = try CHHapticEngine()
            try engine?.start()

            // Handle engine reset
            engine?.resetHandler = { [weak self] in
                do {
                    try self?.engine?.start()
                } catch {
                    print("Failed to restart haptic engine: \(error)")
                }
            }
        } catch {
            print("Failed to create haptic engine: \(error)")
        }
    }

    // MARK: - Public API

    func play(_ type: HapticType) {
        switch type {
        case .light:
            playImpact(.light)
        case .medium:
            playImpact(.medium)
        case .heavy:
            playImpact(.heavy)
        case .success:
            playNotification(.success)
        case .warning:
            playNotification(.warning)
        case .error:
            playNotification(.error)
        case .selection:
            playSelection()
        case .legendary:
            playLegendaryPattern()
        case .bossDeath:
            playBossDeathPattern()
        case .criticalHit:
            playCriticalHitPattern()
        case .defeat:
            playDefeatPattern()
        // TD-specific patterns
        case .towerPlace:
            playTowerPlacePattern()
        case .towerMerge:
            playLegendaryPattern()  // Reuse legendary for merge (triumphant feel)
        case .waveStart:
            playWaveStartPattern()
        case .waveComplete:
            playNotification(.success)
        case .coreHit:
            playCoreHitPattern()
        case .slotSnap:
            playSlotSnapPattern()
        case .invalidAction:
            playNotification(.warning)
        }
    }

    // MARK: - Basic Haptics

    private func playImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    private func playNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    private func playSelection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    // MARK: - Custom Patterns

    private func playLegendaryPattern() {
        guard supportsHaptics, let engine = engine else {
            // Fallback to basic haptics
            playNotification(.success)
            return
        }

        do {
            // Create a pattern: heavy -> pause -> medium -> pause -> light (triumphant feel)
            let events: [CHHapticEvent] = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                    ],
                    relativeTime: 0.1
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                    ],
                    relativeTime: 0.2
                )
            ]

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            playNotification(.success)
        }
    }

    private func playBossDeathPattern() {
        guard supportsHaptics, let engine = engine else {
            playImpact(.heavy)
            return
        }

        do {
            // Rumble pattern
            var events: [CHHapticEvent] = []
            for i in 0..<6 {
                let intensity = 1.0 - (Float(i) * 0.15)
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: Double(i) * 0.08
                ))
            }

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            playImpact(.heavy)
        }
    }

    private func playCriticalHitPattern() {
        guard supportsHaptics, let engine = engine else {
            playImpact(.medium)
            return
        }

        do {
            let events: [CHHapticEvent] = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                    ],
                    relativeTime: 0.05
                )
            ]

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            playImpact(.medium)
        }
    }

    private func playDefeatPattern() {
        guard supportsHaptics, let engine = engine else {
            playNotification(.error)
            return
        }

        do {
            // Descending sad pattern
            var events: [CHHapticEvent] = []
            for i in 0..<4 {
                let intensity = 0.8 - (Float(i) * 0.2)
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                    ],
                    relativeTime: Double(i) * 0.15
                ))
            }

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            playNotification(.error)
        }
    }

    // MARK: - TD-Specific Patterns

    /// Tower placement - satisfying "kerchunk"
    private func playTowerPlacePattern() {
        guard supportsHaptics, let engine = engine else {
            playImpact(.medium)
            return
        }

        do {
            let events: [CHHapticEvent] = [
                // Initial medium thump
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 0
                ),
                // Short continuous rumble for "settling"
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                    ],
                    relativeTime: 0.05,
                    duration: 0.1
                )
            ]

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            playImpact(.medium)
        }
    }

    /// Wave start - double light pulse
    private func playWaveStartPattern() {
        guard supportsHaptics, let engine = engine else {
            playImpact(.light)
            return
        }

        do {
            let events: [CHHapticEvent] = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 0.1
                )
            ]

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            playImpact(.light)
        }
    }

    /// Core hit - urgent warning
    private func playCoreHitPattern() {
        guard supportsHaptics, let engine = engine else {
            playNotification(.warning)
            return
        }

        do {
            let events: [CHHapticEvent] = [
                // Sharp initial hit
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    ],
                    relativeTime: 0
                ),
                // Urgent vibration
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                    ],
                    relativeTime: 0.05,
                    duration: 0.15
                ),
                // Final thump
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                    ],
                    relativeTime: 0.2
                )
            ]

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            playNotification(.warning)
        }
    }

    /// Slot snap - subtle "click" when dragged tower snaps to valid slot
    private func playSlotSnapPattern() {
        guard supportsHaptics, let engine = engine else {
            playSelection()
            return
        }

        do {
            let events: [CHHapticEvent] = [
                // Single crisp tap - like a magnetic snap
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    ],
                    relativeTime: 0
                )
            ]

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            playSelection()
        }
    }
}
