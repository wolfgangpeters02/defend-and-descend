# Rendering Review: Multi-Stage Improvement Plan

Comprehensive review of all tower, enemy, boss, sector, lane, and particle rendering code (~30 files, ~12,000 lines).

Stages 1-5 focus on the board/TD view. Stages 6-11 focus on boss fight visual polish. Execute in order — Stages 1-5 clean up the files that Stages 6-11 build on, and Stage 5a (split BossRenderingManager) gives the boss fight stages smaller, focused files to work in.

---

## Stage 1: Dead Code Removal (Cleanup) -- DONE

Removed rendering code for protocols/archetypes that no longer exist in the game. Three orphaned archetypes (`magic`, `pyro`, `legendary`) had full visual pipelines that were never reached.

**Changes made:**
- Removed `magic`, `pyro`, `legendary` from `TowerArchetype` enum and all switch branches across 6 TowerVisualFactory files
- Removed dead platform creators: `createArcaneCircle`, `createIndustrialBase`, `createSacredPlatform`
- Removed dead body creators: `createArcaneBody`, `createRuneSymbol`, `createIncineratorBody`, `createDivineBody`, `createSwordPath`
- Removed dead barrel creators: `createOrbEmitter`, `createFlameNozzle`, `createDivineBeam`
- Removed dead detail methods: `addDivineParticles`, `addHazardStripes`, `addDivineRays`
- Removed dead glow methods: `createOuterGlow`, `createMidGlow`, `createCoreGlow` (collapsed to single glow, never called)
- Removed idle animations: `startMagicIdleAnimation`, `startPyroIdleAnimation`, `startHeatShimmer`, `startLegendaryIdleAnimation`, `startDivineParticleEmission`
- Removed combat: `playPyroMuzzleFlash`, `playLegendarySpecialEffect` + reference in TDGameScene+EntityVisuals
- Removed dead animation keys: `divineParticles`, `flameFlicker`, `runeOrbit`
- Cleaned old protocol ID aliases from mapper (`bow`, `crossbow`, `cannon`, `bomb`, `snowflake`, `laser`, `lightning`, etc.)
- Removed `ParticleFactory.enforceParticleLimit()`, `BossRenderingManager.bossMechanicFrameCounter`, `MegaBoardRenderer.update()`/`noisePhase`/`pulsePhase`
- Note: Kept `RarityTier.legendary` and rarity ring logic (legendary rarity still exists, only the archetype is dead)

**Actual removal: ~570 lines of dead code across 12 files. Build verified clean.**

---

## Stage 2: Bug Fixes (Correctness) -- DONE

Fixed 14 rendering bugs that caused incorrect visuals, wasted CPU, or potential crashes.

**Changes made:**
- **2a**: Replaced ~24 no-op `glowWidth = 0` toggles with actual `fadeAlpha` animations across all 7 tower archetypes (projectile, frost, beam, tesla, multishot, execute) — towers now visually pulse as intended
- **2b**: Replaced `DispatchQueue.main.asyncAfter` with pure SKAction sequence in Execute tower glitch animation — prevents unsafe mutations during scene pause/dealloc
- **2c**: Fixed star indicator lookup from `"stars"` to `"starIndicator"` — merge star pulse animation now runs
- **2d**: Replaced 67-line duplicate Void Harbinger instance method with delegation to shared static composition — fixes incorrect whole-container rotation (eye/pupil now stay still, only fragments orbit)
- **2e**: Removed `chassis.name = "body"` overwrite in Cyberboss composition — chassis keeps its name, refs dict provides "body" key for hit detection lookup
- **2f**: Moved 6 ambient sector particle spawn points from `particleLayer` (z=7) to `backgroundLayer` (z=0) — GPU heat shimmer, RAM pulses, network rings, cache speed lines, CPU pulses/heartbeat now render behind gameplay
- **2g**: Normalized CameraController inertia friction to `pow(friction, dt * 60)` — consistent deceleration regardless of frame rate
- **2h**: Deferred `currentScale` updates in `reset()` and `animateTo()` to action completion callbacks — prevents stale scale during animated transitions
- **2i**: Changed artillery idle animation from nonexistent `"capacitors"` to actual `"bolts"` node — bolt pulse now fires
- **2j**: Replaced static `CGFloat.random` in Cyberboss phase jitter with `SKAction.customAction` — jitter now randomizes per tick instead of repeating one frozen offset
- **2k**: Deferred chainsaw dictionary key removal until after fade-out completes — prevents duplicate node creation during 0.3s fade
- **2l**: Unified NodePool enemy type key from `"enemy_\(type)"` (acquire) to `"enemy"` (matching releaseInactive) — fixes pool bucket mismatch and negative inUseCount
- **2m**: Applied dashed `UIBezierPath` to range ring `SKShapeNode` via `path:` init — dashed ring now renders instead of being silently discarded
- **2n**: Added `TDGameScene.resetCaches()` called from `EmbeddedTDGameController.reset()` — clears static `cachedCooldownProgress` on scene teardown

**Files changed: 9 files across Rendering/ and UI/Tabs/. Build verified clean.**

---

