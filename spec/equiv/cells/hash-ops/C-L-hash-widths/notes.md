# hash-ops/C-L-hash-widths

SCR-093 (`RIPEMD160/SHA1/SHA256` output sizes, `20/20/32`) and SCR-095
(hash of the empty element). The cell is **both-tool green** on all five hash
opcodes, with the hash transforms as opaque externals shared by both legs.
Coverage is **full at this cell's scope**: the SHA1 width and empty-element
arm is a reviewed cell-local L handler, labelled as such below. The shared
twin is not changed and still maps wire 0xa7 to result 3; the hash algorithms
remain opaque (same-hash premise) and are not claimed as implementations.

## Source

Pinned Core `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`:

- `src/script/interpreter.cpp:1032-1056` — hash opcode family.
- `src/script/interpreter.cpp:1042` — `vchHash` is 20 bytes for
  RIPEMD160/SHA1/HASH160 and 32 otherwise.
- `src/script/interpreter.cpp:1043-1052` — `CRIPEMD160` / `CSHA1` /
  `CSHA256` / `CHash160` / `CHash256` dispatch.
- `src/script/interpreter.cpp:1053-1054` — `popstack(stack);
  stack.push_back(vchHash);`.
- `twin/ops_ir.py` `OP_RIPEMD160` (0xa6), `OP_SHA256` (0xa8),
  `OP_HASH160` (0xa9), `OP_HASH256` (0xaa).
- `twin/ops_ir.py` `OP_UNSUPPORTED_SHA1` (0xa7) — the shared twin's declared
  unsupported wire, see `twin/generator.md:231,393,407`.
- `twin/runtime.inc:409-564` — hash floor has `sha256`, `ripemd160`,
  `hash160`, `hash256`; no `sha1` primitive.
- `spec/core/Bitcoin/Interpreter/Defs.lean:637-643` — `hashForOp 0xa7 =
  hashSha1`.
- `spec/core/Bitcoin/Interpreter/Hashes.lean:133-157` — `sha1F`/`sha1K`/
  `sha1Compress`/`hashSha1`.
- `spec/proofs/BitcoinProofs/AF/PDW78/PDW78.lean:74-106` —
  `scr093_hashForOp_widths` and `scr095_emptyElement_hashed` (Lean model
  targets cited by the row, not re-proved by this cell).

## Design: two observables

Each opcode/preimage pair is exported twice:

- `cell_<op>_<pre>_meta` — the handler plus pop/push, packed as
  `result | error | depth | pushed length`. Alive2 compares these C/L pairs.
- `cell_<op>_<pre>` — the same handler, packed with the first five digest
  bytes as well. SAW verifies these C/L pairs against concrete overrides.

The split is not cosmetic. Alive2 models a call to an external function as a
write to memory it does not track. A function that then reads the written
bytes returns a poisoned aggregate, and a poisoned aggregate refines
anything. The digest-bearing comparison was therefore **vacuously green**.
Two scratch probes, run outside the committed cell:

```sh
# L pushes 32 for HASH160 while C pushes 20 (mutant: op_hash160 st_push(..., 32))
alive-tv build/c_cell_hash160_empty.ll         /tmp/opencode/hashmut/wm_full.ll
# Summary: 1 correct transformations   <- vacuous: the digest read poisons the value

alive-tv build/c_cell_hash160_empty_meta.ll    /tmp/opencode/hashmut/wm_cell_hash160_empty_meta.ll
# Summary: 0 correct, 1 incorrect
# Source value: #x000000000000a101 (width 20)
# Target value: #x0000000000010101 (width 32)
```

The meta comparison is the real width/plumbing check. SAW recovers the digest
bytes with concrete overrides. Neither tool is asked to do the other's job.

## Concrete witnesses

All values below were recomputed with Python `hashlib` (`sha1`, `sha256`;
`ripemd160` via `hashlib.new('ripemd160', ...)`) and match `src/cell.cry`:

