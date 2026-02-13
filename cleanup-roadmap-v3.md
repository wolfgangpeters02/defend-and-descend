# Codebase Cleanup Roadmap v3

Third pass — post-v2 cleanup. Findings from a 5-agent deep audit (stale comments, duplicate systems, dead code, naming inconsistencies, architectural anti-patterns).
Each stage should be tackled in plan mode to map dependencies before making changes.

---

## Stage 1: Broken Protocol Colors + Competing Level Formulas
**Status:** DONE
**Priority:** High (broken functionality + conflicting game math)
**Estimated scope:** ~4 files

### Summary of Changes
- **ParticleFactory.swift**: Replaced 25-line stale `getProtocolColor()` switch (old weapon IDs) with `ProtocolLibrary.get(protocolId)?.color` lookup — protocols now emit their defined colors instead of white fallback
- **BalanceConfig.swift**: Deleted dead `levelMultiplier(level:)` (0 callers); replaced with `linearLevelBonus(level:bonusRate:)` generic helper
- **CoreSystem.swift**: Replaced inline `1.0 + (level-1) * rate` formula with `BalanceConfig.linearLevelBonus()` call
- **LevelingSystem.swift**: Replaced inline formula with `BalanceConfig.linearLevelBonus()` call

### Problem A — Protocol Colors Return Wrong Values
`ParticleFactory.getProtocolColor()` (ParticleFactory.swift:211-237) switches on old weapon IDs like `"sword"`, `"katana"`, `"axe"`, `"bow"`, `"wand"`, `"excalibur"`, `"scythe"`. The actual protocol IDs are `"kernel_pulse"`, `"burst_protocol"`, `"trace_route"`, etc. — none match, so every protocol gets the white `#ffffff` fallback. The function is effectively dead.

### Problem B — Two Competing Level Multiplier Formulas
BalanceConfig defines two different formulas for the same concept:
- `levelStatMultiplier(level:)` at line ~49: **power curve** `pow(level, 0.6)` — used by Protocol.swift for firewall/weapon stats
- `levelMultiplier(level:)` at line ~1980: **linear** `1.0 + (level-1) * bonusPerLevel` — used by LevelingSystem for level bonuses

Additionally, CoreSystem.swift:25 inlines its own calculation: `1.0 + (level - 1) * BalanceConfig.TDCore.levelBonusPercent`.

These produce different results for the same level and it's unclear which is "correct."

### What needs doing
- Replace `getProtocolColor()` switch cases with actual protocol IDs from `EntityIDs.ProtocolID`, or look up color from Protocol.color field
- Decide on ONE level multiplier formula and remove the other
- Update CoreSystem inline calculation to call the chosen function
- Audit all callers to ensure consistent formula usage

### Key files to investigate
- `SystemReboot/Rendering/ParticleFactory.swift` (getProtocolColor)
- `SystemReboot/Core/Config/BalanceConfig.swift` (both levelStatMultiplier and levelMultiplier)
- `SystemReboot/Core/Types/Protocol.swift` (calls levelStatMultiplier)
- `SystemReboot/GameEngine/Systems/LevelingSystem.swift` (calls getLevelMultiplier)
- `SystemReboot/GameEngine/Systems/CoreSystem.swift` (inline level bonus calculation)

---

## Stage 2: Dead Types + Unused Enum Cases
**Status:** DONE
**Priority:** Medium (dead weight, no bugs)
**Estimated scope:** ~3 files

### Summary of Changes
- **SharedTypes.swift**: Deleted `SharedEnemy` struct (~30 lines) and `CollectionItem` struct + nested `CollectionCategory` enum (~18 lines) — zero references outside definitions
- **BossStates.swift**: Deleted `MeteorStrike` struct from VoidHarbingerAI extension — meteor mechanics use `meteorInterval`/`lastMeteorTime` fields directly
- **CombatTypes.swift**: Removed `.plus` and `.heart` cases from `ParticleShape` enum — `createParticleNode()` never rendered them (fell through to default circle)

### Problem
Structs and enum cases that survived previous cleanups but have zero references:

