#!/usr/bin/env bash
#
# The handbook cards are the expected website baselines. Each
# <img src="../web/<path>.png"> in the handbook must be exactly one PNG
# under the website checkout's tests/__screenshots__/. A new or removed
# picture is a card edit. Do not record the count in a workflow file.
#
# Usage:
#   scripts/check-web-baselines.sh <screenshots-dir> <handbook-html>

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <screenshots-dir> <handbook-html>" >&2
  exit 2
fi

SRC_DIR="${1%/}"
HTML="$2"

if [ ! -d "$SRC_DIR" ]; then
  echo "::error::${SRC_DIR} not found — the committed Playwright baselines are missing upstream (RealUnitCH/web tests/__screenshots__/)."
  exit 1
fi
if [ ! -f "$HTML" ]; then
  echo "::error::${HTML} not found."
  exit 1
fi

cards="$(mktemp)"
files="$(mktemp)"
trap 'rm -f "$cards" "$files"' EXIT

grep -o 'src="\.\./web/[^"]*\.png"' "$HTML" \
  | sed 's|^src="../web/||; s|"$||' \
  | sort > "$cards"

if [ ! -s "$cards" ]; then
  echo "::error::No web baseline cards found in ${HTML}."
  exit 1
fi

dups="$(uniq -d "$cards" || true)"
if [ -n "$dups" ]; then
  echo "::error::Duplicate web baseline card in ${HTML}."
  printf '%s\n' "$dups"
  exit 1
fi

find "$SRC_DIR" -type f -name '*.png' | sed "s|^${SRC_DIR}/||" | sort > "$files"

if cmp -s "$cards" "$files"; then
  echo "Web baseline cards match $(wc -l < "$files" | tr -d ' ') PNGs in ${SRC_DIR}."
  exit 0
fi

echo "::error::Web baseline cards in ${HTML} do not match the PNGs in ${SRC_DIR}. Add or remove the handbook card in the same change as the website baseline. Do not edit the deploy workflow to record the count."
echo "Only in the handbook:"
comm -23 "$cards" "$files"
echo "Only in the website checkout:"
comm -13 "$cards" "$files"
exit 1
