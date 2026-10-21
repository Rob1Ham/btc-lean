#!/usr/bin/env bash
# Build and run the hand-computed vectors for policy-flags/C-L-flag-source.
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$CELL/tools/concrete_check.out"
B="$CELL/build/concrete"
mkdir -p "$B"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -I "$CELL/_tools")

# Rename each leg's extern "C" roots so both can be linked into one driver.
"${CXX[@]}" -Dcell_flag_source=c_cell_flag_source \
  -Dcell_lows_gate_block=c_cell_lows_gate_block \
  -Dcell_const_gate_block=c_cell_const_gate_block \
  -Dcell_flag_source_policy_mask=c_cell_flag_source_policy_mask \
  -Dcell_standard_policy_mask=c_cell_standard_policy_mask \
  -Dcell_mandatory_policy_mask=c_cell_mandatory_policy_mask \
  -c "$CELL/c_cell.cpp" -o "$B/c.o"
"${CXX[@]}" -Dcell_flag_source=l_cell_flag_source \
  -Dcell_lows_gate_block=l_cell_lows_gate_block \
  -Dcell_const_gate_block=l_cell_const_gate_block \
  -Dcell_flag_source_policy_mask=l_cell_flag_source_policy_mask \
  -Dcell_standard_policy_mask=l_cell_standard_policy_mask \
  -Dcell_mandatory_policy_mask=l_cell_mandatory_policy_mask \
  -c "$CELL/l_cell.cpp" -o "$B/l.o"
"${CXX[@]}" "$CELL/tools/concrete_check.cpp" "$B/c.o" "$B/l.o" -o "$B/check"

{
  echo "# cell: policy-flags/C-L-flag-source"
  echo "# expectations written from validation.cpp:2249-2284 and policy.h:104-133"
  echo "# at pin cce32b168; C and L legs are linked side by side"
  "$B/check"
} > "$OUT" 2>&1
cat "$OUT"
