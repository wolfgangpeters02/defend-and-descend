# System: Reboot - Game Balancing Blueprint

> **The Definitive Economy & Progression Guide**
> Last Updated: 2026-01-27

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
9. [UI Requirements](#9-ui-requirements)

---

## 1. Game Identity

### One-Line Pitch
> "SimCity meets Tower Defense on a motherboard - build your PC empire, defend it from viruses."

### Core Fantasy
You are a **System Administrator** building and defending a computer system. Your motherboard is your city. Viruses are the invaders. Components are your buildings and economy.

### Two Modes, One Goal
| Mode | Genre | Purpose |
|------|-------|---------|
| **Idle Mode** (Motherboard) | Tower Defense / City Builder | Build, expand, earn passive income |
| **Active Mode** (Dungeons) | Twin-Stick Shooter | Hunt blueprints, earn research Data |

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

**Role:** The MONEY. Earned passively, spent on purchases.

| Property | Value |
|----------|-------|
| Source | CPU (passive), GPU (passive + active) |
| Type | Soft Currency (farmable) |
| Spent On | Building towers, buying components, repairs |
| Storage Limit | Determined by HDD capacity |

**Example:**
```
HDD Capacity: 50,000 Ħ
Current Hash: 48,000 Ħ
Income: 100 Ħ/sec (at 100% Efficiency)

New Tower costs 5,000 Ħ → CAN AFFORD
PSU Upgrade costs 75,000 Ħ → CANNOT AFFORD (exceeds storage!)
  → Need to upgrade HDD first to store more
```

**Key Design Rules:**
- Hash accumulates over time (even offline, with cap)
- Income rate = Base Rate × Efficiency% × RAM Multiplier
- Storage limit creates a "savings goal" mechanic
- Losing Hash on death would be too punishing → instead, Efficiency drops

### 2.3 Data (◈)

**Role:** The RESEARCH CURRENCY. Unlocks new technology.

| Property | Value |
|----------|-------|
| Source | Active Mode (enemy drops, dungeon rewards) |
| Type | Premium/Skill Currency |
| Spent On | Researching blueprints, unlocking tech tree |
| Storage Limit | None (hoardable) |

**Example:**
```
Current Data: 2,500 ◈
"Splash Tower Blueprint" requires: 1,000 ◈ + Blueprint Item
"RAM Overclock" research requires: 5,000 ◈

You have the blueprint but only 2,500 ◈ → Need to farm more Data
```

**Key Design Rules:**
- Data is ONLY earned through active gameplay (skill-based)
- Creates motivation to play Active Mode
- Blueprints are rare drops; Data is the "crafting material"
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

### Component Tiers

Each component type has upgrade tiers:

**PSU Tiers:**
| Tier | Name | Capacity | Hash Cost | Unlock |
|------|------|----------|-----------|--------|
| 1 | Basic PSU | 450W | Starting | Free |
| 2 | Bronze PSU | 650W | 25,000 Ħ | Research: 500 ◈ |
| 3 | Silver PSU | 850W | 75,000 Ħ | Research: 2,000 ◈ |
| 4 | Gold PSU | 1200W | 200,000 Ħ | Research: 5,000 ◈ |
| 5 | Platinum PSU | 1600W | 500,000 Ħ | Research: 15,000 ◈ |

**CPU Tiers:**
| Tier | Name | Power Draw | Hash/sec | Fire Rate Bonus | Hash Cost |
|------|------|------------|----------|-----------------|-----------|
| 1 | i3 | 50W | 10 Ħ/s | +0% | Starting |
| 2 | i5 | 80W | 25 Ħ/s | +5% | 15,000 Ħ |
| 3 | i7 | 120W | 50 Ħ/s | +10% | 50,000 Ħ |
| 4 | i9 | 180W | 100 Ħ/s | +15% | 150,000 Ħ |
| 5 | Xeon | 250W | 200 Ħ/s | +25% | 400,000 Ħ |

**RAM Tiers (per stick, max 4):**
| Tier | Name | Power Draw | Income Bonus | Hash Cost |
|------|------|------------|--------------|-----------|
| 1 | DDR4 8GB | 20W | +10% | 5,000 Ħ |
| 2 | DDR4 16GB | 25W | +15% | 15,000 Ħ |
| 3 | DDR5 16GB | 30W | +20% | 40,000 Ħ |
| 4 | DDR5 32GB | 40W | +25% | 100,000 Ħ |

**HDD Tiers:**
| Tier | Name | Power Draw | Storage Cap | Hash Cost |
|------|------|------------|-------------|-----------|
| 1 | 500GB HDD | 10W | 25,000 Ħ | Starting |
| 2 | 1TB HDD | 15W | 75,000 Ħ | 10,000 Ħ |
| 3 | 2TB HDD | 20W | 200,000 Ħ | 35,000 Ħ |
| 4 | 500GB SSD | 25W | 500,000 Ħ | 100,000 Ħ |
| 5 | 2TB NVMe | 35W | 2,000,000 Ħ | 300,000 Ħ |

---

## 4. The Dual Game Modes

### 4.1 Idle Mode (The Motherboard)

**Genre:** Tower Defense + City Builder

**What You Do:**
- Place and upgrade Towers (Firewalls)
- Expand to new districts (RAM, GPU, Storage)
- Manage Power budget
- Watch Hash accumulate
- Defend against virus waves

**What You Earn:**
- Hash (passive, from CPU/GPU)
- Nothing else - this is the "farming" mode

**When to Play:**
- When you need to accumulate Hash
- When you want to relax and watch progress
- When waiting for enough storage to afford something

### 4.2 Active Mode (The Dungeons)

**Genre:** Twin-Stick Shooter / Roguelite

**What You Do:**
- Enter a "Sector" (dungeon)
- Fight through virus swarms
- Defeat boss at the end
- Collect drops

**What You Earn:**
- Data (◈) - from all enemy kills
- Blueprints - rare drops from bosses/chests
- Sector Keys - unlock new areas on motherboard

**When to Play:**
- When you hit a "Tech Wall" (need to research something)
- When you need a specific Blueprint
- When you want action gameplay

### Mode Switching Motivation

| Situation | Problem | Solution |
|-----------|---------|----------|
| "I can't build more towers" | Power limit reached | Upgrade PSU (costs Hash) |
| "I can't afford the PSU" | Not enough Hash | Wait for income OR upgrade HDD |
| "I can't upgrade PSU" | Not researched | Play Active Mode, get Data |
| "I don't have the blueprint" | Missing item | Play Active Mode, farm boss |

---

## 5. The Gameplay Loop

### The Core Loop (5-15 minutes)

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │  BUILD   │───▶│  DEFEND  │───▶│  EARN    │              │
│  │ (Spend)  │    │ (Play)   │    │ (Gain)   │              │
│  └──────────┘    └──────────┘    └──────────┘              │
│       ▲                               │                     │
│       │                               │                     │
│       └───────────────────────────────┘                     │
│                                                             │
│  IDLE MODE: Hash accumulates, Efficiency maintained         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ Hit a wall?
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │  ENTER   │───▶│  FIGHT   │───▶│  LOOT    │              │
│  │ (Sector) │    │ (Skill)  │    │ (Data)   │              │
│  └──────────┘    └──────────┘    └──────────┘              │
│       │                               │                     │
│       │                               │                     │
│       └───────────────────────────────┘                     │
│                                                             │
│  ACTIVE MODE: Earn Data, find Blueprints                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Session Example

**Day 1 (New Player):**
1. Start with CPU + PSU + 2 basic towers
2. Defend first wave, earn Hash
3. Build 3rd tower (uses most of Power budget)
4. Hit Power wall - can't build 4th tower
5. Research "Bronze PSU" (costs 500 ◈)
6. Don't have enough Data → Enter Sector 1
7. Complete dungeon, earn 600 ◈
8. Research Bronze PSU
9. Buy Bronze PSU (costs 25,000 Ħ)
10. Build more towers!

---

## 6. Progression & Unlocks

### Map Expansion

The motherboard starts small and expands:

```
Phase 1 (Start):
┌─────────────┐
│    CPU      │  ← Only the CPU district
│   (Start)   │     450W PSU, basic towers
└─────────────┘

Phase 2 (First Expansion):
        ┌─────────────┐
        │    RAM      │  ← Unlocked with "North Bridge Key"
        │  District   │     Costs 10,000 Ħ to repair bus
        └──────┬──────┘
               │
┌──────────────┴──────────────┐
│           CPU               │
└─────────────────────────────┘

Phase 3+ (Full Board):
        ┌─────────────┐
        │    RAM      │
        └──────┬──────┘
               │
┌──────┐ ┌─────┴─────┐ ┌──────┐
│ I/O  │─│    CPU    │─│STORAGE│
└──────┘ └─────┬─────┘ └──────┘
               │
        ┌──────┴──────┐
        │    GPU      │  ← WARNING: Opens new spawn lane!
        └─────────────┘
```

### Research Tree (Simplified)

```
[Basic Towers] ──▶ [Splash Tower] ──▶ [Chain Lightning]
      │                  │
      ▼                  ▼
[Bronze PSU] ──▶ [Silver PSU] ──▶ [Gold PSU]
      │
      ▼
[RAM Slot 1] ──▶ [RAM Slot 2] ──▶ [RAM Overclock]
      │
      ▼
[HDD Upgrade] ──▶ [SSD Upgrade] ──▶ [NVMe]
```

### Blueprint Sources

| Blueprint | Source | Drop Rate |
|-----------|--------|-----------|
| Basic Towers | Starting | 100% |
| Bronze PSU | Sector 1 Boss | 25% |
| Splash Tower | Sector 2 Chest | 15% |
| RAM Slot 1 | Sector 1 Boss | 25% |
| Silver PSU | Sector 3 Boss | 20% |
| GPU Slot | Sector 5 Boss | 10% |

---

## 7. Loss Conditions & Recovery

### What Happens When Viruses Reach CPU?

**NOT Game Over.** Instead:

1. **Efficiency Drops**
   - Each virus that reaches CPU: -5% Efficiency
   - Efficiency affects Hash income: `Income = Base × Efficiency%`
   - At 0% Efficiency: You earn nothing (but don't lose anything)

2. **Recovery**
   - Efficiency regenerates slowly over time (+1%/10 seconds)
   - RAM upgrades speed up recovery
   - Killing viruses doesn't restore Efficiency (only time does)

3. **Why This Works**
   - Punishing (you lose income)
   - Not frustrating (you don't lose stuff)
   - Creates urgency (fix your defense!)
   - Recoverable (time heals)

### Example Scenario

```
Before Attack:
- Efficiency: 100%
- Income: 50 Ħ/sec

5 Viruses reach CPU:
- Efficiency: 100% - (5 × 5%) = 75%
- Income: 50 × 0.75 = 37.5 Ħ/sec

Recovery (with base regen):
- +1% per 10 seconds
- Full recovery in ~250 seconds (~4 minutes)
```

---

## 8. Balancing Tables

### Starting Resources

| Resource | Starting Value |
|----------|----------------|
| Power Capacity | 450W |
| Hash | 500 Ħ |
| Hash Storage | 25,000 Ħ |
| Data | 0 ◈ |
| Efficiency | 100% |

### Tower Costs (Power + Hash)

| Tower | Rarity | Power Draw | Hash Cost | Research Cost |
|-------|--------|------------|-----------|---------------|
| Pulse Laser | Common | 15W | 500 Ħ | Free |
| Firewall Basic | Common | 20W | 750 Ħ | Free |
| Antivirus | Rare | 35W | 2,500 Ħ | 500 ◈ |
| Splash Cannon | Rare | 50W | 5,000 Ħ | 1,000 ◈ |
| Chain Lightning | Epic | 75W | 15,000 Ħ | 3,000 ◈ |
| Quarantine Zone | Epic | 100W | 30,000 Ħ | 5,000 ◈ |
| Kernel Nuke | Legendary | 150W | 100,000 Ħ | 15,000 ◈ |

### Income Formulas

```
Hash Income = (CPU_Base + GPU_Base) × (1 + RAM_Bonus) × Efficiency%

Example:
- i5 CPU: 25 Ħ/s base
- No GPU: 0 Ħ/s
- 2x DDR4 16GB RAM: +30% bonus
- Efficiency: 80%

Income = (25 + 0) × (1 + 0.30) × 0.80 = 26 Ħ/s
```

### Data Drops (Active Mode)

| Enemy Type | Data Drop |
|------------|-----------|
| Basic Virus | 1-2 ◈ |
| Fast Virus | 2-3 ◈ |
| Tank Virus | 5-8 ◈ |
| Swarm (10 enemies) | 15-25 ◈ |
| Mini-Boss | 50-100 ◈ |
| Sector Boss | 200-500 ◈ |

---

## 9. UI Requirements

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
│ Splash Tower                        │
│ ─────────────────────────────────── │
│ Power: 50W (You have: 70W free)  ✓  │
│ Cost: 5,000 Ħ (You have: 12,450) ✓  │
│ Research: UNLOCKED                ✓  │
│                                     │
│         [ BUILD ]                   │
└─────────────────────────────────────┘
```

### Blocked Build Shows WHY

```
┌─────────────────────────────────────┐
│ Chain Lightning                     │
│ ─────────────────────────────────── │
│ Power: 75W (You have: 20W free)  ✗  │
│   → Upgrade PSU for more Power      │
│ Cost: 15,000 Ħ (You have: 12,450) ✗ │
│   → Need 2,550 more Hash            │
│ Research: LOCKED                  ✗  │
│   → Requires: 3,000 ◈ + Blueprint   │
│                                     │
│         [ LOCKED ]                  │
└─────────────────────────────────────┘
```

---

## Summary: The Three Walls

| Wall | "I can't because..." | Solution |
|------|---------------------|----------|
| **Power Wall** | "Not enough Watts" | Upgrade PSU |
| **Hash Wall** | "Can't afford it" | Wait for income / Upgrade HDD |
| **Tech Wall** | "Haven't researched" | Play Active Mode |

This creates **meaningful choices** and **clear goals** at every stage of the game.

---

*Document Version: 1.0*
*Game: System: Reboot*
