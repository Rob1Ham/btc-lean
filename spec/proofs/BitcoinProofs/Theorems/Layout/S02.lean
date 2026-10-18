import Bitcoin.Serialization.Interface
import Bitcoin.Block.Params
import Bitcoin.Capstone.Pow

/-!
# BitcoinProofs.Theorems.Layout.S02 — 80-byte block-header byte-map

Layout tier (S02). Ground truth: the header wire form of
`spec/core/Bitcoin/Serialization/Interface.lean` `encHeaderL`
(primitives/block.h `CBlockHeader` SERIALIZE_METHODS @c50817f) and
`Bitcoin.Capstone.Pow.headerHash` (BLK-003, `GetHash`).

The six-field byte map, all fields little-endian:

| offset | size | field           | encoder   |
|--------|------|-----------------|-----------|
| 0..4   | 4    | `nVersion`      | `encU32L` |
| 4..36  | 32   | `hashPrevBlock` | raw bytes |
| 36..68 | 32   | `hashMerkleRoot`| raw bytes |
| 68..72 | 4    | `nTime`         | `encU32L` |
| 72..76 | 4    | `nBits`         | `encU32L` |
| 76..80 | 4    | `nNonce`        | `encU32L` |

VERIFIED below (sorry-free; axiom pins in `axioms.txt`):

* the six take/drop byte-map theorems + total length 80 (`headerLen`);
* `headerHash_dsha` — `headerHash h = sha256d (bytesOfList (encHeaderL h))`
  (the BLK-003 composition) and the 32-byte digest-size contract;
* CompactSize header-count framing: in `header ‖ cs(count) ‖ txs` the
  count starts exactly at offset 80 and the two-stage decode
  (header, then count) succeeds on any such frame;
* genesis pins: `encHeaderL genesisHeader` is the literal 80-byte
  genesis wire form, byte for byte.

python3 cross-check (2026-10-16, `crosscheck.py`): a faithful
python mirror of `encU32L`/`encHeaderL`/`encCSL`/sha256d asserts every
offset slice above, the all-LE round-decode of each field, and
`sha256d(genesis wire).reverse` = the canonical display hash
`000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f` —
all pass; the literal byte lists pinned in §5 are that script's output.
-/

namespace BitcoinProofs.Theorems.Layout.S02

open Bitcoin.Data Bitcoin.Chain Bitcoin.Serialization Bitcoin.Capstone.Pow
open Bitcoin.Crypto.Seam.Hash

/-! ## 0. Primitive sizes and list surgery helpers -/

/-- `encU32L` is exactly 4 bytes (LE). -/
theorem encU32L_length (x : UInt32) : (encU32L x).length = 4 := rfl

/-- `bL` preserves length. -/
theorem bL_length (b : ByteArray) : (bL b).length = b.size := by simp [bL]

/-- A 32-byte hash field contributes exactly 32 wire bytes. -/
theorem len32 {b : ByteArray} (h : b.size = 32) : (bL b).length = 32 := by
  rw [bL_length, h]

/-- Take of an exactly-`n`-long prefix is the prefix itself. -/
private theorem take_head {α : Type} {l rest : List α} {n : Nat} (hl : l.length = n) :
    (l ++ rest).take n = l := by
  rw [List.take_append, hl, Nat.sub_self, List.take_zero, List.append_nil]
  exact List.take_of_length_le (by rw [hl]; exact Nat.le_refl n)

/-- Dropping at least the prefix length `m` lands in the tail, `m` bytes in. -/
private theorem drop_gt {α : Type} {l rest : List α} {n m : Nat} (hl : l.length = m)
    (hmn : m ≤ n) : (l ++ rest).drop n = rest.drop (n - m) := by
  rw [List.drop_append, List.drop_eq_nil_of_le (by rw [hl]; exact hmn), hl,
    List.nil_append]

/-! ## 1. Flat wire form -/

