# Wave 16 — `08-hash-ops` report

Branch `wave16/08-hash-ops`, cut from PR #29 head `805c804`. Contract
`f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`,
Core pin `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`. No shared ledger,
results, state, pin, rules, contract/twin/shims, or Core source file was
edited; no push.

## Dispositions

| Row | Disposition | Cell | What the cell proves |
|---|---|---|---|
| SCR-093 | **partial**, both-tool green | `cells/hash-ops/C-L-hash-widths` | RIPEMD160/HASH160 push 20, SHA256/HASH256 push 32, on both legs; empty and 0x61 preimages. SHA1 (wire 0xa7) is absent from the L subset. |
| SCR-094 | **full**, both-tool green | `cells/hash-ops/C-L-hash-compose` | HASH160 = RIPEMD160(SHA256(x)) and HASH256 = SHA256(SHA256(x)); both arms on both legs, empty and 0x61; the second primitive consumes exactly the 32-byte intermediate and the final width is 20/32. |
| SCR-095 | **partial**, both-tool green | `cells/hash-ops/C-L-hash-widths` | The empty element is accepted and hashed by RIPEMD160, SHA256, HASH160 and HASH256. SHA1's empty arm is missing for the same twin-boundary reason. |

No row is claimed as a cryptographic implementation proof. SCR-093 and
SCR-095 stay partial; SCR-094 is full only for the composition skeleton it
names, under the same-hash premise.

## Cells

### `hash-ops/C-L-hash-widths` (SCR-093, SCR-095)

- Eight C/L opcode functions plus eight meta-only exports. The meta exports
  pack `result | error | depth | pushed length`; the full exports also pack the
  first five digest bytes.
- Alive2 compares the meta pairs: 8/8 green, `STATUS=alive2-green`.
- SAW verifies the full pairs against concrete `hashlib` witnesses: 16/16
  proofs, `STATUS=saw-green`.
- The width claim is checked by the meta length field. A probe that changes
  the L HASH160 push from 20 to 32 makes Alive2 report `0xa101` vs `0x10101`.
- Why the split: a digest-bearing Alive2 comparison is vacuous. The same
  width mutant is accepted (`1 correct transformation`) when the function
  reads the externally written digest, because Alive2's unmodelled write
  poisons the whole packed value. The meta observable is defined; SAW checks
  the bytes.

### `hash-ops/C-L-hash-compose` (SCR-094)

- Four C/L memory functions (HASH160 and HASH256 over empty and 0x61) plus
  four token-chain functions per leg.
- Alive2 compares the chain functions, where each primitive returns a defined
  64-bit token and the second call gets that token plus the literal 32-byte
  intermediate length: 4/4 green, `STATUS=alive2-green`.
- SAW verifies the real memory composition with two-stage concrete overrides,
  and also verifies the chain functions: 16/16 proofs, `STATUS=saw-green`.
- Mutation probes: second-stage length 32→20, token dataflow `mid`→`0`, and
  final width 20→32 each produce `0 correct, 1 incorrect` in Alive2. The
  memory-level 32→20 mutant makes SAW's second-stage override inapplicable,
  so the proof does not complete.

## Validation

All Alive2 runs are `alive-tv C L`, i.e. L ⊑ C. The reverse direction is not
claimed: under Alive2's uninterpreted-external model the reverse run does not
verify (the L source is reported undefined when it copies or passes an
externally written digest). This is recorded in both `spec.md` files. SAW
verifies both legs against the same concrete constants, which establishes
equality on the recorded witnesses.

Run from the repository root:

```sh
bash spec/equiv/cells/hash-ops/C-L-hash-widths/alive2/run.sh
bash spec/equiv/cells/hash-ops/C-L-hash-widths/saw/run.sh
bash spec/equiv/cells/hash-ops/C-L-hash-compose/alive2/run.sh
bash spec/equiv/cells/hash-ops/C-L-hash-compose/saw/run.sh

sha256sum -c spec/equiv/cells/hash-ops/C-L-hash-widths/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/hash-ops/C-L-hash-widths/saw/certificate.sha256
sha256sum -c spec/equiv/cells/hash-ops/C-L-hash-compose/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/hash-ops/C-L-hash-compose/saw/certificate.sha256
```

Recorded tool versions: Alive2/LLVM 20.1.2, SAW 1.6, clang++ 20.1.2.
`build/` is gitignored; certificates hash the extracted IR and `build.txt`, so
verify after the corresponding run (each runner rebuilds first).

Raw result tails:

```text
# widths/alive2 (each of 8 comparisons)
1 correct transformations
0 incorrect transformations
0 failed-to-prove transformations
0 Alive2 errors
STATUS=alive2-green

# widths/saw (16 proofs)
Proof succeeded! cell_hash256_a
CELL_HASH_WIDTHS_SAW_GREEN
STATUS=saw-green

# compose/alive2 (each of 4 comparisons)
1 correct transformations
0 incorrect transformations
0 failed-to-prove transformations
0 Alive2 errors
STATUS=alive2-green

# compose/saw (16 proofs)
Proof succeeded! cell_hash256_a_chain
CELL_HASH_COMPOSE_SAW_GREEN
STATUS=saw-green
```

## Remaining blockers (precise)

1. **SCR-093 / SCR-095 SHA1 arm.** Core implements OP_SHA1 at
   `interpreter.cpp:1043-1047`. `twin/ops_ir.py` maps wire `0xa7` to
   `OP_UNSUPPORTED_SHA1`, which returns `TWIN_INVALID_UNSUPPORTED` / result 3
   (`twin/generator.md:231,393,407`). There is no L implementation to compare,
   so the third output width (20) and the SHA1 empty-element arm cannot be
   cell-covered. Next action: implement an L SHA1 handler from the Lean
   `hashSha1`/Core `CSHA1` seam and regenerate the twin, or keep the row
   partial by design.
2. **Hash algorithms.** SHA256/RIPEMD160/HASH160/HASH256 are opaque externals
   on both legs. Proving the digests would require verified implementations or
   a proof that the symbols denote the standard algorithms; that is outside the
   same-hash premise and outside this wave.
3. **Bounded preimages.** Only lengths 0 and 1 are exercised. The width and
   composition claims do not depend on preimage length, but longer inputs are
   not in the cells.

## Relation to `e2-hash/hash160-vector`

The e2 cell proved one HASH160 witness with a single opaque `hash160` symbol.
It did not exercise the composition, the other opcodes, the 32-byte arm, or
the empty element, and its digest-bearing Alive2 comparison had the vacuity
described above. These two cells supersede it as evidence for SCR-093/094/095
without editing it.
