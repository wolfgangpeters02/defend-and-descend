# Codebase Cleanup Roadmap v2

Second pass — post-v1 cleanup. These are smaller than v1 but still worth fixing systematically.
Each stage should be tackled in plan mode to map dependencies before making changes.

---

## Stage 1: BossTypes.swift Ghost File + Dead GameState Fields
**Status:** DONE — Deleted BossTypes.swift (9 duplicate types), removed 8 dead GameState fields + Enemy.milestones, fixed debug overlay to use actual boss state data.
**Priority:** High (9 duplicate type definitions, 8 dead fields on GameState)
**Estimated scope:** ~3 files

### Problem
BossTypes.swift defines 9 structs (`DamagePuddle`, `BossLaser`, `VoidZone`, `Pylon`, `VoidRift`, `GravityWell`, `MeteorStrike`, `ArenaWall`, `BossMilestones`) that are complete duplicates of types nested inside the boss AI classes in BossStates.swift. The active code uses the AI-nested versions (e.g., `CyberbossAI.LaserBeam`, `VoidHarbingerAI.VoidZone`).

GameState in GameTypes.swift has 8 optional arrays (`bossPuddles`, `bossLasers`, `voidZones`, `pylons`, `voidRifts`, `gravityWells`, `meteorStrikes`, `arenaWalls`) that reference these dead types. They are never written to during gameplay — only read in `GameScene+DebugOverlay.swift` for display.

`BossMilestones` is also defined in BossTypes.swift and referenced as `Enemy.milestones` in GameTypes.swift but never instantiated or assigned anywhere.

### What needs doing
- Verify no code writes to the 8 GameState fields (only debug overlay reads)
- Remove the 8 dead fields from GameState
- Remove BossMilestones from Enemy struct in GameTypes.swift
- Update GameScene+DebugOverlay.swift to remove references to deleted fields (or delete the overlay sections)
- Delete BossTypes.swift entirely
- Remove from .pbxproj

### Key files to investigate
- `SystemReboot/Core/Types/BossTypes.swift` (delete entirely)
- `SystemReboot/Core/Types/GameTypes.swift` (GameState fields + Enemy.milestones)
- `SystemReboot/Core/Types/BossStates.swift` (confirm these are the active types)
- `SystemReboot/Rendering/GameScene+DebugOverlay.swift` (only reader of dead fields)

---

## Stage 2: GameMode Legacy Cases (.arena/.dungeon)
**Status:** OPEN
**Priority:** High (forces || checks everywhere, new code still creates legacy cases)
**Estimated scope:** ~8-10 files

### Problem
GameMode enum has 5 cases: `.survival`, `.boss`, `.towerDefense`, `.arena` (legacy), `.dungeon` (legacy). Comments say `.arena` maps to `.survival` and `.dungeon` maps to `.boss`, but there's no actual mapping — every conditional must use `gameMode == .survival || gameMode == .arena`. New code in DebugArena still defaults to `.arena` not `.survival`.

### What needs doing
- Add computed properties or a helper to GameMode: e.g., `var isSurvivalType: Bool` and `var isBossType: Bool`
- OR: Add an `init(from decoder:)` that maps `.arena` → `.survival` and `.dungeon` → `.boss` on load, then remove the legacy cases entirely
- Audit all `== .arena` and `== .dungeon` checks to use the new pattern
- Update DebugArena definitions in GlobalUpgrades.swift to use `.survival`/`.boss` instead of `.arena`/`.dungeon`
- Ensure save backward compatibility (old saves with "arena"/"dungeon" strings still decode correctly)

### Key files to investigate
- `SystemReboot/Core/Types/GameTypes.swift` (GameMode enum)
- `SystemReboot/Core/Types/GlobalUpgrades.swift` (DebugArena definitions use .arena/.dungeon)
- `SystemReboot/UI/Game/GameContainerView.swift` (|| checks)
- `SystemReboot/UI/Tabs/DebugGameView.swift` (|| checks)
- `SystemReboot/App/AppState.swift` (recordRun uses .arena)
- `SystemReboot/Rendering/GameScene.swift` (mode checks)

---

## Stage 3: Dead Code Removal (ArenaMap, canUpgradeCpu, etc.)
**Status:** OPEN
**Priority:** Medium (dead weight, no bugs)
**Estimated scope:** ~4 files

### Problem
Scattered dead code that survived previous cleanup rounds.

### What needs removing
- `ArenaMap` struct in SharedTypes.swift (~30 lines) — never instantiated or referenced
- `canUpgradeCpu()` in PlayerProfile.swift — defined but never called
- `HazardDamageType.cold` enum case in EntityIDs.swift — alias for `.ice`, never used
- `EntityIDs.validateAgainstConfig()` — empty placeholder, never called

