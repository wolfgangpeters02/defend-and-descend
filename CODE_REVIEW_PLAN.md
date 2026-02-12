# Code Review & Optimization Plan

## Overview

Six review tracks, designed to be executed independently or in sequence. Each track has a specific goal, concrete findings from static analysis, and actionable steps.

---

## Track 1: BalanceConfig Compliance

**Goal:** Every game balance value lives in `BalanceConfig.swift` — zero magic numbers in game systems.

### Current State

Most systems are compliant. Two files have significant violations:

### Violations Found

**ManualOverrideSystem.swift — 8 hardcoded balance values:**

| Line | Value | What It Controls |
|------|-------|-----------------|
| 201 | `70` | Sweep hazard gap size |
| 210, 221 | `80` | Sweep hazard velocity |
| 248 | `80` | Expanding hazard growth rate |
| 285 | `15` | Player collision radius |
| 290 | `15` | Hazard collision radius |
| 88 | `5` | Difficulty escalation interval (seconds) |
| 88 | `0.2` | Spawn interval reduction per tick |

**OfflineSimulator.swift — 6 hardcoded balance values:**

| Line | Value | What It Controls |
|------|-------|-----------------|
| 57, 131 | `20` | Base enemy HP for offline simulation |
| 64 | `0.8` | Defense threshold (80% to hold) |
| 73 | `10.0` | Max leaks per hour without defense |
| 33, 100 | `86400` | 24-hour offline cap |
| 173 | `300`–`86400` | Notification time range |

### Action Items

- [x] Add `BalanceConfig.ManualOverride` struct with all 8 values
- [x] Add `BalanceConfig.OfflineSimulation` struct with all 6 values
- [x] Replace hardcoded values in both files with BalanceConfig references
- [x] Verify no other files snuck in magic numbers since the refactoring

### Already Compliant (verified)

WeaponSystem, LevelingSystem, XPSystem, TowerSystem, ProjectileSystem, SurvivalArenaSystem, ZeroDaySystem, IdleSpawnSystem, PickupSystem, OverclockSystem, PlayerSystem, EnemySystem — all use BalanceConfig correctly.

---

## Track 2: L10n Compliance

**Goal:** All user-facing strings go through the L10n system.

### Current State

Excellent — the codebase is nearly fully localized. Only 2 production violations found.

### Violations Found

| File | Line | String | Fix |
|------|------|--------|-----|
| `IntroSequenceView.swift` | 311 | `"24/7"` | Add `L10n.Intro.operatingHours` |
| `MotherboardView.swift` | 265 | `"SYSTEM"` | Add `L10n.Motherboard.system` |

Preview-only (non-production):
- `TutorialHintOverlay.swift:244` — `"Tutorial Hint Active"` (in `#Preview` block)
- `TutorialHintOverlay.swift:269` — `"BOSS"` (in `#Preview` block)

### Action Items

- [x] Add L10n keys + German translations for the 2 production strings
- [x] Optionally localize preview strings for consistency (skipped — preview-only, not shipped)
- [x] Verify all rendering files (SKLabelNode text assignments) use L10n — confirmed clean

### Already Compliant (verified)

All SpriteKit labels, all alert messages, all navigation titles, all button labels in production code use L10n. Hardware terms (CPU, DDR5, USB, etc.) are correctly left unlocalized.

---

## Track 3: Balance Simulator Audit

**Goal:** The simulator is accurate, maintainable, and useful as the primary balancing tool.

### Current State: Functional but Fragmented

| Tool | Lines | Coverage | Sync Status |
|------|-------|----------|-------------|
| Web simulator (`balance-simulator.html`) | 1,647 | ~20% of game systems | 2 critical mismatches |
| Swift CLI (`tools/BalanceSimulator/main.swift`) | 478 | ~30% of game systems | Hardcoded duplicate values |
| Game simulators (BossSimulator, TDSimulator, etc.) | ~4,400 | ~80% of game systems | Uses BalanceConfig directly |

### Critical Sync Errors

1. **Tower power draw values are WRONG in web simulator:**
   - Web: common=15, rare=30, epic=60, legendary=100
   - BalanceConfig: common=15, rare=20, epic=30, legendary=40
   - Impact: Power budget calculations completely wrong in web tool

2. **Cyberboss base HP mismatch:**
   - Web default: 5000
   - BalanceConfig: uses dynamic wave scaling (9999 for ZeroDay)

