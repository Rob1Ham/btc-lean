import Bitcoin.Consensus.TxCheck
import Bitcoin.Crypto.Ecdsa.Der
import Bitcoin.Crypto.Ecdsa.Verify
import Bitcoin.Crypto.EcdsaDeep.DerSpec

/-!
# PDW69 — TOP-366..370 row faces, TxCheck stateless-check spine (route B)

Row faces for the `CheckTransaction` gates. No core writes; `@[rule]`
tags ride these theorems. Axiom target ⊆ [propext, Classical.choice, Quot.sound].
-/

namespace BitcoinProofs.AF.PDW69TxCheck

open Bitcoin.Data (Tx TxIn)
open Bitcoin.Consensus (checkTransaction TxCheckError hasDupPrevouts)
open Bitcoin.Crypto.Ecdsa.Der
open Bitcoin.Crypto.Ecdsa.Verify
open Bitcoin.Crypto.EcdsaDeep.DerSpec
open Bitcoin.Crypto.Curve.Secp
open Bitcoin.Crypto.Curve.Mod

/-! ## TXV-001 — vin non-empty -/

theorem checkTransaction_vinEmpty_reject (tx : Tx) (h : tx.vin = []) :
    checkTransaction tx = some TxCheckError.vinEmpty := by
  unfold checkTransaction
  rw [h]
  simp

theorem checkTransaction_ok_vin_ne_nil (tx : Tx)
    (h : checkTransaction tx = none) : tx.vin ≠ [] := by
  intro hempty
  unfold checkTransaction at h
  rw [hempty] at h
  split at h
  · exact absurd h (by simp)
  · next hn => exact absurd hn (by simp)

/-! ## TXV-002 — vout non-empty -/

theorem checkTransaction_voutEmpty_reject (tx : Tx)
    (hvin : tx.vin ≠ []) (h : tx.vout = []) :
    checkTransaction tx = some TxCheckError.voutEmpty := by
  unfold checkTransaction
  rw [h]
  split
  · next h1 => simp at h1; exact absurd h1 hvin
  · next _ =>
    split
    · rfl
    · next h2 => exact absurd (by simp) h2

theorem checkTransaction_ok_vout_ne_nil (tx : Tx)
    (h : checkTransaction tx = none) : tx.vout ≠ [] := by
  intro hempty
  unfold checkTransaction at h
  rw [hempty] at h
  split at h
  · exact absurd h (by simp)
  · next _ => exact absurd h (by simp)

/-! ## TXV-009 — non-coinbase has no null prevout -/

@[rule "TXV-009"]
theorem checkTransaction_ok_prevoutNotNull (tx : Tx)
    (h : checkTransaction tx = none) (hncb : tx.isCoinBase = false)
    (i : TxIn) (hi : i ∈ tx.vin) : i.prevout.isNull = false := by
  cases hpo : i.prevout.isNull with
  | false => rfl
  | true =>
    exfalso
    unfold checkTransaction at h
    split at h; · exact absurd h (by simp)
    split at h; · exact absurd h (by simp)
    split at h; · exact absurd h (by simp)
    split at h
    · exact absurd h (by simp)
    · split at h
      · exact absurd h (by simp)
      · split at h
        · next hcb => rw [hcb] at hncb; nomatch hncb
        · next hany =>
          cases hcoin : tx.isCoinBase with
          | true => rw [hcoin] at hany; nomatch hany
          | false =>
            cases hout : (tx.vin.any fun i => i.prevout.isNull) with
            | true =>
              have hall : ∀ x ∈ tx.vin, x.prevout.isNull = false := by
                rw [hout] at h
                simp at h
              have := hall i hi
              rw [hpo] at this
              nomatch this
            | false =>
              have hcontra : (tx.vin.any fun i => i.prevout.isNull) = true :=
                List.any_eq_true.mpr ⟨i, hi, hpo⟩
              have hne : ¬(tx.vin.any fun i => i.prevout.isNull) = true := by
                rw [hout]; intro hcc; nomatch hcc
              exact hne hcontra

/-! ## INV-008 — coinbase scriptSig length ∈ [2,100] -/

