#!/bin/sh
# Write the signing key from $APK_SIGNING_KEY and derive the public key.
# Output: $RUNNER_TEMP/sign.pem, $RUNNER_TEMP/public.pem
set -eu
tmp=${RUNNER_TEMP:?}

umask 077
printf '%s\n' "$APK_SIGNING_KEY" > "$tmp/sign.pem"
openssl ec -in "$tmp/sign.pem" -pubout -out "$tmp/public.pem"
