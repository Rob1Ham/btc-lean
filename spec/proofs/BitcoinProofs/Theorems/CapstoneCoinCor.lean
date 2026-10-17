import Bitcoin.Capstone.Block

/-!
# BitcoinProofs.Theorems.CapstoneCoinCor — P14 (W17 capstone review): the
proved UTXO-view spec over the REAL assoc-list read path (sorry-free)

Executable-tier counterpart of W12's abstract ledger tier. W17's
`lake exe capstone` runs the real pipeline over 6 mainnet anchor blocks
(genesis, 74638, 91842, 91880, 481824, 709632): decode → structure →
PoW/chain-link → merkle/witness-commitment → per-tx script (real ECDSA)
→ ledger fold, 6/6 PASS with 11,825 inputs adjudicated. Every lookup the
run performs goes through `Bitcoin.Ledger.coinLookup`; the theorems below
turn its runtime `Option Coin` results into proved statements about the
REAL assoc-list functions (no new definitions — W12's surface, reused).

C4/rule-linkage table (axiom footprints verified by the `#guard_msgs`
pins at the bottom of this file):

| rule / linkage | theorem here | statement (short) |
|----------------|--------------|-------------------|
| (executable tier) | `coinLookup_nil` | the empty view looks up to `none` (BLK-110's executable reading) |
| (executable tier) | `coinLookup_cons` | the cons unfolding — the definition, exactly |
| (first-match read) | `coinLookup_first_match` | a head whose key `BEq`-matches answers with the head's coin (the first-match-wins semantics `viewOf`/seeds rely on) |
| (first-match read) | `coinLookup_miss_cons` | a head whose key misses defers to the tail |
| (HaveInputs miss lane) | `coinLookup_absent` / `coinLookup_absent_cons` | a key absent from every entry looks up to `none` — the `coinLookup = none` arm of `verifyTxInputs` (Capstone/Block.lean:260-261) and of `HaveInputs` (coins.cpp:322-331) |
| (fold key lemma, INV-111) | `coinLookup_updateCoinsL_hit` | the coin a tx creates for output `j` IS found in `updateCoinsL l tx kf height` (with distinct output keys) — the insert half of the W12 fold |
| (fold key lemma, INV-111) | `coinLookup_updateCoinsL_isSome` | the same presence fact WITHOUT key-uniqueness (first-match-wins answers with some coin) |
| (fold key lemma) | `coinLookup_updateCoinsL_fields` | the found coin carries the connection `height` and the tx's coinbase bit (INV-115 data model) |
| (BEq lawfulness) | `outPoint_beq_self` / `outPoint_eq_of_beq` / `outPoint_ne_of_beq_false` | `OutPoint`'s `BEq` (bytesBEq && n) is reflexive and sound, so lookup misses are meaningful equalities |

Dependencies: W12's proved ledger layer (`Bitcoin.Ledger.Interface` —
`coinLookup`, `addedCoins`, `updateCoinsL`, `addedCoins_lookup_eq`,
`coinLookup_append`, all sorry-free), reached through the capstone's
`Bitcoin.Capstone.Block` import. No mathlib use.

Axiom note: every theorem here has the UNIFORM footprint
`[propext, Classical.choice, Quot.sound]` — `Classical.choice` is
inherited from the W12 layer this package generalizes from (e.g.
`bytesBEq_eq_of_true`, `addedCoins_lookup_eq`, `coinLookup_some_inv`
all carry it); no `sorryAx` anywhere (the pins below fail the build on
any drift). The rfl-level lemmas (`coinLookup_nil/cons`) show the same
footprint because `#print axioms` sees the whole definitional package —
recorded as measured, not as claimed.
-/

namespace BitcoinProofs.Theorems.CapstoneCoin

open Bitcoin.Data Bitcoin.Ledger

/-! ## 1–2: the defining equations -/

/-- The empty assoc list looks up to `none` — the executable reading of
the BLK-110 empty view (`viewOf [] = emptyUtxo`). -/
theorem coinLookup_nil (o : OutPoint) : coinLookup [] o = none := rfl

/-- The cons unfolding of the read path — exactly W12's definition
(first match wins; `List.find?` semantics). -/
theorem coinLookup_cons (p : OutPoint × Coin) (ps : List (OutPoint × Coin)) (o : OutPoint) :
    coinLookup (p :: ps) o = if p.1 == o then some p.2 else coinLookup ps o := rfl

/-! ## 3–4: first-match semantics at the head -/

/-- First-match hit: a head whose key `BEq`-matches `o` answers with the
head's coin, whatever the tail holds. -/
theorem coinLookup_first_match (p : OutPoint × Coin) (ps : List (OutPoint × Coin))
    (o : OutPoint) (h : (p.1 == o) = true) :
    coinLookup (p :: ps) o = some p.2 := by
  rw [coinLookup_cons]
  rw [if_pos h]

/-- First-match miss: a head whose key `BEq`-misses `o` defers to the
tail — the lookup descends, so misses are meaningful equalities. -/
theorem coinLookup_miss_cons (p : OutPoint × Coin) (ps : List (OutPoint × Coin))
    (o : OutPoint) (h : (p.1 == o) = false) :
    coinLookup (p :: ps) o = coinLookup ps o := by
  rw [coinLookup_cons]
  rw [h]
  rfl

/-! ## 5: the HaveInputs-miss lane -/

/-- **THE HAVEINPUTS-MISS LEMMA.** An outpoint on which every entry of
the view `BEq`-misses looks up to `none`. This is exactly the
`coinLookup u prevout = none` arm of the capstone's `verifyTxInputs`
(Capstone/Block.lean:260-261) — the lane where Core's `HaveInputs`
(coins.cpp:322-331) routes to `bad-txns-inputs-missingorspent` via
W12/W10's check — and the `none` lane of every `updateCoins` step. -/
theorem coinLookup_absent (ps : List (OutPoint × Coin)) (o : OutPoint)
    (h : ∀ q ∈ ps, (q.1 == o) = false) :
    coinLookup ps o = none := by
  induction ps with
  | nil => exact coinLookup_nil o
  | cons q r ih =>
    have hq := h q (List.mem_cons.mpr (Or.inl rfl))
    rw [coinLookup_miss_cons q r o hq]
    exact ih (fun p hp => h p (List.mem_cons.mpr (Or.inr hp)))

/-- The cons form of the miss lane: a missing head and an all-missing
tail leave the lookup empty. -/
theorem coinLookup_absent_cons (p : OutPoint × Coin) (ps : List (OutPoint × Coin))
    (o : OutPoint) (hq : (p.1 == o) = false) (h : ∀ q ∈ ps, (q.1 == o) = false) :
    coinLookup (p :: ps) o = none := by
  rw [coinLookup_miss_cons p ps o hq]
  exact coinLookup_absent ps o h

/-! ## 6: the fold key lemma — the newly created coin IS found -/

/-- **THE FOLD KEY LEMMA (INV-111, insert half).** For a spendable
in-range output `j` of `tx`, with distinct output keys, the coin the
executable fold `updateCoinsL l tx kf height` creates is found by
`coinLookup` at `kf tx j` — with exactly W12's fields: output `j`'s
value and script, the connection `height`, and the tx's coinbase bit.
Prepended new coins precede the filtered old list, and a head hit wins
before the tail is consulted, so the pre-state `l` is irrelevant. -/
theorem coinLookup_updateCoinsL_hit (l : List (OutPoint × Coin)) (tx : Tx) (kf : Tx → Key)
    (height : UInt32) (j : Nat) (hj : j < tx.vout.length)
    (hus : scriptUnspendable (tx.vout.getD j ⟨0, Script.empty⟩).scriptPubKey = false)
    (huniq : ∀ i k : Nat, i < tx.vout.length → k < tx.vout.length →
      kf tx OutPoint.null (UInt32.ofNat i) = kf tx OutPoint.null (UInt32.ofNat k) → i = k) :
    coinLookup (updateCoinsL l tx (kf tx) height) (kf tx OutPoint.null (UInt32.ofNat j)) =
      some ⟨(tx.vout.getD j ⟨0, Script.empty⟩).value, height, tx.isCoinBase,
        (tx.vout.getD j ⟨0, Script.empty⟩).scriptPubKey⟩ := by
  unfold updateCoinsL
  rw [coinLookup_append, addedCoins_lookup_eq tx (kf tx) height j hj hus huniq]

/-- INV-111 (presence form): even WITHOUT distinct output keys, the
coin created for a spendable in-range output `j` is found by
`coinLookup` in the updated list — first-match-wins answers with *some*
coin at the created key, which is all `inputsAvailable` /
`verifyTxInputs`' hit arm needs. -/
theorem coinLookup_updateCoinsL_isSome (l : List (OutPoint × Coin)) (tx : Tx) (kf : Tx → Key)
    (height : UInt32) (j : Nat) (hj : j < tx.vout.length)
    (hus : scriptUnspendable (tx.vout.getD j ⟨0, Script.empty⟩).scriptPubKey = false) :
    (coinLookup (updateCoinsL l tx (kf tx) height)
      (kf tx OutPoint.null (UInt32.ofNat j))).isSome = true := by
  unfold updateCoinsL
  have hmem : (kf tx OutPoint.null (UInt32.ofNat j),
      ⟨(tx.vout.getD j ⟨0, Script.empty⟩).value, height, tx.isCoinBase,
        (tx.vout.getD j ⟨0, Script.empty⟩).scriptPubKey⟩)
      ∈ addedCoins tx (kf tx) height :=
    addedCoins_mem tx (kf tx) height j hj hus
  cases hcl : coinLookup (addedCoins tx (kf tx) height)
      (kf tx OutPoint.null (UInt32.ofNat j)) with
  | some c => rw [coinLookup_append, hcl]; rfl
  | none =>
    exfalso
    have h1 := coinLookup_isSome_of_mem (addedCoins tx (kf tx) height) _ hmem
    rw [hcl] at h1
    exact Bool.noConfusion h1

/-- The coin found by the fold key lemma carries the connection `height`
and the tx's coinbase bit (INV-115's data model: `fCoinBase` travels
with the coin; the height is the BIP34-maturity stamp). -/
theorem coinLookup_updateCoinsL_fields (l : List (OutPoint × Coin)) (tx : Tx) (kf : Tx → Key)
    (height : UInt32) (j : Nat) (hj : j < tx.vout.length)
    (hus : scriptUnspendable (tx.vout.getD j ⟨0, Script.empty⟩).scriptPubKey = false)
    (huniq : ∀ i k : Nat, i < tx.vout.length → k < tx.vout.length →
      kf tx OutPoint.null (UInt32.ofNat i) = kf tx OutPoint.null (UInt32.ofNat k) → i = k) :
    (coinLookup (updateCoinsL l tx (kf tx) height)
        (kf tx OutPoint.null (UInt32.ofNat j))).map (fun c => c.height) = some height ∧
    (coinLookup (updateCoinsL l tx (kf tx) height)
        (kf tx OutPoint.null (UInt32.ofNat j))).map (fun c => c.isCoinbase) =
      some tx.isCoinBase := by
  rw [coinLookup_updateCoinsL_hit l tx kf height j hj hus huniq]
  exact ⟨rfl, rfl⟩

