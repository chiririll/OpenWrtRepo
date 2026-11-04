#!/bin/sh
# Index every *.apk in a directory and sign the finished index.
# Sign last: signing appends bytes to packages.adb.
# Usage: index-and-sign.sh <dir> <private_key.pem> [apk-binary]
set -eu
dir=$1
key=$2
apk=${3:-apk}

cd "$dir"
"$apk" mkndx --allow-untrusted --output packages.adb ./*.apk
"$apk" adbsign --allow-untrusted --sign-key "$key" packages.adb
