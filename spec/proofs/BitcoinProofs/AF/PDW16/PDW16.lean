import Bitcoin.Chain.Basic
import Bitcoin.Capstone.Pow
import Bitcoin.Block.Params

/-! # PDW16.lean

Five sorry-free promotion theorems, one per claimed rules.yaml row
(claim v1 = evidence bank 11e3d0d):

* **BLK-037** `powLimit` (Capstone/Pow.lean:45) →
  `compactTarget_eq` (SetCompact magnitude def-mirror) +
  `compactTarget_zero` (zero-bits reject).
* **BLK-038** `targetOk` (Capstone/Pow.lean:48) →
  `targetOk_eq` (P12 bounds-iff gate-pin) + `powLimit_eq` +
  `targetOk_difficulty_one` (0x1d00ffff accept) +
  `targetOk_high_bits_reject` (0x1e00ffff) + `targetOk_zero_reject`.
* **BLK-082** `testnet4Testdummy`/`regtestTestdummy`
  (Block/Params.lean:107/115) → `testnet4_testdummy_table` +
  `regtestTestdummy_table` (CP:371-377/649-655 pins) +
  `testdummy_ratio` (both-75%).
* **BLK-112** `genesisCoinbaseTx` (Block/Params.lean:231) →
  `genesisCoinbaseTx_coinbase` (null-prevout one-in-one-out) +
  `genesisCoinbaseTx_value` (50 COIN) + `genesisScriptPubKey_p2pk`.
* **BLK-130** `TIMESTAMP_WINDOW` (Block/Params.lean:467) →
  `timestamp_window_eq_max_future` (CH:29-37 same-constant pin) +
  `max_future_block_time_eq_7200`.

BLK-037/BLK-038 are now wired to the live model: the core
`Bitcoin.Capstone.Pow` module carries the full `SetCompact` flag model
(`setCompactFull`), `targetOk` applies the full four-bound gate
(`fNegative`, `fOverflow`, nonzero, ≤ powLimit), and
`Bitcoin.Capstone.Block.CheckProofOfWork` consumes that `targetOk`.
The proofs below retain the flag laws and add
`targetOk_eq_targetOkFull`, so `targetOkFull` is no longer a
proof-local residual but is propositionally the live gate.
BLK-112's scriptSig push-law (nBits 486604799 + Times headline) =
`genesisScriptSig` byte-slices pinned via size-laws (X08 B6),
not re-proved here (Params.lean internal).
Route B (PDW11/PDW12/PDW15 pattern): zero core writes, tags
`@[rule "row"]` ride these theorems (Capstone/Pow.lean:45 carries
both BLK-037/038 tags on powLimit = F-PD02-002 tag/target
split-repair); module deliberately NOT imported by the
`BitcoinProofs` root (LedgerCor-13 RED crown-debt, PDW12-isolation
pattern) — own-target built, outside `core/**` (sorry_lint scans
core only). Probe = PDW16/p1.lean + p1_2.lean (30 examples, RC=0).
-/

namespace BitcoinProofs.AF.PDW16

open Bitcoin.Chain Bitcoin.Capstone.Pow Bitcoin.Block.Params Bitcoin.Data

/-! ## BLK-130 — `TIMESTAMP_WINDOW` = `MAX_FUTURE_BLOCK_TIME`
(kernel/chainparams.cpp:29-37 @cce32b168: the same 7200s constant
defines the headers-sync `TIMESTAMP_WINDOW`). -/

@[rule "BLK-130"]
theorem timestamp_window_eq_max_future :
    TIMESTAMP_WINDOW = MAX_FUTURE_BLOCK_TIME := rfl

theorem max_future_block_time_eq_7200 :
    MAX_FUTURE_BLOCK_TIME = 7200 := rfl

/-- The window pin composed: `TIMESTAMP_WINDOW = 7200`. -/
theorem timestamp_window_eq_7200 :
    TIMESTAMP_WINDOW = 7200 := rfl

/-! ## BLK-082 — deployment tables (other nets)
(kernel/chainparams.cpp:371-377/649-655 @cce32b168):
testnet4 testdummy 1512/2016 NEVER_ACTIVE (dormant); regtest
testdummy 108/144 start 0 (active from genesis). Both thresholds =
75% of their periods. -/

@[rule "BLK-082"]
theorem testnet4_testdummy_table :
    testnet4Testdummy.bit = 28 ∧ testnet4Testdummy.start = 4294967294 ∧
    testnet4Testdummy.timeout = 4294967295 ∧
    testnet4Testdummy.minActivation = 0 ∧
    testnet4Testdummy.threshold = 1512 ∧
    testnet4Testdummy.period = 2016 := by decide

