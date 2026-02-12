# Node Count Audit — Where Do ~4,000 Nodes Come From?

**Snapshot**: 17 towers, 32 enemies, 8 active lanes, 8 sectors + CPU

---

## Complete Node Budget Breakdown

### 1. CPU Core — 39 nodes

| Component | Count | Notes |
|-----------|-------|-------|
| Container | 1 | SKNode parent |
| cpuBody (rect) | 1 | glowWidth=2.0 |
| innerChip (rect) | 1 | |
| CPU label | 1 | SKLabelNode |
| Efficiency label | 1 | SKLabelNode |
| Heatsink fins | 8 | Individual SKShapeNode rects |
| Pin connectors | 24 | 4 sides × 6 pins each |
| Glow ring | 1 | glowWidth=3.0 |
| Inner glow ring | 1 | glowWidth=1.5 |
| **Total** | **39** | |

**Recommendation**: Batch 8 fins into 1 compound path, batch 24 pins into 1 compound path → **39 → 7 nodes** (-32). Zero visual change.

---

### 2. Sector Decorations — ~580-750 nodes (8 sectors)

Each non-CPU sector gets 3 layers of decoration:

#### Foundation Layer (per sector, from DistrictFoundation.swift):

| Component | Nodes | Notes |
|-----------|-------|-------|
| Street grid (arteries) | 1 | Batched compound path |
| Street grid (side streets) | 1 | Batched compound path |
| Via roundabouts (pads) | 1 | Batched compound path |
| Via roundabouts (holes) | 1 | Batched compound path |
| Silkscreen labels | 8 | Individual SKLabelNode per designator |
| Silkscreen outlines | 1 | Batched compound path |
| Legacy vias (pads) | 1 | Batched compound path |
| Legacy vias (holes) | 1 | Batched compound path |
| Sector traces | 1 | Batched compound path |
| Sector name label | 1 | SKLabelNode |
| Sector container | 1 | SKNode |
| **Subtotal** | **~18** | |

Foundation × 8 sectors = **~144 nodes**

#### IC Component Layer (varies by sector theme):

| Sector Theme | addChild Calls | Nodes | Key Components |
|-------------|----------------|-------|----------------|
| **GPU** (addHeatSinkPattern) | 8-14 | ~18 | 4 batched paths + ~10 heat sinks (1 per sink) + 2 die+label pairs |
| **Memory** (addMemoryChips) | ~10-14 | ~22 | 6 batched paths + 6 DIMM labels + 8 DDR5 labels |
| **Storage** (addStorageChips) | ~10 | ~16 | 5 batched paths + 3 IC labels + M.2 connector |
| **I/O** (addIOConnectors) | ~12 | ~22 | 5 batched paths + 8 audio jacks + 4 IC labels |
| **Network** (addNetworkJack) | ~10 | ~18 | 6 batched paths + 4 PHY labels + LED groups |
| **Processing** (addCacheBlocks) | ~10 | ~18 | 5 batched paths + 4 grid labels + 6 ALU labels |
| **PSU** (PSUComponents.swift) | 29 | ~55-70 | 12 electrolytic caps (multi-node), 3 transformers, coils, connectors |

IC Component total across 8 sectors ≈ **~190-250 nodes**

**Note**: GPU, Memory, Storage, I/O, Network, and Processing sectors are heavily batched (compound paths). PSU is the worst offender with 29 individual addChild calls.

#### Total Sector Decorations: **~330-400 nodes**

**Recommendations**:
- **PSU sector** (-40 nodes): Batch electrolytic capacitor components into compound paths. Currently each cap has body+band+cap+leads = 4 nodes × 12 caps. Batch all bodies into 1 path, all bands into 1 path → ~55 nodes → ~15 nodes.
- **Silkscreen labels** (-56 nodes): 8 labels × 8 sectors = 64 SKLabelNodes. Replace with a single pre-rendered SKTexture per sector or batch into sector-level sprite. These are tiny "C1", "R12" text at 10pt — barely visible. **Removing them entirely has zero visual impact and saves 56 nodes**.
- **Sector name labels** (-8 nodes): Already handled by MegaBoard UI. Could remove from background layer entirely.
- **Heat sinks** (-~8 nodes per GPU sector): Each of ~10 heat sinks gets its own batched-fins node. Batch ALL heat sink fins across the sector into a single compound path → -9 nodes.

