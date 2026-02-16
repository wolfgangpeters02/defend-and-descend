import SpriteKit

// MARK: - Camera Controller
// Extracted from TDGameScene (Step 4.2) — pure zoom/pan/inertia logic
// with zero game-state dependencies.

class CameraController: NSObject {

    // MARK: - Properties

    weak var scene: SKScene?

    private(set) var cameraNode: SKCameraNode!
    var currentScale: CGFloat = 1.0
    let minScale: CGFloat = 0.15  // Zoom IN limit
    let maxScale: CGFloat = 1.8   // Zoom OUT limit

    // Inertia physics
    var velocity: CGPoint = .zero
    let friction: CGFloat = 0.92
    let boundsElasticity: CGFloat = 0.3
    private var lastPanVelocity: CGPoint = .zero

    // Configuration (set once after init, before setup)
    var isMotherboardMap: Bool = false
    var suppressIntroAnimation: Bool = false  // Tutorial takes over camera
    var panSpeedMultiplier: CGFloat { isMotherboardMap ? 2.5 : 1.0 }

    /// Callback queried each frame to suppress panning during placement/drag.
    var shouldSuppressPan: () -> Bool = { false }

    // MARK: - Computed

    /// Expose camera scale for coordinate conversion from SwiftUI layer.
    var scale: CGFloat { currentScale }

    /// Current camera position in game coordinates.
    var position: CGPoint {
        cameraNode?.position ?? .zero
    }

    // MARK: - Setup

    func setup(in scene: SKScene, starterSectorCenter: CGPoint?) {
        self.scene = scene
        cameraNode = SKCameraNode()

        if isMotherboardMap {
            if let center = starterSectorCenter {
                cameraNode.position = center
            } else {
                cameraNode.position = CGPoint(x: 2100, y: 2100)
            }
        } else {
            cameraNode.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        }

        scene.addChild(cameraNode)
        scene.camera = cameraNode

        // Animated intro zoom (skipped when tutorial takes over camera)
        if isMotherboardMap {
            if suppressIntroAnimation {
                // Tutorial mode: start zoomed out on full board, tutorial will animate
                currentScale = 1.8
                cameraNode.setScale(currentScale)
                cameraNode.position = CGPoint(x: 2100, y: 2100)  // Board center
            } else {
                currentScale = 2.0
                cameraNode.setScale(currentScale)

                let wait = SKAction.wait(forDuration: 0.8)
                let zoomIn = SKAction.scale(to: 1.0, duration: 1.0)
                zoomIn.timingMode = .easeInEaseOut
                let updateScale = SKAction.run { [weak self] in
                    self?.currentScale = 1.0
                }
                cameraNode.run(SKAction.sequence([wait, zoomIn, updateScale]))
            }
        } else {
            currentScale = 1.5
            cameraNode.setScale(currentScale)

            let wait = SKAction.wait(forDuration: 1.0)
            let zoomIn = SKAction.scale(to: 0.8, duration: 0.6)
            zoomIn.timingMode = .easeInEaseOut
            let updateScale = SKAction.run { [weak self] in
                self?.currentScale = 0.8
            }
            cameraNode.run(SKAction.sequence([wait, zoomIn, updateScale]))
        }
    }

    func setupGestureRecognizers(view: SKView) {
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinchGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(pinchGesture)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 2
        panGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(panGesture)
    }

    // MARK: - Gesture Handlers

    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let cameraNode = cameraNode,
              let scene = scene,
              let view = gesture.view else { return }

        if gesture.state == .changed {
            let pinchCenter = gesture.location(in: view)
            let scenePointBefore = scene.convertPoint(fromView: pinchCenter)

            let newScale = currentScale / gesture.scale
            let clampedScale = max(minScale, min(maxScale, newScale))

            cameraNode.setScale(clampedScale)
            currentScale = clampedScale

            let scenePointAfter = scene.convertPoint(fromView: pinchCenter)

            let deltaX = scenePointAfter.x - scenePointBefore.x
            let deltaY = scenePointAfter.y - scenePointBefore.y
            cameraNode.position.x -= deltaX
            cameraNode.position.y -= deltaY

            gesture.scale = 1.0
        } else if gesture.state == .ended {
            currentScale = cameraNode.xScale
        }
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let cameraNode = cameraNode, let view = gesture.view else { return }

        // Suppress camera panning during tower placement / drag
        if shouldSuppressPan() {
            gesture.setTranslation(.zero, in: view)
            return
        }

