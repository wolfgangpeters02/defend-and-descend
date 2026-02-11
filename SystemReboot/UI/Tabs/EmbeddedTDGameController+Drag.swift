import SwiftUI
import SpriteKit

// MARK: - Drag Handling & Coordinate Conversion
// Extracted from EmbeddedTDGameController (Step 4.4)
// Tower drag-from-deck gesture handling and screen↔game coordinate conversion.

extension EmbeddedTDGameController {

    // MARK: - Drag Handling

    func startDrag(weaponType: String) {
        isDraggingFromDeck = true
        draggedWeaponType = weaponType
        canAffordDraggedTower = TowerPlacementService.canAfford(weaponType: weaponType, hash: gameState?.hash ?? 0)

        scene?.enterPlacementMode(weaponType: weaponType)
        HapticsService.shared.play(.selection)
    }

    func updateDrag(_ value: DragGesture.Value, geometry: GeometryProxy) {
        dragPosition = value.location

        guard let state = gameState else { return }

        let gamePos = convertScreenToGame(dragPosition, geometry: geometry)
        let cameraScale = scene?.cameraScale ?? 1.0
        let snap = TowerPlacementService.snapDistance(cameraScale: cameraScale, mapWidth: state.map.width)
        let nearest = TowerPlacementService.findNearestSlot(gamePoint: gamePos, slots: state.towerSlots, snapDistance: snap)

        if nearestValidSlot?.id != nearest?.id {
            nearestValidSlot = nearest
            scene?.highlightNearestSlot(nearest, canAfford: canAffordDraggedTower)

            if nearest != nil && canAffordDraggedTower {
                HapticsService.shared.play(.slotSnap)
            }
        }
    }

    func endDrag(profile: PlayerProfile) {
        scene?.exitPlacementMode()

        defer {
            isDraggingFromDeck = false
            draggedWeaponType = nil
            nearestValidSlot = nil
        }

        if let weaponType = draggedWeaponType,
           let slot = nearestValidSlot,
           canAffordDraggedTower {
            scene?.placeTower(weaponType: weaponType, slotId: slot.id, profile: profile)
            HapticsService.shared.play(.towerPlace)
        }
    }

    // MARK: - Coordinate Conversion

    func convertScreenToGame(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        if let scene = scene {
            return scene.convertScreenToGame(screenPoint: point, viewSize: geometry.size)
        }
        let gameSize = CGSize(width: gameState?.map.width ?? 800, height: gameState?.map.height ?? 600)
        return TowerPlacementService.convertScreenToGame(point, screenSize: geometry.size, gameSize: gameSize)
    }

    func convertGameToScreen(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        if let scene = scene {
            return scene.convertGameToScreen(gamePoint: point, viewSize: geometry.size)
        }
        let gameSize = CGSize(width: gameState?.map.width ?? 800, height: gameState?.map.height ?? 600)
        return TowerPlacementService.convertGameToScreen(point, screenSize: geometry.size, gameSize: gameSize)
    }
}