### 2a. Fix glowWidth no-op animations (ALL tower types)

Every tower type has pulse animations that set `glowWidth = 0` in both on/off states. Replace each with `SKAction.fadeAlpha` or `fillColor` cycling, then remove the dead `glowWidth` blocks.

**Affected files:**
- `Rendering/TowerAnimations+Idle.swift` -- 9 tower types, ~24 individual no-op sequences

**Approach:** For each dead `glowWidth` toggle, replace with:
```swift
// Before (dead):
SKAction.run { node.glowWidth = 0 }
// After (alive):
SKAction.fadeAlpha(to: 0.6, duration: 0.5)  // or scale/color pulse
```

### 2b. Fix DispatchQueue in Execute tower glitch animation

Replace `DispatchQueue.main.asyncAfter` with pure SKAction-based timing to prevent unsafe mutations during scene pause/dealloc.

**File:** `Rendering/TowerAnimations+Idle.swift:714-716`

### 2c. Fix merge star indicator name mismatch

Change search from `"stars"` to `"starIndicator"` so the star pulse animation actually runs.

**File:** `Rendering/TowerAnimations+Idle.swift:757`

### 2d. Fix Void Harbinger dual implementation

Remove the boss-mode version in `EntityRenderer.swift:95-161` that incorrectly rotates the entire container (including eye/pupil). Have boss-mode call the TD static method or a shared helper.

**Files:**
- `Rendering/EntityRenderer.swift` -- Remove/redirect VH instance method
- `Rendering/EntityRenderer+BossDetails.swift` -- Ensure the static method works for both contexts

### 2e. Fix Cyberboss chassis naming

Remove the name overwrite from `"chassis"` to `"body"` or update the refs dictionary key.

**File:** `Rendering/EntityRenderer+BossDetails.swift:52,138`

### 2f. Fix ambient particle z-ordering

Move ambient sector particles from `particleLayer` (z=7, effective z=4.3) to `backgroundLayer` so they render behind gameplay elements.

**File:** `Rendering/TDGameScene+SectorAmbient.swift` -- Change parent from `particleLayer` to `backgroundLayer` (or a new `ambientLayer`)

### 2g. Fix CameraController frame-rate dependent friction

Normalize inertia: `velocity.x *= pow(friction, CGFloat(deltaTime) * 60)`.

**File:** `Rendering/CameraController.swift:273`

### 2h. Fix CameraController premature currentScale

Track `currentScale` via action completion callback instead of setting it immediately.

**File:** `Rendering/CameraController.swift:287,301`

### 2i. Fix artillery idle animating nonexistent capacitors

Change to animate `"bolts"` or remove the dead animation block.

**File:** `Rendering/TowerAnimations+Idle.swift:138-146`

### 2j. Fix boss phase jitter being static

Replace `CGFloat.random` captured once with `SKAction.customAction` for per-tick randomization.

**File:** `Rendering/BossRenderingManager.swift:403-413`

### 2k. Fix chainsaw node leak during fade-out

Delay dictionary key removal until after fade-out completes, or check for existing node before creating new one.

**File:** `Rendering/BossRenderingManager.swift:491-498`

### 2l. Fix NodePool type key mismatch

Use consistent type keys between acquire (`"enemy_{type}"`) and releaseInactive (`"enemy"`).

**File:** `Rendering/NodePool.swift`

### 2m. Fix dashed range ring path never applied

Either apply the `UIBezierPath` to the shape node or remove the dead path creation.

**File:** `Rendering/TowerVisualFactory+Indicators.swift:77-80`

### 2n. Clean up static cachedCooldownProgress on scene teardown

Add a `static func resetCache()` called from scene's `willMove(from:)`.

**File:** `Rendering/TDGameScene+EntityVisuals.swift:279`

---

## Stage 3: Visual Polish (Quality) -- DONE

Visual quality improvements across boss effects, enemy detail, particles, beam towers, camera shake, and execute effects.

**Changes made:**
- **3a**: Restored `glowWidth` on boss lasers (4), energy lines (2), active void zones (2), gravity well cores (4). Added `.add` blending to lasers and energy lines. Kept puddles/chainsaw/pylons/shield/arrows/rifts/arena at 0.
- **3b**: Added `.easeInEaseOut` timing to all 7 cached pulse actions (puddle, void zone, pylon crystal, arena boundary, chainsaw danger, laser flicker) and 4 inline pulses (shield, pylon line, hint label, arrow).
- **3c**: Basic virus: added 3 curved flagella tendrils (compound path, 1 node) making rotation visible. Fast virus: added bright core dot. Tank: added horizontal armor seam line. Elite: randomized vertex jitter per-instance (was alternating fixed pattern).
- **3d**: Overclocker heat gauge arc now grows per phase (~180° → ~225° → ~270° → ~315°) via CGPath rebuild. Cyberboss LED colors were already connected in Stage 2.
- **3e**: Added `wyrmHeadHistory` position buffer (spacing=3 frames) for smooth snake-like trailing. Body segments position at historical head positions instead of game-state positions. History clears on Phase 3 transition and cleanup.
- **3f**: Explosion cap raised from 4 to 8 per burst. Explosion lifetime increased (0.5–1.0s from 0.3–0.8s). Blood lifetime increased (0.4–0.7s from 0.2–0.4s) with downward velocity bias (-40). Trail spawn chance raised from 10% to 25%, lifetime from 0.15s to 0.3s.
- **3g**: Added `TowerAnimations.playBeamLine()` — sustained beam flash from barrel tip in facing direction with `glowWidth=3`, `.add` blending, 0.2s fade-out. Triggered on beam tower fire.
- **3h**: Added `CameraController.shake(intensity:duration:)` with decaying random offsets (matching boss-mode GameScene pattern) for TD mode use.
- **3i**: Added 30% probability gate to execute tower glitch effect to match legendary pattern.

