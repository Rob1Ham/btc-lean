# CORE-IR reproduction commands

All paths below are the CORE-IR work area. Bitcode is regenerable and is not
tracked (`spec/equiv/.gitignore` ignores `*.bc`). Logs in
`findings/core/logs/` are the exact outputs of these commands unless noted.

Environment:

```
Bitcoin Core  cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66 (v32.99)
clang/LLVM   20.1.2  (/usr/bin/clang++-20, /usr/lib/llvm-20/bin)
Alive2       v20.0   (/opt/equiv-tools/alive-tv-v20.0)
SAW          1.6      (/opt/equiv-tools/saw-1.6; PATH must include bin/)
z3           4.8.12 (system build for Alive2); SAW bundle also ships 4.8.14
cmake        3.28.3
python       3.12.3
```

## 0. Pinned clone

```sh
mkdir -p /tmp/opencode/equiv-work/bitcoin
cd /tmp/opencode/equiv-work/bitcoin
git init
git remote add origin https://github.com/bitcoin/bitcoin.git
git fetch --depth 1 origin cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
git checkout FETCH_HEAD

git rev-parse HEAD
# cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
git status --porcelain
# (empty)
```

The primary lane does not require a full build. A CMake configure was used
once to emit `build-ir/src/bitcoin-build-config.h`; the final reproducibility
clone (`/tmp/opencode/equiv-work/verify-tree`) did **not** have that file and
still produced the same bitcode hash.

## 1. Unpatched bitcode (clang 20.1.2)

```sh
cd /tmp/opencode/equiv-work/bitcoin
mkdir -p /tmp/opencode/equiv-work/ir20

/usr/bin/clang++-20 -std=c++20 -O0 -g0 -emit-llvm -c \
  -I src -I build-ir/src -I src/secp256k1/include -I src/univalue/include \
  src/script/interpreter.cpp \
  -o /tmp/opencode/equiv-work/ir20/interpreter-O0.bc

/usr/bin/clang++-20 -std=c++20 -O1 -g0 -emit-llvm -c \
  -I src -I build-ir/src -I src/secp256k1/include -I src/univalue/include \
  src/script/interpreter.cpp \
  -o /tmp/opencode/equiv-work/ir20/interpreter-O1.bc

/usr/bin/clang++-20 -std=c++20 -O0 -g0 -ftrapv -emit-llvm -c \
  -I src -I build-ir/src -I src/secp256k1/include -I src/univalue/include \
  src/script/interpreter.cpp \
  -o /tmp/opencode/equiv-work/ir20/interpreter-O0-ftrapv.bc
```

Disassemble with **LLVM 20** only:

```sh
cd /tmp/opencode/equiv-work/ir20
for f in *.bc; do /usr/lib/llvm-20/bin/llvm-dis "$f" -o "${f%.bc}.ll"; done
sha256sum *.bc
```

Hashes:

```
f5718af79c56ccfd5a5437a313d957573cb87c0de0cdf5641013991268801b2c  interpreter-O0.bc
01003ec095441bad8ada96ed1effa860f84bda23802841c7d7eb15b2e554537f  interpreter-O1.bc
714ad532b43be61c0f4fdc8f0ef9e45d36cae0b538e9f67cd8665511a6b5c576  interpreter-O0-ftrapv.bc
```

`-DDEBUG -DDEBUG_LOCKORDER -DDEBUG_LOCKCONTENTION
-DABORT_ON_FAILED_ASSUME` do not change the O0 hash. `-fno-exceptions`
`-fno-exceptions` emits 20 errors before the compiler error limit (all
`cannot use 'throw' with exceptions disabled` in `util/check.h`,
`serialize.h`, `util/string.h`, `util/strencodings.h`, `uint256.h`) and is
not used. The log is `findings/core/logs/fno-exceptions.log`. Reproduce:

```sh
/usr/bin/clang++-20 -std=c++20 -O0 -g0 -fno-exceptions -emit-llvm -c \
  -I src -I build-ir/src -I src/secp256k1/include -I src/univalue/include \
  src/script/interpreter.cpp -o /tmp/interpreter-O0-noexc.bc \
  > /tmp/fno-exceptions.log 2>&1
```

