import Foundation
import CoreGraphics

// MARK: - Blocker System
// Handles Blocker Node placement and path rerouting in System: Reboot
// Blockers allow strategic path control - viruses reroute around them

class BlockerSystem {

    // MARK: - Blocker Placement

    /// Place a blocker at a blocker slot
    static func placeBlocker(state: inout TDGameState, slotId: String) -> BlockerPlacementResult {
        // Check if player can place more blockers
        guard state.canPlaceBlocker else {
            return .noSlotsAvailable
        }

        // Find the slot
        guard let slotIndex = state.blockerSlots.firstIndex(where: { $0.id == slotId }) else {
            return .invalidSlot
        }

        let slot = state.blockerSlots[slotIndex]

        // Check if slot is already occupied
        if slot.occupied {
            return .slotOccupied
        }

        // Validate that placing here won't block all paths
        var testBlockers = state.blockerNodes
        let newBlocker = BlockerNode.create(at: slot.position)
        testBlockers.append(newBlocker)

        let newPaths = recalculatePaths(basePaths: state.basePaths, blockers: testBlockers, core: state.core.position)

        // Ensure at least one path exists
        guard !newPaths.isEmpty else {
            return .wouldBlockAllPaths
        }

        // Place the blocker
        state.blockerSlots[slotIndex].occupied = true
        state.blockerSlots[slotIndex].blockerId = newBlocker.id
        state.blockerNodes.append(newBlocker)

        // Update paths
        state.paths = newPaths

        return .success(blocker: newBlocker)
    }

    /// Remove a blocker from its slot
    static func removeBlocker(state: inout TDGameState, blockerId: String) {
        // Find and remove the blocker
        guard let blockerIndex = state.blockerNodes.firstIndex(where: { $0.id == blockerId }) else {
            return
        }

        state.blockerNodes.remove(at: blockerIndex)

        // Clear the slot
        if let slotIndex = state.blockerSlots.firstIndex(where: { $0.blockerId == blockerId }) {
            state.blockerSlots[slotIndex].occupied = false
            state.blockerSlots[slotIndex].blockerId = nil
        }

        // Recalculate paths
        state.paths = recalculatePaths(basePaths: state.basePaths, blockers: state.blockerNodes, core: state.core.position)
    }

    /// Move a blocker from one slot to another
    static func moveBlocker(state: inout TDGameState, blockerId: String, toSlotId: String) -> BlockerPlacementResult {
        // Find the blocker
        guard let blockerIndex = state.blockerNodes.firstIndex(where: { $0.id == blockerId }) else {
            return .invalidSlot
        }

        // Find target slot
        guard let targetSlotIndex = state.blockerSlots.firstIndex(where: { $0.id == toSlotId }) else {
            return .invalidSlot
        }

        let targetSlot = state.blockerSlots[targetSlotIndex]

        // Check if target is occupied
        if targetSlot.occupied {
            return .slotOccupied
        }

        // Test if new position would block all paths
        var testBlockers = state.blockerNodes
        testBlockers[blockerIndex].x = targetSlot.x
        testBlockers[blockerIndex].y = targetSlot.y

        let newPaths = recalculatePaths(basePaths: state.basePaths, blockers: testBlockers, core: state.core.position)

        guard !newPaths.isEmpty else {
            return .wouldBlockAllPaths
        }

        // Clear old slot
        if let oldSlotIndex = state.blockerSlots.firstIndex(where: { $0.blockerId == blockerId }) {
            state.blockerSlots[oldSlotIndex].occupied = false
            state.blockerSlots[oldSlotIndex].blockerId = nil
        }

        // Move blocker
        state.blockerNodes[blockerIndex].x = targetSlot.x
        state.blockerNodes[blockerIndex].y = targetSlot.y

        // Update target slot
        state.blockerSlots[targetSlotIndex].occupied = true
        state.blockerSlots[targetSlotIndex].blockerId = blockerId

        // Update paths
        state.paths = newPaths

        return .success(blocker: state.blockerNodes[blockerIndex])
    }

