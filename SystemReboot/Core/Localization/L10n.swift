import Foundation

// MARK: - Localization Helper
// Type-safe access to localized strings
// Usage: Text(L10n.intro.skip) or L10n.gameOver.virusesKilled

enum L10n {
    // MARK: - Intro Sequence
    enum Intro {
        enum SystemBoot {
            static let header = String(localized: "intro.systemBoot.header")
            static let line1 = String(localized: "intro.systemBoot.line1")
            static let line2 = String(localized: "intro.systemBoot.line2")
            static let line3 = String(localized: "intro.systemBoot.line3")
            static let line4 = String(localized: "intro.systemBoot.line4")
        }

        enum ThreatDetected {
            static let header = String(localized: "intro.threatDetected.header")
            static let line1 = String(localized: "intro.threatDetected.line1")
            static let line2 = String(localized: "intro.threatDetected.line2")
            static let line3 = String(localized: "intro.threatDetected.line3")
            static let line4 = String(localized: "intro.threatDetected.line4")
        }

        enum AlwaysRunning {
            static let header = String(localized: "intro.alwaysRunning.header")
            static let line1 = String(localized: "intro.alwaysRunning.line1")
            static let line2 = String(localized: "intro.alwaysRunning.line2")
            static let line3 = String(localized: "intro.alwaysRunning.line3")
            static let line4 = String(localized: "intro.alwaysRunning.line4")
            static let line5 = String(localized: "intro.alwaysRunning.line5")
        }

        static let skip = String(localized: "intro.skip")
        static let swipeHint = String(localized: "intro.swipeHint")
        static let enterSystem = String(localized: "intro.enterSystem")
        static let offline = String(localized: "intro.offline")
        static let earning = String(localized: "intro.earning")
        static let operatingHours = String(localized: "intro.operatingHours")
    }

    // MARK: - Welcome Back Modal
    enum Welcome {
        static let header = String(localized: "welcome.header")
        static let subtitle = String(localized: "welcome.subtitle")
        static let offlineDuration = String(localized: "welcome.offlineDuration")
        static let cappedAt8h = String(localized: "welcome.cappedAt8h")
        static let generatedPwr = String(localized: "welcome.generatedPwr")
        static func leaks(_ count: Int) -> String {
            String(format: String(localized: "welcome.leaks"), count)
        }
        static func efficiency(_ percent: Int) -> String {
            String(format: String(localized: "welcome.efficiency"), percent)
        }
        static func reduced(_ percent: Int) -> String {
            String(format: String(localized: "welcome.reduced"), percent)
        }
        static func threatLevel(_ value: String) -> String {
            String(format: String(localized: "welcome.threatLevel"), value)
        }
        // Defense report
        static let defenseReport = String(localized: "welcome.defenseReport")
        static let yourTowers = String(localized: "welcome.yourTowers")
        static let viruses = String(localized: "welcome.viruses")
        static let vs = String(localized: "welcome.vs")
        static let upgradeHint = String(localized: "welcome.upgradeHint")
    }

    // MARK: - Common
    enum Common {
        static let hash = String(localized: "common.hash")
        static let collect = String(localized: "common.collect")
        static let menu = String(localized: "common.menu")
        static let retry = String(localized: "common.retry")
        static let cancel = String(localized: "common.cancel")
        static let special = String(localized: "common.special")
        static let cost = String(localized: "common.cost")
        static let locked = String(localized: "common.locked")
        static let maxLevel = String(localized: "common.maxLevel")
        static let rewards = String(localized: "common.rewards")
        static let loadout = String(localized: "common.loadout")
        static let launch = String(localized: "common.launch")
        static let done = String(localized: "common.done")
        static let exit = String(localized: "common.exit")
        static let resume = String(localized: "common.resume")
        static let abort = String(localized: "common.abort")
        static let continueAction = String(localized: "common.continue")
        static let flee = String(localized: "common.flee")
        static let recycle = String(localized: "common.recycle")
        static let collectAndExit = String(localized: "common.collectAndExit")
        static let pause = String(localized: "common.pause")
        static let paused = String(localized: "common.paused")
        static let active = String(localized: "common.active")
        static let unknown = String(localized: "common.unknown")
        static func next(_ value: String) -> String {
            String(format: String(localized: "common.next"), value)
        }
        static func lv(_ level: Int) -> String {
            String(format: String(localized: "common.lv"), level)
        }
    }

