# Refactoring Roadmap — Thread-Pulling (Domain-Driven) Strategy

## Executive Summary

**Codebase Size:** ~55,000+ lines across 80+ Swift files
**God Objects Identified:** 6 files exceeding 1,500 lines (up to 3,905)
**Combined TDGameScene:** 7,227 lines across 8 files (single class)
**Estimated Total Extractions:** 40+ discrete refactoring tasks across 4 phases

### The Big Six (God Objects)

| File | Lines | Primary Disease |
|------|-------|----------------|
| `SystemTabView.swift` | 3,905 | 18 types in one file; UI + game logic + state management |
| `GameScene.swift` | 2,654 | Boss rendering (4 bosses) + game loop + entity rendering |
| `TDGameScene.swift` (combined) | 7,227 | 17 concerns across 8 extensions; rendering + domain logic |
| `TDGameContainerView.swift` | 2,343 | 60+ @State properties; drag logic + boss flow + freeze UI |
| `TDTypes.swift` | 1,670 | 500-line factory + mixed data/logic types |
| `TowerVisualFactory.swift` | 1,644 | 10 archetypes in one static class |

---

## Phase 1: Zero-Risk Extraction (Data & Config)

**Risk Level:** None — moving types to new files with no logic changes.
**Build verification:** Project compiles identically after each step.

---

### [x] 1.1 Extract `BossEncounter` model from SystemTabView

**Source:** `SystemTabView.swift` lines 2854–2911
**Target:** `SystemReboot/Core/Types/BossEncounter.swift`

**What moves:**
- `BossEncounter` struct (id, name, subtitle, description, iconName, color, bossId, rewards, unlockCost)
- `BossEncounter.all` static catalog (4 entries)

**Why:** This is a pure data model with a static catalog. Used by `BossEncountersView`, `BossCard`, and `ArsenalView`. No dependencies on any view code.

**Lines saved from SystemTabView:** ~60

---

### [x] 1.2 Extract `CurrencyInfoType` enum from SystemTabView

**Source:** `SystemTabView.swift` lines 7–42
**Target:** `SystemReboot/Core/Types/CurrencyInfoType.swift`

**What moves:**
- `CurrencyInfoType` enum with computed properties (title, description, icon, color)

**Why:** Pure data enum with no UI dependencies. Used by `CurrencyInfoSheet` and `MotherboardView`.

**Lines saved from SystemTabView:** ~35

---

### [x] 1.3 Extract Boss State structs from Boss AI files

**Source:** Each boss AI file's top-level state structs
**Target:** `SystemReboot/Core/Types/BossStates.swift`

**What moves:**
- `CyberbossState` + `CyberbossMode` + `LaserBeam` + `DamagePuddle` (from CyberbossAI.swift lines 11–37)
- `VoidHarbingerState` + nested types (from VoidHarbingerAI.swift lines 11–47)
- `OverclockerState` + `TileState` + `SteamSegment` (from OverclockerAI.swift lines 11–41)
- `TrojanWyrmState` + `Phase4SubState` + `Segment` + `SubWorm` (from TrojanWyrmAI.swift lines 11–83)

**Why:** These are pure data structs consumed by both AI systems AND rendering. Extracting them breaks the implicit dependency between GameScene and Boss AI files. Both layers import the state types instead of each other.

**Lines saved:** ~150 total across 4 files

---

### [x] 1.4 Extract `TDSessionState` from TDTypes

**Source:** `TDTypes.swift` lines 263–383
**Target:** `SystemReboot/Core/Types/TDSessionState.swift`

**What moves:**
- `TDSessionState` struct (snapshot/restore for persistence)
- `TDSessionStats` struct (lines 440–448)

**Why:** Persistence model with no game logic dependency. Used only by `StorageService` and `TDGameStateFactory`.

**Lines saved from TDTypes:** ~130

---

### [x] 1.5 Extract wave config types from TDTypes

**Source:** `TDTypes.swift` lines 923–964
**Target:** `SystemReboot/Core/Types/WaveTypes.swift`

**What moves:**
- `TDWave`, `WaveEnemy`, `TDWaveConfig`, `TDWaveDefinition`, `TDWaveEnemyDef`

**Why:** Pure data structs used only for wave configuration and JSON deserialization. No game logic.

**Lines saved from TDTypes:** ~45

---

### [x] 1.6 Extract `MotherboardConfig.createDefault()` to dedicated Swift file

**Source:** `MotherboardTypes.swift` lines 255–520
**Target:** `SystemReboot/Core/Config/MotherboardConfigData.swift`

**What moves:**
- 265 lines of hardcoded district coordinates, component positions, bus definitions
- The `createDefault()` static factory method and all its literal data

