import SwiftUI

// MARK: - Virtual Joystick Configuration

struct JoystickConfig {
    /// Dead zone radius (0-1, normalized). Input below this threshold is ignored.
    var deadZone: CGFloat = 0.15

    /// Whether to snap to 8 cardinal/diagonal directions
    var snapToDirections: Bool = false

    /// Whether to provide haptic feedback
    var enableHaptics: Bool = true

    /// Spring response for return animation (lower = bouncier)
    var springResponse: Double = 0.3

    /// Spring damping fraction (0-1, higher = less bounce)
    var springDamping: Double = 0.7

    /// Whether to apply momentum after release
    var enableMomentum: Bool = true

    /// How quickly momentum decays (0-1, higher = faster decay)
    var momentumDecay: CGFloat = 0.15

    static let `default` = JoystickConfig()
}

// MARK: - Virtual Joystick

struct VirtualJoystick: View {
    let onMove: (CGFloat, CGFloat) -> Void // (angle, distance)
    let onStop: () -> Void

    var config: JoystickConfig = .default

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var isActive = false
    @State private var basePosition: CGPoint = .zero
    @State private var knobOffset: CGPoint = .zero
    @State private var lastDirection: CGFloat? = nil
    @State private var velocity: CGPoint = .zero
    @State private var lastUpdateTime: Date = Date()

    // Momentum timer
    @State private var momentumTimer: Timer? = nil

    // Responsive sizing — iPhone: verticalSizeClass .regular = portrait, .compact = landscape
    // iPad gets scaled up via adaptiveScale (1.5×), iPhone stays identical (1.0×)
    private var isPortrait: Bool {
        verticalSizeClass == .regular
    }

    private var scale: CGFloat {
        DesignLayout.adaptiveScale(for: horizontalSizeClass)
    }

    private var joystickSize: CGFloat {
        (isPortrait ? 140 : 120) * scale
    }

    private var knobSize: CGFloat {
        (isPortrait ? 60 : 50) * scale
    }

    private var maxDistance: CGFloat {
        (joystickSize - knobSize) / 2
    }

