import Bitcoin.Block.Pow
import Bitcoin.Chain.Basic
import Bitcoin.Crypto.Seam.Hash
import Bitcoin.Serialization.Interface

/-!
# Bitcoin.Capstone.Pow — header hash + proof-of-work (S2b)

Pure, small, consensus-exact:

* `headerHash h` — **BLK-003**: `SHA256d(80-byte header)`, interpreted
  little-endian (Core `GetHash` / `arith_uint256(uint256)`).
* `compactTarget bits` — **BLK-037**: `arith_uint256::SetCompact`'s
  magnitude, already ported in `Bitcoin.Chain.compactTarget`; here the
  full `SetCompact` result (magnitude + `fNegative` + `fOverflow`) is
  `setCompactFull`, and `compactTarget_eq_setCompactFull_target` links
  the live magnitude to it.
* `targetOk` — **BLK-037/BLK-038**: `CheckProofOfWork`'s decode gate —
  `!fNegative && !fOverflow && target ≠ 0 && target ≤ powLimit`
  (pow.cpp:146-159 @cce32b168).  Negative and overflowing compact
  encodings are rejected exactly as Core's `SetCompact` flags require.
* `powOk h` — **BLK-039**: `SHA256d(header)` as a little-endian integer
  `≤` target (`hash ≤ target`, "high-hash" reject otherwise).

`hashNatLE` reads the 32 digest bytes least-significant first — Core's
`uint256` little-endian interpretation, which is what makes the display
form of a block hash the byte-REVERSED digest.
-/

namespace Bitcoin.Capstone.Pow

open Bitcoin.Chain Bitcoin.Crypto.Seam.Hash Bitcoin.Serialization

/-- **BLK-003**: the block hash — SHA256d of the 80-byte header. -/
@[rule "BLK-003"]
def headerHash (h : BlockHeader) : ByteArray :=
  Bitcoin.Crypto.Seam.Hash.sha256d (encodeBlockHeader h)