**Why:** This is pure data masquerading as code. Moving to its own Swift file keeps compile-time safety (typos caught by the compiler) while cleaning up `MotherboardTypes.swift` to contain only the type definitions.

**Important — NOT JSON:** We considered JSON but rejected it. There is no remote config, no modding system, and no runtime editing requirement. JSON would trade compile-time safety for runtime parsing failures with zero upside. Keep it as Swift.

**Lines saved from MotherboardTypes:** ~230

---

### [x] 1.7 Extract `BossLootReward` from TDTypes

**Source:** `TDTypes.swift` lines 1527–1670
**Target:** `SystemReboot/Core/Types/BossLootReward.swift`

**What moves:**
- `BossLootReward` struct + `RewardItem` nested struct + `ItemType` enum

**Why:** Self-contained reward model with display logic. Used by UI modals and `TDBossSystem`.

**Lines saved from TDTypes:** ~145

---

### [x] 1.8 Move remaining hardcoded values to BalanceConfig

**Source:** Various files
**Target:** `BalanceConfig.swift` (add to existing structs)

| Value | Location | Proposed BalanceConfig Key |
|-------|----------|---------------------------|
| Tower baseUpgradeCost = 50 | TDTypes.swift:735 | `Towers.baseUpgradeCost` |
| Motherboard canvasSize = 4200 | TDTypes.swift:470 | `Motherboard.canvasSize` |
| Motherboard cpuSize = 300 | TDTypes.swift:473 | `Motherboard.cpuSize` |
| Boss unlock costs 200/400/600 | SystemTabView.swift:2886-2908 | `Boss.unlockCosts` dict |
| Total waves = 20 | SystemTabView.swift:1079 | `TDSession.totalWaves` |
| Hash sync throttle = 1.0s | SystemTabView.swift:1106 | `TDSession.hashSyncInterval` |
| Freeze recovery = 10% hash | SystemTabView.swift:183 | `Freeze.recoveryHashPercent` |
| Freeze recovery target = 50% | SystemTabView.swift:1317 | `Freeze.recoveryTargetEfficiency` |
| Min offline earnings = 10 | AppState.swift:79 | `OfflineEarnings.minimumDisplayThreshold` |
| TD map list | AppState.swift:225 | `TDMaps.supportedMaps` |
| Lead targeting look-ahead = 0.05 | TowerSystem.swift:337 | `Towers.leadTargetingLookAhead` |

**Why:** The CLAUDE.md rules require all balance values in BalanceConfig. These are stragglers.

---

### Phase 1 Summary

| Extraction | Source File | Lines Saved | Risk |
|-----------|------------|-------------|------|
| 1.1 BossEncounter | SystemTabView | ~60 | Zero |
| 1.2 CurrencyInfoType | SystemTabView | ~35 | Zero |
| 1.3 Boss States | 4 Boss AI files | ~150 | Zero |
| 1.4 TDSessionState | TDTypes | ~130 | Zero |
| 1.5 Wave Types | TDTypes | ~45 | Zero |
| 1.6 Motherboard JSON | MotherboardTypes | ~230 | Low |
| 1.7 BossLootReward | TDTypes | ~145 | Zero |
| 1.8 BalanceConfig stragglers | Various | ~0 (moves) | Zero |
| **Total** | | **~795** | |

---

## Phase 2: Vertical Slice Extraction (Managers & Services)

**Risk Level:** Low to Medium — extracting domain logic into dedicated services.
**Build verification:** Run project after each extraction; test game flow end-to-end.

---

### 2.1 Extract `OfflineSimulator` from StorageService

**Source:** `StorageService.swift` lines 414–546
**Target:** `SystemReboot/GameEngine/Systems/OfflineSimulator.swift`

**What moves:**
- `calculateOfflineEarnings()` — 93 lines of game simulation (threat growth, defense analysis, leak rate prediction, efficiency degradation)
- `scheduleEfficiencyNotification()` — 61 lines of simulation to estimate time-until-zero
- `OfflineEarningsResult` struct (lines 624–667)

**Why:** This is game domain logic (threat scaling, DPS calculations, leak rates) embedded in the persistence layer. It should live alongside `TDSimulator` in the GameEngine.

**StorageService becomes:** Pure persistence (save/load/migrate) — drops from 667 to ~510 lines.

**New file structure:**
```swift
struct OfflineSimulator {
    static func calculateEarnings(state: OfflineSimulationState,
                                  profile: PlayerProfile) -> OfflineEarningsResult
    static func estimateTimeToZeroEfficiency(state: OfflineSimulationState) -> TimeInterval
}
```

---

