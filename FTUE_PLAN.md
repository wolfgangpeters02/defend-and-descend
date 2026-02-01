# First Time User Experience (FTUE) Plan

> **Version:** 1.0
> **Purpose:** Onboard new players with story-driven intro cards, gentle guidance, and natural discovery

---

## Design Philosophy

### What We Want
- **Story-driven intro** (2-3 cards) that establishes the narrative and core concepts
- **Natural discovery** through gentle visual hints, not forced popups
- **Immediate playability** - player can interact within seconds
- **Progressive revelation** - teach concepts as they become relevant

### What We DON'T Want
- Forced "click here to continue" tutorials
- Blocking popups that interrupt gameplay
- Text-heavy explanations
- Hand-holding beyond the first minute

---

## Part 1: The Intro Sequence (3 Cards)

### Trigger
- First app launch ever (tracked via `hasCompletedIntro` in PlayerProfile)
- Can be replayed from Settings menu

### Card Style
- Full-screen dark overlay (matches WelcomeBackModal aesthetic)
- Terminal/hacker theme with glitch effects
- Swipe left/right or tap to advance
- Skip button in corner (respects player agency)
- Sequential reveal animations (typewriter effect for text)

---

### Card 1: "SYSTEM BOOT"

**Visual:**
- Black screen with a glowing CPU chip in center
- Circuit traces animate outward from CPU
- Scanline effect scrolling down

**Text (typewriter reveal):**
```
> INITIALIZING KERNEL...
>
> You are the system administrator.
> Your CPU generates HASH (Ħ) - the lifeblood of this machine.
>
> [CPU icon pulsing with Ħ symbols flowing out]
```

**Teaches:** CPU generates Hash, Hash is the currency

---

### Card 2: "THREAT DETECTED"

**Visual:**
- Red warning glow pulses at edges
- Virus sprites (red corrupted data) approach from lanes
- CPU flashes warning

**Text:**
```
> WARNING: MALWARE DETECTED
>
> Viruses are attacking. They will corrupt the core.
> Build FIREWALLS to defend.
>
> [Tower icon] Firewalls = Your Protocols deployed as defenses
```

**Teaches:** Viruses are the threat, Protocols/Towers defend

---

### Card 3: "ALWAYS RUNNING"

**Visual:**
- Split screen: Left shows phone with moon/sleep icon, Right shows the motherboard still running
- Hash counter incrementing in background
- Clock showing time passing

**Text:**
```
> BACKGROUND PROCESSES ACTIVE
>
> Your system never sleeps.
> Even offline, your CPU generates HASH.
>
> Return anytime to collect your earnings.
>
> [ENTER SYSTEM] button
```

**Teaches:** Idle earnings work offline, incentive to return

---

## Part 2: First Session Flow

After the intro cards dismiss, the player lands on the **BOARD tab** (Motherboard TD view).

### Immediate State
- **CPU is generating Hash** (visible counter ticking up)
- **First wave has NOT started yet** (grace period of 10 seconds)
- **Kernel Pulse card** is highlighted with a subtle glow in the deck
- **One tower slot** has a pulsing "place here" indicator (closest to first lane)

### Gentle Guidance (No Popups)

**Visual Hints Only:**

1. **Deck Glow** - The Kernel Pulse card in the bottom deck has a soft cyan pulse
   - Stops pulsing once player picks it up

2. **Slot Indicator** - One optimal placement slot shows a ghost outline of a tower
   - Disappears after first tower placed

3. **First Enemy Spawn** - After 10-second grace period, first wave spawns
   - If no tower placed, enemies leak and efficiency drops
   - Natural consequence teaches defense is needed

### First Tower Placement

When player successfully places their first tower:
- Brief celebration pulse (cyan ripple from tower)
- Tower immediately starts firing at first enemy
- **No popup** - just visual satisfaction

---

## Part 3: Progressive Milestone Unlocks

Instead of teaching everything upfront, reveal UI hints at natural milestones:

### Milestone 1: First Efficiency Drop (Any leak)
**What happens:** Efficiency bar turns red briefly, income visually slows
**Teaches:** Leaks hurt your income (natural consequence, no popup)

### Milestone 2: First 500 Hash Earned
**What happens:** PSU upgrade button gets a subtle pulse/glow
**Teaches:** You can upgrade your power capacity to place more towers

### Milestone 3: First Zero-Day Event (After ~5 mins)
**What happens:**
- Screen flashes red warning: `ZERO_DAY_DETECTED`
- Boss icon appears on board with timer
- Message: "Firewall breach. Manual intervention required."
**Teaches:** Some threats require direct combat (boss encounters)
**Action:** Tapping the boss alert opens the boss fight

### Milestone 4: First Boss Kill
**What happens:** Blueprint drops, BlueprintDiscoveryModal appears
**Teaches:** Bosses drop blueprints for new Protocols

### Milestone 5: First App Close & Return
**What happens:** WelcomeBackModal shows offline earnings
**Teaches:** Confirms the "always running" promise from intro cards

---

## Part 4: Boss Introduction

### Current State
- Bosses are always accessible from the BOSS tab
- Zero-Day events can spawn mid-TD

### FTUE Enhancement

**First visit to BOSS tab** (after intro complete):
- Brief header flash: `THREAT ANALYSIS: CYBERBOSS`
- Boss card has a "NEW" badge
- Tapping opens standard boss encounter flow

