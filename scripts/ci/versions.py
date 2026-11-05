#!/usr/bin/env python3
"""Write versions.json for the landing page from the *.apk files of a pages checkout.

Usage: versions.py <pages_dir>

Layout read:  <ver>/packages/<arch>/*.apk
              <ver>/targets/<target>/<subtarget>/packages/*.apk
Output:       {"<ver>": {"<package>": {"arch": {<arch>: <version>}, "target": {"<target>/<subtarget>": <version>}}}}
"""
import json
import pathlib
import re
import sys

import yaml

root = pathlib.Path(__file__).resolve().parents[2]
names = [p["name"] for p in yaml.safe_load((root / "config.yml").read_text())["packages"]]


def split(filename):
    stem = filename[: -len(".apk")]
    for name in names:
        rest = stem[len(name) + 1 :]
        if stem.startswith(name + "-") and rest[:1].isdigit():
            return name, rest
    return None


def scan(dirpath, out, kind, key):
    for f in sorted(dirpath.glob("*.apk")):
        hit = split(f.name)
        if hit:
            out.setdefault(hit[0], {}).setdefault(kind, {})[key] = hit[1]


def main(pages):
    pages = pathlib.Path(pages)
    result = {}
    for vdir in sorted(pages.iterdir()):
        if not (vdir.is_dir() and re.match(r"\d", vdir.name)):
            continue
        out = {}
        for d in (vdir / "packages").glob("*/"):
            scan(d, out, "arch", d.name)
        for d in (vdir / "targets").glob("*/*/packages"):
            scan(d, out, "target", f"{d.parent.parent.name}/{d.parent.name}")
        result[vdir.name] = out
    (pages / "versions.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")


if len(sys.argv) != 2:
    sys.exit(__doc__)
main(sys.argv[1])
