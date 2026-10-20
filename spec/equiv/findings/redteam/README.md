# REDTEAM findings — format, dispositions, acceptance

**Status:** design, E0. **Owner:** REDTEAM.
**Normative protocol:** `cells/_redteam/PROTOCOL.md`; mutation catalogue:
`cells/_redteam/MUTATIONS.md`.

This directory holds adversarial results: mutation-test outcomes, harness
attacks, differential-oracle weaknesses, unjudged-cell inflation, pin/replay
defects, and milestone sign-offs. It does **not** replace the per-cell records
or the main `findings/` ledger.

---

## 1. Directory layout

```
findings/redteam/
  README.md                 # this file
  redteam-report.md         # current summary + open questions
  RT-<nnn>-<slug>.md        # one finding per file
  signoffs/E<n>-<date>.md   # milestone sign-off records + JSON manifest
  logs/                     # immutable command/log captures, content-addressed
  mutants/                  # optional narrative mirror of cells/_redteam/mutants/
```

The authoritative mutant records are written by `mutate.py` under
`cells/_redteam/mutants/`. Narrative findings here cite their record hash; do
not hand-edit a mutant JSON record.

---

## 2. Finding format

Every finding gets a stable `RT-<nnn>` id and a file
`RT-<nnn>-<slug>.md`:

```markdown
# RT-<nnn>: <one-line title>

- **milestone / family:** E<n> / <family or harness>
- **class:** MUT | HARNESS | ORACLE | GAP | PIN | REPLAY | CONTRACT | ENUM
- **severity:** S1 | S2 | S3 | S4
- **status:** open | fixed | accepted-risk | rejected
- **cell(s):** <paths or n/a>
- **mutant id / record:** <M-E… / cells/_redteam/mutants/…json or n/a>
- **owner:** <role>
- **opened:** <YYYY-MM-DD>
- **closed:** <YYYY-MM-DD or —>

## Observed

What happened, including the exact command and the failing assertion. No
summaries that hide the counterexample.

## Expected

What the protocol/cell claimed should happen.

## Evidence

- target before/after sha256:
- IR sha256 / pin:
- corpus hash:
- command:
- log path + sha256:
- witness tape (hex, verbatim):
- certificate/proof object hash:

## Disposition

<fixed | accepted-risk | rejected | open> — rationale and required follow-up.
For `fixed`: the new run hashes and the re-test result.
For `accepted-risk`: the named scope, residual risk, and human sign-off.
For `rejected`: the counter-evidence and second reviewer.

## Promotion

If this finding affects a cell ledger entry, the owning role mirrors it as
`F-<area>-<nnn>` in the main findings ledger and cites `RT-<nnn>`.
Promotion status: <pending | F-… | n/a>.
```

Class definitions:

| Class | Covers |
|---|---|
| `MUT` | mutant survived, invalid kill, equivalent-mutant adjudication, reversion failure |
| `HARNESS` | shim logic, tape/ABI defect, panic/exception handling, determinism |
| `ORACLE` | differential blind spot, shared-bug correlation, sensitivity canary failure |
| `GAP` | unjudged cell counted green, inadmissible gap reason, coverage inflation |
| `PIN` | tool/commit/flag/IR hash drift, stale pin, non-hermetic build |
| `REPLAY` | certificate/log reuse, missing hash, unbound spec, replay failure |
| `CONTRACT` | ambiguity, error precedence, unspecified result `2`/`3` behavior |
| `ENUM` | error-enum mapping collision, unmapped value, alias, wrong taxonomy |

Severity:

- **S1** — invalidates a milestone claim or a published green result.
- **S2** — invalidates a family/cell or a required mutation.
- **S3** — localized apparatus defect with a workaround.
- **S4** — process/documentation issue.

An open S1/S2 finding blocks sign-off for every affected cell and family.

---

## 3. Disposition rules

1. **No green cell may hide an open S1/S2 finding.** A cell is not green while
   an affected finding is open.
2. **`fixed` requires a re-run**, not an edit. Record the new command, hashes,
   and baseline/mutant result. A fix without a re-test is `open`.
3. **`accepted-risk` requires** a named scope, a written residual-risk
   argument, and a human sign-off. It cannot be used for a missing required
   mutation or a survivor.
4. **`rejected` requires counter-evidence** and a second reviewer. "I disagree"
   is not a disposition.
5. **No closure by deletion or renaming.** Deleting the cell, renaming
   `UNJUDGED` to `GAP`, narrowing the domain, or removing the mutant from the
   catalogue does not close a finding. Such a change is a new finding.
6. **Counterexamples are preserved verbatim** (tape bytes + expected/actual).
   A finding without a replayable witness is not `fixed`.
7. **Append-only.** Corrections are new findings or a dated addendum; do not
   rewrite history.
8. **Promotion is not optional** when a cell ledger entry is affected. REDTEAM
   cannot write the main ledger; the owning role mirrors the F- finding and
   cites the RT id.

---

## 4. Acceptance rule: a green family needs a passed mutation test

> **A green family without a passed mutation test is not accepted.**

"Green family" means the family matrix, both-tool attempts, certificates, and
gap ledger all look complete. That is necessary, not sufficient.

A **passed mutation test** for a family requires all of:

- the required mutation subset for that milestone killed, or adjudicated
  equivalent under `PROTOCOL.md` §2.5;
- at least one model-site and one core-copy kill (E1–E4);
- baseline green before the mutant run and green again after reversion;
- a concrete kill witness that reaches the mutated behavior;
- the cell spec and corpus hash unchanged between baseline and mutant;
- a complete mutant record (before/after sha256, diff, expected cell, observed
  result, logs, operator);
- a second operator/session reproduction of at least one mutant per milestone;
- no surviving required mutant and no open S1/S2 finding in the family.

A family that is green but has no passed mutation test is **not green for
sign-off**; it is `SIGNED-WITH-RESIDUALS` at best, and only if the missing test
is itself a named gap with a human-approved residual. The default is
`REFUSED`.

This rule applies per family and per milestone. E6 cannot be signed by
aggregating green cells; every E1–E4 family must carry its passed mutation set.

---

## 5. Sign-off records

Sign-offs live in `signoffs/E<n>-<YYYYMMDD>.md` and carry the manifest fields
from `PROTOCOL.md` §6.1. A sign-off is void if any of the following changes:

- `PINS.lock` or a tool/solver version;
- `contract/ABI.md` (contract hash);
- the corpus manifest;
- a cell spec or certificate for an audited cell;
- a declared patch set.

A re-pin or contract amendment requires a new sign-off, not an addendum to the
old one.

---

## 6. Evidence hygiene

- Commands are copy-pasteable from the repo root; logs are captured to
  `findings/redteam/logs/` and hashed.
- Screenshots are supplementary only; the command + log + hash is the evidence.
- Do not redact counterexamples. If a tape contains sensitive material (it
  should not), replace it with a deterministic generator and record the seed.
- Never cite a hash you did not compute. A missing artifact is a finding.
- A tool timeout is not a pass, a kill, or an inapplicability reason. It is an
  `INVALID` run or a resource finding; see `PROTOCOL.md` §5.2.