@[rule "INV-008"]
theorem checkTransaction_ok_cbLength (tx : Tx)
    (h : checkTransaction tx = none) (hcb : tx.isCoinBase = true)
    (i : TxIn) (hvin : tx.vin = [i]) :
    Bitcoin.Consensus.MIN_CB_LENGTH ≤ i.scriptSig.bytes.size ∧
      i.scriptSig.bytes.size ≤ Bitcoin.Consensus.MAX_CB_LENGTH := by
  unfold checkTransaction at h
  split at h; · exact absurd h (by simp)
  split at h; · exact absurd h (by simp)
  split at h; · exact absurd h (by simp)
  split at h
  · exact absurd h (by simp)
  · split at h
    · exact absurd h (by simp)
    · split at h
      · next hcoin =>
        rw [hvin] at hcoin
        cases hcoin <;> simp_all
      · next hany =>
        have habs := hany i hvin
        nomatch habs

/-! ## TXV-007 — no duplicate inputs (CVE-2018-17144) -/

@[rule "TXV-007"]
theorem checkTransaction_none_noDup (tx : Tx) (h : checkTransaction tx = none) :
    hasDupPrevouts tx.vin = false := by
  rw [checkTransaction] at h
  by_cases hv : tx.vin.isEmpty = true
  · rw [ite_eq_left hv] at h; simp at h
  · rw [ite_eq_right hv] at h
    by_cases hvo : tx.vout.isEmpty = true
    · rw [ite_eq_left hvo] at h; simp at h
    · rw [ite_eq_right hvo] at h
      by_cases hs : Bitcoin.Consensus.txStrippedWeightL tx > Bitcoin.Consensus.MAX_BLOCK_WEIGHT
      · rw [ite_eq_left hs] at h; simp at h
      · rw [ite_eq_right hs] at h
        split at h
        · simp at h
        · by_cases hd : hasDupPrevouts tx.vin = true
          · rw [ite_eq_left hd] at h; simp at h
          · rw [ite_eq_right hd] at h
            simp only [Bool.not_eq_true] at hd
            exact hd

/-! ## SGN-105 — pubkey parse rejects non-33/65-byte encodings -/

@[rule "SGN-105"]
theorem parsePubKey_wrong_length (b : ByteArray)
    (h33 : Bitcoin.Crypto.Ecdsa.Der.blen b ≠ 33)
    (h65 : Bitcoin.Crypto.Ecdsa.Der.blen b ≠ 65) :
    Bitcoin.Crypto.Ecdsa.Verify.parsePubKey b = none := by
  unfold Bitcoin.Crypto.Ecdsa.Verify.parsePubKey
  have h33' : (Bitcoin.Crypto.Ecdsa.Der.blen b == 33) = false := by simpa using h33
  have h65' : (Bitcoin.Crypto.Ecdsa.Der.blen b == 65) = false := by simpa using h65
  rw [h33', h65']; rfl

/-- The runtime `isSqrt` check is exactly the curve equation. -/
theorem onCurve_of_isSqrt (x r : Nat) (h : isSqrt (liftY2 x) r = true) :
    OnCurve x r := by
  have he := Nat.beq_eq.mp h
  unfold isSqrt at he
  simp only [mulM, addM, liftY2] at he
  rw [mul_mod_congr_left, Nat.mod_add_mod] at he
  unfold OnCurve
  rw [he]

/-- **SGN-105** (compressed): a 33-byte `02`/`03` key whose x-coordinate is
canonical and whose `x³+7` passes the square-root check is accepted, with
`y` recovered by the `p ≡ 3 (mod 4)` root and the tag-select parity. -/
@[rule "SGN-105"]
theorem parsePubKey_compressed (b : ByteArray) (tag : Nat)
    (hlen : blen b = 33) (htag : tag = 0x02 ∨ tag = 0x03)
    (hbyte : byteAt b 0 = tag)
    (hxP : readBE b 1 32 < P)
    (hsqrt : isSqrt (liftY2 (readBE b 1 32))
      (sqrtP (liftY2 (readBE b 1 32))) = true) :
    parsePubKey b = some (readBE b 1 32,
      if (tag == 0x03) == (sqrtP (liftY2 (readBE b 1 32)) % 2 == 1)
      then sqrtP (liftY2 (readBE b 1 32))
      else negN (sqrtP (liftY2 (readBE b 1 32)))) := by
  rcases htag with rfl | rfl <;>
  · unfold parsePubKey
    simp [hlen, hbyte, hxP, hsqrt]