### Key files to investigate
- `SystemReboot/Core/Types/SharedTypes.swift` (ArenaMap)
- `SystemReboot/Core/Types/PlayerProfile.swift` (canUpgradeCpu)
- `SystemReboot/Core/Types/EntityIDs.swift` (HazardDamageType.cold, validateAgainstConfig)

---

## Stage 4: DRY Violations (Duplicate Hash Cap + Efficiency Color)
**Status:** OPEN
**Priority:** Medium (identical logic in 2 places each — sync risk)
**Estimated scope:** ~4 files

### Problem
Two pieces of logic are copy-pasted across files:

1. **Hash addition with storage cap**: `addHash(_ amount: Int) -> Int` exists with identical cap logic in both `TDGameState` (TDTypes.swift ~line 97) and `PlayerProfile+Progression.swift` (~line 23). If the cap formula changes, both need updating.

2. **Efficiency color**: identical `efficiencyColor` computed property (thresholds at 70%, 40%, 20%) in both `TDGameContainerView.swift` (~line 340) and `MotherboardView.swift` (~line 9).

### What needs doing
- Extract efficiency color to a shared helper (DesignSystem.swift or a small extension on CGFloat/Double)
- For addHash: decide if a shared utility function makes sense, or if the duplication is acceptable given the different contexts (session state vs profile). At minimum, extract the cap formula to BalanceConfig if not already there.

### Key files to investigate
- `SystemReboot/Core/Types/TDTypes.swift` (TDGameState.addHash)
- `SystemReboot/Core/Types/PlayerProfile+Progression.swift` (PlayerProfile.addHash)
- `SystemReboot/UI/Game/TDGameContainerView.swift` (efficiencyColor)
- `SystemReboot/UI/Tabs/MotherboardView.swift` (efficiencyColor)
- `SystemReboot/Core/Config/DesignSystem.swift` (target for shared color helper)

---

## Stage 5: Default ID Consolidation + Stale Comments
**Status:** OPEN
**Priority:** Low (no bugs, sync risk and misleading comments)
**Estimated scope:** ~10 files

### Problem — Default IDs
Same default values defined in multiple places with no single source of truth:
- `"kernel_pulse"` as both `ProtocolLibrary.starterProtocolId` and `PlayerProfile.defaultProtocolId`
- `"ram"` as both `DebugArenaLibrary.starterArenaId` and `PlayerProfile.defaultSectorId`
- `"grasslands"` hardcoded in AppState.swift, BalanceConfig.swift, GameState.swift, and PlayerProfile.swift

### Problem — Stale Comments
- `BossSimulator.swift:122`: `playerWeaponDamage` comment says "legacy, use weapon instead" — field is actively used
- `EntityIDs.swift:152`: Comment says "core/guardian" — Guardian doesn't exist
- `GameScene.swift:430`: Comment says "Update weapons" — system uses protocols now
- `IdleSpawnSystem.swift` and `WaveSystem.swift`: Variables named `legacyLane` for what's actually the active fallback path
- Several rendering files in TDGameScene+EntityVisuals.swift call active code "legacy shapes"
- TDGameScene+Background.swift:240 calls active vias "legacy scattered vias"
- AppState.swift:130 comment still says "weapons/towers"

### What needs doing
- Consolidate default IDs: either have PlayerProfile reference the library constants, or create a GameDefaults enum
- Fix all stale comments listed above (rename legacyLane → fallbackLane, remove "legacy" from active code descriptions, update weapon→protocol in comments, remove Guardian reference)

### Key files to investigate
- `SystemReboot/Core/Types/Protocol.swift` (starterProtocolId)
- `SystemReboot/Core/Types/PlayerProfile.swift` (defaultProtocolId, defaultSectorId)
- `SystemReboot/Core/Types/GlobalUpgrades.swift` (starterArenaId)
- `SystemReboot/App/AppState.swift` ("grasslands" default, "weapons/towers" comment)
- `SystemReboot/GameEngine/Simulation/BossSimulator.swift` (playerWeaponDamage comment)
- `SystemReboot/Core/Types/EntityIDs.swift` ("core/guardian" comment)
- `SystemReboot/Rendering/GameScene.swift` ("Update weapons" comment)
- `SystemReboot/GameEngine/Systems/IdleSpawnSystem.swift` (legacyLane rename)
- `SystemReboot/GameEngine/Systems/WaveSystem.swift` (legacyLane rename)
- `SystemReboot/Rendering/TDGameScene+EntityVisuals.swift` ("legacy shapes" comments)
- `SystemReboot/Rendering/TDGameScene+Background.swift` ("legacy scattered vias" comment)
