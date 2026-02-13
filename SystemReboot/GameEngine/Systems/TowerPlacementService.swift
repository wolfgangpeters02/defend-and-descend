import Foundation
import CoreGraphics

// MARK: - Tower Placement Service
// Single source of truth for coordinate conversion, snap-to-slot logic, and placement affordability.
// Consolidates duplicated logic from TDGameContainerView and EmbeddedTDGameController.
// Step 2.2 of the refactoring roadmap.

struct TowerPlacementService {

    // MARK: - Coordinate Conversion (Fallback)
    // Primary conversion uses TDGameScene.convertScreenToGame/convertGameToScreen (SpriteKit-native).
    // These fallback methods are used when no scene reference is available.

    /// Convert screen coordinates to game coordinates (fallback without SpriteKit scene)
    static func convertScreenToGame(
        _ point: CGPoint,
        screenSize: CGSize,
        gameSize: CGSize
    ) -> CGPoint {
        let scaleX = screenSize.width / gameSize.width
        let scaleY = screenSize.height / gameSize.height
        let scale = max(scaleX, scaleY)
        let scaledWidth = gameSize.width * scale
        let scaledHeight = gameSize.height * scale
        let offsetX = (screenSize.width - scaledWidth) / 2
        let offsetY = (screenSize.height - scaledHeight) / 2

        return CGPoint(
            x: (point.x - offsetX) / scale,
            y: (point.y - offsetY) / scale
        )
    }

    /// Convert game coordinates to screen coordinates (fallback without SpriteKit scene)
    static func convertGameToScreen(
        _ point: CGPoint,
        screenSize: CGSize,
        gameSize: CGSize
    ) -> CGPoint {
        let scaleX = screenSize.width / gameSize.width
        let scaleY = screenSize.height / gameSize.height
        let scale = max(scaleX, scaleY)
        let scaledWidth = gameSize.width * scale
        let scaledHeight = gameSize.height * scale
        let offsetX = (screenSize.width - scaledWidth) / 2
        let offsetY = (screenSize.height - scaledHeight) / 2

        return CGPoint(
            x: point.x * scale + offsetX,
            y: point.y * scale + offsetY
        )
    }

    // MARK: - Snap Distance

    /// Calculate snap distance in game units, adjusted for camera zoom and map size
    static func snapDistance(cameraScale: CGFloat, mapWidth: CGFloat) -> CGFloat {
        let baseSnap: CGFloat = mapWidth > 2000
            ? BalanceConfig.TDSession.largeMapSnapScreenDistance
            : BalanceConfig.TDSession.baseSnapScreenDistance
        // Scale so zoomed-out views have larger snap areas
        return baseSnap / min(cameraScale, 1.0) * max(cameraScale, 1.0)
    }

    // MARK: - Nearest Slot

    /// Find the nearest unoccupied tower slot within snap distance of a game-space point
    static func findNearestSlot(
        gamePoint: CGPoint,
        slots: [TowerSlot],
        snapDistance: CGFloat
    ) -> TowerSlot? {
        var nearest: TowerSlot?
        var minDistance: CGFloat = snapDistance

        for slot in slots where !slot.occupied {
            let dx = slot.x - gamePoint.x
            let dy = slot.y - gamePoint.y
            let distance = sqrt(dx * dx + dy * dy)
            if distance < minDistance {
                minDistance = distance
                nearest = slot
            }
        }

        return nearest
    }

    // MARK: - Affordability

    /// Check whether the player can afford to place a tower of the given protocol type
    static func canAfford(weaponType: String, hash: Int) -> Bool {
        guard let proto = ProtocolLibrary.get(weaponType) else { return false }
        let cost = TowerSystem.towerPlacementCost(rarity: proto.rarity)
        return hash >= cost
    }
}
