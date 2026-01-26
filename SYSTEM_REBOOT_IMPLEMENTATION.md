# SYSTEM: REBOOT - Complete Implementation Specification

## Document Purpose
This document defines the complete game architecture for "SYSTEM: REBOOT" - a hybrid idle-defense/action-survivor game where you play as a System Kernel protecting a motherboard from viral threats.

---

## 1. CORE IDENTITY

### You Are The Kernel
- **Idle Mode (Motherboard)**: You are the Operating System, managing resources and deploying Firewalls
- **Active Mode (Debug)**: You materialize as the Cursor, a glowing combat avatar that manually deletes viruses

### The Theme
Everything is digital, terminal, circuit-board aesthetic:
- Dark backgrounds (#0a0a0f)
- Cyan circuit traces (#00d4ff)
- Monospace typography
- Scan lines, glitch effects
- "Viruses" instead of enemies
- "Firewalls" instead of towers
- "Protocols" instead of weapons/towers
- "Data" and "Watts" instead of coins/gold

---

## 2. CURRENCY SYSTEM

### Watts (⚡)
| Aspect | Description |
|--------|-------------|
| **Source** | Generated passively by CPU based on Efficiency |
| **Rate** | Base rate × Efficiency% (e.g., 50 Watts/sec × 80% = 40 Watts/sec) |
| **Uses** | Build Firewalls, Upgrade Firewalls, Unlock Board Expansions, Global Upgrades |
| **Offline** | Accumulates while away: `Time × Rate × Efficiency%` |
| **Display** | Top bar: "⚡ 12,847 (+42/s)" |

### Data (◈)
| Aspect | Description |
|--------|-------------|
| **Source** | Dropped by viruses in Active/Debug mode |
| **Rate** | Per-kill drops + end-of-run bonus |
| **Uses** | Compile (unlock) Protocols, Level up Protocols |
| **Offline** | Does NOT accumulate offline |
| **Display** | Top bar: "◈ 2,340" |

### Currency Flow
```
┌─────────────────────────────────────────────────────────────┐
│                      MOTHERBOARD                            │
│                                                             │
│   ┌─────────┐      Efficiency      ┌─────────┐             │
│   │   CPU   │ ──────────────────→  │  WATTS  │             │
│   │ (Core)  │      determines      │ balance │             │
│   └─────────┘        rate          └────┬────┘             │
│                                         │                   │
│                          ┌──────────────┼──────────────┐   │
│                          ↓              ↓              ↓   │
│                    Build Towers   Upgrade Towers   Expansions│
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                      DEBUG MODE                             │
│                                                             │
│   ┌─────────┐      Kill drops      ┌─────────┐             │
│   │ Viruses │ ──────────────────→  │  DATA   │             │
│   │ (Enemies)│                     │ balance │             │
│   └─────────┘                      └────┬────┘             │
│                                         │                   │
│                          ┌──────────────┴──────────────┐   │
│                          ↓                             ↓   │
│                    Compile Protocols          Level Up Protocols
└─────────────────────────────────────────────────────────────┘
```

---

## 3. PROTOCOL SYSTEM

### What Is A Protocol?
A Protocol is a dual-purpose card that functions as:
- A **Firewall** (tower) in Motherboard/Idle mode
- A **Weapon** in Debug/Active mode

This is the core innovation: unlocking one Protocol benefits BOTH game modes.

### Protocol Data Model

```swift
struct Protocol: Identifiable, Codable {
    let id: String                    // "kernel_pulse", "burst_protocol"
    let name: String                  // "Kernel Pulse", "Burst Protocol"
    let description: String           // Flavor text
    let rarity: Rarity                // common, rare, epic, legendary
    var level: Int                    // 1-10, affects all stats
    var isCompiled: Bool              // false = locked blueprint, true = usable

    // Visual
    let iconName: String              // SF Symbol or custom asset
    let color: String                 // Hex color for glow/theme

    // === FIREWALL STATS (TD Mode) ===
    let firewallBaseStats: FirewallStats

    // === WEAPON STATS (Active Mode) ===
    let weaponBaseStats: WeaponStats

    // Computed: Current stats based on level
    var firewallStats: FirewallStats { /* base × levelMultiplier */ }
    var weaponStats: WeaponStats { /* base × levelMultiplier */ }

    // Costs
    var compileCost: Int              // Data cost to unlock
    var upgradeCost: Int              // Data cost to level up (scales with level)
}

struct FirewallStats: Codable {
    var damage: CGFloat               // Damage per hit
    var range: CGFloat                // Attack range in points
    var fireRate: CGFloat             // Attacks per second
    var projectileCount: Int          // Multi-shot
    var pierce: Int                   // Enemies hit per projectile
    var splash: CGFloat               // AoE radius (0 = none)
    var slow: CGFloat                 // Slow percentage (0-1)
    var slowDuration: TimeInterval    // How long slow lasts
    var special: FirewallSpecial?     // Unique ability
}

struct WeaponStats: Codable {
    var damage: CGFloat               // Damage per hit
    var fireRate: CGFloat             // Attacks per second
    var projectileCount: Int          // Projectiles per shot
    var spread: CGFloat               // Spread angle for multi-shot
    var pierce: Int                   // Enemies hit per projectile
    var projectileSpeed: CGFloat      // How fast projectiles travel
    var special: WeaponSpecial?       // Unique ability
}

enum FirewallSpecial: String, Codable {
    case homing                       // Projectiles track enemies
    case chain                        // Damage chains to nearby enemies
    case burn                         // DoT effect
    case freeze                       // Stun on hit
    case execute                      // Bonus damage to low HP
}

enum WeaponSpecial: String, Codable {
    case homing
    case explosive                    // AoE on impact
    case ricochet                     // Bounces between enemies
    case lifesteal                    // Heal on hit
    case critical                     // Chance for 2x damage
}
```

### Starting Protocol: Kernel Pulse

```swift
let kernelPulse = Protocol(
    id: "kernel_pulse",
    name: "Kernel Pulse",
    description: "Standard system defense. Reliable and efficient.",
    rarity: .common,
    level: 1,
    isCompiled: true,  // Player starts with this
    iconName: "dot.circle.and.hand.point.up.left.fill",
    color: "#00d4ff",

    firewallBaseStats: FirewallStats(
        damage: 10,
        range: 120,
        fireRate: 1.0,
        projectileCount: 1,
        pierce: 1,
        splash: 0,
        slow: 0,
        slowDuration: 0,
        special: nil
    ),

    weaponBaseStats: WeaponStats(
        damage: 8,
        fireRate: 2.0,
        projectileCount: 1,
        spread: 0,
        pierce: 1,
        projectileSpeed: 400,
        special: nil
    ),

    compileCost: 0,      // Already compiled
    upgradeCost: 50      // 50 Data to go from L1→L2
)
```

### Protocol Library (Initial Set)

| Protocol | Rarity | Firewall Role | Weapon Role |
|----------|--------|---------------|-------------|
| Kernel Pulse | Common | Basic turret | Auto-pistol |
| Burst Protocol | Common | Splash tower | Shotgun |
| Trace Route | Rare | Long-range sniper | Railgun |
| Ice Shard | Rare | Slow tower | Freeze gun |
| Fork Bomb | Epic | Multi-target | Spread cannon |
| Root Access | Epic | High damage single | Laser beam |
| Overflow | Legendary | Chain lightning | Arc weapon |
| Null Pointer | Legendary | Execute (1-shot low HP) | Instakill crits |

### Level Scaling

```swift
// Level multiplier: each level = +15% stats
func levelMultiplier(level: Int) -> CGFloat {
    return 1.0 + (CGFloat(level - 1) * 0.15)
}

// Upgrade cost scales with level and rarity
func upgradeCost(level: Int, rarity: Rarity) -> Int {
    let baseCost: Int
    switch rarity {
    case .common: baseCost = 50
    case .rare: baseCost = 100
    case .epic: baseCost = 200
    case .legendary: baseCost = 400
    }
    return baseCost * level  // L1→L2 = 50, L2→L3 = 100, etc.
}
```

---

## 4. NAVIGATION STRUCTURE

### Tab-Based Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SYSTEM: REBOOT                           │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │                                                       │ │
│  │                   CONTENT AREA                        │ │
│  │              (Changes per tab)                        │ │
│  │                                                       │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌─────────┬─────────┬─────────┬─────────┐                 │
│  │  BOARD  │ ARSENAL │UPGRADES │  DEBUG  │                 │
│  │   ⬡     │   ⚙     │   ↑     │   ▶     │                 │
│  └─────────┴─────────┴─────────┴─────────┘                 │
└─────────────────────────────────────────────────────────────┘
```

### Tab Definitions

| Tab | Icon | Content | Primary Action |
|-----|------|---------|----------------|
| BOARD | Circuit icon | Motherboard TD game | Build/manage Firewalls |
| ARSENAL | Gear icon | Protocol card collection | Compile/upgrade Protocols |
| UPGRADES | Arrow up | Global upgrade tree | Spend Watts on CPU/RAM/Cooling |
| DEBUG | Play icon | Sector selection | Launch Active mode run |

### View Hierarchy

```
AppEntry
└── MainMenuView
    └── SystemTabView (TabView)
        ├── MotherboardView (BOARD)
        │   ├── TDGameScene (SpriteKit)
        │   ├── TopHUD (Watts, Efficiency)
        │   ├── BottomBar (Build deck)
        │   └── SystemFreezeOverlay (when 0%)
        │
        ├── ArsenalView (ARSENAL)
        │   ├── ProtocolGrid (all protocols)
        │   ├── ProtocolDetailSheet (tap to view)
        │   └── LoadoutSelector (pick Active weapon)
        │
        ├── UpgradesView (UPGRADES)
        │   ├── CPUUpgradeCard
        │   ├── RAMUpgradeCard
        │   └── CoolingUpgradeCard
        │
        └── DebugView (DEBUG)
            ├── SectorGrid (RAM, Drive, etc.)
            ├── LoadoutPreview (current weapon)
            └── LaunchButton
                └── GameContainerView (fullscreen Active run)
```

---

## 5. MOTHERBOARD (TD MODE)

### The One Map Philosophy

There is ONE Motherboard that expands over time, not multiple maps.

```
EARLY GAME (5x5 visible)          MID GAME (expanded)
┌───────────────────┐             ┌─────────────────────────────┐
│   ░░░░░░░░░░░░░  │             │ ░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│   ░ ┌─────────┐ ░│             │ ░ ════════════════════════ ░│
│   ░ │ S → → C │ ░│             │ ░ ║  S → → → → → → → → C ║ ░│
│   ░ └─────────┘ ░│             │ ░ ║  ↑               ↓   ║ ░│
│   ░░░░░░░░░░░░░  │             │ ░ ║  S → → → → → → → ↓   ║ ░│
└───────────────────┘             │ ░ ════════════════════════ ░│
                                  │ ░░░░░░░░░░░░░░░░░░░░░░░░░░ │
S = Spawn point                   └─────────────────────────────┘
C = CPU (Core)
░ = Locked area (dark)
```

### Board Expansion System

```swift
struct BoardExpansion: Codable {
    let id: String              // "cache_layer_1", "expansion_bus_north"
    let name: String            // "Cache Layer 1"
    let description: String     // "Unlocks 10 new sockets and 1 new spawn"
    let wattsCost: Int          // Cost to unlock
    let prerequisite: String?   // Must unlock this first

    let newSockets: [CGPoint]   // Socket positions added
    let newSpawns: [SpawnPoint] // Enemy spawn points added
    let newPathSegments: [PathSegment] // New path sections
}

// The player starts with minimal board, unlocks expansions
let expansions = [
    BoardExpansion(
        id: "cache_layer_1",
        name: "Cache Layer 1",
        wattsCost: 5000,
        prerequisite: nil,
        // ... adds 10 sockets, 1 spawn, extends path
    ),
    BoardExpansion(
        id: "expansion_bus_north",
        name: "North Expansion Bus",
        wattsCost: 15000,
        prerequisite: "cache_layer_1",
        // ... adds 15 sockets, 2 spawns
    ),
    // ...more expansions
]
```

### Socket System (Tower Placement)

Towers are placed on pre-defined "Sockets" - small squares adjacent to paths.

```swift
struct Socket: Identifiable, Codable {
    let id: String
    let position: CGPoint       // Center position
    var isUnlocked: Bool        // Part of current board expansion?
    var firewallId: String?     // nil if empty

    // Sockets adjacent to paths are valid
    // Sockets ON paths are invalid
    // Sockets must be unlocked via expansion
}
```

**Socket Visual States:**
| State | Visual |
|-------|--------|
| Locked | Invisible (dark area) |
| Empty (idle) | Invisible or very subtle dot |
| Empty (placing) | Glowing cyan square outline |
| Occupied | Firewall rendered, no socket visible |
| Selected | Firewall + range circle + info panel |

### Efficiency System

Efficiency determines Watts generation rate.

```swift
struct EfficiencyState {
    var current: CGFloat        // 0.0 to 1.0 (0% to 100%)
    var wattsPerSecond: CGFloat // Base rate from CPU level

    var actualWattsPerSecond: CGFloat {
        return wattsPerSecond * current
    }
}

// Efficiency changes based on:
// - Virus reaches core: -10% per virus
// - Time without breach: slowly regenerates (+1%/sec up to 100%)
// - CPU overheating: if too many enemies, efficiency drops
```

### System Freeze (0% Efficiency)

When efficiency hits 0%:

```swift
enum SystemState {
    case running(efficiency: CGFloat)
    case frozen                 // 0% efficiency
}

// When frozen:
// - Watts generation = 0
// - Visual: monochrome filter, "CRITICAL ERROR" overlay
// - Player must REBOOT

enum RebootOption {
    case payWatts               // Spend 10% of banked Watts
    case manualOverride         // Play 30-second survival mini-game
}
```

**Reboot Flow:**
```
System Frozen
     │
     ├─→ "FLUSH MEMORY" (Pay 10% Watts)
     │        │
     │        └─→ All viruses cleared, efficiency → 50%
     │
     └─→ "MANUAL OVERRIDE" (Play mini-game)
              │
              ├─→ Win: All viruses cleared, efficiency → 100%
              │
              └─→ Lose: Nothing happens, must try again or pay
```

### Motherboard HUD

```
┌─────────────────────────────────────────────────────────────┐
│  ⚡ 12,847 (+42/s)    ████████████░░░░░░░ 78%     ⏸ ⚙    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                    [GAME AREA]                              │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  BUILD FIREWALL                                             │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐                        │
│  │ ⚡ │ │ 💥 │ │ ❄  │ │ ⚡ │ │ 🎯 │                        │
│  │100W│ │150W│ │200W│ │300W│ │500W│                        │
│  └────┘ └────┘ └────┘ └────┘ └────┘                        │
└─────────────────────────────────────────────────────────────┘

TOP BAR:
- Left: Watts balance + income rate
- Center: Efficiency bar with percentage
- Right: Pause, Settings buttons

BOTTOM BAR:
- Label: "BUILD FIREWALL"
- Cards: Compiled protocols (only show those player has)
- Each card shows: Icon, Watts cost
- Tap or drag to place
```

---

## 6. DEBUG MODE (ACTIVE)

### Sector System

Sectors replace the old Arena/Dungeon modes.

```swift
struct Sector: Identifiable, Codable {
    let id: String              // "ram", "drive", "gpu"
    let name: String            // "The RAM"
    let subtitle: String        // "Memory Banks"
    let description: String     // "Open arena, swarm survival"

    let difficulty: Difficulty  // easy, medium, hard, chaos
    let dataMultiplier: CGFloat // 1.0, 1.5, 2.0, 3.0

    let unlockCost: Int         // Data to unlock (0 = free)
    let isUnlocked: Bool

    let layout: SectorLayout    // arena, corridors, mixed
    let visualTheme: String     // "ram", "drive", "gpu"

    let duration: TimeInterval  // How long to survive (180s = 3 min)
    let waveCount: Int?         // Or wave-based (nil = time-based)
}

enum SectorLayout {
    case arena                  // Open space, no walls
    case corridors              // Narrow passages
    case mixed                  // Rooms connected by corridors
}
```

### Sector Definitions

| Sector | Layout | Difficulty | Data Mult | Visual |
|--------|--------|------------|-----------|--------|
| The RAM | Arena | Easy | 1.0x | Clean grid, hex addresses |
| The Drive | Corridors | Medium | 1.5x | Encrypted blocks, narrow |
| The GPU | Mixed | Hard | 2.0x | Shader noise, fast enemies |
| The BIOS | Corridors | Chaos | 3.0x | Glitched, unpredictable |

### Active Mode Flow

```
DebugView (Sector Selection)
     │
     │ Player selects sector + confirms loadout
     ↓
GameContainerView (Fullscreen)
     │
     │ Survive duration OR defeat waves
     │ Collect Data drops from kills
     ↓
Run Complete
     │
     ├─→ Victory: "SECTOR CLEANSED"
     │        │
     │        └─→ Rewards: Data + possible Protocol blueprint
     │
     └─→ Death: "DEBUG FAILED"
              │
              └─→ Partial rewards: 50% of collected Data
     │
     ↓
Return to SystemTabView
```

### Loadout (Single Protocol)

The player brings ONE Protocol into Debug mode.

```swift
struct DebugLoadout {
    var primaryProtocol: Protocol   // The weapon you fight with
    // Future: could add secondary slot, consumables, etc.
}
```

**Loadout Selection Flow:**
1. Player goes to ARSENAL tab
2. Taps a compiled Protocol
3. Taps "EQUIP FOR DEBUG"
4. Protocol is now the active loadout
5. When launching Debug, this Protocol's weapon stats are used

### Debug Mode HUD

```
┌─────────────────────────────────────────────────────────────┐
│  ♥♥♥♥♥░░░░░   THE RAM   ◈ 47   ⏱ 2:34                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                                                             │
│                    [GAME AREA]                              │
│                       ◇ ← Player (Cursor)                   │
│                                                             │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                        ●                                    │
│                      ╱   ╲    ← Virtual Joystick            │
│                                                             │
└─────────────────────────────────────────────────────────────┘

TOP BAR:
- Left: Health (hearts or bar)
- Center: Sector name
- Center-Right: Data collected this run
- Right: Time remaining
```

---

## 7. GLOBAL UPGRADES

### Upgrade Categories

Spend Watts to upgrade global stats that affect both modes.

```swift
struct GlobalUpgrades: Codable {
    var cpuLevel: Int           // Affects Watts generation
    var ramLevel: Int           // Affects max health (Active) & efficiency buffer (TD)
    var coolingLevel: Int       // Affects fire rate globally
}
```

### CPU Upgrade (Watts Generation)

| Level | Watts/sec | Cost |
|-------|-----------|------|
| 1 | 10/s | - |
| 2 | 15/s | 1,000 |
| 3 | 22/s | 2,500 |
| 4 | 33/s | 5,000 |
| 5 | 50/s | 10,000 |
| ... | +50%/level | ×2 |

### RAM Upgrade (Health/Buffer)

| Level | Effect | Cost |
|-------|--------|------|
| 1 | 100 HP (Active), 100% max efficiency | - |
| 2 | 120 HP, efficiency regens 10% faster | 1,500 |
| 3 | 145 HP, efficiency regens 20% faster | 3,500 |
| ... | +20% HP, +10% regen | ×2.5 |

### Cooling Upgrade (Fire Rate)

| Level | Effect | Cost |
|-------|--------|------|
| 1 | Base fire rate | - |
| 2 | +5% fire rate all Firewalls & Weapons | 2,000 |
| 3 | +10% fire rate | 5,000 |
| ... | +5%/level | ×2.5 |

### Upgrades View UI

```
┌─────────────────────────────────────────────────────────────┐
│                    SYSTEM UPGRADES                          │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  CPU CORE                                    LV 3   │   │
│  │  ▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░         │   │
│  │  Watts Generation: 22/sec                           │   │
│  │  Next: 33/sec                                       │   │
│  │                              [UPGRADE 5,000⚡]      │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  RAM MODULE                                  LV 2   │   │
│  │  ▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░         │   │
│  │  Max Health: 120 | Efficiency Regen: +10%           │   │
│  │  Next: 145 HP, +20% regen                           │   │
│  │                              [UPGRADE 3,500⚡]      │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  COOLING SYSTEM                              LV 1   │   │
│  │  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░         │   │
│  │  Fire Rate Bonus: +0%                               │   │
│  │  Next: +5% all weapons                              │   │
│  │                              [UPGRADE 2,000⚡]      │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ⚡ 8,240 available                                        │
└─────────────────────────────────────────────────────────────┘
```

---

## 8. ZERO-DAY EVENTS

### The Board Invasion Mechanic

Zero-Day is a special boss that invades the Motherboard, forcing Active mode.

```swift
struct ZeroDayEvent {
    let id: String
    var isActive: Bool
    var bossHealth: CGFloat
    var position: CGPoint       // Where it spawned on board
    var timeRemaining: TimeInterval  // Despawns if ignored too long
}

// Zero-Day characteristics:
// - Spawns randomly on Motherboard (not during first 10 minutes)
// - IMMUNE to all Firewall damage (Root Access)
// - Slowly moves toward CPU
// - Player MUST engage in Active mode to defeat
// - Massive rewards if defeated
```

### Zero-Day Flow

```
Normal Motherboard Gameplay
     │
     │ Random trigger (1% chance per minute after 10min)
     ↓
Zero-Day Spawns
     │
     │ Visual: Massive glitch entity appears on board
     │ Audio: Warning klaxon, screen distortion
     │ UI: "ROOT ACCESS DETECTED" banner
     │
     │ Countdown: 60 seconds to engage or it reaches CPU
     ↓
Player Choice
     │
     ├─→ "MANUAL INTERVENTION" button
     │        │
     │        ↓
     │   Zero-Day Arena (Special Active Mode)
     │        │
     │        ├─→ Win: Massive Data + Corrupted Blueprint
     │        │
     │        └─→ Lose: Zero-Day damages CPU (-30% efficiency)
     │
     └─→ Ignore / Too slow
              │
              └─→ Zero-Day reaches CPU: -50% efficiency
```

### Zero-Day Boss Fight

A special Active mode arena:
- 1v1 against the Zero-Day boss
- No regular enemy spawns
- Boss has phases (shield, enrage, etc.)
- Time limit: 90 seconds
- Victory: Huge Data payout + rare Protocol blueprint

```swift
struct ZeroDayBoss {
    var health: CGFloat         // Much higher than regular enemies
    var phase: Int              // 1, 2, 3 (different attack patterns)

    let immuneToTowers: Bool = true
    let dataReward: Int         // 500-1000 Data
    let blueprintDrop: String?  // Chance for rare Protocol
}
```

---

## 9. ARSENAL VIEW

### Protocol Collection UI

```
┌─────────────────────────────────────────────────────────────┐
│                       ARSENAL                               │
│  ◈ 2,340                                                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  EQUIPPED FOR DEBUG                                         │
│  ┌──────────────────────────────────┐                      │
│  │  ⚡ Kernel Pulse          LV 3   │                      │
│  │  "Standard system defense"       │                      │
│  └──────────────────────────────────┘                      │
│                                                             │
│  ─────────────────────────────────────────────────────────  │
│                                                             │
│  COMPILED PROTOCOLS                                         │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐              │
│  │   ⚡   │ │   💥   │ │   ❄    │ │   🔗   │              │
│  │Kernel │ │ Burst  │ │  Ice   │ │ Trace  │              │
│  │ LV 3  │ │ LV 1   │ │ LV 2   │ │ LV 1   │              │
│  └────────┘ └────────┘ └────────┘ └────────┘              │
│                                                             │
│  BLUEPRINTS (Not Compiled)                                  │
│  ┌────────┐ ┌────────┐ ┌────────┐                          │
│  │   🔒   │ │   🔒   │ │   🔒   │                          │
│  │ Fork   │ │ Root   │ │Overflow│                          │
│  │ 200◈  │ │ 350◈  │ │ 800◈  │                          │
│  └────────┘ └────────┘ └────────┘                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Protocol Detail Sheet

Tap a Protocol to see full details:

```
┌─────────────────────────────────────────────────────────────┐
│                    BURST PROTOCOL                           │
│                         LV 1                                │
│                                                             │
│  "Overwhelm threats with concentrated firepower"            │
│                                                             │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                             │
│  FIREWALL MODE                    WEAPON MODE               │
│  ┌─────────────────────┐         ┌─────────────────────┐   │
│  │ Damage: 8           │         │ Damage: 6           │   │
│  │ Range: 100          │         │ Fire Rate: 0.8/s    │   │
│  │ Fire Rate: 0.8/s    │         │ Projectiles: 5      │   │
│  │ Splash: 40pt        │         │ Spread: 30°         │   │
│  └─────────────────────┘         └─────────────────────┘   │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │              UPGRADE TO LV 2                          │ │
│  │              +15% all stats                           │ │
│  │                    100 ◈                              │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │              EQUIP FOR DEBUG                          │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 10. OFFLINE PROGRESS

### Calculation

When player returns after being away:

```swift
func calculateOfflineProgress(
    timeAway: TimeInterval,
    lastEfficiency: CGFloat,
    wattsPerSecond: CGFloat
) -> OfflineReport {
    // Cap offline time (prevent absurd gains)
    let cappedTime = min(timeAway, 8 * 60 * 60)  // Max 8 hours

    // Calculate earnings
    let earnings = Int(cappedTime * wattsPerSecond * lastEfficiency)

    return OfflineReport(
        timeAway: timeAway,
        cappedTime: cappedTime,
        efficiency: lastEfficiency,
        wattsEarned: earnings
    )
}
```

### Return Popup

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                    SYSTEM REPORT                            │
│                                                             │
│             ┌─────────────────────────┐                    │
│             │     ⚡ +45,230          │                    │
│             │     Watts Generated      │                    │
│             └─────────────────────────┘                    │
│                                                             │
│             Time Away: 7h 42m                              │
│             Efficiency: 82%                                 │
│             Rate: 50⚡/s × 82% = 41⚡/s                     │
│                                                             │
│             ┌─────────────────────────┐                    │
│             │        COLLECT          │                    │
│             └─────────────────────────┘                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Persistence

```swift
struct OfflineState: Codable {
    var lastActiveTime: Date
    var lastEfficiency: CGFloat
    var wattsPerSecond: CGFloat
}

// Save on app background/close
// Load and calculate on app foreground
```

---

## 11. PLAYER PROFILE (Updated)

### Complete Profile Structure

```swift
struct PlayerProfile: Codable {
    // Identity
    var playerId: String
    var createdAt: Date
    var lastPlayedAt: Date

    // Currencies
    var watts: Int
    var data: Int

    // Protocols
    var compiledProtocols: [String]           // IDs of unlocked protocols
    var protocolLevels: [String: Int]         // ID -> Level
    var equippedProtocolId: String            // For Debug mode
    var protocolBlueprints: [String]          // Found but not compiled

    // Global Upgrades
    var cpuLevel: Int
    var ramLevel: Int
    var coolingLevel: Int

    // Motherboard Progress
    var unlockedExpansions: [String]          // Expansion IDs
    var placedFirewalls: [PlacedFirewall]     // Current board state

    // Sectors
    var unlockedSectors: [String]
    var sectorBestTimes: [String: TimeInterval]

    // Stats
    var totalVirusesKilled: Int
    var totalDataCollected: Int
    var totalWattsGenerated: Int
    var totalPlayTime: TimeInterval
    var zeroDaysDefeated: Int

    // Offline
    var offlineState: OfflineState
}

struct PlacedFirewall: Codable {
    var socketId: String
    var protocolId: String
    var level: Int              // Firewall can be upgraded independently
}
```

---

## 12. VISUAL DESIGN SYSTEM

### Colors (Terminal Aesthetic)

```swift
struct DesignColors {
    // Backgrounds
    static let background = Color(hex: "0a0a0f")
    static let surface = Color(hex: "1a1a24")
    static let surfaceDark = Color(hex: "0d1117")

    // Brand
    static let primary = Color(hex: "00d4ff")      // Cyan - main accent
    static let secondary = Color(hex: "8b5cf6")    // Purple - special
    static let success = Color(hex: "22c55e")      // Green - health, valid
    static let warning = Color(hex: "f59e0b")      // Amber - gold, caution
    static let danger = Color(hex: "ef4444")       // Red - damage, invalid
    static let muted = Color(hex: "4a4a5a")        // Gray - disabled

    // Rarity
    static let rarityCommon = Color(hex: "9ca3af")
    static let rarityRare = Color(hex: "3b82f6")
    static let rarityEpic = Color(hex: "a855f7")
    static let rarityLegendary = Color(hex: "f59e0b")

    // Currencies
    static let watts = primary                      // Cyan
    static let dataColor = success                  // Green
}
```

### Typography

```swift
struct DesignTypography {
    // All text uses monospace for terminal feel
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }

    static func headline(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }

    static func body(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }

    static func caption(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }
}
```

### Visual Effects

| Effect | Usage | Implementation |
|--------|-------|----------------|
| Scan Lines | Active mode overlay | Horizontal lines, 3% opacity, slow scroll |
| Glitch | Damage feedback | RGB split + horizontal displacement, 0.15s |
| Circuit Pulse | Tower fires | Cyan line travels along trace |
| Socket Glow | Valid placement | Pulsing cyan outline |
| Efficiency Bar | CPU health | Gradient green→yellow→red |

---

## 13. IMPLEMENTATION PHASES

### Phase 1: Foundation (Data Models & Navigation)
**Goal**: New architecture in place, basic navigation working

**Tasks**:
1. Create `Protocol` type with dual stats
2. Create `GlobalUpgrades` type
3. Update `PlayerProfile` with new structure
4. Rename currencies (gold→watts, coins→data)
5. Create `SystemTabView` with 4 tabs
6. Create stub views for each tab
7. Update app entry flow: MainMenu → SystemTabView

**Deliverable**: App launches into tabbed interface with placeholder content

---

### Phase 2: Motherboard Core
**Goal**: TD game works as BOARD tab with new currency

**Tasks**:
1. Refactor `TDGameState` to use Watts
2. Implement Efficiency system (affects Watts rate)
3. Create Socket-based placement (visual update)
4. Build deck shows compiled Protocols as Firewalls
5. Update HUD: Watts balance, income rate, efficiency bar
6. Remove old map selection (single Motherboard)

**Deliverable**: Playable TD mode in BOARD tab with Watts economy

---

### Phase 3: Protocol System
**Goal**: Protocols work as dual-purpose cards

**Tasks**:
1. Create Protocol library (8 initial protocols)
2. Implement Protocol → Firewall conversion
3. Implement Protocol → Weapon conversion
4. Create ArsenalView UI
5. Protocol detail sheet with stats for both modes
6. Compile (unlock) with Data
7. Upgrade with Data
8. Equip for Debug selection

**Deliverable**: Full Arsenal tab, protocols usable in both modes

---

### Phase 4: Debug Mode (Active)
**Goal**: Sector-based Active runs that drop Data

**Tasks**:
1. Create Sector definitions (RAM, Drive)
2. Create DebugView (sector selection)
3. Refactor GameContainerView to use equipped Protocol as weapon
4. Enemies drop Data instead of coins
5. End-of-run rewards screen
6. Victory: full Data + possible blueprint
7. Death: 50% Data
8. Return to SystemTabView after run

**Deliverable**: Complete Debug mode loop with Data rewards

---

### Phase 5: Global Upgrades
**Goal**: Watts spent on permanent progression

**Tasks**:
1. Create UpgradesView UI
2. Implement CPU upgrade (Watts generation)
3. Implement RAM upgrade (health + efficiency regen)
4. Implement Cooling upgrade (fire rate)
5. Apply global upgrades to both modes

**Deliverable**: Working upgrades that affect gameplay

---

### Phase 6: System Freeze & Reboot
**Goal**: 0% efficiency creates engaging recovery mechanic

**Tasks**:
1. Detect 0% efficiency state
2. Create System Freeze overlay
3. "Flush Memory" option (pay Watts)
4. "Manual Override" option (30-sec survival)
5. Survival mini-game implementation
6. Recovery state transitions

**Deliverable**: Complete freeze/reboot loop

---

### Phase 7: Zero-Day Events
**Goal**: Boss invasions bridge both modes

**Tasks**:
1. Zero-Day spawn trigger system
2. Visual: boss appears on Motherboard
3. Warning UI and countdown
4. "Manual Intervention" transition to boss fight
5. Zero-Day boss arena (special Active mode)
6. Boss phases and attack patterns
7. Rewards: massive Data + corrupted blueprints
8. Failure: efficiency penalty

**Deliverable**: Complete Zero-Day event system

---

### Phase 8: Offline Progress
**Goal**: Idle earnings while away

**Tasks**:
1. Save state on app background
2. Calculate offline earnings on foreground
3. "System Report" popup UI
4. Apply earnings to Watts balance
5. Cap maximum offline time (8 hours)

**Deliverable**: Working offline progression

---

### Phase 9: Board Expansions
**Goal**: Single Motherboard grows over time

**Tasks**:
1. Create expansion definitions
2. Initial small board (5x5 effective area)
3. Expansion purchase UI
4. Camera zoom out on expansion
5. New paths and spawns activate
6. Progression: 4-5 expansion tiers

**Deliverable**: Expandable Motherboard with progression

---

### Phase 10: Polish & Balance
**Goal**: Game feels complete and balanced

**Tasks**:
1. Tutorial/onboarding flow
2. Difficulty curve tuning
3. Economy balance (Watts/Data rates)
4. Protocol balance pass
5. Visual polish (effects, animations)
6. Haptic feedback everywhere
7. Sound effects (if desired)
8. Performance optimization

**Deliverable**: Polished, balanced game

---

## 14. FILE STRUCTURE

### New Files to Create

```
LegendarySurvivors/
├── Core/
│   ├── Types/
│   │   ├── Protocol.swift              // NEW: Dual-purpose card type
│   │   ├── GlobalUpgrades.swift        // NEW: CPU/RAM/Cooling
│   │   ├── Sector.swift                // NEW: Debug mode levels
│   │   ├── ZeroDayEvent.swift          // NEW: Boss invasion
│   │   └── BoardExpansion.swift        // NEW: Motherboard growth
│   │
│   └── Config/
│       ├── ProtocolLibrary.swift       // NEW: All protocol definitions
│       └── SectorLibrary.swift         // NEW: All sector definitions
│
├── UI/
│   ├── Tabs/
│   │   ├── SystemTabView.swift         // NEW: Main tab container
│   │   ├── MotherboardView.swift       // NEW: BOARD tab (wraps TD)
│   │   ├── ArsenalView.swift           // NEW: ARSENAL tab
│   │   ├── UpgradesView.swift          // NEW: UPGRADES tab
│   │   └── DebugView.swift             // NEW: DEBUG tab
│   │
│   ├── Components/
│   │   ├── ProtocolCard.swift          // NEW: Protocol card component
│   │   ├── ProtocolDetailSheet.swift   // NEW: Full protocol view
│   │   ├── EfficiencyBar.swift         // NEW: Efficiency display
│   │   └── SystemReportPopup.swift     // NEW: Offline earnings
│   │
│   └── Overlays/
│       ├── SystemFreezeOverlay.swift   // NEW: 0% efficiency state
│       ├── ZeroDayWarning.swift        // NEW: Boss spawn alert
│       └── ManualOverrideGame.swift    // NEW: Reboot mini-game
│
└── Services/
    └── OfflineProgressService.swift    // NEW: Offline calculation
```

### Files to Modify

```
├── Core/
│   └── Types/
│       ├── PlayerProfile.swift         // Add new fields
│       ├── TDTypes.swift               // Socket system, efficiency
│       └── GameTypes.swift             // Data drops, loadout
│
├── GameEngine/
│   └── Systems/
│       ├── TowerSystem.swift           // Protocol → Firewall
│       └── WeaponSystem.swift          // Protocol → Weapon
│
├── Rendering/
│   ├── TDGameScene.swift               // Socket visuals, efficiency
│   └── GameScene.swift                 // Data drops, loadout
│
├── UI/
│   ├── Screens/
│   │   └── MainMenuView.swift          // Simplified, leads to tabs
│   └── Game/
│       ├── TDGameContainerView.swift   // Watts HUD, new layout
│       └── GameContainerView.swift     // Data HUD, loadout weapon
│
└── Services/
    └── AppState.swift                  // Tab navigation state
```

---

## 15. VERIFICATION CHECKLIST

### Core Loop
- [ ] Watts generate based on efficiency
- [ ] Building Firewalls costs Watts
- [ ] Debug mode drops Data
- [ ] Data unlocks/upgrades Protocols
- [ ] Protocols work as both Firewalls and Weapons
- [ ] Global upgrades affect both modes

### Navigation
- [ ] Tab bar with 4 tabs
- [ ] BOARD shows live TD game
- [ ] ARSENAL shows all protocols
- [ ] UPGRADES shows global stats
- [ ] DEBUG launches sector selection

### Motherboard
- [ ] Single expanding board (not multiple maps)
- [ ] Socket-based placement
- [ ] Efficiency system working
- [ ] System Freeze at 0%
- [ ] Reboot options functional

### Debug Mode
- [ ] Sector selection works
- [ ] Loadout determines weapon
- [ ] Data drops from kills
- [ ] Victory/death rewards correct
- [ ] Returns to tabs after run

### Events
- [ ] Zero-Day spawns on board
- [ ] Immune to Firewalls
- [ ] Forces Active mode transition
- [ ] Boss fight works
- [ ] Rewards granted on victory

### Offline
- [ ] Earnings calculated on return
- [ ] Based on efficiency snapshot
- [ ] System Report popup shows
- [ ] Watts added to balance

---

*End of Implementation Specification*