    private var deadZoneDistance: CGFloat {
        maxDistance * config.deadZone
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Touch area (invisible)
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handleTouch(value: value, in: geometry)
                            }
                            .onEnded { _ in
                                handleTouchEnd()
                            }
                    )

                // Joystick visual
                if isActive {
                    joystickView
                        .position(basePosition)
                } else {
                    // Hint text when not active
                    VStack {
                        Spacer()
                        HStack {
                            if !isPortrait {
                                Spacer().frame(width: 30)
                            }
                            Text(L10n.Game.touchToMove)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.3))
                            if isPortrait {
                                Spacer()
                            }
                        }
                        .padding(.bottom, isPortrait ? 20 : 40)
                        .padding(.leading, isPortrait ? 0 : 20)
                    }
                    .frame(maxWidth: .infinity, alignment: isPortrait ? .center : .leading)
                }
            }
        }
        .allowsHitTesting(true)
    }

    private var joystickView: some View {
        ZStack {
            // Base circle with subtle gradient
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.04),
                            Color.white.opacity(0.01)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: joystickSize / 2
                    )
                )
                .frame(width: joystickSize, height: joystickSize)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1.5)
                )
                .shadow(color: Color.cyan.opacity(0.1), radius: 10)

            // Dead zone indicator (subtle inner circle)
            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                .frame(width: deadZoneDistance * 2, height: deadZoneDistance * 2)

            // Crosshair
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 1, height: joystickSize)
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(width: joystickSize, height: 1)

            // Direction indicators (8 dots around the edge)
            ForEach(0..<8, id: \.self) { i in
                let angle = CGFloat(i) * .pi / 4
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 4, height: 4)
                    .offset(
                        x: cos(angle) * (joystickSize / 2 - 8),
                        y: sin(angle) * (joystickSize / 2 - 8)
                    )
            }

            // Knob with spring animation
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.cyan.opacity(0.25),
                            Color.cyan.opacity(0.1)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: knobSize / 2
                    )
                )
                .frame(width: knobSize, height: knobSize)
                .overlay(
                    Circle()
                        .stroke(Color.cyan.opacity(0.4), lineWidth: 1.5)
                )
                .shadow(color: Color.cyan.opacity(0.3), radius: 12)
                .offset(x: knobOffset.x, y: knobOffset.y)
                .animation(
                    isActive ? .none : .interpolatingSpring(
                        stiffness: 300,
                        damping: 20
                    ),
                    value: knobOffset
                )
        }
    }

    private func handleTouch(value: DragGesture.Value, in geometry: GeometryProxy) {
        let location = value.location
        let now = Date()

        if !isActive {
            // Start touch - set base position
            isActive = true
            basePosition = location
            knobOffset = .zero
            lastDirection = nil

            // Initial haptic feedback
            if config.enableHaptics {
                HapticsService.shared.play(.selection)
            }
        }

        // Calculate delta from base
        let deltaX = location.x - basePosition.x
        let deltaY = location.y - basePosition.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        var angle = atan2(deltaY, deltaX)

        // Calculate velocity for momentum
        let timeDelta = now.timeIntervalSince(lastUpdateTime)
        if timeDelta > 0 {
            let prevX = knobOffset.x
            let prevY = knobOffset.y
            velocity = CGPoint(
                x: (deltaX - prevX) / CGFloat(timeDelta),
                y: (deltaY - prevY) / CGFloat(timeDelta)
            )
        }
        lastUpdateTime = now

        // Apply dead zone
        if distance < deadZoneDistance {
            knobOffset = CGPoint(x: deltaX, y: deltaY)
            onMove(0, 0)
            return
        }

        // Snap to 8 directions if enabled
        if config.snapToDirections {
            angle = snapAngleToDirection(angle)
        }

        // Constrain knob to max distance
        let constrainedDistance = min(distance, maxDistance)
        knobOffset = CGPoint(
            x: cos(angle) * constrainedDistance,
            y: sin(angle) * constrainedDistance
        )

        // Check for direction change for haptic feedback
        let currentDirection = snapAngleToDirection(angle)
        if config.enableHaptics && lastDirection != nil && lastDirection != currentDirection {
            HapticsService.shared.play(.light)
        }
        lastDirection = currentDirection

        // Normalize distance (0-1), accounting for dead zone
        let effectiveDistance = distance - deadZoneDistance
        let effectiveMaxDistance = maxDistance - deadZoneDistance
        let normalizedDistance = min(max(effectiveDistance / effectiveMaxDistance, 0), 1)

        onMove(angle, normalizedDistance)
    }

    private func handleTouchEnd() {
        // Stop momentum timer if running
        momentumTimer?.invalidate()
        momentumTimer = nil

        if config.enableMomentum && config.momentumDecay < 1 {
            // Apply momentum
            applyMomentum()
        } else {
            // Immediate stop
            completeStop()
        }

        // Animate knob back to center with spring physics
        withAnimation(.interpolatingSpring(
            stiffness: 200 / config.springResponse,
            damping: 15 * config.springDamping
        )) {
            knobOffset = .zero
        }

        isActive = false

        // End haptic
        if config.enableHaptics {
            HapticsService.shared.play(.light)
        }
    }

    private func applyMomentum() {
        guard abs(velocity.x) > 10 || abs(velocity.y) > 10 else {
            completeStop()
            return
        }

        var currentVelocity = velocity

        // Use a timer to decay momentum
        momentumTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            // Apply decay
            currentVelocity.x *= (1 - config.momentumDecay)
            currentVelocity.y *= (1 - config.momentumDecay)

            // Check if momentum is negligible
            if abs(currentVelocity.x) < 5 && abs(currentVelocity.y) < 5 {
                timer.invalidate()
                momentumTimer = nil
                completeStop()
                return
            }

            // Calculate angle and distance from velocity
            let speed = sqrt(currentVelocity.x * currentVelocity.x + currentVelocity.y * currentVelocity.y)
            let angle = atan2(currentVelocity.y, currentVelocity.x)
            let normalizedDistance = min(speed / 500, 1.0) // Normalize speed to 0-1

            onMove(angle, normalizedDistance)
        }
    }

    private func completeStop() {
        onStop()
        lastDirection = nil
        velocity = .zero
    }

    /// Snaps an angle to the nearest of 8 directions (N, NE, E, SE, S, SW, W, NW)
    private func snapAngleToDirection(_ angle: CGFloat) -> CGFloat {
        let snapInterval = CGFloat.pi / 4 // 45 degrees
        let snappedAngle = round(angle / snapInterval) * snapInterval
        return snappedAngle
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VirtualJoystick(
            onMove: { angle, distance in
                print("Move: angle=\(angle), distance=\(distance)")
            },
            onStop: {
                print("Stop")
            },
            config: JoystickConfig(
                deadZone: 0.15,
                snapToDirections: false,
                enableHaptics: true,
                enableMomentum: true
            )
        )
    }
}
