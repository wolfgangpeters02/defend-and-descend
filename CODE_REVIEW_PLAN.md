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
- [ ] Split web simulator into separate HTML/CSS/JS files
- [ ] Add automated sync test: web defaults vs BalanceConfig.exportJSON()
- [ ] Consider exposing game simulator results in web UI

### Should the Simulator Be Split?

**Yes, but not yet.** The web simulator should be split into separate files (HTML template, CSS, JS modules) when it's next extended with new tabs. Splitting it now without adding functionality would be churn. The CLI simulator is small enough to stay as one file — but it must stop duplicating values.

---

## Track 4: Systems Code Review

**Goal:** Verify game systems are correct, consistent, and free of logic bugs introduced during refactoring.

### Review Checklist

Each system should be reviewed for: correct delegation to services, no stale/dead code, proper error handling at boundaries, and consistent use of BalanceConfig.

#### Phase 2 Services (verify delegation is complete)
- [ ] `OfflineSimulator` — StorageService fully delegates, no inline calculations remain
- [ ] `TowerPlacementService` — No coordinate conversion logic remains in UI files
- [ ] `GameRewardService` — No XP/hash formulas remain in TDGameContainerView or AppState
- [ ] `FreezeRecoveryService` — No efficiency restoration logic remains in UI/scene files
- [ ] `BossFightCoordinator` — No NotificationCenter patterns remain for boss fight flow
- [ ] `SectorUnlockSystem` — No inline unlock→save→refresh flows remain in UI files

#### Phase 4 Extractions (verify clean boundaries)
- [ ] `TDGameLoop` — No SpriteKit imports, returns pure data via TDFrameResult
- [ ] `TDCollisionSystem` — No rendering side effects, returns VisualEvents
- [ ] `ManualOverrideSystem` — No SKNode references, returns FrameEvents
- [ ] `BossRenderingManager` — Scene reference is weak, no game state mutation
- [ ] `CameraController` — No game state dependencies
- [ ] `ParticleEffectService` — No game state reads, only position/color inputs

#### Cross-cutting Concerns
- [ ] No circular dependencies between layers (Core → GameEngine → Rendering → UI)
- [ ] No retain cycles from weak/strong scene references in extracted managers
- [ ] Consistent error handling: what happens if a service gets nil/invalid input?

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

### Recommended Execution Order

| Priority | Task | Files | Risk | Impact |
|----------|------|-------|------|--------|
| 1 | SpatialGrid for collisions | TDCollisionSystem.swift | Low | High |
| 2 | SpatialGrid for targeting | TowerSystem.swift | Low | High |
| 3 | Trail geometry caching | TDGameScene+EntityVisuals.swift | Low | Medium |
| 4 | Particle node pooling | ParticleEffectService.swift | Low | Medium |
| 5 | Frost crystal recycling | TDGameScene+EntityVisuals.swift | Low | Medium |
| 6 | LED squared distance | TDGameScene+Paths.swift | Low | Medium |
| 7 | Cooldown arc caching | TDGameScene+EntityVisuals.swift | Low | Low-Medium |

### Profiling Strategy

Before implementing, profile on the lowest-supported device to establish baseline:
- [ ] Measure FPS during wave 15+ with 20+ towers (peak entity count)
- [ ] Measure FPS during boss fight with active mechanics
- [ ] Measure FPS on motherboard map with all sectors visible
- [ ] Use Instruments Time Profiler to confirm hotspots match static analysis
- [ ] After each optimization, re-measure to validate improvement

---

## Track 6: Structural Health Check

**Goal:** Verify the refactoring didn't introduce architectural drift and the file organization holds.

### Quick Metrics Check

- [ ] No file exceeds 800 lines (excluding BalanceConfig, simulation tools, and single-concern extensions)
- [ ] No new types added to existing files instead of dedicated files
- [ ] All new game logic added to `GameEngine/Systems/`, not UI files
- [ ] No new hardcoded strings or balance values

### Dependency Direction Audit

The clean dependency flow should be: `Core` ← `GameEngine` ← `Rendering` ← `UI`

- [ ] No `import SpriteKit` in `Core/` or `GameEngine/Systems/` (except rendering-adjacent systems)
- [ ] No `import SwiftUI` in `GameEngine/` or `Rendering/`
- [ ] No `Rendering/` files importing from `UI/`
- [ ] `TDGameLoop`, `TDCollisionSystem`, `ManualOverrideSystem` have zero SpriteKit dependencies

---

## Suggested Execution Order

1. **Track 1 + Track 2** (BalanceConfig + L10n) — quick wins, ~30 min each
2. **Track 3** (Simulator) — fix critical sync errors first, extend coverage later
3. **Track 5, items 1-2** (SpatialGrid integration) — highest performance ROI
4. **Track 4** (Systems review) — thorough but lower urgency
5. **Track 5, items 3-7** (remaining perf work) — guided by profiling data
6. **Track 6** (Structural health) — periodic check, not urgent
