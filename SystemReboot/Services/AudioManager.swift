import AVFoundation

// MARK: - Audio Manager
// Procedurally generated electronic sound effects using AVAudioEngine.
// All sounds are synthesized from raw waveforms — no external asset files.
// Mirrors HapticsService pattern: AudioManager.shared.play(.soundType)

class AudioManager {
    static let shared = AudioManager()

    // MARK: - Sound Types

    enum SoundType {
        // Tier 1: Core Combat
        case towerFire
        case enemyHit
        case enemyDeath
        case playerHit
        case criticalHit
        case hashCollect

        // Tier 2: Moments & Milestones
        case towerPlace
        case towerUpgrade
        case waveStart
        case bossAppear
        case bossDeath
        case levelUp
        case victory
        case defeat

        // Tier 2b: Menu Actions
        case equipProtocol      // Protocol equipped for debug mode
        case componentUpgrade   // System component upgraded (PSU, RAM, etc.)

        // Tier 3: Feedback & Polish
        case uiTap
        case uiDeny
        case coreHit
        case freezeAlert
        case overclockActivate
        case phaseChange
    }

    // MARK: - Sound Priority & Throttling

    private enum SoundPriority: Int, Comparable {
        case ui = 0
        case combat = 1
        case playerFeedback = 2
        case milestone = 3

