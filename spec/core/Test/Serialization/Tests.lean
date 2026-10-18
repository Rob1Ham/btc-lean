import Bitcoin.Serialization.Interface

/-!
# Bitcoin.Serialization unit tests — Serialization conformance vectors

Every check is a build-time `example … := by decide` (kernel-reduced, no
IO), mirroring the prototype pattern. All byte-exact vectors were
generated independently with plain Python (`struct`-packing, `gen_vectors.py`
separately), mirroring Bitcoin Core's serialization code
@ `c50817f` (`serialize.h` CompactSize, `primitives/transaction.h`
`UnserializeTransaction`, `primitives/block.h`).

Tx structures derive only `Repr` (no `DecidableEq`), so tx-decode vectors
use the re-encode trick: decode, re-encode, compare `ByteArray`s.
Error vectors decide directly on `SerError` (which has `DecidableEq`).

Coverage: canonical CompactSize encode/decode at all framing boundaries
(0xfc/0xfd, 0xffff/0x10000, MAX_SIZE), non-canonical rejects (TXV-012),
legacy tx decode/re-encode, SegWit (BIP144) framing decode/re-encode,
superfluous-witness reject (TXV-015), unknown-flag reject (TXV-016),
trailing-data reject (TXV-013 framing), the genesis block header (80 bytes)
and the genesis block (header + varint(1) + coinbase), plus theorem-level
applications of T1 (`decodeTx_encodeTx`), BLK-001 and BLK-002.
-/

namespace Test.Serialization.Tests

open Bitcoin.Serialization Bitcoin.Data Bitcoin.Chain

set_option maxRecDepth 10000

/-- Lean 4.34 core ships no `DecidableEq (Except α β)`; the test vectors
decide on `Except` equalities, so provide it locally. -/
instance instDecEqExcept {α β : Type} [DecidableEq α] [DecidableEq β] :
    DecidableEq (Except α β)
  | .error e, .error e' =>
      match decEq e e' with
      | isTrue h => isTrue (by rw [h])
      | isFalse h => isFalse (by intro h2; exact h (Except.error.inj h2))
  | .ok a, .ok b =>
      match decEq a b with
      | isTrue h => isTrue (by rw [h])
      | isFalse h => isFalse (by intro h2; exact h (Except.ok.inj h2))
  | .error _, .ok _ => isFalse (by intro h; simp at h)
  | .ok _, .error _ => isFalse (by intro h; simp at h)

/-! ## Hex helpers (test infra only; local copy of the Main.lean helpers) -/

def hexDigitVal (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48)        -- '0'..'9'
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)  -- 'a'..'f'
  else if 65 ≤ n ∧ n ≤ 70 then some (n - 55)   -- 'A'..'F'
  else none

def fromHex (s : String) : ByteArray :=
  go s.toList ByteArray.empty
where
  go : List Char → ByteArray → ByteArray
    | [], acc => acc
    | [_], acc => acc
    | a :: b :: rest, acc =>
        match hexDigitVal a, hexDigitVal b with
        | some ha, some hb => go rest (acc.push ((ha * 16 + hb).toUInt8))
        | _, _ => go rest acc

/-- Byte-list view of a hex string. -/
def hex (s : String) : Bytes := (fromHex s).data.toList

/-- Project the error out of a tx decode (Tx has no `DecidableEq`). -/
def errOfTx : Except SerError Tx → Option SerError
  | .ok _ => none
  | .error e => some e

/-- Project the error out of a header decode (no `DecidableEq`). -/
def errOfHeader : Except SerError Bitcoin.Chain.BlockHeader → Option SerError
  | .ok _ => none
  | .error e => some e

/-- Re-encode the result of a tx decode (`.error` → empty). -/
def reEncodeTx : Except SerError Tx → ByteArray
  | .ok t => encodeTx t
  | .error _ => ByteArray.empty

/-- Re-encode the result of a header decode (`.error` → empty). -/
def reEncodeHeader : Except SerError Bitcoin.Chain.BlockHeader → ByteArray
  | .ok h => encodeBlockHeader h
  | .error _ => ByteArray.empty

/-! ## CompactSize (TXV-012): canonical framing boundaries -/

-- encode side
example : encCSL 0 = [0x00] := rfl
example : encCSL 252 = [0xfc] := rfl
example : encCSL 253 = [0xfd, 0xfd, 0x00] := rfl
example : encCSL 65535 = [0xfd, 0xff, 0xff] := rfl
example : encCSL 65536 = [0xfe, 0x00, 0x00, 0x01, 0x00] := rfl
example : encCSL Bitcoin.Serialization.MAX_SIZE =
    [0xfe, 0x00, 0x00, 0x00, 0x02] := rfl