/-- `encHeaderL` right-associated: `nVersion ‖ prev ‖ merkle ‖ time ‖
nBits ‖ nNonce`, each field in little-endian wire order. -/
theorem headerFlat (h : Bitcoin.Chain.BlockHeader) :
    encHeaderL h =
      encU32L h.version.toUInt32 ++
        (bL h.hashPrevBlock ++
          (bL h.hashMerkleRoot ++
            (encU32L h.time ++ (encU32L h.bits ++ encU32L h.nonce)))) := by
  simp only [encHeaderL, List.append_assoc]

/-! ## 2. The byte map (offsets 0..80) -/

/-- Byte map @0..4: `nVersion` little-endian. -/
theorem version_at_0 (h : Bitcoin.Chain.BlockHeader) :
    (encHeaderL h).take 4 = encU32L h.version.toUInt32 := by
  rw [headerFlat]
  exact take_head (encU32L_length _)

/-- Byte map @4..36: `hashPrevBlock` raw (internal byte order). -/
theorem prevhash_at_4 (h : Bitcoin.Chain.BlockHeader)
    (hp : h.hashPrevBlock.size = 32) :
    ((encHeaderL h).drop 4).take 32 = bL h.hashPrevBlock := by
  rw [headerFlat, drop_gt (encU32L_length _) (show (4 : Nat) ≤ 4 by omega)]
  exact take_head (len32 hp)

/-- Byte map @36..68: `hashMerkleRoot` raw (internal byte order). -/
theorem merkleroot_at_36 (h : Bitcoin.Chain.BlockHeader)
    (hp : h.hashPrevBlock.size = 32) (hm : h.hashMerkleRoot.size = 32) :
    ((encHeaderL h).drop 36).take 32 = bL h.hashMerkleRoot := by
  rw [headerFlat, drop_gt (encU32L_length _) (show (4 : Nat) ≤ 36 by omega),
    drop_gt (len32 hp) (show (32 : Nat) ≤ 36 - 4 by omega),
    show (36 : Nat) - 4 - 32 = 0 by omega, List.drop_zero]
  exact take_head (len32 hm)

/-- Byte map @68..72: `nTime` little-endian. -/
theorem time_at_68 (h : Bitcoin.Chain.BlockHeader)
    (hp : h.hashPrevBlock.size = 32) (hm : h.hashMerkleRoot.size = 32) :
    ((encHeaderL h).drop 68).take 4 = encU32L h.time := by
  rw [headerFlat, drop_gt (encU32L_length _) (show (4 : Nat) ≤ 68 by omega),
    drop_gt (len32 hp) (show (32 : Nat) ≤ 68 - 4 by omega),
    drop_gt (len32 hm) (show (32 : Nat) ≤ 68 - 4 - 32 by omega),
    show (68 : Nat) - 4 - 32 - 32 = 0 by omega, List.drop_zero]
  exact take_head (encU32L_length _)

/-- Byte map @72..76: `nBits` little-endian. -/
theorem bits_at_72 (h : Bitcoin.Chain.BlockHeader)
    (hp : h.hashPrevBlock.size = 32) (hm : h.hashMerkleRoot.size = 32) :
    ((encHeaderL h).drop 72).take 4 = encU32L h.bits := by
  rw [headerFlat, drop_gt (encU32L_length _) (show (4 : Nat) ≤ 72 by omega),
    drop_gt (len32 hp) (show (32 : Nat) ≤ 72 - 4 by omega),
    drop_gt (len32 hm) (show (32 : Nat) ≤ 72 - 4 - 32 by omega),
    drop_gt (encU32L_length h.time) (show (4 : Nat) ≤ 72 - 4 - 32 - 32 by omega),
    show (72 : Nat) - 4 - 32 - 32 - 4 = 0 by omega, List.drop_zero]
  exact take_head (encU32L_length _)

