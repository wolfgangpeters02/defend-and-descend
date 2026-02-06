# System: Reboot - Game Design Document

> **Version:** 4.0 (Sector Grid & Component Expansion)
> **Last Updated:** 2026-02-04
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

### Three Modes, One Goal

| Mode | Genre | Purpose | Primary Reward |
|------|-------|---------|----------------|
| **Tower Defense** (Motherboard) | Idle TD / City Builder | Build defenses, earn passive Hash | Hash (passive) |
| **Survivor** (Memory Core) | Twin-Stick Survivor | Survive waves, earn Hash | Hash + XP |
| **Boss Encounters** (Cathedral) | Raid-Style Combat | Defeat bosses for blueprints | Hash + Blueprints |

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

**Earning Sources:**
- **Tower Defense:** Passive CPU generation + enemy kills
- **Survivor Mode:** Pickup drops + time bonus (×0.5 if died, ×1.0 if extracted)
- **Boss Fights:** Fixed rewards by difficulty (250Ħ Easy → 3000Ħ Nightmare)
- **Offline:** Passive earnings while app is closed (capped at 8 hours)

**Spending:**
- Tower placement costs
- Global upgrades (9 components: PSU, Storage, RAM, GPU, Cache, Expansion, I/O, Network, CPU)
- Sector unlocks (25K-500K Ħ per sector)
- Protocol compilation (100-800 Ħ by rarity)

**Storage:** Capped by Storage component level (50,000Ħ base → 5M at max level)

```
Example:
Storage Capacity: 500,000 Ħ
Current Hash: 185,000 Ħ
Base Income: Based on efficiency % and CPU level
```

### Power (Watts) ⚡

**Role:** BUILD LIMIT - determines total tower capacity.

- Power is a **capacity**, not consumed
- Each tower allocates Power while placed
- PSU upgrades increase the ceiling (450W → 3200W)
- Cannot place towers if total would exceed capacity

```
Example:
PSU: 650W Capacity
Currently Used: 520W
Available: 130W

Tower costs 100W → CAN BUILD
Tower costs 200W → CANNOT BUILD (need PSU upgrade)
```

### XP & Leveling

**Role:** CHARACTER PROGRESSION - permanent stat bonuses.

- Earned from kills, survival time, and victories
- Unified across all game modes
- Higher levels unlock more Protocol slots and stat bonuses

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
- Zero-Day boss events (periodic threat)

**Idle Spawn System:**
- Continuous enemy spawning based on threat level
- Threat increases over time, introducing new enemy types
- Enemy variety: Basic → Fast → Swarm → Tank → Elite → Boss

**When to Play:**
- Passive Hash accumulation
- Relaxed tower-building gameplay
- Testing tower layouts and compositions

### 4.2 Survivor Mode: Memory Core

**Genre:** Twin-Stick Survivor (Vampire Survivors style)

**What You Do:**
- Enter the Memory Core arena
- Control the Cursor (player avatar)
- Survive escalating virus waves
- Collect Hash pickups
- Experience survival events

**Key Features:**
- Virtual joystick movement
- Auto-targeting/auto-fire (equipped Protocol → Weapon)
- Survival events (Memory Surge, Buffer Overflow, Virus Swarm, etc.)
- Extraction decision (leave early = safe, stay longer = more rewards)

**Survival Events (7 types, tiered by difficulty):**

| Event | Tier | Duration | Effect |
|-------|------|----------|--------|
| Memory Surge | 1 | 8s | +50% speed, 2× spawn rate |
| Buffer Overflow | 1 | 15s | Arena shrinks (25 DPS kill zone) |
| Cache Flush | 2 | 3s | Clears all enemies on screen |
| Thermal Throttle | 2 | 12s | -30% speed, +50% damage taken |
| Data Corruption | 3 | 10s | Obstacles become hazards (15 DPS) |
| Virus Swarm | 3 | 5s | 50 fast weak enemies (5 HP each) |
| System Restore | 3 | 8s | Healing zone spawns (5 HP/sec) |

**Event Timing:** First at 60s, then every 40-60s based on survival time.