-- decode side (same boundaries, independently packed Python vectors)
example : decCS (hex "00") = .ok (0, []) := by decide
example : decCS (hex "fc") = .ok (252, []) := by decide
example : decCS (hex "fdfd00") = .ok (253, []) := by decide
example : decCS (hex "fdffff") = .ok (65535, []) := by decide
example : decCS (hex "fe00000100") = .ok (65536, []) := by decide
example : decCS (hex "fe00000002") =
    .ok (Bitcoin.Serialization.MAX_SIZE, []) := by decide

-- roundtrip at the boundaries
example : decCS (encCSL 0xfc) = .ok (0xfc, []) := by decide
example : decCS (encCSL 0xfd) = .ok (0xfd, []) := by decide
example : decCS (encCSL 0xffff) = .ok (0xffff, []) := by decide
example : decCS (encCSL 0x10000) = .ok (0x10000, []) := by decide

-- ByteArray-level API (frozen interface members)
example : bytesBEq (encodeCompactSize 65536) (fromHex "fe00000100") = true := by decide
example : decodeCompactSize (fromHex "fdfd00") 0 = some (253, 3) := by decide
example : decodeCompactSize (fromHex "fe00000100") 0 = some (65536, 5) := by decide
example : decodeCompactSize (fromHex "01") 5 = none := by decide

/-! ### Non-canonical / malformed CompactSize rejects (TXV-012) -/

-- 252 claimed via 0xfd
example : decCS (hex "fdfc00") = .error .compactSizeNonMinimal := by decide
-- 65535 claimed via 0xfe
example : decCS (hex "feffff0000") = .error .compactSizeNonMinimal := by decide
-- 2^32 claimed via 0xff: beyond MAX_SIZE → "size too large"
example : decCS (hex "ff0000000001000000") = .error .compactSizeTooLong := by decide
-- truncated 0xfd header
example : decCS (hex "fd01") = .error .truncated := by decide
-- empty input
example : decCS ([] : Bytes) = .error .truncated := by decide

/-! ## Legacy tx (the prototype sampleCoinbase) — decode + byte-exact re-encode -/

/-- Legacy coinbase wire form (same vector as Main.lean's
`sampleCoinbaseHex`, independently regenerated). -/
def legacyTxHex : String :=
  "01000000010000000000000000000000000000000000000000000000000000000000000000\
   ffffffff03025152ffffffff0100f2052a01000000015100000000"

-- decode succeeds, re-encode is byte-exact
example : reEncodeTx (decodeTx (fromHex legacyTxHex)) = fromHex legacyTxHex := by decide
-- decode consumes everything (error-free)
example : errOfTx (decodeTx (fromHex legacyTxHex)) = none := by decide

-- trailing data rejected (Core's DecodeHexTx semantics)
def legacyTrailingHex : String := legacyTxHex ++ "00"
example : errOfTx (decodeTx (fromHex legacyTrailingHex)) = some .badMarkerOrFlag := by decide

/-! ## SegWit (BIP144) framing — marker 0x00, flag 0x01, witness stacks -/

/-- Fabricated SegWit tx: version 2, one input (prev txid `10..2f`,
empty scriptSig, sequence 0xfffffffe), one output (1000 zsat, OP_TRUE),
one witness stack carrying the single 2-byte item `dead`. -/
def witTxHex : String :=
  "02000000000101101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f\
   0000000000feffffff01e80300000000000001510102dead00000000"

-- decode succeeds, canonical re-encode (with witness) is byte-exact
example : reEncodeTx (decodeTx (fromHex witTxHex)) = fromHex witTxHex := by decide
example : errOfTx (decodeTx (fromHex witTxHex)) = none := by decide

/-! ### Superfluous witness reject (TXV-015)

Same SegWit frame, but the single witness stack is empty — Core throws
"superfluous witness record". -/
def superfluousTxHex : String :=
  "02000000000101101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f\
   0000000000feffffff01e80300000000000001510000000000"

example : errOfTx (decodeTx (fromHex superfluousTxHex)) = some .superfluousWitness := by decide

/-! ### Unknown flag reject (TXV-016)

Marker 0x00 with flag 0x02: Core re-reads vin/vout, then rejects the
non-{0,1} flags byte. -/
def unknownFlagTxHex : String :=
  "02000000000201101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f\
   0000000000feffffff01e803000000000000015100000000"

example : errOfTx (decodeTx (fromHex unknownFlagTxHex)) = some .unknownFlag := by decide

/-! ## T1 applied: the genesis coinbase roundtrips through the public API -/

/-- The genesis block's coinbase, in the wire domain. `witness := [[]]`
(one empty stack, exactly what the legacy decoder produces) so that
`wireDomain`'s per-input witness-slot invariant holds; `encodeTx` takes
the base (no-witness) form since every stack is empty. -/
def genesisCoinbase : Tx where
  version := 1
  vin := [{ prevout := OutPoint.null
            scriptSig := scriptOf [0x02, 0x51, 0x52]  -- push [0x51], push [0x52]
            sequence := 0xFFFFFFFF }]
  vout := [{ value := 5000000000, scriptPubKey := scriptOf [0x51] }]  -- 50 BTC, OP_TRUE
  locktime := 0
  witness := [[]]

/-- `wireDomain genesisCoinbase`, component-wise. -/
theorem genesisCoinbaseDomain : wireDomain genesisCoinbase := by
  refine ⟨by decide, rfl, by decide, by decide, ?_, ?_, ?_⟩
  · rintro i hi
    rcases List.mem_cons.mp hi with rfl | h
    · exact ⟨by decide, by decide⟩
    · exact absurd h (by simp)
  · rintro o ho
    rcases List.mem_cons.mp ho with rfl | h
    · exact ⟨by decide, by decide, by decide⟩
    · exact absurd h (by simp)
  · rintro s hs
    rcases List.mem_cons.mp hs with rfl | h
    · exact ⟨by decide, by simp⟩
    · exact absurd h (by simp)

-- **T1** on a concrete tx
example : decodeTx (encodeTx genesisCoinbase) = .ok genesisCoinbase :=
  decodeTx_encodeTx genesisCoinbase genesisCoinbaseDomain

-- its encoding is the legacy (no-witness) wire form, byte-exact
example : bytesBEq (encodeTx genesisCoinbase) (fromHex legacyTxHex) = true := by decide

-- base serialization (what txid is computed over) is the same bytes
example : bytesBEq (encodeTxNoWitness genesisCoinbase) (fromHex legacyTxHex) = true := by decide

/-! ## Block header (BLK-001) — the genesis header -/

/-- Block 0's header (version 1, null prev hash, the famous merkle root,
nTime 1231006505, nBits 0x1d00ffff, nNonce 2083236893). -/
def genesisHeader : Bitcoin.Chain.BlockHeader where
  version := 1
  hashPrevBlock := zeroBytes 32
  hashMerkleRoot := fromHex
    "3ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4a"
  time := 0x495fab29
  bits := 0x1d00ffff
  nonce := 0x7c2bac1d