/-! ## 7: OutPoint BEq lawfulness — misses are meaningful equalities -/

/-- `OutPoint`'s `BEq` instance (bytesBEq of the 32-byte hash && the
index) is reflexive. -/
theorem outPoint_beq_self (a : OutPoint) : (a == a) = true := outPointBeqSelf a

/-- `OutPoint`'s `BEq` is sound: a `true` comparison is real equality
(structural, via the byte-array argument). -/
theorem outPoint_eq_of_beq (a b : OutPoint) (h : (a == b) = true) : a = b :=
  outPointBEq_eq a b h

/-- The contrapositive at the type level: a `BEq` miss separates the
outpoints — so `coinLookup_absent`'s hypothesis is an honest disequality
condition, and a coin stored under `p.1` can only be missed by lookups
at genuinely different outpoints. -/
theorem outPoint_ne_of_beq_false (a b : OutPoint) (h : (a == b) = false) : a ≠ b := by
  intro he
  rw [he] at h
  exact Bool.noConfusion ((outPoint_beq_self b).symm.trans h)

/-- Lookup-hit soundness: `some c` answers carry a witness entry whose
key is REALLY `o` and whose coin is REALLY `c` (W12's
`coinLookup_some_inv`, re-pinned here as the read-path contract). -/
theorem coinLookup_hit_mem (l : List (OutPoint × Coin)) (o : OutPoint) (c : Coin)
    (h : coinLookup l o = some c) : ∃ p ∈ l, p.1 = o ∧ p.2 = c :=
  coinLookup_some_inv l o c h

