#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "${AVIATION_MAPS_CHECKOUT:?Set AVIATION_MAPS_CHECKOUT to the prepared fplnav-spec checkout described in README.md}"
installer_revision=147f8754cc25a51508ca7d4a23254f78c0136968
if [ "$(git -C "$AVIATION_MAPS_CHECKOUT" rev-parse HEAD)" != "$installer_revision" ] ||
   [ -n "$(git -C "$AVIATION_MAPS_CHECKOUT" status --porcelain -- packages/aviation-maps)" ]; then
    echo "Use the clean reviewed fplnav-spec checkout at $installer_revision." >&2
    exit 1
fi

if [ "$#" -ne 0 ]; then
    echo "Usage: sh scripts/prepare-aip-charts.sh" >&2
    exit 2
fi
if [ -z "${GH_TOKEN:-}" ]; then
    GH_TOKEN=$(gh auth token --hostname github.com)
    export GH_TOKEN
fi
mise exec node@24.18.1 -- node "$AVIATION_MAPS_CHECKOUT/packages/aviation-maps/bin/aviation-maps.mjs" \
    install --repo johnbenz13/fplnav-spec --pin "$root/Config/aip-charts-pin.json" \
    --consumer flight --destination "$root/.generated"
/usr/bin/python3 "$root/scripts/verify-aip-charts.py" "$root/Config/aip-charts-pin.json" \
    "$root/.generated/AIPCharts" "$root/.generated/AIPCharts.xcfilelist" >&2
