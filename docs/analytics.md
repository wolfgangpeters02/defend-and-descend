# Analytics Setup

## Provider: Mixpanel (Free Tier)

- **SDK:** mixpanel-swift 5.x via Swift Package Manager
- **Data Residency:** EU (api-eu.mixpanel.com)
- **Project:** https://eu.mixpanel.com/project/3991676
- **Token:** `f15129361422ad3dc2fec2951da3b77f`
- **Free tier limit:** 1M events/month, unlimited data retention

## Privacy

- **No PII collected** — anonymous tracking only
- **Distinct ID:** `UIDevice.current.identifierForVendor` (Apple's per-vendor device UUID)
- **No IDFA** — no ATT prompt required
- **No cookies** — native app, no consent banner needed
- **App Store privacy label:** "Data Not Linked to You: Identifiers, Usage Data"
- **GDPR:** Data stored in EU; recommend adding a privacy policy mentioning anonymous analytics

## Architecture

All analytics go through a single service:

```
SystemReboot/Services/AnalyticsService.swift
```

- Singleton: `AnalyticsService.shared`
- Wraps Mixpanel with typed methods — no raw `track()` calls elsewhere
- Flush interval: 60 seconds (+ immediate flush on app launch and background)
- Debug logging enabled in `#if DEBUG` builds only
- `trackAutomaticEvents: false` — we control exactly what's sent

## Events Tracked

### App Lifecycle

| Event | Properties | Hook Location | Purpose |
|-------|-----------|---------------|---------|
| `app_launched` | `first_launch: Bool` | `SystemRebootApp.init()` | New vs returning user, DAU |
| `session_start` | — | `SystemRebootApp` on foreground from background | Retention (D1/D3/D7), session frequency |

### Tutorial (FTUE)

| Event | Properties | Hook Location | Purpose |
|-------|-----------|---------------|---------|
| `tutorial_completed` | `type: "camera_intro"` | `AppState+Tutorial.completeIntroSequence()` | FTUE funnel |
| `first_tower_placed` | — | `AppState+Tutorial.recordFirstTowerPlacement()` | FTUE milestone |
| `tutorial_completed` | `type: "boss_fight"` | `AppState+Tutorial.completeBossTutorial()` | FTUE funnel |

### Boss Fights

| Event | Properties | Hook Location | Purpose |
|-------|-----------|---------------|---------|
| `boss_fight_started` | `boss_id`, `difficulty` | `BossFightCoordinator.onFightStarted()` | Boss engagement rate |
| `boss_fight_completed` | `boss_id`, `difficulty`, `victory`, `first_kill` | `BossFightCoordinator.onFightCompleted()` | Win rate, boss funnel, difficulty analysis |
| `blueprint_dropped` | `boss_id`, `protocol_id` | `BossFightCoordinator.onFightCompleted()` (victory path) | Loot tracking, drop rate validation |

### Economy

| Event | Properties | Hook Location | Purpose |
|-------|-----------|---------------|---------|
| `offline_earnings_claimed` | `hash_amount`, `time_away_hours` | `AppState.collectOfflineEarnings()` | Monitor offline economy, detect inflation |

### Progression

| Event | Properties | Hook Location | Purpose |
|-------|-----------|---------------|---------|
| `protocol_compiled` | `protocol_id`, `cost` | `ArsenalView.compileProtocol()` | Progression speed |
| `protocol_upgraded` | `protocol_id`, `from_level`, `to_level` | `ArsenalView.upgradeProtocol()` | Engagement depth |
| `component_upgraded` | `component`, `from_level`, `to_level` | `UpgradesView.performUpgrade()` | Engagement depth |
| `sector_unlocked` | `sector_id`, `cost` | `SectorUnlockSystem.unlockSector()` | Progression milestone |
| `level_up` | `new_level` | `GameRewardService.checkLevelUp()` | Progression speed |
| `wave_completed` | `wave_number` | `WaveSystem.completeWave()` | TD engagement |

## Key Questions These Events Answer

1. **Do users retain for 3-7 days?** — `app_launched` + `session_start` retention cohorts
2. **Do they beat all 4 bosses?** — `boss_fight_completed` funnel by `boss_id` with `victory: true`
3. **How fast do they progress?** — Time between `sector_unlocked`, `protocol_compiled`, `level_up` events
4. **Where do they drop off?** — FTUE funnel: `tutorial_completed` -> `first_tower_placed` -> `boss_fight_started`
5. **Is difficulty tuned correctly?** — `boss_fight_completed` win rate segmented by `difficulty`
6. **Is offline economy balanced?** — `offline_earnings_claimed` Hash amounts vs time away

## Files Modified

| File | Change |
|------|--------|
| `SystemReboot/Services/AnalyticsService.swift` | **New** — Mixpanel wrapper singleton |
| `SystemReboot/App/AppState.swift` | Offline earnings claimed event |
| `SystemReboot/App/SystemRebootApp.swift` | Launch tracking, session start, flush on background |
| `SystemReboot/App/AppState+Tutorial.swift` | Tutorial completion + first tower events |
| `SystemReboot/GameEngine/Systems/BossFightCoordinator.swift` | Boss fight start/complete/blueprint events + `onFightStarted()` method |
| `SystemReboot/UI/Game/TDGameContainerView+Overlays.swift` | Calls `bossCoordinator.onFightStarted()` |
| `SystemReboot/UI/Tabs/MotherboardView.swift` | Calls `bossCoordinator.onFightStarted()` |
| `SystemReboot/UI/Tabs/ArsenalView.swift` | Protocol compile + upgrade events |
| `SystemReboot/UI/Tabs/UpgradesView.swift` | Component upgrade events |
| `SystemReboot/Core/Systems/SectorUnlockSystem.swift` | Sector unlock events |
| `SystemReboot/GameEngine/Systems/GameRewardService.swift` | Level up events |
| `SystemReboot/GameEngine/Systems/WaveSystem.swift` | Wave completion events |

## Adding New Events

1. Add a typed method to `AnalyticsService.swift`
2. Call it from the appropriate hook point (1 line)
3. Update this document
