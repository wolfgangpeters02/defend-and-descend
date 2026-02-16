# V1 Scope: MVP Launch — "End of Content" Implementation

## Overview

Implement a clear "end of content" boundary at **Sector 4 (Cache)** so the game has a defined finish point for V1 launch. After Cache, the player has fought all 4 unique bosses. Sectors beyond Cache show "Coming Soon" instead of unlock costs.

**MVP Content Boundary:**
- 4 playable sectors: PSU (starter) → RAM → GPU → Cache
- 4 unique boss fights: Cyberboss, Void Harbinger, Overclocker, Trojan Wyrm
- 4 difficulty tiers per boss (Easy/Normal/Hard/Nightmare) for replay value
- ~6 protocols collectible and upgradeable
- CPU Tiers 1–3 naturally reachable
- Target: 3–7 days of content before the experience tapers off

**What stays playable after "campaign complete":**
- All 4 sectors remain fully functional (TD gameplay, component upgrades)
- Boss farming on harder difficulties for protocol drops
- Protocol upgrading (Lv 1→10)
- Component upgrading (Lv 1→10)
- CPU Tier progression

---

## Build Command

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -scheme SystemReboot \
  -project SystemReboot.xcodeproj \
  -destination 'generic/platform=iOS Simulator' \
  build 2>&1 | tail -5