## 2. Prototype patch tree

A separate clone was used so the pinned checkout stays clean:

```sh
cd /tmp/opencode/equiv-work
git clone --shared bitcoin bitcoin-proto
cd bitcoin-proto
git apply ../P-CORE-01-scriptnum-error-returns.patch.new
git apply ../P-CORE-02-devirtualize-checker.patch
git apply ../P-CORE-03-hoist-evalscript-statics.patch.new
```

(The `.new` files are the final registry patches; they were copied to
`spec/equiv/patches/core/` under the canonical names.)

Patched compile:

```sh
M='-DBTC_EQUIV_NO_SCRIPTNUM_THROW -DBTC_EQUIV_HOIST_STATICS -DBTC_EQUIV_DEVIRT'
cd /tmp/opencode/equiv-work/bitcoin-proto
mkdir -p /tmp/opencode/equiv-work/ir20-proto

/usr/bin/clang++-20 -std=c++20 -O0 -g0 $M -emit-llvm -c \
  -I src -I build-ir/src -I src/secp256k1/include -I src/univalue/include \
  src/script/interpreter.cpp \
  -o /tmp/opencode/equiv-work/ir20-proto/interpreter-O0-patched.bc

/usr/bin/clang++-20 -std=c++20 -O1 -g0 $M -emit-llvm -c \
  -I src -I build-ir/src -I src/secp256k1/include -I src/univalue/include \
  src/script/interpreter.cpp \
  -o /tmp/opencode/equiv-work/ir20-proto/interpreter-O1-patched.bc

/usr/bin/clang++-20 -std=c++20 -O0 -g0 -DBTC_EQUIV_HOIST_STATICS \
  -emit-llvm -c \
  -I src -I build-ir/src -I src/secp256k1/include -I src/univalue/include \
  src/script/interpreter.cpp \
  -o /tmp/opencode/equiv-work/ir20-proto/interpreter-O0-hoistonly.bc
```

Disassemble:

```sh
cd /tmp/opencode/equiv-work/ir20-proto
for f in *.bc; do /usr/lib/llvm-20/bin/llvm-dis "$f" -o "${f%.bc}.ll"; done
```

Hashes:

```
5993460463314028bf1225784bbbcaa28dab7ab6fec979a17907a369cba302c7  interpreter-O0-patched.bc
deebc447a4c2665efb6f83065420a099abdbaea1577d1c14b7822bfe003bfe6f  interpreter-O1-patched.bc
984177bd7a04ca402e0e3b6dbb60626b2be8c22abf2e5e3d2176678558b71819  interpreter-O0-hoistonly.bc
```

## 3. Patch-application reproducibility

```sh
cd /tmp/opencode/equiv-work/verify-tree
git checkout -f .          # cce32b168, clean
for p in \
  ../P-CORE-01-scriptnum-error-returns.patch.new \
  ../P-CORE-02-devirtualize-checker.patch \
  ../P-CORE-03-hoist-evalscript-statics.patch.new; do
    git apply --check "$p" && echo "alone-ok $p"
done
git apply ../P-CORE-01-scriptnum-error-returns.patch.new
git apply ../P-CORE-02-devirtualize-checker.patch
git apply ../P-CORE-03-hoist-evalscript-statics.patch.new \
  && echo SEQUENCE-APPLIED

for f in src/script/interpreter.cpp src/script/interpreter.h src/script/script.h; do
    cmp "$f" "../bitcoin-proto/$f" && echo "same $f"
done
```

Compile the fresh patched tree:

