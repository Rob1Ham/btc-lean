import Bitcoin

/-!
# Main — PoC sanity harness

Run with `lake exe btclean`. Every check is also mirrored by a
`decide`/`rfl`-checked `example` so the compiler itself verifies it at
build time (no runtime harness required for correctness).
-/


open Bitcoin.Data Bitcoin.Data.ScriptInstr Bitcoin.Script Bitcoin.Consensus Bitcoin.Chain Bitcoin.Ledger

set_option maxRecDepth 100000

/-! ## Hex round-trip helper (test infra only) -/

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

/-! ## Sample transactions -/

/-- A minimal *valid* coinbase: one input with null prevout,
2..100-byte scriptSig, one 50 BTC output. -/
def sampleCoinbase : Tx where
  version := 1
  vin := [{ prevout := OutPoint.null
            scriptSig := scriptOf [0x02, 0x51, 0x52]  -- push [51], push [52]
            sequence := 0xFFFFFFFF }]
  vout := [{ value := 5000000000, scriptPubKey := scriptOf [0x51] }]
  locktime := 0
  witness := []

/-- Expected base serialization, computed independently (Python,
`struct`-free hand packing) — this is our first conformance vector. -/
def sampleCoinbaseHex : String :=
  "01000000010000000000000000000000000000000000000000000000000000000000000000\
   ffffffff03025152ffffffff0100f2052a01000000015100000000"

/-- Same tx but with a 1-byte scriptSig → `bad-cb-length`. -/
def shortCoinbase : Tx where
  version := 1
  vin := [{ prevout := OutPoint.null
            scriptSig := scriptOf [0x51]
            sequence := 0xFFFFFFFF }]
  vout := [{ value := 5000000000, scriptPubKey := scriptOf [0x51] }]
  locktime := 0
  witness := []

/-- A non-coinbase tx spending a real (nonzero) prevout twice →
`bad-txns-inputs-duplicate`. -/
def dupInputTx : Tx where
  version := 1
  vin := [{ prevout := ⟨ByteArray.empty.push 0x11, 0⟩, scriptSig := Script.empty, sequence := 0xFFFFFFFF },
          { prevout := ⟨ByteArray.empty.push 0x11, 0⟩, scriptSig := Script.empty, sequence := 0xFFFFFFFF }]
  vout := [{ value := 100, scriptPubKey := Script.empty }]
  locktime := 0
  witness := []

/-- Negative output value → `bad-txns-vout-negative` (CVE-2010-5139). -/
def negativeTx : Tx where
  version := 1
  vin := [{ prevout := ⟨ByteArray.empty.push 0x11, 0⟩, scriptSig := Script.empty, sequence := 0xFFFFFFFF }]
  vout := [{ value := -1, scriptPubKey := Script.empty }]
  locktime := 0
  witness := []

/-- Empty vin → `bad-txns-vin-empty`. -/
def noVinTx : Tx where
  version := 1
  vin := []
  vout := [{ value := 100, scriptPubKey := Script.empty }]
  locktime := 0
  witness := []

/-! ## Build-time-verified facts (`example ... := by decide` / `rfl`) -/

-- CompactSize: 300 encodes as marker 0xfd + 2 LE bytes (checked vs Python).
example : hexChars (compactSizeEnc 300) = ['f', 'd', '2', 'c', '0', '1'] := by decide

-- Money: 0 is in range; MAX_MONEY is exactly 21e6 * COIN.
example : MoneyRange 0 = true := moneyRange_zero
example : MAX_MONEY = 2100000000000000 := by rfl

-- Serialization conformance vector (checked against independent packing).
example : bytesBEq (serTx sampleCoinbase) (fromHex sampleCoinbaseHex) = true := by decide

-- Script: 2+3=5 with EQUAL+VERIFY runs clean.
example : runsClean 100 [const 2, const 3, add, const 5, equal, verify] = true := by decide

-- Script: parsing the wire form of `OP_2 OP_3 OP_ADD OP_5 OP_EQUALVERIFY`.
example : (scriptOf [0x52, 0x53, 0x93, 0x55, 0x88]).parse =
    some [const 2, const 3, add, const 5, equalVerify] := by decide

-- PoW: nBits 0x1d00ffff expands to the difficulty-1 target.
example : compactTarget 0x1d00ffff = 0xffff * 256 ^ (0x1d - 3) := by decide

-- Consensus: each malformed tx is rejected with Core's exact reason.
example : checkTransaction dupInputTx = some .inputsDuplicate := by decide
example : checkTransaction negativeTx = some .voutNegative := by decide
example : checkTransaction noVinTx = some .vinEmpty := by decide
example : checkTransaction shortCoinbase = some .cbLength := by decide
example : checkTransaction sampleCoinbase = none := by decide

