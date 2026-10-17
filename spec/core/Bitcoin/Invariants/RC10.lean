import Bitcoin.Chain.Basic
import Bitcoin.Data.Basic
import Bitcoin.Ledger.Interface
import Bitcoin.RuleAttr

/-!
# Bitcoin.Invariants.RC10

Rule-Closure suite contributor RC10 — INV-109..INV-120 (chain linkage + the
UTXO-transition data-model/serialization/undo/sentinel/state rows).
Ground truth: `research/05-core-inventory.md` Appendix B §B.8/§B.9,
Bitcoin Core v32.99 @ `cce32b168`. All theorems sorry-free; axiom pins at
the bottom.
-/

namespace Bitcoin.Invariants.RC10

open Bitcoin.Chain Bitcoin.Data Bitcoin.Ledger

/-! ## INV-109 — chain structure: prev-block-hash linkage -/

/-- `AcceptBlockHeader` (validation.cpp:4221–4231): a non-genesis header
must name its parent — `pindexPrev->GetBlockHash() == block.hashPrevBlock`
(surfaced as `bad-prevblk`; Capstone `badChainLink`). Genesis is exempt
(`hashPrevBlock = 0`). Executable byte-wise check over the header shape. -/
@[rule "INV-109"]
def chainLinkOk (prev : ByteArray) (h : BlockHeader) : Bool :=
  bytesBEq h.hashPrevBlock prev

/-- An accepted (linked) header really does point at its parent. -/
theorem chainLinkOk_eq (prev : ByteArray) (h : BlockHeader)
    (hok : chainLinkOk prev h = true) : h.hashPrevBlock = prev :=
  Bitcoin.Ledger.bytesBEq_eq_of_true _ _ hok

/-! ## INV-114 — Coin data model: spent ⇔ null out -/

/-- Spentness of an outpoint in the abstract UTXO set: `UtxoSet` is
`OutPoint → Option Coin` (Bitcoin.Ledger.Utxo), and `none` IS Core's
null-out coin (`Coin::IsSpent` / `coinEmpty`, coins.h:45–101). The `Coin`
record itself (value, height, coinbase bit, script) is
`Bitcoin.Ledger.Coin` — INV-114 stacked next to BLK-101 there. -/
@[rule "INV-114"]
def isSpent (u : UtxoSet) (o : OutPoint) : Bool := (u o).isNone

/-- TXV-075 (coins.h @cce32b168): `IsSpent() = out.IsNull()` — "Either
this coin never existed (see e.g. coinEmpty), or it did exist and has
been spent" = spent ⇔ absent-from-cache-or-spent-bit. -/
@[rule "TXV-075"]
theorem isSpent_iff (u : UtxoSet) (o : OutPoint) : isSpent u o = true ↔ u o = none := by
  refine ⟨fun hs => ?_, fun hn => ?_⟩
  · cases h : u o with
    | none => rfl
    | some c =>
      exfalso
      rw [isSpent, h] at hs
      simp at hs
  · rw [isSpent, hn]; rfl

/-! ### TXV-075 (cache tier): spent ⇔ absent-from-cache-or-spent-bit -/

/-- `CCoinsCacheEntry` (coins.h:157–173 @cce32b168): a cached `Coin`,
possibly nulled out (`Coin::Clear` — the "spent" bit), plus the
`FRESH`/`DIRTY` cache-flush bookkeeping flags. The read path treats both
flag values identically: a present entry shadows the parent view. -/
structure CacheEntry where
  /-- The cached coin; `none` is Core's nulled-out/spent coin. -/
  coin : Option Coin
  /-- `FRESH` (coins.h:163): the entry did not exist in the parent view. -/
  fresh : Bool
  /-- `DIRTY` (coins.h:167): the entry differs from the parent view. -/
  dirty : Bool

/-- `CCoinsViewCache::GetCoin` precedence (coins.cpp): a cache hit —
whatever its `FRESH`/`DIRTY` bits — returns the entry's coin (possibly
the null/spent coin); a miss falls through to the parent view. -/
@[rule "TXV-075"]
def cacheView (parent : UtxoSet) (cache : OutPoint → Option CacheEntry) : UtxoSet :=
  fun o =>
    match cache o with
    | some e => e.coin
    | none => parent o

