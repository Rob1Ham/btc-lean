import Bitcoin.Numeric.Interface
import Bitcoin.Interpreter.Defs

/-!
# Z21 dark-corner audit — C1 `scriptNum` minimal encoding, C2 `CastToBool`

2026-10-16. Python3 probe (28/28 PASS against a
verbatim transcription of Core @ `cce32b168` — `script.h:246-271,342-391`,
`interpreter.cpp:46-59`):
`z21_corners_probe.py`.

## Verdicts

* **C1 (0x80 0x00 = 128 IS valid + minimal, the catch): CAPTURED.**
  `Bitcoin.Numeric.decodeScriptNum` = `decodeBE minimal maxSize (bytesOf b).reverse`
  (Numeric/Interface.lean:50-52) with `minimalOkBE` (Numeric/ScriptNum.lean:493-500)
  an exact port of script.h:252-268: reject iff `back & 0x7f == 0` AND
  (`size ≤ 1` OR `vch[size-2] & 0x80 == 0`), in BE terms `d % 128 = 0` AND
  (`t = []` OR head `e < 128`). The interface theorem
  `scriptNum_minimal_reject` (Interface.lean:153-203) states the reject
  hypothesis with the second-to-last WIRE byte `< 128`, so the counterexample
  `0x80 0x00` (= +128, second-to-last wire byte `0x80` has the high bit set)
  is correctly OUTSIDE the reject set and decodes under BOTH flag settings
  (`dec8000true`/`dec8000false` below). Core's own ±255 sign-extension pair
  (`ff00` accepted / its -255 twin `ff80` accepted, script.h:258-262 comment)
  is pinned too (`dec_ff00`, `dec_ff80`).
* **C2 (`CastToBool`: -0 = false; sign-byte-only-true rule): CAPTURED.**
  `Bitcoin.Numeric.castToBool` (Interface.lean:69-70) = `castToBoolList`
  (Numeric/ScriptNum.lean:648-651), an exact port of interpreter.cpp:46-59:
  false iff no nonzero byte OR the FIRST nonzero byte is the last byte and
  `0x80` (in BE terms: `t.any (·≠0) || (d≠0 ∧ d≠128)`). The
  sign-byte-only-true rule (any-length vector whose ONLY nonzero byte is the
  trailing `0x80`) is pinned at 2 and 3 bytes (`bool_0080`, `bool_000080`),
  the -0 corner at 1 byte (`bool_80`), and the true-side contrasts
  (`bool_8000`, `bool_8080`, `bool_0180`). End-to-end through the real
  consensus entry `verifyScriptFull` (which applies final-stack truthiness):
  a bare push of `-0` (`0180`) fails final verify with EVAL_FALSE while a
  two-byte push of `0x80 0x00` (`028000`) verifies, and OP_IF takes the
  ELSE branch on `0x80` (`if_80_else_true` / `if_80_else_false`).
  General agreement theorem: `castToBool_iff_setVchBE` (Interface.lean:207).

