import Bitcoin.Crypto.Taproot.Sighash

/-!
# PDW17CheckM2 — sorry-free / axiom-footprint check (items TOP-81..85, part A)

PDW17 (proof-promotion review, recovery RC21/RC22), 2026-10-17.
Claim `4d864b8` (me-2). v2.1: renamed PDW17Check.lean ->
PDW17CheckM2.lean (F-PDW28-003 twin-path conflict: me-1's
PDW17Check.lean @e717653 restored verbatim to the shared path;
this me-2 file = my 4d864b8-claim B-verify, attrs unchanged).
PDW15Check / PDW11Check pattern (imports
FIRST — F-PDW2-001 repair; module doc AFTER imports). Items:
TPR-046, TPR-040, TPR-041 (part A, this file) — the
PDW18-registered 81..85 c-true THM-on-target head (0e4e305) =
the PD02-F-PD02-002 22-THM-on-target class, X03-U3 e904215 +
TAGFIX ad6d4f3 tag-on-target, X03-retry dormant since 04:32.
The lean_target is already an `@[rule]`-tagged sorry-free core
theorem (Sighash.lean:331/:409/:400); promotion route = B-verify
(this file: name resolution + sorry-free via `#print axioms`
g3-guarded) + rules.yaml status flip (+ drift-fix none). NOT
in the BIP30R-5 ripple/frozen paths (Crypto/Taproot/Sighash.lean
= 0 hits for applyTxStep/badTxnsBIP30/bip30Collision/
bip30BlockCollision, grep-verified at claim @ef81ecf).

Expected lines = the probe1 pass-1 output verbatim
(probe1.lean, direct-lean RC=0 16:4x UTC; the
bare `#print axioms` capture = the in-file gallery pins
Sighash.lean:585/:606/:603 = the same three lines).
All three: the full charter trio `[propext, Classical.choice,
Quot.sound]` (Classical.choice via the `Option`/`getD`
fail-closed seam; the Sighash.lean 26-theorem gallery pins all
⊆ the trio). ZERO `sorryAx` (file sorry-scan: doc-words only).

Elaborated + built with (foreground; direct-lean root?? NO —
proofs package env (this file lives in the proofs tree =
BitcoinProofs.AF.PDW17.PDW17CheckM2); own-target flock lake
build RC=0):
  cd ./spec/proofs && lake env lean \
    BitcoinProofs/AF/PDW17/PDW17CheckM2.lean
-/

namespace PDW17CheckM2

/-! ## A. TPR-046 — `Bitcoin.Crypto.Taproot.sighashTaproot_size`
(Crypto/Taproot/Sighash.lean:331, `@[rule "TPR-046"]`; the
BIP341 digest-32 law: `sighashTaproot env inPos ht sv d = some
m → m.size = 32` (the epoch ‖ SigMsg through the TapSighash
tagged hash). The row face "BIP341 message + sub-hashes use
single SHA256 (no double)" = the construction pinned
structurally by the epoch def-mirror TPR-032 (PDW19 f216df2) +
the tagged-hash unfold TPR-047 (PDW15 b6f7064) —
`taggedHash tagTapSighash (serU8 0 ++ m)` = ONE SHA256 over the
doubled tag (interpreter.cpp:1466 `HASHER_TAPSIGHASH`), the
no-double = the `taggedHash`-vs-`dshaL` seam split (X02);
reject lanes (bad hashtype TPR-030 / SINGLE-no-output TPR-042)
= none-the-face. NO namespace drift (ns
`Bitcoin.Crypto.Taproot` @ Sighash.lean:84 = the yaml
lean_target verbatim). -/

/-- info: 'Bitcoin.Crypto.Taproot.sighashTaproot_size' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms Bitcoin.Crypto.Taproot.sighashTaproot_size

/-! ## B. TPR-040 — `Bitcoin.Crypto.Taproot.acpSlice_acp`
(Crypto/Taproot/Sighash.lean:409, `@[rule "TPR-040"]`; the ACP
ANYONE-CAN-PAY input-slice law (interpreter.cpp:1547-1550):
`htAcp ht = true ∧ inPos < env.spentOutputs.length →
acpSlice env inPos ht = some (serOutPoint
(env.tx.vin.getD inPos dummyTxIn).prevout ++ serTxOut
(env.spentOutputs.getD inPos dummyTxOut) ++ serU32
(env.tx.vin.getD inPos dummyTxIn).sequence)` = `outpoint ‖ full
prevout (amount ‖ scriptPubKey) ‖ nSequence` verbatim; the
spent-outputs cache = Core's `m_spent_outputs`. The cache-miss
`none`-lane = the frozen fail-closed seam face (NOT the row
face). NO drift. -/

/-- info: 'Bitcoin.Crypto.Taproot.acpSlice_acp' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms Bitcoin.Crypto.Taproot.acpSlice_acp

/-! ## C. TPR-041 — `Bitcoin.Crypto.Taproot.acpSlice_notACP`
(Crypto/Taproot/Sighash.lean:400, `@[rule "TPR-041"]`; the
¬ACP input-index law (interpreter.cpp:1552): `htAcp ht = false
→ acpSlice env inPos ht = some (serU32 inPos.toUInt32)` = the
empty prevout-slice side, the 4-byte LE input index the ONLY
input data (the BIP341≠BIP143 divergence rides the ¬ACP-lane
sub-hash commitment = TPR-037, not this face). The
`htAcp = ht && 0x80`-mask law = the TPR-030 classifier lane
(NOT the row face). NO drift. -/

/-- info: 'Bitcoin.Crypto.Taproot.acpSlice_notACP' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms Bitcoin.Crypto.Taproot.acpSlice_notACP

end PDW17CheckM2
