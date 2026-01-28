# System: Reboot - Restructure Plan

## Theme Reminder
- **You are**: An AI process defending a computer system
- **Enemies**: Viruses, malware, corrupted processes
- **Visual**: Dark terminal (#0a0a0f), cyan circuits (#00d4ff), copper traces
- **Weapons**: Protocols (Kernel Pulse, Fork Bomb, Null Pointer, etc.)
- **Currency**: Hash (Ħ), Data (◈)

---

## Part 1: Simplified Game Structure

### NEW MODE STRUCTURE

```
Main Menu
├── DEBUGGER MODE (Survival)
│   └── Single arena: "Memory Core"
│       - Endless waves, dynamic events
│       - Leaderboard: "Longest uptime"
│       - Goal: Survive as long as possible
│
├── BOSS ENCOUNTERS (Boss Rush)
│   ├── Cyberboss: "Rogue Process"
│   ├── Void Harbinger: "Memory Leak"
│   ├── [Future] Frost Titan: "Frozen Thread"
│   └── [Future] Inferno Lord: "Thermal Throttle"
│       - Direct boss fights, no dungeon crawl
│       - Difficulty tiers: Normal / Hard / Nightmare
│       - Goal: Defeat boss, earn rewards
│
└── MOTHERBOARD MODE (Tower Defense)
    └── [Unchanged - already works well]
```

### FILES TO KEEP (Core Systems)

| File | Purpose | Changes Needed |
|------|---------|----------------|
| `GameScene.swift` | Main game renderer | Strip dungeon room logic |
| `GameState.swift` | State management | Remove multi-room tracking |
| `EnemySystem.swift` | Enemy spawning/AI | Keep as-is |
| `ProjectileSystem.swift` | Combat | Keep as-is |
| `PlayerSystem.swift` | Player logic | Keep as-is |
| `SpawnSystem.swift` | Wave spawning | Enhance for survival events |
| `CyberbossAI.swift` | Boss #1 | Keep, polish phase 4 |
| `VoidHarbingerAI.swift` | Boss #2 | Keep as-is (excellent) |
| `VisualEffects.swift` | VFX | Fix Date() calls |
| `ParticleFactory.swift` | Particles | Keep as-is |
| `ScrollingCombatText.swift` | Damage numbers | Keep as-is |
| `DesignSystem.swift` | Theme colors | Keep as-is |
| `Protocol.swift` | Weapons/Towers | Keep as-is |

### FILES TO GUT/REMOVE

| File | Current Purpose | Action |
|------|-----------------|--------|
| `DungeonSystem.swift` | Multi-room generation | **DELETE** (1000+ lines) |
| `ArenaSystem.swift` | Arena hazards/effects | **REWRITE** → SurvivalArenaSystem |
| `GameConfig.json` arenas | 8 arena definitions | **REDUCE** to 1 arena + boss arenas |

### FILES TO MODIFY

| File | Changes |
|------|---------|
| `GameTypes.swift` | Remove `DungeonRoom`, `Door`, simplify `GameMode` enum |
| `GameScene.swift` | Remove 400+ lines of dungeon room transitions, door logic |
| `AppState.swift` | Remove dungeon selection, simplify arena selection |
| `GameContainerView.swift` | New mode selection UI |

---

## Part 2: Single Survival Arena - "Memory Core"

### ARENA CONCEPT

**Setting**: The central memory banks of the system. A circular arena representing RAM modules arranged around a central CPU core. Viruses spawn from the edges (data bus inputs) and try to reach and corrupt the core (you).

**Visual Design**:
```
┌─────────────────────────────────────────┐
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │  ← Data Bus (spawn edge)
│  ░                                   ░  │
│  ░    ╔═══╗     ╔═══╗     ╔═══╗     ░  │  ← RAM Modules (obstacles)
│  ░    ║ R ║     ║ A ║     ║ M ║     ░  │
│  ░    ╚═══╝     ╚═══╝     ╚═══╝     ░  │
│  ░                                   ░  │
│  ░         ┌─────────────┐           ░  │
│  ░         │   PLAYER    │           ░  │  ← Center area (CPU core)
│  ░         │     ◉       │           ░  │
│  ░         └─────────────┘           ░  │
│  ░                                   ░  │
│  ░    ╔═══╗     ╔═══╗     ╔═══╗     ░  │
│  ░    ║ R ║     ║ A ║     ║ M ║     ░  │
│  ░    ╚═══╝     ╚═══╝     ╚═══╝     ░  │
│  ░                                   ░  │
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
└─────────────────────────────────────────┘
```

### ARENA DIMENSIONS
- **Size**: 1000 x 800 (larger than current 800x600 for more tactical space)
- **Safe zone**: Central 400x400 area (CPU core) - no obstacles
- **Obstacle zone**: Ring of RAM modules between center and edges
- **Spawn zone**: Outer 100px edge on all sides

### DYNAMIC EVENTS SYSTEM

Events trigger every 45-60 seconds, creating variety and forcing adaptation.

#### Event 1: **MEMORY SURGE** (Common)
- **Visual**: Cyan pulse radiates from center
- **Effect**: 3-second speed boost (+50%) for player
- **Spawn**: 2x enemy spawn rate during surge
- **Theme fit**: CPU clock speed boost

```swift
struct MemorySurgeEvent {
    let duration: TimeInterval = 8.0
    let playerSpeedBoost: CGFloat = 1.5
    let spawnRateMultiplier: CGFloat = 2.0
}
```

#### Event 2: **BUFFER OVERFLOW** (Common)
- **Visual**: Red warning borders pulse, screen edges glow danger
- **Effect**: Arena shrinks by 100px on each side for 15 seconds
- **Spawn**: Enemies pushed inward, more chaotic
- **Theme fit**: Memory pressure, system under stress

```swift
struct BufferOverflowEvent {
    let duration: TimeInterval = 15.0
    let shrinkAmount: CGFloat = 100.0
    let warningDuration: TimeInterval = 3.0  // Visual warning before shrink
}
```

#### Event 3: **CACHE FLUSH** (Uncommon)
- **Visual**: White flash, all projectiles/particles clear
- **Effect**: Clears ALL enemies on screen, brief respite
- **Cooldown**: Cannot trigger within 2 minutes of last occurrence
- **Theme fit**: Memory garbage collection

```swift
struct CacheFlushEvent {
    let warningDuration: TimeInterval = 2.0  // "CACHE FLUSH IMMINENT" warning
    let invulnerabilityWindow: TimeInterval = 1.0  // Brief player safety
    let cooldown: TimeInterval = 120.0
}
```

#### Event 4: **THERMAL THROTTLE** (Uncommon)
- **Visual**: Orange/red heat shimmer effect, RAM modules glow hot
- **Effect**: Player movement slowed 30%, but damage +50%
- **Duration**: 12 seconds
- **Theme fit**: CPU overheating, power management

```swift
struct ThermalThrottleEvent {
    let duration: TimeInterval = 12.0
    let speedReduction: CGFloat = 0.7
    let damageBoost: CGFloat = 1.5
    let visualEffect: String = "heat_shimmer"
}
```

#### Event 5: **DATA CORRUPTION** (Rare)
- **Visual**: Glitch effects, screen tears, static noise
- **Effect**: Random RAM modules become hazards (damage on touch) for 10s
- **Count**: 2-4 modules corrupted
- **Theme fit**: Memory corruption, bit rot

```swift
struct DataCorruptionEvent {
    let duration: TimeInterval = 10.0
    let corruptedModuleCount: Int = 3
    let hazardDamage: CGFloat = 15.0  // Per second while touching
    let glitchIntensity: CGFloat = 0.3
}
```

#### Event 6: **VIRUS SWARM** (Rare)
- **Visual**: Purple warning, swarm indicator on minimap
- **Effect**: 50 fast weak enemies spawn in tight formation from one direction
- **Opportunity**: High XP/coins if you can AoE them
- **Theme fit**: Worm virus replication

```swift
struct VirusSwarmEvent {
    let enemyCount: Int = 50
    let enemyType: String = "swarm_virus"  // Fast, 1-hit kill, low XP each
    let spawnDuration: TimeInterval = 5.0  // All spawn within 5 seconds
    let formationWidth: CGFloat = 200.0
}
```

#### Event 7: **SYSTEM RESTORE POINT** (Rare, Beneficial)
- **Visual**: Green healing aura appears at random location
- **Effect**: Standing in zone heals 5 HP/sec for 8 seconds
- **Risk**: Zone is at edge of arena, exposed position
- **Theme fit**: System recovery checkpoint

```swift
struct SystemRestoreEvent {
    let duration: TimeInterval = 8.0
    let healPerSecond: CGFloat = 5.0
    let zoneRadius: CGFloat = 60.0
    let spawnLocation: String = "random_edge"  // Forces risky positioning
}
```

### EVENT FREQUENCY & SCALING

| Time Survived | Event Frequency | Event Pool |
|---------------|-----------------|------------|
| 0-60s | None | Tutorial phase |
| 60-180s | Every 60s | Surge, Overflow only |
| 180-300s | Every 50s | + Throttle, Flush |
| 300-480s | Every 45s | + Corruption, Swarm |
| 480s+ | Every 40s | All events, increased intensity |

### WAVE SCALING (Enhanced)

Current system spawns randomly. New system has themed waves:

```swift
enum WaveType {
    case standard      // Mixed enemies, normal density
    case rush          // Fast enemies only, high count
    case tank          // Slow tanky enemies, low count
    case elite         // 1-2 elite enemies with minion escorts
    case boss          // Mini-boss at 5-minute marks
}
```

**Wave Pattern** (repeating cycle):
1. Standard → Standard → Rush → Standard → Tank → ELITE
2. Repeat with +10% enemy stats each cycle
3. Mini-boss every 5 minutes (not full boss, but tough enemy)

### VISUAL ENHANCEMENTS

#### Background
- **Base**: Dark terminal (#0a0a0f) with subtle circuit grid
- **RAM modules**: Glowing cyan rectangles with chip details
- **Center**: Pulsing CPU core indicator (player spawn point)
- **Edges**: Data bus lines with flowing particle "data"

#### Event Visual Cues
- **3-second warning** before each event
- **Screen border color** indicates event type:
  - Cyan = Surge (positive)
  - Red = Overflow/Throttle (challenge)
  - Purple = Corruption/Swarm (danger)
  - Green = Restore (opportunity)

#### Particle Effects
- **Data flow**: Constant subtle particles along grid lines
- **Spawn portals**: Enemies emerge from glowing rifts at edges
- **Death bursts**: Viruses explode into data fragments (collectible?)

---

## Part 3: Boss Arena Redesign

### BOSS ARENA CONCEPT

Instead of dungeon crawl → boss, players select boss directly.

**Boss Selection Screen**:
```
┌─────────────────────────────────────────┐
│         THREAT DETECTED                 │
│                                         │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐ │
│  │ ROGUE   │  │ MEMORY  │  │ LOCKED  │ │
│  │ PROCESS │  │  LEAK   │  │         │ │
│  │ ★★☆☆☆  │  │ ★★★★☆  │  │ ★★★★★  │ │
│  │ [FIGHT] │  │ [FIGHT] │  │ [????]  │ │
│  └─────────┘  └─────────┘  └─────────┘ │
│                                         │
│  Difficulty: [NORMAL] [HARD] [NIGHTMARE]│
└─────────────────────────────────────────┘
```

### BOSS ARENA LAYOUT

Simple circular arena, no obstacles, pure mechanics focus:

```
         ╭─────────────────╮
       ╱                     ╲
      │                       │
      │         BOSS          │
      │          ◆            │
      │                       │
      │                       │
      │        PLAYER         │
      │          ◉            │
      │                       │
       ╲                     ╱
         ╰─────────────────╯
```

- **Size**: 600x600 (smaller = more intense)
- **Shape**: Circular boundary
- **Obstacles**: None (boss mechanics ARE the challenge)
- **Visual**: Theme matches boss (Cyberboss = neon grid, Void = dark void)

---

## Part 4: Implementation Phases

### Phase 1: Cleanup (4-6 hours)
1. Delete DungeonSystem.swift
2. Gut ArenaSystem.swift → stub for new system
3. Remove dungeon code from GameScene.swift (~400 lines)
4. Simplify GameTypes.swift (remove DungeonRoom, Door, etc.)
5. Update GameMode enum: `.survival`, `.boss`, `.towerDefense`

### Phase 2: Survival Arena (6-8 hours)
1. Create SurvivalArenaSystem.swift
2. Implement Memory Core arena layout
3. Implement event system (start with 3 events)
4. Implement wave scaling
5. Update SpawnSystem for new patterns

### Phase 3: Boss Mode (4-6 hours)
1. Create BossSelectionView.swift
2. Create BossFightScene.swift (or modify GameScene)
3. Wire up direct boss encounters
4. Add difficulty modifiers

### Phase 4: Polish (4-6 hours)
1. Event visual effects
2. Arena visual enhancements
3. Boss mechanic visual feedback
4. Performance fixes from review

**Total: ~20-26 hours**

---

## Part 5: What We're Cutting

### REMOVED ENTIRELY
- Multi-room dungeon structure
- Door transitions and room loading
- 7 of 8 arena definitions
- Hazard system (lava, spikes, etc.) - broken anyway
- Effect zones (ice slow, speed boost) - underutilized
- Room clearing/unlocking mechanics
- Decoration rendering system

### KEPT & ENHANCED
- Core combat loop
- Boss AI (both existing bosses)
- Particle/visual effects
- Scrolling combat text
- Weapon/Protocol system
- Tower Defense mode (separate)

### WHY THIS IS BETTER
1. **Focus**: 1 great survival arena > 7 mediocre ones
2. **Fun faster**: Boss rush = instant action, no crawl
3. **Maintainable**: 60% less arena/dungeon code
4. **Replayable**: Events add variety, leaderboards add competition
5. **Theme coherent**: "Memory Core" fits "System: Reboot" perfectly

---

## Appendix: Event System Code Structure

```swift
// New file: SurvivalEventSystem.swift

protocol SurvivalEvent {
    var id: String { get }
    var name: String { get }
    var warningDuration: TimeInterval { get }
    var duration: TimeInterval { get }
    var borderColor: UIColor { get }

    func onStart(state: inout GameState)
    func onUpdate(state: inout GameState, deltaTime: TimeInterval)
    func onEnd(state: inout GameState)
}

class SurvivalEventSystem {
    private var activeEvent: SurvivalEvent?
    private var eventTimer: TimeInterval = 0
    private var nextEventTime: TimeInterval = 60  // First event at 60s
    private var lastFlushTime: TimeInterval = -120  // Cooldown tracking

    func update(state: inout GameState, deltaTime: TimeInterval) {
        eventTimer += deltaTime

        // Check if time for new event
        if activeEvent == nil && eventTimer >= nextEventTime {
            triggerRandomEvent(state: &state)
        }

        // Update active event
        if var event = activeEvent {
            event.onUpdate(state: &state, deltaTime: deltaTime)
            // Check if event ended
            if eventTimer >= event.duration {
                event.onEnd(state: &state)
                activeEvent = nil
                scheduleNextEvent(state: state)
            }
        }
    }

    private func triggerRandomEvent(state: inout GameState) {
        let availableEvents = getAvailableEvents(survivalTime: state.timeElapsed)
        guard let event = availableEvents.randomElement() else { return }

        activeEvent = event
        eventTimer = 0
        event.onStart(state: &state)

        // Announce event
        state.announcementText = event.name
        state.announcementColor = event.borderColor
    }

    private func getAvailableEvents(survivalTime: TimeInterval) -> [SurvivalEvent] {
        var events: [SurvivalEvent] = []

        // Always available after 60s
        if survivalTime >= 60 {
            events.append(MemorySurgeEvent())
            events.append(BufferOverflowEvent())
        }

        // Unlock at 3 minutes
        if survivalTime >= 180 {
            events.append(ThermalThrottleEvent())
            if survivalTime - lastFlushTime >= 120 {
                events.append(CacheFlushEvent())
            }
        }

        // Unlock at 5 minutes
        if survivalTime >= 300 {
            events.append(DataCorruptionEvent())
            events.append(VirusSwarmEvent())
            events.append(SystemRestoreEvent())
        }

        return events
    }

    private func scheduleNextEvent(state: GameState) {
        // Events get more frequent over time
        let baseInterval: TimeInterval = 60
        let minInterval: TimeInterval = 40
        let reductionPerMinute: TimeInterval = 5

        let minutesSurvived = state.timeElapsed / 60
        let interval = max(minInterval, baseInterval - (minutesSurvived * reductionPerMinute))

        nextEventTime = eventTimer + interval
    }
}
```

---

## Part 4: Economy Connection (IMPLEMENTED)

### Survival Mode Rewards

**Primary Currency**: Data (◈)

| Source | Reward |
|--------|--------|
| Time survived | 2◈/sec base + 0.5◈/sec per minute survived |
| Enemy kills | 1◈ per enemy (coinValue) |
| Boss kills | 50◈ per boss |

### Extraction Mechanic

- **Extraction unlocks at**: 3 minutes (180 seconds)
- **Extraction reward**: 100% of earned Data
- **Death reward**: 50% of earned Data

**UI Elements**:
- Bottom-left: `◈ 0` showing running Data total
- Bottom-center: `⬆ EXTRACTION READY` (pulsing, shown after 3 min)

**Code**:
```swift
// In GameScene
var canExtract: Bool  // Check if extraction available
func triggerExtraction()  // Ends game with 100% reward

// In SurvivalArenaSystem
static func extract(state: inout GameState)
static func canExtract(state: GameState) -> Bool
```

### Boss Mode Rewards

**Primary Reward**: Blueprints / Protocol Unlocks

| Difficulty | Reward |
|------------|--------|
| Normal | Base blueprint drop |
| Hard | Better blueprint + bonus Data |
| Nightmare | Guaranteed rare + achievement |

---

## Implementation Status

### ✅ Completed
- [x] Delete DungeonSystem.swift
- [x] Gut ArenaSystem.swift (collision utilities only)
- [x] Remove dungeon code from GameScene
- [x] Simplify GameTypes (removed dungeon structs)
- [x] Create SurvivalArenaSystem with 7 events
- [x] Add visual rendering for all events
- [x] Integrate modifiers (speed, damage, spawn rate)
- [x] Buffer Overflow uses kill zones (not arena shrink)
- [x] Economy: Data earning (time + kills)
- [x] Extraction mechanic (3 min unlock, 100% vs 50%)
- [x] SwiftUI extraction button in GameContainerView
- [x] Post-game reward screen showing Data earned (with extraction bonus/penalty)
- [x] Save Data to PlayerProfile on game end (via recordSurvivorRun)

### ✅ ALL COMPLETE
- [x] Boss mode blueprint drops
  - Cyberboss drops: burst_protocol, trace_route
  - Void Harbinger drops: fork_bomb, overflow
  - Difficulty-based Data bonus (50/150/300)
  - Nightmare mode: Guaranteed rare blueprint if missing

---

## Next Steps

1. **Review this plan** - Does this match your vision?
2. **Approve scope** - Any events to add/remove?
3. **Begin Phase 1** - I'll start with the cleanup
