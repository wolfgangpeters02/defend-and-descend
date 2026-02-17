import SpriteKit
import SwiftUI

extension TDGameScene {

    // MARK: - Placement Mode (Progressive Disclosure)

    /// Enter placement mode - brighten grid dots
    func enterPlacementMode(protocolId: String) {
        guard !isInPlacementMode else { return }

        isInPlacementMode = true
        placementProtocolId = protocolId

        // Brighten grid dots during placement (from ambient 0.3 to full visibility)
        gridDotsLayer.run(SKAction.fadeAlpha(to: 1.0, duration: DesignAnimations.Timing.quick))

        // Subtle pulse to draw attention to available slots
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.12, duration: 0.6),
            SKAction.scale(to: 1.0, duration: 0.6)
        ])
        pulse.timingMode = .easeInEaseOut
        gridDotsLayer.run(SKAction.repeatForever(pulse), withKey: "placementPulse")

        // Update grid dots to show only unoccupied slots
        updateGridDotsVisibility()
    }

    /// Exit placement mode - dim grid dots back to ambient level
    func exitPlacementMode() {
        guard isInPlacementMode else { return }

        isInPlacementMode = false
        placementProtocolId = nil

        // Stop placement pulse and dim grid dots back to ambient visibility
        gridDotsLayer.removeAction(forKey: "placementPulse")
        gridDotsLayer.setScale(1.0)
        gridDotsLayer.run(SKAction.fadeAlpha(to: 0.3, duration: DesignAnimations.Timing.quick))

        // Remove active slot highlight
        activeSlotHighlight?.removeFromParent()
        activeSlotHighlight = nil
    }

    /// Update grid dot visibility based on slot occupation
    func updateGridDotsVisibility() {
        guard let state = state else { return }

        for slot in state.towerSlots {
            // Use SKNode instead of SKShapeNode since createGridDot now returns a container
            if let dotNode = gridDotsLayer.childNode(withName: "gridDot_\(slot.id)") {
                if slot.occupied {
                    dotNode.alpha = 0
                } else {
                    dotNode.alpha = 1
                }
            }
        }
    }

    /// Highlight the nearest valid slot during drag with enhanced visuals
    func highlightNearestSlot(_ slot: TowerSlot?, canAfford: Bool) {
        // Remove existing highlight
        activeSlotHighlight?.removeFromParent()
        activeSlotHighlight = nil

        guard let slot = slot, !slot.occupied else { return }

        // Create highlight container
        let container = SKNode()
        container.position = convertToScene(slot.position)
        container.name = "slotHighlight"
        container.zPosition = 8

        // Outer glow ring
        let outerRing = SKShapeNode(circleOfRadius: 45)
        outerRing.fillColor = .clear
        outerRing.strokeColor = canAfford ? DesignColors.primaryUI : DesignColors.dangerUI
        outerRing.lineWidth = 3
        outerRing.glowWidth = 3.0  // Placement crosshair (1 node, shown during drag only)
        outerRing.alpha = 0.8
        container.addChild(outerRing)

        // Inner fill
        let innerFill = SKShapeNode(circleOfRadius: 35)
        innerFill.fillColor = (canAfford ? DesignColors.primaryUI : DesignColors.dangerUI).withAlphaComponent(0.2)
        innerFill.strokeColor = .clear
        container.addChild(innerFill)

        // Crosshair lines for targeting aesthetic
        let crosshairSize: CGFloat = 50
        let crosshairGap: CGFloat = 15
        let crosshairColor = canAfford ? DesignColors.primaryUI : DesignColors.dangerUI

        // Horizontal lines
        for xSign in [-1.0, 1.0] as [CGFloat] {
            let line = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: crosshairGap * xSign, y: 0))
            path.addLine(to: CGPoint(x: crosshairSize * xSign, y: 0))
            line.path = path
            line.strokeColor = crosshairColor.withAlphaComponent(0.8)
            line.lineWidth = 2
            container.addChild(line)
        }

        // Vertical lines
        for ySign in [-1.0, 1.0] as [CGFloat] {
            let line = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: crosshairGap * ySign))
            path.addLine(to: CGPoint(x: 0, y: crosshairSize * ySign))
            line.path = path
            line.strokeColor = crosshairColor.withAlphaComponent(0.8)
            line.lineWidth = 2
            container.addChild(line)
        }

        // Corner brackets for circuit board aesthetic
        let bracketSize: CGFloat = 12
        let bracketOffset: CGFloat = 32
        for (xSign, ySign) in [(1, 1), (1, -1), (-1, 1), (-1, -1)] as [(CGFloat, CGFloat)] {
            let bracket = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: bracketOffset * xSign, y: (bracketOffset + bracketSize) * ySign))
            path.addLine(to: CGPoint(x: bracketOffset * xSign, y: bracketOffset * ySign))
            path.addLine(to: CGPoint(x: (bracketOffset + bracketSize) * xSign, y: bracketOffset * ySign))
            bracket.path = path
            bracket.strokeColor = crosshairColor.withAlphaComponent(0.6)
            bracket.lineWidth = 2
            bracket.lineCap = .round
            container.addChild(bracket)
        }

        // Pulse animation
        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.4),
            SKAction.scale(to: 1.0, duration: 0.4)
        ]))
        container.run(pulse)

        addChild(container)
        activeSlotHighlight = container
    }


    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Check for locked spawn point tap (8-lane mega-board)
        // Locked spawn points show unlock UI when tapped
        if isMotherboardMap {
            let allLanes = MotherboardLaneConfig.createAllLanes()
            let unlockedSectorIds = gameStateDelegate?.getUnlockedSectorIds() ?? Set([SectorID.power.rawValue])

            // Check locked lanes for spawn point tap
            for lane in allLanes {
                let isUnlocked = lane.isStarterLane || unlockedSectorIds.contains(lane.sectorId)

                // Only respond to taps on locked spawn points
                if !isUnlocked {
                    let spawnPos = convertToScene(lane.spawnPoint)
                    let hitRadius: CGFloat = 80  // Generous tap target

                    let dx = location.x - spawnPos.x
                    let dy = location.y - spawnPos.y
                    let distance = sqrt(dx*dx + dy*dy)

                    if distance < hitRadius {
                        HapticsService.shared.play(.light)
                        gameStateDelegate?.spawnPointTapped(lane)
                        return
                    }
                }
            }

        }

        // Check for boss tap (to engage boss fight)
        if let state = state, state.bossActive, !state.bossEngaged,
           let bossId = state.activeBossId,
           let boss = state.enemies.first(where: { $0.id == bossId }) {
            let bossScenePos = convertToScene(boss.position)
            let bossTapRadius: CGFloat = max(boss.size * 1.5, 60)  // Generous tap target for boss
            let dx = location.x - bossScenePos.x
            let dy = location.y - bossScenePos.y
            let distance = sqrt(dx * dx + dy * dy)
            if distance < bossTapRadius {
                HapticsService.shared.play(.medium)
                gameStateDelegate?.bossTapped()
                return
            }
        }

        // Check for tower touch (start long-press timer for drag)
        // Use distance-based detection to avoid catching range indicator taps
        let towerTapRadius: CGFloat = 50  // Only tap the tower body, not the range
        for (towerId, node) in towerNodes {
            let dx = location.x - node.position.x
            let dy = location.y - node.position.y
            let distance = sqrt(dx * dx + dy * dy)
            if distance < towerTapRadius {
                dragStartPosition = location
                // Start long-press timer for drag-to-merge
                longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                    self?.startDraggingTower(towerId: towerId, from: location)
                }
                return
            }
        }

        // Check for slot selection (distance-based, no invisible nodes needed)
        if let state = state {
            for slot in state.towerSlots where !slot.occupied {
                let slotPos = convertToScene(slot.position)
                let dx = location.x - slotPos.x
                let dy = location.y - slotPos.y
                if dx * dx + dy * dy < (slot.size / 2) * (slot.size / 2) {
                    selectedSlotId = slot.id
                    gameStateDelegate?.slotSelected(slot.id)
                    return
                }
            }
        }

        // Deselect
        selectedSlotId = nil
        selectedTowerId = nil
        gameStateDelegate?.towerSelected(nil)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Cancel long-press if moved too far before timer
        if let startPos = dragStartPosition, !isDragging {
            let dx = location.x - startPos.x
            let dy = location.y - startPos.y
            if sqrt(dx*dx + dy*dy) > 10 {
                cancelLongPress()
            }
        }

        // Update drag position
        if isDragging, let dragNode = dragNode {
            dragNode.position = location
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Cancel any pending long-press
        cancelLongPress()

        if isDragging, let draggedId = draggedTowerId {
            // Check if dropped in removal zone (bottom of visible screen = deck area)
            let touchInView = touch.location(in: self.view)
            let viewHeight = self.view?.bounds.height ?? 800
            let removalZoneThreshold = viewHeight * 0.85  // Bottom 15% of screen

            if touchInView.y > removalZoneThreshold {
                // Tower dropped in removal zone - remove it
                performTowerRemoval(towerId: draggedId)
            }
            // Check for merge with compatible tower (before empty slot check)
            else if let targetTowerId = findMergeCandidateAtLocation(location) {
                performTowerMerge(sourceTowerId: draggedId, targetTowerId: targetTowerId)
            }
            // Check for move to empty slot
            else if let targetSlotId = findEmptySlotAtLocation(location) {
                performTowerMove(towerId: draggedId, toSlotId: targetSlotId)
            }

            // End drag
            endDrag()
        } else {
            // Normal tap - select tower (use distance-based, not node bounds)
            let towerTapRadius: CGFloat = 50
            for (towerId, node) in towerNodes {
                let dx = location.x - node.position.x
                let dy = location.y - node.position.y
                let distance = sqrt(dx * dx + dy * dy)
                if distance < towerTapRadius {
                    selectedTowerId = selectedTowerId == towerId ? nil : towerId
                    gameStateDelegate?.towerSelected(selectedTowerId)
                    updateRangeIndicatorVisibility()
                    return
                }
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        cancelLongPress()
        endDrag()
    }

    // MARK: - Drag Operations

    func startDraggingTower(towerId: String, from position: CGPoint) {
        guard let tower = state?.towers.first(where: { $0.id == towerId }) else { return }

        isDragging = true
        draggedTowerId = towerId
        longPressTimer = nil

        // Find empty slots for repositioning
        if let state = state {
            validMoveSlots = Set(state.towerSlots.filter { !$0.occupied }.map { $0.id })

            // Find merge-compatible towers (same protocol, same star level, can merge)
            mergeCandidateIds = Set(
                state.towers
                    .filter { $0.id != towerId
                        && $0.protocolId == tower.protocolId
                        && $0.starLevel == tower.starLevel
                        && $0.canMerge }
                    .map { $0.id }
            )
        }

        // Create drag visual
        let dragVisual = SKNode()

        // Ghost tower
        let ghost = SKShapeNode(circleOfRadius: 20)
        ghost.fillColor = (UIColor(hex: tower.color) ?? .blue).withAlphaComponent(0.7)
        ghost.strokeColor = .white
        ghost.lineWidth = 2
        ghost.glowWidth = 2.0  // Drag ghost (1 node, only during drag)
        dragVisual.addChild(ghost)

        // Move indicator
        let icon = SKLabelNode(text: "↔")
        icon.fontSize = 16
        icon.verticalAlignmentMode = .center
        dragVisual.addChild(icon)

        dragVisual.position = position
        dragVisual.zPosition = 100
        dragNode = dragVisual
        addChild(dragVisual)

        // Show empty slots as valid move targets
        showEmptySlotHighlights()

        // Show merge candidates with distinct highlight
        showMergeCandidateHighlights()

        // Dim the source tower
        if let sourceNode = towerNodes[towerId] {
            sourceNode.alpha = 0.3
        }

        // Haptic feedback
        HapticsService.shared.play(.selection)
    }

    /// Show highlights on all empty slots during tower drag
    func showEmptySlotHighlights() {
        guard let state = state else { return }

        for slot in state.towerSlots where !slot.occupied {
            if let dotNode = gridDotsLayer.childNode(withName: "gridDot_\(slot.id)") {
                // Create move highlight
                let highlight = SKShapeNode(circleOfRadius: 35)
                highlight.fillColor = DesignColors.primaryUI.withAlphaComponent(0.15)
                highlight.strokeColor = DesignColors.primaryUI.withAlphaComponent(0.6)
                highlight.lineWidth = 2
                highlight.name = "moveHighlight"
                highlight.zPosition = 10
                dotNode.addChild(highlight)

                // Pulse animation
                let pulse = SKAction.sequence([
                    SKAction.scale(to: 1.1, duration: 0.5),
                    SKAction.scale(to: 1.0, duration: 0.5)
                ])
                highlight.run(SKAction.repeatForever(pulse))
            }
        }
    }

    /// Hide empty slot highlights
    func hideEmptySlotHighlights() {
        gridDotsLayer.enumerateChildNodes(withName: "*/moveHighlight") { node, _ in
            node.removeFromParent()
        }
    }

    // MARK: - Merge Highlights

    /// Show merge-compatible tower highlights during drag
    func showMergeCandidateHighlights() {
        for towerId in mergeCandidateIds {
            guard let towerNode = towerNodes[towerId] else { continue }

            // Yellow pulsing ring
            let highlight = SKShapeNode(circleOfRadius: 35)
            highlight.fillColor = UIColor.yellow.withAlphaComponent(0.15)
            highlight.strokeColor = UIColor.yellow.withAlphaComponent(0.8)
            highlight.lineWidth = 2.5
            highlight.name = "mergeHighlight"
            highlight.zPosition = 10
            towerNode.addChild(highlight)

            // Star icon above
            let starLabel = SKLabelNode(text: "\u{2605}")
            starLabel.fontSize = 14
            starLabel.fontColor = .yellow
            starLabel.verticalAlignmentMode = .center
            starLabel.position = CGPoint(x: 0, y: 36)
            starLabel.name = "mergeHighlight"
            towerNode.addChild(starLabel)

            // Pulse animation
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.15, duration: 0.4),
                SKAction.scale(to: 1.0, duration: 0.4)
            ])
            highlight.run(SKAction.repeatForever(pulse))
        }
    }

    /// Hide merge candidate highlights
    func hideMergeCandidateHighlights() {
        for (_, node) in towerNodes {
            node.enumerateChildNodes(withName: "mergeHighlight") { child, _ in
                child.removeFromParent()
            }
        }
    }

    /// Find a merge-compatible tower at the drop location
    func findMergeCandidateAtLocation(_ location: CGPoint) -> String? {
        guard let draggedId = draggedTowerId else { return nil }

        for towerId in mergeCandidateIds {
            guard towerId != draggedId, let node = towerNodes[towerId] else { continue }

            let distance = hypot(node.position.x - location.x, node.position.y - location.y)
            if distance < 45 {
                return towerId
            }
        }
        return nil
    }

    // MARK: - Merge Execution

    /// Merge source tower into target tower
    func performTowerMerge(sourceTowerId: String, targetTowerId: String) {
        guard var state = self.state else { return }

        let result = TowerSystem.mergeTowers(
            state: &state,
            sourceTowerId: sourceTowerId,
            targetTowerId: targetTowerId
        )

        switch result {
        case .success(let mergedTower):
            // Capture positions before removing nodes
            let sourcePosition = towerNodes[sourceTowerId]?.position
            let targetPosition = towerNodes[targetTowerId]?.position

            // Remove source tower node immediately (no orphan risk)
            if let sourceNode = towerNodes[sourceTowerId] {
                sourceNode.removeFromParent()
            }

            // Clean up source tower tracking
            towerNodes.removeValue(forKey: sourceTowerId)
            towerNodeRefs.removeValue(forKey: sourceTowerId)
            towerLastAttackTimes.removeValue(forKey: sourceTowerId)
            towerBarrelRotations.removeValue(forKey: sourceTowerId)

            // Update state first so createTowerNode reads correct starLevel
            self.state = state

            // Rebuild target tower node to immediately reflect new star level
            if let oldTargetNode = towerNodes[targetTowerId],
               let targetPos = targetPosition {
                oldTargetNode.removeFromParent()
                towerNodes.removeValue(forKey: targetTowerId)
                towerNodeRefs.removeValue(forKey: targetTowerId)

                // Recreate with updated star level
                let newNode = createTowerNode(tower: mergedTower)
                newNode.position = targetPos
                towerLayer.addChild(newNode)
                towerNodes[targetTowerId] = newNode

                // Populate cached refs
                var refs = TowerNodeRefs()
                refs.barrel = newNode.childNode(withName: "barrel")
                refs.glowNode = newNode.childNode(withName: "glow")
                if let levelNode = newNode.childNode(withName: "levelIndicator") {
                    refs.levelLabel = levelNode.childNode(withName: "levelLabel") as? SKLabelNode
                }
                refs.starIndicator = newNode.childNode(withName: "starIndicator")
                towerNodeRefs[targetTowerId] = refs

                // Lightweight ghost animation: small circle flies from source to target
                if let srcPos = sourcePosition {
                    let ghost = SKShapeNode(circleOfRadius: 10)
                    ghost.fillColor = UIColor.yellow.withAlphaComponent(0.8)
                    ghost.strokeColor = .white
                    ghost.lineWidth = 1
                    ghost.blendMode = .add
                    ghost.position = srcPos
                    ghost.zPosition = 55
                    particleLayer.addChild(ghost)

                    let moveAction = SKAction.move(to: targetPos, duration: 0.2)
                    moveAction.timingMode = .easeIn
                    let fadeAction = SKAction.fadeOut(withDuration: 0.2)
                    let scaleAction = SKAction.scale(to: 0.3, duration: 0.2)
                    let group = SKAction.group([moveAction, fadeAction, scaleAction])
                    ghost.run(SKAction.sequence([group, SKAction.removeFromParent()]))
                }

                // Merge celebration
                spawnMergeParticles(at: targetPos, starLevel: mergedTower.starLevel)

                // Scale bounce
                let scaleUp = SKAction.scale(to: 1.4, duration: 0.15)
                let scaleBack = SKAction.scale(to: 1.0, duration: 0.25)
                scaleBack.timingMode = .easeOut
                newNode.run(SKAction.sequence([scaleUp, scaleBack]))
            }

            gameStateDelegate?.gameStateUpdated(state)

            // Persist
            StorageService.shared.saveTDSession(TDSessionState.from(gameState: state))

            // Haptic
            HapticsService.shared.play(.towerMerge)
            AudioManager.shared.play(.towerUpgrade)

        default:
            HapticsService.shared.play(.warning)
            AudioManager.shared.play(.uiDeny)
        }
    }

    /// Spawn merge celebration particles
    func spawnMergeParticles(at position: CGPoint, starLevel: Int) {
        let particleCount = 12 + starLevel * 4
        for i in 0..<particleCount {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...4))
            particle.fillColor = .yellow
            particle.strokeColor = .white
            particle.lineWidth = 0.5
            particle.position = position
            particle.zPosition = 55
            particle.blendMode = .add

            let angle = CGFloat(i) * (.pi * 2 / CGFloat(particleCount))
            let distance: CGFloat = CGFloat(35 + starLevel * 8)

            let moveAction = SKAction.move(
                by: CGVector(dx: cos(angle) * distance, dy: sin(angle) * distance),
                duration: 0.35
            )
            moveAction.timingMode = .easeOut
            let fadeAction = SKAction.fadeOut(withDuration: 0.35)
            let group = SKAction.group([moveAction, fadeAction])
            particle.run(SKAction.sequence([group, SKAction.removeFromParent()]))

            particleLayer.addChild(particle)
        }
    }

    /// Find empty slot at drop location for tower repositioning
    func findEmptySlotAtLocation(_ location: CGPoint) -> String? {
        guard let state = state else { return nil }

        for slot in state.towerSlots where validMoveSlots.contains(slot.id) {
            let slotScenePos = convertToScene(slot.position)
            let distance = hypot(slotScenePos.x - location.x, slotScenePos.y - location.y)
            if distance < 45 {  // Slightly larger hit area for easier placement
                return slot.id
            }
        }
        return nil
    }

    /// Move tower to a new empty slot
    func performTowerMove(towerId: String, toSlotId: String) {
        guard var state = self.state,
              let towerIndex = state.towers.firstIndex(where: { $0.id == towerId }),
              let newSlotIndex = state.towerSlots.firstIndex(where: { $0.id == toSlotId }),
              !state.towerSlots[newSlotIndex].occupied
        else { return }

        let tower = state.towers[towerIndex]
        let oldSlotId = tower.slotId

        // Free old slot
        if let oldSlotIndex = state.towerSlots.firstIndex(where: { $0.id == oldSlotId }) {
            state.towerSlots[oldSlotIndex].occupied = false
            state.towerSlots[oldSlotIndex].towerId = nil
        }

        // Move tower to new slot
        let newSlot = state.towerSlots[newSlotIndex]
        state.towers[towerIndex].x = newSlot.x
        state.towers[towerIndex].y = newSlot.y
        state.towers[towerIndex].slotId = toSlotId

        // Occupy new slot
        state.towerSlots[newSlotIndex].occupied = true
        state.towerSlots[newSlotIndex].towerId = towerId

        self.state = state

        // Animate tower movement
        if let towerNode = towerNodes[towerId] {
            let newScenePos = convertToScene(CGPoint(x: newSlot.x, y: newSlot.y))
            let moveAction = SKAction.move(to: newScenePos, duration: 0.3)
            moveAction.timingMode = .easeOut
            towerNode.run(moveAction)
        }

        // Update slot visuals
        if let oldSlotIndex = state.towerSlots.firstIndex(where: { $0.id == oldSlotId }) {
            updateSlotVisual(slot: state.towerSlots[oldSlotIndex])
        }
        updateSlotVisual(slot: state.towerSlots[newSlotIndex])

        HapticsService.shared.play(.selection)

        // Persist and notify
        StorageService.shared.saveTDSession(TDSessionState.from(gameState: state))
        gameStateDelegate?.gameStateUpdated(state)
    }

    func performTowerRemoval(towerId: String) {
        guard var state = state,
              let towerIndex = state.towers.firstIndex(where: { $0.id == towerId })
        else { return }

        let tower = state.towers[towerIndex]

        // Free the slot
        if let slotIndex = state.towerSlots.firstIndex(where: { $0.id == tower.slotId }) {
            state.towerSlots[slotIndex].occupied = false
            state.towerSlots[slotIndex].towerId = nil
        }

        // Remove tower from state
        state.towers.remove(at: towerIndex)

        // Remove tower node immediately, animate a lightweight ghost for visual feedback
        if let towerNode = towerNodes[towerId] {
            let pos = towerNode.position
            let towerColor = UIColor(hex: tower.color) ?? .blue
            towerNode.removeFromParent()

            // Ghost sell animation in particle layer
            let ghost = SKShapeNode(circleOfRadius: 14)
            ghost.fillColor = towerColor.withAlphaComponent(0.5)
            ghost.strokeColor = .white.withAlphaComponent(0.6)
            ghost.lineWidth = 1
            ghost.position = pos
            ghost.zPosition = 55
            particleLayer.addChild(ghost)

            let fadeOut = SKAction.fadeOut(withDuration: 0.25)
            let scaleDown = SKAction.scale(to: 0.3, duration: 0.25)
            let group = SKAction.group([fadeOut, scaleDown])
            ghost.run(SKAction.sequence([group, SKAction.removeFromParent()]))
        }

        // Remove from tracking
        towerNodes.removeValue(forKey: towerId)
        towerNodeRefs.removeValue(forKey: towerId)
        towerLastAttackTimes.removeValue(forKey: towerId)
        towerBarrelRotations.removeValue(forKey: towerId)

        // Update state
        self.state = state
        gameStateDelegate?.gameStateUpdated(state)

        // Persist
        StorageService.shared.saveTDSession(TDSessionState.from(gameState: state))

        // Feedback
        HapticsService.shared.play(.light)
    }

    func endDrag() {
        isDragging = false

        // Remove drag visual
        dragNode?.removeFromParent()
        dragNode = nil

        // Restore source tower opacity
        if let sourceId = draggedTowerId, let sourceNode = towerNodes[sourceId] {
            sourceNode.alpha = 1.0
        }

        // Hide empty slot move highlights and merge highlights
        hideEmptySlotHighlights()
        hideMergeCandidateHighlights()

        draggedTowerId = nil
        validMoveSlots.removeAll()
        mergeCandidateIds.removeAll()
        dragStartPosition = nil
    }

    func cancelLongPress() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }

    // MARK: - Range Indicator

    func updateRangeIndicatorVisibility() {
        for (towerId, node) in towerNodes {
            // Use cached ref if available, fall back to name lookup for compatibility
            let rangeNode: SKNode? = towerNodeRefs[towerId]?.rangeNode ?? node.childNode(withName: "range")
            if let rangeNode = rangeNode as? SKShapeNode {
                let isSelected = towerId == selectedTowerId
                rangeNode.isHidden = !isSelected

                if isSelected {
                    // Add subtle pulse animation
                    let pulse = SKAction.sequence([
                        SKAction.scale(to: 1.02, duration: 0.5),
                        SKAction.scale(to: 0.98, duration: 0.5)
                    ])
                    rangeNode.run(SKAction.repeatForever(pulse), withKey: "rangePulse")
                } else {
                    rangeNode.removeAction(forKey: "rangePulse")
                    rangeNode.setScale(1.0)
                }
            }
        }
    }

}
