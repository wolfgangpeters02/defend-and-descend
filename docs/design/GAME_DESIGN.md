# System: Reboot - Game Design Document

> **Version:** 5.0 (4-Boss Expansion + Overclock)
> **Last Updated:** 2026-02-17
> **Platform:** Native iOS (Swift/SpriteKit)
> **Related:** [GAME_BALANCING_BLUEPRINT.md](./GAME_BALANCING_BLUEPRINT.md) for economy tables

---

## Table of Contents

1. [Game Identity](#1-game-identity)
2. [Visual Identity](#2-visual-identity)
3. [Economy & Currencies](#3-economy--currencies)
4. [Game Modes](#4-game-modes)
5. [The Protocol System](#5-the-protocol-system)
6. [The Mega-Board](#6-the-mega-board)
7. [Component Upgrades](#7-component-upgrades)
8. [Core Mechanics](#8-core-mechanics)
9. [Progression Flow](#9-progression-flow)
10. [UI Structure](#10-ui-structure)
11. [Technical Architecture](#11-technical-architecture)
12. [Design Principles & Safeguards](#12-design-principles--safeguards)

---

## 1. Game Identity

### One-Line Pitch

> "SimCity meets Tower Defense on a motherboard - build your PC empire, defend it from viruses."

### Core Fantasy

You are the **Kernel** - the master system administrator. You build the hardware (Motherboard), install the software (Protocols), and manually debug corrupted sectors when the automated defenses fail.

### The Hook

You cannot just buy upgrades with money. You must:
- **Build the hardware** to run them (PSU capacity)
- **Compile the software** to use them (Protocols from blueprints)
- **Defend the system** to earn resources (Hash from CPU)
- **Hunt bosses** to unlock new technology (blueprint drops)

### Two Modes, One Goal

| Mode | Genre | Purpose | Primary Reward |
|------|-------|---------|----------------|
| **Tower Defense** (Motherboard) | Idle TD / City Builder | Build defenses, earn passive Hash | Hash (passive) |
| **Boss Encounters** (Arena) | Raid-Style Combat | Defeat bosses for blueprints | Hash + Blueprints |

---

## 2. Visual Identity

### Aesthetic: "Dark Mode Terminal"

The game takes place entirely inside a computer system.

| Element | Style |
|---------|-------|
| **Background** | Deep blacks (#0a0a0f), subtle circuit grid |
| **Traces** | Glowing copper/cyan circuit paths |
| **UI** | Monospace fonts, terminal styling |
| **Effects** | Scan lines, glitch effects, additive glow |

### Color Palette

```
BACKGROUNDS
-----------
Background:     #0a0a0f  (Almost black)
Surface:        #1a1a24  (Cards, panels)
Dark Surface:   #0d1117  (Darker panels)

BRAND COLORS
------------
Primary:        #00d4ff  (Cyan - circuits, Power)
Secondary:      #8b5cf6  (Purple - special)
Success:        #22c55e  (Green - health, Data)
Warning:        #f59e0b  (Amber - legendary)
Danger:         #ef4444  (Red - enemies)
Muted:          #4a4a5a  (Disabled)

PCB ELEMENTS
------------
Copper Trace:   #b87333  (Path traces)
Active Glow:    #00ff88  (Active components)
Ghost Mode:     #333344  (Locked sectors)
```

### Typography

All text uses monospace fonts for terminal authenticity:

| Usage | Font |
|-------|------|
| Display | System Monospaced Bold 32-48pt |
| Headline | System Monospaced Bold 18-24pt |
| Body | System Monospaced 14-16pt |
| Caption | System Monospaced 10-12pt |

---

## 3. Economy & Currencies

The economy is centered on **Hash** as the universal currency, with **Power** as a build constraint.

| Icon | Name | Role | Source |
|------|------|------|--------|
| Ħ | **Hash** | Universal Currency | All game modes |
| ⚡ | **Power (Watts)** | Build Capacity | PSU (static limit) |

### Hash (Ħ) - Universal Currency

**Role:** MONEY - earned from all activities, spent on everything.

**Starting Amount:** 500 Ħ

**Earning Sources:**
- **Tower Defense:** Passive CPU generation + enemy kills (sector bonus: later sectors pay more)
- **Boss Fights:** Fixed rewards by difficulty (1,000Ħ Easy → 25,000Ħ Nightmare)
- **Offline:** Passive earnings while app is closed (20% of active rate, capped at 24 hours)
- **Overclock:** 4× Hash generation for 45 seconds (risk/reward mechanic)

**Spending:**
- Tower placement costs
- Global upgrades (9 components: PSU, Storage, RAM, GPU, Cache, Expansion, I/O, Network, CPU)
- Sector unlocks (1,500-300,000 Ħ per sector)
- Protocol compilation (100-800 Ħ by rarity)
- CPU tier upgrades (750-500,000 Ħ)
- Boss encounter unlocks (200-600 Ħ)

**Storage:** Capped by Storage component level (15,000Ħ base, scaling with level)

```
Example:
Storage Capacity: 150,000 Ħ
Current Hash: 85,000 Ħ
Base Income: Based on efficiency % and CPU level × CPU tier
```

### Power (Watts) ⚡

**Role:** BUILD LIMIT - determines total tower capacity.

- Power is a **capacity**, not consumed
- Each tower allocates Power while placed
- PSU upgrades increase the ceiling (300W → 2300W)
- Cannot place towers if total would exceed capacity
- Overclock increases power demand by 1.5× (may disable towers)

```
Example:
PSU: 700W Capacity
Currently Used: 520W
Available: 180W

Tower costs 100W → CAN BUILD
Tower costs 200W → CANNOT BUILD (need PSU upgrade)
```

### XP & Leveling

**Role:** WEAPON MASTERY - per-protocol progression.

- XP earned from kills and survival time in boss encounters
- Each Protocol tracks weapon mastery independently (max level 10)
- +5% stats per level
- XP formula: 100 base + 75 per level

---

## 4. Game Modes

### 4.1 Tower Defense: The Motherboard

**Genre:** Idle Tower Defense + City Builder

**What You Do:**
- Place Firewalls (Protocols converted to towers)
- Defend the CPU core from virus waves
- Expand by unlocking new lanes/sectors
- Manage Power budget
- Earn passive Hash income

**Key Features:**
- 3×3 sector grid (9 sectors) with PCB aesthetics
- Drag-to-place tower system
- Efficiency-based income (viruses leak = reduced income)
- Idle spawning with threat level scaling
- Super Virus boss spawns at threat milestones
- Overclock mechanic (voluntary risk/reward)
- Blocker system (reroute enemies at path intersections)
- Tower merging (combine 2 same-type towers for star upgrades)

**Idle Spawn System:**
- Continuous enemy spawning based on threat level
- Threat increases over time (0.01/sec), introducing new enemy types
- Enemy variety: Basic → Fast → Swarm → Tank → Elite → Boss
- Max 50 enemies on screen

**When to Play:**
- Passive Hash accumulation
- Relaxed tower-building gameplay
- Testing tower layouts and compositions

### 4.2 Boss Encounters: The Arena

**Genre:** Raid-Style Boss Combat (Twin-Stick Shooter)

**What You Do:**
- Select a boss and difficulty level
- Fight in a 1200×900 arena with 8 destructible pillars
- Control the Cursor (player avatar) with virtual joystick
- Auto-targeting/auto-fire with equipped Protocol as weapon
- Learn attack patterns and mechanics across 4 phases
- Earn blueprints for new Protocols

**Difficulty Levels:**

| Difficulty | Boss HP | Boss Damage | Player HP | Player Damage | Hash Reward |
|------------|---------|-------------|-----------|---------------|-------------|
| Easy | 0.6× | 0.35× | 1.75× | 2.5× | 1,000 Ħ |
| Normal | 1.5× | 1.0× | 1.0× | 1.0× | 3,000 Ħ |
| Hard | 2.0× | 1.5× | 1.0× | 1.0× | 10,000 Ħ |
| Nightmare | 3.5× | 2.5× | 0.8× | 1.0× | 25,000 Ħ |

**Current Bosses (4):**

**ROGUE PROCESS** (Cyberboss) - Mode-switching melee/ranged hybrid (Base HP: 2000)
- Phase 1 (100-75%): Alternates melee chase and ranged bombardment
- Phase 2 (75-50%): Spawns minions while mode-switching
- Phase 3 (50-25%): Stationary, spawns damage puddles
- Phase 4 (25-0%): Rotating laser beams + rapid puddles
- Unlock: Free | Drops: Burst Protocol, Trace Route

**MEMORY LEAK** (Void Harbinger) - Raid-style mechanics boss (Base HP: 3000)
- Phase 1 (100-70%): Void zones + shadow bolt volleys + minions
- Phase 2 (70-40%): Invulnerable until 4 pylons destroyed
- Phase 3 (40-20%): Rotating void rifts + gravity wells + meteors
- Phase 4 (20-0%): Shrinking arena + teleportation + enrage
- Unlock: 200Ħ | Drops: Fork Bomb, Overflow

**THERMAL RUNAWAY** (Overclocker) - Heat-themed environmental boss (Base HP: 2500)
- Phase 1 (100-75%): Wind force + rotating blades (3 blades, orbit)
- Phase 2 (75-50%): 4×4 lava tile grid with 2 safe tiles per cycle
- Phase 3 (50-25%): Chase mode + steam trail
- Phase 4 (25-0%): Vacuum suction + shredder zone
- Unlock: 400Ħ | Drops: Ice Shard, Null Pointer

**PACKET WORM** (Trojan Wyrm) - Segmented serpent boss (Base HP: 3500)
- Phase 1 (100-70%): Snake movement with 24-segment body
- Phase 2 (70-40%): Wall sweep + turret fire
- Phase 3 (40-20%): Splits into 3 sub-worms
- Phase 4 (20-0%): Constricting ring + lunge attacks
- Unlock: 600Ħ | Drops: Root Access

**Player Stats in Boss Mode:**
- Health: 200 base (modified by RAM level + difficulty)
- Speed: 200 units/sec
- Regen: 3.0 HP/sec
- Invulnerability: 0.5s after hit, 3.0s after revive
- In-session upgrades offered every 60 seconds (damage, health, speed, abilities)

**When to Play:**
- Need Protocol blueprints
- Want challenging combat
- Testing builds against specific mechanics

### Mode Switching Motivation

| Situation | Problem | Solution |
|-----------|---------|----------|
| "Can't build more towers" | Power limit | Upgrade PSU component (costs Hash) |
| "Can't afford upgrades" | Not enough Hash | Use Overclock or wait for TD income |
| "Need new Protocol" | Missing blueprint | Defeat bosses for blueprint drops |
| "Want to unlock next sector" | Need boss kill | Beat the sector's Super Virus boss |
| "Sector visible but locked" | Need Hash | Farm Hash then pay unlock cost |

---

## 5. The Protocol System

Protocols are **dual-purpose software** that function differently in each mode.

### Protocol Structure

```swift
Protocol {
    id: String
    name: String
    rarity: Rarity          // Common → Legendary
    level: Int              // 1-10 (upgradeable)
    starLevel: Int          // 0-3 (via merging)
    isCompiled: Bool        // Requires blueprint + Hash to compile

    firewallStats: {        // TD Mode stats
        damage, range, attackSpeed, splash, slow, chain, power
    }

    weaponStats: {          // Boss Mode stats
        damage, attackSpeed, projectileCount, pierce, spread
    }
}
```

### The 8 Core Protocols

**Firewall Stats (TD Mode):**

| Protocol | Rarity | Power | DMG | Range | Rate | Special |
|----------|--------|-------|-----|-------|------|---------|
| Kernel Pulse | Common | 15W | 10 | 120 | 1.0/s | — |
| Burst Protocol | Common | 20W | 8 | 100 | 0.8/s | Splash 40 |
| Trace Route | Rare | 35W | 50 | 250 | 0.4/s | Pierce 3 |
| Ice Shard | Rare | 30W | 5 | 130 | 1.5/s | Slow 50%/2s |
| Fork Bomb | Epic | 60W | 12 | 140 | 0.7/s | 3 projectiles |
| Root Access | Epic | 75W | 80 | 160 | 0.3/s | — |
| Overflow | Legendary | 120W | 15 | 150 | 0.8/s | Chain 3 |
| Null Pointer | Legendary | 100W | 25 | 140 | 0.6/s | Execute low HP |

**Weapon Stats (Boss Mode):**

| Protocol | DMG | Rate | Proj | Spread | Pierce | Speed | Special |
|----------|-----|------|------|--------|--------|-------|---------|
| Kernel Pulse | 8 | 2.0/s | 1 | 0 | 1 | 400 | — |
| Burst Protocol | 6 | 0.8/s | 5 | 0.5 rad | 1 | 350 | — |
| Trace Route | 40 | 0.5/s | 1 | 0 | 5 | 800 | — |
| Ice Shard | 4 | 3.0/s | 1 | 0 | 1 | 500 | — |
| Fork Bomb | 10 | 1.0/s | 8 | 0.8 rad | 1 | 380 | — |
| Root Access | 60 | 0.4/s | 1 | 0 | 1 | 600 | — |
| Overflow | 12 | 1.2/s | 1 | 0 | 1 | 450 | Ricochet 3 |
| Null Pointer | 20 | 0.8/s | 1 | 0 | 1 | 500 | Critical 2× |

**Costs:**

| Protocol | Rarity | Compile | Placement | Upgrade Base |
|----------|--------|---------|-----------|--------------|
| Kernel Pulse | Common | Free | 50Ħ | 50Ħ |
| Burst Protocol | Common | 100Ħ | 50Ħ | 50Ħ |
| Trace Route | Rare | 200Ħ | 100Ħ | 100Ħ |
| Ice Shard | Rare | 200Ħ | 100Ħ | 100Ħ |
| Fork Bomb | Epic | 400Ħ | 200Ħ | 200Ħ |
| Root Access | Epic | 400Ħ | 200Ħ | 200Ħ |
| Overflow | Legendary | 800Ħ | 400Ħ | 400Ħ |
| Null Pointer | Legendary | 800Ħ | 400Ħ | 400Ħ |

### Tower Star System (Merging)

Towers can be merged for increased power:
- Combine 2 identical towers → 1 star-upgraded tower
- Each star level: 2× stat multiplier
- Maximum: 3 stars (8× base stats)
- Star count displayed visually on tower

### Protocol Flow

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  BLUEPRINT  │───▶│  COMPILED   │───▶│  EQUIPPED   │
│ (Boss Drop) │    │ (Available) │    │ (In Deck)   │
└─────────────┘    └─────────────┘    └─────────────┘
        │                 │                  │
        ▼                 ▼                  ▼
   Drops from      Costs Hash to      Used as weapon
   boss kills      compile            AND as Firewall
```

### Blueprint System

**Acquiring Blueprints:**
- First boss kill per difficulty: Guaranteed blueprint drop
- Subsequent kills: RNG-based chance (higher difficulty = better odds)
- Pity system: Guaranteed drop every 10 kills without one
- Blueprints unlock the ability to compile that Protocol

**Boss Loot Tables:**

| Boss | Guaranteed First Kill | Other Drops |
|------|----------------------|-------------|
| Rogue Process | Burst Protocol (C) | Trace Route (R) |
| Memory Leak | Fork Bomb (E) | Overflow (L) |
| Thermal Runaway | Ice Shard (R) | Null Pointer (L) |
| Packet Worm | Root Access (E) | — |

**Drop Rates by Difficulty:**

| Difficulty | Common | Rare | Epic | Legendary | Total |
|------------|--------|------|------|-----------|-------|
| Easy | 35% | 12% | 0% | 0% | 47% |
| Normal | 40% | 20% | 6% | 2% | 68% |
| Hard | 35% | 25% | 12% | 5% | 77% |
| Nightmare | 30% | 25% | 18% | 10% | 83% |

**Compiling Protocols:**
- Spend Hash to compile a blueprint into a usable Protocol
- Compiled Protocols work in BOTH modes simultaneously
- Can be upgraded 1-10 with diminishing returns scaling: Level N = N^0.6× stats (Lv5 ≈ 2.6×, Lv10 ≈ 4×)

---

## 6. The Mega-Board

The Motherboard is a **3×3 sector grid** (4200×4200 unit canvas) with **9 sectors** that players unlock progressively through boss defeats.

### Sector Grid Layout

```
┌─────────────┬─────────────┬─────────────┐
│     I/O     │    Cache    │   Network   │  Row 2 (Top)
│   (USB/LAN) │  (L2 Cache) │  (Ethernet) │
├─────────────┼─────────────┼─────────────┤
│     GPU     │     CPU     │     PSU     │  Row 1 (Middle) ← STARTER
│  (Graphics) │   (Core)    │   (Power)   │
├─────────────┼─────────────┼─────────────┤
│   Storage   │     RAM     │  Expansion  │  Row 0 (Bottom)
│  (SSD/HDD)  │  (Memory)   │   (Slots)   │
└─────────────┴─────────────┴─────────────┘
```

### Sector Details

| Sector | Theme | Unlock Cost | Hash Bonus | Component Unlock |
|--------|-------|-------------|------------|------------------|
| PSU | Power (Yellow) | FREE | 1.0× | Starter (PSU) |
| RAM | Memory (Blue) | 1,500 Ħ | 1.2× | RAM Component |
| GPU | Graphics (Red) | 2,500 Ħ | 1.4× | GPU Component |
| Cache | Processing (Cyan) | 6,000 Ħ | 1.6× | Cache Component |
| Storage | Storage (Green) | 15,000 Ħ | 1.8× | Storage Component |
| Expansion | Expansion (Orange) | 35,000 Ħ | 2.0× | Expansion Component |
| Network | Network (Purple) | 75,000 Ħ | 2.2× | Network Component |
| I/O | Peripherals (Pink) | 150,000 Ħ | 2.5× | I/O Component |
| CPU | Core (Gold) | 300,000 Ħ | 3.0× | CPU Component (Final) |

**Total to unlock all sectors:** ~587,000 Ħ

### V1 MVP Boundary

The initial release includes the first 4 sectors: **PSU → RAM → GPU → Cache** (indices 0-3). Sectors beyond Cache display "Coming Soon" in the UI. The CPU core sector is always active as the central defense target regardless of this boundary.

### Sector Unlock Progression

Sectors unlock in a specific order tied to boss encounters:

```
PSU (Free) → RAM → GPU → Cache → Storage → Expansion → Network → I/O → CPU
```

**How Unlocking Works:**
1. **Boss Defeat** → Next sector becomes **visible** (ghost state)
2. **Pay Hash Cost** → Sector becomes **active** and playable
3. **Component Unlock** → Each sector unlocks its matching component upgrade

### Lane System

Each non-CPU sector has one enemy lane with a unique path layout:
- **PSU (Starter):** East side, double-zigzag path
- **RAM:** South side, compact step path
- **GPU:** West side, wide shallow arc
- **Cache:** North side, deep sweep
- **Expansion:** Bottom-right, diagonal L
- **Storage:** Bottom-left, diagonal L
- **Network:** Top-right, diagonal L
- **I/O:** Top-left, diagonal L

Tower slots are dynamically generated along paths (80-unit spacing, 100-unit distance from path center, on both sides). Additional CPU defense slots surround the central CPU core.

### Blocker System

Players can place blockers at path intersections to reroute enemies:
- Start with 3 blocker slots
- Blockers appear as octagon nodes at intersection points
- Strategic tool for channeling enemies through tower kill zones

### PCB Aesthetics

Each sector features:
- Color-coded copper traces matching theme
- Themed component graphics (capacitors, chips, traces)
- Glow effects on active paths
- Ghost/dimmed appearance when locked but visible
- Hidden appearance when not yet discovered

---

## 7. Component Upgrades

**9 Components**, each unlocked by its corresponding sector. All components have 10 upgrade levels.

**Upgrade Cost Formula:** `baseCost × 2^(level-1)`

### Component Overview

| Component | Sector | Effect | Base Cost |
|-----------|--------|--------|-----------|
| **PSU** | PSU | Power capacity (300W → 2300W) | 400 Ħ |
| **Storage** | Storage | Hash capacity (15K base, 1.8× per level) | 350 Ħ |
| **RAM** | RAM | Efficiency regen (1× → 2×) + player health | 350 Ħ |
| **GPU** | GPU | Global tower damage (1× → 1.5×) | 500 Ħ |
| **Cache** | Cache | Global attack speed (1× → 1.3×) | 450 Ħ |
| **Expansion** | Expansion | Extra tower slots (+1/+2/+3) | 700 Ħ |
| **I/O** | I/O | Pickup radius (1× → 2.5×) | 400 Ħ |
| **Network** | Network | Global Hash multiplier (1× → 1.5×) | 800 Ħ |
| **CPU** | CPU | Hash generation rate (1.5× per level) | 600 Ħ |

### PSU (Power Capacity)

| Level | Capacity | Cost |
|-------|----------|------|
| 1 | 300W | Starter |
| 2 | 400W | 400 Ħ |
| 3 | 550W | 800 Ħ |
| 5 | 900W | 3,200 Ħ |
| 10 | 2,300W | 102,400 Ħ |

### CPU Tier Upgrades

Separate from the CPU Component, the CPU Tier system provides global income multipliers:

| Tier | Display | Multiplier | Cost |
|------|---------|------------|------|
| 1 | CPU 1.0 | 1× | Default |
| 2 | CPU 2.0 | 2× | 750 Ħ |
| 3 | CPU 3.0 | 4× | 5,000 Ħ |
| 4 | CPU 4.0 | 8× | 25,000 Ħ |
| 5 | CPU 5.0 | 16× | 500,000 Ħ |

CPU Tier stacks multiplicatively with CPU Component level. A max CPU component (~38Ħ/s) at Tier 5 (16×) generates ~608Ħ/s.

---

## 8. Core Mechanics

### 8.1 Efficiency System

Efficiency determines Hash income rate.

```
Hash Income = Base Rate × Efficiency% × CPU Multiplier × Network Multiplier × CPU Tier
```

**How Efficiency Works:**
- Starts at 100%
- Each virus reaching CPU: -5% (via leak counter)
- Regenerates over time (+1% per interval)
- RAM upgrades speed up regeneration

**At 0% Efficiency:**
- System Freeze state triggers
- All gameplay paused
- Player must recover

### 8.2 System Freeze & Recovery

When efficiency hits 0%:

```
┌─────────────────────────────────────┐
│         SYSTEM FREEZE               │
│                                     │
│   [Flush Memory] - Pay 10% Hash    │
│   [Manual Override] - Free (game)   │
└─────────────────────────────────────┘
```

**Recovery Options:**

1. **Flush Memory**
   - Costs 10% of current Hash (minimum 1 Ħ)
   - Instantly restores 50% efficiency
   - Clears all enemies on screen
   - Quick but expensive

2. **Manual Override**
   - Free (no Hash cost)
   - 30-second survival mini-game
   - 3 HP (hits), dodge 3 hazard types (projectile, expanding, sweep)
   - Difficulty escalates every 5 seconds (spawn interval 1.5s → 0.5s)
   - Success: 100% efficiency restored
   - Failure: Return to freeze screen

### 8.3 Tower Placement

**Drag-to-Place System:**
1. Drag Protocol card from bottom deck
2. Valid slots highlight on map
3. Drop on slot to place
4. Tower costs Hash + allocates Power

**Power Budget:**
- Each tower has Power draw
- Cannot exceed PSU capacity
- Selling tower frees Power (partial refund)

**Sector Pause:**
- Individual lanes can be paused (no enemies spawn)
- Allows safe tower repositioning

### 8.4 Overclock System

Voluntary risk/reward mechanic in TD mode:

| Parameter | Value |
|-----------|-------|
| Duration | 45 seconds |
| Hash Multiplier | 4× generation |
| Threat Growth | 14× (guarantees boss spawn) |
| Power Demand | 1.5× (may disable lowest-rarity towers) |

- Cannot activate during active boss encounter
- Disabled towers are restored when overclock ends
- Creates an intentional boss encounter through threat acceleration

### 8.5 Spawning Systems

Tower Defense uses continuous idle spawning with threat-based scaling:

**Idle Spawn System (Primary)**

| Threat Level | Enemies Available | Spawn Scaling |
|--------------|-------------------|---------------|
| 0+ (Start) | Basic | Slow |
| 2+ (Low) | + Fast | Normal |
| 4+ (Medium) | + Swarm (voidminion) | Normal |
| 5+ (High) | + Tank | Faster |
| 8+ (Critical) | + Elite | Fast |
| 10+ (Extreme) | + Boss class | Very Fast |

- Threat level increases at 0.01/sec (online), 0.001/sec (offline)
- Enemy HP scales +8%/threat, speed +2%/threat, damage +3%/threat
- Spawn rate scales with active lane count: `sqrt(laneCount)`

**Super Virus Boss Spawns:**

- Spawn at threat milestones every 6 threat levels (6, 12, 18, 24...)
- Walk toward CPU, immune to tower damage
- Player taps to engage in full boss arena fight
- 180-second cooldown after boss victory

---

## 9. Progression Flow

### Early Game (First Session)

1. Start with PSU sector (starter) in TD mode
2. Place Kernel Pulse towers (starter Protocol, pre-compiled)
3. Earn Hash passively from efficiency
4. Defeat first Super Virus boss → Unlock RAM sector visibility
5. Pay 1,500 Ħ to unlock RAM sector
6. Fight Rogue Process boss for blueprint drops

### Mid Game (Hours 1-5)

1. Unlock sectors through boss defeats (RAM → GPU → Cache)
2. Upgrade PSU to place more towers
3. Farm bosses for Protocol blueprints
4. Compile new Protocols (Burst Protocol, Trace Route, Ice Shard)
5. Build specialized tower compositions per sector
6. Merge duplicate towers for star upgrades
7. Upgrade CPU tiers for income multipliers

### Late Game (Hours 5+)

1. Unlock remaining sectors (Storage → Expansion → Network → I/O → CPU)
2. Max out all 9 component upgrades
3. Farm Nightmare boss difficulty for legendary blueprints
4. Complete Protocol collection (all 8 protocols at level 10)
5. Optimize tower layouts for maximum Hash income
6. Push high threat levels in idle TD
7. Reach CPU Tier 5 (16× income)

### The Core Loop

```
┌─────────────────────────────────────────────────┐
│              TOWER DEFENSE MODE                  │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐    │
│  │  BUILD   │──▶│  DEFEND  │──▶│   EARN   │    │
│  │ (Towers) │   │  (Idle)  │   │  (Hash)  │    │
│  └──────────┘   └──────────┘   └──────────┘    │
│       ▲                              │          │
│       └──────────────────────────────┘          │
└─────────────────────────────────────────────────┘
                       │
                       │ Need Blueprints?
                       │ Want Hash jackpot?
                       ▼
             ┌─────────────────────┐
             │   BOSS ENCOUNTERS   │
             │  ┌────────┐         │
             │  │ FIGHT  │──▶ Hash │
             │  │ (Raid) │ + Proto │
             │  └────────┘         │
             └─────────────────────┘
```

### Unlock Progression

**Sector Unlock Order (Boss-Triggered):**
```
PSU (Free) → RAM (1.5K) → GPU (2.5K) → Cache (6K) → Storage (15K)
                                                         ↓
CPU (300K) ← I/O (150K) ← Network (75K) ← Expansion (35K)
```

**How Sectors Unlock:**
1. Defeat a sector's Super Virus boss → Next sector becomes **visible** (ghosted)
2. Pay Hash cost → Sector becomes **active**
3. Active sector → Component upgrade available

**Protocol Unlock Order:**
1. Kernel Pulse (starter, free, compiled)
2. Beat bosses → Blueprint drops based on loot tables
3. Compile blueprints with Hash (100-800 Ħ by rarity)
4. Level up Protocols 1-10 with Hash (exponential cost: base × 2^level)

---

## 10. UI Structure

### Main Hub: Motherboard View

The game uses a **single main view** (Motherboard) as the central gameplay area. Additional features are accessed via **sheets and modals**.

| Element | Type | Purpose |
|---------|------|---------|
| **Motherboard** | Main View | Primary TD gameplay |
| **System Menu** | Sheet | Access Arsenal, Upgrades, Settings |
| **Arsenal** | Sheet Tab | Protocol collection & management |
| **Upgrades** | Sheet Tab | Component upgrades per sector |
| **Boss Select** | Modal | Choose boss & difficulty |
| **Upgrade Modal** | Modal | Protocol level-up confirmation |
| **Boss Loot** | Modal | Post-boss loot reveal experience |

### Motherboard HUD

```
┌─────────────────────────────────────────────────┐
│  [Menu]    ⚡ 380/650W    Ħ 12,450    95%       │
├─────────────────────────────────────────────────┤
│                                                 │
│           [3×3 SECTOR GRID]                     │
│                                                 │
│    ┌─────┬─────┬─────┐                         │
│    │ I/O │Cache│ Net │                         │
│    ├─────┼─────┼─────┤                         │
│    │ GPU │ CPU │ PSU │  ← Active Sector        │
│    ├─────┼─────┼─────┤                         │
│    │Store│ RAM │ Exp │                         │
│    └─────┴─────┴─────┘                         │
│                                                 │
│  [Overclock]                      [Pause Lane]  │
├─────────────────────────────────────────────────┤
│  Protocol Deck (drag to place)                  │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐                   │
│  │ KP │ │ BP │ │ TR │ │ IS │                   │
│  │50W │ │75W │ │100W│ │80W │                   │
│  └────┘ └────┘ └────┘ └────┘                   │
└─────────────────────────────────────────────────┘
```

### Boss Mode HUD

```
┌─────────────────────────────────────────────────┐
│  ❤️❤️❤️    BOSS: ROGUE PROCESS    Phase 2/4     │
├─────────────────────────────────────────────────┤
│                                                 │
│            [1200×900 ARENA]                     │
│                                                 │
│       [8 Destructible Pillars]                  │
│                                                 │
│         [Boss] ←→ [Player]                      │
│                                                 │
├─────────────────────────────────────────────────┤
│                                                 │
│              [JOYSTICK]                         │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

## 11. Technical Architecture

### Core Technologies

| Component | Technology |
|-----------|------------|
| Engine | SpriteKit (2D) |
| UI | SwiftUI |
| State | ObservableObject pattern |
| Storage | UserDefaults + Codable |
| Haptics | UIImpactFeedbackGenerator |
| Audio | AVAudioEngine (procedural synthesis, no asset files) |
| Analytics | Mixpanel (EU endpoint, opt-in, no PII) |

### Performance Targets

- 60fps gameplay
- Sector-based culling (LOD) for large board
- Node pooling for enemies, projectiles, and boss hazards
- Per-sound throttling for procedural audio
- Smooth camera with inertia

### Key Systems

| System | File | Purpose |
|--------|------|---------|
| Game State | GameState.swift | Boss mode game state |
| TD Session | TDSessionState.swift | Tower defense session state |
| Protocols | Protocol.swift | Dual-purpose weapon/tower cards |
| Boss Encounters | BossEncounter.swift | 4 bosses with unlock costs |
| Mega-Board | MegaBoardTypes.swift | 3×3 sector grid system |
| Component Types | ComponentTypes.swift | 9 component upgrade definitions |
| Balance Config | BalanceConfig.swift | Centralized tuning |
| Sector Unlock | SectorUnlockSystem.swift | Boss-triggered progression |
| Idle Spawning | IdleSpawnSystem.swift | Threat-based enemy spawning |
| Tower System | TowerSystem.swift | Tower targeting & attacks |
| TD Boss System | TDBossSystem.swift | Super Virus events in TD mode |
| Overclock | OverclockSystem.swift | Risk/reward hash boost |
| Boss AIs | CyberbossAI, VoidHarbingerAI, OverclockerAI, TrojanWyrmAI | 4-phase boss mechanics |
| Blocker System | BlockerSystem.swift | Path intersection rerouting |
| Manual Override | ManualOverrideSystem.swift | Freeze recovery minigame |
| Blueprint Drops | BlueprintDropSystem.swift | Boss loot tables |
| Localization | L10n.swift | EN/DE string localization |
| Storage | StorageService.swift | Persistence & offline earnings |
| Audio | AudioManager.swift | Procedural sound synthesis |
| Analytics | AnalyticsService.swift | Mixpanel event tracking |

### File Structure

```
SystemReboot/
├── App/                          # SwiftUI app entry & state
│   ├── AppState.swift
│   ├── AppState+Tutorial.swift
│   ├── ContentView.swift
│   └── SystemRebootApp.swift
├── Core/
│   ├── Config/                   # All balance & design values
│   │   ├── BalanceConfig.swift
│   │   ├── DesignSystem.swift
│   │   ├── GameConfig.swift
│   │   └── SectorSchematics.swift
│   ├── Localization/
│   │   └── L10n.swift
│   ├── Systems/
│   │   ├── BlueprintDropSystem.swift
│   │   ├── MegaBoardSystem.swift
│   │   └── SectorUnlockSystem.swift
│   ├── Types/                    # Data structures
│   │   ├── BossEncounter.swift
│   │   ├── BossStates.swift
│   │   ├── ComponentTypes.swift
│   │   ├── EntityIDs.swift
│   │   ├── GameTypes.swift
│   │   ├── MegaBoardTypes.swift
│   │   ├── PlayerProfile.swift (+Inventory, +Progression, +Unlocks)
│   │   ├── Protocol.swift
│   │   ├── TDSessionState.swift
│   │   ├── TDTypes.swift
│   │   └── WaveTypes.swift
│   └── Utils/
│       ├── SpatialGrid.swift
│       ├── ObjectPool.swift
│       └── MathUtils.swift
├── GameEngine/
│   ├── Bosses/
│   │   ├── CyberbossAI.swift
│   │   ├── VoidHarbingerAI.swift
│   │   ├── OverclockerAI.swift
│   │   └── TrojanWyrmAI.swift
│   ├── Simulation/               # Balance testing bots
│   │   ├── BossSimulator.swift
│   │   ├── TDSimulator.swift
│   │   └── SimulationRunner.swift
│   ├── Systems/
│   │   ├── ArenaSystem.swift
│   │   ├── BlockerSystem.swift
│   │   ├── BossFightCoordinator.swift
│   │   ├── CoreSystem.swift
│   │   ├── EnemySystem.swift
│   │   ├── FreezeRecoveryService.swift
│   │   ├── GameRewardService.swift
│   │   ├── IdleSpawnSystem.swift
│   │   ├── ManualOverrideSystem.swift
│   │   ├── OfflineSimulator.swift
│   │   ├── OverclockSystem.swift
│   │   ├── PlayerSystem.swift
│   │   ├── TDBossSystem.swift
│   │   ├── TDCollisionSystem.swift
│   │   ├── TDGameLoop.swift
│   │   ├── TowerPlacementService.swift
│   │   ├── TowerSystem.swift
│   │   └── WeaponSystem.swift
│   └── GameState.swift
├── Rendering/
│   ├── TDGameScene.swift (+Actions, +Background, +Effects, +Input, etc.)
│   ├── GameScene.swift (+BossRendering, +Effects, +EntityRendering)
│   ├── BossRenderingManager.swift (+Cyberboss, +VoidHarbinger, +Overclocker, +TrojanWyrm)
│   ├── TowerVisualFactory.swift (+Bodies, +Details, +Platforms, +Indicators)
│   ├── TowerAnimations.swift (+Idle, +Combat, +Special)
│   ├── MegaBoardRenderer.swift
│   ├── CameraController.swift
│   ├── NodePool.swift
│   ├── ParticleFactory / ParticleEffectService
│   └── ScrollingCombatText.swift
├── Services/
│   ├── AnalyticsService.swift
│   ├── AudioManager.swift
│   ├── HapticsService.swift
│   ├── NotificationService.swift
│   └── StorageService.swift
├── UI/
│   ├── Tabs/
│   │   ├── SystemTabView.swift
│   │   ├── MotherboardView.swift
│   │   ├── EmbeddedTDGameView.swift (+Controller, +BossState, +Drag)
│   │   ├── ArsenalView.swift
│   │   ├── UpgradesView.swift
│   │   └── SystemFreezeOverlay.swift
│   ├── Game/
│   │   ├── BossGameView.swift
│   │   ├── GameContainerView.swift
│   │   ├── ManualOverrideView.swift
│   │   ├── UpgradeModalView.swift
│   │   └── VirtualJoystick.swift
│   └── Components/
│       ├── IntroSequenceView.swift
│       ├── WelcomeBackModal.swift
│       ├── BossLootModal.swift
│       ├── SettingsSheet.swift
│       └── TutorialHintOverlay.swift
└── Resources/
    └── Localizable.xcstrings
```

---

## 12. Design Principles & Safeguards

These principles prevent common design traps and ensure a fun, fair experience.

### DO NOT: Economy Buildings Competing for Tower Slots

**The Trap:** If players must choose between placing a Hard Drive (income) or a Firewall (defense) on the same tile, they will always choose defense. This makes the "city-building" aspect feel like a punishment.

**Our Solution: Global Upgrades**

Economy buildings (all 9 components: PSU, Storage, RAM, GPU, Cache, Expansion, I/O, Network, CPU) are **global upgrades purchased through the UI**, not placeable items. Tower slots are used **exclusively** for Firewalls (Protocol towers).

```
Tower Slots → Defense only (Firewalls/Protocols)
Global Upgrades → Economy (9 components per sector)
```

This means players never sacrifice defense capability for economy. They build their hardware through the Upgrades tab, then deploy software (Protocols) as Firewalls on the board.

---

### DO NOT: Simulate Death Offline

**The Trap:** If a player leaves at 100% efficiency and the game simulates waves while they're gone, they might return to find 0 Hash earned because "Wave 50 would have killed them." This leads to uninstalls.

**Our Solution: Snapshot Logic**

The offline system uses a **simplified simulation** of the player's state:

- Efficiency snapshot based on defense strength vs. threat level
- Time capped at 24 hours
- Earnings at 20% of active rate
- **You cannot die while not playing**

Welcome Back modal shows: time away, Hash earned, leaks occurred, threat change.

---

### DO NOT: Dynamic Pathfinding (Maze Building)

**The Trap:** If placing a tower blocks enemy paths, you need complex A* pathfinding that eats CPU and causes bugs (e.g., players completely walling off the CPU).

**Our Solution: Fixed Paths (The Data Bus)**

The copper traces are **permanent roads**. Towers are placed in slots **adjacent** to paths, never on them. Blockers at intersections provide limited rerouting.

```
┌─────────────────────────────────────────┐
│  [Slot]      PATH      [Slot]           │
│    ↓          ↓          ↓              │
│   Tower ←→ Enemies ←→ Tower             │
│             (Fixed)                     │
│              [Blocker] ← Reroute point  │
└─────────────────────────────────────────┘
```

**Benefits:**
- Guaranteed 60fps performance
- No "invalid maze" edge cases
- Predictable gameplay
- Clear visual language (traces = enemy roads)

---

### MUST DO: Protocol Synergy (The Secret Sauce)

**The Opportunity:** When upgrading a Protocol, it enhances **both** the Tower (TD) and Weapon (Boss) simultaneously.

**Our Implementation:**

```swift
struct Protocol {
    var level: Int  // Single level affects both modes (1-10)

    // Diminishing returns: level^0.6
    var statMultiplier: CGFloat {
        pow(CGFloat(level), 0.6)  // Lv5 ≈ 2.6×, Lv10 ≈ 4×
    }
}
```

**Why This Matters:**
- Every upgrade feels doubly rewarding
- Players test upgrades in both TD and Boss modes
- Boss blueprints directly improve TD defenses
- Creates excitement: "New Protocol! Let me try it as a tower!"

---

### MUST DO: System Freeze as Gameplay (Not Just Penalty)

**The Opportunity:** Instead of a simple "Pay to Restore" button, the 0% efficiency state becomes a fun mini-game.

**Our Implementation: Manual Override**

```
Efficiency hits 0%
    → System Freezes (all gameplay paused)
    → Two recovery options presented
    → "Flush Memory" (costs 10% Hash, restores 50%)
    → "Manual Override" (free, 30-sec minigame, restores 100%)
    → Player chooses risk vs cost
```

**Manual Override Mini-Game:**
- Dodge 3 hazard types (projectile, expanding zones, sweep walls)
- Survive 30 seconds
- 3-hit health system
- Difficulty escalates every 5 seconds
- Free (no Hash cost), rewards full 100% efficiency on success

**Why This Matters:**
- Turns failure into fun gameplay
- Gives skill-based recovery option (100% vs 50%)
- Creates memorable moments
- Players don't feel punished for struggling

---

### Technical: Sector-Based Rendering

**The Trap:** A single large texture will choke SpriteKit.

**Our Solution: 3×3 Sector Grid with LOD**

```swift
// Each sector is a separate SKNode subtree
// LOD culling hides off-screen detail
// Node pooling for enemies, projectiles, effects
```

**Rules:**
- Each sector is its own SKNode
- Hidden sectors: Not yet discovered (invisible)
- Ghost sectors: Discovered but locked (dimmed, can pay to unlock)
- Active sectors: Unlocked and playable (full rendering)
- LOD system reduces detail for distant sectors

---

## Summary

**System: Reboot** combines idle tower defense with raid-style boss combat through:

1. **Unified Currency** - Hash is earned from all modes, Power limits tower capacity
2. **Two Modes** - TD (passive income + building) and Boss Encounters (blueprints + jackpots)
3. **Protocol System** - 8 protocols work as Firewalls (TD) AND Weapons (Boss) with unified upgrades
4. **Mega-Board** - 3×3 sector grid (9 sectors) with boss-triggered progressive unlocks
5. **9 Components** - Each sector unlocks a unique component upgrade (PSU, Storage, RAM, GPU, Cache, Expansion, I/O, Network, CPU)
6. **CPU Tiers** - 5-tier global income multiplier system (1× to 16×)
7. **Blueprint System** - Boss kills drop blueprints to unlock new Protocols (4 bosses, 4 difficulties)
8. **Threat Scaling** - Idle TD difficulty increases over time with new enemy types
9. **4 Raid Bosses** - 4-phase boss fights with unique mechanics (Rogue Process, Memory Leak, Thermal Runaway, Packet Worm)
10. **Tower Merging** - Combine duplicate towers for star upgrades (up to 8× stats)
11. **Overclock** - Voluntary 45-second risk/reward mechanic (4× Hash, guarantees boss spawn)

### Design Safeguards

| Trap | Solution |
|------|----------|
| Economy vs Defense slots | Global upgrades (no competition) |
| Offline death simulation | Snapshot logic (can't die offline) |
| Dynamic maze pathfinding | Fixed paths + blockers |
| Disconnected game modes | Protocol synergy (one upgrade, both modes) |
| Punishing failure states | Manual Override mini-game (fun recovery) |
| Grinding for unlocks | Boss blueprints with pity system |

The game creates meaningful choices at every stage, requiring players to balance building, defending, and hunting bosses—without falling into common design traps that frustrate players.

---

*See [GAME_BALANCING_BLUEPRINT.md](./GAME_BALANCING_BLUEPRINT.md) for detailed economy tables and balancing numbers.*
