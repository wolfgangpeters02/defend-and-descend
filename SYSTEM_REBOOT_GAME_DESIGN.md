# System: Reboot - Game Design Document

> **Version:** 3.0 (System Architecture Update)
> **Last Updated:** 2026-01-30
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
- Global upgrades (PSU, CPU, RAM, Cooling, HDD)
- Sector/lane unlocks
- Protocol compilation

**Storage:** Capped by HDD level (25,000Ħ base → 12.8M at max level)

```
Example:
HDD Capacity: 200,000 Ħ
Current Hash: 185,000 Ħ
CPU Income: 50 Ħ/sec (at 100% Efficiency)
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
- Level requirements: 100 + (level-1) × 75 XP
- Unified across all game modes
- Higher levels unlock more Protocol slots

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
- 8-lane motherboard with PCB aesthetics
- Drag-to-place tower system
- Efficiency-based income (viruses leak = reduced income)
- Idle spawning with threat level scaling
- Zero-Day boss events (requires switching to Active)

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

**Survival Events:**
| Event | Effect |
|-------|--------|
| Memory Surge | Speed boost + increased spawns |
| Buffer Overflow | Arena shrinks temporarily |
| Cache Flush | Clears all enemies |
| Thermal Throttle | Slow movement + damage boost |
| Virus Swarm | 50 fast weak enemies |
| System Restore | Healing zone spawns |

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
| "Can't build more towers" | Power limit | Upgrade PSU (costs Hash) |
| "Can't afford upgrades" | Not enough Hash | Play Survivor or wait for TD income |
| "Need new Protocol" | Missing blueprint | Defeat bosses for blueprint drops |
| "Zero-Day spawned in TD" | Boss in Motherboard | Switch to Active to defeat it |

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

| Protocol | Rarity | Firewall Style | Weapon Style |
|----------|--------|----------------|--------------|
| Kernel Pulse | Common | Single-target | Pistol |
| Burst Shot | Common | Multi-shot | Shotgun |
| Ice Shard | Rare | Slow effect | Frost beam |
| Chain Lightning | Rare | Chain attack | Arc weapon |
| Flame Thrower | Epic | AoE burn | Flamethrower |
| Sniper Protocol | Epic | Long range | Railgun |
| Quantum Tunneler | Legendary | Teleport hit | Phase shots |
| Null Pointer | Legendary | Instant kill | Delete beam |

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

The Motherboard is a **4200×4200 PCB** with **8 enemy lanes** that players unlock progressively.

### Lane Layout

```
                    ┌─────────────┐
                    │     CPU     │  (Core - enemies target this)
                    │   (Center)  │
                    └─────────────┘
                          ▲
    ┌─────────┬─────────┬─┴─┬─────────┬─────────┐
    │   I/O   │ Storage │   │  Cache  │ Network │
    │  Lane   │  Lane   │   │  Lane   │  Lane   │
    └────┬────┴────┬────┘   └────┬────┴────┬────┘
         │         │              │         │
    ┌────┴────┬────┴────┐   ┌────┴────┬────┴────┐
    │   GPU   │   PSU   │   │   RAM   │Expansion│
    │  Lane   │ (Start) │   │  Lane   │  Lane   │
    └─────────┴─────────┘   └─────────┴─────────┘
