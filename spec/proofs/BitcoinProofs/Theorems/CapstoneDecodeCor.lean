import Bitcoin.Capstone.Block

/-!
# BitcoinProofs.Theorems.CapstoneDecodeCor — P13: decode-layer corollaries feeding the capstone

Corollaries of proved serialization laws (`Bitcoin.Serialization`)
lifted to the Capstone surface
(`Bitcoin.Capstone.Block.validateBlock`, S2b). Zero new dependencies:
imports only the `core` package via `Bitcoin.Capstone.Block`.

What the existing layer already proves and this file BUILDS ON (not re-proves):
`decU32L_shape`, `decBytesL_shape`, `decBytesL_length`, `decCS_shape`,
`decTxCore_shape`, `decN_shape`, `bytesOfList_bL`, `bL_bytesOfList`,
`bL_inj`, `bindE_ok`/`bindE_err`, `hasWitness_false_of_all_getD_empty`,
`hasWitness_of_witness_mem_nonempty`, `getD_mem`, `decodeBlock`,
`decodeBlockHeader_encodeBlockHeader` (BLK-001), `decodeBlock_encodeBlock`
(BLK-002), `decodeTx_encodeTx` (T1).  What the existing layer did NOT have — and P13
proves here — is the header-level inversion (`decHeaderL_shape`), the
block-level consumed-encoding shape (`decodeBlock_shape`), and the
capstone-facing laws below.

C4 portfolio linkage:

| C4 ID     | theorem here                  | statement (short) |
|-----------|-------------------------------|-------------------|
| (BLK-003 cor) | `decode_ok_header80`      | a decoded block's header satisfies `headerHash h = SHA256d(raw.extract 0 80)` — the first 80 bytes of the wire ARE the encoded header |
| (BLK-003 cor) | `decode_ok_header80'`     | list-layer form of the same fact |
| (BLK-002 cor) | `decodeBlock_shape`       | a successfully decoded block consumed exactly its canonical encoding (values non-negative) |
| (BLK-001 aux) | `decHeaderL_shape`        | header-level inversion: decode consumed the canonical 80-byte header |
| (BLK-006 base) | `encodeTx_no_witness_eq_serTx` | `¬hasWitness ⇒ encodeTx = serTx` (the TX_NO_WITNESS law under `encodeTx`) |
| (BLK-005 cor) | `txidOf_eq_sha256d_encodeTx` | the capstone ledger key's `txidOf` is `SHA256d` of the tx's own canonical encoding |
| (TXV-013 def) | `hasWitness_eq_true_iff` / `hasWitness_eq_false_iff` / `hasWitness_true_iff_mem` | `HasWitness()` characterized per its definition |
| (BLK-024 base) | `serTx_size_pos`          | a serialized tx is nonempty (the version field alone is 4 bytes) |
| (decode totality) | `decodeBlock_total`   | `decodeBlock` returns `.ok` or `.error` — it never crashes |
| (BLK-030 pipe) | `validateBlock_ok_decode` | a successful `validateBlock` run decoded a real block and its state carries `headerHash h` |

Axiom footprints (checked via `#print axioms` in the scratch area;
per-theorem notes in the `/-- docstrings -/` below):

