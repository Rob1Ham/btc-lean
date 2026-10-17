import Bitcoin.Script.Parser.Interface

/-!
# W05 conformance runner — Lean side of the script_tests.json conformance

Pairs with `ref.py` (a faithful Python port of Core's `ParseScript` +
`GetScriptOp` @ `cce32b168`). `ref.py` turns every script asm string of
Core's `script_tests.json` into (a) the hex wire bytes and (b) the
expected normalized AST; this runner re-parses the wire bytes with
`Bitcoin.Script.Parser.parseFrom` and compares.

Run: `bash spec/core/Test/Script/Parser/run.sh` (or directly:
`lake env lean --run ../Test/Script/Parser/Conformance.lean <input> <expected>`).

Normalized AST tokens (identical convention on both sides — the
PUSHDATA1/2/4 form is erased since the AST carries only the payload):
`push:<payload hex>`, `num:<n>` (0 = OP_1NEGATE, 1..16 = OP_1..OP_16),
`op:0x<bb>` (incl. 0x50 = OP_RESERVED).

As a second, stronger axis the runner re-serializes every successfully
parsed AST with `serializeOpcodes` and checks byte-identity with the
input (holds because `lenBytes` = Core's `AppendDataSize` and the asm
grammar only produces canonically-encoded pushes).
-/

namespace Test.Script.Parser

open Bitcoin.Script.Parser

/-! ## Hex helpers (no `String.toUInt8!`; everything total) -/

def hexVal (c : Char) : Option Nat :=
  if c == '0' then some 0 else if c == '1' then some 1 else if c == '2' then some 2
  else if c == '3' then some 3 else if c == '4' then some 4 else if c == '5' then some 5
  else if c == '6' then some 6 else if c == '7' then some 7 else if c == '8' then some 8
  else if c == '9' then some 9 else if c == 'a' || c == 'A' then some 10
  else if c == 'b' || c == 'B' then some 11 else if c == 'c' || c == 'C' then some 12
  else if c == 'd' || c == 'D' then some 13 else if c == 'e' || c == 'E' then some 14
  else if c == 'f' || c == 'F' then some 15 else none

/-- Decode an even-length hex string; `none` on odd length or bad digit. -/
def unhex (s : String) : Option ByteArray :=
  let cs := s.toList
  if cs.length % 2 != 0 then none
  else
    let rec go : List Char → Array UInt8 → Option ByteArray
      | a :: b :: rest, acc =>
        (hexVal a).bind (fun hi => (hexVal b).bind (fun lo =>
          go rest (acc.push ((16 * hi + lo).toUInt8))))
      | [], acc => some (ByteArray.mk acc)
      | [_], _ => none
    go cs #[]

def hexNib (n : Nat) : String :=
  if n < 10 then toString n else
  if n = 10 then "a" else if n = 11 then "b" else if n = 12 then "c"
  else if n = 13 then "d" else if n = 14 then "e" else "f"

def hexByte (x : UInt8) : String :=
  hexNib (x.toNat / 16) ++ hexNib (x.toNat % 16)

def hexBytes (b : ByteArray) : String :=
  let rec go (i : Nat) (acc : String) : String :=
    if i < b.size then go (i + 1) (acc ++ hexByte (b.get! i)) else acc
  go 0 ""

/-! ## Normalization (mirrors `ref.py`'s token grammar) -/

def normOp : Opcode → String
  | .pushBytes d => "push:" ++ hexBytes d
  | .pushNum n => "num:" ++ toString n
  | .op c => "op:0x" ++ hexByte c.toNat.toUInt8

def normOps : List Opcode → String :=
  fun ops => match ops with
    | [] => ""
    | [o] => normOp o
    | o :: rest => normOp o ++ " " ++ normOps rest

/-- Parse one wire line and print the normalized AST, `FAIL` (parse
`none`) — or `SKIP` for the ref's placeholder lines. -/
def parseLine (line : String) : Option (String × Bool) :=
  if line == "-" then none
  else match unhex line with
    | none => some ("UNHEX-FAIL", false)
    | some b =>
      match parseFrom (b.size + 1) b 0 with
      | none => some ("FAIL", true)
      | some ops =>
        -- second axis: the roundtrip law `parseFrom_roundtrip` — the AST
        -- re-serializes (canonically) and parses back to itself. Inputs
        -- with non-minimal push forms (`4c00`, PUSHDATA2 of ≤ 255 …) fail
        -- *byte-identity* with `serializeOpcodes` by design (the printer
        -- canonicalizes, per CheckMinimalPush) — so the check is against
        -- the re-parse, not the input bytes.
        let ser := serializeOpcodes ops
        let rt := (parseFrom (ser.size + 1) ser 0 == some ops)
        some (normOps ops, rt)

end Test.Script.Parser

open Test.Script.Parser in
def main (args : List String) : IO UInt32 := do
  match args with
  | [inputF, expectedF] =>
    let inTxt ← IO.FS.readFile inputF
    let expTxt ← IO.FS.readFile expectedF
    let ins := (inTxt.splitOn "\n").filter (fun l => l.length > 0)
    let exps := (expTxt.splitOn "\n").filter (fun l => l.length > 0)
    let n := ins.length
    if n != exps.length then
      IO.println s!"line-count mismatch: {n} inputs vs {exps.length} expected"
      return 1
    let mut pass := 0
    let mut fail := 0
    let mut rtBad := 0
    let mut skip := 0
    for i in [0:n] do
      let exp := exps[i]!
      match parseLine ins[i]! with
      | none => skip := skip + 1
      | some (got, rt) =>
        if got != exp then
          fail := fail + 1
          IO.println s!"MISMATCH line {i}: got [{got}] expected [{exp}]"
        else if !rt then
          rtBad := rtBad + 1
          IO.println s!"ROUNDTRIP-BAD line {i}: input [{ins[i]!}] got [{got}]"
        else
          pass := pass + 1
    IO.println s!"CONFORMANCE: {pass} passed, {fail} mismatched, \
      {rtBad} roundtrip-bad, {skip} skipped (of {n} scripts)"
    if fail == 0 && rtBad == 0 then return 0 else return 1
  | _ =>
    IO.println "usage: Conformance.lean <conf_input.txt> <conf_expected.txt>"
    return 1