```

---

## Stages

### Stage 1: Config & Data Model Foundation
- **Status:** DONE
- **Summary:** Added `maxMVPSectorIndex` constant and `isBeyondMVP()` helper to `BalanceConfig.SectorUnlock`, and added `campaignCompleted` flag to `PlayerProfile` with backward-compatible decoding.
- **Commit:** 1407787

**Goal:** Add the MVP boundary constant to BalanceConfig and the campaign-completion flag to PlayerProfile.

**Files to modify:**
- `SystemReboot/Core/Config/BalanceConfig.swift` — `SectorUnlock` struct
- `SystemReboot/Core/Types/PlayerProfile.swift`

**Tasks:**

1. In `BalanceConfig.SectorUnlock`, add:
   ```swift
   /// Last sector index included in V1 MVP content (Cache = index 3)
   /// Sectors beyond this index show "Coming Soon" instead of unlock costs
   static let maxMVPSectorIndex: Int = 3

   /// Check if a sector is beyond the current MVP content boundary
   static func isBeyondMVP(_ sectorId: String) -> Bool {
       guard let index = unlockIndex(for: sectorId) else { return false }
       return index > maxMVPSectorIndex
   }
   ```

2. In `PlayerProfile`, add a `campaignCompleted: Bool = false` stored property:
   - Add to `CodingKeys` enum
   - Add to `defaultProfile` factory (set `false`)
   - Keep migration backward-compatible (old saves without the key decode as `false`)

3. Build and verify no compile errors.

---

### Stage 2: Sector Gating Logic
- **Status:** DONE
- **Summary:** Added `comingSoon` case to `SectorRenderMode`, wired `isBeyondMVP()` into `MegaBoardSystem.getRenderMode()`, added `isComingSoon` field to `UnlockStatus` with early-return gating in `getUnlockStatus`/`unlockSector`, and fixed all switch exhaustiveness in rendering code.
- **Commit:** 573ff2a

**Goal:** Make sectors beyond the MVP boundary un-unlockable and show a distinct "coming soon" status.

**Files to modify:**
- `SystemReboot/Core/Systems/SectorUnlockSystem.swift`
- `SystemReboot/Core/Types/MegaBoardTypes.swift`

**Tasks:**

1. Add a new `SectorRenderMode` case:
   ```swift
   case comingSoon  // Beyond MVP boundary — visible but not unlockable
   ```

2. In `SectorUnlockSystem.getUnlockStatus(for:profile:)`:
   - Early-return a special `UnlockStatus` when `BalanceConfig.SectorUnlock.isBeyondMVP(sectorId)` is true
   - The status should have `prerequisitesMet = false` and a `statusMessage` indicating "Coming Soon"
   - Consider adding an `isComingSoon: Bool` field to `UnlockStatus` so the UI can distinguish it from "missing prerequisites"

3. In `SectorUnlockSystem.unlockSector(_:profile:)`:
   - Add an early guard: if `isBeyondMVP`, return failure with reason "Coming Soon"

4. `isSectorVisible` should still return true for the sector immediately after the MVP boundary (Storage, index 4) if the Cache boss is defeated — so the "Coming Soon" badge actually appears on the motherboard. But sectors further beyond (index 5+) should only become visible if the chain continues (existing logic handles this).

5. Build and verify no compile errors.

---

### Stage 3: Motherboard "Coming Soon" UI
- **Status:** TODO
- **Summary:** _to be filled by implementing agent_
- **Commit:** _to be filled_

**Goal:** Update the Motherboard grid view to display a "Coming Soon" state for sectors beyond the MVP boundary, distinct from the locked/unlockable states.

**Files to modify:**
- `SystemReboot/UI/Tabs/MotherboardView.swift` (and any sector tile subview)
- `SystemReboot/Core/Localization/L10n.swift`
- `SystemReboot/Resources/Localizable.xcstrings`

**Tasks:**

1. Add L10n strings:
   - `L10n.Sector.comingSoon` — EN: "Coming Soon", DE: "Demnächst"
   - `L10n.Sector.comingSoonDescription` — EN: "New sectors are being developed. Stay tuned!", DE: "Neue Sektoren werden entwickelt. Bleib dran!"

2. In the motherboard sector rendering logic, check for the `isComingSoon` status (from Stage 2):
   - Show a distinct visual treatment: dimmed/translucent tile with "Coming Soon" label
   - Do NOT show the unlock cost or "Decrypt" button
   - Optionally show a subtle pulsing or locked-with-clock icon
   - The sector's display name should still be visible (players should know what's coming)

3. Build and verify no compile errors.

---

### Stage 4: Campaign Completion Detection
- **Status:** TODO
- **Summary:** _to be filled by implementing agent_
- **Commit:** _to be filled_

**Goal:** Detect when the player has defeated all 4 unique bosses (completing the MVP content) and flag the campaign as complete.

**Files to modify:**
- `SystemReboot/GameEngine/Systems/BossFightCoordinator.swift`
- `SystemReboot/Core/Config/BalanceConfig.swift` (if needed for boss count constant)

**Tasks:**

1. Add a helper to determine if the campaign is complete:
   - The campaign is complete when `defeatedSectorBosses` contains all sectors from index 0 through `maxMVPSectorIndex` in `BalanceConfig.SectorUnlock.unlockOrder`
   - This means PSU, RAM, GPU, and Cache bosses have all been defeated at least once (any difficulty)

2. In `BossFightCoordinator.onFightCompleted(victory:)`, after processing the boss defeat:
   - Check if the campaign just became complete (wasn't before, now is)
   - If so, set `profile.campaignCompleted = true` and save
   - Publish a signal (e.g. a new `@Published var showCampaignComplete = false`) that the UI can observe

3. Build and verify no compile errors.

---

### Stage 5: Campaign Complete Celebration Overlay
- **Status:** TODO
- **Summary:** _to be filled by implementing agent_
- **Commit:** _to be filled_

**Goal:** Show a one-time celebration screen when the player completes the V1 campaign, then encourage continued play on harder difficulties.

**Files to create/modify:**
- `SystemReboot/UI/Game/CampaignCompleteOverlay.swift` (new)
- `SystemReboot/Core/Localization/L10n.swift`
- `SystemReboot/Resources/Localizable.xcstrings`
- `SystemReboot/UI/Game/TDGameContainerView.swift` or `TDGameContainerView+Overlays.swift` (to present the overlay)
- `SystemReboot/UI/Tabs/MotherboardView.swift` (to present overlay if completion happens from embedded view)
- `SystemReboot.xcodeproj/project.pbxproj` (add new file to project)

**Tasks:**

1. Create `CampaignCompleteOverlay.swift` — a SwiftUI overlay view:
   - Title: "System Reboot v1.0 Complete" / "System Reboot v1.0 abgeschlossen"
   - Body acknowledging their achievement (defeated all 4 bosses, decrypted sectors)
   - Tease: "More sectors are being developed..." / "Weitere Sektoren werden entwickelt..."
   - Encourage: "Master harder difficulties and upgrade your protocols!" / "Meistere härtere Schwierigkeitsgrade und verbessere deine Protokolle!"
   - A "Continue" button to dismiss
   - Visual: match the game's tech/hacker aesthetic (similar to existing overlays like BossTutorialOverlay)

2. Add all L10n strings (EN + DE) for the overlay text.

3. Present the overlay:
   - Observe `bossCoordinator.showCampaignComplete` from the appropriate container view(s)
   - Show it as a modal/fullscreen overlay (similar to boss loot modal)
   - Only shows once (gated by the transition from `campaignCompleted == false` to `true`)

4. Build and verify no compile errors.

---

## Agent Instructions

When picking up a stage:

1. **Read this document** to find the first stage with `Status: TODO`
2. **Enter plan mode** — explore the relevant files listed in the stage, understand existing patterns, and plan the implementation
3. **Implement** the changes described in the stage tasks
4. **Build the app** using the build command above. Fix any errors before proceeding.
5. **Update this document:**
   - Change the stage's `Status:` from `TODO` to `DONE`
   - Fill in the `Summary:` with a 1–2 sentence description of what was implemented
   - Fill in the `Commit:` with the commit hash after committing
6. **Commit all changes** (including this doc update) with a descriptive message like:
   `V1 scope stage N: <brief description>`

**Important rules:**
- Follow all rules in `.claude/CLAUDE.md` (L10n, BalanceConfig, architecture)
- Do NOT modify stages that are already `DONE`
- Do NOT skip stages — they must be completed in order
- If a stage requires changes to files modified by a previous stage, read the current state of those files (don't assume the original content)
- Keep changes minimal and focused on the stage's scope
- After the build succeeds, check `git diff` to review your changes before committing
