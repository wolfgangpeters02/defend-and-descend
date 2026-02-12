#!/usr/bin/env python3
"""
Balance Sync Test

Compares web simulator default values against BalanceConfig.exportJSON() output.

Usage:
  1. Generate reference JSON from the app:
     - In Xcode debug console: po BalanceConfig.exportJSON()
     - Save output to tools/balance-config-export.json
     OR
     - Run the app and trigger BalanceConfig.printConfig() (prints to console)

  2. Run this script:
     python3 tools/check-balance-sync.py

  3. Review mismatches — any differences mean the web simulator defaults
     have drifted from BalanceConfig values.
"""

import json
import os
import re
import sys

TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
HTML_PATH = os.path.join(TOOLS_DIR, "balance-simulator.html")
JSON_PATH = os.path.join(TOOLS_DIR, "balance-config-export.json")

# Mapping: HTML input ID -> exportJSON key path
# Only includes values that exist in both the web simulator and exportJSON
VALUE_MAP = {
    # Power Grid
    "power-base":            "powerGrid.basePowerBudget",
    "tower-power-common":    "powerGrid.towerPower.common",
    "tower-power-rare":      "powerGrid.towerPower.rare",
    "tower-power-epic":      "powerGrid.towerPower.epic",
    "tower-power-legendary": "powerGrid.towerPower.legendary",

    # Threat Level
    "threat-hp-scale":       "threatLevel.healthScaling",
    "threat-speed-scale":    "threatLevel.speedScaling",
    "threat-dmg-scale":      "threatLevel.damageScaling",

    # Bosses - Cyberboss
    "cyber-hp":              "bosses.cyberboss.baseHealth",

    # Zero-Day
    "zeroday-hp":            "zeroDay.baseHealth",
    "zeroday-speed":         "zeroDay.speed",
    "zeroday-drain":         "zeroDay.efficiencyDrainRate",
    "zeroday-min-waves":     "zeroDay.minWavesBeforeSpawn",
    "zeroday-hash":          "zeroDay.defeatHashBonus",
    "zeroday-restore":       "zeroDay.defeatEfficiencyRestore",

    # Hash Economy
    "hash-base":             "hashEconomy.baseHashPerSecond",
    "hash-cpu-mult":         "hashEconomy.cpuLevelScaling",
    "offline-max-hours":     "hashEconomy.maxOfflineHours",

    # Protocol Scaling
    "proto-range-mult":      "protocolScaling.rangePerLevel",
    "proto-fire-mult":       "protocolScaling.fireRatePerLevel",

    # Components
    "comp-max-level":        "components.maxLevel",
    "comp-cost-psu":         "components.baseCosts.psu",
    "comp-cost-ram":         "components.baseCosts.ram",
    "comp-cost-gpu":         "components.baseCosts.gpu",
    "comp-cost-cache":       "components.baseCosts.cache",
    "comp-cost-storage":     "components.baseCosts.storage",
    "comp-cost-expansion":   "components.baseCosts.expansion",
    "comp-cost-network":     "components.baseCosts.network",
    "comp-cost-io":          "components.baseCosts.io",
    "comp-cost-cpu":         "components.baseCosts.cpu",

    # Efficiency
    "eff-leak-interval":     "efficiency.leakDecayInterval",
    "eff-warning":           "efficiency.warningThreshold",
}

# Special mappings where the web simulator stores values differently
TRANSFORMS = {
    "offline-rate": {
        "path": "hashEconomy.offlineEarningsRate",
        "transform": lambda v: v / 100,  # Web stores 20, config stores 0.2
    },
    "cyber-phase2": {
        "path": "bosses.cyberboss.phase2Threshold",
        "transform": lambda v: v / 100,
    },
    "cyber-phase3": {
        "path": "bosses.cyberboss.phase3Threshold",
        "transform": lambda v: v / 100,
    },
    "cyber-phase4": {
        "path": "bosses.cyberboss.phase4Threshold",
        "transform": lambda v: v / 100,
    },
}


