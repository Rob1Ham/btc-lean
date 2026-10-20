# Notes — depth-count

## Status

`both-green` for the **bounded leaf cell**.  This is not a green claim for the
whole `equiv_entry` function; see “Whole-entry scope” below.

## Witness

- spk: `5151745287` (`OP_1 OP_1 OP_DEPTH OP_2 OP_EQUAL`)
- tape: base sigversion, flags 0, amount 0, input 0, empty scriptSig, no
  witness record, one input.
- fully parseable; F-DIV-001 does not apply.
- SCR coverage: **partial**, success branch only; DEPTH at 0/1 and larger CScriptNum encodings are not exercised.  The gate proves the concrete success
  branch, not the whole SCR row.

## Alive2

Command: `alive2/run.sh`, which builds the bounded leaves and runs

```sh
/usr/local/bin/alive-tv build/c_<fn>.ll build/l_<fn>.ll
```

Raw tail:

```text
Transformation seems to be correct!

Summary:
  1 correct transformations
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
```

`alive2/result.txt` is the complete raw output; `alive2/certificate.sha256`
hashes the runner, shared sources, `twin/ops_ir.py`, `twin/gen.py`, the
generated `twin_ops.h`, the extracted C/L IR, and the output.

## SAW

Command: `saw/run.sh`, which runs `(cd build && saw cell.saw)`.  The SAW spec
is the closed cell's declared packed observable (see `spec.md`); it verifies
the C and L extracted modules against the same Cryptol constant.

Raw proof lines:

```text
Proof succeeded! cell_depth_count
Proof succeeded! cell_depth_count
STATUS=saw-green
```

The postcondition is a concrete witness constant, **not** a symbolic op law.
`-O1 -fno-strict-aliasing` is used; a scratch fully-inlined `-O0` build was
attempted, but Alive2 did not finish in the 120 s harness timeout.  No `-O0`
proof or artifact is claimed.

## Behavioral whole-entry witness (not proof)

```text
c_lib=/tmp/opencode/cbuild/libequiv-core.so sha256=5fef1df004adae637ffd7d3d7bf7dc96700c552dc2c22729d0de06d81457fbb5
l_lib=/home/ubuntu/btc-lean-public/spec/equiv/twin/build/libtwin.so sha256=b9ed129b9a0bd719da789c7accab7e522f436b08eb33e8cd18874659edeea72b
C=(1,0)
L=(1,0)
witness_status=behavior-match
STATUS=behavior-match
```

The behavioral call is against the real C library and the real L library at
their recorded hashes.  It establishes only that the whole shims agree on this
concrete tape; it is not proof evidence.

## Mutation expectation

Mutant: OP_DEPTH returns depth-1.

Baseline pass; depth-1 is 1, so `OP_2 OP_EQUAL` compares 1 with 2 and the verdict flips to `(0,2)`.

The twin site of record for this cell is `twin/ops_ir.py`; `build_leaf.sh`
regenerates `build/twin_ops.h` from it on every run, so an `ops_ir.py`
mutation is observed.  Mutating only `twin/build/twin.cpp` is **not** observed
by this cell (the leaf is generated from `ops_ir.py`); REDTEAM must use the
`ops_ir.py` site for this gate.

## Whole-entry scope and tool gaps

- Alive2 on the full generated twin (`twin/build/twin.cpp`, clang 20 `-O1`)
  reports `Unsupported attribute: noalias` / `nocapture` /
  `sret(%"struct.twin::Ctx")` and cannot translate `verify_script_full`,
  `eval_script`, or `classify_push_only`.  The exact probe is
  `cells/_tools/gate/whole_entry_alive2_probe.txt`; no whole-entry green is
  claimed.
- Whole-entry SAW is not claimed: `equiv_entry` contains loops, `new`, and
  `try/catch`; the cell's SAW result is for the bounded leaf only.
- F-ERR-TWIN-001 is not engaged: the witness is a success path and only
  `EQUIV_ERR_OK` / result 1 is observed.  No non-OK error-kind claim is made.
- The C leg is a source-excerpt slice of `interpreter.cpp` at the pin, not the
  whole `EvalScript`; L handlers are verbatim `twin/ops_ir.py` bodies.  The
  bounded stack, dispatcher, and packed observable are shared cell harness.