### 2.2 Extract `TowerPlacementService` from scattered UI code

**Source:**
- `TDGameContainerView.swift` lines 1144–1287 (drag handling + coordinate conversion)
- `SystemTabView.swift` lines 1190–1309 (duplicate drag handling)
- `TDGameScene+Input.swift` lines 9–51 (placement mode)

**Target:** `SystemReboot/GameEngine/Systems/TowerPlacementService.swift`

**What moves:**
- `convertScreenToGame()` / `convertGameToScreen()` coordinate conversion
- Snap distance calculation with camera scale
- Nearest valid slot finding
- Affordability checking
- Placement validation and execution

**Why:** Tower placement logic is duplicated between `TDGameContainerView` (SwiftUI drag) and `TDGameScene+Input` (SpriteKit touch). Both should call a single placement service.

**New file structure:**
```swift
struct TowerPlacementService {
    static func findNearestSlot(gamePoint: CGPoint, slots: [TowerSlot],
                                snapDistance: CGFloat) -> TowerSlot?
    static func canPlace(weaponType: String, slot: TowerSlot,
                         state: TDGameState) -> TowerPlacementResult
    static func convertScreenToGame(_ point: CGPoint, sceneSize: CGSize,
                                     cameraScale: CGFloat, cameraPosition: CGPoint) -> CGPoint
}
```

---

### 2.3 Extract `GameRewardService` from UI layer

**Source:**
- `TDGameContainerView.swift` lines 2210–2236 (saveGameResult with XP/hash formulas)
- `SystemTabView.swift` lines 311–420 (handleBossFightCompletion + handleBossLootCollected)
- `AppState.swift` lines 247–391 (recordTDResult, recordSurvivorRun, recordBossDefeat)

**Target:** `SystemReboot/GameEngine/Systems/GameRewardService.swift`

**What moves:**
- XP reward calculation: `waves × rate + kills + bonus`
- Hash reward calculation with extraction/death penalties
- Level-up loop logic
- Boss loot reward application
- Blueprint drop recording

**Why:** Reward calculations are scattered across 3 files (2 UI files + AppState). A single `GameRewardService` becomes the source of truth for all reward math.

**New file structure:**
```swift
struct GameRewardService {
    static func calculateTDRewards(state: TDGameState, victory: Bool) -> GameRewards
    static func calculateSurvivorRewards(stats: SessionStats) -> GameRewards
    static func calculateBossRewards(bossType: String, difficulty: BossDifficulty) -> BossRewards
    static func applyRewards(_ rewards: GameRewards, to profile: inout PlayerProfile)
    static func checkLevelUp(profile: inout PlayerProfile) -> Bool
}
```

---

### 2.4 Extract `FreezeRecoveryService` from UI layer

**Source:**
- `SystemTabView.swift` lines 183–206 (flush memory + manual override handlers)
- `SystemTabView.swift` lines 1314–1325 (flushMemory + manualOverrideSuccess)
- `TDGameContainerView.swift` lines 818–850 (performFlushMemory + performManualOverrideReboot)
- `TDGameScene+Actions.swift` lines 22–57 (restoreEfficiency + recoverFromFreeze)

**Target:** `SystemReboot/GameEngine/Systems/FreezeRecoveryService.swift`

**What moves:**
- Flush cost calculation (10% of banked hash)
- Efficiency restoration logic (restore to 50%)
- Enemy cleanup on recovery
- Recovery state transitions

**Why:** Freeze recovery logic is duplicated across 4 files. The UI files both calculate costs and mutate game state.

---

### 2.5 Extract `BossFightCoordinator` from UI layer

**Source:**
- `SystemTabView.swift` lines 311–420 (handleBossFightCompletion, handleBossLootCollected)
- `TDGameContainerView.swift` lines 218–317 (same pattern duplicated)
- NotificationCenter-based boss fight flow

**Target:** `SystemReboot/GameEngine/Systems/BossFightCoordinator.swift`

**What moves:**
- Boss fight initiation (difficulty selection → scene creation)
- Victory/defeat handling
- Reward calculation delegation
- Boss loot modal triggers
- Post-fight state cleanup

**Why:** The boss fight lifecycle is duplicated between the embedded TD view (`SystemTabView`) and the standalone TD view (`TDGameContainerView`). Both use `NotificationCenter` for completion — a code smell.

**New file structure:**
```swift
class BossFightCoordinator: ObservableObject {
    @Published var showBossFight: Bool
    @Published var showLootModal: Bool
    @Published var pendingReward: BossLootReward?

    func initiateFight(bossType: String, difficulty: BossDifficulty, districtId: String?)
    func onFightCompleted(victory: Bool)
    func onLootCollected()
}
```

