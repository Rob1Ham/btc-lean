# Exact commands

All work was done in `/tmp/opencode/wave64/45-e5-exceptions-pcore01` (branch
`wave64/45-e5-exceptions-pcore01`, base `5946c02`). Scratch trees and build
outputs are under `work/`; they are not committed. The coarse worklog is
`work/build_legs.log` and the raw test outputs copied into `results/`.

## 0. Trees and patches

```sh
cd /tmp/opencode/wave64/45-e5-exceptions-pcore01
mkdir -p work
git clone --shared --no-checkout /tmp/opencode/equiv-work/bitcoin work/core
cd work/core && git checkout --detach cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
# generated build header used by the registry build
mkdir -p build-ir/src
cp /tmp/opencode/wave16b-scratch/10-patch-diff/baseline/build-ir/src/bitcoin-build-config.h build-ir/src/

# P-CORE-01 tree
git apply ../patches/P-CORE-01-scriptnum-error-returns.patch
cp -a src ../core-p1/src; cp -a build-ir ../core-p1/build-ir
git checkout -- src/script/interpreter.cpp src/script/script.h

# amended tree
cp -a src ../core-p1-amend/src; cp -a build-ir ../core-p1-amend/build-ir
cd ../core-p1-amend
sed -n '/^--- a\//,$p' ../patches/P-CORE-01-amendment.proposal.patch \
  | git apply -p1
```

(`git apply` works in `core-p1-amend` because it has no `.git` of its own and
resolves against the enclosing repository; for the committed reproduction use
`patch -p1 -N -r - < P-CORE-01-amendment.patch` from the amended tree root.)

## 1. Compile the interpreter at the pin

```sh
cd work/core
/usr/bin/clang++-20 -O0 -g0 -std=c++20 -fexceptions -emit-llvm -c \
  src/script/interpreter.cpp -I src -o ../base-interpreter-pin.bc
# f5718af79c56ccfd5a5437a313d957573cb87c0de0cdf5641013991268801b2c

cd ../core-p1
/usr/bin/clang++-20 -O0 -g0 -std=c++20 -fexceptions \
  -DBTC_EQUIV_NO_SCRIPTNUM_THROW -emit-llvm -c \
  src/script/interpreter.cpp -I src -o ../p1-interpreter-rel.bc
# 2c23631fbe4970de8dd44a7ca05033c4781eb73b85098532db26e1e5fa749a41

cd ../core-p1-amend
/usr/bin/clang++-20 -O0 -g0 -std=c++20 -fexceptions \
  -DBTC_EQUIV_NO_SCRIPTNUM_THROW -emit-llvm -c \
  src/script/interpreter.cpp -I src -o ../p1amend-interpreter-rel.bc
# 4583a46dd76bfe2ed2b63393c071a21a53986e7e38c873c9b11b8163d358af5b
```

No-macro check: compile the amended tree without the define and compare
`llvm-dis` output against the upstream IR after normalizing only the
`__assert_fail` line-number operands. Result: identical.

Warning check: `-Wall -Wextra -fsyntax-only` gives 44 warnings for each of the
three trees; `diff` of the sorted warning sets is empty.

Composition check:

```sh
cd work
cp -a core/src core-p123-amend/; cp -a core/build-ir core-p123-amend/
cd core-p123-amend
for p in P-CORE-01-scriptnum-error-returns P-CORE-02-devirtualize-checker \
         P-CORE-03-hoist-evalscript-statics P-CORE-01-amendment; do
  patch -p1 -N -r - < "$W/$p.patch"
done
/usr/bin/clang++-20 -O0 -g0 -std=c++20 -fexceptions \
  -DBTC_EQUIV_NO_SCRIPTNUM_THROW -DBTC_EQUIV_HOIST_STATICS \
  -DBTC_EQUIV_DEVIRT -emit-llvm -c src/script/interpreter.cpp -I src \
  -o ../p123amend-interpreter.bc
# ea878eae7cbf7d542b62821650f67aeea71b3edf1fd7133146dc673a44b573db
/usr/lib/llvm-20/bin/opt -passes=verify -disable-output ../p123amend-interpreter.bc
```

