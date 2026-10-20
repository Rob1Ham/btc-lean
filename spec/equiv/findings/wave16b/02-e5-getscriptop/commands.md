# Exact commands — wave16B `02-e5-getscriptop`

Worktree: `/tmp/opencode/wave16b/02-e5-getscriptop`
Prototype: `spec/equiv/cells/e5-whole/PROTO-w16b-getscriptop`

## Tools (versions)

```sh
/opt/equiv-tools/saw-1.6/bin/saw --version       # 1.6 (68eed5f release-1.6)
/usr/bin/clang++-20 --version | head -1          # Ubuntu clang version 20.1.2
/usr/lib/llvm-20/bin/llvm-link --version         # LLVM 20.1.2
```

## 1. Build the pinned linked probe module

```sh
cd spec/equiv/cells/e5-whole/PROTO-w16b-getscriptop
./builder/build-pinned-linked.sh                    # logs/build-pinned-linked.raw.log
```

Inputs are asserted inside the script:
- `ir20/interpreter-O0.bc` must hash to `f5718af7...` (`PINS.lock [core.ir]`);
- the Core tree must be at `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`.

The script compiles the real `src/script/script.cpp`, links it, erases
exception edges, internalises to the five-symbol API, stubs three ABI globals
and pins three `__cxa_guard` variables to 1. Outputs go to `build/out/`
(gitignored). Exact per-stage hashes are printed and are also in
`logs/build-pinned-linked.raw.log`.

## 2. Run every proof / probe

```sh
./run-all.sh                                      # logs/*.raw.log
cat logs/RUN-EXIT-CODES.txt
```

## 3. Negative controls (must fail)

```sh
for f in neg/*.saw; do
  /opt/equiv-tools/saw-1.6/bin/saw "$f"
done
```

## 4. Individual headline runs

```sh
# Real parser, concrete OP_1
/opt/equiv-tools/saw-1.6/bin/saw saw/e5b-gso-op1-concrete.saw

# Real parser, symbolic over all 256 one-byte scripts
/opt/equiv-tools/saw-1.6/bin/saw saw/e5b-gso-symbolic-1byte.saw

# Real parser, symbolic non-push first byte, 4-byte window
/opt/equiv-tools/saw-1.6/bin/saw saw/e5b-gso-symbolic-nonpush-4byte.saw

# First non-empty-script VerifyScript proofs (no override)
/opt/equiv-tools/saw-1.6/bin/saw saw/e5b-verifyscript-nop-linked3pin.saw
/opt/equiv-tools/saw-1.6/bin/saw saw/e5b-verifyscript-nop2-linked3pin.saw
/opt/equiv-tools/saw-1.6/bin/saw saw/e5b-verifyscript-opreturn-linked3pin.saw

# Verified GetScriptOp summary used as a compositional override
/opt/equiv-tools/saw-1.6/bin/saw saw/e5b-verifyscript-nop-with-gso-override.saw

# B1 before/after and the B2 stop
/opt/equiv-tools/saw-1.6/bin/saw saw/e5b-verifyscript-op1-patchedroots.saw
/opt/equiv-tools/saw-1.6/bin/saw saw/e5b-verifyscript-op1-linked3pin.saw

# Unpatched linked module (B4 setup failure)
/opt/equiv-tools/saw-1.6/bin/saw saw/e5b-verifyscript-op1-rawlinked.saw

# Parser push path: B2 with an empty vector, SAW intrinsic gap with capacity
/opt/equiv-tools/saw-1.6/bin/saw saw/e5b-gso-push2-empty.saw
/opt/equiv-tools/saw-1.6/bin/saw saw/e5b-gso-push2-capacity.saw
```

## 5. Compile the parser TU by hand (no script)

```sh
cd /tmp/opencode/equiv-work/bitcoin        # Core pin cce32b16, clean
/usr/bin/clang++-20 -std=c++20 -O0 -g0 -emit-llvm -c \
  -I src -I build-ir/src -I src/secp256k1/include -I src/univalue/include \
  src/script/script.cpp -o /tmp/script-O0.bc
sha256sum /tmp/script-O0.bc
# 657530a8d18741b40e09653a681c5d11438ed453bcccf8bde14f0b2037a6d51c
```

The hash is byte-identical to `ir/script-O0.bc` in the E5 residual.