| theorem                        | axioms |
|--------------------------------|--------|
| `bL_length`                    | [propext] |
| `bytesOfList_size`             | [propext, Quot.sound] |
| `bL_extract`                   | [propext, Classical.choice, Quot.sound] (choice inherited from core's `Array.toList_extract`) |
| `list_extract_zero`            | [propext] |
| `encHeaderL_length`            | [propext] |
| `decHeaderL_shape`             | [propext, Quot.sound] |
| `decodeBlock_shape`            | [propext, Classical.choice, Quot.sound] (choice inherited from the `decTxCore_shape` layer, itself [propext, Classical.choice, Quot.sound]) |
| `decode_ok_header80`           | [propext, Classical.choice, Quot.sound] (via `decodeBlock_shape`) |
| `decode_ok_header80'`          | [propext, Quot.sound] |
| `encodeTx_no_witness_eq_serTx` / `'` | [propext, Quot.sound] |
| `txidOf_eq_sha256d_encodeTx`   | [propext, Quot.sound] |
| `hasWitness_eq_true_iff` / `hasWitness_eq_false_iff` / `hasWitness_true_iff_mem` | [propext, Quot.sound] |
| `serTx_size_pos`               | [propext, Quot.sound] |
| `decodeBlock_total` / `decodeBlockHeader_total` | [propext] |
| `validateBlock_ok_decode`      | [propext, Classical.choice, Quot.sound] (via `decTxCore_shape` layer) |

`Classical.choice` appears only where the inherited core layer already
uses it (recorded honestly); no theorem here introduces `sorry`, and no
`native_decide`/`unsafe`/`partial` is used anywhere in the file.
-/

namespace BitcoinProofs.Theorems.CapstoneDecode

open Bitcoin.Serialization Bitcoin.Capstone.Pow Bitcoin.Capstone.Merkle
open Bitcoin.Data Bitcoin.Chain

/-! ## Byte-array plumbing (auxiliaries restated at this layer) -/

/-- `bL` preserves length (`bL` is a projection of `ByteArray.data`).
Axioms: [propext]. -/
theorem bL_length (b : ByteArray) : (bL b).length = b.size := by
  simp [bL]

/-- `bytesOfList` preserves length. Axioms: [propext, Quot.sound]. -/
theorem bytesOfList_size (l : Bytes) : (bytesOfList l).size = l.length := by
  simp [bytesOfList]

/-- `throw` in the `Except` monad is `Except.error` (definitional). -/
private theorem bind_throw {ε α β : Type} (e : ε) (F : α → Except ε β) :
    Bind.bind (throw e) F = Except.error e := rfl

/-- `Bind.bind (Except.error e) F = Except.error e` (definitional). -/
private theorem bindEerr {ε α β : Type} (e : ε) (F : α → Except ε β) :
    Bind.bind (Except.error e : Except ε α) F = Except.error e := rfl

/-- `Bind.bind (Except.ok x) F = F x` (definitional). -/
private theorem bindEok {ε α β : Type} (x : α) (F : α → Except ε β) :
    Bind.bind (Except.ok x : Except ε α) F = F x := rfl

/-- A definitional discriminant: `Except.error e ≠ Except.ok r`. -/
private theorem errNeOk {ε α : Type} (e : ε) (r : α) :
    (Except.error e : Except ε α) ≠ Except.ok r := by
  simp

/-- Bind inversion: if `m >>= F = .ok r` then `m = .ok x` for some `x`
with `F x = .ok r` — the monadic `let` really did bind a success value. -/
private theorem bind_ok_inv {ε α β : Type} (m : Except ε α) (F : α → Except ε β) (r : β)
    (h : Bind.bind m F = Except.ok r) :
    ∃ x, m = Except.ok x ∧ F x = Except.ok r := by
  cases m with
  | error e => rw [bindEerr] at h; exact absurd h (by simp)
  | ok x => rw [bindEok] at h; exact ⟨x, rfl, h⟩

/-- Inversion of `validateBlock`'s decode step (the desugared head of its
do-block): a successful run's continuation `JP` received a genuinely
decoded `(header, txs)` pair, and `decodeBlock raw = .ok (h, txs)`. -/
private theorem decodeMatch_inv (raw : ByteArray)
    (JP : BlockHeader × List Tx →
      Except Bitcoin.Capstone.Block.CapError Bitcoin.Capstone.Block.CapReport)
    (rep : Bitcoin.Capstone.Block.CapReport)
    (hm : (match decodeBlock raw with
      | .error e => Bind.bind (throw (Bitcoin.Capstone.Block.CapError.ser e)) JP
      | .ok p => Bind.bind (pure p) JP) = Except.ok rep) :
    ∃ h txs, decodeBlock raw = Except.ok (h, txs)
      ∧ JP (h, txs) = Except.ok rep := by
  revert hm
  cases decodeBlock raw with
  | error e =>
    intro hm
    exfalso
    have hm2 : Bind.bind (throw (Bitcoin.Capstone.Block.CapError.ser e)) JP = Except.ok rep := hm
    rw [bind_throw] at hm2
    exact absurd hm2 (by simp)
  | ok p =>
    intro hm
    obtain ⟨h, txs⟩ := p
    exact ⟨h, txs, rfl, hm⟩

/-- Guard inversion: if a guarded pipeline `if b then T else E` produced
`.ok r`, then one of the branches produced `.ok r`. -/
private theorem ite_ok_inv {ε α : Type} (b : Bool) (T E : Except ε α) (r : α)
    (h : (if (b = true) then T else E) = Except.ok r) :
    T = Except.ok r ∨ E = Except.ok r := by
  cases b with
  | true => exact Or.inl h
  | false => exact Or.inr h