    // MARK: - Game HUD
    enum Game {
        static let touchToMove = String(localized: "game.touchToMove")

        enum HUD {
            static let time = String(localized: "game.hud.time")
            static let level = String(localized: "game.hud.level")
            static let extract = String(localized: "game.hud.extract")
            static let extractionReady = String(localized: "game.hud.extractionReady")
            static func wave(_ number: Int) -> String {
                String(format: String(localized: "game.hud.wave"), number)
            }
            static func kills(_ count: Int) -> String {
                String(format: String(localized: "game.hud.kills"), count)
            }
        }
    }

    // MARK: - UI
    enum UI {
        static let newBadge = String(localized: "ui.newBadge")
    }

    // MARK: - Game Over
    enum GameOver {
        static let victory = String(localized: "gameOver.victory")
        static let defeat = String(localized: "gameOver.defeat")
        static let timeSurvived = String(localized: "gameOver.timeSurvived")
        static let virusesKilled = String(localized: "gameOver.virusesKilled")
        static let damageDealt = String(localized: "gameOver.damageDealt")
        static let hashCollected = String(localized: "gameOver.hashCollected")
        static let extractionBonus = String(localized: "gameOver.extractionBonus")
        static let deathPenalty = String(localized: "gameOver.deathPenalty")
        static let blueprintAcquired = String(localized: "gameOver.blueprintAcquired")
    }

    // MARK: - Blueprint Modal
    enum Blueprint {
        static let found = String(localized: "blueprint.found")
        static let dataFragmentFound = String(localized: "blueprint.dataFragmentFound")
        static let decryptionComplete = String(localized: "blueprint.decryptionComplete")
        static let firstKillBonus = String(localized: "blueprint.firstKillBonus")
        static let decrypting = String(localized: "blueprint.decrypting")
        static let tapToDecode = String(localized: "blueprint.tapToDecode")
        static func percentDecoded(_ percent: Int) -> String {
            String(format: String(localized: "blueprint.percentDecoded"), percent)
        }
    }

    // MARK: - Stats
    enum Stats {
        static let dmg = String(localized: "stats.dmg")
        static let rng = String(localized: "stats.rng")
        static let pwr = String(localized: "stats.pwr")
        static let spd = String(localized: "stats.spd")
        static let dps = String(localized: "stats.dps")
        static let rate = String(localized: "stats.rate")
        static func best(_ time: String) -> String {
            String(format: String(localized: "stats.best"), time)
        }
        static func dmgRng(_ dmg: Int, rng: Int) -> String {
            String(format: String(localized: "stats.dmgRng"), dmg, rng)
        }
        static func dmgRate(_ dmg: Int, rate: String) -> String {
            String(format: String(localized: "stats.dmgRate"), dmg, rate)
        }
        static func nextSeconds(_ seconds: Int) -> String {
            String(format: String(localized: "stats.nextSeconds"), seconds)
        }
        static func perSecond(_ value: Int) -> String {
            String(format: String(localized: "stats.perSecond"), value)
        }
        static func dpsValue(_ value: CGFloat) -> String {
            String(format: String(localized: "stats.dpsFormat"), value)
        }
        static let damage = String(localized: "stats.damage")
        static let range = String(localized: "stats.range")
        static let fireRate = String(localized: "stats.fireRate")
        static let projectiles = String(localized: "stats.projectiles")
    }

