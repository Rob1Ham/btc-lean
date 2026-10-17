import Bitcoin.TxValidation.Interface
import Bitcoin.Ledger.Interface
import Bitcoin.DataLaws.Interface

/-!
# Bitcoin.TxValidation.Mempool — X09: the mempool-context tx layer

The tx corpus carries NO block context, so the context-domain TXV rows
(finality-at-tip, sequence-locks-at-tip, the `MEMPOOL_HEIGHT` sentinel,
same-block spend ordering, wtxid identity) live above the stateless and
script slices: this module is Core's `CheckFinalTxAtTip` /
`CheckSequenceLocksAtTip` / mempool side of `ConnectBlock`'s `UpdateCoins`
loop (validation.cpp:156-175, 255-270, 2571-2606; txmempool.h:51;
transaction.cpp:86-93), expressed over the frozen W10/W12 algebra.

## What is proven here (all sorry-free; axiom pins at the file end)

* **TXV-033** — `checkFinalTxAtTip` evaluates `IsFinalTx` at `tipH + 1`
  (validation.cpp:CheckFinalTxAtTip:156-175); finality is monotone in the
  height cutoff, so a tx final at the tip stays final for the mempool's
  next-block evaluation (BIP113's mtp cutoff rides through unchanged).
* **TXV-041** — `checkSequenceLocksAtTip` evaluates the BIP68 height
  projection at `tipH + 1`; the verdict is monotone in the block height.
* **TXV-042** — the `MEMPOOL_HEIGHT = 0x7FFFFFFF` sentinel: equality with
  the Ledger constant, dominance over every realizable next-block height
  (the top bit is reserved — the sentinel can never be confused with a
  spend height), and the coin-code packing roundtrip at the sentinel.
* **TXV-064** — same-block spend ordering: `updateCoins` removes a spent
  prevout, so of two same-block spenders the FIRST in block order wins
  and the second fails `HaveInputs` (validation.cpp:2571-2606's
  sequential fold is load-bearing).
* **TXV-065** — in-block output reuse: a tx's own output coins win the
  pointwise update, so tx `i+1` can spend tx `i`'s outputs (cache-first
  semantics, coins.cpp:SpendCoin:144 + AddCoins ordering).
* **TXV-073** — the mempool identity is the `wtxid` (BIP141): a
  witness-free tx's mempool key IS its txid (the two dedup channels
  coincide), and the key is a function of the extended serialization.
-/

namespace Bitcoin.TxValidation.Mempool

open Bitcoin.Data Bitcoin.Ledger Bitcoin.Consensus Bitcoin.DataLaws
open Bitcoin.TxValidation

/-! ## TXV-033: finality at the mempool tip -/

/-- `CheckFinalTxAtTip` (validation.cpp:156-175): the mempool accepts a
tx only if it is final FOR THE NEXT BLOCK — the height cutoff is
`tipHeight + 1`, the BIP113 time cutoff is the tip's median-time-past. -/
@[rule "TXV-033"]
def checkFinalTxAtTip (tx : Tx) (tipH tipMtp : UInt32) : Bool :=
  Bitcoin.DataLaws.isFinalTx tx (tipH + 1) tipMtp

/-- Finality is monotone in the height cutoff (mtp fixed): raising the
block height only relaxes the height-domain comparison. `hmax` keeps
`h + 1` inside the height domain (no wrap). -/
theorem isFinalTx_height_mono (tx : Tx) (mtp h : UInt32)
    (hmax : h.toNat ≠ 4294967295)
    (hf : Bitcoin.DataLaws.isFinalTx tx h mtp = true) :
    Bitcoin.DataLaws.isFinalTx tx (h + 1) mtp = true := by
  rw [isFinalTx_iff] at hf ⊢
  rcases hf with h0 | hlt | hall
  · exact Or.inl h0
  · refine Or.inr (Or.inl ?_)
    by_cases hd : locktimeIsTimeDomain tx.locktime = true
    · rw [if_pos hd] at hlt ⊢
      exact hlt
    · rw [if_neg hd] at hlt ⊢
      exact UInt32.lt_of_lt_of_le hlt (by
        have hb : h.toNat < 4294967296 := h.toBitVec.isLt
        have h1 : (1 : UInt32).toNat = 1 := rfl
        have hadd : (h + 1).toNat = h.toNat + 1 := by
          rw [UInt32.toNat_add, h1, Nat.mod_eq_of_lt (by omega)]
        rw [UInt32.le_iff_toNat_le, hadd]
        exact Nat.le_add_right _ _)
  · exact Or.inr (Or.inr hall)

