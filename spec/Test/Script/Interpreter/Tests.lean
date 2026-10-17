import Bitcoin.Interpreter.Interface

/-!
# W09 unit tests — script interpreter (Bitcoin.Interpreter.Defs)

Every check is a build-time `example … := by decide` (kernel-reduced) or
`native_decide` (compiler-reduced; confined to this Test-scoped file per
the D2 L1 gate — used where kernel ByteArray evaluation, e.g. the pure
SHA-256/RIPEMD-160 implementations in `Bitcoin.Interpreter.Hashes`,
would exceed the heartbeat budget).

Layout mirrors the W12/W13 `spec/Test/` convention (`run.sh` drives
`lake env lean` from `spec/core`). Coverage:

* pure hash defs — FIPS 180-4 / Dobbertin vectors on the real ByteArray
  path (`Hashes.lean`, SCR-094/095);
* opcode semantics — pushes, arithmetic, IF/ELSE/ENDIF, VERIFY, EQUAL,
  stack ops, altstack, CODESEPARATOR, disabled opcodes
  (SCR-046/065/087-091/096/152/170);
* signature-encoding layers around the frozen EC seam — DER/LOW_S/
  STRICTENC/WITNESS_PUBKEYTYPE + NULLFAIL (SCR-102/104-108/110);
* CLTV/CSV gate algebra against the LocktimeEnv (SCR-122-131);
* end-to-end `verifyScriptFull` — P2SH, CLEANSTACK, SIGPUSHONLY, bare
  P2WPKH / P2WSH witness spends with the stub checker (SCR-001-013/133-138);
* the proven STACK_SIZE theorem instances (SCR-029/030).
-/

namespace Test.Script.Interpreter.Tests

open Bitcoin.Interpreter Bitcoin.Activation Bitcoin.Crypto.Seam

set_option maxRecDepth 10000
set_option maxHeartbeats 4000000

/-! ## Helpers -/

