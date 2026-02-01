# Boss Fight Phase Documentation

## CYBERBOSS (Server Heist Boss)
Health thresholds: 100% -> 75% -> 50% -> 25%

### Phase 1 (100% - 75% HP) - Mode Switching
- **Mode Switching**: Alternates between melee and ranged mode every 5 seconds

- **Melee Mode** (red, DANGEROUS):
  - Chases player aggressively (1.2x speed)
  - **Chainsaw Animation**: Rotating saw-blade effect around boss
    - 8 red triangular teeth spinning fast (0.8s rotation)
    - Pulsing red danger circle
    - Orange warning ring
  - **Contact Damage**: YES - touching the boss deals damage

- **Ranged Mode** (blue, SAFE to approach):
  - Keeps distance (~450px), strafes around player
  - **NO Contact Damage**: Player can touch boss safely
  - **Energy Blast Volley**: 5 cyan projectiles fired in a ~40° spread
    - Size: 35% of boss size
    - 25 damage per projectile, speed 180
    - Fires every 1.2 seconds
    - Trail particles enabled

### Phase 2 (75% - 50% HP) - Minion Phase
- **Same as Phase 1** (mode switching, chainsaw, ranged attacks)
- **Minion Spawns**: Every 8 seconds spawns:
  - 5-6 fast enemies
  - 4-5 tank enemies
  - Spawns in circle around boss (80-150px radius)
  - **Minion Cap**: Maximum 25 minions on screen (performance limit)

### Phase 3 (50% - 25% HP) - Puddle Phase
- **Stationary**: Boss stops moving completely
- **No Chainsaw**: Mode switching stops
- **Minions Continue**: Still spawning to keep player moving

- **Damage Puddles**: Spawns 3-5 puddles every 2 seconds
  - **Duration**: 4 seconds total (reduced from 8)
  - **Warning Phase** (0-1 sec): Yellow outline, no fill, NO damage
    - Pulsing glow to alert player
  - **Active Phase** (1-3.5 sec): Purple fill, magenta border
    - 10 DPS (5 damage per 0.5s tick)
  - **Pop Phase** (3.5-4 sec): Red fill, orange border, intense glow
    - **30 burst damage** if standing in puddle when it pops
  - Spawn at random arena locations (100px from edges)

### Phase 4 (25% - 0% HP) - ENRAGE
- **Stationary**: Boss remains stationary
- **Laser Beams**: 5 rotating lasers emanating from boss
  - **1 second warning phase** - beams visible but deal no damage
  - Rotation: 25 degrees/second (slowed for playability)
  - Length: 800px, Width: 10px
  - **Damage: 50** (survivable - player can take 1-2 hits)
  - Red color with flicker effect and glow
  - 0.5 second invulnerability after hit
- **Faster Puddles**: Spawn interval reduced to 1.5 seconds
  - Same mechanics as Phase 3

---

## VOID HARBINGER (Raid Boss)
Health thresholds: 100% -> 70% -> 40% -> 10%

### Phase 1 (100% - 70% HP) - Introduction
- **Movement**: Slowly chases player (0.6x speed)
- **Void Zones**: Every 8 seconds, spawns at player position
  - 2 second warning (yellow outline, pulsing)
  - 5 seconds active (purple fill)
  - 80px radius, 40 DPS while standing in it
- **Shadow Bolt Volley**: Every 6 seconds, fires 8 projectiles in spread (20 damage each, speed 350)
- **Minion Spawns**: Every 15 seconds, spawns 4 void minions (30 HP, 10 damage, speed 120)

### Phase 2 (70% - 40% HP) - PYLON PHASE
- **Boss Invulnerable**: Cannot be damaged until all pylons destroyed
- **Stationary**: Boss moves to arena center and stops
- **4 Pylons**: Spawn at corners of arena
  - 500 HP each
  - Purple crystal design with health bar
  - Fire homing beams at player every 3 seconds (30 damage, homing strength 2.0)
  - Must destroy all 4 to proceed
