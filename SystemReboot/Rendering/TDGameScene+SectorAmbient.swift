import SpriteKit
import SwiftUI

extension TDGameScene {

    // MARK: - Sector Ambient Effects System

    /// Start ambient effects for each sector to make them feel alive
    /// Only applies to unlocked sectors — unlockable/locked sectors are static
    func startSectorAmbientEffects() {
        let megaConfig = cachedMegaBoardConfig
        let profile = AppState.shared.currentPlayer

        for sector in megaConfig.sectors {
            // Only start ambient effects for fully unlocked sectors
            let renderMode = MegaBoardSystem.shared.getRenderMode(for: sector.id, profile: profile)
            guard renderMode == .unlocked else { continue }

            // CPU sector gets its own dedicated ambient system
            if sector.id == SectorID.cpu.rawValue {
                startCPUSectorAmbient(sector: sector)
                continue
            }

            switch sector.theme {
            case .power:
                startPSUSectorAmbient(sector: sector)
            case .graphics:
                startGPUSectorAmbient(sector: sector)
            case .memory:
                startRAMSectorAmbient(sector: sector)
            case .storage:
                startStorageSectorAmbient(sector: sector)
            case .network:
                startNetworkSectorAmbient(sector: sector)
            case .io:
                startIOSectorAmbient(sector: sector)
            case .processing:
                startCacheSectorAmbient(sector: sector)
            }
        }
    }

    // MARK: - PSU Sector Ambient (Power Theme)

    /// PSU sector: Minimal ambient effects - most visuals are static PSU components
    /// Power rails and capacitor sparks have been removed for cleaner aesthetic
    func startPSUSectorAmbient(sector: MegaBoardSector) {
        // PSU sector ambient effects are intentionally minimal
        // The "city" aesthetic comes from static PSU component decorations
        // Only very subtle voltage arcs remain (handled by startVoltageArcSystem)
    }

    // MARK: - GPU Sector Ambient (Heat Theme) - OPTIMIZED: No glow, slower spawn

    /// GPU sector: Simplified heat shimmer (no expensive glow effects)
    func startGPUSectorAmbient(sector: MegaBoardSector) {
        let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .red
        let center = CGPoint(x: sector.worldX + sector.width / 2, y: sector.worldY + sector.height / 2)

        // REMOVED: Thermal glow circle (expensive blur shader)
        // Heat shimmer emitter - slower spawn rate (was 0.15, now 0.4)
        let spawnShimmer = SKAction.run { [weak self] in
            self?.spawnHeatShimmer(at: center, color: themeColor)
        }

        let shimmerSequence = SKAction.repeatForever(SKAction.sequence([
            spawnShimmer,
            SKAction.wait(forDuration: 0.4)  // Slower spawn rate
        ]))

        backgroundLayer.run(shimmerSequence, withKey: "gpuHeat_\(sector.id)")
    }