    // MARK: - Path Recalculation

    /// Recalculate paths avoiding blockers
    /// This creates alternate routes around blocked waypoints
    static func recalculatePaths(basePaths: [EnemyPath], blockers: [BlockerNode], core: CGPoint) -> [EnemyPath] {
        var resultPaths: [EnemyPath] = []

        for basePath in basePaths {
            // Find which waypoints are blocked
            let blockedWaypoints = findBlockedWaypoints(path: basePath, blockers: blockers)

            if blockedWaypoints.isEmpty {
                // No blockers on this path, use as-is
                resultPaths.append(basePath)
                continue
            }

            // Create path that skips blocked waypoints
            // For now, simple skip - in future could add A* pathfinding for detours
            var newWaypoints: [CGPoint] = []

            for (index, waypoint) in basePath.waypoints.enumerated() {
                if blockedWaypoints.contains(index) {
                    // Skip this waypoint - but add slight detour points
                    if let prevPoint = newWaypoints.last {
                        // Add a small detour around the blocked point
                        let detourDistance: CGFloat = 60
                        let midX = (prevPoint.x + waypoint.x) / 2

                        // Detour to the side that's further from center
                        let detourX = midX > core.x / 2 ? midX + detourDistance : midX - detourDistance
                        let detourY = (prevPoint.y + waypoint.y) / 2

                        newWaypoints.append(CGPoint(x: detourX, y: detourY))
                    }
                } else {
                    newWaypoints.append(waypoint)
                }
            }

            // Only add path if it has at least 2 waypoints
            if newWaypoints.count >= 2 {
                resultPaths.append(EnemyPath(id: basePath.id + "_rerouted", waypoints: newWaypoints))
            }
        }

        return resultPaths
    }

    /// Find which waypoint indices are blocked
    private static func findBlockedWaypoints(path: EnemyPath, blockers: [BlockerNode]) -> Set<Int> {
        var blocked: Set<Int> = []
        let blockRadius: CGFloat = 40

        for (index, waypoint) in path.waypoints.enumerated() {
            // Skip first and last waypoints (spawn and core)
            if index == 0 || index == path.waypoints.count - 1 {
                continue
            }

            for blocker in blockers {
                let dx = waypoint.x - blocker.x
                let dy = waypoint.y - blocker.y
                if sqrt(dx*dx + dy*dy) < blockRadius {
                    blocked.insert(index)
                    break
                }
            }
        }

        return blocked
    }

    // MARK: - Validation

    /// Check if a slot can have a blocker placed
    static func canPlaceBlockerAt(state: TDGameState, slotId: String) -> Bool {
        guard state.canPlaceBlocker else { return false }

        guard let slot = state.blockerSlots.first(where: { $0.id == slotId }) else {
            return false
        }

        if slot.occupied { return false }

        // Test if placement would block all paths
        var testBlockers = state.blockerNodes
        let newBlocker = BlockerNode.create(at: slot.position)
        testBlockers.append(newBlocker)

        let newPaths = recalculatePaths(basePaths: state.basePaths, blockers: testBlockers, core: state.core.position)
        return !newPaths.isEmpty
    }

    /// Preview path changes if a blocker is placed at a slot
    static func previewPathsWithBlocker(state: TDGameState, slotId: String) -> [EnemyPath]? {
        guard let slot = state.blockerSlots.first(where: { $0.id == slotId }) else {
            return nil
        }

        var testBlockers = state.blockerNodes
        let newBlocker = BlockerNode.create(at: slot.position)
        testBlockers.append(newBlocker)

        let newPaths = recalculatePaths(basePaths: state.basePaths, blockers: testBlockers, core: state.core.position)
        return newPaths.isEmpty ? nil : newPaths
    }
}

// MARK: - Blocker Placement Result

enum BlockerPlacementResult {
    case success(blocker: BlockerNode)
    case noSlotsAvailable
    case slotOccupied
    case invalidSlot
    case wouldBlockAllPaths
}