```text
RIPEMD160("")  = 9c1185a5c5e9fc54612808977ee8f548b2258d31
RIPEMD160("a") = 0bdc9d2d256b3ee9daae347be6f4dc835a467ffe
SHA1("")       = da39a3ee5e6b4b0d3255bfef95601890afd80709
SHA1("a")      = 86f7e437faa5a7fce15d1ddcb9eaeaea377667b8
SHA256("")     = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
SHA256("a")    = ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb
HASH160("")    = b472a266d0bd89c13706a4132ccfb16f7c3b9fcb
HASH160("a")   = 994355199e516ff76c4fa4aab39337b9d84cf12b
HASH256("")    = 5df6e0e2761359d30a8275058e299fcc0381534545f55cf43e41983f5d4c9456
HASH256("a")   = bf5d3affb73efd2ec6c36ad3112dd933efed63c4e1cbffcfa88e2759c144f2d8
```

The SAW `llvm_unsafe_assume_spec` overrides pin the input pointer/length and
the full output array to these values. They are assumptions with recorded
witnesses, not derived results.

## L leg: reviewed transliteration

The four implemented handlers (RIPEMD160, SHA256, HASH160, HASH256) are
copied verbatim from `twin/ops_ir.py` (`st_top`/`st_push`/the op bodies).
`mk_leaf.py` emits the same bodies, but its bounded copy is hard-wired to two
bytes, while these handlers push 20 or 32. With `--max-elem 32` mk_leaf
accepts the length and copies only the first two bytes, so its leaf cannot
represent the op. `src/l_leaf.cpp` re-binds only the stack representation:
32-byte slots and the unrolled `h_copy` in `src/hash_common.h`. This is the
same kind of substitution mk_leaf performs, at a width it does not support.
`build/twin_ops.h` is still generated and hashed for provenance; it is not the
compiled L module and it does not contain SHA1.

### SHA1 arm: cell-local, reviewed, not shared-twin

The pinned shared twin has no SHA1 implementation: `twin/ops_ir.py` maps wire
`0xa7` to `OP_UNSUPPORTED_SHA1` (result 3) and `twin/runtime.inc` has no
`sha1` primitive. Editing those files would be a shared twin change and is
outside this cell. Instead `src/l_leaf.cpp` adds a cell-local
`op_sha1` with exactly the same shape as the four transliterated handlers:

```c
if (st.n < 1) return TWIN_INVALID_STACK_OPERATION;
uint32_t l = 0; const uint8_t* p = st_top(st, 1, l);
uint8_t out[20]; sha1(p, l, out);
st.n -= 1; return st_push(st, out, 20);
```

The review anchors are Lean `Defs.lean:637-643` (`hashForOp 0xa7 =
hashSha1`) plus `Hashes.lean:133-157`, and Core `interpreter.cpp:1042`
(width 20 for SHA1) and `:1043-1047` (`CSHA1` dispatch). The transform is the
opaque `sha1` external shared with the C leg: both `build/c_leaf.ll` and
`build/l_leaf.ll` contain only `declare void @sha1(...)` and no definition.
This cell therefore proves the width/empty plumbing, not SHA1 internals. The
shared twin's declared subset and the row's ledger entry are unchanged by this
cell; promoting the shared twin itself requires a separate reviewed change to
`ops_ir.py`/`runtime.inc` and regeneration.

## Commands

From the repository root:

```sh
bash spec/equiv/cells/hash-ops/C-L-hash-widths/alive2/run.sh
bash spec/equiv/cells/hash-ops/C-L-hash-widths/saw/run.sh
sha256sum -c spec/equiv/cells/hash-ops/C-L-hash-widths/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/hash-ops/C-L-hash-widths/saw/certificate.sha256
```

`build/` is gitignored, but the certificates hash the extracted IR and
`build.txt`. Run the scripts first, then verify: each `run.sh` rebuilds before
it writes the certificate.

Tool versions on this host:

```text
alive-tv  Ubuntu LLVM version 20.1.2 (Optimized build)
saw       1.6 (68eed5f release-1.6)
clang++   20.1.2 (Ubuntu 20.1.2-0ubuntu1~24.04.3)
```