```

### Lane Details

| Lane | Theme Color | Unlock Cost | Prerequisites |
|------|-------------|-------------|---------------|
| PSU | Yellow (#ffcc00) | FREE | Starter |
| GPU | Red (#ff4444) | 5,000 Ħ | PSU |
| RAM | Blue (#4488ff) | 3,000 Ħ | PSU |
| Cache | Cyan (#00ccff) | 8,000 Ħ | RAM |
| Expansion | Orange (#ff8800) | 10,000 Ħ | PSU |
| Storage | Green (#44ff44) | 12,000 Ħ | GPU |
| Network | Purple (#8844ff) | 18,000 Ħ | Cache + Expansion |
| I/O | Pink (#ff44aa) | 25,000 Ħ | GPU + Storage |

### PCB Aesthetics

Each lane features:
- Color-coded copper traces matching theme
- Themed component graphics (capacitors, chips, traces)
- Glow effects on active paths
- Ghost/dimmed appearance when locked

### Unlock Progression

When a lane is unlocked:
- Power surge animation along the data bus
- Lane lights up with theme color
- New tower slots become available
- New enemy spawn point activates (more paths = more challenge)

---

## 7. Component Upgrades

Global upgrades enhance the entire system.

### PSU (Power Capacity)

| Tier | Name | Capacity | Hash Cost |
|------|------|----------|-----------|
| 1 | Basic PSU | 450W | Starting |
| 2 | Bronze PSU | 650W | 25,000 Ħ |
| 3 | Silver PSU | 850W | 75,000 Ħ |
| 4 | Gold PSU | 1,200W | 200,000 Ħ |
| 5 | Platinum PSU | 1,600W | 500,000 Ħ |

### CPU (Hash Generation)

| Tier | Name | Hash/sec | Fire Rate Bonus |
|------|------|----------|-----------------|
| 1 | i3 | 10 Ħ/s | +0% |
| 2 | i5 | 25 Ħ/s | +5% |
| 3 | i7 | 50 Ħ/s | +10% |
| 4 | i9 | 100 Ħ/s | +15% |
| 5 | Xeon | 200 Ħ/s | +25% |

### RAM (Efficiency & Health)

| Tier | Effect |
|------|--------|
| 1 | +10% efficiency regen, 100 health |
| 2 | +15% efficiency regen, 120 health |
| 3 | +20% efficiency regen, 150 health |
| 4 | +30% efficiency regen, 200 health |

### Cooling (Fire Rate)

| Tier | Fire Rate Multiplier |
|------|---------------------|
| 1 | 1.0x |
| 2 | 1.15x |
| 3 | 1.30x |
| 4 | 1.50x |

### HDD (Hash Storage)

| Tier | Max Storage |
|------|-------------|
| 1 | 25,000 Ħ |
| 2 | 75,000 Ħ |
| 3 | 200,000 Ħ |
| 4 | 500,000 Ħ |
| 5 | 2,000,000 Ħ |

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

1. Start with PSU lane (starter) in TD mode
2. Place Kernel Pulse towers (starter Protocol)
3. Earn Hash passively from CPU
4. Unlock RAM and GPU lanes (3,000-5,000 Ħ)
5. Try Survivor mode for faster Hash

### Mid Game (Hours 1-5)

1. Unlock all 8 motherboard lanes
2. Upgrade global components (PSU, CPU, RAM)
3. Attempt boss fights for blueprints
4. Compile new Protocols from blueprints
5. Build specialized tower compositions

### Late Game (Hours 5+)

1. Max out global upgrades
2. Farm Nightmare boss difficulty
3. Complete Protocol collection
4. Optimize tower layouts for efficiency
5. Push high threat levels in idle TD

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

**Lane Unlock Order (TD Mode):**
```
PSU (Free) ──┬──▶ GPU (5K) ──┬──▶ Storage (12K) ──▶ I/O (25K)
             │               │
             ├──▶ RAM (3K) ──┴──▶ Cache (8K) ──┐
             │                                  │
             └──▶ Expansion (10K) ─────────────┴──▶ Network (18K)
