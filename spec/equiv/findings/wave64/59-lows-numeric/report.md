# wave64 / 59-lows-numeric — SCR-104 numeric half-order predicate

Task: independent attempt at the LOW_S numeric half-order predicate (SCR-104)
using a shared same-crypto scalar abstraction; model S and n/2 exactly, or
prove the DER/S boundary with an explicit libsecp256k1 seam; do not claim ECDSA
internals; real Alive2 + SAW; tracked-input certificates; no shared edits.

Branch: `wave64/59-lows-numeric` at base `5946c02`.
Worktree: `/tmp/opencode/wave64/59-lows-numeric` only. `/tmp/opencode/equiv-pr`
was not touched.

## Artifact

New cell, all files new, no shared file edited:

```
spec/equiv/cells/checksig/C-L-w64-lows-halforder-seam/
  spec.md, notes.md
  src/lows_scalar.h      shared 256-bit scalar type + explicit seam symbol
  src/c_lows.cpp         C leg: chained limb compare; positional S field
  src/l_lows.cpp         L leg: borrow/subtract; acc*256+byte fold
  src/seam_stub.cpp      SAW seam instantiation (mode 0 strict; 1/2 mutations)
  src/build_ir.sh        tracked textual IR for both lanes
  src/driver.cpp         concrete differential driver
  src/oracle.py          62 hand-computed boundary vectors
  alive2/run.sh, alive2/result.txt, alive2/certificate.sha256
  saw/run.sh, saw/cell.cry, saw/cell.saw, saw/result.txt, saw/certificate.sha256
  ir/                    tracked LLVM modules (per-root for Alive2, stub-linked for SAW)
```

## Result

Both tools green, both refinement directions, two roots:

- `cell_lows_halforder(lowS, s0..s3) -> u32` — exact `S <= floor(n/2)` over
  all 2^256 S.  No DER input, no seam.  C: chained most-significant-limb
  compare.  L: borrow/subtract against `SIG_S_HALF_ORDER`.
- `cell_lows_der_s(lowS, pad, w0..w3) -> u32` — the BIP66 S-field boundary:
  1..32 significant bytes and the 33-byte `0x00 || value` form map to one
  scalar; `S >= n` is answered by the explicit external
  `btc_equiv_secp_s_accept`; then the same numeric compare selects 0 or 27.

Observed:

```
alive2/result.txt   STATUS=alive2-green (2 bidirectional root checks)
saw/result.txt      STATUS=saw-green (4 proofs for 2 roots x 2 legs)
src/oracle.py       checked=62 mismatches=0
```

Alive2 consumes the tracked `ir/*.ll` directly (after the identical `noundef`
annotation on the shared seam declaration).  SAW re-disassembles its linked
bitcode and byte-compares it with the tracked `ir/*_saw_c0.ll` before proving.
Both certificates hash the sources, the exact IR, the raw tool output, the
contract error header, and `docs/DECISION-lax-ecdsa.md`, and verify with
`sha256sum -c` from the repo root.

SAW runtime: 4m35s on the green case (32-byte fold + 256-bit compare); no
internal timeout is used.

## The seam, and an honest negative result

Alive2 compares the two legs with `btc_equiv_secp_s_accept` as a *bare
declaration* in both modules, so its model quantifies over every possible seam
behaviour; SAW links the documented contract (`!overflow && s < n`) into both
modules and proves the composition against an independent Cryptol oracle.
Neither lane proves libsecp256k1, the compact parser, the DER-lax parse, or any
ECDSA internal.

Important scope fact found while mutating: for the SCR-104 verdict the seam is
**observationally redundant in the accept direction**.  Every `s >= n` is
already `> n/2`, so whether the compact parser accepts or rejects it, the
numeric compare still returns `SIG_HIGH_S = 27`.  A reject-all parser bug *is*
observable (it turns low-S into 27) and the SAW oracle kills it.  The seam
becomes a semantic difference only in the Lean `isLowDERSignature`
`s % n <= n/2` formulation, where a high S can reduce into the low half — that
is the SGN-107 boundary, outside SCR-104 and not claimed here.  This is
recorded rather than hidden: `src/seam_stub.cpp` comments, `spec.md` `scope:`.