- **`SharedEnemy`** in SharedTypes.swift (~line 144, ~30 lines) — 0 references outside definition. Includes `.scaled()` method.
- **`CollectionItem`** in SharedTypes.swift (~line 177, ~15 lines) — 0 references outside definition.
- **`MeteorStrike`** in BossStates.swift (~line 148) — defined in VoidHarbingerAI extension but never instantiated. Meteor mechanics now use `meteorInterval`/`lastMeteorTime` directly.
- **`ParticleShape.plus`** and **`.heart`** in CombatTypes.swift:140-141 — never rendered. `createParticleNode()` only handles `.star`, `.spark`, `.square`, `.diamond`, and default `.circle`.

### What needs doing
- Delete `SharedEnemy` and `CollectionItem` from SharedTypes.swift
- Delete `MeteorStrike` from BossStates.swift
- Remove `.plus` and `.heart` from `ParticleShape` enum in CombatTypes.swift
- Remove from .pbxproj if any files are fully deleted

### Key files to investigate
- `SystemReboot/Core/Types/SharedTypes.swift` (SharedEnemy, CollectionItem)
- `SystemReboot/Core/Types/BossStates.swift` (MeteorStrike)
- `SystemReboot/Core/Types/CombatTypes.swift` (ParticleShape.plus, .heart)

---

## Stage 3: Stale Comments + Misleading Labels
**Status:** DONE
**Priority:** Medium (developer confusion, misleading documentation)
**Estimated scope:** ~10 files

### Summary of Changes
- **EntityRenderer+EnemyDetails.swift**: Renamed "Zero-Day Exploit" references to "Elite Virus" (MARK header + doc comment)
- **TDGameScene+EntityVisuals.swift**: Renamed "Zero-Day Exploit" comment to "Elite virus"; replaced misleading "Deprecated Tower Methods" MARK with "Enemy Shape Paths" (methods are actively used for enemy nodes); removed commented-out `spawnTracePulse()` code + NOTE
- **MegaBoardRenderer.swift**: Deleted dead `renderGhostSector()` function (0 callers) along with its "Legacy Support" MARK
- **TDGameContainerView+Overlays.swift**: Replaced TODO mini-game placeholder with factual "Restore efficiency to configured recovery level" comment
- **TDGameScene+Actions.swift**: Deleted orphaned "Motherboard City" placeholder comment referencing unimplemented methods
- **DesignSystem.swift**: Removed 7 unused legacy path color aliases (`pathFillLight/Dark/Border` + UI variants) and their "Legacy" comment
- **TDGameScene+Paths.swift**: Replaced `pathBorderUI` usage with `traceBorderUI`; removed commented-out `startPowerFlowParticles()` + NOTE
- **GameTypes.swift**: Removed stale "Also represents Towers in TD mode" from Weapon MARK; updated inline comments to drop tower references
- **TDTypes.swift**: Removed misleading "legacy" label from active wave progress tracking fields
- **SharedTypes.swift**: Skipped — `case weapon // Also unlocks tower` was already removed in a prior cleanup

### Problem
Comments that reference removed systems, label active code as "deprecated"/"legacy", or contain unimplemented placeholder promises.

### What needs fixing

1. **Zero-Day terminology on elite virus code** — EntityRenderer+EnemyDetails.swift:198-202, TDGameScene+EntityVisuals.swift:817-818 reference "Zero-Day Exploit" but the Zero-Day system was removed in commit dca6871. Rename to "Elite Virus".

2. **"Deprecated Tower Methods" label on active code** — TDGameScene+EntityVisuals.swift:594-599 says methods are deprecated and replaced by TowerVisualFactory, but the hexagon/diamond path methods are still actively used for enemy nodes.

3. **"Legacy Support" on active `renderGhostSector()`** — MegaBoardRenderer.swift:316 labels this as "Legacy Support" but it's the current dispatch mechanism.

4. **TODO mini-game placeholder** — TDGameContainerView+Overlays.swift:420 says `// TODO: Launch 30-second survival mini-game` with placeholder recovery code. Either implement or remove the TODO and update the comment to explain this IS the intended behavior.