/-- Hex digit value (test-only). -/
def hexDigitVal (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
  else if 65 ≤ n ∧ n ≤ 70 then some (n - 55)
  else none

/-- Hex decode (test-only). -/
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

def hex (s : String) : ByteArray := fromHex s

-- core 4.35 has no DecidableEq Except (W12 note); derive it test-locally
deriving instance DecidableEq for Except

/-- No consensus flags. -/
def noflags : ScriptFlags := { p2sh := false }

/-- CLTV+CSV active (the buried-deployment consensus set). -/
def cflags : ScriptFlags := { cltv := true, csv := true }

/-- The corpus checker: frozen stub EC/Schnorr seam + default
transaction environment (version 1, nLockTime 0, nSequence FINAL). -/
def tchk : ScriptChecker := ⟨stubChecker, default⟩

/-- Checker with spendable locktime gates: nVersion ≥ 2 and a
non-FINAL input sequence (Core returns false for CLTV/CSV otherwise). -/
def chk2 : ScriptChecker := ⟨stubChecker, { txSequence := 4, txVersion := 2 }⟩

/-- Run a script from empty stack, base sigversion, no flags. -/
def run (b : ByteArray) (fuel : Nat := 64) : Except ExecError Stack :=
  evalScriptBytes fuel noflags default b [] tchk .base default

/-- Run a script from a given initial stack. -/
def runFrom (st0 : Stack) (b : ByteArray) (fuel : Nat := 64) :
    Except ExecError Stack :=
  evalScriptBytes fuel noflags default b st0 tchk .base default

/-- n repeated bytes. -/
def reps (n : Nat) (u : UInt8) : ByteArray :=
  ByteArray.mk (List.replicate n u).toArray

/-! ## Hashes (native_decide: kernel ByteArray SHA-256 is heartbeat-bound) -/

example : hashSha256 ("".toUTF8) =
    hex "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" := by native_decide

example : hashSha256 ("abc".toUTF8) =
    hex "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" := by native_decide

example : hashSha1 ("".toUTF8) =
    hex "da39a3ee5e6b4b0d3255bfef95601890afd80709" := by native_decide

example : hashRipemd160 ("abc".toUTF8) =
    hex "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc" := by native_decide

example : hashHash160 ("".toUTF8) =
    hex "b472a266d0bd89c13706a4132ccfb16f7c3b9fcb" := by native_decide

example : hashSha256d ("".toUTF8) =
    hex "5df6e0e2761359d30a8275058e299fcc0381534545f55cf43e41983f5d4c9456" := by native_decide

-- the op layer routes to the pure hash defs (SCR-093/094/095)
example : run (hex "00a8") = .ok [hex "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"] := by
  native_decide
example : run (hex "00a9") = .ok [hex "b472a266d0bd89c13706a4132ccfb16f7c3b9fcb"] := by
  native_decide
example : run (hex "00aa") = .ok [hex "5df6e0e2761359d30a8275058e299fcc0381534545f55cf43e41983f5d4c9456"] := by
  native_decide

/-! ## Push + arithmetic semantics (decide) -/

-- OP_1 OP_2 OP_ADD => 0x03 (SCR-088)
example : run (hex "515293") = .ok [hex "03"] := by decide

-- OP_0 pushes the empty string; OP_16 pushes 0x10 (SCR-046)
example : run (hex "00") = .ok [ByteArray.empty] := by decide
example : run (hex "60") = .ok [hex "10"] := by decide

-- OP_1NEGATE
example : run (hex "4f") = .ok [hex "81"] := by decide

-- 1SUB / NEGATE / ABS / NOT / 0NOTEQUAL / SUB (SCR-087)
example : run (hex "528c") = .ok [hex "01"] := by decide
example : run (hex "518f") = .ok [hex "81"] := by decide
example : run (hex "018190") = .ok [hex "01"] := by decide
example : run (hex "0091") = .ok [hex "01"] := by decide
example : run (hex "5192") = .ok [hex "01"] := by decide
example : run (hex "525394") = .ok [hex "81"] := by decide

-- BOOLAND / BOOLOR / MIN / MAX / WITHIN / LESSTHAN (SCR-088/089)
example : run (hex "00529a") = .ok [ByteArray.empty] := by decide
example : run (hex "00529b") = .ok [hex "01"] := by decide
example : run (hex "5253a3") = .ok [hex "02"] := by decide
example : run (hex "5253a4") = .ok [hex "03"] := by decide
example : run (hex "525253a5") = .ok [hex "01"] := by decide
example : run (hex "515253a5") = .ok [ByteArray.empty] := by decide
example : run (hex "52539f") = .ok [hex "01"] := by decide

-- NUMEQUAL numeric vs EQUAL raw bytes: ∅ and 0x00 differ raw, equal numeric (SCR-091)
example : run (hex "0001009c") = .ok [hex "01"] := by decide
example : run (hex "00010087") = .ok [ByteArray.empty] := by decide

-- NUMEQUALVERIFY on false => numEqualVerifyFailed (SCR-090)
example : run (hex "00529d") = .error .numEqualVerifyFailed := by decide

/-! ## Control flow -/

-- IF taken / ELSE skipped (SCR-056/060/064)
example : run (hex "516352675368") = .ok [hex "02"] := by decide
example : run (hex "006352675368") = .ok [hex "03"] := by decide

-- unexecuted branch ops are still disabled-checked (SCR-065/153)
example : run (hex "00637e68") = .error .disabledOpcode := by decide

-- unbalanced conditionals (SCR-061/062/063)
example : run (hex "67") = .error .unbalancedConditional := by decide
example : run (hex "5163") = .error .unbalancedConditional := by decide

-- VERIFY pops iff true (SCR-068)
example : run (hex "5169") = .ok [] := by decide
example : run (hex "0069") = .error .verifyFailed := by decide

-- OP_RETURN (SCR-069)
example : run (hex "6a") = .error .opReturn := by decide

-- disabled OP_CAT executed, OP_2DIV unexecuted-but-checked (SCR-152/153/170)
example : run (hex "7e") = .error .disabledOpcode := by decide
example : run (hex "8e") = .error .disabledOpcode := by decide

-- depth pre-checks (SCR-074)
example : run (hex "91") = .error .stackUnderflow := by decide
example : run (hex "75") = .error .stackUnderflow := by decide

-- DROP / 2DROP / DUP / OVER / NIP / SWAP
example : run (hex "525375") = .ok [hex "02"] := by decide
example : run (hex "52536d") = .ok [] := by decide
example : run (hex "5176") = .ok [hex "01", hex "01"] := by decide
example : run (hex "525378") = .ok [hex "02", hex "03", hex "02"] := by decide
example : run (hex "525377") = .ok [hex "03"] := by decide
example : run (hex "52537c") = .ok [hex "02", hex "03"] := by decide

-- PICK / ROLL (SCR-075)
example : run (hex "52535179") = .ok [hex "02", hex "03", hex "02"] := by decide
example : run (hex "5253517a") = .ok [hex "02", hex "03"] := by decide

-- SIZE pushes the minimal CScriptNum encoding of the length (SCR-076)
example : run (hex "02ab8282") = .ok [hex "02", hex "ab82"] := by decide

-- IF DUP (SCR-077)
example : run (hex "5173") = .ok [hex "01", hex "01"] := by decide
example : run (hex "0073") = .ok [ByteArray.empty] := by decide

-- TOALTSTACK / FROMALTSTACK move semantics (SCR-073)
example : run (hex "526b6c") = .ok [hex "02"] := by decide
example : run (hex "6c") = .error .invalidAltstackOperation := by decide

-- CODESEPARATOR executes as a no-op on the stack (SCR-096/097)
example : run (hex "51ab") = .ok [hex "01"] := by decide

-- upgradable NOPs pass by default (SCR-071/072)
example : run (hex "b9") = .ok [] := by decide

-- OP_VER: badOpcode executed, passes unexecuted (SCR-066)
example : run (hex "62") = .error .badOpcode := by decide
example : run (hex "00636268") = .ok [] := by decide

-- MINIMALDATA: non-minimal push rejected, fExec-gated (SCR-048/049)
example : evalScriptBytes 64 noflags { minimalData := true } (hex "0101") [] tchk
    .base default = .error .minimalData := by decide
example : evalScriptBytes 64 noflags { minimalData := true } (hex "0063010168") [] tchk
    .base default = .ok [] := by decide

-- op-count budget: 202 executed NOPs => opCount (SCR-022/113)
example : run (ByteArray.mk (List.replicate 202 (0x61 : UInt8)).toArray) 256
    = .error .opCount := by native_decide

/-! ## Signature encoding layers (around the frozen EC seam) -/

-- empty sig bypasses DER checks; CHECKSIG pushes FALSE (SCR-108/109)
-- (stack head = top: pk on top, sig below — Core stacktop(-2)/(-1))
example : runFrom [hex "02abab", ByteArray.empty] (hex "ac")
    = .ok [ByteArray.empty] := by
  native_decide

-- CHECKSIG with the stub checker (non-empty sig + non-empty pk => TRUE)
example : runFrom [hex "02abab", hex "01"] (hex "ac") = .ok [hex "01"] := by
  native_decide

-- CHECKSIGVERIFY on a failed check (empty sig) => checkSigVerify
example : runFrom [hex "02abab", ByteArray.empty] (hex "ad")
    = .error .checkSigVerify := by
  native_decide

-- non-DER sig under DERSIG => sigDer (SCR-102)
example : isValidSigEncoding (hex "0102") = false := by decide
example : (checkSigEncoding { dersig := true } default (hex "0102")).isSome := by decide

-- low-S: S = 0x7fff passes, S = 31×0xff fails (SCR-104)
def sigLowS : ByteArray := hex "30080202010002027fff"
def sigHighS : ByteArray := hex "302902020100021f" ++ reps 31 0xff

example : checkLowS sigLowS = true := by decide
example : checkLowS sigHighS = false := by decide
example : (checkSigEncoding noflags { lowS := true } (sigHighS ++ hex "01")).isSome := by
  decide

-- hashtype byte defined (SCR-105)
example : isDefinedHashtype (hex "0101") = true := by decide
example : isDefinedHashtype (hex "0105") = false := by decide

-- pubkey encoding: 33B 02-prefixed ok; 05-prefixed rejected under STRICTENC (SCR-106)
example : checkPubKeyEncoding noflags default .base
    (hex "02" ++ reps 32 0) = none := by decide
example : (checkPubKeyEncoding noflags { strictEnc := true } .base
    (hex "05" ++ reps 32 0)).isSome := by decide

-- WITNESS_PUBKEYTYPE forces compression under witnessV0 (SCR-107)
example : (checkPubKeyEncoding noflags { witnessPubkeyType := true } .witnessV0
    (hex "04" ++ reps 64 0)).isSome := by decide
example : checkPubKeyEncoding noflags { witnessPubkeyType := true } .tapscript
    (hex "04" ++ reps 64 0) = none := by decide

-- NULLFAIL: failed check (empty pk) with non-empty sig (SCR-110)
example : (evalChecksigPreTapscript noflags { nullFail := true } tchk default
    .base 0 (hex "00") (hex "01") ByteArray.empty) = .error .sigNullFail := by
  native_decide

-- policy-flag string parsing (corpus column)
example : (parsePolicyFlags "NULLFAIL,WITNESS_PUBKEYTYPE").nullFail := by native_decide
example : (parsePolicyFlags "NULLFAIL,WITNESS_PUBKEYTYPE").witnessPubkeyType := by native_decide
example : (parsePolicyFlags "NULLFAIL").cleanstack = false := by native_decide

/-! ## CLTV / CSV gates -/

-- CLTV: operand stays on the stack; 0 <= 0 passes with a spendable input (SCR-124/125)
example : evalScriptBytes 64 cflags default (hex "b1") [ByteArray.empty] chk2
    .base default = .ok [ByteArray.empty] := by decide

-- negative operand => NEGATIVE_LOCKTIME at the op layer (SCR-122)
example : evalScriptBytes 64 cflags default (hex "b1") [hex "81"] chk2
    .base default = .error .negativeLocktime := by decide

-- unsatisfied: operand 7 > txLockTime 0 (SCR-124)
example : evalScriptBytes 64 cflags default (hex "57b1") [ByteArray.empty] chk2
    .base default = .error .unsatisfiedLocktime := by decide

-- CSV: operand disable flag (bit 31) => plain NOP, operand stays (SCR-127)
example : evalScriptBytes 64 cflags default (hex "050500008000b2") [] chk2
    .base default = .ok [hex "0500008000"] := by decide

-- FINAL input sequence makes the locktime unsatisfiable (interpreter.cpp:1784)
example : checkLockTimeDef default 0 = false := by decide
example : checkLockTimeDef { txLockTime := 5, txSequence := 4 } 0 = true := by decide
example : checkLockTimeDef { txLockTime := 5, txSequence := 4 } 7 = false := by decide

-- domain split: time-domain operand vs height-domain locktime (SCR-123)
example : checkLockTimeDef { txLockTime := 499999999, txSequence := 4 } 500000000 = false := by decide
example : checkLockTimeDef { txLockTime := 500000000, txSequence := 4 } 500000000 = true := by decide

-- CSV: nVersion < 2 => false (interpreter.cpp:1795); input disable flag => false
example : checkSequenceDef default 3 = false := by decide
example : checkSequenceDef { txVersion := 2, txSequence := 0x80000005 } 5 = false := by decide

-- CSV: mask 0x0040ffff; type flag must match (SCR-129/130/131)
example : checkSequenceDef { txVersion := 2, txSequence := 3 } 3 = true := by decide
example : checkSequenceDef { txVersion := 2, txSequence := 3 } 4 = false := by decide
example : checkSequenceDef { txVersion := 2, txSequence := 3 } 0x00400003 = false := by decide
example : checkSequenceDef { txVersion := 2, txSequence := 0x00400003 } 0x00400003 = true := by decide

/-! ## End-to-end VerifyScript -/

-- sequential eval: scriptSig 1, spk 2+ADD => truthy top (SCR-001/002)
example : verifyScriptFull 64 noflags default (hex "51") (hex "5293") [] tchk
    = .ok := by decide

-- empty script evaluates to success with the stack unchanged (SCR-003)
example : evalScriptBytes 64 noflags default ByteArray.empty [hex "07"] tchk
    .base default = .ok [hex "07"] := by decide

-- truthy single element vs empty spk (SCR-004)
example : verifyScriptFull 64 noflags default (hex "51") ByteArray.empty [] tchk
    = .ok := by decide

-- falsy top => EVAL_FALSE
example : verifyScriptFull 64 noflags default (hex "00") ByteArray.empty [] tchk
    = .fail .evalFalse := by decide
example : verifyScriptFull 64 noflags default ByteArray.empty (hex "00") [] tchk
    = .fail .evalFalse := by decide

-- P2SH: ss pushes the 1-byte OP_1 redeem; spk = HASH160<0x51> EQUAL (SCR-005/012)
def redeem51 : ByteArray := hex "51"
def p2shSpk : ByteArray :=
  ByteArray.mk #[0xa9, 0x14] ++ hashHash160 redeem51 ++ ByteArray.mk #[0x87]

example : verifyScriptFull 64 { p2sh := true } default (hex "01" ++ redeem51)
    p2shSpk [] tchk = .ok := by native_decide

example : verifyScriptFull 64 { p2sh := true } default (hex "01" ++ hex "00")
    p2shSpk [] tchk = .fail .evalFalse := by native_decide

-- SIGPUSHONLY: non-push scriptSig rejected pre-eval (SCR-006/010)
example : verifyScriptFull 64 noflags { sigPushOnly := true } (hex "93")
    ByteArray.empty [] tchk = .fail .sigPushOnly := by decide

-- CLEANSTACK: leftover stack after spk eval (SCR-008)
example : verifyScriptFull 64 noflags { cleanstack := true } (hex "5152")
    ByteArray.empty [] tchk = .fail .cleanstack := by decide

-- witness present but spk is not a witness program => WITNESS_UNEXPECTED (SCR-013)
example : verifyScriptFull 64 { witness := true } default (hex "51")
    (hex "52") [hex "01"] tchk = .fail .witnessUnexpected := by decide

-- bare P2WPKH with the stub checker: implied script checks hash160(pk) (SCR-136/138)
def wpk : ByteArray := hex "02" ++ reps 32 1
def p2wpkhSpk : ByteArray :=
  ByteArray.mk #[0x00, 0x14] ++ hashHash160 wpk

example : verifyScriptFull 64 { witness := true } default ByteArray.empty
    p2wpkhSpk [hex "01", wpk] tchk = .ok := by native_decide

-- wrong P2WPKH program: the implied script's EQUALVERIFY fails (SCR-135/136).
-- (the program bytes are themselves evaluated as the spk, so they must be
-- CastToBool-true to reach the witness branch — as in Core)
example : verifyScriptFull 64 { witness := true } default ByteArray.empty
    (ByteArray.mk #[0x00, 0x14] ++ reps 20 1)
    [hex "01", wpk] tchk = .fail .equalVerifyFailed := by native_decide

-- v0 program of length 21 => WITNESS_PROGRAM_WRONG_LENGTH (SCR-137)
example : verifyScriptFull 64 { witness := true } default ByteArray.empty
    (ByteArray.mk #[0x00, 0x15] ++ reps 21 1)
    [hex "01", wpk] tchk = .fail .witnessProgramWrongLength := by native_decide

-- P2WSH: program = sha256(witnessScript); script consumes the data item (SCR-133/138)
def wshScript : ByteArray := hex "5175"   -- OP_1 OP_DROP
def p2wshSpk : ByteArray :=
  ByteArray.mk #[0x00, 0x20] ++ hashSha256 wshScript

example : verifyScriptFull 64 { witness := true } default ByteArray.empty
    p2wshSpk [hex "07", wshScript] tchk = .ok := by native_decide

-- empty witness for a witness program => WITNESS_PROGRAM_WITNESS_EMPTY (SCR-134)
example : verifyScriptFull 64 { witness := true } default ByteArray.empty
    p2wshSpk [] tchk = .fail .witnessProgramWitnessEmpty := by native_decide

-- witness program shape detection (SCR-053/054/055)
example : isWitnessProgram (ByteArray.mk #[0x00, 0x14] ++ reps 20 7)
    = some (0, reps 20 7) := by decide
example : isWitnessProgram (ByteArray.mk #[0x51, 0x20] ++ reps 32 7)
    = some (1, reps 32 7) := by decide
example : isWitnessProgram (ByteArray.mk #[0x00, 0x10] ++ reps 20 7) = none := by decide
example : isWitnessProgram (ByteArray.mk #[0x00, 0x4c, 0x14] ++ reps 20 7) = none := by decide

-- v1 2-byte 0x4e73 program (P2A): success without execution (SCR-150)
example : verifyScriptFull 64 { witness := true, taproot := true } default
    ByteArray.empty (ByteArray.mk #[0x51, 0x02, 0x4e, 0x73]) [] tchk
    = .ok := by decide

-- v2 program: upgradable success (SCR-151)
example : verifyScriptFull 64 { witness := true } default ByteArray.empty
    (ByteArray.mk #[0x52, 0x14] ++ reps 20 1) [] tchk = .ok := by decide

-- SCRIPT_SIZE: a 10001-byte base script fails pre-parse (SCR-018)
def bigScript : ByteArray := reps 10001 0x51

example : evalScriptBytes 4 noflags default bigScript [] tchk .base default
    = .error .scriptSize := by
  native_decide

-- tapscript is exempt from the 10k guard (SCR-019): parse succeeds, fuel is
-- what stops it (unknownError, not scriptSize)
example : evalScriptBytes 4 noflags default bigScript [] tchk .tapscript default
    = .error .unknownError := by
  native_decide

/-! ## STACK_SIZE (SCR-029/030) -/

-- 1001-element stack (1000-item initial stack + one DUP) => stackSize
example : evalScriptBytes 8 noflags default (hex "76")
    (List.replicate 1000 (hex "01")) tchk .base default = .error .stackSize := by
  native_decide

-- theorem instance: success at any fuel => final stack within the cap
example (fuel : Nat) (b : ByteArray) (st0 : Stack) (st' : Stack)
    (h0 : st0.length ≤ MAX_STACK_SIZE)
    (h : evalScriptBytes fuel noflags default b st0 tchk .base default = .ok st') :
    st'.length ≤ MAX_STACK_SIZE :=
  evalScriptBytes_ok_stack_bound h0 st' h

/-! ## Axiom pins (mirrored in scripts/axiom_probe.lean / the manifest) -/

#guard_msgs (drop info) in #print axioms Bitcoin.Interpreter.stepChecked_ok_bound
#guard_msgs (drop info) in #print axioms Bitcoin.Interpreter.evalFrom_ok_stack_bound
#guard_msgs (drop info) in #print axioms Bitcoin.Interpreter.evalFrom_succ_ok
#guard_msgs (drop info) in #print axioms Bitcoin.Interpreter.evalFrom_fuel_mono
#guard_msgs (drop info) in #print axioms Bitcoin.Interpreter.finalStack_isOk_iff
#guard_msgs (drop info) in #print axioms Bitcoin.Interpreter.finalStack_ok
#guard_msgs (drop info) in #print axioms Bitcoin.Interpreter.evalScriptBytes_ok_stack_bound
#guard_msgs (drop info) in #print axioms Bitcoin.Interpreter.evalScriptBytes_fuel_mono

end Test.Script.Interpreter.Tests