## Raw results

`alive2/result.txt` contains ten comparisons (the `*_meta` exports), including
the SHA1 empty and `0x61` pairs. Each ends with:

```text
Transformation seems to be correct!

Summary:
  1 correct transformations
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
```

and the file ends with `STATUS=alive2-green`.

`saw/result.txt` contains twenty proofs (ten C, ten L). It ends with
`CELL_HASH_WIDTHS_SAW_GREEN` and `STATUS=saw-green`; the last proof tail is:

```text
Applied override! hash256
Checking proof obligations cell_hash256_a...
Proof succeeded! cell_hash256_a
```

The four SHA1 proofs appear as `cell_sha1_empty` and `cell_sha1_a`, once for
each leg, each with `Applied override! sha1` and
`Proof succeeded! cell_sha1_*`.

## Mutation sensitivity

Scratch probe, not committed (the source tree is
`/tmp/opencode/hashmut/wcell`):

- Change L `op_hash160` to `uint8_t out[32]` / `st_push(st, out, 32)`.
- Alive2 on the `_meta` pair: `0 correct, 1 incorrect`, `0xa101` vs
  `0x10101` (length 20 vs 32). This is the width claim.
- SAW on the digest-bearing pair: the proof does not complete; symbolic
  execution fails loading the pushed element because the 32-byte push
  observes bytes the 20-byte primitive did not define. A width change is
  therefore rejected by both tools, by different mechanisms.

The stale `build/twin_ops.h` is generated from the unmutated twin table and
is unchanged by the probe.

SHA1 width probe (scratch tree `/tmp/opencode/sha1mut-wave64-62`, not
committed): change the cell-local `op_sha1` to `uint8_t out[32]` /
`st_push(st, out, 32)` and compare the meta export:

```text
Transformation doesn't verify!
Source value: #x000000000000a101 (41217)
Target value: #x0000000000010101 (65793)
0 correct transformations
1 incorrect transformations
```

`0xa101` is `result 1 | error 0 | depth 1 | length 20`; `0x10101` is the same
with length 32. Running the cell's SAW script against the same width-32 L
mutant stops at `cell_sha1_empty` with `Symbolic execution failed` /
`Error during memory load` (the 32-byte push reads bytes the 20-byte primitive
did not define), so both tools reject the width change by different
mechanisms. The SHA1 width arm is therefore observed, not assumed.

SHA1 empty-path probe: add `if (l == 0) return TWIN_INVALID_STACK_OPERATION;`
to the cell-local `op_sha1`. Alive2 on the empty meta pair reports
`0 correct, 1 incorrect` (the transformation does not verify), and SAW on
`cell_sha1_empty` ends with `Subgoal failed` / `Proof failed`. The green SAW
`cell_sha1_empty` proof on the unmutated source supplies the complementary
concrete witness.

## Coverage limits (not overclaimed)

- **SCR-093 is `full` at this cell's scope.** The row is RIPEMD160/SHA1/SHA256
  output sizes. All three widths are exercised: RIPEMD160 20, SHA1 20, SHA256
  32; the HASH160 20 and HASH256 32 neighbours are also present. The SHA1
  handler is cell-local (the shared twin still returns result 3 on `0xa7`), so
  this is not a claim that the pinned twin supports SHA1.
- **SCR-095 is `full` at this cell's scope.** The empty element is exercised
  for all five wires, including SHA1. The digest is a SAW witness, not a
  proved hash.
- **SHA1 internals are not proved.** The `sha1` symbol is an opaque external
  on both legs; no FIPS 180-4 implementation is linked or verified.
- **Shared-twin integration is not done.** `twin/ops_ir.py` and
  `twin/runtime.inc` still exclude SHA1, and `spec/db/equiv-cells.yaml` is not
  edited by this cell. Promoting the shared twin/ledger is a separate
  reviewed change.
- Only preimages of length 0 and 1 are exercised.
- Alive2 checks the meta fields universally; the digest bytes are checked by
  SAW only for the recorded witnesses.
- No Core source patch is used.