---

### 2.6 Extract `SectorManagementService`

**Source:**
- `SystemTabView.swift` lines 1328–1357 (unlockSector)
- `TDGameContainerView.swift` lines 2185–2208 (unlockSelectedSector)
- `SectorUnlockSystem.swift` (existing — extend it)

**Target:** Extend existing `SystemReboot/Core/Systems/SectorUnlockSystem.swift`

**What moves:**
- Sector unlock with cost deduction (duplicated in 2 UI files)
- Save player profile after unlock
- Refresh mega-board visuals trigger

**Why:** Both UI files duplicate the unlock→save→refresh flow. `SectorUnlockSystem` already exists but doesn't handle the full transaction.

---

### Phase 2 Summary

| Extraction | Source | New File | Risk |
|-----------|--------|----------|------|
| 2.1 OfflineSimulator | StorageService | GameEngine/Systems/OfflineSimulator.swift | Low |
| 2.2 TowerPlacementService | TDGameContainerView + SystemTabView + TDGameScene | GameEngine/Systems/TowerPlacementService.swift | Medium |
| 2.3 GameRewardService | TDGameContainerView + SystemTabView + AppState | GameEngine/Systems/GameRewardService.swift | Medium |
| 2.4 FreezeRecoveryService | SystemTabView + TDGameContainerView + TDGameScene | GameEngine/Systems/FreezeRecoveryService.swift | Low |
| 2.5 BossFightCoordinator | SystemTabView + TDGameContainerView | GameEngine/Systems/BossFightCoordinator.swift | Medium |
| 2.6 SectorManagementService | SystemTabView + TDGameContainerView | Extend SectorUnlockSystem.swift | Low |

---

## Phase 3: Topic-Based Extensions (File Segmentation)

**Risk Level:** Zero to Low — moving code blocks into extensions in separate files.
**Build verification:** Builds identically; all code stays in the same type via `extension`.

---

### [x] 3.1 Split `SystemTabView.swift` (3,905 lines → 8 files)

This is the highest-impact split. The file contains 18 types that should live in their own files.

| New File | Types Moved | Source Lines | Est. Lines |
|----------|------------|-------------|------------|
| `MotherboardView.swift` | MotherboardView | 138–985 | ~850 |
| `EmbeddedTDGameController.swift` | EmbeddedTDGameController + EmbeddedTDDelegateHandler | 986–1425 | ~440 |
| `EmbeddedTDGameView.swift` | EmbeddedTDGameView + EmbeddedProtocolDeckCard | 1429–1755 | ~330 |
| `SystemFreezeOverlay.swift` | SystemFreezeOverlay | 1756–1932 | ~180 |
| `ArsenalView.swift` | ArsenalView + ProtocolCard + ProtocolDetailSheet + ProtocolStatRow | 2011–2697 | ~690 |
| `UpgradesView.swift` | UpgradesView + UpgradeCard | 2698–2850 | ~155 |
| `BossEncountersView.swift` | BossEncountersView + BossCard + BossGameView | 2915–3144 | ~230 |
| `DebugGameView.swift` | DebugView + SectorCard + DebugGameView + CurrencyInfoSheet | 3145–3899 | ~755 |

**After split, `SystemTabView.swift` becomes:** ~90 lines (root view + top nav bar).

---

### [x] 3.2 Split `GameScene.swift` (2,654 lines → 5 files)

The survival-mode scene mixes boss rendering, entity rendering, game loop, and effects.

| New File | Content | Source Lines | Est. Lines |
|----------|---------|-------------|------------|
| `GameScene+BossRendering.swift` | All 4 boss mechanics renderers | 849–2392 | ~1,550 |
| `GameScene+EntityRendering.swift` | renderPlayer, renderEnemies, renderProjectiles, renderPickups, renderParticles, renderPillars | 1765–2085 | ~320 |
| `GameScene+SurvivalEvents.swift` | renderSurvivalEvents, event-specific effects, HUD for events | 2395–2622 | ~230 |
| `GameScene+Effects.swift` | flashScreen, shakeScreen, setupScreenFlash, setupInvulnerabilityAnimation | 369–517 | ~150 |

**After split, `GameScene.swift` becomes:** ~400 lines (properties, setup, game loop, cleanup).

---

### 3.3 Split `TDGameContainerView.swift` (2,343 lines → 5 files)

