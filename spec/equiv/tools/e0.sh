#!/bin/sh
# E0 acceptance gate.
#  1. TOOLS probes (Alive2 positive/negative, SAW positive)
#  2. the real three-leg tape run (C/L/R shared libraries)
# Fails until C, L, and R agree on every tape. Extra args go to
# tools/run_e0.py (e.g. --verbose). For custom shared-library paths, call
# tools/tests/e0_triple.py directly.
set -e
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
python3 tools/run_e0.py --strict-e0 "$@"