**When to Play:**
- Active Hash farming
- Action gameplay
- Testing weapon builds

### 4.3 Boss Encounters: The Cathedral

**Genre:** Raid-Style Boss Combat

**What You Do:**
- Select a boss and difficulty level
- Fight through 4-phase encounters
- Learn attack patterns and mechanics
- Earn blueprints for new Protocols

**Difficulty Levels:**

| Difficulty | Boss HP | Boss Damage | Player Stats | Hash Reward |
|------------|---------|-------------|--------------|-------------|
| Easy | 1.0× | 0.5× | 2.0× HP/DMG | 250 Ħ |
| Normal | 1.0× | 1.0× | 1.5× HP/DMG | 500 Ħ |
| Hard | 1.5× | 1.25× | 1.0× | 1,500 Ħ |
| Nightmare | 2.5× | 1.8× | 1.0× | 3,000 Ħ |

**Current Bosses:**

**Cyberboss** - Mode-switching melee/ranged hybrid
- Phase 1: Alternates melee chase and ranged bombardment
- Phase 2: Spawns minions while mode-switching
- Phase 3: Stationary, spawns damage puddles
- Phase 4: Rotating laser beams + rapid puddles

**Void Harbinger** - Raid-style mechanics boss
- Phase 1: Void zones + shadow bolt volleys + minions
- Phase 2: Invulnerable until 4 pylons destroyed
- Phase 3: Rotating void rifts + gravity wells + meteors
- Phase 4: Shrinking arena + teleportation + enrage

**When to Play:**
- Need Protocol blueprints
- Want challenging combat
- Testing builds against specific mechanics

### Mode Switching Motivation

