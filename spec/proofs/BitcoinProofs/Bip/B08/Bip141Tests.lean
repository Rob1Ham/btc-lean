/-
BitcoinProofs.Bip.B08.Bip141Tests — decisive BIP141 (SegWit) clause tests.

2026-10-16. Every expected value below was
computed in python3 (hashlib) against the
BIP141 text (public domain) / Core @ cce32b168. All checks are `decide`/
`rfl`-closed: sorry-free.

Mutation-thinking: each example is chosen so that mutating the modelled
clause flips the result (noted per-check).
-/

import Bitcoin.Numeric.Interface
import BitcoinProofs.Bip.B08.Bip141Defs

/- The 10,000-byte P2WSH pins below evaluate a `List` of that length in the
kernel; raise the recursion bound so `decide` can walk it (same convention as
the other byte-level audits in this tree). No statement is affected. -/
set_option maxRecDepth 100000

namespace BitcoinProofs.Bip.B08

open Bitcoin.Numeric (bytesFromLE castToBool)

/-! ## C3 — witness program grammar -/

-- `0014||20B` parses as version 0, 20-byte program (P2WPKH shape).
example : parseWitnessProgram ([0x00, 0x14] ++ List.replicate 20 1)
    = some (0, List.replicate 20 1) := by decide

-- `0020||32B` parses as version 0, 32-byte program (P2WSH shape).
example : parseWitnessProgram ([0x00, 0x20] ++ List.replicate 32 2)
    = some (0, List.replicate 32 2) := by decide

-- `0028||40B` IS a witness program (v0, 40B) — later clauses make it fail.
example : parseWitnessProgram ([0x00, 0x28] ++ List.replicate 40 7)
    = some (0, List.replicate 40 7) := by decide

-- `0029||41B` is NOT a witness program (BIP141 footnote: 41-byte push passes).
example : parseWitnessProgram ([0x00, 0x29] ++ List.replicate 41 7) = none := by decide

-- Mutation kill: 0x01 (OP_PUSHBYTES_1) is not a version byte.
example : parseWitnessProgram [0x01, 0x02, 0xAA, 0xBB] = none := by decide

-- L = 1 rejected; version byte span 0x00 / 0x51..0x60 pinned.
example : parseWitnessProgram [0x00, 0x01, 0xAA] = none := by decide
example : (isVersionByte 0x50 = false) ∧ (isVersionByte 0x51 = true)
    ∧ (isVersionByte 0x60 = true) ∧ (isVersionByte 0x61 = false) := by decide
example : versionOf 0x51 = 1 ∧ versionOf 0x60 = 16 ∧ versionOf 0x00 = 0 := by decide

-- Version 1 and 16 programs parse (reserved for future extensions).
example : parseWitnessProgram [0x51, 0x02, 0xAA, 0xBB] = some (1, [0xAA, 0xBB]) := by decide
example : parseWitnessProgram [0x60, 0x02, 1, 2] = some (16, [1, 2]) := by decide

theorem nonProgramVersionByte (vb l : Nat) (prog : List Nat)
    (h : ¬ isVersionByte vb) : parseWitnessProgram (vb :: l :: prog) = none := by
  have hb : isVersionByte vb = false := by
    cases hb : isVersionByte vb with
    | false => rfl
    | true => exact absurd hb h
  simp [parseWitnessProgram, hb]

/-! ## C8 — v0 size dispatch -/

example : dispatchProgram 0 (List.replicate 20 1) = .p2wpkh := by decide
example : dispatchProgram 0 (List.replicate 32 2) = .p2wsh := by decide
-- v0 with 40-byte program: witness program → script MUST fail.
example : dispatchProgram 0 (List.replicate 40 7) = .invalidV0Size := by decide
-- v0 with 2-byte program: also fails.
example : dispatchProgram 0 (List.replicate 2 7) = .invalidV0Size := by decide
-- v1 program of 40 bytes: future version, no interpretation.
example : dispatchProgram 1 (List.replicate 40 7) = .future 1 := by decide