/-- A tx final at the tip is final for the mempool's next-block evaluation
(TXV-033's acceptance direction). -/
theorem finalAtTip_finalAtNext (tx : Tx) (tipH tipMtp : UInt32)
    (hmax : tipH.toNat ≠ 4294967295)
    (hf : Bitcoin.DataLaws.isFinalTx tx tipH tipMtp = true) :
    checkFinalTxAtTip tx tipH tipMtp = true :=
  isFinalTx_height_mono tx tipMtp tipH hmax hf

/-! ## TXV-041: sequence locks at the mempool tip -/

/-- `CheckSequenceLocksAtTip` (validation.cpp:255-270): the BIP68
height-projection verdict evaluated against the NEXT block height
(`tipHeight + 1`; `CalculatePrevHeights` feeds per-input coin heights
from the view). Time-domain locks are `sequenceLocksOk`'s business
(W12's seam carries the parent-MTP chain); this is the height-domain
half the tip context determines. -/
@[rule "TXV-041"]
def checkSequenceLocksAtTip (tx : Tx) (u : UtxoSet) (csvFlag : Bool) (tipH : UInt32) : Bool :=
  bip68HeightOk tx u csvFlag ((tipH + 1).toNat : Int)

/-- The BIP68 height projection is monotone in the spend-block height:
a tx sequence-locked for block `H` is sequence-locked for any later
block. -/
theorem bip68HeightOk_mono (tx : Tx) (u : UtxoSet) (csv : Bool) (H H' : Int)
    (hle : H ≤ H') (hok : bip68HeightOk tx u csv H = true) :
    bip68HeightOk tx u csv H' = true := by
  unfold bip68HeightOk at hok ⊢
  simp only [decide_eq_true_eq] at hok ⊢
  omega

/-- The tip verdict IS the next-block verdict (validation.cpp:255-270's
`nNextBlockHeight` convention), pinned definitionally. -/
theorem seqLocksAtTip_eq_next (tx : Tx) (u : UtxoSet) (csv : Bool)
    (tipH : UInt32) :
    checkSequenceLocksAtTip tx u csv tipH =
      bip68HeightOk tx u csv ((tipH + 1).toNat : Int) := rfl

/-- `CalculatePrevHeights`' per-coin projection (validation.cpp:183-202):
a coin created in the mempool carries `nHeight = MEMPOOL_HEIGHT` and is
assumed to confirm in the next block (`tipH + 1`); a confirmed coin keeps
its own height. -/
def prevHeightAtTip (tipH : UInt32) (c : Coin) : Int :=
  if c.height = mempoolHeight then ((tipH + 1).toNat : Int) else (c.height.toNat : Int)

/-- The per-input prev-height vector `CalculatePrevHeights` builds for
`CheckSequenceLocksAtTip`: the same `(prevHeight, parentMTP)` shape as
`prevHeightData`, but with the mempool sentinel projected to `tipH + 1`
(the time component stays the height-domain dummy). -/
def prevHeightDataAtTip (tx : Tx) (u : UtxoSet) (tipH : UInt32) : List (Int × Int) :=
  tx.vin.map (fun i =>
    match u i.prevout with
    | some c => (prevHeightAtTip tipH c, 0)
    | none => (0, 0))

/-- The full mempool sequence-lock verdict: BIP68 height locks evaluated
at the NEXT block height (`tipH + 1`) over `CalculatePrevHeights`' vector.
This is the row's two-part statement: evaluation height `tipH + 1` and
mempool-input heights `tipH + 1`. -/
@[rule "TXV-041"]
def checkSequenceLocksAtTipMem (tx : Tx) (u : UtxoSet) (csvFlag : Bool)
    (tipH : UInt32) : Bool :=
  (calculateSequenceLocks tx csvFlag (prevHeightDataAtTip tx u tipH)).1
    < ((tipH + 1).toNat : Int)

/-- TXV-041: a mempool coin's height is exactly `tipH + 1` in
`CalculatePrevHeights`. -/
@[rule "TXV-041"] theorem prevHeightAtTip_mempool (tipH : UInt32) (c : Coin)
    (h : c.height = mempoolHeight) :
    prevHeightAtTip tipH c = ((tipH + 1).toNat : Int) := by
  unfold prevHeightAtTip
  rw [if_pos h]

/-- TXV-041: a confirmed coin's height is unchanged by
`CalculatePrevHeights`. -/
@[rule "TXV-041"] theorem prevHeightAtTip_confirmed (tipH : UInt32) (c : Coin)
    (h : c.height ≠ mempoolHeight) :
    prevHeightAtTip tipH c = (c.height.toNat : Int) := by
  unfold prevHeightAtTip
  rw [if_neg h]

/-- TXV-041, full statement: the mempool verdict accepts iff BIP68 is not
enforced, or every input's height lock holds at `tipH + 1` under the
`CalculatePrevHeights` projection (mempool parents at `tipH + 1`). -/
@[rule "TXV-041"] theorem checkSequenceLocksAtTipMem_spec (tx : Tx) (u : UtxoSet)
    (csv : Bool) (tipH : UInt32) :
    checkSequenceLocksAtTipMem tx u csv tipH = true ↔
      (Bitcoin.DataLaws.bip68Enabled tx.version csv = false ∨
        vinHeightOk tx.vin (prevHeightDataAtTip tx u tipH)
          ((tipH + 1).toNat : Int)) := by
  have hH : (0 : Int) ≤ ((tipH + 1).toNat : Int) := by omega
  by_cases he : Bitcoin.DataLaws.bip68Enabled tx.version csv = true
  · unfold checkSequenceLocksAtTipMem
    rw [decide_eq_true_iff, calculateSequenceLocks_enabled _ _ _ he,
      seqLockFold_height hH]
    simp [he]
  · have he' : Bitcoin.DataLaws.bip68Enabled tx.version csv = false := by
      cases hb : Bitcoin.DataLaws.bip68Enabled tx.version csv with
      | true => exact absurd hb he
      | false => rfl
    unfold checkSequenceLocksAtTipMem
    rw [decide_eq_true_iff, calculateSequenceLocks_disabled _ _ _ he']
    exact ⟨fun _ => Or.inl he', fun _ => by omega⟩

/-- TXV-041: for a view in which every input prevout is a confirmed coin
(no `MEMPOOL_HEIGHT` sentinel), the `CalculatePrevHeights` projection is
the identity, so the frozen `checkSequenceLocksAtTip` agrees with the full
mempool verdict. -/
@[rule "TXV-041"] theorem checkSequenceLocksAtTip_eq_mem (tx : Tx) (u : UtxoSet)
    (csv : Bool) (tipH : UInt32)
    (hconf : ∀ i ∈ tx.vin, ∀ c, u i.prevout = some c → c.height ≠ mempoolHeight) :
    checkSequenceLocksAtTip tx u csv tipH
      = checkSequenceLocksAtTipMem tx u csv tipH := by
  unfold checkSequenceLocksAtTip checkSequenceLocksAtTipMem bip68HeightOk
  have hdata : prevHeightData tx u = prevHeightDataAtTip tx u tipH := by
    unfold prevHeightData prevHeightDataAtTip
    apply List.map_congr_left
    intro i hi
    cases hv : u i.prevout with
    | none => rfl
    | some c =>
      simp [prevHeightAtTip_confirmed tipH c (hconf i hi c hv)]
  rw [hdata]

/-! ## TXV-042: the MEMPOOL_HEIGHT sentinel -/

/-- Sentinel equality with the Ledger constant (the frozen-header
duplicate is definitional). -/
theorem mempoolHeight_eq_ledger : mempoolHeight = Bitcoin.Ledger.MEMPOOL_HEIGHT := rfl

/-- The sentinel dominates every realizable next-block height: chain
heights are 31-bit (the Coin packing, TXV-022), so `tipH + 1` never
reaches `MEMPOOL_HEIGHT` — an unconfirmed coin's sentinel height can
never be confused with a spend height. -/
theorem mempoolHeight_dominates (tipH : UInt32) (h31 : tipH.toNat < 2147483647) :
    (tipH + 1).toNat ≤ mempoolHeight.toNat := by
  have h1 : (1 : UInt32).toNat = 1 := rfl
  rw [UInt32.toNat_add, h1, Nat.mod_eq_of_lt (by
    have hb : tipH.toNat < 4294967296 := tipH.toBitVec.isLt
    omega)]
  rw [show mempoolHeight.toNat = 2147483647 from rfl]
  omega

/-- The sentinel survives the coin-code packing (TXV-022 roundtrip at
`0x7FFFFFFF`: the top bit is free for the coinbase flag). -/
theorem mempoolHeight_pack_roundtrip :
    coinHeightOfCode (packCoinCode mempoolHeight false) = mempoolHeight :=
  coinHeightOfCode_pack mempoolHeight false (by decide)

/-! ### TXV-042: the mempool coins view (`CCoinsViewMemPool`)

Core's mempool view inserts a package's transaction outputs into a temporary
cache with `MEMPOOL_HEIGHT`, not a block height: `PackageAddTransaction`
calls `AddCoins(view, tx, MEMPOOL_HEIGHT, false)` (txmempool.cpp:804,816)
and `GetCoin` then serves those coins to `CalculatePrevHeights`. The model
below is the insertion half of that view: it reuses the ledger's `AddCoins`
path (`addedCoins`) with the sentinel substituted for the connection height,
and a wrapper that lets the inserted coins shadow the backing view. -/

/-- `CCoinsViewMemPool::PackageAddTransaction`'s insertion
(txmempool.cpp:804,816): `AddCoins` for `tx`, stamped with the
`MEMPOOL_HEIGHT` sentinel (`txmempool.h:51`). -/
@[rule "TXV-042"]
def mempoolAddedCoins (tx : Tx) (key : Key) : List (OutPoint × Coin) :=
  addedCoins tx key mempoolHeight

/-- The mempool coins view after inserting `tx`: every output the insertion
path produced shadows the backing view at its outpoint; all other outpoints
fall through unchanged. -/
@[rule "TXV-042"]
def mempoolAddCoins (u : UtxoSet) (tx : Tx) (key : Key) : UtxoSet :=
  fun o =>
    match coinLookup (mempoolAddedCoins tx key) o with
    | some c => some c
    | none => u o

/-- Inversion for the mempool insertion path: every inserted coin is the
`AddCoins` image of an in-range, spendable output, with height
`mempoolHeight`. -/
@[rule "TXV-042"]
theorem mempoolAddedCoins_spec (tx : Tx) (key : Key) (p : OutPoint × Coin)
    (hp : p ∈ mempoolAddedCoins tx key) :
    ∃ j, j < tx.vout.length ∧
      p.1 = key OutPoint.null (UInt32.ofNat j) ∧
      p.2 = ⟨(tx.vout.getD j ⟨0, Script.empty⟩).value, mempoolHeight, tx.isCoinBase,
        (tx.vout.getD j ⟨0, Script.empty⟩).scriptPubKey⟩ := by
  unfold mempoolAddedCoins at hp
  obtain ⟨j, hj, hkey, _hus, hcoin⟩ := addedCoins_inv tx key mempoolHeight p hp
  exact ⟨j, hj, hkey, hcoin⟩

/-- TXV-042 (insertion height): every coin inserted by the mempool view
carries the sentinel `MEMPOOL_HEIGHT = 0x7FFFFFFF`, never a block height. -/
@[rule "TXV-042"]
theorem mempoolAddedCoins_height (tx : Tx) (key : Key) (p : OutPoint × Coin)
    (hp : p ∈ mempoolAddedCoins tx key) :
    p.2.height = mempoolHeight := by
  obtain ⟨j, _hj, _hkey, hcoin⟩ := mempoolAddedCoins_spec tx key p hp
  rw [hcoin]

/-- TXV-042 (lookup height): a lookup that hits an inserted mempool coin
returns that sentinel height. -/
@[rule "TXV-042"]
theorem mempoolAddedCoins_lookup_height (tx : Tx) (key : Key) (o : OutPoint)
    (c : Coin) (h : coinLookup (mempoolAddedCoins tx key) o = some c) :
    c.height = mempoolHeight := by
  obtain ⟨p, hp, _hpo, hpc⟩ := coinLookup_some_inv _ _ _ h
  rw [← hpc]
  exact mempoolAddedCoins_height tx key p hp

/-- TXV-042 (lookup output/value): a lookup that hits an inserted mempool
coin returns exactly one of `tx`'s spendable outputs — same value, script,
and coinbase bit — merely with the sentinel height. -/
@[rule "TXV-042"]
theorem mempoolAddedCoins_lookup_value (tx : Tx) (key : Key) (o : OutPoint)
    (c : Coin) (h : coinLookup (mempoolAddedCoins tx key) o = some c) :
    ∃ j, j < tx.vout.length ∧
      c.value = (tx.vout.getD j ⟨0, Script.empty⟩).value ∧
      c.scriptPubKey = (tx.vout.getD j ⟨0, Script.empty⟩).scriptPubKey ∧
      c.isCoinbase = tx.isCoinBase := by
  obtain ⟨p, hp, _hpo, hpc⟩ := coinLookup_some_inv _ _ _ h
  obtain ⟨j, hj, _hkey, hcoin⟩ := mempoolAddedCoins_spec tx key p hp
  refine ⟨j, hj, ?_, ?_, ?_⟩ <;> rw [← hpc, hcoin]

/-- TXV-042 (view lookup): the wrapper serves an inserted coin unchanged;
the backing view is consulted only when the insertion has no entry. -/
@[rule "TXV-042"]
theorem mempoolAddCoins_lookup_mem (u : UtxoSet) (tx : Tx) (key : Key)
    (o : OutPoint) (c : Coin)
    (h : coinLookup (mempoolAddedCoins tx key) o = some c) :
    mempoolAddCoins u tx key o = some c := by
  unfold mempoolAddCoins
  rw [h]

/-- TXV-042 (view lookup at an inserted outpoint): whatever the backing
view, a lookup served by the insertion has the sentinel height. -/
@[rule "TXV-042"]
theorem mempoolAddCoins_lookup_sentinel (u : UtxoSet) (tx : Tx) (key : Key)
    (o : OutPoint) (c : Coin)
    (h : coinLookup (mempoolAddedCoins tx key) o = some c) :
    mempoolAddCoins u tx key o = some c ∧ c.height = mempoolHeight :=
  ⟨mempoolAddCoins_lookup_mem u tx key o c h,
   mempoolAddedCoins_lookup_height tx key o c h⟩

/-- TXV-042: in a view containing only the mempool insertion, every visible
coin has the sentinel height (the unconditional statement of the row for a
lookup at an inserted outpoint). -/
@[rule "TXV-042"]
theorem mempoolAddCoins_empty_height (tx : Tx) (key : Key) (o : OutPoint)
    (c : Coin) (h : mempoolAddCoins (fun _ => none) tx key o = some c) :
    c.height = mempoolHeight := by
  unfold mempoolAddCoins at h
  cases hc : coinLookup (mempoolAddedCoins tx key) o with
  | none => rw [hc] at h; exact absurd h (by simp)
  | some c' =>
    rw [hc] at h
    have hcc : c' = c := Option.some.inj h
    rw [← hcc]
    exact mempoolAddedCoins_lookup_height tx key o c' hc

/-- TXV-042: the same lookup returns the correct output data (value, script,
coinbase bit) of a spendable output of `tx`. -/
@[rule "TXV-042"]
theorem mempoolAddCoins_empty_value (tx : Tx) (key : Key) (o : OutPoint)
    (c : Coin) (h : mempoolAddCoins (fun _ => none) tx key o = some c) :
    ∃ j, j < tx.vout.length ∧
      c.value = (tx.vout.getD j ⟨0, Script.empty⟩).value ∧
      c.scriptPubKey = (tx.vout.getD j ⟨0, Script.empty⟩).scriptPubKey ∧
      c.isCoinbase = tx.isCoinBase := by
  unfold mempoolAddCoins at h
  cases hc : coinLookup (mempoolAddedCoins tx key) o with
  | none => rw [hc] at h; exact absurd h (by simp)
  | some c' =>
    rw [hc] at h
    have hcc : c' = c := Option.some.inj h
    rw [← hcc]
    exact mempoolAddedCoins_lookup_value tx key o c' hc

/-- TXV-042 (tx-pipeline consumer): `prevHeightData` — the height vector
`bip68HeightOk`/`validateTx` consume — reads the inserted coin's height
verbatim, so an in-mempool prevout appears there as the sentinel. -/
@[rule "TXV-042"]
theorem prevHeightData_mempool (tx : Tx) (u : UtxoSet) (i : TxIn) (c : Coin)
    (hi : i ∈ tx.vin) (hv : u i.prevout = some c) (hc : c.height = mempoolHeight) :
    ((mempoolHeight.toNat : Int), (0 : Int)) ∈ prevHeightData tx u := by
  have hm : (match u i.prevout with
      | some c => ((c.height.toNat : Int), (0 : Int))
      | none => ((0 : Int), (0 : Int))) ∈ prevHeightData tx u :=
    List.mem_map.mpr ⟨i, hi, rfl⟩
  simpa [hv, hc] using hm

/-- TXV-042: the sentinel is exactly the pair slot `prevHeightData` produces
for the input — stated as the per-input equality of the consumer's map. -/
@[rule "TXV-042"]
theorem prevHeightData_mempool_entry (tx : Tx) (u : UtxoSet) (i : TxIn) (c : Coin)
    (_hi : i ∈ tx.vin) (hv : u i.prevout = some c) (hc : c.height = mempoolHeight) :
    (match u i.prevout with
      | some c => ((c.height.toNat : Int), (0 : Int))
      | none => ((0 : Int), (0 : Int))) = ((mempoolHeight.toNat : Int), (0 : Int)) := by
  rw [hv]
  simp [hc]

/-- TXV-042: the mempool-view coin also feeds the Core-correct tip
projection (`CalculatePrevHeights`): `prevHeightAtTip` maps the sentinel to
`tip + 1`, so the inserted coin's prev-height is the next block height. -/
@[rule "TXV-042"]
theorem mempoolAddCoins_prevHeightAtTip (tx : Tx) (key : Key) (o : OutPoint)
    (c : Coin) (tipH : UInt32)
    (h : mempoolAddCoins (fun _ => none) tx key o = some c) :
    prevHeightAtTip tipH c = (((tipH + 1).toNat : Nat) : Int) :=
  prevHeightAtTip_mempool tipH c (mempoolAddCoins_empty_height tx key o c h)

/-! ## TXV-064: same-block spend ordering -/

/-- `SpendCoin` (coins.cpp:144) at the update level: a non-coinbase tx
spending prevout `o` (which its own outputs do not re-add) removes `o`
from the view. -/
@[rule "TXV-064"]
theorem updateCoins_spend_removes (u : UtxoSet) (tx : Tx) (key : Key) (h : UInt32)
    (o : OutPoint) (hncb : tx.isCoinBase = false)
    (hnoadd : coinLookup (addedCoins tx key h) o = none)
    (hspend : tx.vin.any (fun i => i.prevout == o) = true) :
    updateCoins u tx key h o = none := by
  unfold updateCoins
  rw [hnoadd]
  simp [hncb, hspend]

/-- A tx spending a prevout the view no longer carries fails
`HaveInputs` (coins.cpp:322-331) — the second same-block spender's
fate. -/
theorem inputsAvailable_false_of_spent (u : UtxoSet) (tx : Tx) (o : OutPoint)
    (hmiss : ∃ i, i ∈ tx.vin ∧ i.prevout = o) (ho : u o = none) :
    inputsAvailable u tx = false := by
  obtain ⟨i, him, hpo⟩ := hmiss
  unfold inputsAvailable
  refine List.all_eq_false.mpr ⟨i, him, ?_⟩
  rw [hpo, ho]
  simp

/-- TXV-064 (first spender wins): in the sequential block fold, if tx
`a`'s step succeeds, tx `b` spends a prevout `a` removed (and `b`'s own
outputs do not re-add it), then `b`'s step fails with
`bad-txns-inputs-missingorspent` — block ORDER decides the winner. The
`hb30` side condition fixes `b`'s BIP30 collision check (a separate
row, TXV-063); `applyTxStepU`'s check order is BIP30 → coinbase →
HaveInputs → maturity. -/
@[rule "TXV-064"]
theorem first_spender_wins (u : UtxoSet) (kf : Tx → Key) (h : UInt32)
    (a b : Tx) (rest : List Tx) (o : OutPoint)
    (haok : applyTxStepU u a (kf a) h = Except.ok (updateCoins u a (kf a) h))
    (hncbb : b.isCoinBase = false)
    (hnoadd : coinLookup (addedCoins b (kf b) h) o = none)
    (hspend : b.vin.any (fun i => i.prevout == o) = true)
    (hb30g : (bip30BlockCollision u kf (a :: b :: rest) h && bip30Enforced h) = false)
    (ho : updateCoins u a (kf a) h o = none) :
    applyBlockU u kf (a :: b :: rest) h =
      Except.error (BlockError.txError TxError.badTxnsInputsMissingOrSpent) := by
  obtain ⟨i, him, hpo⟩ := List.any_eq_true.mp hspend
  have hpo' : i.prevout = o := outPointBEq_eq _ _ hpo
  have hbgN : ¬((bip30BlockCollision u kf (a :: b :: rest) h && bip30Enforced h) = true) := by
    rw [hb30g]; simp
  have hcb' : ¬(b.isCoinBase = true) := by simp [hncbb]
  -- `hnoadd` (b's own outputs do not re-add `o`) is recorded as a side
  -- condition but not needed for THIS verdict: `b` fails `HaveInputs`
  -- before any of its outputs could be added.
  clear hnoadd
  have hnav : (!inputsAvailable (updateCoins u a (kf a) h) b) = true := by
    rw [Bool.not_eq_true']
    exact inputsAvailable_false_of_spent _ b o ⟨i, him, hpo'⟩ ho
  unfold applyBlockU
  rw [if_neg hbgN]
  rw [applyBlockFoldU]
  rw [haok]
  show applyBlockFoldU (updateCoins u a (kf a) h) kf (b :: rest) h = _
  unfold applyBlockFoldU applyTxStepU
  rw [if_neg hcb', if_pos hnav]
  rfl

/-! ## TXV-065: in-block output reuse -/

/-- TXV-065 (cache-first outputs): an output coin `tx` itself creates
WINS the pointwise update — even over a stale view entry at the same
outpoint (SpendCoin-all, then AddCoins: last write wins). -/
@[rule "TXV-065"]
theorem updateCoins_added_coin_wins (u : UtxoSet) (tx : Tx) (key : Key) (h : UInt32)
    (o : OutPoint) (c : Coin)
    (hfind : coinLookup (addedCoins tx key h) o = some c) :
    updateCoins u tx key h o = some c := by
  unfold updateCoins
  rw [hfind]

/-- The sequential fold's one-step rewrite: with `a`'s step succeeding,
the block fold continues on `a`'s updated view — the view tx `i+1`
sees (validation.cpp:2571-2606). Post-D4c-2 both pre-loop BIP30 gates
are fixed false by side conditions (a separate row, TXV-063): `hb30g`
on the pristine block `a :: rest`, `hb30g'` on the residual block
`rest` at the evolved view. -/
@[rule "TXV-065"]
theorem applyBlockU_cons_ok_step (u : UtxoSet) (kf : Tx → Key) (h : UInt32)
    (a : Tx) (rest : List Tx)
    (haok : applyTxStepU u a (kf a) h = Except.ok (updateCoins u a (kf a) h))
    (hb30g : (bip30BlockCollision u kf (a :: rest) h && bip30Enforced h) = false)
    (hb30g' : (bip30BlockCollision (updateCoins u a (kf a) h) kf rest h
        && bip30Enforced h) = false) :
    applyBlockU u kf (a :: rest) h =
      applyBlockU (updateCoins u a (kf a) h) kf rest h := by
  have hbgN : ¬((bip30BlockCollision u kf (a :: rest) h && bip30Enforced h) = true) := by
    rw [hb30g]; simp
  have hbgN' : ¬((bip30BlockCollision (updateCoins u a (kf a) h) kf rest h
      && bip30Enforced h) = true) := by
    rw [hb30g']; simp
  unfold applyBlockU
  rw [if_neg hbgN, if_neg hbgN']
  rw [applyBlockFoldU]
  rw [haok]
  rfl

/-- TXV-065, composition: after `a`'s step, a later same-block tx `b`
whose input `i` spends `a`'s fresh output finds that coin present —
the fold order makes in-block chaining spendable. -/
theorem inblock_output_spendable (u : UtxoSet) (kf : Tx → Key) (h : UInt32)
    (a : Tx) (o : OutPoint) (c : Coin)
    (hfind : coinLookup (addedCoins a (kf a) h) o = some c)
    (b : Tx) (i : TxIn) (_him : i ∈ b.vin) (hpo : i.prevout = o) :
    ((updateCoins u a (kf a) h) i.prevout).isSome = true := by
  rw [hpo, updateCoins_added_coin_wins u a (kf a) h o c hfind]
  rfl

/-! ## TXV-073: the wtxid mempool identity -/

/-- The mempool identity key (validation.cpp:1655-1657): dedup and
indexing by `wtxid` (BIP141; transaction.cpp:ComputeWitnessHash:86-93). -/
@[rule "TXV-073"]
def mempoolKey (tx : Tx) : ByteArray := Bitcoin.DataLaws.wtxid tx

/-- A witness-free tx's mempool key IS its txid: the wtxid and txid
dedup channels coincide for pre-SegWit transactions. -/
theorem mempoolKey_no_witness_eq_txid (tx : Tx)
    (h : tx.witness.all (·.isEmpty)) :
    mempoolKey tx = Bitcoin.DataLaws.txid tx :=
  Bitcoin.DataLaws.wtxid_eq_txid_iff_no_witness tx h

/-- The mempool key is a function of the extended serialization (plus
the has-witness bit): identical wire data ⇒ identical key ⇒ mempool
dedup. -/
theorem mempoolKey_congr (a b : Tx)
    (hw : Bitcoin.DataLaws.serTxWithWitness a = Bitcoin.DataLaws.serTxWithWitness b)
    (hbit : Bitcoin.DataLaws.hasWitness a = Bitcoin.DataLaws.hasWitness b)
    (ht : serTx a = serTx b) :
    mempoolKey a = mempoolKey b := by
  unfold mempoolKey
  exact Bitcoin.DataLaws.wtxid_congr a b hw hbit ht

/-- TXV-073 (converse of the identity): two txs share a mempool key iff
they share a `wtxid`.  The key is not merely a function of the wtxid but
is the wtxid itself, so dedup/conflict equality is exactly wtxid
equality. -/
@[rule "TXV-073"] theorem mempoolKey_eq_iff (a b : Tx) :
    mempoolKey a = mempoolKey b ↔
      Bitcoin.DataLaws.wtxid a = Bitcoin.DataLaws.wtxid b := by
  unfold mempoolKey
  exact Iff.rfl

/-- TXV-073: the mempool's dedup/conflict test — an entry matches the
candidate iff their mempool keys (wtxids) are equal. -/
@[rule "TXV-073"]
def mempoolDedup (pool : List Tx) (tx : Tx) : Bool :=
  pool.any (fun e => decide (mempoolKey e = mempoolKey tx))

/-- TXV-073: dedup/conflict is exactly `wtxid` identity — a pool contains
a conflict iff it holds an entry with the same wtxid. -/
@[rule "TXV-073"] theorem mempoolDedup_iff (pool : List Tx) (tx : Tx) :
    mempoolDedup pool tx = true ↔
      ∃ e ∈ pool, Bitcoin.DataLaws.wtxid e = Bitcoin.DataLaws.wtxid tx := by
  unfold mempoolDedup
  rw [List.any_eq_true]
  constructor
  · rintro ⟨e, he, hd⟩
    exact ⟨e, he, (mempoolKey_eq_iff e tx).mp (of_decide_eq_true hd)⟩
  · rintro ⟨e, he, hw⟩
    exact ⟨e, he, decide_eq_true ((mempoolKey_eq_iff e tx).mpr hw)⟩

/-- TXV-073: the txid-equivalence channel is separate — two txs with the
same txid but different wtxids have different mempool keys, so the second
is not deduplicated against the first (BIP141 malleability split). -/
@[rule "TXV-073"] theorem mempoolKey_txid_separate (a b : Tx)
    (_htxid : Bitcoin.DataLaws.txid a = Bitcoin.DataLaws.txid b)
    (hwtxid : Bitcoin.DataLaws.wtxid a ≠ Bitcoin.DataLaws.wtxid b) :
    mempoolKey a ≠ mempoolKey b := by
  intro h
  exact hwtxid ((mempoolKey_eq_iff a b).mp h)

/-! ## Axiom pins (every theorem here is sorry-free; standard axioms only) -/

section Pins

/-- info: 'Bitcoin.TxValidation.Mempool.isFinalTx_height_mono' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms isFinalTx_height_mono

/-- info: 'Bitcoin.TxValidation.Mempool.finalAtTip_finalAtNext' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms finalAtTip_finalAtNext

/-- info: 'Bitcoin.TxValidation.Mempool.bip68HeightOk_mono' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms bip68HeightOk_mono

/-- info: 'Bitcoin.TxValidation.Mempool.seqLocksAtTip_eq_next' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms seqLocksAtTip_eq_next

/-- info: 'Bitcoin.TxValidation.Mempool.mempoolHeight_eq_ledger' does not depend on any axioms -/
#guard_msgs in #print axioms mempoolHeight_eq_ledger

/-- info: 'Bitcoin.TxValidation.Mempool.mempoolHeight_dominates' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms mempoolHeight_dominates

/-- info: 'Bitcoin.TxValidation.Mempool.mempoolHeight_pack_roundtrip' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms mempoolHeight_pack_roundtrip

/-- info: 'Bitcoin.TxValidation.Mempool.mempoolAddedCoins_spec' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms mempoolAddedCoins_spec

/-- info: 'Bitcoin.TxValidation.Mempool.mempoolAddedCoins_height' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms mempoolAddedCoins_height

/-- info: 'Bitcoin.TxValidation.Mempool.mempoolAddedCoins_lookup_height' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms mempoolAddedCoins_lookup_height

/-- info: 'Bitcoin.TxValidation.Mempool.mempoolAddedCoins_lookup_value' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms mempoolAddedCoins_lookup_value

/-- info: 'Bitcoin.TxValidation.Mempool.mempoolAddCoins_lookup_mem' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms mempoolAddCoins_lookup_mem

/-- info: 'Bitcoin.TxValidation.Mempool.mempoolAddCoins_lookup_sentinel' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms mempoolAddCoins_lookup_sentinel

/-- info: 'Bitcoin.TxValidation.Mempool.mempoolAddCoins_empty_height' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms mempoolAddCoins_empty_height

/-- info: 'Bitcoin.TxValidation.Mempool.mempoolAddCoins_empty_value' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms mempoolAddCoins_empty_value

/-- info: 'Bitcoin.TxValidation.Mempool.prevHeightData_mempool' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms prevHeightData_mempool

/-- info: 'Bitcoin.TxValidation.Mempool.prevHeightData_mempool_entry' depends on axioms: [propext] -/
#guard_msgs in #print axioms prevHeightData_mempool_entry

/-- info: 'Bitcoin.TxValidation.Mempool.mempoolAddCoins_prevHeightAtTip' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms mempoolAddCoins_prevHeightAtTip

/-- info: 'Bitcoin.TxValidation.Mempool.updateCoins_spend_removes' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms updateCoins_spend_removes

/-- info: 'Bitcoin.TxValidation.Mempool.inputsAvailable_false_of_spent' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms inputsAvailable_false_of_spent

/-- info: 'Bitcoin.TxValidation.Mempool.first_spender_wins' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms first_spender_wins

/-- info: 'Bitcoin.TxValidation.Mempool.updateCoins_added_coin_wins' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms updateCoins_added_coin_wins

/-- info: 'Bitcoin.TxValidation.Mempool.applyBlockU_cons_ok_step' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms applyBlockU_cons_ok_step

/-- info: 'Bitcoin.TxValidation.Mempool.inblock_output_spendable' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms inblock_output_spendable

/-- info: 'Bitcoin.TxValidation.Mempool.mempoolKey_no_witness_eq_txid' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms mempoolKey_no_witness_eq_txid

/-- info: 'Bitcoin.TxValidation.Mempool.mempoolKey_congr' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms mempoolKey_congr

end Pins

end Bitcoin.TxValidation.Mempool
