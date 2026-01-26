import AVFoundation

// MARK: - Audio Service

class AudioService {
    static let shared = AudioService()

    private var audioPlayers: [String: AVAudioPlayer] = [:]
    private var backgroundMusicPlayer: AVAudioPlayer?

    private var isMuted = false
    private var musicVolume: Float = 0.5
    private var sfxVolume: Float = 0.8

    enum SoundEffect: String {
        case hit = "hit"
        case explosion = "explosion"
        case coinPickup = "coin"
        case levelUp = "levelup"
        case upgrade = "upgrade"
        case potionUse = "potion"
        case bossSpawn = "boss_spawn"
        case victory = "victory"
        case defeat = "defeat"
        case menuSelect = "menu_select"
        case menuBack = "menu_back"
    }

    enum MusicTrack: String {
        case mainMenu = "menu_music"
        case arena = "arena_music"
        case boss = "boss_music"
        case victory = "victory_music"
    }

    private init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    // MARK: - Sound Effects

    func play(_ effect: SoundEffect) {
        guard !isMuted else { return }

        // For now, just provide haptic feedback since we don't have audio files
        // In a full implementation, you would load and play the audio file
        switch effect {
        case .hit:
            HapticsService.shared.play(.light)
        case .explosion:
            HapticsService.shared.play(.heavy)
        case .coinPickup:
            HapticsService.shared.play(.selection)
        case .levelUp:
            HapticsService.shared.play(.success)
        case .upgrade:
            HapticsService.shared.play(.medium)
        case .potionUse:
            HapticsService.shared.play(.medium)
        case .bossSpawn:
            HapticsService.shared.play(.warning)
        case .victory:
            HapticsService.shared.play(.legendary)
        case .defeat:
            HapticsService.shared.play(.defeat)
        case .menuSelect:
            HapticsService.shared.play(.selection)
        case .menuBack:
            HapticsService.shared.play(.light)
        }

        // Placeholder for actual audio playback:
        // if let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") {
        //     playSound(url: url)
        // }
    }

    private func playSound(url: URL) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = sfxVolume
            player.prepareToPlay()
            player.play()

            // Store to prevent deallocation
            audioPlayers[url.lastPathComponent] = player
        } catch {
            print("Failed to play sound: \(error)")
        }
    }

    // MARK: - Background Music

    func playMusic(_ track: MusicTrack) {
        guard !isMuted else { return }

        // Placeholder - would load and loop music
        // guard let url = Bundle.main.url(forResource: track.rawValue, withExtension: "mp3") else { return }
        // playBackgroundMusic(url: url)
    }

    private func playBackgroundMusic(url: URL) {
        stopMusic()

        do {
            backgroundMusicPlayer = try AVAudioPlayer(contentsOf: url)
            backgroundMusicPlayer?.volume = musicVolume
            backgroundMusicPlayer?.numberOfLoops = -1 // Loop forever
            backgroundMusicPlayer?.prepareToPlay()
            backgroundMusicPlayer?.play()
        } catch {
            print("Failed to play background music: \(error)")
        }
    }

    func stopMusic() {
        backgroundMusicPlayer?.stop()
        backgroundMusicPlayer = nil
    }

    func pauseMusic() {
        backgroundMusicPlayer?.pause()
    }

    func resumeMusic() {
        backgroundMusicPlayer?.play()
    }

    // MARK: - Settings

    func setMuted(_ muted: Bool) {
        isMuted = muted
        if muted {
            stopMusic()
        }
    }

    func setMusicVolume(_ volume: Float) {
        musicVolume = max(0, min(1, volume))
        backgroundMusicPlayer?.volume = musicVolume
    }

    func setSFXVolume(_ volume: Float) {
        sfxVolume = max(0, min(1, volume))
    }
}
