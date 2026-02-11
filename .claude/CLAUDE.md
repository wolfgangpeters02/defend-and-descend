# Project Reboot - Claude Code Instructions

## Localization System (L10n)

**IMPORTANT**: This project uses Apple's String Catalogs for localization. All user-facing text MUST use the L10n helper system.

### Rules

1. **Never hardcode user-facing strings** - All text shown to users must go through L10n
2. **Use L10n helpers** - Located at `SystemReboot/Core/Localization/L10n.swift`
3. **Add translations** - Located at `SystemReboot/Resources/Localizable.xcstrings`

### How to Add New Localized Strings

1. **Add L10n key** in `L10n.swift`:
   ```swift
   enum SomeSection {
       static let myKey = String(localized: "section.myKey")
       // For format strings with parameters:
       static func myFormat(_ value: Int) -> String {
           String(format: String(localized: "section.myFormat"), value)
       }
   }
   ```

2. **Add translation** in `Localizable.xcstrings`:
   ```json
   "section.myKey" : {
     "extractionState" : "manual",
     "localizations" : {
       "de" : { "stringUnit" : { "state" : "translated", "value" : "German text" } },
       "en" : { "stringUnit" : { "state" : "translated", "value" : "English text" } }
     }
   }
   ```

3. **Use in code**:
   - SwiftUI: `Text(L10n.SomeSection.myKey)`
   - SpriteKit: `SKLabelNode(text: L10n.SomeSection.myKey)`

### What NOT to Localize

- SF Symbol names (e.g., `"checkmark.circle.fill"`)
- Color hex codes
- Technical identifiers (e.g., node names, keys)
- Format specifiers alone (`"%d"`, `"%@"`)
- Hardware/tech terms that are universal (e.g., "CPU", "DDR5", "USB")

### Existing L10n Sections

- `L10n.Common` - Shared UI labels (retry, cancel, done, etc.)
- `L10n.Game.HUD` - In-game HUD elements
- `L10n.GameOver` - Game over screen
- `L10n.Boss` - Boss encounters
- `L10n.Sector` - Sector management
- `L10n.TD` - Tower defense mode
- `L10n.ZeroDay` - Zero-day virus events
- `L10n.Freeze` - System freeze events
- `L10n.Override` - Manual override minigame
- `L10n.Blueprint` - Blueprint discovery
- `L10n.Stats` - Stat labels (DMG, RNG, etc.)
- `L10n.Upgrade` - Upgrade modal
- `L10n.Arsenal` - Arsenal/protocols
- `L10n.CPU` - CPU tier upgrades
- `L10n.Extraction` - Extraction mechanics

### Languages Supported

- English (en) - Primary
- German (de)

When adding new strings, always provide both English and German translations.

---

## Balance System (BalanceConfig)

**IMPORTANT**: All game balance values AND formulas MUST be centralized in `SystemReboot/Core/Config/BalanceConfig.swift`.

### Rules

1. **Never hardcode balance values** - No magic numbers in game systems
2. **Never duplicate formulas** - If a calculation is used in multiple places, it belongs in BalanceConfig as a function
3. **Use BalanceConfig** - Reference values as `BalanceConfig.StructName.valueName`
4. **Update simulator** - When adding tunable parameters, update `tools/balance-simulator.html`

### Core Formulas (MUST use these, never reimplement)

```swift
// Upgrade costs - exponential: base × 2^(level-1)
BalanceConfig.exponentialUpgradeCost(baseCost: Int, currentLevel: Int) -> Int

// Level stat multiplier - linear: level number as multiplier (Lv1=1x, Lv5=5x)
BalanceConfig.levelStatMultiplier(level: Int) -> CGFloat
```

### How to Add New Balance Values

1. **Find or create struct** in `BalanceConfig.swift`:
   ```swift
   struct MySystem {
       static let cooldownDuration: TimeInterval = 2.0
       static let damageMultiplier: CGFloat = 1.5
   }
   ```

2. **Use in game code**:
   ```swift
   // ❌ Bad - hardcoded value
   let cooldown = 2.0

   // ✅ Good - centralized config
   let cooldown = BalanceConfig.MySystem.cooldownDuration
   ```

3. **Add helper functions for reused formulas**:
   ```swift
   // ❌ Bad - formula duplicated in Protocol.swift, TDTypes.swift, UI code
   let cost = baseCost * Int(pow(2.0, Double(level - 1)))

   // ✅ Good - single source of truth
   let cost = BalanceConfig.exponentialUpgradeCost(baseCost: baseCost, currentLevel: level)
   ```

### What IS a Balance Value (put in BalanceConfig)

- Damage numbers, health values, speeds
- Costs (upgrade costs, placement costs, compile costs)
- Durations (cooldowns, timers, intervals)
- Rates (spawn rate, growth rate, decay rate)
- Multipliers and scaling factors
- Thresholds (when events trigger, level caps)
- Formulas that calculate any of the above

### What is NOT a Balance Value (keep in code)

- UI layout constants (use DesignSystem.swift)
- String literals (use L10n)
- Technical implementation details (array indices, enum cases)
- One-off calculations that aren't reused

### Existing BalanceConfig Sections

- `Player` - Base stats (health, speed, damage)
- `Waves` - Wave scaling (health/speed per wave, boss intervals)
- `ThreatLevel` - Idle mode threat scaling and enemy unlock thresholds
- `Towers` - Placement costs, refund rates
- `Cyberboss` / `VoidHarbinger` - Boss-specific tuning
- `SurvivalEvents` - Event durations, damage values
- `SurvivalEconomy` - Hash earning rates
- `Overclock` - Risk/reward multipliers
- `DropRates` - Blueprint drop chances
- `Leveling` - XP requirements, stat bonuses

### Balance Testing Tools

- `tools/balance-simulator.html` - Interactive web simulator
- `tools/BalanceSimulator/` - Swift CLI for Monte Carlo testing
- `BalanceConfig.exportJSON()` - Syncs Swift values to web tools

---

## Architecture Rules

**IMPORTANT**: The codebase was refactored from God Objects into focused files. Follow these rules to keep it that way.

### File Size & Separation of Concerns

1. **No file should exceed ~800 lines** — if it does, split by concern using Swift extensions in separate files
2. **No domain logic in UI files** — views call services, they don't calculate rewards, validate placement, or simulate physics
3. **No duplicated logic across files** — if two views need the same operation, extract a service to `GameEngine/Systems/`
4. **New types get their own file** — don't add structs/enums to an existing file unless they're small (<30 lines) and tightly coupled

### Where Code Lives

| Code Type | Location | Example |
|-----------|----------|---------|
| Pure data types & enums | `Core/Types/` | BossStates, WaveTypes |
| Game logic & services | `GameEngine/Systems/` | TDGameLoop, GameRewardService |
| SpriteKit rendering | `Rendering/` | TowerVisualFactory, ParticleEffectService |
| SwiftUI views | `UI/Tabs/` or `UI/Game/` | ArsenalView, TDGameContainerView |
| Config & constants | `Core/Config/` | BalanceConfig, DesignSystem |

### Anti-Patterns to Avoid

- Adding game calculations (XP, costs, damage) directly in a SwiftUI view — use a service in `GameEngine/Systems/`
- Growing a file past 800 lines — split into focused `+Extension` files
- Using NotificationCenter for control flow between views — use callbacks or coordinators
- Putting a new boss's rendering code in GameScene.swift — add to BossRenderingManager
- Duplicating freeze/reward/placement logic across views — call the existing service
