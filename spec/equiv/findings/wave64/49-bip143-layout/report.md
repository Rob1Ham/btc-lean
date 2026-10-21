# wave64 / 49-bip143-layout — SCR-140 independent audit

Scope: independent audit/extension of the SCR-140 BIP143 preimage layout
cells — field order, field offsets, amount inclusion, and the
hashOutputs/hashSequence slots. No shared file was edited; this report and
the new cell are additive.

- Base commit: `5946c02` (branch `wave64/49-bip143-layout`).
- Contract: `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`.
- Core pin: `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
  (interpreter.cpp:1655-1670).
- New cell: `spec/equiv/cells/witness-v0/C-L-bip143-layout-bytemap/`.
- Tool versions: Alive2 v20.0 (LLVM 20.1.2), clang 20.1.2, SAW 1.6
  (`68eed5f`), z3 4.8.12.

## 1. Independent check

The new cell observes the preimage as an **absolute byte map**, not the
width|offset descriptor of `witness-v0/C-L-bip143-layout`:

| function | observable |
|---|---|
| `field_start(field, len)` | absolute start; id 10 = total length |
| `field_width(field, len)` | width |
| `field_byte(field, lane, ...)` | byte at a lane inside a field |
| `byte_tag(pos, len)` | owning field tag at an **absolute** position |
| `amount_at(k, len, amount)` | amount byte k, gated on the slot's tag |

`field_byte` sources the three sub-hash fields from the external same-hash
seam `bip143_sha256d_lane(seed, lane)`, with seeds for hashPrevouts (field 1),
hashSequence (field 2), and hashOutputs (field 7). Alive2 treats the external
as uninterpreted but identical on both legs; SAW overrides it with the
deterministic `seam_word` from `cell.cry`. Real SHA256d is abstracted; the
cell claims placement/wiring only.

### Result (real tools)

```text
alive2: 5/5 functions "Transformation seems to be correct!",
        0 incorrect / 0 failed-to-prove / 0 Alive2 errors
        STATUS=alive2-green
saw:    20/20 "Proof succeeded!" (5 functions x C/L + 5 spot laws x C/L)
        STATUS=saw-green
sha256sum -c alive2/certificate.sha256   -> all OK
sha256sum -c saw/certificate.sha256      -> all OK
```

Evidence digests (sha256 of raw output files):

```text
058c1b5e72f0aee90c4d69006c4e0f8120ac75ebfc23b3441b27db6c841bcb62  alive2/result.txt
81aaefafef6a19f63e707f6cd2ea6a616bb8f8427c871b2a1a1290c44ad15e76  saw/result.txt
```

Tracked-input certificates hash the runner, both sources, `fns.txt`,
the Cryptol/SAW spec (SAW cert), the extracted IR, `spec.md`, and the raw
result. Build products (`build/`, `*.bc`) are ignored.

### Non-vacuity

Two mutants were run in temporary copies (not committed):

1. L moves the amount after nSequence (start 105 -> 113, nSequence ->
   105): Alive2 rejects `field_start` with `105` vs `113`, and rejects
   `amount_at` (source 1, target 0).
2. L swaps the hashSequence/hashOutputs seeds: Alive2 rejects
   `field_byte` (`Transformation doesn't verify`, external call
   mismatch).

## 2. Comparison with the existing SCR-140 cells

Existing layout cell:
`spec/equiv/cells/witness-v0/C-L-bip143-layout/`.

A programmatic comparison evaluated both cells' L-source expressions at
script lengths 0, 1, 17, 75. All ten starts/widths and the total matched:

```text
RESULT: ALL MATCH
e.g. len=0:  amount gap/new start 105/105, hashSequence 36/36,
             hashOutputs 117/117, total 157/157
     len=75: amount 180/180, hashSequence 36/36, hashOutputs 192/192,
             total 232/232
```

Semantic sources agree as well:

- Lean `bip143MsgL` order (Digest.lean:288-302): version, hashPrevouts,
  hashSequence, outpoint, scriptCode, amount, nSequence, hashOutputs,
  locktime, hashtype.
- `PDW58.lean:77-92` total `124 + outpoint_hash_size + encCSL(len) + len`
  equals `157+len` for a 32-byte txid and one-byte CompactSize, matching the
  new cell's `field_start(10, len)`.
- `hashSequenceL` (Digest.lean) is a 32-byte field; `hashOutputsL` is a
  32-byte field selected by the hashtype/SINGLE rules. The layout cell places
  them at ids 2 and 7; the new byte map independently returns tags 3 and 8 at
  `[36,68)` and `[117+len,149+len)` and wires `seedS`/`seedO` respectively.