theorem v0_bad_size_fails (prog : List Nat)
    (h20 : prog.length ≠ 20) (h32 : prog.length ≠ 32) :
    dispatchProgram 0 prog = .invalidV0Size := by
  simp [dispatchProgram, h20, h32]

/-! ## C9 — CastToBool and the witness-program verdict -/

-- Core's CastToBool (interpreter.cpp:46-59), pinned through the real
-- numeric model. Negative zero is false; a non-final 0x80 is true.
example : castToBool (bytesFromLE []) = false := by decide
example : castToBool (bytesFromLE [0x00]) = false := by decide
example : castToBool (bytesFromLE [0x00, 0x80]) = false := by decide
example : castToBool (bytesFromLE [0x80, 0x00]) = true := by decide
example : castToBool (bytesFromLE [0x00, 0x80, 0x00]) = true := by decide
example : castToBool (bytesFromLE [0x01]) = true := by decide

-- A witness program is not rejected for a zero-valued program: v0/20 is
-- a valid P2WPKH template and v0/32 is a valid P2WSH template.
example : dispatchProgram 0 (List.replicate 20 0) = .p2wpkh := by decide
example : dispatchProgram 0 (List.replicate 32 0) = .p2wsh := by decide
example : nativeWitnessOk ([0x00, 0x14] ++ List.replicate 20 0) [] = some .p2wpkh := by decide
example : nativeWitnessOk ([0x00, 0x20] ++ List.replicate 32 0) [] = some .p2wsh := by decide
-- Versions 1..16 are future programs: their bytes are not interpreted.
example : dispatchProgram 1 (List.replicate 2 0) = .future 1 := by decide
example : nativeWitnessOk [0x60, 0x02, 0, 0] [] = some (.future 16) := by decide

/-! ## C6 — P2WPKH witness stack shape -/

example : p2wpkhWitnessOk [[1, 2], List.replicate 33 9] = true := by decide
example : p2wpkhWitnessOk [[1, 2]] = false := by decide                        -- 1 item
example : p2wpkhWitnessOk [[1, 2], List.replicate 33 9, [3]] = false := by decide -- 3 items
example : p2wpkhWitnessOk [[1, 2], List.replicate 521 9] = false := by decide  -- >520B item

/-! ## C7 — P2WSH witnessScript size -/

example : p2wshScriptSizeOk (List.replicate 10000 1) = true := by decide
example : p2wshScriptSizeOk (List.replicate 10001 1) = false := by decide

/-! ## C4 — native witness program: scriptSig exactly empty -/

example : nativeScriptSigOk [] = true := by decide
example : nativeScriptSigOk [0x00] = false := by decide
example : nativeScriptSigOk [0x51] = false := by decide

-- Full native path: P2WPKH spk + empty scriptSig → p2wpkh.
example : nativeWitnessOk ([0x00, 0x14] ++ List.replicate 20 1) [] = some .p2wpkh := by decide
-- Mutation kill: any scriptSig byte fails a native witness program.
example : nativeWitnessOk ([0x00, 0x14] ++ List.replicate 20 1) [0x51] = none := by decide
-- Non-witness-version program is anyone-can-spend at v1 (no scriptSig rule).
example : nativeWitnessOk [0x51, 0x02, 0xAA, 0xBB] [] = some (.future 1) := by decide

/-! ## C5 — P2SH-wrapped witness: scriptSig exactly one push of redeem -/

def redeem22 : List Nat := [0x00, 0x14] ++ List.replicate 20 3   -- 0014||20B
def redeem34 : List Nat := [0x00, 0x20] ++ List.replicate 32 4   -- 0020||32B

