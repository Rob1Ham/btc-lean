import Bitcoin.Capstone.Block

/-!
# BitcoinProofs.Theorems.CapstoneTxidCor — P06: proved txid-keying spec (sorry-free)

The capstone run keyed the ledger fold by the REAL txid:
`Bitcoin.Capstone.Block.txidKey tx = fun _ k ⇒ ⟨txidOf tx, k⟩` (BLK-005),
replacing test placeholder `Bitcoin.Ledger.txidPreimageKey tx =
fun _ k ⇒ ⟨serTx tx, k⟩` (the preimage itself in the hash slot). This
module turns that runtime keying choice into proved statements, all at
the Capstone surface (`Bitcoin.Capstone.Merkle.txidOf`/`wtxidOf`,
`Bitcoin.Capstone.Block.txidKey`, `Bitcoin.Ledger.applyBlockU`).

HONEST REPORTING — the placeholder-agreement question (package aim 2):
`txidKey tx v k = txidPreimageKey tx v k` asks for `txidOf tx = serTx tx`,
i.e. a hash equalling its own preimage. That is FALSE in general —
`txidKey_placeholder_differ_example` exhibits a concrete tx (the empty tx)
where the two keys differ (32-byte hash vs 10-byte preimage). Nor does
`¬hasWitness` help: `serTx` ignores the witness entirely, so the base-tx
hypothesis is vacuous. The honest bridge is the *hash chain*: the two keys
agree on the index component, and the txid-keyed key's hash is exactly
`sha256d` of the placeholder key's hash (`txidKey_placeholder_hash_chain`).

C4 portfolio linkage:

| C4 ID / rule | theorem here | statement (short) |
|--------------|--------------|-------------------|
| BLK-005 | `txidOf_eq_dsha256_serTx`, `txidKey_eq`, `txidKey_eq_dsha` | txid = SHA256d(serTx); the ledger key applies it: `txidKey tx v k = ⟨txidOf tx, k⟩` |
| BLK-005 (keying vs) | `txidKey_placeholder_index_agrees`, `txidKey_placeholder_hash_chain`, `txidKey_agrees_placeholder_of_txid_eq_preimage`, `txidKey_placeholder_differ_example` | keys agree on `n`; hash slot related by `sha256d`; NOT equal in general (concrete counterexample) |
| BLK-005 (BIP30, 91842/91880) | `txidOf_congr`, `txidKey_congr`, `bip30_collision_same_txid` | same base serialization ⇒ same txid ⇒ same key ⇒ identical addedCoins ⇒ the BIP30 duplicate-coinbase collision fires |
| BLK-006 | `wtxidOf_eq_txidOf_of_no_witness`, `wtxidOf_eq_dsha256_encodeTx_of_hasWitness`, `wtxidOf_eq_datalaws_wtxid` | wtxid = txid verbatim when no witness; = SHA256d(encodeTx) otherwise; bridge to `DataLaws.wtxid` |
| TXV-017 cor | `serTx_witness_independence`, `txidOf_witness_independence`, `txidKey_witness_independence`, `hasWitness_datalaws_eq` | witness data never touches the txid or the key (corollary of `DataLaws.txid_witness_independence`) |
| BLK-102 / INV-111 (fold) | `txidKey_ofNat_inj`, `addedCoins_txidKey_lookup`, `coinbase_coin_keyed_by_txid`, `no_double_spend_txidKey` | the fold inserts/looks up coins at outpoints `⟨txidOf tx, j⟩` — the REAL txid, on the nose |

Axiom footprints (verified by the `#guard_msgs` pins at the bottom):
all theorems land in `[propext, Quot.sound]` or smaller; none pulls
`sorryAx` (`sha256d` is real) or `Classical.choice`.

Dependencies: `Bitcoin.Capstone.Block` (which transitively carries
`Bitcoin.Capstone.Merkle`, `Bitcoin.Ledger.Interface`, `Bitcoin.DataLaws`,
`Bitcoin.Serialization.Interface`), plus `Bitcoin.DataLaws.
txid_witness_independence` as the bridge.
-/

