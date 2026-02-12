import SpriteKit

// MARK: - Survival Events & HUD

extension GameScene {

    // MARK: - HUD Setup (Cached - Phase 1.3)

    func setupHUD() {
        hudLayer = SKNode()
        hudLayer.zPosition = 1000

        // For boss mode with larger arena, attach HUD to camera so it stays on screen
        // For other modes, add to scene directly
        if gameState.gameMode == .boss, let cam = cameraNode {
            cam.addChild(hudLayer)
        } else {
            addChild(hudLayer)
        }

        // Health bar constants
        let healthBarWidth: CGFloat = 200
        let healthBarHeight: CGFloat = 20

        // Calculate HUD positions based on whether attached to camera or scene
        let hudWidth = gameState.gameMode == .boss ? screenSize.width : gameState.arena.width
        let hudHeight = gameState.gameMode == .boss ? screenSize.height : gameState.arena.height
        // When attached to camera, positions are relative to camera center (0,0)
        let hudYOffset: CGFloat = gameState.gameMode == .boss ? hudHeight / 2 - 30 : hudHeight - 30
        let hudXOffsetLeft: CGFloat = gameState.gameMode == .boss ? -hudWidth / 2 + 120 : 120
        let hudXCenter: CGFloat = gameState.gameMode == .boss ? 0 : hudWidth / 2
        let hudXOffsetRight: CGFloat = gameState.gameMode == .boss ? hudWidth / 2 - 20 : hudWidth - 20

        // Create health bar background (cached)
        healthBarBg = SKShapeNode(rectOf: CGSize(width: healthBarWidth, height: healthBarHeight), cornerRadius: 4)
        healthBarBg.fillColor = SKColor.darkGray
        healthBarBg.strokeColor = SKColor.white.withAlphaComponent(0.3)
        healthBarBg.position = CGPoint(x: hudXOffsetLeft, y: hudYOffset)
        hudLayer.addChild(healthBarBg)

        // Create health bar fill (cached - update only fillColor and xScale)
        healthBarFill = SKShapeNode(rect: CGRect(
            x: -healthBarWidth / 2,
            y: -healthBarHeight / 2,
            width: healthBarWidth,
            height: healthBarHeight
        ), cornerRadius: 4)
        healthBarFill.fillColor = SKColor.green
        healthBarFill.strokeColor = .clear
        healthBarFill.position = healthBarBg.position
        hudLayer.addChild(healthBarFill)

        // Create health text (cached)
        healthText = SKLabelNode(text: "\(Int(gameState.player.maxHealth))/\(Int(gameState.player.maxHealth))")
        healthText.fontName = "Helvetica-Bold"
        healthText.fontSize = 14
        healthText.fontColor = .white
        healthText.position = CGPoint(x: healthBarBg.position.x, y: healthBarBg.position.y - 5)
        hudLayer.addChild(healthText)

        // Create timer text (cached)
        timerText = SKLabelNode(text: "0:00")
        timerText.fontName = "Helvetica-Bold"
        timerText.fontSize = 24
        timerText.fontColor = .white
        timerText.position = CGPoint(x: hudXCenter, y: hudYOffset)
        hudLayer.addChild(timerText)

        // Create kill counter (cached)
        killText = SKLabelNode(text: L10n.Game.HUD.kills(0))
        killText.fontName = "Helvetica"
        killText.fontSize = 16
        killText.fontColor = .white
        killText.horizontalAlignmentMode = .right
        killText.position = CGPoint(x: hudXOffsetRight, y: hudYOffset)
        hudLayer.addChild(killText)
    }

    // MARK: - Survival Event Visuals Setup

