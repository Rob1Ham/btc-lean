# Historical module names

The proof package contains module names that predate the current layout:
`BitcoinProofs.AF.PDW*`, `BitcoinProofs.PDW9`, `BitcoinProofs.Activation.PDW5`,
and the four `Rows*` modules under `AF/PDW60`. They are retained. This note
explains what the names do and do not mean, and how to navigate them without
relying on the numbers.

## 1. Why the names are retained

Fully qualified Lean names are part of the stable theorem surface:

- `spec/db/rules.yaml` stores a `lean_target` for every non-obsolete row, and
  those strings contain the historical module names.
- `@[rule "<ID>"]` tags and the axiom manifest refer to declarations by
  their fully qualified names.
- External readers cite theorem names, not directory names. Renaming a module
  would change every declaration name inside it.

Renaming theorem modules would therefore be a breaking API change with no
mathematical benefit. The names are opaque historical labels: they do not
encode a proof order, a priority, a row number, or a dependency rank. Read them
as stable identifiers, not as claims about the content.

The retention rule is: **no theorem-module renames**. New descriptive modules
may be added beside them; existing proof modules keep their paths and
declaration names.

## 2. The `AF/PDW*` family

`spec/proofs/BitcoinProofs/AF/` groups the row-facing proof modules. `AF` is a
historical grouping label with no semantic meaning in the candidate tree.

Each `PDW<n>` directory holds one or more standalone Lean modules:

| Pattern | Example | Meaning |
|---|---|---|
| `PDW<n>/PDW<n>.lean` | `AF/PDW22/PDW22.lean` | the module named for the group |
| `PDW<n>/PDW<n><suffix>.lean` | `AF/PDW95/PDW95d.lean`, `AF/PDW62b/PDW62b.lean` | a sibling module; the suffix distinguishes it from the others |
| `PDW<n>/<ROW>.lean` | `AF/PDW18/BLK101.lean`, `AF/PDW41/TPR012.lean` | a module named after the rows it closes |
| `PDW<n>/<DESCRIPTION>.lean` | `AF/PDW13/WitnessCommitmentReserved.lean`, `AF/PDW69TxCheck/PDW69TxCheck.lean` | a sibling module named for its subject |

The `<n>` is an assignment label. It is not the row number and does not sort
the modules by importance or dependency. `PDW69TxCheck` is a single directory
whose label includes a description; it is not a different namespace.

Most `AF/PDW*` modules are row-facing: they import the core model, state
theorems about it, and carry `@[rule]` tags. Some siblings (notably
`*Guards*.lean` and probe modules) only pin declarations for the axiom check and
carry no tag of their own. Do not assume every `.lean` file in a `PDW` directory
closes a row; use the tag search (section 4). The modules are not all imported
by `BitcoinProofs.lean`, so the import graph is not the right index either.

## 3. The `Rows*` family

`spec/proofs/BitcoinProofs/AF/PDW60/` contains four modules:

```text
RowsA.lean
RowsB.lean
RowsC.lean
RowsD.lean
```

They are sibling partitions of one row set. Each module is standalone: it
imports core modules, declares tagged theorems, and is not imported by another
`Rows*` module. The letter is a partition label, not a reading order or a
dependency rank. A theorem may live in any of the four, and the module docstring
is not an authority on the current row-to-file mapping; the `@[rule]` tag is.

## 4. Navigation rules

1. **Search the rule tag first.**

   ```sh
   grep -rn 'rule "BLK-106"' spec/core spec/proofs --include='*.lean'
   ```

   This works regardless of which historical module holds the theorem and
   whether the attribute lists one ID or several.

2. **Use `lean_target` only as a hint.** A target such as
   `BitcoinProofs.AF.PDW22.checkTransaction_vin_empty_reject` points at the
   `AF/PDW22/` directory, but the declaration may be in `PDW22.lean`,
   `PDW22b.lean`, or a descriptively named sibling. The dotted name gives the
   namespace, not the filename.

3. **Then search the declaration inside that directory.**

   ```sh
   grep -rn 'theorem checkTransaction_vin_empty_reject' \
     spec/proofs/BitcoinProofs/AF/PDW22
   ```

4. **If the target is a definition, use `lean_target` and the tag search.** Some
   rows anchor on an executable definition rather than a theorem (for example
   `Bitcoin.Consensus.TxCheck.checkTransaction`); the target and the `@[rule]`
   tag identify the proof face.

5. **Do not infer meaning from the number.** `PDW2` is not earlier than
   `PDW100` in any proof-theoretic sense, and a higher suffix is not a newer
   claim. The only ordering that matters is the rule ID and the `status` field.

## 5. Index by namespace

Generated from `spec/db/rules.yaml` by grouping the `id` prefix and counting
`status`; proof locations are the observed `@[rule]` tag sites in this snapshot.
Rows are rule dispositions, not theorem counts.

| Prefix | Rows | Proven | Obsolete | Principal core model | Representative proof locations |
|---|---:|---:|---:|---|---|
| `BLK` | 130 | 130 | 0 | `Bitcoin/Block`, `Bitcoin/Capstone`, `Bitcoin/Activation`, `Bitcoin/Ledger` | `AF/PDW13`, `AF/PDW28`, `AF/PDW43`, `AF/PDW50`, `ErrMap/E03` |
| `INV` | 176 | 139 | 37 | `Bitcoin/Interpreter`, `Bitcoin/Invariants`, `Bitcoin/Block`, `Bitcoin/Activation` | `AF/PDW22`, `AF/PDW44`, `AF/PDW48`, `AF/PDW58`, `AF/PDW67` |
| `SCR` | 183 | 183 | 0 | `Bitcoin/Interpreter`, `Bitcoin/Activation`, `Bitcoin/Numeric`, `Bitcoin/SigHash` | `AF/PDW60`, `AF/PDW73`, `AF/PDW85`, `AF/PDW89`, `AF/PDW95` |
| `SGN` | 11 | 11 | 0 | `Bitcoin/Crypto`, `Bitcoin/Capstone` | `AF/PDW58`, `AF/PDW69TxCheck`, `AF/PDW74`, `AF/PDW95` |
| `SWT` | 68 | 67 | 1 | `Bitcoin/Interpreter`, `Bitcoin/SigHash`, `Bitcoin/Capstone`, `Bitcoin/Activation` | `AF/PDW34`, `AF/PDW45`, `AF/PDW54`, `AF/PDW65` |
| `TPR` | 83 | 71 | 12 | `Bitcoin/Crypto`, `Bitcoin/Script`, `Bitcoin/Interpreter` | `AF/PDW17`, `AF/PDW25`, `AF/PDW35`, `AF/PDW41`, `AF/PDW56` |
| `TXV` | 75 | 75 | 0 | `Bitcoin/TxValidation`, `Bitcoin/DataLaws`, `Bitcoin/Consensus`, `Bitcoin/Serialization` | `AF/PDW40`, `AF/PDW59`, `AF/PDW63`, `AF/PDW4` |

The table is intentionally short. `spec/db/rules.yaml` is authoritative for
every row; this index only tells a reader where the bulk of each namespace
lives. The rule-ID meanings and status vocabulary are in `STRUCTURE.md`.
