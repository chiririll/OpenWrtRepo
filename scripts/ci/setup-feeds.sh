#!/bin/sh
# Configure SDK feeds from the repo (local packages/ + enabled feeds in feeds.yml),
# install them, then run each enabled feed's setup script.
set -eu
repo=$PWD

cd sdk
cp feeds.conf.default feeds.conf

# Local feed only if packages/ holds something besides .gitkeep.
if [ -n "$(ls -A "$repo/packages" | grep -v '^\.gitkeep$')" ]; then
  echo "src-link local $repo/packages" >> feeds.conf
fi
python3 "$repo/scripts/ci/repo.py" feeds-conf >> feeds.conf

./scripts/feeds update -a
./scripts/feeds install -a
cd "$repo"

for setup in $(python3 scripts/ci/repo.py setup-scripts); do
  echo "== feed setup: $setup"
  sh "$setup" sdk
done