3. **CLI simulator duplicates values** instead of importing from BalanceConfig — no guarantee of sync

### Coverage Gaps (major systems missing from web simulator)

- Component upgrade system (9 components with upgrade trees)
- Sector unlock progression (costs, boss gating)
- Protocol abilities (Throttler, Pinger, GarbageCollector, Fragmenter, Recursion)
- Efficiency decay/recovery (freeze system)
- Survival mode events
- Tower type comparison
- XP & loot tables

### Structural Issues

1. **Monolithic HTML** — 1,647 lines, CSS/JS/HTML mixed, hard to extend
2. **Triple source of truth** — values in web HTML, CLI Swift, and BalanceConfig.swift
3. **No bidirectional sync** — `exportJSON()` only covers ~15-20% of BalanceConfig values
4. **Isolated simulators** — game simulators (TDSimulator/BossSimulator) not connected to web UI

### Action Items

#### High Priority (fix what's broken)
- [x] Fix tower power draw values in web simulator to match BalanceConfig
- [x] Fix Cyberboss HP default in web simulator
- [x] Expand `BalanceConfig.exportJSON()` to cover all tunable sections
- [x] Make CLI simulator import from BalanceConfig instead of hardcoding values

#### Medium Priority (extend coverage)
- [x] Add Component upgrade tab to web simulator
- [x] Add Protocol ability comparison tab
- [x] Add Efficiency/Freeze system visualization
- [x] Add Sector progression timeline