    func setupSurvivalEventVisuals() {
        // Event border (pulsing colored border around arena during events)
        let borderPath = CGMutablePath()
        let inset: CGFloat = 10
        borderPath.addRect(CGRect(
            x: inset,
            y: inset,
            width: gameState.arena.width - inset * 2,
            height: gameState.arena.height - inset * 2
        ))

        eventBorderNode = SKShapeNode(path: borderPath)
        eventBorderNode?.strokeColor = .clear
        eventBorderNode?.fillColor = .clear
        eventBorderNode?.lineWidth = 6
        eventBorderNode?.zPosition = 500
        eventBorderNode?.alpha = 0
        addChild(eventBorderNode!)

        // Event announcement label (top center, below HUD)
        eventAnnouncementLabel = SKLabelNode(text: "")
        eventAnnouncementLabel?.fontName = "Menlo-Bold"
        eventAnnouncementLabel?.fontSize = 28
        eventAnnouncementLabel?.fontColor = .white
        eventAnnouncementLabel?.position = CGPoint(x: gameState.arena.width / 2, y: gameState.arena.height - 70)
        eventAnnouncementLabel?.zPosition = 1001
        eventAnnouncementLabel?.alpha = 0
        addChild(eventAnnouncementLabel!)

        // Event timer label (below announcement)
        eventTimerLabel = SKLabelNode(text: "")
        eventTimerLabel?.fontName = "Menlo"
        eventTimerLabel?.fontSize = 16
        eventTimerLabel?.fontColor = SKColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1)
        eventTimerLabel?.position = CGPoint(x: gameState.arena.width / 2, y: gameState.arena.height - 95)
        eventTimerLabel?.zPosition = 1001
        eventTimerLabel?.alpha = 0
        addChild(eventTimerLabel!)