| Situation | Problem | Solution |
|-----------|---------|----------|
| "Can't build more towers" | Power limit | Upgrade PSU component (costs Hash) |
| "Can't afford upgrades" | Not enough Hash | Play Survivor or wait for TD income |
| "Need new Protocol" | Missing blueprint | Defeat bosses for blueprint drops |
| "Want to unlock next sector" | Need boss kill | Beat boss to trigger sector visibility |
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
    isCompiled: Bool        // Requires blueprint + Hash to compile

    firewallStats: {        // TD Mode stats
        damage, range, attackSpeed, splash, slow, chain
    }

    weaponStats: {          // Active Mode stats
        damage, attackSpeed, projectileCount, pierce
    }
}
```

### The 8 Core Protocols

| Protocol | Rarity | Firewall Style | Weapon Style | Special Ability |
|----------|--------|----------------|--------------|-----------------|
| Kernel Pulse | Common | Single-target | Pistol | Homing |
| Burst Protocol | Common | Multi-shot splash | Shotgun | Explosive |
| Trace Route | Rare | Long-range sniper | Railgun | Pierce (3 targets) |
| Ice Shard | Rare | Slow effect | Frost spray | Freeze (0.5× slow) |
| Fork Bomb | Epic | Multi-projectile | Spread shot | 3 projectiles |
| Root Access | Epic | High damage burst | Heavy striker | Critical hits |
| Overflow | Legendary | Chain attack | Arc weapon | Chain to 3 enemies |
| Null Pointer | Legendary | Execute (instakill) | Delete beam | Execute low HP |

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
- Blueprints unlock the ability to compile that Protocol

**Compiling Protocols:**
- Spend Hash to compile a blueprint into a usable Protocol
- Compiled Protocols work in BOTH modes simultaneously
- Can be upgraded 1-10 with aggressive damage scaling (Level N = N× damage)

---

## 6. The Mega-Board

The Motherboard is a **3×3 sector grid** with **9 sectors** that players unlock progressively through boss defeats.

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

| Sector | Theme | Unlock Cost | Component Unlock |
|--------|-------|-------------|------------------|
| PSU | Power (Yellow) | FREE | Starter (PSU) |
| RAM | Memory (Blue) | 25,000 Ħ | RAM Component |
| GPU | Graphics (Red) | 50,000 Ħ | GPU Component |
| Cache | Processing (Cyan) | 75,000 Ħ | Cache Component |
| Storage | Storage (Green) | 100,000 Ħ | Storage Component |
| Expansion | Expansion (Orange) | 150,000 Ħ | Expansion Component |
| Network | Network (Purple) | 200,000 Ħ | Network Component |
| I/O | Peripherals (Pink) | 300,000 Ħ | I/O Component |
| CPU | Core (Gold) | 500,000 Ħ | CPU Component (Final) |

**Total to unlock all sectors:** 1,475,000 Ħ

### Sector Unlock Progression

Sectors unlock in a specific order tied to boss encounters:

```
PSU (Free) → RAM → GPU → Cache → Storage → Expansion → Network → I/O → CPU
```

**How Unlocking Works:**
1. **Boss Defeat** → Next sector becomes **visible** (ghost state)
2. **Pay Hash Cost** → Sector becomes **active** and playable
3. **Component Unlock** → Each sector unlocks its matching component upgrade

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
| **PSU** | PSU | Power capacity (300W → 2300W) | 500 Ħ |
| **Storage** | Storage | Hash capacity + offline rate | 400 Ħ |
| **RAM** | RAM | Efficiency regen (1× → 2×) + health | 400 Ħ |
| **GPU** | GPU | Global tower damage (1× → 1.5×) | 600 Ħ |
| **Cache** | Cache | Global attack speed (1× → 1.3×) | 550 Ħ |
| **Expansion** | Expansion | Extra tower slots (+0 → +2) | 800 Ħ |
| **I/O** | I/O | Pickup radius (1× → 2.5×) | 450 Ħ |
| **Network** | Network | Global Hash multiplier (prestige) | 1000 Ħ |
| **CPU** | CPU | Hash generation rate (exponential) | 750 Ħ |

### PSU (Power Capacity)

| Level | Capacity | Cost |
|-------|----------|------|
| 1 | 300W | Starter |
| 2 | 500W | 500 Ħ |
| 3 | 700W | 1,000 Ħ |
| 5 | 1,100W | 4,000 Ħ |
| 10 | 2,300W | 128,000 Ħ |

### CPU (Hash Generation)

| Level | Hash/sec | Cost |
|-------|----------|------|
| 1 | 10 Ħ/s | Requires CPU sector |
| 5 | 50 Ħ/s | 6,000 Ħ |
| 10 | 200 Ħ/s | 192,000 Ħ |

### RAM (Efficiency & Health)

| Level | Efficiency Regen | Health Bonus |
|-------|------------------|--------------|
| 1 | 1.0× | +0 |
| 5 | 1.5× | +50 |
| 10 | 2.0× | +100 |

### GPU (Tower Damage)

| Level | Damage Multiplier |
|-------|-------------------|
| 1 | 1.0× |
| 5 | 1.25× |
| 10 | 1.5× |

### Cache (Attack Speed)

| Level | Attack Speed Multiplier |
|-------|------------------------|
| 1 | 1.0× |
| 5 | 1.15× |
| 10 | 1.3× |

### Storage (Hash Capacity)

| Level | Max Storage |
|-------|-------------|
| 1 | 50,000 Ħ |
| 5 | 500,000 Ħ |
| 10 | 5,000,000 Ħ |

### Network (Hash Multiplier)

| Level | Global Hash Bonus |
|-------|-------------------|
| 1 | 1.0× |
| 5 | 1.25× |
| 10 | 1.5× |

### Expansion (Tower Slots)

| Level | Extra Slots |
|-------|-------------|
| 1-3 | +0 |
| 4-6 | +1 |
| 7-10 | +2 |

### I/O (Pickup Radius)

| Level | Pickup Radius |
|-------|---------------|
| 1 | 1.0× |
| 5 | 1.75× |
| 10 | 2.5× |

---

## 8. Core Mechanics

### 8.1 Efficiency System

Efficiency determines Hash income rate.

```
Hash Income = Base Rate × Efficiency% × RAM Multiplier
```

**How Efficiency Works:**
- Starts at 100%
- Each virus reaching CPU: -5%
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
│   [Flush Memory] - Pay 10% Hash     │
│   [Manual Override] - Free (game)   │
└─────────────────────────────────────┘
```

**Recovery Options:**

