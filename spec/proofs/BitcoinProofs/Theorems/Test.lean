import BitcoinProofs.Theorems.ParserCor
import BitcoinProofs.Theorems.FlagsCor
import BitcoinProofs.Theorems.NumericCor
import BitcoinProofs.Theorems.LedgerCor
import BitcoinProofs.Theorems.InterpCor
import BitcoinProofs.AF.PDW50.PDW50

/-!
# BitcoinProofs.Theorems.Test — executable cross-checks

Every numeral below is recomputed by Lean from the C1 definitions via
`decide` (all target functions are structural, so `decide` kernel-reduces
— `decide` is barred only through well-founded recursions).
The values mirror the vectors used in the report and in the modules'
docstrings; if any definition drifts, the build fails here.

Sections:
1. Parser vectors (`Bitcoin.Data.Script.parse`): valid programs, a
   truncated push, an unknown opcode.
2. Interpreter vectors (`run`/`runsTrue`/`runsClean`): success, opcode
   failure, the fuel error, fuel canonicality, the add/equalVerify/
   checkSig-stub paths.
3. Flag vectors (`getBlockScriptFlags`): both exception blocks, burial
   boundaries, and the full BIP9 machine walk (defined → started →
   lockedIn → active; plus the timeout → failed path).
4. Numeric vectors (`setVchBE`/`decodeBE`/`decodeScriptNum`/`MoneyRange`):
   including the `[0x80]` negative-zero corner and the encode/decode
   roundtrip.
5. Ledger vectors (`checkTransaction`, block sums): the CVE-2018-17144
   duplicate-input rejection, the null-prevout rejection, the
   txout-total overflow, and hand conservation through the block sums.
6. L3 axiom pins: one headline theorem per module.
-/

namespace BitcoinProofs.Theorems.Test

open Bitcoin.Data Bitcoin.Numeric Bitcoin.Ledger Bitcoin.Consensus
open Bitcoin.Conservation Bitcoin.Activation Bitcoin.Script
open BitcoinProofs.Theorems.LedgerCor

/-! ## 1. Parser vectors -/

example : (scriptOf [0x51, 0x61]).parse = some [.const 1, .nop] := by decide
example : (scriptOf [0x60]).parse = some [.const 16] := by decide
example : (scriptOf [0x4f, 0x00]).parse = some [.op1negate, .push ByteArray.empty] := by decide
example : (scriptOf [0x02, 0x51]).parse = none := by decide   -- truncated push
example : (scriptOf [0x62]).parse = none := by decide         -- unknown opcode

/-! ## 2. Interpreter vectors -/

example : run 0 [.nop] [] = .error .scriptSize := by rfl
example : run 2 [.nop] [] = .ok [] := by rfl
example : run 3 [.const 1, .verify] [] = .ok [] := by rfl
example : runsClean 10 [.const 1, .verify] = true := by decide
example : runsTrue 10 [.const 1] = true := by decide
example : runsTrue 10 [.nop] = false := by decide             -- empty top of stack
example : runsClean 10 [.verify] = false := by decide         -- stackUnderflow
example : runsClean 10 [.push (serU8 0x01), .push (serU8 0x02), .equal, .verify] = false := by decide
example : runsClean 10 [.push (serU8 0x07), .push (serU8 0x07), .equalVerify] = true := by decide
example : runsTrue 10 [.const 2, .const 3, .add] = true := by decide
example : runsTrue 10 [.op1negate] = true := by decide
example : runsTrue 10 [.push (serU8 0x01), .push (serU8 0x02), .checkSig] = true := by decide
-- fuel canonicality (T2), executable instance:
example : run 100 [.const 1] [] = run 2 [.const 1] [] := by rfl
example : runsClean 100 [.const 1] = runsClean 2 [.const 1] := by decide

/-! ## 3. Flag vectors -/

example : (getBlockScriptFlags 170060).p2sh = false := by decide    -- BIP16 exception
example : (getBlockScriptFlags 692261).taproot = false := by decide -- taproot exception
example : (getBlockScriptFlags 692261).witness = true := by decide
example : (getBlockScriptFlags 363724).dersig = false := by decide  -- one below BIP66
example : (getBlockScriptFlags 419328).csv = true := by decide      -- exactly at CSV
example : (getBlockScriptFlags 481824).nullDummy = true := by decide

/-- A toy BIP9 deployment: start 100, threshold 8/10, 20 periods to timeout. -/
def PTest : Bip9Params := ⟨100, 20, 8, 10, 0, fun _ => 8⟩

example : bip9StateByPeriod PTest 0 = .defined := by decide
example : bip9StateByPeriod PTest 9 = .defined := by decide    -- boundary 99 < start
example : bip9StateByPeriod PTest 10 = .started := by decide   -- boundary 109
example : bip9StateByPeriod PTest 11 = .lockedIn := by decide  -- 8/8 signalled
example : bip9StateByPeriod PTest 12 = .active := by decide
example : bip9StateByPeriod PTest 50 = .active := by decide    -- absorbing
example : bip9State PTest 129 = .active := by decide           -- via height alignment

/-- The timeout path: same shape but only 3/10 signalled, deadline
`start + 2·period = 120`; the period ending at 119 still STARTED, the
one ending at 129 FAILED (BLK-077 ordering). -/
def PFail : Bip9Params := ⟨100, 2, 8, 10, 0, fun _ => 3⟩

example : bip9StateByPeriod PFail 11 = .started := by decide
example : bip9StateByPeriod PFail 12 = .failed := by decide
example : bip9StateByPeriod PFail 50 = .failed := by decide

/-! ## 4. Numeric vectors -/