namespace BitcoinProofs.Theorems.CapstoneTxid

open Bitcoin.Data Bitcoin.Ledger Bitcoin.Serialization
open Bitcoin.Crypto.Seam
open Bitcoin.Capstone.Merkle Bitcoin.Capstone.Block

/-! ## §1. BLK-005 unfold pins: the Capstone txid surface -/

/-- **BLK-005** unfold: the Capstone txid is `SHA256d` of the base
(no-witness) serialization — the same pipeline as `DataLaws.txid`
(`Bitcoin.DataLaws.txid_eq_dsha256_serTx` at the surface). -/
theorem txidOf_eq_dsha256_serTx (tx : Tx) : txidOf tx = sha256d (serTx tx) := rfl

/-- The Capstone txid IS `DataLaws.txid` (definitional link between
the BLK-005 merkle-leaf function and the TXV-017 data law). -/
theorem txidOf_eq_datalaws_txid (tx : Tx) : txidOf tx = Bitcoin.DataLaws.txid tx := rfl

/-- **BLK-005 keying, point form**: the ledger key applied to
`(v, k)` is the outpoint whose hash is the REAL txid and whose index is
`k`. -/
theorem txidKey_eq (tx : Tx) (v : OutPoint) (k : UInt32) :
    txidKey tx v k = ⟨txidOf tx, k⟩ := rfl

/-- The placeholder key applied to `(v, k)`: the outpoint whose hash
is the base serialization itself (the txid *preimage*). -/
theorem txidPreimageKey_eq (tx : Tx) (v : OutPoint) (k : UInt32) :
    txidPreimageKey tx v k = ⟨serTx tx, k⟩ := rfl

/-- **BLK-005 keying, hash-form**: the txid-keyed key is the placeholder
key with `sha256d` applied to the hash slot. -/
theorem txidKey_eq_dsha (tx : Tx) (v : OutPoint) (k : UInt32) :
    txidKey tx v k = ⟨sha256d (serTx tx), k⟩ := rfl

/-! ## §2. BLK-006: the wtxid at the Capstone surface -/

/-- **BLK-006** (transaction.cpp:ComputeWitnessHash:86-93, the
`!HasWitness()` branch): without a witness the wtxid is the txid
verbatim — `wtxidOf`'s else branch is definitionally `txidOf`. -/
theorem wtxidOf_eq_txidOf_of_no_witness (tx : Tx)
    (h : Bitcoin.Serialization.hasWitness tx = false) :
    wtxidOf tx = txidOf tx := by
  unfold wtxidOf txidOf
  rw [h]
  rfl

/-- **BLK-006**, the `HasWitness()` branch: with a witness the wtxid is
`SHA256d` of the BIP144 extended serialization. -/
theorem wtxidOf_eq_dsha256_encodeTx_of_hasWitness (tx : Tx)
    (h : Bitcoin.Serialization.hasWitness tx = true) :
    wtxidOf tx = sha256d (encodeTx tx) := by
  unfold wtxidOf
  rw [h]
  rfl

/-- Bridge to `wtxidOf` (Capstone surface) is `DataLaws.wtxid`
(TXV-018) whenever the two `hasWitness` predicates agree and
`encodeTx` matches `serTxWithWitness`. The `hasWitness` predicates
differ only in how they pad absent witness slots (range-over-`vin` with
`getD`-defaults vs `.any` over the witness list) — see
`hasWitness_datalaws_eq` for the wire-domain agreement. -/
theorem wtxidOf_eq_datalaws_wtxid (tx : Tx)
    (hw : Bitcoin.Serialization.hasWitness tx = Bitcoin.DataLaws.hasWitness tx)
    (henc : encodeTx tx = Bitcoin.DataLaws.serTxWithWitness tx) :
    wtxidOf tx = Bitcoin.DataLaws.wtxid tx := by
  unfold wtxidOf Bitcoin.DataLaws.wtxid
  rw [hw, henc]
  rfl