/-- The `extract` of a `ByteArray` is the `take` of its list view.
Axioms: [propext, Classical.choice, Quot.sound] — the choice is inherited
from core's `Array.toList_extract`. -/
theorem bL_extract (b : ByteArray) (i j : Nat) :
    bL (b.extract i j) = (bL b).extract i j := by
  simp only [bL, ByteArray.data_extract, Array.toList_extract]

/-- `List.extract i j` at `i = 0` is `take j`. Axioms: [propext]. -/
theorem list_extract_zero {α : Type} (l : List α) (j : Nat) :
    l.extract 0 j = l.take j := by
  simp [List.extract_eq_take_drop]

/-! ## The 80-byte header: length and decode-side inversion -/

/-- The header wire form is exactly 80 bytes (6 + 32 + 32 fields; 4-byte
fields ×4 = 16, plus two 32-byte hashes) when both hashes are 32 bytes —
which every decoded header satisfies (`decHeaderL_shape` below). -/
theorem encHeaderL_length (h : BlockHeader)
    (hp : h.hashPrevBlock.size = 32) (hm : h.hashMerkleRoot.size = 32) :
    (encHeaderL h).length = 80 := by
  simp [encHeaderL, encU32L, bL_length, hp, hm]

/-- **Header decode inversion** (the decode-side twin of
`decHeaderL_enc`, which P13 derives from fixed-width shape laws):
a successful `decHeaderL` read a 32-byte prev hash, a 32-byte merkle root,
and consumed exactly the canonical 80-byte header encoding.
Axioms: [propext, Quot.sound]. -/
theorem decHeaderL_shape (l : Bytes) (h : BlockHeader) (rest : Bytes)
    (hd : decHeaderL l = .ok (h, rest)) :
    h.hashPrevBlock.size = 32 ∧ h.hashMerkleRoot.size = 32
      ∧ l = encHeaderL h ++ rest := by
  unfold decHeaderL at hd
  cases hv : decU32L l with
  | error => rw [hv] at hd; simp at hd
  | ok p =>
    obtain ⟨v, l1⟩ := p
    rw [hv] at hd; simp only [bindE_ok] at hd
    cases h1 : decBytesL 32 l1 with
    | error => rw [h1] at hd; simp at hd
    | ok q1 =>
      obtain ⟨hp, l2⟩ := q1
      rw [h1] at hd; simp only [bindE_ok] at hd
      cases h2 : decBytesL 32 l2 with
      | error => rw [h2] at hd; simp at hd
      | ok q2 =>
        obtain ⟨hm, l3⟩ := q2
        rw [h2] at hd; simp only [bindE_ok] at hd
        cases h3 : decU32L l3 with
        | error => rw [h3] at hd; simp at hd
        | ok q3 =>
          obtain ⟨t, l4⟩ := q3
          rw [h3] at hd; simp only [bindE_ok] at hd
          cases h4 : decU32L l4 with
          | error => rw [h4] at hd; simp at hd
          | ok q4 =>
            obtain ⟨bi, l5⟩ := q4
            rw [h4] at hd; simp only [bindE_ok] at hd
            cases h5 : decU32L l5 with
            | error => rw [h5] at hd; simp at hd
            | ok q5 =>
              obtain ⟨nc, l6⟩ := q5
              rw [h5] at hd
              simp only [bindE_ok, Except.ok.injEq, Prod.mk.injEq] at hd
              obtain ⟨hh, hrest⟩ := hd
              subst hrest
              subst hh
              refine ⟨?_, ?_, ?_⟩
              · show (bytesOfList hp).size = 32
                rw [bytesOfList_size]
                exact decBytesL_length 32 l1 hp l2 h1
              · show (bytesOfList hm).size = 32
                rw [bytesOfList_size]
                exact decBytesL_length 32 l2 hm l3 h2
              · rw [decU32L_shape l v l1 hv, decBytesL_shape 32 l1 hp l2 h1,
                  decBytesL_shape 32 l2 hm l3 h2, decU32L_shape l3 t l4 h3,
                  decU32L_shape l4 bi l5 h4, decU32L_shape l5 nc l6 h5]
                simp only [encHeaderL, encU32L, bL_bytesOfList, List.append_assoc,
                  show (UInt32.toInt32 v).toUInt32 = v from rfl]

