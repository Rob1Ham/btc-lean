import Bitcoin.Activation.Flags
import Bitcoin.Numeric.Interface

/-!
# Z19 dark-corner audit — hash-keyed flag carve-outs + MAX_MONEY vs the
4-byte scriptNum decode (W4 suite, 2026-10-16)

NEW file, owned by Z19 alone. Python3 probes:
`build/scratch/build/scratch/scratch/Z19/z19_c1_flags_probe.py` and
`z19_c2_scriptnum_probe.py` (transcriptions of Core `GetBlockScriptFlags`
validation.cpp:2249-2288, `script_flag_exceptions`
kernel/chainparams.cpp:115-118, and `CScriptNum` serialize/decode
script.h:342-373/246-271, vendored @ `cce32b168`). Findings:
`spec/db/findings-w4/Z19.md`.

## Corners audited

* **C1 — exception blocks 170060/692261** (Review-1 report 09; W06 report
  w2-06 §2.2): Core keys the two mainnet script-flag carve-outs by BLOCK
  HASH; a hit REPLACES the base P2SH|WITNESS|TAPROOT set BEFORE the
  buried ORs. Verdict: CAPTURED — `getBlockScriptFlagsP` +
  `mainnetExceptionMap` + `exception_replaces_base` (BLK-084) are
  Core-faithful; this file adds the bit-level pins (0x0 / 0xE15, matching
  the python probe and report w2-06 §5) and the decisive hash-keyed (not
  height-keyed) counterfactuals.
