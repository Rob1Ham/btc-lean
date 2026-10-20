# Wave 16 / `01-exec-verify` — advancing SCR-001..SCR-017

Task: convert honestly provable `exec-verify` SCR rows into real both-tool
green cells, and narrow the rest to precise, reproducible blockers.

- Worktree: `/tmp/opencode/wave16/01-exec-verify`
- Branch: `wave16/01-exec-verify`, cut from PR #29 head `805c804`
- Pin: `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
- Contract hash: `f1841e36…7773c1c6` (v3, unchanged)
- Cells: `spec/equiv/cells/exec-verify/C-L-*` (6 new cells)
- Shared runners: `spec/equiv/findings/wave16/01-exec-verify/tools/`

Nothing in the ledger, results, contract, pins, twin, shims, Lean or census
was edited.  Every cell is `patches: none`.

## Result at a glance

| Cell | Alive2 | SAW | Rows | Coverage |
|---|---|---|---|---|
| `C-L-flags-domain` | green (3 cmps) | green (6 proofs) | SCR-009, SCR-014 | **full** (contract level) |
| `C-L-eval-empty` | green (1 cmp) | green (2 proofs) | SCR-003 | **full** (zero-op frame) |
| `C-L-verifyscript-tail` | green (2 cmps) | green (4 proofs) | SCR-002, 008, 011, 013 / SCR-004, 012 | **full** / **partial** |
| `C-L-p2sh-handoff` | green (2 cmps) | green (4 proofs) | SCR-007 / SCR-005 | **full** / **partial** |
| `C-L-pushonly` | green (3 cmps) | green (6 proofs) | SCR-006, SCR-010 | **partial** |
| `C-L-failure-propagation` | green (1 cmp) | green (2 proofs) | SCR-017 | **full** |

Net: **9 rows both-tool green with full coverage** (002, 003, 007, 008, 009,
011, 013, 014, 017), **5 rows advanced to explicit partial** (004, 005, 006,
010, 012), **3 rows filed as precise no-go** (001, 015, 016).  No row was
made green by weakening a claim.

## Method (identical for all six cells)

Each cell is a bounded, line-cited source slice, in the shape of the existing
`cells/e4-witness/C-L-witness-v0-dispatch` cell:

- `src/c_cell.cpp` — C leg: a direct transliteration of the cited Core lines
  (`interpreter.cpp` / `script.cpp`), presenting the same packed observable.
- `src/l_cell.cpp` — L leg: the reviewed Lean transliteration
  (`spec/core/Bitcoin/Interpreter/Defs.lean`,
  `spec/core/Bitcoin/Script/Parser/Defs.lean`), same observable, same
  signature.
- Alive2 compares C↔L for every exported function (`alive-tv` on the two
  `llvm-extract --recursive` leaves).
- SAW verifies **both** legs against one independently written Cryptol
  function (`saw/cell.cry`), so the postcondition does not come from either
  leg: each function is checked twice (`2 × |FNS|` `Proof succeeded!`).
- `certificate.sha256` hashes `spec.md`, both `run.sh`/`cell.saw`/`cell.cry`
  inputs, the shared tool sources, the emitted `.ll`/`.bc`, and the raw
  `result.txt`; it verifies with `sha256sum -c` from the repo root.
- `build/` is git-ignored, so a certificate is only valid **after** running
  the cell.  Certificates were regenerated after the last edit of every
  `spec.md` and of the shared runners.

No patch, no shim change, no pin change.  Crypto/hash is out of scope in all
six cells (none of them contains a hash, signature or curve operation), so
the same-crypto premise is satisfied vacuously and is stated in each
`trust_note` where a shape predicate (P2SH / witness-program) stands in for a
real script execution.

## Row dispositions

### Both-tool green, full coverage

- **SCR-002** — *After scriptPubKey eval, stack non-empty and top
  CastToBool-true*.  `C-L-verifyscript-tail::cell_vs_tail`: for every
  post-eval depth 0..3, every 0/1-byte top, every flag mask.  `CastToBool` is
  modelled exactly (empty / `0x00` / `0x80` false).
- **SCR-003** — *Empty/short script evaluates to success with unchanged
  stack*.  `C-L-eval-empty::cell_eval_frame`.  The zero-op family is exactly
  the empty script: any non-empty script yields at least one opcode from
  `GetScriptOp` (possibly `OP_INVALIDOPCODE`).  Proves success + unchanged
  stack, and `UNBALANCED_CONDITIONAL` (20) when the conditional vector is
  non-empty at loop exit (1248-1250).  Explicitly **not** covered: execution
  of one or more opcodes ("short script with ops") — E5 dispatch residual.
- **SCR-007** — *stackCopy (taken after scriptSig) is restored for subscript
  eval*.  `C-L-p2sh-handoff::cell_p2sh_handoff`: for every captured stack
  (depth 0..3, symbolic bytes), the value consumed by the subscript call is
  the capture with its top popped, order and bytes preserved; the popped top
  is the redeemScript; arm gating proved.  Excluded: the unreachable
  `assert(!stack.empty())` arm (2074).
- **SCR-008** — *Exactly 1 element after all evaluation*.
  `C-L-verifyscript-tail::cell_vs_tail`: the CLEANSTACK check proved for
  every final depth, after the P2SH arm, with the witness `resize(1)` bypass,
  in Core's order.
- **SCR-009 / SCR-014** — *Flag-combination constraints* (asserts at
  2113-2114 / 2124).  `C-L-flags-domain`: `flags_guard`,
  `flags_assertsafe`, `flags_implication` proved for **all 2^64 masks**.
  `flags_implication` shows an ABI-accepted mask always satisfies both
  asserts, i.e. the assert path is unreachable inside the contract domain and
  the contract totalization to result 2 is exactly the assert's content.  Not
  claimed: the debug-build abort path itself.
- **SCR-011** — *scriptSig == ∅ for bare witness programs*.
  `C-L-verifyscript-tail::cell_vs_tail`: every scriptSig size.
- **SCR-013** — *Non-null witness without witness program fails*.
  `C-L-verifyscript-tail::cell_vs_tail`: every witness item count, with
  `hadWitness` derived from both witness arms; `WITNESS_UNEXPECTED` (43).
- **SCR-017** — *Any EvalScript/VerifyWitnessProgram failure ⇒ input
  invalid*.  `C-L-failure-propagation::cell_failprop`: all five return-false
  sites (2029-2031, 2034-2036, 2052-2054, 2080-2082, 2097-2099) wired in
  Core's order, callee `(ok, err)` symbolic in both directions.  Proves:
  no failure is swallowed, the returned ordinal is the failing callee's own,
  the first failure wins, and a failure at a non-entered arm has no effect.
  The callees' internals (E5) are not part of the row.

### Partial (explicit, not usable as row completion)

- **SCR-004** — `C-L-verifyscript-tail`.  Proved: WITNESS-off / empty
  scriptPubKey / single truthy element → pass; WITNESS-on + non-null witness
  + non-witness scriptPubKey → `WITNESS_UNEXPECTED` (43).  Missing: the
  scriptSig `EvalScript` that *produces* the truthy element (E5 dispatch),
  and the row's own explicitly-unproved CLEANSTACK-on one-element arm.
- **SCR-005** — `C-L-p2sh-handoff`.  Proved: the 23-byte
  `IsPayToScriptHash` shape predicate exactly (all four fields Core reads,
  arbitrary length/bytes) and the identification/transfer of the **last
  scriptSig stack element** as the subscript.  Missing: the subscript
  `EvalScript(pubKey2)` call (2080-2082) and its `EVAL_FALSE` checks
  (2083-2086) — E5 dispatch residual.
- **SCR-006** — `C-L-pushonly`.  Proved: exact `IsPushOnly`, `SIG_PUSHONLY`
  (26), arm gating, for every script of **0..8 bytes**.  Missing: scripts
  longer than 8 bytes (the unbounded `GetScriptOp` walk).
- **SCR-010** — `C-L-pushonly`.  Proved: policy-flag short-circuit and
  `SIG_PUSHONLY` over the same 0..8-byte domain.  Missing: the *sequencing*
  claim "before eval" (that the pre-check runs before the scriptSig
  `EvalScript` call) — whole-function composition, i.e. SCR-001.
- **SCR-012** — `C-L-verifyscript-tail::cell_single_push_eq`.  Proved: the
  `scriptSig == CScript() << redeemScript` comparison for redeemScript
  lengths 0..2 with the single-byte push encoding.  Missing: PUSHDATA1/2/4
  encodings (redeemScript ≥ 76 bytes).

The 8-byte bound in `C-L-pushonly` is a **bound on the input**, not on the
predicate: for every claimed input the whole Core loop body runs.  It is the
reason the two rows stay `partial` rather than green.

### No-go (precise blockers, reproducible)

- **SCR-001** — *Sequential evaluation, not concatenation* (2026-2036).
  Blocker: this is a composition property of the whole `VerifyScript` →
  `EvalScript` path.  A bounded leaf cannot state it: the C leg would need the
  real `EvalScript` (opcode dispatch, altstack, conditionals, all opcodes) as
  an inlined callee, which is exactly the E5 scoped residual
  (`findings/e5/E5-RESIDUAL.md`).  Abstracting the two calls to their
  outcomes (as `C-L-verifyscript-tail` and `C-L-failure-propagation` do) makes
  the "not concatenation" distinction unobservable, so no cell on that
  abstraction can honestly claim the row.  Next action: E5 must land a real
  `EvalScript` core first; the row then becomes a two-call composition lemma.
- **SCR-015** — *Away from named hash exceptions, P2SH/WITNESS/TAPROOT are
  enabled; DERSIG/CLTV/CSV/NULLDUMMY added at buried heights*
  (`validation.cpp:2249-2288`, `kernel/chainparams.cpp:115-118`).
  Blocker: the subject is the **flag word derived from block height and
  chainparams** (`GetBlockScriptFlags`, deployment states).  Neither the tape
  nor the ABI carries height, chainparams or deployment state — the flags word
  is an input at `contract/tape.md §5`.  No C/L leaf pair can observe the
  derivation, and adding height to the ABI would change the contract (not
  permitted).  `C-L-flags-domain` proves the *consumer* side of the same flag
  word.  Next action: a contract-level cell over `GetBlockScriptFlags` with
  height/chainparams in the tape, if the contract is ever extended.
- **SCR-016** — *Two named mainnet blocks get reduced flag sets*
  (`kernel/chainparams.cpp:115-118`, `validation.cpp:2262-2265`).
  Blocker: same as SCR-015 plus the two named block hashes; the reduction is a
  chainparams fact, not a script behaviour.  Next action: same as SCR-015
  (data/flag-derivation cell), not an interpreter cell.

## Validation

From the repo root `/tmp/opencode/wave16/01-exec-verify`:

```sh
for c in flags-domain eval-empty verifyscript-tail p2sh-handoff pushonly \
         failure-propagation; do
  bash spec/equiv/cells/exec-verify/C-L-$c/alive2/run.sh
  bash spec/equiv/cells/exec-verify/C-L-$c/saw/run.sh
  sha256sum -c spec/equiv/cells/exec-verify/C-L-$c/alive2/certificate.sha256
  sha256sum -c spec/equiv/cells/exec-verify/C-L-$c/saw/certificate.sha256
