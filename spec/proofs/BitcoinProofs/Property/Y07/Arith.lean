import Bitcoin.Interpreter.Interface

/-!
# BitcoinProofs.Property.Y07 — arithmetic-ops property corpus

2026-10-16.

Module under test: `Bitcoin.Interpreter` arithmetic opcodes (unary 0x8b/0x8c/
0x8f/0x90/0x91/0x92, binary 0x93/0x94/0x9a-0xa4, OP_WITHIN 0xa5, and the
disabled arithmetic family 0x7e-0x99 bits), driven through the public
`evalScriptBytes` entry (harness style).

Ground truth: Bitcoin Core @ c50817f —
  script/script.h:222-358    CScriptNum ctor decode + serialize/getvch
  script/script.cpp:373-397  CheckMinimalPush
  script/interpreter.cpp:447-483  disabled-opcode table (CVE-2010-5137)
  script/interpreter.cpp:926-1032 unary/binary arithmetic + OP_WITHIN
ported to a plain-python reference (independent of the Lean code). The
corpus below (215 cases) was generated with seed 20261016 —
REPRODUCIBLE: `python3 gen.py` regenerates this file byte-identically.
Structure: S direct-layer sanity, A unary edges, B ADD/SUB edges incl.
5-byte "results may overflow" results, C comparisons, D NUMEQUALVERIFY,
E the 15 disabled opcodes (DISABLED precedes the stack-depth check),
F CScriptNum decode edges under both policy settings, G underflow,
H/I seeded pseudo-random operand pairs, J OP_WITHIN, K MINIMALDATA-policy
randoms. Every case is a kernel `decide` over the concrete ByteArray
path (no native_decide: axiom footprint stays in the standard trio).
-/

namespace BitcoinProofs.Property.Y07.Arith

open Bitcoin.Interpreter Bitcoin.Numeric Bitcoin.Activation Bitcoin.Crypto.Seam

set_option maxRecDepth 10000
set_option maxHeartbeats 4000000

/-- Hex decode (test-only). -/
def fromHex (s : String) : ByteArray :=
  go s.toList ByteArray.empty
where
  go : List Char → ByteArray → ByteArray
    | [], acc => acc
    | [_], acc => acc
    | a :: b :: rest, acc =>
        let d (c : Char) : Option Nat :=
          let n := c.toNat
          if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
          else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
          else if 65 ≤ n ∧ n ≤ 70 then some (n - 55)
          else none
        match d a, d b with
        | some ha, some hb => go rest (acc.push ((ha * 16 + hb).toUInt8))
        | _, _ => go rest acc

def hex (s : String) : ByteArray := fromHex s

-- core 4.35 has no DecidableEq Except (note); derive it test-locally
deriving instance DecidableEq for Except

/-- No consensus flags. -/
def noflags : ScriptFlags := { p2sh := false }

/-- MINIMALDATA policy (script.cpp policy.c STANDARD_SCRIPT_VERIFY_FLAGS
includes MINIMALDATA; the consensus-default record leaves it off). -/
def minPol : PolicyFlags := { minimalData := true }

/-- The corpus checker: frozen stub EC seam + default tx env. -/
def tchk : ScriptChecker := ⟨stubChecker, default, none⟩

/-- EvalScript from an empty initial stack, base sigversion, 64 fuel.
The scripts are ≤ 7 opcodes, well inside every budget. -/
def runPol (pol : PolicyFlags) (b : ByteArray) : Except ExecError Stack :=
  evalScriptBytes 64 noflags pol b [] tchk .base default

/-! ## S — direct-layer sanity (public defs, no script driving) -/
/-- s01: binOp ADD 1 2 -/
example : binOp 0x93 1 2 = 3 := by decide
/-- s02: binOp ADD 2147483647 2147483647 (overflow result) -/
example : binOp 0x93 2147483647 2147483647 = 4294967294 := by decide
/-- s03: binOp SUB 0 1 -/
example : binOp 0x94 0 1 = (-1 : Int) := by decide
/-- s04: unOp NEGATE 0 -/
example : unOp 0x8f 0 = 0 := by decide
/-- s05: unOp NOT 5 -/
example : unOp 0x91 5 = 0 := by decide
/-- s06: encodeScriptNum 4294967294 (5-byte result encoding) -/
example : encodeScriptNum 4294967294 false = hex "feffffff00" := by decide
/-- s07: encodeScriptNum 0 = empty -/
example : encodeScriptNum 0 false = hex "" := by decide
/-- s08: encodeScriptNum (-1) -/
example : encodeScriptNum (-1 : Int) false = hex "81" := by decide
/-- s09: decodeScriptNum 8100 (minimalData off) = some 129 [reference-derived] -/
example : decodeScriptNum (hex "8100") false 4 = some 129 := by decide
/-- s10: decodeScriptNum 8100 (minimalData on) = some 129 [reference-derived] -/
example : decodeScriptNum (hex "8100") true 4 = some 129 := by decide
/-- s11: decodeScriptNum 0100 (minimalData off) = some 1 [reference-derived] -/
example : decodeScriptNum (hex "0100") false 4 = some 1 := by decide
/-- s12: decodeScriptNum 0100 (minimalData on) = none [reference-derived] -/
example : decodeScriptNum (hex "0100") true 4 = none := by decide
/-- s13: decodeScriptNum 0100000080 (minimalData off) = none [reference-derived] -/
example : decodeScriptNum (hex "0100000080") false 4 = none := by decide
/-- s14: decodeScriptNum 80 (minimalData off) = some 0 [reference-derived] -/
example : decodeScriptNum (hex "80") false 4 = some 0 := by decide
/-- s15: decodeScriptNum 80 (minimalData on) = none [reference-derived] -/
example : decodeScriptNum (hex "80") true 4 = none := by decide
/-- s16: decodeScriptNum 0080 (minimalData on) = none [reference-derived] -/
example : decodeScriptNum (hex "0080") true 4 = none := by decide