5. **"Will implement" empty placeholder** — TDGameScene+Actions.swift:17-18 says `// Will implement: setupMotherboard(), updateComponentVisibility(), playInstallAnimation()` — these either exist elsewhere or were cut.

6. **Legacy path color aliases** — DesignSystem.swift:57-60 defines `pathFillLight`, `pathFillDark`, `pathBorder` as "Legacy path colors" but they're just aliases to trace colors. Remove the aliases if unused, or drop the "Legacy" label.

7. **Stale Weapon comment** — GameTypes.swift:289 says `// MARK: - Weapon (Also represents Towers in TD mode)` — Weapon struct no longer represents towers.

8. **"Legacy wave fields" comment** — TDTypes.swift:40 says wave progress tracking fields are "legacy" but they're actively used for stats.

9. **Stale "weapons/towers" in SharedTypes.swift** — SharedTypes.swift:189 `case weapon // Also unlocks tower` describes the old dual-unlock system that no longer exists.

10. **Commented-out code** — TDGameScene+Paths.swift:15-16 and TDGameScene+EntityVisuals.swift:232-234 have commented-out `startPowerFlowParticles()` and `spawnTracePulse()` calls with NOTE comments. Remove entirely.

### Key files to investigate
- `SystemReboot/Rendering/EntityRenderer+EnemyDetails.swift`
- `SystemReboot/Rendering/TDGameScene+EntityVisuals.swift`
- `SystemReboot/Rendering/MegaBoardRenderer.swift`
- `SystemReboot/UI/Game/TDGameContainerView+Overlays.swift`
- `SystemReboot/Rendering/TDGameScene+Actions.swift`
- `SystemReboot/Core/Config/DesignSystem.swift`
- `SystemReboot/Core/Types/GameTypes.swift`
- `SystemReboot/Core/Types/TDTypes.swift`
- `SystemReboot/Core/Types/SharedTypes.swift`
- `SystemReboot/Rendering/TDGameScene+Paths.swift`

---

## Stage 4: DRY Violations — Tier Colors + Efficiency Formula
**Status:** DONE
**Priority:** Medium (sync risk, scattered magic numbers)
**Estimated scope:** ~8 files

### Summary of Changes
- **DesignSystem.swift**: Added `TierColors` enum with `.gold` (`#ffd700`), `.silver` (`#c0c0c0`), `.bronze` (`#8b4513`) hex string constants for particle/projectile systems
- **BalanceConfig.swift**: Added `efficiencyForLeakCount(_:)` and `leakCountForEfficiency(_:)` helper functions to `TDSession` struct, next to the `efficiencyLossPerLeak` constant
- **XPSystem.swift**: Replaced 3 hardcoded hex strings in `getTierColor()` with `TierColors` constants
- **CoreSystem.swift**: Replaced hardcoded `"#ffd700"` in core auto-attack projectile with `TierColors.gold`
- **TDParticleFactory.swift**: Replaced 2 hardcoded `"#ffd700"` in hash floaties and merge celebration with `TierColors.gold`
- **VisualEffects.swift**: Replaced 3 hardcoded `"#ffd700"` in level-up and legendary explosion effects with `TierColors.gold`
- **FreezeRecoveryService.swift**: Replaced local formula implementations with delegation to `BalanceConfig.TDSession` helpers
- **TDTypes.swift**: Replaced inline efficiency formula in computed property with `BalanceConfig.TDSession.efficiencyForLeakCount()`
- **TDSimulator.swift**: Replaced 2 inline inverse formula derivations with `BalanceConfig.TDSession.leakCountForEfficiency()`
- **OfflineSimulator.swift**: Replaced 2 inline forward formula derivations with `BalanceConfig.TDSession.efficiencyForLeakCount()`

### Problem A — Tier Colors as Hardcoded Hex Strings
The same tier/rarity colors appear as raw hex strings in 5+ rendering files:
- `#ffd700` (gold) in: XPSystem `getTierColor()`, ParticleFactory, VisualEffects (level-up + legendary explosion), TDParticleFactory (hash floaties), CoreSystem (auto-attack)
- `#c0c0c0` (silver) in: XPSystem, ParticleFactory
- `#8b4513` (brown) in: XPSystem, ParticleFactory

