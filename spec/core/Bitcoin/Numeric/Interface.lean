import Bitcoin.Data.Basic
import Bitcoin.Data.Script
import Bitcoin.Numeric.ScriptNum

/-!
# Bitcoin.Numeric — FROZEN INTERFACE

## Interface contract (do not edit outside an interface-change PR)

Core counterpart files: src/script/interpreter.cpp (CScriptNum:415-451,
                        CScriptNum::GetNum64?, decode: GetOp/arith paths,
                        CastToBool:437-445), src/consensus/amount.h
Status: frozen 2026-10-16. Statements are
                        sorry-stubbed placeholders; the bodies are filled.

## Scope

`CScriptNum` (int64, little-endian, sign bit, 4-byte default carry
limit), the minimal-encoding rule, `CastToBool`, and the fee/amount
arithmetic layer on top of the prototype's `Amount := Int` + `MoneyRange`
(`Bitcoin.Data.Basic` — already live). Exit: SCR numeric rules + overflow
theorems sorry-free.
-/

namespace Bitcoin.Numeric

open Bitcoin.Data

/-- Default CScriptNum serialization width limit (`nMaxNumSize = 4`);
OP_CHECKMULTISIG/OP_CLTV/OP_CSV contexts pass other widths (5 for CLTV
pre-BIP65-compat calls). -/
@[rule "SCR-080"]
def SCRIPT_NUM_DEFAULT_MAX_SIZE : Nat := 4

/-- `CScriptNum` value type. `Int` (not Nat): Core's CScriptNum is
int64 and negative values are representable (OP_1NEGATE etc.). -/
abbrev ScriptNum := Int

/-- `CScriptNum` decode (interpreter.cpp:429-451, `CScriptNum(vch,
fRequireMinimal, nMaxNumSize)`): little-endian sign-magnitude, minimal
encoding optional-but-default, width ≤ nMaxNumSize.
Implementation: `decodeBE` on the big-endian view of the wire bytes
(`Bitcoin.Numeric.ScriptNum`; wire is LE, so reverse). -/
@[rule "SCR-081"]
def decodeScriptNum :
    ByteArray → Bool → Nat → Option ScriptNum :=
  fun b minimal maxSize => decodeBE minimal maxSize (bytesOf b).reverse

/-- `CScriptNum` encode (interpreter.cpp:415-427, `getvch`): minimal
LE sign-magnitude; 0 encodes as the empty byte string.
Implementation: `scriptNumBE` (canonical BE digits) reversed to wire
order. Core's encoder is unconditionally canonical, so the `minimal`
flag is accepted for interface symmetry and ignored. -/
@[rule "SCR-082", rule "SCR-085"]
def encodeScriptNum : ScriptNum → Bool → ByteArray :=
  fun n _minimal => bytesFromLE (scriptNumBE n).reverse

/-- `CastToBool` (interpreter.cpp:437-444): false iff all bytes are 0x00,
or the only nonzero byte is a lone `0x80` sign byte in the most
significant (wire-last) position — the negative zero (SCR-057/083).
Truth table pinned against interpreter.cpp:46-59; see
`castToBool_iff_setVchBE` below. -/
@[rule "SCR-057"]
def castToBool : ByteArray → Bool :=
  fun b => castToBoolList (bytesOf b).reverse

/-- Fee arithmetic helper: `fee = valueIn − valueOut` as computed by
`Consensus::CheckTxInputs` (tx_verify.cpp:186-193); negative fee ⇒
`bad-txns-in-belowout`. -/
def feeOf : Amount → Amount → Amount :=
  fun vi vo => vi - vo

/-- `MoneyRange` positive-ray law: `0 ≤ n ≤ MAX_MONEY` (amount.h:27),
already implemented in the prototype — restated here as the numeric-layer entry of the
CAmount story. -/
@[rule "TXV-068"]
theorem moneyRange_iff (n : Amount) :
    MoneyRange n = true ↔ (0 ≤ n ∧ n ≤ MAX_MONEY) := by
  simp only [MoneyRange, decide_eq_true_iff]

