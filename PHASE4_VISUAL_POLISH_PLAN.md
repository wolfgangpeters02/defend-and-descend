# Phase 4: Visual Polish Plan
## "From Big to Small" - Making It POP

---

## THE VISION: Terminal Hacker Aesthetic

The game should feel like you're inside a computer system. Everything has a **digital, terminal, circuit board** feel. Dark backgrounds, glowing cyan traces, monospace fonts, scan lines, and glitch effects.

---

## COLOR SYSTEM (Source of Truth)

```
BACKGROUNDS
-----------
Background:     #0a0a0f  (Almost black - main backdrop)
Surface:        #1a1a24  (Cards, panels, elevated)
Dark Surface:   #0d1117  (Darker panels)

BRAND COLORS
------------
Primary:        #00d4ff  (Cyan - circuits, Watts, Idle mode accent)
Secondary:      #8b5cf6  (Purple - magic, special effects)
Success:        #22c55e  (Green - health, Data, valid, Active mode accent)
Warning:        #f59e0b  (Amber - alerts, legendary, important)
Danger:         #ef4444  (Red - enemies, damage, errors)
Muted:          #4a4a5a  (Disabled, inactive, subtle)

ENEMY TIERS
-----------
Tier 1:         #ef4444  (Red - basic viruses)
Tier 2:         #f97316  (Orange - medium)
Tier 3:         #a855f7  (Purple - hard)
Tier 4/Boss:    #ffffff + color cycle (White with rainbow pulse)
Zero-Day:       #9933ff  (Deep purple/violet - special boss)

RARITY
------
Common:         #9ca3af  (Gray)
Rare:           #3b82f6  (Blue)
Epic:           #a855f7  (Purple)
Legendary:      #f59e0b  (Amber/Gold)
```

---

## TYPOGRAPHY (Monospace Terminal Feel)

ALL TEXT should use monospace/terminal fonts:
- **Display (32-48pt)**: `.system(.largeTitle, design: .monospaced)` + `.bold`
- **Headline (18-24pt)**: `.system(size: 20, weight: .bold, design: .monospaced)`
- **Body (14-16pt)**: `.system(size: 14, design: .monospaced)`
- **Caption (10-12pt)**: `.system(size: 11, design: .monospaced)`
- **Numbers**: Always monospaced for alignment

---

## BIG: SCREEN LAYOUTS

### TD Mode (Motherboard) - THE VISION

```
┌─────────────────────────────────────────────────────────────┐
│  ⚡ 247/s        ████████████████░░░░░░        CPU 87%   ⚙️ │  <- TOP BAR
├─────────────────────────────────────────────────────────────┤
│                                                             │
│    ════════════════════════════════════════════════         │  <- CIRCUIT TRACES (Cyan glow)
│    ║                                              ║         │
│    ║     [FW]══════════[FW]═══════════════════   ║         │  <- Firewalls on junctions
│    ║       ║              ║                  ║   ║         │
│    ════════╬══════════════╬══════════════════╬═══╝         │
│            ║              ║                  ║              │
│            ║        ╔═══════════╗            ║              │
│            ║        ║    CPU    ║            ║              │  <- Core (pulsing)
│            ╚════════╣   ███████ ╠════════════╝              │
│                     ╚═══════════╝                           │
│                                                             │
│  ▪ ▪ ▪ viruses flowing along traces ▪ ▪ ▪                   │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  DRAG FIREWALL TO DEPLOY                                    │  <- Hint text
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐                        │  <- Tower deck (compact)
│  │ 🛡️ │ │ ❄️ │ │ ⚡ │ │ 🔥 │ │ 💀 │                        │
│  │100W│ │150W│ │200W│ │300W│ │500W│                        │
│  └────┘ └────┘ └────┘ └────┘ └────┘                        │
└─────────────────────────────────────────────────────────────┘
```

**TOP BAR Components:**
| Element | Position | Visual |
|---------|----------|--------|
| Watts/sec | Left | ⚡ icon + cyan number + "/s" |
| Efficiency Bar | Center | Progress bar with gradient (green→yellow→red) |
| CPU % | Center-Right | "CPU XX%" in efficiency color |
| Pause/Settings | Right | Gear icon button |

