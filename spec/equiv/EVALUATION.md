# Evaluator's checklist

For a reviewer who wants to check this workstream without trusting its own
summaries. Read `README.md` first, then work down this list.

## 0. What this tree can and cannot establish

- **Can:** that the three engines agree on the harness contract, as discharged
  by Alive2/SAW with recorded certificates, or that a cell is inapplicable with
  a named IR feature.
- **Cannot:** anything about the machine backend, the linker, the OS, libsecp
  internals, or live-network behavior. It is not a Lean-kernel theorem.
- **Conditional:** every result depends on the trust base in `README.md` §11.
  Your job is to decide whether you accept those premises.

## 1. Ten-minute check

```sh
cd spec/equiv
cat PINS.lock                 # are all pins filled, or clearly TODO?
make gate-ir-pin              # pins + hashes + SCR coverage + no unfiled gaps
make equiv                    # cell suite; regenerates results/matrix.md
```

Expected at E0: the gate reports incomplete coverage and exits non-zero,
because cells do not exist yet. That is correct behavior, not a failure. At
E6 every gate must pass.

## 2. Audit one green cell

Pick any cell marked `both-green` in `spec/db/equiv-cells.yaml`.

1. `spec.md` — is the precondition honest? Does the postcondition state
   verdict **and** error kind? Is the direction (`L ⊑ C`, etc.) explicit?
2. `alive2/run.sh`, `saw/run.sh` — do they use the pinned versions from
   `PINS.lock`? Do the commands actually reference the recorded IR hashes?
3. Recompute: `sha256sum` the IR inputs and compare with the record. Rerun
   the tool. Compare output.
4. `certificate.sha256` — does it hash the tool output you just reproduced?
5. `notes.md` — does it name any patch ids and the crypto override? Does the
   cell rely on unstated assumptions?
6. Check the SCR rows listed in `spec.md` exist in `spec/db/rules.yaml` and
   are marked covered in `spec/db/equiv-cells.yaml`.

Reject the cell if: the precondition hides a hard case, the error kind is
ignored, the tool version differs, the IR hash does not match, or a required
direction is missing.

## 3. Audit a patch

For every entry in `patches/README.md`:

1. The diff is minimal and localized; the intent is one thing.
2. Behavior-preservation evidence exists: a differential run against the
   **unpatched** build on the full corpus plus fuzz lanes, with command,
   corpus hash, and zero divergences.
3. The IR artifacts record `patched: yes` and the patch id.
4. The patch does not alter consensus semantics, limits, flags, error
   selection, or serialization.
5. The patch is upstreamable in principle, or the cell's trust note says why
   not.

Reject any patch without (2), and any cell that depends on a rejected patch.

## 4. Audit the coverage

1. `python3 results/scripts/coverage_report.py --strict` — must report
   183/183 SCR rows covered or filed.
2. For every `gap`, `unjudged-seam`, or `alive2-green`/`saw-green` (not
   `both-green`), open the finding. It must name the blocking feature
   (`invoke`, indirect call, ptrtoint, loop bound, LLVM version, crypto seam)
   and the next action.
3. Any `unjudged-seam` cell must cite `docs/DECISION-lax-ecdsa.md`.
4. No row may appear in the ledger with `status: planned` at E6.

## 5. Audit the trust base

For each premise in `README.md` §11, identify the results that depend on it.
At minimum:

- Front-end trust: are all legs lowered by the pinned compilers recorded in
  `PINS.lock`? Is the twin’s generator audited or is the transliteration
  fallback in use (and labelled)?
- Tool trust: which cells are Alive2-only, SAW-only, or both? Both-tool cells
  are stronger because the two tools have independent semantics and solvers.
- Same-crypto: every checksig cell must say the checker was overridden.
- Pins: no result may predate a pin change; re-pinning is a new result.

## 6. Red flags

- A green cell whose precondition excludes the interesting inputs.
- Error kind omitted or normalized away.
- A gap described as "tool limitation" without naming the IR feature.
- A patch without differential evidence.
- A result whose IR hash cannot be reproduced.
- Any sentence claiming unconditional Lean ≡ Core equivalence.

## 7. Milestone acceptance

| Milestone | You should see |
|---|---|
| E0 | hello-world triple green in `results/`; capability matrix with both tools' limits; `PINS.lock` complete |
| E1 | stack family cells, both-tool attempts, one passed mutation record |
| E2 | flow/numeric/hash cells; gaps filed |
| E3 | checksig/CMS cells with symbolic checker; error-enum equality note |
| E4 | witness/taproot dispatch; seam-unjudged cells enumerated |
| E5 | whole-function cell or scoped residual naming the IR blocker |
| E6 | `gate-ir-pin` and `make equiv` green; 183/183 coverage; matrix + trust base published |
