# locktime/C-L-locktime-input-index — notes

Per-input locktime checkers, row SCR-132, both tools green.

## Commands

```sh
cd /tmp/opencode/wave16/12-locktime
bash spec/equiv/cells/locktime/C-L-locktime-input-index/alive2/run.sh
bash spec/equiv/cells/locktime/C-L-locktime-input-index/saw/run.sh
sha256sum -c spec/equiv/cells/locktime/C-L-locktime-input-index/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/locktime/C-L-locktime-input-index/saw/certificate.sha256
```

Tools: Alive2 v20.0 (LLVM 20.1.2), SAW 1.6 (`68eed5f`), clang++-20 20.1.2.

## Shape of the proof

Both entry points have the same signature on both legs:

```
int32 f(uint32 tx_locktime_or_version, int64 operand,
        uint32 seq0, uint32 seq1, bool nIn)
```

- C builds `const CTxIn vin[2] = {{seq0}, {seq1}}` and calls the transcribed
  checker with `txTo.vin[nIn]` (IR: `nIn ? &vin[1] : &vin[0]`).
- L builds `LocktimeEnv{version, locktime, vin_at(vin, nIn)}` from
  `locktimeEnvOf`, where `vin_at` is `nIn ? vin[1] : vin[0]`, and calls
  `checkLockTimeDef`/`checkSequenceDef`.

The unselected slot is a free argument of both functions and never appears in
the L body's result.  So `C = L` for all `(…, s0, s1, nIn)` says: replace
`s1` by anything while `nIn = 0`, or `s0` by anything while `nIn = 1`, and the
verdict is unchanged.  That is SCR-132.

The independent Cryptol predicate in `src/cell.cry` repeats the claim: `cltv`
and `csv` take both slots and use only `if nin then s1 else s0`.  SAW checks
each leg against that predicate (4 proofs).

## Exact bound

The Lean theorems quantify over an arbitrary `vin` list and any `nIn`.  The
LLVM cell is the two-input instance: `nIn` is a boolean, both index values are
symbolic, both slots are symbolic, and the `getD` fallback is unreachable
because `nIn < vin.length`.  The checker reads exactly one slot, so the
instance covers the row's only input-access edge; the induction to arbitrary
`n` is the Lean proof, not the cell's claim.  `spec.md` says this under
`scr_row_coverage` instead of silently advertising the general statement.

## Domain and harness details

- **operand >= 0.**  The opcode rejects a negative operand before the checker
  is called (`interpreter.cpp:582-584`, `:589-590`).  Both legs return the
  sentinel `-1` for `operand < 0` so the cell's domain is the opcode-reachable
  set and the excluded case cannot hide a divergence.  The sentinel is harness
  text, not engine text, and is mirrored in `src/cell.cry` (`is_neg`).
  Without it, CSV would diverge on negative operands for a reason that has
  nothing to do with SCR-132: Lean's `ScriptNum.toNat` is `Int.toNat`
  (negative -> 0) while `CScriptNum::operator&` keeps the two's-complement low
  bits.
- **`tx.version` is uint32.**  `primitives/transaction.h:299`; the L leg's
  `env.txVersion < 2u` is the unsigned wire comparison of
  `toUInt32 < 2`.  The cell models it as `uint32_t` so the bit-31 edge agrees.
- **CLTV reads `vin[nIn]` only for the final test**; `txLockTime` is a
  transaction-level field.  The cell keeps `txLockTime` symbolic and proves the
  whole CheckLockTime body, so the per-input part is not isolated from the
  transaction-level part (they share one observable verdict).
- **CSV reads `vin[nIn]` for everything**: version gate, disable flag, mask and
  compare.  The CSV spec in the sibling cells is reused verbatim in
  `src/cell.cry` (with the BIP68 type boundary `TYPE_FLAG = 0x400000`, not the
  locktime threshold; an early draft used `LOCKTIME_THRESHOLD` here and SAW
  caught it on a counterexample before any certificate was written).

## Source and elisions

The C leg keeps both checker bodies verbatim.  Elisions, all in `spec.md`:
dispatch/flags/stack/decode (SCR-051/052 and the sibling cells), the index
range guards (`nIn < vin.size()`, statically true for a 2-input tx and a
boolean index), signature/sighash code (not reached), and the `ScriptError`
plumbing (the observable here is the checker's boolean verdict, `1`/`0`).

## Twin status

`twin/ops_ir.py:44-58` has no transaction context for flag-on CLTV/CSV; the L
leg is the reviewed Lean transliteration, as in the other locktime cells.
Finding F-LOCKTIME-001 in the wave report.