/-- Little-endian byte string → Nat (Core's uint256 LE interpretation). -/
def hashNatLE (b : ByteArray) : Nat :=
  (List.range b.size).foldl (fun acc i =>
    acc + (b.get! i).toNat * 256 ^ i) 0

/-- **BLK-037+BLK-038**: `CheckProofOfWork`'s target decode gate —
magnitude decode (Bitcoin.Chain.compactTarget), nonzero, ≤ powLimit
(mainnet `powLimit` = 2^224 − 1, chainparams.cpp:126 @cce32b168). -/
@[rule "BLK-037", rule "BLK-038"]
def powLimit : Nat := Bitcoin.Block.Pow.powLimitMainnet

/-- Share the exact chain parameter used by the retarget machinery. -/
theorem powLimit_eq_mainnet : powLimit = Bitcoin.Block.Pow.powLimitMainnet := rfl

/-! ## Full `SetCompact` result (`fNegative`, `fOverflow`)

`arith_uint256::SetCompact` (arith_uint256.cpp:176-194 @cce32b168)
returns the magnitude plus two rejection flags.  The live decoder
`Bitcoin.Chain.compactTarget` keeps only the magnitude; the definitions
below supply the flags so `targetOk` can apply Core's full gate. -/

/-- `nSize` — the compact encoding's exponent byte. -/
def setCompactExp (bits : UInt32) : Nat := ((bits >>> 24).toUInt8).toNat

/-- `nWord` before the right-shift branch (`nCompact & 0x007fffff`). -/
def setCompactMantissa (bits : UInt32) : Nat := (bits &&& 0x007fffff).toNat

/-- `nWord` after Core's `nSize ≤ 3` right-shift — the value used by the
sign/overflow tests. -/
def setCompactWord (bits : UInt32) : Nat :=
  let exp := setCompactExp bits
  if exp ≤ 3 then setCompactMantissa bits >>> (8 * (3 - exp))
  else setCompactMantissa bits

/-- The three visible outputs of `SetCompact`: decoded magnitude, the
`pfNegative` flag, and the `pfOverflow` flag. -/
structure SetCompactResult where
  target : Nat
  negative : Bool
  overflow : Bool
deriving Repr, DecidableEq

/-- `arith_uint256::SetCompact` (arith_uint256.cpp:176-194 @cce32b168),
faithful to Core's flag computations.  The magnitude is `nWord` shifted
left by `8·(exp−3)` when `exp > 3`; the sign flag is set only for a
nonzero `nWord` with bit `0x00800000`; overflow is the BIP-pinned
`exp > 34 ∨ (m > 0xff ∧ exp > 33) ∨ (m > 0xffff ∧ exp > 32)` arm.  In
that arm `exp > 32`, hence `nWord = m`, so the mantissa formula is exact. -/
@[rule "BLK-037"]
def setCompactFull (bits : UInt32) : SetCompactResult :=
  let exp := setCompactExp bits
  let m := setCompactMantissa bits
  let word := setCompactWord bits
  { target := if exp ≤ 3 then word else word <<< (8 * (exp - 3))
    negative := decide (word ≠ 0 ∧ (bits &&& 0x00800000) ≠ 0)
    overflow := decide (m ≠ 0 ∧
      (34 < exp ∨ (0xff < m ∧ 33 < exp) ∨ (0xffff < m ∧ 32 < exp))) }

/-- **BLK-037**: the live magnitude decoder is exactly the `target`
component of the full `SetCompact` result. -/
@[rule "BLK-037"]
theorem compactTarget_eq_setCompactFull_target (bits : UInt32) :
    compactTarget bits = (setCompactFull bits).target := by
  unfold compactTarget setCompactFull setCompactWord setCompactExp
    setCompactMantissa
  by_cases h : bits.toNat >>> 24 % 256 ≤ 3 <;> simp [h]

/-- **BLK-037+BLK-038**: `CheckProofOfWork`'s decode gate over the full
`SetCompact` result.  The magnitude bound is retained; the negative and
overflow arms are Core's `fNegative`/`fOverflow` rejects
(pow.cpp:146-159 @cce32b168). -/
@[rule "BLK-037", rule "BLK-038"]
def targetOk (bits : UInt32) : Bool :=
  let r := setCompactFull bits
  !r.negative && !r.overflow &&
    0 < compactTarget bits && compactTarget bits ≤ powLimit

/-- **BLK-038**: the live gate accepted iff the decoded target is
nonzero and at most `powLimit`, and neither `SetCompact` rejection flag
(`fNegative`, `fOverflow`) is set. -/
@[rule "BLK-038"]
theorem targetOk_eq (bits : UInt32) :
    targetOk bits = true ↔
      (setCompactFull bits).negative = false ∧
      (setCompactFull bits).overflow = false ∧
      0 < compactTarget bits ∧
      compactTarget bits ≤ powLimit := by
  unfold targetOk
  simp [Bool.and_eq_true, and_assoc, and_left_comm, and_comm]

/-- **BLK-038**: the full four-bound gate, expressed over the `SetCompact`
target itself. -/
@[rule "BLK-037", rule "BLK-038"]
theorem targetOk_iff_full (bits : UInt32) :
    targetOk bits = true ↔
      (setCompactFull bits).negative = false ∧
      (setCompactFull bits).overflow = false ∧
      0 < (setCompactFull bits).target ∧
      (setCompactFull bits).target ≤ powLimit := by
  rw [targetOk_eq]
  rw [compactTarget_eq_setCompactFull_target]

/-- **BLK-038**: the live gate rejects every negative decode
(`fNegative`, arith_uint256.cpp:188 / pow.cpp:155). -/
@[rule "BLK-038"]
theorem targetOk_negative_reject (bits : UInt32)
    (h : (setCompactFull bits).negative = true) : targetOk bits = false := by
  unfold targetOk
  simp [h]

/-- **BLK-038**: the live gate rejects every overflow decode
(`fOverflow`, arith_uint256.cpp:190-192 / pow.cpp:155). -/
@[rule "BLK-038"]
theorem targetOk_overflow_reject (bits : UInt32)
    (h : (setCompactFull bits).overflow = true) : targetOk bits = false := by
  unfold targetOk
  simp [h]

/-- **BLK-038** live-gate witness: the sign-bit compact encoding
`0x03800123` (`word = 0x123 ≠ 0`, bit `0x00800000` set) is rejected by
the live gate exactly as Core rejects it at pow.cpp:155. -/
@[rule "BLK-038"]
theorem targetOk_negative_witness : targetOk 0x03800123 = false := by
  decide

/-- **BLK-037** sign witness: `0x03800123` has a nonzero word and the
`0x00800000` bit set, so `SetCompact` reports `fNegative`; its decoded
magnitude is the small value `0x123`, not an overflow. -/
@[rule "BLK-037"]
theorem setCompactFull_sign_witness :
    (setCompactFull 0x03800123).negative = true ∧
    (setCompactFull 0x03800123).overflow = false ∧
    (setCompactFull 0x03800123).target = 0x123 := by
  decide

/-- **BLK-039**: SHA256d(header) as LE integer ≤ target ("high-hash"). -/
@[rule "BLK-039"]
def powOk (h : BlockHeader) : Bool :=
  targetOk h.bits && hashNatLE (headerHash h) ≤ compactTarget h.bits

end Bitcoin.Capstone.Pow

-- R07c exact footprint guards.
/-- info: 'Bitcoin.Capstone.Pow.powLimit_eq_mainnet' does not depend on any axioms -/
#guard_msgs in #print axioms Bitcoin.Capstone.Pow.powLimit_eq_mainnet