    // MARK: - Tabs
    enum Tabs {
        static let board = String(localized: "tabs.board")
        static let boss = String(localized: "tabs.boss")
        static let arsenal = String(localized: "tabs.arsenal")
        static let tdMode = String(localized: "tabs.tdMode")
        static let encounters = String(localized: "tabs.encounters")
        static let protocols = String(localized: "tabs.protocols")
    }

    // MARK: - System
    enum System {
        static let title = String(localized: "system.title")
    }

    // MARK: - Currency Info
    enum Currency {
        static let hashTitle = String(localized: "currency.hashTitle")
        static let powerTitle = String(localized: "currency.powerTitle")
        static let hashDescription = String(localized: "currency.hashDescription")
        static let powerDescription = String(localized: "currency.powerDescription")
        static let psuLevel = String(localized: "currency.psuLevel")
        static let nextLevel = String(localized: "currency.nextLevel")
        static let upgradePSU = String(localized: "currency.upgradePSU")
        static let psuMaxed = String(localized: "currency.psuMaxed")
    }

    // MARK: - Motherboard
    enum Motherboard {
        static let dragToDeploy = String(localized: "motherboard.dragToDeploy")
        static let initializing = String(localized: "motherboard.initializing")
        static let tapToUpgrade = String(localized: "motherboard.tapToUpgrade")
        static let system = String(localized: "motherboard.system")
    }

    // MARK: - Sector
    enum Sector {
        static let encrypted = String(localized: "sector.encrypted")
        static let decryptCost = String(localized: "sector.decryptCost")
        static let yourBalance = String(localized: "sector.yourBalance")
        static let select = String(localized: "sector.select")
        static let decrypt = String(localized: "sector.decrypt")
        static let manageSectors = String(localized: "sector.manageSectors")
        static let management = String(localized: "sector.management")
        static let pauseDescription = String(localized: "sector.pauseDescription")
        static let pausedWarning = String(localized: "sector.pausedWarning")
        static let alreadyDecrypted = String(localized: "sector.alreadyDecrypted")
        static let readyToDecrypt = String(localized: "sector.readyToDecrypt")
        static func needMoreHash(_ amount: Int) -> String {
            String(format: String(localized: "sector.needMoreHash"), amount)
        }
        static func requires(_ prerequisites: String) -> String {
            String(format: String(localized: "sector.requires"), prerequisites)
        }
    }

    // MARK: - Arsenal
    enum Arsenal {
        static let compiled = String(localized: "arsenal.compiled")
        static let blueprints = String(localized: "arsenal.blueprints")
        static let undiscovered = String(localized: "arsenal.undiscovered")
        static let blueprintRequired = String(localized: "arsenal.blueprintRequired")
        static let defeatBossesHint = String(localized: "arsenal.defeatBossesHint")
        static let equippedForDebug = String(localized: "arsenal.equippedForDebug")
        static let compile = String(localized: "arsenal.compile")
        static let equipForDebug = String(localized: "arsenal.equipForDebug")
        static func upgradeTo(_ level: Int) -> String {
            String(format: String(localized: "arsenal.upgradeTo"), level)
        }
    }

    // MARK: - Mode
    enum Mode {
        static let firewall = String(localized: "mode.firewall")
        static let weapon = String(localized: "mode.weapon")
        static let dungeon = String(localized: "mode.dungeon")
        static let arena = String(localized: "mode.arena")
    }

    // MARK: - Boss
    enum Boss {
        static let encounters = String(localized: "boss.encounters")
        static let encountersDesc = String(localized: "boss.encountersDesc")
        static func phase(_ phase: Int) -> String {
            String(format: String(localized: "boss.phase"), phase)
        }
        static func phaseInvulnerable(_ phase: Int) -> String {
            String(format: String(localized: "boss.phaseInvulnerable"), phase)
        }
        // TD Integration - Boss Alert
        static let superVirusDetected = String(localized: "boss.superVirusDetected")
        static let cyberboss = String(localized: "boss.cyberboss")
        static let voidHarbinger = String(localized: "boss.voidHarbinger")
        static let overclocker = String(localized: "boss.overclocker")
        static let trojanWyrm = String(localized: "boss.trojanWyrm")
        static let immuneToFirewalls = String(localized: "boss.immuneToFirewalls")
        static let engageTarget = String(localized: "boss.engageTarget")
        static let ignoreHint = String(localized: "boss.ignoreHint")
        static let selectDifficulty = String(localized: "boss.selectDifficulty")
        static let blueprintDrop = String(localized: "boss.blueprintDrop")
        static let destroyPylons = String(localized: "boss.destroyPylons")
    }