def genesisHeaderHex : String :=
  "010000000000000000000000000000000000000000000000000000000000000000000000\
   3ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4a\
   29ab5f49ffff001d1dac2b7c"

-- encode is byte-exact (80 bytes, field order is consensus)
example : bytesBEq (encodeBlockHeader genesisHeader) (fromHex genesisHeaderHex) = true := by decide
-- decode succeeds and re-encodes byte-exact
example : reEncodeHeader (decodeBlockHeader (fromHex genesisHeaderHex)) =
    fromHex genesisHeaderHex := by decide
example : errOfHeader (decodeBlockHeader (fromHex genesisHeaderHex)) = none := by decide

-- **BLK-001** applied
example : decodeBlockHeader (encodeBlockHeader genesisHeader) = .ok genesisHeader :=
  decodeBlockHeader_encodeBlockHeader genesisHeader (by decide) (by decide)

-- 79-byte header → truncated (the 80-byte vector minus its last byte)
def genesisHeader79Hex : String :=
  "010000000000000000000000000000000000000000000000000000000000000000000000\
   3ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4a\
   29ab5f49ffff001d1dac2b"
example : errOfHeader (decodeBlockHeader (fromHex genesisHeader79Hex)) = some .truncated := by
  decide

/-! ## Block (BLK-002) — the genesis block -/

def genesisBlockHex : String :=
  genesisHeaderHex ++
  "01" ++
  "01000000010000000000000000000000000000000000000000000000000000000000000000\
   ffffffff03025152ffffffff0100f2052a01000000015100000000"

-- encode is byte-exact: header ‖ varint(1) ‖ coinbase
example : bytesBEq (encodeBlock genesisHeader [genesisCoinbase])
    (fromHex genesisBlockHex) = true := by native_decide

-- **BLK-002** applied: decode ∘ encode = id
theorem singleGenesisDomain : ∀ t ∈ [genesisCoinbase], wireDomain t := by
  intro t ht
  have hte : t = genesisCoinbase := by
    cases ht with
    | head => rfl
    | tail _ h => cases h
  subst hte
  exact genesisCoinbaseDomain

example : decodeBlock (encodeBlock genesisHeader [genesisCoinbase]) =
    .ok (genesisHeader, [genesisCoinbase]) :=
  decodeBlock_encodeBlock genesisHeader [genesisCoinbase] (by decide) (by decide)
    (by decide) singleGenesisDomain

-- decode of the independently generated vector succeeds
def errOfBlock : Except SerError (Bitcoin.Chain.BlockHeader × List Tx) → Option SerError
  | .ok _ => none
  | .error e => some e

example : errOfBlock (decodeBlock (fromHex genesisBlockHex)) = none := by native_decide

end Test.Serialization.Tests