**MAIN VIEW:**
- Background: #0a0a0f with subtle circuit grid pattern
- Circuit traces: 60-80pt wide, cyan (#00d4ff) with glow effect
- Trace borders: Darker cyan (#006688)
- Core: Large CPU icon, pulsing animation, center of screen
- Firewalls: Placed on trace junctions, show tier stars
- Viruses: Small geometric shapes (hexagons) flowing along traces

**BOTTOM BAR:**
- Dark panel background
- Hint text: "DRAG FIREWALL TO DEPLOY"
- Tower cards: Compact, show icon + cost
- Scrollable horizontally

### Active Mode (Debugger) - THE VISION

```
┌─────────────────────────────────────────────────────────────┐
│  ♥♥♥♥♥░░░░░   SECTOR 1-A   ◈ 47   ⏱ 2:34                  │  <- TOP BAR
├─────────────────────────────────────────────────────────────┤
│                                                             │
│     ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─             │  <- Scan lines (subtle)
│   ═ ═ ═ ═ ═ ═ ═ ═ ═ ═ ═ ═ ═ ═ ═ ═ ═ ═ ═ ═ ═ ═ ═           │
│     ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─             │
│                  ▲ ▲                                        │
│            ▲         ▲       ▲                              │  <- Enemies (red shapes)
│                                                             │
│                    ◇                                        │  <- Player (cyan cursor)
│              ▲           ▲                                  │
│                    ▲                                        │
│     ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─             │
│   ═ ═ ═ ═ ═ ═ ═ ═ ═ ═ ═ ═ ═ ═ ═ ═ ═ ═ ═ ═ ═ ═ ═           │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                        ●                                    │  <- Joystick
│                      ╱   ╲                                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**TOP BAR Components:**
| Element | Position | Visual |
|---------|----------|--------|
| Health | Left | Heart icons (filled/empty) or health bar |
| Sector | Center | "SECTOR X-Y" in green |
| Data | Center-Right | ◈ icon + green number |
| Timer | Right | ⏱ icon + time |

**MAIN VIEW:**
- Background: Dark with visible scan lines overlay
- Corruption particles: Subtle noise, flickering dots
- Player: Bright cyan cursor/arrow, glowing
- Enemies: Red/orange geometric shapes (hexagons, triangles)
- Projectiles: Cyan trails
- Pickups: Green (health), Yellow (data), Blue (powerup)

---

## MEDIUM: COMPONENT STYLING

### Circuit Board Background (TD Mode)
```swift
// Grid pattern of dots or circuit traces
- Base: #0a0a0f solid
- Grid: #1a1a24 lines at 40pt intervals
- Nodes: Small dots at intersections
- Subtle glow effect around active elements
```

### Path/Trace Rendering
```swift
// Virus paths should look like circuit traces
- Width: 60-80pt (much wider than typical TD games)
- Fill: Cyan gradient #00d4ff → #0099cc
- Border: Dark cyan #006688, 4pt
- Glow: Outer glow effect, 8pt blur
- Direction: Subtle chevron arrows showing flow
```

### Enemy (Virus) Rendering
```swift
// Geometric virus shapes
- Shape: Hexagon (6-sided) for regular, Triangle for fast, Diamond for tank
- Size: 24-40pt based on tier
- Color: Tier-based (red → orange → purple)
- Effect: Slight inner glow, pulsing
- Zero-Day: Much larger (60pt), purple with white corona
```

### Firewall (Tower) Rendering
```swift
// Digital firewall nodes
- Base: Rounded rectangle or circle
- Color: Rarity-based glow
- Icon: SF Symbol inside (shield, flame, snowflake, etc.)
- Stars: Gold stars for merge level (1-3)
- Range: Only shown when selected (subtle circle)
```

### Core (CPU) Rendering
```swift
// The thing being protected
- Shape: Large octagon or rounded square
- Size: 80-100pt
- Color: Cyan with pulse animation
- Text: "CPU" inside
- Effect: Radial glow that intensifies with efficiency
```

---

## SMALL: DETAIL POLISH

### Scan Lines Effect (Active Mode)
```swift
// Subtle horizontal lines across the screen
- Lines: 2pt tall, every 4pt
- Color: White at 3% opacity
- Animation: Slow vertical scroll (subtle)
- Optional: Occasional "glitch" jump
```

### Glitch Effect (Damage/Corruption)
```swift
// When player takes damage or in corrupted zones
- RGB split: Offset red/blue channels by 2-3pt
- Horizontal displacement: Random sections shift
- Duration: 0.1-0.2s
- Frequency: On damage, or continuous in corruption zones
```

### Particle Effects
```swift
// Corruption particles (Active mode)
- Small dots (3-6pt)
- Random movement
- Color: White at 20% opacity
- Count: 20-40 on screen

// Circuit pulse (TD mode on tower fire)
- Line travels along circuit trace
- Color: Bright cyan
- Speed: Fast (0.3s)
- Fade: Quick fade out

// Data stream (pickup collection)
- Small squares flowing to UI
- Color: Green for data, Yellow for coins
- Duration: 0.5s
```

### Button Styling
```swift
// All buttons should have terminal feel
- Background: Surface color or transparent
- Border: 1-2pt, primary/accent color
- Text: Monospace, bold
- Hover/Press: Glow effect, scale 0.95
- Disabled: Muted color, no glow
```

### Panel/Card Styling
```swift
// Information panels
- Background: #1a1a24 or #0d1117
- Border: 1pt, accent color at 30% opacity
- Corner radius: 12-16pt
- Shadow: Subtle glow in accent color
```

---

## VISUAL EFFECTS IMPLEMENTATION CHECKLIST

### High Priority
- [ ] Scan lines overlay for Active mode
- [ ] Glitch effect on damage
- [ ] Circuit pulse on tower attack
- [ ] Core pulse animation
- [ ] Enemy death dissolve effect

### Medium Priority
- [ ] Corruption particles in Active mode
- [ ] Data stream pickup effect
- [ ] Path direction chevrons
- [ ] Grid pattern background

### Lower Priority (Nice to Have)
- [ ] RGB split on heavy damage
- [ ] CRT screen curvature (subtle)
- [ ] Boot sequence on app launch
- [ ] Typing effect on text reveals

---

## EXTRACTION MECHANIC (Active Mode)

After surviving to a certain point:
```
┌─────────────────────────────────────────────────────────────┐
│                    EXTRACTION AVAILABLE                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                  Current Data: ◈ 147                        │
│                                                             │
│   ┌───────────────────┐      ┌───────────────────┐         │
│   │    EXTRACT NOW    │      │    CONTINUE       │         │
│   │   Keep all Data   │      │   Risk for more   │         │
│   └───────────────────┘      └───────────────────┘         │
│                                                             │
│   Warning: Death = 50% Data loss                           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## SECTOR SELECTION (Active Mode)

```
┌─────────────────────────────────────────────────────────────┐
│                    SELECT SECTOR                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│   │ QUARANTINE  │  │  WORM FARM  │  │   TROJAN    │        │
│   │   █ █ █     │  │   ░ ░ ░     │  │   VAULT     │        │
│   │  Easy  ◈x1  │  │  Med  ◈x2   │  │ Hard  ◈x3   │        │
│   │  🔓 UNLOCKED │  │  🔓 UNLOCKED │  │  🔒 100 DATA │        │
│   └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                             │
│                    ┌─────────────┐                          │
│                    │ GLITCH ZONE │                          │
│                    │   ? ? ? ?   │                          │
│                    │ Chaos ◈x5   │                          │
│                    │ 🔒 500 DATA  │                          │
│                    └─────────────┘                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## AUDIT PLAN

1. **Check DesignSystem.swift** - Are all colors correct?
2. **Check typography usage** - Is everything monospaced?
3. **Check TDGameScene** - Circuit traces, enemy rendering, core
4. **Check TDGameContainerView** - HUD layout, button styling
5. **Check GameContainerView** - Active mode HUD, scan lines
6. **Check all modal/overlay views** - Consistent styling
7. **Add missing visual effects**
8. **Implement extraction mechanic**
9. **Implement sector selection**
