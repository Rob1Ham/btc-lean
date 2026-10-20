# tapscript/C-L-w32-witness-dispatch-upgradable

Bounded, symbolic proof of the two post-commitment dispatch decisions of
`VerifyWitnessProgram` at pin `cce32b168`: unknown **leaf versions**
(SCR-149), the **P2A** arm (SCR-150), and the **v2..v16 / wrong-size v1 /
P2SH-wrapped v1** upgradable tail (SCR-151).

## Why this seam

All three rows are pure version/length/byte/flag predicates over values the
engine has already decoded.  They do not need SHA256, Schnorr, the control
block, the annex, or the EvalScript loop.  Two arms that *would* need those
things (leaf 0xc0 execution and the whole taproot arm) are passed through as
**uninterpreted inputs**, so the proof cannot manufacture a success for them.

## Functions

| function | row | result |
|---|---|---|
| `cell_leaf_version_dispatch(control0, discourage_utv, tapscript_rc)` | SCR-149 | tapscript iff `control0 & 0xfe == 0xc0`; else fail 35 under the policy flag, else pass |
| `cell_program_tail_dispatch(version, plen, b0, b1, is_p2sh, discourage_ugwp, taproot_rc)` | SCR-150, SCR-151 | P2A pass; taproot arm passthrough; else fail 34 under the policy flag, else pass |

`tapscript_rc` / `taproot_rc` are 64-bit packed `(result, error)` values that
are arbitrary in the proof.  `(2, 1)` is the harness bad-input marker for
`version` outside 1..16.

## Rows

- **SCR-149** — full at the dispatch seam.  256 `control[0]` values × both
  flag states.  The ledger summary names
  `DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM`, but the cited code
  (`interpreter.cpp:1995`, `Defs.lean:1316`) tests
  `DISCOURAGE_UPGRADABLE_TAPROOT_VERSION`; the cell follows the code and
  records the naming discrepancy in `spec.md`.
- **SCR-150** — full.  The P2A branch precedes the discourage test, so P2A is
  success under every flag; nothing is executed.
- **SCR-151** — full over version 1..16, every program length, first two
  program bytes, both `is_p2sh` states, both discourage states.
- `version = 0` (v0 arm) and `version > 16` are outside all three rows and
  return the domain marker.

## What is not proved

- Control-block size (SCR-145) and the tapleaf/tweak commitment
  (SCR-146/147): the cell starts after both.
- The annex (SCR-143), key path (SCR-144) and script path execution
  (SCR-148 onward): `taproot_rc` / `tapscript_rc` are arbitrary inputs.
- P2SH wrapping itself (scriptSig push, inner evaluation): `is_p2sh` is an
  input.
- Any hash, Schnorr or EvalScript result.

## Exact commands

```sh
spec/equiv/cells/tapscript/C-L-w32-witness-dispatch-upgradable/alive2/run.sh
spec/equiv/cells/tapscript/C-L-w32-witness-dispatch-upgradable/saw/run.sh
cd <repo root> && sha256sum -c spec/equiv/cells/tapscript/C-L-w32-witness-dispatch-upgradable/alive2/certificate.sha256
cd <repo root> && sha256sum -c spec/equiv/cells/tapscript/C-L-w32-witness-dispatch-upgradable/saw/certificate.sha256
```

## Raw results

`alive2/result.txt` and `saw/result.txt`.  Alive2 compares
`build/{c,l}_cell_*.ll` pairwise; SAW verifies each leg against
`src/cell.cry`.