| New File | Content | Source Lines | Est. Lines |
|----------|---------|-------------|------------|
| `TDGameContainerView+Overlays.swift` | zeroDayAlert, bossAlert, bossDifficulty, overclock, systemFreeze overlays | 319–850 | ~530 |
| `TDGameContainerView+HUD.swift` | topBar, waveControls, cpuUpgradeSection | 852–1590 | ~410 |
| `TDGameContainerView+Towers.swift` | towerDeck, dragPreview, towerSelectionMenu, towerInfoPanel | 937–1441 | ~320 |
| `TDGameContainerView+Panels.swift` | pauseOverlay, gameOverOverlay, sectorUnlock, sectorManagement | 1443–1947 | ~500 |

**After split, `TDGameContainerView.swift` becomes:** ~580 lines (properties, body, setup, state handlers).

---

### 3.4 Split `TowerVisualFactory.swift` (1,644 lines → 4 files)

| New File | Content | Source Lines | Est. Lines |
|----------|---------|-------------|------------|
| `TowerVisualFactory+Platforms.swift` | All 10 platform creation methods | 1104–1295 | ~190 |
| `TowerVisualFactory+Bodies.swift` | All body creation methods by archetype | 304–785 | ~480 |
| `TowerVisualFactory+Details.swift` | Detail elements, circuit traces, frost, arcs | 1032–1416 | ~385 |
| `TowerVisualFactory+Indicators.swift` | Level, range, cooldown, LOD, rarity ring | 1432–1623 | ~190 |

**After split, `TowerVisualFactory.swift` becomes:** ~400 lines (main factory + barrel creation).

---

### 3.5 Split `TowerAnimations.swift` (1,431 lines → 3 files)

| New File | Content | Source Lines | Est. Lines |
|----------|---------|-------------|------------|
| `TowerAnimations+Idle.swift` | All 10 archetype idle animations + particle emissions | 38–873 | ~835 |
| `TowerAnimations+Combat.swift` | Muzzle flashes, recoil, range, targeting, charging | 877–1370 | ~495 |
| `TowerAnimations+Special.swift` | Legendary and execute special effects | 1371–1431 | ~60 |

**After split, `TowerAnimations.swift` becomes:** ~40 lines (state enum + animation keys).

---

### 3.6 Consolidate `TDGameScene+SectorRendering.swift` (2,492 lines → 4 files)

This extension is already separate from TDGameScene.swift but is itself a God Object.

| New File | Content | Source Lines | Est. Lines |
|----------|---------|-------------|------------|
| `TDGameScene+SectorAmbient.swift` | Sector-specific ambient effects (PSU, GPU, RAM, etc.) | 9–364 | ~360 |
| `TDGameScene+DistrictFoundation.swift` | Foundation rendering (vias, ICs, grid, labels, shadows) | 366–668 | ~300 |
| `TDGameScene+PSUComponents.swift` | PSU-specific components (capacitors, transformers, etc.) | 670–1156 | ~490 |
| `TDGameScene+SectorComponents.swift` | GPU heat sinks, memory chips, remaining sector components | 1194–2492 | ~1,300 |

---

### 3.7 Split `GameTypes.swift` (1,319 lines → 3 files)

| New File | Content | Source Lines | Est. Lines |
|----------|---------|-------------|------------|
| `PlayerProfile.swift` | PlayerProfile (282 lines of 30+ methods) | 889–1171 | ~285 |
| `CombatTypes.swift` | CombatText, DamageEvent, Projectile, Pickup, Particle | 542–874 | ~335 |
| `BossTypes.swift` | DamagePuddle, BossLaser, VoidZone, Pylon, VoidRift, GravityWell, MeteorStrike, ArenaWall, BossMilestones | 715–801 + 534–538 | ~100 |

**After split, `GameTypes.swift` becomes:** ~600 lines (GameState, Player, Enemy, Arena, etc.).

---

### Phase 3 Summary

| Split | Original Lines | Files After | Lines Remaining in Original |
|-------|---------------|-------------|---------------------------|
| 3.1 SystemTabView | 3,905 | 8 + original | ~90 |
| 3.2 GameScene | 2,654 | 4 + original | ~400 |
| 3.3 TDGameContainerView | 2,343 | 4 + original | ~580 |
| 3.4 TowerVisualFactory | 1,644 | 4 + original | ~400 |
| 3.5 TowerAnimations | 1,431 | 3 + original | ~40 |
| 3.6 TDGameScene+SectorRendering | 2,492 | 4 (replaces original) | 0 |
| 3.7 GameTypes | 1,319 | 3 + original | ~600 |

**Total new files:** ~30
**Total lines reorganized:** ~15,788

---

## Phase 4: Logic Decoupling (The Hard Stuff)

**Risk Level:** Medium to High — separating interleaved logic from rendering.
**Build verification:** Must test full gameplay flows after each extraction.

---

### 4.1 Extract `BossRenderingManager` from GameScene

