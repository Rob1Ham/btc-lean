import Bitcoin.Interpreter.Rules
import Bitcoin.Crypto.Taproot.Program
import Bitcoin.Ledger.Utxo
import Bitcoin.Ledger.Interface
import Bitcoin.Invariants.RC10

/-! # PDW18.lean

Five rows, one or more sorry-free promotion theorems each (route B,
PDW11/PDW12/PDW16 pattern — zero core writes, the `@[rule]` tags ride
THESE theorems; module deliberately NOT imported by the
`BitcoinProofs` root, PDW12-isolation pattern — own-target built,
outside `core/**`):

* **SCR-042** `evalChecksigTapscript` (tag-on-def Defs.lean:722
  8-stack) → `evalChecksigTapscript_upgradable_key_decrements`
  (the Rules.lean:481 twin restated, the budget-decrement law).
* **TPR-009** `controlBlockSizeOk` (tag-on-def Program.lean:389 +
  the LVS:189 proofs-twin) → `_sizes` + `_minimal` + `_maximal` +
  `_66` + `_m` + `_iff` (the 33+32m 0≤m≤128 lattice, the
  Program:398..436/LVS:211..227 twins on the core def).
* **INV-051** `cmsCleanup` (tag-on-def Defs.lean:667) →
  `cmsCleanup_nullFail_fires` + `_nullFail_off` + `_le` +
  `_fuel0` (the BIP146 flag-gate, fail-closed).
* **BLK-101** `Coin` (tag-on-struct Utxo.lean:21) → `Coin_mk_eta` +
  `Coin_mk_inj` + `Coin_coinbase_two_face` (the 4-field record law).
* **INV-114** `isSpent` (tag-on-def RC10.lean:42 + the Utxo:21
  stack) → `isSpent_true_iff_none` + `isSpent_false_iff_some`
  (the isSpent_iff/coins.h:45-101 twin).

Honest gaps (F-PDW18-003-class weaker honest variants, all
sorry-free): INV-051 — the gate's `st[0]!.size ≠ 0` is NOT
syntactically the def's `st[0]?.getD default = ByteArray.empty`
(`st[0]!` not defeq the getD-form, p4-probe); `_nullFail_fires`
carries the getD-form (= the Core `!vchSig.empty()` intent). BLK-101
— the on-disk 31+1-bit code-word elided (INV-115 `coinMetaEncode`,
RC10). SCR-042 — the Rules.lean:481 twin verbatim (Core :368-376).
Probes = p0..p6 (p5/p6 RC=0). -/

namespace BitcoinProofs.AF.PDW18

open Bitcoin.Interpreter Bitcoin.Crypto.Taproot.Program Bitcoin.Ledger
     Bitcoin.Invariants.RC10 Bitcoin.Data

/-! ## SCR-042 — the upgradable-key budget decrement
(interpreter.cpp:368-376 @cce32b168: an upgradable (non-32-byte,
non-empty) pubkey still consumes the budget — the decrement precedes
the pubkey-size dispatch; the untagged core twin =
Rules.lean:481). -/

