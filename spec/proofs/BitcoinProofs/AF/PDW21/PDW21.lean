import Bitcoin.Invariants.RC10
import Bitcoin.Activation.Interface

/-! # PDW21.lean — proof-promotion review RC26, items TOP-101..105
(PDW21, 2026-10-17; claim b053a92).

Route B (PDW11..16 pattern): zero core writes; `@[rule]` tags ride
THESE theorems; old core tags untouched; pins ⊆
`[propext, Classical.choice, Quot.sound]`; zero `sorryAx`.

* **INV-118** `MEMPOOL_HEIGHT` sentinel: ≠ every real (≤10⁶) height,
  plus both lockpoints faces.
* **INV-119** `muhashSet` — an ADDITIVE ABSTRACTION of the MuHash3072
  combination law: `muhashSet cf cs = Σ cf c` over `Nat`. It supports
  the partition/split algebra used by the snapshot lane, but it is NOT
  the 3072-bit class-group product, NOT a hash, and `snapshotEq` is not
  the consensus MuHash commitment comparison. The residual is stated in
  the INV-119 section below; the core `RC10` module carries the same
  disclosure ("arithmetic PROPOSED").
* **INV-120** `setBestBlock` / `connectBestBlock`: pointer tracks,
  coins untouched.
* **INV-121** `bip9Transition`: the FSM edge faces in Core order.
* **INV-126** `bip9State_eq`: period-alignment cache semantics.
-/

namespace BitcoinProofs.AF.PDW21

open Bitcoin.Invariants.RC10

/-! ## INV-118 — MEMPOOL_HEIGHT sentinel -/

@[rule "INV-118"]
theorem sentinel_ne_real_height (h : UInt32) (hh : h.toNat ≤ 1000000) :
    h ≠ Bitcoin.Ledger.MEMPOOL_HEIGHT :=
  mempool_height_ne_real h hh

@[rule "INV-118"]
theorem lockpoints_mempool_face (t : UInt32) :
    prevHeightOrNext Bitcoin.Ledger.MEMPOOL_HEIGHT t = t + 1 :=
  prevHeightOrNext_mempool t

@[rule "INV-118"]
theorem lockpoints_real_face (h t : UInt32)
    (hne : h ≠ Bitcoin.Ledger.MEMPOOL_HEIGHT) :
    prevHeightOrNext h t = h :=
  prevHeightOrNext_real h t hne

/-! ## INV-119 — MuHash3072 snapshot hash (additive abstraction)

**Residual (accepted, disclosed):** Core's `MuHash3072` combines coin
elements by multiplication/division in a 3072-bit class group; the
snapshot commitment is that group element (kernel/coinstats.cpp:59-112).
`RC10.muhashSet` replaces the group operation with `Nat` addition and the
hash-to-group map with an arbitrary per-coin datum `cf`. Consequently:

* the theorems below are true of the additive monoid model only;
* they do NOT prove that `snapshotEq` equals Core's commitment check, nor
  that the combination law is collision-resistant;
* the 3072-bit modular arithmetic and the MuHash serialization are not
  modelled (zero-FFI core; Review-4 bigint seam).

What IS established is the partition/append algebra the snapshot lane
uses, plus the exact definition of the local predicate. Treat this row as
model-level evidence about the additive abstraction, not as a MuHash3072
correctness proof. -/

@[rule "INV-119"]
theorem muhashSet_split (cf : Bitcoin.Ledger.Coin → Nat)
    (a b : List Bitcoin.Ledger.Coin) :
    muhashSet cf (a ++ b) = muhashSet cf a + muhashSet cf b :=
  muhashSet_append cf a b

@[rule "INV-119"]
theorem muhashSet_comm (cf : Bitcoin.Ledger.Coin → Nat)
    (a b : List Bitcoin.Ledger.Coin) :
    muhashSet cf (a ++ b) = muhashSet cf (b ++ a) := by
  rw [muhashSet_append, muhashSet_append, Nat.add_comm]

@[rule "INV-119"]
theorem muhashSet_nil (cf : Bitcoin.Ledger.Coin → Nat) : muhashSet cf [] = 0 := rfl

/-- **REM-10 — the assumeutxo snapshot equality predicate (additive
model).**

`CheckUTXOState`/`VerifyUTXOSet` compare the combined MuHash3072 of the
snapshot's coin set against the expected commitment (coinstats.cpp:59-
112). `snapshotEq` is the analogous equality predicate for the RC10
ADDITIVE abstraction `muhashSet`: equality of two natural-number
summaries, not equality of 3072-bit MuHash group elements. The theorems
below characterize this local predicate exactly; they do not claim to
model the consensus commitment (see the INV-119 residual block). -/
@[rule "INV-119"]
def snapshotEq (cf : Bitcoin.Ledger.Coin → Nat)
    (a b : List Bitcoin.Ledger.Coin) : Bool :=
  muhashSet cf a == muhashSet cf b

