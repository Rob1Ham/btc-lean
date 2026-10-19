import Bitcoin.Data.Basic
import Bitcoin.Data.Tx
import Bitcoin.DataLaws.Interface
import Bitcoin.Ledger.Utxo
import Bitcoin.TxValidation.Interface
import Bitcoin.Conservation.Interface

/-!
# Bitcoin.Ledger — FROZEN INTERFACE, bodies + theorem tier filled

## Interface contract (do not edit outside an interface-change PR)

Core counterpart files: src/coins.h (Coin, CCoinsView*), src/coins.cpp
                        (BatchWrite — a perf artifact, not modeled),
                        src/validation.cpp (UpdateCoins:1998, ConnectBlock
                        :2294 coinbase/maturity/BIP30, DisconnectBlock
                        :2178), src/coins.cpp:AddCoin:82 (OP_RETURN
                        early-return — unspendables NOT stored)
Status: frozen 2026-10-16; bodies + theorems
                        filled 2026-10-16. Two SANCTIONED statement
                        changes (the interface conventions, `hle` precedent):

  1. `applyBlock` returns `Except BlockError UtxoSet` — the block-level
     checks (BIP30 `bad-txns-BIP30`, `bad-cb-missing`, `bad-cb-multiple`)
     live in ConnectBlock, not in any single-tx check, so the frozen
     `TxError` cannot express them. Per-tx failures still carry the
     exact `TxError` (`BlockError.txError e`). Interface-change proposal
     filed: absorb `badTxnsBIP30` into `TxError`.
  2. `applyBlock_no_double_spend` restated in freshness form: the frozen
     "each outpoint spent by ≤ 1 tx" form is REFUTABLE — a tx that spends
     an outpoint whose txid-preimage a later tx in the same block
     re-creates lets a third tx spend the re-created coin (Core accepts
     such blocks; BIP30's per-tx check passes because the first spend
     removed the coin). See the theorem comment for the scenario.

## Scope

The UTXO decision is implemented: abstract `UtxoSet := OutPoint → Option
Coin` for theorems; assoc-list executable instance in
`Bitcoin.Ledger.AssocList` (HashMap later — instances are NOT switched
in this module). `updateCoins` as a total function; `applyBlock` as the
explicit sequential fold (the same-block spend ordering — the one
mutation-load-bearing behavior, B3); BIP30 carve-outs (91842/91880 +
disconnect pair 91722/91812 + BIP34_IMPLIES_BIP30_LIMIT = 1,983,702);
coinbase maturity at apply time; OP_RETURN outputs never inserted;
genesis = EMPTY Utxo set (validation.cpp:2330-2334).

Keying: `applyBlock` keys new coins by `txidPreimageKey` = the base
serialization `serTx tx` (serialization-backed, real, computable).
`DataLaws.txid = sha256d (serTx tx)` carries the `sha256d` opaque
stub (sorryAx by dependency) — keying by it would taint every theorem
here with sorryAx, so the hash is applied at the seam, not inside
the ledger. Swapping `txidPreimageKey` to txid is a one-line change when
the hash floor lands; every theorem below is key-generic.
-/

namespace Bitcoin.Ledger

open Bitcoin.Data Bitcoin.Conservation Bitcoin.TxValidation

/-! ## Constants (the frozen surface; moved here from the stub file so
the BIP30 predicate below can use them — same namespace, same names) -/

/-- Mempool coins sentinel (`coins.h`: MEMPOOL_HEIGHT = 0x7FFFFFFF). -/
@[rule "INV-118"]
def MEMPOOL_HEIGHT : UInt32 := 0x7FFFFFFF

/-- BIP30 repeat-exception blocks (validation.cpp:IsBIP30Repeat:6207). -/
def BIP30_DUPLICATE_COINBASE_HEIGHTS : List UInt32 := [91842, 91880]

/-- BIP30 disconnect-relaxation pair
(validation.cpp:IsBIP30Unspendable:6213; rule BLK-099). -/
def BIP30_DISCONNECT_HEIGHTS : List UInt32 := [91722, 91812]

/-- BIP34 activation height (chainparams.cpp: BIP34Height). -/
def BIP34_HEIGHT : UInt32 := 227931

/-- From here BIP30 is enforced unconditionally again
(validation.cpp:BIP34_IMPLIES_BIP30_LIMIT = 1983702). -/
def BIP34_IMPLIES_BIP30_LIMIT : UInt32 := 1983702

/-! ## The model -/

/-- The injected key function (frozen `updateCoins` seam): builds the
outpoint of output `k`. The canonical instance ignores the first
argument; it is kept so the fold is provable key-generically. -/
abbrev Key := OutPoint → UInt32 → OutPoint

/-- Canonical key pending the hash floor: the txid *preimage* (the base
serialization-backed). -/
def txidPreimageKey (tx : Tx) : Key := fun _ k => ⟨serTx tx, k⟩

/-- `MAX_SCRIPT_SIZE` (script.h; Core consensus constant). -/
def MAX_SCRIPT_SIZE : Nat := 10000

/-- `CScript::IsUnspendable()` (script.h:566): OP_RETURN-prefixed or
larger than MAX_SCRIPT_SIZE. -/
@[rule "INV-112", rule "BLK-094", rule "SCR-070"]
def scriptUnspendable (s : Script) : Bool :=
  (s.bytes.size > 0 && s.bytes.get! 0 == 0x6a) || s.bytes.size > MAX_SCRIPT_SIZE

/-- Coins added by `tx` (coins.cpp:AddCoins:133-142): one entry per
non-unspendable output, keyed by `key`, carrying the connection `height`
and the coinbase bit (coins.h:45-72 — `fCoinBase:1` in the height's LSB
on disk; modeled as an explicit field, the data-model half of INV-115).
Unspendable outputs are never inserted (AddCoin's early return,
coins.cpp:82 — INV-112). BLK-093: OP_RETURN outputs are never stored. -/
@[rule "BLK-093"]
def addedCoins (tx : Tx) (key : Key) (height : UInt32) : List (OutPoint × Coin) :=
  (List.range tx.vout.length).filterMap (fun k =>
    let o := tx.vout.getD k ⟨0, Script.empty⟩
    if scriptUnspendable o.scriptPubKey then none
    else some (key OutPoint.null (UInt32.ofNat k),
               ⟨o.value, height, tx.isCoinBase, o.scriptPubKey⟩))

/-- Keys of `addedCoins`. -/
def addedKeys (tx : Tx) (key : Key) (height : UInt32) : List OutPoint :=
  (addedCoins tx key height).map (fun p => p.1)

/-- Association-list lookup (the executable instance's read path;
first match wins — same as `List.find?`). -/
def coinLookup : List (OutPoint × Coin) → OutPoint → Option Coin
  | [], _ => none
  | (o', c) :: r, o => if o' == o then some c else coinLookup r o

/-- `UpdateCoins` for one tx (validation.cpp:1998-2011), as a TOTAL
function (Voskuil: spending = a total, explicit relation; the *checks*
live in `applyTxStep`). Pointwise semantics:
  * an output's coin, if added, wins (Core: SpendCoin-all, then
    AddCoins — last write wins);
  * otherwise a spent prevout's coin is removed (`SpendCoin`) — the
    removal loop is skipped entirely for the coinbase, whose single
    input has the null prevout and is never looked up (INV-110:
    "spend all inputs exactly once, coinbase exempt");
  * everything else is preserved.
Theorems quantify over `u` and `key` — the abstraction discipline. -/
@[rule "INV-110", rule "INV-111", rule "INV-113"]
def updateCoins (u : UtxoSet) (tx : Tx) (key : Key) (height : UInt32) : UtxoSet :=
  fun o =>
    match coinLookup (addedCoins tx key height) o with
    | some c => some c
    | none =>
      if tx.isCoinBase then u o
      else if tx.vin.any (fun i => i.prevout == o) then none
      else u o

/-! ## Executable tier: the assoc-list fold (the ledger layer)

The theorems quantify over the point (`UtxoSet`); the executable spec
runs the SAME fold over the assoc list (`UtxoList`). The abstraction
lemma `updateCoinsL_abstract` ties the two — the abstraction discipline, kept. -/

/-- Byte-wise equality is real equality (needed to reason about the
`BEq OutPoint` instance inside the abstraction lemma). -/
theorem bytesBEq_eq_of_true (a b : ByteArray) (h : bytesBEq a b = true) : a = b := by
  simp only [bytesBEq, decide_eq_true_eq] at h
  obtain ⟨hsz, hall⟩ := h
  refine ByteArray.ext (Array.ext hsz (fun i h1 h2 => ?_))
  have hget2 : a.get! i = b.get! i := by
    have hm : i ∈ List.range a.size := List.mem_range.mpr h1
    exact eq_of_beq (List.all_eq_true.mp hall i hm)
  rw [show a.data[i] = a.get! i from by rw [← getElem!_pos a.data i h1]; rfl,
      show b.data[i] = b.get! i from by rw [← getElem!_pos b.data i h2]; rfl]
  exact hget2

theorem outPointBEq_eq (a b : OutPoint) (h : (a == b) = true) : a = b := by
  have h0 : (a == b) = (bytesBEq a.hash b.hash && a.n == b.n) := rfl
  rw [h0, Bool.and_eq_true] at h
  obtain ⟨h1, h2⟩ := h
  have he1 := bytesBEq_eq_of_true _ _ h1
  have he2 : a.n = b.n := eq_of_beq h2
  have ha : a = OutPoint.mk a.hash a.n := rfl
  have hb : b = OutPoint.mk b.hash b.n := rfl
  rw [ha, hb, he1, he2]

/-- The abstraction map: assoc list → point (the UTXO decision). -/
def viewOf (l : List (OutPoint × Coin)) : UtxoSet := fun o => coinLookup l o

/-- Executable `updateCoins`: prepend `tx`'s non-unspendable output
coins (coins.cpp:AddCoins), drop spent prevouts (SpendCoin; the removal
loop is skipped for the coinbase — INV-110). New coins precede old
ones, so an (unvalidated) collision resolves "new wins" — exactly the
pointwise `updateCoins` above. -/
@[rule "BLK-092", rule "BLK-095"]
def updateCoinsL (l : List (OutPoint × Coin)) (tx : Tx) (key : Key) (height : UInt32) :
    List (OutPoint × Coin) :=
  addedCoins tx key height ++
    l.filter (fun p => tx.isCoinBase || !(tx.vin.any (fun i => i.prevout == p.1)))

theorem coinLookup_append (a b : List (OutPoint × Coin)) (o : OutPoint) :
    coinLookup (a ++ b) o =
      match coinLookup a o with
      | some c => some c
      | none => coinLookup b o := by
  induction a with
  | nil => rfl
  | cons q r ih =>
    simp only [List.cons_append, coinLookup]
    cases hq : (q.1 == o) with
    | true => simp
    | false => simp [ih]