/-- A001: OP_1ADD 0 (operand ) — script 008b (policy: default) -/
example : runPol default (hex "008b") = .ok [hex "01"] := by decide

/-- A002: OP_1ADD 1 (operand 01) — script 518b (policy: default) -/
example : runPol default (hex "518b") = .ok [hex "02"] := by decide

/-- A003: OP_1ADD 16 (operand 10) — script 608b (policy: default) -/
example : runPol default (hex "608b") = .ok [hex "11"] := by decide

/-- A004: OP_1ADD 128 (operand 8000) — script 0280008b (policy: default) -/
example : runPol default (hex "0280008b") = .ok [hex "8100"] := by decide

/-- A005: OP_1ADD 2^31-1 (operand ffffff7f) — script 04ffffff7f8b (policy: default) -/
example : runPol default (hex "04ffffff7f8b") = .ok [hex "0000008000"] := by decide

/-- A006: OP_1ADD -(2^31-1) (operand ffffffff) — script 04ffffffff8b (policy: default) -/
example : runPol default (hex "04ffffffff8b") = .ok [hex "feffffff"] := by decide

/-- A007: OP_1SUB 0 (operand ) — script 008c (policy: default) -/
example : runPol default (hex "008c") = .ok [hex "81"] := by decide

/-- A008: OP_1SUB 1 (operand 01) — script 518c (policy: default) -/
example : runPol default (hex "518c") = .ok [hex ""] := by decide

/-- A009: OP_1SUB 16 (operand 10) — script 608c (policy: default) -/
example : runPol default (hex "608c") = .ok [hex "0f"] := by decide

/-- A010: OP_1SUB 128 (operand 8000) — script 0280008c (policy: default) -/
example : runPol default (hex "0280008c") = .ok [hex "7f"] := by decide

/-- A011: OP_1SUB 2^31-1 (operand ffffff7f) — script 04ffffff7f8c (policy: default) -/
example : runPol default (hex "04ffffff7f8c") = .ok [hex "feffff7f"] := by decide

/-- A012: OP_1SUB -(2^31-1) (operand ffffffff) — script 04ffffffff8c (policy: default) -/
example : runPol default (hex "04ffffffff8c") = .ok [hex "0000008080"] := by decide

/-- A013: OP_NEGATE 0 (operand ) — script 008f (policy: default) -/
example : runPol default (hex "008f") = .ok [hex ""] := by decide

/-- A014: OP_NEGATE 1 (operand 01) — script 518f (policy: default) -/
example : runPol default (hex "518f") = .ok [hex "81"] := by decide

/-- A015: OP_NEGATE 16 (operand 10) — script 608f (policy: default) -/
example : runPol default (hex "608f") = .ok [hex "90"] := by decide

/-- A016: OP_NEGATE 128 (operand 8000) — script 0280008f (policy: default) -/
example : runPol default (hex "0280008f") = .ok [hex "8080"] := by decide

/-- A017: OP_NEGATE 2^31-1 (operand ffffff7f) — script 04ffffff7f8f (policy: default) -/
example : runPol default (hex "04ffffff7f8f") = .ok [hex "ffffffff"] := by decide

/-- A018: OP_NEGATE -(2^31-1) (operand ffffffff) — script 04ffffffff8f (policy: default) -/
example : runPol default (hex "04ffffffff8f") = .ok [hex "ffffff7f"] := by decide

/-- A019: OP_ABS 0 (operand ) — script 0090 (policy: default) -/
example : runPol default (hex "0090") = .ok [hex ""] := by decide

/-- A020: OP_ABS 1 (operand 01) — script 5190 (policy: default) -/
example : runPol default (hex "5190") = .ok [hex "01"] := by decide

/-- A021: OP_ABS 16 (operand 10) — script 6090 (policy: default) -/
example : runPol default (hex "6090") = .ok [hex "10"] := by decide

/-- A022: OP_ABS 128 (operand 8000) — script 02800090 (policy: default) -/
example : runPol default (hex "02800090") = .ok [hex "8000"] := by decide

/-- A023: OP_ABS 2^31-1 (operand ffffff7f) — script 04ffffff7f90 (policy: default) -/
example : runPol default (hex "04ffffff7f90") = .ok [hex "ffffff7f"] := by decide

/-- A024: OP_ABS -(2^31-1) (operand ffffffff) — script 04ffffffff90 (policy: default) -/
example : runPol default (hex "04ffffffff90") = .ok [hex "ffffff7f"] := by decide

/-- A025: OP_NOT 0 (operand ) — script 0091 (policy: default) -/
example : runPol default (hex "0091") = .ok [hex "01"] := by decide

/-- A026: OP_NOT 1 (operand 01) — script 5191 (policy: default) -/
example : runPol default (hex "5191") = .ok [hex ""] := by decide

/-- A027: OP_NOT 16 (operand 10) — script 6091 (policy: default) -/
example : runPol default (hex "6091") = .ok [hex ""] := by decide

/-- A028: OP_NOT 128 (operand 8000) — script 02800091 (policy: default) -/
example : runPol default (hex "02800091") = .ok [hex ""] := by decide

/-- A029: OP_NOT 2^31-1 (operand ffffff7f) — script 04ffffff7f91 (policy: default) -/
example : runPol default (hex "04ffffff7f91") = .ok [hex ""] := by decide

/-- A030: OP_NOT -(2^31-1) (operand ffffffff) — script 04ffffffff91 (policy: default) -/
example : runPol default (hex "04ffffffff91") = .ok [hex ""] := by decide

/-- A031: OP_0NOTEQUAL 0 (operand ) — script 0092 (policy: default) -/
example : runPol default (hex "0092") = .ok [hex ""] := by decide