/-- INV: fee is in MoneyRange whenever both sides are
(`MoneyRange(nFee)` check, tx_verify.cpp:194-196). -/
theorem fee_in_money_range (vi vo : Amount)
    (hvi : MoneyRange vi) (hvo : MoneyRange vo)
    (h : vi ≥ vo) : MoneyRange (feeOf vi vo) = true := by
  have h1 : 0 ≤ vi ∧ vi ≤ MAX_MONEY := (moneyRange_iff vi).mp hvi
  have h2 : 0 ≤ vo ∧ vo ≤ MAX_MONEY := (moneyRange_iff vo).mp hvo
  refine (moneyRange_iff (feeOf vi vo)).mpr ?_
  show 0 ≤ vi - vo ∧ vi - vo ≤ MAX_MONEY
  -- NOTE: `omega` cannot see through the `Amount` abbrev here; use core Int lemmas.
  refine ⟨Int.sub_nonneg.mpr h, ?_⟩
  exact Int.le_trans (Int.sub_le_self vi h2.1) h1.2

/-! ## Frozen laws (the numeric layer exit criteria) -/

/-- Roundtrip for values representable within the width bound. -/
theorem scriptNum_roundtrip (n : ScriptNum) (minimal : Bool)
    (h : n ≥ -(2^(8 * SCRIPT_NUM_DEFAULT_MAX_SIZE - 1) - 1)
       ∧ n ≤  (2^(8 * SCRIPT_NUM_DEFAULT_MAX_SIZE - 1) - 1)) :
    decodeScriptNum (encodeScriptNum n minimal) minimal SCRIPT_NUM_DEFAULT_MAX_SIZE = some n := by
  obtain ⟨hlo, hhi⟩ := h
  have hN : (2 : Int) ^ (8 * SCRIPT_NUM_DEFAULT_MAX_SIZE - 1) - 1 = 2147483647 := by
    unfold SCRIPT_NUM_DEFAULT_MAX_SIZE
    decide
  rw [hN] at hlo hhi
  have h2pow : (2 : Nat) ^ 31 = 2147483648 := by decide
  -- `omega` cannot see through the `ScriptNum` abbrev on `n`, so discharge
  -- via a fresh `Int`-typed variable.
  have bound : ∀ m : Int, m ≤ 2147483647 → m ≥ -2147483647 → m.natAbs < 2147483648 := by
    intro m _ _
    omega
  have habs : n.natAbs < 2 ^ (31 : Nat) := by
    rw [h2pow]
    exact bound n hhi hlo
  have h10 : n.natAbs < 256 ^ 10 := natAbs_lt_pow10 _ habs
  show decodeBE minimal SCRIPT_NUM_DEFAULT_MAX_SIZE
      (bytesOf (bytesFromLE (scriptNumBE n).reverse)).reverse = some n
  rw [bytesOf_bytesFromLE _ (fun m hm =>
      scriptNumBE_digits_lt n m (List.mem_reverse.mp hm)),
    List.reverse_reverse,
    decodeBE_some (maxSize := SCRIPT_NUM_DEFAULT_MAX_SIZE)
      (scriptNumBE_length_le4 n habs)
      (Or.inr (minimalOkBE_scriptNumBE n h10)),
    scriptNumBE_value n h10]

/-- The 4-byte rule: decode refuses values needing > 4 bytes unless the
caller widens the bound. -/
@[rule "SCR-079"]
theorem scriptNum_four_byte_rule (b : ByteArray)
    (h : b.size > SCRIPT_NUM_DEFAULT_MAX_SIZE) :
    decodeScriptNum b true SCRIPT_NUM_DEFAULT_MAX_SIZE = none := by
  have hlen : (bytesOf b).reverse.length > SCRIPT_NUM_DEFAULT_MAX_SIZE := by
    rw [List.length_reverse, bytesOf_length]; exact h
  show decodeBE true SCRIPT_NUM_DEFAULT_MAX_SIZE (bytesOf b).reverse = none
  unfold decodeBE
  rw [ite_eq_left hlen]

