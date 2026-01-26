# SYSTEM: REBOOT - Game Design Document

## Core Concept

**You are an AI protecting a computer system.**

The player manages a CPU that mines "Hash Power" (currency) while defending against endless streams of Viruses, Bugs, and Glitches. When threats overwhelm the automated defenses, the player must manually enter corrupted sectors to extract the source code needed to build better defenses.

**The Metaphor:**
- Red squares aren't goblins — they're **Viruses**
- Towers aren't archers — they're **Firewalls**
- The map isn't a landscape — it's a **Circuit Board**
- Death isn't failure — it's **Efficiency Loss**
- Currency isn't gold — it's **Hash Power** (Watts) and **Data**

---

## The Two Modes

### IDLE MODE: "The Motherboard"
Tower defense that runs continuously. Optimizes income while you're away.

### ACTIVE MODE: "The Debugger"
Survivor roguelite. Manual intervention to unlock new capabilities.

---

## The Dependency Loop

```
┌─────────────────────────────────────────────────────────────┐
│                    THE CORE LOOP                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   IDLE MODE (Motherboard)         ACTIVE MODE (Debugger)    │
│   ─────────────────────           ──────────────────────    │
│                                                             │
│   Generates: WATTS                Generates: DATA           │
│   (passive currency)              (blueprints/unlocks)      │
│                                                             │
│   Watts fund:                     Data unlocks:             │
│   • Hero upgrades (HP, DMG)       • New Firewall types      │
│   • Firewall upgrades             • New Circuit components  │
│   • CPU tier upgrades             • New abilities           │
│                                                             │
│   You play IDLE to power up       You play ACTIVE to        │
│   your Active hero                unlock Idle capabilities  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Why play Active?** Your idle Firewalls can't stop Level 2+ threats. You're stuck at 0% efficiency. You NEED that Slow Tower blueprint. Active is the **accelerator**.

**Why play Idle?** Your Active hero is too weak. You NEED more Watts to upgrade HP before attempting that dungeon.

### Soft-Lock Prevention

**Critical:** Active mode is the accelerator, NOT the only fuel source.

- Idle mode generates **1 Data per 1,000 viruses killed** by Firewalls
- This ensures players who struggle with Active can still progress (slowly)
- Active mode earns Data ~50x faster, but isn't mandatory
- No player should ever be permanently stuck

---

## IDLE MODE: The Motherboard

### Visual Design

The screen resembles a **dark circuit board** with glowing traces.

```
┌─────────────────────────────────────────────────────────────┐
│  ⚡ 1,247 W/s    ░░░░░░░░░░░░░░░░░░░░░░░░    CPU: 87%  ⚙️  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│    ┌───PORT A                                               │
│    │                                                        │
│    │    ○────○────○────┐                                    │
│    │                   │                                    │
│    └────○    [FW]     ○┘        ┌────PORT B                │
│          │     │       │        │                           │
│          ○─────○───────○────────○                           │
│                        │        │                           │
│                       ○┘        │                           │
│                       │         │                           │
│              ┌────────○─────────○                           │
│              │                  │                           │
│              │      ╔═══╗       │                           │
│              └──────║CPU║───────┘                           │
│                     ╚═══╝                                   │
│                     CORE                                    │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  [SCAN]     [BUILD]     [UPGRADE]     [DEBUGGER ⚠️]        │
└─────────────────────────────────────────────────────────────┘
```

### Top Bar (Always Visible)
| Element | Position | Description |
|---------|----------|-------------|
| Watts/sec | Left | Current income rate with lightning icon |
| Efficiency Bar | Center | Visual bar showing 0-100% efficiency |
| CPU % | Center-Right | Numeric efficiency percentage |
| Settings | Right | Gear icon for options |

### Main View: The Circuit Board
- **Dark background** (#0a0a0f) with subtle grid pattern
- **Circuit traces** glow in cyan (#00d4ff) - these are the paths
- **Ports** pulse red when spawning viruses
- **Core (CPU)** pulses in the center - this is what you protect
- **Firewalls** are placed at junction nodes along traces
- **Viruses** flow along traces as small geometric shapes

### Bottom Bar: Action Buttons
| Button | Function |
|--------|----------|
| SCAN | View incoming threats, wave info |
| BUILD | Open Firewall placement mode |
| UPGRADE | Spend Watts on Firewall/CPU upgrades |
| DEBUGGER | Launch Active mode (pulses when recommended) |

### Efficiency System

Efficiency determines your Watts/second income:
- **100%**: No viruses reaching core. Full mining speed.
- **50%**: Some leakage. Half mining speed.
- **0%**: Overwhelmed. No income. Game prompts Active mode.

---

### SYSTEM BREACH Events (The Emergency Hook)

**The Problem:** Static transitions between modes are boring. Player chooses when to switch — no urgency.

**The Solution:** Occasionally, a **Zero-Day Exploit** spawns in Idle mode.

```
┌─────────────────────────────────────────────────────────────┐
│  ⚠️ SYSTEM BREACH DETECTED ⚠️                               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│         ██████████████████████████████████                  │
│         ██                              ██                  │
│         ██    ╔═══════════════════╗     ██                  │
│         ██    ║   ZERO-DAY        ║     ██                  │
│         ██    ║   ████████████    ║     ██                  │
│         ██    ║   BREACH LV.3     ║     ██                  │
│         ██    ╚═══════════════════╝     ██                  │
│         ██                              ██                  │
│         ██████████████████████████████████                  │
│                                                             │
│              EFFICIENCY DROPPING: 87% → 34%                 │
│                                                             │
│            [ ⚡ INITIATE MANUAL OVERRIDE ]                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Mechanics:**
- Spawns every 10-20 minutes of active play (not offline)
- A massive boss virus that Firewalls cannot kill
- Screen flashes RED, efficiency plummets rapidly
- Pulsing button: "INITIATE MANUAL OVERRIDE"
- Clicking launches **immediately** into Active mode against that boss
- Defeating it grants bonus Data + temporary efficiency boost
- Ignoring it: Boss eventually despawns after tanking your efficiency

