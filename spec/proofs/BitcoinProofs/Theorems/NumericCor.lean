import Bitcoin.Numeric.Interface
import Bitcoin.DataLaws.Interface

/-!
# BitcoinProofs.Theorems.NumericCor

W15 correctness theorems over the frozen numeric layer
(`Bitcoin.Numeric`, W04) and the finality constants (`Bitcoin.DataLaws`,
W03). Zero-dependency on mathlib: plain Lean + the core library only.

Portfolio rows carried here:

* **THM-008** — `decodeScriptNum_int32_range`: a CScriptNum decoded with
  the default 4-byte width limit is always an int32
  (interpreter.cpp:429-451; `CScriptNum` is int64 but the 4-byte carry
  bound makes the value fit 31 magnitude bits + sign). Support lemma
  `setVchBE_int32_bound` does the digit arithmetic.
* **THM-010** — `locktime_partition`: every `nLockTime` is *exactly one*
  of the two comparison domains (height below `LOCKTIME_THRESHOLD`,
  time at-or-above; script/script.h:48, tx_verify.cpp:35-37).
* Corner laws pinning `MAX_MONEY`, `MoneyRange` at the boundary vectors
  (CVE-2010-5137 family) and `CastToBool` at the negative-zero corner
  (SCR-057/SCR-083, interpreter.cpp:46-59).

All proofs use induction / rewriting; no `decide` through recursive
definitions (W14 finding).
-/

namespace BitcoinProofs.Theorems.NumericCor

open Bitcoin.Numeric Bitcoin.Data Bitcoin.DataLaws

/-! ## Small Int-transport helpers (omega is linear-only) -/

private theorem intLo : ∀ M : Nat, (-2147483648 : Int) ≤ (M : Int) := by intro M; omega

private theorem intHi : ∀ M : Nat, M ≤ 2147483647 → (M : Int) ≤ 2147483647 := by
  intro M h; omega

private theorem intNeg : ∀ M : Nat, M ≤ 2147483647 →
    (-2147483648 : Int) ≤ -((M : Int)) ∧ -((M : Int)) ≤ 2147483647 := by
  intro M h
  constructor <;> (have h0 : (0 : Int) ≤ (M : Int) := by omega) <;> omega

/-! ## `MAX_MONEY` and `MoneyRange` at the boundary vectors -/

/-- THM-005 companion (decimal tier): `MAX_MONEY` is exactly
21,000,000 · 10^8 = 2,100,000,000,000,000 sats (amount.h:26). -/
theorem MAX_MONEY_exact : MAX_MONEY = 2100000000000000 := by rfl

/-- `MoneyRange` at the four boundary vectors: `0` and `MAX_MONEY` itself
are in range (amount.h:27 uses `≤`), while `MAX_MONEY + 1` and a negative
amount are out — the exact CVE-2010-5137 boundary. -/
theorem moneyRange_boundary_vectors :
    MoneyRange 0 = true
    ∧ MoneyRange MAX_MONEY = true
    ∧ MoneyRange (MAX_MONEY + 1) = false
    ∧ MoneyRange (-1) = false := by
  refine ⟨?_, ?_, ?_, ?_⟩ <;> decide

/-! ## THM-008: the 4-byte ScriptNum width bound -/