## Mutation evidence (REDTEAM)

Raw logs under `logs/`:

| ID | mutant | expected | observed |
|---|---|---|---|
| M-104-a | C compare `<` at the low boundary (`s0 < HALF_N0`) | Alive2 counterexample | **killed**: `Value mismatch` at exactly `S = floor(n/2)` (`s0=0xdfe92f46681b20a0`, `s1=0x5d576e7357a4501d`, `s2=0xffffffffffffffff`, `s3=0x7fffffffffffffff`); source 0 vs target 27 |
| M-104-b | C S-field endianness (`pos = I`) | Alive2 counterexample | **killed** on `cell_lows_der_s` |
| M-104-c | seam mode 1, reject all scalars | SAW failure | **killed**: `Proof failed.` / `STATUS=saw-not-green` |
| M-104-d | seam mode 2, accept all scalars | equivalent for this row | **survived by design** (see above), `STATUS=saw-green` |

Mutants are generated in the gitignored `build/`; no tracked source was
modified for them.

## Findings and blockers

1. **No ECDSA claim.**  The cell proves predicate/refinement wiring and one
   explicit seam profile; it says nothing about libsecp256k1 scalar
   multiplication, the group equation, nonces, or sighash.
2. **Whole-DER location walk is out of scope.**  The S field is a boundary
   input: the strict-DER shape table, `lenR`/`lenS` offsets, and the lax
   length-descriptor walk that locates the S bytes are other cells
   (`C-L-checksig-der`, `C-L-lows-policy`).  BIP66 minimality caps significant
   S at 32 bytes, so the lax `> 32 significant bytes` window cannot reach
   `CheckLowS` once the strict gate has passed.
3. **R leg absent** (F-HARNESS-002): the pinned rbitcoin shim has no typed
   ScriptError and rejects policy flags, so no R claim is made.
4. **Shared-ledger handoff, not an edit.**  `spec/db/equiv-cells.yaml` still
   records SCR-104 as `gap` with note `checksig/C-L-checksig-lows: partial`.
   This branch deliberately does not edit the shared ledger.  Proposal for its
   owner:
   ```yaml
   - id: SCR-104
     cells: [checksig/C-L-checksig-lows, checksig/C-L-w64-lows-halforder-seam]
     status: both-green
     gap_note: "numeric predicate full over 2^256; DER/S S-field boundary via
                explicit seam; whole-DER offset walk out of row scope"
   ```
5. **Evidence tier.**  Alive2/SAW output is evidence-tier, not a Lean-kernel
   theorem; the Lean target `PDW89c.checkLowS_row` is cited for provenance of
   the L equations, not re-proved here.

## Reproduce

```sh
cd /tmp/opencode/wave64/59-lows-numeric
bash spec/equiv/cells/checksig/C-L-w64-lows-halforder-seam/alive2/run.sh
bash spec/equiv/cells/checksig/C-L-w64-lows-halforder-seam/saw/run.sh   # ~4.5 min
python3 spec/equiv/cells/checksig/C-L-w64-lows-halforder-seam/src/oracle.py
sha256sum -c spec/equiv/cells/checksig/C-L-w64-lows-halforder-seam/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/checksig/C-L-w64-lows-halforder-seam/saw/certificate.sha256
```

Both certificates also verify from a bare `git archive HEAD` extraction (they
reference only tracked files; `build/` is gitignored and re-derived).

## Gate status (pre-existing failure, no regression)

`python3 spec/equiv/tools/gate_ir_pin.py` fails on this base **and** on the
branch: 225 certificate issues at base `5946c02`, 225 on this commit
(`cells/stack-ops/C-L-pick` and others reference gitignored `build-saw/`
artifacts).  The cell count rises 141 -> 142 because this cell directory
exists; no failure names this cell.  The shared ledger was intentionally not
edited, so SCR-104's ledger row is still the old `gap` until its owner applies
the handoff above.