@[rule "SCR-042"]
theorem evalChecksigTapscript_upgradable_key_decrements
    (pol : PolicyFlags) (chk : ScriptChecker)
    (ed : Bitcoin.Crypto.Seam.ScriptExecutionData)
    (sig pk : ByteArray) (vw : Option Int)
    (hsig : sig.size ≠ 0) (hpk0 : pk.size ≠ 0) (hpk32 : pk.size ≠ 32)
    (hno : pol.discourageUpgradablePubkeyType = false)
    (hvw : 0 ≤ (vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED) :
    evalChecksigTapscript pol chk ed sig pk vw
      = .ok (true, some ((vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED)) := by
  simp [evalChecksigTapscript, hsig, hpk0, hpk32, hno,
    show ¬((vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED < 0) by omega]

/-! ## INV-114 — spent ⇔ null-out (coins.h:45-101 @cce32b168:
`IsSpent() = out.IsNull()`; the row's B-2 tag-sites =
RC10.lean:42 + the Utxo.lean:21 stack; the core twin `isSpent_iff`
(RC10:47) is the TXV-075-tagged pre-existing vehicle — mine = the
row-facing INV-114 restatement). -/

@[rule "INV-114"]
theorem isSpent_true_iff_none (u : UtxoSet) (o : OutPoint) :
    isSpent u o = true ↔ u o = none := by
  refine ⟨fun hs => ?_, fun hn => ?_⟩
  · cases h : u o with
    | none => rfl
    | some c =>
      exfalso
      rw [isSpent, h] at hs
      simp at hs
  · rw [isSpent, hn]; rfl

theorem isSpent_false_iff_some (u : UtxoSet) (o : OutPoint) :
    isSpent u o = false ↔ ∃ c, u o = some c := by
  cases h : u o with
  | none => simp [isSpent, h]
  | some c => simp [isSpent, h]

/-! ## BLK-101 — the Coin record law (coins.h:45-72 @cce32b168:
value + scriptPubKey + creation height + coinbase bit, 31+1 bits on
disk; honest gap: the on-disk code-word elided = INV-115
`coinMetaEncode`, RC10). -/

@[rule "BLK-101"]
theorem Coin_mk_eta (c : Coin) :
    Coin.mk c.value c.height c.isCoinbase c.scriptPubKey = c := rfl

theorem Coin_mk_inj {v : Amount} {h : UInt32} {cb : Bool} {s : Script}
    {v' : Amount} {h' : UInt32} {cb' : Bool} {s' : Script}
    (hi : Coin.mk v h cb s = Coin.mk v' h' cb' s') :
    v = v' ∧ h = h' ∧ cb = cb' ∧ s = s' := by
  injection hi with h1 h2 h3 h4; exact ⟨h1, h2, h3, h4⟩

/-- The coinbase-bit 2-face (the `fCoinBase : 1` of the code word):
both bit-values are inhabitable records, P6 Core Coin. -/
theorem Coin_coinbase_two_face (c : Coin) :
    c.isCoinbase = true ∨ c.isCoinbase = false := by
  cases c.isCoinbase with
  | true => exact Or.inl rfl
  | false => exact Or.inr rfl

example : (Coin.mk 0 0 true Script.empty).isCoinbase = true := rfl
example : (Coin.mk 0 0 false Script.empty).isCoinbase = false := rfl

/-! ## INV-051 — the NULLFAIL flag-gate (BIP146,
interpreter.cpp:351-352,1196-1198 @cce32b168: `!fSuccess ∧
pol.nullFail ∧ sig nonempty → sigNullFail`; the POLICY word —
block validation with the consensus-default policy never raises
sigNullFail). Honest gap (F-PDW18-003): the def's gate arm
`st[0]!.size ≠ 0` is not syntactically the elaborated
`st[0]?.getD default = ByteArray.empty` (p4-probe) —
`_nullFail_fires` carries the getD-form (the `!vchSig.empty()`
intent). -/

