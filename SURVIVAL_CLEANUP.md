# Survival Mode Cleanup Plan

## Overview

Remove all legacy survival (formerly "arena") mode code from the codebase. The game pivoted from a roguelite survivor game to a tower defense game. Survival mode code is no longer reachable from the active UI but remains scattered across ~40 files.

## What MUST remain untouched

1. **Tower Defense mode** — All `TD*` prefixed files, motherboard, firewalls, viruses, sectors, idle earnings, overclock, threat system
2. **Boss Fights** — All 4 boss AIs (Cyberboss, Void Harbinger, Overclocker, Trojan Wyrm), GameScene.swift (boss mode), player movement, virtual joystick, ArenaSystem (collision detection), ArenaRenderer (boss arena theming), PillarSystem, WeaponSystem (boss combat), EnemySystem (shared), ProjectileSystem (shared), GameContainerView (boss mode UI)
3. **Manual Override mini-game** — ManualOverrideSystem, ManualOverrideView, ManualOverrideScene+Visuals
4. **Protocol system** — Dual-purpose (Firewall in TD, Weapon in boss fights)
5. **Save compatibility** — GameMode decoder must still handle old "arena"/"dungeon" raw values gracefully

## AI Execution Prompt

Paste this prompt to instruct the AI to execute the next open stage:

```
Read SURVIVAL_CLEANUP.md. Find the first stage that is NOT marked [DONE]. Execute that stage:
1. Make all the changes described in the stage
2. Build the project: xcodebuild -project SystemReboot.xcodeproj -scheme SystemReboot -destination 'generic/platform=iOS' build 2>&1 | tail -40
3. Fix any build errors until the build succeeds
4. Mark the stage as [DONE] in SURVIVAL_CLEANUP.md and add a one-line summary of what was done under the stage heading
5. Commit with message: "Cleanup stage N: <stage title>"

CRITICAL: Do NOT touch any TD, boss fight, or manual override code. Only remove survival-specific code. When cleaning shared files, only remove code guarded by `gameMode == .survival` or code that exclusively references survival systems. Keep the GameMode.survival enum case and its decoder for save compatibility until Stage 8.
```

---

## Stages

### Stage 1: Delete survival-only system files [DONE]
Deleted SurvivalArenaSystem.swift, GameScene+SurvivalEvents.swift, SpawnSystem.swift; removed all references from project.pbxproj; cleaned survival code from GameScene.swift, WeaponSystem.swift, PlayerSystem.swift, EnemySystem.swift, and GameContainerView.swift.

Delete these files entirely (they are 100% survival-mode code):

- `SystemReboot/GameEngine/Systems/SurvivalArenaSystem.swift`
- `SystemReboot/Rendering/GameScene+SurvivalEvents.swift`
- `SystemReboot/GameEngine/Systems/SpawnSystem.swift`

Also remove their references from `SystemReboot.xcodeproj/project.pbxproj` (remove the file from the Xcode project).

After deleting, fix all compilation errors in files that reference these deleted types:

- **GameScene.swift**: Remove `var survivalSystem`, all `SurvivalArenaSystem` calls, the `setupSurvivalEventVisuals()` call, the `renderSurvivalEvents()` call, survival HUD node vars (`eventBorderNode`, `eventAnnouncementLabel`, `eventTimerLabel`, `healingZoneNode`, `arenaOverlayNode`, `hashEarnedLabel`, `extractionLabel`, `lastHashEarned`, `lastEventTimeRemaining`), the extraction section (`canExtract`, `hashEarned`, `triggerExtraction`, `onExtraction`), and the survival-mode spawn block (lines ~413-420 calling `SpawnSystem`)
- **WeaponSystem.swift**: Remove `SurvivalArenaSystem.getDamageModifier()` call — just use the base damage directly
- **PlayerSystem.swift**: Remove `SurvivalArenaSystem.getSpeedModifier()` call — just use speed without survival modifier
- **EnemySystem.swift**: Remove the survival-mode hash earning block (`if state.gameMode == .survival { ... hashEarned ... }`)