**Priority**: Remove silkscreen labels (zero visual loss, -56 nodes) and batch PSU components (-40 nodes).

---

### 3. Background Base — ~12 nodes

| Component | Count | Notes |
|-----------|-------|-------|
| Substrate sprite | 1 | SKSpriteNode |
| Ground plane hatch | 1 | Single compound path |
| PCB grid | 1 | Single compound path |
| Silkscreen labels | 5 | REV, board name, PWR, GND, copyright |
| CPU core from drawCPUCore() | 4 | outerGlow, cpuBody, cpuDie, label |
| **Total** | **~12** | Already well optimized |

**Note**: `drawCPUCore()` in Background.swift creates a simplified background CPU visual (4 nodes). The main CPU is `setupCore()` in TDGameScene.swift (39 nodes). These may overlap — verify if both are active. If so, remove the background one (-4 nodes).

---

### 4. Path System — ~200-250 nodes (8 lanes)

Per lane:

| Component | Nodes | Notes |
|-----------|-------|-------|
| Border path | 1 | Batched |
| Path fill | 1 | Batched |
| Highlight | 1 | Batched |
| Flow overlay | 1 | Animated dashed path |
| LEDs | ~16 | Individual nodes (needed for per-LED animation) |
| Spawn point container | 1 | Container with 3-6 children |
| Spawn point children | ~4 | Ring, label, arrows |
| Batched dots | 1 | Compound path |
| Batched chevrons | 1 | Compound path |
| **Per lane** | **~27** | |

8 lanes × ~27 = **~216 nodes**

Main contributor: **LEDs (~128 total)**. Each LED is an individual SKShapeNode because they animate independently (proximity glow, idle pulse, color changes).

**Recommendations**:
- **LEDs — no easy reduction** without losing per-LED animation. Current count is acceptable at ~128 nodes.
- **Spawn points** (-24 nodes): Batch spawn point children (ring + arrows) into single compound path per spawn. Keep label separate. ~5 nodes × 8 → ~2 nodes × 8 = save ~24 nodes.

---

### 5. Tower Slots / Grid Dots — ~80-120 nodes

| Component | Count | Notes |
|-----------|-------|-------|
| Grid dots (compound paths) | ~40 | 1 per slot (already optimized from 9→1 per slot) |
| Slot nodes (hit areas) | ~40 | 1 container + 1 invisible circle each = ~80 |
| **Total** | **~120** | |

**Recommendation**: Slot hit area nodes are invisible — used only for hit detection. Consider replacing the ~40 `createSlotNode` calls with a dictionary-based position lookup (no nodes at all) → **-80 nodes**. Hit testing can use `towerSlots.first(where:)` by distance.

---

### 6. Towers — ~220-300 nodes (17 towers)

Per tower (from TowerVisualFactory):

| Component | Nodes | Notes |
|-----------|-------|-------|
| Container | 1 | |
| Core glow | 1 | SKShapeNode (glowWidth 0-2.5) |
| Rarity ring | 1 | |
| Platform | 2-6 | Archetype-specific (octagon, square, crystal) |
| Body | 2-4 | Archetype-specific |
| Barrel | 1 | SKSpriteNode |
| Muzzle flash (lazy) | 0-2 | Created on first shot |
| Detail elements | 2-8 | Archetype-specific decorations |
| Level indicator | 2-4 | Dots or label |
| Rarity accent (lazy) | 0-1 | Epic/Legendary only |
| **Per tower** | **~12-18** | Average ~15 |

17 towers × ~15 = **~255 nodes**

**Recommendations**:
- **Snapshot to texture** (-~10 per tower): Use `SKView.texture(from:)` to pre-render the static parts (platform, body, details) into a single SKSpriteNode. Only barrel, glow, and level indicator remain dynamic. This would cut ~15 nodes to ~5 per tower. With 17 towers: **~255 → ~85** (-170 nodes). Requires re-render on level-up.
- **Batch platform details**: Platform sub-nodes (bolts, traces, capacitors) → compound path per platform type.

---

### 7. Enemies — ~80-130 nodes (32 enemies)

Per basic enemy:

| Component | Nodes | Notes |
|-----------|-------|-------|
| Container | 1 | |
| Body shape | 1 | Circle/square/triangle/hexagon |
| Health bar bg (if damaged) | 0-1 | Lazy |
| Health bar fill (if damaged) | 0-1 | Lazy |
| Slow overlay (if slowed) | 0-1 | Hidden by default |
| Frost crystals (if slowed) | 0-5 | Container + 4 diamonds |
| **Per enemy** | **2-4** | Average ~3 |

32 enemies × ~3 = **~96 nodes**

**Note**: Enemy visuals are already minimal. The enemy/boss visual overhaul plan proposes adding 3-5 nodes per enemy type for visual quality — still well within budget.

---

### 8. Projectiles — ~40-80 nodes

Per projectile:

| Component | Nodes | Notes |
|-----------|-------|-------|
| Container | 1 | |
| Projectile shape | 1 | Circle or special shape |
| Trail (if applicable) | 0-1 | Dynamic path |
| **Per projectile** | **2-3** | |

~20 active projectiles × ~3 = **~60 nodes**

---

### 9. Sector Ambient Effects — ~40-70 nodes (static + transient)

| Sector | Static Nodes | Transient Nodes | Notes |
|--------|-------------|-----------------|-------|
| PSU | 0 | 0 | Intentionally minimal |
| GPU | 0 | ~5-15 | Heat shimmer particles (capped) |
| RAM | 12 | ~2-5 | 12 static LEDs + data pulses |
| Storage | 1 | 0 | 1 activity LED |
| Network | 4 | ~2-5 | 4 packet LEDs + signal rings |
| I/O | 3 | 0 | 3 USB LEDs |
| Cache | 0 | ~2-5 | Speed line particles |
| **Total** | **~20** | **~15-30** | |

**Note**: Already well optimized. Particle cap (200) prevents runaway. Actual transient count is low.

---

### 10. MegaBoard Visuals — ~20-60 nodes

| Component | Count | Notes |
|-----------|-------|-------|
| Ghost sectors | ~8-15 | 3-5 locked sectors × 2-3 nodes each |
| Encryption gates | ~10-20 | Gate nodes with icons and labels |
| Data bus connections | ~5-10 | Line nodes for bus connections |
| **Total** | **~25-45** | |

---

### 11. Debug Overlay — ~15-20 nodes (when enabled)

| Component | Count |
|-----------|-------|
| Background | 1 |
| FPS label | 1 |
| Node count label | 1 |
| Other stat labels | ~12-15 |

**Note**: Only present when debug overlay is enabled.

---

### 12. Layer Containers & Camera — ~12 nodes

| Component | Count |
|-----------|-------|
| backgroundLayer | 1 |
| gridDotsLayer | 1 |
| pathLayer | 1 |
| blockerLayer | 1 |
| towerSlotLayer | 1 |
| towerLayer | 1 |
| enemyLayer | 1 |
| projectileLayer | 1 |
| particleLayer | 1 |
| uiLayer | 1 |
| cameraNode | 1 |
| scene root | 1 |
| **Total** | **~12** | |

---

### 13. Scrolling Combat Text — ~10-50 transient nodes

Damage numbers, heal numbers floating up and fading. Self-cleaning (remove after animation).

---

## Grand Total

| Category | Nodes | % of Total |
|----------|-------|------------|
| **Sector Decorations** (8 sectors) | ~330-400 | 22% |
| **Towers** (17) | ~255 | 17% |
| **Path System** (8 lanes) | ~216 | 14% |
| **Tower Slots / Grid** | ~120 | 8% |
| **Enemies** (32) | ~96 | 6% |
| **Sector Ambient** (static + transient) | ~50 | 3% |
| **Projectiles** | ~60 | 4% |
| **CPU Core** | 39 | 3% |
| **MegaBoard Visuals** | ~35 | 2% |
| **Background Base** | ~12 | 1% |
| **Debug Overlay** | ~17 | 1% |
| **Layer Containers** | ~12 | 1% |
| **Combat Text** (transient) | ~30 | 2% |
| **Other (UI, blockers, etc.)** | ~20 | 1% |
| | | |
| **Estimated Total** | **~1,300-1,400** | |