/-- On the wire domain (one witness slot per input, absent slots empty)
`hasWitness` (`.any` over the witness list) and `hasWitness`
(range over `vin` with `getD` padding) agree exactly. -/
theorem hasWitness_datalaws_eq (tx : Tx) (hlen : tx.witness.length ≤ tx.vin.length) :
    Bitcoin.DataLaws.hasWitness tx = Bitcoin.Serialization.hasWitness tx := by
  unfold Bitcoin.DataLaws.hasWitness Bitcoin.Serialization.hasWitness
  cases hL : tx.witness.any (fun s => !s.isEmpty) with
  | false =>
      cases hR : (List.range tx.vin.length).any
          (fun i => !(tx.witness.getD i []).isEmpty) with
      | false => rfl
      | true =>
          rw [List.any_eq_true] at hR
          obtain ⟨i, hi, hp⟩ := hR
          have hilt : i < tx.vin.length := List.mem_range.mp hi
          rw [List.getD_eq_getElem?_getD] at hp
          cases hx : tx.witness[i]? with
          | none => rw [hx] at hp; simp at hp
          | some s =>
              rw [hx, Option.getD_some] at hp
              obtain ⟨hlt, heq⟩ := List.getElem?_eq_some_iff.mp hx
              subst heq
              have htrue : tx.witness.any (fun s => !s.isEmpty) = true :=
                List.any_eq_true.mpr ⟨tx.witness[i], List.getElem_mem hlt, hp⟩
              rw [htrue] at hL
              exact Bool.noConfusion hL
  | true =>
      obtain ⟨s, hs, hp⟩ := List.any_eq_true.mp hL
      obtain ⟨i, hx⟩ := List.mem_iff_getElem?.mp hs
      obtain ⟨hlt, heq⟩ := List.getElem?_eq_some_iff.mp hx
      have hilt : i < tx.vin.length := Nat.lt_of_lt_of_le hlt hlen
      have hp' : !(tx.witness.getD i []).isEmpty = true := by
        rw [List.getD_eq_getElem?_getD, List.getElem?_eq_some_iff.mpr ⟨hlt, heq⟩,
          Option.getD_some]
        exact hp
      exact (List.any_eq_true.mpr ⟨i, List.mem_range.mpr hilt, hp'⟩).symm


/-! ## §3. TXV-017 corollary: the witness never touches the txid or the key -/

/-- The base serialization ignores the witness (structural: `serTx`
projects only `version`/`vin`/`vout`/`locktime`). -/
theorem serTx_witness_independence (tx : Tx) (w : List WitnessStack) :
    serTx { tx with witness := w } = serTx tx := rfl

/-- TXV-017 corollary at the Capstone surface: `txidOf` ignores the
witness — a corollary of `Bitcoin.DataLaws.txid_witness_independence`
(`txid {tx with witness := w} = txid tx`), transferred through the
definitional link `txidOf = DataLaws.txid`. -/
theorem txidOf_witness_independence (tx : Tx) (w : List WitnessStack) :
    txidOf { tx with witness := w } = txidOf tx :=
  Bitcoin.DataLaws.txid_witness_independence tx w

/-- The BLK-005-keyed ledger key ignores the witness: two presentations
of the same transaction (differing only in parsed-but-unserialized
witness slots) key the fold identically. -/
theorem txidKey_witness_independence (tx : Tx) (w : List WitnessStack)
    (v : OutPoint) (k : UInt32) :
    txidKey { tx with witness := w } v k = txidKey tx v k := by
  rw [txidKey_eq, txidKey_eq, txidOf_witness_independence]

/-! ## §4. Keying vs placeholder: the honest hash-chain bridge -/

/-- The two keys agree on the index component — for EVERY tx, witness or
not (both keys pass the output index through untouched). -/
theorem txidKey_placeholder_index_agrees (tx : Tx) (v : OutPoint) (k : UInt32) :
    (txidKey tx v k).n = (txidPreimageKey tx v k).n := rfl

/-- The honest hash-chain bridge: the txid-keyed key's hash slot is
exactly `sha256d` of the placeholder key's hash slot. (key-generic
fold theorems transfer: any property proved for an arbitrary `Key` holds
at `txidKey`; where the placeholder's *byte identity* matters, the
transfer goes through this chain, not through key equality.) -/
theorem txidKey_placeholder_hash_chain (tx : Tx) (v : OutPoint) (k : UInt32) :
    (txidKey tx v k).hash = sha256d (txidPreimageKey tx v k).hash := rfl

