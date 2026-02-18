import SpriteKit

// MARK: - Level of Detail & Viewport Culling

extension TDGameScene {

    /// Update Level of Detail visibility based on camera zoom and viewport culling
    func updateTowerLOD() {
        // Show details when zoomed in (scale < 0.4 means close-up)
        let showDetail = currentScale < 0.4
        let targetAlpha: CGFloat = showDetail ? 1.0 : 0.0

        // Calculate visible rect once for performance
        let visibleRect = calculateVisibleRect()
        // Expand rect slightly to avoid animation pop-in at edges
        let paddedRect = visibleRect.insetBy(dx: -100, dy: -100)

        for (towerId, node) in towerNodes {
            // LOD detail visibility based on zoom (lazy creation)
            if showDetail {
                var refs = towerNodeRefs[towerId] ?? TowerNodeRefs()
                // Lazily create LOD detail on first zoom-in
                if refs.lodDetail == nil, let tower = state?.towers.first(where: { $0.id == towerId }) {
                    let towerColor = UIColor(hex: tower.color) ?? TowerColors.color(for: tower.protocolId)
                    let lodDetail = TowerVisualFactory.createLODDetail(
                        damage: tower.effectiveDamage,
                        attackSpeed: tower.effectiveAttackSpeed,
                        projectileCount: tower.projectileCount,
                        level: tower.level,
                        color: towerColor
                    )
                    lodDetail.name = "lodDetail"
                    lodDetail.alpha = 0
                    lodDetail.zPosition = 20
                    node.addChild(lodDetail)
                    refs.lodDetail = lodDetail
                    towerNodeRefs[towerId] = refs
                }
                if let lodDetail = refs.lodDetail {
                    // Update DPS label if tower stats changed (e.g. after merge)
                    if let tower = state?.towers.first(where: { $0.id == towerId }),
                       let dpsLabel = lodDetail.childNode(withName: "dpsLabel") as? SKLabelNode {
                        let currentDPS = tower.effectiveDamage * tower.effectiveAttackSpeed * CGFloat(tower.projectileCount)
                        let newText = L10n.Stats.dpsValue(currentDPS)
                        if dpsLabel.text != newText {
                            dpsLabel.text = newText
                        }
                    }
                    if abs(lodDetail.alpha - targetAlpha) > 0.01 {
                        lodDetail.removeAction(forKey: "lodFade")
                        let fadeAction = SKAction.fadeAlpha(to: targetAlpha, duration: 0.2)
                        lodDetail.run(fadeAction, withKey: "lodFade")
                    }
                }
            } else {
                // Not zoomed in — only animate fade-out if LOD detail exists
                if let refs = towerNodeRefs[towerId], let lodDetail = refs.lodDetail {
                    if abs(lodDetail.alpha - targetAlpha) > 0.01 {
                        lodDetail.removeAction(forKey: "lodFade")
                        let fadeAction = SKAction.fadeAlpha(to: targetAlpha, duration: 0.2)
                        lodDetail.run(fadeAction, withKey: "lodFade")
                    }
                }
            }

            // Animation LOD: pause/resume actions for off-screen towers
            let isVisible = paddedRect.contains(node.position)

            if isVisible && pausedTowerAnimations.contains(towerId) {
                // Tower came into view - resume animations
                node.isPaused = false
                pausedTowerAnimations.remove(towerId)
            } else if !isVisible && !pausedTowerAnimations.contains(towerId) {
                // Tower went off-screen - pause animations
                node.isPaused = true
                pausedTowerAnimations.insert(towerId)
            }
        }
    }

    /// Calculate the visible rectangle in scene coordinates
    func calculateVisibleRect() -> CGRect {
        guard let camera = cameraNode, let view = self.view else {
            return CGRect(x: 0, y: 0, width: size.width, height: size.height)
        }

        // Account for .aspectFill scene-to-view scaling.
        // With .aspectFill the scene is scaled uniformly so the larger ratio fills the view,
        // meaning 1 view point != 1 scene point. Dividing by this factor converts
        // view-space dimensions back to scene-space dimensions.
        let aspectFillScale = max(view.bounds.width / size.width,
                                  view.bounds.height / size.height)
        let viewWidth = (view.bounds.width / aspectFillScale) * currentScale
        let viewHeight = (view.bounds.height / aspectFillScale) * currentScale

        return CGRect(
            x: camera.position.x - viewWidth / 2,
            y: camera.position.y - viewHeight / 2,
            width: viewWidth,
            height: viewHeight
        )
    }

    // MARK: - Background Detail LOD (Performance)

    /// Hide background decorations, parallax, and grid dots when zoomed out.
    /// These small details are invisible at high zoom levels and waste GPU rendering time.
    func updateBackgroundDetailLOD() {
        let shouldShow = currentScale < 0.56
        guard shouldShow != backgroundDetailVisible else { return }
        backgroundDetailVisible = shouldShow

        // Toggle parallax layers
        for (layer, _) in parallaxLayers {
            layer.isHidden = !shouldShow
        }

        // Toggle sector decoration nodes
        backgroundLayer.enumerateChildNodes(withName: "sectorDecor_*") { node, _ in
            node.isHidden = !shouldShow
        }

        // Toggle grid dots layer (small dots not visible when zoomed out)
        gridDotsLayer?.isHidden = !shouldShow
    }