/-- A032: OP_0NOTEQUAL 1 (operand 01) — script 5192 (policy: default) -/
example : runPol default (hex "5192") = .ok [hex "01"] := by decide

/-- A033: OP_0NOTEQUAL 16 (operand 10) — script 6092 (policy: default) -/
example : runPol default (hex "6092") = .ok [hex "01"] := by decide

/-- A034: OP_0NOTEQUAL 128 (operand 8000) — script 02800092 (policy: default) -/
example : runPol default (hex "02800092") = .ok [hex "01"] := by decide

/-- A035: OP_0NOTEQUAL 2^31-1 (operand ffffff7f) — script 04ffffff7f92 (policy: default) -/
example : runPol default (hex "04ffffff7f92") = .ok [hex "01"] := by decide

/-- A036: OP_0NOTEQUAL -(2^31-1) (operand ffffffff) — script 04ffffffff92 (policy: default) -/
example : runPol default (hex "04ffffffff92") = .ok [hex "01"] := by decide

/-- B037: 0 + 0 — script 000093 (policy: default) -/
example : runPol default (hex "000093") = .ok [hex ""] := by decide

/-- B038: 0 - 0 — script 000094 (policy: default) -/
example : runPol default (hex "000094") = .ok [hex ""] := by decide

/-- B039: 1 + 0 — script 510093 (policy: default) -/
example : runPol default (hex "510093") = .ok [hex "01"] := by decide

/-- B040: 1 - 0 — script 510094 (policy: default) -/
example : runPol default (hex "510094") = .ok [hex "01"] := by decide

/-- B041: 0 + 1 — script 005193 (policy: default) -/
example : runPol default (hex "005193") = .ok [hex "01"] := by decide

/-- B042: 0 - 1 — script 005194 (policy: default) -/
example : runPol default (hex "005194") = .ok [hex "81"] := by decide

/-- B043: 1 + -1 — script 514f93 (policy: default) -/
example : runPol default (hex "514f93") = .ok [hex ""] := by decide

/-- B044: 1 - -1 — script 514f94 (policy: default) -/
example : runPol default (hex "514f94") = .ok [hex "02"] := by decide

/-- B045: -1 + 1 — script 4f5193 (policy: default) -/
example : runPol default (hex "4f5193") = .ok [hex ""] := by decide

/-- B046: -1 - 1 — script 4f5194 (policy: default) -/
example : runPol default (hex "4f5194") = .ok [hex "82"] := by decide

/-- B047: 127 + 1 — script 017f5193 (policy: default) -/
example : runPol default (hex "017f5193") = .ok [hex "8000"] := by decide

/-- B048: 127 - 1 — script 017f5194 (policy: default) -/
example : runPol default (hex "017f5194") = .ok [hex "7e"] := by decide

/-- B049: 128 + 1 — script 0280005193 (policy: default) -/
example : runPol default (hex "0280005193") = .ok [hex "8100"] := by decide

/-- B050: 128 - 1 — script 0280005194 (policy: default) -/
example : runPol default (hex "0280005194") = .ok [hex "7f"] := by decide

/-- B051: 2147483647 + 1 — script 04ffffff7f5193 (policy: default) -/
example : runPol default (hex "04ffffff7f5193") = .ok [hex "0000008000"] := by decide

/-- B052: 2147483647 - 1 — script 04ffffff7f5194 (policy: default) -/
example : runPol default (hex "04ffffff7f5194") = .ok [hex "feffff7f"] := by decide

/-- B053: 2147483647 + 2147483647 — script 04ffffff7f04ffffff7f93 (policy: default) -/
example : runPol default (hex "04ffffff7f04ffffff7f93") = .ok [hex "feffffff00"] := by decide

/-- B054: 2147483647 - 2147483647 — script 04ffffff7f04ffffff7f94 (policy: default) -/
example : runPol default (hex "04ffffff7f04ffffff7f94") = .ok [hex ""] := by decide

/-- B055: -2147483647 + -2147483647 — script 04ffffffff04ffffffff93 (policy: default) -/
example : runPol default (hex "04ffffffff04ffffffff93") = .ok [hex "feffffff80"] := by decide

/-- B056: -2147483647 - -2147483647 — script 04ffffffff04ffffffff94 (policy: default) -/
example : runPol default (hex "04ffffffff04ffffffff94") = .ok [hex ""] := by decide

/-- B057: 2147483647 + -2147483647 — script 04ffffff7f04ffffffff93 (policy: default) -/
example : runPol default (hex "04ffffff7f04ffffffff93") = .ok [hex ""] := by decide

/-- B058: 2147483647 - -2147483647 — script 04ffffff7f04ffffffff94 (policy: default) -/
example : runPol default (hex "04ffffff7f04ffffffff94") = .ok [hex "feffffff00"] := by decide

/-- B059: 8388608 + 8388608 — script 0400008000040000800093 (policy: default) -/
example : runPol default (hex "0400008000040000800093") = .ok [hex "00000001"] := by decide

/-- B060: 8388608 - 8388608 — script 0400008000040000800094 (policy: default) -/
example : runPol default (hex "0400008000040000800094") = .ok [hex ""] := by decide

/-- C061: OP_BOOLAND 0 0 — script 00009a (policy: default) -/
example : runPol default (hex "00009a") = .ok [hex ""] := by decide

/-- C062: OP_BOOLAND 0 1 — script 00519a (policy: default) -/
example : runPol default (hex "00519a") = .ok [hex ""] := by decide

/-- C063: OP_BOOLAND 1 0 — script 51009a (policy: default) -/
example : runPol default (hex "51009a") = .ok [hex ""] := by decide

/-- C064: OP_BOOLAND -1 1 — script 4f519a (policy: default) -/
example : runPol default (hex "4f519a") = .ok [hex "01"] := by decide

