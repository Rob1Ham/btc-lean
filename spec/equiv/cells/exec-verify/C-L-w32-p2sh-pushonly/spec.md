---
cell: C-L-w32-p2sh-pushonly
family: exec-verify
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (symbolic push-only gate over decoded opcodes)
precondition: |
  - Cell seam: the P2SH-arm push-only gate of VerifyScript and nothing else.
    No tx decoding, no EvalScript, no redeem-script execution, no witness,
    no signature checking.
  - The scriptSig is an already-decoded opcode sequence of length n_ops <= 3;
    element i has one symbolic 64-bit "wire byte" input (only the low 8 bits
    are semantics).  Decoding (`CScript::GetOp` / `GetScriptOp`) is an
    abstraction: the malformed-tail error kind is F-DIV-001 and is excluded
    from this cell (Core's `GetOp` failure returns false from IsPushOnly and
    the Lean `parseWire` returns `none` -> BAD_OPCODE).
  - The scriptPubKey is the P2SH template (23-byte HASH160 .. EQUAL) by
    construction, so the arm at interpreter.cpp:2062 is entered iff the P2SH
    flag bit is set.  All other flags are irrelevant to the row.
  - After the gate, the redeem-script EvalScript (:2080) is abstracted to
    success: the cell observes the gate, not a script verdict.
postcondition: |
  Observable = packed (result, error_kind): result(2) | error(6) << 2.
    p2sh = 0                                  -> (1, 0)  arm not entered
    p2sh != 0, every opcode wire <= 0x60      -> (1, 0)  gate passed
    p2sh != 0, some opcode wire > 0x60        -> (0, 26) SIG_PUSHONLY
  The boundary is OP_16 = 0x60 (a push-only opcode) against OP_NOP = 0x61:
  the symbolic comparison covers every wire byte, not just the boundary.
  Result 1 is "the gate did not reject"; it is not a whole-VerifyScript pass.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-006
scr_row_coverage: |
  full for the row's branch set over decoded scriptSig:
  - push-only scriptSig under P2SH passes the gate (C :2065 / Lean
    `isPushOnlyWire ops = true`),
  - non-push-only scriptSig under P2SH returns SIG_PUSHONLY (C :2066 /
    Lean `.fail .sigPushOnly`), including the 0x60/0x61 boundary,
  - the gate is not executed when the P2SH flag is clear (:2062), so no
    SIG_PUSHONLY can originate here without P2SH.
  Named boundary of the claim: scriptSig decoding is abstracted, so the
  malformed-tail input class is not judged (F-DIV-001); that class is a
  parser seam, not an edge of "scriptSig must be push-only".  The redeem
  script evaluation after the gate is not part of SCR-006 and is abstracted.
patches: none
source_citations:
  - interpreter.cpp:2012 (VerifyScript signature)
  - interpreter.cpp:2062 (P2SH arm guard `flags & SCRIPT_VERIFY_P2SH && IsPayToScriptHash`)
  - interpreter.cpp:2064-2066 (push-only check -> SCRIPT_ERR_SIG_PUSHONLY)
  - script.cpp:266-282 (CScript::IsPushOnly; `opcode > OP_16` -> false, OP_16 = 0x60)
  - script.cpp:283-286 (CScript::IsPushOnly() entry)
  - spec/core/Bitcoin/Interpreter/Defs.lean:496 (isPushOnlyWire)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1326-1350 (p2shInner push-only arm)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1388-1392 (P2SH arm guard in verifyScriptFull)
  - contract/error_enum.md:61 (SIG_PUSHONLY = 26)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core at the pin, not the
  whole VerifyScript.  L is a reviewed transliteration of the Verified Lean
  `p2shInner`/`isPushOnlyWire` definitions, not generated from the twin (the
  generated twin's classify_push_only has its own parser).  `GetScriptOp` is
  abstracted to an already-decoded opcode list; the abstraction is declared
  and is the F-DIV-001 seam.  Both tools prove the same symbolic function:
  Alive2 compares the C and L IR directly, SAW verifies each module against
  the same Cryptol function `spec_cell_p2sh_pushonly_gate`.  No Core source
  patch is used.
mutant: >
  Proposed, not executed: replace `opcode > OP_16` with `opcode > OP_15`
  (0x5f) in the C leg.  Expected Alive2 counterexample at wire = 0x60
  (C = SIG_PUSHONLY, L = gate passed); SAW proof failure.
---

# exec-verify/C-L-w32-p2sh-pushonly

Bounded symbolic proof of SCR-006, the second push-only check in
`VerifyScript` (the P2SH-arm one, not the SIGPUSHONLY pre-check of SCR-010).

## Seam

Core at the pin (`src/script/interpreter.cpp`):

```
2062  if ((flags & SCRIPT_VERIFY_P2SH) && scriptPubKey.IsPayToScriptHash())
2063  {
2064      // scriptSig must be literals-only or validation fails
2065      if (!scriptSig.IsPushOnly())
2066          return set_error(serror, SCRIPT_ERR_SIG_PUSHONLY);
```

`CScript::IsPushOnly` (`src/script/script.cpp:266-282`) walks the script with
`GetOp` and rejects the first opcode above `OP_16` (0x60).

Lean (`spec/core/Bitcoin/Interpreter/Defs.lean`):

```
496    def isPushOnlyWire (ops : List WireOp) : Bool := ops.all (fun o => o.wire ≤ 0x60)
...
1334   if !isPushOnlyWire ops then .fail .sigPushOnly
```

## What is proved

`cell_p2sh_pushonly_gate(n_ops, w0, w1, w2, p2sh)` is symbolic in all five
arguments.  Both legs return the ABI pair:

| flags | decoded scriptSig | result |
|---|---|---|
| P2SH clear | anything | (1, 0), arm not entered |
| P2SH set | empty or every wire ≤ 0x60 | (1, 0) |
| P2SH set | any wire > 0x60 | (0, 26 SIG_PUSHONLY) |

Alive2 compares the two IR modules; SAW proves each module equals the
Cryptol function of the same name.  Both directions are one equality.

## What is not proved

- The script decoder.  Malformed tails are the F-DIV-001 seam; the cell
  starts from a decoded opcode list.
- The redeem-script `EvalScript` after the gate (:2080) and every later
  VerifyScript stage.  Result 1 means "the gate did not reject".
- Opcode execution of OP_RESERVED (a push-only opcode that fails when run):
  that is an EvalScript row, not this gate.

## Exact commands

From the repository root (`spec/equiv` is part of the path):

```sh
spec/equiv/cells/exec-verify/C-L-w32-p2sh-pushonly/alive2/run.sh
spec/equiv/cells/exec-verify/C-L-w32-p2sh-pushonly/saw/run.sh
sha256sum -c spec/equiv/cells/exec-verify/C-L-w32-p2sh-pushonly/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/exec-verify/C-L-w32-p2sh-pushonly/saw/certificate.sha256
```