- SCR-141's `C-L-bip143-hashoutputs-single-oor` concerns which value fills the
  field-7 slot; it is orthogonal to, and consistent with, this layout.

**No layout, offset, amount, or sub-hash-slot mismatch was found.**

Documentation-only differences:

- Numbering: Lean/PDW comments call the amount "field 6" (1-based); the equiv
  cells use id 5 (0-based). The same slot. `C-L-bip143-layout/notes.md`
  already flags this; suggest saying "id 5 (0-based) / field 6 (1-based)".
- The existing cell's `spec.md` says `tool_status: both-green` while
  `spec/db/equiv-cells.yaml` for SCR-140 still carries `alive2: null`,
  `saw: null` and `status: gap` (see finding 1).

## 3. Findings (no shared edit made)

### F1 — SCR-140 ledger record is stale relative to the existing cell

`spec/db/equiv-cells.yaml` SCR-140 lists
`cells: [witness-v0/C-L-bip143-layout]`, `alive2: null`, `saw: null`,
`status: gap`, while
`C-L-bip143-layout/{alive2,saw}/result.txt` are green and both certificates
verify. The row note ("partial") may justify keeping `status: gap`, but the
null tool records do not reflect the committed evidence. Also, the new cell
`C-L-bip143-layout-bytemap` is not in the ledger `cells:` list. Ledger writes
belong to the orchestrator (shared file); recommendation: run
`update_ledger.py --from-cells`, then add the new cell id and keep the partial
note (this cell does not model preimage contents/SHA256, so SCR-140 is still
not full).

### F2 — Committed certificates of the existing cell are not reproducible with the committed runner

The existing `alive2/certificate.sha256` has 18 entries, including
`notes.md`, `saw/result.txt`, `saw/run.sh`, `src/cell.cry`, `src/cell.saw`,
`src/solver.txt`. The committed `_tools/run_alive2.sh` writes a 12-entry
certificate and does not add those files. A rebuild of the cell in a
relocated copy produced exactly the 12-entry list:

```text
committed (normalized):  alive2 result/run, 4 IR, notes.md, saw result/run,
                         spec, src 6, _tools 2
regenerated:             alive2 result/run, 4 IR, spec, c/l source, fns,
                         _tools 2
```

Same for `saw/certificate.sha256` (18 committed vs 14 regenerated). The
cells' certificates were therefore produced by a different generator than the
one now in the tree; `sha256sum -c` passes only because the old files are
still present, not because the runner reproduces them. Recommend unifying the
certificate generator or recording the generator version in `spec.md`.

### F3 — IR and certificate hashes are build-path dependent

Committed IR embeds absolute paths:

```text
; ModuleID = '/tmp/opencode/equiv-pr/spec/equiv/cells/witness-v0/C-L-bip143-layout/build/c_cell_bip143_field.bc'
source_filename = "/tmp/opencode/equiv-pr/spec/equiv/cells/witness-v0/C-L-bip143-layout/src/c_cell.cpp"
```

A rebuild in another directory differs only in those two lines; the
certificate then differs. The new cell has the same property (its IR embeds
`/tmp/opencode/wave64/49-bip143-layout/...`). Recommend compiling with
`-ffile-prefix-map` / relative paths and hashing normalized IR, otherwise
"tracked-input" certificates are checkout-location-bound.

### F4 — `_tools/run_saw.sh` can report `saw-green` after a SAW script error

Probe (reproduced, evidence in `saw-status-probe.txt`): append an unknown
function to `cell.saw` after the valid proofs. SAW prints 20
`Proof succeeded!`, then a stack trace / `Could not find definition ...`, and
the runner still writes `STATUS=saw-green` and exits 0. The classifier only
looks for `Proof failed` / `saw: error` and counts proofs. Recommendation:
treat `Error`, `Stack trace`, and a missing final success marker as red. The
new cell's committed SAW output contains no such error (checked explicitly),
but other cells relying on this runner could be falsely green.

### F5 — No semantic mismatch in the audited cells

The existing cell, the Lean definitions (`PDW23`, `PDW58`, `PDW58D`), and the
new byte map agree on field order, the 8-byte LE amount at id 5, and the
hashSequence/hashOutputs slots at ids 2 and 7. The remaining limits are the
ones already filed: sub-hash contents, transaction serialization, final
SHA256d, and multi-byte CompactSize (`len > 75`).
