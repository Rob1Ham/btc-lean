# Notes — C-L-altstack

## Status

`both-green` for the **bounded closed witnesses** listed in `spec.md`.
This is not a symbolic proof of the op law and not a whole-entry proof.

TOALTSTACK/FROMALTSTACK success and underflow witnesses.

## Witnesses

- `cell_alt_from_empty`: spk `6c` (`OP_FROMALTSTACK`) -> `0x000000000000004c`; result 0, err 19 INVALID_ALTSTACK_OPERATION, n=0
- `cell_alt_to_empty`: spk `6b` (`OP_TOALTSTACK`) -> `0x0000000000000048`; result 0, err 18 INVALID_STACK_OPERATION, n=0
- `cell_alt_roundtrip`: spk `51526b6c` (`OP_1 OP_2 OP_TOALTSTACK OP_FROMALTSTACK`) -> `0x0000000001202a01`; result 1, err 0, n=2 [1,2]

All scripts are fully parseable (F-DIV-001 does not apply) and run with base
sigversion, flags 0, empty scriptSig, amount 0, input 0.

## Alive2

Command: `alive2/run.sh`, which reads `alive2/manifest.txt` and runs
`/usr/local/bin/alive-tv build/c_<fn>.ll build/l_<fn>.ll` for each function.

Raw summary lines:

```text
### function: cell_alt_from_empty
Transformation seems to be correct!
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
### function: cell_alt_to_empty
Transformation seems to be correct!
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
### function: cell_alt_roundtrip
Transformation seems to be correct!
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
STATUS=alive2-green
```

All 3 extracted C/L pairs report `1 correct transformations`, `0 incorrect`,
`0 failed-to-prove`, `0 Alive2 errors`.  `alive2/certificate.sha256` hashes the
runner, manifests, shared sources, `twin/ops_ir.py`, `twin/gen.py`, the
generated header, all extracted IR, and the output.

## SAW

Command: `saw/run.sh`, which builds the per-function `.bc` files and one
combined `build/cell.saw`, then runs `(cd build && saw cell.saw)`.

Raw proof lines:

```text
Proof succeeded! cell_alt_from_empty
Proof succeeded! cell_alt_from_empty
Proof succeeded! cell_alt_to_empty
Proof succeeded! cell_alt_to_empty
Proof succeeded! cell_alt_roundtrip
Proof succeeded! cell_alt_roundtrip
STATUS=saw-green
```

There are 6 `Proof succeeded!` lines (3 functions × C and L).  The SAW
postcondition is each function's declared packed constant, **not** a symbolic
op law.  `saw/certificate.sha256` hashes the manifests, combined module, spec,
sources, and output.

## Behavioral whole-entry witnesses (not proof)

```text
### witness: alt_from_empty spk=6c expect=0,19
C=(0,19)
L=(0,19)
witness_status=behavior-match
### witness: alt_to_empty spk=6b expect=0,18
C=(0,18)
L=(0,18)
witness_status=behavior-match
### witness: alt_roundtrip spk=51526b6c expect=1,0
C=(1,0)
L=(1,0)
witness_status=behavior-match
STATUS=behavior-match
```

The real C and L `equiv_entry` libraries agree on every listed spk.  This is
behavioral evidence only.

## Coverage and limits

- These are **closed** edge witnesses, not the symbolic
  depth/stack/truth-domain cells originally planned.  No universal op law is
  claimed.
- SCR coverage is partial: only the concrete branches listed in `spec.md` are
  exercised; no stack-size, OP_COUNT, or symbolic-domain edge is covered.
- Whole-entry Alive2 is not ingestible (see
  `cells/_tools/gate/whole_entry_alive2_probe.txt`); no whole-entry green is
  claimed.
- `-O1 -fno-strict-aliasing` is used because the fully inlined `-O0` build did
  not finish in the Alive2 harness timeout.
- The runner regenerates `build/twin_ops.h` from `twin/ops_ir.py` and checks
  reproducibility.  A transient `ops_ir.py` mutation causes `DRIFT` and the
  runner stops rather than certifying a mixed source; this was observed during
  the M-E1-002 mutation exercise.
- For `C-L-dup-drop-swap` the success composition is deliberately sensitive
  to DUP order: the correct leaf ends `[1,2]` (packed `0x1202a01`), while a
  DUP-second-from-top mutant ends `[1,1]` and fails Alive2.
- F-ERR-TWIN-001 (whole-entry non-OK error-kind mapping) remains open; the
  leaf proves only the exact closed error ordinals listed here.