/-- Byte map @76..80: `nNonce` little-endian — the tail of the 80. -/
theorem nonce_at_76 (h : Bitcoin.Chain.BlockHeader)
    (hp : h.hashPrevBlock.size = 32) (hm : h.hashMerkleRoot.size = 32) :
    (encHeaderL h).drop 76 = encU32L h.nonce := by
  rw [headerFlat, drop_gt (encU32L_length _) (show (4 : Nat) ≤ 76 by omega),
    drop_gt (len32 hp) (show (32 : Nat) ≤ 76 - 4 by omega),
    drop_gt (len32 hm) (show (32 : Nat) ≤ 76 - 4 - 32 by omega),
    drop_gt (encU32L_length h.time) (show (4 : Nat) ≤ 76 - 4 - 32 - 32 by omega),
    drop_gt (encU32L_length h.bits)
      (show (4 : Nat) ≤ 76 - 4 - 32 - 32 - 4 by omega),
    show (76 : Nat) - 4 - 32 - 32 - 4 - 4 = 0 by omega, List.drop_zero]

/-- The header wire form is exactly 80 bytes (BLK-001 framing). -/
theorem headerLen (h : Bitcoin.Chain.BlockHeader)
    (hp : h.hashPrevBlock.size = 32) (hm : h.hashMerkleRoot.size = 32) :
    (encHeaderL h).length = 80 := by
  rw [headerFlat]
  simp [encU32L_length, bL_length, hp, hm]

/-! ## 3. `headerHash` = sha256d of the 80-byte wire form (BLK-003) -/

/-- **BLK-003 composition**: the block hash is double-SHA256 of the
80-byte wire form — `headerHash` routes through
`encodeBlockHeader = bytesOfList ∘ encHeaderL`. -/
theorem headerHash_dsha (h : Bitcoin.Chain.BlockHeader) :
    headerHash h = sha256d (bytesOfList (encHeaderL h)) := rfl

/-- The block hash is always 32 bytes (digest-size contract, B5). -/
theorem headerHash_size (h : Bitcoin.Chain.BlockHeader) :
    (headerHash h).size = 32 := by
  rw [headerHash_dsha]
  exact sha256d_size _