```sh
cd /tmp/opencode/equiv-work/verify-tree
/usr/bin/clang++-20 -std=c++20 -O0 -g0 \
  -DBTC_EQUIV_NO_SCRIPTNUM_THROW -DBTC_EQUIV_HOIST_STATICS -DBTC_EQUIV_DEVIRT \
  -emit-llvm -c \
  -I src -I build-ir/src -I src/secp256k1/include -I src/univalue/include \
  src/script/interpreter.cpp \
  -o /tmp/opencode/equiv-work/ir20-proto/verify-tree-O0-patched.bc

sha256sum /tmp/opencode/equiv-work/ir20-proto/verify-tree-O0-patched.bc
# 5993460463314028bf1225784bbbcaa28dab7ab6fec979a17907a369cba302c7
```

## 4. Exception erasure and internalization

```sh
cd /tmp/opencode/equiv-work

python3 erase_exceptions.py \
  ir20-proto/interpreter-O0-patched.ll \
  ir20-proto/interpreter-O0-patched-noexc.ll
# converted invokes: 683, neutralised landingpad blocks: 202

/usr/lib/llvm-20/bin/llvm-as \
  ir20-proto/interpreter-O0-patched-noexc.ll \
  -o ir20-proto/interpreter-O0-patched-noexc.bc

/usr/lib/llvm-20/bin/opt -passes=simplifycfg \
  ir20-proto/interpreter-O0-patched-noexc.bc \
  -o ir20-proto/interpreter-O0-patched-noexc-s.bc

/usr/lib/llvm-20/bin/llvm-dis \
  ir20-proto/interpreter-O0-patched-noexc-s.bc \
  -o ir20-proto/interpreter-O0-patched-noexc-s.ll

sha256sum ir20-proto/interpreter-O0-patched-noexc-s.bc
# 3bfeecfb06cbecf41aa9edbf6cfe3c2c448f8e8df58d877e7936e4f965a33003
```

Internalize to a five-symbol public API:

```sh
API='_Z10CastToBoolRKSt6vectorIhSaIhEE,_Zor19script_verify_flagsS_,_Z10EvalScriptRSt6vectorIS_IhSaIhEESaIS1_EERK7CScript19script_verify_flagsRK20BaseSignatureChecker10SigVersionR19ScriptExecutionDataP13ScriptError_t,_ZNK10CScriptNum6getintEv,_Z12VerifyScriptRK7CScriptS1_PK14CScriptWitness19script_verify_flagsRK20BaseSignatureCheckerP13ScriptError_t'

/usr/lib/llvm-20/bin/opt -passes=internalize,globaldce \
  -internalize-public-api-list="$API" \
  ir20-proto/interpreter-O0-patched-noexc-s.bc \
  -o ir20-proto/roots.bc

/usr/lib/llvm-20/bin/llvm-dis ir20-proto/roots.bc -o ir20-proto/roots.bc.ll
sha256sum ir20-proto/roots.bc
# 2b9f683c4fdd3550e4eab43083a4c528ce785d37956f0f24b75311ec756f04a8
```

`roots.bc` has 616 `define`s, 52 `declare`s, and 0 undefined ABI vtable
globals.

## 5. Alive2

Function name variables used below:

```sh
EVAL='_Z10EvalScriptRSt6vectorIS_IhSaIhEESaIS1_EERK7CScript19script_verify_flagsRK20BaseSignatureChecker10SigVersionR19ScriptExecutionDataP13ScriptError_t'
VERIFY='_Z12VerifyScriptRK7CScriptS1_PK14CScriptWitness19script_verify_flagsRK20BaseSignatureCheckerP13ScriptError_t'
WIT='_ZL20VerifyWitnessProgramRK14CScriptWitnessiRKSt6vectorIhSaIhEE19script_verify_flagsRK20BaseSignatureCheckerP13ScriptError_tb'
CAST='_Z10CastToBoolRKSt6vectorIhSaIhEE'
```

Translation/ingest checks (self-comparison, no SMT):