If a tier color changes, every file needs manual updating.

### Problem B — Efficiency Formula Duplicated
The formula `100 - leakCounter * efficiencyLossPerLeak` appears in 5+ locations:
- TDTypes.swift:104 (computed property — this is the "source of truth")
- TDSimulator.swift:122 (comment + manual calc)
- FreezeRecoveryService.swift:43, 64 (inverse calc)
- TDGameContainerView.swift:374 (comment)
- OfflineSimulator (direct use)

While the computed property exists on TDGameState, other files re-derive the formula or its inverse instead of calling a shared function.

### What needs doing
- Extract tier/rarity colors to `DesignSystem.swift` (e.g., `DesignColors.tierGold`, `DesignColors.tierSilver`, `DesignColors.tierBronze`)
- Replace all hardcoded hex strings with the new constants
- Extract efficiency formula helpers: `efficiencyForLeakCount(_:)` and `leakCountForEfficiency(_:)` into BalanceConfig or a shared utility
- Update all callers to use the helpers

### Key files to investigate
- `SystemReboot/GameEngine/Systems/XPSystem.swift` (getTierColor)
- `SystemReboot/Rendering/ParticleFactory.swift` (getProtocolColor tier colors)
- `SystemReboot/Rendering/VisualEffects.swift` (level-up, legendary explosion)
- `SystemReboot/Rendering/TDParticleFactory.swift` (hash floaties)
- `SystemReboot/GameEngine/Systems/CoreSystem.swift` (auto-attack color)
- `SystemReboot/Core/Config/DesignSystem.swift` (target for shared colors)
- `SystemReboot/GameEngine/Systems/FreezeRecoveryService.swift` (efficiency formula)
- `SystemReboot/GameEngine/Simulation/TDSimulator.swift` (efficiency formula)

---

## Stage 5: Type Safety — Enemy Type Enum + ComponentType/SectorID Alignment
**Status:** DONE
**Priority:** Medium (no compile-time safety, naming mismatch)
**Estimated scope:** ~8 files

### Summary of Changes
- **EntityIDs.swift**: Added 4 missing cases to `EnemyID` enum: `overclocker`, `voidPylon` ("void_pylon"), `voidMinionSpawn` ("void_minion"), `voidElite` ("void_elite"); updated `isBoss` to include `.overclocker`
- **IdleSpawnSystem.swift**: Replaced all 13 raw enemy type strings with `EnemyID.x.rawValue`; fixed "swarm" vs "voidminion" UI inconsistency (line 234 said "swarm" but spawn system used "voidminion")
- **WaveSystem.swift**: Replaced all 10 raw enemy type strings with `EnemyID.x.rawValue`
- **TDTypes.swift**: Replaced 4 raw strings in `idleAvailableEnemyTypes` computed property with `EnemyID.x.rawValue`
- **XPSystem.swift**: Replaced 6 raw string dictionary keys in `enemyXPValues` with `EnemyID.x.rawValue`
- **CyberbossAI.swift**: Replaced 2 raw strings in `spawnMinion(type:)` calls with `EnemyID.fast/tank.rawValue`
- **TDGameScene+EntityVisuals.swift**: Replaced 6 raw strings in enemy color switch and boss type checks with `EnemyID.x.rawValue`
- **TDGameScene+Paths.swift**: Replaced 2 raw strings in LED color switch with `EnemyID.x.rawValue`
- **EntityRenderer.swift**: Replaced 5 raw strings in special rendering checks (void_pylon, void_minion, void_elite, boss) with `EnemyID.x.rawValue`
- **ComponentTypes.swift**: Renamed `UpgradeableComponent.psu` → `.power` (rawValue stays `"psu"` for serialization compat); renamed `ComponentLevels.psu` → `.power` with `CodingKeys` for backwards compat; simplified `sectorId` mapping (`case .power: return .power`)
- **BalanceConfig.swift**: Updated 4 `ComponentLevels` preset initializers from `psu:` → `power:`
- **DebugGameView.swift**: Updated 4 `.psu` references → `.power`
- **SimulationRunner.swift**: Updated 4 `.psu` property accesses → `.power`
- **PlayerProfile.swift**: Updated 1 `.psu` migration reference → `.power`

