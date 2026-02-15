# Boss Fight Fix Stages

## Trigger Prompt

Paste this to start the next open stage:

> Read `BOSS_FIX_STAGES.md` and find the next stage that is NOT marked `[DONE]`. Enter plan mode. Explore the relevant files, develop a plan to fix all issues listed in that stage, then implement the fixes. After implementation, build the project with `xcodebuild -scheme SystemReboot -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20`. If the build succeeds, update `BOSS_FIX_STAGES.md` to mark the stage as `[DONE]`, add a one-line summary of what changed under the stage heading, and commit all changes with a descriptive message. If the build fails, fix the errors before committing.

---

## Stage 1: Trojan Wyrm — Hardcoded Values & Sub-Worm Count Bug [DONE]

Centralized 7 categories of hardcoded values into BalanceConfig.TrojanWyrm; fixed sub-worm spawn to use dynamic count with evenly-spaced angles; widened cleanup loop to safe upper bound of 8.

**Files:** `TrojanWyrmAI.swift`, `BalanceConfig.swift`, `BossRenderingManager.swift`

- [x] **Bug: Sub-worm count ignores BalanceConfig.** `enterPhase` (line 98) hardcodes 4 sub-worms via a fixed offsets array. Change to dynamically generate `BalanceConfig.TrojanWyrm.subWormCount` sub-worms with evenly-spaced angles.
- [x] **Bug: Rendering cleanup hardcodes `for wi in 0..<4`** (BossRenderingManager.swift:1392). Use `BalanceConfig.TrojanWyrm.subWormCount` (or a safe upper bound like 8).
- [x] Move circling duration `4.0` (line 330) to `BalanceConfig.TrojanWyrm.circlingDuration`
- [x] Move lunge timeout `1.5` (line 368) to `BalanceConfig.TrojanWyrm.lungeDuration`
- [x] Move lunge bounds padding `50` (line 365) to `BalanceConfig.TrojanWyrm.lungeBoundsPadding`
- [x] Move wall margins `100` (lines 88, 89, 196, 197, 199, 203) to `BalanceConfig.TrojanWyrm.wallMargin`
- [x] Move contact detection padding `+ 20` (lines 496, 504, 520, 525, 538) to `BalanceConfig.TrojanWyrm.contactPadding`
- [x] Move turret projectile color `"#00ff44"` (line 238) to a constant or DesignColors

---

## Stage 2: Overclocker — Magic Number & Missing Phase Visuals

**Files:** `OverclockerAI.swift`, `BalanceConfig.swift`, `BossRenderingManager.swift`

- [ ] **Bug: `bossMoveSpeed * 150` magic number** (line 185). Replace with a single `BalanceConfig.Overclocker.phase2BossMoveSpeed` value that means what it says (e.g., `150`), remove the multiplication.
- [ ] Add `updateOverclockerBodyVisuals(phase:boss:gameState:)` to BossRenderingManager, matching the pattern used by Cyberboss and Void Harbinger. At minimum: phase-dependent color shifts on the boss body node, threat ring intensity changes, and a visual indicator for suction-active state.
- [ ] Call the new method from `renderOverclockerMechanics`.

---

## Stage 3: Void Harbinger — Hardcoded Values & Minion Cap

**Files:** `VoidHarbingerAI.swift`, `BalanceConfig.swift`

- [ ] Add minion cap: add `BalanceConfig.VoidHarbinger.maxMinionsOnScreen` (suggest 20), check count before spawning in `spawnVoidMinions` and `spawnEliteMinion`.
- [ ] Move pylon collision size `40` (line 142) to `BalanceConfig.VoidHarbinger.pylonSize`
- [ ] Move pylon XP `10` (line 143) to `BalanceConfig.VoidHarbinger.pylonXP`
- [ ] Move pylon color `"#aa00ff"`, minion color `"#6600aa"`, projectile color `"#8800ff"` to DesignColors or local constants with descriptive names.

---

## Stage 4: Cyberboss — Minor Cleanup

**Files:** `CyberbossAI.swift`, `BalanceConfig.swift`

- [ ] Move particle color `"#6b7280"` (line 119), count `15`, size `12` to BalanceConfig or DesignSystem constants.
- [ ] Move mode indicator colors `"#ff4444"` / `"#4444ff"` (line 214) to DesignColors constants.
- [ ] Move projectile color `"#00ffff"` (line 371) to a constant.
- [ ] Fix Phase 4 puddle interval being set every frame (line 278): move to `enterPhase4` instead.

---

## Stage 5: BossSimulator — Sync with BalanceConfig

**Files:** `BossSimulator.swift`, `BalanceConfig.swift`

- [ ] Replace `getBossBaseHealth()` (line 332) with `BalanceConfig.Cyberboss.baseHealth`, `.VoidHarbinger.baseHealth`, `.Overclocker.baseHealth`, `.TrojanWyrm.baseHealth`
- [ ] Replace all hardcoded Cyberboss sim values (mode switch 5.0, chase 1.2, volley count 5, spread 0.5, projectile speed 300, damage 25) with BalanceConfig references
- [ ] Replace all hardcoded Overclocker sim values (blade radius 180→250, blade damage 80→25, tile interval 3.0→5.0, warning 1.0→2.0, chase speed 180→160, steam interval 0.15→0.2, steam radius 40→35, suction durations 4.0/2.0→2.5/1.5, vacuum strength 80→25, shredder radius 80→140)
- [ ] Replace all hardcoded Trojan Wyrm sim values (segment spacing 45, wall margins 100, sub-worm spawn distance 200, body spacing 20/25) with BalanceConfig references
- [ ] Replace all hardcoded Void Harbinger sim values (pylon offsets, spawn counts, pylon health) with BalanceConfig references
- [ ] Verify the simulator still compiles and runs after changes

---

## Stage 6: Balance Tuning Pass

**Files:** `BalanceConfig.swift`

- [ ] **Easy→Normal cliff:** Reduce Easy player damage multiplier from 2.0 to 1.5, increase Easy boss health from 1.0 to 1.2. This narrows the gap (effective incoming goes from 0.47x→1.0x to 0.58x→1.0x).
- [ ] **Trojan Wyrm effective HP:** Reduce `bodyDamageMitigation` from 0.80 to 0.60 (40% damage passes through instead of 20%). Alternatively reduce base HP from 5500 to 4500.
- [ ] **Overclocker lava DPS:** Reduce `lavaTileDPS` from 60 to 40. Still punishing, but not 6x the Cyberboss puddle rate.
- [ ] **Phase 4 duration for VH and TW:** Change phase4Threshold from 0.10 to 0.20 so the final phase covers 20% of HP instead of 10%.
- [ ] **Void Harbinger meteor damage:** Reduce `meteorDamage` from 80 to 60. 80 DPS is the highest single-mechanic value and can one-shot on Nightmare.
- [ ] Update `tools/balance-simulator.html` if it references any changed values (check for hardcoded duplicates).

---