    /// Spawn a heat shimmer particle - OPTIMIZED: no glow, simpler animation
    func spawnHeatShimmer(at center: CGPoint, color: UIColor) {
        guard currentScale < 0.8, ambientParticleCount < maxAmbientParticles else { return }
        ambientParticleCount += 1

        let shimmer = SKShapeNode(rectOf: CGSize(width: 3, height: 8))
        shimmer.position = CGPoint(
            x: center.x + CGFloat.random(in: -100...100),
            y: center.y - 100 + CGFloat.random(in: -50...50)
        )
        shimmer.fillColor = color.withAlphaComponent(0.4)
        shimmer.strokeColor = .clear
        shimmer.zPosition = -2.7
        // REMOVED: blendMode = .add (causes extra render pass)
        backgroundLayer.addChild(shimmer)

        // Simple rise and fade
        shimmer.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 80, duration: 1.5),
                SKAction.fadeOut(withDuration: 1.5)
            ]),
            SKAction.run { [weak self] in self?.ambientParticleCount -= 1 },
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - RAM Sector Ambient (Memory Theme)

    /// RAM sector: OPTIMIZED - Static LEDs with simple shared blink, no glow
    func startRAMSectorAmbient(sector: MegaBoardSector) {
        let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .green

        // Create static LED nodes (no individual animations)
        let chipBaseY = sector.worldY + sector.height / 2
        let chipX = sector.worldX + 150

        // Pre-defined blink pattern (which LEDs are "on" at each step)
        // Pattern cycles through showing different LEDs lit
        let blinkPatterns: [[Bool]] = [
            [true, false, false, true, false, true, false, false, true, false, false, true],
            [false, true, false, false, true, false, true, false, false, true, false, false],
            [true, true, false, false, false, true, false, true, false, false, true, false],
            [false, false, true, true, false, false, false, false, true, true, false, true],
        ]

        var allLEDs: [SKShapeNode] = []
        for chipIndex in 0..<4 {
            let yOffset = CGFloat(chipIndex) * 100 - 150
            for ledIndex in 0..<3 {
                let ledX = chipX + 50 + CGFloat(ledIndex) * 50
                let ledY = chipBaseY + yOffset + 30

                let led = SKShapeNode(circleOfRadius: 3)
                led.position = CGPoint(x: ledX, y: ledY)
                led.fillColor = themeColor.withAlphaComponent(0.2)
                led.strokeColor = themeColor.withAlphaComponent(0.4)
                led.lineWidth = 1
                // REMOVED: glowWidth, blendMode
                led.zPosition = -2.3
                backgroundLayer.addChild(led)
                allLEDs.append(led)
            }
        }

        // Single timer updates all LEDs with pre-defined pattern
        var patternIndex = 0
        let updateLEDs = SKAction.run { [weak self] in
            guard self != nil else { return }
            let pattern = blinkPatterns[patternIndex % blinkPatterns.count]
            for (i, led) in allLEDs.enumerated() {
                let isOn = pattern[i % pattern.count]
                led.fillColor = themeColor.withAlphaComponent(isOn ? 0.8 : 0.15)
            }
            patternIndex += 1
        }

        let blinkSequence = SKAction.repeatForever(SKAction.sequence([
            updateLEDs,
            SKAction.wait(forDuration: 0.3)  // Update every 0.3s (was random 0.05-0.15)
        ]))
        backgroundLayer.run(blinkSequence, withKey: "ramBlink_\(sector.id)")

        // Simplified data pulse (less frequent, no glow)
        startRAMDataPulse(sector: sector, color: themeColor)
    }

    /// RAM sector: Simplified data pulse - no glow, less frequent
    func startRAMDataPulse(sector: MegaBoardSector, color: UIColor) {
        let spawnPulse = SKAction.run { [weak self] in
            guard let self = self, self.currentScale < 0.8, self.ambientParticleCount < self.maxAmbientParticles else { return }
            self.ambientParticleCount += 1

            let pulseY = sector.worldY + sector.height / 2 + CGFloat.random(in: -100...100)
            let pulse = SKShapeNode(rectOf: CGSize(width: 300, height: 3))
            pulse.position = CGPoint(x: sector.worldX, y: pulseY)
            pulse.fillColor = color.withAlphaComponent(0.5)
            pulse.strokeColor = .clear
            // REMOVED: glowWidth, blendMode
            pulse.zPosition = -2.2
            self.backgroundLayer.addChild(pulse)

            pulse.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveTo(x: sector.worldX + sector.width, duration: 0.5),
                    SKAction.fadeOut(withDuration: 0.5)
                ]),
                SKAction.run { [weak self] in self?.ambientParticleCount -= 1 },
                SKAction.removeFromParent()
            ]))
        }

        let pulseSequence = SKAction.repeatForever(SKAction.sequence([
            SKAction.wait(forDuration: 4.0),  // Less frequent (was 2-5s random)
            spawnPulse
        ]))
        backgroundLayer.run(pulseSequence, withKey: "ramPulse_\(sector.id)")
    }

    // MARK: - Storage Sector Ambient - OPTIMIZED: No glow, simpler LED

    /// Storage sector: Simple activity LED, no trail particles
    func startStorageSectorAmbient(sector: MegaBoardSector) {
        let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .purple
        let chipCenter = CGPoint(x: sector.worldX + 325, y: sector.worldY + sector.height / 2)

        // Simple activity LED (no glow)
        let activityLED = SKShapeNode(circleOfRadius: 5)
        activityLED.position = CGPoint(x: chipCenter.x + 100, y: chipCenter.y + 50)
        activityLED.fillColor = themeColor.withAlphaComponent(0.3)
        activityLED.strokeColor = themeColor.withAlphaComponent(0.6)
        activityLED.lineWidth = 1
        // REMOVED: glowWidth, blendMode
        activityLED.zPosition = -2.3
        backgroundLayer.addChild(activityLED)

        // Simple on/off blink (not complex random pattern)
        let activityBlink = SKAction.repeatForever(SKAction.sequence([
            SKAction.run { activityLED.fillColor = themeColor.withAlphaComponent(0.8) },
            SKAction.wait(forDuration: 0.1),
            SKAction.run { activityLED.fillColor = themeColor.withAlphaComponent(0.2) },
            SKAction.wait(forDuration: 0.8)
        ]))
        activityLED.run(activityBlink, withKey: "storageActivity")

        // REMOVED: Data trail particles (too expensive, minimal visual impact)
    }

    /// Storage sector: Data trail - DISABLED for performance
    func startStorageDataTrail(sector: MegaBoardSector, color: UIColor) {
        // Disabled - particles were expensive for minimal visual impact
    }

    // MARK: - Network Sector Ambient - OPTIMIZED: No glow, less frequent rings

    /// Network sector: Simplified rings, static LEDs
    func startNetworkSectorAmbient(sector: MegaBoardSector) {
        let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .cyan
        let center = CGPoint(x: sector.worldX + sector.width / 2, y: sector.worldY + sector.height / 2)

        // Expanding signal rings (no glow, less frequent)
        let spawnRing = SKAction.run { [weak self] in
            guard let self = self, self.currentScale < 0.8, self.ambientParticleCount < self.maxAmbientParticles else { return }
            self.ambientParticleCount += 1

            let ring = SKShapeNode(circleOfRadius: 20)
            ring.position = center
            ring.fillColor = .clear
            ring.strokeColor = themeColor.withAlphaComponent(0.4)
            ring.lineWidth = 2
            // REMOVED: glowWidth, blendMode
            ring.zPosition = -2.8
            self.backgroundLayer.addChild(ring)

            ring.run(SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 8, duration: 2.0),
                    SKAction.fadeOut(withDuration: 2.0)
                ]),
                SKAction.run { [weak self] in self?.ambientParticleCount -= 1 },
                SKAction.removeFromParent()
            ]))
        }

        let ringSequence = SKAction.repeatForever(SKAction.sequence([
            spawnRing,
            SKAction.wait(forDuration: 2.5)  // Less frequent (was 1.5)
        ]))
        backgroundLayer.run(ringSequence, withKey: "networkRings_\(sector.id)")

        // Static packet LEDs with shared blink timer (no individual animations)
        var packetLEDs: [SKShapeNode] = []
        for i in 0..<4 {
            let led = SKShapeNode(rectOf: CGSize(width: 8, height: 4))
            led.position = CGPoint(x: center.x - 50 + CGFloat(i) * 30, y: center.y + 150)
            led.fillColor = themeColor.withAlphaComponent(0.2)
            led.strokeColor = .clear
            // REMOVED: glowWidth, blendMode
            led.zPosition = -2.3
            backgroundLayer.addChild(led)
            packetLEDs.append(led)
        }

        // Single timer updates all LEDs
        var blinkState = 0
        let blinkPattern: [[Bool]] = [[true, false, true, false], [false, true, false, true], [true, true, false, false], [false, false, true, true]]
        let updateLEDs = SKAction.run {
            let pattern = blinkPattern[blinkState % blinkPattern.count]
            for (i, led) in packetLEDs.enumerated() {
                led.fillColor = themeColor.withAlphaComponent(pattern[i] ? 0.8 : 0.15)
            }
            blinkState += 1
        }
        backgroundLayer.run(SKAction.repeatForever(SKAction.sequence([updateLEDs, SKAction.wait(forDuration: 0.4)])), withKey: "networkLEDs_\(sector.id)")
    }

    // MARK: - I/O Sector Ambient - OPTIMIZED: Static LEDs, no burst particles

    /// I/O sector: Static LEDs with simple shared blink
    func startIOSectorAmbient(sector: MegaBoardSector) {
        // Static USB LEDs (no individual animations, no glow)
        var usbLEDs: [SKShapeNode] = []
        for i in 0..<3 {
            let ledX = sector.worldX + 100 + CGFloat(i) * 120 + 40
            let ledY = sector.worldY + 200 + 25

            let led = SKShapeNode(circleOfRadius: 3)
            led.position = CGPoint(x: ledX, y: ledY)
            led.fillColor = UIColor.green.withAlphaComponent(0.2)
            led.strokeColor = .clear
            // REMOVED: glowWidth, blendMode
            led.zPosition = -2.3
            backgroundLayer.addChild(led)
            usbLEDs.append(led)
        }

        // Single timer updates all LEDs with rotating pattern
        var ledState = 0
        let updateLEDs = SKAction.run {
            for (i, led) in usbLEDs.enumerated() {
                let isOn = (i == ledState % 3)
                led.fillColor = UIColor.green.withAlphaComponent(isOn ? 0.8 : 0.15)
            }
            ledState += 1
        }
        backgroundLayer.run(SKAction.repeatForever(SKAction.sequence([updateLEDs, SKAction.wait(forDuration: 0.5)])), withKey: "ioLEDs_\(sector.id)")

        // REMOVED: Data burst particles (too expensive)
    }

    /// I/O sector: Data burst - DISABLED for performance
    func startIODataBurst(sector: MegaBoardSector, color: UIColor) {
        // Disabled - particles were expensive for minimal visual impact
    }

    // MARK: - Cache Sector Ambient - OPTIMIZED: No flash particles, simple speed lines

    /// Cache sector: Simplified - just occasional speed lines, no flash particles
    func startCacheSectorAmbient(sector: MegaBoardSector) {
        let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .blue

        // REMOVED: Cache hit flash particles (very expensive with glowWidth=15)
        // Only keep speed lines, but less frequent
        startCacheSpeedLines(sector: sector, color: themeColor)
    }

    /// Cache sector: Speed lines - simplified, no glow, less frequent
    func startCacheSpeedLines(sector: MegaBoardSector, color: UIColor) {
        let spawnLine = SKAction.run { [weak self] in
            guard let self = self, self.currentScale < 0.8, self.ambientParticleCount < self.maxAmbientParticles else { return }
            self.ambientParticleCount += 1

            let y = sector.worldY + CGFloat.random(in: 100...(sector.height - 100))
            let lineLength: CGFloat = 100  // Fixed length instead of random

            let line = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: sector.worldX, y: y))
            path.addLine(to: CGPoint(x: sector.worldX + lineLength, y: y))
            line.path = path
            line.strokeColor = color.withAlphaComponent(0.6)
            line.lineWidth = 2
            // REMOVED: glowWidth, blendMode
            line.zPosition = -2.6
            self.backgroundLayer.addChild(line)

            line.run(SKAction.sequence([
                SKAction.moveBy(x: sector.width + lineLength, y: 0, duration: 0.2),
                SKAction.run { [weak self] in self?.ambientParticleCount -= 1 },
                SKAction.removeFromParent()
            ]))
        }

        let lineSequence = SKAction.repeatForever(SKAction.sequence([
            SKAction.wait(forDuration: 0.8),  // Less frequent (was 0.2-0.6)
            spawnLine
        ]))
        backgroundLayer.run(lineSequence, withKey: "cacheLines_\(sector.id)")
    }

    // MARK: - CPU Sector Ambient (Processing Core)

    /// CPU sector: Data processing pulses + heartbeat ring. Tier-responsive.
    func startCPUSectorAmbient(sector: MegaBoardSector) {
        let cpuTier = state?.cpuTier ?? 1
        let tierColor = CPUTierColors.color(for: cpuTier)
        let center = CGPoint(x: sector.worldX + sector.width / 2, y: sector.worldY + sector.height / 2)

        startCPUDataPulses(center: center, sectorId: sector.id, tier: cpuTier, color: tierColor)
        startCPUHeartbeatRing(center: center, sectorId: sector.id, color: tierColor)
    }

    /// CPU data processing pulses — small rectangles spawn from die edges, move outward
    private func startCPUDataPulses(center: CGPoint, sectorId: String, tier: Int, color: UIColor) {
        // Spawn rate scales with tier: 0.6s at tier 1, 0.3s at tier 5
        let spawnInterval = max(0.3, 0.7 - Double(tier) * 0.1)

        let spawnPulse = SKAction.run { [weak self] in
            guard let self = self, self.currentScale < 0.8, self.ambientParticleCount < self.maxAmbientParticles else { return }
            self.ambientParticleCount += 1

            // Pick a random direction to emit from the die edge
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let startOffset: CGFloat = BalanceConfig.Motherboard.cpuSize / 2 + 20
            let travelDistance: CGFloat = CGFloat.random(in: 100...250)

            let pulse = SKShapeNode(rectOf: CGSize(width: 5, height: 3))
            pulse.position = CGPoint(x: center.x + cos(angle) * startOffset,
                                     y: center.y + sin(angle) * startOffset)
            pulse.fillColor = color.withAlphaComponent(0.6)
            pulse.strokeColor = .clear
            pulse.zRotation = angle
            pulse.zPosition = -2.5
            self.backgroundLayer.addChild(pulse)

            pulse.run(SKAction.sequence([
                SKAction.group([
                    SKAction.move(by: CGVector(dx: cos(angle) * travelDistance,
                                               dy: sin(angle) * travelDistance),
                                  duration: 0.6),
                    SKAction.fadeOut(withDuration: 0.6)
                ]),
                SKAction.run { [weak self] in self?.ambientParticleCount -= 1 },
                SKAction.removeFromParent()
            ]))
        }

        let pulseSequence = SKAction.repeatForever(SKAction.sequence([
            spawnPulse,
            SKAction.wait(forDuration: spawnInterval)
        ]))
        backgroundLayer.run(pulseSequence, withKey: "cpuPulses_\(sectorId)")
    }

    /// CPU heartbeat ring — expanding sonar-like ring centered on CPU
    private func startCPUHeartbeatRing(center: CGPoint, sectorId: String, color: UIColor) {
        let spawnRing = SKAction.run { [weak self] in
            guard let self = self, self.currentScale < 0.8, self.ambientParticleCount < self.maxAmbientParticles else { return }
            self.ambientParticleCount += 1

            let ring = SKShapeNode(circleOfRadius: 50)
            ring.position = center
            ring.fillColor = .clear
            ring.strokeColor = color.withAlphaComponent(0.3)
            ring.lineWidth = 2
            ring.zPosition = -2.8
            self.backgroundLayer.addChild(ring)

            ring.run(SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 8, duration: 2.5),
                    SKAction.fadeOut(withDuration: 2.5)
                ]),
                SKAction.run { [weak self] in self?.ambientParticleCount -= 1 },
                SKAction.removeFromParent()
            ]))
        }

        let ringSequence = SKAction.repeatForever(SKAction.sequence([
            spawnRing,
            SKAction.wait(forDuration: 3.0)
        ]))
        backgroundLayer.run(ringSequence, withKey: "cpuHeartbeat_\(sectorId)")
    }
}