/-- **TXV-075 (spent ⇔ absent-from-cache-or-spent-bit)**: in a chained
view, an outpoint is spent exactly when the cache holds an entry whose
coin has been nulled out (the "spent bit"), or when neither the cache
nor the parent view knows the outpoint (never existed — `coinEmpty`).
`FRESH`/`DIRTY` do not participate in the read. -/
@[rule "TXV-075"]
theorem cacheView_spent_iff (parent : UtxoSet)
    (cache : OutPoint → Option CacheEntry) (o : OutPoint) :
    isSpent (cacheView parent cache) o = true ↔
      (∃ e, cache o = some e ∧ e.coin = none) ∨
        (cache o = none ∧ parent o = none) := by
  unfold cacheView isSpent
  cases h : cache o with
  | none => simp [h]
  | some e =>
    cases hc : e.coin with
    | none => simp [h, hc]
    | some c => simp [h, hc]

/-- Byte-array equality is reflexive. -/
theorem bytesBEq_self (a : ByteArray) : bytesBEq a a = true := by
  unfold bytesBEq
  simp [List.all_eq_true]

/-- `OutPoint`'s `BEq` is reflexive (Data/Tx.lean:41). -/
theorem outPoint_beq_self (o : OutPoint) : (o == o) = true := by
  show (bytesBEq o.hash o.hash && o.n == o.n) = true
  rw [bytesBEq_self]
  simp

/-- A cache write of the null coin (Core `SpendCoin` → `Coin::Clear` →
entry `DIRTY`) shadows a live parent coin, i.e. it implements the spent
bit at the cache tier. -/
def cacheSpend (cache : OutPoint → Option CacheEntry) (o : OutPoint) :
    OutPoint → Option CacheEntry :=
  fun o' => if o' == o then some ⟨none, true, true⟩ else cache o'

/-- **TXV-075 (spent bit is written, not inferred from absence)**: after
`cacheSpend`, the outpoint reads as spent even when the parent view
still holds a coin for it. -/
@[rule "TXV-075"]
theorem cacheSpend_isSpent (parent : UtxoSet)
    (cache : OutPoint → Option CacheEntry) (o : OutPoint) :
    isSpent (cacheView parent (cacheSpend cache o)) o = true := by
  unfold isSpent cacheView cacheSpend
  simp [outPoint_beq_self]

/-- **TXV-075 (Undo restores on disconnect)**: disconnecting `tx`
(`undoCoins` over the `spentUndo` payload) restores the pre-state, hence
restores every spentness bit — the coins.h/validation.cpp
`ApplyTxInUndo` half of the row, stated on the RC10 `isSpent` face. -/
@[rule "TXV-075"]
theorem txv075_undo_restores_spent (u : UtxoSet) (tx : Tx) (key : Key)
    (height : UInt32)
    (h5 : ∀ q ∈ addedKeys tx key height,
      u q = none ∨ tx.vin.any (fun i => i.prevout == q) = true)
    (o : OutPoint) :
    isSpent (undoCoins (updateCoins u tx key height) (spentUndo u tx) tx key height) o
      = isSpent u o := by
  rw [updateCoins_undo u tx key height h5]

/-! ## INV-115 — serialization invariant: height 31 bits, coinbase 1 bit -/

/-- coins.h:77–89: the on-disk code word packs `nHeight : 31` and
`fCoinBase : 1` — `uint32_t code{(uint32_t{nHeight} << 1) | uint32_t{fCoinBase}}`
(Coin::Serialize, coins.h:86–89; VARINT-wrapped on the wire). -/
@[rule "INV-115"]
def coinMetaEncode (height : Nat) (coinbase : Bool) : Nat :=
  height * 2 + (if coinbase then 1 else 0)

/-- Coin::Unserialize (coins.h:92–96): `nHeight = code >> 1; fCoinBase = code & 1`. -/
def coinMetaDecode (code : Nat) : Nat × Bool :=
  (code / 2, code % 2 == 1)

theorem coinMetaDecode_encode (height : Nat) (coinbase : Bool) :
    coinMetaDecode (coinMetaEncode height coinbase) = (height, coinbase) := by
  unfold coinMetaEncode coinMetaDecode
  cases coinbase with
  | false =>
    have h1 : (height * 2 + 0) / 2 = height := by omega
    have h2 : (height * 2 + 0) % 2 = 0 := by omega
    show ((height * 2 + 0) / 2, (height * 2 + 0) % 2 == 1) = (height, false)
    rw [h1, h2]; rfl
  | true =>
    have h1 : (height * 2 + 1) / 2 = height := by omega
    have h2 : (height * 2 + 1) % 2 = 1 := by omega
    show ((height * 2 + 1) / 2, (height * 2 + 1) % 2 == 1) = (height, true)
    rw [h1, h2]; rfl