/-- SCR-079 (flag-independent form): the width guard precedes the
minimal-encoding guard, so the 4-byte rule holds for *either* value of
`fRequireMinimal`. This is the form the interpreter's `decodeNum` (which
passes `pol.minimalData`) consumes in `Bitcoin.Numeric.RowFaces`. -/
@[rule "SCR-079"]
theorem scriptNum_four_byte_rule_any (b : ByteArray) (minimal : Bool)
    (h : b.size > SCRIPT_NUM_DEFAULT_MAX_SIZE) :
    decodeScriptNum b minimal SCRIPT_NUM_DEFAULT_MAX_SIZE = none := by
  have hlen : (bytesOf b).reverse.length > SCRIPT_NUM_DEFAULT_MAX_SIZE := by
    rw [List.length_reverse, bytesOf_length]; exact h
  show decodeBE minimal SCRIPT_NUM_DEFAULT_MAX_SIZE (bytesOf b).reverse = none
  unfold decodeBE
  rw [ite_eq_left hlen]

/-- SCR-079/SCR-080 (any width): `nMaxNumSize` is enforced before every
other decode gate, so an operand wider than the passed limit decodes to
`none` regardless of `fRequireMinimal` (`script.h:257-261`). -/
@[rule "SCR-079", rule "SCR-080"]
theorem scriptNum_width_rule (b : ByteArray) (minimal : Bool) (maxSize : Nat)
    (h : b.size > maxSize) :
    decodeScriptNum b minimal maxSize = none := by
  have hlen : (bytesOf b).reverse.length > maxSize := by
    rw [List.length_reverse, bytesOf_length]; exact h
  show decodeBE minimal maxSize (bytesOf b).reverse = none
  unfold decodeBE
  rw [ite_eq_left hlen]

/-- Minimal-encoding rule (SCR row: non-minimal pushes rejected when
`fRequireMinimal`): a trailing 0x00 or redundant sign byte is refused.

INTERFACE CHANGE (documented in the script-number notes): the frozen
statement (`1 < b.size ∧ back = 0 ⇒ reject`) is FALSE as stated — the
counterexample is the two-byte `0x80 0x00` (= 128), which Core accepts
(script.h:252-268 rejects only when the *second-to-last* byte's high bit
is also clear). The corrected hypothesis `(b.get! (b.size - 2)).toNat
< 128` restores exact Core semantics. -/
@[rule "SCR-084"]
theorem scriptNum_minimal_reject (b : ByteArray)
    (h : 1 < b.size ∧ (b.get! (b.size - 1)).toNat = 0
       ∧ (b.get! (b.size - 2)).toNat < 128) :
    decodeScriptNum b true SCRIPT_NUM_DEFAULT_MAX_SIZE = none := by
  obtain ⟨h1, hb1, hb2⟩ := h
  show decodeBE true SCRIPT_NUM_DEFAULT_MAX_SIZE (bytesOf b).reverse = none
  unfold decodeBE
  by_cases hw : (bytesOf b).reverse.length > SCRIPT_NUM_DEFAULT_MAX_SIZE
  · rw [ite_eq_left hw]
  · rw [ite_eq_right hw]
    cases hl : (bytesOf b).reverse with
    | nil =>
      have hz : ([] : List Nat).length = b.size := by
        rw [← hl, List.length_reverse, bytesOf_length]
      rw [List.length_nil] at hz
      exact absurd h1 (by omega)
    | cons d t =>
      have hlen : (d :: t).length = b.size := by
        rw [← hl, List.length_reverse, bytesOf_length]
      rw [List.length_cons] at hlen
      have hd : d = (b.get! (b.size - 1)).toNat := by
        have h0 : (bytesOf b).reverse[0]'(by rw [List.length_reverse, bytesOf_length]; omega)
            = (b.get! (b.size - 1)).toNat :=
          bytesOf_reverse_get0 b (by omega)
        simp only [hl, List.getElem_cons_zero] at h0
        exact h0
      have ht1 : 1 ≤ t.length := by omega
      cases ht : t with
      | nil =>
        rw [ht, List.length_nil] at hlen
        exact absurd h1 (by omega)
      | cons e s =>
        have he : e = (b.get! (b.size - 2)).toNat := by
          have h1' : (bytesOf b).reverse[1]'(by rw [List.length_reverse, bytesOf_length]; omega)
              = (b.get! (b.size - 2)).toNat :=
            bytesOf_reverse_get1 b (by omega)
          simp only [hl, List.getElem_cons_succ] at h1'
          simp only [ht, List.getElem_cons_zero] at h1'
          exact h1'
        have hmin : minimalOkBE (d :: e :: s) = false := by
          rw [minimalOkBE, ite_eq_left (show d % 128 = 0 from by
            rw [hd, hb1])]
          exact decide_eq_false (show ¬(e ≥ 128) from by rw [he]; omega)
        have hcond : (true = true) ∧ ¬(minimalOkBE (d :: e :: s) = true) :=
          ⟨rfl, by rw [hmin]; simp⟩
        rw [ite_eq_left hcond]

