#!/usr/bin/env bash
# Shared helpers for the wave16/01-exec-verify cells.
#
# These cells are bounded, line-cited source-excerpt leaves of
# `VerifyScript`/`EvalScript` (C leg) against reviewed Lean transliterations
# (L leg).  Nothing here is engine code: the only shared logic is the build
# invocation, the sha256 certificate writer, and the tool lookup.

set -euo pipefail

ev_root() {
  local d="$1"
  while [ "$d" != "/" ]; do
    if [ -f "$d/spec/equiv/contract/error_kind.h" ]; then printf '%s\n' "$d"; return 0; fi
    d="$(dirname "$d")"
  done
  echo "cannot locate repo root (spec/equiv/contract/error_kind.h)" >&2
  return 1
}

ev_alive_tv() {
  if [ -x /opt/equiv-tools/alive-tv-v20.0 ]; then printf '%s\n' /opt/equiv-tools/alive-tv-v20.0; return; fi
  command -v alive-tv
}

ev_saw() {
  if [ -x /opt/equiv-tools/saw-1.6/bin/saw ]; then printf '%s\n' /opt/equiv-tools/saw-1.6/bin/saw; return; fi
  command -v saw
}

# Build the C/L leaf pair for a cell.  `cell.conf` defines CELL_ID and FNS.
ev_build_pair() {
  local cell="$1" src build fn leg
  src="$cell/src"; build="$cell/build"
  mkdir -p "$build"
  # shellcheck disable=SC1090
  source "$cell/cell.conf"
  local CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing -fno-discard-value-names -I "$src" -c -emit-llvm)
  "${CXX[@]}" "$src/c_cell.cpp" -o "$build/c_leaf.bc"
  "${CXX[@]}" "$src/l_cell.cpp" -o "$build/l_leaf.bc"
  /usr/lib/llvm-20/bin/llvm-dis "$build/c_leaf.bc" -o "$build/c_leaf.ll"
  /usr/lib/llvm-20/bin/llvm-dis "$build/l_leaf.bc" -o "$build/l_leaf.ll"
  for fn in $FNS; do
    for leg in c l; do
      /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
        "$build/${leg}_leaf.bc" -o "$build/${leg}_${fn}.bc"
      /usr/lib/llvm-20/bin/llvm-dis "$build/${leg}_${fn}.bc" -o "$build/${leg}_${fn}.ll"
    done
  done
  {
    printf 'cell=%s\n' "$(source "$cell/cell.conf"; printf '%s' "$CELL_ID")"
    printf 'fns=%s\n' "$FNS"
    printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
    printf 'llvm-extract=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  } > "$build/build.txt"
}

# Write a certificate for the listed repo-root-relative paths.
ev_certificate() {
  local cell="$1"; shift
  local root; root="$(ev_root "$cell")"
  local files=("$@")
  {
    cd "$root"
    for f in "${files[@]}"; do
      if [ -f "$f" ]; then sha256sum "$f"; else echo "# MISSING $f"; fi
    done
  }
}