### Gap Analysis: 1,400 vs. 4,000

The debug overlay reports ~4,000 nodes but the audit accounts for ~1,400. The gap comes from:

1. **Motherboard districts** (drawMotherboardDistricts): Creates outline + label + locked text per district. This old system may be running alongside the MegaBoard system, doubling sector visuals. If active: ~30+ nodes.
2. **SpriteKit internal nodes**: SKShapeNode internally creates child nodes for complex paths. A compound path with 50 ellipses may count as 1 API node but SpriteKit's renderer may report more.
3. **Tower sub-tree depth**: Each tower's platform, body, and details may have sub-children not visible in the top-level addChild count. A tower archetype with "circuit traces" in its platform adds 3-4 sub-nodes.
4. **drawCPUCore() duplication**: Both `drawCPUCore()` (Background.swift) and `setupCore()` (TDGameScene.swift) may both be active = ~43 duplicate CPU nodes.
5. **Unaccounted animation nodes**: SKAction sequences, muzzle flashes, and temporary effects.
6. **MegaBoardRenderer internals**: 22 addChild calls — ghost sectors likely have more internal structure per sector.

---

## Recommended Node Reductions

### Tier 1: Free — Zero Visual Impact

| Change | Savings | Effort |
|--------|---------|--------|
| Remove silkscreen labels (8×8 sectors) | -56 | 5 min |
| Batch CPU heatsink fins (8→1) | -7 | 10 min |
| Batch CPU pins (24→1) | -23 | 10 min |
| Remove duplicate CPU core (if drawCPUCore + setupCore both active) | -4 to -39 | 5 min |
| Remove invisible slot hit-area nodes (use position lookup) | -80 | 30 min |
| Remove sector name labels (redundant with MegaBoard UI) | -8 | 5 min |
| **Subtotal** | **-178 to -213** | **~1 hour** |

### Tier 2: Easy — Minimal Visual Change

| Change | Savings | Effort |
|--------|---------|--------|
| Batch PSU electrolytic capacitors into compound paths | -40 | 30 min |
| Batch spawn point children per lane | -24 | 20 min |
| Batch heat sink fins across entire GPU sector (not per sink) | -9 | 15 min |
| Reduce DIMM/DDR5/IC individual labels → fewer labels or batch | -30 | 20 min |
| **Subtotal** | **-103** | **~1.5 hours** |

### Tier 3: High Impact — Requires Careful Implementation

| Change | Savings | Effort | Visual Impact |
|--------|---------|--------|---------------|
| Snapshot tower static parts to texture | -170 | 2 hours | Must re-render on level-up; may lose sub-pixel quality |
| Sector LOD: Only draw IC details when zoomed into sector | -200+ | 2 hours | Sectors look empty when zoomed out (but you can't see detail anyway) |
| Reduce sector decoration density (fewer random components) | -50-100 | 30 min | Slightly sparser sectors |
| **Subtotal** | **-420 to -470** | **~4.5 hours** |

---

## Priority Ranking (Performance + Visual Clarity)

1. **Remove silkscreen labels** — 56 nodes of barely-visible 10pt text. Zero loss. ★★
2. **Batch CPU fins + pins** — 30 nodes → 2 nodes. Zero loss. ★★
3. **Remove duplicate CPU** — Up to 39 nodes if both systems are active. ★★
4. **Remove invisible slot nodes** — 80 invisible nodes. Use math for hit testing. ★★
5. **Batch PSU components** — PSU is the node-heaviest sector. ★
6. **Sector LOD** — Load IC details only when camera is close. Biggest single win. ★★★
7. **Tower texture snapshots** — Biggest per-entity win, but complex to implement. ★★★

**Quick wins (Tier 1 + 2): ~280-315 nodes removed in ~2.5 hours**
**Full optimization (all tiers): ~700-800 nodes removed**

---

## What NOT to Remove

- **Path LEDs** — These are the "life" of the lanes. Worth every node.
- **Tower detail nodes** — Towers are the visual centerpiece. Don't simplify.
- **Ambient effects** — Already minimal, make sectors feel alive.
- **Via roundabouts** — Give the motherboard PCB feel. 2 nodes per sector (batched).
- **Street grid** — The "city streets" aesthetic. 2 nodes per sector (batched).