/-- The keys agree exactly when the txid equals its preimage — i.e. only
in the degenerate case where the double-SHA256 digest happens to equal
the base serialization. `¬hasWitness tx` does NOT suffice: `serTx`
ignores the witness, so stripping the witness cannot change the stored
hashes (see `txidKey_placeholder_differ_example`). -/
theorem txidKey_agrees_placeholder_of_txid_eq_preimage (tx : Tx) (v : OutPoint) (k : UInt32)
    (h : txidOf tx = serTx tx) : txidKey tx v k = txidPreimageKey tx v k := by
  simp only [txidKey, txidPreimageKey, h]

/-- CONCRETE COUNTEREXAMPLE to `txidKey tx v k = txidPreimageKey tx v k`:
for the empty transaction the placeholder stores the 10-byte base
serialization while the txid key stores its 32-byte double-SHA256 digest —
structurally different ByteArrays, so the keys differ. This is why P06
lands the hash-chain bridge (`txidKey_placeholder_hash_chain`) rather
than the package-drafted agreement statement. -/
theorem txidKey_placeholder_differ_example (v : OutPoint) (k : UInt32) :
    txidKey (⟨0, [], [], 0, []⟩ : Tx) v k ≠ txidPreimageKey (⟨0, [], [], 0, []⟩ : Tx) v k := by
  intro h
  have heq : txidOf (⟨0, [], [], 0, []⟩ : Tx) = serTx (⟨0, [], [], 0, []⟩ : Tx) := by
    simpa [txidKey, txidPreimageKey, OutPoint.mk.injEq] using h
  have hs : (txidOf (⟨0, [], [], 0, []⟩ : Tx)).size
      = (serTx (⟨0, [], [], 0, []⟩ : Tx)).size := by rw [heq]
  rw [show txidOf (⟨0, [], [], 0, []⟩ : Tx)
        = sha256d (serTx (⟨0, [], [], 0, []⟩ : Tx)) from rfl,
      Bitcoin.Crypto.Seam.sha256d_size] at hs
  have h10 : (serTx (⟨0, [], [], 0, []⟩ : Tx)).size = 10 := by rfl
  omega

/-! ## §5. BIP30 mechanism: same txid ⇒ same key ⇒ same coins -/

/-- Equal base serializations give equal txids (the sha256d congruence
half of BLK-005; `DataLaws.txid_congr` at the Capstone surface). -/
theorem txidOf_congr (a b : Tx) (h : serTx a = serTx b) : txidOf a = txidOf b :=
  congrArg sha256d h

/-- **BIP30 mechanism (91842/91880)**: two transactions with the same
base serialization key the fold identically — the historical
duplicate-coinbase blocks collide on outpoints precisely because their
coinbases' base serializations (hence txids) coincide. -/
theorem txidKey_congr (a b : Tx) (h : serTx a = serTx b) : txidKey a = txidKey b := by
  funext v k
  simp only [txidKey, txidOf_congr a b h]

