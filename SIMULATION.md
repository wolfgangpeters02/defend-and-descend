# TD Simulation System

Headless game loop for automated balance testing. Runs the full TD game logic without SpriteKit, driven by AI bots that make tower placement/upgrade/sell/overclock decisions. Enables running thousands of simulated games at 1000x+ realtime speed.

## Why

The existing `tools/balance-simulator.html` is outdated and can't capture emergent gameplay dynamics (tower synergies, overclock timing, efficiency spirals). Training bots to actually play the game and analyzing their performance gives real balance insights:

- "Overclock at threat 15 is always optimal"
- "Fragmenter + Pinger trivializes threat 1-30"
- "Storage cap bottlenecks progression at threat 40"
- "3 Throttlers prevent efficiency from ever dropping below 80%"
- "PSU power wall hits at 85% with 5 towers — need level 4 PSU to break through"

## Architecture

```
SimulationRunner
  |
  +-- SimulationConfig (seed, bot, protocols, sectors, componentLevels)
  |
  +-- TDSimulator (headless game loop)
  |     |
  |     +-- TDProjectileSystem (movement, homing, lifetime)
  |     +-- TDCollisionSystem (damage, status effects, death rewards)
  |     +-- PathSystem, TowerSystem, CoreSystem, etc. (existing systems, unchanged)
  |     +-- SeededRNG (deterministic random for reproducible runs)
  |     +-- Boss probability model (win chance from component levels + difficulty)
  |     |
  |     +-- TDBot.decide(state, profile) -> TDBotAction
  |
  +-- SimulationResult (metrics, wall metrics, replay log, efficiency graph)
  |
  +-- MetaRunner (chain N sessions with progression between runs)
```

The game logic was already ~75% decoupled from rendering. The remaining 25% (projectile movement + collision/damage resolution) was embedded in `TDGameScene.swift`. We extracted it into standalone system files so both the scene and the headless simulator can share the same logic.

## Files

### Simulation
| File | Purpose |
|------|---------|
| `GameEngine/Simulation/TDSimulator.swift` | Headless game loop + SeededRNG + boss probability model |
| `GameEngine/Simulation/TDBot.swift` | Bot protocol + 5 implementations |
| `GameEngine/Simulation/SimulationRunner.swift` | Batch runner, meta-runner, metrics, summary output |

### Extracted Systems
| File | Purpose |
|------|---------|
| `GameEngine/Systems/TDProjectileSystem.swift` | Projectile movement, homing, bounds |
| `GameEngine/Systems/TDCollisionSystem.swift` | Swept collision, damage, status effects, pierce, splash, death |

### Modified
| File | Change |
|------|--------|
| `Core/Config/BalanceConfig.swift` | `Simulation` struct: timing, wall thresholds, boss probability, bot thresholds, progression presets |
| `Rendering/TDGameScene.swift` | Delegates to new systems; ~450 lines of game logic replaced with system calls |

## Bot Decision Space

```swift
enum TDBotAction {
    case idle
    case placeTower(protocolId: String, slotId: String)
    case upgradeTower(towerId: String)
    case sellTower(towerId: String)
    case activateOverclock
    case engageBoss(difficulty: BossDifficulty)
    case ignoreBoss
}
```

Bots observe the full `TDGameState` and decide once every `BalanceConfig.Simulation.botDecisionInterval` (0.5s).

## Bots Implemented

| Bot | Strategy | Purpose |
|-----|----------|---------|
| **PassiveBot** | Never places towers | Baseline: core-only survival |
| **GreedyBot** | Upgrade strongest tower first, then place cheapest | Single-tower DPS maximizer |
| **SpreadBot** | Fill all slots round-robin, then upgrade lowest | Even coverage strategy |
| **RushOverclockBot** | Overclock aggressively, prioritize high-damage towers | Income-focused play |
| **AdaptiveBot** | Efficiency panic mode, power ceiling awareness, hash reserves | Smart reactive play |

### AdaptiveBot Behaviors
- **Efficiency panic** (< 60%): Stops placing towers, prioritizes slow towers, refuses overclock
- **Power ceiling** (> 85% usage): Stops placing new towers, focuses on upgrades
- **Hash reserve**: Keeps 10s of income as buffer before spending
- **Boss difficulty scaling**: Hard when healthy (> 85% eff), Normal otherwise, ignore when panicking

## Component Levels

`SimulationConfig.componentLevels` accepts a full `GlobalUpgrades` struct controlling:
- **PSU** → Power capacity (how many towers fit)
- **CPU** → Hash generation rate
- **RAM** → Efficiency recovery speed
- **Cooling** → Tower fire rate multiplier
- **HDD** → Hash storage capacity