### Problem A — Enemy Types as Raw Strings
Enemy types are scattered as raw string literals (`"basic"`, `"fast"`, `"tank"`, `"boss"`, `"voidminion"`) across multiple files with no enum. Typos won't be caught at compile time.

Affected files:
- IdleSpawnSystem.swift:70-97 — `("basic", 100)`, `("fast", fastWeight)`, etc.
- WaveSystem.swift:37-97 — `type: "basic"`, `type: "fast"`, `type: "tank"`
- TDTypes.swift:73-76 — `types.append("fast")`, `types.append("tank")`
- Various rendering files switch on enemy type strings

### Problem B — ComponentType vs SectorID Mismatch
Two nearly identical enums define motherboard hardware components:
- `ComponentType` in ComponentTypes.swift: `.psu`, `.storage`, `.ram`, `.gpu`, `.cache`, `.expansion`, `.io`, `.network`, `.cpu`
- `SectorID` in EntityIDs.swift: `.cpu`, `.ram`, `.gpu`, `.storage`, `.io`, `.network`, `.power`, `.cache`, `.expansion`

Key difference: `ComponentType.psu` vs `SectorID.power` for the same concept. No clear mapping between the two.

### What needs doing
- Create an `EnemyTypeID` enum (or add cases to EntityIDs) with all enemy type strings
- Replace raw string literals with enum references
- Align ComponentType and SectorID — either merge into one enum, or add an explicit mapping function and rename `.psu`/`.power` to match

### Key files to investigate
- `SystemReboot/GameEngine/Systems/IdleSpawnSystem.swift` (enemy type strings)
- `SystemReboot/GameEngine/Systems/WaveSystem.swift` (enemy type strings)
- `SystemReboot/Core/Types/TDTypes.swift` (enemy type strings, ThreatLevel)
- `SystemReboot/Core/Types/ComponentTypes.swift` (ComponentType enum)
- `SystemReboot/Core/Types/EntityIDs.swift` (SectorID enum)
- `SystemReboot/Rendering/TDGameScene+EntityVisuals.swift` (switches on enemy type strings)

---

## Stage 6: Oversized Files (Ongoing)
**Status:** OPEN
**Priority:** Low (structural improvement, high effort, no bugs)
**Estimated scope:** 14+ files

### Problem
14 files exceed the project's 800-line guideline. The worst offenders:

| File | Lines | Split Strategy |
|------|-------|---------------|
| BalanceConfig.swift | 2,376 | Split by domain: `BalanceConfig+Bosses.swift`, `BalanceConfig+TD.swift`, `BalanceConfig+Survival.swift`, `BalanceConfig+LootTables.swift` |
| BossSimulator.swift | 2,023 | Split by boss type |
| SimulationRunner.swift | 1,793 | Extract test scenarios to data file |
| BossRenderingManager.swift | 1,436 | Split into per-boss renderers: `CyberbossRenderer`, `VoidHarbingerRenderer`, etc. |
| TDGameScene+SectorComponents.swift | 1,302 | Split by sector group |
| TDGameScene+EntityVisuals.swift | 1,294 | Split enemy vs tower visuals |
| TDTypes.swift | 1,023 | Extract TDGameStateFactory to own file |

### What needs doing
- This is ongoing work — tackle files as they're touched for other changes
- Priority splits: BalanceConfig (most impactful), BossRenderingManager (clear decomposition), TDTypes (TDGameStateFactory extraction)
- For each split: use Swift extensions in separate files, ensure no circular dependencies

### Key files to investigate
All files listed in the table above.

---

## Reusable Prompt for New Sessions

When starting a new Claude Code session to tackle a stage, paste this:

> Read `cleanup-roadmap-v3.md` in the project root. I want to work on **Stage N** (replace N). Enter plan mode, investigate all listed files, verify the problems still exist, then propose the specific changes. After I approve the plan, implement the changes, build to verify (`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme SystemReboot -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.4' build 2>&1 | tail -5`), and update the stage status to DONE with a summary of what was changed.