### Stage 2: Delete DebugGameView and debug arena infrastructure [DONE]
Deleted DebugGameView.swift; moved CurrencyInfoSheet to UI/Components; removed DebugArena, ArenaDifficulty, ArenaLayout, DebugArenaLibrary from GlobalUpgrades.swift; removed createDebugGameState() from GameState.swift; cleaned PlayerProfile references.

Delete these files:

- `SystemReboot/UI/Tabs/DebugGameView.swift`

Remove from `project.pbxproj`.

Then clean up all references to `DebugGameView` in navigation/tabs (search for `DebugGameView` across the project).

Also remove from **GlobalUpgrades.swift**:

- The `ArenaLayout` enum (`.arena`, `.corridors`, `.mixed`)
- The `DebugArena` struct (if it's only used by DebugGameView — check first)
- The `DebugArenaLibrary` struct and all survival arena definitions (`theRam`, `theDrive`, `theGpu`, `theBios`)
- Keep boss dungeon definitions (`cathedral`, `frostCaverns`, `volcanicCore`, `heistVault`, `voidRaid`) ONLY if they're referenced by active boss fight code — otherwise remove them too

Check if `GameStateFactory.createDebugGameState()` in `GameState.swift` is still called anywhere after DebugGameView is gone. If not, remove it too.

### Stage 3: Remove survival-only types from shared files [DONE]
Removed SurvivalEventType, SurvivalEventData, WeaponID enums; removed activeEvent/eventEndTime/eventData from GameState; removed extractionAvailable/extracted/finalHashReward from SessionStats; cleaned DebugOverlay, GameContainerView, AppState, GameRewardService, and UpgradeSystem.

In **GameTypes.swift**:

- Remove `SurvivalEventType` enum
- Remove `SurvivalEventData` struct
- Remove survival event fields from `GameState`: `activeEvent`, `eventEndTime`, `eventData`
- Remove extraction fields from `SessionStats`: `extractionAvailable`, `extracted`
- Remove `SessionStats.finalHashReward()` method (extraction reward calc)
- Remove `PlayerAbilities` struct entirely
- Remove `player.abilities` field from `Player` struct (if it exists there)

In **EntityIDs.swift**:

- Remove the entire `WeaponID` enum (legacy weapon IDs: bow, cannon, ice_shard, laser, staff, bomb, lightning, flamethrower, excalibur)

Fix all compilation errors from removed types. For `abilities: nil` in `GameStateFactory.createPlayer()`, just remove the parameter.

### Stage 4: Clean survival code from GameContainerView and AppState [DONE]
Removed recordRun() survival-only wrapper from AppState; removed gameMode == .survival branch from GameRewardService.applySurvivorResult; changed GameContainerView preview from .survival to .boss.

In **GameContainerView.swift**:

- Remove the extraction button UI block (`if gameMode == .survival && state.stats.extractionAvailable`)
- Remove `extracted` parameter from `recordSurvivorRun` calls
- Remove survival-specific hash display if it's survival-only (check if boss mode also shows it)

In **AppState.swift**:

- Remove the `extracted` parameter from `recordSurvivorRun()` method signature
- Update the method to remove extraction logic
- If `recordSurvivorRun` is only called for survival mode (not boss mode), remove it entirely and update callers to use boss-specific reward recording

In **GameRewardService.swift**:

- Remove `extracted` parameter from `calculateSurvivorRewards()` and `applySurvivorResult()`
- Remove the `SurvivorRewardResult` struct if no longer needed
- Remove `calculateSurvivorRewards()` if boss rewards are handled separately
- Clean the `applySurvivorResult()` method: remove the `if gameMode == .survival` branch (keep boss stats tracking)

### Stage 5: Remove survival balance config and localization [DONE]
Removed SurvivalEvents and SurvivalEconomy structs from BalanceConfig; stripped survival-only values from BossSurvivor (kept phase thresholds used by EnemySystem); removed L10n.Extraction enum, unused Mode.arena/dungeon entries, and orphaned HUD extraction entries; cleaned all corresponding Localizable.xcstrings entries and exportJSON() references.

In **BalanceConfig.swift**:

- Remove `struct SurvivalEvents { ... }` section entirely
- Remove `struct SurvivalEconomy { ... }` section entirely
- Remove `struct BossSurvivor { ... }` section entirely (this is survival-mode boss scaling, NOT the 4 active boss fights)
- Remove `SurvivalEvents`/`SurvivalEconomy` references from `exportJSON()` method
- Remove `struct SurvivorRewards { ... }` if it only applies to survival mode (check if boss fight rewards use it too — if boss fights have their own reward system via `BossFightCoordinator`, remove it)

In **L10n.swift**:

- Remove `L10n.Extraction` enum entirely
- Remove `L10n.Mode.arena` if unused (keep `L10n.Mode.dungeon` only if boss fights use it)
- Remove any other survival-only L10n entries (search for "extraction", "arena" in L10n sections)

In **Localizable.xcstrings**:

- Remove all `extraction.*` string entries
- Remove `mode.arena` entry if the L10n key was removed
- Remove any other orphaned survival string entries

### Stage 6: Clean deprecated player profile fields [DONE]
Removed unlockedSectors, sectorBestTimes, PlayerUnlocks.arenas, SurvivorModeStats.arenaRuns, LegacyGlobalUpgrades; deleted GlobalUpgrades.swift; cleaned dead arena cycling from AppState and LevelingSystem; cleaned StorageService migration code.

In **PlayerProfile.swift**:

- Remove `unlockedSectors` and `sectorBestTimes` if only used for debug arenas (TD sectors use a different system)
- Remove `SurvivorModeStats.arenaRuns` field (keep `dungeonRuns`, `bossesDefeated`, `dungeonsCompleted` if boss fights use them)
- Remove `PlayerUnlocks.arenas` array if it was only for survival arena unlocks (check if boss fights use it)
- Remove deprecated global upgrade fields if marked `DEPRECATED` (old PSU/CPU/RAM/Cooling/HDD levels)
- Clean `defaultProfile` to not reference removed fields
- Clean debug unlock helper to not reference removed arena lists

In **StorageService.swift**:

- Keep the legacy Data→Hash migration (it's harmless backward compat for very old saves)
- Remove `arenaRuns` migration code if the field was removed
- Clean any other references to removed profile fields

### Stage 7: Remove unused arena themes from ArenaRenderer [DONE]
Deleted ArenaRenderer.swift (entirely unused, zero callers); removed survival-only arena definitions (boss_arena, grasslands, volcano, ice_cave, castle, space, temple) from GameConfig.json; kept memory_core, cyberboss, voidrealm for boss fights.

In **ArenaRenderer.swift**:

- Identify which arena themes are actually used by boss fights (check `BossEncounter` arena types and `GameStateFactory.createBossGameState()`)
- Remove theme definitions that are never referenced (city, forest, desert, jungle, graveyard, temple, castle, underwater, hell, heaven — if none are used by active boss encounters)
- Keep themes used by boss fights (memory_core, cyberboss, voidrealm, etc.)
- Remove atmospheric particle configs for removed themes
- Remove effect zone color definitions if only used by survival events

Also check **GameConfigLoader** — if it loads arena configs from a JSON file, some arena definitions there may also be survival-only dead data.

### Stage 8: Final cleanup — GameMode enum and sweep [TODO]

In **GameTypes.swift**:

- Remove `GameMode.survival` case
- Update the backward-compat decoder: map both `"arena"` and `"survival"` to `.towerDefense` (safe fallback for old saves)
- Search entire codebase for any remaining `== .survival` or `.survival` references and remove them

Global sweep:

- Search for any remaining references to: `survival`, `extraction`, `SurvivalArena`, `SurvivalEvent`, `PlayerAbilities`, `WeaponID`, `DebugGameView`, `DebugArena`, `ArenaLayout`, `SpawnSystem` (the deleted one), `arenaRuns`
- Remove any orphaned imports
- Remove any now-empty `// MARK:` sections
- Verify no dead code paths remain
- Build and confirm zero warnings related to the cleanup

---

## Completion Checklist

- [x] Stage 1: Survival system files deleted
- [x] Stage 2: DebugGameView and debug arenas removed
- [x] Stage 3: Survival types cleaned from shared files
- [x] Stage 4: Survival UI and reward code cleaned
- [x] Stage 5: Balance config and L10n cleaned
- [x] Stage 6: Player profile fields cleaned
- [x] Stage 7: Unused arena themes removed
- [ ] Stage 8: GameMode.survival removed, final sweep done
