# Wave 64 / task 05 — SCR-021 bounded OP_SUCCESSx scan

Branch `wave64/05-scr-021`, cut from `5946c02` (base of the wave-64 fleet).
Additive to the `limits/C-L-witness-push-size` cell only.  No ledger, contract,
pin, result matrix, Lean proof or other cell was edited.

## Target

SCR-021 (`limits`, consensus): witness stack items >520 bytes fail with
`PUSH_SIZE` for base/v0 and for tapscript without OP_SUCCESSx, provided the
initial stack has ≤1000 items; a tapscript containing OP_SUCCESSx returns
success before the item-size loop and is exempt (BIP342).

The previous gap was exact: the item-size predicate and the post-scan ordering
were proved, but `has_success` was an abstract Boolean.  The row's "containing
OP_SUCCESSx" branch was not decided over script bytes.

## Result

**The missing link is closed for every script of length ≤ 6 bytes.**

`limits/C-L-witness-push-size` now exports a second decision,
`cell_witness_push_size_scan(depth, max_item, sv, discourage, len, b0..b5)`:

1. computes the TAPSCRIPT OP_SUCCESSx scan from the six symbolic script bytes
   and the symbolic length (`len ∈ [0, 6]`), using Core's `GetScriptOp` /
   `IsOpSuccess` rules (and Lean's `getOp` / `opSuccessScanFrom` on the L leg),
2. then applies the same ordering as the original lemma:
   found → success (or 36 with `DISCOURAGE_OP_SUCCESS`) before the initial
   stack guard and the 520-byte item check; not found → stack guard, then
   `PUSH_SIZE`, then admit.

The original `cell_witness_push_size` ordering lemma is retained and still
proved, so the branch decision and the ordering are both checked.

This is **not** a proof for arbitrary script length.  Six bytes is the explicit
cell bound (see "Bound selection").  Scripts longer than six remain the
SCR-153-style loop/induction blocker.

## Proof obligations

| function | Alive2 | SAW (bitwuzla) | note |
|---|---|---|---|
| `cell_witness_push_size` | green (syntactically equal) | 2 proofs green | ordering lemma, abstract `has_success` |
| `cell_witness_push_size_scan` | green, non-trivial SMT (~38 s) | 2 proofs green | scan derived from six symbolic bytes |

Alive2 result tail:

```
Transformation seems to be correct! (syntactically equal)   # ordering lemma
Transformation seems to be correct!                          # scan decision
Summary: 2 x (1 correct, 0 incorrect, 0 failed, 0 errors)
STATUS=alive2-green
```

SAW result tail:

```
Proof succeeded! cell_witness_push_size
Proof succeeded! cell_witness_push_size
Proof succeeded! cell_witness_push_size_scan
Proof succeeded! cell_witness_push_size_scan
CELL_LIMITS_WITNESS_PUSH_SIZE_SAW_GREEN
STATUS=saw-green
```

The scan compare is not syntactic equality: the C and L decode paths differ
(Lean keeps a push-vs-`.op` distinction), so Alive2 discharges it with SMT.

## Concrete sanity check (not proof evidence)

Driver against the built C leaf:

```
tap 0x50 success, item 600                 result=1 error=0
tap 0x50 success + discourage              result=0 error=36
tap truncated push, item 600               result=0 error=6
tap 0x00 x4 then 0x50                      result=1 error=0
tap 00 00 00 00 00 02, item 600            result=0 error=6
tap no success, depth 2000                 result=0 error=8
base item 600                              result=0 error=6
v0 item 600                                result=0 error=6
tap no success, item 600                   result=0 error=6
```

`0x50` (OP_RESERVED, in the OP_SUCCESSx set) beats the 600-byte item and the
2000-item stack; a `0x50` after four empty pushes is found; a truncated push
before any success is not found, so the item check applies.

## Bound selection (measured, not assumed)

| bound | function | tool / solver | outcome |
|---|---|---|---|
| 4 | scan (prototype) | Alive2 / SAW abc | green (existing tapscript-prescan scale) |
| 5 | scan only | SAW abc | green, ~2m08 both legs |
| 6 | scan+decision | SAW bitwuzla | green, ~1m58 both legs |
| 6 | two functions, 4 proofs | SAW bitwuzla | green, ~3m21 total |
| 6 | scan+decision | Alive2 `--smt-to=120000` | green, ~38 s |
| 8 | scan only | SAW bitwuzla | 5-minute timeout on second leg |

Alive2's default 10 s SMT budget is too small for the six-byte scan; the cell
runner passes `--smt-to=120000`.  Six is the largest instance both tools
discharged comfortably with this encoding.

A design note: the scan uses a sticky `found` flag rather than an early
`return true`.  With an early return, clang -O1 leaves an `undef` on the dead
false arm of the success test; Alive2 correctly reports a branch-on-poison
hazard even when the concrete value is defined.  The sticky form keeps the
false arm live and removes the undef.

## Exact commands

```sh
bash spec/equiv/cells/limits/C-L-witness-push-size/alive2/run.sh   # ~38 s
bash spec/equiv/cells/limits/C-L-witness-push-size/saw/run.sh      # ~3m21
python3 spec/equiv/tools/normalize_certificates.py
sha256sum -c spec/equiv/cells/limits/C-L-witness-push-size/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/limits/C-L-witness-push-size/saw/certificate.sha256
```

Certificate verification: every listed file `OK` for both legs.

## Limits / non-claims

- **Script length > 6** is outside the cell.  The scan is unrolled, not proved
  by a loop invariant.  Arbitrary-length `opSuccessScan` is the same feature
  that blocks SCR-153.
- The scan compares the **found bit**.  A truncated push before any success
  and end-of-script both fold to "not found" (Core and Lean agree on the found
  bit); Core's `BAD_OPCODE` error kind on a malformed tail is
  F-DIV-w32-001 / SCR-153, not SCR-021.
- `EvalScript` is still a stub, but the row ends before it.
- The 520-byte item predicate, the SCR-031 stack guard order and the BIP342
  exemption order are fully symbolic and unbounded in depth/max_item.
- The L leg is a reviewed transliteration of `Defs.lean` because the generated
  twin has no witness engine at the pin.
- No Core patch, no crypto.

## Proposed ledger note (for the LEDGER/integration owner)

The shared `spec/db/equiv-cells.yaml` was intentionally not edited.  Suggested
replacement for SCR-021's `gap_note`:

> partial (bounded script): the item-size predicate, the SCR-031 ordering and
> the BIP342 exemption are proved; `limits/C-L-witness-push-size` now also
> decides `opSuccessScan` over symbolic script bytes of length 0..6 (all byte
> values) and feeds the result into the same decision, so the row's
> "containing OP_SUCCESSx" branch is proved for every script of length ≤ 6.
> Remaining: scripts longer than 6 (unrolled scan; arbitrary length needs the
> SCR-153 loop/induction), and the BAD_OPCODE-vs-size-error ordering on a
> truncated tail (F-DIV-w32-001), which is not part of this row.  EvalScript
> remains outside the cell.

Suggested `cells` entry: keep `limits/C-L-witness-push-size`; its `alive2`
and `saw` records are green for both functions.
