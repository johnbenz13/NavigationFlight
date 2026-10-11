#!/bin/sh
set -eu

expected_version="0.2.0"
expected_revision="c6c904aedad0cf72192b4e0b02e6edce52fd2e70"
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
mkdir -p NavigationFlightTests/Fixtures/FPLNav/V7/Official
cp node_modules/@johnbenz13/fplnav-spec/examples/v5/representative.fplnav \
    NavigationFlightTests/Fixtures/FPLNav/V5/representative.fplnav
cp node_modules/@johnbenz13/fplnav-spec/examples/v7/representative.fplnav \
    NavigationFlightTests/Fixtures/FPLNav/V7/Official/representative-v7.fplnav
npm run contract:verify