@[rule "BLK-082"]
theorem regtest_testdummy_table :
    regtestTestdummy.bit = 28 ∧ regtestTestdummy.start = 0 ∧
    regtestTestdummy.timeout = 4294967295 ∧
    regtestTestdummy.minActivation = 0 ∧
    regtestTestdummy.threshold = 108 ∧
    regtestTestdummy.period = 144 := by decide

/-- Both non-mainnet testdummy thresholds = 75% of period
(the CP:371-377/649-655 3-in-4 ratio). -/
theorem testdummy_ratio :
    testnet4Testdummy.threshold * 4 = 3 * testnet4Testdummy.period ∧
    regtestTestdummy.threshold * 4 = 3 * regtestTestdummy.period := by
  constructor <;> decide

/-! ## BLK-037 — SetCompact magnitude decode, def-mirror
(consensus AmountToRange... arith_uint256 SetCompact:176-194
@cce32b168): `compactTarget bits` = the magnitude law
`(mantissa &&& 0x007fffff) >>> 8*(3-exp)` (exp ≤ 3) /
`<<< 8*(exp-3)` (exp > 3), where `exp = (bits >>> 24).toUInt8`.
The spec model (Bitcoin/Chain/Basic.lean) is magnitude-only
(CheckProofWorks... `CheckProofOfWork` reads `nBits → arith nBits.GetCompact...`); **honest gap**: the spec discards
SetCompact's sign-bit (c = 0x00800000 reject) and > 32-bit-shift
overflow laws (SetCompact:176-194) — the model decodes every
`bits` to a magnitude (SetCompact drops... matches BLK-038's
`CheckRangeFor... DeriveTarget`:**... = weaker honest variant
(one-level... elided = F-PD16 tag/honest-note). -/
@[rule "BLK-037"]
theorem compactTarget_eq (bits : UInt32) : compactTarget bits =
    (if ((bits >>> 24).toUInt8).toNat ≤ 3
     then (bits &&& 0x007fffff).toNat >>> (8 * (3 - ((bits >>> 24).toUInt8).toNat))
     else (bits &&& 0x007fffff).toNat <<< (8 * (((bits >>> 24).toUInt8).toNat - 3))) := rfl

/-- Zero bits decode to target 0 (SetCompact exp-0... c=0). -/
theorem compactTarget_zero : compactTarget (0 : UInt32) = 0 := by rfl

/-! ### BLK-037 full `SetCompact` model (sign + overflow arms)

The full model now lives in the live core module
`Bitcoin.Capstone.Pow` (`setCompactExp`, `setCompactMantissa`,
`setCompactWord`, `SetCompactResult`, `setCompactFull`), where
`targetOk` consumes it.  The theorems below remain the PDW16 row-face
links: the magnitude/shift law, the sign/overflow flag laws, and the
identity between the live magnitude decoder and the full target. -/

/-- **BLK-037**: the full `SetCompact` law — magnitude shift, nonzero-word
sign-bit validity, and the three overflow clauses. -/
@[rule "BLK-037"]
theorem setCompactFull_spec (bits : UInt32) :
    (setCompactFull bits).target =
      (if setCompactExp bits ≤ 3
       then setCompactMantissa bits >>> (8 * (3 - setCompactExp bits))
       else setCompactMantissa bits <<< (8 * (setCompactExp bits - 3))) ∧
    ((setCompactFull bits).negative = true ↔
      setCompactWord bits ≠ 0 ∧ (bits &&& 0x00800000) ≠ 0) ∧
    ((setCompactFull bits).overflow = true ↔
      setCompactMantissa bits ≠ 0 ∧
        (34 < setCompactExp bits ∨
         (0xff < setCompactMantissa bits ∧ 33 < setCompactExp bits) ∨
         (0xffff < setCompactMantissa bits ∧ 32 < setCompactExp bits))) := by
  unfold setCompactFull setCompactWord
  by_cases h : setCompactExp bits ≤ 3 <;> simp [h]

/-- **BLK-037**: the live magnitude decoder is exactly the `target`
component of the full `SetCompact` result.  This is the missing link
between `setCompactFull_spec` and `Bitcoin.Chain.compactTarget`: the
shift law is shared; only the two rejection flags are extra. -/
@[rule "BLK-037"]
theorem compactTarget_eq_setCompactFull_target (bits : UInt32) :
    compactTarget bits = (setCompactFull bits).target := by
  unfold compactTarget setCompactFull setCompactWord setCompactExp
    setCompactMantissa
  by_cases h : bits.toNat >>> 24 % 256 ≤ 3 <;> simp [h]

/-- **BLK-037** sign witness: `0x03800123` has a nonzero word and the
`0x00800000` bit set, so `SetCompact` reports `fNegative`; its decoded
magnitude is the small value `0x123`, not an overflow. -/
@[rule "BLK-037"]
theorem setCompactFull_sign_witness :
    (setCompactFull 0x03800123).negative = true ∧
    (setCompactFull 0x03800123).overflow = false ∧
    (setCompactFull 0x03800123).target = 0x123 := by
  decide

/-- **BLK-037** live-decoder witness: `compactTarget` masks the sign bit
away, so `0x03800123` (fNegative) and `0x03000123` (sign clear) decode to
the same magnitude.  The flag is applied by `targetOk` (which rejects the
former) and is exposed by `setCompactFull`. -/
@[rule "BLK-037"]
theorem compactTarget_sign_bit_witness :
    compactTarget 0x03800123 = compactTarget 0x03000123 := by decide

/-! ## BLK-038 — PoW target bounds gate
(pow.cpp DeriveTarget... CheckProofOfWork:146-159 @cce32b168):
the live `targetOk` rejects `fNegative`, `fOverflow`, target 0, and
target > powLimit.  The proofs below state the same four-bound gate
through `targetOkFull` and link it to the live predicate. -/

/-- `powLimit` = 0x00000000FFFF0000…FF = 0xffff·256²⁶
(chainparams.cpp:109, the 268-... 2¹⁰·... difficulty-1 target). -/
theorem powLimit_eq : powLimit = 2 ^ 224 - 1 := by decide

@[rule "BLK-038"]
theorem targetOk_eq (bits : UInt32) : targetOk bits = true ↔
    (setCompactFull bits).negative = false ∧
    (setCompactFull bits).overflow = false ∧
    0 < compactTarget bits ∧
    compactTarget bits ≤ powLimit :=
  Bitcoin.Capstone.Pow.targetOk_eq bits

/-- The difficulty-1 compact form 0x1d00ffff passes (genesis
bits, Params.lean:208... `genesis_pow_difficulty_one`). -/
theorem targetOk_difficulty_one : targetOk 0x1d00ffff = true := by decide

/-- 0x1e00ffff (powLimit... target = 2·powLimit) fails the ≤
powLimit bound = the high-bits reject. -/
theorem targetOk_high_bits_reject : targetOk 0x1e00ffff = false := by decide

/-- Zero bits (target 0) fails the nonzero bound. -/
theorem targetOk_zero_reject : targetOk (0 : UInt32) = false := by decide

/-- **BLK-038**: `DeriveTarget`'s four-target-bounds gate over the FULL
`SetCompact` decode: reject the negative arm, reject the overflow arm,
reject zero, and reject above `powLimit` (pow.cpp:146-159 @cce32b168). -/
@[rule "BLK-038"]
def targetOkFull (bits : UInt32) : Bool :=
  let r := setCompactFull bits
  !r.negative && !r.overflow && 0 < r.target && r.target ≤ powLimit

/-- **BLK-038**: the proof-local four-bound gate is propositionally the
LIVE `Bitcoin.Capstone.Pow.targetOk`; there is no residual gap. -/
@[rule "BLK-038"]
theorem targetOk_eq_targetOkFull (bits : UInt32) :
    targetOk bits = targetOkFull bits := by
  unfold targetOk targetOkFull
  rw [compactTarget_eq_setCompactFull_target]

/-- The gate as an iff, with the sign and overflow arms explicit. -/
@[rule "BLK-038"]
theorem targetOkFull_iff (bits : UInt32) :
    targetOkFull bits = true ↔
      (setCompactFull bits).negative = false ∧
      (setCompactFull bits).overflow = false ∧
      0 < (setCompactFull bits).target ∧
      (setCompactFull bits).target ≤ powLimit := by
  unfold targetOkFull
  simp [Bool.and_eq_true, and_assoc]

/-- **BLK-038**: an accepted full decode is non-overflowing, not
negative, nonzero, and at most `powLimit`.  (The old `0 ≤ target`
conjunct was vacuous: `target : Nat`.) -/
@[rule "BLK-038"]
theorem targetOkFull_spec (bits : UInt32) (h : targetOkFull bits = true) :
    (setCompactFull bits).negative = false ∧
    (setCompactFull bits).overflow = false ∧
    (setCompactFull bits).target ≠ 0 ∧
    (setCompactFull bits).target ≤ powLimit := by
  obtain ⟨hneg, hov, hpos, hle⟩ := (targetOkFull_iff bits).mp h
  exact ⟨hneg, hov, Nat.ne_of_gt hpos, hle⟩

/-- **BLK-038**: the full gate rejects every negative decode
(`fNegative`, arith_uint256.cpp:188 / pow.cpp:155). -/
@[rule "BLK-038"]
theorem targetOkFull_negative_reject (bits : UInt32)
    (h : (setCompactFull bits).negative = true) : targetOkFull bits = false := by
  unfold targetOkFull
  simp [h]

/-- **BLK-038**: the full gate rejects every overflow decode
(`fOverflow`, arith_uint256.cpp:190-192 / pow.cpp:155). -/
@[rule "BLK-038"]
theorem targetOkFull_overflow_reject (bits : UInt32)
    (h : (setCompactFull bits).overflow = true) : targetOkFull bits = false := by
  unfold targetOkFull
  simp [h]

/-- **BLK-038** live-gate witness: both the full four-bound gate and the
live `targetOk` reject the sign-bit compact encoding `0x03800123`
(F-Z11-003 closed; Core pow.cpp:155 `fNegative` arm). -/
@[rule "BLK-038"]
theorem targetOk_full_vs_live_sign_witness :
    targetOkFull 0x03800123 = false ∧ targetOk 0x03800123 = false := by
  decide

/-! ## BLK-112 — the genesis output script
(kernel/chainparams.cpp:66-67 @cce32b168): P2PK to the never-spent
pubkey `04678afd…b6bf11d5f` (65B, OP_PUSH65 0x41 + pubkey +
OP_CHECKSIG 0xac), 50 COIN. **Honest gap**: the scriptSig
push-law (nBits 486604799 + 69B Times headline) = X08 B6
`genesisScriptSig`-internal size-pins (Params.lean:258), not
re-proved here. -/

@[rule "BLK-112"]
theorem genesisCoinbaseTx_coinbase :
    genesisCoinbaseTx.vin.length = 1 ∧
    genesisCoinbaseTx.vin = [TxIn.mk OutPoint.null ⟨genesisScriptSig⟩ 0xFFFFFFFF] ∧
    genesisCoinbaseTx.isCoinBase = true := ⟨rfl, rfl, by decide⟩

theorem genesisCoinbaseTx_value :
    genesisCoinbaseTx.vout.length = 1 ∧
    genesisCoinbaseTx.vout = [TxOut.mk (50 * COIN) ⟨genesisScriptPubKey⟩] := ⟨rfl, rfl⟩

theorem genesisScriptPubKey_p2pk :
    genesisScriptPubKey = bytesOf [0x41] ++ genesisPubkey
    ++ bytesOf [0xac] := rfl

/-- **BLK-112**: the genesis output in full — exactly one output paying
`50·COIN`, whose script is the 67-byte P2PK template
`0x41 <04678afd…b6bf11d5f> 0xac`, with the 65-byte pubkey pinned
byte-for-byte (kernel/chainparams.cpp:66-67 @cce32b168). -/
@[rule "BLK-112"]
theorem genesisCoinbaseTx_p2pk_50 :
    genesisCoinbaseTx.vout.length = 1 ∧
    genesisCoinbaseTx.vout =
      [TxOut.mk (50 * COIN) ⟨genesisScriptPubKey⟩] ∧
    genesisScriptPubKey = bytesOf [0x41] ++ genesisPubkey
      ++ bytesOf [0xac] ∧
    genesisPubkey = bytesOf
      [0x04,0x67,0x8a,0xfd,0xb0,0xfe,0x55,0x48,0x27,0x19,0x67,0xf1,0xa6,0x71,0x30,0xb7,
       0x10,0x5c,0xd6,0xa8,0x28,0xe0,0x39,0x09,0xa6,0x79,0x62,0xe0,0xea,0x1f,0x61,0xde,
       0xb6,0x49,0xf6,0xbc,0x3f,0x4c,0xef,0x38,0xc4,0xf3,0x55,0x04,0xe5,0x1e,0xc1,0x12,
       0xde,0x5c,0x38,0x4d,0xf7,0xba,0x0b,0x8d,0x57,0x8a,0x4c,0x70,0x2b,0x6b,0xf1,0x1d,0x5f] := by
  exact ⟨rfl, rfl, rfl, rfl⟩
