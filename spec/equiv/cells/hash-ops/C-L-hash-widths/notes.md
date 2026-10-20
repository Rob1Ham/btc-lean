# hash-ops/C-L-hash-widths

SCR-093 (`RIPEMD160/SHA1/SHA256` output sizes, `20/20/32`) and SCR-095
(hash of the empty element). The cell is **both-tool green** on the four hash
opcodes the twin implements, with the hash transforms as opaque externals
shared by both legs. Coverage is `partial`: the SHA1 arm and the hash
implementations themselves are not in the cell (see below).

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
- `twin/ops_ir.py` `OP_UNSUPPORTED_SHA1` (0xa7) — the twin's declared
  unsupported wire, see `twin/generator.md:231,393,407`.

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

All values below were recomputed with Python `hashlib` (`sha256`; `ripemd160`
via `hashlib.new('ripemd160', ...)`) and match `src/cell.cry`:

```text
RIPEMD160("")  = 9c1185a5c5e9fc54612808977ee8f548b2258d31
RIPEMD160("a") = 0bdc9d2d256b3ee9daae347be6f4dc835a467ffe
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

The L handler bodies are copied verbatim from `twin/ops_ir.py`
(`st_top`/`st_push`/the four op bodies). `mk_leaf.py` emits the same bodies,
but its bounded copy is hard-wired to two bytes, while these handlers push
20 or 32. With `--max-elem 32` mk_leaf accepts the length and copies only the
first two bytes, so its leaf cannot represent the op. `src/l_leaf.cpp`
re-binds only the stack representation: 32-byte slots and the unrolled
`h_copy` in `src/hash_common.h`. This is the same kind of substitution
mk_leaf performs, at a width it does not support. `build/twin_ops.h` is still
generated and hashed for provenance; it is not the compiled L module.

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

`alive2/result.txt` contains eight comparisons (the `*_meta` exports). Each
ends with:

```text
Transformation seems to be correct!

Summary:
  1 correct transformations
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
```

and the file ends with `STATUS=alive2-green`.

`saw/result.txt` contains sixteen proofs (eight C, eight L). It ends with
`CELL_HASH_WIDTHS_SAW_GREEN` and `STATUS=saw-green`; the last proof tail is:

```text
Applied override! hash256
Checking proof obligations cell_hash256_a...
Proof succeeded! cell_hash256_a
```

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

## Coverage limits (not overclaimed)

- **SCR-093 is `partial`.** The row is RIPEMD160/SHA1/SHA256 output sizes.
  SHA1 is absent from the L subset: wire `0xa7` returns
  `TWIN_INVALID_UNSUPPORTED` / result 3, so there is no L implementation to
  compare for the third width. RIPEMD160 (20), SHA256 (32), and the HASH160
  (20) / HASH256 (32) arms are exercised.
- **SCR-095 is `partial`.** The empty element is exercised for RIPEMD160,
  SHA256, HASH160 and HASH256, but not SHA1 (same twin boundary), and the
  digest is a SAW witness, not a proved hash.
- Only preimages of length 0 and 1 are exercised.
- Alive2 checks the meta fields universally; the digest bytes are checked by
  SAW only for the recorded witnesses.
- No Core source patch is used.
