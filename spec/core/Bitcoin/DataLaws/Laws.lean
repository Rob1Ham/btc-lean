import Bitcoin.Data.Basic
import Bitcoin.Data.Tx
import Bitcoin.Crypto.Seam.Interface
import Bitcoin.Numeric.Interface
import Bitcoin.Consensus.TxCheck

/-!
# Bitcoin.DataLaws — type-level laws

Laws over the frozen data types, proved sorry-free here (the only `sorry`
in the surface is the -owned CScriptNum contract, tagged and
routed). Companion of the frozen `Bitcoin.DataLaws.Interface`, which
imports this file and fills its four `opaque` stubs.

Ground truth (Bitcoin Core @ `cce32b1682d86076ee71c10f9788c48d44458a263`):

* weight model        — `consensus/validation.h:135-142` (`GetTransactionWeight`),
                        `consensus/consensus.h:21` (`WITNESS_SCALE_FACTOR = 4`)
* BIP68 field layout  — `primitives/transaction.h:77-115` (`SEQUENCE_*` constants),
                        `consensus/tx_verify.cpp:45-101` (`CalculateSequenceLocks`)
* finality domain     — `script/script.h:48` (`LOCKTIME_THRESHOLD = 500_000_000`)
* outpoint nullness   — `primitives/transaction.h:29-56` (`COutPoint::IsNull`,
                        32-zero-byte hash — the prototype-audited empty-vs-32-byte fix)
* txid/wtxid          — `primitives/transaction.cpp:81-96` (`ComputeHash`,
                        `ComputeWitnessHash`: **returns txid verbatim when
                        `!HasWitness()`**)

Rule-DB rows touched (see `spec/db/rules.yaml`): SWT-018, TXV-017..019,
INV-011..014, TXV-027..030, TXV-034..038; the CScriptNum contract
statement is supplied by the numeric layer.
-/

namespace Bitcoin.DataLaws

open Bitcoin.Data

/-! ## Field constants (`primitives/transaction.h`, `script/script.h`,
`consensus/consensus.h` — values pinned against Core @ cce32b168) -/

/-- `LOCKTIME_THRESHOLD` (`script/script.h:48`): nLockTime values below it
are block heights, at-or-above are Unix timestamps. -/
def LOCKTIME_THRESHOLD : UInt32 := 500000000

/-- `CTxIn::SEQUENCE_FINAL` (`primitives/transaction.h:77`). -/
def SEQUENCE_FINAL : UInt32 := 0xFFFFFFFF

/-- `CTxIn::MAX_SEQUENCE_NONFINAL` (`primitives/transaction.h:83`). -/
def MAX_SEQUENCE_NONFINAL : UInt32 := 0xFFFFFFFE

/-- `CTxIn::SEQUENCE_LOCKTIME_DISABLE_FLAG` (`primitives/transaction.h:94`,
`1 << 31`): BIP68 ignore bit. -/
def SEQUENCE_LOCKTIME_DISABLE_FLAG : UInt32 := 0x80000000

/-- `CTxIn::SEQUENCE_LOCKTIME_TYPE_FLAG` (`primitives/transaction.h:100`,
`1 << 22`): BIP68 512-second-granularity bit. -/
def SEQUENCE_LOCKTIME_TYPE_FLAG : UInt32 := 0x00400000

/-- `CTxIn::SEQUENCE_LOCKTIME_MASK` (`primitives/transaction.h:105`,
`0x0000ffff`): BIP68 relative-locktime payload. -/
def SEQUENCE_LOCKTIME_MASK : UInt32 := 0x0000ffff

/-- `CTxIn::SEQUENCE_LOCKTIME_GRANULARITY` (`primitives/transaction.h:115`):
time-based relative locktimes count in units of 2^9 = 512 seconds. -/
def SEQUENCE_LOCKTIME_GRANULARITY : Nat := 9

/-- `WITNESS_SCALE_FACTOR = 4` (`consensus/consensus.h:21`); BIP141 weight
unit: one legacy byte of weight per byte of serialized size. -/
@[rule "SWT-018"]
def WITNESS_SCALE_FACTOR : Nat := 4

/-- `LOCKTIME_VERIFY_SEQUENCE = 1 << 0` (`consensus/consensus.h`): the
`CalculateSequenceLocks` flag; `ScriptFlags.checkSequenceVerify`
supplies the value in block context. -/
def LOCKTIME_VERIFY_SEQUENCE : Nat := 1

