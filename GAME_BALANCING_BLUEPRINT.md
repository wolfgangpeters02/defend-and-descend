# System: Reboot - Game Balancing Blueprint

> **The Definitive Economy & Progression Guide**
> Last Updated: 2026-01-30

---

## Table of Contents
1. [Game Identity](#1-game-identity)
2. [The Three Currencies](#2-the-three-currencies)
3. [The Component Ecosystem](#3-the-component-ecosystem)
4. [The Dual Game Modes](#4-the-dual-game-modes)
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
| **Firewall Mode** (TD) | Tower Defense | Wave-based defense, earn Hash, test Protocols |
| **Survival Mode** | Twin-Stick Shooter | Endurance runs, earn Data, discover Blueprints |

---

## 2. The Three Currencies

### Overview

| Icon | Name | Role | Analogy |
|------|------|------|---------|
| ⚡ | **Power (Watts)** | The Ceiling | Electricity bill - limits what you can run |
| Ħ | **Hash** | The Cash | Money - spend to buy things |
| ◈ | **Data** | The Science | Research points - unlock new tech |

### 2.1 Power (Watts) ⚡

**Role:** The BUILD LIMIT. Determines how much you can have running simultaneously.

| Property | Value |
|----------|-------|
| Source | PSU (Power Supply Unit) |
| Type | Hard Capacity Limit |
| Spent On | Sustaining towers & components |
| Regenerates? | No - it's a ceiling, not a pool |

**Example:**
```
PSU: 450W Capacity
Currently Used: 380W
Available: 70W

Tower costs 50W to run → CAN BUILD
Tower costs 100W to run → CANNOT BUILD (need PSU upgrade)
```

**Key Design Rules:**
- Power is NOT consumed - it's allocated
- Selling/removing a tower frees up its Power
- PSU upgrades are the ONLY way to increase capacity
- Running at max Power is fine (no penalty)

### 2.2 Hash (Ħ)

**Role:** The MONEY. Earned passively and through gameplay.

| Property | Value |
|----------|-------|
| Source | Survival Mode (passive), Firewall waves (bonus) |
| Type | Soft Currency (farmable) |
| Spent On | Compiling Protocols, placing towers, upgrades |
| Storage Limit | Determined by sector unlocks |

**Earning Rates (Survival Mode):**
```
Base Rate: 2.0 Ħ/sec
Time Bonus: +0.5 Ħ/sec per minute survived
Example at 5 minutes: 2.0 + (5 × 0.5) = 4.5 Ħ/sec
```

**Wave Bonuses (Firewall Mode):**
```
Wave Bonus = Wave Number × 10 Ħ
Wave 5 = 50 Ħ bonus
Wave 10 = 100 Ħ bonus
Wave 20 = 200 Ħ bonus
```

### 2.3 Data (◈)

**Role:** The RESEARCH CURRENCY. Unlocks new Protocols.

| Property | Value |
|----------|-------|
| Source | Survival Mode (time-based), Boss defeats |
| Type | Premium/Skill Currency |
| Spent On | Compiling Protocol Blueprints |
| Storage Limit | None (hoardable) |

**Key Design Rules:**
- Data is ONLY earned through Survival Mode gameplay
- Creates motivation to play challenging content
- Blueprints are boss drops; Data is the "crafting material"
- No Data loss on death (frustration protection)

---

## 3. The Component Ecosystem

### The Motherboard as a City

Every component serves an **economic function**:

| Component | City Analogy | Consumes ⚡ | Produces | Special Ability |
|-----------|--------------|-------------|----------|-----------------|
| **PSU** | Power Plant | 0W | Power Capacity | None - pure infrastructure |
| **CPU** | Factory | 50-200W | Hash/sec | +% Tower Fire Rate |
| **GPU** | Super Factory | 150-400W | Hash/sec (high) | Acts as AoE Tower + opens new spawn lane |
| **RAM** | Efficiency Office | 20-50W | Nothing | Multiplies Hash income (+10-25% per stick) |
| **HDD** | Bank Vault | 10-30W | Nothing | Increases max Hash storage |
| **SSD** | Safe Deposit | 15-40W | Nothing | Enables save slots + faster load |
| **Towers** | Defense Turrets | 10-100W | Nothing | Defends against viruses |

### Tower Placement Costs by Rarity

| Rarity | Hash Cost |
|--------|-----------|
| Common | 50 Ħ |
| Rare | 100 Ħ |
| Epic | 200 Ħ |
| Legendary | 400 Ħ |

**Selling Towers:** 50% refund of total investment (placement + upgrades)

---

## 4. The Dual Game Modes

### 4.1 Firewall Mode (Tower Defense)

**Genre:** Wave-based Tower Defense

**What You Do:**
- Place Protocols (towers) on the motherboard
- Defend against waves of viruses
- Upgrade towers between waves
- Manage Hash economy

**What You Earn:**
- Hash (wave completion bonuses)
- Practice for Survival Mode

**Wave Structure:**
- Waves get progressively harder
- Boss waves every 5 waves
- 10-second cooldown between waves

### 4.2 Survival Mode (Twin-Stick Shooter)

**Genre:** Arena Survival / Roguelite

**What You Do:**
- Survive as long as possible in the arena
- Fight through virus swarms
- React to survival events
- Extract after 3 minutes for rewards

**What You Earn:**
- Data (◈) - passive accumulation
- Hash (Ħ) - passive accumulation
- Protocol Blueprints - boss drops

**Extraction:**
- Available after 180 seconds (3 minutes)
- Keep all accumulated rewards
- Death = lose run rewards

### Mode Switching Motivation

| Situation | Problem | Solution |
|-----------|---------|----------|
| "I need a new Protocol" | Missing Blueprint | Play Survival, defeat bosses |
| "I can't compile the Protocol" | Not enough Data | Play Survival, earn Data |
| "I need more Hash for towers" | Low Hash | Play Firewall waves OR Survival |
| "I want to test my builds" | Want practice | Play Firewall Mode |

---

## 5. The Gameplay Loop

### The Core Loop

```
┌─────────────────────────────────────────────────────────────┐
│  FIREWALL MODE (TD)                                         │
│                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │  PLACE   │───▶│  DEFEND  │───▶│  EARN    │              │
│  │ (Build)  │    │ (Waves)  │    │ (Hash)   │              │
│  └──────────┘    └──────────┘    └──────────┘              │
│       ▲                               │                     │
│       └───────────────────────────────┘                     │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ Need Blueprints?
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  SURVIVAL MODE                                              │
│                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │  ENTER   │───▶│  SURVIVE │───▶│  EXTRACT │              │
│  │ (Arena)  │    │ (Endure) │    │ (Loot)   │              │
│  └──────────┘    └──────────┘    └──────────┘              │
│                                       │                     │
│                 Defeat Boss ──────────┤                     │
│                     │                 │                     │
│               Blueprint Drop?    Data + Hash                │
└─────────────────────────────────────────────────────────────┘
```

---

## 6. Progression & Unlocks

### Protocol System

Protocols are your tower blueprints. Each Protocol defines a tower's behavior.

**Protocol Acquisition:**
1. **Starter Protocol** - Free (Kernel Pulse)
2. **Blueprint Drop** - Defeat bosses in Survival Mode
3. **Compile** - Spend Data to unlock usage

### Sector Gating

Sectors (motherboard regions) unlock based on compiled Protocols:

| Sector | Required Protocols | Rationale |
|--------|-------------------|-----------|
| Power | (starter - free) | Starting zone |
| RAM | Kernel Pulse | Basic access |
| CPU | (Hash only) | Core goal |
| GPU | Burst + Fork Bomb | Parallel = multi-shot |
| Storage | Trace Route | Persistence = range |
| Cache | Kernel + Ice Shard | Speed + control |
| Expansion | Root Access | System privileges |
| I/O | Fork Bomb + Trace Route | Multi-channel |
| Network | Overflow + Null Pointer | Full mastery |

---

## 7. Loss Conditions & Recovery

### Firewall Mode: Virus Breach

**NOT Game Over.** Instead:

1. **Efficiency Drops**
   - Each virus that reaches CPU: -5% Efficiency
   - Efficiency affects Hash income
   - At 0% Efficiency: You earn nothing (but don't lose stuff)

2. **Recovery**
   - Efficiency regenerates slowly over time
   - RAM upgrades speed up recovery

### Survival Mode: Player Death

- Run ends
- Lose all accumulated rewards from that run
- Blueprints are permanent once dropped
- No penalty to existing Hash/Data

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
| XP per Level | +50 XP |
| Max Weapon Level | 10 |
| Damage per Level | +1.0× (Level 10 = 10× damage) |

---

## 9. Wave & Threat Scaling

### Wave Scaling (Firewall Mode)

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

### Threat Level Scaling (Idle TD Mode)

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
| Tank | 5.0 | ~80 sec |
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
3. **Compile Protocol** → Spend Data, unlock for placement

### Drop Rate Formula

```
effectiveRate = baseRate × difficultyMult × (1 / (1 + diminishingFactor × killCount))
```

### Base Drop Rates

| Rarity | Base Rate |
|--------|-----------|
| Common | 60% |
| Rare | 30% |
| Epic | 8% |
| Legendary | 2% |

### Difficulty Multipliers

| Difficulty | Multiplier | Legendary? |
|------------|------------|------------|
| Easy | 0.5× | No |
| Normal | 1.0× | Yes (2%) |
| Hard | 1.5× | Yes (3%) |
| Nightmare | 2.5× | Yes (5%) |

### Special Rules

- **First Kill Bonus:** Guaranteed drop on first boss kill
- **Pity System:** Guaranteed drop every 10 kills without one
- **Diminishing Returns:** Factor of 0.1 reduces rates over many kills
- **No Duplicates:** Already-owned blueprints excluded from pool

### Boss → Protocol Mapping

| Boss | Drops | Theme |
|------|-------|-------|
| **Cyberboss** | Burst Protocol (C), Trace Route (R), Ice Shard (R) | Hacking/intrusion |
| **Void Harbinger** | Fork Bomb (E), Root Access (E), Overflow (L) | Memory corruption |
| **Frost Titan** | Ice Shard (R), Null Pointer (L) | Cryogenic |
| **Inferno Lord** | Root Access (E), Overflow (L), Null Pointer (L) | Destruction |

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
│ ⚡ 380/450W    Ħ 12,450    ◈ 2,340          │
│ Efficiency: 95% ████████████░░ (+1%/10s)    │
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
| **Power Wall** | "Not enough Watts" | Upgrade PSU |
| **Hash Wall** | "Can't afford it" | Play Survival / Firewall |
| **Blueprint Wall** | "Don't have Protocol" | Defeat bosses in Survival |

This creates **meaningful choices** and **clear goals** at every stage of the game.

---

## Appendix: BalanceConfig Reference

All balance values live in `SystemReboot/Core/Config/BalanceConfig.swift`.

### Structure

```swift
struct BalanceConfig {
    struct Player { ... }        // Health, speed, regen, etc.
    struct Waves { ... }         // TD mode scaling
    struct ThreatLevel { ... }   // Idle TD scaling
    struct Towers { ... }        // Costs, projectile settings
    struct BossSurvivor { ... }  // Boss scaling in survival
    struct SurvivalEvents { ... }// Event parameters
    struct SurvivalEconomy { ... }// Hash/Data earning
    struct Pickups { ... }       // Lifetime settings
    struct Timing { ... }        // Upgrade intervals
    struct Limits { ... }        // Performance caps
    struct Visual { ... }        // Screen shake, trails
    struct Leveling { ... }      // XP formulas
    struct DropRates { ... }     // Blueprint RNG
}
```

### Helper Functions

```swift
BalanceConfig.waveHealthMultiplier(waveNumber:)
BalanceConfig.waveSpeedMultiplier(waveNumber:)
BalanceConfig.threatHealthMultiplier(threatLevel:)
BalanceConfig.threatSpeedMultiplier(threatLevel:)
BalanceConfig.threatDamageMultiplier(threatLevel:)
BalanceConfig.spawnDelay(waveNumber:)
BalanceConfig.xpRequired(level:)
BalanceConfig.levelMultiplier(level:)
BalanceConfig.towerCost(rarity:)
BalanceConfig.exportJSON() // For simulator tools
```

---

*Document Version: 2.0*
*Game: System: Reboot*
