---
# Cell exec-verify/C-L-w64-p2sh-single-push
cell: C-L-w64-p2sh-single-push
family: exec-verify
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 5946c024546e39f55775bfd9a077b042e3feeef4
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (3 bounded leaves x C/L; scriptSig 0..49 bytes, redeemScript 4..42 bytes)
precondition: |
  - The P2SH-wrapped witness-program guard of `VerifyScript`
    (interpreter.cpp:2089-2104), reached with `SCRIPT_VERIFY_WITNESS` set.
    The two callers' results enter as premises: `pubKey2` is the last
    scriptSig stack element (2076-2078; handoff proved by
    `cells/exec-verify/C-L-p2sh-handoff`), the subscript
    `EvalScript(stack, pubKey2, ...)` returned ok and left a truthy top
    (2080-2086; the E5 residual is not modelled), and the following
    `VerifyWitnessProgram` (2097-2098) is abstracted to success.
  - `redeemScript` (`pubKey2`) has length `plen` in 4..42.  This is not a
    weakening: `IsWitnessProgram` (script.cpp:250-264) is recomputed in-cell
    and is false outside 4..42, so the 2092 guard is unreachable there.
  - `scriptSig` has length `slen` in 0..49, stored as 56 bytes.  The bound is
    the largest wire form a single push of a 4..42-byte program can have
    (PUSHDATA4 prefix 5 + 42 payload) plus slack; scripts that are not one
    complete push are reported out-of-model (see the postcondition).
  - `minimaldata` in {0,1} stands for `SCRIPT_VERIFY_MINIMALDATA`
    (`fRequireMinimal`, interpreter.cpp:489).
  - Every input byte is symbolic; nothing is assumed about script contents
    beyond the two length bounds.
postcondition: |
  `cell_p2sh_guard` returns
  `verdict(2) | err(6)<<2 | eq(1)<<8 | single(1)<<9 | elem_eq(1)<<10 |
   elem_len(8)<<11 | wit(1)<<19`:
  - `single` = scriptSig is exactly one complete push (the producing
    `GetScriptOp` at 2029 succeeds and consumes the whole scriptSig);
  - `eq` = `scriptSig == CScript() << vector(pubKey2)` computed byte for
    byte over the *whole* scriptSig: size `plen+1`, first byte `plen`, then
    `pubKey2` (2092, script.h:408-424,484-495, prevector.h:429);
  - `elem_eq` = the decoded push payload equals the redeemScript;
    `elem_len` = its length; `wit` = `IsWitnessProgram(pubKey2)` recomputed
    from the bytes (script.cpp:250-264);
  - `verdict` 1 = pass, 0 = reject, 3 = scriptSig is not one complete push
    (out of this cell's model; no 42 can fire on such an input, since the
    2092 comparison is still evaluated but the producing evaluation is an
    `EvalScript` loop this cell does not model);
  - `err` is Core's ordinal, with exactly Core's precedence:
      GetScriptOp fails                     -> 16 BAD_OPCODE  (455-456)
      non-minimal single push, minimaldata  -> 25 MINIMALDATA (489-490)
      witness program, `!eq`                -> 42 WITNESS_MALLEATED_P2SH (2092-2095)
      otherwise                             -> 0
  On a non-canonical single push (PUSHDATA1/2/4) of the right program,
  `elem_eq` is 1 but `eq` is 0, so with the policy flag off the guard rejects
  with 42 and with the flag on it rejects earlier with 25.  That is the
  malleability statement the row is about.
  `cell_sig_push` returns the same decode/`single`/`MINIMALDATA`/`BAD_OPCODE`
  facts alone (ok, is_push, single, depth, err, op, dlen, next, min_ok);
  `cell_canon_prefix` returns `AppendDataSize` (kind 2 bits, prefix length
  4 bits, five prefix bytes) for every 32-bit size, including the
  PUSHDATA1/2/4 branches the row domain does not reach.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-012