**Source:** `GameScene.swift` lines 849–2392

**Problem:** GameScene contains ~1,550 lines of boss mechanics rendering for 4 bosses, plus boss AI integration (lines 663–847) that calls into CyberbossAI, VoidHarbingerAI, etc.

**Target:** `SystemReboot/Rendering/BossRenderingManager.swift`

**What moves:**
```swift
class BossRenderingManager {
    weak var scene: SKScene?
    var bossMechanicNodes: [String: SKNode]
    var puddlePhaseCache: [String: String]
    var zonePhaseCache: [String: Bool]

    // Lazy cached actions (currently 8 properties on GameScene)
    lazy var laserFlickerAction: SKAction
    lazy var puddlePulseAction: SKAction
    // ... etc

    func renderBossMechanics(state: GameState)
    func renderCyberbossMechanics(bossState: CyberbossState)
    func renderVoidHarbingerMechanics(bossState: VoidHarbingerState)
    func renderOverclockerMechanics(bossState: OverclockerState)
    func renderTrojanWyrmMechanics(bossState: TrojanWyrmState)
    func renderPhaseIndicator(phase: Int, bossType: String, isInvulnerable: Bool)
    func cleanup()
}
```

**Why:** Boss rendering is the single largest block in GameScene. It has 8 lazy cached actions and 3 cache dictionaries that are boss-specific. This extraction removes ~1,550 lines and 11 properties from GameScene.

**Difficulty:** Medium — requires passing scene reference and node pool.

---

### 4.2 Extract `CameraController` from TDGameScene

**Source:** `TDGameScene.swift` lines 179–441

**Problem:** 8 camera properties + 6 methods (~260 lines) for zoom, pan, inertia, and bounds calculation all live directly on TDGameScene.

**Target:** `SystemReboot/Rendering/CameraController.swift`

**What moves:**
```swift
class CameraController {
    weak var cameraNode: SKCameraNode?
    var currentScale: CGFloat
    var minScale, maxScale: CGFloat
    var velocity: CGVector
    var friction, boundsElasticity: CGFloat

    func handlePinch(_ gesture: UIPinchGestureRecognizer)
    func handlePan(_ gesture: UIPanGestureRecognizer)
    func calculateBounds(sceneSize: CGSize, mapSize: CGSize) -> CGRect
    func updatePhysics(deltaTime: TimeInterval)
    func reset(to center: CGPoint, scale: CGFloat)
}
```

**Why:** Camera logic is pure math + gesture handling. Zero game state dependencies. Trivially testable.

**Difficulty:** Low — clean interface boundary.

---

### 4.3 Extract `ParticleEffectService` from TDGameScene+Effects

**Source:** `TDGameScene+Effects.swift` lines 99–510 + 625–967

**Problem:** ~700 lines of particle spawning, voltage arcs, screen shake, and boss effects tightly coupled to the scene.

**Target:** `SystemReboot/Rendering/ParticleEffectService.swift`

**What moves:**
```swift
class ParticleEffectService {
    weak var scene: SKScene?
    weak var particleLayer: SKNode?

    // Power flow
    func startPowerFlowParticles(along paths: [EnemyPath])
    func spawnPowerFlowParticle(along path: EnemyPath)

    // Voltage arcs
    func startVoltageArcSystem()
    func spawnVoltageArc(from: CGPoint, to: CGPoint)

    // Boss effects
    func triggerBossEntranceEffect(at position: CGPoint, color: SKColor)
    func triggerBossDeathEffect(at position: CGPoint, color: SKColor)

    // General particles
    func spawnPortalAnimation(at position: CGPoint, color: SKColor)
    func spawnDeathParticles(at position: CGPoint, color: SKColor)
    func spawnImpactSparks(at position: CGPoint, color: SKColor)
    func spawnGoldFloaties(at position: CGPoint, count: Int)
}
```

**Why:** Particle effects are a standalone visual system. They accept positions and colors, they don't read game state.

**Difficulty:** Low — effects are already parameterized.

---

### 4.4 Extract `EmbeddedTDGameController` logic to ViewModel pattern

**Source:** `SystemTabView.swift` lines 986–1358 (currently `ObservableObject` class)

**Problem:** This 370-line controller mixes game state management, drag handling, coordinate conversion, freeze recovery, sector unlocking, boss state, and Combine subscriptions.

**Target:** Split into focused protocols/extensions:

| New File | Content | Lines |
|----------|---------|-------|
| `EmbeddedTDGameController+Drag.swift` | startDrag, updateDrag, endDrag | ~70 |
| `EmbeddedTDGameController+BossState.swift` | Boss-related @Published + methods | ~50 |