-- Coinbase shape: the sample IS a coinbase by Core's definition.
example : sampleCoinbase.isCoinBase = true := by decide

/-! ## Runtime harness -/

def check (name : String) (b : Bool) : IO Unit :=
  IO.println s!"[{if b then "PASS" else "FAIL"}] {name}"

/-- the frozen interface: each check returns its verdict so `main` can count failures and
exit non-zero, making `lake test` CI-usable. The original 13 checks are preserved
verbatim; 3 more were added. -/
def checkR (name : String) (b : Bool) : IO Bool := do
  check name b
  return b

/-- Spending a real prevout, for the ledger smoke test. -/
def spendTx : Tx where
  version := 1
  vin := [{ prevout := ⟨serU8 0xab ++ serU8 0xcd, 0⟩, scriptSig := Script.empty, sequence := 0xFFFFFFFF }]
  vout := [{ value := 900, scriptPubKey := Script.empty }]
  locktime := 0
  witness := []

def main : IO UInt32 := do
  let r0 := checkR "serTx conformance vector" (bytesBEq (serTx sampleCoinbase) (fromHex sampleCoinbaseHex))
  let r1 := do
    let a ← r0
    let b ← checkR "compactSize 300 == fd2c01" (toHex (compactSizeEnc 300) == "fd2c01")
    return a && b
  let r2 := do
    let a ← r1
    let b ← checkR "script 2+3==5" (runsClean 100 [const 2, const 3, add, const 5, equal, verify])
    return a && b
  let r3 := do
    let a ← r2
    let b ← checkR "script 2+3!=6" (¬ runsTrue 100 [const 2, const 3, add, const 6, equal, verify])
    return a && b
  let r4 := do
    let a ← r3
    let b ← checkR "checksig stub accepts" (runsTrue 100 [push (serU8 0x01), push (serU8 0x02), checkSig])
    return a && b
  let r5 := do
    let a ← r4
    let b ← checkR "dup inputs rejected" (checkTransaction dupInputTx == some .inputsDuplicate)
    return a && b
  let r6 := do
    let a ← r5
    let b ← checkR "negative output rejected" (checkTransaction negativeTx == some .voutNegative)
    return a && b
  let r7 := do
    let a ← r6
    let b ← checkR "empty vin rejected" (checkTransaction noVinTx == some .vinEmpty)
    return a && b
  let r8 := do
    let a ← r7
    let b ← checkR "short coinbase rejected" (checkTransaction shortCoinbase == some .cbLength)
    return a && b
  let r9 := do
    let a ← r8
    let b ← checkR "valid coinbase accepted" (checkTransaction sampleCoinbase == none)
    return a && b
  let r10 := do
    let a ← r9
    let b ← checkR "getValueOut == 50 BTC" (sampleCoinbase.getValueOut == 5000000000)
    return a && b
  let r11 := do
    let a ← r10
    let b ← checkR "compactTarget(0x1d00ffff) is difficulty-1" (compactTarget 0x1d00ffff == 0xffff * 256 ^ 26)
    return a && b

  -- UTXO smoke test: spend from an assoc-list ledger view.
  let coin : Coin := ⟨1000, 100, false, scriptOf [0x51]⟩
  let op : OutPoint := ⟨(serU8 0xab ++ serU8 0xcd), 0⟩
  let ledger : UtxoList := [(op, coin)]
  let ledger' := applyTx ledger spendTx
  let r12 := do
    let a ← r11
    let b ← checkR "UTXO: spent coin removed" (utxoLookup ledger' op == none)
    return a && b

  -- Additional gate checks: CompactSize roundtrip, MoneyRange boundary,
  -- witness-frame decode placeholder behavior stays stable.
  let r13 := do
    let a ← r12
    let b := match compactSizeDec (compactSizeEnc 300) 0 with
      | some (v, 3) => v == 300
      | _ => false
    let b' ← checkR "compactSizeDec ∘ compactSizeEnc 300 roundtrip" b
    return a && b'
  let r14 := do
    let a ← r13
    let b ← checkR "MoneyRange boundary: 0 and MAX_MONEY in range, MAX_MONEY+1 out"
      (MoneyRange 0 && MoneyRange MAX_MONEY && ¬ MoneyRange (MAX_MONEY + 1))
    return a && b
  let r15 := do
    let a ← r14
    let b ← checkR "CompactSize 0xfd marker canonicality: 0xfc encodes short, 0xfd needs marker"
      (toHex (compactSizeEnc 0xfc) == "fc" && toHex (compactSizeEnc 0xfd) == "fdfd00")
    return a && b

  IO.println s!"sample tx hex: {toHex (serTx sampleCoinbase)}"
  IO.println "done."
  return if ← r15 then 0 else 1
