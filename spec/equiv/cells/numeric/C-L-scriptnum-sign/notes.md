# notes — numeric/C-L-scriptnum-sign (SCR-082)

## What this cell is

A bounded C-vs-L cell for the two CScriptNum byte<->number functions named by
the row:

```
src/script/script.h:342-373   CScriptNum::serialize   (encode)
src/script/script.h:376-391   set_vch                 (decode)
```

Both functions are called directly. No EvalScript case block is sliced in, so
the cell is exactly the row's subject: the 0x80 sign bit rides on the most
significant (wire-last) byte, a sign bit over a zero magnitude is a
"negative zero" wire form that decodes to 0, and the encoder is the canonical
inverse (0 -> empty; fresh 0x80/0x00 byte when the magnitude's top byte
already has bit 7 set; otherwise the sign bit is OR-ed into the top byte).

Four entry points, all with an int64 bit pattern as the observable:

| entry | inputs | observable | domain |
|---|---|---|---|
| `cell_decode` | `w: u64`, `lb: u32` | decoded int64 | length `lb & 7` = 0..7; content all 2^64 words |
| `cell_encode` | `mag: u64`, `neg: u32` | `len(4) | b0<<4 | b1<<12 | b2<<20 | b3<<28 | b4<<36` | `mag & 0xffffffff`; `neg & 1`; so \|v\| <= 2^32-1 |
| `cell_encode_decode` | same | value recovered from the encoded bytes | same |
| `cell_roundtrip` | `w: u64`, `lb: u32` | encoded form of the decoded operand | length `lb & 3` = 0..4 (every legal 4-byte operand) |

### Why these bounds

- **Decode length 0..7.** The bounded leaf's element is 8 bytes. `set_vch`
  has no width check, so the C leg calls it directly; the L leg calls
  `decode_num` with `maxSize = 8`, `minimal = false`. Lengths 0..7 therefore
  exercise the sign rule at every byte position the leaf can address,
  including every negative-zero form (0x80, 00 80, 00 00 80, ...). The width
  guard is SCR-079/080's row, not this one.
- **Encode \|v\| <= 2^32-1.** A 4-byte CScriptNum operand decodes to
  \|v\| <= 2^31-1; OP_ADD/OP_SUB of two of them reaches 2^32-2. This is the
  closure of values any numeric opcode can hand to `serialize`, and their
  encoding is at most 5 bytes (4 magnitude bytes + a fresh sign byte), so the
  observable fits 44 bits. The full int64 domain would need a 9-byte encoding
  (INT64_MIN) and is not reachable from any numeric opcode.
- **Roundtrip length 0..4.** Decode of a 5..7-byte vector can produce a
  magnitude that needs 6..8 bytes on re-encode; those vectors are not legal
  numeric operands. Lengths 0..4 are exactly the 4-byte operand domain and
  their canonical re-encoding is <= 5 bytes.

## Harness

- **C leg** (`src/c_leaf.cpp` + the shared
  `findings/wave16/07-numeric-ops/tools/num_core.h`): bounded transcription of
  `set_vch`, `serialize`, `getvch` (8-byte element instead of `std::vector`,
  error return instead of `scriptnum_error`, unrolled loops). Both routines
  are called directly. No patch to Core; the transcription and its deviations
  are documented in `num_core.h`.
- **L leg** (`src/l_leaf.cpp` + generated `build/twin_ops.h`):
  `twin/runtime.inc`'s `encode_num` / `decode_num`, unrolled to an 8-byte
  element by `mk_num_leaf.py` from `twin/ops_ir.py` + `runtime.inc`. The
  generated header's `OP_1ADD` handler is unused; `build.cfg` selects it only
  because `mk_num_leaf.py` needs a non-empty op set to emit the header.
- **Model** (`src/sign.cry`): written independently from script.h and the
  Lean equations (`Numeric/ScriptNum.lean:encodeSignBE`/`magBE`/`setVchBE`,
  `Numeric/Interface.lean:encodeScriptNum`/`decodeScriptNum`). SAW verifies
  the C module and the L module separately against it (4 entry points x 2
  legs = 8 proofs).
