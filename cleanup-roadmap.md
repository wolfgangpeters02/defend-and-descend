# Codebase Cleanup Roadmap

Staged plan to untangle overlapping systems, fix naming conflicts, and remove legacy code.
Each stage should be tackled in plan mode to map dependencies before making changes.

---

## Stage 1: Weapon → Protocol Migration
**Status:** DONE
**Summary:** Removed LevelingSystem legacy dual-writes to weaponLevels/unlocks.weapons; renamed all TD-mode weapon→protocol identifiers across 20 files (weaponType→protocolId params, .weaponLocked→.protocolLocked, .insufficientGold→.insufficientHash, draggedWeaponType→draggedProtocolId, getWeaponLevel→getProtocolLevel, createWeaponTrail→createProjectileTrail, getWeaponColor→getProtocolColor).
**Priority:** Critical (has an actual level-sync bug)
**Estimated scope:** ~15 files

### Problem
The game renamed "weapons" to "protocols" but the migration is half-done. The same data lives in 3 places on PlayerProfile: `compiledProtocols`, `weaponLevels`, and `unlocks.weapons`. Two parallel lookup paths exist (`GameConfigLoader.getWeapon()` vs `ProtocolLibrary.get()`). `LevelingSystem` only writes to `weaponLevels`, never syncing `protocolLevels` — this is an active bug.

### What needs untangling
- `PlayerProfile`: Decide which properties stay (likely `compiledProtocols` + `protocolLevels`), remove the rest
- `Tower.weaponType` field: Rename to `protocolId` or similar (holds protocol IDs, not weapon IDs)
- `WeaponTower` struct in SharedTypes.swift: Is it still needed or fully replaced by `Protocol`?
- `GameConfigLoader.getWeapon()`: Remove if all callers can use `ProtocolLibrary.get()` instead
- `LevelingSystem`: Fix to write to the canonical system
- `TDGameScene+Actions.swift`: Remove dual-write pattern (`// Legacy support`)
- `PlayerUnlocks.weapons`: Rename or remove
- `AppState.weaponLevel(for:)` and `unlockedTowers`: Update to use protocol system
- `Protocol.toWeapon()` bridge: Check if Active/Debug mode can use Protocol directly
- Save file migration: Ensure old profiles with only `weaponLevels` get migrated on load

### Key files to investigate
- `SystemReboot/Core/Types/PlayerProfile.swift`
- `SystemReboot/Core/Types/SharedTypes.swift` (WeaponTower)
- `SystemReboot/Core/Types/Protocol.swift`
- `SystemReboot/Core/Config/GameConfig.swift`
- `SystemReboot/GameEngine/Systems/LevelingSystem.swift`
- `SystemReboot/GameEngine/Systems/TowerSystem.swift`
- `SystemReboot/GameEngine/Systems/TowerPlacementService.swift`
- `SystemReboot/Rendering/TDGameScene+Actions.swift`
- `SystemReboot/UI/Tabs/MotherboardView.swift`
- `SystemReboot/UI/Game/TDGameContainerView+Towers.swift`
- `SystemReboot/Services/StorageService.swift` (migration)

---

## Stage 2: GlobalUpgrades → ComponentLevels Migration
**Status:** DONE
**Summary:** Deleted GlobalUpgrades struct and GlobalUpgradeType enum; migrated all 35+ references across 13 files to use ComponentLevels as the single source of truth; added healthBonus/tierName/color helpers to ComponentLevels/UpgradeableComponent; rewrote UpgradesView; kept minimal LegacyGlobalUpgrades for save-file backward compatibility with auto-migration.
**Priority:** High (already marked deprecated, blocking clean architecture)
**Estimated scope:** ~10 files

### Problem
`GlobalUpgrades` is marked `// DEPRECATED: Use ComponentLevels instead` but has 34 active references across 8+ files. `ComponentLevels` only has 9 references. Some files read from one, some from the other. `SimulationRunner` has a property named `componentLevels` typed as `GlobalUpgrades`. BalanceConfig simulation presets are defined as `GlobalUpgrades`.

### What needs untangling
- Decide if `ComponentLevels` is the canonical system (it should be, per the deprecation comment)
- Migrate all `globalUpgrades.*` reads to `componentLevels.*` equivalents
- Move static utility methods (e.g., `psuTierName`, `hashPerSecond`) somewhere accessible without GlobalUpgrades
- Update BalanceConfig simulation presets to use ComponentLevels
- Fix SimulationRunner type mismatch
- Update UpgradesView and DebugGameView to use ComponentLevels
- Ensure PlayerProfile migration handles old saves that only have `globalUpgrades`
- Remove GlobalUpgrades struct and GlobalUpgradeType enum once all references are gone