@[rule "INV-051"]
theorem cmsCleanup_nullFail_fires (pol : PolicyFlags) (st : Stack)
    (fSuccess : Bool) (i ikey2 f : Nat) (hi : 1 < i)
    (hfs : fSuccess = false) (hpol : pol.nullFail = true)
    (hikey2 : ikey2 = 0)
    (hsz' : ¬ (st[0]?.getD default = ByteArray.empty)) :
    cmsCleanup pol st fSuccess i ikey2 (f + 1) = .error .sigNullFail := by
  have hi1 : ¬ (i ≤ 1) := by omega
  simp [cmsCleanup, hfs, hpol, hikey2, hi1, hsz']

/-- The P11 fail-closed face: nullFail off ⇒ NO sigNullFail at any
i/ikey2/fuel (fuel-induction, the recursion changes st/i/ikey2). -/
theorem cmsCleanup_nullFail_off (pol : PolicyFlags) (st : Stack)
    (fSuccess : Bool) (i ikey2 fuel : Nat)
    (hpol : pol.nullFail = false) :
    cmsCleanup pol st fSuccess i ikey2 fuel ≠ .error .sigNullFail := by
  induction fuel generalizing st i ikey2 with
  | zero => intro h; simp [cmsCleanup] at h
  | succ f ih =>
      intro h
      by_cases hi : i ≤ 1
      · simp [cmsCleanup, hi] at h
      · simp [cmsCleanup, hpol, hi] at h
        exact ih st.tail (i - 1) (if 0 < ikey2 then ikey2 - 1 else ikey2) h

/-- The i ≤ 1 boundary face (the cleanup exit). -/
theorem cmsCleanup_le (pol : PolicyFlags) (st : Stack) (fSuccess : Bool)
    (i ikey2 fuel : Nat) (hi : i ≤ 1) :
    cmsCleanup pol st fSuccess i ikey2 fuel = .ok st := by
  cases fuel with
  | zero => simp [cmsCleanup, hi]
  | succ f => simp [cmsCleanup, hi]

/-- The fuel-0 boundary face (both arms = `.ok st`). -/
theorem cmsCleanup_fuel0 (pol : PolicyFlags) (st : Stack) (fSuccess : Bool)
    (i ikey2 : Nat) :
    cmsCleanup pol st fSuccess i ikey2 0 = .ok st := by
  by_cases hi : i ≤ 1
  · simp [cmsCleanup, hi]
  · simp [cmsCleanup, hi]

/-! ## TPR-009 — the control-block size lattice
(interpreter.cpp:1979-1982 + interpreter.h:244-247 @cce32b168:
`33 ≤ len ≤ 4129 ∧ (len−33) % 32 = 0`; the untagged core twins =
Program.lean:398..436 (the F-X03-1 Core-33 repair), the LVS:189
proofs-twin + the LVS:211 `_iff` = the "both levels" of the claim
register). -/

@[rule "TPR-009"]
theorem controlBlockSizeOk_sizes (control : ByteArray) :
    controlBlockSizeOk control = true ↔
      (33 ≤ control.size ∧ control.size ≤ 33 + 128 * 32 ∧
        (control.size - 33) % 32 = 0) := by
  unfold controlBlockSizeOk
  exact decide_eq_true_iff

/-- Minimal: m = 0 (the leaf sits directly under the output key). -/
theorem controlBlockSizeOk_minimal (control : ByteArray)
    (h : control.size = 33) : controlBlockSizeOk control = true :=
  (controlBlockSizeOk_sizes control).mpr (by omega)

/-- Maximal: m = 128 (the deepest tapscript tree). -/
theorem controlBlockSizeOk_maximal (control : ByteArray)
    (h : control.size = 33 + 128 * 32) :
    controlBlockSizeOk control = true :=
  (controlBlockSizeOk_sizes control).mpr (by omega)

/-- Reject face: 66 = 33 + 33 is off-lattice ((66−33) % 32 ≠ 0). -/
theorem controlBlockSizeOk_66 (control : ByteArray)
    (h : control.size = 66) : controlBlockSizeOk control = false := by
  have h' : ¬ (33 ≤ control.size ∧ control.size ≤ 33 + 128 * 32 ∧
      (control.size - 33) % 32 = 0) := by
    rw [h]; decide
  exact decide_eq_false_iff_not.mpr h'

/-- The m-recovery: every accepted size determines its m, 0 ≤ m ≤ 128. -/
theorem controlBlockSizeOk_m (control : ByteArray)
    (h : controlBlockSizeOk control = true) :
    ∃ m : Nat, 0 ≤ m ∧ m ≤ 128 ∧ control.size = 33 + 32 * m := by
  obtain ⟨h₁, h₂, h₃⟩ := (controlBlockSizeOk_sizes control).mp h
  refine ⟨(control.size - 33) / 32, by omega, ?_, ?_⟩
  · have hlt : control.size - 33 < 32 * 129 := by omega
    have := Nat.div_lt_of_lt_mul hlt
    omega
  · have := Nat.div_add_mod (control.size - 33) 32
    omega

/-- The parse-domain iff: the gate accepts exactly the lattice
`{33 + 32·m | m ≤ 128}` (the LVS:211 `_iff` on the core def). -/
theorem controlBlockSizeOk_iff (control : ByteArray) :
    controlBlockSizeOk control = true ↔
      ∃ m : Nat, m ≤ 128 ∧ control.size = 33 + 32 * m := by
  rw [controlBlockSizeOk_sizes]
  constructor
  · rintro ⟨h1, h2, h3⟩
    refine ⟨(control.size - 33) / 32, ?_, ?_⟩
    · have hlt : control.size - 33 < 32 * 129 := by omega
      have := Nat.div_lt_of_lt_mul hlt
      omega
    · have := Nat.div_add_mod (control.size - 33) 32
      omega
  · rintro ⟨m, hm, heq⟩
    rw [heq]
    exact ⟨by omega, by omega, by omega⟩

/-! ## BLK-101 — the 31-bit well-formedness domain

`Coin.height` is a full `UInt32` in `Bitcoin/Ledger/Utxo.lean` (outside
this module), so the 31-bit field cannot be enforced by a
subtype here.  We therefore state the invariant as a predicate, prove
that every coin *constructed/stored* by the model's UTXO update path
satisfies it (given the connection height is below `2^31`), and prove
that the invariant is not automatic for an arbitrary record — the exact
residual the re-audit names. -/

/-- BLK-101: the 31-bit height domain of the on-disk metadata word
(coins.h:77-89: `nHeight : 31`, `fCoinBase : 1`). -/
@[rule "BLK-101"]
def CoinWellFormed (c : Coin) : Prop := c.height.toNat < 2 ^ 31

theorem CoinWellFormed_iff (c : Coin) :
    CoinWellFormed c ↔ c.height.toNat < 2 ^ 31 := Iff.rfl

theorem Coin_mk_wellFormed_iff (v : Amount) (h : UInt32) (cb : Bool)
    (s : Script) :
    CoinWellFormed (Coin.mk v h cb s) ↔ h.toNat < 2 ^ 31 := Iff.rfl

/-- A well-formed coin's metadata word is a 32-bit value: 31 height bits
plus the 1 coinbase bit. -/
@[rule "BLK-101"]
theorem CoinWellFormed_meta_lt (c : Coin) (hw : CoinWellFormed c) :
    Bitcoin.Invariants.RC10.coinMetaEncode c.height.toNat c.isCoinbase <
      2 ^ 32 :=
  Bitcoin.Invariants.RC10.coinMetaEncode_lt _ _ hw

/-- Decoding any 32-bit metadata code word lands in the 31-bit height
domain (the decoder projection `nHeight = code >> 1`). -/
@[rule "BLK-101"]
theorem coinMetaDecode_wellFormed (code : Nat) (hc : code < 2 ^ 32) :
    (Bitcoin.Invariants.RC10.coinMetaDecode code).1 < 2 ^ 31 := by
  unfold Bitcoin.Invariants.RC10.coinMetaDecode
  have h32 : (2 : Nat) ^ 32 = 2 ^ 31 * 2 := by
    rw [show (32 : Nat) = 31 + 1 by omega, Nat.pow_succ]
  rw [h32] at hc
  exact Nat.div_lt_of_lt_mul hc

/-- Coins produced from a 32-bit metadata code word are well formed. -/
@[rule "BLK-101"]
def Coin.ofMeta (value : Amount) (code : Nat) (s : Script) : Coin :=
  let p := Bitcoin.Invariants.RC10.coinMetaDecode code
  ⟨value, UInt32.ofNat p.1, p.2, s⟩

@[rule "BLK-101"]
theorem Coin.ofMeta_wellFormed (value : Amount) (code : Nat) (s : Script)
    (hc : code < 2 ^ 32) : CoinWellFormed (Coin.ofMeta value code s) := by
  unfold Coin.ofMeta CoinWellFormed
  have hlt := coinMetaDecode_wellFormed code hc
  have hlt32 : (Bitcoin.Invariants.RC10.coinMetaDecode code).1 < 2 ^ 32 := by
    omega
  simp [UInt32.toNat_ofNat, Nat.mod_eq_of_lt hlt32, hlt]

/-- Every coin inserted by `UpdateCoins`/`AddCoins` carries the
connection height and is therefore well formed whenever that height is
below `2^31` (the consensus-reachable heights). -/
@[rule "BLK-101"]
theorem addedCoins_wellFormed (tx : Tx) (key : Key) (height : UInt32)
    (hh : height.toNat < 2 ^ 31) :
    ∀ p ∈ addedCoins tx key height, CoinWellFormed p.2 := by
  intro p hp
  obtain ⟨j, _, _, _, hp2⟩ := addedCoins_inv tx key height p hp
  rw [hp2]
  exact hh

/-- The UTXO update path preserves the 31-bit invariant: every coin in a
well-formed view remains well formed after `updateCoins`, and every newly
added coin is well formed by `addedCoins_wellFormed`. -/
@[rule "BLK-101"]
theorem updateCoins_preserves_wellFormed (u : UtxoSet) (tx : Tx)
    (key : Key) (height : UInt32)
    (hu : ∀ o c, u o = some c → CoinWellFormed c)
    (hh : height.toNat < 2 ^ 31) :
    ∀ o c, updateCoins u tx key height o = some c → CoinWellFormed c := by
  intro o c hc
  unfold updateCoins at hc
  split at hc
  · rename_i c' hlook
    simp only [Option.some.injEq] at hc
    subst hc
    obtain ⟨p, hp, _, hpc⟩ :=
      coinLookup_some_inv (addedCoins tx key height) o c' hlook
    rw [← hpc]
    exact addedCoins_wellFormed tx key height hh p hp
  · split at hc
    · exact hu o c hc
    · split at hc
      · simp at hc
      · exact hu o c hc

/-- The residual is real: `Coin.height` is an unrestricted `UInt32`, so
`CoinWellFormed` does not hold for every in-model record.  A subtype (or
an invariant on `UtxoSet`) in `Bitcoin/Ledger/Utxo.lean` would be needed
to make the 31-bit domain automatic; that file is outside this module. -/
theorem Coin_not_all_wellFormed : ¬ ∀ c : Coin, CoinWellFormed c := by
  intro h
  have := h (Coin.mk 0 0x80000000 false Script.empty)
  simp [CoinWellFormed, UInt32.toNat_ofNat] at this

end BitcoinProofs.AF.PDW18
