# Selected research notes

These are selected survey notes from the project's 2026-10-16 research pass.
They are background material, not proof claims or rule anchors. Statements such
as "no Lean 4 Bitcoin formalization" describe the prior-work landscape at that
date, not the current tree. The canonical
rule anchor for the proof tree is the Core commit recorded in
`spec/db/rules.yaml` (`cce32b168…`); the reports below record the exact upstream
commit they read at the time, which is sometimes a later master snapshot.
Toolchain versions and counts are likewise historical; the repository pins and
the checked census are authoritative.

| Note | Scope |
|---|---|
| [Mechanized models](mechanized-models.md) | prior proof-assistant and model-checking work on Bitcoin, and what it covers |
| [Conformance testing](conformance-testing.md) | Core/BIP vector inventory, Lean execution options, and a layered harness design |
| [Theorem portfolio](theorem-portfolio.md) | a five-tier theorem plan and its crypto dependencies |
| [Formality ladder](formality-ladder.md) | trust levels, axiom policy, `sorry` accounting, and the TCB inventory |

The notes are descriptive. Where they recommend a design, the recommendation is
not a claim that the tree implements it. Counts and status labels come from the
surveys and may differ from the current generated indexes; use
`spec/db/rules.yaml` and the theorem index for the current census.