/-! ## Block-level decode inversion -/

/-- Helper: a successful `decBlockCore` read a well-formed header first. -/
private theorem decBlockCore_header_ok (raw : ByteArray) (h : BlockHeader)
    (txs : List Tx) (rest : Bytes)
    (hc : decBlockCore (bL raw) = .ok (h, txs, rest)) :
    ∃ l1, decHeaderL (bL raw) = .ok (h, l1) := by
  unfold decBlockCore at hc
  cases hd : decHeaderL (bL raw) with
  | error => rw [hd] at hc; simp at hc
  | ok p =>
    obtain ⟨h2, l1⟩ := p
    rw [hd] at hc; simp only [bindE_ok] at hc
    cases hk : decCS l1 with
    | error => rw [hk] at hc; simp at hc
    | ok s =>
      obtain ⟨k, l2⟩ := s
      rw [hk] at hc; simp only [bindE_ok] at hc
      cases hn : decN decTxCore k l2 with
      | error => rw [hn] at hc; simp at hc
      | ok u =>
        obtain ⟨ys, l3⟩ := u
        rw [hn] at hc
        simp only [bindE_ok, Except.ok.injEq, Prod.mk.injEq] at hc
        obtain ⟨rfl, -, -⟩ := hc
        exact ⟨l1, rfl⟩

/-- Helper: `decodeBlock`'s ok-branch — the core decode succeeded and the
remainder was empty. -/
private theorem decodeBlock_ok_core (raw : ByteArray) (h : BlockHeader)
    (txs : List Tx) (hdec : decodeBlock raw = .ok (h, txs)) :
    decBlockCore (bL raw) = .ok (h, txs, []) := by
  unfold decodeBlock at hdec
  cases hc : decBlockCore (bL raw) with
  | error => rw [hc] at hdec; simp at hdec
  | ok p =>
    obtain ⟨hh, tt, rest⟩ := p
    rw [hc] at hdec
    simp only [bindE_ok] at hdec
    by_cases rempty : rest.isEmpty = true
    · rw [ite_eq_left rempty, Except.ok.injEq, Prod.mk.injEq] at hdec
      obtain ⟨rfl, rfl⟩ := hdec
      have hrest : rest = [] := by
        cases rest with
        | nil => rfl
        | cons c cs => simp at rempty
      subst hrest
      rfl
    · rw [ite_eq_right rempty] at hdec; simp at hdec