/-- The 31-bit height field: encodable heights stay inside `UInt32`. -/
theorem coinMetaEncode_lt (height : Nat) (coinbase : Bool) (hh : height < 2 ^ 31) :
    coinMetaEncode height coinbase < 2 ^ 32 := by
  cases coinbase with
  | false => show height * 2 + 0 < 2 ^ 32; omega
  | true => show height * 2 + 1 < 2 ^ 32; omega

/-- Build-time pins (decide): mainnet tip-era height, both coinbase bits. -/
example : coinMetaDecode (coinMetaEncode 840000 true) = (840000, true) := rfl
example : coinMetaDecode (coinMetaEncode 840000 false) = (840000, false) := rfl

/-! ## INV-118 — MEMPOOL_HEIGHT sentinel ≠ real height

The sentinel constant itself is `Bitcoin.Ledger.MEMPOOL_HEIGHT`
(0x7FFFFFFF, txmempool.h:51) — INV-118 stacked on that declaration
in W12's Interface.lean; X09's TXV-042 pins the mempool-side equality.
Here: the lockpoints rule + the ≠-real-height pin. -/

/-- validation.cpp:198–200 (`CalculateLockPointsAtTip`): a coin at the
sentinel height is assumed to confirm in the next block (tip + 1); a real
coin keeps its own height. -/
def prevHeightOrNext (coinHeight tipHeight : UInt32) : UInt32 :=
  if coinHeight = Bitcoin.Ledger.MEMPOOL_HEIGHT then tipHeight + 1 else coinHeight

theorem prevHeightOrNext_mempool (t : UInt32) :
    prevHeightOrNext Bitcoin.Ledger.MEMPOOL_HEIGHT t = t + 1 := by
  unfold prevHeightOrNext; simp

theorem prevHeightOrNext_real (h t : UInt32)
    (hne : h ≠ Bitcoin.Ledger.MEMPOOL_HEIGHT) :
    prevHeightOrNext h t = h := by
  unfold prevHeightOrNext
  split
  · next hb => exact absurd hb hne
  · rfl

/-- The sentinel is the maximum 31-bit value: no real (mainnet-feasible,
≤ 10⁶) block height can equal it. -/
theorem mempool_height_ne_real (h : UInt32) (hh : h.toNat ≤ 1000000) :
    h ≠ Bitcoin.Ledger.MEMPOOL_HEIGHT := by
  have hv : Bitcoin.Ledger.MEMPOOL_HEIGHT = 2147483647 := rfl
  have h2 : (2147483647 : UInt32).toNat = 2147483647 := rfl
  intro he
  rw [he, hv, h2] at hh
  omega

/-! ## INV-119 — UTXO-set snapshot hash (MuHash3072, abstracted) -/

/-- kernel/coinstats.cpp:59–66: the assumeutxo snapshot commitment hashes
each coin as `TxOutSer(outpoint, coin)` into a `MuHash3072` (commutative
multiset hash over the class group: Insert/Remove = multiply/divide by
`num ← num * n` mod 2³⁰⁷²). The consensus-relevant property the snapshot
predicate relies on is partition/order-invariance of the combination;
we pin that over an abstracted commutative monoid `(Nat, +)` with a
per-coin datum `cf`. The 3072-bit modular arithmetic itself is NOT
modeled (zero-FFI core; Review-4 bigint seam) — algebraic pin VERIFIED,
arithmetic PROPOSED. -/
@[rule "INV-119"]
def muhashSet (cf : Coin → Nat) (coins : List Coin) : Nat :=
  coins.foldr (fun c acc => cf c + acc) 0