        static func < (lhs: SoundPriority, rhs: SoundPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    private struct SoundConfig {
        let priority: SoundPriority
        let cooldown: TimeInterval   // Minimum interval between plays
        let volume: Float
    }

    // MARK: - Properties

    private static let soundEnabledKey = "soundEffectsEnabled"

    var isMuted: Bool {
        get { !UserDefaults.standard.bool(forKey: Self.soundEnabledKey) }
        set { UserDefaults.standard.set(!newValue, forKey: Self.soundEnabledKey) }
    }

    /// Whether sound effects are enabled (convenience for Settings UI binding)
    var soundEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.soundEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.soundEnabledKey) }
    }

    /// When true, combat and player-feedback sounds are suppressed (e.g. system menu open).
    /// Milestone and UI sounds still play through so menu interactions remain audible.
    var gameSoundsSuppressed = false

    /// Viewport in game coordinates for spatial filtering. Set by TDGameScene each frame.
    /// Sounds played via `play(_:at:)` outside this rect are skipped.
    var visibleRect: CGRect?

    private var engine: AVAudioEngine?
    private var playerNodes: [AVAudioPlayerNode] = []
    private var bufferCache: [SoundType: AVAudioPCMBuffer] = [:]
    private var towerFireBuffers: [String: AVAudioPCMBuffer] = [:]  // Per-archetype tower fire sounds
    private var lastPlayedTime: [SoundType: CFAbsoluteTime] = [:]
    private var isEngineRunning = false

    private let sampleRate: Double = 44100
    private let nodeCount = 4

    private let soundConfigs: [SoundType: SoundConfig] = [
        // Tier 1: Core Combat
        .towerFire:         SoundConfig(priority: .combat, cooldown: 0.150, volume: 0.25),
        .enemyHit:          SoundConfig(priority: .combat, cooldown: 0.100, volume: 0.20),
        .enemyDeath:        SoundConfig(priority: .combat, cooldown: 0.080, volume: 0.30),
        .playerHit:         SoundConfig(priority: .playerFeedback, cooldown: 0.200, volume: 0.35),
        .criticalHit:       SoundConfig(priority: .playerFeedback, cooldown: 0.080, volume: 0.35),
        .hashCollect:       SoundConfig(priority: .combat, cooldown: 0.120, volume: 0.25),

        // Tier 2: Moments & Milestones
        .towerPlace:        SoundConfig(priority: .playerFeedback, cooldown: 0.0, volume: 0.35),
        .towerUpgrade:      SoundConfig(priority: .milestone, cooldown: 0.0, volume: 0.40),
        .waveStart:         SoundConfig(priority: .milestone, cooldown: 0.0, volume: 0.40),
        .bossAppear:        SoundConfig(priority: .milestone, cooldown: 0.0, volume: 0.50),
        .bossDeath:         SoundConfig(priority: .milestone, cooldown: 0.0, volume: 0.50),
        .levelUp:           SoundConfig(priority: .milestone, cooldown: 0.0, volume: 0.45),
        .victory:           SoundConfig(priority: .milestone, cooldown: 0.0, volume: 0.50),
        .defeat:            SoundConfig(priority: .milestone, cooldown: 0.0, volume: 0.45),

        // Tier 2b: Menu Actions
        .equipProtocol:     SoundConfig(priority: .milestone, cooldown: 0.0, volume: 0.40),
        .componentUpgrade:  SoundConfig(priority: .milestone, cooldown: 0.0, volume: 0.40),

        // Tier 3: Feedback & Polish
        .uiTap:             SoundConfig(priority: .ui, cooldown: 0.050, volume: 0.15),
        .uiDeny:            SoundConfig(priority: .ui, cooldown: 0.300, volume: 0.20),
        .coreHit:           SoundConfig(priority: .playerFeedback, cooldown: 0.200, volume: 0.40),
        .freezeAlert:       SoundConfig(priority: .milestone, cooldown: 0.0, volume: 0.45),
        .overclockActivate: SoundConfig(priority: .milestone, cooldown: 0.0, volume: 0.40),
        .phaseChange:       SoundConfig(priority: .milestone, cooldown: 0.0, volume: 0.40),
    ]

    // MARK: - Initialization

    private init() {
        // Default: sound ON for new installs
        UserDefaults.standard.register(defaults: [Self.soundEnabledKey: true])
        setupAudioEngine()
        generateAllBuffers()
    }

    private func setupAudioEngine() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default)
            try session.setActive(true)
        } catch {
            return
        }

        let eng = AVAudioEngine()
        engine = eng

        guard let monoFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }

        for _ in 0..<nodeCount {
            let node = AVAudioPlayerNode()
            eng.attach(node)
            eng.connect(node, to: eng.mainMixerNode, format: monoFormat)
            playerNodes.append(node)
        }

        do {
            try eng.start()
            isEngineRunning = true

            for node in playerNodes {
                node.play()
            }
        } catch {
            isEngineRunning = false
        }
    }

    // MARK: - Public API

    func play(_ sound: SoundType) {
        guard !isMuted, isEngineRunning else { return }

        // Suppress game sounds when in system menu (combat & player feedback)
        if gameSoundsSuppressed {
            let priority = soundConfigs[sound]?.priority ?? .combat
            if priority == .combat || priority == .playerFeedback {
                return
            }
        }

        // Throttle check
        let now = CFAbsoluteTimeGetCurrent()
        if let config = soundConfigs[sound], config.cooldown > 0 {
            if let lastTime = lastPlayedTime[sound], now - lastTime < config.cooldown {
                return
            }
        }
        lastPlayedTime[sound] = now

        guard let buffer = bufferCache[sound] else { return }

        // Find available player node (round-robin with priority preemption)
        let config = soundConfigs[sound] ?? SoundConfig(priority: .combat, cooldown: 0, volume: 0.3)
        playBuffer(buffer, volume: config.volume, priority: config.priority)
    }

    /// Play a sound only if the event position is visible on screen.
    /// Use for high-frequency combat sounds (towerFire, enemyHit, etc.) so the player
    /// only hears what they can see. Pass game-coordinate positions.
    func play(_ sound: SoundType, at position: CGPoint) {
        if let rect = visibleRect {
            let expanded = rect.insetBy(dx: -120, dy: -120)  // Margin to avoid hard cutoff at edges
            if !expanded.contains(position) {
                return
            }
        }
        play(sound)
    }

    /// Play tower fire sound with per-archetype variation.
    /// Each tower type has a distinct sound character matching its role.
    func playTowerFire(protocolId: String, at position: CGPoint) {
        guard !isMuted, isEngineRunning else { return }
        if gameSoundsSuppressed { return }

        // Viewport check
        if let rect = visibleRect {
            let expanded = rect.insetBy(dx: -120, dy: -120)
            if !expanded.contains(position) { return }
        }

        // Throttle (shared across all tower fire variants)
        let now = CFAbsoluteTimeGetCurrent()
        if let config = soundConfigs[.towerFire], config.cooldown > 0 {
            if let lastTime = lastPlayedTime[.towerFire], now - lastTime < config.cooldown {
                return
            }
        }
        lastPlayedTime[.towerFire] = now

        let key = protocolId.lowercased()
        guard let buffer = towerFireBuffers[key] ?? bufferCache[.towerFire] else { return }
        let config = soundConfigs[.towerFire] ?? SoundConfig(priority: .combat, cooldown: 0.15, volume: 0.25)
        playBuffer(buffer, volume: config.volume, priority: config.priority)
    }

    // MARK: - Playback

    /// Track which priority is currently playing on each node
    private var nodeCurrentPriority: [Int: SoundPriority] = [:]
    private var nextNodeIndex = 0

    private func playBuffer(_ buffer: AVAudioPCMBuffer, volume: Float, priority: SoundPriority) {
        guard let engine = engine, engine.isRunning else { return }

        // Try to find a non-playing node first
        for i in 0..<nodeCount {
            let idx = (nextNodeIndex + i) % nodeCount
            let node = playerNodes[idx]
            if !node.isPlaying || nodeCurrentPriority[idx] == nil {
                scheduleOnNode(idx, buffer: buffer, volume: volume, priority: priority)
                nextNodeIndex = (idx + 1) % nodeCount
                return
            }
        }

        // All nodes busy — preempt lowest priority if ours is higher
        var lowestIdx = 0
        var lowestPriority = nodeCurrentPriority[0] ?? .ui
        for i in 1..<nodeCount {
            let p = nodeCurrentPriority[i] ?? .ui
            if p < lowestPriority {
                lowestPriority = p
                lowestIdx = i
            }
        }

        if priority >= lowestPriority {
            playerNodes[lowestIdx].stop()
            playerNodes[lowestIdx].play()
            scheduleOnNode(lowestIdx, buffer: buffer, volume: volume, priority: priority)
        }
    }

    private func scheduleOnNode(_ index: Int, buffer: AVAudioPCMBuffer, volume: Float, priority: SoundPriority) {
        let node = playerNodes[index]
        node.volume = volume
        nodeCurrentPriority[index] = priority
        node.scheduleBuffer(buffer) { [weak self] in
            self?.nodeCurrentPriority[index] = nil
        }
    }

    // MARK: - Sound Generation

    private func generateAllBuffers() {
        let allSounds: [SoundType] = [
            .towerFire, .enemyHit, .enemyDeath, .playerHit, .criticalHit, .hashCollect,
            .towerPlace, .towerUpgrade, .waveStart, .bossAppear, .bossDeath, .levelUp,
            .victory, .defeat, .equipProtocol, .componentUpgrade,
            .uiTap, .uiDeny, .coreHit, .freezeAlert, .overclockActivate, .phaseChange
        ]
        for sound in allSounds {
            bufferCache[sound] = generateBuffer(for: sound)
        }
        generateTowerFireVariants()
    }

    /// Generate per-archetype tower fire sounds so each tower type has distinct audio character.
    private func generateTowerFireVariants() {
        // Scanner (KernelPulse, TraceRoute) — sharp high blip (the "default" towerFire)
        let scannerSound = squareWave(frequency: 880, duration: 0.05, attack: 0.005, decay: 0.04)
        towerFireBuffers["kernel_pulse"] = scannerSound
        towerFireBuffers["trace_route"] = scannerSound

        // Payload (BurstProtocol) — deep punchy thud
        let payloadSound = squareWave(frequency: 220, duration: 0.06, attack: 0.003, decay: 0.05)
        towerFireBuffers["burst_protocol"] = payloadSound

        // Cryowall (IceShard) — crystalline chime
        let cryoSound = sineWave(frequency: 1400, duration: 0.06, attack: 0.005, decay: 0.05)
        towerFireBuffers["ice_shard"] = cryoSound

        // Rootkit (RootAccess) — soft low hum
        let rootkitSound = sineWave(frequency: 330, duration: 0.05, attack: 0.005, decay: 0.04)
        towerFireBuffers["root_access"] = rootkitSound

        // Overload (Overflow) — buzzy glitch burst
        let overloadSound = noiseBurst(duration: 0.04, attack: 0.003, decay: 0.035)
        towerFireBuffers["overflow"] = overloadSound

        // Forkbomb (ForkBomb) — rapid double blip
        let forkSound = arpeggio(frequencies: [660, 880], noteDuration: 0.025, waveform: .square)
        towerFireBuffers["fork_bomb"] = forkSound

        // Exception (NullPointer) — sharp descending crack
        let exceptionSound = sweep(startFreq: 1200, endFreq: 600, duration: 0.04, waveform: .square)
        towerFireBuffers["null_pointer"] = exceptionSound
    }

    private func generateBuffer(for sound: SoundType) -> AVAudioPCMBuffer? {
        switch sound {
        // Tier 1: Core Combat
        case .towerFire:
            return squareWave(frequency: 880, duration: 0.05, attack: 0.005, decay: 0.04)
        case .enemyHit:
            return noiseBurst(duration: 0.03, attack: 0.002, decay: 0.025)
        case .enemyDeath:
            return combinedBuffer([
                sweep(startFreq: 600, endFreq: 200, duration: 0.12, waveform: .sine),
                noiseBurst(duration: 0.08, attack: 0.005, decay: 0.07)
            ])
        case .playerHit:
            return squareWave(frequency: 150, duration: 0.10, attack: 0.005, decay: 0.08, tremolo: 30)
        case .criticalHit:
            return sweep(startFreq: 1200, endFreq: 400, duration: 0.12, waveform: .sine)
        case .hashCollect:
            return arpeggio(frequencies: [523, 784], noteDuration: 0.05, waveform: .sine)

        // Tier 2: Moments & Milestones
        case .towerPlace:
            return combinedBuffer([
                sineWave(frequency: 100, duration: 0.03, attack: 0.002, decay: 0.025),
                squareWave(frequency: 600, duration: 0.02, attack: 0.002, decay: 0.015)
            ])
        case .towerUpgrade:
            return arpeggio(frequencies: [523, 659, 784], noteDuration: 0.08, waveform: .square)
        case .waveStart:
            return arpeggio(frequencies: [880, 0, 880], noteDuration: 0.08, waveform: .square)
        case .bossAppear:
            return combinedBuffer([
                sweep(startFreq: 60, endFreq: 120, duration: 0.5, waveform: .sine),
                sweep(startFreq: 400, endFreq: 800, duration: 0.6, waveform: .sine, delaySeconds: 0.2)
            ])
        case .bossDeath:
            return combinedBuffer([
                sweep(startFreq: 800, endFreq: 100, duration: 0.3, waveform: .noise),
                arpeggio(frequencies: [523, 659, 784, 1047], noteDuration: 0.1, waveform: .sine, delaySeconds: 0.15)
            ])
        case .levelUp:
            return arpeggio(frequencies: [523, 659, 784, 1047], noteDuration: 0.08, waveform: .sine)
        case .victory:
            return arpeggio(frequencies: [523, 659, 784, 1047, 1319], noteDuration: 0.12, waveform: .sine)
        case .defeat:
            return arpeggio(frequencies: [659, 523, 440], noteDuration: 0.15, waveform: .sine, fadeOut: true)

        // Tier 2b: Menu Actions
        case .equipProtocol:
            // Confident two-tone "lock-in" — low confirm thud + high affirmation ping
            return combinedBuffer([
                squareWave(frequency: 330, duration: 0.06, attack: 0.005, decay: 0.05),
                sineWave(frequency: 880, duration: 0.08, attack: 0.01, decay: 0.06)
            ])
        case .componentUpgrade:
            // Ascending power-up chime — shorter than towerUpgrade, different interval (4th instead of 3rd)
            return arpeggio(frequencies: [440, 587, 880], noteDuration: 0.07, waveform: .sine)

        // Tier 3: Feedback & Polish
        case .uiTap:
            return sineWave(frequency: 1000, duration: 0.02, attack: 0.002, decay: 0.015)
        case .uiDeny:
            return squareWave(frequency: 200, duration: 0.10, attack: 0.005, decay: 0.08)
        case .coreHit:
            return arpeggio(frequencies: [1000, 0, 1000, 0, 1000], noteDuration: 0.04, waveform: .sine)
        case .freezeAlert:
            return sweep(startFreq: 800, endFreq: 100, duration: 0.5, waveform: .sine)
        case .overclockActivate:
            return sweep(startFreq: 200, endFreq: 1200, duration: 0.4, waveform: .sine)
        case .phaseChange:
            return combinedBuffer([
                sweep(startFreq: 600, endFreq: 200, duration: 0.15, waveform: .sine),
                sweep(startFreq: 200, endFreq: 800, duration: 0.25, waveform: .sine, delaySeconds: 0.15)
            ])
        }
    }

    // MARK: - Waveform Generators

    private enum Waveform {
        case sine
        case square
        case noise
    }

    private func makeBuffer(duration: TimeInterval) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return nil }
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard frameCount > 0 else { return nil }
        return AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
    }

    private func sineWave(frequency: Double, duration: TimeInterval, attack: TimeInterval, decay: TimeInterval) -> AVAudioPCMBuffer? {
        guard let buffer = makeBuffer(duration: duration) else { return nil }
        let frameCount = Int(duration * sampleRate)
        buffer.frameLength = AVAudioFrameCount(frameCount)
        guard let data = buffer.floatChannelData?[0] else { return nil }

        let attackFrames = Int(attack * sampleRate)
        let decayStart = frameCount - Int(decay * sampleRate)

        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            var sample = Float(sin(2.0 * .pi * frequency * t))

            // Envelope
            if i < attackFrames {
                sample *= Float(i) / Float(attackFrames)
            } else if i > decayStart {
                let decayProgress = Float(i - decayStart) / Float(frameCount - decayStart)
                sample *= 1.0 - decayProgress
            }
            data[i] = sample
        }
        return buffer
    }

    private func squareWave(frequency: Double, duration: TimeInterval, attack: TimeInterval, decay: TimeInterval, tremolo: Double = 0) -> AVAudioPCMBuffer? {
        guard let buffer = makeBuffer(duration: duration) else { return nil }
        let frameCount = Int(duration * sampleRate)
        buffer.frameLength = AVAudioFrameCount(frameCount)
        guard let data = buffer.floatChannelData?[0] else { return nil }

        let attackFrames = Int(attack * sampleRate)
        let decayStart = frameCount - Int(decay * sampleRate)

        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            let phase = sin(2.0 * .pi * frequency * t)
            var sample: Float = phase >= 0 ? 0.5 : -0.5

            // Tremolo
            if tremolo > 0 {
                let trem = Float(0.5 + 0.5 * sin(2.0 * .pi * tremolo * t))
                sample *= trem
            }

            // Envelope
            if i < attackFrames {
                sample *= Float(i) / Float(attackFrames)
            } else if i > decayStart {
                let decayProgress = Float(i - decayStart) / Float(frameCount - decayStart)
                sample *= 1.0 - decayProgress
            }
            data[i] = sample
        }
        return buffer
    }

    private func noiseBurst(duration: TimeInterval, attack: TimeInterval, decay: TimeInterval) -> AVAudioPCMBuffer? {
        guard let buffer = makeBuffer(duration: duration) else { return nil }
        let frameCount = Int(duration * sampleRate)
        buffer.frameLength = AVAudioFrameCount(frameCount)
        guard let data = buffer.floatChannelData?[0] else { return nil }

        let attackFrames = Int(attack * sampleRate)
        let decayStart = frameCount - Int(decay * sampleRate)

        for i in 0..<frameCount {
            var sample = Float.random(in: -0.5...0.5)

            if i < attackFrames {
                sample *= Float(i) / Float(attackFrames)
            } else if i > decayStart {
                let decayProgress = Float(i - decayStart) / Float(frameCount - decayStart)
                sample *= 1.0 - decayProgress
            }
            data[i] = sample
        }
        return buffer
    }

    private func sweep(startFreq: Double, endFreq: Double, duration: TimeInterval, waveform: Waveform, delaySeconds: TimeInterval = 0) -> AVAudioPCMBuffer? {
        let totalDuration = delaySeconds + duration
        guard let buffer = makeBuffer(duration: totalDuration) else { return nil }
        let totalFrames = Int(totalDuration * sampleRate)
        let delayFrames = Int(delaySeconds * sampleRate)
        let sweepFrames = totalFrames - delayFrames
        buffer.frameLength = AVAudioFrameCount(totalFrames)
        guard let data = buffer.floatChannelData?[0] else { return nil }

        // Silence during delay
        for i in 0..<delayFrames {
            data[i] = 0
        }

        let attackFrames = max(1, sweepFrames / 10)
        let decayFrames = max(1, sweepFrames / 4)
        let decayStart = delayFrames + sweepFrames - decayFrames

        for i in 0..<sweepFrames {
            let progress = Double(i) / Double(sweepFrames)
            let freq = startFreq + (endFreq - startFreq) * progress
            let t = Double(i) / sampleRate

            var sample: Float
            switch waveform {
            case .sine:
                sample = Float(sin(2.0 * .pi * freq * t))
            case .square:
                sample = sin(2.0 * .pi * freq * t) >= 0 ? 0.5 : -0.5
            case .noise:
                sample = Float.random(in: -0.5...0.5)
            }

            let globalIdx = delayFrames + i
            if i < attackFrames {
                sample *= Float(i) / Float(attackFrames)
            } else if globalIdx > decayStart {
                let decayProgress = Float(globalIdx - decayStart) / Float(totalFrames - decayStart)
                sample *= 1.0 - decayProgress
            }
            data[globalIdx] = sample
        }
        return buffer
    }

    private func arpeggio(frequencies: [Double], noteDuration: TimeInterval, waveform: Waveform, delaySeconds: TimeInterval = 0, fadeOut: Bool = false) -> AVAudioPCMBuffer? {
        let totalNoteDuration = noteDuration * Double(frequencies.count)
        let totalDuration = delaySeconds + totalNoteDuration
        guard let buffer = makeBuffer(duration: totalDuration) else { return nil }
        let totalFrames = Int(totalDuration * sampleRate)
        let delayFrames = Int(delaySeconds * sampleRate)
        buffer.frameLength = AVAudioFrameCount(totalFrames)
        guard let data = buffer.floatChannelData?[0] else { return nil }

        // Silence during delay
        for i in 0..<delayFrames {
            data[i] = 0
        }

        let noteFrames = Int(noteDuration * sampleRate)

        for (noteIdx, freq) in frequencies.enumerated() {
            let noteStart = delayFrames + noteIdx * noteFrames
            for i in 0..<noteFrames {
                let globalIdx = noteStart + i
                guard globalIdx < totalFrames else { break }

                var sample: Float
                if freq == 0 {
                    // Silent gap (used for beep patterns)
                    sample = 0
                } else {
                    let t = Double(i) / sampleRate
                    switch waveform {
                    case .sine:
                        sample = Float(sin(2.0 * .pi * freq * t))
                    case .square:
                        sample = sin(2.0 * .pi * freq * t) >= 0 ? 0.5 : -0.5
                    case .noise:
                        sample = Float.random(in: -0.5...0.5)
                    }
                }

                // Per-note envelope (quick attack, quick release to avoid clicks)
                let noteProgress = Float(i) / Float(noteFrames)
                let noteAttack: Float = min(1.0, noteProgress * 20) // Quick 5% attack
                let noteRelease: Float = min(1.0, (1.0 - noteProgress) * 10) // Quick 10% release
                sample *= noteAttack * noteRelease

                // Global fade out (for defeat sound etc.)
                if fadeOut {
                    let globalProgress = Float(globalIdx - delayFrames) / Float(totalFrames - delayFrames)
                    sample *= 1.0 - globalProgress * 0.7
                }

                data[globalIdx] = sample
            }
        }
        return buffer
    }

    /// Combine multiple buffers into one (for layered sounds)
    private func combinedBuffer(_ buffers: [AVAudioPCMBuffer?]) -> AVAudioPCMBuffer? {
        let validBuffers = buffers.compactMap { $0 }
        guard !validBuffers.isEmpty else { return nil }

        let maxFrames = validBuffers.map { $0.frameLength }.max() ?? 0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return nil }
        guard let combined = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: maxFrames) else { return nil }
        combined.frameLength = maxFrames
        guard let outData = combined.floatChannelData?[0] else { return nil }

        // Zero out
        for i in 0..<Int(maxFrames) {
            outData[i] = 0
        }

        // Mix all buffers
        for buf in validBuffers {
            guard let inData = buf.floatChannelData?[0] else { continue }
            for i in 0..<Int(buf.frameLength) {
                outData[i] += inData[i] / Float(validBuffers.count)
            }
        }
        return combined
    }
}
