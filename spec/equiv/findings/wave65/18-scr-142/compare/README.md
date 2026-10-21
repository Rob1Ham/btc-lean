# SCR-142 pin-vs-model probe

Finding-scoped, not a ledger cell. One exported symbol `cell_compare` is
built six times from `variants.cpp` (`-DVARIANT=1..6`) so Alive2 always sees
matching names and signatures:

| variant | flags | height | hash |
|---|---|---|---|
| 1 | pinned `GetBlockScriptFlags` slice @ cce32b168 | 709631 | symbolic |
| 2 | pinned slice | 709632 | symbolic |
| 3 | historical BIP9 model (TPR-078) | 709631 | symbolic |
| 4 | historical BIP9 model | 709632 | symbolic |
| 5 | pinned slice | 692261 | taproot exception `…1e395ad` fixed |
| 6 | historical BIP9 model | 692261 | taproot exception `…1e395ad` fixed |

Alive2 pairs (`alive2/run.sh`) and the expected outcome:

| pair | expected | meaning |
|---|---|---|
| 1 vs 2 | EQUIV | the pin's TAPROOT observable is height-inert |
| 3 vs 4 | DIFF | the model's 709632 gate is live (non-vacuity) |
| 2 vs 4 | EQUIV | pin and model agree at activation |
| 1 vs 3 | DIFF | pin and model differ below activation |
| 5 vs 6 | EQUIV | pin and model agree at the exception block |

SAW (`saw/run.sh`) proves variants 1 and 2 against one height-free pinned
predicate, i.e. the same statement as pair 1/2 without Alive2's
bidirectional framing.

Run:

```sh
bash spec/equiv/findings/wave65/18-scr-142/compare/alive2/run.sh
bash spec/equiv/findings/wave65/18-scr-142/compare/saw/run.sh
```

The DIFF pairs are successes for this probe: they are the raw
counterexamples showing that the historical height clause is not a
`cce32b168` property. Do not read `STATUS=probe-as-expected` as an
equivalence result for the row.
