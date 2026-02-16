# Bug Fix Plan

## Bundle 1: Tower Display & Interaction (drag bar + board)
> All related to tower icons in the bottom drag-and-drop bar and board view.

- [x] **1a.** Drag bar tower icons are black/white — should reflect rarity color — ✅ Changed icon foregroundColor from .white/.gray to rarityColor in TowerDeckCards.swift
- [x] **1b.** Drag bar tower icons should show hash cost in the standard blue — ✅ Removed conditional red color; hash cost now always uses DesignColors.primary (cyan) in TowerDeckCards.swift, relying on card opacity for affordability
- [ ] **1c.** Tower DPS display is inconsistent — sometimes shows, sometimes doesn't
- [ ] **1d.** Towers in settings sheet don't show DPS either; clarify where DPS is shown
- [ ] **1e.** Tapping a tower icon in the drag bar should open the same info/upgrade popup as tapping the placed tower on the board

## Bundle 2: HUD Layout & State
> Top HUD issues — layout and live updates.

- [ ] **2a.** PSU upgrade: HUD number doesn't update immediately after upgrading
- [ ] **2b.** Top HUD sometimes line-breaks — redesign as a consistent 2-line layout

## Bundle 3: Readability
> Global text readability.

- [x] **3a.** Grey font color in popups (and generally) is too hard to read — increase contrast — ✅ Brightened textSecondary (#7d8590→#9eaab6) and muted (#3a3a4a→#6e7681) in DesignSystem.swift; replaced ~25 raw Color.gray usages with DesignColors.textSecondary across 8 UI files

## Bundle 4: Boss Victory Screen
> Reward collection UX.

- [ ] **4a.** With 3 rewards, the screen closes on collecting the 3rd before the player sees it — add a brief delay or require explicit dismiss after all rewards are revealed

## Bundle 5: Tutorial — Blueprint Discovery
> New guided hint (non-blocking).

- [ ] **5a.** When a new blueprint is found, pulse the system menu tab until tapped
- [ ] **5b.** Once in system menu, pulse the new blueprint until tapped
- [ ] **5c.** No popup — pulse animation only

## Bundle 6: Sector Upgrades (investigation)
> May be a bug or a missing feature.

- [ ] **6a.** Verify whether CPU and other sectors are actually upgradeable; if not, clarify in UI or implement

---

## Suggested Order

1. **Bundle 3** (readability) — quick global CSS/color fix, improves everything else you'll be testing
2. **Bundle 1** (tower display) — largest bundle, all in the same area, do in one pass
3. **Bundle 2** (HUD) — small, self-contained
4. **Bundle 4** (boss victory) — isolated fix
5. **Bundle 5** (tutorial pulse) — new feature, lowest risk
6. **Bundle 6** (sector upgrades) — needs investigation first
