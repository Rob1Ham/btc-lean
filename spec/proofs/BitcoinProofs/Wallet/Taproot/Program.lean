import Bitcoin.Wallet.Taproot.Commit

/-!
# Wallet Taproot program proofs

The structural Taproot program facts are proved in the core package at
`Bitcoin.Wallet.Taproot.Commit`: they need only the executable
consensus definitions (`Bitcoin.Interpreter.Defs`,
`Bitcoin.Crypto.Taproot.Verify`) and no Mathlib.  This module re-exports
those facts under the proofs-package namespace and pins their axiom
footprints, so downstream wallet proofs have a single import for the
program-equality surface.

No new mathematical content is introduced.  In particular the named
proposition `Bitcoin.Wallet.Taproot.W1_taprootSpendJudged` remains a
target: the consensus commitment verifier now compares the recomputed
output key with its `program` argument (Core
`src/script/interpreter.cpp:1913-1925`, model `Verify.checkTapTweak`),
but the capstone still routes the whole v1 lane to `unjudgedTaproot`
(`Bitcoin/Wallet/Taproot/Commit.lean` module note).

## What is not modeled

* The secp256k1 tweak-add comparison is not re-proved here; this module
  consumes the core model's `outputKeyOk`/`tweakPoint` chain unchanged.
* No consensus claim is strengthened and no contract or interpreter
  definition is modified.
* Nothing here proves that a wallet-produced Taproot spend is accepted
  by consensus; that is the W1 target, stated separately.
-/

namespace BitcoinProofs.Wallet.Taproot

open Bitcoin.Data (Script)
open Bitcoin.Wallet.Taproot
open Bitcoin.Crypto.Taproot.Verify (scriptPathSpend)

/-- `programMatches` is Boolean-sound and complete: it is true exactly
when the spent scriptPubKey's v1 program is the supplied program. -/
theorem programMatches_true_iff (spk : Script) (program : ByteArray) :
    programMatches spk program = true ↔ ProgramMatches spk program :=
  programMatches_eq_true_iff spk program

/-- A canonical 34-byte v1 scriptPubKey decomposes to the 32-byte
program payload. -/
theorem programOf_v1_34_payload (spk : Script)
    (h0 : (spk.bytes.get! 0).toNat = 0x51)
    (h1 : (spk.bytes.get! 1).toNat = 32)
    (hsz : spk.bytes.size = 34) :
    programOf spk = some (1, spk.bytes.extract 2 spk.bytes.size) ∧
      (spk.bytes.extract 2 spk.bytes.size).size = 32 :=
  ⟨programOf_v1_34 spk h0 h1 hsz, programOf_v1_34_size spk hsz⟩

/-- On a 34-byte v1 scriptPubKey, program equality is exactly equality
with the trailing 32-byte payload. -/
theorem programMatches_v1_34_true_iff (spk : Script) (program : ByteArray)
    (h0 : (spk.bytes.get! 0).toNat = 0x51)
    (h1 : (spk.bytes.get! 1).toNat = 32)
    (hsz : spk.bytes.size = 34) :
    programMatches spk program = true ↔
      spk.bytes.extract 2 spk.bytes.size = program :=
  programMatches_v1_34_iff spk program h0 h1 hsz

/-- An accepted commitment binds its `program` argument to the recomputed
output key: Core's `q.CheckTapTweak` comparison. -/
theorem commitmentOf_program_binding
    (control program leafScript : ByteArray)
    (h : commitmentOf control program leafScript = true) :
    committedProgram control leafScript = some program :=
  Bitcoin.Wallet.Taproot.commitmentOf_program_binding
    control program leafScript h

/-- An accepted script-path arm binds its `program` argument likewise. -/
theorem scriptPathSpend_program_binding
    (control leafScript program : ByteArray) (tl : ByteArray) (ts : Bool)
    (h : scriptPathSpend control leafScript program = some (tl, true, ts)) :
    committedProgram control leafScript = some program :=
  Bitcoin.Wallet.Taproot.scriptPathSpend_program_binding
    control leafScript program tl ts h

#print axioms programMatches_true_iff
#print axioms programOf_v1_34_payload
#print axioms programMatches_v1_34_true_iff
#print axioms commitmentOf_program_binding
#print axioms scriptPathSpend_program_binding

end BitcoinProofs.Wallet.Taproot
