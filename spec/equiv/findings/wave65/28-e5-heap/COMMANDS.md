# Exact commands — wave65/28 E5 guard model

All work ran in `/tmp/opencode/wave65/28-e5-heap` (branch
`wave65/28-e5-heap`, base `76dbfe5e42f8a337e41a7308158b0de078afafd9`).
Scratch modules live in `/tmp/opencode/wave65/28-e5-heap-scratch`; no other
agent's tree and no pinned artifact was modified.

## 0. Tools (hashes of the exact binaries used)

| tool | version | sha256 |
|---|---|---|
| SAW | `1.6 (68eed5f release-1.6)` | `ca07da51c8f1ea98f91b6faf723f9ec795d908bf2c90f63eff57e97c7c2e7220` |
| Alive2 | `v20.0 (c0f5434), Ubuntu LLVM 20.1.2` | `91d9c14af27444c5248b948437b64e9dc7b0ed63d1bf478305a1e9cef2ed50ff` |
| clang++ | `Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)` | `/usr/bin/clang++-20` |
| LLVM tools | `/usr/lib/llvm-20/bin/{llvm-as,llvm-dis,llvm-link}` | 20.1.2 |
| Python | 3.12.3 | — |

```sh
/opt/equiv-tools/saw-1.6/bin/saw --version      # 1.6 (68eed5f release-1.6)
/usr/local/bin/alive-tv --version               # prints "Ubuntu LLVM version 20.1.2"
```

## 1. Inputs (PINS.lock carriers, hash-checked by build.sh)

| input | sha256 |
|---|---|
| `[core.ir]` single-TU `ir20/interpreter-O0.bc` | `f5718af79c56ccfd5a5437a313d957573cb87c0de0cdf5641013991268801b2c` |
| `[ir]` closure `ir-pipeline/artifacts/core-interpreter-O0.bc` | `204cf6711ca56738eccd9d8034fe40e39b01e6f070e286f0882d3fd5956c0975` |
| `script.cpp` at pin, same flags | `657530a8d18741b40e09653a681c5d11438ed453bcccf8bde14f0b2037a6d51c` |
| Core source tree HEAD | `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` |

The `script.cpp` hash was reproduced from a clean tree with:

```sh
cd /tmp/opencode/equiv-work/bitcoin
/usr/bin/clang++-20 -std=c++20 -O0 -g0 -emit-llvm -c \
  -I src -I build-ir/src -I src/secp256k1/include -I src/univalue/include \
  src/script/script.cpp -o /tmp/opencode/wave65/28-e5-heap-scratch/script-O0.bc
sha256sum .../script-O0.bc
# 657530a8d18741b40e09653a681c5d11438ed453bcccf8bde14f0b2037a6d51c
```

Note: compiling with an absolute source path produces a different bitcode
hash (`4870cc7b…`) because the module identifier embeds the path. The build
script compiles from the tree root with relative paths, matching `PINS.lock`.

## 2. Build

```sh
cd /tmp/opencode/wave65/28-e5-heap
spec/equiv/findings/wave65/28-e5-heap/harness/build.sh
```

`build.sh` performs, in order:

1. hash-checks both carriers and the Core tree HEAD;
2. compiles `script.cpp` (single-TU B1 closure);
3. assembles `harness/abi-stub-singletu.ll` and `harness/abi-stub-closure.ll`
   (the 7 undefined ABI globals per carrier);
4. generates `model-{128,66,65}.ll` from `models/cell-model.ll.tmpl`;
5. links `singletu-link.bc = interpreter-O0.bc + script-O0.bc + stub` and
   `singletu-model-$CAP.bc = singletu-link.bc + model-$CAP.bc`;
6. links `closure-model-{128,66,65}.bc = closure + stub + model`;
7. derives the pinned-guard controls `singletu-pinned.ll` / `closure-pinned.ll`
   (guards → `constant i64 1`, static objects → `constant`, replacing exactly
   4 guard defs and 3 object defs);
8. writes `logs/build-hashes.txt`.

Resulting module hashes (`logs/build-hashes.txt`):

| module | sha256 |
|---|---|
| `singletu-link.bc` | `243aecd052e9bafbc49d35c3491eece0be74b84e2b4499b926c7934036445a3d` |
| `singletu-model-128.bc` | `6356f54d9090cdc0ea3091ce1e75284ff1ac82da55b77ee6038e6e6ee3c22b96` |
| `singletu-model-66.bc` | `fdbfae7a0543562c4c8fac9593d7f62b2cd990b9a685962c25be7ef41ccb387a` |
| `singletu-model-65.bc` | `638d9d782082f7adadbd4ed27cf5df5167caa649af9ddae48a84f22777e4014c` |
| `singletu-pinned.bc` | `5176d37173cccf6a901f7f68a8b71c60d0d291647f4ccd1aeda4d843a106d2f3` |
| `closure-model-128.bc` | `28b0b1f60518c7baa17d93d96493501b1f8465e3a7bde545573db462dadb1503` |
| `closure-model-66.bc` | `c22246dfd41c5676cae47bb4ca9db0625462ca6e14f49ba6dd6a1cbc0858ca5b` |
| `closure-model-65.bc` | `db0264384e609030a189c9499fed6b36da8e348bbaec1148cb7a6e4b8be7517f` |
| `closure-pinned.bc` | `6f9d89d8f84dea386fe728f28fed7a16ac2926db69bd85cff00ba8664386ae94` |
| `model-128.bc` | `6db835e759cb0212ef093748afb94c66ebb615dceb3520dcde583b1f67190840` |
| `model-66.bc` | `5650dc4fabb233af8b9cf825a00ab8e1cff70009d69045754ee142f18c394cd0` |
| `model-65.bc` | `9d9844dfd13a2bd52b7a0ef2c9642f0d48807c3f3c547d364061911383f96408` |