        switch gesture.state {
        case .began:
            velocity = .zero

        case .changed:
            let translation = gesture.translation(in: view)
            let multiplier = panSpeedMultiplier

            let newX = cameraNode.position.x - translation.x * currentScale * multiplier
            let newY = cameraNode.position.y + translation.y * currentScale * multiplier

            let bounds = calculateBounds()

            let overscrollResistance: CGFloat = 0.3
            var finalX = newX
            var finalY = newY

            if newX < bounds.minX {
                finalX = bounds.minX + (newX - bounds.minX) * overscrollResistance
            } else if newX > bounds.maxX {
                finalX = bounds.maxX + (newX - bounds.maxX) * overscrollResistance
            }

            if newY < bounds.minY {
                finalY = bounds.minY + (newY - bounds.minY) * overscrollResistance
            } else if newY > bounds.maxY {
                finalY = bounds.maxY + (newY - bounds.maxY) * overscrollResistance
            }

            cameraNode.position = CGPoint(x: finalX, y: finalY)

            let vel = gesture.velocity(in: view)
            lastPanVelocity = CGPoint(x: -vel.x * currentScale * multiplier,
                                      y:  vel.y * currentScale * multiplier)

            gesture.setTranslation(.zero, in: view)

        case .ended, .cancelled:
            velocity = lastPanVelocity
            lastPanVelocity = .zero

        default:
            break
        }
    }

    // MARK: - Bounds

    func calculateBounds() -> (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        guard let scene = scene, let view = scene.view else {
            if isMotherboardMap {
                return (2100, 2100, 2100, 2100)
            }
            let s = scene?.size ?? .zero
            return (s.width / 2, s.width / 2, s.height / 2, s.height / 2)
        }

        let visibleWidth = view.bounds.width * currentScale
        let visibleHeight = view.bounds.height * currentScale
        let halfWidth = visibleWidth / 2
        let halfHeight = visibleHeight / 2

        if isMotherboardMap {
            let mapWidth: CGFloat = 4200
            let mapHeight: CGFloat = 4200

            let minX = halfWidth
            let maxX = mapWidth - halfWidth
            let minY = halfHeight
            let maxY = mapHeight - halfHeight

            return (
                minX: min(minX, mapWidth / 2),
                maxX: max(maxX, mapWidth / 2),
                minY: min(minY, mapHeight / 2),
                maxY: max(maxY, mapHeight / 2)
            )
        }

        let s = scene.size
        let minX = halfWidth
        let maxX = s.width - halfWidth
        let minY = halfHeight
        let maxY = s.height - halfHeight

        return (
            minX: min(minX, s.width / 2),
            maxX: max(maxX, s.width / 2),
            minY: min(minY, s.height / 2),
            maxY: max(maxY, s.height / 2)
        )
    }

    // MARK: - Physics (Inertia)

    func updatePhysics(deltaTime: TimeInterval) {
        guard let cameraNode = cameraNode else { return }

        let speed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
        guard speed > 0.1 else {
            velocity = .zero
            return
        }

        let dt = CGFloat(deltaTime)
        var newX = cameraNode.position.x + velocity.x * dt
        var newY = cameraNode.position.y + velocity.y * dt

        let bounds = calculateBounds()

        if newX < bounds.minX {
            newX = bounds.minX
            velocity.x = -velocity.x * boundsElasticity
        } else if newX > bounds.maxX {
            newX = bounds.maxX
            velocity.x = -velocity.x * boundsElasticity
        }

        if newY < bounds.minY {
            newY = bounds.minY
            velocity.y = -velocity.y * boundsElasticity
        } else if newY > bounds.maxY {
            newY = bounds.maxY
            velocity.y = -velocity.y * boundsElasticity
        }

        cameraNode.position = CGPoint(x: newX, y: newY)

        // Frame-rate independent friction: normalize to 60fps baseline
        let frictionFactor = pow(friction, dt * 60)
        velocity.x *= frictionFactor
        velocity.y *= frictionFactor
    }

    // MARK: - Reset

    func reset(to center: CGPoint, scale targetScale: CGFloat) {
        guard let cameraNode = cameraNode else { return }
        let action = SKAction.group([
            SKAction.move(to: center, duration: 0.3),
            SKAction.scale(to: targetScale, duration: 0.3)
        ])
        action.timingMode = .easeInEaseOut
        let updateScale = SKAction.run { [weak self] in
            self?.currentScale = targetScale
        }
        cameraNode.run(SKAction.sequence([action, updateScale]))
    }

    /// Animate camera to a position and scale with custom duration (for tutorial sequences)
    func animateTo(position: CGPoint, scale targetScale: CGFloat, duration: TimeInterval, completion: (() -> Void)? = nil) {
        guard let cameraNode = cameraNode else {
            completion?()
            return
        }
        let action = SKAction.group([
            SKAction.move(to: position, duration: duration),
            SKAction.scale(to: targetScale, duration: duration)
        ])
        action.timingMode = .easeInEaseOut
        cameraNode.run(action) { [weak self] in
            self?.currentScale = targetScale
            DispatchQueue.main.async {
                completion?()
            }
        }
    }
}