**Why this works:**
- Creates **urgency** — you WANT to click that button
- **Seamless transition** — no menu navigation
- **Contextual reward** — you're fighting the thing hurting your base
- **Optional** — bad timing? Let it pass, take the efficiency hit

```
Efficiency = 100% - (leakedViruses / threshold * 100)
WattsPerSecond = baseRate * (efficiency / 100) * CPUTier
```

**Key insight:** You never "die" in Idle mode. You just become inefficient. This removes frustration while maintaining pressure.

### Blocker Nodes (Strategic Path Control)

**The Problem:** Static TD with preset paths is boring in 2025. Players need a strategic lever.

**The Solution:** Players can place **Blocker Nodes** to redirect virus paths.

```
Before Blocker:                    After Blocker:

PORT ──────────→ CORE              PORT ───┐
                                           │ [BLOCKER]
                                           │
                                   ┌───────┘
                                   │
                                   └──────→ CORE
```

**Mechanics:**
- Blockers are placed on circuit trace intersections
- Viruses cannot pass through Blockers — they reroute
- Longer paths = more time for Firewalls to shoot
- Limited Blocker slots (start with 3, upgradeable)
- Blockers are FREE to place/move — strategy, not paywall
- Invalid placement prevented (can't block ALL paths)

**Why this works:**
- Gives player **agency** over the battlefield
- Simple to implement (path recalculation on placement)
- Creates emergent strategy (funnel viruses through kill zones)
- Differentiates from generic TD games

**Visual:**
- Blocker = Red octagon (stop sign aesthetic)
- Valid placement spots glow when in BUILD mode
- Path preview shows new route before confirming

---

### Firewall Types (Unlocked via Active Mode)

| Firewall | Unlock | Effect | Visual |
|----------|--------|--------|--------|
| Basic | Default | Single target damage | White square |
| Burst | Data Tier 1 | AOE damage | Orange square with pulse |
| Freeze | Data Tier 2 | Slows viruses | Cyan square with crystals |
| Chain | Data Tier 3 | Hits multiple targets | Yellow with lightning |
| Purge | Data Tier 4 | Massive single damage | Red with skull icon |

### Virus Types

| Virus | Appearance | Behavior |
|-------|------------|----------|
| Bug | Red square | Basic, slow |
| Worm | Red rectangle | Fast, weak |
| Trojan | Red triangle | Tanky, slow |
| Glitch | Flickering shape | Teleports forward |
| Ransomware | Purple square | Disables nearby Firewalls |

---

## ACTIVE MODE: The Debugger

### Visual Design

A corrupted, glitchy arena. The player's "Cursor" avatar fights waves of viruses.

```
┌─────────────────────────────────────────────────────────────┐
│  ♥♥♥♥♥♥░░░░   SECTOR 3-2   DATA: 47   ⏱ 2:34              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│         ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·                │
│      ·        ▪ ▪                        ·                  │
│         ·  ▪     ▪  ·     ·  ·  ·  ·  ·                    │
│      ·     ▪  ▲  ▪     ·                 ·                  │
│         ·     ▪     ·        ▪ ▪ ▪    ·                    │
│      ·  ·  ·  ·  ·  ·     ▪       ▪      ·                 │
│         ·           ·     ▪   ◇   ▪   ·                    │
│      ·     ·  ·  ·     ·     ▪ ▪ ▪    ·                    │
│         ·              ·  ·  ·  ·  ·  ·                    │
│      ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·                   │
│                                                             │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                      ○                                      │
│                   JOYSTICK                                  │
└─────────────────────────────────────────────────────────────┘

◇ = Player (Cursor)
▲ = Enemy (Bug)
▪ = Enemy (Worm)
· = Corruption particles (visual noise)
```

### Top Bar
| Element | Position | Description |
|---------|----------|-------------|
| Health | Left | Heart icons or bar |
| Sector ID | Center | Current dungeon/level |
| Data Collected | Center-Right | Currency earned this run |
| Timer | Right | Survival time |

### Main View: The Corrupted Sector
- **Background**: Dark with scan lines and glitch effects
- **Player**: Bright cyan cursor/arrow shape
- **Enemies**: Red/purple geometric shapes
- **Pickups**: Green (health), Yellow (data), Blue (powerups)
- **Corruption**: Visual noise particles, flickering regions

### Controls
- **Left thumb**: Virtual joystick for movement
- **Auto-fire**: Weapons fire automatically at nearest enemy
- **Abilities**: Tap buttons for special abilities (unlocked via progression)

### HUD Elements During Gameplay
- Health bar (top left) - Large, always visible
- Current weapon indicator (small icon)
- Ability cooldowns (bottom corners if unlocked)
- Data counter (top right)
- Wave/time indicator

### Run Structure

Each Active run is a "Debug Session":

1. **Select Sector**: Choose which virus type to hunt (determines rewards)
2. **Survive Waves**: Kill viruses, collect Data pickups
3. **Extract or Die**: Survive to extraction timer OR die and keep partial Data
4. **Rewards**: Data spent on unlocks, blueprints discovered

### Extraction Mechanic

After surviving X minutes, an "EXTRACTION AVAILABLE" prompt appears:
- **Extract now**: Keep all Data, end run safely
- **Continue**: Risk death for more Data, chance at rare blueprints

This adds risk/reward decision-making.

---

## VISUAL DESIGN SYSTEM

### Color Palette

| Role | Hex | Usage |
|------|-----|-------|
| Background | #0a0a0f | Primary dark background |
| Surface | #1a1a24 | Panels, cards |
| Primary | #00d4ff | Cyan - circuits, player, UI accents |
| Secondary | #8b5cf6 | Purple - special effects, rare items |
| Success | #22c55e | Green - health, valid actions |
| Warning | #f59e0b | Amber - alerts, important info |
| Danger | #ef4444 | Red - enemies, damage, errors |
| Muted | #4a4a5a | Disabled, inactive |

### Enemy Colors by Threat Level
- **Tier 1**: Red (#ef4444)
- **Tier 2**: Orange (#f97316)
- **Tier 3**: Purple (#a855f7)
- **Tier 4 (Boss)**: White with color cycling

### Typography

**Terminal/Monospace aesthetic:**
- **Headers**: SF Mono Bold or system monospace
- **Body**: SF Mono Regular
- **Numbers**: Tabular figures (fixed width for counters)

### Visual Effects

| Effect | Usage |
|--------|-------|
| Scan lines | Subtle overlay on Active mode |
| Pixel dissolve | Enemy death animation |
| Glitch flicker | Damage taken, corruption zones |
| Circuit pulse | Path highlighting, Firewall activation |
| Data stream | Pickup collection |

### Sound Design Direction

| Event | Sound Type |
|-------|------------|
| Firewall shot | Digital blip/chirp |
| Enemy death | Pixel crunch/de-rez |
| Damage taken | Distorted buzz |
| Pickup collected | Ascending chime |
| Level up | Synthesized fanfare |
| Extraction | Computer boot sound |
| Background (Idle) | Low ambient hum |
| Background (Active) | Synthwave/chiptune beat |

---

## PROGRESSION SYSTEM

### Currencies

| Currency | Earned In | Spent On |
|----------|-----------|----------|
| **Watts (⚡)** | Idle mode (passive) | Hero upgrades, Firewall upgrades, CPU tiers |
| **Data (◈)** | Active mode (primary), Idle mode (1 per 1000 kills) | Unlock Firewalls, abilities, sectors |

**Soft-Lock Prevention:** Idle generates ~1 Data per 1000 virus kills. Active earns Data ~50x faster but isn't mandatory. No player gets permanently stuck.

### Idle Upgrades (Cost: Watts)

**CPU Tiers** (Global multiplier):
- CPU 1.0: 1x base income
- CPU 2.0: 2x base income (Cost: 1000W)
- CPU 3.0: 4x base income (Cost: 5000W)
- etc.

**Firewall Upgrades**:
- Damage +10% (repeatable)
- Attack speed +10% (repeatable)
- Range +10% (repeatable)

**Hero Upgrades** (for Active mode):
- Max HP +10
- Damage +5%
- Speed +5%
- Pickup Range +10%

### Active Unlocks (Cost: Data)

**Firewall Blueprints**:
- Burst Firewall: 50 Data
- Freeze Firewall: 100 Data
- Chain Firewall: 200 Data
- Purge Firewall: 500 Data

**Sectors**:
- Sector 2: 100 Data
- Sector 3: 250 Data
- Sector 4: 500 Data

**Abilities**:
- EMP Burst (AOE stun): 150 Data
- Overclock (speed boost): 150 Data
- Firewall (temp shield): 200 Data

---

## UI FLOW

### App Launch
```
[Splash: "SYSTEM: REBOOT"]
         ↓
[Main Screen: Motherboard (Idle Mode)]
```

Always launch into Idle mode. This is home base.

### Main Navigation

```
┌─────────────────────────────────────────┐
│           MOTHERBOARD (Idle)            │
│                                         │
│   [SCAN] [BUILD] [UPGRADE] [DEBUGGER]   │
└─────────────────────────────────────────┘
     │        │        │          │
     ↓        ↓        ↓          ↓
  Threat   Place    Upgrade    Launch
  Info     Mode     Menu       Active
                               Mode
```

### Offline Return

When player opens app after being away:
```
┌─────────────────────────────────────────┐
│         SYSTEM REPORT                   │
│                                         │
│   Time offline: 4h 23m                  │
│   Watts earned: +12,450 ⚡              │
│   Efficiency avg: 67%                   │
│   Viruses neutralized: 4,892            │
│                                         │
│            [COLLECT]                    │
└─────────────────────────────────────────┘
```

---

## IDLE MODE DETAILED MECHANICS

### Wave System

Viruses spawn continuously from Ports. Difficulty scales with time:
- **Minutes 0-5**: Tier 1 only (Bugs)
- **Minutes 5-15**: Tier 1-2 (Bugs, Worms)
- **Minutes 15-30**: Tier 1-3 (add Trojans)
- **Minutes 30+**: All types including Glitches

### Efficiency Calculation

```
leakCounter += 1 for each virus reaching Core
leakCounter decays by 1 every 5 seconds

efficiency = max(0, 100 - (leakCounter * 5))
```

This creates a rolling average rather than instant punishment.

### Offline Calculation

```
offlineWatts = timeAway * baseWattsPerSecond * avgEfficiency * 0.5

// 50% penalty for offline vs online
// Capped at 8 hours to prevent infinite gains
```

---

## ACTIVE MODE DETAILED MECHANICS

### Sector Selection

Each sector targets a specific virus type:
- **Sector 1: Quarantine** - Bugs only (easy, low Data)
- **Sector 2: Worm Farm** - Worms (fast enemies, medium Data)
- **Sector 3: Trojan Vault** - Trojans (tanky, high Data)
- **Sector 4: Glitch Zone** - Mixed + Glitches (hardest, best rewards)

Completing a sector unlocks its Firewall blueprint effective against that type.

### Wave Progression

```
Wave 1-3: Light spawns, learn patterns
Wave 4-6: Medium density
Wave 7-9: Heavy spawns
Wave 10: Mini-boss (large virus)
Wave 11+: Endless scaling until death/extraction
```

### Extraction Timer

- Available after Wave 10 (approximately 3 minutes)
- Button appears: "EXTRACT [◈ 47]"
- Staying increases Data but risks losing everything
- Death = keep 50% of collected Data

---

## TECHNICAL NOTES

### State Persistence

Save on every significant action:
- Firewall placed/upgraded
- Watts earned (periodic)
- Active run completed
- Settings changed

### Offline Sync

On app launch:
1. Load last save timestamp
2. Calculate time delta
3. Simulate idle earnings
4. Show report modal
5. Update state

### Performance Targets

- Idle mode: 30 FPS (battery efficient)
- Active mode: 60 FPS (smooth combat)
- Max entities: 100 viruses, 20 firewalls, 50 projectiles

---

## IMPLEMENTATION PHASES

### Phase 1: Rebrand & Core Loop
- [ ] Rename everything (Virus, Firewall, Watts, Data, etc.)
- [ ] Implement efficiency-based loss (not death)
- [ ] Add terminal/circuit visual style
- [ ] **Blocker Nodes** (simplified path control from day 1)
- [ ] Basic persistence (save/load)

### Phase 2: Idle Mechanics
- [ ] Offline earnings calculation
- [ ] Welcome back modal
- [ ] Watts income display
- [ ] CPU tier upgrades
- [ ] **Passive Data generation** (1 Data per 1000 kills — soft-lock prevention)

### Phase 3: Dual Currency & Connection
- [ ] Data earned in Active mode
- [ ] Data spent on Firewall unlocks
- [ ] Watts spent on hero upgrades
- [ ] Unlock gating between modes
- [ ] **System Breach events** (Zero-Day boss, emergency hook)

### Phase 4: Polish
- [ ] Sound effects
- [ ] Visual effects (glitch, scan lines)
- [ ] Extraction mechanic
- [ ] Sector selection

### Phase 5: Advanced Path Control (Future)
- [ ] Player-drawn circuit traces (full maze building)
- [ ] Path validation
- [ ] Multiple path configurations

---

## SUCCESS METRICS

The game is working when:
1. Player voluntarily switches between modes (neither feels like a chore)
2. "One more run" in Active to unlock that Firewall
3. Satisfying to check Idle earnings after being away
4. Clear understanding of what to do next
5. Terminal aesthetic feels intentional, not placeholder
6. **Blocker placement feels strategic** — "if I move this here, I create a kill zone"
7. **System Breach creates excitement** — player WANTS to click Manual Override
8. **No soft-locks** — even bad Active players progress (slowly) via idle Data

---

*This document is the source of truth. All implementation decisions reference this spec.*
