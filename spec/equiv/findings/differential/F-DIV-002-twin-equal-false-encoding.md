# F-DIV-002 — Twin `OP_EQUAL` pushes one-byte `00` instead of empty `vchFalse`

- **status:** **fixed** in the regenerated twin, **verified by re-run**
  (2026-10-19). Confirmed by execution against the pre-fix twin
  (`9d787f1b…`); no longer reproducible against `d560a5f6…`.
- **legs:** L_twin vs C (and vs the Lean model, which sides with C)
- **cells:** E1 base-script `EQUAL`/boolean-result family; any script that
  consumes the boolean result with `EQUAL`, `SIZE`, or another
  bytes-sensitive operation
- **severity for the claim:** narrow but real. It is a **twin generator
  bug**, not a Lean-model divergence: the Lean source says `vchFalse` is the
  empty vector, and the pre-fix twin's hand-written IR body did not implement
  it. It changed a verdict, not just an error kind.

## Later regeneration (2026-10-19)

The tracked twin was regenerated again after the flow-op extension:
`libtwin.so` `b9ed129b9a0bd719da789c7accab7e522f436b08eb33e8cd18874659edeea72b`,
generated `twin.cpp`
`39ab7c66ea112ea0108e6f2b93c6bbb8ad0b8261f3230310c989cb8d0af2478f`;
`python3 twin/gen.py --check twin/build/twin.cpp` exits 0, and the EQUAL body
is still `eq ? 1u : 0u`. A full harness rerun against it is **922 / 0 / 336**
with `determinism: identical`; `sc-0365` agrees. The `d560a5f6…` hash below is
the first post-fix build, preserved in `differential/results/archive-d560/`.

## Resolution (verified)

The twin generator was corrected while this report was being written:
`ops_ir.py` now emits

```cpp
uint8_t b = 1u;
return st_push(st.stack, &b, eq ? 1u : 0u);
```

so a false `EQUAL` pushes an empty element. The regenerated twin
(`spec/equiv/twin/build/libtwin.so`, sha256
`d560a5f69a05179c29851aa80cbea330e976ec455c7e6bca32f0b6dfee223801`)
now returns `OK` for `sc-0365`, and a full harness re-run reports:

```text
C~L_twin agree=854 disagree=0 blocked=404
```

with `c-l.jsonl` sha256
`024d40652b084be4b53ed1fe650d4827ae3bf5fbabcf345bf844b4ae8615e771`.
This is a fix for the defect below; the counterexample remains the
regression test.

## Symptom

The pinned corpus row `sc-0365` (`source_index` 371) is:

```json
["0 0 1", "EQUAL EQUAL", "P2SH,STRICTENC", "OK"]
```

Execution stack:

1. `scriptSig` `0 0 1` pushes `[]`, `[]`, `[0x01]`.
2. First `EQUAL` compares `[0x01]` and `[]` → false.
3. Core pushes `vchFalse`, the **empty** vector `[]`; stack is `[] []`.
4. Second `EQUAL` compares `[]` and `[]` → true.
5. Final stack `[0x01]` is truthy → `OK`.

The twin instead pushes a **one-byte** zero `[0x00]` at step 3:

1. stack after first `EQUAL`: `[] [0x00]`;
2. second `EQUAL` compares `[]` and `[0x00]` → false;
3. final stack is `[]`, which is falsy → `EVAL_FALSE`.

## Observed results (pre-fix twin `9d787f1b…`)

| Leg | `result` | `error_kind` | Name |
|---|---:|---:|---|
| expected | 1 | 0 | `OK` |
| C | 1 | 0 | `OK` |
| Lean interpreter model (`tierC.l2r`) | pass | 0 | `OK` |
| **L_twin** | **0** | **2** | **`EVAL_FALSE`** |

Pre-fix record: `row_id = "sc-0365"`, `source_index = 371`, tape sha256
`2ee8a857b719892ea68c6dd9ba70f942724b84339d3fb2e0c7c33e59b6b89b1d`,
`script_sig_hex = 000051`, `script_pubkey_hex = 8787`, flags
`P2SH|STRICTENC` (`3`). The pre-fix `c-l.jsonl` had sha256
`32a960455a5821e36f4dff503ef2204aa929448e0869fe2c95495d7c35f69580`.
The current results (post-fix) record `c_vs_l_twin = "agree"` for this row.

