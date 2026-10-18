import Bitcoin.Script.Parser.Defs
import Bitcoin.Interpreter.Defs
import Bitcoin.Data.Script

/-!
# BitcoinProofs.Theorems.Audit.CV02 — the disabled-opcode audit (CVE-2010-5137)

ANALYSIS-suite probe. Everything below is READ-ONLY over
the frozen parser/interpreter layers (`Bitcoin.Script.Parser`, `Bitcoin.Interpreter`);
no definition of those layers is edited.

## Ground truth (Bitcoin Core @ cce32b168)

`src/script/interpreter.cpp`, `EvalScript` main loop:

* **:438-440**  `(BASE || WITNESS_V0) && script.size() > MAX_SCRIPT_SIZE`
  → `SCRIPT_ERR_SCRIPT_SIZE` (tapscript exempt);
* **:455-456**  `GetOp` mid-script failure → `SCRIPT_ERR_BAD_OPCODE`;
* **:457-458**  push payload > 520 → `SCRIPT_ERR_PUSH_SIZE`;
* **:460-465**  the 201-opcode budget, `BASE`/`WITNESS_V0` only,
  `opcode > OP_16 && ++nOpCount > 201` (:462) — OP_RESERVED (0x50) and
  all pushes ≤ OP_16 are excluded by the `> OP_16` guard (:461 comment);
* **:467-481**  the fifteen-case list — OP_CAT(0x7e) :467, OP_SUBSTR(0x7f),
  OP_LEFT(0x80), OP_RIGHT(0x81), OP_INVERT(0x83), OP_AND(0x84),
  OP_OR(0x85), OP_XOR(0x86), OP_2MUL(0x8d), OP_2DIV(0x8e), OP_MUL(0x95),
  OP_DIV(0x96), OP_MOD(0x97), OP_LSHIFT(0x98), OP_RSHIFT(0x99) :481
  (`script.h:136-168` — OP_LSHIFT = 0x98 :167, OP_RSHIFT = 0x99 :168);
* **:482**  `return set_error(serror, SCRIPT_ERR_DISABLED_OPCODE); // Disabled opcodes (CVE-2010-5137).`
  — **fail-the-script**, never skip, never reach the dispatcher;
* **:484-485**  the next check (OP_CODESEPARATOR / CONST_SCRIPTCODE);
* **:488**  `if (fExec && 0 <= opcode && opcode <= OP_PUSHDATA4)` push;
* **:493**  `else if (fExec || (OP_IF <= opcode && opcode <= OP_ENDIF))`
  dispatch — i.e. **:467-482 precedes BOTH `fExec` gates**: a disabled
  opcode fails the script even in an UNEXECUTED branch (B2 below), and
  a fortiori in an executed one (B1). This ordering IS the
  CVE-2010-5137 hardening: pre-Aug-2010, OP_LSHIFT/OP_RSHIFT were
  executed and crashed the node on shift counts ≥ 80 (10-byte CBigNum
  buffer); the fix removed them from the switch, disabled-set rejection
  replaced execution (see F-CV02-003 for the historical trace).

`ExecuteWitnessScript` (B1-checkout :1845-1876):

* **:1846-1862**  the tapscript OP_SUCCESSx pre-pass — GetOp-ordered,
  `IsOpSuccess` → `set_success` **overriding everything, including
  stack element size limits** (:1847 comment verbatim), decode failure
  → `SCRIPT_ERR_BAD_OPCODE` (:1851-1852), `DISCOURAGE_OP_SUCCESS` →
  fail (:1856-1858);
* **:1864-1865**  tapscript initial-stack cap (MAX_STACK_SIZE = 1000);
* **:1868-1871**  witness-item 520 cap (all sigversions, incl. P2WSH);
* **:1874**  `EvalScript` — for `WITNESS_V0` (:1875 lane) :467-482 fires
  as for BASE: Core re-arms the disabled set ONLY for tapscript.

`src/script/script.cpp` **:365-372** `IsOpSuccess` (B1 checkout):
`opcode == 80 || opcode == 98 || (126..129) || (131..134) || (137..138)
|| (141..142) || (149..153) || (187..254)` — superset of all 15
disabled bytes (all in 126..138), so tapscript re-enables every one
(disabledWire ⊆ IsOpSuccess, C1 below).

