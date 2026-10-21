#!/bin/sh
# Run every F-HARNESS-002 probe and regenerate logs/. Advisory/off-pin only.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
"$HERE/build.sh"
python3 "$HERE/tools/census.py"
python3 "$HERE/tools/witness.py"
python3 "$HERE/tools/abi_domain.py"
"$HERE/build/witness" "$HERE/cases.tsv" > "$HERE/logs/witness-raw.tsv"
"$HERE/tools/env.sh" > "$HERE/logs/env.txt"
echo GATE_OK