```sh
cd /tmp/opencode/equiv-work

/opt/equiv-tools/alive-tv-v20.0 --func="$EVAL" --passes=verify --skip-smt \
  ir20/interpreter-O0.bc \
  > logs20/alive2-unpatched-evalscript.log 2>&1

/opt/equiv-tools/alive-tv-v20.0 --func="$EVAL" --passes=verify --skip-smt \
  ir20-proto/interpreter-O0-hoistonly.bc \
  > logs20/alive2-hoistonly-evalscript.log 2>&1

/opt/equiv-tools/alive-tv-v20.0 --func="$EVAL" --passes=verify --skip-smt \
  ir20-proto/interpreter-O0-patched.bc \
  > logs20/alive2-patched-evalscript.log 2>&1

/opt/equiv-tools/alive-tv-v20.0 --func="$EVAL" --passes=verify --skip-smt \
  ir20-proto/interpreter-O0-patched-noexc-s.bc \
  > logs20/alive2-erased-evalscript.log 2>&1

/opt/equiv-tools/alive-tv-v20.0 --func="$VERIFY" --passes=verify --skip-smt \
  ir20-proto/interpreter-O0-patched-noexc-s.bc \
  > logs20/alive2-erased-_Z12VerifyScriptRK7CScriptS1_P.log 2>&1

/opt/equiv-tools/alive-tv-v20.0 --func="$WIT" --passes=verify --skip-smt \
  ir20-proto/interpreter-O0-patched-noexc-s.bc \
  > logs20/alive2-erased-_ZL20VerifyWitnessProgramRK14C.log 2>&1
```

Leaf proof with SMT:

```sh
timeout 300 /opt/equiv-tools/alive-tv-v20.0 \
  --func="$CAST" --always-verify --smt-to=60000 \
  ir20-proto/interpreter-O0-patched-noexc-s.bc \
  > logs20/alive2-leaf-casttobool.log 2>&1
```

Expected: unpatched fails on an atomic guard load; hoist-only and patched fail
on `invoke set_error`; erased functions translate; the leaf proof reports
`Transformation seems to be correct!`.

## 6. SAW

`PATH` must include the bundled binaries so `abc` resolves:

```sh
cd /tmp/opencode/equiv-work
PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw saw20-leaf.saw
PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw saw20-leaf-bad.saw
PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw saw20-load.saw
```

Specs (copied to `findings/core/scripts/saw/`):

```
saw20-load.saw:      m <- llvm_load_module "ir20-proto/roots.bc";
saw20-leaf.saw:      prove _Zor19script_verify_flagsS_ returns x || y
saw20-leaf-bad.saw:  claim the same function returns x (negative control)
```

Expected: load succeeds; leaf `Proof succeeded!`; bad spec fails with
counterexample `x = 9222246136947933183`, `y = 1125899906842624`.

## 7. Inventory and call graph

```sh
cd /tmp/opencode/equiv-work
python3 inventory20.py > ir20-features.tsv
python3 callgraph.py ir20/interpreter-O0.ll > logs20/callgraph-unpatched.log
python3 callgraph.py ir20-proto/interpreter-O0-patched-noexc-s.ll \
  > logs20/callgraph-patched-erased.log
python3 analyze_ir.py ir20/interpreter-O0.ll | head -20
```

`inventory20.py` expects the work-directory layout above. The checked-in copy
is the exact script used.

## 8. Artifact inventory

Checked-in under `findings/core/`:

```
core-ir-report.md                  this narrative
commands.md                        this file
ir-features.tsv                    module + function feature table
hashes.txt                         sha256 of every checked-in artifact
pins-proposal.md                   proposed PINS.lock values
NONPROOF-clang18.txt               retired clang-18 artifacts
handoff-contract-pcore02.md        CONTRACT shim work item
scripts/inventory20.py             feature inventory
scripts/erase_exceptions.py        exception-edge transform
scripts/callgraph.py               static reachability / ptrtoint / externals
scripts/analyze_ir.py              function-level opcode/feature scan
scripts/split_patch.py             patch splitter used for the registry
scripts/mkinventory.py             earlier clang-18 inventory helper
scripts/saw/*.saw                  SAW leaf/load specs
logs/*.log                         exact tool and compile outputs
```

Bitcode and `.ll` files remain under `/tmp/opencode/equiv-work/`; they are
not tracked by design.