example : redeem22.length = 22 ∧ redeem34.length = 34 := by decide
example : p2shWitnessOk redeem22 ([0x16] ++ redeem22) = some .p2wpkh := by decide
example : p2shWitnessOk redeem34 ([0x22] ++ redeem34) = some .p2wsh := by decide
-- Mutation kill: extra push after the redeem → two items, rejected.
example : p2shWitnessOk redeem22 ([0x16] ++ redeem22 ++ [0x51]) = none := by decide
-- Mutation kill: empty scriptSig rejected.
example : p2shWitnessOk redeem22 [] = none := by decide
-- Mutation kill: OP_DROP-prefixed scriptSig is not a push.
example : p2shWitnessOk redeem22 ([0x75, 0x16] ++ redeem22) = none := by decide
-- Wrong push length (0x15 instead of 0x16) is not a push of redeem22.
example : p2shWitnessOk redeem22 ([0x15] ++ redeem22) = none := by decide

/-! ## C1 — marker/flag framing + witness discipline -/

example : framingCheck 0 1 [[1, 2], [3]] = .ok := by decide
example : framingCheck 1 1 [[1]] = .badMarker := by decide                  -- marker MUST be 0x00
example : framingCheck 0 0 [[1]] = .badFlag := by decide                    -- flag MUST be non-zero
example : framingCheck 0 2 [[1]] = .badFlag := by decide                    -- TXV-016: flag ∉ {1}
example : framingCheck 0 1 [[], []] = .superfluousWitness := by decide      -- Core: superfluous witness record

-- Non-witness-program input must carry an empty witness field.
example : witnessDiscipline [true, false] [[1, 2], []] = true := by decide
example : witnessDiscipline [true, false] [[1, 2], [9]] = false := by decide -- mutation kill
example : witnessDiscipline [true, true] [[], []] = true := by decide        -- framing catches this instead
example : witnessDiscipline [true] [[], []] = false := by decide             -- arity mismatch

/-! ## C10 — block weight -/

example : blockWeight 1000000 1000000 = 4000000 := by decide
example : blockWeightOk 1000000 1000000 = true := by decide                  -- exact boundary
example : blockWeightOk 1000001 1000000 = false := by decide                 -- base overage not discounted
example : blockWeightOk 999999 1000000 = true := by decide
example : blockWeightOk 500000 1500000 = true := by decide
example : blockWeightOk 999999 1500001 = false := by decide                  -- total overage

example : blockWeight 500000 1500000 = 3000000 := by decide
example : 4 * (500000 + 1000000) = 6000000 := by decide                      -- `4·total` mutant value

/-! ## C11 — sigops -/

example : blockSigopOk 20000 0 = true := by decide                           -- 80,000 boundary
example : blockSigopOk 20001 0 = false := by decide                          -- 80,004
example : blockSigopOk 0 80000 = true := by decide
example : blockSigopOk 0 80001 = false := by decide
example : blockSigopOk 10000 40001 = false := by decide                      -- mixed = 80,001
example : blockSigopOk 10000 40000 = true := by decide
example : legacySigopCost 3 = 12 := by decide                                -- ×4 scaling
example : cmsSigops 1 = 1 ∧ cmsSigops 8 = 8 ∧ cmsSigops 16 = 16 := by decide
example : cmsSigops 0 = 20 ∧ cmsSigops 17 = 20 ∧ cmsSigops 255 = 20 := by decide
example : p2wpkhSigops = 1 := by decide

/-! ## C2 — commitment output pattern -/

example : isCommitmentSpk ([0x6a, 0x24, 0xaa, 0x21, 0xa9, 0xed] ++ List.replicate 32 9)
    = true := by decide
example : isCommitmentSpk ([0x6a, 0x24, 0xaa, 0x21, 0xa9, 0xed] ++ List.replicate 31 9)
    = false := by decide                                                     -- 37 bytes
example : isCommitmentSpk ([0x6a, 0x24, 0xaa, 0x21, 0xa9, 0xee] ++ List.replicate 32 9)
    = false := by decide                                                     -- header mutation
example : isCommitmentSpk ([0x6a, 0x25, 0xaa, 0x21, 0xa9, 0xed] ++ List.replicate 33 9)
    = false := by decide                                                     -- push-count mutation

