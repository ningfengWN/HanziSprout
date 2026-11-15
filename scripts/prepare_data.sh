#!/bin/sh
# Build-time only; the installed App never downloads stroke data.
set -eu
PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DEST="$PROJECT_ROOT/HanziSprout/Resources/Strokes"
if [ -f "$DEST/.ready-2.0.1" ]; then exit 0; fi
TEMP_DATA="$(mktemp -d)"
trap 'rm -rf "$TEMP_DATA"' EXIT
/usr/bin/curl --fail --location --retry 3 --connect-timeout 20 --max-time 180 'https://registry.npmjs.org/hanzi-writer-data/-/hanzi-writer-data-2.0.1.tgz' -o "$TEMP_DATA/data.tgz"
EXPECTED='72baf3d82b114e60d6e40ea05f24d2262a05cd39d544e2f322ba2fceb7beff15'
ACTUAL="$(shasum -a 256 "$TEMP_DATA/data.tgz" | cut -d ' ' -f 1)"
if [ "$ACTUAL" != "$EXPECTED" ]; then echo 'error: Stroke data checksum mismatch'; exit 1; fi
tar -xzf "$TEMP_DATA/data.tgz" -C "$TEMP_DATA"
mkdir -p "$DEST"
# Only the package's one-character JSON names are stroke data.
for FILE in "$TEMP_DATA"/package/*.json; do
  NAME="$(basename "$FILE" .json)"
  if [ "$NAME" != package ]; then cp "$FILE" "$DEST/"; fi
done
touch "$DEST/.ready-2.0.1"