/-- **SGN-105** (uncompressed/hybrid): a 65-byte `04`/`06`/`07` key with
canonical coordinates, the hybrid parity invariant, and the on-curve check
is accepted with its literal `(x, y)`. -/
@[rule "SGN-105"]
theorem parsePubKey_uncompressed (b : ByteArray) (tag : Nat)
    (hlen : blen b = 65) (htag : tag = 0x04 ∨ tag = 0x06 ∨ tag = 0x07)
    (hbyte : byteAt b 0 = tag)
    (hxP : ¬ (readBE b 1 32 ≥ P)) (hyP : ¬ (readBE b 33 32 ≥ P))
    (hpar06 : tag = 0x06 → (readBE b 33 32 % 2 == 1) = false)
    (hpar07 : tag = 0x07 → (readBE b 33 32 % 2 == 1) = true)
    (hon : onCurveN (readBE b 1 32) (readBE b 33 32) = true) :
    parsePubKey b = some (readBE b 1 32, readBE b 33 32) := by
  rcases htag with rfl | rfl | rfl
  · unfold parsePubKey
    simp [hlen, hbyte, hxP, hyP, hon]
  · unfold parsePubKey
    simp [hlen, hbyte, hxP, hyP, hpar06 rfl, hon]
  · unfold parsePubKey
    simp [hlen, hbyte, hxP, hyP, hpar07 rfl, hon]

/-- **SGN-105** (hybrid parity): `06` requires an even y and `07` an odd
y; a mismatch is rejected before the curve equation is consulted. -/
@[rule "SGN-105"]
theorem parsePubKey_hybrid_parity_reject (b : ByteArray) (tag : Nat)
    (hlen : blen b = 65)
    (hbyte : byteAt b 0 = tag)
    (hxP : ¬ (readBE b 1 32 ≥ P)) (hyP : ¬ (readBE b 33 32 ≥ P))
    (htag : tag = 0x06 ∨ tag = 0x07)
    (hpar06 : tag = 0x06 → (readBE b 33 32 % 2 == 1) = true)
    (hpar07 : tag = 0x07 → (readBE b 33 32 % 2 == 1) = false) :
    parsePubKey b = none := by
  rcases htag with rfl | rfl
  · unfold parsePubKey
    simp [hlen, hbyte, hxP, hyP, hpar06 rfl]
  · unfold parsePubKey
    simp [hlen, hbyte, hxP, hyP, hpar07 rfl]

/-- **SGN-105** (coordinates and curve equation): every key accepted by
`parsePubKey` has canonical coordinates `x, y < P` and satisfies
`y² = x³ + 7 (mod P)` — covering all compressed, uncompressed and hybrid
acceptance paths. -/
@[rule "SGN-105"]
theorem parsePubKey_spec (b : ByteArray) (x y : Nat)
    (h : parsePubKey b = some (x, y)) :
    x < P ∧ y < P ∧ OnCurve x y := by
  unfold parsePubKey at h
  dsimp only at h
  split at h
  · rename_i h33
    split at h
    · cases h
    · rename_i hxP
      have hxPlt : readBE b 1 32 < P := by omega
      split at h
      · cases h
      · rename_i hsqrt
        simp only [Bool.not_eq_true] at hsqrt
        cases h
        have hsqrtT : isSqrt (liftY2 (readBE b 1 32))
            (sqrtP (liftY2 (readBE b 1 32))) = true := by
          simpa using hsqrt
        have hbase : OnCurve (readBE b 1 32)
            (sqrtP (liftY2 (readBE b 1 32))) :=
          onCurve_of_isSqrt _ _ hsqrtT
        have hroot : sqrtP (liftY2 (readBE b 1 32)) < P :=
          expM_lt P _ _ P_gt_one
        refine ⟨hxPlt, ?_, ?_⟩
        · split
          · exact hroot
          · exact negN_lt _
        · split
          · exact hbase
          · exact OnCurve_negN hroot hbase
  · split at h
    · rename_i h65
      split at h
      · cases h
      · rename_i hxyP
        have hxlt : readBE b 1 32 < P := by
          have hh := hxyP
          simp at hh
          omega
        have hylt : readBE b 33 32 < P := by
          have hh := hxyP
          simp at hh
          omega
        split at h
        · cases h
        · rename_i hpar
          split at h
          · rename_i hon
            cases h
            exact ⟨hxlt, hylt, onCurveN_true hon⟩
          · cases h
    · cases h

/-! ## SGN-106 — lax DER parser rejects a non-0x30 sequence tag -/

