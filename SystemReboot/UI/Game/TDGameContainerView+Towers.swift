import SwiftUI

// MARK: - TDGameContainerView Towers
// Tower deck, drag preview, drag handling, coordinate conversion, tower selection/info

extension TDGameContainerView {

    // MARK: - Tower Deck (Large Touch-Friendly)

    func towerDeck(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Hint text
            Text(L10n.Motherboard.dragToDeploy)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)
                .padding(.top, 6)

            // Scrollable tower cards - large and touch-friendly
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    let protocols = getCompiledProtocols()
                    ForEach(Array(protocols.enumerated()), id: \.element.id) { index, proto in
                        ProtocolDeckCard(
                            protocol: proto,
                            hash: gameState?.hash ?? 0,
                            onDragStart: { startDragFromDeck(protocolId: proto.id) },
                            onDragChanged: { value in updateDragPosition(value, geometry: geometry) },
                            onDragEnded: { endDragFromDeck() }
                        )
                        // FTUE: Glow on first card for new players
                        .tutorialGlow(
                            color: DesignColors.primary,
                            isActive: index == 0 &&
                                !appState.currentPlayer.firstTowerPlaced &&
                                TutorialHintManager.shared.shouldShowHint(.deckCard, profile: appState.currentPlayer)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .frame(height: 110)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.95), Color.black.opacity(0.7)],
                startPoint: .bottom,
                endPoint: .top
            )
        )
    }

    // MARK: - Drag Preview Overlay (Progressive Disclosure)
    // Note: Grid dots are now shown in the SpriteKit scene, not here
    // This overlay only shows the dragged tower preview

    func dragPreviewOverlay(protocolId: String, geometry: GeometryProxy) -> some View {
        ZStack {
            if let proto = ProtocolLibrary.get(protocolId) {
                let displayPosition = nearestValidSlot != nil && canAffordDraggedTower
                    ? convertGameToScreen(nearestValidSlot!.position, geometry: geometry)
                    : dragPosition
                let protoColor = Color(hex: proto.color) ?? DesignColors.primary
                let range = proto.firewallStats.range

                ZStack {
                    // Range preview circle (shown when snapped to valid slot)
                    if nearestValidSlot != nil && canAffordDraggedTower {
                        Circle()
                            .fill(protoColor.opacity(DesignLayout.rangeCircleFillOpacity))
                            .frame(width: range * 0.6, height: range * 0.6)

                        Circle()
                            .stroke(protoColor.opacity(DesignLayout.rangeCircleStrokeOpacity), lineWidth: 2)
                            .frame(width: range * 0.6, height: range * 0.6)
                    }

                    // Tower preview body
                    Circle()
                        .fill(protoColor.opacity(DesignLayout.towerPreviewOpacity))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(
                                    canAffordDraggedTower ? Color.white : DesignColors.danger,
                                    lineWidth: 2
                                )
                        )
                        .shadow(
                            color: canAffordDraggedTower
                                ? protoColor.opacity(0.6)
                                : DesignColors.danger.opacity(0.4),
                            radius: canAffordDraggedTower ? 12 : 6
                        )

                    // Protocol icon
                    Image(systemName: proto.iconName)
                        .font(DesignTypography.headline(18))
                        .foregroundColor(.white)

                    // Cost indicator (Hash)
                    Text("Ħ\(TowerSystem.towerPlacementCost(rarity: proto.rarity))")
                        .font(DesignTypography.caption(11))
                        .fontWeight(.bold)
                        .foregroundColor(canAffordDraggedTower ? DesignColors.primary : DesignColors.danger)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DesignColors.surface.opacity(0.9))
                        .cornerRadius(4)
                        .offset(y: 32)
                }
                .position(displayPosition)
                .animation(DesignAnimations.quick, value: nearestValidSlot?.id)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Drag Handling (Progressive Disclosure)

    func startDragFromDeck(protocolId: String) {
        isDraggingFromDeck = true
        draggedProtocolId = protocolId
        previousNearestSlot = nil
        canAffordDraggedTower = TowerPlacementService.canAfford(protocolId: protocolId, hash: gameState?.hash ?? 0)

        // Enter placement mode - shows grid dots (progressive disclosure)
        scene?.enterPlacementMode(protocolId: protocolId)

        HapticsService.shared.play(.selection)
    }

    func updateDragPosition(_ value: DragGesture.Value, geometry: GeometryProxy) {
        dragPosition = value.location

        if let state = gameState {
            let gamePos = convertScreenToGame(dragPosition, geometry: geometry)
            let cameraScale = scene?.cameraScale ?? 1.0
            let snap = TowerPlacementService.snapDistance(cameraScale: cameraScale, mapWidth: state.map.width)
            let nearest = TowerPlacementService.findNearestSlot(gamePoint: gamePos, slots: state.towerSlots, snapDistance: snap)

            if nearestValidSlot?.id != nearest?.id {
                previousNearestSlot = nearestValidSlot
                nearestValidSlot = nearest

                scene?.highlightNearestSlot(nearest, canAfford: canAffordDraggedTower)

                if nearest != nil && canAffordDraggedTower {
                    HapticsService.shared.play(.slotSnap)
                }
            }
        }
    }

    func endDragFromDeck() {
        // Exit placement mode - hides grid dots
        scene?.exitPlacementMode()

        defer {
            isDraggingFromDeck = false
            draggedProtocolId = nil
            nearestValidSlot = nil
            previousNearestSlot = nil
        }

        // Place tower if valid
        if let protocolId = draggedProtocolId,
           let slot = nearestValidSlot,
           canAffordDraggedTower {
            scene?.placeTower(protocolId: protocolId, slotId: slot.id, profile: appState.currentPlayer)
            HapticsService.shared.play(.towerPlace)

            // FTUE: Track first tower placement
            if !appState.currentPlayer.firstTowerPlaced {
                appState.recordFirstTowerPlacement()
            }
        }
    }

    // MARK: - Coordinate Conversion
    // The SpriteView renders full-screen with .aspectFill scaleMode
    // Game space is 800x600, screen space varies by device
    // With aspectFill, the scene is scaled up until it fills the screen (may crop edges)

    func convertGameToScreen(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        if let scene = scene {
            return scene.convertGameToScreen(gamePoint: point, viewSize: geometry.size)
        }
        let gameSize = CGSize(width: gameState?.map.width ?? 800, height: gameState?.map.height ?? 600)
        return TowerPlacementService.convertGameToScreen(point, screenSize: geometry.size, gameSize: gameSize)
    }

    func convertScreenToGame(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        if let scene = scene {
            return scene.convertScreenToGame(screenPoint: point, viewSize: geometry.size)
        }
        let gameSize = CGSize(width: gameState?.map.width ?? 800, height: gameState?.map.height ?? 600)
        return TowerPlacementService.convertScreenToGame(point, screenSize: geometry.size, gameSize: gameSize)
    }

    // MARK: - Tower Selection Menu

    func towerSelectionMenu(slotId: String) -> some View {
        VStack(spacing: 12) {
            Text(L10n.TD.deployFirewall)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)

            ForEach(getCompiledProtocols()) { proto in
                let cost = TowerSystem.towerPlacementCost(rarity: proto.rarity)
                let canAfford = (gameState?.hash ?? 0) >= cost

                Button(action: {
                    placeTower(protocolId: proto.id, slotId: slotId)
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(proto.name)
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                            Text(L10n.Stats.dmgRng(Int(proto.firewallStats.damage), rng: Int(proto.firewallStats.range)))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        Text("Ħ\(cost)")
                            .foregroundColor(canAfford ? .cyan : .red)
                            .fontWeight(.bold)
                            .font(.system(size: 14, design: .monospaced))
                    }
                    .padding(10)
                    .background(RarityColors.color(for: proto.rarity).opacity(0.3))
                    .cornerRadius(8)
                }
                .disabled(!canAfford)
                .opacity(canAfford ? 1 : 0.5)
            }

            Button(L10n.Common.cancel) {
                showTowerMenu = false
                selectedSlotId = nil
            }
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(.gray)
            .padding(.top, 8)
        }
        .padding(16)
        .background(Color.black.opacity(0.95))
        .cornerRadius(16)
        .frame(maxWidth: 300)
    }

    // MARK: - Tower Info Panel

    func towerInfoPanel(tower: Tower, geometry: GeometryProxy) -> some View {
        let towerScreenPos = convertGameToScreen(tower.position, geometry: geometry)
        // Position panel to the side of the tower, avoiding edges
        let panelX = towerScreenPos.x > geometry.size.width / 2
            ? towerScreenPos.x - 120
            : towerScreenPos.x + 120
        let panelY = min(max(towerScreenPos.y, 150), geometry.size.height - 200)

        return VStack(alignment: .leading, spacing: 8) {
            // Header with name and merge stars
            HStack {
                Text(tower.towerName)
                    .font(DesignTypography.headline(16))
                    .foregroundColor(.white)

                Spacer()
            }

            Text(L10n.TD.levelMax(tower.level, max: 10))
                .font(DesignTypography.caption(12))
                .foregroundColor(.gray)

            Divider().background(Color.white.opacity(0.3))

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    TDStatRow(icon: "flame.fill", label: L10n.Stats.dmg, value: String(format: "%.1f", tower.damage), color: .orange)
                    TDStatRow(icon: "scope", label: L10n.Stats.rng, value: String(format: "%.0f", tower.range), color: .blue)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    TDStatRow(icon: "bolt.fill", label: L10n.Stats.spd, value: String(format: "%.2f/s", tower.attackSpeed), color: .yellow)
                    TDStatRow(icon: "chart.line.uptrend.xyaxis", label: L10n.Stats.dps, value: String(format: "%.1f", tower.damage * tower.attackSpeed * CGFloat(tower.projectileCount)), color: .green)
                }
            }
            .font(DesignTypography.caption(12))

            Divider().background(Color.white.opacity(0.3))

            // Action buttons
            HStack(spacing: 8) {
                if tower.canUpgrade {
                    Button(action: { upgradeTower(tower.id) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("Ħ\(tower.upgradeCost)")
                        }
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background((gameState?.hash ?? 0) >= tower.upgradeCost ? Color.cyan : Color.gray)
                        .cornerRadius(6)
                    }
                    .disabled((gameState?.hash ?? 0) < tower.upgradeCost)
                }

                Button(action: { sellTower(tower.id) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                        Text(L10n.Common.recycle)
                    }
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.8))
                    .cornerRadius(6)
                }

                // Close button
                Spacer()
                Button(action: { selectedTowerId = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignTypography.headline(18))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .foregroundColor(.white)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.95))
                .shadow(color: rarityColorForTower(tower).opacity(0.5), radius: 8)
        )
        .frame(width: 200)
        .position(x: panelX, y: panelY)
    }

    private func rarityColorForTower(_ tower: Tower) -> Color {
        return RarityColors.color(for: tower.rarity)
    }
}