    // MARK: - Glow LOD (Performance)

    /// Disable expensive glowWidth (Gaussian blur shader) when zoomed out.
    /// Each glowWidth > 0 node triggers a separate GPU blur pass per frame.
    /// At zoomed-out view, glows are sub-pixel and invisible — pure waste.
    func updateGlowLOD() {
        let shouldEnable = currentScale < 0.5
        guard shouldEnable != glowLODEnabled else { return }
        glowLODEnabled = shouldEnable

        for entry in glowNodes {
            entry.node.glowWidth = shouldEnable ? entry.normalGlowWidth : 0
        }
    }

    /// Hide/unhide path LEDs when zoomed out.
    /// LEDs are individual nodes with blendMode=.add — still cost draw calls even when frozen.
    func updateLEDVisibility() {
        let shouldHide = currentScale >= 0.8
        guard shouldHide != ledsHidden else { return }
        ledsHidden = shouldHide

        for (_, leds) in pathLEDNodes {
            for led in leds {
                led.isHidden = shouldHide
            }
        }
    }

    // MARK: - Sector Visibility Culling (Performance)

    /// Update which sectors are visible and pause/resume ambient effects accordingly
    func updateSectorVisibility(currentTime: TimeInterval) {
        // Only update every 0.5 seconds to avoid per-frame overhead
        guard currentTime - lastVisibilityUpdate >= visibilityUpdateInterval else { return }
        lastVisibilityUpdate = currentTime

        let visibleRect = calculateVisibleRect()
        // Expand rect to include sectors partially visible (sector size is 1400)
        let paddedRect = visibleRect.insetBy(dx: -700, dy: -700)

        let megaConfig = cachedMegaBoardConfig
        var newVisibleSectors = Set<String>()

        for sector in megaConfig.sectors {
            let sectorRect = CGRect(
                x: sector.worldX,
                y: sector.worldY,
                width: sector.width,
                height: sector.height
            )

            if paddedRect.intersects(sectorRect) {
                newVisibleSectors.insert(sector.id)
            }
        }

        // Resume effects for sectors that came into view
        let sectorsNowVisible = newVisibleSectors.subtracting(visibleSectorIds)
        for sectorId in sectorsNowVisible {
            resumeSectorAmbientEffects(sectorId: sectorId)
        }

        // Pause effects for sectors that went out of view
        let sectorsNowHidden = visibleSectorIds.subtracting(newVisibleSectors)
        for sectorId in sectorsNowHidden {
            pauseSectorAmbientEffects(sectorId: sectorId)
        }

        visibleSectorIds = newVisibleSectors
    }

    /// Pause ambient effect actions for a sector
    func pauseSectorAmbientEffects(sectorId: String) {
        // Each sector has actions with keys like "gpuHeat_gpu", "ramPulse_ram", etc.
        let actionKeys = [
            "gpuHeat_\(sectorId)",
            "ramPulse_\(sectorId)",
            "storageTrail_\(sectorId)",
            "networkRings_\(sectorId)",
            "ioBurst_\(sectorId)",
            "cacheFlash_\(sectorId)",
            "cacheLines_\(sectorId)"
        ]

        for key in actionKeys {
            backgroundLayer.removeAction(forKey: key)
        }
    }

    /// Resume ambient effect actions for a sector (re-start them)
    func resumeSectorAmbientEffects(sectorId: String) {
        guard let sector = cachedMegaBoardConfig.sectors.first(where: { $0.id == sectorId }) else { return }

        // Re-start the appropriate ambient effects based on sector theme
        switch sector.theme {
        case .graphics:
            // GPU: Re-add heat shimmer spawning
            let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .red
            let center = CGPoint(x: sector.worldX + sector.width / 2, y: sector.worldY + sector.height / 2)
            let spawnShimmer = SKAction.run { [weak self] in
                guard let self = self else { return }
                self.spawnHeatShimmer(at: center, color: themeColor)
            }
            let shimmerSequence = SKAction.repeatForever(SKAction.sequence([
                spawnShimmer,
                SKAction.wait(forDuration: 0.15)
            ]))
            backgroundLayer.run(shimmerSequence, withKey: "gpuHeat_\(sectorId)")

        case .memory:
            // RAM: Re-add data pulse
            let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .green
            startRAMDataPulse(sector: sector, color: themeColor)

        case .storage:
            // Storage: Re-add data trail
            let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .purple
            startStorageDataTrail(sector: sector, color: themeColor)

        case .network:
            // Network: Re-add signal rings
            startNetworkSectorAmbient(sector: sector)

        case .io:
            // I/O: Re-add data bursts
            let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .orange
            startIODataBurst(sector: sector, color: themeColor)

        case .processing:
            // Cache: Re-add flash and speed lines
            startCacheSectorAmbient(sector: sector)

        case .power:
            // PSU has minimal effects, nothing to resume
            break
        }
    }
}
