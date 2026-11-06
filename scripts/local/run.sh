#!/bin/bash
# Run the whole packages workflow (matrix -> build -> collect/sign -> publish prep -> landing
# page) in Docker and commit the result to the LOCAL gh-pages branch. Never pushes.
#
#   APK_SIGNING_KEY_FILE=~/razzmatazz.priv.pem scripts/local/run.sh [--fresh] [--branch NAME]
#
#   --fresh        start gh-pages from scratch: orphan commit, no history, no old versions
#   --branch NAME  branch to commit to (default gh-pages)
#
# Works with a remote Docker context: everything goes through stdin/stdout, nothing is
# bind-mounted. SDKs live in named volumes (openwrt-repo-sdk-<ver>-<target>-<subtarget>) on the
# Docker host, so later runs are incremental. The signing key is sent over stdin only and is
# never written into the image or a volume.
#
# To publish afterwards (manual): git push --force-with-lease origin gh-pages
set -euo pipefail
cd "$(dirname "$0")/../.."
repo=$PWD

fresh=0 branch=gh-pages
while [ $# -gt 0 ]; do
  case $1 in
    --fresh) fresh=1 ;;
    --branch) branch=${2:?}; shift ;;
    *) sed -n '2,/^set /p' "$0" | sed '$d;s/^# \{0,1\}//' >&2; exit 2 ;;
  esac
  shift
done
: "${APK_SIGNING_KEY_FILE:?set APK_SIGNING_KEY_FILE to the EC private key (pem) used for signing}"
[ -r "$APK_SIGNING_KEY_FILE" ] || { echo "cannot read $APK_SIGNING_KEY_FILE" >&2; exit 1; }

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir "$stage/src" "$stage/parts"

echo "== staging sources" >&2
tar -c --exclude=./sdk --exclude=./.git --exclude=node_modules --exclude=./out \
  --exclude=./build --exclude=./pages --exclude=./parts . | tar -x -C "$stage/src"
cp "$APK_SIGNING_KEY_FILE" "$stage/src/.signkey"
chmod 600 "$stage/src/.signkey"

mkdir "$stage/src/pages"  # always present: tells pages-prepare.sh not to clone
# Previous gh-pages content, so only the rebuilt version directories are replaced (like CI).
if [ $fresh = 0 ]; then
  for ref in "$branch" "origin/$branch"; do
    if git rev-parse -q --verify "refs/heads/$ref" >/dev/null || git rev-parse -q --verify "refs/remotes/$ref" >/dev/null; then
      echo "== seeding from $ref" >&2
      git archive "$ref" | tar -x -C "$stage/src/pages"
      break
    fi
  done
fi

echo "== building image" >&2
docker build -q -t openwrt-repo-build scripts/local >/dev/null

# Runs a shell snippet in a fresh container. Sources arrive on stdin; the snippet's own stdout
# is the result tar (fd 3), everything else goes to stderr.
# usage: in_container <extra docker args...> -- <snippet>
in_container() {
  local args=()
  while [ "$1" != -- ]; do args+=("$1"); shift; done; shift
  tar -c -C "$stage/src" . |
    docker run --rm -i "${args[@]}" openwrt-repo-build sh -euc \
      'exec 3>&1 1>&2; tar -x -C /work; export RUNNER_TEMP=/tmp/runner; mkdir -p "$RUNNER_TEMP"; '"$1"
}

matrix=$(in_container -- 'python3 scripts/matrix.py >&3' | python3 -c '
import json, sys
for e in json.load(sys.stdin)["include"]:
    print(e["version"], e["target"], e["subtarget"], e["arch"])')
[ -n "$matrix" ] || { echo "empty build matrix" >&2; exit 1; }

while read -r version target subtarget arch; do
  echo "== build $version $target/$subtarget ($arch)" >&2
  vol="openwrt-repo-sdk-$version-$target-$subtarget"
  mkdir -p "$stage/parts/$target-$subtarget"
  in_container -v "$vol:/work/sdk" \
    -e VERSION="$version" -e TARGET="$target" -e SUBTARGET="$subtarget" -e ARCH="$arch" -- '
      APK_SIGNING_KEY=$(cat .signkey); export APK_SIGNING_KEY; rm .signkey
      sh scripts/ci/prepare-key.sh
      [ -e sdk/Makefile ] || sh scripts/ci/download-sdk.sh
      sh scripts/ci/setup-feeds.sh
      sh scripts/ci/build.sh
      sh scripts/ci/collect.sh
      tar -c -C out . >&3' |
    tar -x -C "$stage/parts/$target-$subtarget"
done <<< "$matrix"

echo "== publish prep + landing page" >&2
mkdir "$stage/result"
rm "$stage/src/.signkey"  # not needed any more; the publish container never sees the key
mv "$stage/parts" "$stage/src/parts"
in_container -- '
  sh scripts/ci/pages-prepare.sh
  sh scripts/ci/site-build.sh
  tar -c -C pages . >&3' | tar -x -C "$stage/result"

# Commit with plumbing so the working tree, index and HEAD stay untouched.
export GIT_INDEX_FILE="$stage/index"
tree=$(git --work-tree="$stage/result" add -A . && git write-tree)
parent=""
if [ $fresh = 0 ] && git rev-parse -q --verify "refs/heads/$branch" >/dev/null; then
  parent=$(git rev-parse "refs/heads/$branch")
  if [ "$(git rev-parse "$parent^{tree}")" = "$tree" ]; then
    echo "nothing to publish: $branch already matches" >&2; exit 0
  fi
fi
src=$(git rev-parse --short HEAD)
[ -z "$(git status --porcelain --untracked-files=no)" ] || src="$src-dirty"
commit=$(git commit-tree "$tree" ${parent:+-p "$parent"} -m "Publish local-$src")
git update-ref "refs/heads/$branch" "$commit"
echo "== $branch -> $(git rev-parse --short "$commit") ($(git ls-tree -r --name-only "$commit" | wc -l) files). Not pushed." >&2