/-- C065: OP_BOOLAND 2147483647 2147483646 — script 04ffffff7f04feffff7f9a (policy: default) -/
example : runPol default (hex "04ffffff7f04feffff7f9a") = .ok [hex "01"] := by decide

/-- C066: OP_BOOLOR 0 0 — script 00009b (policy: default) -/
example : runPol default (hex "00009b") = .ok [hex ""] := by decide

/-- C067: OP_BOOLOR 0 1 — script 00519b (policy: default) -/
example : runPol default (hex "00519b") = .ok [hex "01"] := by decide

/-- C068: OP_BOOLOR 1 0 — script 51009b (policy: default) -/
example : runPol default (hex "51009b") = .ok [hex "01"] := by decide

/-- C069: OP_BOOLOR -1 1 — script 4f519b (policy: default) -/
example : runPol default (hex "4f519b") = .ok [hex "01"] := by decide

/-- C070: OP_BOOLOR 2147483647 2147483646 — script 04ffffff7f04feffff7f9b (policy: default) -/
example : runPol default (hex "04ffffff7f04feffff7f9b") = .ok [hex "01"] := by decide

/-- C071: OP_LESSTHAN 0 0 — script 00009f (policy: default) -/
example : runPol default (hex "00009f") = .ok [hex ""] := by decide

/-- C072: OP_LESSTHAN 0 1 — script 00519f (policy: default) -/
example : runPol default (hex "00519f") = .ok [hex "01"] := by decide

/-- C073: OP_LESSTHAN 1 0 — script 51009f (policy: default) -/
example : runPol default (hex "51009f") = .ok [hex ""] := by decide

/-- C074: OP_LESSTHAN -1 1 — script 4f519f (policy: default) -/
example : runPol default (hex "4f519f") = .ok [hex "01"] := by decide

/-- C075: OP_LESSTHAN 2147483647 2147483646 — script 04ffffff7f04feffff7f9f (policy: default) -/
example : runPol default (hex "04ffffff7f04feffff7f9f") = .ok [hex ""] := by decide

/-- C076: OP_GREATERTHAN 0 0 — script 0000a0 (policy: default) -/
example : runPol default (hex "0000a0") = .ok [hex ""] := by decide

/-- C077: OP_GREATERTHAN 0 1 — script 0051a0 (policy: default) -/
example : runPol default (hex "0051a0") = .ok [hex ""] := by decide

/-- C078: OP_GREATERTHAN 1 0 — script 5100a0 (policy: default) -/
example : runPol default (hex "5100a0") = .ok [hex "01"] := by decide

/-- C079: OP_GREATERTHAN -1 1 — script 4f51a0 (policy: default) -/
example : runPol default (hex "4f51a0") = .ok [hex ""] := by decide

/-- C080: OP_GREATERTHAN 2147483647 2147483646 — script 04ffffff7f04feffff7fa0 (policy: default) -/
example : runPol default (hex "04ffffff7f04feffff7fa0") = .ok [hex "01"] := by decide

/-- C081: OP_LESSTHANOREQUAL 0 0 — script 0000a1 (policy: default) -/
example : runPol default (hex "0000a1") = .ok [hex "01"] := by decide

/-- C082: OP_LESSTHANOREQUAL 0 1 — script 0051a1 (policy: default) -/
example : runPol default (hex "0051a1") = .ok [hex "01"] := by decide

/-- C083: OP_LESSTHANOREQUAL 1 0 — script 5100a1 (policy: default) -/
example : runPol default (hex "5100a1") = .ok [hex ""] := by decide

/-- C084: OP_LESSTHANOREQUAL -1 1 — script 4f51a1 (policy: default) -/
example : runPol default (hex "4f51a1") = .ok [hex "01"] := by decide

/-- C085: OP_LESSTHANOREQUAL 2147483647 2147483646 — script 04ffffff7f04feffff7fa1 (policy: default) -/
example : runPol default (hex "04ffffff7f04feffff7fa1") = .ok [hex ""] := by decide

/-- C086: OP_GREATERTHANOREQUAL 0 0 — script 0000a2 (policy: default) -/
example : runPol default (hex "0000a2") = .ok [hex "01"] := by decide

/-- C087: OP_GREATERTHANOREQUAL 0 1 — script 0051a2 (policy: default) -/
example : runPol default (hex "0051a2") = .ok [hex ""] := by decide

/-- C088: OP_GREATERTHANOREQUAL 1 0 — script 5100a2 (policy: default) -/
example : runPol default (hex "5100a2") = .ok [hex "01"] := by decide

/-- C089: OP_GREATERTHANOREQUAL -1 1 — script 4f51a2 (policy: default) -/
example : runPol default (hex "4f51a2") = .ok [hex ""] := by decide

/-- C090: OP_GREATERTHANOREQUAL 2147483647 2147483646 — script 04ffffff7f04feffff7fa2 (policy: default) -/
example : runPol default (hex "04ffffff7f04feffff7fa2") = .ok [hex "01"] := by decide

/-- C091: OP_MIN 0 0 — script 0000a3 (policy: default) -/
example : runPol default (hex "0000a3") = .ok [hex ""] := by decide

/-- C092: OP_MIN 0 1 — script 0051a3 (policy: default) -/
example : runPol default (hex "0051a3") = .ok [hex ""] := by decide

/-- C093: OP_MIN 1 0 — script 5100a3 (policy: default) -/
example : runPol default (hex "5100a3") = .ok [hex ""] := by decide

/-- C094: OP_MIN -1 1 — script 4f51a3 (policy: default) -/
example : runPol default (hex "4f51a3") = .ok [hex "81"] := by decide

/-- C095: OP_MIN 2147483647 2147483646 — script 04ffffff7f04feffff7fa3 (policy: default) -/
example : runPol default (hex "04ffffff7f04feffff7fa3") = .ok [hex "feffff7f"] := by decide