**And delegate to extracted services:**
- Coordinate conversion → `TowerPlacementService` (Phase 2.2)
- Freeze recovery → `FreezeRecoveryService` (Phase 2.4)
- Sector unlock → `SectorUnlockSystem` (Phase 2.6)

**Why:** After Phase 2 extractions, the controller becomes mostly a thin adapter between services and SwiftUI state.

---

### 4.5 Extract `TDGameLoop` from TDGameScene

**Source:** `TDGameScene.swift` lines 885–1016 (`update()` method)

**Problem:** The `update()` method is 130+ lines orchestrating wave spawning, projectile updates, collision detection, and state syncing.

**Target:** `SystemReboot/GameEngine/Systems/TDGameLoop.swift`

**What moves:**
```swift
struct TDGameLoop {
    static func update(state: inout TDGameState, deltaTime: TimeInterval,
                       context: FrameContext) -> TDFrameResult
}

struct TDFrameResult {
    var enemiesKilled: [(TDEnemy, CGPoint)]
    var projectilesHit: [(Projectile, TDEnemy)]
    var coreHits: [TDEnemy]
    var towersToAnimate: [String]  // tower IDs that fired
}
```

**Why:** The game loop is pure logic operating on `TDGameState`. The scene's `update()` would call `TDGameLoop.update()` and then render the results. This makes the game loop unit-testable without SpriteKit.

**Difficulty:** High — requires defining a clean result type and updating all render calls.

**Verification step:** Before extracting, confirm that `update()` does NOT read from `SKNode` positions or use `SKPhysicsBody` contacts. From analysis, this codebase uses custom geometry on `TDGameState` structs (not SpriteKit physics), so extraction should be feasible — but verify at execution time. If any SpriteKit internals are found, define a `PhysicsInterface` protocol to abstract them rather than abandoning the extraction.

---

### 4.6 Extract `CollisionSystem` from TDGameScene

**Source:** `TDGameScene.swift` lines 1099–1276

**Problem:** ~180 lines of swept-sphere collision detection, splash damage calculation, and gold distribution mixed into the scene.

**Target:** `SystemReboot/GameEngine/Systems/TDCollisionSystem.swift`

**What moves:**
```swift
struct TDCollisionSystem {
    static func processCollisions(projectiles: inout [Projectile],
                                   enemies: inout [TDEnemy],
                                   deltaTime: TimeInterval) -> [CollisionEvent]
    static func lineIntersectsCircle(lineStart:lineEnd:center:radius:) -> Bool
    static func applySplashDamage(at position: CGPoint, radius: CGFloat,
                                   damage: CGFloat, enemies: inout [TDEnemy]) -> [TDEnemy]
}
```

**Why:** Collision detection is pure geometry + math. Zero rendering dependencies.

**Difficulty:** Medium — needs clean event output type for rendering to consume.

---

### 4.7 Decouple `PlayerProfile` responsibilities

**Source:** `GameTypes.swift` lines 889–1171

**Problem:** `PlayerProfile` is 282 lines with 30+ methods combining:
- Progression (XP, level, hash)
- Inventory (protocols, blueprints)
- Unlocks (sectors, components, bosses)
- Persistence (Codable)

**Target:** Split into focused extensions:

| New File | Content | Lines |
|----------|---------|-------|
| `PlayerProfile+Progression.swift` | XP, levels, hash management | ~50 |
| `PlayerProfile+Inventory.swift` | Protocols, blueprints, equipment | ~60 |
| `PlayerProfile+Unlocks.swift` | Sectors, components, boss kills | ~80 |

**After split, `PlayerProfile` in GameTypes:** ~90 lines (stored properties + Codable).

---

### 4.8 Extract ManualOverride game simulation from UI

**Source:** `ManualOverrideView.swift` lines 241–708

**Problem:** A complete game simulation (physics, collision, spawning, damage) is embedded inside a SpriteKit scene that lives in the UI layer.

**Target:** `SystemReboot/GameEngine/Systems/ManualOverrideSystem.swift`

**What moves:**
```swift
struct ManualOverrideSystem {
    struct State { /* player pos, health, hazards, timer */ }

    static func update(state: inout State, input: CGPoint, deltaTime: TimeInterval)
    static func spawnHazard(state: inout State, type: HazardType)
    static func checkCollisions(state: inout State) -> [CollisionEvent]
}
```

**The scene becomes:** A thin renderer that calls the system and visualizes the state (~200 lines instead of ~470).

**Difficulty:** Medium — requires defining state model and result types.

---

### Phase 4 Summary