**Files changed: 6 files across Rendering/. Build verified clean.**

---

Improvements that upgrade the visual quality toward AAA code-only rendering.

### 3a. Restore boss glow and blending

Selectively re-enable `glowWidth` on boss lasers (3-5), energy lines (2-3), void zones (2), gravity well cores (4). Add `.add` blending mode to energy/laser/explosion effects.

**File:** `Rendering/BossRenderingManager.swift` (16 occurrences of `glowWidth = 0`)

### 3b. Add easing to boss pulse animations

Replace default linear timing with `.easeInEaseOut` on all boss pulse actions.

**File:** `Rendering/BossRenderingManager.swift`

### 3c. Improve enemy visual variety

- **Basic virus:** Add 2-3 flagella tendrils (compound path) so rotation is visible, or remove the invisible rotation
- **Fast virus:** Add a core dot or speed line (1 extra node)
- **Tank:** Increase breathing scale from 3% to 6%, add armor seam line
- **Elite:** Randomize vertex jitter per-instance, add faint glitch offset overlay
- **Void minions:** Add float/bob animation (+/-2px, 1s cycle)

**Files:** `Rendering/EntityRenderer+EnemyDetails.swift`, `Rendering/TDGameScene+EntityVisuals.swift`

### 3d. Connect boss visuals to gameplay state

- Overclocker: Animate heat gauge arc length based on health/phase
- Cyberboss: Change LED colors (green > yellow > red) as health decreases
- Cyberboss: Eye scanner could track nearest tower position

**File:** `Rendering/BossRenderingManager.swift`, `Rendering/EntityRenderer+BossDetails.swift`

### 3e. Improve Trojan Wyrm segment trailing

Store head's last N positions and position each body segment at a historical position for snake-like trailing motion.

**File:** `Rendering/BossRenderingManager.swift` (Wyrm section)

### 3f. Increase particle visibility

- Increase explosion count cap from 4 to 8-12
- Increase lifetimes by 2-3x
- Add scale-down over lifetime (`SKAction.scale`)
- Add gravity to blood particles (downward velocity bias)
- Increase trail spawn chance from 10% to 30%

**File:** `Rendering/ParticleFactory.swift`

### 3g. Add beam tower continuous beam visual

Add a sustained beam line from barrel tip to target during firing, instead of discrete muzzle flash only.

**Files:** `Rendering/TowerAnimations+Combat.swift`, `Rendering/TDGameScene+EntityVisuals.swift`

### 3h. Add screen shake to CameraController

Add `shake(intensity:duration:)` method. Trigger on boss phase transitions, major hits, tower destruction.

**File:** `Rendering/CameraController.swift`

### 3i. Add execute tower effect probability gate

Add 25-33% chance gate (matching legendary pattern) instead of firing every shot.

**File:** `Rendering/TDGameScene+EntityVisuals.swift:245`

---

## Stage 4: Performance (Optimization) -- DONE

Six performance optimizations reducing per-frame allocations, CPU waste, and scene graph overhead.

**Changes made:**
- **4a**: Cached enemy CGPaths (flagella, chevron, bolts, seam, crosshair) as static properties keyed by size — eliminates per-enemy path allocation for basic, fast, tank, and elite virus compositions
- **4b**: Added `currentCameraScale < 0.5` guard before artillery smoke ring and particle spawning — skips 4-6 invisible node allocations per shot when zoomed out
- **4c**: Added `bakeSectorComponentsToSprite()` utility in SectorFoundation — bakes static sector IC components (15-25 SKShapeNodes) into a single sprite texture for all non-PSU sectors, with graceful fallback to shape nodes if view is unavailable
- **4d**: Extracted 7 duplicated `isNearLane` closures into a single `static func TDGameScene.isNearLane()` shared across SectorComponents, PSUComponents, and CPUComponents (25 lines removed, ~40 call sites updated)
- **4e**: Replaced per-flash `SKShapeNode` allocation in Tesla tower electric arcs with a pool of 3 reusable arc nodes per tower — updates path and alpha instead of create/remove cycle
- **4f**: Added `NodePool.prewarm(type:count:creator:)` for loading-screen pre-allocation, child cleanup on acquire (strips unnamed/temp_ children), and guard against negative `inUseCount` on double-release

**Files changed: 8 files across Rendering/. Build verified clean.**

---

### 4a. Cache enemy CGPaths as static properties

