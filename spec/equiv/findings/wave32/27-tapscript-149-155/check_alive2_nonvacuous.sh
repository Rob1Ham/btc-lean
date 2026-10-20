#!/usr/bin/env bash
# Non-vacuity spot check for the Alive2 legs of the wave-32 tapscript cells.
#
# A "green" Alive2 run is only meaningful if Alive2 actually discharges the
# query.  Alive2 20.0 sometimes silently skips large raw -O1 functions (see
# run 1 of probe/alive2/result.txt).  The cell runner therefore verifies the
# -O2 form with --always-verify.  This script mutates one constant in the raw
# L leg, applies the same -O2 step, and checks that alive-tv reports exactly
# one incorrect transformation.  A skip would show up as NOT-DETECTED.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../../../.." && pwd)"
CELLS="$ROOT/spec/equiv/cells/tapscript"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

check() { # cell fn mutation-sed
  local cell="$1" fn="$2" expr="$3"
  local src="$CELLS/$cell/build/l_${fn}.ll"
  local mut="$TMP/l_${fn}.ll"
  sed -E "$expr" "$src" > "$mut"
  if cmp -s "$src" "$mut"; then
    printf '%-42s %-30s MUTATION-NOT-APPLIED\n' "$cell" "$fn"
    return 1
  fi
  /usr/lib/llvm-20/bin/opt -O2 -S "$mut" -o "$TMP/l_${fn}.opt.ll"
  local out
  out="$(/usr/local/bin/alive-tv --always-verify --smt-to=60000 \
        "$CELLS/$cell/build/c_${fn}.opt.ll" "$TMP/l_${fn}.opt.ll" 2>&1 || true)"
  if printf '%s' "$out" | grep -q '1 incorrect transformations'; then
    printf '%-42s %-30s DETECTED (alive2 is checking this pair)\n' "$cell" "$fn"
  else
    printf '%-42s %-30s NOT-DETECTED (alive2 skipped the pair)\n' "$cell" "$fn"
    return 1
  fi
}

check_perl() { # cell fn  (bump the first numeric phi entry)
  local cell="$1" fn="$2"
  local src="$CELLS/$cell/build/l_${fn}.ll"
  local mut="$TMP/l_${fn}.ll"
  perl -0pe 's/(, \[ )(\d+)(,)/$1.($2+1).$3/e' "$src" > "$mut"
  if cmp -s "$src" "$mut"; then
    printf '%-42s %-30s MUTATION-NOT-APPLIED\n' "$cell" "$fn"
    return 1
  fi
  /usr/lib/llvm-20/bin/opt -O2 -S "$mut" -o "$TMP/l_${fn}.opt.ll"
  local out
  out="$(/usr/local/bin/alive-tv --always-verify --smt-to=60000 \
        "$CELLS/$cell/build/c_${fn}.opt.ll" "$TMP/l_${fn}.opt.ll" 2>&1 || true)"
  if printf '%s' "$out" | grep -q '1 incorrect transformations'; then
    printf '%-42s %-30s DETECTED (alive2 is checking this pair)\n' "$cell" "$fn"
  else
    printf '%-42s %-30s NOT-DETECTED (alive2 skipped the pair)\n' "$cell" "$fn"
    return 1
  fi
}

rc=0
check_perl C-L-w32-op-success-prescan cell_prescan_tail || rc=1
check_perl C-L-w32-op-success-prescan cell_scan_finds_success || rc=1
check C-L-w32-op-success-set cell_is_op_success 's/icmp ult i8 %0, 68/icmp ult i8 %0, 69/' || rc=1
check_perl C-L-w32-opcount-budget cell_opcount_guard || rc=1
check_perl C-L-w32-opcount-budget cell_nop_overbudget || rc=1
check C-L-w32-witness-dispatch-upgradable cell_leaf_version_dispatch 's/i64 140/i64 141/' || rc=1
check_perl C-L-w32-witness-dispatch-upgradable cell_program_tail_dispatch || rc=1
exit "$rc"