| Extraction | Source | Difficulty | Impact |
|-----------|--------|-----------|--------|
| 4.1 BossRenderingManager | GameScene | Medium | -1,550 lines from GameScene |
| 4.2 CameraController | TDGameScene | Low | -260 lines, reusable component |
| 4.3 ParticleEffectService | TDGameScene+Effects | Low | -700 lines, cleaner effects |
| 4.4 EmbeddedTDGameController split | SystemTabView | Low | Focused responsibilities |
| 4.5 TDGameLoop | TDGameScene | High | Unit-testable game logic |
| 4.6 CollisionSystem | TDGameScene | Medium | Unit-testable collision |
| 4.7 PlayerProfile split | GameTypes | Low | Focused extensions |
| 4.8 ManualOverride system | ManualOverrideView | Medium | Game logic out of UI |

---

## Recommended Execution Order

### Sprint 1: Foundation (Phase 1)
Steps 1.1 → 1.2 → 1.3 → 1.4 → 1.5 → 1.6 → 1.7 → 1.8

**Rationale:** Pure moves, zero logic changes, immediate reduction in file sizes. Builds confidence and establishes patterns.

### Sprint 2: Split SystemTabView + GameScene (Phase 3.1 + 3.2)
Steps 3.1 → 3.2

**Rationale:** Splitting the two worst God Objects (SystemTabView 3,905 lines and GameScene 2,654 lines) has the highest immediate impact on developer experience. No logic changes, just file organization.

**Why split before service extraction?** A reviewer raised concerns about splitting views before extracting services ("copying bad logic into 8 files"). This doesn't apply to SystemTabView because its 18 types are already self-contained structs with their own `var body`. The inline logic concentrates in `MotherboardView` and `EmbeddedTDGameController` — it doesn't spread when we move `ArsenalView` or `UpgradesView` to their own files. Splitting first means all subsequent service extractions target focused 200–800 line files instead of a 3,905-line monolith.

### Sprint 3: Service Extraction (Phase 2) + TDGameContainerView Split (Phase 3.3)
Steps 2.1 → 2.4 → 2.3 → 2.6 → 2.2 → 2.5 → then 3.3

**Rationale:** Ordered by ascending risk. OfflineSimulator and FreezeRecovery are self-contained. GameRewardService and SectorManagement consolidate duplicates. TowerPlacement and BossFightCoordinator require more careful interface design.

**Important ordering note for TDGameContainerView:** Unlike SystemTabView, `TDGameContainerView` has significant inline domain logic (boss handling, freeze recovery, reward calculations) spread through its body and helper methods. We extract the services that affect it (2.2, 2.3, 2.4, 2.5) first, THEN split the now-cleaner file (3.3). This avoids copying business logic into extension files only to refactor it back out.

### Sprint 4: Remaining Splits (Phase 3.4–3.7)
Steps 3.4 → 3.5 → 3.6 → 3.7

**Rationale:** These splits are zero-risk but less urgent than Sprint 2. Do them after services are extracted so the split files are already cleaner.

### Sprint 5: Logic Decoupling (Phase 4)
Steps 4.2 → 4.3 → 4.7 → 4.1 → 4.8 → 4.4 → 4.6 → 4.5

**Rationale:** CameraController and ParticleEffectService are easiest (clean boundaries). PlayerProfile split is low-risk. BossRenderingManager and ManualOverride are medium. TDGameLoop is last as it's the highest risk/highest reward extraction.

---

## Success Metrics

After full execution:

| Metric | Before | After |
|--------|--------|-------|
| Largest file | 3,905 lines | ~600 lines |
| Files > 1,000 lines | 13 | 2–3 |
| Average file size | ~690 lines | ~250 lines |
| Unit-testable game systems | 0 | 5+ |
| Duplicated domain logic instances | 12+ | 0 |
| Balance values outside BalanceConfig | 11+ | 0 |

---

## Appendix: Files NOT Requiring Refactoring

These files are well-structured and appropriately sized:

- `BalanceConfig.swift` (2,053 lines) — Large but appropriate; single source of truth by design
- `DesignSystem.swift` (745 lines) — Pure constants, well-organized
- `L10n.swift` (545 lines) — Localization keys, grows naturally
- `EntityIDs.swift` (313 lines) — Type-safe identifiers
- All Boss AI files (484–776 lines) — Focused on single boss each
- All GameEngine/Systems files (291–447 lines) — Well-scoped ECS systems
- `HapticsService.swift` (408 lines) — Clean singleton pattern
- `ArenaRenderer.swift` (288 lines) — Minimal, static utility
- `MegaBoardRenderer.swift` (477 lines) — Well-scoped renderer
- `ScrollingCombatText.swift` (380 lines) — Well-encapsulated manager
