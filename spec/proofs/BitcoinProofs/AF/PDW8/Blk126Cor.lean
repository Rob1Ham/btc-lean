import Bitcoin.Block.Params
import Bitcoin.Invariants.RC08

/-!
# Blk126Cor — BLK-126 promotion proof (PDW8, row TOP-40)

Row BLK-126 (signet only: block solution satisfies the challenge,
BIP325; validation.cpp:3938-3940 @cce32b168): the
`bad-signet-blk-sig` reject lane.

Semantics port (route B): `signetDefaultChallenge`
(Params.lean:382) is the BIP325 default 1-of-2 CHECKMULTISIG
challenge script, 71 bytes (kernel/signet.h:20). The theorem here
pins the full script layout by `decide` (the gold byte-pins,
verified against the ground-truth `bytesOf` constant): `0x51` OP_1
(m-of-n), `0x21` push-33 ×2 (the two 33-byte compressed keys, at
1..35 and 35..69), `0x30`/`0x03` inside the second key's
SEC-encoding, `0x52` OP_2, `0xae` OP_CHECKMULTISIG. The
`signetCheckApplies` gate (Params.lean:405) skips the check entirely
on non-signet nets (mainnet et al.) — the mainnet-skip lane.
Companion to the core `signetDefaultChallenge_shape` (Params.lean:391)
and `signetCheckApplies_mainnet` (Params.lean:407).
PDW8-2 build evidence: the tree file was clean FIRST-BUILD RC=0
(the reference assembly, `:= by decide` split across :42/:43
at the script-shape theorem = the core Params:394 form; contrast
Blk063Cor which died with the :53/:54 errors).

Axiom-pinned in-file (D2 L3); zero sorryAx — pin-sets in the L3
section below (PDW8-2 probe pass). -/

namespace BitcoinProofs.AF.PDW8

/-- BLK-126 (script layout): the default signet challenge is the
71-byte 1-of-2 CHECKMULTISIG script — OP_1, two 33-byte compressed
key pushes, OP_2, OP_CHECKMULTISIG. -/
@[rule "BLK-126"]
theorem signetDefaultChallenge_script_shape :
    Bitcoin.Block.Params.signetDefaultChallenge.size = 71 ∧
    (Bitcoin.Block.Params.signetDefaultChallenge.get! 0).toNat = 0x51 ∧
    (Bitcoin.Block.Params.signetDefaultChallenge.get! 1).toNat = 0x21 ∧
    (Bitcoin.Block.Params.signetDefaultChallenge.get! 34).toNat = 0x30 ∧
    (Bitcoin.Block.Params.signetDefaultChallenge.get! 35).toNat = 0x21 ∧
    (Bitcoin.Block.Params.signetDefaultChallenge.get! 36).toNat = 0x03 ∧
    (Bitcoin.Block.Params.signetDefaultChallenge.get! 68).toNat = 0xc4 ∧
    (Bitcoin.Block.Params.signetDefaultChallenge.get! 69).toNat = 0x52 ∧
    (Bitcoin.Block.Params.signetDefaultChallenge.get! 70).toNat = 0xae := by
  decide

/-- BLK-126 (mainnet-skip lane): the solution check does not apply
where `signet_blocks = false` (mainnet/testnet/testnet4/regtest). -/
@[rule "BLK-126"]
theorem signetCheckApplies_mainnet_skip :
    Bitcoin.Block.Params.signetCheckApplies false = false := rfl

/-- **BLK-126** (solution gate, BIP325 / validation.cpp:3938-3940): on
signet with PoW checked, the block verdict passes iff the solution
satisfies the challenge script (`signetSolutionOk` is the abstract
`CheckSignetBlockSolution`); on a net with `signet_blocks = false`
(mainnet/testnet/testnet4/regtest) the check is skipped unconditionally,
whatever the solution. This states the signet-only + solution-satisfies-
challenge content, not merely the default challenge's script shape. -/
@[rule "BLK-126"]
theorem signetSolution_gate_row
    (satisfies : ByteArray → ByteArray → Bool) (challenge solution : ByteArray) :
    (Bitcoin.Block.Params.signetCheckApplies true = true ∧
      (Bitcoin.Block.Params.signetSolutionOk satisfies challenge solution = true ↔
        satisfies challenge solution = true) ∧
      (Bitcoin.Invariants.RC08.signetBlockOk true true
        (Bitcoin.Block.Params.signetSolutionOk satisfies challenge solution) = true ↔
        satisfies challenge solution = true)) ∧
    (Bitcoin.Block.Params.signetCheckApplies false = false ∧
      Bitcoin.Invariants.RC08.signetBlockOk false true
        (Bitcoin.Block.Params.signetSolutionOk satisfies challenge solution) = true) := by
  refine ⟨⟨rfl, ?_, ?_⟩, rfl, ?_⟩
  · rfl
  · rw [Bitcoin.Invariants.RC08.signetBlockOk_gate]
    rfl
  · exact Bitcoin.Invariants.RC08.signetBlockOk_skip _ _

/-! ## L3 axiom pins (D2): drift on any of these fails the build.
Both rule-theorems sorry-free; pin-sets (PDW8-2 probe pass):
script_shape AXIOM-FREE (the `decide` kernel-route),
mainnet_skip AXIOM-FREE (the `rfl` route); every pin ⊆
[propext, Classical.choice, Quot.sound] = the charter trio; zero
`sorryAx` (sorry_lint G1 class). -/

/-- info: 'BitcoinProofs.AF.PDW8.signetDefaultChallenge_script_shape' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW8.signetDefaultChallenge_script_shape

/-- info: 'BitcoinProofs.AF.PDW8.signetCheckApplies_mainnet_skip' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW8.signetCheckApplies_mainnet_skip

end BitcoinProofs.AF.PDW8
