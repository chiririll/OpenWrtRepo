#!/bin/sh
# Check out gh-pages into ./pages (or start it) and replace only the versions built in this run.
# Expects build artifacts in ./parts/<artifact>/ (each: public.pem and <version>/...).
# Env: PAGES_URL (push URL incl. credentials)
set -eu
: "${PAGES_URL:?}"

if ! git clone -q --depth 1 -b gh-pages "$PAGES_URL" pages 2>/dev/null; then
  git init -q -b gh-pages pages
  git -C pages remote add origin "$PAGES_URL"
fi

name=$(python3 scripts/ci/repo.py get repo_name)
mkdir -p pages/keys

# Drop the versions rebuilt in this run; other versions stay untouched.
for part in parts/*/; do
  cp "${part}public.pem" "pages/keys/$name.pem"
  for v in "$part"[0-9]*/; do
    rm -rf "pages/$(basename "$v")"
  done
done

# An arch directory is built identically by every target sharing it, so the first one wins.
for part in parts/*/; do
  for dir in "$part"*/packages/* "$part"*/targets/*/*/packages; do
    [ -d "$dir" ] || continue
    rel=${dir#"$part"}
    [ -e "pages/$rel" ] && continue
    mkdir -p "$(dirname "pages/$rel")"
    cp -r "$dir" "pages/$rel"
  done
done
