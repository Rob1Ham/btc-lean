import Bitcoin.Data.Basic

/-!
# Bitcoin.Chain.Basic

Block-header shape and the compact-bits → PoW-target expansion.
Ground truth: `src/primitives/block.h` (`CBlockHeader`) and
`src/arith_uint256.cpp` (`arith_uint256::SetCompact`, mirrored by
`src/consensus/pow.cpp` users). Full block validation is workstream B4.
-/


namespace Bitcoin.Chain

open Bitcoin.Data

structure BlockHeader where
  version : Int32
  hashPrevBlock : ByteArray    -- 32 bytes
  hashMerkleRoot : ByteArray   -- 32 bytes
  time : UInt32
  bits : UInt32                -- nBits: compact difficulty encoding
  nonce : UInt32
deriving Repr

/-- `arith_uint256::SetCompact` (negative/floating part elided; consensus
targets always have the sign bit clear and use the magnitude). -/
def compactTarget (bits : UInt32) : Nat :=
  let size := ((bits >>> 24).toUInt8).toNat
  let word := (bits &&& 0x007fffff).toNat   -- shift in Nat: targets exceed 32 bits
  if size ≤ 3 then word >>> (8 * (3 - size))
  else word <<< (8 * (size - 3))

/-- Testnet/mainnet difficulty-1 target: nBits = 0x1d00ffff. -/
theorem compactTarget_difficulty_one :
    compactTarget 0x1d00ffff = 0xffff * 256 ^ (0x1d - 3) := by
  rfl

end Bitcoin.Chain