    // MARK: - System Upgrades
    enum SystemUpgrades {
        static let title = String(localized: "system.upgrades")
    }

    // MARK: - Debug
    enum Debug {
        static let mode = String(localized: "debug.mode")
        static let failed = String(localized: "debug.failed")
        static let gallery = String(localized: "debug.gallery")
        static let gallerySubtitle = String(localized: "debug.gallerySubtitle")
        static let animations = String(localized: "debug.animations")
        static let deckCardPreview = String(localized: "debug.deckCardPreview")
    }

    // MARK: - TD Mode (Tower Defense)
    enum TD {
        static let deployFirewall = String(localized: "td.deployFirewall")
        static let systemPaused = String(localized: "td.systemPaused")
        static let protocolsSuspended = String(localized: "td.protocolsSuspended")
        static let systemSecure = String(localized: "td.systemSecure")
        static let systemBreach = String(localized: "td.systemBreach")
        static let threatsNeutralized = String(localized: "td.threatsNeutralized")
        static let cpuCompromised = String(localized: "td.cpuCompromised")
        static let waves = String(localized: "td.waves")
        static let viruses = String(localized: "td.viruses")
        static func levelMax(_ level: Int, max: Int) -> String {
            String(format: String(localized: "td.levelMax"), level, max)
        }
        // Overclock system
        static let overclock = String(localized: "td.overclock")
        static let overclocking = String(localized: "td.overclocking")
        // Locked towers
        static let tapToUnlock = String(localized: "td.tapToUnlock")
        // Overclock labels
        static let hashMultiplier = String(localized: "td.hashMultiplier")
        static let threatMultiplier = String(localized: "td.threatMultiplier")
        static let bossActive = String(localized: "td.bossActive")
    }

    // MARK: - CPU
    enum CPU {
        static let tier = String(localized: "cpu.tier")
        static let multiplier = String(localized: "cpu.multiplier")
        static let watts = String(localized: "cpu.watts")
        static let maxTier = String(localized: "cpu.maxTier")
        static func upgradeTo(_ tier: Int) -> String {
            String(format: String(localized: "cpu.upgradeTo"), tier)
        }
    }

    // MARK: - Extraction
    enum Extraction {
        static let available = String(localized: "extraction.available")
        static let extract = String(localized: "extraction.extract")
        static let keepHash = String(localized: "extraction.keepHash")
        static let riskForMore = String(localized: "extraction.riskForMore")
        static let sectorCleansed = String(localized: "extraction.sectorCleansed")
        static let virusesEliminated = String(localized: "extraction.virusesEliminated")
        static let hashEarned = String(localized: "extraction.hashEarned")
        static func hashSecured(_ amount: Int) -> String {
            String(format: String(localized: "extraction.hashSecured"), amount)
        }
    }

    // MARK: - Zero-Day
    enum ZeroDay {
        static let breachDetected = String(localized: "zeroDay.breachDetected")
        static let virusDetected = String(localized: "zeroDay.virusDetected")
        static let efficiencyDraining = String(localized: "zeroDay.efficiencyDraining")
        static let manualOverride = String(localized: "zeroDay.manualOverride")
        static let overrideTitle = String(localized: "zeroDay.overrideTitle")
        static let neutralized = String(localized: "zeroDay.neutralized")
        static let dataReward = String(localized: "zeroDay.dataReward")
        static let wattsReward = String(localized: "zeroDay.wattsReward")
        static let overrideFailed = String(localized: "zeroDay.overrideFailed")
        static let efficiencyPenalty = String(localized: "zeroDay.efficiencyPenalty")
        static let indicator = String(localized: "zeroDay.indicator")
    }

