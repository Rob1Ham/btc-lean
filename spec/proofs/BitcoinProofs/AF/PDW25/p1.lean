import Bitcoin.Crypto.Taproot.Program

/-! # p1 — PDW25 probe (TOP-121..125: TPR-001/002/005/007/008)

Mirrors of the in-tree green theorems of
`Bitcoin.Crypto.Taproot.Program` (statements verbatim, proofs ride
the core twins — the PDW14 F-PDW14-001 re-proof-rides-core
pattern). Tag-shape rehearsal for AF/PDW25/PDW25.lean; NOT a build
target (probe discipline, PDW16 p1). -/

namespace BitcoinProofs.AF.PDW25

open Bitcoin.Crypto.Taproot.Program (p2trProgram isPayToTaproot
  p2trScript taprootLane isAnnex spendStack classifySpend SpendPath)

/-! ## TPR-001 — P2/P9: P2TR = v1 + 32B program (native template). -/

-- P9 def-mirror (script.cpp:241-246; the decide-coercion face):
example (v : Nat) (program : ByteArray) :
    p2trProgram v program = decide (v = 1 ∧ program.size = 32) := rfl

-- P2 round-trip (core :101 statement verbatim):
example (program : ByteArray) :
    isPayToTaproot (p2trScript program) = (program.size = 32) :=
  Bitcoin.Crypto.Taproot.Program.isPayToTaproot_p2trScript program

/-! ## TPR-002 — P11: the TAPROOT flag gate. -/

-- P11 flag-off face (core :136 verbatim):
example (version : Nat) (program : ByteArray) (isP2SH : Bool) :
    taprootLane false version program isP2SH = false :=
  Bitcoin.Crypto.Taproot.Program.taprootLane_off version program isP2SH

-- P11 consensus-purity (core :143 verbatim):
example (v₁ v₂ : Nat) (p₁ p₂ : ByteArray) (i₁ i₂ : Bool)
    (hv : v₁ = v₂) (hp : p₁ = p₂) (hi : i₁ = i₂) (f : Bool) :
    taprootLane f v₁ p₁ i₁ = taprootLane f v₂ p₂ i₂ :=
  Bitcoin.Crypto.Taproot.Program.taprootLane_pure v₁ v₂ p₁ p₂ i₁ i₂ hv hp hi f

/-! ## TPR-005 — P2: annex detection. -/

-- P2 def-mirror (interpreter.cpp:1961-1969; the decide-coercion face):
example (items : List ByteArray) :
    isAnnex items =
      decide (2 ≤ items.length ∧ (items.getLast!).size ≠ 0 ∧
        ((items.getLast!).get! 0).toNat = 0x50) := rfl

-- arity rejects (core :235/:241 verbatim):
example : isAnnex [] = false :=
  Bitcoin.Crypto.Taproot.Program.isAnnex_nil

example (a : ByteArray) : isAnnex [a] = false :=
  Bitcoin.Crypto.Taproot.Program.isAnnex_single a

/-! ## TPR-007 — P2: key-path (exactly 1 post-annex element). -/

example (sig : ByteArray) :
    classifySpend [sig] = SpendPath.keyPath sig :=
  Bitcoin.Crypto.Taproot.Program.classifySpend_keyPath sig

example (sig annex : ByteArray) :
    isAnnex [sig, annex] = true →
    classifySpend [sig, annex] = SpendPath.keyPath sig :=
  Bitcoin.Crypto.Taproot.Program.classifySpend_annex_keyPath sig annex

/-! ## TPR-008 — P2: script-path (≥2 elements). -/

example (script control : ByteArray)
    (h : isAnnex [script, control] = false) :
    classifySpend [script, control] = SpendPath.scriptPath script control :=
  Bitcoin.Crypto.Taproot.Program.classifySpend_scriptPath script control h

example (script control annex : ByteArray) :
    isAnnex [script, control, annex] = true →
    classifySpend [script, control, annex] = SpendPath.scriptPath script control :=
  Bitcoin.Crypto.Taproot.Program.classifySpend_annex_scriptPath script control annex

end BitcoinProofs.AF.PDW25