/-- Support lemma for THM-008: a big-endian digit vector of at most 4
bytes (each `< 256`) decodes to a value with at most 31 magnitude bits,
i.e. an int32 magnitude. `set_vch` (script.h:376-391) keeps the sign bit
in the most-significant byte, so `d ≥ 128` contributes `d - 128 ≤ 127`
multiples of `256^len`; with `len ≤ 3` the magnitude stays `< 2^31`. -/
theorem setVchBE_int32_bound (l : List Nat) (hlen : l.length ≤ 4)
    (hdigits : ∀ d ∈ l, d < 256) :
    (-2147483648 : Int) ≤ setVchBE l ∧ setVchBE l ≤ 2147483647 := by
  match l with
  | [] => exact ⟨by simp [setVchBE], by simp [setVchBE]⟩
  | d :: t =>
    have hd : d < 256 := hdigits d List.mem_cons_self
    have hmem : ∀ e ∈ t, e < 256 := fun e he => hdigits e (List.mem_cons_of_mem _ he)
    have hmag : magOfBE t < 256 ^ t.length := magOfBE_lt t hmem
    have hlen3 : t.length ≤ 3 := by
      have h : (d :: t).length = t.length + 1 := rfl
      omega
    have hpow : 256 ^ t.length ≤ 16777216 := by
      have h : 256 ^ t.length ≤ 256 ^ 3 := Nat.pow_le_pow_right (by omega) hlen3
      have p3 : (256 : Nat) ^ 3 = 16777216 := by decide
      rw [p3] at h; exact h
    -- linear bridge: `x * p` with bounded factors (omega is nonlinear)
    have key : ∀ (p m x : Nat), p ≤ 16777216 → m < p → x ≤ 127 →
        x * p + m ≤ 2147483647 := by
      intro p m x hp hm hx
      have h1 : x * p ≤ 127 * p := Nat.mul_le_mul_right p hx
      have h2 : 127 * p ≤ 127 * 16777216 := Nat.mul_le_mul_left 127 hp
      have h3 : 127 * 16777216 = 2130706432 := by decide
      have h4 : 2130706432 + 16777215 = 2147483647 := by decide
      have h5 : 16777216 - 1 = 16777215 := by decide
      omega
    rcases Nat.lt_or_ge d 128 with hlt | hge
    · have heq : setVchBE (d :: t) = ((d * 256 ^ t.length + magOfBE t : Nat) : Int) := by
        rw [setVchBE]; exact ite_eq_left hlt
      rw [heq]
      exact ⟨intLo _, intHi _ (key _ _ _ hpow hmag (Nat.le_of_lt_succ hlt))⟩
    · have hge' : ¬ d < 128 := by omega
      have heq : setVchBE (d :: t) = -((((d - 128) * 256 ^ t.length + magOfBE t : Nat)) : Int) := by
        rw [setVchBE]; exact ite_eq_right hge'
      rw [heq]
      have hx : d - 128 ≤ 127 := by omega
      exact intNeg _ (key _ _ _ hpow hmag hx)

/-- **THM-008** — a `CScriptNum` decoded with the default 4-byte width
limit is an int32 (interpreter.cpp:429-451: `nMaxNumSize = 4` bounds the
serialization, so the decoded int64 value cannot overflow int32 range —
this is why `CScriptNum` arithmetic on decoded values is overflow-free
for the CLTV/CSV/addition consensus paths). -/
theorem decodeScriptNum_int32_range (b : ByteArray) (minimal : Bool) (v : ScriptNum)
    (h : decodeScriptNum b minimal 4 = some v) :
    -2147483648 ≤ v ∧ v ≤ 2147483647 := by
  have hspec : (bytesOf b).reverse.length ≤ 4 ∧ v = setVchBE ((bytesOf b).reverse) := by
    rw [decodeScriptNum, decodeBE] at h
    split at h
    · simp at h
    · split at h
      · simp at h
      · rename_i h1 h2
        exact ⟨by omega, (Option.some.inj h).symm⟩
  have hlen := hspec.1
  have hdig : ∀ d ∈ (bytesOf b).reverse, d < 256 := fun d hd =>
    bytesOf_lt b d (List.mem_reverse.mp hd)
  rw [hspec.2]
  exact setVchBE_int32_bound _ hlen hdig

/-! ## THM-010: the locktime threshold partition -/

/-- Bridge: `lt < 500000000` (UInt32) iff the same comparison on `.toNat`
(`UInt32.lt_ofNat_iff`, `500000000 < 2^32`). -/
private theorem locktime_lt_iff (lt : UInt32) :
    lt < (500000000 : UInt32) ↔ lt.toNat < 500000000 :=
  UInt32.lt_ofNat_iff (n := lt) (by decide : 500000000 < UInt32.size)

