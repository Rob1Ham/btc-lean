# Reproduction commands — wave65/27-e5-whole

All commands run as an unprivileged user. `$CELL` is this directory:

```sh
CELL=/tmp/opencode/wave65/27-e5-whole/spec/equiv/findings/wave65/27-e5-whole
PIN=/tmp/opencode/equiv-work/bitcoin     # clean cce32b1 checkout, read-only use
```

Tool versions are pinned in `logs/tool-versions.txt`: SAW 1.6 (`68eed5f`),
clang/LLVM 20.1.2, Lean 4.35.0, z3 4.8.12.

## 0. Source of record (read-only)

```sh
for f in interpreter.cpp script.cpp script.h; do
  git -C /tmp/pcore01 show cce32b1:src/script/$f \
    > /tmp/opencode/wave65/27-e5-whole-evidence/src/$f
done
sha256sum /tmp/opencode/wave65/27-e5-whole-evidence/src/*
```

Expected: `57a6f328…`, `210b1720…`, `43e4eb10…` (see `SHA256SUMS`).

## 1. Build the pinned parser bitcode (bit-for-bit)

```sh
cd $PIN
/usr/bin/clang++-20 -std=c++20 -O0 -g0 -emit-llvm -c src/script/script.cpp \
  -I src -o $CELL/build/script-O0.bc
/usr/bin/clang++-20 -std=c++20 -O0 -g0 -emit-llvm -c $CELL/harness/measure.cpp \
  -I src -o $CELL/build/measure-O0.bc
/usr/lib/llvm-20/bin/llvm-link $CELL/build/script-O0.bc $CELL/build/measure-O0.bc \
  -o $CELL/build/parser-measure.bc
sha256sum $CELL/build/*.bc
```

Expected hashes: `script-O0.bc 657530a8…`, `measure-O0.bc 9f287fb1…`,
`parser-measure.bc 1d8b344e…`.

> The `source_filename` recorded in the bitcode is the relative
> `src/script/script.cpp`; compiling the same file by absolute path produces a
> different bitcode hash. Always run from the checkout root.

## 2. Parser measure proofs (real pinned IR)

```sh
cd $CELL
saw saw/parser-measure.saw > logs/parser-measure.log 2>&1; echo "exit=$?"
grep -c "Proof succeeded" logs/parser-measure.log     # 5
```

## 3. Negative control (must fail)

```sh
cd $CELL
saw saw/parser-measure-negative.saw > logs/parser-measure-negative.log 2>&1; echo "exit=$?"
tail -2 logs/parser-measure-negative.log              # Proof failed.
```

## 4. O-PVCHRET edge (must stop at `_Znwm`)

```sh
cd $CELL
saw saw/parser-ret-gap.saw > logs/parser-ret-gap.log 2>&1; echo "exit=$?"
grep -n "_Znwm" logs/parser-ret-gap.log
```

Expected lines: `Subgoal failed: … in _ZNSt15__new_allocatorIhE8allocateEmPKv`,
`Failed to load function handle: _Znwm`, `Proof failed.` with counterexample
`n: 128`.

## 5. Lean loop-control development

```sh
cd $CELL/lean
lean LoopMeasure.lean > ../logs/lean-check.log 2>&1; echo "exit=$?"
grep -c "sorryAx" ../logs/lean-check.log              # 0
grep -E "depends on axioms" ../logs/lean-check.log    # propext / Quot.sound / Classical.choice only
```

No `lake` project and no Mathlib are needed: the file is core Lean 4 and is
checked directly by `lean`.

## 6. Hashes

```sh
cd $CELL
sha256sum -c SHA256SUMS
```

## 7. Commit

```sh
cd /tmp/opencode/wave65/27-e5-whole
git add spec/equiv/findings/wave65/27-e5-whole
git status --porcelain      # only cell-local paths
git commit -m "wave65/27: E5 whole-EvalScript C1 loop measure + real-IR parser proofs"
```