/-- With the txid key, equal txids plus equal outputs give IDENTICAL
`addedCoins` — so `bip30Collision` cannot distinguish the duplicate from
the original, and the BLK-096/097/098 check fires on the second
occurrence exactly as Core's `IsBIP30Repeat` logic demands. -/
theorem bip30_collision_same_txid (u : UtxoSet) (a b : Tx) (height : UInt32)
    (h : txidOf a = txidOf b) (hv : a.vout = b.vout) (_hcb : a.isCoinBase = b.isCoinBase) :
    bip30Collision u b (txidKey b) height = bip30Collision u a (txidKey a) height := by
  have hk : txidKey b = txidKey a := by
    funext v k
    simp only [txidKey, h]
  -- Post-D4c-1 (F-TXVB-014): `bip30Collision` is the UNFILTERED
  -- `(List.range tx.vout.length).any` loop (Core 2466-2475) — no
  -- `addedCoins` congruence (hadd/hcb) anymore: equal txids (`h`, `hk`)
  -- + equal vouts (`hv`) key every outpoint identically. The
  -- `hcb : a.isCoinBase = b.isCoinBase` arm is vacuous post-D4c-1 (kept
  -- in the signature for stability, hence `_`).
  have hko : ∀ o : Nat, txidKey b OutPoint.null (UInt32.ofNat o)
      = txidKey a OutPoint.null (UInt32.ofNat o) := fun o =>
    congrFun (congrFun hk OutPoint.null) (UInt32.ofNat o)
  unfold bip30Collision
  rw [hv]
  refine congrArg (fun (g : Nat → Bool) =>
      (List.range b.vout.length).any g) (funext fun o =>
    congrArg (fun k => (u k).isSome) (hko o))

/-! ## §6. The fold keys coins by the REAL txid (BLK-102 / INV-111) -/

/-- Output-index injectivity of the txid key: two outputs of the same tx
land on the same txid-keyed outpoint only if they are the same output
(the txid slot is shared, so equality forces the `UInt32` indices
equal; below 2^32 `ofNat` is injective). -/
theorem txidKey_ofNat_inj (tx : Tx) {i k : Nat} (hi : i < 4294967296) (hk : k < 4294967296)
    (h : txidKey tx OutPoint.null (UInt32.ofNat i) = txidKey tx OutPoint.null (UInt32.ofNat k)) :
    i = k := by
  have hn : (UInt32.ofNat i : UInt32) = UInt32.ofNat k := by
    have h' : txidKey tx OutPoint.null (UInt32.ofNat i)
        = txidKey tx OutPoint.null (UInt32.ofNat k) := h
    simp only [txidKey, OutPoint.mk.injEq] at h'
    exact h'.2
  have h2 := congrArg UInt32.toNat hn
  have h' : i % 4294967296 = k % 4294967296 := h2
  rw [Nat.mod_eq_of_lt hi, Nat.mod_eq_of_lt hk] at h'
  exact h'

/-- **INV-111 at the txid key**: a spendable output `j` of `tx` is looked
up EXACTLY (right coin, right height, right coinbase bit) at the outpoint
whose hash is the REAL txid — the on-the-nose lookup the capstone run
performs for each of the 11,825 adjudicated inputs' creations. -/
theorem addedCoins_txidKey_lookup (tx : Tx) (height : UInt32) (j : Nat)
    (hj : j < tx.vout.length) (hsmall : tx.vout.length < 4294967296)
    (hus : scriptUnspendable (tx.vout.getD j ⟨0, Script.empty⟩).scriptPubKey = false) :
    coinLookup (addedCoins tx (txidKey tx) height) ⟨txidOf tx, UInt32.ofNat j⟩ =
      some ⟨(tx.vout.getD j ⟨0, Script.empty⟩).value, height, tx.isCoinBase,
        (tx.vout.getD j ⟨0, Script.empty⟩).scriptPubKey⟩ := by
  rw [show ⟨txidOf tx, UInt32.ofNat j⟩ = txidKey tx OutPoint.null (UInt32.ofNat j) from rfl]
  exact addedCoins_lookup_eq tx (txidKey tx) height j hj hus
    (fun i k hi hk hcon => txidKey_ofNat_inj tx (by omega) (by omega) hcon)