/-- C096: OP_MAX 0 0 — script 0000a4 (policy: default) -/
example : runPol default (hex "0000a4") = .ok [hex ""] := by decide

/-- C097: OP_MAX 0 1 — script 0051a4 (policy: default) -/
example : runPol default (hex "0051a4") = .ok [hex "01"] := by decide

/-- C098: OP_MAX 1 0 — script 5100a4 (policy: default) -/
example : runPol default (hex "5100a4") = .ok [hex "01"] := by decide

/-- C099: OP_MAX -1 1 — script 4f51a4 (policy: default) -/
example : runPol default (hex "4f51a4") = .ok [hex "01"] := by decide

/-- C100: OP_MAX 2147483647 2147483646 — script 04ffffff7f04feffff7fa4 (policy: default) -/
example : runPol default (hex "04ffffff7f04feffff7fa4") = .ok [hex "ffffff7f"] := by decide

/-- C101: OP_NUMNOTEQUAL 0 0 — script 00009e (policy: default) -/
example : runPol default (hex "00009e") = .ok [hex ""] := by decide

/-- C102: OP_NUMNOTEQUAL 0 1 — script 00519e (policy: default) -/
example : runPol default (hex "00519e") = .ok [hex "01"] := by decide

/-- C103: OP_NUMNOTEQUAL 1 0 — script 51009e (policy: default) -/
example : runPol default (hex "51009e") = .ok [hex "01"] := by decide

/-- C104: OP_NUMNOTEQUAL -1 1 — script 4f519e (policy: default) -/
example : runPol default (hex "4f519e") = .ok [hex "01"] := by decide

/-- C105: OP_NUMNOTEQUAL 2147483647 2147483646 — script 04ffffff7f04feffff7f9e (policy: default) -/
example : runPol default (hex "04ffffff7f04feffff7f9e") = .ok [hex "01"] := by decide

/-- D106: NUMEQUALVERIFY 5 5 — script 55559d (policy: default) -/
example : runPol default (hex "55559d") = .ok [] := by decide

/-- D107: NUMEQUALVERIFY 0 0 — script 00009d (policy: default) -/
example : runPol default (hex "00009d") = .ok [] := by decide

/-- D108: NUMEQUALVERIFY -1 -1 — script 4f4f9d (policy: default) -/
example : runPol default (hex "4f4f9d") = .ok [] := by decide

/-- D109: NUMEQUALVERIFY 5 6 — script 55569d (policy: default) -/
example : runPol default (hex "55569d") = .error .numEqualVerifyFailed := by decide

/-- D110: NUMEQUALVERIFY 0 1 — script 00519d (policy: default) -/
example : runPol default (hex "00519d") = .error .numEqualVerifyFailed := by decide

/-- D111: NUMEQUALVERIFY 2147483647 2147483647 — script 04ffffff7f04ffffff7f9d (policy: default) -/
example : runPol default (hex "04ffffff7f04ffffff7f9d") = .ok [] := by decide

/-- E112: disabled 0x7e on empty stack — script 7e (policy: default) -/
example : runPol default (hex "7e") = .error .disabledOpcode := by decide

/-- E113: disabled 0x7f on empty stack — script 7f (policy: default) -/
example : runPol default (hex "7f") = .error .disabledOpcode := by decide

/-- E114: disabled 0x80 on empty stack — script 80 (policy: default) -/
example : runPol default (hex "80") = .error .disabledOpcode := by decide

/-- E115: disabled 0x81 on empty stack — script 81 (policy: default) -/
example : runPol default (hex "81") = .error .disabledOpcode := by decide

/-- E116: disabled 0x83 on empty stack — script 83 (policy: default) -/
example : runPol default (hex "83") = .error .disabledOpcode := by decide

/-- E117: disabled 0x84 on empty stack — script 84 (policy: default) -/
example : runPol default (hex "84") = .error .disabledOpcode := by decide

/-- E118: disabled 0x85 on empty stack — script 85 (policy: default) -/
example : runPol default (hex "85") = .error .disabledOpcode := by decide

/-- E119: disabled 0x86 on empty stack — script 86 (policy: default) -/
example : runPol default (hex "86") = .error .disabledOpcode := by decide

/-- E120: disabled 0x8d on empty stack — script 8d (policy: default) -/
example : runPol default (hex "8d") = .error .disabledOpcode := by decide

/-- E121: disabled 0x8e on empty stack — script 8e (policy: default) -/
example : runPol default (hex "8e") = .error .disabledOpcode := by decide

/-- E122: disabled 0x95 on empty stack — script 95 (policy: default) -/
example : runPol default (hex "95") = .error .disabledOpcode := by decide

/-- E123: disabled 0x96 on empty stack — script 96 (policy: default) -/
example : runPol default (hex "96") = .error .disabledOpcode := by decide

/-- E124: disabled 0x97 on empty stack — script 97 (policy: default) -/
example : runPol default (hex "97") = .error .disabledOpcode := by decide

/-- E125: disabled 0x98 on empty stack — script 98 (policy: default) -/
example : runPol default (hex "98") = .error .disabledOpcode := by decide

/-- E126: disabled 0x99 on empty stack — script 99 (policy: default) -/
example : runPol default (hex "99") = .error .disabledOpcode := by decide

/-- E127: disabled 0x7e after operands — script 52537e (policy: default) -/
example : runPol default (hex "52537e") = .error .disabledOpcode := by decide

/-- E128: disabled 0x86 after operands — script 525386 (policy: default) -/
example : runPol default (hex "525386") = .error .disabledOpcode := by decide

/-- E129: disabled 0x8d after operands — script 52538d (policy: default) -/
example : runPol default (hex "52538d") = .error .disabledOpcode := by decide

/-- E130: disabled 0x95 after operands — script 525395 (policy: default) -/
example : runPol default (hex "525395") = .error .disabledOpcode := by decide