/-- Non-divergence guard: the laws-layer constant equals the prototype bootstrap
copy in `Bitcoin.Consensus.TxCheck` (both pin consensus.h:21). -/
theorem witnessScaleFactor_eq_consensus :
    WITNESS_SCALE_FACTOR = Bitcoin.Consensus.WITNESS_SCALE_FACTOR := rfl

theorem sequenceFinal_value : SEQUENCE_FINAL = 0xFFFFFFFF := rfl

theorem maxSequenceNonfinal_succ : MAX_SEQUENCE_NONFINAL + 1 = SEQUENCE_FINAL := rfl

theorem disableFlag_value : SEQUENCE_LOCKTIME_DISABLE_FLAG.toNat = 2 ^ 31 := rfl

theorem typeFlag_value : SEQUENCE_LOCKTIME_TYPE_FLAG.toNat = 2 ^ 22 := rfl

theorem mask_value : SEQUENCE_LOCKTIME_MASK.toNat = 2 ^ 16 - 1 := rfl

/-- The three BIP68 bit fields are disjoint (layout precondition for
TXV-035/036: disable ⊃ type ⊃ payload). -/
theorem bip68_flags_disjoint :
    (SEQUENCE_LOCKTIME_TYPE_FLAG &&& SEQUENCE_LOCKTIME_MASK) = 0 ∧
    (SEQUENCE_LOCKTIME_DISABLE_FLAG &&&
      (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) = 0 := by
  decide

/-! ## Bit-level helpers (Nat side) -/

private theorem nat_land_single_bit (x i : Nat) : x &&& 2 ^ i = 0 ↔ x.testBit i = false := by
  constructor
  · intro h
    have h' := congrFun (congrArg Nat.testBit h) i
    rw [Nat.testBit_and, Nat.testBit_two_pow] at h'
    simpa using h'
  · intro h
    apply Nat.eq_of_testBit_eq
    intro j
    by_cases hj : i = j
    · subst hj
      rw [Nat.testBit_and, Nat.testBit_two_pow, h]
      simp
    · rw [Nat.testBit_and, Nat.testBit_two_pow, decide_eq_false_iff_not.mpr hj]
      simp

/-- Bit 31 of a 32-bit word is exactly the `≥ 2^31` threshold (the BIP68
disable-flag reading; tx_verify.cpp:71-75). -/
theorem testBit31_iff (x : Nat) (hx : x < 4294967296) :
    x.testBit 31 = false ↔ x < 2147483648 := by
  constructor
  · intro h
    rcases Nat.lt_or_ge x 2147483648 with hlt | hge
    · exact hlt
    · exfalso
      have hkeq : x = 2147483648 + (x - 2147483648) := by omega
      have hlt' : x - 2147483648 < 2147483648 := by omega
      have h0 : (x - 2147483648).testBit 31 = false := Nat.testBit_lt_two_pow hlt'
      have h2 : (2147483648 + (x - 2147483648)).testBit 31 = !((x - 2147483648).testBit 31) :=
        Nat.testBit_two_pow_add_eq _ 31
      rw [hkeq, h2, h0] at h
      simp at h
  · intro h
    refine Nat.testBit_lt_two_pow (i := 31) ?_
    rw [show (2 : Nat) ^ 31 = 2147483648 from by decide]
    exact h

/-! ## OutPoint / null-prevout laws (TXV-009/010, INV-008/009/010) -/

/-- `zeroBytes (n+1)` appends one zero byte to `zeroBytes n` (structural
form — keeps `decide` reduction healthy per the prototype kernel-reduction rules). -/
private theorem zeroBytes_succ (n : Nat) : zeroBytes (n + 1) = (zeroBytes n).push 0 := by
  simp only [zeroBytes, List.range_succ, List.foldl_append]
  rfl

/-- `ByteArray.get!` in terms of the `GetElem!` notation (the bridge the
byte-level laws below are stated through). -/
private theorem get!_eq_getElem! (b : ByteArray) (i : Nat) : b.get! i = b[i]! := by
  by_cases h : i < b.size
  · rw [getElem!_pos b i h]
    show b.data[i]! = b[i]
    have hb : i < b.data.size := by simpa using h
    rw [getElem!_pos b.data i hb]
    exact (ByteArray.getElem_eq_getElem_data (a := b) (i := i) (h := h)).symm
  · rw [getElem!_neg b i h]
    show b.data[i]! = default
    exact getElem!_neg b.data i h

theorem zeroBytes_size (n : Nat) : (zeroBytes n).size = n := by
  induction n with
  | zero => rfl
  | succ n ih => rw [zeroBytes_succ, ByteArray.size_push, ih]

/-- Every byte of `zeroBytes n` is 0 (out-of-range `get!` also defaults to 0,
so this holds for every index — the range check in `OutPoint.isNull` is
what does the bounding work). -/
theorem zeroBytes_get_zero (n i : Nat) : (zeroBytes n).get! i == 0 := by
  induction n with
  | zero => rfl
  | succ n ih =>
      rw [zeroBytes_succ, get!_eq_getElem!, ByteArray.getElem!_push]
      split
      · rfl
      · rw [← get!_eq_getElem!]; exact ih

/-- The canonical null outpoint `OutPoint.null` satisfies `IsNull`
(primitives/transaction.h:43). -/
theorem null_outPoint_isNull : OutPoint.null.isNull = true := by
  decide

/-- REGRESSION (the prototype audit, empty-vs-32-byte null prevout): `IsNull` demands
32 ZERO bytes — an empty hash must NOT pass even with `n = NULL_INDEX`.
Core: `COutPoint::IsNull() = hash.IsNull() && n == NULL_INDEX` with
`uint256::IsNull` = all 32 bytes zero. -/
theorem isNull_rejects_empty_hash (n : UInt32) :
    OutPoint.isNull ⟨ByteArray.empty, n⟩ = false := by
  simp [OutPoint.isNull]

/-- Full spec of `COutPoint::IsNull` as a proposition. -/
theorem isNull_spec (o : OutPoint) :
    o.isNull = true ↔
      o.n = NULL_INDEX ∧ o.hash.size = 32 ∧ ∀ i < 32, o.hash.get! i == 0 := by
  by_cases hsz : o.hash.size = 32
  · rw [OutPoint.isNull, decide_eq_true_iff, hsz]
    simp [List.all_eq_true, List.mem_range]
  · rw [OutPoint.isNull, decide_eq_true_iff]
    simp [hsz, List.all_eq_true, List.mem_range]

/-- Extensional form: a null prevout is byte-equal (in the `bytesBEq`
sense — the equality actually used by the OutPoint `BEq`) to
`OutPoint.null`. -/
theorem isNull_bytesBEq (o : OutPoint) (h : o.isNull = true) :
    bytesBEq o.hash OutPoint.null.hash = true ∧ o.n = NULL_INDEX := by
  have hnull : OutPoint.null.hash = zeroBytes 32 := rfl
  have hs := (isNull_spec o).mp h
  refine ⟨?_, hs.1⟩
  rw [hnull]
  show decide (o.hash.size = (zeroBytes 32).size ∧
    ((List.range o.hash.size).all fun i => o.hash.get! i == (zeroBytes 32).get! i) = true) = true
  rw [decide_eq_true_iff]
  refine ⟨?_, ?_⟩
  · rw [zeroBytes_size]
    exact hs.2.1
  · rw [List.all_eq_true]
    intro i hi
    have hz : (zeroBytes 32).get! i = 0 := beq_iff_eq.mp (zeroBytes_get_zero 32 i)
    rw [hz]
    have h32 : o.hash.size = 32 := hs.2.1
    have hi' : i < 32 := by have := hi; rw [h32] at this; simpa using this
    exact hs.2.2 i hi'

/-- `CTransaction::IsCoinBase` (`primitives/transaction.h:347`): coinbase
⇔ exactly one input whose prevout is null. There is no "half coinbase"
(07 §g.9): a two-input tx with a null prevout is `bad-txns-prevout-null`
material, not a coinbase. -/
theorem isCoinBase_iff (tx : Tx) :
    tx.isCoinBase = true ↔ ∃ i : TxIn, tx.vin = [i] ∧ i.prevout.isNull = true := by
  cases hv : tx.vin with
  | nil => simp [Tx.isCoinBase, hv]
  | cons i tl =>
    cases tl with
    | nil => simp [Tx.isCoinBase, hv]
    | cons j rest => simp [Tx.isCoinBase, hv]

/-! ## BIP68: the nSequence field algebra (TXV-034..038) -/

/-- The masked relative locktime carried by `nSequence`
(tx_verify.cpp:94/96: `nSequence & SEQUENCE_LOCKTIME_MASK`). -/
@[rule "TXV-037", rule "INV-020"]
def seqRelative (s : UInt32) : Nat := (s &&& SEQUENCE_LOCKTIME_MASK).toNat

/-- tx_verify.cpp:71-75: `nSequence & SEQUENCE_LOCKTIME_DISABLE_FLAG` read
as truthy — disable bit set ⇒ the input contributes no sequence lock. -/
@[rule "TXV-035", rule "INV-018"]
def seqIsDisabled (s : UInt32) : Bool :=
  decide ((s &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) ≠ 0)

/-- tx_verify.cpp:79: `nSequence & SEQUENCE_LOCKTIME_TYPE_FLAG` read as
truthy — type bit set ⇒ 512-second granularity. -/
@[rule "TXV-036", rule "INV-019"]
def seqIsTimeBased (s : UInt32) : Bool :=
  decide ((s &&& SEQUENCE_LOCKTIME_TYPE_FLAG) ≠ 0)

/-- `UInt32` equality reads off `toNat` (bridge for the zero-tests below). -/
private theorem u32_eq_zero_iff_toNat (x : UInt32) : x = 0 ↔ x.toNat = 0 := by
  constructor
  · intro e; rw [e]; rfl
  · intro e
    refine UInt32.toNat_inj.mp ?_
    rw [e]
    rfl

/-- The mask extracts exactly the low 16 bits (transaction.h:105). -/
theorem seqRelative_eq_mod (s : UInt32) : seqRelative s = s.toNat % 65536 := by
  unfold seqRelative
  rw [UInt32.toNat_and, mask_value, Nat.and_two_pow_sub_one_eq_mod,
    show ((2 : Nat) ^ 16 = 65536) from by decide]

theorem seqRelative_bounded (s : UInt32) : seqRelative s < 65536 := by
  rw [seqRelative_eq_mod]; omega

/-- TXV-035: the disable bit is set exactly when the sequence's top bit is
(tx_verify.cpp:71-75; `nSequence & SEQUENCE_LOCKTIME_DISABLE_FLAG`). -/
theorem seqIsDisabled_iff (s : UInt32) :
    seqIsDisabled s = true ↔ 2147483648 ≤ s.toNat := by
  unfold seqIsDisabled
  rw [decide_eq_true_iff, ne_eq, u32_eq_zero_iff_toNat, UInt32.toNat_and,
    disableFlag_value, nat_land_single_bit, testBit31_iff s.toNat s.toNat_lt]
  omega

theorem seqIsDisabled_of_ge (s : UInt32) (h : 2147483648 ≤ s.toNat) :
    seqIsDisabled s = true := (seqIsDisabled_iff s).mpr h

theorem seqNotDisabled_of_lt (s : UInt32) (h : s.toNat < 2147483648) :
    seqIsDisabled s = false := by
  cases hb : seqIsDisabled s with
  | true => have := (seqIsDisabled_iff s).mp hb; omega
  | false => rfl

/-- TXV-036: the type bit is bit 22 (transaction.h:100). -/
theorem seqIsTimeBased_iff (s : UInt32) :
    seqIsTimeBased s = true ↔ s.toNat.testBit 22 = true := by
  unfold seqIsTimeBased
  rw [decide_eq_true_iff, ne_eq, u32_eq_zero_iff_toNat, UInt32.toNat_and,
    typeFlag_value, nat_land_single_bit]
  simp

/-- TXV-034: the BIP68 enable gate (tx_verify.cpp:57):
`tx.version >= 2 && flags & LOCKTIME_VERIFY_SEQUENCE`.

AUDIT NOTE : Core's `CTransaction::version` is `const uint32_t` @
cce32b168, so `>= 2` compares the WIRE value unsigned; the scaffold's
`Tx.version : Int32` is signed. The faithful gate therefore goes through
`Int32.toUInt32` (byte-identical wire value): a tx with wire version
0xFFFFFFFF has BIP68 *enabled* in Core — see the concrete instance below.
(Scaffold infidelity flagged in the type-law notes; the `Int32`
field type itself is the frozen interface's to change via interface-change PR.) -/
@[rule "TXV-034", rule "INV-017"]
def bip68Enabled (version : Int32) (locktimeFlag : Bool) : Bool :=
  decide (2 ≤ version.toUInt32.toNat) && locktimeFlag

theorem bip68Enabled_iff (v : Int32) (f : Bool) :
    bip68Enabled v f = true ↔ 2 ≤ v.toUInt32.toNat ∧ f = true := by
  simp [bip68Enabled]

theorem bip68Enabled_of_wire_version (v : Int32) (f : Bool)
    (h : 2 ≤ v.toUInt32) : bip68Enabled v f = f := by
  have h2 : 2 ≤ v.toUInt32.toNat := by
    have h' := UInt32.le_iff_toNat_le.mp h
    simpa using h'
  simp [bip68Enabled, h2]

theorem bip68Enabled_zero_flag (v : Int32) : bip68Enabled v false = false := by
  simp [bip68Enabled]

/-- SEQUENCE_FINAL carries the disable bit, so `SEQUENCE_FINAL` inputs
contribute no BIP68 lock (transaction.h:80-82 comment; TXV-030/035 join). -/
theorem sequence_final_disables_bip68 : seqIsDisabled SEQUENCE_FINAL = true := by
  decide

/-- The height-domain lockpoint of one input (tx_verify.cpp:96):
`nCoinHeight + (nSequence & MASK) − 1`, in nLockTime's **last-invalid**
semantics (TXV-038; the −1 is the BIP68-first-valid → nLockTime-last-invalid
conversion documented at tx_verify.cpp:82-93). -/
@[rule "TXV-038"]
def seqHeightLock (coinHeight : Nat) (s : UInt32) : Nat :=
  coinHeight + seqRelative s - 1

/-- The height-domain contribution of ONE input to `CalculateSequenceLocks`'
fold, in nLockTime last-invalid form: `none` exactly when the BIP68
disable bit is set (tx_verify.cpp:71-75 sets `nMinHeight = -1` and leaves
the input out of the fold), else the `coinHeight + (seq & 0xffff) − 1`
lockpoint.  `TXV-035`'s consequence — a disable-bit sequence contributes
NO relative lock — is the `none` arm. -/
@[rule "TXV-035"]
def seqHeightLockContribution (coinHeight : Nat) (s : UInt32) : Option Nat :=
  if seqIsDisabled s then none else some (seqHeightLock coinHeight s)

/-- TXV-035: the disable bit is set iff the input contributes no BIP68
height lock (tx_verify.cpp:71-75).  This is the row's "⇒ no relative
lock" half, stated in the lock calculation rather than only as a bit
predicate. -/
@[rule "TXV-035"]
theorem seqIsDisabled_iff_no_relative_lock (coinHeight : Nat) (s : UInt32) :
    seqIsDisabled s = true ↔ seqHeightLockContribution coinHeight s = none := by
  unfold seqHeightLockContribution
  cases seqIsDisabled s <;> simp

/-- TXV-035 (complement): an input without the disable bit DOES contribute
its `coinHeight + masked − 1` lockpoint. -/
@[rule "TXV-035"]
theorem seqHeightLockContribution_of_not_disabled (coinHeight : Nat) (s : UInt32)
    (h : seqIsDisabled s = false) :
    seqHeightLockContribution coinHeight s = some (seqHeightLock coinHeight s) := by
  unfold seqHeightLockContribution
  simp [h]

/-- TXV-037: the height-domain lockpoint `seqHeightLock` is exactly
`coinHeight + (nSequence & 0xffff) − 1` (tx_verify.cpp:96), the `else`
arm of the BIP68 type-flag dispatch. -/
@[rule "TXV-037"]
theorem seqHeightLock_eq_mask (coinHeight : Nat) (s : UInt32) :
    seqIsDisabled s = false → seqIsTimeBased s = false →
    seqHeightLock coinHeight s = coinHeight + (s.toNat &&& 65535) - 1 := by
  intro _ _
  have hmod : seqHeightLock coinHeight s = coinHeight + s.toNat % 65536 - 1 := by
    unfold seqHeightLock
    rw [seqRelative_eq_mod]
  rw [hmod]
  have hmask : s.toNat &&& 65535 = s.toNat % 65536 := by
    rw [show (65535 : Nat) = 2 ^ 16 - 1 from by decide,
      Nat.and_two_pow_sub_one_eq_mod]
  rw [hmask]

/-- TXV-037 (mod form): the same lockpoint with the mask written as the
`% 65536` of the wire value. -/
@[rule "TXV-037"]
theorem seqHeightLock_eq_mod (coinHeight : Nat) (s : UInt32) :
    seqHeightLock coinHeight s = coinHeight + s.toNat % 65536 - 1 := by
  unfold seqHeightLock
  rw [seqRelative_eq_mod]

/-- Height-domain spend admissibility (EvaluateSequenceLocks' `lockPair.first
>= block.nHeight → invalid`, tx_verify.cpp:103-111): valid iff the block
height is at least coin-height + masked sequence (the BIP68 first-valid
reading). -/
def seqHeightOk (coinHeight : Nat) (s : UInt32) (H : Nat) : Bool :=
  decide (H ≥ coinHeight + seqRelative s)

theorem seqHeightOk_iff (coinHeight : Nat) (s : UInt32) (H : Nat) :
    seqHeightOk coinHeight s H = true ↔ coinHeight + seqRelative s ≤ H := by
  simp [seqHeightOk]

theorem seqHeightOk_succ (coinHeight : Nat) (s : UInt32) (H : Nat)
    (h : seqHeightOk coinHeight s H = true) : seqHeightOk coinHeight s (H + 1) = true := by
  rw [seqHeightOk_iff] at h ⊢; omega

/-- Zero relative delay is admissible immediately (masked sequence 0). -/
theorem seqHeightOk_zero_delay (coinHeight : Nat) (s : UInt32) (H : Nat)
    (h0 : seqRelative s = 0) (hH : coinHeight ≤ H) :
    seqHeightOk coinHeight s H = true := by
  rw [seqHeightOk_iff, h0]; omega

/-- TXV-038: the two readings coincide — BIP68's "first valid at
`coinHeight + masked`" is exactly nLockTime's "last invalid at
`coinHeight + masked − 1`", away from the single degenerate corner
`(coinHeight = 0 ∧ masked = 0)` where the `Nat` truncation of the
C++ `int` sentinel `−1` differs (and is immaterial: both readings admit
every height). -/
theorem seqHeightLock_last_invalid (coinHeight : Nat) (s : UInt32) (H : Nat)
    (h : 1 ≤ coinHeight ∨ 1 ≤ seqRelative s) :
    seqHeightOk coinHeight s H = true ↔ seqHeightLock coinHeight s < H := by
  rw [seqHeightOk_iff, seqHeightLock]; omega

/-- Time-domain granularity: 512 = 2^9 seconds per masked unit
(transaction.h:107-115). -/
theorem seqTimeGranularity_pow :
    (512 : Nat) = 2 ^ SEQUENCE_LOCKTIME_GRANULARITY := by decide

/-- Time-domain spend admissibility (tx_verify.cpp:79-94 + 103-111): valid
iff `MTP(block) ≥ MTP(coin-block's parent) + masked·512` — again the
first-valid reading of a `… − 1` last-invalid lockpoint. -/
def seqTimeOk (mtpParent : Nat) (s : UInt32) (mtpBlock : Nat) : Bool :=
  decide (mtpBlock ≥ mtpParent + seqRelative s * 512)

theorem seqTimeOk_iff (mtpParent : Nat) (s : UInt32) (mtpBlock : Nat) :
    seqTimeOk mtpParent s mtpBlock = true ↔
      mtpParent + seqRelative s * 512 ≤ mtpBlock := by
  simp [seqTimeOk]

/-- TXV-038 (time domain): same first-valid ⟺ last-invalid duality. -/
theorem seqTimeLock_last_invalid (mtpParent : Nat) (s : UInt32) (mtpBlock : Nat)
    (h : 1 ≤ mtpParent + seqRelative s * 512) :
    seqTimeOk mtpParent s mtpBlock = true ↔
      mtpParent + seqRelative s * 512 - 1 < mtpBlock := by
  rw [seqTimeOk_iff]; omega

/-! ## The CScriptNum 4-byte contract boundary (SCR numeric family;
coordinate-by-interface — the implementation is in `Bitcoin.Numeric`) -/

/-- Largest value representable in a `w`-byte sign-magnitude CScriptNum
(int64 semantics; `2^(8w−1) − 1`). -/
def scriptNumMaxValue (w : Nat) : Int := 2 ^ (8 * w - 1) - 1

/-- At the default width the CScriptNum range is exactly int32
(`interpreter.cpp:415-451`, `nMaxNumSize = 4`). -/
theorem scriptNum4ByteMaxValue :
    scriptNumMaxValue Bitcoin.Numeric.SCRIPT_NUM_DEFAULT_MAX_SIZE = 2147483647 := by
  decide

/-- CONTRACT (type-level statement of the 4-byte rule; SCR-numeric family).
Whatever byte string decodes to a value under the default width bound is at
most 4 bytes long. The implementation — and this theorem's proof — is in
(`Bitcoin.Numeric.decodeScriptNum`, interpreter.cpp:429-451); the boundary
is stated here so consumers can use it by interface. -/
theorem scriptNum_four_byte_boundary (b : ByteArray)
    (h : Bitcoin.Numeric.decodeScriptNum b true
        Bitcoin.Numeric.SCRIPT_NUM_DEFAULT_MAX_SIZE ≠ none) :
    b.size ≤ Bitcoin.Numeric.SCRIPT_NUM_DEFAULT_MAX_SIZE := by
  -- Discharged (agreed interface): contrapositive of
  -- `Bitcoin.Numeric.scriptNum_four_byte_rule` — a > 4-byte wire string
  -- always decodes to `none` under the default width, so a successful
  -- decode forces `b.size ≤ 4`.
  by_cases hn : b.size > Bitcoin.Numeric.SCRIPT_NUM_DEFAULT_MAX_SIZE
  · exact absurd (Bitcoin.Numeric.scriptNum_four_byte_rule b hn) h
  · exact Nat.not_lt.mp hn

/-! ## Concrete sanity instances (kernel-`decide`d at build time) -/

set_option maxRecDepth 100000

-- BIP68 field algebra on concrete values:
example : seqRelative 0x00400010 = 16 := by decide
example : seqIsTimeBased 0x00400010 = true := by decide
example : seqIsDisabled 0x00400010 = false := by decide
example : seqIsDisabled SEQUENCE_FINAL = true := sequence_final_disables_bip68
example : seqHeightOk 100 0x00000003 103 = true := by decide
example : seqHeightOk 100 0x00000003 102 = false := by decide
-- The masked payload of SEQUENCE_FINAL is 0xffff, so the *raw* masked-lock
-- predicate still bites at height 100; it is `seqIsDisabled` that removes
-- SEQUENCE_FINAL inputs from BIP68 consideration (lockpoint fold).
example : seqHeightOk 100 SEQUENCE_FINAL 100 = false := by decide
-- The unsigned-BIP68-gate audit instance: wire version 0xFFFFFFFF.
example : bip68Enabled (-1 : Int32) true = true := by decide
example : bip68Enabled 1 true = false := by decide
example : bip68Enabled 2 true = true := by decide

-- Null-prevout regression set (the prototype audit):
example : OutPoint.isNull ⟨ByteArray.empty, NULL_INDEX⟩ = false :=
  isNull_rejects_empty_hash NULL_INDEX
example : OutPoint.null.isNull = true := null_outPoint_isNull

-- Axiom transcripts of the headline laws (in-module half of the
-- axiom-manifest gate). The single `sorryAx` is the numeric layer's
-- CScriptNum contract statement, tagged SORRY above.
/-- info: 'Bitcoin.DataLaws.isNull_spec' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms isNull_spec
/-- info: 'Bitcoin.DataLaws.seqRelative_eq_mod' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms seqRelative_eq_mod
/-- info: 'Bitcoin.DataLaws.seqIsDisabled_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms seqIsDisabled_iff
/-- info: 'Bitcoin.DataLaws.seqIsDisabled_iff_no_relative_lock' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms seqIsDisabled_iff_no_relative_lock
/-- info: 'Bitcoin.DataLaws.seqHeightLockContribution_of_not_disabled' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms seqHeightLockContribution_of_not_disabled
/-- info: 'Bitcoin.DataLaws.seqHeightLock_eq_mask' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms seqHeightLock_eq_mask
/-- info: 'Bitcoin.DataLaws.seqHeightLock_eq_mod' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms seqHeightLock_eq_mod
/-- info: 'Bitcoin.DataLaws.seqIsTimeBased_iff' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms seqIsTimeBased_iff
/-- info: 'Bitcoin.DataLaws.bip68Enabled_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms bip68Enabled_iff
/-- info: 'Bitcoin.DataLaws.scriptNum_four_byte_boundary' depends on axioms: [propext] -/
#guard_msgs in #print axioms scriptNum_four_byte_boundary

end Bitcoin.DataLaws
