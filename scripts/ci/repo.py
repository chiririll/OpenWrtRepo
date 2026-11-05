#!/usr/bin/env python3
"""Read config.yml / feeds.yml for the CI scripts.

  repo.py get <key>      value from config.yml
  repo.py feeds-conf     `src-git` lines for enabled feeds (feeds.conf format)
  repo.py setup-scripts  setup scripts of enabled feeds, one per line
  repo.py kconfig        CONFIG_PACKAGE_<name>=m lines for packages of enabled feeds
  repo.py packages [scope]  names of the packages of enabled feeds, space-separated; scope: target | arch
"""
import pathlib
import sys

import yaml

root = pathlib.Path(__file__).resolve().parents[2]
cfg = yaml.safe_load((root / "config.yml").read_text())
feeds = yaml.safe_load((root / "feeds.yml").read_text())["feeds"]

enabled = [f for f in feeds if f.get("enabled", True)]
enabled_names = {f["name"] for f in enabled}


def package_enabled(p):
    return "feed" not in p or p["feed"] in enabled_names


def main(argv):
    cmd = argv[0] if argv else ""
    if cmd == "get":
        print(cfg[argv[1]])
    elif cmd == "feeds-conf":
        for f in enabled:
            print(f"src-git {f['name']} {f['git']}")
    elif cmd == "setup-scripts":
        for f in enabled:
            if f.get("setup"):
                print(f["setup"])
    elif cmd == "kconfig":
        for p in cfg["packages"]:
            if package_enabled(p):
                print(f"CONFIG_PACKAGE_{p['name']}=m")
    elif cmd == "packages":
        scope = argv[1] if len(argv) > 1 else None
        print(" ".join(p["name"] for p in cfg["packages"]
                       if package_enabled(p) and scope in (None, p.get("scope"))))
    else:
        sys.exit(__doc__)


main(sys.argv[1:])