scr_row_coverage: |
  SCR-012 full for the row's reachable domain.  "scriptSig == single push of
  redeemScript" (interpreter.cpp:2092-2096) is proved for every scriptSig of
  0..49 bytes and every redeemScript that can satisfy `IsWitnessProgram`
  (4..42 bytes), including all four push encodings, with the exact
  `WITNESS_MALLEATED_P2SH` (42) result and its precedence after
  BAD_OPCODE (16) and MINIMALDATA (25).
  This also closes the producing-scriptSig-evaluation residual that the
  earlier `C-L-verifyscript-tail` cell declared for this row: the single-push
  production (GetScriptOp, `single`, MINIMALDATA, BAD_OPCODE) is proved
  separately in `cell_sig_push`.
  NOT covered (all outside the row's reachable domain or other rows):
  redeemScript > 42 (IsWitnessProgram false, guard unreachable) and
  scriptSig > 49; scriptSigs that are not one complete push (verdict 3: the
  EvalScript loop is the E5 residual, and such inputs cannot produce 42);
  the subscript `EvalScript` and `VerifyWitnessProgram` premises; crypto,
  hashing and signature checking; the rest of `VerifyScript` (other rows and
  `cells/exec-verify/C-L-verifyscript-tail`).
patches: none
source_citations:
  - interpreter.cpp:2076-2078 (pubKey2 = last stack element; popstack)
  - interpreter.cpp:2080-2086 (subscript EvalScript; EVAL_FALSE checks)
  - interpreter.cpp:2088-2096 (P2SH witness-program arm; scriptSig equality; WITNESS_MALLEATED_P2SH)
  - interpreter.cpp:2097-2098 (VerifyWitnessProgram call, abstracted here)
  - interpreter.cpp:2029-2031 (scriptSig EvalScript call, the producing evaluation)
  - interpreter.cpp:455-456 (GetScriptOp failure -> SCRIPT_ERR_BAD_OPCODE)
  - interpreter.cpp:488-492 (fExec push, CheckMinimalPush gate -> SCRIPT_ERR_MINIMALDATA)
  - script.h:408-424 (CScript::AppendDataSize), 484-495 (operator<< span)
  - script.cpp:313-363 (GetScriptOp push decode: direct/PUSHDATA1/2/4, truncation)
  - script.cpp:373-396 (CheckMinimalPush)
  - script.cpp:250-264 (CScript::IsWitnessProgram)
  - prevector.h:429 (element-wise CScript operator==)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1327-1356 (p2shInner; `ss != pushBytesWire pubKey2`)
  - spec/core/Bitcoin/Interpreter/Defs.lean:510-526 (isWitnessProgram), 529-537 (checkMinimalPush), 421-431 (parseWire)
  - spec/core/Bitcoin/Script/Parser/Defs.lean:367-377 (lenBytes), 377 (pushBytesWire)
  - contract/error_kind.h (16, 25, 42)
trust_note: >
  A bounded four-leaf cell, not a whole-VerifyScript proof.  C is a line-cited
  source-excerpt slice of the pinned Core file; L is a reviewed transliteration
  of Lean's `p2shInner` push/guard shape (encode-then-compare, `getOpAux`,
  `checkMinimalPush`, `isWitnessProgram`), not twin-generated.  Both legs are
  proved equal to one independent Cryptol statement.  The subscript EvalScript,
  VerifyWitnessProgram, script shape as a stack element, and all crypto are
  declared premises or other cells' rows.  Out-of-model scriptSigs (not one
  complete push) are reported with a sentinel, never as 42.  No engine-wide
  claim is made.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
mutant: >
  Proposed, not executed.  (1) In L, compare only the decoded payload with the
  redeemScript (`elem_eq`) instead of the whole scriptSig: expected Alive2
  counterexample at a PUSHDATA1 encoding of the same 42-byte program
  (`eq = 0`, `elem_eq = 1`): C returns 42, L returns pass.  (2) Swap the 25
  and 42 gates: expected counterexample with minimaldata = 1 and a
  non-minimal single push of a witness program (C 25, mutant 42).  (3) Widen
  the witness template to `plen <= 43`: expected counterexample at
  plen = 43 where C never takes the arm (wit = 0) but the mutant returns 42.
---

# exec-verify/C-L-w64-p2sh-single-push