/-- E131: disabled 0x99 after operands — script 525399 (policy: default) -/
example : runPol default (hex "525399") = .error .disabledOpcode := by decide

/-- F132: direct push of [01] accepted with minimalData off — script 010191 (policy: default) -/
example : runPol default (hex "010191") = .ok [hex ""] := by decide

/-- F133: direct push of [01] → MINIMALDATA (should be OP_1) — script 010191 (policy: MINIMALDATA) -/
example : runPol minPol (hex "010191") = .error .minimalData := by decide

/-- F134: direct push of [81] → MINIMALDATA (should be OP_1NEGATE) — script 018191 (policy: MINIMALDATA) -/
example : runPol minPol (hex "018191") = .error .minimalData := by decide

/-- F135: OP_1 itself is by-definition minimal (no CheckMinimalPush) — script 5191 (policy: MINIMALDATA) -/
example : runPol minPol (hex "5191") = .ok [hex ""] := by decide

/-- F136: decode canonical +129 8100 under default policy — script 02810091 (policy: default) -/
example : runPol default (hex "02810091") = .ok [hex ""] := by decide

/-- F137: decode canonical +129 8100 under MINIMALDATA — script 02810091 (policy: MINIMALDATA) -/
example : runPol minPol (hex "02810091") = .ok [hex ""] := by decide

/-- F138: decode neg-zero top byte -> 0 0080 under default policy — script 02008091 (policy: default) -/
example : runPol default (hex "02008091") = .ok [hex "01"] := by decide

/-- F139: decode neg-zero top byte -> 0 0080 under MINIMALDATA — script 02008091 (policy: MINIMALDATA) -/
example : runPol minPol (hex "02008091") = .error .scriptNum := by decide

/-- F140: decode negative zero encoding 80 under default policy — script 018091 (policy: default) -/
example : runPol default (hex "018091") = .ok [hex "01"] := by decide

/-- F141: decode negative zero encoding 80 under MINIMALDATA — script 018091 (policy: MINIMALDATA) -/
example : runPol minPol (hex "018091") = .error .scriptNum := by decide

/-- F142: decode non-minimal 0 000000 under default policy — script 0300000091 (policy: default) -/
example : runPol default (hex "0300000091") = .ok [hex "01"] := by decide

/-- F143: decode non-minimal 0 000000 under MINIMALDATA — script 0300000091 (policy: MINIMALDATA) -/
example : runPol minPol (hex "0300000091") = .error .scriptNum := by decide

/-- F144: decode non-minimal 127 7f00 under default policy — script 027f0091 (policy: default) -/
example : runPol default (hex "027f0091") = .ok [hex ""] := by decide

/-- F145: decode non-minimal 127 7f00 under MINIMALDATA — script 027f0091 (policy: MINIMALDATA) -/
example : runPol minPol (hex "027f0091") = .error .scriptNum := by decide

/-- F146: decode non-minimal 1 0100 under default policy — script 02010091 (policy: default) -/
example : runPol default (hex "02010091") = .ok [hex ""] := by decide

/-- F147: decode non-minimal 1 0100 under MINIMALDATA — script 02010091 (policy: MINIMALDATA) -/
example : runPol minPol (hex "02010091") = .error .scriptNum := by decide

/-- F148: decode canonical -32768 008080 under default policy — script 0300808091 (policy: default) -/
example : runPol default (hex "0300808091") = .ok [hex ""] := by decide

/-- F149: decode canonical -32768 008080 under MINIMALDATA — script 0300808091 (policy: MINIMALDATA) -/
example : runPol minPol (hex "0300808091") = .ok [hex ""] := by decide

/-- F150: decode maximal 4-byte 2147483647 ffffff7f under default policy — script 04ffffff7f91 (policy: default) -/
example : runPol default (hex "04ffffff7f91") = .ok [hex ""] := by decide

/-- F151: decode maximal 4-byte 2147483647 ffffff7f under MINIMALDATA — script 04ffffff7f91 (policy: MINIMALDATA) -/
example : runPol minPol (hex "04ffffff7f91") = .ok [hex ""] := by decide

/-- F152: decode canonical -16777215 ffffffff under default policy — script 04ffffffff91 (policy: default) -/
example : runPol default (hex "04ffffffff91") = .ok [hex ""] := by decide

/-- F153: decode canonical -16777215 ffffffff under MINIMALDATA — script 04ffffffff91 (policy: MINIMALDATA) -/
example : runPol minPol (hex "04ffffffff91") = .ok [hex ""] := by decide

/-- F154: decode canonical -8421504 80808080 under default policy — script 048080808091 (policy: default) -/
example : runPol default (hex "048080808091") = .ok [hex ""] := by decide

/-- F155: decode canonical -8421504 80808080 under MINIMALDATA — script 048080808091 (policy: MINIMALDATA) -/
example : runPol minPol (hex "048080808091") = .ok [hex ""] := by decide

/-- F156: decode 5-byte 2^31+1 (width overflow) 0100000080 under default policy — script 05010000008091 (policy: default) -/
example : runPol default (hex "05010000008091") = .error .scriptNum := by decide

/-- F157: decode 5-byte 2^31+1 (width overflow) 0100000080 under MINIMALDATA — script 05010000008091 (policy: MINIMALDATA) -/
example : runPol minPol (hex "05010000008091") = .error .scriptNum := by decide

/-- F158: decode canonical 128 8000 under default policy — script 02800091 (policy: default) -/
example : runPol default (hex "02800091") = .ok [hex ""] := by decide

/-- F159: decode canonical 128 8000 under MINIMALDATA — script 02800091 (policy: MINIMALDATA) -/
example : runPol minPol (hex "02800091") = .ok [hex ""] := by decide

/-- F160: decode canonical -1 81 under default policy — script 4f91 (policy: default) -/
example : runPol default (hex "4f91") = .ok [hex ""] := by decide