-- Highest output index wins when several outputs match.
example : pickCommitmentIdx [[0x51], [0x6a, 0x24, 0xaa, 0x21, 0xa9, 0xed] ++ List.replicate 32 1,
    [0x6a, 0x24, 0xaa, 0x21, 0xa9, 0xed] ++ List.replicate 32 2] = some 2 := by decide
example : pickCommitmentIdx [[0x51], [0x52]] = none := by decide

-- Coinbase input witness = single 32-byte witness reserved value.
example : reservedValueOk [List.replicate 32 0] = true := by decide
example : reservedValueOk [List.replicate 31 0] = false := by decide
example : reservedValueOk [List.replicate 32 0, List.replicate 32 0] = false := by decide
example : reservedValueOk [] = false := by decide

-- Witness data ⇒ commitment; no witness data ⇒ commitment optional.
example : commitmentGate false true = false := by decide                     -- witness without commitment: invalid
example : commitmentGate false false = true := by decide                     -- optional when no witness data
example : commitmentGate true true = true := by decide
example : commitmentGate true false = true := by decide

/-! ## C2 / INV-092 — witness merkle shape (coinbase leaf = 0; odd dup) -/

example : witnessRoot [(true, [9, 9, 9])] = zero32 := by decide
example : witnessRoot [(false, [9, 9, 9])] ≠ zero32 := by decide             -- mutation kill: leaf not zeroed
example : witnessRoot [(true, [9]), (false, [5, 5, 5])] = combine zero32 [5, 5, 5] := by decide
example : witnessRoot [(true, [9]), (false, [5, 5, 5]), (false, [7, 7, 7])]
    = combine (combine zero32 [5, 5, 5]) (combine [7, 7, 7] [7, 7, 7]) := by decide
example : witnessRoot [(true, [9]), (false, [5]), (false, [7]), (false, [11])]
    = combine (combine zero32 [5]) (combine [7] [11]) := by decide           -- even count, no dup

/-! ## C12 — BIP9 segwit deployment -/

example : segwitParams.bit = 1 := by decide                                  -- BIP9 bit 1
example : segwitParams.start = 1479168000 := by decide                       -- 2016-11-15 UTC
example : segwitParams.timeout = 1510704000 := by decide                     -- 2017-11-15 UTC
example : segwitParams.threshold = 1916 := by decide                         -- Core deploymentinfo.cpp

example : bip9Step segwitParams .defined 1479167999 0 = .defined := by decide
example : bip9Step segwitParams .defined 1479168000 0 = .started := by decide
example : bip9Step segwitParams .started 1510703999 1915 = .started := by decide
-- Core checks the signal count BEFORE the timeout: at/after the timeout a
-- boundary with 5000 signals still locks in.
example : bip9Step segwitParams .started 1510704000 5000 = .lockedIn := by decide
-- Only a boundary at/after the timeout that is BELOW threshold fails.
example : bip9Step segwitParams .started 1510704000 1915 = .failed := by decide
example : bip9Step segwitParams .started 1510704000 1916 = .lockedIn := by decide
example : bip9Step segwitParams .started 1500000000 1916 = .lockedIn := by decide
example : bip9Step segwitParams .started 1500000000 1915 = .started := by decide -- mutation kill: threshold off-by-one
example : bip9Step segwitParams .lockedIn 1500000000 0 = .active := by decide
example : bip9Step segwitParams .active 9999999999 0 = .active := by decide
example : bip9Step segwitParams .failed 1000 9999 = .failed := by decide

theorem failedTerminal (p : Bip9Params) (t sigs : Nat) :
    bip9Step p .failed t sigs = .failed := by rfl

/-- defined →(t≥start) started →(sigs≥1916, t<timeout) lockedIn → active. -/
theorem segwit_reaches_active :
    bip9Step segwitParams
      (bip9Step segwitParams (bip9Step segwitParams .defined 1479168000 0) 1500000000 1916)
      1500201600 0 = .active := by rfl

#print axioms witness_discounted_once
#print axioms v0_bad_size_fails
#print axioms nonProgramVersionByte
#print axioms failedTerminal
#print axioms segwit_reaches_active

end BitcoinProofs.Bip.B08