done
```

Observed on this host:

- all 12 `run.sh` exit 0 and every `result.txt` ends with its green status
  (`STATUS=alive2-green`, `STATUS=saw-green`);
- `sha256sum -c` reports `OK` for every file in all 12 certificates
  (14-24 hashed files each);
- Alive2 comparisons: 3 / 1 / 2 / 2 / 3 / 1 (`flags-domain`, `eval-empty`,
  `verifyscript-tail`, `p2sh-handoff`, `pushonly`, `failure-propagation`);
  SAW proofs: 6 / 2 / 4 / 4 / 6 / 2 — exactly `2 × |FNS|` in each cell.

Raw tails are in each cell's `alive2/result.txt` and `saw/result.txt`;
`notes.md` records the exact commands, tool versions and design limits.
`C-L-pushonly` is the slow cell: ~20 min for its 6 `abc` proofs on a host at
load average ~12, and ~1 min for Alive2 with `--smt-to=300000`.

Note on certificate lifetime: `build/` is git-ignored (repo convention, same
as `cells/e4-witness/C-L-witness-v0-dispatch`), so a certificate additionally
hashes the generated `build/*.ll`/`*.bc` and therefore verifies only after
that cell's `run.sh` has been executed in the checkout.

## Residual infrastructure notes

- `C-L-pushonly` needs `--smt-to=300000` for Alive2 (the 10 s default times
  out on the 8-step unrolled walk) and `abc` for SAW (z3 did not finish in
  15 min on these obligations).  Both are recorded in the cell's `cell.conf`
  / `saw/cell.saw` and in `notes.md`.
- A recursive L leg made Alive2 report a spurious "Function triggered UB";
  the L legs therefore use unrolled/iterative walks.  This is a tooling
  constraint on the *encoding*, not a semantic deviation; each cell discloses
  any L-vs-C structural deviation in `notes.md`
  (`C-L-verifyscript-tail`: `stack.resize(1)` vs Lean's length recomputation;
  `C-L-pushonly`: Lean's two passes combined into one walk).

## What is not claimed

- No unconditional equivalence of `VerifyScript`/`EvalScript`, and no
  whole-engine claim.  Every cell is bounded and says so in its
  `precondition`.
- No claim about opcode dispatch, `EvalScript` internals, `VerifyWitnessProgram`
  internals, or script execution (E5 residual).
- No crypto/hash implementation claim (no such operation occurs in these
  cells).
- SCR-015/016 are **not** covered at all; SCR-001 is not covered.