@[rule "INV-119"]
theorem snapshotEq_eq_true_iff (cf : Bitcoin.Ledger.Coin → Nat)
    (a b : List Bitcoin.Ledger.Coin) :
    snapshotEq cf a b = true ↔ muhashSet cf a = muhashSet cf b := by
  unfold snapshotEq
  simp

@[rule "INV-119"]
theorem snapshotEq_refl (cf : Bitcoin.Ledger.Coin → Nat)
    (a : List Bitcoin.Ledger.Coin) : snapshotEq cf a a = true := by
  rw [snapshotEq_eq_true_iff]

/-- A snapshot check over a partition of both coin sets decomposes into
the two additive halves — the equality predicate is stable under the
partitioning the assumeutxo snapshot uses. -/
@[rule "INV-119"]
theorem snapshotEq_append_iff (cf : Bitcoin.Ledger.Coin → Nat)
    (a b c d : List Bitcoin.Ledger.Coin) :
    snapshotEq cf (a ++ b) (c ++ d) = true ↔
      muhashSet cf a + muhashSet cf b = muhashSet cf c + muhashSet cf d := by
  rw [snapshotEq_eq_true_iff, muhashSet_append, muhashSet_append]

/-! ## INV-120 — best-block pointer tracks coins state -/

@[rule "INV-120"]
theorem setBestBlock_coins' (v : CoinsView) (h : ByteArray) :
    (setBestBlock v h).coins = v.coins :=
  setBestBlock_coins v h

@[rule "INV-120"]
theorem setBestBlock_best' (v : CoinsView) (h : ByteArray) :
    (setBestBlock v h).bestBlock = h :=
  setBestBlock_best v h

@[rule "INV-120"]
theorem connectBestBlock_coins' (v : CoinsView) (tx : Bitcoin.Data.Tx) (key : Bitcoin.Ledger.Key)
    (height : UInt32) (bh : ByteArray) :
    (connectBestBlock v tx key height bh).coins =
      Bitcoin.Ledger.updateCoins v.coins tx key height :=
  connectBestBlock_coins v tx key height bh

@[rule "INV-120"]
theorem connectBestBlock_best (v : CoinsView) (tx : Bitcoin.Data.Tx) (key : Bitcoin.Ledger.Key)
    (height : UInt32) (bh : ByteArray) :
    (connectBestBlock v tx key height bh).bestBlock = bh := rfl

/-! ## INV-121 — BIP9 FSM transition faces (Core test order) -/

open Bitcoin.Activation

@[rule "INV-121"]
theorem defined_started (P : Bip9Params) (h : Nat) (hs : P.start ≤ h) :
    bip9Transition P .defined h = .started := by
  simp [bip9Transition, hs]

@[rule "INV-121"]
theorem defined_wait (P : Bip9Params) (h : Nat) (hs : h < P.start) :
    bip9Transition P .defined h = .defined := by
  simp [bip9Transition, Nat.not_le.mpr hs]

@[rule "INV-121"]
theorem started_locked (P : Bip9Params) (h : Nat)
    (hc : P.threshold ≤ P.count h) :
    bip9Transition P .started h = .lockedIn := by
  simp [bip9Transition, hc]

@[rule "INV-121"]
theorem started_failed (P : Bip9Params) (h : Nat)
    (hc : ¬ P.threshold ≤ P.count h) (hd : bip9Deadline P ≤ h) :
    bip9Transition P .started h = .failed := by
  simp [bip9Transition, hc, hd]

@[rule "INV-121"]
theorem started_wait (P : Bip9Params) (h : Nat)
    (hc : ¬ P.threshold ≤ P.count h) (hd : ¬ bip9Deadline P ≤ h) :
    bip9Transition P .started h = .started := by
  simp [bip9Transition, hc, hd]

@[rule "INV-121"]
theorem locked_active (P : Bip9Params) (h : Nat)
    (ha : P.minActivation ≤ h + 1) :
    bip9Transition P .lockedIn h = .active := by
  simp [bip9Transition, ha]

@[rule "INV-121"]
theorem locked_wait (P : Bip9Params) (h : Nat)
    (ha : ¬ P.minActivation ≤ h + 1) :
    bip9Transition P .lockedIn h = .lockedIn := by
  simp [bip9Transition, ha]

@[rule "INV-121"]
theorem active_stays (P : Bip9Params) (h : Nat) :
    bip9Transition P .active h = .active := rfl

@[rule "INV-121"]
theorem failed_stays (P : Bip9Params) (h : Nat) :
    bip9Transition P .failed h = .failed := rfl

/-! ## INV-126 — period-alignment cache semantics -/

@[rule "INV-126"]
theorem bip9State_eq' (P : Bip9Params) (hP0 : P.period ≠ 0) (h : Nat)
    (hk : P.period ≤ h + 1) :
    bip9State P h = bip9StateByPeriod P ((h + 1) / P.period - 1) :=
  bip9State_eq P hP0 h hk

@[rule "INV-126"]
theorem bip9State_pre' (P : Bip9Params) (h : Nat) (hk : h + 1 < P.period) :
    bip9State P h = .defined :=
  bip9State_pre P h hk

end BitcoinProofs.AF.PDW21