### Key files to investigate
- `SystemReboot/Core/Types/GlobalUpgrades.swift`
- `SystemReboot/Core/Types/ComponentTypes.swift`
- `SystemReboot/Core/Types/PlayerProfile.swift`
- `SystemReboot/Core/Config/BalanceConfig.swift` (simulation presets)
- `SystemReboot/GameEngine/Simulation/SimulationRunner.swift`
- `SystemReboot/UI/Tabs/UpgradesView.swift`
- `SystemReboot/UI/Tabs/DebugGameView.swift`
- `SystemReboot/GameEngine/Systems/TowerSystem.swift`

---

## Stage 3: Terminology Cleanup (gold/coins, Guardian, district, waves)
**Status:** DONE
**Summary:** Renamed gold/coins→hash across ~25 files (goldValue→hashValue, coinValue→hashValue, spawnGoldFloaties→spawnHashFloaties, coinMagnetSpeed→pickupMagnetSpeed, JSON keys); renamed Guardian→Core (deleted dead GuardianStats struct, updated L10n welcome subtitle); renamed district→sector throughout (defeatedDistrictBosses→defeatedSectorBosses with CodingKey backward compat, bossTypeForDistrict→bossTypeForSector, DistrictFoundationColors→SectorFoundationColors, file rename); updated wave-based comments; deleted stale comments.
**Priority:** Medium (no runtime bugs, but actively misleading)
**Estimated scope:** ~12 files, mostly comments and parameter names

### Problem
Stale terminology from earlier design iterations persists in comments, parameter names, and function names. These don't cause bugs but create confusion and will mislead future development.

### What needs fixing
- **"gold" / "coins" → "hash"**: `PotionSystem.chargePotions(coins:)` parameter name, `ParticleEffectService.spawnGoldFloaties()` function name, `TDEnemy.goldValue` field, `TDConfig.json` keys (`startingGold`, `goldPerKill`), `StorageService` migration comments
- **"The Guardian" → "Core"**: TDTypes.swift line 23 and 664, CoreSystem.swift comment
- **"district" → "sector"**: Throughout TDBossSystem.swift (`bossTypeForDistrict`, `districtId` params), TDGameState.activeBossDistrictId, L10n.swift "District Upgrades" comment
- **"wave-based" → "continuous/idle"**: TDTypes.swift line 44 comment, BalanceConfig.totalWaves comment
- **Stale code comments**: TDTypes.swift lines 20-21 ("Will be implemented in MotherboardTypes.swift" — never will be), TDGameScene removal comments, MotherboardTypes.swift line 251 referencing deleted factory file

### Key files to investigate
- `SystemReboot/GameEngine/Systems/PotionSystem.swift`
- `SystemReboot/Rendering/ParticleEffectService.swift`
- `SystemReboot/GameEngine/Systems/TDBossSystem.swift`
- `SystemReboot/Core/Types/TDTypes.swift`
- `SystemReboot/Core/Types/GameTypes.swift` (TDEnemy.goldValue if it exists)
- `SystemReboot/Core/Localization/L10n.swift`
- `SystemReboot/Core/Config/BalanceConfig.swift`
- `SystemReboot/Resources/TDConfig.json`

---

## Stage 4: Map/Level System Consolidation
**Status:** DONE
**Summary:** Removed dead `selectedTDMap` from AppState; renamed `Sector`→`DebugArena` (and SectorDifficulty→ArenaDifficulty, SectorLayout→ArenaLayout, SectorLibrary→DebugArenaLibrary) across 5 files to disambiguate from TD sector types; renamed PlayerProfile `isSectorUnlocked`→`isDebugArenaUnlocked`; removed dead non-motherboard path from TDGameStateFactory (~150 lines) and `mapId` from TDGameContainerView; added Stage 6 TODO for DataBusConnection/EncryptionGate removal; confirmed TDConfig.json is bundled but never loaded (deferred to Stage 6).
**Priority:** Medium (confusing but functional)
**Estimated scope:** ~8 files

### Problem
Five overlapping map/level concepts use "sector" or similar terms for different things. MegaBoardConfig has empty connection/gate arrays (hollowed out). `selectedTDMap` on AppState is dead. The Sector struct (debug arenas) name-clashes with SectorLane (TD lanes).