```

**Protocol Unlock Order:**
1. Kernel Pulse (starter, free)
2. Boss drops unlock blueprints
3. Compile blueprints with Hash
4. Level up Protocols 1-10 with Hash

---

## 10. UI Structure

### Tab Navigation

| Tab | View | Purpose |
|-----|------|---------|
| **BOARD** | MotherboardView | Main TD gameplay |
| **ARSENAL** | ArsenalView | Protocol collection |
| **UPGRADES** | UpgradesView | Component upgrades |
| **DEBUG** | DebugView | Active mode selector |

### Motherboard HUD

```
┌─────────────────────────────────────────────────┐
│ ⚡ 380/450W    Ħ 12,450    Efficiency: 95%      │
├─────────────────────────────────────────────────┤
│                                                 │
│            [GAME AREA]                          │
│                                                 │
├─────────────────────────────────────────────────┤
│  Protocol Deck (drag to place)                  │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐                   │
│  │ 🛡️ │ │ ❄️ │ │ ⚡ │ │ 🔥 │                   │
│  │50W │ │75W │ │100W│ │150W│                   │
│  └────┘ └────┘ └────┘ └────┘                   │
└─────────────────────────────────────────────────┘
```

### Active Mode HUD

```
┌─────────────────────────────────────────────────┐
│  ❤️❤️❤️    SECTOR: RAM    Ħ 1,247    ⏱ 2:34    │
├─────────────────────────────────────────────────┤
│                                                 │
│            [GAME AREA]                          │
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
| Mega-Board | MegaBoardTypes.swift | 8-lane motherboard system |
| Global Upgrades | GlobalUpgrades.swift | PSU, CPU, RAM, Cooling, HDD |
| Balance Config | BalanceConfig.swift | Centralized tuning values |
| Idle Spawning | IdleSpawnSystem.swift | Threat-based enemy spawning |
| Tower System | TowerSystem.swift | Tower targeting & attacks |
| Boss AI | CyberbossAI.swift, VoidHarbingerAI.swift | 4-phase boss mechanics |
| Survival Events | SurvivalArenaSystem.swift | Memory Surge, Virus Swarm, etc. |
| Blueprint Drops | BlueprintDropSystem.swift | Boss loot tables |
| Storage | StorageService.swift | Persistence & offline earnings |

### File Structure

```
LegendarySurvivors/
├── Core/
│   ├── Config/          # BalanceConfig, LootTables, SectorSchematics
│   ├── Types/           # GameTypes, TDTypes, Protocol, etc.
│   └── Systems/         # SectorUnlockSystem, BlueprintDropSystem
├── GameEngine/
│   ├── Bosses/          # CyberbossAI, VoidHarbingerAI
│   └── Systems/         # IdleSpawnSystem, TowerSystem, etc.
├── Rendering/
│   ├── GameScene.swift       # Survivor rendering
│   └── TDGameScene.swift     # TD rendering
├── Services/
│   └── StorageService.swift  # Persistence & offline
└── UI/
    ├── Components/      # Modals, shared UI
    ├── Game/            # GameContainerView, TDGameContainerView
    └── Tabs/            # SystemTabView
```

---

## 12. Design Principles & Safeguards

These principles prevent common design traps and ensure a fun, fair experience.

### 🔴 DO NOT: Economy Buildings Competing for Tower Slots

**The Trap:** If players must choose between placing a Hard Drive (income) or a Firewall (defense) on the same tile, they will always choose defense. This makes the "city-building" aspect feel like a punishment.

**Our Solution: Global Upgrades**

Economy buildings (PSU, CPU, RAM, HDD, Cooling) are **global upgrades purchased through the UI**, not placeable items. Tower slots are used **exclusively** for Firewalls (Protocol towers).

```
Tower Slots → Defense only (Firewalls/Protocols)
Global Upgrades → Economy (PSU, CPU, RAM, HDD, Cooling)
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

**The Trap:** A single 4000x4000 texture will choke SpriteKit.

**Our Solution: Sector Chunks**

```swift
// Each sector is a separate SKNode (~1400x1400)
func renderGhostSector(_ sector: MegaBoardSector, in parentNode: SKNode) {
    let ghostNode = SKNode()
    ghostNode.name = "ghost_\(sector.id)"
    // Only added when visible/adjacent
    parentNode.addChild(ghostNode)
}
```

**Rules:**
- Each sector is its own SKNode
- Only render visible + adjacent sectors
- Ghost sectors (locked) are lightweight
- Decrypt animation transitions between states

---

## Summary

**System: Reboot** combines idle tower defense with active twin-stick combat through:

1. **Unified Currency** - Hash is earned from all modes, Power limits tower capacity
2. **Three Modes** - TD (passive income), Survivor (active farming), Boss (blueprints)
3. **Protocol System** - Cards work as Firewalls (TD) AND Weapons (Active) with unified upgrades
4. **Mega-Board** - 8-lane motherboard with progressive unlocks
5. **Blueprint System** - Boss kills drop blueprints to unlock new Protocols
6. **Threat Scaling** - Idle TD difficulty increases over time with new enemy types
7. **Raid Bosses** - 4-phase boss fights with WoW-style mechanics

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
