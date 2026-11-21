#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if [ "$#" -ne 0 ]; then
    echo "Usage: sh scripts/prepare-aip-charts.sh" >&2
    exit 2
fi
exec /usr/bin/python3 "$root/scripts/download-aip-charts.py"
