# System: Reboot - Tower & Weapon Reference

This document details all protocols in System: Reboot. Each protocol functions as both a **Firewall** (tower in TD mode) and a **Weapon** (in boss fights).

---

## Core Mechanics

### Dual-Mode System
Every protocol has two stat configurations:
- **Firewall Mode (TD)**: Stationary defense with focus on range, fire rate, and area control
- **Weapon Mode (Boss)**: Player-wielded with focus on projectile spread, speed, and DPS

### Power System
Firewalls consume power while placed. Power is a limited resource upgraded via PSU:
- **Base Capacity**: 300W (PSU Level 1)
- **Max Capacity**: 2,300W (PSU Level 10)

### Upgrade System
- All protocols share the same exponential cost formula: `baseCost × 2^(level-1)`
- Max level: 10
- Upgrading a protocol upgrades ALL towers of that type on the board

---

## Protocol Reference

### 1. KERNEL PULSE (Starter)

| Property | Value |
|----------|-------|
| Rarity | Common |
| Color | Cyan (#00d4ff) |
| Icon | `dot.circle.and.hand.point.up.left.fill` |
| Role | Balanced all-rounder |

**Firewall Stats (TD Mode)**
| Stat | Base Value | Notes |
|------|------------|-------|
| Damage | 10 | Reliable single-target |
| Range | 120 | Medium coverage |
| Fire Rate | 1.0/s | Steady |
| Pierce | 1 | Single target |
| Splash | 0 | No AoE |
| Power Draw | 15W | Lowest power cost |

**Weapon Stats (Boss Mode)**
| Stat | Base Value |
|------|------------|
| Damage | 8 |
| Fire Rate | 2.0/s |
| Projectiles | 1 |
| Spread | 0 |
| Pierce | 1 |
| Speed | 400 |

**Costs**
- Compile: Free (starts unlocked)
- Placement: 50 Hash
- Upgrade Base: 50 Hash

---

### 2. BURST PROTOCOL

| Property | Value |
|----------|-------|
| Rarity | Common |
| Color | Orange (#f97316) |
| Icon | `burst.fill` |
| Role | AoE crowd control |

**Firewall Stats (TD Mode)**
| Stat | Base Value | Notes |
|------|------------|-------|
| Damage | 8 | Per target in splash |
| Range | 100 | Short range |
| Fire Rate | 0.8/s | Moderate |
| Pierce | 1 | - |
| **Splash** | **40** | **40-unit AoE radius** |
| Power Draw | 20W | Efficient |

**Weapon Stats (Boss Mode)**
| Stat | Base Value | Notes |
|------|------------|-------|
| Damage | 6 | Per projectile |
| Fire Rate | 0.8/s | - |
| **Projectiles** | **5** | **Shotgun spread** |
| **Spread** | **0.5 rad** | **Wide cone** |
| Pierce | 1 | - |
| Speed | 350 | - |

**Costs**
- Compile: 100 Hash
- Placement: 50 Hash
- Upgrade Base: 50 Hash

**Strategy**: Place at choke points for maximum crowd damage. In boss mode, get close for shotgun burst.

---

### 3. TRACE ROUTE

| Property | Value |
|----------|-------|
| Rarity | Rare |
| Color | Blue (#3b82f6) |
| Icon | `scope` |
| Role | Long-range sniper |

**Firewall Stats (TD Mode)**
| Stat | Base Value | Notes |
|------|------------|-------|
| **Damage** | **50** | **High single-target** |
| **Range** | **250** | **Longest range** |
| Fire Rate | 0.4/s | Slow, deliberate |
| **Pierce** | **3** | **Penetrates enemies** |
| Splash | 0 | - |
| Power Draw | 35W | Moderate |

**Weapon Stats (Boss Mode)**
| Stat | Base Value | Notes |
|------|------------|-------|
| **Damage** | **40** | **Heavy hits** |
| Fire Rate | 0.5/s | - |
| Projectiles | 1 | Single shot |
| Spread | 0 | Perfect accuracy |
| **Pierce** | **5** | **Penetrates multiple** |
| **Speed** | **800** | **Fastest projectile** |

**Costs**
- Compile: 200 Hash
- Placement: 100 Hash
- Upgrade Base: 100 Hash

**Strategy**: Position at the back for maximum coverage. Excellent against boss targets.

---

### 4. ICE SHARD

| Property | Value |
|----------|-------|
| Rarity | Rare |
| Color | Light Cyan (#22d3ee) |
| Icon | `snowflake` |
| Role | Crowd control / slow support |

**Firewall Stats (TD Mode)**
| Stat | Base Value | Notes |
|------|------------|-------|
| Damage | 5 | Low damage |
| Range | 130 | Medium |
| **Fire Rate** | **1.5/s** | **Fast application** |
| Pierce | 1 | - |
| Splash | 0 | - |
| **Slow** | **50%** | **Half speed debuff** |
| **Slow Duration** | **2.0s** | **Lasting effect** |
| Power Draw | 30W | - |

**Weapon Stats (Boss Mode)**
| Stat | Base Value | Notes |
|------|------------|-------|
| Damage | 4 | - |
| **Fire Rate** | **3.0/s** | **Rapid fire** |
| Projectiles | 1 | - |
| Spread | 0 | - |
| Pierce | 1 | - |
| Speed | 500 | - |

**Costs**
- Compile: 200 Hash
- Placement: 100 Hash
- Upgrade Base: 100 Hash

**Strategy**: Pair with high-damage towers. Slowed enemies take more hits from other defenses.

---

### 5. FORK BOMB

| Property | Value |
|----------|-------|
| Rarity | Epic |
| Color | Purple (#a855f7) |
| Icon | `arrow.triangle.branch` |
| Role | Multi-target spray |

**Firewall Stats (TD Mode)**
| Stat | Base Value | Notes |
|------|------------|-------|
| Damage | 12 | Per projectile |
| Range | 140 | Medium-long |
| Fire Rate | 0.7/s | - |
| **Projectiles** | **3** | **Triple shot** |
| Pierce | 1 | - |
| Splash | 0 | - |
| **Power Draw** | **60W** | **High** |

**Weapon Stats (Boss Mode)**
| Stat | Base Value | Notes |
|------|------------|-------|
| Damage | 10 | Per projectile |
| Fire Rate | 1.0/s | - |
| **Projectiles** | **8** | **Spread cannon** |
| **Spread** | **0.8 rad** | **Very wide** |
| Pierce | 1 | - |
| Speed | 380 | - |

**Costs**
- Compile: 400 Hash
- Placement: 200 Hash
- Upgrade Base: 200 Hash

**Strategy**: Effective against swarms. Position where paths converge for multi-target hits.

---

### 6. ROOT ACCESS

| Property | Value |
|----------|-------|
| Rarity | Epic |
| Color | Red (#ef4444) |
| Icon | `terminal.fill` |
| Role | Heavy single-target cannon |

**Firewall Stats (TD Mode)**
| Stat | Base Value | Notes |
|------|------------|-------|
| **Damage** | **80** | **Highest base damage** |
| Range | 160 | Long |
| **Fire Rate** | **0.3/s** | **Slowest** |
| Pierce | 1 | - |
| Splash | 0 | - |
| **Power Draw** | **75W** | **Very high** |

**Weapon Stats (Boss Mode)**
| Stat | Base Value | Notes |
|------|------------|-------|
| **Damage** | **60** | **Laser cannon** |
| Fire Rate | 0.4/s | - |
| Projectiles | 1 | - |
| Spread | 0 | - |
| Pierce | 1 | - |
| Speed | 600 | - |

**Costs**
- Compile: 400 Hash
- Placement: 200 Hash
- Upgrade Base: 200 Hash

**Strategy**: Anti-boss specialist. Devastating when combined with Ice Shard slow.

---

### 7. OVERFLOW

| Property | Value |
|----------|-------|
| Rarity | Legendary |
| Color | Amber (#f59e0b) |
| Icon | `bolt.horizontal.fill` |
| Role | Chain damage specialist |

**Firewall Stats (TD Mode)**
| Stat | Base Value | Notes |
|------|------------|-------|
| Damage | 15 | Per target in chain |
| Range | 150 | Long |
| Fire Rate | 0.8/s | - |
| Pierce | 1 | - |
| Splash | 0 | - |
| **Special** | **Chain** | **Jumps to 3 nearby** |
| **Power Draw** | **120W** | **Highest** |

**Weapon Stats (Boss Mode)**
| Stat | Base Value | Notes |
|------|------------|-------|
| Damage | 12 | - |
| Fire Rate | 1.2/s | - |
| Projectiles | 1 | - |
| Spread | 0 | - |
| Pierce | 1 | - |
| Speed | 450 | - |
| **Special** | **Ricochet** | **Bounces between 3** |

**Costs**
- Compile: 800 Hash
- Placement: 400 Hash
- Upgrade Base: 400 Hash

**Strategy**: Excels against grouped enemies. Chain damage multiplies value in crowded lanes.

---

### 8. NULL POINTER

| Property | Value |
|----------|-------|
| Rarity | Legendary |
| Color | Dark Red (#dc2626) |
| Icon | `exclamationmark.triangle.fill` |
| Role | Execution finisher |

**Firewall Stats (TD Mode)**
| Stat | Base Value | Notes |
|------|------------|-------|
| Damage | 25 | Base damage |
| Range | 140 | Medium-long |
| Fire Rate | 0.6/s | - |
| Pierce | 1 | - |
| Splash | 0 | - |
| **Special** | **Execute** | **Bonus damage to low HP** |
| **Power Draw** | **100W** | **Very high** |

**Weapon Stats (Boss Mode)**
| Stat | Base Value | Notes |
|------|------------|-------|
| Damage | 20 | - |
| Fire Rate | 0.8/s | - |
| Projectiles | 1 | - |
| Spread | 0 | - |
| Pierce | 1 | - |
| Speed | 500 | - |
| **Special** | **Critical** | **Chance for 2x damage** |

**Costs**
- Compile: 800 Hash
- Placement: 400 Hash
- Upgrade Base: 400 Hash

**Strategy**: Place late in the path to execute wounded enemies. Synergizes with any damage-dealer.

---

## Stat Scaling

### Level Multipliers
All protocols scale the same way per level:

| Level | Damage Mult | Range Bonus | Fire Rate Bonus |
|-------|-------------|-------------|-----------------|
| 1 | 1.0x | +0% | +0% |
| 2 | 2.0x | +5% | +3% |
| 3 | 3.0x | +10% | +6% |
| 4 | 4.0x | +15% | +9% |
| 5 | 5.0x | +20% | +12% |
| 6 | 6.0x | +25% | +15% |
| 7 | 7.0x | +30% | +18% |
| 8 | 8.0x | +35% | +21% |
| 9 | 9.0x | +40% | +24% |
| 10 | 10.0x | +45% | +27% |

### Upgrade Costs (Example: Common Protocol)
Base upgrade cost: 50 Hash

| Upgrade | Cost | Total Invested |
|---------|------|----------------|
| Lv1 → 2 | 50 | 50 |
| Lv2 → 3 | 100 | 150 |
| Lv3 → 4 | 200 | 350 |
| Lv4 → 5 | 400 | 750 |
| Lv5 → 6 | 800 | 1,550 |
| Lv6 → 7 | 1,600 | 3,150 |
| Lv7 → 8 | 3,200 | 6,350 |
| Lv8 → 9 | 6,400 | 12,750 |
| Lv9 → 10 | 12,800 | 25,550 |

---

## Quick Reference Table

| Protocol | Rarity | Power | Damage | Range | Rate | Special |
|----------|--------|-------|--------|-------|------|---------|
| Kernel Pulse | Common | 15W | 10 | 120 | 1.0 | None |
| Burst Protocol | Common | 20W | 8 | 100 | 0.8 | Splash 40 |
| Trace Route | Rare | 35W | 50 | 250 | 0.4 | Pierce 3 |
| Ice Shard | Rare | 30W | 5 | 130 | 1.5 | Slow 50%/2s |
| Fork Bomb | Epic | 60W | 12 | 140 | 0.7 | 3-shot |
| Root Access | Epic | 75W | 80 | 160 | 0.3 | - |
| Overflow | Legendary | 120W | 15 | 150 | 0.8 | Chain 3 |
| Null Pointer | Legendary | 100W | 25 | 140 | 0.6 | Execute |

---

## Synergy Recommendations

### Crowd Control Combo
**Ice Shard + Root Access**
- Ice slows enemies, Root Access obliterates them while stationary

### Swarm Defense
**Burst Protocol + Fork Bomb**
- Maximum AoE coverage for dense enemy waves

### Boss Killer Setup
**Trace Route + Null Pointer**
- Trace chunks HP from range, Null finishes with execute bonus

### Efficient Early Game
**Kernel Pulse + Ice Shard**
- Low power draw, good coverage while building economy

### Late Game Power Play
**Overflow + Null Pointer**
- Chain spreads damage, execute cleans up wounded targets



Tower,"The ""Why"" (Player Motivation)","The ""When"" (Game State)"
Kernel Pulse,"""I have 15 Power left and need something.""",Filler / Early Game.
Fragmenter,"""Enemies are clumping, but they have too much HP to one-shot.""",Mid-waves / vs. High HP Swarms.
Pinger,"""My big towers aren't killing the Boss fast enough.""",Synergy (Placed before Kill Zone).
Throttler,"""The fast enemies are leaking past my defenses.""",Control (Placed at corners).
Recursion,"""There are 50 weak enemies on screen.""","Cleanup (Vs. ""Trash mobs"")."
Root Access,"""This one specific Tank enemy won't die.""",Counter (Vs. Armor/High HP).
Garbage Collector,"""I'm winning easily, let me get greedy.""",Economy (Placed at the very end).