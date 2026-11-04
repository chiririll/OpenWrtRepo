#!/usr/bin/env python3
"""Print the CI build matrix (unique target/subtarget/arch combos) as JSON."""
import json
import pathlib

import yaml

root = pathlib.Path(__file__).resolve().parent.parent
cfg = yaml.safe_load((root / "config.yml").read_text())

seen = {}
for f in sorted((root / "devices").glob("*.yml")):
    d = yaml.safe_load(f.read_text())
    key = (d["target"], d["subtarget"], d["arch"])
    seen[key] = {
        "target": d["target"],
        "subtarget": d["subtarget"],
        "arch": d["arch"],
        "version": cfg["openwrt_version"],
    }

print(json.dumps({"include": list(seen.values())}))