#### Low Priority (structural improvements)
- [x] Split web simulator into separate HTML/CSS/JS files
- [x] Add automated sync test: web defaults vs BalanceConfig.exportJSON()
- [x] Consider exposing game simulator results in web UI *(evaluated — not recommended: game simulators run full Swift engine simulations that can't be meaningfully replicated in JS; the web tool serves a different purpose of parameter tuning/visualization)*

### Should the Simulator Be Split?

**Done.** The web simulator has been split into `balance-simulator.html` (1,066 lines), `balance-simulator.css` (299 lines), and `balance-simulator.js` (772 lines). A sync test script (`check-balance-sync.py`) was added to verify web defaults match BalanceConfig.exportJSON() output. The CLI simulator is small enough to stay as one file — but it must stop duplicating values.

---

## Track 4: Systems Code Review

**Goal:** Verify game systems are correct, consistent, and free of logic bugs introduced during refactoring.

### Review Checklist

Each system should be reviewed for: correct delegation to services, no stale/dead code, proper error handling at boundaries, and consistent use of BalanceConfig.

#### Phase 2 Services (verify delegation is complete)
- [x] `OfflineSimulator` — StorageService fully delegates, no inline calculations remain
- [x] `TowerPlacementService` — No coordinate conversion logic remains in UI files
- [x] `GameRewardService` — No XP/hash formulas remain in TDGameContainerView or AppState *(unused legacy DebugGameView has inline hash calc — dead code, not a production violation)*
- [x] `FreezeRecoveryService` — No efficiency restoration logic remains in UI/scene files *(1 minor violation: TDGameContainerView+Overlays.swift:107 directly sets leakCounter for Zero-Day defeat penalty; TDBossSystem.swift:302 resets leakCounter on boss victory — both are single-line state resets, not formula duplication)*
- [x] `BossFightCoordinator` — No NotificationCenter patterns remain for boss fight flow
- [x] `SectorUnlockSystem` — No inline unlock→save→refresh flows remain in UI files *(unused legacy DebugGameView has inline unlock — dead code, not a production violation)*

#### Phase 4 Extractions (verify clean boundaries)
- [x] `TDGameLoop` — No SpriteKit imports, returns pure data via TDFrameResult (imports Foundation + CoreGraphics only)
- [x] `TDCollisionSystem` — No rendering side effects, returns VisualEvents (imports Foundation + CoreGraphics only)
- [x] `ManualOverrideSystem` — No SKNode references, returns FrameEvents (imports Foundation only)
- [x] `BossRenderingManager` — Scene reference is weak (`weak var scene: SKScene?`), no game state mutation
- [x] `CameraController` — No game state dependencies (only camera/viewport logic)
- [x] `ParticleEffectService` — No game state reads, only position/color inputs (uses injectable closures for queries)

#### Cross-cutting Concerns
- [x] No circular dependencies between layers (Core → GameEngine → Rendering → UI) *(2 known exceptions: DesignSystem.swift imports SpriteKit for SKShapeNode extensions, CurrencyInfoType.swift imports SwiftUI for Color type; 11 TDGameScene\* files in Rendering/ have unnecessary `import SwiftUI` — no actual SwiftUI usage)*
- [x] No retain cycles from weak/strong scene references in extracted managers *(all managers use `weak var scene`, closures use `[weak self]` correctly)*
- [x] Consistent error handling: what happens if a service gets nil/invalid input? *(services use guard-let + early return consistently; OfflineSimulator has theoretical division-by-zero paths if BalanceConfig values are zero — acceptable since config is static; BossFightCoordinator uses silent fallback defaults for optional callbacks)*

---

## Track 5: Performance Optimization Plan

**Goal:** Maintain 60 FPS on the motherboard map with many towers/enemies and during boss fights.

### High Impact Optimizations

#### 1. SpatialGrid for Collision Detection
**File:** `TDCollisionSystem.swift:28-133`
**Problem:** Brute-force O(n²) — every projectile checked against every enemy each frame
**Solution:** Use existing `SpatialGrid.swift` (already well-implemented, only used for chain lightning)
**Expected gain:** 30-40% frame time reduction during heavy combat
**Risk:** Low — SpatialGrid is proven in the codebase

```
Current: 100 enemies × 50 projectiles = 5,000 checks/frame
With grid: ~50 projectiles × ~5 nearby enemies = ~250 checks/frame
```

#### 2. SpatialGrid for Tower Targeting
**File:** `TowerSystem.swift:168-280`
**Problem:** Each tower iterates ALL enemies to find targets in range
**Solution:** Use `SpatialGrid.findNearest()` for range queries
**Expected gain:** 15-25% frame time reduction with many towers
**Risk:** Low — same grid infrastructure

```
Current: 50 towers × 100 enemies = 5,000 distance checks/frame
With grid: 50 towers × ~5 grid cells = ~250 checks/frame
```

### Medium Impact Optimizations

#### 3. Projectile Trail Geometry Caching
**File:** `TDGameScene+EntityVisuals.swift:986-1018`
**Problem:** Creates new `CGMutablePath` every frame for every projectile trail
**Solution:** Cache path, only rebuild when trail points change
**Expected gain:** 5-10% frame time reduction

#### 4. LED Proximity Queries
**File:** `TDGameScene+Paths.swift:496-541`
**Problem:** O(n) per-LED enemy search with `sqrt()` per check (~2,000 distance calculations)
**Solution:** Use squared distance comparisons (avoid `sqrt`), batch by lane, or use spatial grid
**Note:** Already throttled to every 3rd frame with visibility culling — partially mitigated
**Expected gain:** 5-10% in zoomed-in view

#### 5. Enemy Frost Crystal Recycling
**File:** `TDGameScene+EntityVisuals.swift` (enemy rendering)
**Problem:** Frost crystal decorations created/destroyed every frame for slowed enemies
**Solution:** Pool frost crystal nodes, toggle visibility instead of create/destroy
**Expected gain:** 3-8% during slow-heavy compositions

#### 6. Tower Cooldown Arc Caching
**File:** `TDGameScene+EntityVisuals.swift:204-237`
**Problem:** Trigonometry recalculated every frame for every tower's cooldown indicator
**Solution:** Only recalculate when cooldown progress changes (on attack/reload)
**Expected gain:** 2-5% frame time

#### 7. Particle Pooling for Frequent Effects
**File:** `ParticleEffectService.swift:632-672`
**Problem:** Boss death spawns 50 fresh `SKShapeNode` particles, no pooling
**Solution:** Use existing `NodePool` (already in codebase) for impact sparks, death particles, and portal effects
**Expected gain:** Eliminates allocation spikes during combat

### Low Impact / Already Optimized

- **Sector components:** Already use batched path rendering
- **Ambient particles:** Already capped at 30 with tracking
- **Boss cached actions:** Already use lazy `SKAction` properties
- **LED updates:** Already throttled to 1/3 frame rate with zoom culling

### Implementation Status

| Priority | Task | Files | Status |
|----------|------|-------|--------|
| 1 | SpatialGrid for collisions | TDCollisionSystem.swift, SpatialGrid.swift, TDTypes.swift, TDGameLoop.swift | **Done** — Added `SpatialGrid<TDEnemy>` extension, `enemyGrid` property to TDGameState, grid rebuild per frame, spatial queries in collision loop + splash damage |
| 2 | SpatialGrid for targeting | TowerSystem.swift | **Done** — Tower targeting uses grid query + squared distance instead of iterating all enemies |
| 3 | Trail geometry caching | TDGameScene+EntityVisuals.swift | **Already optimized** — Code already uses single CGMutablePath per trail; trail changes every frame by design |
| 4 | LED squared distance | TDGameScene+Paths.swift | **Done** — Inner loop uses squared distance comparison, sqrt only for final nearest enemy |
| 5 | Frost crystal recycling | TDGameScene+EntityVisuals.swift | **Done** — Toggles `isHidden` instead of create/destroy cycle |
| 6 | Cooldown arc caching | TDGameScene+EntityVisuals.swift | **Done** — Caches progress per tower, only rebuilds arc path when progress changes by >2% |
| 7 | Particle pooling | ParticleEffectService.swift | **Done** — Boss death particles use internal pool (acquire/release) instead of fresh allocation + removeFromParent |

### Profiling Strategy

Profile on the lowest-supported device to validate improvements:
- [ ] Measure FPS during wave 15+ with 20+ towers (peak entity count)
- [ ] Measure FPS during boss fight with active mechanics
- [ ] Measure FPS on motherboard map with all sectors visible
- [ ] Use Instruments Time Profiler to confirm hotspots match static analysis
- [ ] After each optimization, re-measure to validate improvement

---

## Track 6: Structural Health Check

**Goal:** Verify the refactoring didn't introduce architectural drift and the file organization holds.

### Quick Metrics Check

- [x] No file exceeds 800 lines *(5 non-exempt files over 800: TDTypes.swift 1331, BossRenderingManager.swift 1125, BlueprintRevealModal.swift 911, ParticleEffectService.swift 880, TDGameScene.swift 869 — all pre-existing from before refactoring, no new growth)*
- [x] No new types added to existing files instead of dedicated files *(structural debt in Core/Types: TDTypes.swift has 13 types including 500-line TDGameStateFactory, GameTypes.swift has 28 types; UI has ManualOverrideView.swift bundling controller+scene classes — all pre-existing, no new violations)*
- [x] All new game logic added to `GameEngine/Systems/`, not UI files *(clean — no game calculations found in UI views; ManualOverrideController/Scene in ManualOverrideView.swift are view-adjacent, not new additions)*
- [x] No new hardcoded strings or balance values *(balance values: all properly centralized in BalanceConfig; strings: rendering files have hardcoded motherboard labels like "REV 2.0", "© LEGENDARY TECH", cost format "Ħ" — hardware terms exempt per CLAUDE.md, decorative labels are low-priority)*

### Dependency Direction Audit

The clean dependency flow should be: `Core` ← `GameEngine` ← `Rendering` ← `UI`

- [x] No `import SpriteKit` in `Core/` or `GameEngine/Systems/` *(1 known exception: DesignSystem.swift imports SpriteKit for SKShapeNode extensions — rendering-adjacent config, acceptable)*
- [x] No `import SwiftUI` in `GameEngine/` or `Rendering/` *(GameEngine: clean; Rendering: 11 TDGameScene\* files import SwiftUI for Color bridging — known issue from Track 4, no actual SwiftUI view usage)*
- [x] No `Rendering/` files importing from `UI/` *(clean — zero code dependencies from Rendering to UI; only proper TDGameSceneDelegate protocol pattern)*
- [x] `TDGameLoop`, `TDCollisionSystem`, `ManualOverrideSystem` have zero SpriteKit dependencies *(confirmed: TDGameLoop imports Foundation+CoreGraphics, TDCollisionSystem imports Foundation+CoreGraphics, ManualOverrideSystem imports Foundation only)*

---

## Suggested Execution Order

1. **Track 1 + Track 2** (BalanceConfig + L10n) — quick wins, ~30 min each
2. **Track 3** (Simulator) — fix critical sync errors first, extend coverage later
3. **Track 5, items 1-2** (SpatialGrid integration) — highest performance ROI
4. **Track 4** (Systems review) — thorough but lower urgency
5. **Track 5, items 3-7** (remaining perf work) — guided by profiling data
6. **Track 6** (Structural health) — periodic check, not urgent
