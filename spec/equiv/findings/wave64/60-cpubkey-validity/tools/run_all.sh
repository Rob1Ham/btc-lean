#!/usr/bin/env bash
# Reproduce both legs and the comparison table.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$HERE/run_c.sh"
"$HERE/run_lean.sh"
python3 "$HERE/compare.py" > "$HERE/../results/comparison.md"