        // Healing zone (for system restore event)
        healingZoneNode = SKShapeNode(circleOfRadius: 60)
        healingZoneNode?.fillColor = SKColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 0.3) // #22c55e
        healingZoneNode?.strokeColor = SKColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 0.8)
        healingZoneNode?.lineWidth = 3
        healingZoneNode?.zPosition = 15
        healingZoneNode?.alpha = 0
        addChild(healingZoneNode!)

        // Arena overlay for buffer overflow shrink effect
        arenaOverlayNode = SKShapeNode()
        arenaOverlayNode?.zPosition = 20
        arenaOverlayNode?.alpha = 0
        addChild(arenaOverlayNode!)

        // Hash earned display (bottom left)
        hashEarnedLabel = SKLabelNode(text: "Ħ 0")
        hashEarnedLabel?.fontName = "Menlo-Bold"
        hashEarnedLabel?.fontSize = 18
        hashEarnedLabel?.fontColor = SKColor(red: 0.02, green: 0.71, blue: 0.83, alpha: 1) // #06b6d4 cyan
        hashEarnedLabel?.horizontalAlignmentMode = .left
        hashEarnedLabel?.position = CGPoint(x: 20, y: 50)
        hashEarnedLabel?.zPosition = 1001
        addChild(hashEarnedLabel!)

        // Extraction available label (bottom center) - hidden until 3 min
        extractionLabel = SKLabelNode(text: L10n.Game.HUD.extractionReady)
        extractionLabel?.fontName = "Menlo-Bold"
        extractionLabel?.fontSize = 16
        extractionLabel?.fontColor = SKColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 1) // #22c55e
        extractionLabel?.position = CGPoint(x: gameState.arena.width / 2, y: 50)
        extractionLabel?.zPosition = 1001
        extractionLabel?.alpha = 0
        addChild(extractionLabel!)
    }

    // MARK: - Survival Event Rendering

    func renderSurvivalEvents() {
        guard gameState.gameMode == .survival || gameState.gameMode == .arena else {
            // Hide all survival elements if not in survival mode
            eventBorderNode?.alpha = 0
            eventAnnouncementLabel?.alpha = 0
            eventTimerLabel?.alpha = 0
            healingZoneNode?.alpha = 0
            arenaOverlayNode?.alpha = 0
            return
        }

        // Update event border and announcement
        if let activeEvent = gameState.activeEvent {
            // Show event border with appropriate color
            if let borderColor = SurvivalArenaSystem.getEventBorderColor(state: gameState) {
                let color = colorFromHex(borderColor)
                eventBorderNode?.strokeColor = color
                eventBorderNode?.glowWidth = 0  // PERF: was 5 (GPU Gaussian blur)

                // Pulsing effect
                let pulse = 0.5 + 0.3 * sin(CGFloat(gameState.timeElapsed * 4))
                eventBorderNode?.alpha = pulse
            }

            // Show event announcement
            eventAnnouncementLabel?.text = eventName(for: activeEvent)
            eventAnnouncementLabel?.fontColor = eventBorderNode?.strokeColor ?? .white
            eventAnnouncementLabel?.alpha = 1

            // Show event timer (cached to avoid per-frame string allocation)
            if let endTime = gameState.eventEndTime {
                let remaining = max(0, endTime - gameState.timeElapsed)
                let remainingTenths = Int(remaining * 10)  // Cache at 0.1s precision
                if remainingTenths != lastEventTimeRemaining {
                    lastEventTimeRemaining = remainingTenths
                    eventTimerLabel?.text = String(format: "%.1fs remaining", remaining)
                }
                eventTimerLabel?.alpha = 1
            }

            // Event-specific rendering
            renderEventSpecificEffects(event: activeEvent)

        } else {
            // No active event - hide UI elements with fade
            if eventBorderNode?.alpha ?? 0 > 0 {
                eventBorderNode?.alpha = max(0, (eventBorderNode?.alpha ?? 0) - 0.05)
            }
            eventAnnouncementLabel?.alpha = 0
            eventTimerLabel?.alpha = 0
            healingZoneNode?.alpha = 0
            arenaOverlayNode?.alpha = 0
            lastEventTimeRemaining = -1  // Reset cache when no event

            // Reset corrupted obstacle visuals
            resetCorruptedObstacles()
        }

        // === ECONOMY UI ===
        // Update Hash earned display
        if gameState.stats.hashEarned != lastHashEarned {
            lastHashEarned = gameState.stats.hashEarned
            hashEarnedLabel?.text = "Ħ \(gameState.stats.hashEarned)"
        }

        // Show extraction button when available (after 3 min)
        if SurvivalArenaSystem.canExtract(state: gameState) {
            extractionLabel?.alpha = 1
            // Pulsing effect to draw attention
            let pulse = 0.7 + 0.3 * sin(CGFloat(gameState.timeElapsed * 2))
            extractionLabel?.alpha = pulse
        } else {
            extractionLabel?.alpha = 0
        }
    }

    func renderEventSpecificEffects(event: SurvivalEventType) {
        switch event {
        case .systemRestore:
            // Render healing zone
            if let zonePos = gameState.eventData?.healingZonePosition {
                healingZoneNode?.position = CGPoint(
                    x: zonePos.x,
                    y: gameState.arena.height - zonePos.y
                )
                healingZoneNode?.alpha = 1

                // Pulsing glow
                let pulse = 0.7 + 0.3 * sin(CGFloat(gameState.timeElapsed * 3))
                healingZoneNode?.glowWidth = 0  // PERF: was 8 * pulse (GPU Gaussian blur)

                // Check if player is in zone - intensify effect
                let dx = gameState.player.x - zonePos.x
                let dy = gameState.player.y - zonePos.y
                let distance = sqrt(dx * dx + dy * dy)
                if distance < 60 {
                    healingZoneNode?.fillColor = SKColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 0.5)
                } else {
                    healingZoneNode?.fillColor = SKColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 0.3)
                }
            }

        case .dataCorruption:
            // Highlight corrupted obstacles
            healingZoneNode?.alpha = 0
            updateCorruptedObstacles()

        case .bufferOverflow:
            // Show shrinking arena overlay
            healingZoneNode?.alpha = 0
            if let shrinkAmount = gameState.eventData?.shrinkAmount {
                renderArenaShirnkOverlay(shrinkAmount: shrinkAmount)
            }

        default:
            healingZoneNode?.alpha = 0
            arenaOverlayNode?.alpha = 0
        }
    }

    func updateCorruptedObstacles() {
        guard let corruptedIds = gameState.eventData?.corruptedObstacles else { return }

        for (index, obstacle) in gameState.arena.obstacles.enumerated() {
            guard index < obstacleNodes.count else { continue }
            let node = obstacleNodes[index]

            let isCorrupted = obstacle.isCorrupted == true ||
                              corruptedIds.contains(obstacle.id ?? "obs_\(index)")

            if isCorrupted {
                // Corrupted visual: purple glow + pulsing
                if let shapeNode = node as? SKShapeNode {
                    shapeNode.strokeColor = SKColor(red: 0.66, green: 0.33, blue: 0.97, alpha: 1) // #a855f7
                    shapeNode.glowWidth = 0  // PERF: was 5 + 3 * sin(elapsed) (GPU Gaussian blur)
                    shapeNode.lineWidth = 3
                }
            } else {
                // Normal visual
                if let shapeNode = node as? SKShapeNode {
                    shapeNode.strokeColor = colorFromHex(obstacle.color).darker(by: 0.2)
                    shapeNode.glowWidth = 0
                    shapeNode.lineWidth = 2
                }
            }
        }
    }

    func resetCorruptedObstacles() {
        for (index, obstacle) in gameState.arena.obstacles.enumerated() {
            guard index < obstacleNodes.count else { continue }
            if let shapeNode = obstacleNodes[index] as? SKShapeNode {
                shapeNode.strokeColor = colorFromHex(obstacle.color).darker(by: 0.2)
                shapeNode.glowWidth = 0
                shapeNode.lineWidth = 2
            }
        }
    }

    func renderArenaShirnkOverlay(shrinkAmount: CGFloat) {
        // Create a frame showing the "danger zone" at arena edges
        let dangerPath = CGMutablePath()

        // Top danger strip
        dangerPath.addRect(CGRect(x: 0, y: gameState.arena.height - shrinkAmount, width: gameState.arena.width, height: shrinkAmount))
        // Bottom danger strip
        dangerPath.addRect(CGRect(x: 0, y: 0, width: gameState.arena.width, height: shrinkAmount))
        // Left danger strip
        dangerPath.addRect(CGRect(x: 0, y: shrinkAmount, width: shrinkAmount, height: gameState.arena.height - shrinkAmount * 2))
        // Right danger strip
        dangerPath.addRect(CGRect(x: gameState.arena.width - shrinkAmount, y: shrinkAmount, width: shrinkAmount, height: gameState.arena.height - shrinkAmount * 2))

        arenaOverlayNode?.path = dangerPath
        arenaOverlayNode?.fillColor = SKColor(red: 1, green: 0.27, blue: 0.27, alpha: 0.3) // #ff4444
        arenaOverlayNode?.strokeColor = SKColor(red: 1, green: 0.27, blue: 0.27, alpha: 0.8)
        arenaOverlayNode?.lineWidth = 2
        arenaOverlayNode?.alpha = 0.5 + 0.3 * sin(CGFloat(gameState.timeElapsed * 2))
    }

    func eventName(for event: SurvivalEventType) -> String {
        switch event {
        case .memorySurge: return "⚡ MEMORY SURGE"
        case .bufferOverflow: return "⚠️ BUFFER OVERFLOW"
        case .cacheFlush: return "🧹 CACHE FLUSH"
        case .thermalThrottle: return "🔥 THERMAL THROTTLE"
        case .dataCorruption: return "☠️ DATA CORRUPTION"
        case .virusSwarm: return "🦠 VIRUS SWARM"
        case .systemRestore: return "💚 SYSTEM RESTORE"
        }
    }

    // MARK: - HUD Update (Cached - Phase 1.3)

    func updateHUD() {
        // HUD is now provided by SwiftUI overlay - skip if elements not created
        guard healthBarFill != nil else { return }

        // Only update health bar if changed
        let healthPercent = gameState.player.health / gameState.player.maxHealth
        if abs(healthPercent - lastHealthPercent) > 0.001 {
            lastHealthPercent = healthPercent

            // Update fill scale (efficient - just changes transform)
            healthBarFill.xScale = max(0.001, healthPercent) // Avoid zero scale

            // Update fill color
            healthBarFill.fillColor = healthPercent > 0.3 ? SKColor.green : SKColor.red

            // Update text
            healthText?.text = "\(Int(gameState.player.health))/\(Int(gameState.player.maxHealth))"
        }

        // Only update timer if second changed
        let timeSeconds = Int(gameState.timeElapsed)
        if timeSeconds != lastTimeSeconds {
            lastTimeSeconds = timeSeconds
            let minutes = timeSeconds / 60
            let seconds = timeSeconds % 60
            timerText?.text = String(format: "%d:%02d", minutes, seconds)
        }

        // Only update kill counter if changed
        let killCount = gameState.stats.enemiesKilled
        if killCount != lastKillCount {
            lastKillCount = killCount
            killText?.text = L10n.Game.HUD.kills(killCount)
        }
    }
}