The P2SH-wrapped witness-program malleability guard: the scriptSig must be
*exactly* one canonical push of the redeemScript.

## The region

```c
// interpreter.cpp:2092-2096 (inside the 2089-2104 P2SH/witness arm)
if (scriptSig != CScript() << std::vector<unsigned char>(pubKey2.begin(), pubKey2.end())) {
    // The scriptSig must be _exactly_ a single push of the redeemScript. Otherwise we
    // reintroduce malleability.
    return set_error(serror, SCRIPT_ERR_WITNESS_MALLEATED_P2SH);
}
```

`CScript() << vector(pubKey2)` is `AppendDataSize(size) ++ pubKey2`
(script.h:408-424,484-495).  Because the arm is entered only when
`pubKey2.IsWitnessProgram(...)` (2091), the redeemScript is 4..42 bytes, and
`AppendDataSize` is the direct-push branch there — but the *scriptSig* side is
not restricted: any byte string of the same content can be offered, including
`PUSHDATA1/2/4` encodings of the same program.  Those produce the same stack
element and therefore pass the subscript evaluation, yet are not the canonical
push; the 2092 comparison is what rejects them.

## The leaves

Three exported functions, each proved twice (C and L) against `src/cell.cry`:

1. `cell_canon_prefix(dlen)` — `AppendDataSize`: (kind, prefix length, prefix
   bytes) for every 32-bit `dlen`.  Kind 0 = direct (`n < 76`), 1 = PUSHDATA1,
   2 = PUSHDATA2, 3 = PUSHDATA4.  This is where the PUSHDATA1/2/4 encodings
   live; at 4..42 the branch taken is always kind 0.
2. `cell_sig_push(slen, s0..s6, minimaldata)` — the producing scriptSig
   evaluation for a one-op script: `GetScriptOp` decode of the first opcode
   (all four encodings, truncation), whether the scriptSig is exactly one
   complete push (`single`), the pushed length, the MINIMALDATA verdict, and
   the resulting `EvalScript` error (16 or 25).  This is the residual the
   earlier tail cell declared.
3. `cell_p2sh_guard(plen, p0..p5, slen, s0..s6, minimaldata)` — the 2092
   guard: recompute `IsWitnessProgram(pubKey2)`, compare the whole scriptSig
   byte for byte with `[plen] ++ pubKey2`, and return pass / 16 / 25 / 42 in
   Core's order.

## Why the bounds are the row

`IsWitnessProgram` requires `size() >= 4 && size() <= 42` and a two-byte
template check (`[0]` in {0x00, 0x51..0x60}, `[1] + 2 == size`).  Above 42
bytes the guard cannot fire, so 4..42 is the entire redeemScript domain of the
row.  A single push of such a program is at most 5 + 42 = 47 bytes
(PUSHDATA4); 49 leaves room for any one complete push plus its prefix.

## What is not proved

- The subscript `EvalScript(stack, pubKey2, ...)` (2080-2082) and its
  EVAL_FALSE checks: the guard is studied at the point where it is reached.
- `VerifyWitnessProgram` (2097-2098).
- ScriptSigs that are not exactly one complete push.  They are reported as
  `verdict = 3`; no 42 is claimed for them, because the 42 path is only
  reachable after a successful single-push scriptSig evaluation.
- Everything crypto, hashing and signature related, and the rest of
  `VerifyScript`.

## Exact commands

```sh
bash spec/equiv/cells/exec-verify/C-L-w64-p2sh-single-push/alive2/run.sh
bash spec/equiv/cells/exec-verify/C-L-w64-p2sh-single-push/saw/run.sh
# from the repository root:
sha256sum -c spec/equiv/cells/exec-verify/C-L-w64-p2sh-single-push/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/exec-verify/C-L-w64-p2sh-single-push/saw/certificate.sha256
```

## Results

Alive2: three comparisons (`cell_canon_prefix`, `cell_sig_push`,
`cell_p2sh_guard`), each `1 correct transformations`, `0 incorrect`,
`0 Alive2 errors`, `STATUS=alive2-green`.

SAW: six `Proof succeeded!` (three leaves x C/L) against `src/cell.cry`,
`STATUS=saw-green`.
