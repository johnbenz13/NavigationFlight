#!/bin/sh
set -eu

expected_version="0.1.1"
expected_revision="f8dc139057e088552a83d92882ebd3b0052392a3"
npm_cache="${TMPDIR:-/tmp}/navigationflight-npm-cache"

if [ -z "${FPLNAV_PACKAGES_TOKEN:-}" ]; then
    FPLNAV_PACKAGES_TOKEN="$(gh auth token)"
    export FPLNAV_PACKAGES_TOKEN
fi

published_revision="$(npm view "@johnbenz13/fplnav-spec@${expected_version}" gitHead --cache "$npm_cache")"
if [ "$published_revision" != "$expected_revision" ]; then
    echo "Unexpected fplnav-spec revision for ${expected_version}" >&2
    exit 1
fi

npm ci --ignore-scripts --cache "$npm_cache"
mkdir -p NavigationFlightTests/Fixtures/FPLNav/V5
cp node_modules/@johnbenz13/fplnav-spec/examples/v5/representative.fplnav \
    NavigationFlightTests/Fixtures/FPLNav/V5/representative.fplnav
npm run contract:verify
