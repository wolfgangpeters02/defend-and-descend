# Project Reboot - Claude Code Instructions

## Localization System (L10n)

**IMPORTANT**: This project uses Apple's String Catalogs for localization. All user-facing text MUST use the L10n helper system.

### Rules

1. **Never hardcode user-facing strings** - All text shown to users must go through L10n
2. **Use L10n helpers** - Located at `LegendarySurvivors/Core/Localization/L10n.swift`
3. **Add translations** - Located at `LegendarySurvivors/Resources/Localizable.xcstrings`

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

**IMPORTANT**: All game balance values MUST be centralized in `LegendarySurvivors/Core/Config/BalanceConfig.swift`.

### Rules

1. **Never hardcode balance values** - No magic numbers in game systems
2. **Use BalanceConfig** - Reference values as `BalanceConfig.StructName.valueName`
3. **Update simulator** - When adding tunable parameters, update `tools/balance-simulator.html`

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

3. **Add helper functions** if formula is reused:
   ```swift
   static func scaledDamage(base: CGFloat, level: Int) -> CGFloat {
       return base * (1 + CGFloat(level) * MySystem.damageMultiplier)
   }
   ```

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