example : setVchBE [1, 2] = 258 := by decide
example : setVchBE [128] = 0 := by decide                      -- negative zero (SCR-083)
example : setVchBE [131] = -3 := by decide
example : decodeBE true 4 [1, 2] = some 258 := by decide
example : decodeBE true 4 [128] = none := by decide            -- non-minimal
example : decodeBE false 4 [128] = some 0 := by decide
example : decodeBE true 1 [1, 2] = none := by decide           -- width limit
example : decodeScriptNum (encodeScriptNum 300 false) true 4 = some 300 := by decide
example : decodeScriptNum (encodeScriptNum (-3) false) true 4 = some (-3) := by decide
example : castToBool (serU8 0x01) = true := by decide
example : castToBool ByteArray.empty = false := by decide
example : castToBool (serU8 0x80) = false := by decide         -- negative zero casts false
example : MoneyRange (0 : Amount) = true := by decide
example : MoneyRange (2100000000000000 : Amount) = true := by decide
example : MoneyRange (2100000000000001 : Amount) = false := by decide
example : MoneyRange (-1 : Amount) = false := by decide

/-! ## 5. Ledger vectors -/

/-- Two utxo coins: 1500 sats at vout 0, 2500 sats at vout 1. -/
def coinA : Coin := ⟨1500, 0, false, Script.empty⟩
def coinB : Coin := ⟨2500, 0, false, Script.empty⟩

def oA : OutPoint := ⟨ByteArray.empty, 0⟩
def oB : OutPoint := ⟨ByteArray.empty, 1⟩

/-- The test UTXO view: vout 0 → coinA, vout 1 → coinB, else nothing. -/
def uTest : UtxoSet := fun o =>
  if o.n = 0 then some coinA else if o.n = 1 then some coinB else none

def iA : TxIn := ⟨oA, Script.empty, 0⟩
def iB : TxIn := ⟨oB, Script.empty, 0⟩

def txTest : Tx :=
  ⟨1, [iA, iB], [⟨400, Script.empty⟩, ⟨600, Script.empty⟩], 0, []⟩

example : totalOut txTest = 1000 := by decide
example : totalIn uTest txTest = 4000 := by decide
example : checkTransaction txTest = none := by decide

/-- CVE-2018-17144 shape: the same prevout twice is rejected. -/
def txDup : Tx := ⟨1, [iA, iA], [⟨400, Script.empty⟩], 0, []⟩

example : checkTransaction txDup = some .inputsDuplicate := by decide

/-- Null prevout (32 zero bytes + NULL_INDEX) in a non-coinbase input. -/
def oNull : OutPoint := ⟨zeroBytes 32, 0xFFFFFFFF⟩
def iNull : TxIn := ⟨oNull, Script.empty, 0⟩
def txNullPrev : Tx := ⟨1, [iNull, iA], [⟨400, Script.empty⟩], 0, []⟩

example : checkTransaction txNullPrev = some .prevoutNull := by decide

/-- Accumulated output total above MAX_MONEY (`bad-txns-txouttotal-toolarge`). -/
def txOverflow : Tx :=
  ⟨1, [iA], [⟨2100000000000000, Script.empty⟩, ⟨1, Script.empty⟩], 0, []⟩

example : checkTransaction txOverflow = some .txoutTotalTooLarge := by decide

/-- Empty vin / empty vout rejections. -/
example : checkTransaction ⟨1, [], [], 0, []⟩ = some .vinEmpty := by decide
example : checkTransaction ⟨1, [iA], [], 0, []⟩ = some .voutEmpty := by decide

/-- Block-sum conservation instance through arithmetic tier:
4000 in, 1000 + 1000 out, fee 2000. -/
example : blockOut [txTest, txTest] = 2000 := by decide
example : blockIn uTest [txTest] = 4000 := by decide

/-! ## 6. Merkle odd-tail regression (BLK-008) -/

section MerkleOddTail

open Bitcoin.Capstone.Merkle

/-- Seven leaves (odd at three levels): the general append law puts the
duplicated tail `g` in the first level exactly as `pairHash g g`. -/
example (a b c d e f g : ByteArray) :
    merkleLevel [a, b, c, d, e, f, g] =
      [pairHash a b, pairHash c d, pairHash e f, pairHash g g] := by
  rw [show [a, b, c, d, e, f, g] = [a, b, c, d, e, f] ++ [g] from rfl]
  rw [BitcoinProofs.AF.PDW50.merkleLevel_append_singleton [a, b, c, d, e, f] g (by simp)]
  simp [merkleLevel]

end MerkleOddTail

/-! ## 7. L3 axiom pins: one headline theorem per module -/

/--
info: 'BitcoinProofs.Theorems.ParserCor.parseScript_fuel_indep' depends on axioms: [propext, Quot.sound]
-/
#guard_msgs in #print axioms BitcoinProofs.Theorems.ParserCor.parseScript_fuel_indep

/--
info: 'BitcoinProofs.Theorems.FlagsCor.flags_genesis_exact' does not depend on any axioms
-/
#guard_msgs in #print axioms BitcoinProofs.Theorems.FlagsCor.flags_genesis_exact

/--
info: 'BitcoinProofs.Theorems.NumericCor.MAX_MONEY_exact' does not depend on any axioms
-/
#guard_msgs in #print axioms BitcoinProofs.Theorems.NumericCor.MAX_MONEY_exact

/--
info: 'BitcoinProofs.Theorems.LedgerCor.checkTransaction_none_noDup' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
-/
#guard_msgs in #print axioms BitcoinProofs.Theorems.LedgerCor.checkTransaction_none_noDup

/--
info: 'BitcoinProofs.Theorems.InterpCor.run_fuel_canonical' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms BitcoinProofs.Theorems.InterpCor.run_fuel_canonical

end BitcoinProofs.Theorems.Test
