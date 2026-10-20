# Wave 64 / agent 34 — SCR-147 taproot commitment wiring

- **Row:** SCR-147 — `32-byte program == x(tweak(p, merkle_root))`;
  `control[0]&1 == parity of the tweaked key`.
- **Seam:** `interpreter.cpp:1913-1925` (`VerifyTaprootCommitment`,
  `q.CheckTapTweak(p, merkle_root, control[0] & 1)` at `:1924`), pin
  `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`.
- **Branch / base:** `wave64/34-scr-147` @ `5946c02`.
- **Cell:** `spec/equiv/cells/tapscript/C-L-taproot-commitment`.
- **Verdict:** **same-crypto abstraction cell built; Alive2 green, SAW green,
  Lean-side theorem green. Row coverage: partial (wiring full; EC lane
  uninterpreted).** No EC internal is claimed.

## What was proved

Three total symbolic functions per leg, all mutually equal under Alive2
(`--bidirectional`, 1 correct / 0 incorrect / 0 failed-to-prove / 0 errors
each) and both legs verified by SAW against one shared Cryptol statement
(6/6 `Proof succeeded!`):

| function | content |
|---|---|
| `cell_program_eq` | the final `secp256k1_memcmp_var(pk_expected32, tweaked_pubkey32, 32) == 0` lane: exact 256-bit equality of the 32-byte witness program and `x(Q)`, all four words / all 32 bytes significant |
| `cell_parity` | `control[0] & 1 == secp256k1_fe_is_odd(&pk.y)`, i.e. `(control[0] & 1) == (y(Q) & 1)` for every control byte |
| `cell_commit` | the whole wiring: the `:1957` native-v1-32 guard, `tweak_add` failure, parity lane and program lane; every rejection folds to `(0, 40)` `SCRIPT_ERR_WITNESS_PROGRAM_MISMATCH` (`:1984-1985`), acceptance is `(1, 0)` |

Lean side (`lean/Scr147.lean`, re-checked by `lean/run.sh`,
`Bitcoin.Crypto.Taproot.Verify` rebuilt, standard axiom trio, no `sorry`):

- `CellTaprootCommitment.scr147_commitment_iff` — with
  `tweakedKey control root = some (xQ, yQ)` as the *only* crypto hypothesis,
  `checkTapTweak` accepts iff `program.size = 32 ∧ program = natToBytesBE 32 xQ
  ∧ control[0] % 2 = yQ % 2`.
- `CellTaprootCommitment.scr147_commitment_iff_bool` — the same statement as
  the Boolean conjunction that `cell_commit` implements.

## The explicit premise (same-crypto abstraction)

The EC lane behind `CheckTapTweak` — `secp256k1_xonly_pubkey_tweak_add_check`
(`extrakeys_main_impl.h:142-161`: lift_x / `xonly_pubkey_load`, TapTweak
scalar, `P + t*G`, x-only save, infinity reject) — is **uninterpreted**. Its
result is a shared input triple

```
tweak_ok ∈ {0,1},  x(Q) as four u64 words,  q_parity = y(Q) mod 2
```

produced by one oracle call on one `(control[1..33], merkle_root)` pair and
given identically to both legs. The cell proves the comparison/parity wiring
is a pure function of that triple, so the premise is exactly "both sides use
the same secp256k1 tweak". No property of the oracle beyond determinism is
used. This is the same-crypto premise of `docs/DECISION-lax-ecdsa.md`,
unchanged.

## Non-vacuity / negative controls

Scratch mutants (not committed) are all caught by both tools:

1. parity lane drops `& 1` → Alive2 `Value mismatch` (C=1 vs L=0 at
   `control[0]=0xc2`, `q_parity=0`); SAW `Proof failed` for `cell_parity`.
2. program lane compares only three words → Alive2 `Value mismatch`
   (C=160 vs L=1 for `q3 != x3`).
3. `cell_commit` drops the tweak-failure reject → Alive2 `Value mismatch`
   (C=160 vs L=1 for `tweak_ok=0`).

Positive witnesses: accept for `0xc0`/even parity, accept for `0xc2` (proving
`&1` not `==`), reject for `0xc1`/even, reject on last-word mismatch, reject
on tweak failure, delegated for lengths 31/33.

## Row coverage and blockers

**Full at this seam:** the comparison and parity wiring, including the
32-byte length (`:1957`), the `&1` mask, `x(Q)` byte equality, and the
fail-closed `tweak_add` reject.

**Not proved (blockers for closing SCR-147 entirely):**

- **EC lane** (`lift_x`, `TaggedHash("TapTweak", ...)`, scalar range,
  `P + t*G`, x-only serialization, infinity reject). There is no libsecp
  proof at the leaf seam. Smallest next experiment: a bounded cell for
  `secp256k1_xonly_pubkey_tweak_add_check` (or a proved Core↔Lean link for
  `tweakPoint`), which is a cryptographic-primitive project and must stay a
  separate same-crypto floor.
- **Merkle root** at `:1922` (`ComputeTaprootMerkleRoot`; TapBranch/TapLeaf
  tagged hashes = SCR-146 / TPR-012..015) and the tapleaf hash at `:1983`.
- **Control-size gate** at `:1980-1982` (SCR-145's cell) and Lean's
  `control.size >= 33` premise inside `outputKeyOk`.

## Ledger recommendation

`spec/db/equiv-cells.yaml` currently has SCR-147 as `unjudged-seam` with the
gap note "Pure secp256k1 EC; outside the seam." That note is now too coarse.
Recommended retag (integration wave, not done here): `status: both-green` for
the tool evidence but **row-partial**, with a ledger note: "wiring proved at
`interpreter.cpp:1913-1925` (program = x(Q), control[0]&1 = y(Q) parity);
EC lane (lift_x/TapTweak/P+tG) is the same-crypto premise, not proved."

No shared file (`equiv-cells.yaml`, ledger, matrix, pin, contract) was
modified by this agent. Only additive cell + report files, as in the wave-32
cell commits.

## Evidence

- `spec/equiv/cells/tapscript/C-L-taproot-commitment/spec.md`
- `.../alive2/result.txt`, `.../alive2/certificate.sha256` — 3/3 green
- `.../saw/result.txt`, `.../saw/certificate.sha256` — 6/6 proofs green
- `.../lean/result.txt`, `.../lean/certificate.sha256` — Lean green
- `.../notes.md` — seam, abstraction, mutants, witnesses

Replay:

```sh
bash spec/equiv/cells/tapscript/C-L-taproot-commitment/alive2/run.sh
bash spec/equiv/cells/tapscript/C-L-taproot-commitment/saw/run.sh
bash spec/equiv/cells/tapscript/C-L-taproot-commitment/lean/run.sh
```