    // MARK: - Enemy Indicators
    enum Enemy {
        static let bossIndicator = String(localized: "enemy.bossIndicator")
        static let superVirusIndicator = String(localized: "enemy.superVirusIndicator")
        static let immuneToTowers = String(localized: "enemy.immuneToTowers")
    }

    // MARK: - System Freeze
    enum Freeze {
        static let header = String(localized: "freeze.header")
        static let criticalError = String(localized: "freeze.criticalError")
        static let hashHalted = String(localized: "freeze.hashHalted")
        static let selectReboot = String(localized: "freeze.selectReboot")
        static let flushMemory = String(localized: "freeze.flushMemory")
        static func flushCost(_ cost: Int) -> String {
            String(format: String(localized: "freeze.flushCost"), cost)
        }
        static let overrideSurvive = String(localized: "freeze.overrideSurvive")
        static let allSystemsHalted = String(localized: "freeze.allSystemsHalted")
        static let chooseRecoveryMethod = String(localized: "freeze.chooseRecoveryMethod")
        static let hashPercent = String(localized: "freeze.hashPercent")
        static let restoresEfficiency = String(localized: "freeze.restoresEfficiency")
        static let manualOverride = String(localized: "freeze.manualOverride")
        static let freeSurvive = String(localized: "freeze.freeSurvive")
        static let completeChallenge = String(localized: "freeze.completeChallenge")
        static func frozenTimesSession(_ count: Int) -> String {
            String(format: String(localized: "freeze.frozenTimesSession"), count)
        }
    }

    // MARK: - Manual Override
    enum Override {
        static let survive = String(localized: "override.survive")
        static let dodgeHazards = String(localized: "override.dodgeHazards")
        static let moveWithJoystick = String(localized: "override.moveWithJoystick")
        static let systemRecovered = String(localized: "override.systemRecovered")
        static let efficiencyRestored = String(localized: "override.efficiencyRestored")
        static let failed = String(localized: "override.failed")
        static let tryAgain = String(localized: "override.tryAgain")
    }

    // MARK: - Upgrade Modal
    enum Upgrade {
        static let chooseUpgrade = String(localized: "upgrade.chooseUpgrade")
        static let upgrade = String(localized: "upgrade.upgrade")
        static func level(_ level: Int) -> String {
            String(format: String(localized: "upgrade.level"), level)
        }
    }

    // MARK: - Settings
    enum Settings {
        static let title = String(localized: "settings.title")
        static let notifications = String(localized: "settings.notifications")
        static let notificationsDesc = String(localized: "settings.notificationsDesc")
        static let efficiencyAlerts = String(localized: "settings.efficiencyAlerts")
        static let efficiencyAlertsDesc = String(localized: "settings.efficiencyAlertsDesc")
        static let permissionRequired = String(localized: "settings.permissionRequired")
        static let openSettings = String(localized: "settings.openSettings")
        static let enable = String(localized: "settings.enable")
        // Boss Arena
        static let bossArena = String(localized: "settings.bossArena")
        static let bossArenaDesc = String(localized: "settings.bossArenaDesc")
        static let defeated = String(localized: "settings.defeated")
        static let notEncountered = String(localized: "settings.notEncountered")
        static let fight = String(localized: "settings.fight")
        // Danger Zone
        static let dangerZone = String(localized: "settings.dangerZone")
        static let resetAccount = String(localized: "settings.resetAccount")
        static let resetAccountDesc = String(localized: "settings.resetAccountDesc")
        static let reset = String(localized: "settings.reset")
        static let resetAlertTitle = String(localized: "settings.resetAlertTitle")
        static let resetAlertMessage = String(localized: "settings.resetAlertMessage")
    }