- **Player must attack pylons, not boss**
- Projectiles collide with pylons and deal damage

### Phase 3 (40% - 10% HP) - Chaos Phase
- **Movement**: Resumes chasing (0.8x speed)
- **Void Zones**: Continue spawning
- **Void Rifts**: 3 rotating energy beams from arena center
  - 45 degrees/second rotation
  - 700px length, 40px width
  - 50 DPS on contact
- **Gravity Wells**: 2 black holes that pull player toward them
  - 250px pull radius
  - Visual: spinning black/purple effect
- **Meteor Strikes**: Every 6 seconds, large void zone (100px, 80 damage)
- **Elite Minions**: Every 20 seconds, spawns 1 elite (200 HP, 25 damage)

### Phase 4 (10% - 0% HP) - FINAL STAND
- **All Phase 3 mechanics** plus:
- **Shrinking Arena**: Circular boundary shrinks at 30px/second
  - Minimum radius: 150px
  - Standing outside deals 40 DPS and pushes back toward center
  - Red pulsing boundary ring
- **Random Teleports**: Boss teleports every 3 seconds
- **Faster Void Zones**: Spawn interval reduced to 2 seconds

---

## Implementation Status

### Cyberboss - IMPLEMENTED
- [x] Phase transitions based on health thresholds
- [x] Mode switching with visual indicators (color change)
- [x] Chainsaw animation for melee mode
- [x] No contact damage in ranged mode
- [x] Ranged volley spread attack (5 projectiles)
- [x] Minion spawning (Phase 2-3)
- [x] Damage puddles with warning/active/pop phases
- [x] Rotating laser beams with warning phase (Phase 4)
- [x] Death checks on all damage sources
- [x] Obstacle collision avoidance
- [x] Arena bounds enforcement

### Void Harbinger - IMPLEMENTED
- [x] Phase transitions based on health thresholds
- [x] Void zone spawning with warning phase
- [x] Pylon phase with invulnerability
- [x] Pylon damage from player projectiles
- [x] Void rifts (rotating beams)
- [x] Gravity wells
- [x] Shrinking arena boundary
- [x] Death checks on all damage sources

---

## Visual Reference

### Cyberboss Colors
- Melee Mode: `#ff4444` (red)
- Ranged Mode: `#4444ff` (blue)
- Energy Blast: `#00ffff` (cyan)
- Puddle Warning: Yellow outline
- Puddle Active: Purple fill, magenta border
- Puddle Pop: Red fill, orange border
- Laser Beams: Red with glow

### Void Harbinger Colors
- Boss: Purple/magenta
- Void Zones: Purple fill when active, yellow warning
- Pylons: Purple body, magenta crystal
- Void Rifts: Purple with glow
- Gravity Wells: Black center, purple ring
- Arena Boundary: Red pulsing

---

## Tuning Notes

### Damage Values (Cyberboss)
| Source | Damage | Notes |
|--------|--------|-------|
| Contact (melee) | Enemy damage stat | Only in melee mode |
| Energy Blast Volley | 25 × 5 | 5 projectiles, 25 damage each |
| Puddle (active) | 10 DPS | 5 damage per 0.5s tick |
| Puddle (pop) | 30 | Burst when puddle expires |
| Laser Beam | 50 | Was 999, now survivable |

### Damage Values (Void Harbinger)
| Source | Damage | Notes |
|--------|--------|-------|
| Contact | Enemy damage stat | Always active |
| Shadow Bolt | 20 | Per projectile, 8 projectiles per volley |
| Pylon Beam | 30 | Homing projectile |
| Void Zone | 40 DPS | While standing in it |
| Void Rift | 50 DPS | While touching beam |
| Meteor Strike | 80 | Burst damage, 100px radius |
| Outside Arena | 40 DPS | Phase 4 only |

---

## Future Improvements
- [ ] Sound effects for mode switches
- [ ] Screen shake on phase transitions
- [ ] Boss health bar improvements
- [ ] Victory celebration effects
- [ ] Difficulty scaling options