### Preset Progression Stages
```swift
BalanceConfig.Simulation.earlyGame  // All level 1
BalanceConfig.Simulation.midGame    // PSU 4, CPU 4, RAM 3, Cool 3, HDD 3
BalanceConfig.Simulation.lateGame   // PSU 7, CPU 7, RAM 6, Cool 6, HDD 6
BalanceConfig.Simulation.endGame    // All level 10
```

## Wall Metrics

Detect when progression bottlenecks hit:
- **peakPowerUsagePercent**: Highest power used / capacity (1.0 = capped out)
- **timeAtPowerWall**: Seconds spent above 90% power usage
- **peakStoragePercent**: Highest hash / storage capacity
- **timeAtStorageWall**: Seconds spent above 90% storage
- **hashFloat**: Estimated hash income wasted while storage-capped

## Boss Fights

Boss fights use a **probabilistic model** based on component levels and difficulty:

```
winChance = base(0.60) + (avgLevel - 1) × 0.05 + difficultyMod
```

| Difficulty | Modifier | Example (Lv1) | Example (Lv5) |
|-----------|----------|---------------|---------------|
| Easy | +0.25 | 85% | 95% |
| Normal | +0.00 | 60% | 80% |
| Hard | -0.20 | 40% | 60% |
| Nightmare | -0.35 | 25% | 45% |

Win probability is clamped to [10%, 95%]. On win: threat resets, hash reward applied. On loss: efficiency penalty.

## Usage

```swift
// Quick comparison of all 5 bots (prints table to console)
SimulationRunner.runDefaultComparison()

// With mid-game components
SimulationRunner.runDefaultComparison(
    componentLevels: BalanceConfig.Simulation.midGame
)

// Progression comparison: same bot across all 4 stages
SimulationRunner.runProgressionComparison(bot: SpreadBot())

// Meta-simulation: 10 sessions with auto-upgrades between runs
let meta = SimulationRunner.runMetaSimulation(
    sessions: 10,
    bot: AdaptiveBot()
)
SimulationRunner.printMetaSummary(meta, botName: "Adaptive")

// Custom single run
let config = SimulationConfig(
    seed: 42,
    bot: AdaptiveBot(),
    maxGameTime: 1800,
    compiledProtocols: ["kernel_pulse", "burst_protocol", "ice_shard", "trace_route"],
    unlockedSectors: [SectorID.power.rawValue],
    componentLevels: BalanceConfig.Simulation.midGame
)
if let result = SimulationRunner.run(config: config) {
    SimulationRunner.printSummary([result])
}
```

## Determinism

Same seed + same bot + same config = identical result. The `SeededRNG` wraps `GKMersenneTwisterRandomSource`. Boss fight outcomes also use the seeded RNG. Currently only used inside the simulator; the live game still uses `Int.random()`.

## Meta-Runner

Chain N sessions to simulate multi-session progression:
1. Run session with current component levels
2. After session: auto-spend surplus hash on cheapest component upgrades
3. Carry over remaining hash (capped by new storage capacity)
4. Repeat with upgraded components

Tracks: sessions to max all components, total hash earned/spent on upgrades, per-session results.

## Implementation Status

### Done
- [x] Extract projectile movement into `TDProjectileSystem`
- [x] Extract collision/damage into `TDCollisionSystem`
- [x] Refactor `TDGameScene` to use extracted systems (game plays identically)
- [x] `TDSimulator` headless game loop
- [x] `SeededRNG` for deterministic runs
- [x] `TDBot` protocol + 5 rule-based bots (incl. AdaptiveBot)
- [x] `SimulationRunner` with batch execution and metrics
- [x] `BalanceConfig.Simulation` for all tunable sim parameters
- [x] Full component levels in `SimulationConfig` (PSU, CPU, RAM, Cooling, HDD)
- [x] Progression presets (earlyGame, midGame, lateGame, endGame)
- [x] Wall metrics (power cap %, storage cap %, hash float)
- [x] Probabilistic boss model (win chance from component levels + difficulty)
- [x] Meta-runner for multi-session progression testing
- [x] AdaptiveBot with efficiency panic, power ceiling, hash reserve
- [x] Progression comparison runner (same bot across all stages)
- [x] Xcode build passes

### Future
- [ ] Wire up a debug button / SwiftUI view to trigger simulations from the app
- [ ] Genetic algorithm for bot parameter optimization
- [ ] SwiftUI dashboard to visualize efficiency-over-time graphs
- [ ] Restore per-hit impact VFX in TDGameScene (minor visual regression from extraction)
- [ ] Inject SeededRNG into live game systems for fully reproducible replays
- [ ] GPU/Expansion component levels (currently GlobalUpgrades has 5 core components)
