import Bitcoin.Interpreter.Defs

/-!
# BitcoinProofs.AF.PDW17 — TPR-060 (OP_SUCCESSx set law)

PDW17 (proof-promotion review, recovery RC21/RC22), 2026-10-17.
Claim `4d864b8`. Row **TPR-060** (P9 WIRE-DECIDE, d1, c-true):
`opcodes {80, 98, 126-129, 131-134, 137-138, 141-142, 149-153,
187-254}` — Core `script.cpp:IsOpSuccess:365-371@cce32b168`
(BIP342 OP_SUCCESSx). The tag-debt state at claim (TAGFIX
`ad6d4f3`): `@[rule "TPR-060"]` sits on the CORE DEF
`Bitcoin.Interpreter.isOpSuccessWire`
(`Interpreter/Defs.lean:441`, body `fun w => decide (8-block
lattice)` = 0 axioms, kernel-`decide`-reducible) = the
PDW16-BLK-103 thm+attr+flip gap class. Route B
(PDW14-BLK-103/PDW16): THIS sorry-free module carries
`@[rule "TPR-060"]` on the row-face theorem
(`isOpSuccessWire_set`); the CORE tag-site is UNTOUCHED (2-site
multiset, PDW16-BLK-037 powSite+compactTarget_eq precedent);
ZERO core writes. `lean_target` drift-fix in the flip (5th
instance, SCR-092/SCR-101/SCR-141 + PDW19-F-PDW19-002 class):
`Bitcoin.Interpreter.Defs.isOpSuccessWire` →
`Bitcoin.Interpreter.isOpSuccessWire` (ns
`Bitcoin.Interpreter` @ Defs.lean:54; `.Defs.` = the MODULE).

X04's side pins in `Script/Tapscript/Delta.lean` are the
untagged-twin class (PDW16-BLK-082 mirror) and are LEFT
UNTOUCHED: `checksigadd_not_success` (:89,
`isOpSuccessWire 0xba = false`, 0xba = 186 = OP_CHECKSIGADD =
just below the 187..254 block) + `disabledWire_success`
(:96 = row TPR-074, the CVE-2010-5137 set ⊆ SUCCESSx).

Honest gaps (NOT the row face, not re-proved here): the
`opSuccessScanFrom` raw-byte pre-pass + its decode-ordering
(interpreter.cpp:1846-1862) + the exec consumption = X04's
Delta lane (TPR-055..059/061..065); `disabledWire`'s
`[0x7e..0x99]`-vs-SUCCESSx set-difference laws = TPR-074/SCR-172
lanes. Probe evidence (claim, `probe2.lean`):
the set-iff below is `by simp [isOpSuccessWire]`; boundary
`#eval`s {80, 98, 187, 254} = true, {130, 154, 186, 255} =
false.
-/

namespace BitcoinProofs.AF.PDW17

open Bitcoin.Interpreter (isOpSuccessWire)

/-- **TPR-060 (the row face)**: `isOpSuccessWire w = true` iff
`w` is in the OP_SUCCESSx 8-block lattice — the set equation
`{80, 98} ∪ [126..129] ∪ [131..134] ∪ [137..138] ∪ [141..142] ∪
[149..153] ∪ [187..254]` (script.cpp:365-371 verbatim). The
def body is the `decide`-coercion of this exact lattice, hence
`simp [isOpSuccessWire]` (probe2). -/
@[rule "TPR-060"]
theorem isOpSuccessWire_set (w : Nat) :
    isOpSuccessWire w = true ↔
      (w = 80 ∨ w = 98 ∨ (126 ≤ w ∧ w ≤ 129) ∨ (131 ≤ w ∧ w ≤ 134) ∨
       (137 ≤ w ∧ w ≤ 138) ∨ (141 ≤ w ∧ w ≤ 142) ∨ (149 ≤ w ∧ w ≤ 153) ∨
       (187 ≤ w ∧ w ≤ 254)) := by
  simp [isOpSuccessWire]

/-! ## Boundary faces (untagged aux; the 186 face = the
Delta.lean:89 `checksigadd_not_success` twin, restated here per
the PDW16-BLK-082 tagged-restatement convention — the X04 core
original is untouched). -/

/-- OP_SUCCESS0 (0x50 = 80) = the first singleton. -/
theorem isOpSuccessWire_80 : isOpSuccessWire 80 = true := by decide

/-- 0x62 = 98 = the second singleton (OP_2..OP_16 gap above). -/
theorem isOpSuccessWire_98 : isOpSuccessWire 98 = true := by decide

/-- 126 = 0x7e = the 0x7e..0x81 block start. -/
theorem isOpSuccessWire_126 : isOpSuccessWire 126 = true := by decide

/-- 254 = 0xfe = the 0xbb..0xfe block end. -/
theorem isOpSuccessWire_254 : isOpSuccessWire 254 = true := by decide

/-- 130 = the 129/131 gap (inside 0x7e..0x86 NOT SUCCESS). -/
theorem isOpSuccessWire_130 : isOpSuccessWire 130 = false := by decide

/-- 154 = the 153/187 gap (0x95..0x99 block ends, 0xba ≠ yet). -/
theorem isOpSuccessWire_154 : isOpSuccessWire 154 = false := by decide

/-- 186 = 0xba = OP_CHECKSIGADD — NOT a SUCCESSx (Delta.lean:89
twin; BIP342 assigns 186 explicitly). -/
theorem isOpSuccessWire_186 : isOpSuccessWire 186 = false := by decide

/-- 255 = 0xff = the `> 0xfe` cap. -/
theorem isOpSuccessWire_255 : isOpSuccessWire 255 = false := by decide

end BitcoinProofs.AF.PDW17
