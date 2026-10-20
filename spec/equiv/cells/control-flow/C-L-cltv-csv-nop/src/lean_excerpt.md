# Lean excerpt reviewed for `control-flow/C-L-cltv-csv-nop`

Repository `btc-lean-public` @ `4d62a97e551082a69b13f495365bff0a903b0c99`
(the `[lean] model_rev` pin). Files
`spec/core/Bitcoin/Interpreter/Defs.lean` and
`spec/proofs/BitcoinProofs/AF/PDW73/PDW73.lean`.

## stepBody: the op-count bump precedes dispatch (Defs.lean:817-848)

```lean
def stepBody (ctx : Ctx) (op : WireOp) (st : State) : Except ExecError State :=
  ...
  -- (2) opcode budget (interpreter.cpp:459-463)
  let counts := (ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < w
  let opCount' := if counts then st.opCount + 1 else st.opCount
  if counts ∧ MAX_OPS_PER_SCRIPT < opCount' then .error .opCount
  ...
  else
    let fExec := st.vf.all id
    let st₁ := { st with opCount := opCount' }
    ...
    | .op _ =>
        if !(fExec ∨ (0x63 ≤ w ∧ w ≤ 0x68)) then .ok st₁
        else dispatchOp ctx op w fExec st₁
```

## The two pre-activation branches (Defs.lean:857-875)

```lean
    else if w = 0xb1 then                                   -- OP_CHECKLOCKTIMEVERIFY
      if !flags.cltv then .ok st
      else if st.stack.length < 1 then .error .stackUnderflow
      else match decodeNum pol (topAt st.stack 1) 5 with
        | .error e => .error e
        | .ok n =>
          if n < 0 then .error .negativeLocktime
          else if !checkLockTimeDef ctx.chk.env n then .error .unsatisfiedLocktime
          else .ok st
    else if w = 0xb2 then                                   -- OP_CHECKSEQUENCEVERIFY
      if !flags.csv then .ok st
      else if st.stack.length < 1 then .error .stackUnderflow
      else match decodeNum pol (topAt st.stack 1) 5 with
        | .error e => .error e
        | .ok n =>
          if n < 0 then .error .negativeLocktime
          else if (n.toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) ≠ 0 then .ok st
          else if !checkSequenceDef ctx.chk.env n then .error .unsatisfiedLocktime
          else .ok st
```

## The row's Lean face (PDW73.lean:31-47)

```lean
/-- SCR-072: without their activation flags CLTV (0xb1) and CSV (0xb2)
are plain no-ops; only the op-count budget moves. -/
@[rule "SCR-072"]
theorem stepBody_cltv_csv_noflag_nop (ctx : Ctx) (st : State) (w : Fin 256)
    (hf : st.vf.all id = true) (hsv : ctx.sv = .base)
    (hw : w.val = 0xb1 ∨ w.val = 0xb2)
    (hcltv : ctx.flags.cltv = false) (hcsv : ctx.flags.csv = false)
    (hcnt : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1)) :
    stepBody ctx { ast := .op w, wire := w.val, next := 1 } st =
      .ok { st with opCount := st.opCount + 1 } := by
  rcases hw with hw | hw <;>
    simp [stepBody, stepBody.dispatchOp, disabledWire, hf, hsv, hcltv, hcsv, hcnt, hw]
```

## Review mapping

| Lean | `src/l_leaf.cpp` |
|---|---|
| `counts := (ctx.sv = .base ∨ …) ∧ 0x60 < w` | base sigversion and wire 0xb1/0xb2, so the bump always applies |
| `opCount' := if counts then st.opCount + 1 else st.opCount` | `opCount = opCount + 1;` |
| `st₁ := { st with opCount := opCount' }` | the bumped counter is threaded into the dispatch |
| `if !flags.cltv then .ok st` | `if (!cltv_flag) return {CELL_CONT, opCount};` |
| `if !flags.csv then .ok st` | `if (!csv_flag) return {CELL_CONT, opCount};` |
| `if st.stack.length < 1 then .error .stackUnderflow` | `if (stack_length < 1) return {EQUIV_ERR_INVALID_STACK_OPERATION, opCount};` |
| `decodeNum` / `checkLockTimeDef` / `checkSequenceDef` continuation | declared cell boundary (`CELL_BOUNDARY`), covered by the locktime cells |
| `.stackUnderflow` | `TWIN_INVALID_STACK_OPERATION` → `INVALID_STACK_OPERATION` = 18 (`twin/gen.py`, `contract/error_kind.h`) |

The transliteration drops only the `decodeNum`/comparison continuation, which
is outside this cell's domain and is the locktime cells' rows. Nothing in the
flag-off branch is dropped: it is `.ok st`, and the cell observes the whole
bounded state (stack depth, top byte, op-count).
