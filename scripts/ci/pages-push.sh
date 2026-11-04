#!/bin/sh
# Commit ./pages and push gh-pages (no-op if nothing changed).
set -eu
cd pages
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add -A
if git diff --cached --quiet; then
  echo "nothing to publish"
  exit 0
fi
git commit -q -m "Publish ${GITHUB_SHA:-local}"
git push origin gh-pages
