---
# Cell disabled/C-L-w65-row172-arbscan
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 76dbfe5e42f8a337e41a7308158b0de078afafd9
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: disabled/C-L-w65-row172-arbscan
family: disabled-opcodes
tool_status: >-
  both-green for the bounded context pair (Alive2 C<->L both directions at
  len <= 8 under --smt-to=300000, SAW against an independent jump-form Cryptol
  spec at len <= 8, Lean kernel induction for arbitrary length); one EXPECTED
  Alive2 counterexample for the post-scan ordering is recorded separately in
  alive2/divergence.txt and is not part of the green claim.
precondition: |
  - `len` is the script length in bytes (uint32); `b0..b7` are the first eight
    script bytes.  The bounded domain is `len <= 8`; both legs return 254 for
    `len > 8` on both exported functions.  Bytes after `len` are ignored.
  - `disc` is the cell's normalised policy word: `disc != 0` means
    SCRIPT_VERIFY_DISCOURAGE_OP_SUCCESS is set, `disc == 0` means clear.
    Only that one policy bit is modelled.
  - C leg: the eight-iteration shift-register transcription of
    script.cpp:311-362 (GetScriptOp), script.cpp:365-371 (IsOpSuccess),
    interpreter.cpp:472-483 (legacy disabled table) and
    interpreter.cpp:1846-1862 (tapscript OP_SUCCESSx pre-scan).  Both
    classifications are computed in one walk.
  - L leg: the same shift register written from the pinned Lean definitions:
    Parser/Defs.lean getOpAux/getOp (push-vs-op classification),
    Interpreter/Defs.lean disabledWire, isOpSuccessWire, opSuccessScanFrom and
    the disabled gate in stepBody.
  - Within `len <= 8` a push payload cannot exceed 4 bytes (PUSHDATA4's length
    field itself is 4 bytes, so no larger payload can be encoded in eight
    bytes), and at most eight opcodes can run, so neither the 520-byte item
    cap nor the 201-op budget can preempt the classifications below.
  - `cell_tail` takes the five abstract facts (found, decode_fail, discourage,
    too_many, oversize) as inputs; it models ordering, not how the facts were
    computed.
  - Arbitrary-length Lean statements quantify over any ByteArray and any
    witness stack/fuel; they do not assume `len <= 8`.
postcondition: |
  - `cell_flip(len, b0..b7, disc)` = `(base << 32) | tap`.
      base = 17 (SCRIPT_ERR_DISABLED_OPCODE) iff the decode walk reaches a
             decoded opcode byte in the fifteen-wire legacy disabled set
             {0x7e,0x7f,0x80,0x81,0x83,0x84,0x85,0x86,0x8d,0x8e,0x95,0x96,
              0x97,0x98,0x99} before any GetOp failure;
             16 (SCRIPT_ERR_BAD_OPCODE) iff GetOp fails before any disabled
             opcode is decoded;
             66 otherwise (the walk decodes the whole script and EvalScript
             would run; 66 is a cell marker, not a ScriptError).
      tap  = 0 (OK) / 36 (SCRIPT_ERR_DISCOURAGE_OP_SUCCESS) iff the walk
             reaches a decoded `.op` whose wire is in IsOpSuccess
             ({80,98,126-129,131-134,137-138,141-142,149-153,187-254}) before
             any GetOp failure, with 36 exactly when `disc != 0`;
             16 iff GetOp fails before any such opcode (Core's pre-scan returns
             BAD_OPCODE immediately);
             66 otherwise (the scan completes and EvalScript would run).
    The C and L walks agree for every input in the domain (Alive2, both
    directions), and each is proved equal to the independent jump-form
    Cryptol spec `flip` in src/cell.cry (SAW).
  - `cell_tail(found, decode_fail, disc, too_many, oversize)` is deliberately
    NOT the same function on the two legs.  C implements Core's order
    (interpreter.cpp:1846-1871): found -> 0/36, decode_fail -> 16, too_many
    -> 8, oversize -> 6, else 66.  L implements the Lean order
    (Interpreter/Defs.lean:1211-1233): found -> 0/36, too_many -> 8, oversize
    -> 6, decode_fail -> 16, else 66.  The exact divergence set is
    `found = 0 /\ decode_fail != 0 /\ (too_many != 0 \/ oversize != 0)`;
    there Core returns 16 and Lean returns 8 (or 6 if only oversize).
    Alive2 reports this as an expected counterexample (source 16, target 8) in
    alive2/divergence.txt; the cell never claims equivalence of the contexts
    on that set.
  - Lean `opSuccessScan_of_reaches_success`: for every ByteArray `b`, every
    decode path from index 0 to `j`, every decoded `.op c` at `j` with
    `isOpSuccessWire c = true`, `opSuccessScan b = true`, with no bound on
    `b.size` and no condition on the suffix.
  - Lean `executeWitnessScript_tapscript_of_reaches_disabled`: under the same
    hypothesis with `disabledWire c = true`, `executeWitnessScript` at
    SigVersion.tapscript returns `.ok` when `discourageOpSuccess = false` and
    `.fail .discourageOpSuccess` when it is true, for every fuel, item list and
    validation-weight value — i.e. before the stack-size/item-size checks and
    before EvalScript.
  - Lean `evalFrom_prefix_disabled`: if a prefix steps without error and then
    a decoded wire op in the disabled table is reached with
    `opCount < MAX_OPS_PER_SCRIPT`, `evalFrom` returns
    `.error .disabledOpcode`, for any prefix length and any suffix.  At
    `opCount = 201` the budget check wins instead (PDW60), so this base
    direction is conditional by design.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-172
