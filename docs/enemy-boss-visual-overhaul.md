# Enemy & Boss Visual Overhaul Plan

**Goal**: Bring enemies and bosses to the same visual quality as towers (8-15 nodes, archetype-specific details, meaningful animations, selective glow).

**Current state**: Basic enemies are 2 nodes (shape + container), bosses range from 2 nodes (Cyberboss body) to 9 nodes (Void Harbinger). Towers have 10-15 nodes with archetype-specific platforms, bodies, barrels, details, and rarity-based glow.

**Performance budget**: Adding 3-5 nodes per enemy type and 5-10 per boss is safe. With 30-50 enemies on screen, that's +90-250 nodes — well within budget given we freed ~4,000 nodes in optimization passes.

---

## Phase 1: Quick Wins (No New Nodes) — DONE

Zero performance cost. Pure visual tuning via color, animation, and glow on existing nodes.

> **Status**: Implemented in both `EntityRenderer.swift` (idle/survival mode) and `TDGameScene+EntityVisuals.swift` (TD mode). Includes shape differentiation, type-specific idle animations, hit flash, critical state jitter, and improved death animation.

### 1A. Enemy Shape Differentiation

Currently all enemy types use generic shapes (circle/square/triangle/hexagon) with flat solid fills. Make each type visually distinct:

| Type | Current | Proposed |
|------|---------|----------|
| **Basic** | Red circle | Red circle with inner ring (darker center), subtle pulse |
| **Fast** | Orange triangle | Orange triangle with motion-blur stroke (elongated alpha trail) |
| **Tank** | Purple square | Purple square with thick double-stroke border (armor look) |
| **Elite** | Larger version | Existing shape + brighter stroke + 0.5 glowWidth |
| **Boss** | White hexagon | White hexagon + color-cycle stroke + 2.0 glowWidth (already done) |

**Files**: `EntityRenderer.swift` lines 44-117
**Effort**: ~30 min

### 1B. Enemy Idle Animations

Currently only bosses pulse. Add subtle per-type animations:

- **Basic**: Slow rotation (full turn every 4s) — viruses spin
- **Fast**: Faster rotation (2s) + slight wobble — unstable speed
- **Tank**: No rotation (tanks don't spin), but slow scale breathing (1.0↔1.03, 2s)
- **Elite**: Existing shape + alpha flicker (0.9↔1.0, 0.3s) — glitchy presence

**Files**: `EntityRenderer.swift` (add to `createEnemyNode`)
**Effort**: ~20 min

### 1C. Damage State Visuals

Currently enemies only get frost crystals (when slowed) and a damage overlay (when <30% HP). Enhance:

- **Hit flash**: Brief white tint on damage (0.05s duration) — already exists for some via combat text, make body react
- **Critical state (<20% HP)**: Body stroke becomes red, slight jitter animation
- **Death**: Currently just `removeFromParent()`. Add quick scale-to-zero + fade (0.15s) — cheap, dramatic

**Files**: `TDGameScene+EntityVisuals.swift` (updateEnemyVisuals, enemy death handling)
**Effort**: ~30 min

---

## Phase 2: Inner Detail Layer (+1 node per enemy)

Add a single inner detail shape to each enemy type, giving them "internals" like tower bodies have.

### 2A. Type-Specific Inner Details — SKIP (merged into Phase 1 & 3)

> **Status**: Basic inner details (chevron for fast, cross for tank, concentric hexagon for basic) were already added as part of Phase 1 implementation. Phase 3 will replace these with full archetype compositions, so this phase can be skipped.

| Type | Inner Detail | Description |
|------|-------------|-------------|
| **Basic** | Concentric ring | Smaller circle at 60% radius, darker fill — "virus membrane" |
| **Fast** | Inner chevron | Small > shape pointing forward — "speed core" |
| **Tank** | Inner cross/plus | + shape at 50% size — "armored core" |
| **Elite** | Inner star/burst | 6-point star shape — "enhanced processor" |
| **Boss** | Inner hexagon (exists) | Already has inner hex — add rotation animation |

**Implementation**: In `createEnemyNode()`, after the body shape, add one `SKShapeNode` with `zPosition = 0.1`:

```swift
// Inner detail (virus core)
let innerDetail = SKShapeNode(/* type-specific path */)
innerDetail.fillColor = bodyColor.darker(by: 0.4)
innerDetail.strokeColor = bodyColor.withAlphaComponent(0.5)
innerDetail.lineWidth = 1
innerDetail.zPosition = 0.1
container.addChild(innerDetail)
```

**Files**: `EntityRenderer.swift`
**Cost**: +1 node per enemy (+30-50 nodes total)
**Effort**: ~45 min

### 2B. Health Bar Redesign

Currently enemies have no visible health bar (boss HP is in the UI overlay). Add a minimal health indicator:

- Thin arc above the enemy (not a full bar — too cluttered)
- Only visible when enemy has taken damage
- Color transitions: green → yellow → red
- Created lazily on first damage, removed on full heal

```swift
let healthArc = SKShapeNode()
healthArc.path = arcPath(from: -CGFloat.pi * 0.8, to: CGFloat.pi * 0.8, radius: size + 4)
healthArc.strokeColor = healthColor
healthArc.lineWidth = 2
healthArc.zPosition = 0.2
```

**Files**: `TDGameScene+EntityVisuals.swift` (updateEnemyVisuals)
**Cost**: +1 node per damaged enemy (lazy, 0 when full HP)
**Effort**: ~30 min

---

## Phase 3: Archetype Visual Identity (+3-4 nodes per enemy)

Give each enemy type a unique silhouette and visual language, matching how towers have archetype-specific platforms and details.

### 3A. Basic Virus — "Malware Blob"

**Theme**: Organic, pulsating threat. Simple but alive.

- **Body**: Circle with slight wobble deformation (use `SKAction.customAction` to slightly randomize radius each frame — or use a pre-computed wobble path)
- **Membrane ring**: Outer ring at 120% radius, dashed stroke — "cell wall"
- **Nucleus**: Inner darker circle with rotation
- **Flagella**: 2-3 thin trailing lines (compound path, single node) — "tentacles"

**Node budget**: 4 nodes (body, membrane, nucleus, flagella-compound)

### 3B. Fast Virus — "Packet Runner"

**Theme**: Sleek, angular, aerodynamic. Data packet in transit.

- **Body**: Elongated diamond/chevron shape (not triangle)
- **Speed lines**: 2 trailing dashes behind (compound path, single node)
- **Core dot**: Small bright dot at center
- **Directional arrow**: Tiny embedded arrow pointing forward

**Node budget**: 4 nodes (body, speed-lines, core, arrow)

### 3C. Tank Virus — "Armored Payload"

**Theme**: Heavy, layered, industrial. Ransomware that's hard to crack.

- **Body**: Rounded rectangle (not square) with thick border
- **Armor plates**: 4 small rectangles at corners (compound path, single node) — "bolt heads"
- **Inner core**: Skull-like or lock icon (simple path)
- **Damage cracks**: Show progressively as HP drops (swap path at 75%, 50%, 25%)

**Node budget**: 4 nodes (body, armor-compound, core, crack-overlay)

### 3D. Elite Virus — "Zero-Day Exploit"

**Theme**: Glitchy, unstable, dangerous. Corrupted data visualization.

- **Body**: Hexagon with jagged/glitched edges (slightly irregular vertices)
- **Glitch overlay**: Semi-transparent rectangle that offsets randomly (jitter animation)
- **Data fragments**: 3 orbiting small shapes (compound path, single node)
- **Aura ring**: Outer ring with 0.5 glowWidth — "threat indicator"

**Node budget**: 5 nodes (body, glitch, fragments, aura, inner)

### Implementation Strategy

Create `EntityRenderer+EnemyDetails.swift` extension file to keep `EntityRenderer.swift` clean. Each type gets a dedicated factory method:

```swift
extension EntityRenderer {
    func createBasicVirusDetails(container: SKNode, size: CGFloat, color: SKColor) { ... }
    func createFastVirusDetails(container: SKNode, size: CGFloat, color: SKColor) { ... }
    func createTankVirusDetails(container: SKNode, size: CGFloat, color: SKColor) { ... }
    func createEliteVirusDetails(container: SKNode, size: CGFloat, color: SKColor) { ... }
}
```

**Files**: New `EntityRenderer+EnemyDetails.swift`
**Cost**: +3-5 nodes per enemy (+90-250 total)
**Effort**: ~2-3 hours

---

## Phase 4: Boss Overhaul — Cyberboss (+8-12 nodes)

The Cyberboss currently has only the generic enemy hexagon body (2 nodes). It's the weakest visually. Complete redesign.

### 4A. Cyberboss Body Redesign

**Theme**: Corporate AI gone rogue. Sleek, geometric, chrome-like.

**Visual structure** (matching tower complexity):

1. **Outer threat ring** — Large circle, red pulsing stroke, 2.0 glowWidth
2. **Shield hexagon** — Main body outline, chrome stroke (white/silver), thick border
3. **Inner chassis** — Slightly smaller hexagon, dark fill, circuit-trace pattern stroke
4. **Core processor** — Central square with bright fill, rotation animation
5. **Eye/scanner** — Horizontal line across center that sweeps up/down (scanning animation)
6. **Data ports** — 6 small squares at hexagon vertices (compound path, single node)
7. **Status LEDs** — 3 dots on one side (compound path, single node) — red/yellow/green

**Animations**:
- Core processor: slow rotation (8s full turn)
- Eye scanner: vertical sweep (2s up, 2s down)
- Threat ring: pulse (1.0↔1.05 scale, 1s)
- Status LEDs: sequential blink pattern
- Phase transitions: Brief flash + scale pop

**Node budget**: 8 nodes (ring, shield, chassis, core, eye, ports-compound, LEDs-compound, label)

### 4B. Cyberboss Phase Indicators

Visual changes per boss phase to communicate escalation:

| Phase | Visual Change |
|-------|--------------|
| Phase 1 | Base design, green status LEDs, calm pulse |
| Phase 2 | Yellow LEDs, faster pulse, shield hexagon gains glowWidth 1.0 |
| Phase 3 | Red LEDs, threat ring expands, eye scanner speeds up |
| Phase 4 | All red, glitch jitter on chassis, sparks from data ports |

**Files**: `EntityRenderer.swift` (new `createCyberbossNode` method), `BossRenderingManager.swift` (phase visual updates)
**Effort**: ~2 hours

---

## Phase 5: Boss Overhaul — Void Harbinger Enhancement

The Void Harbinger already has the best enemy visuals (9 nodes, multiple animations, selective glow). Polish and add phase-specific visuals.

### 5A. Phase-Specific Visual Escalation

| Phase | Addition |
|-------|----------|
| Phase 1 | Base design (already good) |
| Phase 2 | Fragment orbit speeds up, aura stroke thickens 3→5, new inner runes (1 compound path node) |
| Phase 3 | Eye color shifts to red, body crack lines appear (1 node), fragment count doubles (reuse path) |
| Phase 4 | Full "unleashed" mode — aura expands 1.3→1.6×, all fragments trail particles, body becomes semi-transparent |

### 5B. Void Minion Upgrade

Currently void minions are plain circles. Make them mini-harbingers:

- **Regular minion**: Teardrop/wisp shape instead of circle, trailing fade
- **Elite minion**: Mini-octagon (matching harbinger), orbiting sparks, magenta glow

**Cost**: +1-2 nodes per minion
**Effort**: ~1.5 hours

---

## Phase 6: Boss Overhaul — Overclocker & Trojan Wyrm

### 6A. Overclocker Redesign

**Theme**: Overheating CPU. Red/orange, industrial, heat distortion.

- **Body**: Octagon (CPU die shape) with heat-sink fin pattern (compound path)
- **Heat gauge**: Arc meter around body showing "temperature" (fills as phases progress)
- **Thermal vents**: 4 small openings that emit particle puffs in combat
- **Core clock**: Central spinning element (represents clock speed)

**Node budget**: 7 nodes

### 6B. Trojan Wyrm Enhancement

**Theme**: Organic data worm. Segmented, undulating, parasitic.

- **Head**: Larger segment with "jaw" detail (V-shaped mouth)
- **Body segments**: Alternating light/dark fills for caterpillar effect
- **Tail**: Tapered final segment with trailing whisps
- **Eye dots**: 2 small red dots on head

**Node budget**: Existing segments + 3 detail nodes

**Effort**: ~2 hours each

---

## Phase 7: Polish & Consistency Pass

### 7A. Unified Color Language

Establish a consistent color system across all enemies:

| Threat Level | Primary Color | Stroke | Glow |
|-------------|--------------|--------|------|
| Basic | `#ff4444` (red) | Darker variant | 0 |
| Fast | `#ff8800` (orange) | Darker variant | 0 |
| Tank | `#8844ff` (purple) | Darker variant | 0 |
| Elite | `#ff00ff` (magenta) | White | 0.5 |
| Boss (Cyber) | `#ffffff` (white) | `#00ffff` (cyan) | 2.0 |
| Boss (Void) | `#8800ff` (void purple) | `#ff00ff` (magenta) | 2.0 |
| Boss (Overclock) | `#ff4400` (heat orange) | `#ffaa00` (amber) | 1.5 |
| Boss (Wyrm) | `#00ff45` (toxic green) | `#88ff00` (lime) | 1.0 |

### 7B. Death Animations by Type

| Type | Death Animation |
|------|----------------|
| Basic | Pop + 4 small fragments scatter |
| Fast | Streak/smear in movement direction + fade |
| Tank | Crack effect (armor plates separate) + slow collapse |
| Elite | Glitch-out (rapid position jitter) + dissolve |
| Boss | Dramatic: expand, flash white, shatter into 12+ fragments, screen shake |

### 7C. Spawn Animations

| Type | Spawn Animation |
|------|----------------|
| Basic | Scale from 0 + fade in (0.2s) |
| Fast | Slide in from off-path + snap to position |
| Tank | Drop in (scale from 1.5 to 1.0) + heavy "thud" feel |
| Elite | Glitch-in (rapid alpha flicker for 0.3s) |
| Boss | Void tear opens, boss emerges over 1s, rift closes |

**Effort**: ~2 hours

---

## Implementation Order

| Step | Phase | What | Nodes Added | Est. Time | Status |
|------|-------|------|-------------|-----------|--------|
| 1 | 1A-1C | Quick wins (animation/color/death) | 0 | 1 hour | **DONE** |
| 2 | 2A | Inner detail layer | +30-50 | 45 min | **SKIP** (merged into 1 & 3) |
| 3 | 2B | Health arc indicator | +0-30 (lazy) | 30 min | **DONE** |
| 4 | 3A-3D | Full enemy archetype visuals | +90-250 | 2-3 hours | **DONE** |
| 5 | 4A-4B | Cyberboss redesign | +8 | 2 hours | **DONE** |
| 6 | 5A-5B | Void Harbinger polish + minions | +5-10 | 1.5 hours | **DONE** |
| 7 | 6A-6B | Overclocker + Trojan Wyrm | +10-15 | 2 hours | **DONE** |
| 8 | 7A-7C | Polish pass (colors, death, spawn) | 0 | 2 hours | **DONE** |

**Total new nodes at full overhaul**: ~150-350 (well within performance budget)
**Total estimated effort**: ~12-15 hours

---

## Performance Safety Rules

1. **Compound paths**: Any group of small decorative shapes (fragments, plates, dots) → single `CGMutablePath` node
2. **Zoom-gated glow**: Enemy glowWidth only enabled when `cameraScale < 0.6`
3. **No per-enemy custom actions**: Use shared update loop for animations (like LED system)
4. **Lazy creation**: Health arcs, damage cracks, frost crystals — create on first need, not at spawn
5. **Death cleanup**: All enemy child nodes removed on death (no orphan nodes)
6. **Cap transient particles**: Death fragment particles capped at 8 per death, auto-remove after 0.5s
