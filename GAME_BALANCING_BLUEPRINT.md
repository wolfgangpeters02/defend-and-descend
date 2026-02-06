# System: Reboot - Game Balancing Blueprint

> **The Definitive Economy & Progression Guide**
> Last Updated: 2026-02-05

---

## Table of Contents
1. [Game Identity](#1-game-identity)
2. [Currency & Economy](#2-currency--economy)
3. [The Component Ecosystem](#3-the-component-ecosystem)
4. [The Game Modes](#4-the-game-modes)
5. [The Gameplay Loop](#5-the-gameplay-loop)
6. [Progression & Unlocks](#6-progression--unlocks)
7. [Loss Conditions & Recovery](#7-loss-conditions--recovery)
8. [Balancing Tables](#8-balancing-tables)
9. [Wave & Threat Scaling](#9-wave--threat-scaling)
10. [Survival Events](#10-survival-events)
11. [Blueprint Drop System](#11-blueprint-drop-system)
12. [Balance Simulator Tools](#12-balance-simulator-tools)
13. [UI Requirements](#13-ui-requirements)

---

## 1. Game Identity

### One-Line Pitch
> "SimCity meets Tower Defense on a motherboard - build your PC empire, defend it from viruses."

### Core Fantasy
You are a **System Administrator** building and defending a computer system. Your motherboard is your city. Viruses are the invaders. Components are your buildings and economy.

### Two Modes, One Goal
| Mode | Genre | Purpose |
|------|-------|---------|
| **Firewall Mode** (TD) | Idle Tower Defense | Continuous threat defense, earn Hash, upgrade components |
| **Boss Encounters** | Auto-Shoot Action | Boss fights (auto-fire, move to dodge), earn Hash & Blueprints |

---

## 2. Currency & Economy

### Overview

| Icon | Name | Role | Analogy |
|------|------|------|---------|
| ⚡ | **Power (Watts)** | The Ceiling | Electricity bill - limits what you can run |
| Ħ | **Hash** | The Cash | Money - spend to buy everything |

> **Note:** Data (◈) was a former second currency but has been removed. Hash is now the universal currency for all purchases.

### 2.1 Power (Watts) ⚡

**Role:** The BUILD LIMIT. Determines how much you can have running simultaneously.

| Property | Value |
|----------|-------|
| Source | PSU (Power Supply Unit) component |
| Type | Hard Capacity Limit (NOT a currency) |
| Governs | Tower placement capacity |
| Regenerates? | No - it's a ceiling, not a pool |

**Example:**
```
PSU Lv1: 300W Capacity
Currently Used: 250W
Available: 50W

Tower costs 30W to run → CAN BUILD
Tower costs 100W to run → CANNOT BUILD (need PSU upgrade)
```

**Key Design Rules:**
- Power is NOT consumed - it's allocated
- Selling/removing a tower frees up its Power
- PSU component upgrades increase capacity (Lv1: 300W → Lv10: 2300W)
- Running at max Power is fine (no penalty)
- Overclock doubles power demand temporarily

### 2.2 Hash (Ħ)

**Role:** The UNIVERSAL CURRENCY. Earned passively and through gameplay.

| Property | Value |
|----------|-------|
| Source | Passive income (CPU level), Boss defeats, Offline generation |
| Type | Soft Currency (farmable) |
| Spent On | Compiling Protocols, placing towers, component upgrades, sector unlocks |
| Storage Limit | Determined by Storage component level (Lv1: 25,000 Ħ) |

**Passive Income (Firewall Mode):**
```
Base Rate: 1.0 Ħ/sec (CPU Lv1)
CPU Level Scaling: 1.5× per level
  Lv1: 1.0 Ħ/sec
  Lv5: ~5 Ħ/sec
  Lv10: ~38 Ħ/sec
Efficiency scales income (0-100%, each leaked virus costs 5%)
```

**Boss Rewards (by difficulty):**
```
Easy: 1,000 Ħ
Normal: 3,000 Ħ
Hard: 8,000 Ħ
Nightmare: 20,000 Ħ
```

**Offline Earnings:**
- 20% of active rate (upgradeable via Storage component)
- Max 8 hours accumulation

---

## 3. The Component Ecosystem

### The Motherboard as a City

Components are upgradeable (Lv 1-10) and unlock via district boss progression. Each serves a distinct role:

| Component | Unlock Order | Role | Upgrade Effect |
|-----------|-------------|------|----------------|
| **PSU** | 0 (starter) | Power Capacity | 300W → 2300W ceiling |
| **RAM** | 1 | Efficiency Recovery | 1.0× → 2.0× recovery speed |
| **GPU** | 2 | Tower Damage | 1.0× → 1.5× global tower damage |
| **Cache** | 3 | Attack Speed | 1.0× → 1.3× global attack speed |
| **Storage** | 4 | Hash Storage + Offline | 25,000 Ħ cap, 20% → 60% offline rate |
| **Expansion** | 5 | Extra Tower Slots | +0/+1/+2 slots per sector |
| **Network** | 6 | Hash Multiplier | 1.0× → 1.5× all Hash income |
| **I/O** | 7 | Pickup Radius | 1.0× → 2.5× pickup range |
| **CPU** | 8 (final) | Hash Generation | 1.0 → ~38 Ħ/sec (exponential) |

Component upgrade costs use exponential formula: `baseCost × 2^(level-1)`

### Tower Placement Costs by Rarity

| Rarity | Hash Cost | Power Draw |
|--------|-----------|------------|
| Common | 50 Ħ | 15-20W |
| Rare | 100 Ħ | 30-35W |
| Epic | 200 Ħ | 60-75W |
| Legendary | 400 Ħ | 100-120W |

**Selling Towers:** 50% refund of total investment (placement + upgrades)

---

## 4. The Game Modes

### 4.1 Firewall Mode (Idle Tower Defense)

**Genre:** Idle Tower Defense with Threat Scaling

**What You Do:**
- Place Protocols (towers) on the 8-lane motherboard
- Defend against continuously spawning viruses (threat scales over time)
- Manage efficiency (viruses reaching CPU reduce Hash income)
- Unlock new sectors, upgrade components
- Overclock CPU for risk/reward (2× Hash, 10× threat growth)

**What You Earn:**
- Hash (Ħ) - passive generation from CPU level, scaled by efficiency
- Offline Hash accumulation when away

**Threat System (replaces waves):**
- Threat level increases continuously over time
- Higher threat = stronger enemies, faster spawns, new enemy types
- Boss "super viruses" spawn at threat milestones (every 6 threat levels)
- District bosses are immune to towers - must enter boss fight to defeat

### 4.2 Boss Encounters (Auto-Shoot Action)

**Genre:** Top-Down Action (Auto-Fire + Movement)

**What You Do:**
- Move to dodge boss attacks (virtual joystick)
- Weapons fire automatically at nearest enemy
- Navigate boss phases and raid-style mechanics
- Choose difficulty for risk/reward

**What You Earn:**
- Hash (Ħ) - difficulty-scaled rewards (1,000 - 20,000 Ħ)
- Protocol Blueprints - RNG drops from boss defeats

**Boss Difficulty:**
| Difficulty | Boss HP | Boss DMG | Player HP | Player DMG | Blueprint Chance |
|------------|---------|----------|-----------|------------|-----------------|
| Easy | 1.0× | 0.5× | 2.0× | 4.0× | 5% |
| Normal | 1.0× | 1.0× | 1.0× | 1.5× | 15% |
| Hard | 1.5× | 1.3× | 1.0× | 1.0× | 30% |
| Nightmare | 2.5× | 1.8× | 1.0× | 1.0× | 50% |

### Mode Interaction

| Situation | Problem | Solution |
|-----------|---------|----------|
| "I need a new Protocol" | Missing Blueprint | Defeat district bosses for drops |
| "I can't compile the Protocol" | Not enough Hash | Earn Hash passively or from boss rewards |
| "I need more Hash for towers" | Low Hash | Upgrade CPU, wait for passive income, defeat bosses |
| "I want to unlock a new sector" | Need boss defeat + protocols + Hash | Defeat current district boss, compile required protocols, pay Hash |

---

## 5. The Gameplay Loop

### The Core Loop

```
┌─────────────────────────────────────────────────────────────┐
│  FIREWALL MODE (Idle TD)                                    │
│                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │  PLACE   │───▶│  DEFEND  │───▶│  EARN    │              │
│  │ (Build)  │    │ (Threat) │    │ (Hash)   │              │
│  └──────────┘    └──────────┘    └──────────┘              │
│       ▲                               │                     │
│       └───────────────────────────────┘                     │
│                                                             │
│   Threat Milestone → District Boss Spawns!                  │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      │ Tap boss to engage
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  BOSS ENCOUNTER (Auto-Shoot Action)                         │
│                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │  PICK    │───▶│  FIGHT   │───▶│  LOOT    │              │
│  │(Diffi-   │    │ (Dodge & │    │ (Hash +  │              │
│  │ culty)   │    │  Survive)│    │Blueprint?)│              │
│  └──────────┘    └──────────┘    └──────────┘              │
│                                       │                     │
│               Blueprint Drop ─────────┤                     │
│                     │            Hash Reward                 │
│              Compile Protocol    Sector Unlock               │
└─────────────────────────────────────────────────────────────┘
```

---

## 6. Progression & Unlocks

### Protocol System

Protocols are your tower blueprints. Each Protocol defines a tower's behavior.

**Protocol Acquisition:**
1. **Starter Protocol** - Free (Kernel Pulse)
2. **Blueprint Drop** - Defeat district bosses (RNG based on difficulty)
3. **Compile** - Spend Hash (Ħ) to unlock for placement

### Sector Gating (Three-Layer System)

Sectors unlock through a three-gate system:

1. **Visibility Gate** — Defeat the previous district's boss to see the next sector
2. **Protocol Gate** — Compile the required Protocols (blueprints from boss drops)
3. **Hash Gate** — Pay the unlock cost in Hash

| Sector | Order | Required Protocols | Hash Cost | Rationale |
|--------|-------|-------------------|-----------|-----------|
| PSU | 0 | (none - starter) | 0 Ħ | Starting zone |
| RAM | 1 | Fragmenter | 25,000 Ħ | Multi-target processing |
| GPU | 2 | Fragmenter + Recursion | 50,000 Ħ | Parallel = multi-shot |
| Cache | 3 | Kernel Pulse + Throttler | 75,000 Ħ | Speed + control |
| Storage | 4 | Pinger | 100,000 Ħ | Persistence = range |
| Expansion | 5 | Root Access | 150,000 Ħ | System privileges |
| Network | 6 | Overflow + Garbage Collector | 200,000 Ħ | Full mastery |
| I/O | 7 | Recursion + Pinger | 300,000 Ħ | Multi-channel |
| CPU | 8 | (none) | 500,000 Ħ | Final goal (Hash only) |

**Total unlock cost:** 1,400,000 Ħ across all sectors

---

## 7. Loss Conditions & Recovery

### Firewall Mode: Virus Breach

**NOT Game Over.** Instead:

1. **Efficiency Drops**
   - Each virus that reaches CPU: -5% Efficiency (leak counter +1)
   - Efficiency affects Hash income rate
   - At 0% Efficiency: System Freeze — earn nothing (but don't lose stuff)

2. **Recovery**
   - Leak counter decays over time (interval from `BalanceConfig.Efficiency.leakDecayInterval`)
   - RAM component upgrades speed up recovery (1.0× to 2.0×)
   - No permanent loss — efficiency always recoverable

### Boss Encounter: Player Death

- Fight ends, return to Firewall Mode
- No Hash reward for that fight
- No penalty to existing Hash or progress
- Can retry immediately at any difficulty

### Survival Mode: Player Death

- Run ends
- **Receive 50% of accumulated Hash** (extraction = 100%)
- Extraction available after 180 seconds (3 minutes)
- Blueprints are permanent once dropped
- No penalty to existing Hash

---

## 8. Balancing Tables

> **Source of Truth:** `SystemReboot/Core/Config/BalanceConfig.swift`

### Player Stats

| Stat | Value |
|------|-------|
| Base Health | 200 HP |
| Base Speed | 200 units/sec |
| Hitbox Radius | 15 units |
| Pickup Range | 50 units |
| Health Regen | 1.5 HP/sec |
| Damage Invulnerability | 0.5 sec |
| Revive Invulnerability | 3.0 sec |

### Tower Projectile Settings

| Setting | Value |
|---------|-------|
| Projectile Speed | 600 units/sec |
| Hitbox Radius | 8 units |
| Lifetime | 3.0 sec |
| Homing Strength | 8.0 |
| Multi-shot Spread | 0.15 rad |
| Lead Prediction Cap | 0.8 sec |

### Leveling & Mastery

| Setting | Value |
|---------|-------|
| Bonus per Level | +5% |
| Base XP Required | 100 XP |
| XP per Level | +75 XP |
| Max Weapon Level | 10 |
| Damage per Level | +1.0× (Level 10 = 10× damage) |

---

## 9. Wave & Threat Scaling

### Wave Scaling (Legacy/Fallback)

> **Note:** The primary mode is now Idle TD with threat scaling (below). Wave-based scaling exists as a fallback for non-motherboard maps.

| Parameter | Value | Effect |
|-----------|-------|--------|
| Health Scaling | +15%/wave | Wave 20 = 3.85× HP |
| Speed Scaling | +2%/wave | Wave 20 = 1.38× speed |
| Base Enemy Count | 5 | Starting count |
| Enemies per Wave | +2 | Wave 20 = 45 enemies |
| Boss Wave Interval | Every 5 waves | Waves 5, 10, 15, 20... |
| Boss Health Mult | 2.0× | On top of wave scaling |
| Boss Speed Mult | 0.8× | Slower but tankier |

**Spawn Timing:**
- Base Delay: 0.8 sec
- Min Delay: 0.3 sec
- Reduction: -0.02 sec/wave

### Threat Level Scaling (Primary Idle TD Mode)

| Parameter | Value |
|-----------|-------|
| Health per Threat | +15% |
| Speed per Threat | +2% |
| Damage per Threat | +5% |

**Enemy Unlock Thresholds:**

| Enemy Type | Threat Level | Time (~) |
|------------|--------------|----------|
| Basic | 1.0 | Start |
| Fast | 2.0 | ~20 sec |
| Swarm | 4.0 | ~60 sec |
| Tank | 5.0 | ~80 sec |
| Elite | 8.0 | ~130 sec |
| Boss | 10.0 | ~160 sec |

---

## 10. Survival Events

Events trigger periodically during Survival Mode to add variety and challenge.

### Event Timing

| Parameter | Value |
|-----------|-------|
| First Event | 60 sec |
| Base Interval | 60 sec |
| Min Interval | 40 sec |
| Reduction | -5 sec/minute |
| Random Variance | ±5 sec |

### Event Types

| Event | Effect | Duration |
|-------|--------|----------|
| **Memory Surge** | +50% player speed, 2× spawn rate | Timed |
| **Thermal Throttle** | -30% speed, +50% damage taken | Timed |
| **Buffer Overflow** | Kill zones at arena edges (25 DPS) | Timed |
| **Data Corruption** | Random obstacles deal 15 DPS | Timed |
| **System Restore** | Healing zone spawns (5 HP/sec) | Timed |
| **Virus Swarm** | 50 fast enemies spawn | Instant |
| **Cache Flush** | All enemies cleared (120s cooldown) | Instant |

---

## 11. Blueprint Drop System

### How Blueprints Work

1. **Defeat Boss** → RNG roll for Blueprint drop
2. **Get Blueprint** → Can now compile Protocol
3. **Compile Protocol** → Spend Hash (Ħ), unlock for placement

### Drop Rate System

**TD Mode (district bosses):** Simple flat chance based on difficulty:

| Difficulty | Drop Chance |
|------------|-------------|
| Easy | 5% |
| Normal | 15% |
| Hard | 30% |
| Nightmare | 50% |

**Boss Encounter Mode (Cathedral):** Uses full rarity-weighted system:

```
effectiveRate = baseRate × difficultyMult × (1 / (1 + diminishingFactor × killCount))
```

### Base Drop Rates (by Rarity Tier)

| Rarity | Base Rate |
|--------|-----------|
| Common | 60% |
| Rare | 30% |
| Epic | 8% |
| Legendary | 2% |

### Difficulty Multipliers (Boss Encounter Mode)

| Difficulty | Multiplier | Legendary? |
|------------|------------|------------|
| Easy | 0.5× | No |
| Normal | 1.0× | Yes (2%) |
| Hard | 1.5× | Yes (3%) |
| Nightmare | 2.5× | Yes (5%) |

### Special Rules

- **First Kill Bonus:** Guaranteed drop on first kill of each boss
- **Pity System:** Guaranteed drop every 10 kills without one
- **Diminishing Returns:** Factor of 0.1 reduces rates over many kills
- **No Duplicates:** Already-owned blueprints excluded from pool

### Active Boss Roster

Bosses cycle through districts: PSU gets Cyberboss, RAM gets Void Harbinger, GPU gets Overclocker, etc.

| Boss | ID | Drops | Theme |
|------|----|-------|-------|
| **Cyberboss** | `cyberboss` | Fragmenter (C), Pinger (R), Throttler (R) | Hacking/intrusion |
| **Void Harbinger** | `void_harbinger` | Recursion (E), Root Access (E), Overflow (L) | Memory corruption |
| **Overclocker** | `overclocker` | (cycles through same tables) | PSU/Cooling |
| **Trojan Wyrm** | `trojan_wyrm` | (cycles through same tables) | Network worm |

### Future Bosses (Loot Tables Defined)

| Boss | Drops | Theme |
|------|-------|-------|
| **Frost Titan** | Throttler (R), Garbage Collector (L) | Cryogenic |
| **Inferno Lord** | Root Access (E), Overflow (L), Garbage Collector (L) | Destruction |

---

## 12. Balance Simulator Tools

### Overview

Two tools exist for balance testing and iteration:

1. **HTML Visualizer** (`tools/balance-simulator.html`)
2. **Swift CLI Simulator** (`tools/BalanceSimulator/main.swift`)

### HTML Visualizer

Open in browser. Features:
- Wave scaling charts (HP/Speed over 30 waves)
- Threat level progression
- Tower DPS comparison
- Economy timeline
- Drop rate Monte Carlo simulation
- Import/Export JSON configs

### CLI Simulator

Run via: `./tools/run-balance-sim.sh [command]`

| Command | Description |
|---------|-------------|
| `waves [count]` | Simulate wave scaling |
| `drops [kills] [difficulty]` | Monte Carlo drop simulation |
| `economy [seconds]` | Survival economy projection |
| `threat [max] [rate]` | Threat level progression |
| `all` | Run all simulations |
| `analyze` | Generate balance insights (for AI) |

**Example:**
```bash
./tools/run-balance-sim.sh waves 25
./tools/run-balance-sim.sh drops 500 nightmare
./tools/run-balance-sim.sh analyze
```

### Keeping Tools in Sync

The `BalanceConfig.swift` has an `exportJSON()` function that outputs values matching the HTML tool format. Run in-game debug to export, then paste into HTML tool.

---

## 13. UI Requirements

### Always Visible (HUD)

```
┌─────────────────────────────────────────────┐
│ ⚡ 250/300W    Ħ 12,450 / 25,000            │
│ Efficiency: 95% ████████████░░              │
│ Threat: 4.2    Hash/sec: 0.95               │
└─────────────────────────────────────────────┘
```

### Build Menu Shows

```
┌─────────────────────────────────────┐
│ Kernel Pulse                        │
│ ─────────────────────────────────── │
│ Cost: 50 Ħ (You have: 12,450)    ✓  │
│ Blueprint: OWNED                 ✓  │
│ Compiled: YES                    ✓  │
│                                     │
│         [ PLACE ]                   │
└─────────────────────────────────────┘
```

### Blocked Build Shows WHY

```
┌─────────────────────────────────────┐
│ Overflow Protocol                   │
│ ─────────────────────────────────── │
│ Cost: 400 Ħ (You have: 12,450)   ✓  │
│ Blueprint: MISSING               ✗  │
│   → Defeat: Void Harbinger          │
│ Compiled: NO                     ✗  │
│   → Requires Blueprint first        │
│                                     │
│         [ LOCKED ]                  │
└─────────────────────────────────────┘
```

### Blueprint Discovery Modal

```
┌─────────────────────────────────────┐
│       ✦ BLUEPRINT FOUND! ✦         │
│          [FIRST KILL!]              │
│                                     │
│        ╔═══════════════╗           │
│        ║  Fork Bomb    ║           │
│        ║    (Epic)     ║           │
│        ╚═══════════════╝           │
│                                     │
│   "Spawns child projectiles on     │
│    impact for area coverage"        │
│                                     │
│         [ COLLECT ]                 │
└─────────────────────────────────────┘
```

---

## Summary: The Three Walls

| Wall | "I can't because..." | Solution |
|------|---------------------|----------|
| **Power Wall** | "Not enough Watts" | Upgrade PSU component |
| **Hash Wall** | "Can't afford it" | Upgrade CPU, earn passive Hash, defeat bosses |
| **Blueprint Wall** | "Don't have Protocol" | Defeat district bosses for blueprint drops |

This creates **meaningful choices** and **clear goals** at every stage of the game.

---

## Appendix: BalanceConfig Reference

All balance values live in `SystemReboot/Core/Config/BalanceConfig.swift`.

### Structure

```swift
struct BalanceConfig {
    // Core
    struct Player { ... }           // Health, speed, regen, etc.
    struct Waves { ... }            // Wave-based TD scaling (legacy)
    struct ThreatLevel { ... }      // Idle TD scaling (primary)
    struct Towers { ... }           // Costs, projectile settings
    struct TowerUpgrades { ... }    // Per-level stat multipliers

    // Boss Encounters
    struct BossSurvivor { ... }     // Boss scaling
    struct Cyberboss { ... }        // Cyberboss phase config
    struct VoidHarbinger { ... }    // Void Harbinger phase config
    struct Overclocker { ... }      // Overclocker phase config
    struct TrojanWyrm { ... }       // Trojan Wyrm phase config
    struct BossDifficultyConfig { ... } // Difficulty multipliers & rewards

    // TD Systems
    struct TDCore { ... }           // Guardian (CPU) stats & upgrades
    struct TDBoss { ... }           // District boss integration
    struct ZeroDay { ... }          // Zero-Day system breach boss
    struct HashEconomy { ... }      // Hash generation & CPU scaling
    struct Efficiency { ... }       // Leak decay, warning thresholds
    struct Overclock { ... }        // Overclock risk/reward system
    struct TDRendering { ... }      // TD visual timing

    // Progression
    struct SectorUnlock { ... }     // 9-sector unlock order & costs
    struct Components { ... }       // Component upgrade system (PSU→CPU)
    struct Leveling { ... }         // XP formulas
    struct DropRates { ... }        // Blueprint RNG

    // Protocol Status Effects
    struct Throttler { ... }        // Stun chance & immunity
    struct Pinger { ... }           // Tag damage bonus
    struct GarbageCollector { ... } // Mark & bonus hash
    struct Fragmenter { ... }       // DoT burn ticks
    struct Recursion { ... }        // Child projectile splitting

    // Economy & Events
    struct SurvivalEvents { ... }   // Event parameters
    struct SurvivalEconomy { ... }  // Hash earning
    struct Pickups { ... }          // Lifetime settings
    struct Potions { ... }          // Potion charges & effects

    // Performance & Visual
    struct Limits { ... }           // Performance caps
    struct Visual { ... }           // Screen shake, trails
    struct Particles { ... }        // Particle effect params
    struct Timing { ... }           // Upgrade intervals
}
```

### Helper Functions

```swift
// Core formulas
BalanceConfig.exponentialUpgradeCost(baseCost:currentLevel:)  // baseCost × 2^(level-1)
BalanceConfig.levelStatMultiplier(level:)                      // level as multiplier (Lv5 = 5×)

// Wave & Threat scaling
BalanceConfig.waveHealthMultiplier(waveNumber:)
BalanceConfig.waveSpeedMultiplier(waveNumber:)
BalanceConfig.threatHealthMultiplier(threatLevel:)
BalanceConfig.threatSpeedMultiplier(threatLevel:)
BalanceConfig.threatDamageMultiplier(threatLevel:)
BalanceConfig.spawnDelay(waveNumber:)

// Leveling & Economy
BalanceConfig.xpRequired(level:)
BalanceConfig.levelMultiplier(level:)
BalanceConfig.towerCost(rarity:)
BalanceConfig.HashEconomy.hashPerSecond(at:)                   // CPU-level Hash rate

// Components
BalanceConfig.Components.upgradeCost(for:at:)                  // Component upgrade costs
BalanceConfig.Components.psuCapacity(at:)                      // PSU Watt capacity
BalanceConfig.Components.cpuHashPerSecond(at:)                 // CPU Hash generation
BalanceConfig.SectorUnlock.unlockCost(for:)                    // Sector Hash costs

// Tools
BalanceConfig.exportJSON() // For simulator tools
```

---

*Document Version: 3.0*
*Game: System: Reboot*