1. **Flush Memory**
   - Costs 10% of current Hash
   - Instantly restores 50% efficiency
   - Quick but expensive

2. **Manual Override**
   - Free (no Hash cost)
   - 30-second survival mini-game
   - Dodge hazards to restore system
   - Success: 50% efficiency restored
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
- Selling tower frees Power

### 8.4 Spawning Systems

Tower Defense uses two complementary spawning systems:

**Idle Spawn System (Primary)**

Continuous enemy spawning with threat-based scaling:

| Threat Level | Enemies Available | Spawn Rate |
|--------------|-------------------|------------|
| 0-2 (Low) | Basic | Slow |
| 2-4 (Medium) | + Fast | Normal |
| 4-5 | + Swarm (voidminion) | Normal |
| 5-8 (High) | + Tank | Faster |
| 8-10 (Critical) | + Elite | Fast |
| 10+ (Extreme) | + Mini-boss | Very Fast |

- Threat level increases over time
- Enemy stats scale with threat (HP, speed, damage)
- Creates escalating difficulty without discrete waves

**Wave System (Event-Based)**

Traditional wave spawning for special events:

- Zero-Day boss spawns (periodic threat)
- Survival events in Active modes
- Challenge modes with fixed wave counts

**Zero-Day Events:**

Periodic boss spawns in TD mode:
- Spawns every 120-180 seconds
- Cannot be damaged by towers
- Drains efficiency (2%/sec) while active
- Must switch to Active mode to defeat

---

## 9. Progression Flow

### Early Game (First Session)

1. Start with PSU sector (starter) in TD mode
2. Place Kernel Pulse towers (starter Protocol)
3. Earn Hash passively from efficiency
4. Defeat first boss → Unlock RAM sector visibility
5. Pay 25,000 Ħ to unlock RAM sector
6. Try Survivor mode for faster Hash

### Mid Game (Hours 1-5)

1. Unlock sectors through boss defeats (RAM → GPU → Cache → Storage)
2. Upgrade PSU to place more towers
3. Farm bosses for Protocol blueprints
4. Compile new Protocols (Burst Protocol, Trace Route, Ice Shard)
5. Build specialized tower compositions per sector

### Late Game (Hours 5+)

1. Unlock all 9 sectors (total 1.475M Ħ)
2. Max out all 9 component upgrades
3. Farm Nightmare boss difficulty for legendary blueprints
4. Complete Protocol collection (all 8 protocols at level 10)
5. Optimize tower layouts for maximum Hash income
6. Push high threat levels in idle TD

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
           │                    │
           │ Need Hash fast?    │ Need Blueprints?
           ▼                    ▼
┌─────────────────────┐  ┌─────────────────────┐
│   SURVIVOR MODE     │  │   BOSS ENCOUNTERS   │
│  ┌────────┐         │  │  ┌────────┐         │
│  │ FIGHT  │──▶ Hash │  │  │ FIGHT  │──▶ Hash │
│  │ (Skill)│         │  │  │ (Raid) │ + Proto │
│  └────────┘         │  │  └────────┘         │
└─────────────────────┘  └─────────────────────┘
```

### Unlock Progression

**Sector Unlock Order (Boss-Triggered):**
```
PSU (Free) → RAM (25K) → GPU (50K) → Cache (75K) → Storage (100K)
                                                         ↓
CPU (500K) ← I/O (300K) ← Network (200K) ← Expansion (150K)
```

**How Sectors Unlock:**
1. Defeat a boss → Next sector becomes **visible** (ghosted)
2. Pay Hash cost → Sector becomes **active**
3. Active sector → Component upgrade available

**Protocol Unlock Order:**
1. Kernel Pulse (starter, free, compiled)
2. Beat bosses → Blueprint drops based on loot tables
3. Compile blueprints with Hash (100-800 Ħ by rarity)
4. Level up Protocols 1-10 with Hash (base × 2^level)

---

## 10. UI Structure

### Main Hub: System Tab

The game uses a **single main view** (System Tab) with the motherboard as the central gameplay area. Additional features are accessed via **sheets and modals**.

| Element | Type | Purpose |
|---------|------|---------|
| **Motherboard** | Main View | Primary TD gameplay |
| **System Menu** | Sheet | Access Arsenal, Settings, Stats |
| **Arsenal** | Sheet | Protocol collection & management |
| **Sector Detail** | Modal | Component upgrades per sector |
| **Boss Select** | Modal | Choose boss & difficulty |
| **Upgrade Modal** | Modal | Protocol level-up confirmation |

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
├─────────────────────────────────────────────────┤
│  Protocol Deck (drag to place)                  │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐                   │
│  │ KP │ │ BP │ │ TR │ │ IS │                   │
│  │50W │ │75W │ │100W│ │80W │                   │
│  └────┘ └────┘ └────┘ └────┘                   │
└─────────────────────────────────────────────────┘
```

