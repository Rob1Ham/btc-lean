#!/usr/bin/env bash
# Reproduction for wave16b/06-r-alive22 (B-03 probe). Run on the pinned host.
# Nothing here writes outside the scratch dir. Does not touch PINS.lock.
set -euo pipefail

SCRATCH=/tmp/opencode/wave16b-scratch/06-r-alive22
R_LL=/tmp/opencode/equiv-work/target-195-ir/release/deps/rbitcoin_consensus-68e7c81c2384e3ba.ll
LLVM22=/usr/lib/llvm-22/bin
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$SCRATCH" && cd "$SCRATCH"
# probe inputs committed next to this script
cp -n "$HERE"/probes/*.ll "$HERE"/probes/ir_strip_probe.py . 2>/dev/null || true
mkdir -p minimal && cp -n "$HERE"/probes/minimal/*.ll minimal/ 2>/dev/null || true

# ---------------------------------------------------------------- LLVM 22
# apt.llvm.org noble, llvm-toolchain-noble-22:
#   llvm-22/llvm-22-dev/clang-22 =
#   1:22.1.8~++20260714014902+ca7933e47d3a-1~exp1~20260714135019.80
#
# sudo gpg --dearmor -o /usr/share/keyrings/llvm-snapshot.gpg llvm-snapshot.gpg.key
# echo 'deb [signed-by=/usr/share/keyrings/llvm-snapshot.gpg] \
#   http://apt.llvm.org/noble/ llvm-toolchain-noble-22 main' \
#   | sudo tee /etc/apt/sources.list.d/llvm-22.list
# sudo apt-get update && sudo apt-get install -y llvm-22-dev clang-22

# ---------------------------------------------------------------- Alive2
# Newest upstream commit that builds against LLVM 22 (see logs/build-*-fail.log
# for the newer commits that do not).
git clone https://github.com/AliveToolkit/alive2.git alive2-src
git -C alive2-src checkout 0dc2be5f
mkdir -p build-0dc2be5f && cd build-0dc2be5f
cmake -GNinja -DCMAKE_BUILD_TYPE=Release -DBUILD_LLVM_UTILS=ON \
      -DLLVM_DIR=/usr/lib/llvm-22/lib/cmake/llvm \
      -DCMAKE_C_COMPILER=/usr/bin/clang-22 \
      -DCMAKE_CXX_COMPILER=/usr/bin/clang++-22 \
      ../alive2-src
ninja -j16
cd "$SCRATCH"
# binary sha256 078cd01354ab96145d44a2fdf2902e91825c5797e2b1045c14ec2a1b4345d771

# ------------------------------------------------------------ pin artifact
$LLVM22/llvm-as "$R_LL" -o real-r-195.bc          # rc=0 on LLVM 22.1.8

# 1. whole-module self-comparison (351 defined functions)
./build-0dc2be5f/alive-tv real-r-195.bc real-r-195.bc > full-module-selfcompare.out 2>&1 || true

# 2. target function: eval_script (the 1.95 module has no standalone verify_input)
F=_ZN18rbitcoin_consensus6script11interpreter11eval_script17h9bf99c7ab3467ea9E
$LLVM22/llvm-extract -func="$F" real-r-195.bc -o eval_script-195.bc
$LLVM22/llvm-dis eval_script-195.bc -o eval_script-195.ll
./build-0dc2be5f/alive-tv eval_script-195.bc eval_script-195.bc  # p0: param noalias

run() { tag=$1; shift
  python3 ir_strip_probe.py eval_script-195.ll "ev-$tag.ll" "$@"
  $LLVM22/llvm-as "ev-$tag.ll" -o "ev-$tag.bc"
  ./build-0dc2be5f/alive-tv "ev-$tag.bc" "ev-$tag.bc" > "ev-$tag.out" 2>&1 || true
}
run pA param_noalias               # pA: Unsupported metadata: 8
run pB param_noalias nomd          # pB: noalias.scope.decl / metadata type
run pC param_noalias nomd scopedecl  # pC: translates, 1 correct

# 3. function that actually carries dead_on_return (v20 parse failure site)
G='_ZN111_$LT$alloc..vec..Vec$LT$T$GT$$u20$as$u20$alloc..vec..spec_from_iter_nested..SpecFromIterNested$LT$T$C$I$GT$$GT$9from_iter17h4edb8bfb10638b77E'
$LLVM22/llvm-extract -func="$G" real-r-195.bc -o from_iter-195.bc
$LLVM22/llvm-dis from_iter-195.bc -o from_iter-195.ll
python3 ir_strip_probe.py from_iter-195.ll fi-noalias.ll param_noalias
$LLVM22/llvm-as fi-noalias.ll -o fi-noalias.bc
./build-0dc2be5f/alive-tv fi-noalias.bc fi-noalias.bc   # dead_on_return kept

# 4. minimal per-feature probes
for f in sret noalias-param captures-address; do
  $LLVM22/llvm-as "minimal/$f.ll" -o "minimal/$f.bc"
  ./build-0dc2be5f/alive-tv "minimal/$f.bc" "minimal/$f.bc" || true
done

# 5. positive leaf probe: real pin body vs rewritten twin (not a cell, advisory)
$LLVM22/llvm-as scb-pair.ll -o scb-pair.bc
./build-0dc2be5f/alive-tv scb-pair.bc

# ------------------------------------------------- compiler-flag alternatives
# (a) same rustc, alias metadata off
cd /tmp/opencode/equiv-work/rbitcoin-clean
RUSTC_BOOTSTRAP=1 RUSTFLAGS='-Z mutable-noalias=no -Z box-noalias=no' \
  CARGO_TARGET_DIR="$SCRATCH/target-195-noalias" \
  cargo +1.95.0 rustc --release --ignore-rust-version -p rbitcoin-consensus --lib -- \
  --emit=llvm-ir,llvm-bc -C lto=no -C panic=abort
# (b) -O0
CARGO_TARGET_DIR="$SCRATCH/target-195-O0" \
  cargo +1.95.0 rustc --ignore-rust-version -p rbitcoin-consensus --lib -- \
  --emit=llvm-ir -C lto=no -C panic=abort
