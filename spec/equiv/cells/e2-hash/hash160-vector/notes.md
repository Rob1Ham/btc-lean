# e2-hash/hash160-vector

SCR-093/SCR-094 (`HASH160` output width 20; `RIPEMD160∘SHA256` composition),
implemented as a closed concrete witness with the cryptographic transform as
an opaque external shared by both legs. **Both tools are green** on the
opcode plumbing and the concrete digest witness.

## Source

Pinned Core `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`:

- `src/script/interpreter.cpp:1032-1056` — hash opcode family
  (`OP_RIPEMD160`, `OP_SHA1`, `OP_SHA256`, `OP_HASH160`, `OP_HASH256`).
- `src/script/interpreter.cpp:1042` — `vchHash` is 20 bytes for
  RIPEMD160/SHA1/HASH160 and 32 otherwise.
- `src/script/interpreter.cpp:1049-1050` — HASH160 arm:
  `CHash160().Write(vch).Finalize(vchHash);`.
- `src/script/interpreter.cpp:1053-1054` — `popstack(stack);
  stack.push_back(vchHash);`.
- `twin/ops_ir.py` `OP_HASH160` (wires `[0xa9]`, `lean Defs.lean:1028-1030`).

Witness: preimage `0x61` ("a").

```text
SHA256(0x61)  = ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb
RIPEMD160(..) = 994355199e516ff76c4fa4aab39337b9d84cf12b
```

The first line was checked with Python `hashlib.sha256`; the second with
`hashlib.new('ripemd160', sha256_digest)`. The same concrete digest is the
SAW override postcondition.

## L leg: why it is a reviewed transliteration

`twin/ops_ir.py` has `OP_HASH160`, and `mk_leaf.py` emits its body verbatim.
But mk_leaf's `st_push`/`bounded_memcpy` is hard-wired to two bytes
(`e[MAX][2]`, `if (len >= 1) d[0] = ...; if (len >= 2) d[1] = ...`), while
the handler pushes a 20-byte digest. With `--max-elem 32`, `st_push` accepts
the length but copies only the first two bytes, so the generated leaf cannot
represent the op.

`src/l_leaf.cpp` therefore carries the twin body unchanged and re-binds only
the cell stack representation: element width 32 and an unrolled 20-byte copy.
This is the same class of substitution mk_leaf performs (bounded constants
and a bounded copy), applied at a width mk_leaf does not support. It is
labelled as a reviewed transliteration in `spec.md`; it is not claimed to be
mk_leaf output. `build/twin_ops.h` is still generated and certified for
provenance.

## Hash opacity

Both C and L declare the same external:

```cpp
extern "C" void hash160(const uint8_t* in, uint32_t len, uint8_t* out);
```

- Alive2 compares `cell_hash160` in both modules with `hash160`
  uninterpreted. It proves the opcode plumbing (pop, output length 20, push)
  and that both legs call the external with the same input bytes and length.
  It does **not** prove the hash.
- SAW uses `llvm_unsafe_assume_spec` for `hash160` on both modules: input
  pointer holds `[0x61]`, length 1, output pointer holds the concrete digest.
  Both legs then prove the exact packed observable.

This is the named external-function seam, recorded rather than hidden.

## Commands

```sh
cd spec/equiv/cells
./e2-hash/hash160-vector/alive2/run.sh   # ./_tools/e2/run_alive2.sh ... cell_hash160
./e2-hash/hash160-vector/saw/run.sh      # ./_tools/e2/run_saw.sh ... 2
```

## Raw tails

`alive2/result.txt` ends with:

```text
Transformation seems to be correct!

Summary:
  1 correct transformations
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
STATUS=alive2-green
```

`saw/result.txt` ends with (twice, once per module):

```text
Applied override! hash160
Checking proof obligations cell_hash160...
Proof succeeded! cell_hash160
...
CELL_E2_HASH160_SAW_GREEN
STATUS=saw-green
```

## Coverage limit (not overclaimed)

- Only HASH160 is exercised. `OP_RIPEMD160`, `OP_SHA1`, `OP_SHA256`,
  `OP_HASH256` (and the 32-byte width arm of SCR-093) are not.
- Only the 1-byte preimage `0x61` is exercised; SCR-095 (hash of the empty
  element) is not.
- The digest is an override value, not a proved transform. The cell proves
  the opcode's observable behavior given that value.
- `scr_row_coverage: partial` in `spec.md` records all of the above.

## Mutation relevance

M-E2-007 (`HASH160` composition/dispatch swapped) is expected to make this
cell non-green when the C/L composition differs. A mutation that only swaps
the opaque external body is invisible to Alive2 (same uninterpreted symbol)
and is caught only if the SAW override digest is changed to the mutated
value; the cell as recorded catches a **dispatch/width/stack** mutation, not
a change hidden inside the external. This is the documented external-function
limitation. The mutation was **not** executed; see `findings/e2/report.md`.