### Active Mode HUD (Survival/Boss)

```
┌─────────────────────────────────────────────────┐
│  ❤️❤️❤️    MODE: SURVIVAL    Ħ 1,247   ⏱ 2:34  │
├─────────────────────────────────────────────────┤
│                                                 │
│            [GAME AREA]                          │
│                                                 │
│        [Event Warning Banner]                   │
│        "VIRUS SWARM INCOMING"                   │
│                                                 │
├─────────────────────────────────────────────────┤
│                                                 │
│              [JOYSTICK]        [Extract]        │
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

### Performance Targets

- 60fps gameplay
- Sector culling for large board
- Efficient particle systems
- Smooth camera with inertia

### Key Systems

| System | File | Purpose |
|--------|------|---------|
| TD Game State | TDTypes.swift | Tower defense state model |
| Active Game State | GameTypes.swift | Survivor/boss state model |
| Protocols | Protocol.swift | Dual-purpose weapon/tower cards |
| Mega-Board | MegaBoardTypes.swift | 3×3 sector grid system |
| Global Upgrades | GlobalUpgrades.swift | 9 component upgrades |
| Balance Config | BalanceConfig.swift | Centralized tuning (1600+ lines) |
| Sector Unlock | SectorUnlockSystem.swift | Boss-triggered progression |
| Idle Spawning | IdleSpawnSystem.swift | Threat-based enemy spawning |
| Tower System | TowerSystem.swift | Tower targeting & attacks |
| TD Boss System | TDBossSystem.swift | Zero-Day events in TD mode |
| Boss AI | CyberbossAI.swift, VoidHarbingerAI.swift | 4-phase boss mechanics |
| Survival Events | SurvivalArenaSystem.swift | 7 event types |
| Blueprint Drops | BlueprintDropSystem.swift | Boss loot tables |
| Localization | L10n.swift | EN/DE string localization |
| Storage | StorageService.swift | Persistence & offline earnings |

### File Structure

```
SystemReboot/
├── App/                          # SwiftUI app entry & state
│   ├── AppState.swift
│   ├── ContentView.swift
│   └── SystemRebootApp.swift
├── Core/
│   ├── Config/                   # All balance & design values
│   │   ├── BalanceConfig.swift   # Master config (1655 lines)
│   │   ├── DesignSystem.swift    # UI constants
│   │   ├── GameConfig.swift
│   │   ├── LootTables.swift      # Boss loot tables
│   │   └── SectorSchematics.swift
│   ├── Localization/
│   │   └── L10n.swift            # Multilingual strings (EN/DE)
│   ├── Systems/                  # Game logic systems
│   │   ├── SectorUnlockSystem.swift
│   │   ├── MegaBoardSystem.swift
│   │   ├── BlueprintDropSystem.swift
│   │   └── [20+ more systems]
│   ├── Types/                    # Data structures
│   │   ├── Protocol.swift
│   │   ├── GlobalUpgrades.swift
│   │   ├── MegaBoardTypes.swift
│   │   ├── GameTypes.swift
│   │   ├── TDTypes.swift
│   │   └── MotherboardTypes.swift
│   └── Utils/                    # Utilities
│       ├── SpatialGrid.swift
│       ├── ObjectPool.swift
│       └── [Math, Random, etc]
├── GameEngine/
│   ├── Bosses/
│   │   ├── CyberbossAI.swift     # 4-phase melee/ranged boss
│   │   └── VoidHarbingerAI.swift # 4-phase raid boss
│   ├── Systems/
│   │   ├── TDBossSystem.swift
│   │   ├── SurvivalArenaSystem.swift
│   │   └── [17+ more systems]
│   └── GameState.swift
├── Rendering/
│   ├── TDGameScene.swift         # TD SpriteKit scene
│   ├── GameScene.swift           # Survivor/boss scene
│   ├── TowerVisualFactory.swift
│   ├── MegaBoardRenderer.swift
│   └── [8 more rendering files]
├── Services/
│   └── StorageService.swift
├── UI/
│   ├── Tabs/
│   │   └── SystemTabView.swift   # Main hub view
│   ├── Game/
│   │   ├── TDGameContainerView.swift
│   │   ├── GameContainerView.swift
│   │   └── UpgradeModalView.swift
│   ├── Components/
│   │   ├── IntroSequenceView.swift
│   │   ├── BossLootModal.swift
│   │   ├── BlueprintModals.swift
│   │   └── [8 more components]
│   └── Debug/
│       └── TowerGalleryView.swift
└── Resources/
    └── Localizable.xcstrings     # Translations (EN/DE)