All examples are closed `decide` proofs (kernel reductions; no axioms beyond
Lean's standard three, none of which these proofs even use).
-/

namespace Bitcoin.Proofs.Audit.Z21

open Bitcoin.Numeric Bitcoin.Interpreter Bitcoin.Crypto.Seam

-- hex helper (Z01/Z03 suite pattern)
private def hexDigitVal (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
  else none

/-- Wire bytes, in stored (little-endian) order: `fromHex "8000"` is the
two-byte vector `{0x80, 0x00}` with `vch[0] = 0x80`. -/
private def fromHex (s : String) : ByteArray :=
  go (s.toList.filter (fun c => c != '\n' && c != ' ')) ByteArray.empty
where
  go : List Char → ByteArray → ByteArray
    | [], acc => acc
    | [_], acc => acc
    | a :: b :: rest, acc =>
        match hexDigitVal a, hexDigitVal b with
        | some ha, some hb => go rest (acc.push ((ha * 16 + hb).toUInt8))
        | _, _ => go rest acc

/-! ## C1 — scriptNum minimal encoding: `0x80 0x00` = +128 IS valid -/

section C1

/-- **The catch, minimal flag ON** (MINIMALDATA / CLTV/CSV/CMS-count
setting): wire `{0x80, 0x00}` decodes to **+128**, not to `-0`/`-128`, and is
ACCEPTED — the top byte's sign bit sits on the SECOND wire byte, so the
script.h:262-268 sign-extension exception applies. -/
example : decodeScriptNum (fromHex "8000") true 4 = some 128 := by decide

/-- Flag-independence: the same decode with `fRequireMinimal = false`. -/
example : decodeScriptNum (fromHex "8000") false 4 = some 128 := by decide

/-- The canonical encoder itself produces `0x80 0x00` for 128 — and the
`minimal` flag is inert (Core's encoder is unconditionally canonical). -/
example : encodeScriptNum 128 true = fromHex "8000" := by decide
example : encodeScriptNum 128 true = encodeScriptNum 128 false := by decide

/-- Contrast (SCR-083): the ONE-byte `0x80` (negative zero) IS rejected as a
number under minimal, but decodes to 0 without the flag. -/
example : decodeScriptNum (fromHex "80") true 4 = none := by decide
example : decodeScriptNum (fromHex "80") false 4 = some 0 := by decide

/-- 128 with a trailing zero byte (`{0x80,0x00,0x00}`) is NON-minimal. -/
example : decodeScriptNum (fromHex "800000") true 4 = none := by decide

/-- A small value with a trailing zero byte is non-minimal (BIP62 r4). -/
example : decodeScriptNum (fromHex "0100") true 4 = none := by decide
example : decodeScriptNum (fromHex "0100") false 4 = some 1 := by decide

/-- Zero must be encoded as the EMPTY vector under minimal (script.h:260-262:
`vch.size() <= 1` branch rejects a lone `0x00`). -/
example : decodeScriptNum (fromHex "00") true 4 = none := by decide
example : decodeScriptNum (fromHex "") true 4 = some 0 := by decide

/-- Core's own ±255 sign-extension example (script.h:258-262 comment): the
stored vector `{0xff,0x00}` (= +255) is accepted, and so is its -255 twin
`{0xff,0x80}` — the second-most-significant byte's high bit saves both. -/
example : decodeScriptNum (fromHex "ff00") true 4 = some 255 := by decide
example : decodeScriptNum (fromHex "ff80") true 4 = some (-255) := by decide

/-- Non-minimal NEGATIVE zero `{0x00,0x80}` (decodes to 0) is rejected under
minimal, accepted as 0 without it. -/
example : decodeScriptNum (fromHex "0080") true 4 = none := by decide
example : decodeScriptNum (fromHex "0080") false 4 = some 0 := by decide

end C1

/-! ## C2 — CastToBool: -0 is false; sign-byte-only-true rule -/

section C2

/-- Empty and all-zero vectors are FALSE. -/
example : castToBool (fromHex "") = false := by decide
example : castToBool (fromHex "00") = false := by decide
example : castToBool (fromHex "0000") = false := by decide

/-- **The -0 corner**: the lone sign byte `0x80` casts FALSE. -/
example : castToBool (fromHex "80") = false := by decide

/-- **Sign-byte-only-true rule**: a vector whose ONLY nonzero byte is the
trailing `0x80` sign byte is FALSE at any length (interpreter.cpp:53-54
fires on the first nonzero byte only when it is the last AND `0x80`). -/
example : castToBool (fromHex "0080") = false := by decide
example : castToBool (fromHex "000080") = false := by decide

/-- True side: any nonzero byte BEFORE the trailing sign byte wins —
including the very bytes C1 showed decode to +128. -/
example : castToBool (fromHex "8000") = true := by decide
example : castToBool (fromHex "8080") = true := by decide
example : castToBool (fromHex "0180") = true := by decide
example : castToBool (fromHex "ff") = true := by decide

/-- The two corners on the SAME bytes: `{0x80,0x00}` is simultaneously
bool-TRUE and the number +128 (a naive "0x80 prefix = negative" reading
gets both wrong). -/
example :
    castToBool (fromHex "8000") = true ∧
    decodeScriptNum (fromHex "8000") true 4 = some 128 := by decide

/-! ### End-to-end through the real interpreter

`evalScriptBytes` routes OP_IF/NOTIF/OP_VERIFY checks through
`Bitcoin.Numeric.castToBool`, but it does NOT apply final-stack truthiness:
it returns the final stack. The consensus entry `verifyScriptFull` is the
function that adds the `EVAL_FALSE` check (Interpreter/Defs.lean:1325), so
the end-to-end rows below use it. Flags `{}` (pre-BIP66 consensus set),
policy `default`. (`Except` has no `DecidableEq` instance in this
toolchain, so the runs are pinned via Bool-matched projections —
kernel-reduced by `decide`, exactly like the `Numeric/Tests.lean` vectors.) -/

/-- Run a bare-script spend through the full consensus verifier. -/
private def runVerify (s : String) : VerifyOutcome :=
  verifyScriptFull 100 {} default (fromHex "") (fromHex s) [] default

/-- `true` iff the full verifier fails with `EVAL_FALSE`
(SCRIPT_ERR_EVAL_FALSE, the final-stack-truthiness failure). -/
private def runErrEvalFalse (s : String) : Bool :=
  match runVerify s with
  | .fail .evalFalse => true | _ => false

/-- `true` iff the full verifier accepts. -/
private def runOk (s : String) : Bool :=
  match runVerify s with
  | .ok => true | _ => false

/-- The raw evaluation's final stack (∅ on error); used only to pin stack
CONTENTS where the consensus verdict alone would be insufficient. -/
private def runFinal (s : String) : List ByteArray :=
  match evalScriptBytes 100 {} default (fromHex s) [] default SigVersion.base default with
  | .ok st => st | .error _ => []

/-- A bare push of negative-zero `0x80` leaves a bool-FALSE stack: the full
verifier fails EVAL_FALSE. (`evalScriptBytes` alone would return `.ok`.) -/
example : runErrEvalFalse "0180" = true := by decide

/-- A two-byte push of `0x80 0x00` (= +128, C1's catch) verifies: the script
is `02 8000` (PUSH2), not `01 80 00` (a one-byte push followed by OP_0). -/
example : runOk "028000" = true := by decide
example : runFinal "028000" = [fromHex "8000"] := by decide

/-- OP_IF consumes `-0` as FALSE: the ELSE branch runs. Script
`0180 63 51 67 00 68` (push 0x80; IF; OP_1; ELSE; OP_0; ENDIF) — the false
branch pushes OP_0, so the final stack is `[∅]` → EVAL_FALSE. -/
example : runErrEvalFalse "01806351670068" = true := by decide

/-- Twin with the true branch: `0180 63 51 67 51 68` leaves `[0x01]` → OK.
(With the previous example this pins that OP_IF branched on CastToBool.) -/
example : runOk "01806351675168" = true := by decide
example : runFinal "01806351675168" = [fromHex "01"] := by decide

end C2

end Bitcoin.Proofs.Audit.Z21
