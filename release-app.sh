#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# release-app.sh — one-command Flutter APK release for Sanlam Chronic Care.
#
# Usage:
#   ./release-app.sh                 # auto-bumps build number, prompts for notes
#   ./release-app.sh 1.0.5           # set marketing version, auto-bumps build
#   ./release-app.sh 1.0.5 --force   # also marks this as a forced update
#
# What it does:
#   1. Bumps app/pubspec.yaml version (X.Y.Z+N → X.Y.Z+N+1, or to the version
#      you pass).
#   2. Builds the release APK with the production --dart-defines.
#   3. Backs up the old APK and copies the new one to all 3 serve locations.
#   4. Updates backend/uploads/apk/version.json (latest, latestCode,
#      sizeBytes, releasedAt, releaseNotes) — and minSupportedCode if --force.
#   5. Verifies the live endpoint returns the new version.
#
# Members will see the in-app update dialog on next open.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$REPO/app"
APK_OUT="$APP_DIR/build/app/outputs/flutter-apk/app-sideload-release.apk"
APK_TARGETS=(
  "$REPO/backend/uploads/apk/sanlam-chronic-care.apk"
  "$REPO/backend/uploads/apk/SanCare+.apk"
  "$REPO/portal/public/uploads/apk/sanlam-chronic-care.apk"
  "$REPO/portal/public/uploads/apk/SanCare+.apk"
  "$REPO/portal/dist/uploads/apk/sanlam-chronic-care.apk"
  "$REPO/portal/dist/uploads/apk/SanCare+.apk"
)
MANIFEST="$REPO/backend/uploads/apk/version.json"
PUBSPEC="$APP_DIR/pubspec.yaml"
FLUTTER="${FLUTTER:-/home/saz/flutter/bin/flutter}"
API_URL="${API_URL:-https://app.sanlamallianz4u.co.ug/api}"
SANLAM_URL="${SANLAM_URL:-https://ehosccs.net/SanlamMemberApi/api/member/}"
LIVE_VERSION_URL="${LIVE_VERSION_URL:-https://app.sanlamallianz4u.co.ug/api/app/version}"

NEW_VERSION_ARG="${1:-}"
FORCE_UPDATE=false
if [[ "${2:-}" == "--force" ]] || [[ "${1:-}" == "--force" ]]; then
  FORCE_UPDATE=true
fi
[[ "$NEW_VERSION_ARG" == "--force" ]] && NEW_VERSION_ARG=""

cyan()   { printf "\033[1;36m%s\033[0m\n" "$*"; }
green()  { printf "\033[1;32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[1;33m%s\033[0m\n" "$*"; }
red()    { printf "\033[1;31m%s\033[0m\n" "$*"; }

# ── 1. Read current version ─────────────────────────────────────────────────
CUR_LINE="$(grep -E '^version:' "$PUBSPEC" | head -1)"
CUR_VERSION="$(echo "$CUR_LINE" | sed -E 's/version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+).*/\1/')"
CUR_CODE="$(echo "$CUR_LINE" | sed -E 's/version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+).*/\2/')"

NEW_VERSION="${NEW_VERSION_ARG:-$CUR_VERSION}"
NEW_CODE=$(( CUR_CODE + 1 ))

cyan "▶ Current: v$CUR_VERSION+$CUR_CODE"
cyan "▶ New:     v$NEW_VERSION+$NEW_CODE"
$FORCE_UPDATE && yellow "⚠ Forced update — older builds will be blocked from running"

# ── 2. Collect release notes ────────────────────────────────────────────────
yellow ""
yellow "Enter release notes (one bullet per line, blank line to finish):"
NOTES_JSON="["
FIRST=true
while IFS= read -r line; do
  [[ -z "$line" ]] && break
  esc="$(printf '%s' "$line" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip()))')"
  $FIRST || NOTES_JSON+=","
  NOTES_JSON+="$esc"
  FIRST=false
done
NOTES_JSON+="]"
if [[ "$NOTES_JSON" == "[]" ]]; then
  yellow "No notes entered — keeping the previous release notes."
fi

# ── 3. Bump pubspec ─────────────────────────────────────────────────────────
cyan ""
cyan "▶ Step 1/4: Bumping $PUBSPEC → version: $NEW_VERSION+$NEW_CODE"
sed -i.bak -E "s/^version:.*/version: $NEW_VERSION+$NEW_CODE/" "$PUBSPEC"
rm -f "$PUBSPEC.bak"

# ── 4. Build APK ────────────────────────────────────────────────────────────
cyan ""
cyan "▶ Step 2/4: Building release APK (this takes ~90s)…"
cd "$APP_DIR"
"$FLUTTER" build apk --release --flavor sideload \
  --dart-define=API_URL="$API_URL" \
  --dart-define=SANLAM_API_URL="$SANLAM_URL"
[[ -f "$APK_OUT" ]] || { red "✗ APK not produced at $APK_OUT"; exit 1; }
NEW_SIZE=$(stat -c %s "$APK_OUT")
green "✓ Built $(du -h "$APK_OUT" | cut -f1) APK"

# ── 5. Deploy APK ───────────────────────────────────────────────────────────
cyan ""
cyan "▶ Step 3/4: Deploying APK to all serve locations…"
TS=$(date +%Y%m%d_%H%M%S)
cp "${APK_TARGETS[0]}" "${APK_TARGETS[0]}.bak.$TS" 2>/dev/null || true
for t in "${APK_TARGETS[@]}"; do
  mkdir -p "$(dirname "$t")"
  cp "$APK_OUT" "$t"
  green "  ✓ $t"
done

# ── 6. Update manifest ──────────────────────────────────────────────────────
cyan ""
cyan "▶ Step 4/4: Updating $MANIFEST"
RELEASED_AT="$(date -Iseconds)"
python3 - <<PY
import json, pathlib
p = pathlib.Path("$MANIFEST")
m = json.loads(p.read_text())
m["latest"] = "$NEW_VERSION"
m["latestCode"] = $NEW_CODE
m["sizeBytes"] = $NEW_SIZE
m["releasedAt"] = "$RELEASED_AT"
notes = $NOTES_JSON
if notes:
    m["releaseNotes"] = notes
if $( $FORCE_UPDATE && echo True || echo False ):
    m["minSupportedCode"] = $NEW_CODE
    m["minSupported"] = "$NEW_VERSION"
p.write_text(json.dumps(m, indent=2) + "\n")
print("✓ manifest updated:", json.dumps({k: m[k] for k in ("latest","latestCode","minSupportedCode","sizeBytes")}))
PY

# ── 7. Verify ───────────────────────────────────────────────────────────────
cyan ""
cyan "▶ Verifying live endpoint…"
sleep 1
LIVE="$(curl -s "$LIVE_VERSION_URL" || true)"
if echo "$LIVE" | grep -q "\"latestCode\":$NEW_CODE"; then
  green "✓ Live: $LIVE_VERSION_URL reports latestCode=$NEW_CODE"
else
  red "⚠ Live endpoint did not yet show new code. Response: $LIVE"
  red "  (Cache may still be warm — wait 60s and retry.)"
fi

green ""
green "═════════════════════════════════════════════════════════════"
green "✅ Released v$NEW_VERSION+$NEW_CODE"
green "   Members will see the update prompt on next app open."
green "   Public download page: https://app.sanlamallianz4u.co.ug/download"
green "═════════════════════════════════════════════════════════════"