`build.sh` is idempotent: rerunning from the same inputs reproduces every hash
above.

## 3. Generate the committed specs

```sh
cd /tmp/opencode/wave65/28-e5-heap
python3 spec/equiv/findings/wave65/28-e5-heap/models/gen-specs.py \
  /tmp/opencode/wave65/28-e5-heap-scratch \
  spec/equiv/findings/wave65/28-e5-heap/specs
# wrote 11 specs
```

The specs embed absolute `$OUT` module paths (the repo's established SAW-cell
pattern). Regenerate after changing `$OUT`.

## 4. Run and assert

```sh
spec/equiv/findings/wave65/28-e5-heap/harness/run-all.sh
```

Observed (tail):

```
singletu-op1.saw                                 expect=proved  rc=0 PASS
singletu-op1add.saw                              expect=proved  rc=0 PASS
singletu-op1sub.saw                              expect=proved  rc=0 PASS
closure-op1add.saw                               expect=proved  rc=0 PASS
closure-op1sub.saw                               expect=proved  rc=0 PASS
closure-op1add-cap66.saw                         expect=proved  rc=0 PASS
neg-singletu-op1sub-expect-true.saw              expect=failed  rc=2 PASS
neg-closure-pinned-op1sub-expect-false.saw       expect=failed  rc=2 PASS
neg-closure-op1add-cap65.saw                     expect=throw   rc=2 PASS
pinned-singletu-op1sub.saw                       expect=proved  rc=0 PASS
pinned-closure-op1sub.saw                        expect=proved  rc=0 PASS

ALL EXPECTATIONS MET
```

Each spec is `llvm_verify m verify_script [] false <setup> z3`. No
`llvm_unsafe_assume_spec`, no `llvm_unsafe_...` of any kind.

Expected failure messages, quoted from the logs:

```
# neg-singletu-op1sub-expect-true.log
Proof failed.          # OP_1SUB correctly returns false

# neg-closure-op1add-cap65.log
Abort due to assertion failure:
  internal: error: in _Znwm
  Failed to load function handle: _ZSt17__throw_bad_allocv

# neg-closure-pinned-op1sub-expect-false.log
Proof failed.          # pinned guards return true (divergence)
```

## 5. Alive2 ingest checks

```sh
spec/equiv/findings/wave65/28-e5-heap/harness/alive2.sh
```

Observed:

```
verifyScript closure rc=1
ERROR: Unsupported instruction:   %109 = invoke … @_Z10EvalScript…
ERROR: Could not translate 'VerifyScript' to Alive IR
  1 Alive2 errors

_Znwm                 : 1 correct, 0 errors  (syntactically equal; translation only)
__cxa_guard_acquire   : 1 correct, 0 errors  (syntactically equal; translation only)
__cxa_guard_release   : 1 correct, 0 errors  (syntactically equal; translation only)
```

Alive2 does **not** ingest the engine result. The leaf lines are
self-comparisons, not proofs.

## 6. `invoke` semantics micro-probe

```sh
spec/equiv/findings/wave65/28-e5-heap/harness/probe-invoke.sh
# normal-edge(return 1) rc=0 : Proof succeeded! f
# unwind-edge(return 2) rc=2 : Proof failed.
```

SAW 1.6 executes `invoke` as a non-unwinding call. This is why B4 is unchanged
and why dropping `erase_exceptions.py` needed no new assumption.

## 7. Inventory

```sh
llvm-dis-20 /tmp/opencode/equiv-work/ir20/interpreter-O0.bc \
  -o /tmp/opencode/wave65/28-e5-heap-scratch/pinned-interpreter-O0.ll
python3 spec/equiv/findings/wave65/28-e5-heap/harness/inventory.py \
  /tmp/opencode/wave65/28-e5-heap-scratch/pinned-interpreter-O0.ll \
  > spec/equiv/findings/wave65/28-e5-heap/logs/inventory-singleTU.txt

llvm-dis-20 /tmp/opencode/ir-pipeline/artifacts/core-interpreter-O0.bc \
  -o /tmp/opencode/wave65/28-e5-heap-scratch/closure-O0.ll
python3 spec/equiv/findings/wave65/28-e5-heap/harness/inventory.py \
  /tmp/opencode/wave65/28-e5-heap-scratch/closure-O0.ll \
  > spec/equiv/findings/wave65/28-e5-heap/logs/inventory-closure.txt
```

The disassembled text IR is not committed; it is regenerable from the pinned
bitcode, and its hash depends on `llvm-dis` formatting, not on the pin.