/-- Combining a partition of the UTXO set equals combining the whole
(MuHash3072's group-law order-invariance, abstracted). -/
theorem muhashSet_append (cf : Coin → Nat) (a b : List Coin) :
    muhashSet cf (a ++ b) = muhashSet cf a + muhashSet cf b := by
  induction a with
  | nil => simp only [List.nil_append, muhashSet, List.foldr_nil, Nat.zero_add]
  | cons x r ih =>
    simp only [List.cons_append, muhashSet, List.foldr_cons]
    rw [show List.foldr (fun c acc => cf c + acc) 0 (r ++ b) =
      List.foldr (fun c acc => cf c + acc) 0 r
        + List.foldr (fun c acc => cf c + acc) 0 b from ih]
    exact (Nat.add_assoc _ _ _).symm

/-! ## INV-120 — best-block pointer tracks coins state -/

/-- `CCoinsViewCache`: the cached pair (coins view, best-block pointer)
(coins.h CCoinsView; SetBestBlock coins.cpp:196). -/
structure CoinsView where
  coins : UtxoSet
  bestBlock : ByteArray

/-- `CCoinsViewCache::SetBestBlock` (coins.cpp:196–199): re-point the
cache at the new block hash — the coin contents are untouched. -/
@[rule "INV-120"]
def setBestBlock (v : CoinsView) (h : ByteArray) : CoinsView :=
  { v with bestBlock := h }

theorem setBestBlock_coins (v : CoinsView) (h : ByteArray) :
    (setBestBlock v h).coins = v.coins := rfl

theorem setBestBlock_best (v : CoinsView) (h : ByteArray) :
    (setBestBlock v h).bestBlock = h := rfl

/-- `ConnectBlock`'s cache update (validation.cpp:2652 → SetBestBlock):
first apply the tx fold to the coins, THEN re-point at the connected
block's hash — the pointer tracks the coins state. -/
def connectBestBlock (v : CoinsView) (tx : Tx) (key : Key) (height : UInt32)
    (bh : ByteArray) : CoinsView :=
  setBestBlock { v with coins := updateCoins v.coins tx key height } bh

theorem connectBestBlock_coins (v : CoinsView) (tx : Tx) (key : Key) (height : UInt32)
    (bh : ByteArray) :
    (connectBestBlock v tx key height bh).coins = updateCoins v.coins tx key height := rfl

/-! ## Axiom footprints (`#guard_msgs in #print axioms`) -/

/-- info: 'Bitcoin.Invariants.RC10.chainLinkOk_eq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms chainLinkOk_eq

/-- info: 'Bitcoin.Invariants.RC10.isSpent_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms isSpent_iff

/-- info: 'Bitcoin.Invariants.RC10.bytesBEq_self' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms bytesBEq_self

/-- info: 'Bitcoin.Invariants.RC10.outPoint_beq_self' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms outPoint_beq_self

/-- info: 'Bitcoin.Invariants.RC10.cacheView_spent_iff' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms cacheView_spent_iff

/-- info: 'Bitcoin.Invariants.RC10.cacheSpend_isSpent' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms cacheSpend_isSpent

/-- info: 'Bitcoin.Invariants.RC10.txv075_undo_restores_spent' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms txv075_undo_restores_spent

/-- info: 'Bitcoin.Invariants.RC10.coinMetaDecode_encode' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms coinMetaDecode_encode

/-- info: 'Bitcoin.Invariants.RC10.coinMetaEncode_lt' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms coinMetaEncode_lt

/-- info: 'Bitcoin.Invariants.RC10.prevHeightOrNext_mempool' depends on axioms: [propext] -/
#guard_msgs in #print axioms prevHeightOrNext_mempool

/-- info: 'Bitcoin.Invariants.RC10.prevHeightOrNext_real' does not depend on any axioms -/
#guard_msgs in #print axioms prevHeightOrNext_real

/-- info: 'Bitcoin.Invariants.RC10.mempool_height_ne_real' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms mempool_height_ne_real

/-- info: 'Bitcoin.Invariants.RC10.muhashSet_append' depends on axioms: [propext] -/
#guard_msgs in #print axioms muhashSet_append

/-- info: 'Bitcoin.Invariants.RC10.setBestBlock_coins' does not depend on any axioms -/
#guard_msgs in #print axioms setBestBlock_coins

/-- info: 'Bitcoin.Invariants.RC10.setBestBlock_best' does not depend on any axioms -/
#guard_msgs in #print axioms setBestBlock_best

/-- info: 'Bitcoin.Invariants.RC10.connectBestBlock_coins' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms connectBestBlock_coins

end Bitcoin.Invariants.RC10
