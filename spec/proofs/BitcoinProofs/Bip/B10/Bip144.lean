import Bitcoin.Data.Basic
import Bitcoin.Data.Tx

/-!
# BitcoinProofs.Bip.B10.Bip144 — BIP144 consensus-framing reference codec

B10 (Review-5 support suite) reference implementation of the BIP144
witness-serialization *consensus* clauses, cross-checked (python3,
`scratch/B10/bip144_ref.py`) against the BIP text (public domain) and
Bitcoin Core @ cce32b168
`src/primitives/transaction.h:UnserializeTransaction:212-239` (the
rules.yaml ground-truth pin).

NEW self-contained module (owned by B10; touches no existing file).
It is the executable oracle the W02 `decodeTx`/`encodeTx`
implementations of `Bitcoin.Serialization` (TXV-011..016) must match;
`Bitcoin.Serialization.Interface` currently ships `SerError` plus
sorry-stubbed `opaque decodeTx`, so every BIP144 consensus clause is
COVERED-WEAK/MISSING in the tree today — clause table in
`spec/db/findings-w5/B10.md`.

Consensus clauses encoded here (BIP144 §Specification; the P2P-only
material — NODE_WITNESS, MSG_WITNESS_* inv types, getdata semantics —
carries no consensus force and is out of scope):

* K1 framing: version ‖ marker(0x00) ‖ flag(0x01) ‖ vin ‖ vout ‖
  witness ‖ locktime; the witness path is entered iff the leading
  vin-count varint reads 0 and the flag byte has bit 0 set
  (`UnserializeTransaction:212-222`).
* K2 stacks: one stack per input, count implied by vin_count, in vin
  order; each stack = CompactSize item count, items = CompactSize
  length ‖ bytes; empty stack = single 0x00 byte.
* K3 superfluous-witness ban: flag set but all stacks empty ⇒ decode
  failure (Core "Superfluous witness record", transaction.h:229-232;
  row TXV-015).
* K4 unknown-flag ban: flag bits other than bit 0 ⇒ decode failure
  (Core "Unknown transaction optional data", transaction.h:234-237;
  row TXV-016).
* K5 hashes: txid is computed over the base (non-witness) encoding —
  `encodeTx144 tx = serTx tx` when the witness is empty — hence an
  empty witness gives wtxid = txid. The hash functions themselves are
  the core-side seam (TXV-017/018), not re-implemented here.
* K6 values: a txout value is a raw `int64_t`; the codec decodes it with
  `u64ToAmt`, so a high bit set is a two's-complement NEGATIVE amount
  (later rejected by `bad-txns-vout-negative`), not a huge unsigned
  amount.
-/

namespace BitcoinProofs.Bip.B10

open Bitcoin.Data

/-! ## Error taxonomy — one constructor per BIP144/Core rejection class -/

/-- BIP144 decode failures (mirrors the `Bitcoin.Serialization.SerError`
constructors TXV-013/015/016 plus truncation; the CompactSize
canonicality class is TXV-012, owned elsewhere). -/
inductive Err where
  | truncated            -- input ended mid-field
  | superfluousWitness   -- K3 / TXV-015: flag set, all stacks empty
  | unknownFlag          -- K4 / TXV-016: flag bits beyond bit 0
deriving Repr, DecidableEq

deriving instance BEq for TxIn, TxOut, Tx

/-- Vector-literal helper (test data only). -/
def bytesOf (l : List UInt8) : ByteArray := l.toByteArray

/-! ## Readers (`Except Err`, binds kept explicit so the rejection
theorems reduce by case analysis) -/

def rdBytes (b : ByteArray) (i n : Nat) : Except Err (ByteArray × Nat) :=
  if i + n ≤ b.size then .ok (b.extract i (i + n), i + n) else .error .truncated

def rdFlag (b : ByteArray) (i : Nat) : Except Err (Nat × Nat) :=
  match b[i]? with
  | some x => .ok (x.toNat, i + 1)
  | none => .error .truncated