```

---

## 12. Design Principles & Safeguards

These principles prevent common design traps and ensure a fun, fair experience.

### 🔴 DO NOT: Economy Buildings Competing for Tower Slots

**The Trap:** If players must choose between placing a Hard Drive (income) or a Firewall (defense) on the same tile, they will always choose defense. This makes the "city-building" aspect feel like a punishment.

**Our Solution: Global Upgrades**

Economy buildings (all 9 components: PSU, Storage, RAM, GPU, Cache, Expansion, I/O, Network, CPU) are **global upgrades purchased through the UI**, not placeable items. Tower slots are used **exclusively** for Firewalls (Protocol towers).

```
Tower Slots → Defense only (Firewalls/Protocols)
Global Upgrades → Economy (9 components per sector)
```

This means players never sacrifice defense capability for economy. They build their hardware through the Upgrades tab, then deploy software (Protocols) as Firewalls on the board.

---

### 🔴 DO NOT: Simulate Death Offline

**The Trap:** If a player leaves at 100% efficiency and the game simulates waves while they're gone, they might return to find 0 Hash earned because "Wave 50 would have killed them." This leads to uninstalls.

**Our Solution: Snapshot Logic**

The offline system uses a **frozen snapshot** of the player's state:

```swift
// How offline earnings work:
let efficiency = profile.tdStats.averageEfficiency  // SNAPSHOT - not simulated
let hashEarned = timeAway * baseRate * cpuMultiplier * efficiency * 0.5
```

**Rules:**
- Efficiency is frozen at the average from last session
- No wave simulation occurs offline
- Time is capped at 8 hours
- 50% income penalty (offline multiplier)
- **You cannot die while not playing**

---

### 🔴 DO NOT: Dynamic Pathfinding (Maze Building)

**The Trap:** If placing a tower blocks enemy paths, you need complex A* pathfinding that eats CPU and causes bugs (e.g., players completely walling off the CPU).

**Our Solution: Fixed Paths (The Data Bus)**

The copper traces are **permanent roads**. Towers are placed in slots **adjacent** to paths, never on them.

```
┌─────────────────────────────────────────┐
│  [Slot]      PATH      [Slot]           │
│    ↓          ↓          ↓              │
│   Tower ←→ Enemies ←→ Tower             │
│             (Fixed)                     │
└─────────────────────────────────────────┘
```

**Implementation:**
```swift
let pathOffset: CGFloat = 100  // Slots are 100pts away from path center
```

**Benefits:**
- Guaranteed 60fps performance
- No "invalid maze" edge cases
- Predictable gameplay
- Clear visual language (traces = enemy roads)

---

### 🟢 MUST DO: Protocol Synergy (The Secret Sauce)

**The Opportunity:** When upgrading a Protocol, it enhances **both** the Tower (TD) and Weapon (Active) simultaneously.

**Our Implementation:**

```swift
struct Protocol {
    var level: Int  // Single level affects both modes (1-10)