scr_row_coverage: >-
  partial.  Proved on the bounded compiled pair: for every `len <= 8`, every
  eight-byte script and every `disc` word the C and L classifications are
  identical in both directions (Alive2), and each leg equals an independent
  jump-form Cryptol specification (SAW), including the exact post-scan
  divergence boundary (spec-level theorem) and the recorded IR counterexample.
  Proved on the Lean model for ARBITRARY length: reaching any decoded
  OP_SUCCESSx/legacy-disabled opcode forces the tapscript success outcome
  before the size checks (ScanPath induction), and reaching a legacy-disabled
  opcode forces the BASE disabled error while the op-count budget is not
  exhausted.  Not machine-checked: an arbitrary-length proof about the
  compiled C IR (the unroll is bounded at 8; the arbitrary-length closure is
  the Lean model of record, not a compiled-C theorem); the case where a
  disabled opcode is only reached after a truncated push (the walk cannot
  reach it); witness-stack contents, validation weight, annex/control block,
  EvalScript after the disabled guard, and signature operations.  The base
  disabled verdict is conditional on `opCount < 201`; at the boundary OP_COUNT
  wins.  The push-decode ordering divergence is preserved, not declared
  equivalent: Core returns BAD_OPCODE (16) on a truncated tail before the
  stack/item checks, Lean checks STACK_SIZE (8) / PUSH_SIZE (6) first.  The
  policy error 36 is standardness, not a consensus failure.
patches: none
source_citations:
  - script.cpp:311-362 (GetScriptOp decode / truncation)
  - script.cpp:365-371 (IsOpSuccess)
  - interpreter.cpp:472-483 (the fifteen legacy disabled opcodes)
  - interpreter.cpp:1846-1862 (tapscript OP_SUCCESSx pre-scan and policy arm)
  - interpreter.cpp:1864-1871 (initial stack-size and 520-byte item checks)
  - script/script.h:168 (OP_RSHIFT = 0x99)
  - Defs.lean:206-229 (getOpAux / getOp)
  - Defs.lean:455-459 (disabledWire)
  - Defs.lean:463-468 (isOpSuccessWire)
  - Defs.lean:479-492 (opSuccessScanFrom / opSuccessScan)
  - Defs.lean:817-840 (stepBody: pushSize, opCount, disabledWire order)
  - Defs.lean:1211-1233 (executeWitnessScript tapscript arm)
  - Delta.lean:62-85 (executeWitnessScript_success_total / _success_discourage)
  - Delta.lean:98+ (every disabled wire is an OP_SUCCESSx)
trust_note: >
  C is a line-cited source-excerpt slice of Core, not the whole EvalScript or
  ExecuteWitnessScript: it models the decode walk, IsOpSuccess, the disabled
  table, the one-walk pre-scan and the ordering of the five post-scan facts.
  L is a literal transcription of the pinned Lean definitions, not generated
  twin output; the twin's dispatch table has no pre-scan handler because the
  scan runs before EvalScript.  Both are hand transcriptions, so a shared
  misreading of the two source tables is the known limit of a table cell; the
  independent Cryptol spec and the Lean induction are separate formulations
  that reduce, but do not eliminate, that risk.  Alive2 compares the compiled
  slices; SAW checks each leg against src/cell.cry; the Lean runner compiles
  src/Row172Induction.lean against the pinned core package and pins the axiom
  footprints to [propext, Quot.sound].  No Core source patch is used.  This is
  a bounded compiled cell plus an arbitrary-length model theorem, not a
  whole-Engine equivalence proof.
---
