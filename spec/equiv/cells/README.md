# Cell records

A **cell** is the unit of proof, review, and coverage. One directory per cell:

```
cells/<family>/<cell-id>/
  spec.md            # precondition, postcondition, direction, contract domain
  alive2/
    run.sh           # exact command(s), tool version from PINS.lock
    result.txt       # raw output
    certificate.sha256
  saw/
    run.sh
    result.txt
    certificate.sha256
  notes.md           # gap reason, patch dependency, trust note
```

## Naming

- `<family>`: `stack`, `flow`, `numeric`, `hash`, `checksig`, `cms`,
  `locktime`, `segwit0`, `taproot`, `disabled`, `limits`, `whole`.
- `<cell-id>`: `C-L-<op-or-rule>-<variant>` when comparing Core to the Lean
  twin; `C-R-<op-or-rule>-<variant>` for Core vs rbitcoin; `L-R-...` for the
  direct pair (optional cross-check).

## Required content of `spec.md`

1. `contract:` hash of `contract/ABI.md` and `contract/tape.md`.
2. `legs:` C, L, R (which pair this cell compares).
3. `precondition:` the exact subset of the tape domain (e.g. base sigversion,
   no flags, script length <= 10000).
4. `postcondition:` verdict and error_kind relation (equality, refinement
   direction).
5. `direction:` `L ⊑ C`, `C ⊑ L`, `R ⊑ C`, `C ⊑ R` — one file may hold
   several, each with its own result.
6. `scr_rows:` the SCR rule IDs this cell covers (must exist in
   `spec/db/equiv-cells.yaml`).
7. `patches:` patch ids from `patches/README.md`, or `none`.
8. `trust_note:` anything the cell relies on beyond the global trust base
   (e.g. crypto checker overridden as symbolic).

## Both-tool rule

Every cell records an `alive2/` **and** a `saw/` attempt when the IR feature
set permits. If a tool cannot express the cell, `notes.md` names the blocking
feature (invoke, indirect call, ptrtoint, loop, LLVM version) and a `TOOL`
finding id. Absence of a directory is a gate failure; inapplicability is a
recorded result.

## Status meanings

- `both-green` — both tools prove the cell in every required direction.
- `alive2-green` / `saw-green` — one tool proves it; the other is recorded
  as inapplicable with a named feature.
- `unjudged-seam` — the cell depends on crypto outside the abstracted
  checker (must cite `DECISION-lax-ecdsa.md` and the finding).
- `gap` — not proved; `notes.md` and the ledger carry the reason and the
  next action.

No cell may be marked green while an associated finding is open.

## Milestone gate cells (E1)

REDTEAM's mutation catalogue (`cells/_redteam/MUTATIONS.md`) names gate cells
under `cells/e1-stack/`, `cells/e1-altstack/`, `cells/e1-push/`. These are
first-class cells, not aliases: their ids are consumed verbatim by
`mutate.py`'s expected-failing lists. They map to the `stack-ops` ledger
family. Broader exploratory cells may live under `cells/stack/` with the
`C-L-*` naming.

The first gate batch, buildable against the twin's current E1 surface
(pushes, flow, altstack, DROP/DUP/NIP/OVER/PICK/ROT/SWAP/TUCK, 2*/3*/DEPTH/
SIZE/IFDUP/EQUAL):

| Gate cell | Witness (spk bytes) | Baseline | Mutant |
|---|---|---|---|
| `cells/e1-stack/swap-order` | `51 52 7c 51 87` | pass | `OP_SWAP` no-op → fail |
| `cells/e1-stack/dup-order` | `51 52 76 52 87` | pass | `OP_DUP` duplicates second-from-top → fail |
| `cells/e1-stack/rot-direction` | `51 52 53 7b 51 87` | pass | opposite rotation → fail |
| `cells/e1-altstack/roundtrip` | `51 52 6b 6c 52 87` | pass | `TOALT`/`FROMALT` swapped or main-stack acting → fail |
| `cells/e1-stack/depth-count` | `51 51 74 52 87` | pass | off-by-one depth → fail |
| `cells/e1-stack/pick-depth` | `51 52 53 52 79 51 87` | pass (`OP_2` selects the bottom `1`) | off-by-one pick → fail |

All six were checked on the current C and L builds on 2026-10-19:
`(1, 0)` for both legs, with the earlier wrong `PICK` witness
`51 52 53 52 79 52 87` returning `(0, 2)` on both and therefore **not** usable
as a baseline. Base sigversion, flags 0, empty scriptSig, fully parseable (so
F-DIV-001 does not apply). A gate cell must be green on unmutated sources
before REDTEAM may apply the mutant.