- **Alive2**: this cell's `alive2/run.sh` runs *both* refinement directions
  for every entry point (`c -> l` and `l -> c`), 8 checks total. The shared
  wave-16 runner only runs `c -> l`, so this cell carries its own runner and
  records both directions in `result.txt`.

## Results

Raw logs: `alive2/result.txt`, `saw/result.txt`. Certificates:
`alive2/certificate.sha256`, `saw/certificate.sha256`.

- Alive2 v20.0 (Ubuntu LLVM 20.1.2), `--smt-to=180000`:
  **8/8 `1 correct transformations`**, no incorrect, no failed-to-prove, no
  Alive2 errors — `cell_decode`, `cell_encode`, `cell_encode_decode`,
  `cell_roundtrip`, each compared C->L and L->C.
- SAW 1.6, z3: **8/8 `Proof succeeded!`** — each of the four entry points on
  both the C and L modules against `src/sign.cry`.
- Concrete model evaluations printed in the SAW log:
  `negZeroEq` = `True`; `(decode 0x80 len1, decode 00 80 len2,
  encPackV 0, encPackV -128)` = `(0, 0, 0, 526338)`, i.e. negative zero
  decodes to 0, 0 encodes to the empty vector, and -128 encodes to
  `80 80` (packed `0x80802`).

## Tool findings from building this cell

1. **Clang 20 `icmp samesign` can poison a harness input (both-tool rule
   earned its keep).** The first harness passed the magnitude as `uint32_t`
   (as the wave-16 unary cells do). At `-O2`, clang narrowed the
   `zext(mag) < 65536` compares in `serialize` to
   `icmp samesign ult i32 %mag, 65536`. That is poison when `%mag` is
   >= 2^31 (negative in i32), i.e. for legal 5-byte results such as
   OP_ADD's. **Alive2 still reported `1 correct transformations` in both
   directions**, because both legs contained the same poison; **SAW rejected
   the C leg** with `Undefined behavior encountered ... Two integers with
   different signs were compared even though the 'samesign' flag was set`.
   Passing the magnitude as a 64-bit word masked to `0xffffffff` moves the
   compares to a value clang knows is non-negative and removes the poison
   (this is the committed harness). Not proof of a Core bug — it is a
   front-end/harness artifact — but a concrete case where Alive2 alone would
   have accepted a UB-bearing leaf.
2. **Model bug caught by the third leg.** The first `sign.cry` emitted the
   fresh 0x80 byte whenever `k == nb` and the value was negative, instead of
   only when `needsSignV`. SAW produced the counterexample
   `mag = 1921373656, neg = 1` (top magnitude byte 0x72, so no fresh byte is
   due) and the model was fixed; the C and L legs were right.
3. The `samesign` episode is also why the entry signature is
   `(uint64_t mag, uint32_t neg)` rather than `(uint32_t mag, uint32_t neg)`;
   the observable and the model are otherwise unchanged.

## Reproduce

From the repository root:

```sh
bash spec/equiv/cells/numeric/C-L-scriptnum-sign/alive2/run.sh
bash spec/equiv/cells/numeric/C-L-scriptnum-sign/saw/run.sh
sha256sum -c spec/equiv/cells/numeric/C-L-scriptnum-sign/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/numeric/C-L-scriptnum-sign/saw/certificate.sha256
```

Each runner rebuilds both legs from `src/` and the shared tools, so the logs
are regenerated from tracked inputs. `build/` is gitignored and excluded from
the certificates.

## Scope / not changed

This is a bounded two-function cell, not an EvalScript or whole-engine
equivalence proof. It does not claim SCR-079/080 (width guard) or SCR-083/084
(minimal-encoding / CastToBool) even though it exercises negative-zero
decoding. No change was made to `spec/db/equiv-cells.yaml`,
`spec/equiv/results/**`, `PINS.lock`, `contract/**`, `twin/**`, the shared
wave-16 tools, any other cell, or any Core source.
