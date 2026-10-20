#!/usr/bin/env bash
# Shared helpers for the wave-16 numeric cell runners.
#
#   certify OUT PATH...   write a repo-relative sha256 manifest over the given
#                         files/directories (verifiable with
#                         `sha256sum -c OUT` from the repository root)
#
# Only committed files are certified (`build/` is gitignored), so a fresh
# checkout of the cell verifies with `sha256sum -c`.  The hashes of the
# generated leaf (`build/twin_ops.h`) and the build metadata are recorded in
# the raw `result.txt` header and in build/build.txt instead.

set -euo pipefail

# Resolve the repository root from this script's location:
#   <repo>/spec/equiv/findings/wave16/07-numeric-ops/tools/certify.sh
TOOLS_HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EQ_ROOT="$(cd "$TOOLS_HELPER_DIR/../../../.." && pwd)"
REPO_ROOT="$(cd "$EQ_ROOT/../.." && pwd)"

certify() {
  local out="$1"; shift
  (
    cd "$REPO_ROOT"
    local p rp
    for p in "$@"; do
      rp="$(realpath --relative-to="$REPO_ROOT" "$p")"
      case "$rp" in
        ../*|/*) echo "# outside-root $rp $(sha256sum "$p" | cut -d' ' -f1)" ;;
        *)
          if [ -d "$rp" ]; then
            find "$rp" -type f -print0 | sort -z | xargs -0 -r sha256sum
          else
            sha256sum "$rp"
          fi
          ;;
      esac
    done
  ) > "$out"
}

# Common file set for a cell's certificate: record, both runners, committed
# cell sources, the shared tools, the contract excerpt and the twin sources the
# L leg is generated from, and the raw result.
cell_certify() {
  local cell_dir="$1" out="$2" res="$3" build="$4" tools="$5" eq="$6"
  certify "$out" \
    "$cell_dir/spec.md" \
    "$cell_dir/alive2/run.sh" \
    "$cell_dir/saw/run.sh" \
    "$cell_dir/src" \
    "$tools" \
    "$eq/contract/error_kind.h" \
    "$eq/twin/ops_ir.py" \
    "$eq/twin/gen.py" \
    "$eq/twin/runtime.inc" \
    "$eq/cells/_tools/mk_leaf.py" \
    "$res"
}