def extract_html_defaults(html: str) -> dict[str, float]:
    """Extract default values from HTML input elements."""
    defaults = {}
    for match in re.finditer(r"<input\s+[^>]*>", html, re.IGNORECASE):
        tag = match.group(0)
        id_match = re.search(r'id="([^"]+)"', tag)
        value_match = re.search(r'value="([^"]+)"', tag)
        if id_match and value_match:
            try:
                defaults[id_match.group(1)] = float(value_match.group(1))
            except ValueError:
                pass  # Skip non-numeric values (e.g., select options)
    return defaults


def get_nested(obj: dict, key_path: str):
    """Get a value from a nested dict using dot-separated path."""
    keys = key_path.split(".")
    current = obj
    for key in keys:
        if not isinstance(current, (dict, list)):
            return None
        if isinstance(current, list):
            try:
                current = current[int(key)]
            except (ValueError, IndexError):
                return None
        else:
            current = current.get(key)
            if current is None:
                return None
    return current


def values_match(a: float, b: float) -> bool:
    """Compare two floats with 0.1% tolerance."""
    if b == 0:
        return a == 0
    return abs(a - b) <= abs(b) * 0.001


def main():
    if not os.path.exists(HTML_PATH):
        print(f"Error: HTML file not found at {HTML_PATH}", file=sys.stderr)
        sys.exit(1)

    if not os.path.exists(JSON_PATH):
        print(f"Error: Reference JSON not found at {JSON_PATH}", file=sys.stderr)
        print("", file=sys.stderr)
        print("Generate it by running in Xcode debug console:", file=sys.stderr)
        print("  po BalanceConfig.exportJSON()", file=sys.stderr)
        print("", file=sys.stderr)
        print(f"Then save the output to: {JSON_PATH}", file=sys.stderr)
        sys.exit(1)

    with open(HTML_PATH) as f:
        html = f.read()
    with open(JSON_PATH) as f:
        config = json.load(f)

    web_defaults = extract_html_defaults(html)

    mismatches = 0
    matches = 0
    missing = 0

    print("Balance Sync Check: Web Simulator vs BalanceConfig.exportJSON()")
    print("=" * 70)
    print()

    # Check direct mappings
    for html_id, config_path in sorted(VALUE_MAP.items()):
        web_val = web_defaults.get(html_id)
        config_val = get_nested(config, config_path)

        if web_val is None:
            print(f"  SKIP  {html_id} -- not found in HTML")
            missing += 1
            continue
        if config_val is None:
            print(f"  SKIP  {html_id} -> {config_path} -- not found in config JSON")
            missing += 1
            continue

        config_val = float(config_val)
        if values_match(web_val, config_val):
            matches += 1
        else:
            print(f"  MISMATCH  {html_id}")
            print(f"            Web default: {web_val}")
            print(f"            Config value: {config_val}  ({config_path})")
            print()
            mismatches += 1

    # Check transformed mappings
    for html_id, spec in sorted(TRANSFORMS.items()):
        web_val = web_defaults.get(html_id)
        config_val = get_nested(config, spec["path"])

        if web_val is None or config_val is None:
            missing += 1
            continue

        transformed = spec["transform"](web_val)
        config_val = float(config_val)
        if values_match(transformed, config_val):
            matches += 1
        else:
            print(f"  MISMATCH  {html_id} (transformed)")
            print(f"            Web default: {web_val} -> {transformed}")
            print(f"            Config value: {config_val}  ({spec['path']})")
            print()
            mismatches += 1

    # Summary
    print("=" * 70)
    print(f"Results: {matches} OK, {mismatches} MISMATCH, {missing} SKIPPED")
    print()

    if mismatches > 0:
        print("FAIL: Web simulator defaults are out of sync with BalanceConfig.")
        print("Update the HTML input default values to match BalanceConfig.")
        sys.exit(1)
    else:
        print("PASS: All checked values are in sync.")
        sys.exit(0)


if __name__ == "__main__":
    main()