/-- **THE TXID-KEYING THEOREM (BLK-005 × BLK-102)**: connecting a lone
coinbase to the EMPTY view under the key succeeds, and the coin it
creates sits at the outpoint keyed by the coinbase's REAL txid — with
the connection height and the coinbase bit, on the nose. This is the
proved form of what the capstone run observed for the genesis anchor
(validation.cpp:2330-2334 skips genesis's txs; every later anchor's
coinbase enters under `⟨txidOf cb, j⟩`). -/
theorem coinbase_coin_keyed_by_txid (cb : Tx) (height : UInt32)
    (hcb : cb.isCoinBase = true)
    (hv0 : 0 < cb.vout.length)
    (hsmall : cb.vout.length < 4294967296)
    (hus : scriptUnspendable (cb.vout.getD 0 ⟨0, Script.empty⟩).scriptPubKey = false) :
    ∃ u' : UtxoSet,
      applyBlockU emptyUtxo txidKey [cb] height = Except.ok u' ∧
      (u' ⟨txidOf cb, 0⟩).isSome = true ∧
      (u' ⟨txidOf cb, 0⟩).map (fun c : Coin => c.height) = some height ∧
      (u' ⟨txidOf cb, 0⟩).map (fun c : Coin => c.isCoinbase) = some true := by
  have keyEq : txidKey cb OutPoint.null (UInt32.ofNat 0) = ⟨txidOf cb, 0⟩ := rfl
  have hcol : bip30Collision emptyUtxo cb (txidKey cb) height = false :=
    listAny_false_intro _ _ (fun _ _ => rfl)
  -- Post-D4c-2 shape (F-TXVB-014): `applyTxStepU` is BIP30-free (the
  -- coinbase leg skips the input/maturity gates), and the BIP30 gate
  -- is the pre-loop `bip30BlockCollision` in `applyBlockU` — quiet on
  -- the empty pristine view (every `bip30Collision` is `false`).
  have hstep : applyTxStepU emptyUtxo cb (txidKey cb) height =
      Except.ok (updateCoins emptyUtxo cb (txidKey cb) height) := by
    unfold applyTxStepU
    rw [hcb]
    rfl
  have hbcol : bip30BlockCollision emptyUtxo txidKey [cb] height = false := by
    show (bip30Collision emptyUtxo cb (txidKey cb) height
        || bip30BlockCollision emptyUtxo txidKey [] height) = false
    rw [hcol]
    rfl
  have hgate : (bip30BlockCollision emptyUtxo txidKey [cb] height
      && bip30Enforced height) = false := by
    rw [hbcol]
    simp
  refine ⟨updateCoins emptyUtxo cb (txidKey cb) height, ?_, ?_, ?_, ?_⟩
  · unfold applyBlockU
    rw [hgate]
    show applyBlockFoldU emptyUtxo txidKey [cb] height = _
    rw [applyBlockFoldU]
    rw [hstep]
    rfl
  · rw [← keyEq]
    exact updateCoins_insert_isSome emptyUtxo cb (txidKey cb) height 0 hv0 hus
  · rw [← keyEq]
    unfold updateCoins
    rw [addedCoins_lookup_eq cb (txidKey cb) height 0 hv0 hus
      (fun i k hi hk hcon => txidKey_ofNat_inj cb (by omega) (by omega) hcon)]
    simp
  · rw [← keyEq]
    unfold updateCoins
    rw [addedCoins_lookup_eq cb (txidKey cb) height 0 hv0 hus
      (fun i k hi hk hcon => txidKey_ofNat_inj cb (by omega) (by omega) hcon)]
    simp [hcb]

/-- INV-110 block form transfers to the Capstone key verbatim
(fold theorems quantify key-generically over `kf : Tx → Key`, and
`txidKey` is a `Tx → Key`): a succeeding txid-keyed fold never
double-spends a coin that is absent from the starting view and never
re-created. -/
theorem no_double_spend_txidKey (u : UtxoSet) (p : OutPoint) (txs : List Tx)
    (height : UInt32)
    (hnone : u p = none)
    (hnoadd : ∀ tx ∈ txs, p ∉ addedKeys tx (txidKey tx) height)
    (hok : (applyBlockU u txidKey txs height).isOk = true) :
    (txs.filter (fun tx => !tx.isCoinBase && tx.vin.any (fun i => i.prevout == p))).length = 0 :=
  applyBlockU_no_double_spend txidKey p txs height u hnone hnoadd hok

/-! ## Axiom-footprint pins (L3): drift on any of these fails the build -/

/-- info: 'BitcoinProofs.Theorems.CapstoneTxid.txidOf_eq_dsha256_serTx' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms txidOf_eq_dsha256_serTx

/-- info: 'BitcoinProofs.Theorems.CapstoneTxid.txidOf_eq_datalaws_txid' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms txidOf_eq_datalaws_txid

/-- info: 'BitcoinProofs.Theorems.CapstoneTxid.txidKey_eq' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms txidKey_eq

/-- info: 'BitcoinProofs.Theorems.CapstoneTxid.txidPreimageKey_eq' depends on axioms: [propext] -/
#guard_msgs in #print axioms txidPreimageKey_eq

/-- info: 'BitcoinProofs.Theorems.CapstoneTxid.txidKey_eq_dsha' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms txidKey_eq_dsha

/-- info: 'BitcoinProofs.Theorems.CapstoneTxid.wtxidOf_eq_txidOf_of_no_witness' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms wtxidOf_eq_txidOf_of_no_witness

/-- info: 'BitcoinProofs.Theorems.CapstoneTxid.wtxidOf_eq_dsha256_encodeTx_of_hasWitness' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms wtxidOf_eq_dsha256_encodeTx_of_hasWitness

/-- info: 'BitcoinProofs.Theorems.CapstoneTxid.wtxidOf_eq_datalaws_wtxid' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms wtxidOf_eq_datalaws_wtxid

/-- info: 'BitcoinProofs.Theorems.CapstoneTxid.hasWitness_datalaws_eq' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms hasWitness_datalaws_eq

/-- info: 'BitcoinProofs.Theorems.CapstoneTxid.serTx_witness_independence' depends on axioms: [propext] -/
#guard_msgs in #print axioms serTx_witness_independence

/-- info: 'BitcoinProofs.Theorems.CapstoneTxid.txidOf_witness_independence' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms txidOf_witness_independence

/-- info: 'BitcoinProofs.Theorems.CapstoneTxid.txidKey_witness_independence' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms txidKey_witness_independence

/-- info: 'BitcoinProofs.Theorems.CapstoneTxid.txidKey_placeholder_index_agrees' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms txidKey_placeholder_index_agrees

/-- info: 'BitcoinProofs.Theorems.CapstoneTxid.txidKey_placeholder_hash_chain' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms txidKey_placeholder_hash_chain

/-- info: 'BitcoinProofs.Theorems.CapstoneTxid.txidKey_agrees_placeholder_of_txid_eq_preimage' depends on axioms: [propext,
 Quot.sound] -/
#guard_msgs in #print axioms txidKey_agrees_placeholder_of_txid_eq_preimage

/-- info: 'BitcoinProofs.Theorems.CapstoneTxid.txidKey_placeholder_differ_example' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms txidKey_placeholder_differ_example

/-- info: 'BitcoinProofs.Theorems.CapstoneTxid.txidOf_congr' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms txidOf_congr

/-- info: 'BitcoinProofs.Theorems.CapstoneTxid.txidKey_congr' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms txidKey_congr

/-- info: 'BitcoinProofs.Theorems.CapstoneTxid.bip30_collision_same_txid' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms bip30_collision_same_txid

/-- info: 'BitcoinProofs.Theorems.CapstoneTxid.txidKey_ofNat_inj' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms txidKey_ofNat_inj

/-- info: 'BitcoinProofs.Theorems.CapstoneTxid.addedCoins_txidKey_lookup' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms addedCoins_txidKey_lookup

/-- info: 'BitcoinProofs.Theorems.CapstoneTxid.coinbase_coin_keyed_by_txid' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms coinbase_coin_keyed_by_txid

/-- info: 'BitcoinProofs.Theorems.CapstoneTxid.no_double_spend_txidKey' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms no_double_spend_txidKey

end BitcoinProofs.Theorems.CapstoneTxid
