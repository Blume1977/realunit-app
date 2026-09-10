#!/usr/bin/env bash
#
# Validate the store-listing metadata before it is pushed to App Store
# Connect / Google Play Console. Three gates:
#   1. No FIXME- placeholders left in any metadata file.
#   2. Store-side character limits are respected (App Store / Play limits).
#   3. URL fields are well-formed http(s) URLs within Apple's length limit.
#
# Used by:
#   - .github/workflows/store-metadata.yaml  (preflight job, metadata-only sync)
#   - .github/workflows/release.yaml         (before the beta lane runs, so a
#                                             tag-driven release can never ship
#                                             a FIXME or oversize field live)
#
# Runs from anywhere; resolves paths relative to the repo root. Collects all
# violations before exiting (better CI diagnostics than fail-on-first).

set -euo pipefail

# Force a UTF-8 locale so `wc -m` and ${#var} count characters, not bytes,
# on runners whose default locale is C/POSIX (umlauts would otherwise inflate
# the count and trip a false positive).
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

fail=0

# 1) FIXME guard — catches unresolved placeholders (e.g. privacy/support URLs).
matches=$(grep -rE "^FIXME-" ios/fastlane/metadata android/fastlane/metadata 2>/dev/null || true)
if [ -n "$matches" ]; then
  echo "::error::Metadata still contains FIXME placeholders:"
  echo "$matches"
  fail=1
fi

# 2) Character limits. wc -m counts a trailing newline; drop it.
check() {
  file="$1"
  limit="$2"
  label="$3"
  if [ -f "$file" ]; then
    chars=$(($(wc -m < "$file" | tr -d ' ') - 1))
    if [ "$chars" -gt "$limit" ]; then
      echo "::error::$label exceeds $limit chars (got $chars): $file"
      fail=1
    fi
  fi
}
check ios/fastlane/metadata/de-DE/name.txt 30 "iOS name"
check ios/fastlane/metadata/de-DE/subtitle.txt 30 "iOS subtitle"
check ios/fastlane/metadata/de-DE/promotional_text.txt 170 "iOS promotional_text"
check ios/fastlane/metadata/de-DE/keywords.txt 100 "iOS keywords"
check ios/fastlane/metadata/de-DE/description.txt 4000 "iOS description"
check ios/fastlane/metadata/de-DE/release_notes.txt 4000 "iOS release_notes"
check android/fastlane/metadata/android/de-DE/title.txt 30 "Android title"
check android/fastlane/metadata/android/de-DE/short_description.txt 80 "Android short_description"
check android/fastlane/metadata/android/de-DE/full_description.txt 4000 "Android full_description"
check android/fastlane/metadata/android/de-DE/changelogs/default.txt 500 "Android changelog"

# 3) URL fields: optional, but if present must be a well-formed http(s) URL
# within Apple's 255-char limit.
check_url() {
  file="$1"
  label="$2"
  if [ -f "$file" ]; then
    url=$(head -n1 "$file" | tr -d '\r' | sed 's/[[:space:]]*$//')
    [ -z "$url" ] && return 0
    chars=${#url}
    if [ "$chars" -gt 255 ]; then
      echo "::error::$label exceeds 255 chars (got $chars): $file"
      fail=1
    fi
    if ! printf '%s' "$url" | grep -qiE '^https?://[^[:space:]]+\.[^[:space:]]+$'; then
      echo "::error::$label is not a valid http(s) URL: $file ($url)"
      fail=1
    fi
  fi
}
check_url ios/fastlane/metadata/de-DE/marketing_url.txt "iOS marketing_url"
check_url ios/fastlane/metadata/de-DE/privacy_url.txt "iOS privacy_url"
check_url ios/fastlane/metadata/de-DE/support_url.txt "iOS support_url"

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "store metadata preflight OK"
