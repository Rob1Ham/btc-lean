import Bitcoin.Interpreter.Defs

/-! Wave32 scratch probe (NOT part of the repo, lives in /tmp):
concrete evaluation of `verifyScriptFull` on a P2SH-wrapped P2WPKH spend
under CLEANSTACK.  Expected Core behaviour (interpreter.cpp:2069-2101 +
2110-2118): VerifyWitnessProgram succeeds, then `stack.resize(1)`, then the
CLEANSTACK check sees size 1 and passes. -/

open Bitcoin.Interpreter
open Bitcoin.Crypto.Seam (stubChecker SigVersion)
open Bitcoin.Numeric (castToBool)

def tchk : ScriptChecker := ⟨stubChecker, default, none⟩

def reps (n : Nat) (b : UInt8) : ByteArray :=
  (List.replicate n b).foldl (fun acc x => acc.push x) ByteArray.empty

def pk : ByteArray := (ByteArray.mk #[0x02]) ++ reps 32 1

/-- Redeem script = v0 P2WPKH program: OP_0 <20-byte keyhash>. -/
def redeem : ByteArray := ByteArray.mk #[0x00, 0x14] ++ hashHash160 pk

/-- scriptSig = single direct push of the 22-byte redeem script. -/
def ss : ByteArray := ByteArray.mk #[0x16] ++ redeem

/-- scriptPubKey = HASH160 <hash160(redeem)> EQUAL. -/
def spk : ByteArray :=
  ByteArray.mk #[0xa9, 0x14] ++ hashHash160 redeem ++ ByteArray.mk #[0x87]

def fl : Bitcoin.Activation.ScriptFlags := { p2sh := true, witness := true }
def pol : PolicyFlags := { cleanstack := true }
def wit : Bitcoin.Data.WitnessStack := [ByteArray.mk #[0x01], pk]

#eval repr (verifyScriptFull 64 fl pol ss spk wit tchk)
#eval (match verifyScriptFull 64 fl pol ss spk wit tchk with
       | .ok => "OK"
       | .fail e => s!"FAIL {repr e}"
       | .unjudged => "UNJUDGED")
