# Core correspondence surface

This page records what the census can and cannot show about Bitcoin Core.
It is the issue 22 section 4 evidence page, not a claim of a mechanical
translation.

## Pinned surface

The normative source is Bitcoin Core v32.99 at commit
`cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`. Every proven consensus row in
[`spec/db/rules.yaml`](../spec/db/rules.yaml) has:

- a non-empty `core_ref` naming the file, function, and line anchor at that
  commit;
- a non-empty `lean_target` naming the declaration that carries the row's
  `@[rule "<ID>"]` tag;
- a row summary that is the statement under review for statement fidelity.

The generated [rule-census theorem index](THEOREMS.md) joins those three
fields for every row. The table is the mechanical correspondence surface:
it names the Core function and the Lean target. It is not a translation
proof, and a `proven` tag is not evidence that the Lean statement is the Core
accept/reject relation.

## What was checked

```sh
python3 spec/scripts/core_correspondence_check.py
python3 spec/scripts/gate_census.py
python3 spec/scripts/theorem_index.py --check
python3 spec/scripts/residuals_index.py --check
```

`core_correspondence_check.py` requires every proven row with
`consensus: true` to carry a Core anchor at the pinned commit and a Lean
target, and rejects the six out-of-ledger rows if they are still marked
`consensus: true`. The closeout run passes for all **611** proven consensus
rows.

## Statement fidelity

Statement fidelity is the semantic half: the Lean theorem must state the
whole Core rule, including both accept and reject branches. The current
per-row review is [`RESIDUALS.md`](RESIDUALS.md); its closeout state is **0
open residuals**, with the closing targets recorded in
[`ISSUE-22-CLOSEOUT.md`](ISSUE-22-CLOSEOUT.md). The remaining claim is still
conditional on the reviewed row summaries and the model's representation
choices; it is not a proof that the model's data types are Core's C++ types. In particular:

- `core_ref` is a citation, not a verified translation;
- `lean_target` is an index into the proof surface, not a paraphrase claim;
- `status: proven` means the target builds and carries the tag;
- the `consensus: false` rows are boundary evidence and are outside this
  surface.

The claims page [`CLAIMS.md`](CLAIMS.md) repeats these limits. Any future
change to a row's `core_ref`, `lean_target`, or summary must update this
page and the generated indexes in the same commit.