/-- F161: decode canonical -1 81 under MINIMALDATA — script 4f91 (policy: MINIMALDATA) -/
example : runPol minPol (hex "4f91") = .ok [hex ""] := by decide

/-- F162: decode empty  under default policy — script 0091 (policy: default) -/
example : runPol default (hex "0091") = .ok [hex "01"] := by decide

/-- F163: decode empty  under MINIMALDATA — script 0091 (policy: MINIMALDATA) -/
example : runPol minPol (hex "0091") = .ok [hex "01"] := by decide

/-- G164: OP_ADD on empty stack — script 93 (policy: default) -/
example : runPol default (hex "93") = .error .stackUnderflow := by decide

/-- G165: OP_NOT on empty stack — script 91 (policy: default) -/
example : runPol default (hex "91") = .error .stackUnderflow := by decide

/-- G166: OP_NUMEQUALVERIFY with 1 operand — script 539d (policy: default) -/
example : runPol default (hex "539d") = .error .stackUnderflow := by decide

/-- G167: OP_WITHIN with 2 operands — script 5152a5 (policy: default) -/
example : runPol default (hex "5152a5") = .error .stackUnderflow := by decide

/-- G168: OP_ADD chain drains stack — script 5193 (policy: default) -/
example : runPol default (hex "5193") = .error .stackUnderflow := by decide

/-- H169: random#00 OP_BOOLAND 2147483649 -2147483648 — script 0501000080000500000080809a (policy: default) -/
example : runPol default (hex "0501000080000500000080809a") = .error .scriptNum := by decide

/-- H170: random#01 OP_LESSTHAN -2147483647 113231737 — script 04ffffffff0479c7bf069f (policy: default) -/
example : runPol default (hex "04ffffffff0479c7bf069f") = .ok [hex "01"] := by decide

/-- H171: random#02 OP_BOOLOR -1 3 — script 4f539b (policy: default) -/
example : runPol default (hex "4f539b") = .ok [hex "01"] := by decide

/-- H172: random#03 OP_ADD 2147483645 32768 — script 04fdffff7f0300800093 (policy: default) -/
example : runPol default (hex "04fdffff7f0300800093") = .ok [hex "fd7f008000"] := by decide

/-- H173: random#04 OP_NUMNOTEQUAL 8388609 1 — script 0401008000519e (policy: default) -/
example : runPol default (hex "0401008000519e") = .ok [hex "01"] := by decide

/-- H174: random#05 OP_GREATERTHAN 0 2147483647 — script 0004ffffff7fa0 (policy: default) -/
example : runPol default (hex "0004ffffff7fa0") = .ok [hex ""] := by decide

/-- H175: random#06 OP_NUMEQUALVERIFY -1514117293 -1065129650 — script 04ad983fda04b2967cbf9d (policy: default) -/
example : runPol default (hex "04ad983fda04b2967cbf9d") = .error .numEqualVerifyFailed := by decide

/-- H176: random#07 OP_MAX 168943085 -1 — script 04eddd110a4fa4 (policy: default) -/
example : runPol default (hex "04eddd110a4fa4") = .ok [hex "eddd110a"] := by decide

/-- H177: random#08 OP_MAX -417920206 -1 — script 04cef4e8984fa4 (policy: default) -/
example : runPol default (hex "04cef4e8984fa4") = .ok [hex "81"] := by decide

/-- H178: random#09 OP_NUMEQUAL 1554473998 255 — script 040e64a75c02ff009c (policy: default) -/
example : runPol default (hex "040e64a75c02ff009c") = .ok [hex ""] := by decide

/-- H179: random#10 OP_GREATERTHANOREQUAL 2 -2 — script 520182a2 (policy: default) -/
example : runPol default (hex "520182a2") = .ok [hex "01"] := by decide

/-- H180: random#11 OP_NUMEQUALVERIFY -647767065 -1 — script 0419249ca64f9d (policy: default) -/
example : runPol default (hex "0419249ca64f9d") = .error .numEqualVerifyFailed := by decide

/-- H181: random#12 OP_NUMNOTEQUAL 2 -395461297 — script 5204b14292979e (policy: default) -/
example : runPol default (hex "5204b14292979e") = .ok [hex "01"] := by decide

/-- H182: random#13 OP_GREATERTHAN 16 127 — script 60017fa0 (policy: default) -/
example : runPol default (hex "60017fa0") = .ok [hex ""] := by decide

/-- H183: random#14 OP_NUMEQUALVERIFY -1 8388608 — script 4f04000080009d (policy: default) -/
example : runPol default (hex "4f04000080009d") = .error .numEqualVerifyFailed := by decide

/-- H184: random#15 OP_LESSTHANOREQUAL 2147483646 1711578893 — script 04feffff7f040d9f0466a1 (policy: default) -/
example : runPol default (hex "04feffff7f040d9f0466a1") = .ok [hex ""] := by decide

/-- H185: random#16 OP_ADD -1 -1974420093 — script 4f047d42aff593 (policy: default) -/
example : runPol default (hex "4f047d42aff593") = .ok [hex "7e42aff5"] := by decide

/-- H186: random#17 OP_GREATERTHANOREQUAL 774230818 819537179 — script 0422d3252e041b25d930a2 (policy: default) -/
example : runPol default (hex "0422d3252e041b25d930a2") = .ok [hex ""] := by decide

/-- H187: random#18 OP_GREATERTHANOREQUAL 1785005355 32768 — script 042b05656a03008000a2 (policy: default) -/
example : runPol default (hex "042b05656a03008000a2") = .ok [hex "01"] := by decide

/-- H188: random#19 OP_NUMNOTEQUAL 627597302 20 — script 04f65f682501149e (policy: default) -/
example : runPol default (hex "04f65f682501149e") = .ok [hex "01"] := by decide