/-- CompactSize read; `none` from `compactSizeDec` is truncation.
(Canonicality — TXV-012 — is owned elsewhere; `compactSizeDec`
accepts non-minimal forms.) -/
def rdCs (b : ByteArray) (i : Nat) : Except Err (Nat × Nat) :=
  match compactSizeDec b i with
  | some (v, c) => .ok (v, i + c)
  | none => .error .truncated

/-- 4-byte little-endian → UInt32 (`serialize.h` Load32). -/
def le32 (bs : ByteArray) : UInt32 :=
  (bs.get! 0).toUInt32 ||| ((bs.get! 1).toUInt32 <<< 8)
    ||| ((bs.get! 2).toUInt32 <<< 16) ||| ((bs.get! 3).toUInt32 <<< 24)

/-- 4-byte little-endian → int32_t (two's complement). -/
def leI32 (bs : ByteArray) : Int32 :=
  if (bs.get! 3).toNat < 0x80 then Int32.ofNat (le32 bs).toNat
  else Int32.ofInt ((le32 bs).toNat - 0x100000000)

/-- 8-byte little-endian → Nat (txout value). -/
def rdU64 (bs : ByteArray) : Nat :=
  (List.range 8).foldl (fun acc k => acc + (bs.get! k).toNat * 256 ^ k) 0

def rdVin (b : ByteArray) (i : Nat) : Except Err (TxIn × Nat) := do
  let h ← rdBytes b i 32
  let n ← rdBytes b h.2 4
  let sl ← rdCs b n.2
  let sb ← rdBytes b sl.2 sl.1
  let sq ← rdBytes b sb.2 4
  .ok (⟨⟨h.1, le32 n.1⟩, ⟨sb.1⟩, le32 sq.1⟩, sq.2)

/-- 8-byte little-endian → signed `CAmount` (two's complement). Core
serializes `int64_t`, so a high bit set is a NEGATIVE output value (the
`bad-txns-vout-negative` class), not a huge unsigned amount. -/
def rdVout (b : ByteArray) (i : Nat) : Except Err (TxOut × Nat) := do
  let v ← rdBytes b i 8
  let sl ← rdCs b v.2
  let sb ← rdBytes b sl.2 sl.1
  .ok (⟨u64ToAmt (rdU64 v.1), ⟨sb.1⟩⟩, sb.2)

def rdList {α : Type} (rd : ByteArray → Nat → Except Err (α × Nat))
    (b : ByteArray) (i : Nat) : Nat → Except Err (List α × Nat)
  | 0 => .ok ([], i)
  | n + 1 =>
    (rd b i).bind (fun p =>
      (rdList rd b p.2 n).map (fun q => (p.1 :: q.1, q.2)))

/-- One script witness stack: CompactSize item count, then
CompactSize-length-prefixed items. Empty stack = single 0x00. -/
def rdStack (b : ByteArray) (i : Nat) : Except Err (WitnessStack × Nat) :=
  (rdCs b i).bind (fun p => (rdItems b p.2 p.1).map (fun q => (q.1, q.2)))
where
  rdItems (b : ByteArray) (i : Nat) : Nat → Except Err (List ByteArray × Nat)
    | 0 => .ok ([], i)
    | n + 1 =>
      (rdCs b i).bind (fun p =>
      (rdBytes b p.2 p.1).bind (fun it =>
        (rdItems b it.2 n).map (fun q => (it.1 :: q.1, q.2))))

/-- `n` stacks, one per input, in input order (BIP144: the number of
script witnesses is implied by txin_count, never serialized). -/
def rdStacks (b : ByteArray) (i : Nat) : Nat → Except Err (List WitnessStack × Nat)
  | 0 => .ok ([], i)
  | n + 1 =>
    (rdStack b i).bind (fun p =>
      (rdStacks b p.2 n).map (fun q => (p.1 :: q.1, q.2)))

/-- Spine lemma for `rdStacks`: a successful read yields exactly `n`
stacks (K2, count-implied side). -/
theorem rdStacks_spine : ∀ (b : ByteArray) (n i : Nat) (ss : List WitnessStack) (i' : Nat),
    rdStacks b i n = .ok (ss, i') → ss.length = n := by
  intro b n
  induction n with
  | zero =>
    intro i ss i' h
    simp only [rdStacks] at h
    simp at h
    obtain ⟨rfl, rfl⟩ := h
    rfl
  | succ n ih =>
    intro i ss i' h
    simp only [rdStacks] at h
    cases hp : rdStack b i with
    | error e =>
      rw [hp] at h
      simp only [Except.bind.eq_1] at h
      simp at h
    | ok p =>
      rw [hp] at h
      simp only [Except.bind.eq_2] at h
      cases hq : rdStacks b p.2 n with
      | error e =>
        rw [hq] at h
        simp only [Except.map.eq_1] at h
        simp at h
      | ok q =>
        rw [hq] at h
        simp only [Except.map.eq_2] at h
        simp at h
        obtain ⟨rfl, rfl⟩ := h
        simp [ih p.2 q.1 q.2 hq]

/-! ## K3 / K4: the witness section, with the two consensus bans -/

/-- Witness section after vout: present iff flag bit 0 is set (K1).
All-empty stacks under the flag ⇒ `superfluousWitness` (K3); residual
flag bits ⇒ `unknownFlag` (K4). Rejection order matches Core:
superfluous before unknown-flag (transaction.h:229-237). -/
def witnessSection (b : ByteArray) (i flag : Nat) (vins : List TxIn) :
    Except Err (List WitnessStack × Nat) :=
  if flag % 2 == 1 then
    (rdStacks b i vins.length).bind (fun p =>
      if p.1.all (·.isEmpty) then .error .superfluousWitness
      else if flag / 2 ≠ 0 then .error .unknownFlag
      else .ok p)
  else
    if flag ≠ 0 then .error .unknownFlag
    else .ok ([], i)

/-- K2: when the witness section is present (flag bit 0 set), a
successful read yields exactly one stack per input. -/
theorem witnessSection_spine (b : ByteArray) (i flag : Nat) (vins : List TxIn)
    (ss : List WitnessStack) (i' : Nat)
    (h : witnessSection b i flag vins = .ok (ss, i')) (hf : flag % 2 = 1) :
    ss.length = vins.length := by
  simp only [witnessSection] at h
  rw [if_pos (by simpa using hf)] at h
  cases hp : rdStacks b i vins.length with
  | error e =>
    rw [hp] at h
    simp only [Except.bind.eq_1] at h
    simp at h
  | ok p =>
    rw [hp] at h
    simp only [Except.bind.eq_2] at h
    split at h
    · simp at h
    · split at h
      · simp at h
      · simp only [Except.ok.injEq] at h
        subst h
        exact rdStacks_spine b vins.length i ss i' hp

/-- K3 (general form): a successful witness section never carries
all-empty stacks — the superfluous-witness framing is rejected. -/
theorem witnessSection_not_superfluous (b : ByteArray) (i flag : Nat) (vins : List TxIn)
    (ss : List WitnessStack) (i' : Nat)
    (h : witnessSection b i flag vins = .ok (ss, i')) (hf : flag % 2 = 1) :
    ¬ (ss.all (·.isEmpty)) := by
  simp only [witnessSection] at h
  rw [if_pos (by simpa using hf)] at h
  cases hp : rdStacks b i vins.length with
  | error e =>
    rw [hp] at h
    simp only [Except.bind.eq_1] at h
    simp at h
  | ok p =>
    rw [hp] at h
    simp only [Except.bind.eq_2] at h
    split at h
    · simp at h
    · rename_i hne
      split at h
      · simp at h
      · simp only [Except.ok.injEq] at h
        subst h
        exact hne

/-- K4 (general form, witness path): flag = 0x01 with residual bits ⇒
`unknownFlag`, never a successful decode. -/
theorem witnessSection_unknownflag (b : ByteArray) (i flag : Nat) (vins : List TxIn)
    (ss : List WitnessStack) (i' : Nat)
    (h : witnessSection b i flag vins = .ok (ss, i'))
    (hf : flag % 2 = 1) (hg : flag / 2 ≠ 0) : False := by
  simp only [witnessSection] at h
  rw [if_pos (by simpa using hf)] at h
  cases hp : rdStacks b i vins.length with
  | error e =>
    rw [hp] at h
    simp only [Except.bind.eq_1] at h
    simp at h
  | ok p =>
    rw [hp] at h
    simp only [Except.bind.eq_2] at h
    by_cases hall : p.1.all (·.isEmpty) = true
    · rw [if_pos hall] at h; simp at h
    · rw [if_neg hall] at h
      rw [if_pos hg] at h
      simp at h

/-- K4 (general form, no-witness path): flag with bit 0 CLEAR but
nonzero ⇒ `unknownFlag`. -/
theorem witnessSection_flag_no_bit0 (b : ByteArray) (i flag : Nat) (vins : List TxIn)
    (hf : flag % 2 = 0) (hg : flag ≠ 0) :
    witnessSection b i flag vins = .error .unknownFlag := by
  simp only [witnessSection]
  rw [if_neg (by simp [hf])]
  rw [if_pos (by simp [hg])]

/-! ## Full decode — Core `UnserializeTransaction` @cce32b168 -/

/-- The BIP144 "marker" is realized as the leading vin-count varint
reading 0 (`tx.vin.size() == 0` branch); only then is a flag byte
consumed. Core re-reads vin/vout iff the flag byte is NONZERO; with
flag = 0x00 no re-read happens and the tx decodes as 0-in/0-out
(rejected end-to-end later by the vin-empty rule INV-001, not by the
codec) — pinned by vector V8. -/
def decodeTx144 (b : ByteArray) : Except Err Tx := do
  let vb ← rdBytes b 0 4
  let pc ← rdCs b 4
  if pc.1 = 0 then
    let fl ← rdFlag b pc.2
    if fl.1 ≠ 0 then
      let vc ← rdCs b fl.2
      let vs ← rdList rdVin b vc.2 vc.1
      let oc ← rdCs b vs.2
      let os ← rdList rdVout b oc.2 oc.1
      let ws ← witnessSection b os.2 fl.1 vs.1
      let lt ← rdBytes b ws.2 4
      .ok ⟨leI32 vb.1, vs.1, os.1, le32 lt.1, ws.1⟩
    else
      let lt ← rdBytes b fl.2 4
      .ok ⟨leI32 vb.1, [], [], le32 lt.1, []⟩
  else
    let vs ← rdList rdVin b pc.2 pc.1
    let oc ← rdCs b vs.2
    let os ← rdList rdVout b oc.2 oc.1
    let lt ← rdBytes b os.2 4
    .ok ⟨leI32 vb.1, vs.1, os.1, le32 lt.1, []⟩

/-! ## Encode — witness serialization iff the witness is nonempty -/

/-- Core `CTransaction::HasWitness()`. -/
def txHasWitness (tx : Tx) : Bool := tx.witness.any (fun s => !s.isEmpty)

def encStack (s : WitnessStack) : ByteArray :=
  compactSizeEnc s.length ++
    s.foldl (fun acc it => acc ++ compactSizeEnc it.size ++ it) ByteArray.empty

def encVins (vins : List TxIn) : ByteArray :=
  compactSizeEnc vins.length ++ vins.foldl (fun acc i => acc ++ serTxIn i) ByteArray.empty

def encVouts (vouts : List TxOut) : ByteArray :=
  compactSizeEnc vouts.length ++ vouts.foldl (fun acc o => acc ++ serTxOut o) ByteArray.empty

/-- BIP144 encode: marker 0x00 + flag 0x01 + stacks exactly when
`HasWitness()`; the base (old) format otherwise. A stack count is NOT
emitted — implied by vin_count (K2). -/
def encodeTx144 (tx : Tx) : ByteArray :=
  serU32 tx.version.toUInt32
    ++ (if txHasWitness tx then serU8 0 ++ serU8 1 else ByteArray.empty)
    ++ encVins tx.vin ++ encVouts tx.vout
    ++ (if txHasWitness tx
        then tx.witness.foldl (fun acc s => acc ++ encStack s) ByteArray.empty
        else ByteArray.empty)
    ++ serU32 tx.locktime

/-! ## Consensus theorems (sorry-free) -/

/-- K3 (encode side) / K5: an empty witness is serialized in the OLD
format — the BIP144 framing is emitted iff the witness is nonempty,
and the base encoding (over which txid is computed, TXV-017) is
`serTx`. -/
theorem enc_empty_witness_base (tx : Tx) (h : ¬ txHasWitness tx) :
    encodeTx144 tx = serTx tx := by
  have hc : ¬ (txHasWitness tx = true) := h
  simp only [encodeTx144]
  simp only [if_neg hc]
  simp [serTx, encVins, encVouts, ByteArray.append_assoc, ByteArray.empty_append]

/-! ## V9 regression — int64 output signedness (BIP144 K6 / TXV-018)

A wire value of `0xffffffffffffffff` is `-1`, not `2^64−1`: Core
serializes `CAmount` as `int64_t` and `checkTransaction` rejects the
negative amount (`bad-txns-vout-negative`). These are the regressions
for the audit's BIP144 signed-decoding finding. -/

def v9NegOneWire : ByteArray :=
  bytesOf [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]

theorem v9_leaf_v :
    rdBytes (v9NegOneWire ++ bytesOf [0x01, 0x51]) 0 8 =
      .ok (v9NegOneWire, 8) := by rfl

theorem v9_leaf_sl :
    rdCs (v9NegOneWire ++ bytesOf [0x01, 0x51]) 8 = .ok (1, 9) := by rfl

theorem v9_leaf_sb :
    rdBytes (v9NegOneWire ++ bytesOf [0x01, 0x51]) 9 1 =
      .ok (bytesOf [0x51], 10) := by rfl

theorem v9_u64_neg_one : u64ToAmt (rdU64 v9NegOneWire) = (-1 : Amount) := by
  have h : rdU64 v9NegOneWire = 18446744073709551615 := by
    unfold rdU64
    rfl
  rw [h]
  rfl

/-- V9 positive face: the codec decodes the high-bit wire value as the
signed amount `-1`. -/
theorem v9_value_is_negative_one :
    rdVout (v9NegOneWire ++ bytesOf [0x01, 0x51]) 0 =
      .ok (⟨(-1 : Amount), ⟨bytesOf [0x51]⟩⟩, 10) := by
  unfold rdVout
  simp only [Bind.bind, Except.bind.eq_2, v9_leaf_v, v9_leaf_sl, v9_leaf_sb,
    v9_u64_neg_one]

/-- V9 negative face: the raw unsigned reading `2^64−1` is not produced. -/
theorem v9_value_not_unsigned :
    rdVout (v9NegOneWire ++ bytesOf [0x01, 0x51]) 0 ≠
      .ok (⟨((2 ^ 64 - 1 : Nat) : Amount), ⟨bytesOf [0x51]⟩⟩, 10) := by
  rw [v9_value_is_negative_one]
  intro h
  injection h with hp
  have hv : (-1 : Amount) = ((2 ^ 64 - 1 : Nat) : Amount) :=
    congrArg TxOut.value (congrArg Prod.fst hp)
  exact absurd hv (by decide)

end BitcoinProofs.Bip.B10
