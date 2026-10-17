#!/usr/bin/env bash
# Rebuild the raw vector-runner result record. The former per-rule coverage
# dashboard was retired; spec/db/results.json is a raw run snapshot, not a
# census or a proof artifact.
set -euo pipefail
cd "$(dirname "$0")/.."   # spec/

(cd runners && lake build vectorrunner >/dev/null)
./runners/.lake/build/bin/vectorrunner db/results.json