    // Level N = N× damage (aggressive scaling)
    var firewallStats: FirewallStats {
        let multiplier = CGFloat(level)  // Level 5 = 5× damage
        return FirewallStats(damage: baseDamage * multiplier, ...)
    }

    var weaponStats: WeaponStats {
        let multiplier = CGFloat(level)  // SAME multiplier
        return WeaponStats(damage: baseDamage * multiplier, ...)
    }
}
```

**Why This Matters:**
- Every upgrade feels doubly rewarding
- Players test upgrades in both TD and Active modes
- Boss blueprints directly improve TD defenses
- Creates excitement: "New Protocol! Let me try it as a tower!"

---

### 🟢 MUST DO: System Freeze as Gameplay (Not Just Penalty)

**The Opportunity:** Instead of a simple "Pay to Restore" button, the 0% efficiency state becomes a fun mini-game.

**Our Implementation: Manual Override**

```
Efficiency hits 0%
    → System Freezes (all gameplay paused)
    → "EMERGENCY OVERRIDE" button pulses
    → Player clicks it
    → 30-second survival mini-game launches
    → Win: System reboots to 50% efficiency
    → Lose: Return to freeze screen, try again
```

**Manual Override Mini-Game:**
- Dodge hazards (projectiles, expanding zones, sweep lasers)
- Survive 30 seconds
- 3-hit health system
- Difficulty scales over time
- Free (no Hash cost)

**Why This Matters:**
- Turns failure into fun gameplay
- Gives skill-based recovery option
- Creates memorable moments
- Players don't feel punished for struggling

---

### 🛠️ Technical: Sector-Based Rendering

**The Trap:** A single large texture will choke SpriteKit.

**Our Solution: 3×3 Sector Grid**

```swift
// Each sector is a separate SKNode
// 9 sectors in a 3×3 grid layout
func renderSector(_ sector: MegaBoardSector, in parentNode: SKNode) {
    let sectorNode = SKNode()
    sectorNode.name = "sector_\(sector.id)"
    // Visibility states: hidden, ghost, active
    parentNode.addChild(sectorNode)
}
```

**Rules:**
- Each sector is its own SKNode
- Hidden sectors: Not yet discovered (invisible)
- Ghost sectors: Discovered but locked (dimmed, can pay to unlock)
- Active sectors: Unlocked and playable (full rendering)
- Smooth transitions between states

---

## Summary

**System: Reboot** combines idle tower defense with active twin-stick combat through:

1. **Unified Currency** - Hash is earned from all modes, Power limits tower capacity
2. **Three Modes** - TD (passive income), Survivor (active farming), Boss (blueprints)
3. **Protocol System** - 8 protocols work as Firewalls (TD) AND Weapons (Active) with unified upgrades
4. **Mega-Board** - 3×3 sector grid (9 sectors) with boss-triggered progressive unlocks
5. **9 Components** - Each sector unlocks a unique component upgrade (PSU, Storage, RAM, GPU, Cache, Expansion, I/O, Network, CPU)
6. **Blueprint System** - Boss kills drop blueprints to unlock new Protocols (2 bosses, 4 difficulties)
7. **Threat Scaling** - Idle TD difficulty increases over time with new enemy types
8. **Raid Bosses** - 4-phase boss fights with mechanics (Cyberboss, Void Harbinger)

### Design Safeguards

| Trap | Solution |
|------|----------|
| Economy vs Defense slots | Global upgrades (no competition) |
| Offline death simulation | Snapshot logic (can't die offline) |
| Dynamic maze pathfinding | Fixed paths (towers adjacent to traces) |
| Disconnected game modes | Protocol synergy (one upgrade, both modes) |
| Punishing failure states | Manual Override mini-game (fun recovery) |
| Grinding for unlocks | Boss blueprints guarantee progress |

The game creates meaningful choices at every stage, requiring players to balance building, defending, and hunting bosses—without falling into common design traps that frustrate players.

---

*See [GAME_BALANCING_BLUEPRINT.md](./GAME_BALANCING_BLUEPRINT.md) for detailed economy tables and balancing numbers.*