**Narrative framing for bosses:**
- Bosses are "Critical Viruses" that firewalls cannot stop
- They must be debugged manually (the survivor/boss combat mode)
- Defeating them yields Protocol blueprints

---

## Part 5: UI Hints System

### Hint Types (Subtle, Non-Blocking)

| Hint Type | Visual | When to Use |
|-----------|--------|-------------|
| **Glow Pulse** | Soft cyan/purple breathing glow | Highlight important interactive elements |
| **Ghost Preview** | Semi-transparent preview | Show where something can be placed |
| **Badge** | "NEW" or "!" indicator | New feature/content unlocked |
| **Edge Glow** | Subtle colored border | Draw attention to a screen section |

### Hint Dismissal Rules
- Hints auto-dismiss after player interacts with the element
- Hints never block interaction
- Hints fade after 30 seconds if ignored (don't nag)

---

## Part 6: Implementation Requirements

### New PlayerProfile Fields

```swift
// Add to PlayerProfile
var hasCompletedIntro: Bool = false      // Intro cards seen
var firstTowerPlaced: Bool = false       // First placement milestone
var firstBossKilled: Bool = false        // First boss victory
var tutorialHintsSeen: [String] = []     // Track dismissed hints
```

### New Components

1. **IntroSequenceView** - The 3-card intro flow
   - Reuses styling from WelcomeBackModal/BlueprintRevealModal
   - Swipe/tap navigation
   - Skip button
   - onComplete callback

2. **TutorialHintOverlay** - Subtle hint system
   - Takes a list of active hints
   - Renders glows/badges/ghosts
   - Tracks dismissal

3. **MilestoneTracker** - Monitors gameplay events
   - Triggers hints at appropriate moments
   - Updates PlayerProfile flags

### Modified Files

| File | Change |
|------|--------|
| `PlayerProfile` | Add FTUE tracking fields |
| `ContentView` | Show IntroSequenceView on first launch |
| `MotherboardView` | Add TutorialHintOverlay for deck/slot hints |
| `AppState` | Add firstLaunch detection logic |
| `SystemTabView` | Add "NEW" badges for unexplored tabs |

---

## Part 7: Intro Card Visual Mockups

### Card 1 Layout
```
┌────────────────────────────────────────┐
│                                        │
│         [Skip →]                       │
│                                        │
│              ┌─────┐                   │
│              │ CPU │  ← Glowing        │
│              └──┬──┘                   │
│          ═══════╪═══════               │
│                 │                      │
│            Ħ   Ħ   Ħ   ← Flowing out   │
│                                        │
│  > INITIALIZING KERNEL...              │
│                                        │
│  You are the system administrator.     │
│  Your CPU generates HASH (Ħ).          │
│                                        │
│                                        │
│              ○ ○ ○   ← Page dots       │
│              ●                         │
│                                        │
│       [Swipe or tap to continue]       │
└────────────────────────────────────────┘
```

### Card 2 Layout
```
┌────────────────────────────────────────┐
│                                        │
│  ▓▓▓ WARNING ▓▓▓       [Skip →]        │
│                                        │
│     🦠 → → → ┌─────┐                   │
│     🦠 → → → │ CPU │ ← Under attack    │
│     🦠 → → → └─────┘                   │
│                                        │
│  > MALWARE DETECTED                    │
│                                        │
│  Viruses are attacking.                │
│  Build FIREWALLS to defend.            │
│                                        │
│     ┌───┐                              │
│     │ ⚡ │ = Your Protocols            │
│     └───┘   as defenses                │
│                                        │
│              ○ ● ○                     │
│                                        │
└────────────────────────────────────────┘
```

### Card 3 Layout
```
┌────────────────────────────────────────┐
│                                        │
│         [Skip →]                       │
│                                        │
│   ┌──────────┐    ┌──────────┐         │
│   │  📱 💤   │    │ Ħ +500   │         │
│   │  You     │ →  │ Earning  │         │
│   │  sleep   │    │ 24/7     │         │
│   └──────────┘    └──────────┘         │
│                                        │
│  > BACKGROUND PROCESSES ACTIVE         │
│                                        │
│  Your system never sleeps.             │
│  Even offline, your CPU generates Ħ.   │
│                                        │
│         ┌─────────────────┐            │
│         │  ENTER SYSTEM   │            │
│         └─────────────────┘            │
│                                        │
│              ○ ○ ●                     │
│                                        │
└────────────────────────────────────────┘
```

---

## Part 8: Success Metrics

### Quantitative (If analytics added)
- % of players completing intro sequence
- % of players placing first tower within 30 seconds
- % of players returning after first session
- Time to first boss encounter

### Qualitative
- Player understands CPU → Hash relationship
- Player understands tower = defense
- Player returns to collect offline earnings
- Player naturally discovers boss encounters

---

## Summary: The First 60 Seconds

| Time | What Happens |
|------|--------------|
| 0-15s | Intro cards (can skip) |
| 15-20s | Lands on BOARD tab, sees Hash ticking up |
| 20-25s | Notices glowing Kernel Pulse card, drags it |
| 25-30s | Places tower on highlighted slot |
| 30-35s | First enemies spawn, tower starts shooting |
| 35-60s | Natural gameplay begins, learning through play |

**No forced clicks. No blocking popups. Just story, then play.**