Historical anchors (pre-fixed-URL; `af02_` raw API evidence from the
predecessor session): f4b95c66 (v0.3.15) comment cites CVE-2010-5137 =
560ec9a4 (2010) = 05760879 (v0.3.7/v0.3.10-era) = 235ea8e (SVN),
Error-comment base fce7 grief-shape. Crash shape (BIP66-era test-pi
https://github.com/bitcoin/bitcoin/commit/05760879d88 -- CVE-2010-5137):
script pushes N then 80+ (the CBigNum 10-byte = 80-bit), OP_LSHIFT;
CBigNum::ShiftLeft heap-overflowed = remote crash (DoS) ≈ 2010-08. The
vectors (spec/vectors/incidents/CV02/) pin 80/23/22 = the historical
crash shapes; C-section pins tapscript-OP_SUCCESS re-arming.

See F-CV02-001..004.
-/

namespace BitcoinProofs.Theorems.Audit.CV02

open Bitcoin.Interpreter Bitcoin.Script.Parser Bitcoin.Activation
open Bitcoin.Data Bitcoin.Crypto.Seam

set_option maxHeartbeats 4000000
set_option maxRecDepth 200000

/-! ## Notation

All rows are Bool-valued constructor-matches (decEq-free) closed by
`rfl` in the kernel, Y10-matrix style; `decide` rows (ExecError /
VerifyOutcome enums, `Bool`, `Nat`) stay `by decide`. `Except` /
`Except ExecError Stack` props use plain `rfl` rows (Except has NO
DecidableEq ⇒ no `decide` over result-equality). `String`-decoding
(`parsePolicyFlags`) is not kernel-reducible: policy records are
literal structure updates (F-Y10-005 pattern). No `Array`-vs-`List`
literals: `ByteArray.mk #[...]` / `ByteArray.mk (Array.replicate n _)`
only. -/

/-- No consensus flags (Z09 idiom; ScriptFlags has no Inhabited). -/
def noflags : ScriptFlags := { p2sh := false }

/-- DISCOURAGE_OP_SUCCESS on, everything else off (Core :1856-1858). -/
def discOS : PolicyFlags := { discourageOpSuccess := true }

def ba (c : Nat) : ByteArray := ByteArray.mk #[c.toUInt8]

/-- The fifteen disabled wire bytes, `interpreter.cpp:467-481` @cce32b168
(script.h:136-168). 4 splice ops, 4 bitwise ops, 2 double ops,
mul-div-mod, 2 shifts. This is the wire-level table `disabledWire`
(`Defs.lean:423`), NOT the parser's `isDisabled` — the
0x9a/0x99 swap between the two is F-CV02-002 (section E). -/
def disabled15 : List Nat :=
  [0x7e, 0x7f, 0x80, 0x81, 0x83, 0x84, 0x85, 0x86,
   0x8d, 0x8e, 0x95, 0x96, 0x97, 0x98, 0x99]

theorem disabled15_nodup : disabled15.Nodup := by decide

/-! ## A. The disabled set — `disabledWire` = EXACTLY the fifteen bytes

`cv02_setEq`: full 256-byte sweep — Core :467-481 (`script.h:136-168`)
= `disabledWire` (Defs.lean:423) = `disabled15`. Closed `by decide`
(Nat-list `==` = decidable membership;-`isDisabled`-free). -/

def cv02_setEq : Bool :=
  (List.range 256).all (fun c => (disabledWire c) == (decide (c ∈ disabled15)))

theorem cv02_setEq_true : cv02_setEq = true := by decide

/-- `isOpSuccessWire` (script.cpp:365-372) contains all 15 disabled
bytes (Core: disabledWire ⊆ IsOpSuccess) — the tapscript re-arm (C). -/

def cv02_subset : Bool := disabled15.all (fun c => isOpSuccessWire c)

theorem cv02_subset_true : cv02_subset = true := by decide

/-! ## B. The main-loop audit — fail, not skip, executed AND unexecuted

The exec face: `evalScriptBytes` runs `stepBody` per parsed
opcode; `disabledWire` fires as guard 3 (Defs.lean:783), right after
push-size (guard 1) and the opcount budget (guard 2), and BEFORE the
`.ast`-dispatch (`stepBody` :769) — i.e. Core :467-482 firing after
:457-465 and before :488/:493. We pin:

* **B1 (all 15, executed)**: single-opcode script `⟨c⟩`, empty stack,
  `SigVersion.base` → `.error .disabledOpcode` — NOT `.badOpcode`, NOT
  a successful skip (Core: script FAILS).
* **B2 (all 15, unexecuted)**: `OP_0 OP_IF <c> OP_ENDIF` (vf = [false]
  at `<c>`) → disabled fires in the unexecuted branch (Core :482 < :493
  fExec gate; SCR-153). Z09's stepBody-level dark-branch theorem covers
  the base case; B2 runs the full parse/evalScriptBytes face.
* **B3 (ordering vs push-size)**: 765-byte PUSHDATA2 payload (0x4d 0xfd
  0x02 = 765 LE) + OP_CAT: `.pushSize` fires (Core :457-458 < :467),
  not `.disabledOpcode`.
* **B4 (negative flanks)**: every NON-disabled byte in 0x7e..0x9a
  (OP_SIZE 0x82, OP_EQUAL/VERIFY 0x87/0x88, OP_RESERVED1/2 0x89/0x8a,
  OP_1ADD 0x8b, OP_1SUB 0x8c, OP_NEGATE..OP_SUB 0x8f-0x94, OP_BOOLAND
  0x9a) does NOT produce `.disabledOpcode`; executed OP_SIZE =
  `.stackUnderflow`, executed OP_1 = `.ok [01]`.
* **B5 (ordering vs opcount)**: 201 OP_1ADD (0x8b) then OP_MOD:
  `.opCount` (Core :460-465 < :467) — and dually 201 OP_0 (uncounted,
  ≤ OP_16) + OP_MOD = `.disabledOpcode` (the count gate never fires) —
  pins :467 strictly above :462.
-/

/-- `OP_0 OP_IF <c> OP_ENDIF` — `vf = [false]` when `<c>` is reached,
i.e. the disabled check fires UNEXECUTED (Core :482 < :493). -/
def scriptUnexec (c : Nat) : ByteArray :=
  ba 0x00 ++ ba 0x63 ++ ba c ++ ba 0x68

/-- B-rows are decEq-free Bool constructor-matches (Y10 native-matrix
pattern — no `Except`/`ByteArray` DecidableEq needed in the kernel). -/
def rowB1 (c : Nat) : Bool :=
  match evalScriptBytes 3 noflags default (ba c) [] default .base default with
  | .error ExecError.disabledOpcode => true
  | _ => false

def matrixB1 : Bool := disabled15.all rowB1
theorem matrixB1_true : matrixB1 = true := by rfl

def rowB2 (c : Nat) : Bool :=
  match evalScriptBytes 5 noflags default (scriptUnexec c) [] default .base default with
  | .error ExecError.disabledOpcode => true
  | _ => false

def matrixB2 : Bool := disabled15.all rowB2
theorem matrixB2_true : matrixB2 = true := by rfl

/-- B3: 765-byte PUSHDATA2 payload + OP_CAT = `.pushSize` first. -/
def scriptB3 : ByteArray :=
  ByteArray.mk #[0x4d, 0xfd, 0x02] ++ ByteArray.mk (Array.replicate 765 (0x41 : UInt8))
    ++ ba 0x7e

def rowB3 : Bool :=
  match evalScriptBytes 3 noflags default scriptB3 [] default .base default with
  | .error ExecError.pushSize => true
  | _ => false
theorem rowB3_pushSize_first : rowB3 = true := by rfl

/-- The non-disabled flanks INSIDE 0x7e..0x9a: Core's :467-481 chain
falls through for these (OP_SIZE 0x82, OP_EQUAL 0x87, OP_EQUALVERIFY
0x88, OP_RESERVED1/2 0x89/0x8a, OP_1ADD 0x8b, OP_1SUB 0x8c,
OP_NEGATE..OP_SUB 0x8f-0x94, OP_BOOLAND 0x9a). Unexecuted (B2 shape)
they are all SKIPPED (.ok) — dually, B2's unexecuted-branch failure
is a DISTINGUISHING pin (disabled vs non-disabled byte-for-byte):
disabled bytes fail unexecuted branches, non-disabled do not. -/
def flanksB4 : List Nat :=
  [0x82, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c,
   0x8f, 0x90, 0x91, 0x92, 0x93, 0x94, 0x9a]

def rowB4 (c : Nat) : Bool :=
  match evalScriptBytes 5 noflags default (scriptUnexec c) [] default .base default with
  | .error ExecError.disabledOpcode => false
  | _ => true

def matrixB4 : Bool := flanksB4.all rowB4
theorem matrixB4_true : matrixB4 = true := by rfl

/-- B4 spot-check (executed, non-disabled): OP_SIZE (0x82) alone on the
empty stack = `.stackUnderflow` (Core :467-481 fall-through reaches
OP_SIZE's own INVALID_STACK_OPERATION), NOT `.disabledOpcode`. -/
def rowB4os : Bool :=
  match evalScriptBytes 3 noflags default (ba 0x82) [] default .base default with
  | .error ExecError.stackUnderflow => true
  | _ => false
theorem rowB4_opsize : rowB4os = true := by rfl

/-- B4 spot-check (pushNum): OP_1 (0x51) alone = `.ok [01]`. -/
def rowB4o1 : Bool :=
  match evalScriptBytes 3 noflags default (ba 0x51) [] default .base default with
  | .ok (ByteArray.mk #[0x01] :: []) => true
  | _ => false
theorem rowB4_op1 : rowB4o1 = true := by rfl

/-- B5a: 201 counted opcodes (OP_1ADD 0x8b; OP_0 seed OP_0) then OP_MOD
(0x97) — `.opCount` (Core :460-465) beats the disabled check (:467):
OP_MOD never reaches the disabled gate (SCR-171). -/
def scriptB5a : ByteArray :=
  ba 0x00 ++ (List.range 201).foldl (fun acc _ => acc ++ ba 0x8b) ByteArray.empty
    ++ ba 0x97

def rowB5a : Bool :=
  match evalScriptBytes 210 noflags default scriptB5a [] default .base default with
  | .error ExecError.opCount => true
  | _ => false
theorem rowB5a_opcount_first : rowB5a = true := by rfl

/-- B5-negative: 201 OP_0 (0x00 ≤ OP_16, not counted) + OP_MOD =
`.disabledOpcode` — the count gate (Core :462 `> OP_16`) does not
shield the disabled set. -/
def scriptB5b : ByteArray :=
  (List.range 201).foldl (fun acc _ => acc ++ ba 0x00) ByteArray.empty ++ ba 0x97

def rowB5b : Bool :=
  match evalScriptBytes 210 noflags default scriptB5b [] default .base default with
  | .error ExecError.disabledOpcode => true
  | _ => false
theorem rowB5b_disabled_fires : rowB5b = true := by rfl

/-! ## C. The tapscript re-arming — OP_SUCCESSx pre-pass

`ExecuteWitnessScript` (Core :1846-1862): for TAPSCRIPT only, a
GetOp-ordered pre-scan over the raw script bytes short-circuits with
SUCCESS on the first OP_SUCCESSx — overriding element limits (:1847),
the initial-stack cap (:1864-1865) and even a later truncated push
(:1851-1852; `opSuccessScan`, X04). Every disabled byte (all 126..138)
IS an OP_SUCCESSx under tapscript (disabledWire ⊆ IsOpSuccess,
script.cpp:365-372), so `executeWitnessScript` returns `.ok` for
`⟨c⟩`-tapscript — the same byte that is `.disabledOpcode` under BASE
(B1) — VERIFIED for all 15 bytes (C1), and dually P2WSH scripts are
NOT pre-scanned (Core :1875 WITNESS_V0 lane): the disabled failure is
preserved (C2). The DISCOURAGE_OP_SUCCESS policy (Core :1856-1858)
turns C1's success into `.discourageOpSuccess` (C3). The pre-scan
precedes both the witness-element 520 cap (C4, :1846 < :1868) and the
initial-stack cap (C5) — success even with a 600-byte witness item
(C4) or 1001 initial items (C5). C6 pins the byte-position ordering:
OP_CAT (0x7e) BEFORE a truncated push (0x05 0x00 = needs 5 payload
bytes, only 1 left) still succeeds; the truncated push WITHOUT a
success byte scans to `false` (BadOpCode at EvalScript).
-/

def rowC1 (c : Nat) : Bool :=
  match executeWitnessScript 3 [] 0 (ba c) noflags default default .tapscript with
  | VerifyOutcome.ok => true
  | _ => false

def matrixC1 : Bool := disabled15.all rowC1
theorem matrixC1_true : matrixC1 = true := by rfl

/-- C2: the P2WSH inner exec (`executeWitnessScript` sv = `.witnessV0`)
has NO pre-scan (Core :1846 TAPSCRIPT-only, :1875 WITNESS_V0) —
`.fail .disabledOpcode` for every disabled byte. -/
def rowC2 (c : Nat) : Bool :=
  match executeWitnessScript 3 [] 0 (ba c) noflags default default .witnessV0 with
  | VerifyOutcome.fail ExecError.disabledOpcode => true
  | _ => false

def matrixC2 : Bool := disabled15.all rowC2
theorem matrixC2_true : matrixC2 = true := by rfl

/-- C3: `DISCOURAGE_OP_SUCCESS` (Core :1856-1858). Policy records are
literal structure updates: `parsePolicyFlags`'s `String.splitOn` is
not kernel-reducible (F-Y10-005 pattern). -/
theorem rowC3_discourage :
    executeWitnessScript 3 [] 0 (ba 0x7e) noflags discOS default .tapscript
      = VerifyOutcome.fail ExecError.discourageOpSuccess := by rfl

/-- C4: OP_SUCCESS beats the 520-byte witness item cap
(Core :1847 vs :1868-1871) — `.ok` with a 600-byte item. -/
theorem rowC4_itemsize :
    executeWitnessScript 3 [ByteArray.mk (Array.replicate 600 (0x00 : UInt8))] 0
      (ba 0x98) noflags default default .tapscript = VerifyOutcome.ok := by rfl

/-- C5: OP_SUCCESS beats the initial-stack cap (1001 items,
Core :1847 vs :1864-1865). -/
theorem rowC5_stacksize :
    executeWitnessScript 3 (List.replicate 1001 ByteArray.empty) 0
      (ba 0x99) noflags default default .tapscript = VerifyOutcome.ok := by rfl

/-- C6: the pre-scan is byte-ordered (X04): OP_CAT (success) BEFORE a
truncated push still succeeds; the truncated push alone scans false. -/
def scanC6a : ByteArray := ba 0x7e ++ ByteArray.mk #[0x05, 0x00] ++ ba 0x00
def scanC6b : ByteArray := ByteArray.mk #[0x05, 0x00] ++ ba 0x00

theorem rowC6a_success_beats_truncation : opSuccessScan scanC6a = true := by decide
theorem rowC6b_truncation_only : opSuccessScan scanC6b = false := by decide

/-! ## D. Negative pins — script-size pre-gate, no tapscript exemption

EvalScript pre-gate (Core :438-440): `.scriptSize` for non-tapscript
before any opcode (D1); tapscript does NOT take the gate (D2) — ours
`sv = .tapscript` makes the guard's antecedent false (Defs.lean:1118),
Core likewise gates on `BASE || WITNESS_V0` (:438). A D2-execution row
(10001-byte tapscript) is beyond the kernel's `by rfl` budget
(F-Y10-005 class); D2 pins the gate-antecedent fact + the Core anchor.
-/

def scriptD (n : Nat) : ByteArray := ByteArray.mk (Array.replicate n (0x00 : UInt8))

def rowD1 : Bool :=
  match evalScriptBytes 3 noflags default (scriptD 10001) [] default .base default with
  | .error ExecError.scriptSize => true
  | _ => false
theorem rowD1_scriptsize : rowD1 = true := by rfl

/-- D2: tapscript takes NO :438-440 gate (ours Defs.lean:1118, the
`(sv = .base ∨ sv = .witnessV0)` antecedent is false at `.tapscript`). -/
theorem rowD2_tapscript_no_sizegate :
    ¬(SigVersion.tapscript = SigVersion.base ∨
      SigVersion.tapscript = SigVersion.witnessV0) := by decide

/-! ## E. Aux pins (F-CV02-002) — `isDisabled` ≠ `disabledWire`

The parser-level predicate (Parser/Defs.lean:62) and the
interpreter-level table (Defs.lean:423) disagree on OP_RSHIFT:
`disabledWire 0x99 = true` (Core OP_RSHIFT = 0x99, script.h:168) but
`isDisabled 0x99 = false`, and dually `isDisabled 0x9a = true` (=
OP_BOOLAND!, script.h:170) while `disabledWire 0x9a = false`. The
interpreter/elaborator path uses `disabledWire` only (F-CV02-002
grep evidence), so NO consensus effect — but its own test file
pins THE SWAPPED SET as correct (core/Test/Script/Parser/Tests.lean
:151-175) — F-CV02-002 (read-only divergence pin). -/

theorem aux_isDisabled_099 : isDisabled ⟨0x99, by decide⟩ = false := by decide
theorem aux_disabledWire_099 : disabledWire 0x99 = true := by decide
theorem aux_isDisabled_09a : isDisabled ⟨0x9a, by decide⟩ = true := by decide
theorem aux_disabledWire_09a : disabledWire 0x9a = false := by decide

end BitcoinProofs.Theorems.Audit.CV02