## 2. C-leg shared libraries

```sh
cd work
JOBS=12 ./build_legs.sh
# baseline  f3f32d635d4086efbb53ca9bb2f25d8f390a4727bd7c05c356a8e326737dbc2f
# p01       637e9bf5995edcf4f476ae13b4708d7926d5b91993673262f1313c5acc19d09b
# p01amend  0dcee4c898483c654d0d5ffcca061d1829ae68bea04ec34c38e7400de30c6e7d
```

`build_legs.sh` uses the registry file set, the real
`spec/equiv/shims/core/entry.cpp`, `-O0 -g0`, and the same generated
`bitcoin-build-config.h` for all three legs.

## 3. Predicate check

```sh
cd work/predcheck
mkdir -p inc/script
cp ../core-p1-amend/src/script/script.h inc/script/script.h
/usr/bin/clang++-20 -O2 -std=c++20 -DBTC_EQUIV_NO_SCRIPTNUM_THROW \
  -I inc -I ../core-p1-amend/src predcheck.cpp -o predcheck
./predcheck
# checks=11700356 failures=0
```

## 4. Corpus and fuzz differential

```sh
cd work
mkdir -p results/corpus results/fuzz
python3 diff_corpus.py \
  --baseline lib/libequiv-core-baseline.so \
  --variant p01=lib/libequiv-core-p01.so \
  --variant p01amend=lib/libequiv-core-p01amend.so \
  --out results/corpus
# 1258/1258 equal for both variants, 0 divergent

H=$(sha256sum fuzz_diff.cpp | cut -d' ' -f1)
g++ -std=c++20 -O2 -DGENERATOR_SHA256="\"$H\"" -o fuzz_diff \
  fuzz_diff.cpp -ldl -lcrypto
./fuzz_diff --baseline lib/libequiv-core-baseline.so \
  --variant p01=lib/libequiv-core-p01.so \
  --variant p01amend=lib/libequiv-core-p01amend.so \
  --n 1000000 --seed 0x16b10 --out results/fuzz/summary.json
# cases_with_divergence=0, divergent_calls=0
```

`diff_corpus.py` is the wave16b/10-patch-diff harness with its `SPEC` path
rebased onto this repository's `spec/`; `fuzz_diff.cpp` is unchanged except
for the source hash baked at build time.

## 5. Directed site and throw/OOM tests

```sh
cd work
for leg in baseline p01 p01amend; do
  case $leg in
    baseline)  tree=core ;;
    p01)       tree=core-p1 ;;
    p01amend)  tree=core-p1-amend ;;
  esac
  /usr/bin/clang++-20 -std=c++20 -O0 -g0 \
    -I $tree/src -I $tree/build-ir/src -I $tree/src/secp256k1/include \
    -c sites_driver.cpp -o obj/$leg/sites.o
  /usr/bin/clang++-20 -std=c++20 -O0 -g0 -o bin-sites-$leg \
    obj/$leg/sites.o obj/$leg/core-*.o obj/$leg/test_stubs.o obj/secp/*.o
  /usr/bin/clang++-20 -std=c++20 -O0 -g0 \
    -I $tree/src -I $tree/build-ir/src -I $tree/src/secp256k1/include \
    -c throw_oom_driver.cpp -o obj/$leg/driver.o
  /usr/bin/clang++-20 -std=c++20 -O0 -g0 -o bin-throw-oom-$leg \
    obj/$leg/driver.o obj/$leg/core-*.o obj/$leg/test_stubs.o obj/secp/*.o
done
./bin-sites-baseline > /tmp/sites.base
./bin-sites-p01 > /tmp/sites.p01
./bin-sites-p01amend > /tmp/sites.amend
diff /tmp/sites.base /tmp/sites.p01amend   # empty
./bin-throw-oom-baseline
./bin-throw-oom-p01
./bin-throw-oom-p01amend
```