/-- I189: randomUnary#00 OP_1ADD 32767 — script 02ff7f8b (policy: default) -/
example : runPol default (hex "02ff7f8b") = .ok [hex "008000"] := by decide

/-- I190: randomUnary#01 OP_NEGATE 8388607 — script 03ffff7f8f (policy: default) -/
example : runPol default (hex "03ffff7f8f") = .ok [hex "ffffff"] := by decide

/-- I191: randomUnary#02 OP_1ADD -1232362086 — script 04665a74c98b (policy: default) -/
example : runPol default (hex "04665a74c98b") = .ok [hex "655a74c9"] := by decide

/-- I192: randomUnary#03 OP_NOT -2147483650 — script 05020000808091 (policy: default) -/
example : runPol default (hex "05020000808091") = .error .scriptNum := by decide

/-- I193: randomUnary#04 OP_NOT 128 — script 02800091 (policy: default) -/
example : runPol default (hex "02800091") = .ok [hex ""] := by decide

/-- I194: randomUnary#05 OP_1SUB 255 — script 02ff008c (policy: default) -/
example : runPol default (hex "02ff008c") = .ok [hex "fe00"] := by decide

/-- I195: randomUnary#06 OP_1SUB 14 — script 5e8c (policy: default) -/
example : runPol default (hex "5e8c") = .ok [hex "0d"] := by decide

/-- I196: randomUnary#07 OP_1ADD 18 — script 01128b (policy: default) -/
example : runPol default (hex "01128b") = .ok [hex "13"] := by decide

/-- J197: WITHIN 5 in [1,10) — script 55515aa5 (policy: default) -/
example : runPol default (hex "55515aa5") = .ok [hex "01"] := by decide

/-- J198: WITHIN 1 in [1,10) — script 51515aa5 (policy: default) -/
example : runPol default (hex "51515aa5") = .ok [hex "01"] := by decide

/-- J199: WITHIN 10 in [1,10) — script 5a515aa5 (policy: default) -/
example : runPol default (hex "5a515aa5") = .ok [hex ""] := by decide

/-- J200: WITHIN 0 in [1,10) — script 00515aa5 (policy: default) -/
example : runPol default (hex "00515aa5") = .ok [hex ""] := by decide

/-- J201: WITHIN 11 in [1,10) — script 5b515aa5 (policy: default) -/
example : runPol default (hex "5b515aa5") = .ok [hex ""] := by decide

/-- J202: WITHIN -5 in [-10,10) — script 0185018a5aa5 (policy: default) -/
example : runPol default (hex "0185018a5aa5") = .ok [hex "01"] := by decide

/-- J203: WITHIN 5 in [10,1) — script 555a51a5 (policy: default) -/
example : runPol default (hex "555a51a5") = .ok [hex ""] := by decide

/-- J204: WITHIN 5 in [5,5) — script 555555a5 (policy: default) -/
example : runPol default (hex "555555a5") = .ok [hex ""] := by decide

/-- J205: WITHIN 0 in [-1,1) — script 004f51a5 (policy: default) -/
example : runPol default (hex "004f51a5") = .ok [hex "01"] := by decide

/-- J206: randomWithin#00 -2147483646 in [-245213561,1222795951) — script 04feffffff0479a99d8e04af62e248a5 (policy: default) -/
example : runPol default (hex "04feffffff0479a99d8e04af62e248a5") = .ok [hex ""] := by decide

/-- J207: randomWithin#01 0 in [1402014544,32767) — script 0004500b915302ff7fa5 (policy: default) -/
example : runPol default (hex "0004500b915302ff7fa5") = .ok [hex ""] := by decide

/-- K208: randomMinimal#00 OP_BOOLOR 8388608 32768 — script 0400008000030080009b (policy: MINIMALDATA) -/
example : runPol minPol (hex "0400008000030080009b") = .ok [hex "01"] := by decide

/-- K209: randomMinimal#01 OP_SUB 19 2 — script 01135294 (policy: MINIMALDATA) -/
example : runPol minPol (hex "01135294") = .ok [hex "11"] := by decide

/-- K210: randomMinimal#02 OP_BOOLAND 16 -409500224 — script 6004407a68989a (policy: MINIMALDATA) -/
example : runPol minPol (hex "6004407a68989a") = .ok [hex "01"] := by decide

/-- K211: randomMinimal#03 OP_NUMEQUALVERIFY 1403136866 -2147483647 — script 04622ba25304ffffffff9d (policy: MINIMALDATA) -/
example : runPol minPol (hex "04622ba25304ffffffff9d") = .error .numEqualVerifyFailed := by decide

/-- K212: randomMinimal#04 OP_NUMEQUALVERIFY 258 2147483646 — script 02020104feffff7f9d (policy: MINIMALDATA) -/
example : runPol minPol (hex "02020104feffff7f9d") = .error .numEqualVerifyFailed := by decide

/-- K213: randomMinimal#05 OP_NUMNOTEQUAL -2 -2147483650 — script 01820502000080809e (policy: MINIMALDATA) -/
example : runPol minPol (hex "01820502000080809e") = .error .scriptNum := by decide

/-- K214: randomMinimal#06 OP_NUMNOTEQUAL 174624089 2147483645 — script 04598d680a04fdffff7f9e (policy: MINIMALDATA) -/
example : runPol minPol (hex "04598d680a04fdffff7f9e") = .ok [hex "01"] := by decide

/-- K215: randomMinimal#07 OP_LESSTHAN 32768 -16889958 — script 030080000466b801819f (policy: MINIMALDATA) -/
example : runPol minPol (hex "030080000466b801819f") = .ok [hex ""] := by decide

/-! ## Axiom footprint audit — kept in the file for reproducibility.
Standard trio only (no sorryAx, no native_decide axiom leaks) -/

#print axioms BitcoinProofs.Property.Y07.Arith.runPol

end BitcoinProofs.Property.Y07.Arith