/-- SCR-084 (positive half, Core's sign-extension exception): the two
vectors Core names in the `script.h:262-268` comment — `0xff00` (+255)
and `0xff80` (−255), little-endian on the wire — are **both minimal** and
BOTH decode. The exception exists because the sign bit of +255's `0xff`
would collide with the sign bit, so the extra byte is required for each
sign. (The row's old text labelled `0xff00` non-minimal; Core says
`+-255, which encode to 0xff00 and 0xff80 respectively`.) -/
@[rule "SCR-084"]
theorem scriptNum_sign_extension_255 :
    decodeScriptNum (bytesFromLE [0xff, 0x00]) true 4 = some 255 ∧
    decodeScriptNum (bytesFromLE [0xff, 0x80]) true 4 = some (-255) := by
  decide

/-- SCR-085: the encoder has no width parameter at all — `getvch`
(`script.h:342-373`) returns `CScriptNum::serialize`, whose only bound is
the `int64_t` value domain. The `minimal` flag is accepted for interface
symmetry and discarded, so the two flags agree definitionally. -/
@[rule "SCR-085"]
theorem encodeScriptNum_ignores_flag (n : ScriptNum) (b₁ b₂ : Bool) :
    encodeScriptNum n b₁ = encodeScriptNum n b₂ := rfl

/-- `encodeSignBE` never shrinks the digit list (it keeps it, or prepends
one sign byte) — so a magnitude that needs more than four base-256 digits
necessarily serializes to more than four wire bytes. -/
theorem encodeSignBE_length_ge (neg : Bool) (l : List Nat) :
    l.length ≤ (encodeSignBE neg l).length := by
  cases l with
  | nil => simp [encodeSignBE]
  | cons d t =>
    by_cases h : d < 128
    · cases neg <;> simp [encodeSignBE, h]
    · cases neg <;> simp [encodeSignBE, h]

/-- A magnitude ≥ `256^4` needs more than four base-256 digits. -/
theorem magBE_length_gt_four (a : Nat) (h : 256 ^ 4 ≤ a) (h10 : a < 256 ^ 10) :
    4 < (magBE a).length := by
  by_cases hle : (magBE a).length ≤ 4
  · exfalso
    have hlt := magOfBE_lt (magBE a) (magBE_digits_lt a)
    have hval := magOfBE_magBE a h10
    rw [hval] at hlt
    have hpow : 256 ^ (magBE a).length ≤ 256 ^ 4 :=
      Nat.pow_le_pow_right (by omega) hle
    have : a < 256 ^ 4 := Nat.lt_of_lt_of_le hlt hpow
    omega
  · omega

/-- SCR-085: any in-range value with magnitude ≥ `256^4` serializes to
more than four bytes — the encoder emits it; it is only the *next*
`CScriptNum` re-interpretation that refuses it. -/
@[rule "SCR-085"]
theorem encodeScriptNum_size_gt_four (n : ScriptNum)
    (h : 256 ^ 4 ≤ n.natAbs) (h10 : n.natAbs < 256 ^ 10) :
    SCRIPT_NUM_DEFAULT_MAX_SIZE < (encodeScriptNum n false).size := by
  have hlen : 4 < (scriptNumBE n).length :=
    Nat.lt_of_lt_of_le (magBE_length_gt_four n.natAbs h h10)
      (encodeSignBE_length_ge _ _)
  simpa [encodeScriptNum, SCRIPT_NUM_DEFAULT_MAX_SIZE, bytesFromLE_length] using hlen

/-- SCR-085 concrete witness: `2^31` (the first magnitude outside the
4-byte signed range) serializes to 5 bytes and the 4-byte decoder refuses
the result. -/
@[rule "SCR-085"]
theorem encodeScriptNum_five_byte_witness :
    (encodeScriptNum ((2 : Int) ^ 31) false).size = 5 ∧
    decodeScriptNum (encodeScriptNum ((2 : Int) ^ 31) false) true
      SCRIPT_NUM_DEFAULT_MAX_SIZE = none := by
  have hsz : (encodeScriptNum ((2 : Int) ^ 31) false).size = 5 := by decide
  refine ⟨hsz, ?_⟩
  exact scriptNum_four_byte_rule_any _ true (by rw [hsz]; decide)

/-! ## the numeric layer helper laws for consumers (the interpreter and transaction-validation layers) -/

/-- `CastToBool` agrees with the decoded value being nonzero — for every
byte vector, including the negative-zero corner (`0x80` casts false,
SCR-057/083). This is the exact content of Core's comment " Casting a
bool casts to 0/1 " inverse: `CScriptNum::operator bool` and
`CastToBool` coincide off the minimal-encoding corner cases. -/
theorem castToBool_iff_setVchBE (b : ByteArray) :
    castToBool b = true ↔ setVchBE ((bytesOf b).reverse) ≠ 0 :=
  castToBoolList_iff _ (fun m hm => bytesOf_lt b m (List.mem_reverse.mp hm))

/-- Decode value characterization: a successful decode returns exactly
`set_vch` of the (reversed) bytes, and the width/minimal guards passed. -/
theorem decodeScriptNum_value (b : ByteArray) (minimal : Bool) (maxSize : Nat)
    (v : ScriptNum) (h : decodeScriptNum b minimal maxSize = some v) :
    v = setVchBE ((bytesOf b).reverse)
      ∧ (bytesOf b).reverse.length ≤ maxSize
      ∧ (minimal = false ∨ minimalOkBE ((bytesOf b).reverse) = true) := by
  have h2 : decodeBE minimal maxSize (bytesOf b).reverse = some v := h
  unfold decodeBE at h2
  by_cases hw : (bytesOf b).reverse.length > maxSize
  · rw [ite_eq_left hw] at h2
    simp at h2
  · rw [ite_eq_right hw] at h2
    by_cases hm : minimal ∧ ¬ minimalOkBE ((bytesOf b).reverse)
    · rw [ite_eq_left hm] at h2
      simp at h2
    · rw [ite_eq_right hm] at h2
      simp only [Option.some.injEq] at h2
      refine ⟨h2.symm, by omega, ?_⟩
      by_cases hb : minimalOkBE ((bytesOf b).reverse)
      · exact Or.inr hb
      · refine Or.inl ?_
        by_cases hmin : minimal
        · exact absurd ⟨hmin, hb⟩ hm
        · rw [Bool.not_eq_true] at hmin
          exact hmin

/-- Fee sign law (TXV-024): `fee = valueIn − valueOut` is nonnegative
exactly when the outputs do not exceed the inputs (`bad-txns-in-belowout`
guard, tx_verify.cpp:186-193). -/
@[rule "TXV-024"]
theorem feeOf_nonneg_iff (vi vo : Amount) : 0 ≤ feeOf vi vo ↔ vo ≤ vi := by
  show 0 ≤ vi - vo ↔ vo ≤ vi
  exact Int.sub_nonneg

end Bitcoin.Numeric