Paths identical across all instances of a type (fast virus chevron, tank bolts, etc.) should be computed once.

**File:** `Rendering/EntityRenderer+EnemyDetails.swift`

### 4b. Camera-gate artillery muzzle smoke

Add `guard TowerAnimations.currentCameraScale < 0.5` check before spawning smoke particles.

**File:** `Rendering/TowerAnimations+Combat.swift`

### 4c. Convert static sector decorations to sprite textures

Use `SKView.texture(from:)` to bake each sector's IC components (15-25 SKShapeNode batches) into 1-2 sprite textures.

**File:** `Rendering/TDGameScene+SectorComponents.swift`

### 4d. Extract and share isNearLane utility

Replace 7+ duplicated closures with a shared function that derives exclusion zones from actual lane waypoint data.

**Files:** `Rendering/TDGameScene+SectorComponents.swift`, `Rendering/TDGameScene+CPUComponents.swift`

### 4e. Pool Tesla electric arc nodes

Replace per-flash `SKShapeNode` allocation with a pool of 2-3 reusable arc nodes.

**File:** `Rendering/TowerAnimations+Idle.swift` (Tesla section)

### 4f. Add NodePool pre-warming and child cleanup

- Add `prewarm(type:count:creator:)` for loading screens
- Reset children on acquire or add `prepareForReuse` callback
- Guard against negative `inUseCount`

**File:** `Rendering/NodePool.swift`

---

## Stage 5: Architecture (Structure) -- DONE

Split oversized files, added type-safe pool keys, standardized boss node lifecycle, renamed archetypes.

**Changes made:**
- **5a**: Split `BossRenderingManager.swift` (1,608 → ~223 lines) into shared base + 4 boss extensions: `+Cyberboss` (~295), `+VoidHarbinger` (~530), `+Overclocker` (~280), `+TrojanWyrm` (~280)
- **5a**: Split `TDGameScene+EntityVisuals.swift` (1,390 → ~235 lines) into base (damage events, projectiles, core) + 3 extensions: `+TowerVisuals` (~340), `+EnemyVisuals` (~490), `+LODAndCulling` (~250)
- **5b**: Added `NodePoolType` enum with 13 type-safe cases (enemy, projectile, tdProjectile, pickup, particle, bossPuddle, bossLaser, bossZone, bossPylon, bossRift, bossWell, bossMisc). Updated all pool acquire/release/releaseInactive callers. Removed dead `acquireBossMechanicNode`/`releaseBossMechanicNodes` helpers. Fixed pickup/particle pooling mismatch (acquire/release now use same key).
- **5c**: Added `removeBossNode(key:)` helper and `poolTypeForKey(_:)` to BossRenderingManager. Replaced all 15 `removeFromParent()` + `removeValue(forKey:)` patterns in boss extensions with `removeBossNode(key:)`. Updated `cleanup()` to release through pool.
- **5d**: Renamed `TowerArchetype` enum cases to match cybersecurity theme: `projectile`→`scanner`, `artillery`→`payload`, `frost`→`cryowall`, `beam`→`rootkit`, `tesla`→`overload`, `multishot`→`forkbomb`, `execute`→`exception`. Updated all 7 switch statements across 6 files. Dead cases `magic`/`pyro`/`legendary` were already absent.

---

## Stage 6: Boss Damage & Death Feedback -- DONE

Added boss hit feedback, death explosion, and removed dead VisualEffects code.

