/-
  Wave64 / 41-div-w32-p2sh-cleanstack
  Concrete Lean probe for finding F-DIV-W32-01, using the *same byte tapes*
  that the Core probe (`witness/core_probe.cpp`) executes through the real
  pinned `VerifyScript`.

  Tapes (Core hex output from `core_probe`):

    P2SH-P2WPKH
      scriptSig   160014adfce54f529b2154e3c361bbe3f7d41db0635717
      scriptPubKey a914173727a17ada832a0fd90be6c628f63598b3400f87
      redeem       0014adfce54f529b2154e3c361bbe3f7d41db0635717
      witness      [ <dummy sig>, 02 || 32*0x11 ]

    P2SH-P2WSH
      scriptSig   2200204ae81572f06e1b88fd5ced7a1a000945432e83e1551e6f721ee9c00b8cc33260
      scriptPubKey a91472c44f957fc011d97e3406667dca5b1c930c402687
      redeem       0020 4ae81572...3260
      witness      [0x51]                     (witnessScript = OP_TRUE)

    Bare P2WPKH (control: the arm the model does resize)
      scriptSig    (empty)
      scriptPubKey 0014adfce54f529b2154e3c361bbe3f7d41db0635717
      witness      [ <dummy sig>, 02 || 32*0x11 ]

  Core accepts all three under SCRIPT_VERIFY_P2SH|WITNESS|CLEANSTACK.
  The Lean model is expected to accept only the bare one.
-/
import Bitcoin.Interpreter.Defs

open Bitcoin.Interpreter
open Bitcoin.Crypto.Seam (stubChecker SigVersion)
open Bitcoin.Numeric (castToBool)

def tchk : ScriptChecker := ⟨stubChecker, default, none⟩

def hexVal (c : Char) : Nat :=
  if '0' ≤ c ∧ c ≤ '9' then c.toNat - '0'.toNat
  else if 'a' ≤ c ∧ c ≤ 'f' then c.toNat - 'a'.toNat + 10
  else 0

def unhex (s : String) : ByteArray :=
  let rec go (acc : ByteArray) : List Char → ByteArray
    | a :: b :: rest => go (acc.push (UInt8.ofNat (hexVal a * 16 + hexVal b))) rest
    | _ => acc
  go ByteArray.empty s.toList

def reps (n : Nat) (b : UInt8) : ByteArray :=
  (List.replicate n b).foldl (fun acc x => acc.push x) ByteArray.empty

def pk : ByteArray := (ByteArray.mk #[0x02]) ++ reps 32 0x11

-- P2SH-P2WPKH
def redeemWPKH : ByteArray := unhex "0014adfce54f529b2154e3c361bbe3f7d41db0635717"
def ssWPKH : ByteArray := unhex "160014adfce54f529b2154e3c361bbe3f7d41db0635717"
def spkWPKH : ByteArray := unhex "a914173727a17ada832a0fd90be6c628f63598b3400f87"
def witWPKH : Bitcoin.Data.WitnessStack := [ByteArray.mk #[0x30, 0x01, 0x01], pk]

-- P2SH-P2WSH (witnessScript = OP_TRUE, so SHA256(witnessScript) is below)
def redeemWSH : ByteArray :=
  unhex "00204ae81572f06e1b88fd5ced7a1a000945432e83e1551e6f721ee9c00b8cc33260"
def ssWSH : ByteArray :=
  unhex "2200204ae81572f06e1b88fd5ced7a1a000945432e83e1551e6f721ee9c00b8cc33260"
def spkWSH : ByteArray := unhex "a91472c44f957fc011d97e3406667dca5b1c930c402687"
def witWSH : Bitcoin.Data.WitnessStack := [ByteArray.mk #[0x51]]

-- Bare P2WPKH
def spkBare : ByteArray := unhex "0014adfce54f529b2154e3c361bbe3f7d41db0635717"

-- Plain (non-witness) P2SH control: redeem = OP_TRUE
def redeemPlain : ByteArray := unhex "51"
def ssPlain : ByteArray := unhex "0151"
def spkPlain : ByteArray := unhex "a914da1745e9b549bd0bfa1a569971c77eba30cd5a4b87"

def fl : Bitcoin.Activation.ScriptFlags := { p2sh := true, witness := true }
def polCS : PolicyFlags := { cleanstack := true }
def polNoCS : PolicyFlags := { cleanstack := false }

def outcome (o : VerifyOutcome) : String :=
  match o with
  | .ok => "OK"
  | .fail e => s!"FAIL {repr e}"
  | .unjudged => "UNJUDGED"

-- Sanity: the tapes are the ones Core ran.
#eval s!"pk hash160 = {repr (hashHash160 pk)}"
#eval s!"spkWPKH isWitnessProgram = {repr (isWitnessProgram spkWPKH)}"
#eval s!"redeemWPKH isWitnessProgram = {repr (isWitnessProgram redeemWPKH)}"
#eval s!"redeemWSH isWitnessProgram = {repr (isWitnessProgram redeemWSH)}"

-- The inner redeem-script evaluation that `finalLen` recomputes.
#eval s!"eval redeemWPKH on [] length = \
  {(match evalScriptBytes 64 fl polCS redeemWPKH [] tchk .base default with
    | .ok s => s.length | .error _ => 999)}"
#eval s!"eval redeemWSH on [] length = \
  {(match evalScriptBytes 64 fl polCS redeemWSH [] tchk .base default with
    | .ok s => s.length | .error _ => 999)}"

-- p2shInner itself (witness verification) succeeds on both wrapped tapes.
#eval s!"p2shInner WPKH = {outcome (p2shInner 64 fl polCS ssWPKH [redeemWPKH] witWPKH tchk)}"
#eval s!"p2shInner WSH  = {outcome (p2shInner 64 fl polCS ssWSH [redeemWSH] witWSH tchk)}"

-- The divergence: wrapped witness + cleanstack.
#eval s!"verifyScriptFull P2SH-P2WPKH cleanstack=true  = {outcome (verifyScriptFull 64 fl polCS ssWPKH spkWPKH witWPKH tchk)}"
#eval s!"verifyScriptFull P2SH-P2WSH  cleanstack=true  = {outcome (verifyScriptFull 64 fl polCS ssWSH spkWSH witWSH tchk)}"
-- Controls.
#eval s!"verifyScriptFull P2SH-P2WPKH cleanstack=false = {outcome (verifyScriptFull 64 fl polNoCS ssWPKH spkWPKH witWPKH tchk)}"
#eval s!"verifyScriptFull P2SH-P2WSH  cleanstack=false = {outcome (verifyScriptFull 64 fl polNoCS ssWSH spkWSH witWSH tchk)}"
#eval s!"verifyScriptFull BARE-P2WPKH  cleanstack=true  = {outcome (verifyScriptFull 64 fl polCS ByteArray.empty spkBare witWPKH tchk)}"
#eval s!"verifyScriptFull P2SH-plain   cleanstack=true  = {outcome (verifyScriptFull 64 fl polCS ssPlain spkPlain [] tchk)}"
