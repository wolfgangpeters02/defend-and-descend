# Board Mechanics Documentation

Complete documentation of towers (Protocols/Firewalls) and enemies in the Motherboard TD mode.

---

## Table of Contents

1. [Protocols (Towers/Firewalls)](#protocols-towersfirewalls)
2. [Tower Visual System](#tower-visual-system)
3. [Tower Animations](#tower-animations)
4. [Upgrade System](#upgrade-system)
5. [Enemies](#enemies)
6. [Enemy Spawning Systems](#enemy-spawning-systems)
7. [Power System](#power-system)
8. [Economy](#economy)

---

## Protocols (Towers/Firewalls)

Protocols are dual-purpose cards that function as **Firewalls** (towers) in TD mode. Each has unique stats, visuals, and special abilities.

### Protocol Summary Table

| Protocol | Rarity | Power Draw | Base Damage | Range | Fire Rate | Special |
|----------|--------|------------|-------------|-------|-----------|---------|
| Kernel Pulse | Common | 15W | 10 | 120 | 1.0/s | - |
| Burst Protocol | Common | 20W | 8 | 100 | 0.8/s | 40 Splash |
| Trace Route | Rare | 35W | 50 | 250 | 0.4/s | 3 Pierce |
| Ice Shard | Rare | 30W | 5 | 130 | 1.5/s | 50% Slow (2s) |
| Fork Bomb | Epic | 60W | 12 | 140 | 0.7/s | 3 Projectiles |
| Root Access | Epic | 75W | 80 | 160 | 0.3/s | High Damage |
| Overflow | Legendary | 120W | 15 | 150 | 0.8/s | Chain Lightning |
| Null Pointer | Legendary | 100W | 25 | 140 | 0.6/s | Execute (low HP bonus) |

---

### Protocol Details

#### 1. Kernel Pulse
**Starter Protocol** - Standard system defense

| Property | Value |
|----------|-------|
| **ID** | `kernel_pulse` |
| **Rarity** | Common |
| **Icon** | `dot.circle.and.hand.point.up.left.fill` |
| **Color** | Cyan (#00d4ff) |
| **Power Draw** | 15W |
| **Compile Cost** | 0 (starts compiled) |
| **Upgrade Cost** | 50 Hash/level |

**Firewall Stats:**
- Damage: 10 (×Level scaling)
- Range: 120 (+5%/level)
- Fire Rate: 1.0/s (+3%/level)
- Projectiles: 1
- Pierce: 1

**Visual Archetype:** Projectile
- Octagonal tech platform with circuit traces
- Targeting reticle with 4 crosshairs and brackets
- Precision barrel (6×22 dark gray)
- Center dot glow pulse animation

---

#### 2. Burst Protocol
**Splash Damage Tower** - Overwhelm with concentrated firepower

| Property | Value |
|----------|-------|
| **ID** | `burst_protocol` |
| **Rarity** | Common |
| **Icon** | `burst.fill` |
| **Color** | Orange (#f97316) |
| **Power Draw** | 20W |
| **Compile Cost** | 100 Hash |
| **Upgrade Cost** | 50 Hash/level |

**Firewall Stats:**
- Damage: 8
- Range: 100
- Fire Rate: 0.8/s
- Projectiles: 1
- Pierce: 1
- **Splash Radius: 40**

**Visual Archetype:** Artillery
- Reinforced square platform with corner bolts
- Rectangular armored unit (28×28)
- Heavy barrel (12×18) with muzzle brake
- Ammo glow indicator with pulse animation
- Large muzzle flash with smoke particles

---

#### 3. Trace Route
**Sniper Tower** - Precision strikes from extreme range

| Property | Value |
|----------|-------|
| **ID** | `trace_route` |
| **Rarity** | Rare |
| **Icon** | `scope` |
| **Color** | Blue (#3b82f6) |
| **Power Draw** | 35W |
| **Compile Cost** | 200 Hash |
| **Upgrade Cost** | 100 Hash/level |

**Firewall Stats:**
- Damage: 50
- Range: 250 (highest range)
- Fire Rate: 0.4/s (slow)
- Projectiles: 1
- **Pierce: 3**

**Visual Archetype:** Beam
- Tech grid platform with capacitor nodes
- Rectangular emitter (26×26) with central lens
- Colored barrel (8×24) with focusing lens
- Lens pulse animation with capacitor charging sequence

---

#### 4. Ice Shard
**Slow/Utility Tower** - Cryogenic defense

| Property | Value |
|----------|-------|
| **ID** | `ice_shard` |
| **Rarity** | Rare |
| **Icon** | `snowflake` |
| **Color** | Cyan (#22d3ee) |
| **Power Draw** | 30W |
| **Compile Cost** | 200 Hash |
| **Upgrade Cost** | 100 Hash/level |

**Firewall Stats:**
- Damage: 5 (low)
- Range: 130
- Fire Rate: 1.5/s (fast)
- Projectiles: 1
- Pierce: 1
- **Slow: 50%**
- **Slow Duration: 2.0s**

**Visual Archetype:** Frost
- Crystalline base with frost particle emanation
- Multi-faceted 6-pointed crystal (size 16)
- Crystal emitter (4×20) with ice crystal tip
- 3 orbiting ice shards at different rotation speeds
- Ice shard burst muzzle flash

---

#### 5. Fork Bomb
**Multi-Target Tower** - Recursive attack pattern

| Property | Value |
|----------|-------|
| **ID** | `fork_bomb` |
| **Rarity** | Epic |
| **Icon** | `arrow.triangle.branch` |
| **Color** | Purple (#a855f7) |
| **Power Draw** | 60W |
| **Compile Cost** | 400 Hash |
| **Upgrade Cost** | 200 Hash/level |

**Firewall Stats:**
- Damage: 12
- Range: 140
- Fire Rate: 0.7/s
- **Projectiles: 3**
- Pierce: 1

**Visual Archetype:** Multishot
- Server rack style base
- Central hub (8 radius) + 5 process nodes in pentagon
- Lines connecting hub to nodes
- Multiple emitters (3 small circular)
- Hub pulse with data flow dots animation

---

#### 6. Root Access
**High Damage Tower** - Elevated privileges, devastating power

| Property | Value |
|----------|-------|
| **ID** | `root_access` |
| **Rarity** | Epic |
| **Icon** | `terminal.fill` |
| **Color** | Red (#ef4444) |
| **Power Draw** | 75W |
| **Compile Cost** | 400 Hash |
| **Upgrade Cost** | 200 Hash/level |

**Firewall Stats:**
- **Damage: 80** (highest single-target)
- Range: 160
- Fire Rate: 0.3/s (slow)
- Projectiles: 1
- Pierce: 1

**Visual Archetype:** Beam
- Tech grid platform with capacitor nodes
- High-intensity lens with bright white stroke
- Lens flare streaks on firing
- Overexposure effect muzzle flash

---

#### 7. Overflow
**Chain Lightning Tower** - Cascading system failures

| Property | Value |
|----------|-------|
| **ID** | `overflow` |
| **Rarity** | Legendary |
| **Icon** | `bolt.horizontal.fill` |
| **Color** | Amber (#f59e0b) |
| **Power Draw** | 120W |
| **Compile Cost** | 800 Hash |
| **Upgrade Cost** | 400 Hash/level |

**Firewall Stats:**
- Damage: 15
- Range: 150
- Fire Rate: 0.8/s
- Projectiles: 1
- Pierce: 1
- **Special: Chain** (damage jumps to nearby enemies)

**Visual Archetype:** Tesla
- Insulator base with coil foundation
- Cylindrical base (28×14) + conductor spike (6×20)
- 4 discharge nodes with cyan glow
- Tesla antenna (10×26) with top sphere
- Electric arc animations between nodes
- Radiating electric sparks on fire

---

#### 8. Null Pointer
**Execute Tower** - Critical exceptions terminate instantly

| Property | Value |
|----------|-------|
| **ID** | `null_pointer` |
| **Rarity** | Legendary |
| **Icon** | `exclamationmark.triangle.fill` |
| **Color** | Crimson (#dc2626) |
| **Power Draw** | 100W |
| **Compile Cost** | 800 Hash |
| **Upgrade Cost** | 400 Hash/level |

**Firewall Stats:**
- Damage: 25
- Range: 140
- Fire Rate: 0.6/s
- Projectiles: 1
- Pierce: 1
- **Special: Execute** (bonus damage to low HP enemies)

**Visual Archetype:** Execute
- Corrupted/glitched platform
- Warning triangle (size 18) with exclamation mark
- Glitched emitter (8×14 red rectangle)
- Warning triangle pulse animation
- Glitch position jitter (±2-3 pixels)
- Falling code particles (0-1-!-?-#-@-%)
- Red fatal error flash on fire

---

## Tower Visual System

Towers use an 8-layer procedural rendering system:

| Layer | Z-Position | Purpose |
|-------|------------|---------|
| Outer Glow | -3 | Soft aura, breathing animation |
| Mid Glow | -2 | Medium intensity pulse |
| Core Glow | -1 | Tight bright shimmer |
| Base Platform | 0 | Archetype-specific foundation |
| Tower Body | 1 | Main structure |
| Barrel/Emitter | 2 | Weapon output |
| Detail Elements | 3 | Orbiting/special components |
| Muzzle Flash | 10 | Combat effect (hidden until fired) |

### Glow Layer Properties by Rarity

| Rarity | Outer Radius | Mid Radius | Core Radius | Features |
|--------|--------------|------------|-------------|----------|
| Common | 28 | 22 | 16 | Single core glow |
| Rare | 28 | 22 | 16 | Outer ring appears |
| Epic | 30 | 24 | 18 | Rotating outer ring |
| Legendary | 35 | 26 | 20 | Brightest, enhanced effects |

### Tower Archetypes

| Archetype | Used By | Visual Theme |
|-----------|---------|--------------|
| Projectile | Kernel Pulse, Trace Route | Targeting reticle, brackets |
| Artillery | Burst Protocol | Armored, ammo indicator |
| Frost | Ice Shard | Crystalline, orbiting shards |
| Beam | Root Access | Tech grid, charging lens |
| Tesla | Overflow | Coils, electric arcs |
| Multishot | Fork Bomb | Server rack, hub nodes |
| Execute | Null Pointer | Corrupted, glitch effects |

---

## Tower Animations

### Idle Animations (continuous)

| Archetype | Animation Details |
|-----------|-------------------|
| Projectile | Ring rotation (12s), bracket pulse, center dot glow |
| Artillery | Ammo glow pulse (0.8s), barrel sway (±0.03 rad), capacitor cascade |
| Frost | Ice shard orbit (6-7s), shard float (±2 units), frost particles |
| Beam | Lens pulse (0.8s), capacitor charging sequence |
| Tesla | Conductor pulse (0.3s), electric arcs between nodes |
| Multishot | Hub pulse (0.6s), node cascade (0.2s stagger), data flow dots |
| Execute | Triangle pulse (0.3s), exclamation blink, glitch jitter (±2px) |

### Combat Animations

**Muzzle Flash:**
- Duration: 0.15s
- Scale: 1.3 → 0.8
- Blend mode: Additive for glow

**Enhanced Muzzle Flashes by Archetype:**
- **Artillery:** 2.0× scale, smoke ring, 3-5 rising smoke particles
- **Beam:** Overexposure, 4 lens flare streaks at 45° angles
- **Tesla:** 6-8 electric sparks radiating outward, cyan flicker
- **Frost:** 4-6 ice crystal shards in burst pattern

**Recoil Animation:**
- Barrel knockback: -3 units over 0.05s
- Barrel recovery: Ease-out over 0.15s
- Body shake: ±1.5 units over 0.1s

**Cooldown Arc:**
- Circular arc showing time until next attack
- Progress 0 = full arc, 1.0 = ready to fire
- Line width: 3, rounded caps

---

## Upgrade System

### Level Scaling

Protocols level from 1-10 with aggressive scaling:

```
Level Multiplier = Level (e.g., Level 5 = 5.0× stats)
```

| Stat | Scaling Per Level |
|------|-------------------|
| Damage | ×Level (linear) |
| Range | +5% per level |
| Fire Rate | +3% per level |
| Power Draw | Does not scale |

### Upgrade Costs

```
Upgrade Cost = Base Upgrade Cost × Current Level
```

| Rarity | Base Cost | Level 1→2 | Level 9→10 |
|--------|-----------|-----------|------------|
| Common | 50 Hash | 50 | 450 |
| Rare | 100 Hash | 100 | 900 |
| Epic | 200 Hash | 200 | 1,800 |
| Legendary | 400 Hash | 400 | 3,600 |

### Protocol Compilation

Protocols start as locked blueprints (except Kernel Pulse):

| Rarity | Compile Cost |
|--------|--------------|
| Common (Starter) | 0 (pre-compiled) |
| Common | 100 Hash |
| Rare | 200 Hash |
| Epic | 400 Hash |
| Legendary | 800 Hash |

---

## Enemies

### Enemy Summary Table

| Enemy | Health | Speed | Damage | Coin Value | Size | Shape | Color |
|-------|--------|-------|--------|------------|------|-------|-------|
| Basic | 21 | 80 | 10 | 1 | 12 | Square | Red #ff4444 |
| Fast | 11 | 150 | 5 | 2 | 8 | Triangle | Green #44ff44 |
| Tank | 70 | 40 | 20 | 5 | 20 | Hexagon | Blue #4444ff |
| Elite | 120 | 100 | 25 | 15 | 16 | Diamond | Orange #ffaa00 |
| Void Minion | 40 | 100 | 15 | 3 | 14 | Triangle | Purple #6600aa |
| Boss | 350 | 60 | 30 | 50 | 30 | Hexagon | Magenta #ff00ff |
| Cyberboss | 12,500 | 100 | 50 | 500 | 50 | Hexagon | Cyan #00ffff |
| Void Harbinger | 25,000 | 80 | 60 | 1,000 | 60 | Hexagon | Purple #8800ff |

---

### Enemy Details

#### 1. Basic Enemy
**Entry-level threat**

- **ID:** `basic`
- **Role:** Baseline enemy for early game
- **Stats:** 21 HP, 80 speed, 10 damage
- **Visual:** Red square (12px)
- **Behavior:** Standard path following, no special abilities
- **Spawn:** Always available (threat level 0+)

---

#### 2. Fast Enemy
**Speed threat**

- **ID:** `fast`
- **Role:** Pressure unit forcing quick reactions
- **Stats:** 11 HP (fragile), 150 speed (1.875× basic), 5 damage
- **Visual:** Green triangle (8px, smallest)
- **Behavior:** Pure speed threat, dies quickly but reaches core fast
- **Spawn:** Threat level ≥ 2.0

---

#### 3. Tank Enemy
**Durability threat**

- **ID:** `tank`
- **Role:** Blocking unit requiring sustained firepower
- **Stats:** 70 HP (3.3× basic), 40 speed (0.5× basic), 20 damage
- **Visual:** Blue hexagon (20px)
- **Behavior:** Slow but absorbs significant damage
- **Spawn:** Threat level ≥ 5.0

---

#### 4. Elite Trooper
**Hybrid threat**

- **ID:** `elite`
- **Role:** High-value mixed threat (speed + durability)
- **Stats:** 120 HP, 100 speed, 25 damage
- **Visual:** Orange diamond (16px)
- **Behavior:** Combines fast movement with substantial health
- **Spawn:** Threat level ≥ 8.0

---

#### 5. Void Minion
**Swarm unit**

- **ID:** `voidminion`
- **Role:** Group-based threat, dangerous in numbers
- **Stats:** 40 HP, 100 speed, 15 damage
- **Visual:** Purple triangle (14px)
- **Behavior:** Spawns in groups, weak individually but overwhelming in volume
- **Spawn:** Threat level ≥ 4.0

---

#### 6. Boss (Wave Boss)
**Major challenge**

- **ID:** `boss`
- **Role:** Wave milestone threat
- **Stats:** 350 HP (16.7× basic), 60 speed, 30 damage
- **Visual:** Magenta hexagon (30px) with glow and pulsing animation
- **Behavior:**
  - 4-phase system: transitions at 75%, 50%, 25% health
  - Each phase: +20% speed, +15% damage
  - Spawns rage particles on transition
- **Spawn:** Every 5th wave (wave 5, 10, 15, 20...)
- **Rendering:** Special boss glow (width 5), 1.15× scale pulsing (0.6s cycle)

---

#### 7. Cyberboss (Raid Boss)
**Extended boss fight**

- **ID:** `cyberboss`
- **Name:** Cyber Overlord
- **Role:** Raid mode encounter
- **Stats:** 12,500 HP, 100 speed, 50 damage, 500 coin reward
- **Visual:** Cyan hexagon (50px) with enhanced glow
- **Behavior:**
  - Complex 4-phase AI
  - Alternates between melee/ranged attack modes
  - Spawns minions (fast + basic types)
  - Energy blast projectiles with 3-layer pulsing visual
  - Phase transitions modify behavior patterns
- **Spawn:** Specific raid/arena mode encounter

---

#### 8. Void Harbinger (Ultimate Boss)
**Final challenge**

- **ID:** `voidharbinger`
- **Name:** Void Harbinger
- **Role:** Ultimate boss requiring mastery
- **Stats:** 25,000 HP (highest), 80 speed, 60 damage, 1,000 coin reward
- **Visual:** Purple hexagon (60px, largest) with maximum glow
- **Behavior:**
  - Multiple attack patterns (volleys, zones, meteors, teleportation)
  - Void phase activation at low health
  - Invulnerability phases
  - Creates void zones with special damage types
- **Spawn:** Void Realm/raid mode

---

## Enemy Spawning Systems

### 1. Idle Spawn System (Continuous)

Handles endless spawning based on **Threat Level**.

#### Threat Level Mechanics

Threat Level starts at 1.0 and increases continuously:
```
Threat Growth = idleThreatGrowthRate per second (default: 0.01)
```

#### Enemy Type Unlocks by Threat Level

| Enemy Type | Unlock Threshold | Weight/Threat | Max Weight |
|------------|------------------|---------------|------------|
| Basic | 0+ | Always 100 | 100 |
| Fast | 2.0 | 15 | 60 |
| Void Minion (Swarm) | 4.0 | 12 | 50 |
| Tank | 5.0 | 10 | 40 |
| Elite | 8.0 | 8 | 30 |
| Boss | 10.0 | 2 | 10 |

#### Stat Scaling by Threat Level

```
Health Multiplier = 1.0 + (threat - 1.0) × 0.15  (+15% per level)
Speed Multiplier = 1.0 + (threat - 1.0) × 0.02   (+2% per level)
Damage Multiplier = 1.0 + (threat - 1.0) × 0.05  (+5% per level)
```

#### Threat Display Levels

| Threat Range | Display Name | Color |
|--------------|--------------|-------|
| 0-2 | Low | Green #44ff44 |
| 2-5 | Medium | Yellow #ffff44 |
| 5-10 | High | Orange #ff8844 |
| 10-20 | Critical | Red #ff4444 |
| 20+ | Extreme | Magenta #ff00ff |

#### Spawn Timing

```
Spawn Interval = max(0.3, baseSpawnRate / (1 + threat × 0.1))
```

- Base spawn rate: 2.0 seconds
- Minimum interval: 0.3 seconds
- Max enemies on screen: 50 (performance cap)

---

### 2. Wave Spawn System (TD Mode)

Structured 20-wave progression:

#### Wave Composition

| Waves | Enemy Types |
|-------|-------------|
| 1-3 | Basic only |
| 4-6 | Basic + Fast (50/50) |
| 7-10 | Basic + Fast + Tank (33/33/33) |
| 11+ | Basic + Fast + Tank + occasional Boss |

#### Wave Scaling

```
Enemy Count = 10 + (wave × 2)
Health Multiplier = 1.1^wave
Speed Multiplier = 1.05^wave
Spawn Delay = decreases per wave (faster spawns)
```

#### Boss Waves

- Appear every 5th wave (5, 10, 15, 20)
- Boss health: 2× wave health multiplier
- Boss speed: 1× wave speed multiplier (no extra speed)

#### Wave Rewards

```
Bonus Hash = wave × 5
```

#### Cooldown Between Waves

5.0 seconds between wave completion and next wave start.

---

## Power System

### Overview

Power is a **ceiling** (allocation), not consumed resource:
- Each placed tower uses power while placed
- Total power used = sum of all tower power draws
- Cannot place towers if insufficient power available

### Power Draw by Rarity

| Rarity | Typical Power Draw |
|--------|-------------------|
| Common | 15-20W |
| Rare | 30-35W |
| Epic | 60-75W |
| Legendary | 100-120W |

### Specific Protocol Power Draws

| Protocol | Power Draw |
|----------|------------|
| Kernel Pulse | 15W |
| Burst Protocol | 20W |
| Ice Shard | 30W |
| Trace Route | 35W |
| Fork Bomb | 60W |
| Root Access | 75W |
| Null Pointer | 100W |
| Overflow | 120W |

### PSU Capacity

- Base PSU capacity: 450W
- Upgradeable via Global Upgrades (PSU component)
- Example: 450W capacity ÷ 15W per common tower = ~30 common towers max

---

## Economy

### Currency: Hash (Ħ)

Hash is the soft currency used for:
- Compiling protocols (unlocking)
- Upgrading protocol levels
- Placing towers (placement cost)

### Placement Costs by Rarity

| Rarity | Placement Cost |
|--------|----------------|
| Common | 50 Hash |
| Rare | 100 Hash |
| Epic | 200 Hash |
| Legendary | 400 Hash |

### Earning Hash

- **Enemy Kills:** Each enemy drops its `coinValue` in Hash
- **Wave Completion:** Bonus Hash = wave number × 5
- **Offline Earnings:** Accumulated while away (System: Reboot feature)

### Hash Storage

- Default capacity: 25,000 Hash
- Upgradeable via Global Upgrades

### Tower Refund

When selling a tower:
```
Refund = (baseCost + upgradeCost) × refundRate
```
- Default refund rate: 75%
- Subject to Hash storage cap

---

## Tower Targeting & Combat

### Targeting Algorithm

1. Find all enemies within tower range
2. Filter out: dead, reached core, Zero-Day immune
3. **Priority:** Enemy furthest along path (closest to core)
4. Update tower rotation to face target

### Lead Targeting (Prediction)

Towers predict where enemies will be:
- Estimate enemy velocity from path direction
- Calculate where enemy will be when projectile arrives
- Account for projectile speed and enemy movement
- Maximum prediction time capped for balance

### Multi-Shot Spread

For towers with multiple projectiles:
```
Spread Angle = configurable per tower
Projectiles evenly distributed across spread
```

### Attack Execution

1. Check cooldown: `attackInterval = 1.0 / fireRate`
2. Calculate lead angle for prediction
3. Fire projectile(s) with appropriate spread
4. Trigger muzzle flash animation
5. Apply recoil animation

---

## Lane System (Motherboard Map)

### 8-Lane Architecture

The motherboard map uses an 8-lane sector system:
- Each sector (PSU, GPU, RAM, etc.) has dedicated spawn lanes
- Lanes are color-coded by sector theme
- Enemies spawn from sector edges and travel toward CPU core

### Tower Slot Generation

- Slots placed perpendicular to paths (100 units from center)
- Slot spacing: 80 units along path
- CPU exclusion zone: 200 radius (no slots near core)
- Special CPU defense slots: 8 slots around CPU perimeter

### Lane Visuals

- LEDs along lanes (react to enemy proximity)
- No rushing particles (clean lane design)
- Each sector has unique component decorations

---

## Status Verification

All mechanics documented above have been verified in the codebase:

- **Protocols:** Defined in [Protocol.swift](LegendarySurvivors/Core/Types/Protocol.swift)
- **Tower System:** [TowerSystem.swift](LegendarySurvivors/GameEngine/Systems/TowerSystem.swift)
- **Tower Visuals:** [TowerVisualFactory.swift](LegendarySurvivors/Rendering/TowerVisualFactory.swift)
- **Tower Animations:** [TowerAnimations.swift](LegendarySurvivors/Rendering/TowerAnimations.swift)
- **Enemies:** [GameConfig.json](LegendarySurvivors/Resources/GameConfig.json)
- **Idle Spawning:** [IdleSpawnSystem.swift](LegendarySurvivors/GameEngine/Systems/IdleSpawnSystem.swift)
- **Wave Spawning:** [WaveSystem.swift](LegendarySurvivors/GameEngine/Systems/WaveSystem.swift)
- **Balance Config:** [BalanceConfig.swift](LegendarySurvivors/Core/Config/BalanceConfig.swift)
- **Entity Rendering:** [EntityRenderer.swift](LegendarySurvivors/Rendering/EntityRenderer.swift)