This was the only C-vs-L_twin disagreement among the 846 rows for which the
pre-fix twin returned a verdict.

## Cause

Pre-fix twin generated source, `twin.cpp:1012-1027` at hash `9d787f1b…`
(generated from the then-current `ops_ir.py`, `Lean:` anchor
`Defs.lean:1059-1066`):

```cpp
// OP_EQUAL (wire 0x87 0x88) -- Lean: Defs.lean:1059-1066
static TwinErr op_OP_EQUAL(State& st, const Ctx& ctx, const Decoded& d) {
  ...
  st.stack.n -= 2;
  uint8_t b = eq ? 1u : 0u;
  return st_push(st.stack, &b, 1);
}
```

The false branch pushes `&b, 1`, i.e. one byte `0x00`.

Core's `CScriptNum`/boolean conventions — and the Lean spec the twin is
supposed to mirror — use the empty vector for false:

- Core `src/script/interpreter.cpp` at pin `cce32b168`: `OP_EQUAL` executes
  `stacktop(-2) == stacktop(-1) ? vchTrue : vchFalse` with
  `static const valtype vchFalse(0)`.
- Lean `Bitcoin/Interpreter/Defs.lean:286-291`:
  `def vchFalse : ByteArray := ByteArray.empty` and
  `def pushBoolV (v : Bool) : ByteArray := if v then vchTrue else vchFalse`.
- Lean `Defs.lean:965-968` uses `pushBoolV fEqual` for `OP_EQUAL`.

So the generated C++ body diverges from its own `Lean:` anchor. The Lean
interpreter model returns `OK` on this row, which independently confirms the
model does not have this defect.

## Why the corpus barely exposes it

`EQUAL`'s false result is usually consumed as a *truth value*
(`VERIFY`, `IF`, `BOOLAND`, `NOT`), where `[]` and `[0x00]` are both falsy
and behaviour agrees. It becomes observable only when the result's **byte
length** is compared, hashed, serialized, or itself passed to `EQUAL`
exactly as `sc-0365` does. The corpus has no other such row inside the twin
subset, so the single disagreement understates the class of affected
scripts, though it does not create additional known counterexamples.

## Evidence

- Pre-fix harness run: `python3 spec/equiv/differential/run.py` →
  `C~L_twin agree=845 disagree=1 blocked=412`, twin `9d787f1b…`.
  The row showed `C=(1,OK)`, `L_twin=(0,EVAL_FALSE)`,
  `c_vs_lean_model=agree`.
- Post-fix harness run: `C~L_twin agree=854 disagree=0 blocked=404`,
  twin `d560a5f6…`; `sc-0365` is `agree`.
- C leg sha256
  `5fef1df004adae637ffd7d3d7bf7dc96700c552dc2c22729d0de06d81457fbb5`.
- Pre-fix twin sha256
  `9d787f1beaf2214a5bb47d925526dc19e8b308ed2f64c52ba9e2b95c033516ce`.
- Fixed twin sha256
  `d560a5f69a05179c29851aa80cbea330e976ec455c7e6bca32f0b6dfee223801`.
- Lean-model verdict file sha256
  `88624ebfb4c772be5f353feea4ea3972923e7dcca1ed0cc57805d6361d7df1b6`.
- Source: twin generator `spec/equiv/twin/ops_ir.py`; pre-fix generated
  `twin.cpp:1025`, fixed body `twin.cpp:1045-1046`.

## Disposition

1. **Twin bug — fixed.** The generator's `OP_EQUAL` body now pushes the empty
   vector for false; `twin.cpp` was regenerated and `gen.py --check` passes
   (checked 2026-10-19). The regenerated twin is hash `d560a5f6…`.
2. **Do not patch the Lean model.** It was already correct here.
3. **Do not edit the corpus** and do not special-case `sc-0365` in the
   harness. The harness records the comparison and exits `1` on any
   disagreement.
4. **Re-run done.** `C~L_twin disagree=0`; the blocked-row count moved from
   412 to 404 because the same regeneration also expanded the supported
   subset (locktime rows now return verdicts). The 404 remaining rows are
   still outside-subset blocks.
5. Ledger: the artifact is regenerated and green, so E1 cells using twin
   `d560a5f6…` may cite this finding as **fixed**. Any cell pinned to the
   older twin `9d787f1b…` must carry it as an open defect.

## Owner

TWIN (generator fix). DIFFERENTIAL owns the reproducer and re-run.