* **C2 — MAX_MONEY-scale values do NOT fit the 4-byte scriptNum decode**
  (W04 warning K5'; report 07 amount.h lineage): `MAX_MONEY = 2.1e15`
  serializes to 7 wire bytes; the default-width `CScriptNum` ctor
  throws "script number overflow" at anything > 4 bytes. Verdict:
  CAPTURED — `vec_max_money_not_scriptnum` (instance) +
  `scriptNum_roundtrip` (the ≤ 2^31−1 if-direction); this file adds the
  MISSING only-if direction as a general theorem
  (`z19_decode_none_beyond_4`): every |n| ≥ 2^31 fails the width-4 decode,
  so the amount layer (`MoneyRange`/`checkedSum`) and the scriptnum layer
  are provably disjoint regimes at MAX_MONEY scale.
-/

namespace Bitcoin.Proofs.Audit.Z19

open Bitcoin.Activation Bitcoin.Numeric Bitcoin.Data

/-! ## C1 — the hash-keyed flag carve-outs (blocks 170060 / 692261) -/

/-- Bit-level pin of the BIP16 exception block: the carve-out REPLACES the
base, no buried deployment is active at 170060, so the UInt32 view is
exactly `SCRIPT_VERIFY_NONE` = 0x0 (python probe case 1; report w2-06 §5
row "170060 | BIP16 exception block | 0x0"). -/
theorem z19_flagBits_bip16_exception :
    flagBits (getBlockScriptFlagsP mainnetParams bip16ExceptionHash
      BIP16_EXCEPTION_HEIGHT) = (0x0 : UInt32) := by decide

/-- Bit-level pin of the taproot exception block: P2SH|WITNESS replace the
base, then all four buried ORs fire (all buried heights < 692261) —
0x1 | 0x4 | 0x10 | 0x200 | 0x400 | 0x800 = 0xE15, TAPROOT (0x20000) OFF
(python probe case 2; report w2-06 §5 row "692261 | 0xE15"). -/
theorem z19_flagBits_taproot_exception :
    flagBits (getBlockScriptFlagsP mainnetParams taprootExceptionHash
      TAPROOT_EXCEPTION_HEIGHT) = (0xE15 : UInt32) := by decide

/-- DECISIVE counterfactual (hash-keyed, not height-keyed): a different
block at the SAME height 692261 keeps the full always-on set including
TAPROOT — the carve-out cannot be triggered by height alone. -/
theorem z19_other_hash_same_height_692261 :
    getBlockScriptFlagsP mainnetParams 1 TAPROOT_EXCEPTION_HEIGHT =
      { p2sh := true, dersig := true, cltv := true, csv := true,
        nullDummy := true, witness := true, taproot := true } := by decide

/-- Bit-level view of the counterfactual: full set 0x20E15 (python probe
case 3). -/
theorem z19_flagBits_other_hash_692261 :
    flagBits (getBlockScriptFlagsP mainnetParams 1
      TAPROOT_EXCEPTION_HEIGHT) = (0x20E15 : UInt32) := by decide

/-- Companion counterfactual at the BIP16 height: another block at
170060 gets plain P2SH|WITNESS|TAPROOT (0x20801) — python probe case 4. -/
theorem z19_flagBits_other_hash_170060 :
    flagBits (getBlockScriptFlagsP mainnetParams 1
      BIP16_EXCEPTION_HEIGHT) = (0x20801 : UInt32) := by decide

/-- REPLACE-then-OR is load-bearing in the other direction too: the BIP16
exception HASH at a modern height still gets the buried flags OR-ed back
in — 0x614 = DERSIG|NULLDUMMY|CLTV|CSV (python probe case 5). The
carve-out only ever zeroes the three always-on bits. -/
theorem z19_flagBits_bip16_hash_modern_height :
    flagBits (getBlockScriptFlagsP mainnetParams bip16ExceptionHash
      900000) = (0x614 : UInt32) := by decide

/-! ## C2 — MAX_MONEY-scale values vs the 4-byte scriptNum decode -/

/-! ### Machinery: encode length grows with the value -/

theorem z19_encodeSignBE_length_cons_lt (neg : Bool) (d : Nat) (t : List Nat)
    (hlt : d < 128) : (encodeSignBE neg (d :: t)).length = t.length + 1 := by
  cases neg
  · have hout : encodeSignBE false (d :: t) = d :: t := by simp [encodeSignBE, hlt]
    rw [hout]; rfl
  · have hout : encodeSignBE true (d :: t) = (d + 128) :: t := by simp [encodeSignBE, hlt]
    rw [hout]; rfl

theorem z19_encodeSignBE_length_cons_ge (neg : Bool) (d : Nat) (t : List Nat)
    (hlt : ¬ d < 128) : (encodeSignBE neg (d :: t)).length = t.length + 2 := by
  cases neg
  · have hout : encodeSignBE false (d :: t) = (0 : Nat) :: d :: t := by
      simp [encodeSignBE, hlt]
    rw [hout]; rfl
  · have hout : encodeSignBE true (d :: t) = (128 : Nat) :: d :: t := by
      simp [encodeSignBE, hlt]
    rw [hout]; rfl

/-- Lower bound dual to the tree's `magBEAux_length_le`: a value ≥ 256^k
has strictly more than k magnitude digits. -/
theorem z19_magBEAux_length_ge : ∀ (f k n : Nat), 256 ^ k ≤ n → k < f →
    k < (magBEAux f n).length := by
  intro f
  induction f with
  | zero => intro k n _ hk; exact absurd hk (Nat.not_lt_zero k)
  | succ f ih =>
    intro k n hn hk
    have h1 : 1 ≤ 256 ^ k := Nat.one_le_pow _ _ (by omega)
    have hn0 : n ≠ 0 := by
      intro h0; subst h0; omega
    rw [magBEAux, ite_eq_right hn0, List.length_append, List.length_singleton]
    rcases k with _ | j
    · omega
    · have hdiv : 256 ^ j ≤ n / 256 := by
        refine (Nat.le_div_iff_mul_le (k := 256) (by omega)).mpr ?_
        calc (256 ^ j) * 256 = 256 ^ (j + 1) := (Nat.pow_succ 256 j).symm
          _ ≤ n := hn
      have hjf : j < f := by omega
      have hih := ih j (n / 256) hdiv hjf
      omega

/-- **The missing only-if direction** (audit delta over W04): a value of
magnitude ≥ 2^31 needs ≥ 5 encoded bytes, so the canonical encoder output
cannot pass the width-4 gate. W04 pinned `scriptNumBE_length_le4` (the
 converse) and the single instance `vec_max_money_not_scriptnum`; this
generalizes both to the full half-line. -/
theorem z19_scriptNumBE_length_ge5 {n : Int} (h : 2 ^ 31 ≤ n.natAbs)
    (h10 : n.natAbs < 256 ^ 10) : 5 ≤ (scriptNumBE n).length := by
  have hpos : 0 < n.natAbs := by omega
  obtain ⟨d, t, hdt, hd0⟩ := magBEAux_exists_head 10 n.natAbs hpos h10
  have hdt2 : magBE n.natAbs = d :: t := hdt
  show 5 ≤ (encodeSignBE (decide (n < 0)) (magBE n.natAbs)).length
  have hdig : ∀ e ∈ (d :: t : List Nat), e < 256 := by
    rw [← hdt2]; exact magBE_digits_lt n.natAbs
  have hval : d * 256 ^ t.length + magOfBE t = n.natAbs := by
    rw [← magOfBE_magBE n.natAbs h10, hdt2]; rfl
  have hmt : magOfBE t < 256 ^ t.length :=
    magOfBE_lt t (fun e he => hdig e (List.mem_cons_of_mem _ he))
  by_cases hlt : d < 128
  · rw [hdt2, z19_encodeSignBE_length_cons_lt _ d t hlt]
    by_cases h4 : 4 ≤ t.length
    · omega
    · exfalso
      -- t.length ≤ 3 and the top digit is sign-bit-free: value < 128·256^t.length ≤ 2^31
      have hd128 : d ≤ 127 := by omega
      have hm : magOfBE t ≤ 256 ^ t.length - 1 := by omega
      have hstep : d * 256 ^ t.length + magOfBE t
          ≤ 127 * 256 ^ t.length + (256 ^ t.length - 1) :=
        Nat.add_le_add (Nat.mul_le_mul hd128 (Nat.le_refl _)) hm
      have hcoll : 127 * 256 ^ t.length + (256 ^ t.length - 1)
          = 128 * 256 ^ t.length - 1 := by omega
      have hA : 1 ≤ 256 ^ t.length := Nat.one_le_pow t.length 256 (by omega)
      have hup : n.natAbs < 128 * 256 ^ t.length := by
        calc n.natAbs = d * 256 ^ t.length + magOfBE t := hval.symm
          _ ≤ 127 * 256 ^ t.length + (256 ^ t.length - 1) := hstep
          _ = 128 * 256 ^ t.length - 1 := hcoll
          _ < 128 * 256 ^ t.length := by omega
      have hP2 : 128 * 256 ^ t.length ≤ 128 * (256 ^ 3 : Nat) :=
        Nat.mul_le_mul (Nat.le_refl 128)
          (Nat.pow_le_pow_right (by omega) (by omega))
      have h32 : (2 ^ 31 : Nat) = 128 * (256 ^ 3 : Nat) := by decide
      omega
  · rw [hdt2, z19_encodeSignBE_length_cons_ge _ d t hlt]
    by_cases h3 : 3 ≤ t.length
    · omega
    · exfalso
      -- t.length ≤ 2: value < 256^(t.length+1) ≤ 256^3 < 2^31
      have h1 : magOfBE (d :: t) < 256 ^ (t.length + 1) := magOfBE_lt _ hdig
      rw [← hdt2, magOfBE_magBE n.natAbs h10] at h1
      have hp1 : 256 ^ (t.length + 1) ≤ (256 ^ 3 : Nat) :=
        Nat.pow_le_pow_right (by omega) (by omega)
      have h32 : (256 ^ 3 : Nat) < 2 ^ 31 := by decide
      omega

/-- General decode failure: every |n| ≥ 2^31 — hence every MAX_MONEY-scale
amount — fails the default 4-byte `CScriptNum` decode (Core: "script
number overflow", script.h:250-252). -/
theorem z19_decode_none_beyond_4 (n : Int) (minimal : Bool)
    (h : 2 ^ 31 ≤ n.natAbs) (h10 : n.natAbs < 256 ^ 10) :
    decodeScriptNum (encodeScriptNum n minimal) minimal 4 = none := by
  show decodeBE minimal 4
      (bytesOf (bytesFromLE (scriptNumBE n).reverse)).reverse = none
  rw [bytesOf_bytesFromLE ((scriptNumBE n).reverse)
      (fun d hd => scriptNumBE_digits_lt n d (List.mem_reverse.mp hd)),
    List.reverse_reverse]
  rw [decodeBE, ite_eq_left (show (scriptNumBE n).length > 4 from by
    have h5 := z19_scriptNumBE_length_ge5 h h10; omega)]

/-! ### Decisive instances (python probe `z19_c2_scriptnum_probe.py`) -/

/-- The boundary: 2^31 is the FIRST value the width-4 decode refuses
(its canonical encoding `00 00 00 80 00` is 5 bytes — probe case 4). -/
theorem z19_int32_boundary_not_scriptnum :
    decodeScriptNum (encodeScriptNum 2147483648 true) true 4 = none := by
  exact z19_decode_none_beyond_4 2147483648 true (by decide) (by decide)

/-- And 2^31 − 1, one below the boundary, still roundtrips at width 4
(probe case 3) — the two instances bracket the boundary exactly. -/
theorem z19_int32_max_roundtrips :
    decodeScriptNum (encodeScriptNum 2147483647 true) true 4 =
      some 2147483647 := by decide

/-- MAX_MONEY itself: the amount layer's inclusive bound is REFUSED by the
scriptnum layer at default width (probe case 1; wire bytes
`00 40 07 5a f0 75 07`, 7 bytes > 4). -/
theorem z19_max_money_not_scriptnum :
    decodeScriptNum (encodeScriptNum MAX_MONEY true) true 4 = none := by
  exact z19_decode_none_beyond_4 MAX_MONEY true (by decide) (by decide)

/-- The exact wire bytes of MAX_MONEY's canonical encoding, pinned against
the python probe (`serialize(2100000000000000) = 0040075af07507`). -/
theorem z19_max_money_wire :
    bytesOf (encodeScriptNum MAX_MONEY true) =
      [0x00, 0x40, 0x07, 0x5a, 0xf0, 0x75, 0x07] := by decide

/-- Any amount in `[MAX_MONEY, 256^10)` fails the width-4 decode: the
value-accumulation regime and the script-integer regime are disjoint
(W04's K5′ warning, now a theorem). -/
theorem z19_amount_scale_not_scriptnum (n : Amount) (hlo : MAX_MONEY ≤ n)
    (hhi : n < (256 ^ 10 : Amount)) :
    decodeScriptNum (encodeScriptNum n true) true 4 = none := by
  have hnn : 0 ≤ n := Int.le_trans (by decide : (0 : Amount) ≤ MAX_MONEY) hlo
  have h2 : (2 ^ 31 : Amount) ≤ n := Int.le_trans (by decide) hlo
  refine z19_decode_none_beyond_4 n true ?_ ?_
  · have hkey : (2 ^ 31 : Int) ≤ (n.natAbs : Int) := by
      rw [Int.natAbs_of_nonneg hnn]; exact h2
    exact Int.ofNat_le.mp hkey
  · have hkey : (n.natAbs : Int) < (256 ^ 10 : Int) := by
      rw [Int.natAbs_of_nonneg hnn]; exact hhi
    exact Int.ofNat_lt.mp hkey

/-- The two-layer divergence in one statement: `MoneyRange` ACCEPTS
MAX_MONEY (inclusive bound, amount.h:27) while the width-4 decode REFUSES
it — value sums must ride `checkedSum`/`MoneyRange`, never the scriptnum
layer (probe's two-layer check). -/
theorem z19_money_range_but_not_scriptnum :
    MoneyRange MAX_MONEY = true ∧
    decodeScriptNum (encodeScriptNum MAX_MONEY true) true 4 = none := by
  refine ⟨?_, z19_max_money_not_scriptnum⟩
  unfold MoneyRange MAX_MONEY COIN
  decide

end Bitcoin.Proofs.Audit.Z19