@[rule "SGN-106"]
theorem parseDerLax_badHead (b : ByteArray)
    (h : Bitcoin.Crypto.Ecdsa.Der.byteAt b 0 ≠ 0x30) :
    Bitcoin.Crypto.Ecdsa.Der.parseDerLax b = none := by
  unfold Bitcoin.Crypto.Ecdsa.Der.parseDerLax
  have h' : (Bitcoin.Crypto.Ecdsa.Der.byteAt b 0 != 0x30) = true := by simpa using h
  simp [h']

/-- **SGN-106** (overlong-integer overflow): for any structurally valid
lax DER signature whose zero-stripped r- or s-payload exceeds 32 bytes,
`parseDerLax` returns `some (0, 0)` — the single shared overflow flag
zeroes **both** integers (Core memsets the whole 64-byte compact buffer,
pubkey.cpp:158,170,175-183). Both coordinates therefore fail the
verifier's nonzero check. -/
@[rule "SGN-106"]
theorem parseDerLax_overlong_zeroes_both
    (b : ByteArray) (p2 rlen rpos slen spos rpos' rlen' spos' slen' : Nat)
    (hstr : StrOk b p2 rlen rpos slen spos)
    (hrz : stripZeros b rpos rlen = (rpos', rlen'))
    (hsz : stripZeros b spos slen = (spos', slen'))
    (hov : rlen' > 32 ∨ slen' > 32) :
    parseDerLax b = some (0, 0) := by
  obtain ⟨hseq, htagR, hlenR, hfitR, htagS, hlenS, hfitS⟩ := hstr
  obtain ⟨hb1, hb2, h0, hlow, hhigh, hple⟩ := hseq
  obtain ⟨hp2lt, htagRval⟩ := htagR
  obtain ⟨hSlt, htagSval⟩ := htagS
  have hp2 : (if byteAt b 1 < 0x80 then 2 else 2 + (byteAt b 1 - 0x80)) = p2 := by
    by_cases h : byteAt b 1 < 0x80
    · simp [h]; exact (hlow h).symm
    · have hge : byteAt b 1 ≥ 0x80 := by omega
      simp [h]; exact (hhigh hge).symm
  have hlenR' : readLenAt b (p2 + 1) = some (rlen, rpos) := hlenR
  have hlenS' : readLenAt b (rpos + rlen + 1) = some (slen, spos) := hlenS
  have hb1ne : blen b ≠ 0 := by omega
  have hov' : (decide (rlen' > 32) || decide (slen' > 32)) = true := by
    simp [hov]
  simp [parseDerLax, hp2, hb1ne, h0, hb2, hple, hp2lt, htagRval,
    hlenR', hfitR, hSlt, htagSval, hlenS', hfitS, hrz, hsz, hov']

/-! ## Axiom pins — subset [propext, Classical.choice, Quot.sound] -/

/-- info: 'BitcoinProofs.AF.PDW69TxCheck.checkTransaction_none_noDup' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW69TxCheck.checkTransaction_none_noDup
/-- info: 'BitcoinProofs.AF.PDW69TxCheck.checkTransaction_ok_prevoutNotNull' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW69TxCheck.checkTransaction_ok_prevoutNotNull
/-- info: 'BitcoinProofs.AF.PDW69TxCheck.checkTransaction_ok_cbLength' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW69TxCheck.checkTransaction_ok_cbLength
/-- info: 'BitcoinProofs.AF.PDW69TxCheck.parsePubKey_wrong_length' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW69TxCheck.parsePubKey_wrong_length
/-- info: 'BitcoinProofs.AF.PDW69TxCheck.parseDerLax_badHead' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW69TxCheck.parseDerLax_badHead

#print axioms BitcoinProofs.AF.PDW69TxCheck.onCurve_of_isSqrt
#print axioms BitcoinProofs.AF.PDW69TxCheck.parsePubKey_compressed
#print axioms BitcoinProofs.AF.PDW69TxCheck.parsePubKey_uncompressed
#print axioms BitcoinProofs.AF.PDW69TxCheck.parsePubKey_hybrid_parity_reject
#print axioms BitcoinProofs.AF.PDW69TxCheck.parsePubKey_spec
#print axioms BitcoinProofs.AF.PDW69TxCheck.parseDerLax_overlong_zeroes_both

end BitcoinProofs.AF.PDW69TxCheck