### What needs untangling
- Remove `selectedTDMap` from AppState (dead property)
- Rename `Sector` struct (debug arenas) to something unambiguous — e.g., `DebugArena` or `ActiveModeSector`
- Clean up `MegaBoardConfig.createDefault()`: Remove empty `connections`/`gates` arrays or document why they're empty
- ~~Remove stale `TDTypes.swift` comment about MotherboardConfig (lines 20-21)~~ (done in Stage 3)
- ~~Rename `districtId` parameters to `sectorId` in TDBossSystem and related code~~ (done in Stage 3)
- Decide if `TDGameStateFactory.createTDGameState()` (non-motherboard path) is still needed or can be removed
- Verify `TDConfig.json` wave definitions are actually loaded somewhere

### Key files to investigate
- `SystemReboot/App/AppState.swift` (selectedTDMap)
- `SystemReboot/Core/Types/GlobalUpgrades.swift` (Sector, SectorLibrary)
- `SystemReboot/Core/Types/MegaBoardTypes.swift`
- `SystemReboot/Core/Types/TDTypes.swift` (TDGameStateFactory)
- `SystemReboot/GameEngine/Systems/TDBossSystem.swift`
- `SystemReboot/Resources/TDConfig.json`

---

## Stage 5: Upgrade Cost Formula Unification
**Status:** OPEN
**Priority:** Low-Medium (balance inconsistency, not a crash bug)
**Estimated scope:** ~3 files

### Problem
Two different upgrade cost formulas coexist. `SharedTypes.swift` (WeaponTower) uses linear: `base + level * perLevel`. `Protocol.swift` uses exponential: `base * 2^(level-1)`. CLAUDE.md says to always use `BalanceConfig.exponentialUpgradeCost()`. BalanceConfig still defines `legacyUpgradeCostBase` and `legacyUpgradeCostPerLevel`.

### What needs untangling
- Decide: Does WeaponTower still need its own cost formula, or does it go away with Stage 1?
- If WeaponTower is removed in Stage 1, the linear formula dies with it — this stage may be free
- If WeaponTower survives, migrate its `upgradeCost` to use `BalanceConfig.exponentialUpgradeCost()`
- Remove `legacyUpgradeCostBase` / `legacyUpgradeCostPerLevel` from BalanceConfig if unused after Stage 1

### Key files to investigate
- `SystemReboot/Core/Types/SharedTypes.swift`
- `SystemReboot/Core/Types/Protocol.swift`
- `SystemReboot/Core/Config/BalanceConfig.swift`

### Dependencies
- Depends on Stage 1 outcome (if WeaponTower is removed, this is moot)

---

## Stage 6: Dead Config and State Cleanup
**Status:** OPEN
**Priority:** Low (no bugs, just cruft)
**Estimated scope:** ~5 files

### Problem
Leftover config data, unused state, and stale JSON. `TDConfig.json` uses "gold" naming and may not even be loaded. Wave-based fields on TDGameState (`waveInProgress`, `waveEnemiesRemaining`, etc.) may be vestigial now that the game uses continuous idle spawning. Legacy reward fallback paths in GameRewardService may be unreachable.

### What needs untangling
- **`TDConfig.json` is confirmed dead** (Stage 4 verified: bundled but never loaded; only `GameConfig.json` is loaded by `GameConfigLoader`) — safe to delete
- **`DataBusConnection` and `EncryptionGate` types are dead infrastructure** (Stage 4 added TODO: always-empty arrays, rendering code never produces output) — remove types, query methods, and rendering code
- Verify which `TDConfig.json` fields are actually loaded by `GameConfigLoader`
- Check if wave-tracking fields on TDGameState are read anywhere or are dead
- Check if `GameRewardService` legacy fallback (`legacyHashPerKills` etc.) is ever reached
- Check `BossSimulator.playerWeaponDamage` field marked as legacy
- Check `StorageService.saveRunResult()` / `saveTDResult()` — are these legacy wrappers that duplicate GameRewardService?
- Remove dead paths, update or delete stale JSON

### Key files to investigate
- `SystemReboot/Resources/TDConfig.json`
- `SystemReboot/Core/Config/GameConfig.swift` (what it loads)
- `SystemReboot/Core/Types/TDTypes.swift` (wave fields)
- `SystemReboot/GameEngine/Systems/GameRewardService.swift`
- `SystemReboot/GameEngine/Simulation/BossSimulator.swift`
- `SystemReboot/Services/StorageService.swift`