/-- `headerHash` depends only on the 80-byte wire form. -/
theorem headerHash_congr {h h' : Bitcoin.Chain.BlockHeader}
    (he : encHeaderL h = encHeaderL h') : headerHash h = headerHash h' := by
  rw [headerHash_dsha, headerHash_dsha, he]

/-! ## 4. CompactSize header-count framing (BLK-002) -/

/-- The tx count's CompactSize starts exactly at offset 80, i.e. the
header frame is self-delimiting (`CBlock` wire: header ‖ varint(txcount)). -/
theorem count_at_80 (h : Bitcoin.Chain.BlockHeader) (k : Nat) (rest : Bytes)
    (hp : h.hashPrevBlock.size = 32) (hm : h.hashMerkleRoot.size = 32) :
    (encHeaderL h ++ encCSL k ++ rest).drop 80 = encCSL k ++ rest := by
  rw [List.append_assoc,
    drop_gt (headerLen h hp hm) (show (80 : Nat) ≤ 80 by omega),
    Nat.sub_self, List.drop_zero]

/-- Block-body framing: `encBlockL h txs = header ‖ cs(‖txs‖) ‖ txs`, and
the tx-count field begins at byte 80. -/
theorem block_count_at_80 (h : Bitcoin.Chain.BlockHeader) (txs : List Tx)
    (hp : h.hashPrevBlock.size = 32) (hm : h.hashMerkleRoot.size = 32) :
    (encBlockL h txs).drop 80 = encCSL txs.length ++ txs.flatMap encTxL := by
  unfold encBlockL
  rw [List.append_assoc,
    drop_gt (headerLen h hp hm) (show (80 : Nat) ≤ 80 by omega),
    Nat.sub_self, List.drop_zero]

/-- Two-stage frame decode: on `header ‖ cs(k) ‖ rest` the header stage
consumes exactly the 80 header bytes and the count stage reads `k`
(canonical CompactSize, `k ≤ MAX_SIZE`). -/
theorem frame_two_stage (h : Bitcoin.Chain.BlockHeader) (k : Nat) (rest : Bytes)
    (hp : h.hashPrevBlock.size = 32) (hm : h.hashMerkleRoot.size = 32)
    (hk : k ≤ Bitcoin.Serialization.MAX_SIZE) :
    Except.bind (decHeaderL (encHeaderL h ++ (encCSL k ++ rest)))
      (fun (_, r) => decCS r) = .ok (k, rest) := by
  rw [decHeaderL_enc h (encCSL k ++ rest) hp hm]
  simp only
  exact decCS_encCSL k hk rest

/-! ## 5. Genesis pins (python-cross-checked byte-for-byte) -/

/-- The mainnet genesis 80-byte wire form (`crosscheck.py`;
display hash `000000000019d668…ce26f` verified there via hashlib). -/
def genesisWire : Bytes :=
  [0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
   0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
   0x00,0x00,0x00,0x00,0x3b,0xa3,0xed,0xfd,0x7a,0x7b,0x12,0xb2,0x7a,0xc7,0x2c,0x3e,
   0x67,0x76,0x8f,0x61,0x7f,0xc8,0x1b,0xc3,0x88,0x8a,0x51,0x32,0x3a,0x9f,0xb8,0xaa,
   0x4b,0x1e,0x5e,0x4a,0x29,0xab,0x5f,0x49,0xff,0xff,0x00,0x1d,0x1d,0xac,0x2b,0x7c]

theorem genesis_wire_len : genesisWire.length = 80 := rfl

/-- **BLK-111**: `Params.genesisHeader` serializes to the canonical
genesis wire bytes, field by field. -/
theorem genesis_wire : encHeaderL Bitcoin.Block.Params.genesisHeader = genesisWire := rfl

theorem genesis_prev_size :
    Bitcoin.Block.Params.genesisHeader.hashPrevBlock.size = 32 := by
  simp only [Bitcoin.Block.Params.genesisHeader, Bitcoin.Data.zeroBytes,
    foldl_push_size]
  simp

theorem genesis_merkle_size :
    Bitcoin.Block.Params.genesisHeader.hashMerkleRoot.size = 32 := by
  simp [Bitcoin.Block.Params.genesisHeader, Bitcoin.Block.Params.genesisMerkleRootInternal,
    Bitcoin.Block.Params.bytesOf]

/-- The genesis frame decodes: header stage eats all 80 wire bytes. -/
theorem genesis_frame (rest : Bytes) :
    decHeaderL (genesisWire ++ rest)
      = .ok (Bitcoin.Block.Params.genesisHeader, rest) := by
  have h := decHeaderL_enc Bitcoin.Block.Params.genesisHeader rest
    genesis_prev_size genesis_merkle_size
  rwa [genesis_wire] at h

/-- Genesis `nVersion` little-endian: `01 00 00 00` (python: enc_u32l(1)). -/
theorem genesis_version_LE :
    genesisWire.take 4 = [0x01, 0x00, 0x00, 0x00] := by
  rw [← genesis_wire, version_at_0]
  rfl

/-- Genesis `nBits` little-endian: `ff ff 00 1d` = 0x1d00ffff difficulty-1
(python: enc_u32l(0x1d00ffff)). -/
theorem genesis_bits_LE :
    (genesisWire.drop 72).take 4 = [0xff, 0xff, 0x00, 0x1d] := by
  rw [← genesis_wire,
    bits_at_72 Bitcoin.Block.Params.genesisHeader genesis_prev_size genesis_merkle_size]
  rfl

/-- Genesis `nNonce` little-endian: `1d ac 2b 7c` = 2083236893
(python: enc_u32l(2083236893)). -/
theorem genesis_nonce_LE :
    genesisWire.drop 76 = [0x1d, 0xac, 0x2b, 0x7c] := by
  rw [← genesis_wire,
    nonce_at_76 Bitcoin.Block.Params.genesisHeader genesis_prev_size genesis_merkle_size]
  rfl

end BitcoinProofs.Theorems.Layout.S02