theorem coinLookup_filter_kept (l : List (OutPoint × Coin))
    (keep : OutPoint × Coin → Bool) (o : OutPoint)
    (h : ∀ p ∈ l, (p.1 == o) = true → keep p = true) :
    coinLookup (l.filter keep) o = coinLookup l o := by
  induction l with
  | nil => rfl
  | cons q r ih =>
    obtain ⟨o', c⟩ := q
    cases hbq : (o' == o) with
    | true =>
      have hk : keep ⟨o', c⟩ = true := h _ (List.mem_cons.mpr (Or.inl rfl)) hbq
      rw [List.filter_cons_of_pos hk]
      simp only [coinLookup]
      rw [if_pos hbq, if_pos hbq]
    | false =>
      have hnt : ¬((o' == o) = true) := by rw [hbq]; simp
      cases hkq : keep ⟨o', c⟩ with
      | true =>
        rw [List.filter_cons_of_pos hkq]
        simp only [coinLookup]
        rw [if_neg hnt, if_neg hnt]
        exact ih (fun p hp hpo => h p (List.mem_cons.mpr (Or.inr hp)) hpo)
      | false =>
        rw [List.filter_cons_of_neg (by simp [hkq])]
        simp only [coinLookup]
        rw [if_neg hnt]
        exact ih (fun p hp hpo => h p (List.mem_cons.mpr (Or.inr hp)) hpo)

theorem coinLookup_filter_none (l : List (OutPoint × Coin))
    (keep : OutPoint × Coin → Bool) (o : OutPoint)
    (h : ∀ p ∈ l, (p.1 == o) = true → keep p = false) :
    coinLookup (l.filter keep) o = none := by
  induction l with
  | nil => rfl
  | cons q r ih =>
    obtain ⟨o', c⟩ := q
    cases hbq : (o' == o) with
    | true =>
      have hk : keep ⟨o', c⟩ = false := h _ (List.mem_cons.mpr (Or.inl rfl)) hbq
      rw [List.filter_cons_of_neg (by simp [hk])]
      exact ih (fun p hp hpo => h p (List.mem_cons.mpr (Or.inr hp)) hpo)
    | false =>
      have hnt : ¬((o' == o) = true) := by rw [hbq]; simp
      cases hkq : keep ⟨o', c⟩ with
      | true =>
        rw [List.filter_cons_of_pos hkq]
        simp only [coinLookup]
        rw [if_neg hnt]
        exact ih (fun p hp hpo => h p (List.mem_cons.mpr (Or.inr hp)) hpo)
      | false =>
        rw [List.filter_cons_of_neg (by simp [hkq])]
        exact ih (fun p hp hpo => h p (List.mem_cons.mpr (Or.inr hp)) hpo)

/-- `List.any p = true` yields a witness (dual of `listAny_false`). -/
theorem listAny_true_mem {α : Type _} (p : α → Bool) :
    (l : List α) → l.any p = true → ∃ x ∈ l, p x = true
  | [], h => by simp at h
  | b :: r, h => by
      simp only [List.any_cons] at h
      cases hb : p b with
      | true => exact ⟨b, List.mem_cons.mpr (Or.inl rfl), hb⟩
      | false =>
        rw [hb] at h
        simp only [Bool.false_or] at h
        obtain ⟨x, hx, hpx⟩ := listAny_true_mem p r h
        exact ⟨x, List.mem_cons.mpr (Or.inr hx), hpx⟩

/-- THE ABSTRACTION LEMMA (the executable tier): lookup over the updated list computes the
pointwise `updateCoins`. Everything downstream (the block fold, THM-037,
no-double-spend) is stated over the point and transferred through this. -/
theorem updateCoinsL_abstract (l : List (OutPoint × Coin)) (tx : Tx) (key : Key) (height : UInt32) :
    viewOf (updateCoinsL l tx key height) = updateCoins (viewOf l) tx key height := by
  funext o
  unfold updateCoinsL viewOf updateCoins
  rw [coinLookup_append]
  cases ha : coinLookup (addedCoins tx key height) o with
  | some c => rfl
  | none =>
    dsimp only
    by_cases hcb : tx.isCoinBase = true
    · rw [if_pos hcb]
      simp only [hcb, Bool.true_or]
      rw [List.filter_eq_self.mpr (fun _ _ => rfl)]
    · rw [if_neg hcb]
      simp only [hcb, Bool.false_or]
      by_cases hv : (tx.vin.any fun i => i.prevout == o) = true
      · rw [if_pos hv]
        refine coinLookup_filter_none l _ o (fun p _ hp => ?_)
        have hpio : p.1 = o := outPointBEq_eq _ _ hp
        have hany : tx.vin.any (fun i => i.prevout == p.1) = true := by
          rw [hpio]; exact hv
        simp [hcb, hany]
      · rw [if_neg hv]
        refine coinLookup_filter_kept l _ o (fun p _ hp => ?_)
        have hpio : p.1 = o := outPointBEq_eq _ _ hp
        have hany : tx.vin.any (fun i => i.prevout == p.1) = false := by
          rw [hpio]; exact Bool.eq_false_iff.mpr hv
        simp [hcb, hany]

/-! ## Block-level checks (ConnectBlock's UTXO-side per-tx gates) -/

/-- Block-level error: per-tx failures keep the transaction-validation layer's exact `TxError`;
ConnectBlock-only failures get their own constructors (ownership block,
sanctioned change #1). -/
inductive BlockError : Type where
  | txError (e : TxError)
  | badTxnsBIP30        -- "bad-txns-BIP30" (validation.cpp:2496-2511)
  | badCbMissing        -- "bad-cb-missing"   (ConnectBlock:2540-2545)
  | badCbMultiple       -- "bad-cb-multiple"
deriving Repr, DecidableEq, BEq

/-- `HaveInputs` (coins.cpp:322-331): every prevout of a non-coinbase
tx names an existing coin. -/
def inputsAvailable (u : UtxoSet) (tx : Tx) : Bool :=
  tx.vin.all (fun i => (u i.prevout).isSome)

/-- Coinbase maturity at apply time (tx_verify.cpp:185-188; BLK-100 /
INV-028): a coinbase coin may be spent only when
`spendHeight − coinHeight ≥ COINBASE_MATURITY = 100`. Comparisons in
`Nat` (heights are 31-bit in the Coin — no UInt32-overflow corners). -/
@[rule "INV-028", rule "BLK-100"]
def maturityOk (u : UtxoSet) (tx : Tx) (height : UInt32) : Bool :=
  tx.vin.all (fun i =>
    match u i.prevout with
    | none => true   -- availability is a separate check (Core checks it first)
    | some c => !c.isCoinbase ||
                  c.height.toNat + COINBASE_MATURITY.toNat ≤ height.toNat)

/-- BIP30 enforcement predicate (BLK-096/097/098): enforced unless the
block is one of the two historical duplicate-coinbase blocks, and not
in the BIP34 window (227931 < h < 1983702) where duplicates are
impossible by construction; `BIP34_IMPLIES_BIP30_LIMIT` re-enables the
check wholesale. The BIP34-window *hash pin* (the chain's block@227931
= BIP34Hash) is a chain-level canonicality condition abstracted here —
see report §"BIP30 modeling".

FIX D2a (2026-10-17; was `BIP34_HEIGHT ≤ height`, i.e. the elide-window
[227931, 1983702)): Core @cce32b168 validation.cpp:2458-2461 computes
`pindexBIP34height = pindex->pprev->GetAncestor(BIP34Height)` — on the
height-227930 parent this is null, so 2461's second conjunct is VACUOUS
at h = 227931 and Core ENFORCES BIP30 there (the loop-gate 2466
`fEnforceBIP30 || h ≥ 1983702` is ON). The skip window proper is
(227931, 1983702) — Core's null-ancestor reading makes 227931 the LAST
BIP30-ON height, not the first elided one. Fixed heights-only, exactly
the D2a divergence (CV07 D2a / the block-vector module / CT02 V2). This is the CANONICAL-CHAIN face: D2b
(227932..1983701 non-canonical-branch hash-pin) and D2c (91842/91880
own-hash-pins) are modeled by `bip30EnforcedAt` below, of which this is
the canonical specialization (`bip30EnforcedAt_canonical`). -/
@[rule "BLK-096", rule "BLK-097", rule "BLK-098", rule "INV-104"]
def bip30Enforced (height : UInt32) : Bool :=
  !(BIP30_DUPLICATE_COINBASE_HEIGHTS.contains height) &&
  !(BIP34_HEIGHT < height && height < BIP34_IMPLIES_BIP30_LIMIT)

/-- Chain-context BIP30 gate (D2b + D2c): Core
validation.cpp:2401/2458-2461/2466 --
`fEnforceBIP30 = !IsBIP30Repeat(*pindex) && !(pindexBIP34height &&
pindexBIP34height->GetBlockHash() == BIP34Hash)` and the 2466 overlap
loop runs iff `fEnforceBIP30 || nHeight >= BIP34_IMPLIES_BIP30_LIMIT`.
`repeatExceptionOk` = the block IS one of the two OWN-HASH-pinned
repeats (D2c: 91842/91880; heights alone are NOT enough — a fork block
at those heights is still enforced); `bip34AncestorOk` = the ancestor
at BIP34Height is the canonical BIP34 block (D2b: inside 227932..1983701
a non-canonical ancestor re-enables the loop). `bip30Enforced` is the
canonical-chain specialization (`repeatExceptionOk = contains height`,
`bip34AncestorOk = true`). -/
@[rule "BLK-096", rule "BLK-098", rule "INV-104"]
def bip30EnforcedAt (height : UInt32) (repeatExceptionOk : Bool)
    (bip34AncestorOk : Bool) : Bool :=
  !repeatExceptionOk &&
  !(BIP34_HEIGHT < height && height < BIP34_IMPLIES_BIP30_LIMIT && bip34AncestorOk)

/-- The canonical-chain face: `bip30EnforcedAt` at
`repeatExceptionOk = BIP30_DUPLICATE_COINBASE_HEIGHTS.contains height`
and `bip34AncestorOk = true` IS the heights-only `bip30Enforced`. -/
theorem bip30EnforcedAt_canonical (height : UInt32) :
    bip30EnforcedAt height (BIP30_DUPLICATE_COINBASE_HEIGHTS.contains height) true =
      bip30Enforced height := by
  unfold bip30EnforcedAt bip30Enforced
  simp

/-- Core `IsBIP30Repeat` own-hash pin @91842 (validation.cpp:6205-6210;
kernel/chainparams.cpp). `bip30EnforcedAt` takes the resulting predicate
as a Bool; these constants make the pin explicit at the Ledger face. -/
def BIP30_REPEAT_HASH_91842 : Nat :=
  0x00000000000a4d0a398161ffc163c503763b1f4360639393e0e4c8e300e0caec

/-- Core `IsBIP30Repeat` own-hash pin @91880. -/
def BIP30_REPEAT_HASH_91880 : Nat :=
  0x00000000000743f190a18c5577a3c2d2a1f610ae9601ac046a38084ccb7cd721

/-- Core `BIP34Hash` (kernel/chainparams.cpp:119; the ancestor at
`BIP34_HEIGHT` whose hash elides the BIP30 loop, D2b). -/
def BIP34_ACTIVATION_HASH : Nat :=
  0x000000000000024b89b42a942fe0d9fea3bb44ab7bd1b19115dd6a759c0808b8

/-- The own hash of the canonical repeat block at `height` (0 elsewhere). -/
def BIP30_REPEAT_HASH_OF_HEIGHT (height : UInt32) : Nat :=
  if height = 91842 then BIP30_REPEAT_HASH_91842
  else if height = 91880 then BIP30_REPEAT_HASH_91880 else 0

/-- D2c, exactly Core: the block is a repeat only at 91842/91880 AND with
that height's own hash (`IsBIP30Repeat`, validation.cpp:6205-6210). -/
def bip30OwnHashPinned (height : UInt32) (ownHash : Nat) : Bool :=
  (height = 91842 && ownHash = BIP30_REPEAT_HASH_91842) ||
  (height = 91880 && ownHash = BIP30_REPEAT_HASH_91880)

/-- D2b, exactly Core 2460-2461: the ancestor at `BIP34_HEIGHT` exists
(`BIP34_HEIGHT < height`) and its hash is `BIP34Hash`. -/
def bip34AncestorPinned (height : UInt32) (ancestorHash : Nat) : Bool :=
  BIP34_HEIGHT < height && ancestorHash = BIP34_ACTIVATION_HASH

/-- Hash-typed BIP30 gate: `bip30EnforcedAt` with the own-hash repeat pin
(D2c) and the BIP34 ancestor-hash window pin (D2b) discharged from the
actual hashes. Exactly Core validation.cpp:2401/2458-2461/2466. -/
@[rule "BLK-096", rule "BLK-098", rule "INV-104"]
def bip30EnforcedAtHashes (height : UInt32) (ownHash ancestorHash : Nat) : Bool :=
  !bip30OwnHashPinned height ownHash &&
  !(BIP34_HEIGHT < height && height < BIP34_IMPLIES_BIP30_LIMIT &&
    bip34AncestorPinned height ancestorHash)

/-- The Bool-context `bip30EnforcedAt` IS this hash-typed gate at the
discharged pins (definitional). -/
theorem bip30EnforcedAtHashes_eq (height : UInt32) (ownHash ancestorHash : Nat) :
    bip30EnforcedAtHashes height ownHash ancestorHash =
      bip30EnforcedAt height (bip30OwnHashPinned height ownHash)
        (bip34AncestorPinned height ancestorHash) := rfl

/-- On the canonical chain the height's own hash is the pinned repeat hash
at 91842/91880 and nothing else. -/
theorem bip30OwnHashPinned_canonical (height : UInt32) :
    bip30OwnHashPinned height (BIP30_REPEAT_HASH_OF_HEIGHT height) =
      BIP30_DUPLICATE_COINBASE_HEIGHTS.contains height := by
  unfold bip30OwnHashPinned BIP30_REPEAT_HASH_OF_HEIGHT
    BIP30_DUPLICATE_COINBASE_HEIGHTS
  by_cases h1 : height = 91842
  · subst h1; simp
  · by_cases h2 : height = 91880
    · subst h2; simp [h1]
    · simp [h1, h2]

/-- Canonical-chain specialization: the hash-typed gate at the canonical
own hash and `BIP34Hash` is the heights-only `bip30Enforced`. -/
theorem bip30EnforcedAtHashes_canonical (height : UInt32) :
    bip30EnforcedAtHashes height (BIP30_REPEAT_HASH_OF_HEIGHT height)
        BIP34_ACTIVATION_HASH = bip30Enforced height := by
  rw [bip30EnforcedAtHashes_eq, bip30OwnHashPinned_canonical]
  by_cases hb : BIP34_HEIGHT < height
  · have hanc : bip34AncestorPinned height BIP34_ACTIVATION_HASH = true := by
      simp [bip34AncestorPinned, hb]
    rw [hanc]
    exact bip30EnforcedAt_canonical height
  · have hanc : bip34AncestorPinned height BIP34_ACTIVATION_HASH = false := by
      simp [bip34AncestorPinned, hb]
    rw [hanc]
    simp [bip30EnforcedAt, bip30Enforced, hb]

/-- BIP30 duplicate check (validation.cpp:2466-2475): some output of
`tx` — over EVERY vout index, unfiltered — lands on an outpoint
already in the view (`(u op).isSome` = Core's `HaveCoin`,
spent = none = INV-114).

FIX D4c-1 — the first half of the atomic D4c-1+D4c-2 pair —
was `(addedCoins tx key height).any ...` —
unspendable-SKIPPED (via addedCoins' AddCoin filter), Core's loop
2467-2471 is over ALL `tx.vout` with NO unspendable skip. Fixed to
the unfiltered `List.range tx.vout.length` shape =
`bip30OverlapPristine`'s inner (Bip30Nuance §2). The second half
(D4c-2) moves the CALL SITE: Core runs this check ONCE pre-block on
the PRISTINE view (the `bip30BlockCollision` gate), not per-tx in
the fold — D4c-2 lands as the immediate next decls; the BIP30 row set's D4c
witnesses flip when both halves are in. `height` is the unused
loop-gate context (kept for the def's signature stability). -/
@[rule "INV-104"]
def bip30Collision (u : UtxoSet) (tx : Tx) (key : Key) (height : UInt32) : Bool :=
  (List.range tx.vout.length).any (fun o =>
    (u (key OutPoint.null (UInt32.ofNat o))).isSome)

/-- Core 2466-2475 verbatim shape: some output of some tx of the
block (keyed `kf` per-tx, Core's `COutPoint(tx->GetId(), o)`) lands
on an outpoint already in the PRE-BLOCK (pristine) view `u` — the
loop Core runs ONCE per block, BEFORE the per-tx ConnectBlock fold
(~2519). FIX D4c-2 — the second half of the atomic D4c-1+D4c-2 pair —
`bip30Collision` was called per-tx INSIDE the fold
on the EVOLVING view; Core 2466-2475 calls it pre-block on the
pristine view. This def is the collision loop; `applyBlockU/L`
become the `badTxnsBIP30`-gated wrappers (next decls), and
`applyTxStepU/L` lose the inline BIP30 branch. Height threads the
unused loop-gate context (2466), matching `bip30Collision`. -/
def bip30BlockCollision (u : UtxoSet) (kf : Tx → Key) :
    List Tx → UInt32 → Bool
  | [], _ => false
  | tx :: rest, height =>
    bip30Collision u tx (kf tx) height || bip30BlockCollision u kf rest height

/-! ## The block fold (the ledger layer): one tx step + the sequential fold

`applyTxStep` = ConnectBlock's per-tx UTXO side, in Core's check order
(ConnectBlock loop → `CheckTxInputs` gates → `UpdateCoins`): inputs
available (HaveInputs), coinbase maturity, then the total
`updateCoins`. Coinbase txs skip the input checks (their single input
is the null prevout, never looked up — INV-110).

FIX D4c-2 — the second half of the atomic D4c-1+D4c-2 pair —
the BIP30 duplicate branch is REMOVED from
`applyTxStepU/L` — Core runs the duplicate-coinbase check ONCE per
block (validation.cpp:2466-2475) on the PRISTINE pre-block view
BEFORE the per-tx ConnectBlock fold (~2519), never per-tx inside the
fold on the evolving view. The branch now lives in `applyBlockU/L`
as the pre-loop `bip30BlockCollision`-gated `badTxnsBIP30` error. -/

/-- One step over the point (post-D4c-2: NO BIP30 branch — the
duplicate check is the block-level pre-loop gate in `applyBlockU`). -/
def applyTxStepU (u : UtxoSet) (tx : Tx) (key : Key) (height : UInt32) :
    Except BlockError UtxoSet :=
  if tx.isCoinBase then
    Except.ok (updateCoins u tx key height)
  else if !inputsAvailable u tx then
    Except.error (BlockError.txError TxError.badTxnsInputsMissingOrSpent)
  else if !maturityOk u tx height then
    Except.error (BlockError.txError TxError.badTxnsPrematureSpendOfCoinbase)
  else
    Except.ok (updateCoins u tx key height)

/-- One step over the assoc list (post-D4c-2: NO BIP30 branch — the
duplicate check is the block-level pre-loop gate in `applyBlockL`). -/
def applyTxStepL (l : List (OutPoint × Coin)) (tx : Tx) (key : Key) (height : UInt32) :
    Except BlockError (List (OutPoint × Coin)) :=
  if tx.isCoinBase then
    Except.ok (updateCoinsL l tx key height)
  else if !inputsAvailable (viewOf l) tx then
    Except.error (BlockError.txError TxError.badTxnsInputsMissingOrSpent)
  else if !maturityOk (viewOf l) tx height then
    Except.error (BlockError.txError TxError.badTxnsPrematureSpendOfCoinbase)
  else
    Except.ok (updateCoinsL l tx key height)

/-- `applyBlock`'s fold over the point: the SEQUENTIAL fold — tx i + 1
sees the UTXO set after tx i (B3: same-block spend ordering, the one
mutation-load-bearing order in the pipeline). Post-D4c-2 this is the
BIP30-free inner fold; `applyBlockU` is its pre-loop-gated wrapper. -/
def applyBlockFoldU (u : UtxoSet) (kf : Tx → Key) :
    List Tx → UInt32 → Except BlockError UtxoSet
  | [], _ => Except.ok u
  | tx :: rest, height =>
    (applyTxStepU u tx (kf tx) height).bind
      (fun u' => applyBlockFoldU u' kf rest height)

/-- `applyBlock`'s fold over the assoc list (the executable
instance). Post-D4c-2: the BIP30-free inner fold; `applyBlockL` is
its pre-loop-gated wrapper. -/
def applyBlockFoldL (l : List (OutPoint × Coin)) (kf : Tx → Key) :
    List Tx → UInt32 → Except BlockError (List (OutPoint × Coin))
  | [], _ => Except.ok l
  | tx :: rest, height =>
    (applyTxStepL l tx (kf tx) height).bind
      (fun l' => applyBlockFoldL l' kf rest height)

/-- `applyBlock` over the point, post-D4c-2 = Core's shape: the BIP30
duplicate-coinbase loop (2466-2475) runs ONCE, PRE-BLOCK, on the
PRISTINE view `u` (gated by `bip30Enforced`, 2466) and rejects the
whole block with `bad-txns-BIP30` BEFORE the sequential per-tx fold
(`applyBlockFoldU`). Was (pre-D4c-2): the bare sequential fold with
the BIP30 branch inlined per-tx in `applyTxStepU` — the D4c divergence
(Core = pre-block pristine ONCE; ours =
per-tx evolving). -/
def applyBlockU (u : UtxoSet) (kf : Tx → Key) (txs : List Tx) (height : UInt32) :
    Except BlockError UtxoSet :=
  if bip30BlockCollision u kf txs height && bip30Enforced height then
    Except.error BlockError.badTxnsBIP30
  else applyBlockFoldU u kf txs height

/-- `applyBlock` over the assoc list (the executable instance),
post-D4c-2 = the L-mirror of `applyBlockU`: the same pre-loop
BIP30 gate (2466-2475, pristine `viewOf l`, ONCE) in front of
`applyBlockFoldL`. -/
def applyBlockL (l : List (OutPoint × Coin)) (kf : Tx → Key) (txs : List Tx) (height : UInt32) :
    Except BlockError (List (OutPoint × Coin)) :=
  if bip30BlockCollision (viewOf l) kf txs height && bip30Enforced height then
    Except.error BlockError.badTxnsBIP30
  else applyBlockFoldL l kf txs height

/-- Hash-aware pre-loop BIP30 gate over the point view: the same pristine
collision loop as `applyBlockU`, but the enforcement decision is Core's
actual `bip30EnforcedAtHashes` (own-hash repeat pins + BIP34 ancestor pin)
rather than the canonical-chain height approximation. -/
def applyBlockExactU (u : UtxoSet) (kf : Tx → Key) (txs : List Tx) (height : UInt32)
    (ownHash ancestorHash : Nat) : Except BlockError UtxoSet :=
  if bip30BlockCollision u kf txs height &&
      bip30EnforcedAtHashes height ownHash ancestorHash then
    Except.error BlockError.badTxnsBIP30
  else applyBlockFoldU u kf txs height

/-- Hash-aware pre-loop BIP30 gate over the executable assoc-list view. -/
def applyBlockExactL (l : List (OutPoint × Coin)) (kf : Tx → Key) (txs : List Tx)
    (height : UInt32) (ownHash ancestorHash : Nat) :
    Except BlockError (List (OutPoint × Coin)) :=
  if bip30BlockCollision (viewOf l) kf txs height &&
      bip30EnforcedAtHashes height ownHash ancestorHash then
    Except.error BlockError.badTxnsBIP30
  else applyBlockFoldL l kf txs height

/-- On the canonical chain, the hash-aware gate at the height's pinned own
hash and `BIP34Hash` is exactly the heights-only gate, so the exact fold
specializes to `applyBlockU`. -/
theorem applyBlockExactU_canonical (u : UtxoSet) (kf : Tx → Key) (txs : List Tx)
    (height : UInt32) :
    applyBlockExactU u kf txs height (BIP30_REPEAT_HASH_OF_HEIGHT height)
        BIP34_ACTIVATION_HASH = applyBlockU u kf txs height := by
  unfold applyBlockExactU applyBlockU
  rw [bip30EnforcedAtHashes_canonical]

/-- Executable mirror of `applyBlockExactU_canonical`. -/
theorem applyBlockExactL_canonical (l : List (OutPoint × Coin)) (kf : Tx → Key)
    (txs : List Tx) (height : UInt32) :
    applyBlockExactL l kf txs height (BIP30_REPEAT_HASH_OF_HEIGHT height)
        BIP34_ACTIVATION_HASH = applyBlockL l kf txs height := by
  unfold applyBlockExactL applyBlockL
  rw [bip30EnforcedAtHashes_canonical]

/-- The exact gate rejects a pristine collision whenever the hash-aware
enforcement bit is on. This is the fork-side counterpart of the canonical
specialization above: a non-canonical block at 91842/91880 cannot borrow the
height-only repeat exception. -/
theorem applyBlockExactL_error_of_collision (l : List (OutPoint × Coin))
    (kf : Tx → Key) (txs : List Tx) (height : UInt32) (ownHash ancestorHash : Nat)
    (hc : bip30BlockCollision (viewOf l) kf txs height = true)
    (he : bip30EnforcedAtHashes height ownHash ancestorHash = true) :
    applyBlockExactL l kf txs height ownHash ancestorHash =
      Except.error BlockError.badTxnsBIP30 := by
  unfold applyBlockExactL
  rw [if_pos (by simp [hc, he])]

/-! ### Frozen canonical wrappers (the frozen interface surface, now on the kf fold)

The frozen `applyBlock` took no key: the ledger's actual keying rule
is the txid preimage, so the canonical wrappers pin `txidPreimageKey`
per tx (`applyBlock`/`applyBlockExec`); the `kf`-threading folds above
carry the general form the theorems quantify over. -/

/-- FROZEN (the frozen interface): `ConnectBlock`'s UTXO fold, keyed by the txid preimage. -/
@[rule "BLK-102", rule "INV-027", rule "INV-028", rule "BLK-096"]
def applyBlock (u : UtxoSet) (txs : List Tx) (height : UInt32) :
    Except BlockError UtxoSet :=
  applyBlockU u txidPreimageKey txs height

/-- FROZEN (the frozen interface): executable twin of `applyBlock`. -/
def applyBlockExec (l : List (OutPoint × Coin)) (txs : List Tx) (height : UInt32) :
    Except BlockError (List (OutPoint × Coin)) :=
  applyBlockL l txidPreimageKey txs height

/-- The BLK-005 key at the ledger seam: coins are keyed by the real
double-SHA256 txid (`Bitcoin.DataLaws.txid`), not by the base-serialization
preimage. The hash floor is real (not an opaque stub), so this key can be
used by the executable connection path without tainting its theorems. -/
@[rule "BLK-005"]
def txidKeyReal (tx : Tx) : Key := fun _ k => ⟨Bitcoin.DataLaws.txid tx, k⟩

/-- Hash-aware, real-txid block fold used by the connection path. The
pristine BIP30 loop and the coin keys both use Core's actual identities. -/
def applyBlockTxid (u : UtxoSet) (txs : List Tx) (height : UInt32)
    (ownHash ancestorHash : Nat) : Except BlockError UtxoSet :=
  applyBlockExactU u txidKeyReal txs height ownHash ancestorHash

/-- Executable twin of `applyBlockTxid`. -/
def applyBlockExecTxid (l : List (OutPoint × Coin)) (txs : List Tx) (height : UInt32)
    (ownHash ancestorHash : Nat) : Except BlockError (List (OutPoint × Coin)) :=
  applyBlockExactL l txidKeyReal txs height ownHash ancestorHash

/-- The frozen wrapper IS the general fold at `txidPreimageKey`. -/
theorem applyBlock_abstract (u : UtxoSet) (txs : List Tx) (height : UInt32) :
    applyBlock u txs height = applyBlockU u txidPreimageKey txs height := rfl

/-- The step commutes with the abstraction map. -/
theorem applyTxStepL_abstract (l : List (OutPoint × Coin)) (tx : Tx) (key : Key) (height : UInt32) :
    (applyTxStepL l tx key height).map viewOf =
      applyTxStepU (viewOf l) tx key height := by
  unfold applyTxStepL applyTxStepU
  by_cases hc : tx.isCoinBase = true
  · rw [if_pos hc, if_pos hc]
    show Except.ok (viewOf (updateCoinsL l tx key height)) =
      Except.ok (updateCoins (viewOf l) tx key height)
    rw [updateCoinsL_abstract]
  · rw [if_neg hc, if_neg hc]
    by_cases hi : (!inputsAvailable (viewOf l) tx) = true
    · rw [if_pos hi, if_pos hi]
      rfl
    · rw [if_neg hi, if_neg hi]
      by_cases hm : (!maturityOk (viewOf l) tx height) = true
      · rw [if_pos hm, if_pos hm]
        rfl
      · rw [if_neg hm, if_neg hm]
        show Except.ok (viewOf (updateCoinsL l tx key height)) =
          Except.ok (updateCoins (viewOf l) tx key height)
        rw [updateCoinsL_abstract]

/-- The whole gate-free fold commutes with the abstraction map (the executable tier
exit: the executable block-apply IS the point-level fold; the
pre-D4c-2 `applyBlockL` body, now on `applyBlockFoldL`). -/
theorem applyBlockFoldL_abstract (l : List (OutPoint × Coin)) (kf : Tx → Key) (txs : List Tx)
    (height : UInt32) :
    (applyBlockFoldL l kf txs height).map viewOf =
      applyBlockFoldU (viewOf l) kf txs height := by
  induction txs generalizing l with
  | nil => rfl
  | cons tx rest ih =>
    unfold applyBlockFoldL applyBlockFoldU
    rw [← applyTxStepL_abstract]
    have mapBind : ∀ (x : Except BlockError (List (OutPoint × Coin)))
        (g : UtxoSet → Except BlockError UtxoSet),
        (x.map viewOf).bind g = x.bind (fun a => g (viewOf a)) := by
      intro x g
      cases x with
      | error e => rfl
      | ok v => rfl
    rw [mapBind]
    have mapBind2 : ∀ (x : Except BlockError (List (OutPoint × Coin)))
        (g : List (OutPoint × Coin) → Except BlockError (List (OutPoint × Coin))),
        Except.map viewOf (x.bind g) = x.bind (fun a => Except.map viewOf (g a)) := by
      intro x g
      cases x with
      | error e => rfl
      | ok v => rfl
    rw [mapBind2]
    simp only [ih]

/-- The whole fold commutes with the abstraction map (the executable tier: the
executable block-apply IS the point-level fold). Post-D4c-2 wrapper:
the pristine `bip30BlockCollision` gate either rejects the block
outright (both sides the same `badTxnsBIP30` error) or the equation
lands in the fold. -/
theorem applyBlockL_abstract (l : List (OutPoint × Coin)) (kf : Tx → Key) (txs : List Tx)
    (height : UInt32) :
    (applyBlockL l kf txs height).map viewOf =
      applyBlockU (viewOf l) kf txs height := by
  by_cases hbp : (bip30BlockCollision (viewOf l) kf txs height && bip30Enforced height) = true
  · unfold applyBlockL applyBlockU
    rw [if_pos hbp, if_pos hbp]
    rfl
  · unfold applyBlockL applyBlockU
    rw [if_neg hbp, if_neg hbp]
    exact applyBlockFoldL_abstract l kf txs height
/-! ## Small generic helpers (self-contained; no reliance on core
`List.all_eq_*` name drift across toolchain versions) -/

theorem listAll_true {α : Type _} (p : α → Bool) :
    (l : List α) → (∀ a ∈ l, p a = true) → l.all p = true
  | [], _ => rfl
  | b :: r, h => by
      have h1 := h b (List.mem_cons.mpr (Or.inl rfl))
      have h2 : r.all p = true :=
        listAll_true p r (fun a ha => h a (List.mem_cons.mpr (Or.inr ha)))
      simp [List.all_cons, h1, h2]

theorem listAll_false_of_mem {α : Type _} (p : α → Bool) :
    (l : List α) → (a : α) → a ∈ l → p a = false → l.all p = false
  | [], a, ha, _ => by exact absurd ha (by simp)
  | b :: r, a, ha, hp => by
      cases List.mem_cons.mp ha with
      | inl he => subst he; simp [List.all_cons, hp]
      | inr hr =>
        have h3 : r.all p = false := listAll_false_of_mem p r a hr hp
        cases hp2 : p b with
        | false => simp [List.all_cons, hp2]
        | true => simp [List.all_cons, hp2, h3]

theorem listAny_true_of_mem {α : Type _} (p : α → Bool) :
    (l : List α) → (a : α) → a ∈ l → p a = true → l.any p = true
  | [], a, ha, _ => by exact absurd ha (by simp)
  | b :: r, a, ha, hp => by
      cases List.mem_cons.mp ha with
      | inl he => subst he; simp [List.any_cons, hp]
      | inr hr =>
        have h3 : r.any p = true := listAny_true_of_mem p r a hr hp
        cases hp2 : p b with
        | false => simp [List.any_cons, hp2, h3]
        | true => simp [List.any_cons, hp2]

theorem listAny_false {α : Type _} (p : α → Bool) :
    (l : List α) → l.any p = false → ∀ a ∈ l, p a = false
  | [], _, a, ha => by exact absurd ha (by simp)
  | b :: r, h, a, ha => by
      cases List.mem_cons.mp ha with
      | inl he =>
        rw [he]
        simp only [List.any_cons] at h
        cases hb : p b with
        | false => rfl
        | true => rw [hb] at h; simp at h
      | inr hr =>
        simp only [List.any_cons] at h
        cases hb : p b with
        | true => rw [hb] at h; simp at h
        | false =>
          rw [hb] at h
          simp only [Bool.false_or] at h
          exact listAny_false p r h a hr

theorem Except.ok_iff_isOk {ε α : Type _} (x : Except ε α) :
    (∃ a, x = Except.ok a) ↔ x.isOk = true := by
  cases x with
  | error e =>
    constructor
    · intro h; simp at h
    · intro h; exact Bool.noConfusion h
  | ok a =>
    constructor
    · intro _; rfl
    · intro _; exact ⟨a, rfl⟩

theorem Except.isOk_ok {ε α : Type _} (x : Except ε α) (h : x.isOk = true) :
    ∃ a, x = Except.ok a :=
  (Except.ok_iff_isOk x).mpr h

theorem Except.bind_ok_intro {ε α β : Type _} {x : Except ε α} {f : α → Except ε β}
    {a : α} {b : β} (hx : x = Except.ok a) (hf : f a = Except.ok b) :
    x.bind f = Except.ok b := by
  rw [hx]
  exact hf

theorem Except.bind_ok_inv {ε α β : Type _} (x : Except ε α) (f : α → Except ε β) (b : β)
    (h : x.bind f = Except.ok b) : ∃ a, x = Except.ok a ∧ f a = Except.ok b := by
  cases x with
  | error e => simp only [Except.bind] at h; simp at h
  | ok a => exact ⟨a, rfl, h⟩

theorem bytesBEq_self (b : ByteArray) : bytesBEq b b = true := by
  simp [bytesBEq]

theorem outPointBeqSelf (o : OutPoint) : (o == o) = true := by
  show bytesBEq o.hash o.hash && (o.n == o.n) = true
  rw [bytesBEq_self]
  simp

/-- A pair in the list makes its key look up to `some`. -/
theorem coinLookup_isSome_of_mem (l : List (OutPoint × Coin)) (p : OutPoint × Coin)
    (h : p ∈ l) : (coinLookup l p.1).isSome = true := by
  induction l with
  | nil => exact absurd h (by simp)
  | cons q r ih =>
    cases List.mem_cons.mp h with
    | inl he =>
      subst he
      rw [coinLookup, outPointBeqSelf]
      rfl
    | inr hr =>
      cases hbp : q.1 == p.1 with
      | false => rw [coinLookup, hbp]; exact ih hr
      | true => rw [coinLookup, hbp]; rfl

/-- A key absent from every pair looks up to `none`. -/
theorem coinLookup_none_of_all_ne (l : List (OutPoint × Coin)) (o : OutPoint)
    (h : ∀ p ∈ l, (p.1 == o) = false) : coinLookup l o = none := by
  induction l with
  | nil => rfl
  | cons q r ih =>
    have hq := h q (List.mem_cons.mpr (Or.inl rfl))
    rw [coinLookup, hq]
    exact ih (fun p hp => h p (List.mem_cons.mpr (Or.inr hp)))

theorem coinLookup_none_of_any_false (l : List (OutPoint × Coin)) (o : OutPoint)
    (h : (l.any (fun p => p.1 == o)) = false) : coinLookup l o = none :=
  coinLookup_none_of_all_ne l o (listAny_false (fun p => p.1 == o) l h)

/-! ## The theorem tier — spend/insert/remove discipline, gating,
genesis (BLK-110), and THM-037 -/

/-! ### Lookup discipline over `addedCoins` -/

/-- First-match lookup hit: some entry at `o` carries exactly `c`. -/
theorem coinLookup_some_inv (l : List (OutPoint × Coin)) (o : OutPoint) (c : Coin)
    (h : coinLookup l o = some c) : ∃ p ∈ l, p.1 = o ∧ p.2 = c := by
  induction l with
  | nil => simp only [coinLookup] at h; exact absurd h (by simp)
  | cons q r ih =>
    by_cases hbq : (q.1 == o) = true
    · simp only [coinLookup, if_pos hbq] at h
      have hinj : q.2 = c := Option.some.inj h
      exact ⟨q, List.mem_cons.mpr (Or.inl rfl), outPointBEq_eq _ _ hbq, hinj⟩
    · simp only [coinLookup, if_neg hbq] at h
      obtain ⟨p, hp, h1, h2⟩ := ih h
      exact ⟨p, List.mem_cons.mpr (Or.inr hp), h1, h2⟩

/-- Unique-hit lookup: if `(o, c)` is in `l` and no other entry at `o`
carries a different coin, the lookup returns exactly `c`. -/
theorem coinLookup_eq_of_mem_unique (l : List (OutPoint × Coin)) (o : OutPoint) (c : Coin)
    (hmem : (o, c) ∈ l)
    (huniq : ∀ p ∈ l, p.1 = o → p.2 = c) :
    coinLookup l o = some c := by
  induction l with
  | nil => exact absurd hmem (by simp)
  | cons q r ih =>
    by_cases hbq : (q.1 == o) = true
    · have hq1 : q.1 = o := outPointBEq_eq _ _ hbq
      have hq2 : q.2 = c := huniq q (List.mem_cons.mpr (Or.inl rfl)) hq1
      simp only [coinLookup, if_pos hbq, hq2]
    · rcases List.mem_cons.mp hmem with he | hr
      · exfalso
        subst he
        exact hbq (outPointBeqSelf o)
      · simp only [coinLookup, if_neg hbq]
        exact ih hr (fun p hp => huniq p (List.mem_cons.mpr (Or.inr hp)))

/-- Every entry of `addedCoins` comes from some in-range, spendable
output (lookup-inversion for INV-111/112). -/
theorem addedCoins_inv (tx : Tx) (key : Key) (height : UInt32) (p : OutPoint × Coin)
    (hmem : p ∈ addedCoins tx key height) :
    ∃ j, j < tx.vout.length ∧
      p.1 = key OutPoint.null (UInt32.ofNat j) ∧
      scriptUnspendable (tx.vout.getD j ⟨0, Script.empty⟩).scriptPubKey = false ∧
      p.2 = ⟨(tx.vout.getD j ⟨0, Script.empty⟩).value, height, tx.isCoinBase,
        (tx.vout.getD j ⟨0, Script.empty⟩).scriptPubKey⟩ := by
  unfold addedCoins at hmem
  obtain ⟨k, hk, hfk⟩ := List.mem_filterMap.mp hmem
  have h2 : (if scriptUnspendable (tx.vout.getD k ⟨0, Script.empty⟩).scriptPubKey = true
      then (none : Option (OutPoint × Coin))
      else some (key OutPoint.null (UInt32.ofNat k),
            ⟨(tx.vout.getD k ⟨0, Script.empty⟩).value, height, tx.isCoinBase,
              (tx.vout.getD k ⟨0, Script.empty⟩).scriptPubKey⟩)) = some p := hfk
  by_cases hus : scriptUnspendable (tx.vout.getD k ⟨0, Script.empty⟩).scriptPubKey = true
  · rw [if_pos hus] at h2; simp at h2
  · rw [if_neg hus] at h2
    have hp' := Option.some.inj h2
    exact ⟨k, List.mem_range.mp hk, (congrArg Prod.fst hp').symm,
      Bool.eq_false_iff.mpr hus, (congrArg Prod.snd hp').symm⟩

/-- A spendable in-range output `j` contributes its entry to
`addedCoins` (INV-111 membership half). -/
theorem addedCoins_mem (tx : Tx) (key : Key) (height : UInt32) (j : Nat)
    (hj : j < tx.vout.length)
    (hus : scriptUnspendable (tx.vout.getD j ⟨0, Script.empty⟩).scriptPubKey = false) :
    (key OutPoint.null (UInt32.ofNat j),
      ⟨(tx.vout.getD j ⟨0, Script.empty⟩).value, height, tx.isCoinBase,
        (tx.vout.getD j ⟨0, Script.empty⟩).scriptPubKey⟩)
      ∈ addedCoins tx key height := by
  unfold addedCoins
  refine List.mem_filterMap.mpr ⟨j, List.mem_range.mpr hj, ?_⟩
  dsimp only
  cases hx : scriptUnspendable (tx.vout.getD j ⟨0, Script.empty⟩).scriptPubKey with
  | true => exact absurd hx (fun hc => Bool.noConfusion ((Eq.symm hus).trans hc))
  | false => rfl

/-- INV-111: a spendable output's coin IS in the updated set (isSome
needs no key-uniqueness — first-match-wins answers with some coin). -/
theorem updateCoins_insert_isSome (u : UtxoSet) (tx : Tx) (key : Key) (height : UInt32)
    (j : Nat) (hj : j < tx.vout.length)
    (hus : scriptUnspendable (tx.vout.getD j ⟨0, Script.empty⟩).scriptPubKey = false) :
    (updateCoins u tx key height (key OutPoint.null (UInt32.ofNat j))).isSome = true := by
  have hmem := addedCoins_mem tx key height j hj hus
  unfold updateCoins
  cases hcl : coinLookup (addedCoins tx key height) (key OutPoint.null (UInt32.ofNat j)) with
  | some _ => rfl
  | none =>
    have h1 := coinLookup_isSome_of_mem _ _ hmem
    rw [hcl] at h1
    simp at h1

/-- INV-111 (precise): with distinct output keys, the coin created for
output `j` is looked up exactly. -/
theorem addedCoins_lookup_eq (tx : Tx) (key : Key) (height : UInt32) (j : Nat)
    (hj : j < tx.vout.length)
    (hus : scriptUnspendable (tx.vout.getD j ⟨0, Script.empty⟩).scriptPubKey = false)
    (huniq : ∀ i k : Nat, i < tx.vout.length → k < tx.vout.length →
      key OutPoint.null (UInt32.ofNat i) = key OutPoint.null (UInt32.ofNat k) → i = k) :
    coinLookup (addedCoins tx key height) (key OutPoint.null (UInt32.ofNat j)) =
      some ⟨(tx.vout.getD j ⟨0, Script.empty⟩).value, height, tx.isCoinBase,
        (tx.vout.getD j ⟨0, Script.empty⟩).scriptPubKey⟩ := by
  refine coinLookup_eq_of_mem_unique _ _ _ (addedCoins_mem tx key height j hj hus) ?_
  intro p hp hp1
  obtain ⟨i, hi, hp1', hus', hp2⟩ := addedCoins_inv tx key height p hp
  have hij : i = j := huniq i j hi hj (by rw [← hp1', hp1])
  rw [hij] at hus' hp2
  exact hp2

/-- INV-112: an OP_RETURN (unspendable) output never enters the set —
with distinct output keys, nothing else can land on its outpoint. -/
theorem addedCoins_lookup_none_of_unspendable (tx : Tx) (key : Key) (height : UInt32) (j : Nat)
    (hj : j < tx.vout.length)
    (hus : scriptUnspendable (tx.vout.getD j ⟨0, Script.empty⟩).scriptPubKey = true)
    (hdist : ∀ i k : Nat, i < tx.vout.length → k < tx.vout.length → i ≠ k →
      key OutPoint.null (UInt32.ofNat i) ≠ key OutPoint.null (UInt32.ofNat k)) :
    coinLookup (addedCoins tx key height) (key OutPoint.null (UInt32.ofNat j)) = none := by
  refine coinLookup_none_of_all_ne _ _ (fun p hp => ?_)
  obtain ⟨i, hi, hp1, hus', _⟩ := addedCoins_inv tx key height p hp
  by_cases hij : i = j
  · subst hij
    rw [hus] at hus'
    exact Bool.noConfusion hus'
  · have hne : key OutPoint.null (UInt32.ofNat i) ≠ key OutPoint.null (UInt32.ofNat j) :=
      hdist i j hi hj hij
    rw [hp1]
    exact Bool.eq_false_iff.mpr (fun hc => hne (outPointBEq_eq _ _ hc))

/-- Absent from the key map → looks up to `none`. -/
theorem coinLookup_none_of_not_mem_keys (l : List (OutPoint × Coin)) (o : OutPoint)
    (h : o ∉ l.map (fun p => p.1)) : coinLookup l o = none :=
  coinLookup_none_of_all_ne l o (fun p hp =>
    Bool.eq_false_iff.mpr
      (fun hc => h (List.mem_map.mpr ⟨p, hp, outPointBEq_eq _ _ hc⟩)))

/-! ### INV-110: a spent prevout leaves the set -/

/-- A non-coinbase tx that spends `p` without re-creating it removes
`p`'s coin, whatever the prior state (`SpendCoin`, coins.cpp:82-117). -/
theorem updateCoins_spend_gone (u : UtxoSet) (tx : Tx) (key : Key) (height : UInt32)
    (p : OutPoint) (hcb : tx.isCoinBase = false)
    (hsp : tx.vin.any (fun i => i.prevout == p) = true)
    (hnew : coinLookup (addedCoins tx key height) p = none) :
    updateCoins u tx key height p = none := by
  unfold updateCoins
  rw [hnew]
  dsimp only
  rw [if_neg (by simp [hcb]), if_pos hsp]

/-- Spend-then-recreate in one tx: the NEW coin wins (`AddCoins` runs
after `SpendCoin`), so `p` is still present. -/
theorem updateCoins_spend_recreate (u : UtxoSet) (tx : Tx) (key : Key) (height : UInt32)
    (p : OutPoint) (c : Coin)
    (hnew : coinLookup (addedCoins tx key height) p = some c) :
    updateCoins u tx key height p = some c := by
  unfold updateCoins
  rw [hnew]

/-! ### BLK-102 / INV-027 / INV-028: the per-tx gates fire in Core's order -/

/-- When the BIP30 duplicate check passes, the tx is not a coinbase, and
an input prevout is missing, the step fails with Core's exact
`bad-txns-inputs-missingorspent`. -/
theorem applyTxStepU_missing_or_spent (u : UtxoSet) (tx : Tx) (key : Key) (height : UInt32)
    (hb : (bip30Enforced height && bip30Collision u tx key height) = false)
    (hcb : tx.isCoinBase = false)
    (hi : inputsAvailable u tx = false) :
    applyTxStepU u tx key height =
      Except.error (BlockError.txError TxError.badTxnsInputsMissingOrSpent) := by
  unfold applyTxStepU
  rw [if_neg (by simp [hcb]), if_pos (by simp [hi])]

/-- Same order, maturity leg: an available but immature coinbase coin
fails with `bad-txns-premature-spend-of-coinbase`. -/
theorem applyTxStepU_premature (u : UtxoSet) (tx : Tx) (key : Key) (height : UInt32)
    (hb : (bip30Enforced height && bip30Collision u tx key height) = false)
    (hcb : tx.isCoinBase = false)
    (hi : inputsAvailable u tx = true)
    (hm : maturityOk u tx height = false) :
    applyTxStepU u tx key height =
      Except.error (BlockError.txError TxError.badTxnsPrematureSpendOfCoinbase) := by
  unfold applyTxStepU
  rw [if_neg (by simp [hcb]),
    if_neg (by simp [hi]), if_pos (by simp [hm])]

/-- A coinbase coin created at height `coinH` is spendable at
`coinH + 100`, not at `coinH + 99` (BLK-100 / INV-028, on the nose). -/
theorem maturity_boundary (coinH : UInt32) (val : Amount) (scr : Script) (p : OutPoint)
    (h32 : coinH.toNat + 100 < 4294967296) :
    maturityOk (fun q => if q == p then some ⟨val, coinH, true, scr⟩ else none)
        (⟨1, [⟨p, Script.empty, 0xFFFFFFFF⟩], [], 0, []⟩)
        (UInt32.ofNat (coinH.toNat + 99)) = false ∧
    maturityOk (fun q => if q == p then some ⟨val, coinH, true, scr⟩ else none)
        (⟨1, [⟨p, Script.empty, 0xFFFFFFFF⟩], [], 0, []⟩)
        (UInt32.ofNat (coinH.toNat + 100)) = true := by
  constructor
  · unfold maturityOk
    refine listAll_false_of_mem _ _ ⟨p, Script.empty, 0xFFFFFFFF⟩
      (List.mem_cons.mpr (Or.inl rfl)) ?_
    dsimp only
    rw [if_pos (outPointBeqSelf p)]
    dsimp only
    rw [show (UInt32.ofNat (coinH.toNat + 99)).toNat = coinH.toNat + 99 from by simp; omega]
    show decide (coinH.toNat + 100 ≤ coinH.toNat + 99) = false
    exact decide_eq_false_iff_not.mpr (by omega)
  · unfold maturityOk
    refine listAll_true _ _ (fun i hi => ?_)
    cases List.mem_cons.mp hi with
    | inl he =>
      subst he
      dsimp only
      rw [if_pos (outPointBeqSelf p)]
      dsimp only
      rw [show (UInt32.ofNat (coinH.toNat + 100)).toNat = coinH.toNat + 100 from by simp; omega]
      show decide (coinH.toNat + 100 ≤ coinH.toNat + 100) = true
      exact decide_eq_true_iff.mpr (Nat.le_refl _)
    | inr hr => exact absurd hr (by simp)

/-! ### BLK-110: the empty view and the genesis coin -/

/-- The empty UTXO view (before the genesis block). Connecting genesis
skips its transactions entirely (validation.cpp:2330-2334), so the 50 BTC
output never enters the set (chainparams.cpp:52-54) — §g, report 08. -/
@[rule "BLK-110"]
def emptyUtxo : UtxoSet := fun _ => none

theorem emptyUtxo_lookup (p : OutPoint) : emptyUtxo p = none := rfl

theorem viewOf_nil : viewOf [] = emptyUtxo := rfl

/-- `l.any f = false` from pointwise falsity (intro direction; the dual
of `listAny_true_mem`). -/
theorem listAny_false_intro {α : Type _} (f : α → Bool) (l : List α)
    (h : ∀ x ∈ l, f x = false) : l.any f = false := by
  refine Bool.eq_false_iff.mpr (fun hc => ?_)
  obtain ⟨x, hx, hfx⟩ := listAny_true_mem f l hc
  exact Bool.noConfusion ((Eq.symm hfx).trans (h x hx))

/-- BLK-110: connecting a lone coinbase to the EMPTY view succeeds —
no input checks apply to the coinbase — and the genesis-style coin is
present under the txid-preimage key with the connection height and the
coinbase bit set. -/
theorem genesis_coin_isSome (cb : Tx) (height : UInt32)
    (hcb : cb.isCoinBase = true)
    (hv0 : 0 < cb.vout.length)
    (hsmall : cb.vout.length < 4294967296)
    (hus : scriptUnspendable (cb.vout.getD 0 ⟨0, Script.empty⟩).scriptPubKey = false) :
    ∃ u, applyBlock emptyUtxo [cb] height = Except.ok u ∧
      (u (txidPreimageKey cb OutPoint.null (UInt32.ofNat 0))).isSome = true ∧
      (u (txidPreimageKey cb OutPoint.null (UInt32.ofNat 0))).map (fun c => c.height) =
        some height ∧
      (u (txidPreimageKey cb OutPoint.null (UInt32.ofNat 0))).map (fun c => c.isCoinbase) =
        some true := by
  have hcol : bip30Collision emptyUtxo cb (txidPreimageKey cb) height = false :=
    listAny_false_intro _ _ (fun p _ => rfl)
  have hstep : applyTxStepU emptyUtxo cb (txidPreimageKey cb) height =
      Except.ok (updateCoins emptyUtxo cb (txidPreimageKey cb) height) := by
    unfold applyTxStepU
    rw [if_pos hcb]
  have hfold : applyBlock emptyUtxo [cb] height =
      Except.ok (updateCoins emptyUtxo cb (txidPreimageKey cb) height) := by
    unfold applyBlock applyBlockU applyBlockFoldU
    rw [if_neg (by simp [bip30BlockCollision, hcol])]
    rw [hstep]
    rfl
  refine ⟨updateCoins emptyUtxo cb (txidPreimageKey cb) height, hfold, ?_, ?_, ?_⟩
  · exact updateCoins_insert_isSome _ _ _ _ 0 hv0 hus
  · unfold updateCoins
    rw [addedCoins_lookup_eq cb (txidPreimageKey cb) height 0 hv0 hus
      (fun i k hi hk hcon => by
        simp only [txidPreimageKey] at hcon
        injection hcon with _ hn
        have h' : i % 4294967296 = k % 4294967296 := by
          have h2 := congrArg UInt32.toNat hn
          show i % 4294967296 = k % 4294967296
          exact h2
        rw [Nat.mod_eq_of_lt (by omega), Nat.mod_eq_of_lt (by omega)] at h'
        exact h')]
    rfl
  · unfold updateCoins
    rw [addedCoins_lookup_eq cb (txidPreimageKey cb) height 0 hv0 hus
      (fun i k hi hk hcon => by
        simp only [txidPreimageKey] at hcon
        injection hcon with _ hn
        have h' : i % 4294967296 = k % 4294967296 := by
          have h2 := congrArg UInt32.toNat hn
          show i % 4294967296 = k % 4294967296
          exact h2
        rw [Nat.mod_eq_of_lt (by omega), Nat.mod_eq_of_lt (by omega)] at h'
        exact h')]
    simp [hcb]

/-! ### THM-037 (lower half): block fees are nonnegative -/

/-- THM-037, executable form: total fees extracted by connecting `txs`
to `u` — per tx, the fee `CheckTxInputs` certifies on success (0
otherwise), threaded over the fold's running view. -/
def chainFees (u : UtxoSet) (kf : Tx → Key) : List Tx → UInt32 → Amount
  | [], _ => 0
  | tx :: rest, height =>
    match checkTxInputs tx u height with
    | .ok fee => fee + chainFees (updateCoins u tx (kf tx) height) kf rest height
    | .error _ => chainFees (updateCoins u tx (kf tx) height) kf rest height

/-- THM-037: every fee `CheckTxInputs` certifies is nonnegative
(`checkTxInputs_ok_conservation`), so the accumulated total is too. -/
theorem chainFees_nonneg (u : UtxoSet) (kf : Tx → Key) :
    (txs : List Tx) → (height : UInt32) → 0 ≤ chainFees u kf txs height
  | [], _ => by show 0 ≤ 0; exact Int.le_refl 0
  | tx :: rest, height => by
    unfold chainFees
    rcases hci : checkTxInputs tx u height with _ | fee
    · dsimp only; exact chainFees_nonneg _ _ _ _
    · dsimp only
      obtain ⟨_, hfee⟩ := checkTxInputs_ok_conservation tx u height fee hci
      exact Int.add_nonneg hfee (chainFees_nonneg _ _ _ _)

/-! ### INV-110 (block form): no double-spend in a succeeding fold -/

/-- The step's value on success: every `ok` branch of `applyTxStepU`
returns exactly the updated view. -/
theorem applyTxStepU_ok_value {u : UtxoSet} {tx : Tx} {key : Key} {height : UInt32}
    {w : UtxoSet} (h : applyTxStepU u tx key height = Except.ok w) :
    w = updateCoins u tx key height := by
  unfold applyTxStepU at h
  split at h
  · simp at h; exact h.symm
  · split at h
    · simp at h
    · split at h
      · simp at h
      · simp at h; exact h.symm

/-- A key that is absent from the starting view and not added by `tx`
is still absent after `updateCoins` (freshness is preserved per step). -/
theorem updateCoins_preserve_none (u : UtxoSet) (tx : Tx) (key : Key) (height : UInt32)
    (p : OutPoint) (hnone : u p = none) (hnoadd : p ∉ addedKeys tx key height) :
    updateCoins u tx key height p = none := by
  dsimp only [updateCoins]
  rw [coinLookup_none_of_all_ne (addedCoins tx key height) p
    (fun q hq => by
      by_cases hbe : (q.1 == p) = true
      · exact absurd (List.mem_map.mpr ⟨q, hq, outPointBEq_eq _ _ hbe⟩) hnoadd
      · exact Bool.eq_false_iff.mpr hbe)]
  by_cases hb : tx.isCoinBase = true
  · rw [if_pos hb, hnone]
  · rw [if_neg hb]
    by_cases hva : tx.vin.any (fun i => i.prevout == p) = true
    · rw [if_pos hva]
    · rw [if_neg hva, hnone]

/-- Freshness threads through the whole gate-free fold: a point absent
from the starting view and never added stays absent in every
intermediate view (the pre-D4c-2 `applyBlockU` body, now on
`applyBlockFoldU`). -/
theorem applyBlockFoldU_preserve_none (kf : Tx → Key) (p : OutPoint) :
    (txs : List Tx) → (height : UInt32) → (u : UtxoSet) → u p = none →
    (∀ tx ∈ txs, p ∉ addedKeys tx (kf tx) height) →
    ∀ u', applyBlockFoldU u kf txs height = Except.ok u' → u' p = none
  | [], _, _, hnone, _, _ => by
      intro hfold
      injection hfold with hu
      rw [← hu]
      exact hnone
  | tx :: rest, height, u, hnone, hnoadd, u' => by
      intro hfold
      obtain ⟨w, hstep, hrest⟩ :=
        Except.bind_ok_inv _ _ _ hfold
      have hw : w = updateCoins u tx (kf tx) height := applyTxStepU_ok_value hstep
      have hwp : w p = none :=
        by rw [hw]
           exact updateCoins_preserve_none u tx (kf tx) height p hnone
             (hnoadd tx (List.mem_cons.mpr (Or.inl rfl)))
      exact applyBlockFoldU_preserve_none kf p rest height w hwp
        (fun tx' ht' => hnoadd tx' (List.mem_cons.mpr (Or.inr ht'))) u' hrest

/-- Freshness threads through the whole fold: a point absent from the
starting view and never added stays absent in every intermediate view.
Post-D4c-2 wrapper: the pristine `bip30BlockCollision` gate either
rejects the block outright or the hypothesis lands in the fold. -/
theorem applyBlockU_preserve_none (kf : Tx → Key) (p : OutPoint) :
    (txs : List Tx) → (height : UInt32) → (u : UtxoSet) → u p = none →
    (∀ tx ∈ txs, p ∉ addedKeys tx (kf tx) height) →
    ∀ u', applyBlockU u kf txs height = Except.ok u' → u' p = none
  | txs, height, u, hnone, hnoadd, u' => by
      intro hfold
      unfold applyBlockU at hfold
      by_cases hbp :
          (bip30BlockCollision u kf txs height && bip30Enforced height) = true
      · rw [if_pos hbp] at hfold
        simp at hfold
      · rw [if_neg hbp] at hfold
        exact applyBlockFoldU_preserve_none kf p txs height u hnone hnoadd u' hfold

/-- INV-110 (block form), the gate-free fold: if the fold over `txs`
succeeds, then no tx in the block spends `p` — given `p` is absent
from the starting view and no tx adds `p` (the pre-D4c-2
`applyBlockU` body, now on `applyBlockFoldU`). -/
theorem applyBlockFoldU_no_double_spend (kf : Tx → Key) (p : OutPoint) :
    (txs : List Tx) → (height : UInt32) → (u : UtxoSet) → u p = none →
    (∀ tx ∈ txs, p ∉ addedKeys tx (kf tx) height) →
    (applyBlockFoldU u kf txs height).isOk = true →
    (txs.filter (fun tx => !tx.isCoinBase && tx.vin.any (fun i => i.prevout == p))).length = 0
  | [], _, _, _, _, _ => rfl
  | tx :: rest, height, u, hnone, hnoadd, hok => by
      obtain ⟨u'', hfold⟩ := Except.isOk_ok _ hok
      obtain ⟨w, hstep, hrest⟩ := Except.bind_ok_inv _ _ _ hfold
      have hw : w = updateCoins u tx (kf tx) height := applyTxStepU_ok_value hstep
      have hwp : w p = none :=
        by rw [hw]
           exact updateCoins_preserve_none u tx (kf tx) height p hnone
             (hnoadd tx (List.mem_cons.mpr (Or.inl rfl)))
      by_cases hqtx :
          (!tx.isCoinBase && tx.vin.any (fun i => i.prevout == p)) = true
      · -- `tx` would be rejected: its step errors, contradicting the fold
        exfalso
        rw [Bool.and_eq_true] at hqtx
        obtain ⟨h1, hvany⟩ := hqtx
        simp at h1
        obtain ⟨i, hi, hpi⟩ := List.any_eq_true.mp hvany
        have hpo : i.prevout = p := outPointBEq_eq _ _ hpi
        have hia : inputsAvailable u tx = false := by
          unfold inputsAvailable
          exact listAll_false_of_mem (fun i => (u i.prevout).isSome) tx.vin i hi (by
            rw [hpo, hnone]; rfl)
        unfold applyTxStepU at hstep
        rw [if_neg (by simp [h1]),
            if_pos (show (!inputsAvailable u tx) = true from by rw [hia]; rfl)] at hstep
        simp at hstep
      · -- `tx` is not in the filter; recurse on the rest at the new view
        rw [List.filter_cons_of_neg
          (p := fun t => !t.isCoinBase && t.vin.any (fun i => i.prevout == p)) (a := tx) hqtx]
        exact applyBlockFoldU_no_double_spend kf p rest height w hwp
          (fun tx' ht' => hnoadd tx' (List.mem_cons.mpr (Or.inr ht')))
          (by rw [hrest]; rfl)

/-- INV-110 (block form): if the fold over `txs` succeeds, then no tx in
the block spends `p` — given `p` is absent from the starting view and no
tx adds `p`. Any tx whose vin references `p` would fail the
availability check at its own step (its coin never exists: freshness is
preserved through the fold), so a succeeding fold contains no such tx.
Post-D4c-2 wrapper: the pristine `bip30BlockCollision` gate either
rejects the block outright or the hypothesis lands in the fold. -/
theorem applyBlockU_no_double_spend (kf : Tx → Key) (p : OutPoint) :
    (txs : List Tx) → (height : UInt32) → (u : UtxoSet) → u p = none →
    (∀ tx ∈ txs, p ∉ addedKeys tx (kf tx) height) →
    (applyBlockU u kf txs height).isOk = true →
    (txs.filter (fun tx => !tx.isCoinBase && tx.vin.any (fun i => i.prevout == p))).length = 0
  | txs, height, u, hnone, hnoadd, hok => by
      unfold applyBlockU at hok
      by_cases hbp :
          (bip30BlockCollision u kf txs height && bip30Enforced height) = true
      · rw [if_pos hbp] at hok
        exact Bool.noConfusion hok
      · rw [if_neg hbp] at hok
        exact applyBlockFoldU_no_double_spend kf p txs height u hnone hnoadd hok

/-- FROZEN-wrapper form of `applyBlockU_no_double_spend` at the canonical
key: a succeeding `ConnectBlock` never double-spends a coin that is
absent from the starting view and never re-created. -/
theorem applyBlock_no_double_spend (u : UtxoSet) (p : OutPoint) (txs : List Tx)
    (height : UInt32) (hnone : u p = none)
    (hnoadd : ∀ tx ∈ txs, p ∉ addedKeys tx (txidPreimageKey tx) height)
    (hok : (applyBlock u txs height).isOk = true) :
    (txs.filter (fun tx => !tx.isCoinBase && tx.vin.any (fun i => i.prevout == p))).length = 0 := by
  rw [applyBlock_abstract] at hok
  exact applyBlockU_no_double_spend txidPreimageKey p txs height u hnone hnoadd hok

/-! ### INV-113 (block form): the undo (disconnect) tier -/

/-- The coins `tx` spends from view `u`: one pair per input whose prevout
holds a coin in `u` (validation.cpp: `SpendCoin` / `ApplyTxInUndo` — the
disconnect twin of `updateCoins`). FilterMap over `tx.vin` preserves
input order — the CTxUndo layout (BLK-105). -/
@[rule "BLK-105"]
def spentUndo (u : UtxoSet) (tx : Tx) : List (OutPoint × Coin) :=
  tx.vin.filterMap (fun i =>
    match u i.prevout with
    | some c => some (i.prevout, c)
    | none => none)

/-- One disconnect step: restore the spent coins (restore wins over the
insert — the exact reverse of `updateCoins`'s new-wins discipline), then
blank every key `tx` added, and keep the rest of the post-state. -/
@[rule "INV-117"]
def undoCoins (uAfter : UtxoSet) (spent : List (OutPoint × Coin)) (tx : Tx)
    (key : Key) (height : UInt32) : UtxoSet :=
  fun o =>
    match coinLookup spent o with
    | some c => some c
    | none => if (coinLookup (addedCoins tx key height) o).isSome then none else uAfter o

/-- Every entry of the undo payload names an input of `tx` whose prevout
held exactly that coin in the pre-state. -/
theorem spentUndo_inv (u : UtxoSet) (tx : Tx) (q : OutPoint × Coin)
    (h : q ∈ spentUndo u tx) : ∃ i, i ∈ tx.vin ∧ i.prevout = q.1 ∧ u q.1 = some q.2 := by
  unfold spentUndo at h
  obtain ⟨i, hi, hf⟩ := List.mem_filterMap.mp h
  cases hu : u i.prevout with
  | none => rw [hu] at hf; exact absurd hf (by simp)
  | some c =>
    rw [hu] at hf
    injection hf with hp
    have hp' : i.prevout = q.1 ∧ c = q.2 := Prod.mk.injEq _ _ _ _ ▸ hp
    obtain ⟨h1, h2⟩ := hp'
    exact ⟨i, hi, h1, by rw [h1, h2] at hu; exact hu⟩

/-- A hit in the undo payload certifies the coin really was in the view. -/
theorem spentUndo_hit (u : UtxoSet) (tx : Tx) (o : OutPoint) (c : Coin)
    (h : coinLookup (spentUndo u tx) o = some c) : u o = some c := by
  obtain ⟨p, hp, h1, h2⟩ := coinLookup_some_inv _ _ _ h
  obtain ⟨_, _, _, huc⟩ := spentUndo_inv u tx p hp
  rw [← h1, ← h2]
  exact huc

/-- An input holding coin `c` at `o` puts `(o, c)` in the undo payload. -/
theorem mem_spentUndo_of_input (u : UtxoSet) (tx : Tx) (i : TxIn) (hi : i ∈ tx.vin)
    (o : OutPoint) (c : Coin) (hpo : i.prevout = o) (huc : u o = some c) :
    (o, c) ∈ spentUndo u tx := by
  unfold spentUndo
  refine List.mem_filterMap.mpr ⟨i, hi, ?_⟩
  rw [hpo, huc]

/-- Nothing in the undo payload can sit at a prevout no input names. -/
theorem spentUndo_lookup_none_of_any_false (u : UtxoSet) (tx : Tx) (o : OutPoint)
    (hv : (tx.vin.any (fun i => i.prevout == o)) = false) :
    coinLookup (spentUndo u tx) o = none := by
  refine coinLookup_none_of_all_ne _ _ (fun q hq => ?_)
  obtain ⟨i, hi, hpo, _⟩ := spentUndo_inv u tx q hq
  have hp := listAny_false (fun i => i.prevout == o) tx.vin hv i hi
  rw [hpo] at hp
  exact hp

/-- INV-113 (the disconnect round-trip): undoing the effect of `tx` on
the post-state restores the original view exactly, given only that no
added key overwrote a live coin (`h5`: every added key was either fresh
in `u` or itself re-spent by `tx`'s own inputs). -/
@[rule "INV-116"]
theorem updateCoins_undo (u : UtxoSet) (tx : Tx) (key : Key) (height : UInt32)
    (h5 : ∀ q ∈ addedKeys tx key height,
      u q = none ∨ tx.vin.any (fun i => i.prevout == q) = true) :
    undoCoins (updateCoins u tx key height) (spentUndo u tx) tx key height = u := by
  funext o
  dsimp only [undoCoins]
  rcases hcs : coinLookup (spentUndo u tx) o with _ | c'
  · -- the undo payload has nothing at `o`
    dsimp only [updateCoins]
    by_cases hva : tx.vin.any (fun i => i.prevout == o) = true
    · -- some input spends `o`; the payload miss forces `u o = none`
      have hF : u o = none ∨ ∃ cu, u o = some cu :=
        match hu : u o with
        | none => Or.inl rfl
        | some cu => Or.inr ⟨cu, rfl⟩
      rcases hF with huno | ⟨cu, hucuo⟩
      · rw [huno]
        rcases hca : coinLookup (addedCoins tx key height) o with _ | c
        · rw [if_neg (by simp)]
          by_cases hb : tx.isCoinBase = true
          · rw [if_pos hb]
          · rw [if_neg hb, if_pos hva]
        · rw [if_pos (by simp)]
      · exfalso
        obtain ⟨i, hi, hpi⟩ := List.any_eq_true.mp hva
        have hpo : i.prevout = o := outPointBEq_eq _ _ hpi
        have his := coinLookup_isSome_of_mem (spentUndo u tx) (o, cu)
          (mem_spentUndo_of_input u tx i hi o cu hpo hucuo)
        rw [hcs] at his
        exact absurd his (by simp)
    · -- no input references `o`
      rcases hca : coinLookup (addedCoins tx key height) o with _ | c
      · rw [if_neg (by simp)]
        by_cases hb : tx.isCoinBase = true
        · rw [if_pos hb]
        · rw [if_neg hb, if_neg hva]
      · rw [if_pos (by simp)]
        have hmem : o ∈ addedKeys tx key height := by
          obtain ⟨q, hq, hq1, _⟩ := coinLookup_some_inv _ _ _ hca
          exact List.mem_map.mpr ⟨q, hq, hq1⟩
        rcases h5 o hmem with huno | hva'
        · rw [huno]
        · exact absurd hva' hva
  · -- the payload restores `o`'s pre-state coin exactly
    rw [spentUndo_hit u tx o c' hcs]

/-! ## S2b: block-level conservation (THM-037, upper half)

`chainFees` certifies per-tx fees; this section bounds the TOTAL fees a
block's transactions can extract: fees ≤ (value in the starting UTXO
set) + (total value the block's own outputs draw). Executable form over
the assoc list, transferred to the point tier through `chainFees_viewOf`
(the executable tier's abstraction discipline).

Arithmetic note: this toolchain's `omega` only counts atoms whose type
is syntactically `Int`, so every `Amount` fact is transported through
the (defeq) wrapper `toI` before `omega` closes a goal. -/

/-- Transport for `omega` (see the section note). -/
def toI (a : Amount) : Int := a

/-- Total value of the coins stored in an assoc-list UTXO set. -/
def listTotal (l : List (OutPoint × Coin)) : Amount :=
  l.foldl (fun a p => a + p.2.value) 0

/-- Value of the coin at `o` in `l` (0 when `o` is absent). -/
def coinValueAt (l : List (OutPoint × Coin)) (o : OutPoint) : Amount :=
  match coinLookup l o with
  | some c => c.value
  | none => 0

/-- Total value of the coins at `ps` in `l` (first-match-wins per point,
mirroring `coinLookup`). -/
def sumAtL (l : List (OutPoint × Coin)) (ps : List OutPoint) : Amount :=
  ps.foldl (fun a o => a + coinValueAt l o) 0

/-- Total value the block's transactions draw (create) across their
outputs. -/
def blockDrawn (txs : List Tx) : Amount :=
  txs.foldl (fun a tx => a + tx.getValueOut) 0

/-! ### Small arithmetic helpers (no Mathlib) -/

theorem boolNot_eq_true_of_eq_false {b : Bool} (h : (!b) = false) : b = true := by
  cases b with
  | true => rfl
  | false => exact absurd h (by simp)

theorem boolEq_false_of_notEq_true {b : Bool} (h : (!b) = true) : b = false := by
  cases b with
  | true => exact absurd h (by simp)
  | false => rfl

/-- A sum-fold with an offset accumulator splits off the offset. -/
theorem foldl_add_split {β : Type _} (g : β → Amount) :
    (l : List β) → (a : Amount) →
    l.foldl (fun x b => x + g b) a = a + l.foldl (fun x b => x + g b) 0
  | [], a => by simp [Int.add_zero]
  | b :: r, a => by
      show r.foldl (fun x b => x + g b) (a + g b)
        = a + r.foldl (fun x b => x + g b) (0 + g b)
      rw [foldl_add_split g r (a + g b), foldl_add_split g r (0 + g b), Int.add_assoc,
        Int.zero_add]

/-! ### `listTotal` lemmas -/

theorem listTotal_cons (p : OutPoint × Coin) (l : List (OutPoint × Coin)) :
    listTotal (p :: l) = p.2.value + listTotal l := by
  simp only [listTotal, List.foldl_cons]
  rw [foldl_add_split, Int.zero_add]

theorem listTotal_append (a b : List (OutPoint × Coin)) :
    listTotal (a ++ b) = listTotal a + listTotal b := by
  simp only [listTotal, List.foldl_append]
  rw [foldl_add_split]

theorem listTotal_nonneg (l : List (OutPoint × Coin))
    (hval : ∀ p ∈ l, 0 ≤ p.2.value) : 0 ≤ listTotal l := by
  induction l with
  | nil => show (0:Int) ≤ (0:Int); exact Int.le_refl 0
  | cons p r ih =>
      have h1 : (0:Int) ≤ toI p.2.value := hval p (List.mem_cons.mpr (Or.inl rfl))
      have h2 : (0:Int) ≤ toI (listTotal r) :=
        ih (fun q hq => hval q (List.mem_cons.mpr (Or.inr hq)))
      rw [listTotal_cons]
      show (0:Int) ≤ toI p.2.value + toI (listTotal r)
      omega

theorem listTotal_filter_mono (l : List (OutPoint × Coin)) (keep : OutPoint × Coin → Bool)
    (hval : ∀ p ∈ l, 0 ≤ p.2.value) : listTotal (l.filter keep) ≤ listTotal l := by
  induction l with
  | nil => show (0:Int) ≤ (0:Int); exact Int.le_refl 0
  | cons p r ih =>
      have hvalr : ∀ q ∈ r, 0 ≤ q.2.value := fun q hq => hval q (List.mem_cons.mpr (Or.inr hq))
      have h1 : (0:Int) ≤ toI p.2.value := hval p (List.mem_cons.mpr (Or.inl rfl))
      have h2 : toI (listTotal (r.filter keep)) ≤ toI (listTotal r) := ih hvalr
      by_cases hk : keep p = true
      · rw [List.filter_cons_of_pos hk, listTotal_cons, listTotal_cons]
        show toI p.2.value + toI (listTotal (r.filter keep))
          ≤ toI p.2.value + toI (listTotal r)
        omega
      · rw [List.filter_cons_of_neg hk, listTotal_cons]
        show toI (listTotal (r.filter keep)) ≤ toI p.2.value + toI (listTotal r)
        omega

/-! ### `sumAtL` lemmas -/

theorem sumAtL_cons (l : List (OutPoint × Coin)) (q : OutPoint) (ps : List OutPoint) :
    sumAtL l (q :: ps) = coinValueAt l q + sumAtL l ps := by
  show ps.foldl (fun a o => a + coinValueAt l o) (0 + coinValueAt l q)
    = coinValueAt l q + ps.foldl (fun a o => a + coinValueAt l o) 0
  rw [foldl_add_split, Int.zero_add]

theorem sumAtL_nil (ps : List OutPoint) : sumAtL [] ps = 0 := by
  induction ps with
  | nil => rfl
  | cons q r ih =>
      rw [sumAtL_cons]
      have h0 : coinValueAt [] q = 0 := rfl
      rw [h0, Int.zero_add, ih]

theorem sumAtL_congr (ps : List OutPoint) (l₁ l₂ : List (OutPoint × Coin))
    (h : ∀ o ∈ ps, coinValueAt l₁ o = coinValueAt l₂ o) : sumAtL l₁ ps = sumAtL l₂ ps := by
  induction ps with
  | nil => rfl
  | cons q r ih =>
      rw [sumAtL_cons, sumAtL_cons, h q (List.mem_cons.mpr (Or.inl rfl)),
        ih (fun o ho => h o (List.mem_cons.mpr (Or.inr ho)))]

theorem sumAtL_le_of_pointwise (ps : List OutPoint) (l₁ l₂ : List (OutPoint × Coin))
    (h : ∀ o, coinValueAt l₁ o ≤ coinValueAt l₂ o) : sumAtL l₁ ps ≤ sumAtL l₂ ps := by
  induction ps with
  | nil => show (0:Int) ≤ (0:Int); exact Int.le_refl 0
  | cons q r ih =>
      rw [sumAtL_cons, sumAtL_cons]
      exact Int.add_le_add (h q) ih

theorem coinValueAt_nonneg (l : List (OutPoint × Coin)) (hval : ∀ p ∈ l, 0 ≤ p.2.value)
    (o : OutPoint) : 0 ≤ coinValueAt l o := by
  simp only [coinValueAt]
  rcases hc : coinLookup l o with _ | c
  · show (0:Int) ≤ (0:Int); exact Int.le_refl 0
  · obtain ⟨p, hp, _, h2⟩ := coinLookup_some_inv l o c hc
    show (0:Int) ≤ toI c.value
    rw [← h2]
    exact hval p hp

theorem sumAtL_nonneg (l : List (OutPoint × Coin)) (hval : ∀ p ∈ l, 0 ≤ p.2.value) :
    (ps : List OutPoint) → 0 ≤ sumAtL l ps
  | [] => by show (0:Int) ≤ (0:Int); exact Int.le_refl 0
  | q :: r => by
      rw [sumAtL_cons]
      exact Int.add_nonneg (coinValueAt_nonneg l hval q) (sumAtL_nonneg l hval r)

theorem coinValueAt_cons_le (p : OutPoint × Coin) (l : List (OutPoint × Coin))
    (hval : ∀ q ∈ p :: l, 0 ≤ q.2.value) (o : OutPoint) :
    coinValueAt (p :: l) o ≤ coinValueAt l o + p.2.value := by
  by_cases hb : (p.1 == o) = true
  · have hc : coinValueAt (p :: l) o = p.2.value := by
      simp [coinValueAt, coinLookup, hb]
    have h0 : (0:Int) ≤ toI (coinValueAt l o) := coinValueAt_nonneg l
      (fun q hq => hval q (List.mem_cons.mpr (Or.inr hq))) o
    have h1 : toI (coinValueAt (p :: l) o) = toI p.2.value := hc
    show toI (coinValueAt (p :: l) o) ≤ toI (coinValueAt l o) + toI p.2.value
    omega
  · have hc : coinValueAt (p :: l) o = coinValueAt l o := by
      simp [coinValueAt, coinLookup, hb]
    have h0 : (0:Int) ≤ toI (coinValueAt l o) := coinValueAt_nonneg l
      (fun q hq => hval q (List.mem_cons.mpr (Or.inr hq))) o
    have h1 : toI (coinValueAt (p :: l) o) = toI (coinValueAt l o) := hc
    have h2 : (0:Int) ≤ toI p.2.value := hval p (List.mem_cons.mpr (Or.inl rfl))
    show toI (coinValueAt (p :: l) o) ≤ toI (coinValueAt l o) + toI p.2.value
    omega

theorem sumAtL_cons_le (p : OutPoint × Coin) (l : List (OutPoint × Coin))
    (hval : ∀ q ∈ p :: l, 0 ≤ q.2.value) :
    ∀ (ps : List OutPoint), ps.Nodup →
    sumAtL (p :: l) ps ≤ sumAtL l ps + p.2.value := by
  intro ps
  induction ps with
  | nil =>
      intro _
      show (0:Int) ≤ (0:Int) + toI p.2.value
      have h1 : (0:Int) ≤ toI p.2.value := hval p (List.mem_cons.mpr (Or.inl rfl))
      omega
  | cons q r ih =>
      intro hnd
      obtain ⟨hqnr, hrnd⟩ := List.nodup_cons.mp hnd
      rw [sumAtL_cons, sumAtL_cons]
      have hcv : (0:Int) ≤ toI (coinValueAt l q) := coinValueAt_nonneg l
        (fun q' hq => hval q' (List.mem_cons.mpr (Or.inr hq))) q
      by_cases hb : (p.1 == q) = true
      · -- the head query hits the new pair; no other query can
        -- (nodup + BEQ = real equality)
        have hr : sumAtL (p :: l) r = sumAtL l r := by
          refine sumAtL_congr r (p :: l) l (fun o ho => ?_)
          have hne : (p.1 == o) = false := by
            cases hx : (p.1 == o) with
            | false => rfl
            | true =>
              exfalso
              have ho1 : p.1 = o := outPointBEq_eq _ _ hx
              have hq1 : p.1 = q := outPointBEq_eq _ _ hb
              have hoq : o = q := ho1.symm.trans hq1
              exact hqnr (hoq ▸ ho)
          simp [coinValueAt, coinLookup, hne]
        have hc : toI (coinValueAt (p :: l) q) = toI p.2.value := by
          simp [coinValueAt, coinLookup, hb]
        have hrI : toI (sumAtL (p :: l) r) = toI (sumAtL l r) := hr
        show toI (coinValueAt (p :: l) q) + toI (sumAtL (p :: l) r)
          ≤ toI (coinValueAt l q) + toI (sumAtL l r) + toI p.2.value
        omega
      · have hc : toI (coinValueAt (p :: l) q) = toI (coinValueAt l q) := by
          simp [coinValueAt, coinLookup, hb]
        have hih : toI (sumAtL (p :: l) r) ≤ toI (sumAtL l r) + toI p.2.value :=
          ih hrnd
        show toI (coinValueAt (p :: l) q) + toI (sumAtL (p :: l) r)
          ≤ toI (coinValueAt l q) + toI (sumAtL l r) + toI p.2.value
        omega

theorem sumAtL_cons_of_not_any (p : OutPoint × Coin) (l : List (OutPoint × Coin))
    (ps : List OutPoint) (h : (ps.any (fun q => p.1 == q)) = false) :
    sumAtL (p :: l) ps = sumAtL l ps := by
  refine sumAtL_congr ps (p :: l) l (fun o ho => ?_)
  have hq := listAny_false (fun q => p.1 == q) ps h o ho
  simp [coinValueAt, coinLookup, hq]

/-! ### S2b helpers: byte arrays, null outpoints, lookup-none -/

theorem blockDrawn_cons (tx : Tx) (rest : List Tx) :
    blockDrawn (tx :: rest) = tx.getValueOut + blockDrawn rest := by
  simp only [blockDrawn, List.foldl_cons]
  rw [foldl_add_split, Int.zero_add]

theorem zeroBytes_push (n : Nat) : zeroBytes (n + 1) = (zeroBytes n).push 0 := by
  rw [zeroBytes, List.range_succ, List.foldl_append]
  rfl

theorem zeroBytes_size (n : Nat) : (zeroBytes n).size = n := by
  induction n with
  | zero => rfl
  | succ k ih => rw [zeroBytes_push, ByteArray.size_push, ih]

theorem byteArray_get!_eq (b : ByteArray) (i : Nat) (h : i < b.size) :
    b.get! i = b[i]! := by
  rw [getElem!_pos b i h]
  have hd : i < b.data.size := h
  show b.data[i]! = b.data[i]
  exact getElem!_pos b.data i hd

theorem zeroBytes_get (n : Nat) : ∀ i < n, (zeroBytes n).get! i = 0 := by
  intro i
  induction n with
  | zero => intro h; exact absurd h (Nat.not_lt_zero i)
  | succ k ih =>
      intro h
      rcases Nat.lt_succ_iff_lt_or_eq.mp h with h1 | h1
      · have hsz : i < (zeroBytes k).size := by rw [zeroBytes_size]; exact h1
        rw [zeroBytes_push,
            byteArray_get!_eq _ i (by rw [ByteArray.size_push, zeroBytes_size]; omega),
            ByteArray.getElem!_push_lt _ _ i hsz,
            ← byteArray_get!_eq (zeroBytes k) i hsz]
        exact ih h1
      · rw [zeroBytes_push]
        have hsz : i < ((zeroBytes k).push 0).size := by
          rw [ByteArray.size_push, zeroBytes_size]; omega
        rw [byteArray_get!_eq _ i hsz, show i = (zeroBytes k).size from by
          rw [zeroBytes_size]; exact h1, ByteArray.getElem!_push_eq]

theorem outPointIsNull_beq (o : OutPoint) (h : o.isNull = true) :
    (o == OutPoint.null) = true := by
  simp only [OutPoint.isNull, decide_eq_true_eq] at h
  obtain ⟨hn, hsz, hall⟩ := h
  have hz : ∀ i < 32, (zeroBytes 32).get! i = 0 := zeroBytes_get 32
  have hbs : bytesBEq o.hash (zeroBytes 32) = true := by
    simp only [bytesBEq, decide_eq_true_eq]
    refine ⟨?_, ?_⟩
    · rw [zeroBytes_size]; exact hsz
    · apply List.all_eq_true.mpr
      intro i hi
      rw [hz i (by have := List.mem_range.mp hi; rw [hsz] at this; exact this)]
      exact List.all_eq_true.mp hall i hi
  have h0 : (o == OutPoint.null)
      = (bytesBEq o.hash (zeroBytes 32) && o.n == NULL_INDEX) := rfl
  rw [h0, hbs, hn, Bool.true_and]
  decide

theorem coinLookup_all_ne_of_none (l : List (OutPoint × Coin)) (o : OutPoint)
    (h : coinLookup l o = none) : ∀ p ∈ l, (p.1 == o) = false := by
  induction l with
  | nil => intro p hp; exact absurd hp (by simp)
  | cons q r ih =>
      intro p hp
      rcases List.mem_cons.mp hp with he | hr
      · subst he
        by_cases hb : (p.1 == o) = true
        · rw [coinLookup, if_pos hb] at h; simp at h
        · exact Bool.eq_false_iff.mpr hb
      · by_cases hb : (q.1 == o) = true
        · rw [coinLookup, if_pos hb] at h; simp at h
        · rw [coinLookup, if_neg hb] at h
          exact ih h p hr

theorem coinLookup_filter_none_of_none (l : List (OutPoint × Coin))
    (keep : OutPoint × Coin → Bool) (o : OutPoint) (h : coinLookup l o = none) :
    coinLookup (l.filter keep) o = none := by
  refine coinLookup_none_of_all_ne _ o (fun p hp => ?_)
  cases hb : (p.1 == o) with
  | false => rfl
  | true =>
      exfalso
      have hpe : p.1 = o := outPointBEq_eq _ _ hb
      have his := coinLookup_isSome_of_mem l p (List.mem_filter.mp hp).1
      rw [hpe, h] at his
      simp at his

theorem coinLookup_updateCoinsL_null_none (l : List (OutPoint × Coin)) (tx : Tx)
    (key : Key) (height : UInt32)
    (hnull : coinLookup l OutPoint.null = none)
    (hkey : ∀ k < tx.vout.length,
      scriptUnspendable (tx.vout.getD k ⟨0, Script.empty⟩).scriptPubKey = false →
      ((key OutPoint.null (UInt32.ofNat k)) == OutPoint.null) = false) :
    coinLookup (updateCoinsL l tx key height) OutPoint.null = none := by
  rw [updateCoinsL, coinLookup_append]
  have h1 : coinLookup (addedCoins tx key height) OutPoint.null = none := by
    refine coinLookup_none_of_all_ne _ _ (fun p hp => ?_)
    obtain ⟨j, hj, h3, hus, _⟩ := addedCoins_inv tx key height p hp
    rw [h3]
    exact hkey j hj hus
  have h2 : coinLookup
      (l.filter (fun p => tx.isCoinBase || !(tx.vin.any (fun i => i.prevout == p.1))))
      OutPoint.null = none :=
    coinLookup_filter_none_of_none l _ _ hnull
  rw [h1]
  exact h2

theorem outPointBEq_symm_true (a b : OutPoint) (h : (a == b) = true) :
    (b == a) = true := by
  rw [outPointBEq_eq a b h]
  exact outPointBeqSelf b

/-! ### S2b: fee/conservation plumbing for the block-level bound -/

theorem checkTxInputs_ok_haveInputs (tx : Tx) (u : UtxoSet) (height : UInt32)
    (fee : Amount) (h : checkTxInputs tx u height = .ok fee) :
    haveInputs tx u = true := by
  unfold checkTxInputs at h
  by_cases hi : haveInputs tx u = true
  · exact hi
  · rw [if_neg hi] at h
    simp at h

/-- `totalIn` over a view given by an assoc list, with an offset
accumulator, is the offset plus the sum at the prevouts. -/
theorem totalIn_acc_sumAtL (l : List (OutPoint × Coin)) :
    ∀ (vin : List TxIn) (a : Amount),
      vin.foldl (fun acc i => match coinLookup l i.prevout with
        | some c => acc + c.value | none => acc) a
        = a + sumAtL l (vin.map (·.prevout)) := by
  intro vin
  induction vin with
  | nil => intro a; show a = a + 0; rw [Int.add_zero]
  | cons i rest ih =>
      intro a
      rw [List.foldl_cons, List.map_cons, sumAtL_cons, ih]
      simp only [coinValueAt]
      rcases hc : coinLookup l i.prevout with _ | c
      · simp only [hc, Int.zero_add]
      · simp only [hc, Int.add_assoc]

theorem totalIn_eq_sumAtL (l : List (OutPoint × Coin)) (tx : Tx) :
    Bitcoin.Conservation.totalIn (viewOf l) tx = sumAtL l (tx.vin.map (·.prevout)) := by
  show tx.vin.foldl (fun acc i => match coinLookup l i.prevout with
    | some c => acc + c.value | none => acc) 0 = _
  rw [totalIn_acc_sumAtL l tx.vin 0, Int.zero_add]

theorem map_range_succ (n : Nat) :
    List.map (· + 1) (List.range (n + 1)) = List.map (· + 1) (List.range n) ++ [n + 1] := by
  rw [List.range_succ, List.map_append]
  rfl

theorem range_cons_succ (n : Nat) :
    List.range (n + 1) = 0 :: (List.range n).map (· + 1) := by
  induction n with
  | zero => rfl
  | succ k ih =>
      rw [show List.range (k + 1 + 1) = List.range (k + 1) ++ [k + 1] from List.range_succ,
        map_range_succ k, ih, List.cons_append]

theorem sum_getD_range (d : TxOut) (vout : List TxOut) :
    (List.range vout.length).foldl (fun a k => a + (vout.getD k d).value) 0
      = vout.foldl (fun a o => a + o.value) 0 := by
  induction vout with
  | nil => rfl
  | cons hd tl ih =>
      have h0 : (hd :: tl).length = tl.length + 1 := rfl
      rw [h0, range_cons_succ, List.foldl_cons, List.foldl_map]
      have hfun : (fun a k => a + ((hd :: tl).getD (k + 1) d).value)
          = (fun a k => a + (tl.getD k d).value) := by
        funext a k; rw [List.getD_cons_succ]
      rw [hfun]
      show List.foldl (fun a k => a + (tl.getD k d).value) (0 + hd.value)
          (List.range tl.length)
        = List.foldl (fun a o => a + o.value) (0 + hd.value) tl
      rw [foldl_add_split _ _ (0 + hd.value), ih]
      exact (foldl_add_split _ _ (0 + hd.value)).symm

theorem listTotal_filterMap_le (ks : List Nat) (F : Nat → Option (OutPoint × Coin))
    (v : Nat → Amount) (hv : ∀ k ∈ ks, 0 ≤ v k)
    (hF : ∀ k p c, F k = some (p, c) → c.value = v k) :
    listTotal (ks.filterMap F) ≤ ks.foldl (fun a k => a + v k) 0 := by
  induction ks with
  | nil => show (0:Int) ≤ (0:Int); exact Int.le_refl 0
  | cons k r ih =>
      rw [List.filterMap_cons, List.foldl_cons]
      cases hFk : F k with
      | none =>
          rw [foldl_add_split (fun k => v k) r (0 + v k), Int.zero_add]
          have hvk : (0:Int) ≤ toI (v k) := hv k (List.mem_cons.mpr (Or.inl rfl))
          have hih : toI (listTotal (r.filterMap F))
              ≤ toI (r.foldl (fun a k => a + v k) 0) :=
            ih (fun j hj => hv j (List.mem_cons.mpr (Or.inr hj)))
          show toI (listTotal (r.filterMap F))
            ≤ toI (v k) + toI (r.foldl (fun a k => a + v k) 0)
          omega
      | some pc =>
          rw [listTotal_cons, foldl_add_split (fun k => v k) r (0 + v k), Int.zero_add]
          have hvc : toI pc.2.value = toI (v k) := hF k pc.1 pc.2 hFk
          have hih : toI (listTotal (r.filterMap F))
              ≤ toI (r.foldl (fun a k => a + v k) 0) :=
            ih (fun j hj => hv j (List.mem_cons.mpr (Or.inr hj)))
          show toI pc.2.value + toI (listTotal (r.filterMap F))
            ≤ toI (v k) + toI (r.foldl (fun a k => a + v k) 0)
          omega

theorem listTotal_addedCoins_le (tx : Tx) (key : Key) (height : UInt32)
    (hvout : ∀ k < tx.vout.length, 0 ≤ (tx.vout.getD k ⟨0, Script.empty⟩).value) :
    listTotal (addedCoins tx key height) ≤ tx.getValueOut := by
  have h1 : listTotal (addedCoins tx key height)
      ≤ (List.range tx.vout.length).foldl
        (fun a k => a + (tx.vout.getD k ⟨0, Script.empty⟩).value) 0 := by
    refine listTotal_filterMap_le (List.range tx.vout.length)
      (fun k => if scriptUnspendable (tx.vout.getD k ⟨0, Script.empty⟩).scriptPubKey then
        (none : Option (OutPoint × Coin))
      else some (key OutPoint.null (UInt32.ofNat k),
            (⟨(tx.vout.getD k ⟨0, Script.empty⟩).value, height, tx.isCoinBase,
              (tx.vout.getD k ⟨0, Script.empty⟩).scriptPubKey⟩ : Coin)))
      (fun k => (tx.vout.getD k ⟨0, Script.empty⟩).value) ?hv ?hF
    · intro k hk; exact hvout k (List.mem_range.mp hk)
    · intro k p c hFk
      by_cases hus : scriptUnspendable (tx.vout.getD k ⟨0, Script.empty⟩).scriptPubKey = true
      · rw [if_pos hus] at hFk
        simp at hFk
      · rw [if_neg hus] at hFk
        have h3 := Option.some.inj hFk
        simp only [Prod.mk.injEq] at h3
        obtain ⟨_, h5⟩ := h3
        rw [← h5]
  have h2 : (List.range tx.vout.length).foldl
        (fun a k => a + (tx.vout.getD k ⟨0, Script.empty⟩).value) 0
      = tx.getValueOut :=
    sum_getD_range ⟨0, Script.empty⟩ tx.vout
  rw [← h2]
  exact h1

theorem getValueOut_nonneg (tx : Tx)
    (hvout : ∀ k < tx.vout.length, 0 ≤ (tx.vout.getD k ⟨0, Script.empty⟩).value) :
    0 ≤ tx.getValueOut := by
  have h : ∀ (vout : List TxOut),
      (∀ k < vout.length, 0 ≤ (vout.getD k ⟨0, Script.empty⟩).value) →
      0 ≤ vout.foldl (fun a o => a + o.value) 0 := by
    intro vout
    induction vout with
    | nil => intro _; show (0:Int) ≤ (0:Int); exact Int.le_refl 0
    | cons hd tl ih =>
        intro hv
        have h1 : (0:Int) ≤ toI hd.value := hv 0 (by simp)
        have h2 : (0:Int) ≤ toI (tl.foldl (fun a o => a + o.value) 0) :=
          ih (fun k hk => by
            have hvk := hv (k + 1) (by simp only [List.length_cons]; omega)
            rw [List.getD_cons_succ] at hvk
            exact hvk)
        rw [List.foldl_cons, foldl_add_split, Int.zero_add]
        show (0:Int) ≤ toI hd.value + toI (tl.foldl (fun a o => a + o.value) 0)
        omega
  show 0 ≤ tx.vout.foldl (fun a o => a + o.value) 0
  exact h tx.vout hvout

theorem value_nonneg_of_mem_updateCoinsL (l : List (OutPoint × Coin)) (tx : Tx) (key : Key)
    (height : UInt32) (hv : ∀ p ∈ l, 0 ≤ p.2.value)
    (hvout : ∀ k < tx.vout.length, 0 ≤ (tx.vout.getD k ⟨0, Script.empty⟩).value)
    (p : OutPoint × Coin) (h : p ∈ updateCoinsL l tx key height) : 0 ≤ p.2.value := by
  rw [updateCoinsL] at h
  rcases List.mem_append.mp h with h1 | h2
  · obtain ⟨j, hj, _, hus, h5⟩ := addedCoins_inv tx key height p h1
    rw [h5]
    exact hvout j hj
  · exact hv p (List.mem_filter.mp h2).1

theorem listTotal_updateCoinsL_le (l : List (OutPoint × Coin)) (tx : Tx) (key : Key)
    (height : UInt32) (hv : ∀ p ∈ l, 0 ≤ p.2.value)
    (hvout : ∀ k < tx.vout.length, 0 ≤ (tx.vout.getD k ⟨0, Script.empty⟩).value) :
    listTotal (updateCoinsL l tx key height) ≤ listTotal l + tx.getValueOut := by
  rw [updateCoinsL, listTotal_append]
  have h1 : toI (listTotal (addedCoins tx key height)) ≤ toI tx.getValueOut :=
    listTotal_addedCoins_le tx key height hvout
  have h2 : toI (listTotal
      (l.filter (fun p => tx.isCoinBase || !(tx.vin.any (fun i => i.prevout == p.1)))))
      ≤ toI (listTotal l) :=
    listTotal_filter_mono l _ hv
  show toI (listTotal (addedCoins tx key height))
      + toI (listTotal (l.filter (fun p => tx.isCoinBase || !(tx.vin.any (fun i => i.prevout == p.1)))))
    ≤ toI (listTotal l) + toI tx.getValueOut
  omega

/-- Master bound (B″): the value drawn at the (distinct) query points
plus the value kept by `keep` is at most the total value — kept entries
match no query, and `Nodup` bounds the head-hit contribution. -/
theorem sumAtL_add_kept_le (l : List (OutPoint × Coin)) (keep : OutPoint × Coin → Bool)
    (ps : List OutPoint) (hnd : ps.Nodup)
    (hval : ∀ p ∈ l, 0 ≤ p.2.value)
    (hkeep : ∀ p ∈ l, keep p = true → (ps.any (fun q => p.1 == q)) = false) :
    sumAtL l ps + listTotal (l.filter keep) ≤ listTotal l := by
  induction l with
  | nil =>
      have h0 : toI (sumAtL [] ps) = (0:Int) := sumAtL_nil ps
      have h1 : toI (listTotal (List.filter keep [])) = (0:Int) := rfl
      have h2 : toI (listTotal []) = (0:Int) := rfl
      show toI (sumAtL [] ps) + toI (listTotal (List.filter keep []))
        ≤ toI (listTotal [])
      omega
  | cons p r ih =>
      have hvalr : ∀ q ∈ r, 0 ≤ q.2.value :=
        fun q hq => hval q (List.mem_cons.mpr (Or.inr hq))
      by_cases hk : keep p = true
      · have hany : (ps.any (fun q => p.1 == q)) = false :=
          hkeep p (List.mem_cons.mpr (Or.inl rfl)) hk
        have hpt : ∀ o ∈ ps, coinValueAt (p :: r) o = coinValueAt r o := by
          intro o ho
          have hne := listAny_false (fun q => p.1 == q) ps hany o ho
          simp [coinValueAt, coinLookup, hne]
        rw [List.filter_cons_of_pos hk, sumAtL_congr ps _ _ hpt,
          listTotal_cons, listTotal_cons]
        have h1 : (0:Int) ≤ toI p.2.value := hval p (List.mem_cons.mpr (Or.inl rfl))
        have h2 : toI (sumAtL r ps) + toI (listTotal (r.filter keep))
            ≤ toI (listTotal r) :=
          ih (fun q hq => hval q (List.mem_cons.mpr (Or.inr hq)))
            (fun q hq hqk => hkeep q (List.mem_cons.mpr (Or.inr hq)) hqk)
        show toI (sumAtL r ps) + (toI p.2.value + toI (listTotal (r.filter keep)))
          ≤ toI p.2.value + toI (listTotal r)
        omega
      · rw [List.filter_cons_of_neg hk, listTotal_cons]
        have h1 : (0:Int) ≤ toI p.2.value := hval p (List.mem_cons.mpr (Or.inl rfl))
        have h2 : toI (sumAtL (p :: r) ps) ≤ toI (sumAtL r ps) + toI p.2.value :=
          sumAtL_cons_le p r hval ps hnd
        have h3 : toI (sumAtL r ps) + toI (listTotal (r.filter keep))
            ≤ toI (listTotal r) :=
          ih (fun q hq => hval q (List.mem_cons.mpr (Or.inr hq)))
            (fun q hq hqk => hkeep q (List.mem_cons.mpr (Or.inr hq)) hqk)
        show toI (sumAtL (p :: r) ps) + toI (listTotal (r.filter keep))
          ≤ toI p.2.value + toI (listTotal r)
        omega

/-! ### S2b: the block-level fee bound (THM-037, upper half) -/

/-- Executable twin of `chainFees`: per tx, the fee `checkTxInputs`
certifies on the RUNNING assoc-list view (0 on error), threading
`updateCoinsL` through every step — the same state discipline as
`applyTxStepL`/`applyBlockL`. -/
def chainFeesL (l : List (OutPoint × Coin)) (kf : Tx → Key) :
    List Tx → UInt32 → Amount
  | [], _ => 0
  | tx :: rest, height =>
    match checkTxInputs tx (viewOf l) height with
    | .ok fee => fee + chainFeesL (updateCoinsL l tx (kf tx) height) kf rest height
    | .error _ => chainFeesL (updateCoinsL l tx (kf tx) height) kf rest height

/-- The executable fee fold computes the point-tier fee fold on the
abstracted view (the prototype's discipline). -/
theorem chainFees_viewOf (kf : Tx → Key) :
    (txs : List Tx) → (height : UInt32) → ∀ (l : List (OutPoint × Coin)),
    chainFees (viewOf l) kf txs height = chainFeesL l kf txs height := by
  intro txs
  induction txs with
  | nil => intro height l; rfl
  | cons tx rest ih =>
      intro height l
      simp only [chainFees, chainFeesL]
      cases hci : checkTxInputs tx (viewOf l) height with
      | ok fee =>
          dsimp only
          rw [← updateCoinsL_abstract, ih height (updateCoinsL l tx (kf tx) height)]
      | error e =>
          dsimp only
          rw [← updateCoinsL_abstract, ih height (updateCoinsL l tx (kf tx) height)]

/-- THM-037 (upper half), executable form: the total fees collected by
connecting `txs` never exceed the value present in the starting UTXO
set plus the value the block's own outputs draw. Hypotheses: coins
nonneg, per-tx output values nonneg, per-tx prevout distinctness (each
input spent once — INV-110), keys never BEq-collide with the null
outpoint, and the null outpoint absent from the starting set. -/
theorem chainFeesL_le_blockDrawn (l : List (OutPoint × Coin)) (kf : Tx → Key)
    (txs : List Tx) (height : UInt32)
    (hval : ∀ p ∈ l, 0 ≤ p.2.value)
    (hrange : ∀ tx ∈ txs, ∀ k < tx.vout.length, 0 ≤ (tx.vout.getD k ⟨0, Script.empty⟩).value)
    (hnd : ∀ tx ∈ txs, (tx.vin.map (·.prevout)).Nodup)
    (hkey : ∀ tx ∈ txs, ∀ k < tx.vout.length,
      scriptUnspendable (tx.vout.getD k ⟨0, Script.empty⟩).scriptPubKey = false →
      ((kf tx) OutPoint.null (UInt32.ofNat k) == OutPoint.null) = false)
    (hnull : coinLookup l OutPoint.null = none) :
    chainFeesL l kf txs height ≤ listTotal l + blockDrawn txs := by
  have gen : ∀ (txs : List Tx) (height : UInt32) (l : List (OutPoint × Coin)),
      (∀ p ∈ l, 0 ≤ p.2.value) →
      (∀ tx ∈ txs, ∀ k < tx.vout.length, 0 ≤ (tx.vout.getD k ⟨0, Script.empty⟩).value) →
      (∀ tx ∈ txs, (tx.vin.map (·.prevout)).Nodup) →
      (∀ tx ∈ txs, ∀ k < tx.vout.length,
        scriptUnspendable (tx.vout.getD k ⟨0, Script.empty⟩).scriptPubKey = false →
        ((kf tx) OutPoint.null (UInt32.ofNat k) == OutPoint.null) = false) →
      (coinLookup l OutPoint.null = none) →
      chainFeesL l kf txs height ≤ listTotal l + blockDrawn txs := by
    intro txs
    induction txs with
    | nil =>
        intro height l hval _ _ _ _
        have hl : (0:Int) ≤ toI (listTotal l) := listTotal_nonneg l hval
        have hz : toI (blockDrawn []) = (0:Int) := rfl
        show (0:Int) ≤ toI (listTotal l) + toI (blockDrawn [])
        omega
    | cons tx rest ih =>
        intro height l hval hrange hnd hkey hnull
        simp only [chainFeesL]
        have hvout' : ∀ k < tx.vout.length, 0 ≤ (tx.vout.getD k ⟨0, Script.empty⟩).value :=
          hrange tx (List.mem_cons.mpr (Or.inl rfl))
        have hval' : ∀ p ∈ updateCoinsL l tx (kf tx) height, 0 ≤ p.2.value :=
          value_nonneg_of_mem_updateCoinsL l tx (kf tx) height hval hvout'
        have hrange' : ∀ q ∈ rest, ∀ k < q.vout.length,
            0 ≤ (q.vout.getD k ⟨0, Script.empty⟩).value :=
          fun q hq => hrange q (List.mem_cons.mpr (Or.inr hq))
        have hnd' : ∀ q ∈ rest, (q.vin.map (·.prevout)).Nodup :=
          fun q hq => hnd q (List.mem_cons.mpr (Or.inr hq))
        have hkey' : ∀ q ∈ rest, ∀ k < q.vout.length,
            scriptUnspendable (q.vout.getD k ⟨0, Script.empty⟩).scriptPubKey = false →
            ((kf q) OutPoint.null (UInt32.ofNat k) == OutPoint.null) = false :=
          fun q hq => hkey q (List.mem_cons.mpr (Or.inr hq))
        have hnull' : coinLookup (updateCoinsL l tx (kf tx) height) OutPoint.null = none :=
          coinLookup_updateCoinsL_null_none l tx (kf tx) height hnull
            (hkey tx (List.mem_cons.mpr (Or.inl rfl)))
        cases hci : checkTxInputs tx (viewOf l) height with
        | error e =>
            have hE : toI (listTotal (updateCoinsL l tx (kf tx) height))
                ≤ toI (listTotal l) + toI tx.getValueOut :=
              listTotal_updateCoinsL_le l tx (kf tx) height hval hvout'
            have hih : toI (chainFeesL (updateCoinsL l tx (kf tx) height) kf rest height)
                ≤ toI (listTotal (updateCoinsL l tx (kf tx) height))
                  + toI (blockDrawn rest) :=
              ih height (updateCoinsL l tx (kf tx) height) hval' hrange' hnd' hkey' hnull'
            rw [blockDrawn_cons]
            have hout : (0:Int) ≤ toI tx.getValueOut := getValueOut_nonneg tx hvout'
            show toI (chainFeesL (updateCoinsL l tx (kf tx) height) kf rest height)
              ≤ toI (listTotal l) + (toI tx.getValueOut + toI (blockDrawn rest))
            omega
        | ok fee =>
            -- a paying tx is not the coinbase: its (single) null prevout
            -- would have to resolve to a coin, contradicting `hnull`
            have hncb : tx.isCoinBase = false := by
              by_cases hb : tx.isCoinBase = true
              · exfalso
                have hhi : haveInputs tx (viewOf l) = true :=
                  checkTxInputs_ok_haveInputs tx (viewOf l) height fee hci
                simp only [haveInputs, Tx.isCoinBase, viewOf] at hhi hb
                cases hx : tx.vin with
                | nil => rw [hx] at hb; simp at hb
                | cons i0 tl =>
                    cases tl with
                    | nil =>
                        rw [hx] at hhi hb
                        have hb2 : i0.prevout.isNull = true := hb
                        have hall := List.all_eq_true.mp hhi
                        have hf := hall i0 (by simp)
                        rcases hcc : coinLookup l i0.prevout with _ | c
                        · rw [hcc] at hf; simp at hf
                        · have hbeq : (i0.prevout == OutPoint.null) = true :=
                            outPointIsNull_beq _ hb2
                          have hpeq : i0.prevout = OutPoint.null := outPointBEq_eq _ _ hbeq
                          rw [hpeq] at hcc
                          rw [hcc] at hnull
                          simp at hnull
                    | cons i1 tl2 =>
                        rw [hx] at hb
                        simp at hb
              · exact Bool.eq_false_iff.mpr hb
            obtain ⟨hcons, hfee⟩ := checkTxInputs_ok_conservation tx (viewOf l) height fee hci
            have hsum : toI (sumAtL l (tx.vin.map (·.prevout)))
                = toI tx.getValueOut + toI fee := by
              rw [← totalIn_eq_sumAtL]; exact hcons
            have hndtx : (tx.vin.map (·.prevout)).Nodup :=
              hnd tx (List.mem_cons.mpr (Or.inl rfl))
            have hmaster : toI (sumAtL l (tx.vin.map (·.prevout)))
                + toI (listTotal
                  (l.filter (fun p => tx.isCoinBase || !(tx.vin.any (fun i => i.prevout == p.1)))))
                ≤ toI (listTotal l) := by
              refine sumAtL_add_kept_le l
                (fun p => tx.isCoinBase || !(tx.vin.any (fun i => i.prevout == p.1)))
                (tx.vin.map (·.prevout)) hndtx hval ?_
              intro p hp hkp
              have h1 : (!(tx.vin.any (fun i => i.prevout == p.1))) = true := by
                have h0 : (tx.isCoinBase || !(tx.vin.any (fun i => i.prevout == p.1))) = true :=
                  hkp
                rw [hncb, Bool.false_or] at h0
                exact h0
              have h2 : (tx.vin.any (fun i => i.prevout == p.1)) = false :=
                boolEq_false_of_notEq_true h1
              apply listAny_false_intro
              intro q hq
              obtain ⟨i, hi, hq'⟩ := List.mem_map.mp hq
              have hf := listAny_false (fun i => i.prevout == p.1) tx.vin h2 i hi
              rw [← hq']
              cases hx : (p.1 == i.prevout) with
              | false => rfl
              | true =>
                  exfalso
                  have hcon : (i.prevout == p.1) = true := outPointBEq_symm_true _ _ hx
                  rw [hcon] at hf
                  exact Bool.noConfusion hf
            have hsplit : toI (listTotal (updateCoinsL l tx (kf tx) height))
                = toI (listTotal (addedCoins tx (kf tx) height))
                  + toI (listTotal
                    (l.filter (fun p => tx.isCoinBase || !(tx.vin.any (fun i => i.prevout == p.1))))) := by
              rw [updateCoinsL]; exact listTotal_append _ _
            have hAC : toI (listTotal (addedCoins tx (kf tx) height)) ≤ toI tx.getValueOut :=
              listTotal_addedCoins_le tx (kf tx) height hvout'
            have hfee' : (0:Int) ≤ toI fee := hfee
            have hstep : toI fee + toI (listTotal (updateCoinsL l tx (kf tx) height))
                ≤ toI (listTotal l) := by
              rw [hsplit]
              omega
            have hih : toI (chainFeesL (updateCoinsL l tx (kf tx) height) kf rest height)
                ≤ toI (listTotal (updateCoinsL l tx (kf tx) height))
                  + toI (blockDrawn rest) :=
              ih height (updateCoinsL l tx (kf tx) height) hval' hrange' hnd' hkey' hnull'
            rw [blockDrawn_cons]
            have hout : (0:Int) ≤ toI tx.getValueOut := getValueOut_nonneg tx hvout'
            show toI fee + toI (chainFeesL (updateCoinsL l tx (kf tx) height) kf rest height)
              ≤ toI (listTotal l) + (toI tx.getValueOut + toI (blockDrawn rest))
            omega
  exact gen txs height l hval hrange hnd hkey hnull

/-- Corollary at the frozen canonical keying: with the txid-preimage
key, a spendable output's coin can never sit at the null outpoint (the
key embeds the tx's serialization, which differs from 32 zero bytes). -/
theorem applyBlockL_fees_le (l : List (OutPoint × Coin)) (txs : List Tx) (height : UInt32)
    (hval : ∀ p ∈ l, 0 ≤ p.2.value)
    (hrange : ∀ tx ∈ txs, ∀ k < tx.vout.length, 0 ≤ (tx.vout.getD k ⟨0, Script.empty⟩).value)
    (hnd : ∀ tx ∈ txs, (tx.vin.map (·.prevout)).Nodup)
    (hser : ∀ tx ∈ txs, serTx tx ≠ zeroBytes 32)
    (hnull : coinLookup l OutPoint.null = none) :
    chainFeesL l txidPreimageKey txs height ≤ listTotal l + blockDrawn txs := by
  refine chainFeesL_le_blockDrawn l txidPreimageKey txs height hval hrange hnd ?_ hnull
  intro tx hmem k hk hus
  cases hx : ((txidPreimageKey tx) OutPoint.null (UInt32.ofNat k) == OutPoint.null) with
  | false => rfl
  | true =>
      exfalso
      have hbe : (txidPreimageKey tx) OutPoint.null (UInt32.ofNat k) = OutPoint.null :=
        outPointBEq_eq _ _ hx
      have hinj : serTx tx = zeroBytes 32 ∧ UInt32.ofNat k = NULL_INDEX := by
        simp only [txidPreimageKey] at hbe
        simpa [OutPoint.mk.injEq, OutPoint.null] using hbe
      exact hser tx hmem hinj.1

/-! ## REM-01 remediation: THEOREM-TIER row vehicles (BLK-097/098/100/102/105,
INV-028/113)

The rows below were tag-on-def only; these theorems state the row
conclusions directly.  BLK-096 is a `resolved` row (its loop theorem is
`BitcoinProofs.Theorems.CapstoneBip30Loop.applyBlockU_loop_iff`, verified
from this module) and is deliberately not duplicated here. -/

/-! ### BLK-097: own-hash-pinned canonical repeat exemptions -/

/-- Low 24 bits of the 91842 repeat hash (`…0a4d0a`). -/
theorem bip30_hash_91842_digits :
    BIP30_REPEAT_HASH_91842 / 2 ^ 192 % 2 ^ 24 = 0x0a4d0a := by
  decide

/-- Low 24 bits of the 91880 repeat hash (`…0743f1`). -/
theorem bip30_hash_91880_digits :
    BIP30_REPEAT_HASH_91880 / 2 ^ 192 % 2 ^ 24 = 0x0743f1 := by
  decide

/-- The 91842 block with its own pinned hash is exempt (gate off). -/
theorem bip30_repeat_91842_exempt :
    bip30EnforcedAtHashes 91842 BIP30_REPEAT_HASH_91842 BIP34_ACTIVATION_HASH = false := by
  unfold bip30EnforcedAtHashes bip30OwnHashPinned
  decide

/-- The 91880 block with its own pinned hash is exempt (gate off). -/
theorem bip30_repeat_91880_exempt :
    bip30EnforcedAtHashes 91880 BIP30_REPEAT_HASH_91880 BIP34_ACTIVATION_HASH = false := by
  unfold bip30EnforcedAtHashes bip30OwnHashPinned
  decide

/-- **BLK-097 vehicle**: on the canonical chain the two historical
duplicate-coinbase blocks are exempt — their canonical own hashes are
the pinned `…0a4d0a…` / `…0743f1…` hashes and `bip30EnforcedAtHashes`
is false at both heights. -/
@[rule "BLK-097"]
theorem bip30_repeat_exempt_canonical :
    bip30EnforcedAtHashes 91842 (BIP30_REPEAT_HASH_OF_HEIGHT 91842) BIP34_ACTIVATION_HASH = false ∧
    bip30EnforcedAtHashes 91880 (BIP30_REPEAT_HASH_OF_HEIGHT 91880) BIP34_ACTIVATION_HASH = false ∧
    BIP30_REPEAT_HASH_91842 / 2 ^ 192 % 2 ^ 24 = 0x0a4d0a ∧
    BIP30_REPEAT_HASH_91880 / 2 ^ 192 % 2 ^ 24 = 0x0743f1 := by
  refine ⟨?_, ?_, bip30_hash_91842_digits, bip30_hash_91880_digits⟩
  · rw [show BIP30_REPEAT_HASH_OF_HEIGHT 91842 = BIP30_REPEAT_HASH_91842 from by
      simp [BIP30_REPEAT_HASH_OF_HEIGHT]]
    exact bip30_repeat_91842_exempt
  · rw [show BIP30_REPEAT_HASH_OF_HEIGHT 91880 = BIP30_REPEAT_HASH_91880 from by
      simp [BIP30_REPEAT_HASH_OF_HEIGHT]]
    exact bip30_repeat_91880_exempt

/-! ### BLK-098: window skip and unconditional re-enable -/

/-- Any height above BIP34 cannot be an own-hash-pinned repeat. -/
theorem bip30OwnHashPinned_false_of_ne (h : UInt32) (ownHash : Nat)
    (h1 : h ≠ 91842) (h2 : h ≠ 91880) :
    bip30OwnHashPinned h ownHash = false := by
  unfold bip30OwnHashPinned
  simp [h1, h2]

theorem uint32_ne_91842_of_gt_bip34 (h : UInt32) (h34 : BIP34_HEIGHT < h) :
    h ≠ 91842 := by
  intro he
  rw [he] at h34
  exact absurd h34 (by decide)

theorem uint32_ne_91880_of_gt_bip34 (h : UInt32) (h34 : BIP34_HEIGHT < h) :
    h ≠ 91880 := by
  intro he
  rw [he] at h34
  exact absurd h34 (by decide)

theorem uint32_ne_91842_of_ge_limit (h : UInt32)
    (hge : BIP34_IMPLIES_BIP30_LIMIT ≤ h) : h ≠ 91842 := by
  intro he
  rw [he] at hge
  exact absurd hge (by decide)

theorem uint32_ne_91880_of_ge_limit (h : UInt32)
    (hge : BIP34_IMPLIES_BIP30_LIMIT ≤ h) : h ≠ 91880 := by
  intro he
  rw [he] at hge
  exact absurd hge (by decide)

/-- **BLK-098 (skip)**: once the chain's block at `BIP34_HEIGHT` is the
canonical BIP34 block (`bip34AncestorPinned`) and the height is still
below `BIP34_IMPLIES_BIP30_LIMIT`, BIP30 is elided — no own-hash
hypothesis is needed, because above BIP34 the height cannot be a repeat
exemption. -/
@[rule "BLK-098"]
theorem bip30_skip_after_bip34 (h : UInt32) (ownHash ancestorHash : Nat)
    (hlim : h < BIP34_IMPLIES_BIP30_LIMIT)
    (hanc : bip34AncestorPinned h ancestorHash = true) :
    bip30EnforcedAtHashes h ownHash ancestorHash = false := by
  unfold bip30EnforcedAtHashes
  have h34 : BIP34_HEIGHT < h :=
    of_decide_eq_true ((Bool.and_eq_true _ _).mp hanc |>.1)
  rw [bip30OwnHashPinned_false_of_ne h ownHash
    (uint32_ne_91842_of_gt_bip34 h h34)
    (uint32_ne_91880_of_gt_bip34 h h34)]
  have hanc' : (BIP34_HEIGHT < h && h < BIP34_IMPLIES_BIP30_LIMIT &&
      bip34AncestorPinned h ancestorHash) = true := by
    simp [h34, hlim, hanc]
  rw [hanc']
  simp

/-- **BLK-098 (re-enable)**: from `BIP34_IMPLIES_BIP30_LIMIT` on, BIP30
is enforced unconditionally (the window conjunct is false; the height is
far above the two own-hash exemptions). -/
@[rule "BLK-098"]
theorem bip30_reenabled_from_limit (h : UInt32) (ownHash ancestorHash : Nat)
    (hge : BIP34_IMPLIES_BIP30_LIMIT ≤ h) :
    bip30EnforcedAtHashes h ownHash ancestorHash = true := by
  unfold bip30EnforcedAtHashes
  rw [bip30OwnHashPinned_false_of_ne h ownHash
    (uint32_ne_91842_of_ge_limit h hge)
    (uint32_ne_91880_of_ge_limit h hge)]
  have hwin : (BIP34_HEIGHT < h && h < BIP34_IMPLIES_BIP30_LIMIT &&
      bip34AncestorPinned h ancestorHash) = false := by
    apply Bool.eq_false_iff.mpr
    intro hc
    have h1 : (BIP34_HEIGHT < h && h < BIP34_IMPLIES_BIP30_LIMIT) = true :=
      (Bool.and_eq_true _ _).mp hc |>.1
    have hlt : h < BIP34_IMPLIES_BIP30_LIMIT :=
      of_decide_eq_true ((Bool.and_eq_true _ _).mp h1 |>.2)
    have hle : BIP34_IMPLIES_BIP30_LIMIT.toNat ≤ h.toNat :=
      (UInt32.le_iff_toNat_le (a := BIP34_IMPLIES_BIP30_LIMIT) (b := h)).mp hge
    have hltn : h.toNat < BIP34_IMPLIES_BIP30_LIMIT.toNat :=
      (UInt32.lt_iff_toNat_lt (a := h) (b := BIP34_IMPLIES_BIP30_LIMIT)).mp hlt
    omega
  rw [hwin]
  simp

/-! ### BLK-100 / INV-028: the general maturity condition -/

/-- `maturityOk` holds iff every resolved input coin is either not a
coinbase coin or has `coinHeight + 100 ≤ spendHeight`. -/
theorem maturityOk_iff (u : UtxoSet) (tx : Tx) (height : UInt32) :
    maturityOk u tx height = true ↔
      ∀ i ∈ tx.vin, ∀ c : Coin, u i.prevout = some c →
        c.isCoinbase = false ∨
          c.height.toNat + COINBASE_MATURITY.toNat ≤ height.toNat := by
  unfold maturityOk
  constructor
  · intro h i hi c hc
    have h1 := List.all_eq_true.mp h i hi
    rw [hc] at h1
    simpa only [Bool.or_eq_true, Bool.not_eq_true', decide_eq_true_eq] using h1
  · intro h
    refine List.all_eq_true.mpr ?_
    intro i hi
    cases hc : u i.prevout with
    | none => rfl
    | some c =>
        rcases h i hi c hc with hnc | hle
        · simp [hnc]
        · have hd : decide (c.height.toNat + COINBASE_MATURITY.toNat ≤ height.toNat) = true :=
            decide_eq_true hle
          simp [hd]

/-- **BLK-100 / INV-028 vehicle**: the row's subtraction form — a
resolved input coin passes maturity iff it is not a coinbase coin or
`spendHeight − coinHeight ≥ 100`. -/
@[rule "BLK-100", rule "INV-028"]
theorem maturityOk_diff_iff (u : UtxoSet) (tx : Tx) (height : UInt32) :
    maturityOk u tx height = true ↔
      ∀ i ∈ tx.vin, ∀ c : Coin, u i.prevout = some c →
        c.isCoinbase = false ∨
          COINBASE_MATURITY.toNat ≤ height.toNat - c.height.toNat := by
  rw [maturityOk_iff]
  constructor
  · intro h i hi c hc
    rcases h i hi c hc with hnc | hle
    · exact Or.inl hnc
    · refine Or.inr ?_
      have hc100 : COINBASE_MATURITY.toNat = 100 := rfl
      omega
  · intro h i hi c hc
    rcases h i hi c hc with hnc | hle
    · exact Or.inl hnc
    · refine Or.inr ?_
      have hc100 : COINBASE_MATURITY.toNat = 100 := rfl
      omega

theorem maturityOk_false_of_immature (u : UtxoSet) (tx : Tx) (height : UInt32)
    (i : TxIn) (hi : i ∈ tx.vin) (c : Coin) (hc : u i.prevout = some c)
    (hcb : c.isCoinbase = true)
    (himm : height.toNat < c.height.toNat + COINBASE_MATURITY.toNat) :
    maturityOk u tx height = false := by
  unfold maturityOk
  refine listAll_false_of_mem _ _ i hi ?_
  rw [hc]
  simp [hcb]
  exact himm

/-- **BLK-100 / INV-028 (reject)**: an available but immature coinbase
input rejects the step with Core's exact
`bad-txns-premature-spend-of-coinbase`. -/
@[rule "BLK-100", rule "INV-028"]
theorem applyTxStepU_premature_of_coin (u : UtxoSet) (tx : Tx) (key : Key)
    (height : UInt32) (hcb : tx.isCoinBase = false)
    (hi : inputsAvailable u tx = true)
    (i : TxIn) (himem : i ∈ tx.vin) (c : Coin) (hc : u i.prevout = some c)
    (hcis : c.isCoinbase = true)
    (himm : height.toNat < c.height.toNat + COINBASE_MATURITY.toNat) :
    applyTxStepU u tx key height =
      Except.error (BlockError.txError TxError.badTxnsPrematureSpendOfCoinbase) := by
  have hm : maturityOk u tx height = false :=
    maturityOk_false_of_immature u tx height i himem c hc hcis himm
  unfold applyTxStepU
  rw [if_neg (by simp [hcb]), if_neg (by simp [hi]), if_pos (by simp [hm])]

/-- **BLK-100 / INV-028 (accept)**: with all inputs available and
`maturityOk` true, the step succeeds (maturity is the last per-tx
gate). -/
@[rule "BLK-100", rule "INV-028"]
theorem applyTxStepU_mature_ok (u : UtxoSet) (tx : Tx) (key : Key)
    (height : UInt32) (hcb : tx.isCoinBase = false)
    (hi : inputsAvailable u tx = true) (hm : maturityOk u tx height = true) :
    ∃ w, applyTxStepU u tx key height = Except.ok w := by
  unfold applyTxStepU
  rw [if_neg (by simp [hcb]), if_neg (by simp [hi]), if_neg (by simp [hm])]
  exact ⟨_, rfl⟩

/-! ### BLK-102: every prevout present -/

/-- **BLK-102 (iff)**: `inputsAvailable` means every input prevout
resolves to a coin in the view. -/
@[rule "BLK-102"]
theorem inputsAvailable_iff (u : UtxoSet) (tx : Tx) :
    inputsAvailable u tx = true ↔ ∀ i ∈ tx.vin, (u i.prevout).isSome = true := by
  unfold inputsAvailable
  rw [List.all_eq_true]

/-- **BLK-102 (reject)**: a missing input rejects with Core's exact
`bad-txns-inputs-missingorspent` (no stale BIP30 side condition — the
post-D4c-2 step is BIP30-free). -/
@[rule "BLK-102"]
theorem applyTxStepU_inputs_missing (u : UtxoSet) (tx : Tx) (key : Key)
    (height : UInt32) (hcb : tx.isCoinBase = false)
    (h : inputsAvailable u tx = false) :
    applyTxStepU u tx key height =
      Except.error (BlockError.txError TxError.badTxnsInputsMissingOrSpent) := by
  unfold applyTxStepU
  rw [if_neg (by simp [hcb]), if_pos (by simp [h])]

/-- **BLK-102 (per-prevout)**: one absent prevout is enough. -/
@[rule "BLK-102"]
theorem applyTxStepU_missing_prevout (u : UtxoSet) (tx : Tx) (key : Key)
    (height : UInt32) (hcb : tx.isCoinBase = false)
    (i : TxIn) (himem : i ∈ tx.vin) (hi : u i.prevout = none) :
    applyTxStepU u tx key height =
      Except.error (BlockError.txError TxError.badTxnsInputsMissingOrSpent) := by
  refine applyTxStepU_inputs_missing u tx key height hcb ?_
  unfold inputsAvailable
  exact listAll_false_of_mem _ _ i himem (by rw [hi]; rfl)

/-! ### BLK-105: CTxUndo layout -/

/-- **BLK-105 vehicle**: the undo payload is exactly the input-ordered
filterMap of resolved `(prevout, prior coin)` pairs; every entry names an
input whose prevout held precisely that coin; and a payload lookup hit
certifies the coin was in the pre-state. -/
@[rule "BLK-105"]
theorem spentUndo_layout (u : UtxoSet) (tx : Tx) :
    spentUndo u tx =
        tx.vin.filterMap (fun i => (u i.prevout).map (fun c => (i.prevout, c))) ∧
    (∀ q ∈ spentUndo u tx, ∃ i, i ∈ tx.vin ∧ i.prevout = q.1 ∧ u q.1 = some q.2) ∧
    (∀ (o : OutPoint) (c : Coin), coinLookup (spentUndo u tx) o = some c → u o = some c) := by
  refine ⟨?_, ?_, ?_⟩
  · unfold spentUndo
    congr 1
    funext i
    cases u i.prevout <;> rfl
  · intro q hq
    exact spentUndo_inv u tx q hq
  · intro o c h
    exact spentUndo_hit u tx o c h

/-! ### INV-113: coinbase overwrite in the pre-BIP30 regime -/

theorem updateCoins_coinbase_overwrite (u : UtxoSet) (tx : Tx) (key : Key)
    (height : UInt32) (hcb : tx.isCoinBase = true) (p : OutPoint) (c cOld : Coin)
    (hpresent : u p = some cOld)
    (hnew : coinLookup (addedCoins tx key height) p = some c) :
    updateCoins u tx key height p = some c := by
  unfold updateCoins
  rw [hnew]

/-- **INV-113 vehicle**: under `bip30Enforced = false` a coinbase tx (a)
steps successfully, (b) overwrites the prior coin at a re-created
outpoint with the new coin (new-wins `updateCoins`), and (c) the block
application is exactly the BIP30-free fold. -/
@[rule "INV-113"]
theorem inv113_coinbase_overwrite_pre_bip30 (u : UtxoSet) (kf : Tx → Key)
    (txs : List Tx) (height : UInt32) (henf : bip30Enforced height = false)
    (tx : Tx) (p : OutPoint) (c cOld : Coin)
    (hcb : tx.isCoinBase = true) (hpresent : u p = some cOld)
    (hnew : coinLookup (addedCoins tx (kf tx) height) p = some c) :
    applyTxStepU u tx (kf tx) height = Except.ok (updateCoins u tx (kf tx) height) ∧
      updateCoins u tx (kf tx) height p = some c ∧
      applyBlockU u kf txs height = applyBlockFoldU u kf txs height := by
  refine ⟨?_, updateCoins_coinbase_overwrite u tx (kf tx) height hcb p c cOld
    hpresent hnew, ?_⟩
  · unfold applyTxStepU
    rw [if_pos (by simp [hcb])]
  · unfold applyBlockU
    rw [if_neg (by simp [henf])]