/-- Bridge: `500000000 ≤ lt` (UInt32) iff the same comparison on `.toNat`. -/
private theorem locktime_le_iff (lt : UInt32) :
    (500000000 : UInt32) ≤ lt ↔ 500000000 ≤ lt.toNat :=
  UInt32.ofNat_le_iff (n := lt) (by decide : 500000000 < UInt32.size)

/-- **THM-010** — every `nLockTime` falls in *exactly one* comparison
domain: strictly below `LOCKTIME_THRESHOLD = 500,000,000` the field is
compared against block height (INV-012), at-or-above against the BIP113
median-time-past (INV-013). The `Bool` domain predicate
`locktimeIsTimeDomain` (script.h:48) decides the split exactly. -/
theorem locktime_partition (lt : UInt32) :
    (lt < (500000000 : UInt32) ∧ locktimeIsTimeDomain lt = false) ∨
    ((500000000 : UInt32) ≤ lt ∧ locktimeIsTimeDomain lt = true) := by
  rcases Nat.lt_or_ge lt.toNat 500000000 with h | h
  · refine Or.inl ⟨locktime_lt_iff lt |>.mpr h, ?_⟩
    simp [locktimeIsTimeDomain, locktime_lt_iff lt, h]
  · refine Or.inr ⟨locktime_le_iff lt |>.mpr h, ?_⟩
    simp [locktimeIsTimeDomain, locktime_le_iff lt, h]

/-- The partition is exclusive: no locktime is in both domains
(the threshold comparison is trichotomous). -/
theorem locktime_domain_exclusive (lt : UInt32)
    (hlo : lt < (500000000 : UInt32)) (hhi : (500000000 : UInt32) ≤ lt) : False := by
  have h1 : lt.toNat < 500000000 := locktime_lt_iff lt |>.mp hlo
  have h2 : 500000000 ≤ lt.toNat := locktime_le_iff lt |>.mp hhi
  omega

/-! ## CastToBool at the corner vectors (SCR-057 / SCR-083) -/

/-- `CastToBool` (interpreter.cpp:46-59) at the consensus corner vectors:
all-zero vectors and the lone `0x80` sign byte (negative zero) cast to
`false`; a vector with any nonzero payload byte casts to `true`. Pinned
through the real `ByteArray` entry point (`bytesFromLE`), not just the
digit-list model. -/
theorem castToBool_corner_vectors :
    castToBool (bytesFromLE []) = false
    ∧ castToBool (bytesFromLE [0]) = false
    ∧ castToBool (bytesFromLE [128]) = false
    ∧ castToBool (bytesFromLE [0, 0]) = false
    ∧ castToBool (bytesFromLE [1]) = true
    ∧ castToBool (bytesFromLE [0, 1]) = true
    ∧ castToBool (bytesFromLE [255, 1]) = true := by
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_⟩ <;>
    simp [castToBool, bytesOf_bytesFromLE, castToBoolList]

/-! ## Axiom-footprint pins (L3): drift on any of these fails the build -/

/-- info: 'BitcoinProofs.Theorems.NumericCor.MAX_MONEY_exact' does not depend on any axioms -/
#guard_msgs in #print axioms MAX_MONEY_exact

/-- info: 'BitcoinProofs.Theorems.NumericCor.moneyRange_boundary_vectors' does not depend on any axioms -/
#guard_msgs in #print axioms moneyRange_boundary_vectors

/-- info: 'BitcoinProofs.Theorems.NumericCor.setVchBE_int32_bound' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms setVchBE_int32_bound

/-- info: 'BitcoinProofs.Theorems.NumericCor.decodeScriptNum_int32_range' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms decodeScriptNum_int32_range

/-- info: 'BitcoinProofs.Theorems.NumericCor.locktime_partition' depends on axioms: [propext] -/
#guard_msgs in #print axioms locktime_partition

/-- info: 'BitcoinProofs.Theorems.NumericCor.locktime_domain_exclusive' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms locktime_domain_exclusive

/-- info: 'BitcoinProofs.Theorems.NumericCor.castToBool_corner_vectors' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms castToBool_corner_vectors

end BitcoinProofs.Theorems.NumericCor
