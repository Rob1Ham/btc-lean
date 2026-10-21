#!/usr/bin/env bash
# Build the general-vin C/L leaves for one locktime cell and record the hashes.
# Self-contained (no cells/_tools dependency): the L leg is a reviewed Lean
# transliteration, not a generated twin handler.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EQ="$(cd "$CELL_DIR/../../.." && pwd)"
BUILD="$CELL_DIR/build"
mkdir -p "$BUILD"

CXX=(/usr/bin/clang++-20 -std=c++20 -O1 -fno-strict-aliasing
     -S -emit-llvm -fno-discard-value-names)
"${CXX[@]}" "$CELL_DIR/src/c_leaf.cpp" -o "$BUILD/c_leaf.ll"
"${CXX[@]}" "$CELL_DIR/src/l_leaf.cpp" -o "$BUILD/l_leaf.ll"

FNS_C=(
  cell_cltv_general cell_csv_general
  cell_cltv_raw cell_csv_raw
  cell_cltv_noninterf_a cell_cltv_noninterf_b
  cell_csv_noninterf_a cell_csv_noninterf_b
  cell_getd_len_a cell_getd_len_b
)
FNS_L=(
  cell_cltv_general cell_csv_general
  cell_cltv_raw_l cell_csv_raw_l
  cell_cltv_noninterf_b cell_csv_noninterf_b
  cell_getd_len_b
)
for fn in "${FNS_C[@]}"; do
  /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
    "$BUILD/c_leaf.ll" -o "$BUILD/c_${fn}.bc"
  /usr/lib/llvm-20/bin/llvm-dis "$BUILD/c_${fn}.bc" -o "$BUILD/c_${fn}.ll"
done
for fn in "${FNS_L[@]}"; do
  /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
    "$BUILD/l_leaf.ll" -o "$BUILD/l_${fn}.bc"
  /usr/lib/llvm-20/bin/llvm-dis "$BUILD/l_${fn}.bc" -o "$BUILD/l_${fn}.ll"
done

# Alive2 compares functions by name.  Produce one same-named pair (`f`) per
# transform, stripping the `nocapture` parameter attribute that Alive2 v20
# does not ingest (it is an optimization hint, not semantics).
PAIRS=(
  "cltv     c_cell_cltv_general     l_cell_cltv_general"
  "csv      c_cell_csv_general      l_cell_csv_general"
  "cltv_raw c_cell_cltv_raw         l_cell_cltv_raw_l"
  "csv_raw  c_cell_csv_raw          l_cell_csv_raw_l"
  "cltv_ni  c_cell_cltv_noninterf_a l_cell_cltv_noninterf_b"
  "csv_ni   c_cell_csv_noninterf_a  l_cell_csv_noninterf_b"
  "getd_len c_cell_getd_len_a       l_cell_getd_len_b"
)
: > "$BUILD/pairs.txt"
for p in "${PAIRS[@]}"; do
  read -r name src tgt <<<"$p"
  sed -E 's/ nocapture//g; s/@cell_[A-Za-z0-9_]+/@f/g' "$BUILD/${src}.ll" > "$BUILD/${name}_src.ll"
  sed -E 's/ nocapture//g; s/@cell_[A-Za-z0-9_]+/@f/g' "$BUILD/${tgt}.ll" > "$BUILD/${name}_tgt.ll"
  printf '%s src=%s tgt=%s\n' "$name" "$src" "$tgt" >> "$BUILD/pairs.txt"
done

{
  printf 'cell=%s\n' "$(basename "$CELL_DIR")"
  printf 'fns_c=%s\n' "${FNS_C[*]}"
  printf 'fns_l=%s\n' "${FNS_L[*]}"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'flags=-O1 -fno-strict-aliasing -S -emit-llvm\n'
  printf 'c_leaf_sha256=%s\n' "$(sha256sum "$BUILD/c_leaf.ll" | cut -d' ' -f1)"
  printf 'l_leaf_sha256=%s\n' "$(sha256sum "$BUILD/l_leaf.ll" | cut -d' ' -f1)"
  printf 'root=%s\n' "$EQ"
} > "$BUILD/build.txt"