    // MARK: - Notifications
    enum Notification {
        static let efficiencyTitle = String(localized: "notification.efficiency.title")
        static let efficiencyBody = String(localized: "notification.efficiency.body")
    }

    // MARK: - Boss Loot Modal
    enum BossLoot {
        static let neutralized = String(localized: "bossLoot.neutralized")
        static let decryptingPackets = String(localized: "bossLoot.decryptingPackets")
        static let decryptionComplete = String(localized: "bossLoot.decryptionComplete")
        static let tapToDecrypt = String(localized: "bossLoot.tapToDecrypt")
        static let hashReward = String(localized: "bossLoot.hashReward")
        static let protocolAcquired = String(localized: "bossLoot.protocolAcquired")
        static let sectorAccessGranted = String(localized: "bossLoot.sectorAccessGranted")
        static let firstDefeat = String(localized: "bossLoot.firstDefeat")
        static func hashAmount(_ amount: Int) -> String {
            String(format: String(localized: "bossLoot.hashAmount"), amount)
        }
    }

    // MARK: - Rarity
    enum RarityStrings {
        static let common = String(localized: "rarity.common")
        static let rare = String(localized: "rarity.rare")
        static let epic = String(localized: "rarity.epic")
        static let legendary = String(localized: "rarity.legendary")

        /// Get localized string for a rarity value
        static func localized(for rarity: Rarity) -> String {
            switch rarity {
            case .common: return common
            case .rare: return rare
            case .epic: return epic
            case .legendary: return legendary
            }
        }
    }

    // MARK: - Components (District Upgrades)
    enum Component {
        // Section title
        static let title = String(localized: "component.title")
        static let upgrade = String(localized: "component.upgrade")
        static let locked = String(localized: "component.locked")
        static let maxLevel = String(localized: "component.maxLevel")

        // Component names
        static let psuName = String(localized: "component.psu.name")
        static let storageName = String(localized: "component.storage.name")
        static let ramName = String(localized: "component.ram.name")
        static let gpuName = String(localized: "component.gpu.name")
        static let cacheName = String(localized: "component.cache.name")
        static let expansionName = String(localized: "component.expansion.name")
        static let ioName = String(localized: "component.io.name")
        static let networkName = String(localized: "component.network.name")
        static let cpuName = String(localized: "component.cpu.name")

        // Component descriptions (effects)
        static let psuEffect = String(localized: "component.psu.effect")
        static let storageEffect = String(localized: "component.storage.effect")
        static let ramEffect = String(localized: "component.ram.effect")
        static let gpuEffect = String(localized: "component.gpu.effect")
        static let cacheEffect = String(localized: "component.cache.effect")
        static let expansionEffect = String(localized: "component.expansion.effect")
        static let ioEffect = String(localized: "component.io.effect")
        static let networkEffect = String(localized: "component.network.effect")
        static let cpuEffect = String(localized: "component.cpu.effect")

        // Unlock messages
        static func defeatBossToUnlock(_ bossName: String) -> String {
            String(format: String(localized: "component.defeatBossToUnlock"), bossName)
        }

        // Level display
        static func level(_ level: Int) -> String {
            String(format: String(localized: "component.level"), level)
        }

        // Value displays
        static func watts(_ value: Int) -> String {
            String(format: String(localized: "component.watts"), value)
        }

        static func hashCapacity(_ value: Int) -> String {
            String(format: String(localized: "component.hashCapacity"), value)
        }

        static func offlineRate(_ percent: Int) -> String {
            String(format: String(localized: "component.offlineRate"), percent)
        }

        static func multiplier(_ value: String) -> String {
            String(format: String(localized: "component.multiplier"), value)
        }

        static func extraSlots(_ count: Int) -> String {
            String(format: String(localized: "component.extraSlots"), count)
        }

        static func hashPerSecond(_ value: String) -> String {
            String(format: String(localized: "component.hashPerSecond"), value)
        }
    }
}