**Changes made:**
- **6a**: Added `lastKnownBossHealth` tracking in `BossRenderingManager.renderFrame()` — detects per-frame health decrease and triggers cached `damageFlashAction` (alpha 1.0→0.4→1.0, 0.15s) on the boss body node via `withKey: "damageFlash"`
- **6b**: Added `triggerBossDeathEffects()` in `GameScene+BossRendering` — fires 16-particle explosion in boss theme color (#00ffff cyan / #ff00ff magenta / #ff6600 orange / #00ff41 lime), screen flash (0.25 alpha, 0.3s), screen shake (intensity 8, 0.35s), and boss node scale-up (1.3x) + fade-out before cleanup. Raised `ParticleFactory.createExplosion()` per-call cap from 8 to 16.
- **6c**: Removed `VisualEffects.swift` entirely (~387 lines) — `VisualEffects` singleton (screen shake/flash/slow-mo/hitstop), 7 dead `ParticleFactory` extension methods (`createLevelUpEffect`, `createVictoryConfetti`, `createLegendaryExplosion`, `createPlayerDeathEffect`, `createFireParticles`, `createIceParticles`, `createLightningParticles`), and unused `DamageNumber`/`DamageNumberManager` types. All were self-referencing dead code with zero external callers.

**Files changed: 4 files (BossRenderingManager.swift, GameScene+BossRendering.swift, ParticleFactory.swift, project.pbxproj) + 1 file removed (VisualEffects.swift). Build verified clean.**

---

The biggest boss fight visual gap: bosses give zero feedback when hit and have no death animation.

### 6a. Boss damage flash on hit

**Problem:** Boss body maintains steady visual state when taking damage. Player can't confirm hits are registering.

**Fix:** When boss takes damage, briefly flash the boss body node.

```swift
// In BossRenderingManager, on damage event:
let flash = SKAction.sequence([
    SKAction.fadeAlpha(to: 0.4, duration: 0.06),
    SKAction.fadeAlpha(to: 1.0, duration: 0.09)
])
bossBodyNode.run(flash, withKey: "damageFlash")
```

**Trigger:** Hook into damage events in `renderFrame()` — check if boss health decreased since last frame.

**Files:**
- `Rendering/BossRenderingManager.swift` (or per-boss extension after 5a split) — add damage flash logic
- Store `lastKnownBossHealth` to detect health decreases

**Perf cost:** 1 alpha tween per hit (not per frame). Negligible.

### 6b. Boss death explosion

**Problem:** Boss vanishes instantly when health reaches 0. No payoff for winning the fight. `ParticleFactory.createExplosion()` exists but is never called for boss death. `VisualEffects.createLegendaryExplosion()` exists as dead code.

**Fix:** On boss death:
1. Spawn boss-colored particle burst (12-16 particles)
2. Fire screen flash (`ParticleEffectService.flashOverlay()`)
3. Fire screen shake (`ParticleEffectService.triggerScreenShake()`)
4. Optional: 0.3s scale-up (boss node 1.0 -> 1.2) before removal for visual "burst"

**Boss-specific particle colors:**
- Cyberboss: Cyan (#00ffff)
- Void Harbinger: Magenta (#ff00ff)
- Overclocker: Orange (#ff6600)
- Trojan Wyrm: Lime (#00ff41)

**Files:**
- `Rendering/BossRenderingManager.swift` — add death sequence before node removal
- `Rendering/ParticleFactory.swift` — may need to increase count cap for boss death (currently 4 max per call)
- `Rendering/ParticleEffectService.swift` — already has flash/shake methods

**Perf cost:** One-time event. 12-16 particles + 1 flash + 1 shake. Well within limits.

### 6c. Wire up or remove dead VisualEffects functions

**Problem:** 6 elaborate effect functions in `VisualEffects.swift` are never called anywhere:
- `createLegendaryExplosion()` (100 + 50 particles)
- `createVictoryConfetti()` (50 particles)
- `createPlayerDeathEffect()` (60 + 20 particles)
- `createFireParticles()`, `createIceParticles()`, `createLightningParticles()`

**Decision needed:** Either wire these into appropriate game events or remove as dead code.

**Recommendation:**
- Wire `createLegendaryExplosion()` into boss death (from 6b) — but reduce particle counts to stay within budget
- Wire `createPlayerDeathEffect()` into player death in boss mode
- Remove the rest (element-specific particles have no current use case)

**Files:**
- `Rendering/VisualEffects.swift` — remove unused functions or adapt
- `Rendering/BossRenderingManager.swift` or `GameScene.swift` — wire up retained functions

---

## Stage 7: Phase Transition Polish -- DONE

Phase transition effects, indicator polish, and health bar animation for all 4 bosses.

**Changes made:**
- **7a**: Added phase transition detection via `lastIndicatorPhase` dict in `renderPhaseIndicator()`. On phase change: boss body scale pulse (1.0→1.15→1.0, 0.4s easeInEaseOut), screen flash in boss theme color (cyan/magenta/orange/green, 0.15 alpha, 0.2s), screen shake (intensity 6, 0.3s), and SCT dramatic text ("PHASE X") at boss position. Added `triggerPhaseTransitionEffects()` helper.
- **7b**: Rewrote `renderPhaseIndicator()` — phase label now has glow layer behind it (1.2x scale, 0.4 alpha), color-coded per phase (green→yellow→orange→red), fades in on creation/transition (0→1.0, 0.3s), auto-fades out after 3s (1.0→0, 0.5s). Container-based node replaces bare SKLabelNode.
- **7c**: Added `.animation(.easeOut(duration: 0.25))` to boss health bar width for smooth transitions. Added phase tick marks at 75%, 50%, 25% as thin white lines. Added red flash overlay on large damage spikes (>10% max HP) via `showBossHealthFlash` state and `triggerBossHealthFlash()` helper.
- **Fix**: Added missing `renderPhaseIndicator()` calls to Overclocker and TrojanWyrm boss extensions (were only called for Cyberboss and Void Harbinger).
- **Fix**: Added `config` parameter to `ScrollingCombatText.show()` for dramatic preset usage.

**Files changed: 5 files (BossRenderingManager.swift, +Overclocker, +TrojanWyrm, ScrollingCombatText.swift, GameContainerView.swift). Build verified clean.**

---

Phase changes are the dramatic peaks of a boss fight but currently happen silently.

### 7a. Phase transition visual effects

**Problem:** Phase indicator label just updates text. No animation, no drama. Players miss that a phase change happened.

**Fix:** On phase change:
1. Boss node scale pulse: 1.0 -> 1.15 -> 1.0 over 0.4s (easeInEaseOut)
2. Screen flash in boss theme color (0.15 alpha, 0.2s)
3. Screen shake (intensity 6, 0.3s)
4. SCT dramatic text: "PHASE 2" / "SHIELDS ACTIVE" / "OVERHEATING" etc.

```swift
// On phase change detection:
let phasePulse = SKAction.sequence([
    SKAction.scale(to: 1.15, duration: 0.2),
    SKAction.scale(to: 1.0, duration: 0.2)
])
phasePulse.timingMode = .easeInEaseOut
bossNode.run(phasePulse, withKey: "phaseTransition")
particleEffectService?.flashOverlay(color: bossThemeColor, alpha: 0.15, duration: 0.2)
particleEffectService?.triggerScreenShake(intensity: 6, duration: 0.3)
```

**Files:**
- `Rendering/BossRenderingManager.swift` — detect phase changes (compare cached phase), trigger effects
- `Rendering/ScrollingCombatText.swift` — already has `.dramatic` preset, just needs to be called

**Perf cost:** One-time per phase transition. 1 scale action + 1 flash + 1 shake.

### 7b. Phase indicator improvements

**Problem:** Phase label is permanent (never fades), uses plain text, no emphasis.

**Fix:**
- Fade in on phase change (0 -> 1.0 alpha over 0.3s)
- Auto-fade out after 3 seconds (1.0 -> 0 alpha over 0.5s)
- Add glow layer behind label (same technique as SCT glow)
- Color-code per phase: Phase 1 green, Phase 2 yellow, Phase 3 orange, Phase 4 red

**Files:**
- `Rendering/BossRenderingManager.swift` — `renderPhaseIndicator()` method

### 7c. Boss health bar animation

**Problem:** SwiftUI health bar width snaps instantly on damage. Large hits feel invisible.

**Fix:**
- Add `.animation(.easeOut(duration: 0.25), value: healthPercent)` to bar width
- Add red flash overlay on large damage spikes (>10% max HP)
- Consider adding phase tick marks on the health bar (vertical lines at 75%, 50%, 25%)

**Files:**
- `UI/Game/GameContainerView.swift` — boss health bar section (~line 176)

**Perf cost:** SwiftUI animation modifier. Negligible.

---

## Stage 8: Mechanic Spawn/Despawn Animations

All boss mechanics (puddles, zones, pylons, rifts, tiles, etc.) pop in and out instantly. This breaks immersion and makes mechanics feel cheap.

### 8a. Standardize fade-in for all spawning mechanics

**Problem:** Every boss mechanic node appears at full opacity/scale on frame 1.

**Fix:** On first creation of any mechanic node, start at alpha 0 and fade in:
```swift
node.alpha = 0
node.run(SKAction.fadeAlpha(to: targetAlpha, duration: 0.15))
```

Apply to: puddles, zones, pylons, rifts, gravity wells, blades, lava tiles, steam segments, shredder ring, aim line, arena boundary.

**Implementation:** Add a helper method `fadeInMechanicNode(_ node:, targetAlpha:, duration: 0.15)` in BossRenderingManager.

**Files:**
- `Rendering/BossRenderingManager.swift` — all `addChild` / first-creation points for mechanic nodes

**Perf cost:** 1 alpha tween per spawn event. Negligible.

### 8b. Standardize fade-out for all despawning mechanics

**Problem:** Most mechanic nodes vanish instantly. Only chainsaw has a proper 0.3s fade-out.

**Fix:** Before removing any mechanic node, run fade-out:
```swift
node.run(SKAction.sequence([
    SKAction.group([
        SKAction.fadeOut(withDuration: 0.2),
        SKAction.scale(to: 0.85, duration: 0.2)
    ]),
    SKAction.removeFromParent()
]))
```

Apply to: puddles, zones, pylons (on destruction), rifts, gravity wells, blades, lava tiles, steam segments, sub-worms, shredder ring, arena boundary.

**Important:** For pooled nodes, fade out a copy or reset alpha after pool release.

**Files:**
- `Rendering/BossRenderingManager.swift` — all `removeFromParent()` / pool release points

### 8c. Pylon destruction burst

**Problem:** Void Harbinger pylons simply vanish when destroyed. This is the key shield-breaking mechanic — it should feel rewarding.

**Fix:** On pylon death:
1. 15-20 purple particles radiating outward from pylon position
2. Small screen shake (intensity 4, 0.2s)
3. Energy lines from pylon to boss should snap/flash before disappearing
4. SCT text: "SHIELD DOWN" or similar at pylon position

**Files:**
- `Rendering/BossRenderingManager+VoidHarbinger.swift` — pylon rendering section
- `Rendering/ParticleFactory.swift` — explosion with purple color

### 8d. Puddle pop burst

**Problem:** Cyberboss damage puddles silently disappear at end of lifetime. The "pop" damage spike has no visual.

**Fix:** At puddle expiry (last 0.1s of lifetime):
1. Brief scale pulse (1.0 -> 1.3) over 0.1s
2. 6-8 red particles radiating outward
3. Flash the puddle circle bright red (alpha 0.8) before removal

**Files:**
- `Rendering/BossRenderingManager+Cyberboss.swift` — puddle rendering section

### 8e. Lava tile state transitions

**Problem:** Overclocker lava tiles change color instantly between states (normal/warning/lava/safe). No transition animation.

**Fix:** On state change:
1. Brief scale pulse (1.0 -> 1.05 -> 1.0 over 0.2s)
2. Color change via 0.15s fade (old color fades, new color fades in)
3. For warning->lava: add quick red flash

**Files:**
- `Rendering/BossRenderingManager+Overclocker.swift` — lava tile section

### 8f. Sub-worm phase transition

**Problem:** Trojan Wyrm sub-worms vanish instantly at Phase 3->4 transition.

**Fix:** On Phase 3 end:
1. Each sub-worm fades out over 0.3s
2. Small green particle burst (8 particles) at each sub-worm head position
3. Stagger the despawns by 0.1s each for cascade effect

**Files:**
- `Rendering/BossRenderingManager+TrojanWyrm.swift` — sub-worm section

---

## Stage 9: Arena Differentiation

All 4 bosses fight in identical arenas. Easy visual wins with near-zero perf cost.

### 9a. Boss-specific arena color themes

**Problem:** All arenas use the same dark background (#0a0a0f) and green grid (#00ff41 at 8% opacity).

**Fix:** Set grid color and background tint based on boss type at arena setup:

| Boss | Grid Color | Grid Opacity | Background |
|------|-----------|-------------|------------|
| Cyberboss | Cyan (#00ffff) | 8% | #0a0a1a |
| Void Harbinger | Magenta (#ff00ff) | 6% | #0a000f |
| Overclocker | Orange (#ff8800) | 8% | #0f0a05 |
| Trojan Wyrm | Lime (#00ff41) | 8% | #050a05 |

**Files:**
- `Rendering/GameScene.swift` — `setupBackground()` method, parameterize colors based on boss type

**Perf cost:** Zero ongoing. Setup-time color change only.

### 9b. Pillar visual escalation per phase

**Problem:** Gray pillars look the same throughout the entire fight regardless of phase intensity.

**Fix:** On phase change, update pillar fill/stroke color to match escalation:
- Phase 1: Default gray (#4a5568)
- Phase 2: Slightly tinted with boss theme color (10% blend)
- Phase 3: More tinted (25% blend), add subtle glow (glowWidth 2)
- Phase 4: Strongly tinted (40% blend), glowWidth 4

**Files:**
- `Rendering/GameScene+EntityRendering.swift` — pillar rendering section

**Perf cost:** 1 color update per pillar (8 total) per phase change. Negligible.

### 9c. Arena vignette overlay

**Problem:** Arena feels flat. No sense of enclosure or escalating danger.

**Fix:** Add a semi-transparent radial gradient overlay (dark edges, clear center):
- 1 SKShapeNode rectangle with radial gradient fill (or 4 edge rectangles with linear gradients)
- Alpha increases per phase: Phase 1 (0.1), Phase 2 (0.15), Phase 3 (0.2), Phase 4 (0.3)
- Creates sense of the arena "closing in" as danger increases

**Files:**
- `Rendering/GameScene.swift` — add vignette node in `setupBackground()`, update alpha on phase change

**Perf cost:** 1 static node (or 4 edge nodes). No per-frame updates except alpha on phase change.

---

## Stage 10: Pickup & Projectile Clarity

### 10a. Replace health pickup emoji with geometric shape

**Problem:** Health pickup uses system emoji `♥` which is visually inconsistent with the geometric art style. Rendering varies by device.

**Fix:** Replace with a geometric heart path (or a red cross/plus for med-kit theme):
```swift
// Red plus/cross shape matching cybersecurity theme
let crossPath = CGMutablePath()
crossPath.addRect(CGRect(x: -2, y: -6, width: 4, height: 12))
crossPath.addRect(CGRect(x: -6, y: -2, width: 12, height: 4))
```

**Files:**
- `Rendering/EntityRenderer.swift` — `createPickupNode()` (~line 302)

### 10b. Add pickup animations

**Problem:** All pickups are static. They sit on the ground with no visual draw.

**Fix:**
- Hash (hexagon): slow rotation (4s/cycle) + gentle vertical bob (±3pt, 2s/cycle)
- Health: pulse scale (1.0 -> 1.15 -> 1.0, 1.5s/cycle)
- XP orb: bob (±2pt, 1.5s/cycle) + increase radius from 5 to 8pt

```swift
// Generic pickup bob animation:
let bob = SKAction.sequence([
    SKAction.moveBy(x: 0, y: 3, duration: 1.0),
    SKAction.moveBy(x: 0, y: -3, duration: 1.0)
])
bob.timingMode = .easeInEaseOut
node.run(SKAction.repeatForever(bob))
```

**Files:**
- `Rendering/EntityRenderer.swift` — `createPickupNode()`
- Or apply in `GameScene+EntityRendering.swift` after node creation

**Perf cost:** 1 repeating SKAction per active pickup. Pickups are few (typically 1-5 on screen).

### 10c. Projectile source distinction

**Problem:** Player and enemy projectiles look identical. Players can't quickly distinguish incoming threats from outgoing fire.

**Fix:** Tint enemy projectiles slightly toward red/dark, keep player projectiles bright:
```swift
// For enemy-sourced projectiles:
if projectile.isEnemyProjectile {
    body.fillColor = color.blended(withFraction: 0.3, of: .red)
    body.strokeColor = SKColor.red.withAlphaComponent(0.6)
}
```

**Files:**
- `Rendering/EntityRenderer.swift` — `createProjectileNode()`

**Perf cost:** 1 color blend at creation time. Zero ongoing.

---

## Stage 11: Boss Minor Polish & Cleanup

### 11a. Void rift animation

**Problem:** Rifts are static lines with no animation or visual energy.

**Fix:** Add subtle alpha oscillation (0.5 -> 1.0, 0.8s cycle) and/or line width pulse (3 -> 5, 1s cycle).

**Files:**
- `Rendering/BossRenderingManager+VoidHarbinger.swift` — rift rendering

### 11b. Gravity well pull visual

**Problem:** Gravity wells rotate but have no visual indication of the pull force.

**Fix:** Add 3-4 small particles that spawn at the well edge and animate inward toward center over 0.5s, then respawn. Creates visual "suction" effect.

**Files:**
- `Rendering/BossRenderingManager+VoidHarbinger.swift` — gravity well rendering

**Perf cost:** 3-4 particles per gravity well, recycled on 0.5s cycle. Low.

### 11c. Steam trail fade-in/out

**Problem:** Overclocker steam trail segments appear/disappear harshly.

**Fix:** New segments start at alpha 0 and fade in (0.1s). Oldest segment fades out (0.2s) before removal.

**Files:**
- `Rendering/BossRenderingManager+Overclocker.swift` — steam trail section

### 11d. Destroyed pillar node cleanup

**Problem:** Destroyed pillars set alpha to 0 but remain in scene graph as invisible nodes.

**Fix:** After destruction animation completes, remove pillar node from scene entirely and clean up from tracking dictionaries.

**Files:**
- `Rendering/GameScene+EntityRendering.swift` — pillar rendering/destruction

### 11e. SCT AoE clustering mitigation

**Problem:** When 10+ damage events fire simultaneously (AoE), text nodes cluster and overlap despite 50ms stagger.

**Fix:** Add spatial jitter: random ±20px horizontal offset per text in batch. Already has ±15px but may need increase for large batches. Consider throttling to max 5 visible per burst (show largest hit + total as single text).

**Files:**
- `Rendering/ScrollingCombatText.swift` — `showDamageBatch()`

### 11f. CGPath caching for rift hot loops

**Problem:** Void rift paths are recreated via `CGMutablePath()` every frame even when coordinates haven't changed.

**Fix:** Cache last path per rift. Only recreate if rift start/end positions changed since last frame.

**Files:**
- `Rendering/BossRenderingManager+VoidHarbinger.swift` — rift rendering loop

### 11g. Raise particle cap for boss fights

**Problem:** Boss mode particle cap is 80. Boss death explosion (12-16) + active combat hits can overflow, causing FIFO truncation of ongoing effects.

**Fix:** Increase boss mode cap from 80 to 150 (TD mode already allows 500).

**Files:**
- `Rendering/ParticleFactory.swift` — `maxParticles` / `canAddParticles()`
- Alternatively: `Core/Config/BalanceConfig.swift` if the cap is defined there

---

## Priority Order

Recommended execution order for maximum value per effort:

**Board/TD View (Stages 1-5):**

1. **Stage 1** (dead code removal) -- Quick wins, reduces noise for all later work
2. **Stage 2a-2c** (tower animation fixes) -- Biggest visual impact
3. **Stage 2d-2f** (enemy + z-ordering fixes) -- Correctness
4. **Stage 3f** (particle visibility) -- Low effort, high visual impact
5. **Stage 3a-3b** (boss glow + easing) -- Makes boss fights feel premium
6. **Stage 2g-2h** (camera fixes) -- Consistent feel
7. **Stage 3c** (enemy variety) -- Visual polish
8. **Stage 2i-2n** (remaining bug fixes) -- Correctness sweep
9. **Stage 3d-3i** (remaining polish) -- AAA quality push
10. **Stage 4** (performance) -- Optimization pass
11. **Stage 5** (architecture) -- Split BossRenderingManager + structure cleanup

**Boss Fight Polish (Stages 6-11) — after Stages 1-5 are complete:**

12. **Stage 6a-6b** (damage flash + death explosion) -- Highest-impact boss fight gap
13. **Stage 7a-7b** (phase transition effects + indicator) -- Dramatic peaks
14. **Stage 8a-8d** (spawn/despawn fades + pylon/puddle bursts) -- Mechanic polish
15. **Stage 9a-9c** (arena themes + pillars + vignette) -- Visual variety
16. **Stage 7c** (health bar animation) -- UI polish
17. **Stage 10a-10c** (pickups + projectiles) -- Clarity
18. **Stage 8e-8f** (lava tiles + sub-worms) -- Per-boss polish
19. **Stage 11a-11g** (minor polish + perf) -- Final pass
20. **Stage 6c** (dead VisualEffects decision) -- After 6b is working, decide what to keep
