# E2 numeric + hash cells — report

Role: E2-NUMERIC-HASH. Scope: `cells/e2-numeric/**`, `cells/e2-hash/**`,
`cells/_tools/e2/**`, `findings/e2/**`. No other tree path was edited; no
commits; `make equiv` / `make gate-ir-pin` were not run.

Pin: `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
Repo head: `4d62a97e551082a69b13f495365bff0a903b0c99`

## Cells and status

| Cell | Family | SCR rows | Coverage | Alive2 | SAW |
|---|---|---|---|---|---|
| `cells/e2-numeric/within-boundary` | numeric | SCR-089 | partial: all 2^24 one-byte operand triples; no 2–4 byte width edge | green (`STATUS=alive2-green`) | green (`STATUS=saw-green`, 2 proofs) |
| `cells/e2-hash/hash160-vector` | hash-ops | SCR-093, SCR-094 | partial: one concrete HASH160 witness, 20-byte width; hash opaque | green (`STATUS=alive2-green`) | green (`STATUS=saw-green`, 2 proofs) |

### Numeric cell

- ABI: `uint64_t cell_within(uint8_t av, uint8_t bv, uint8_t cv)`; the three
  raw element bytes are `[x, min, max]`.
- C: line-cited slice of `interpreter.cpp:1012-1026` plus `script.h:246-271`
  and `script.h:376-391`.
- L: `OP_WITHIN` handler verbatim from `twin/ops_ir.py` via
  `cells/_tools/mk_leaf.py` (`--ops OP_WITHIN --max-depth 4 --max-elem 2`).
- Alive2 compares C and L symbolically over all i8 triples.
- SAW verifies **both** C and L against an independent Cryptol predicate
  (`min <= x && x < max` on decoded one-byte scriptnums), not against a
  recorded constant. This is the stronger of the two shapes the task asked
  for: every value of the small integer inputs, not a boundary witness set.

### Hash cell

Row selection note: at this pin SCR-180..182 are **not** hash-ops rows. They
are the policy-only flags CLEANSTACK, CONST_SCRIPTCODE, and
WITNESS_PUBKEYTYPE (`rules.yaml` lines 7900-7932), family `flags`. The
hash-ops family is the three rows SCR-093/094/095 from AppendixB §B.7, so
this cell targets SCR-093/SCR-094. SCR-095 (hash of the empty element) is
not exercised and is listed as a gap below.

- ABI: `uint64_t cell_hash160()`; closed witness preimage `0x61` ("a").
- C: line-cited slice of `interpreter.cpp:1032-1056`; HASH160 arm at
  `:1049-1050`; output width at `:1042`.
- L: reviewed transliteration of `twin/ops_ir.py` `OP_HASH160`, because
  mk_leaf's bounded copy is hard-wired to two bytes and cannot represent a
  20-byte push. The op body is unchanged; only the stack element width (32)
  and the unrolled 20-byte copy are re-bound.
- `hash160` is the same opaque external symbol in both legs.
- Alive2 proves the opcode plumbing with the hash uninterpreted.
- SAW supplies the concrete digest via `llvm_unsafe_assume_spec` for
  `hash160` and proves both legs' packed observable.

## Exact result hashes

```text
e8367b7153783f3379c0afe393b13c8b1b780401264315a652ec1a7d7ef5598f  cells/e2-numeric/within-boundary/alive2/result.txt
c6da80d10837e07319da4765d978dc907fc3985c347b4399a45ebc50ae3c1c5f  cells/e2-numeric/within-boundary/saw/result.txt
cb2412943d348a53068d8b86a0b789d255fe2c3f71e9e399bd3a4d40da834727  cells/e2-hash/hash160-vector/alive2/result.txt
f62eef8d1a0296ebbee455ebf854baffcc46bcf7d787263f7bbe5ea559b9f3af  cells/e2-hash/hash160-vector/saw/result.txt
```

Certificate files (`alive2/certificate.sha256`, `saw/certificate.sha256`)
hash `spec.md`, `run.sh`, the cell `src/` sources, the shared
`cells/_tools/e2/` tools, `cells/_tools/mk_leaf.py`, `twin/ops_ir.py`,
`twin/gen.py`, `contract/error_kind.h`, `build/twin_ops.h`, `build/build.txt`,
and the raw result. Regenerate by rerunning the cell scripts.

## Commands run

```sh
cd /home/ubuntu/btc-lean-public/spec/equiv/cells
./e2-numeric/within-boundary/alive2/run.sh
./e2-numeric/within-boundary/saw/run.sh
./e2-hash/hash160-vector/alive2/run.sh
./e2-hash/hash160-vector/saw/run.sh
```

Each verifies its own `alive2/result.txt` / `saw/result.txt` with the exact
`STATUS=` line and rewrites its `certificate.sha256`.

Digest witness recomputation (informational, not a tool proof):

```text
python3 -c "import hashlib; x=b'a'; s=hashlib.sha256(x).digest(); print(s.hex()); print(hashlib.new('ripemd160', s).hexdigest())"
ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb
994355199e516ff76c4fa4aab39337b9d84cf12b
```

## Proposed mutation (NOT executed)

### M-E2-004r — OP_WITHIN max boundary inclusive

- Twin site: `twin/ops_ir.py`, `OP_WITHIN` body, the final expression:
  `return st_push_num(st.stack, (b <= a && a < c) ? 1 : 0);`
  change `a < c` to `a <= c`.
- Expected failing cell: `cells/e2-numeric/within-boundary`.
- Catch:
  - Alive2: C (fixed slice) vs L (mutated twin) disagree on `[x=5, min=1,
    max=5]` (baseline EVAL_FALSE, mutant true), so the pair is non-green.
  - SAW: the independent `within` predicate still says false, so the L
    verification fails even if C is mutated in the same direction. This is
    why the cell uses an independent spec rather than a constant.
- If the mutation is applied to both the twin and a C-side copy identically,
  Alive2 cannot see it; SAW is the catcher. Record that as the intended
  division of labour.
- Status: proposed only. No file was mutated and no mutant run was performed
  in this session.

### M-E2-007r — HASH160 dispatch/composition swap

- Twin site: `twin/ops_ir.py`, `OP_HASH160` body,
  `hash160(p, l, out);` → `hash256(p, l, out);` (or swap the wire
  `[0xa9]` onto the HASH256 handler).
- Expected failing cell: `cells/e2-hash/hash160-vector`.
- Catch:
  - Alive2: the external callee changes from `hash160` to `hash256`, so the
    C/L call graphs differ and the pair is non-green.
  - SAW: the `hash160` override no longer matches; the mutated external is
    unverified, so the proof does not close.
- Limitation: mutating only the *body* behind the opaque `hash160` symbol
  (keeping the same symbol and signature) is invisible to Alive2 and is
  invisible to SAW unless the override digest is also changed. That is the
  documented external-hash gap; the cell catches dispatch/width/stack
  mutations, not a change hidden inside the crypto implementation.
- Status: proposed only. Not executed.

## Blockers and gaps

1. **CScriptNum 2–4 byte symbolic operands (SCR-079/SCR-080).** The twin's
   `decode_num` in `mk_leaf.py` has a hard `len > 2` guard (its bounded
   element width is 2). A faithful symbolic 4-byte width-cap cell needs a
   wider `decode_num` plus the `len > maxlen` branch only; the generated
   leaf cannot express it. A 5-byte reject-only witness is possible but
   would agree for the wrong reason on the L side (`len > 2` fires before
   `len > 4`), so it is not filed as coverage.
2. **Hash body.** The crypto transform is external in both legs. Green means
   the opcode plumbing and a concrete digest witness are verified, not that
   RIPEMD160/SHA256 were proved. This is `scr_row_coverage: partial` and is
   recorded in `cells/e2-hash/hash160-vector/notes.md`.
3. **mk_leaf 20-byte elements.** `bounded_memcpy` is fixed at two bytes, so
   the hash L leg is a reviewed transliteration, not generated output. The
   generated `build/twin_ops.h` is retained and certified for provenance.
4. **Empty elements.** The packed observables canonicalise a zero-length
   element to value 0, because Core's `vchFalse` is the empty vector and the
   bounded stack can retain stale bytes in the slot. Applied to both legs;
   documented in `cells/_tools/e2/e2_common.h`.

---

## Orchestrator addendum — E2-family mutation and E6 status

The E2 cell mutations proposed above were not executed. The E2/family
mutation requirement was satisfied by **M-E2-010** (a flow/tail mutation),
which was executed and killed by both Alive2 and SAW on its cell; the report is
in `cells/_redteam/runs/` and `MUTATIONS.md`. The E2 cells themselves remain
tool-green but **partial**: SCR-089 (WITHIN, one-byte domain) and
SCR-093/094 (HASH160, one concrete vector / opaque transform) stay `gap` in
the E6 ledger. No E2 row is green.
