#!/bin/sh
# Build the landing page into ./pages (versions.json + assets + index.html), next to the packages.
# Run from the repo root after pages-prepare.sh.
set -eu
root=$PWD

python3 scripts/ci/versions.py pages
rm -rf pages/assets
cd site
npm ci
VERSIONS=$(ls "$root/pages" | grep -E '^[0-9]' | sort -rV | paste -sd,)
export VERSIONS VERSIONS_JSON="$root/pages/versions.json" SITE_OUT="$root/pages"
npm run build