/-- Helper (P13, a value-conditioned variant of `decN_shape`): the
per-element shape law only needs to hold for elements satisfying `P` —
which for `decTxCore` is exactly the `decTxCore_shape` hypothesis
(non-negative output values). Axioms: [propext, Quot.sound]. -/
private theorem decN_shape_P {α : Type} {dec : Bytes → Except SerError (α × Bytes)}
    {enc : α → Bytes} (P : α → Prop)
    (Hshape : ∀ (l : Bytes) (a : α) (rest : Bytes),
      dec l = .ok (a, rest) → P a → l = enc a ++ rest) :
    ∀ (k : Nat) (l : Bytes) (xs : List α) (rest : Bytes),
      decN dec k l = .ok (xs, rest) → (∀ a ∈ xs, P a) →
      xs.length = k ∧ l = encN enc xs ++ rest := by
  intro k
  induction k with
  | zero =>
    intro l xs rest h _
    simp only [decN] at h
    simp only [Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, rfl⟩ := h
    exact ⟨rfl, rfl⟩
  | succ k ih =>
    intro l xs rest h hP
    simp only [decN] at h
    cases hd : dec l with
    | error => rw [hd] at h; simp at h
    | ok p =>
      obtain ⟨a, l1⟩ := p
      rw [hd] at h
      simp only [bindE_ok] at h
      cases h2 : decN dec k l1 with
      | error => rw [h2] at h; simp at h
      | ok q =>
        obtain ⟨as, l2⟩ := q
        rw [h2] at h
        simp only [bindE_ok, Except.ok.injEq, Prod.mk.injEq] at h
        obtain ⟨rfl, rfl⟩ := h
        obtain ⟨ha, hrest⟩ := ih l1 as l2 h2 (fun x hx => hP x (List.Mem.tail _ hx))
        refine ⟨by simp [ha], ?_⟩
        rw [Hshape l a l1 hd (hP a (List.Mem.head _))]
        simp [encN, hrest]

/-- **BLK-002 inversion (the consumed-encoding shape of a decoded block)**:
if `decodeBlock raw = .ok (h, txs)` and every decoded output value is
non-negative (true of every real mainnet block; `decTxCore_shape`
needs the same hypothesis because the raw `u64` lane admits two's-complement
negatives), then the wire was exactly `header ‖ txcount ‖ txs` in canonical
form — `encHeaderL`/`encCSL`/`encTxL` encodings, nothing else.
Axioms: [propext, Classical.choice, Quot.sound] (choice inherited from
`decTxCore_shape` layer). -/
theorem decodeBlock_shape (raw : ByteArray) (h : BlockHeader) (txs : List Tx)
    (hdec : decodeBlock raw = .ok (h, txs))
    (hval : ∀ t ∈ txs, ∀ o ∈ t.vout, 0 ≤ o.value) :
    bL raw = encHeaderL h ++ (encCSL txs.length ++ txs.flatMap encTxL) := by
  have hcore := decodeBlock_ok_core raw h txs hdec
  unfold decBlockCore at hcore
  cases hd : decHeaderL (bL raw) with
  | error => rw [hd] at hcore; simp at hcore
  | ok q =>
    obtain ⟨h2, l1⟩ := q
    rw [hd] at hcore; simp only [bindE_ok] at hcore
    cases hk : decCS l1 with
    | error => rw [hk] at hcore; simp at hcore
    | ok s =>
      obtain ⟨k, l2⟩ := s
      rw [hk] at hcore; simp only [bindE_ok] at hcore
      cases hn : decN decTxCore k l2 with
      | error => rw [hn] at hcore; simp at hcore
      | ok u =>
        obtain ⟨ys, l3⟩ := u
        rw [hn] at hcore
        simp only [bindE_ok, Except.ok.injEq, Prod.mk.injEq] at hcore
        obtain ⟨hh2, hys, hrl3⟩ := hcore
        subst hrl3
        obtain ⟨hlen, hshape⟩ :=
          decN_shape_P (fun t => ∀ o ∈ t.vout, 0 ≤ o.value)
            (fun l' a r hdec' hP => decTxCore_shape l' a r hdec' hP) k l2 ys [] hn
            (fun a ha => hval a (hys ▸ ha))
        have hshape0 := decHeaderL_shape (bL raw) h2 l1 hd
        obtain ⟨-, -, hpre⟩ := hshape0
        have hcs := decCS_shape l1 k l2 hk
        rw [hpre, hcs, hshape, ← hh2, ← hlen, hys]
        simp only [encN, List.append_nil]

/-- **BLK-003 corollary (the txid-soundness of the capstone's decode step)**:
when `validateBlock`'s step-1 decode succeeds, the returned header `h` has
32-byte hashes, its canonical encoding is EXACTLY the first 80 bytes of the
raw block, and therefore `headerHash h = SHA256d(raw.extract 0 80)` — the
block hash is the double-SHA256 of the header bytes actually on the wire.
Axioms: [propext, Classical.choice, Quot.sound] (choice inherited from
`decTxCore_shape` layer via `decodeBlock_shape`). -/
theorem decode_ok_header80 (raw : ByteArray) (h : BlockHeader) (txs : List Tx)
    (hdec : decodeBlock raw = .ok (h, txs)) :
    h.hashPrevBlock.size = 32 ∧ h.hashMerkleRoot.size = 32
      ∧ raw.extract 0 80 = encodeBlockHeader h
      ∧ headerHash h = Bitcoin.Crypto.Seam.Hash.sha256d (raw.extract 0 80) := by
  have hcore := decodeBlock_ok_core raw h txs hdec
  obtain ⟨l1, hd⟩ := decBlockCore_header_ok raw h txs [] hcore
  obtain ⟨hp32, hm32, hpre⟩ := decHeaderL_shape (bL raw) h l1 hd
  have h80 := encHeaderL_length h hp32 hm32
  have htake : (bL raw).take 80 = encHeaderL h := by
    rw [hpre, ← h80, List.take_left]
  have hext : raw.extract 0 80 = encodeBlockHeader h := by
    unfold encodeBlockHeader
    apply bL_inj
    rw [bL_extract, list_extract_zero, htake, bL_bytesOfList]
  refine ⟨hp32, hm32, hext, ?_⟩
  unfold headerHash
  rw [hext]

/-- List-layer form of `decode_ok_header80`: the first 80 bytes of the
byte-list view are the canonical header encoding.
Axioms: [propext, Quot.sound]. -/
theorem decode_ok_header80' (raw : ByteArray) (h : BlockHeader) (txs : List Tx)
    (hdec : decodeBlock raw = .ok (h, txs)) :
    (bL raw).take 80 = encHeaderL h := by
  have hcore := decodeBlock_ok_core raw h txs hdec
  obtain ⟨l1, hd⟩ := decBlockCore_header_ok raw h txs [] hcore
  obtain ⟨hp32, hm32, hpre⟩ := decHeaderL_shape (bL raw) h l1 hd
  have h80 := encHeaderL_length h hp32 hm32
  rw [hpre, ← h80, List.take_left]

/-! ## TX_NO_WITNESS: `encodeTx` agrees with the base encoder -/

/-- **BLK-006 (base form, `encTxL` branch law)**: a tx without a
witness encodes exactly as the frozen base encoder `serTx` —
`encTxL` takes its else-branch, and `bytesOfList ∘ bL = id`
(`bytesOfList_bL`). This is the ingredient that makes
`encodeTxNoWitness = serTx` definition agree with the witness-aware
`encodeTx` on witness-free txs, i.e. the txid bytes are the extended-format
bytes whenever there is no witness. Axioms: [propext, Quot.sound]. -/
theorem encodeTx_no_witness_eq_serTx (tx : Tx) (hw : hasWitness tx = false) :
    encodeTx tx = serTx tx := by
  unfold encodeTx encTxL
  rw [ite_eq_right (show ¬ (hasWitness tx = true) from by rw [hw]; simp), bytesOfList_bL]

/-- Negation form of `encodeTx_no_witness_eq_serTx`.
Axioms: [propext, Quot.sound]. -/
theorem encodeTx_no_witness_eq_serTx' (tx : Tx) (hw : ¬ (hasWitness tx = true)) :
    encodeTx tx = serTx tx := by
  cases hb : hasWitness tx with
  | false => exact encodeTx_no_witness_eq_serTx tx hb
  | true => exact absurd hb hw

/-- **BLK-005 corollary (ledger-key txid soundness)**: the capstone fold
keys coins by `txidKey tx = fun _ k ⇒ ⟨txidOf tx, k⟩` (Block.lean); for a
witness-free tx that `txidOf` is the double-SHA256 of the tx's own
canonical `encodeTx` bytes — the hash of what the wire actually carries.
Axioms: [propext, Quot.sound]. -/
theorem txidOf_eq_sha256d_encodeTx (tx : Tx) (hw : hasWitness tx = false) :
    txidOf tx = Bitcoin.Crypto.Seam.Hash.sha256d (encodeTx tx) := by
  unfold txidOf
  rw [encodeTx_no_witness_eq_serTx tx hw]

/-! ## `HasWitness()` characterized -/

/-- `hasWitness tx = true` ⟺ some in-range witness slot is nonempty
(`CTransaction::HasWitness()`, transaction.h — range/`getD` form).
Axioms: [propext, Quot.sound]. -/
theorem hasWitness_eq_true_iff (tx : Tx) :
    hasWitness tx = true ↔ ∃ i, i < tx.vin.length ∧ tx.witness.getD i [] ≠ ([] : List ByteArray) := by
  constructor
  · intro hh
    rw [hasWitness, List.any_eq_true] at hh
    obtain ⟨i, hi, hne⟩ := hh
    refine ⟨i, List.mem_range.mp hi, ?_⟩
    cases hb : (tx.witness.getD i []).isEmpty with
    | true =>
      rw [List.isEmpty_iff.mp hb] at hne
      simp at hne
    | false =>
      intro h0
      rw [h0] at hb
      simp at hb
  · rintro ⟨i, hi, hne⟩
    rw [hasWitness, List.any_eq_true]
    refine ⟨i, List.mem_range.mpr hi, ?_⟩
    cases hb : (tx.witness.getD i []).isEmpty with
    | true =>
      have h0 : tx.witness.getD i [] = [] := List.isEmpty_iff.mp hb
      exact absurd h0 hne
    | false => rfl

/-- `hasWitness tx = false` ⟺ every in-range witness slot is empty —
`hasWitness_false_of_all_getD_empty` read as an iff.
Axioms: [propext, Quot.sound]. -/
theorem hasWitness_eq_false_iff (tx : Tx) :
    hasWitness tx = false ↔
      ∀ i, i < tx.vin.length → tx.witness.getD i [] = ([] : List ByteArray) := by
  constructor
  · intro hh i hi
    rw [hasWitness, List.any_eq_false] at hh
    have h0 := hh i (List.mem_range.mpr hi)
    cases hb : (tx.witness.getD i []).isEmpty with
    | true => exact List.isEmpty_iff.mp hb
    | false => rw [hb] at h0; simp at h0
  · intro hall
    exact hasWitness_false_of_all_getD_empty hall

/-- On well-formed domain (`witness.length = vin.length`),
`hasWitness tx = true` ⟺ some witness slot of `tx.witness` itself is
nonempty — via `hasWitness_of_witness_mem_nonempty` and `getD_mem`.
Axioms: [propext, Quot.sound]. -/
theorem hasWitness_true_iff_mem (tx : Tx) (hwlen : tx.witness.length = tx.vin.length) :
    hasWitness tx = true ↔ ∃ s ∈ tx.witness, s.isEmpty = false := by
  constructor
  · intro hh
    rw [hasWitness, List.any_eq_true] at hh
    obtain ⟨i, hi, hne⟩ := hh
    refine ⟨tx.witness.getD i [],
      getD_mem [] tx.witness i (by rw [hwlen]; exact List.mem_range.mp hi), ?_⟩
    cases hb : (tx.witness.getD i []).isEmpty with
    | true => rw [hb] at hne; simp at hne
    | false => rfl
  · rintro ⟨s, hs, hne⟩
    exact hasWitness_of_witness_mem_nonempty hwlen s hs hne

/-! ## Base serialization is nonempty -/

/-- **BLK-024 (base form)**: a serialized tx is nonempty — the 4-byte
version field alone forces `4 ≤ (serTx tx).size`, so every summand of
`strippedSize` is bounded below by 4. Axioms: [propext, Quot.sound]. -/
theorem serTx_size_pos (tx : Tx) : 0 < (serTx tx).size := by
  have h : (serTx tx).size
      = (serU32 tx.version.toUInt32).size
        + ((compactSizeEnc tx.vin.length).size
        + ((tx.vin.foldl (fun acc i => acc ++ serTxIn i) ByteArray.empty).size
        + ((compactSizeEnc tx.vout.length).size
        + ((tx.vout.foldl (fun acc o => acc ++ serTxOut o) ByteArray.empty).size
        + (serU32 tx.locktime).size)))) := by
    simp [serTx]
    omega
  have h4 : (serU32 tx.version.toUInt32).size = 4 := by simp [serU32]
  omega

/-! ## Decode totality -/

/-- **Decode totality**: `decodeBlock` is a total function into `Except` —
it returns `.ok (header, txs)` or a `SerError`, never anything else (and
Lean's definitional totality means it cannot crash). This is the
Except-characterization of the capstone's step-1 gate. Axioms: [propext]. -/
theorem decodeBlock_total (raw : ByteArray) :
    (∃ h : BlockHeader, ∃ txs : List Tx, decodeBlock raw = .ok (h, txs))
    ∨ (∃ e : SerError, decodeBlock raw = .error e) := by
  cases decodeBlock raw with
  | ok p => obtain ⟨h, txs⟩ := p; exact Or.inl ⟨h, txs, rfl⟩
  | error e => exact Or.inr ⟨e, rfl⟩

/-- The same totality for the public header decoder. Axioms: [propext]. -/
theorem decodeBlockHeader_total (raw : ByteArray) :
    (∃ h : BlockHeader, decodeBlockHeader raw = .ok h)
    ∨ (∃ e : SerError, decodeBlockHeader raw = .error e) := by
  cases decodeBlockHeader raw with
  | ok h => exact Or.inl ⟨h, rfl⟩
  | error e => exact Or.inr ⟨e, rfl⟩

/-! ## Tie-in: what a successful `validateBlock` run implies about the decode -/

/-- **BLK-030 pipeline corollary**: if `validateBlock raw st` succeeds, then
step 1 really decoded a block — `decodeBlock raw = .ok (h, txs)` — and the
report's new state links forward with `prevHash = headerHash h` (the state
the next block's chain-link check consumes, exactly Block.lean's step-3
gate for the following anchor). Axioms: [propext, Classical.choice,
Quot.sound] (choice inherited from the `decTxCore_shape` layer). -/
theorem validateBlock_ok_decode (raw : ByteArray) (st : Bitcoin.Capstone.Block.CapState)
    (rep : Bitcoin.Capstone.Block.CapReport)
    (hv : Bitcoin.Capstone.Block.validateBlock raw st = .ok rep) :
    ∃ h : BlockHeader, ∃ txs : List Tx,
      decodeBlock raw = .ok (h, txs) ∧ rep.state.prevHash = headerHash h := by
  unfold Bitcoin.Capstone.Block.validateBlock at hv
  obtain ⟨h, txs, hdec, hJP⟩ := decodeMatch_inv raw _ _ hv
  refine ⟨h, txs, hdec, ?_⟩
  -- Collapse every guard's throw-branch to `Except.error` (definitional),
  -- then peel the 16 guard levels of the pipeline (BLK-022/027/028/029,
  -- 060..062/069, 037..039, chain-link, BLK-010/011, 015..020, 023..026): each
  -- `ite` either threw (contradiction with `hv : … = .ok rep`) or the run
  -- continued along the else-branch.
  simp only [bind_throw] at hJP
  rcases ite_ok_inv _ _ _ _ hJP with hJP | hJP <;>
    first | exact absurd hJP (errNeOk _ _) | skip
  rcases ite_ok_inv _ _ _ _ hJP with hJP | hJP <;>
    first | exact absurd hJP (errNeOk _ _) | skip
  rcases ite_ok_inv _ _ _ _ hJP with hJP | hJP <;>
    first | exact absurd hJP (errNeOk _ _) | skip
  rcases ite_ok_inv _ _ _ _ hJP with hJP | hJP <;>
    first | exact absurd hJP (errNeOk _ _) | skip
  rcases ite_ok_inv _ _ _ _ hJP with hJP | hJP <;>
    first | exact absurd hJP (errNeOk _ _) | skip
  rcases ite_ok_inv _ _ _ _ hJP with hJP | hJP <;>
    first | exact absurd hJP (errNeOk _ _) | skip
  rcases ite_ok_inv _ _ _ _ hJP with hJP | hJP <;>
    first | exact absurd hJP (errNeOk _ _) | skip
  rcases ite_ok_inv _ _ _ _ hJP with hJP | hJP <;>
    first | exact absurd hJP (errNeOk _ _) | skip
  rcases ite_ok_inv _ _ _ _ hJP with hJP | hJP <;>
    first | exact absurd hJP (errNeOk _ _) | skip
  rcases ite_ok_inv _ _ _ _ hJP with hJP | hJP <;>
    first | exact absurd hJP (errNeOk _ _) | skip
  rcases ite_ok_inv _ _ _ _ hJP with hJP | hJP <;>
    first | exact absurd hJP (errNeOk _ _) | skip
  rcases ite_ok_inv _ _ _ _ hJP with hJP | hJP <;>
    first | exact absurd hJP (errNeOk _ _) | skip
  rcases ite_ok_inv _ _ _ _ hJP with hJP | hJP <;>
    first | exact absurd hJP (errNeOk _ _) | skip
  rcases ite_ok_inv _ _ _ _ hJP with hJP | hJP <;>
    first | exact absurd hJP (errNeOk _ _) | skip
  rcases ite_ok_inv _ _ _ _ hJP with hJP | hJP <;>
    first | exact absurd hJP (errNeOk _ _) | skip
  rcases ite_ok_inv _ _ _ _ hJP with hJP | hJP <;>
    first | exact absurd hJP (errNeOk _ _) | skip
  -- All guards passed: the report came from the final `pure`, so the
  -- tail-bind's `applyTxs` result was `.ok (utxo', okN, unjN)` and
  -- `rep` is exactly the state-literal built from the decoded header.
  obtain ⟨y, hy, hgy⟩ := bind_ok_inv _ _ _ hJP
  obtain ⟨utxo', okn, unjn⟩ := y
  have hv2 : Except.ok ({ state := { height := st.height + 1
                                        , prevHash := headerHash h
                                        , utxo := utxo' }
                        , txs := txs.length, scriptOk := okn
                        , scriptUnjudged := unjn } :
      Bitcoin.Capstone.Block.CapReport) = Except.ok rep := hgy
  simp only [Except.ok.injEq] at hv2
  rw [← hv2]

end BitcoinProofs.Theorems.CapstoneDecode