/-! ## Axiom-footprint pins (L3): drift on any of these fails the build -/

/-- info: 'BitcoinProofs.Theorems.CapstoneCoin.coinLookup_nil' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (info, whitespace := lax) in #print axioms coinLookup_nil

/-- info: 'BitcoinProofs.Theorems.CapstoneCoin.coinLookup_cons' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (info, whitespace := lax) in #print axioms coinLookup_cons

/-- info: 'BitcoinProofs.Theorems.CapstoneCoin.coinLookup_first_match' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (info, whitespace := lax) in #print axioms coinLookup_first_match

/-- info: 'BitcoinProofs.Theorems.CapstoneCoin.coinLookup_miss_cons' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (info, whitespace := lax) in #print axioms coinLookup_miss_cons

/-- info: 'BitcoinProofs.Theorems.CapstoneCoin.coinLookup_absent' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (info, whitespace := lax) in #print axioms coinLookup_absent

/-- info: 'BitcoinProofs.Theorems.CapstoneCoin.coinLookup_absent_cons' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (info, whitespace := lax) in #print axioms coinLookup_absent_cons

/-- info: 'BitcoinProofs.Theorems.CapstoneCoin.coinLookup_updateCoinsL_hit' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (info, whitespace := lax) in #print axioms coinLookup_updateCoinsL_hit

/-- info: 'BitcoinProofs.Theorems.CapstoneCoin.coinLookup_updateCoinsL_isSome' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (info, whitespace := lax) in #print axioms coinLookup_updateCoinsL_isSome

/-- info: 'BitcoinProofs.Theorems.CapstoneCoin.coinLookup_updateCoinsL_fields' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (info, whitespace := lax) in #print axioms coinLookup_updateCoinsL_fields

/-- info: 'BitcoinProofs.Theorems.CapstoneCoin.outPoint_beq_self' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (info, whitespace := lax) in #print axioms outPoint_beq_self

/-- info: 'BitcoinProofs.Theorems.CapstoneCoin.outPoint_eq_of_beq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (info, whitespace := lax) in #print axioms outPoint_eq_of_beq

/-- info: 'BitcoinProofs.Theorems.CapstoneCoin.outPoint_ne_of_beq_false' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (info, whitespace := lax) in #print axioms outPoint_ne_of_beq_false

/-- info: 'BitcoinProofs.Theorems.CapstoneCoin.coinLookup_hit_mem' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (info, whitespace := lax) in #print axioms coinLookup_hit_mem

end BitcoinProofs.Theorems.CapstoneCoin