## 6. E5 probe module `m3a.bc`

```sh
cd work/core
/usr/bin/clang++-20 -O0 -g0 -std=c++20 -fexceptions -emit-llvm -c \
  src/script/script.cpp -I src -o ../script-O0.bc
# 657530a8d18741b40e09653a681c5d11438ed453bcccf8bde14f0b2037a6d51c

cd ../e5probe
/usr/lib/llvm-20/bin/llvm-as stub-fns.ll -o stub-fns.bc
/usr/lib/llvm-20/bin/llvm-link ../p1amend-interpreter-rel.bc \
  ../script-O0.bc stub-fns.bc -o m3a-raw.bc
/usr/lib/llvm-20/bin/llvm-dis m3a-raw.bc -o m3a-raw.ll
python3 defglob.py m3a-raw.ll m3a-def.ll
/usr/lib/llvm-20/bin/llvm-as m3a-def.ll -o m3a-base.bc
/usr/lib/llvm-20/bin/llvm-dis m3a-base.bc -o m3a-base.ll
python3 mkm.py m3a-base.ll m3a.ll patched-explicit
/usr/lib/llvm-20/bin/llvm-as m3a.ll -o m3a.bc
/usr/lib/llvm-20/bin/opt -passes=verify -disable-output m3a.bc
# 78b1b47f2d03fed464480acd7e006310857997d5963116858730f45ad88f1ad5
```

Then:

```sh
/opt/equiv-tools/saw-1.6/bin/saw spec-b4-throw-pcore01-amend.saw
# Proof succeeded! (EvalScript OP_1ADD 5-byte -> SCRIPT_ERR_SCRIPTNUM)

sed 's|m2.bc|m3a.bc|' spec-vs-empty-m2.saw > spec-vs-empty-m3a.saw
/opt/equiv-tools/saw-1.6/bin/saw spec-vs-empty-m3a.saw
# Proof succeeded! (VerifyScript empty -> SCRIPT_ERR_EVAL_FALSE)

/opt/equiv-tools/saw-1.6/bin/saw spec-vs-scriptnum-m3a.saw
# Symbolic execution failed: Failed to load function handle: _Znwm
```

`spec-vs-scriptnum-m3a.saw` is generated from `spec-vs-empty-m3a.saw` by
encoding `scriptSig = 05 01 02 03 04 05` (PUSH5 `[1,2,3,4,5]`) and
`scriptPubKey = 8b` (OP_1ADD), expected `(false, SCRIPT_ERR_SCRIPTNUM)`.

## 7. Alive2

```sh
/usr/local/bin/alive-tv p1amend-interpreter-rel.bc \
  --func='_Z12VerifyScriptRK7CScriptS1_PK14CScriptWitness19script_verify_flagsRK20BaseSignatureCheckerP13ScriptError_t' \
  --passes=verify --skip-smt
# ERROR: Unsupported instruction: ... invoke ...
/usr/local/bin/alive-tv p1amend-interpreter-rel.bc \
  --func='_Z10EvalScriptRSt6vectorIS_IhSaIhEESaIS1_EERK7CScript19script_verify_flagsRK20BaseSignatureChecker10SigVersionR19ScriptExecutionDataP13ScriptError_t' \
  --passes=verify --skip-smt
# ERROR: Unsupported instruction: ... load atomic ... __cxa_guard ...
# erased form (erase_exceptions.py), for contrast only:
python3 e5probe/erase_exceptions.py p1amend-interpreter-rel.ll erased.ll
/usr/lib/llvm-20/bin/llvm-as erased.ll -o erased.bc
/usr/local/bin/alive-tv erased.bc --func='...VerifyScript...' \
  --passes=verify --skip-smt
# Transformation seems to be correct! (syntactically equal)  [not a proof]
```
