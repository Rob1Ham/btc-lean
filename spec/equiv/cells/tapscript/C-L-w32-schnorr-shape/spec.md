---
# Cell tapscript/C-L-w32-schnorr-shape
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
lean_model_rev: 4d62a97e551082a69b13f495365bff0a903b0c99
legs: C, L
r_leg: "not attempted: no tapscript Schnorr cell on the pinned rbitcoin lane; IR not Alive2-ingestable (F-TOOL-001)"
cell: C-L-w32-schnorr-shape
family: tapscript
tool_status: both-green (Alive2 symbolic over the bounded domain; SAW concrete scenarios)
precondition: |
  - One call to GenericTransactionSignatureChecker::CheckSchnorrSignature
    (interpreter.cpp:1726-1752) as reached from EvalChecksigTapscript under
    SigVersion::TAPSCRIPT. The empty-signature/empty-pubkey triage that
    precedes this call is the sibling C-L-w32-pubkey-triage cell.
  - sigversion is pinned to TAPSCRIPT (2): the only value the caller passes
    (interpreter.cpp:379-382). The Lean adapter also accepts TAPROOT; the
    guard at RealChecker.lean:122 is therefore discharged by the caller,
    not exercised here.
  - The pubkey is an x-only 32-byte key. interpreter.cpp:1731 asserts
    pubkey_in.size() == 32; a different pk_len is OUT OF CONTRACT, and both
    legs return the same out-of-domain sentinel. pk triage is cell 2.
  - The signature element is symbolic in length 0..255 and in its first
    five bytes; sig_last is a separate symbolic byte that stands for byte 64
    of a 65-byte signature. Bytes 5..63 of a 64/65-byte signature are not
    representable in the cell ABI; they reach the tail unchanged in both
    legs (same element, same body slice), and the tail's verdict is the one
    shared external symbol, so their value cannot distinguish the legs.
  - The shared tail symbol btc_equiv_schnorr_tail is unconstrained: Alive2
    quantifies over one verdict per call; SAW pins it to 0 and to 47.
postcondition: |
  Observable (src/tap_common.h, `tp_pack(ok, err, 0, 0)`):
    bit 0 eval_ok, bits 1..6 error ordinal. This is a signature-checker
    verdict, so no stack element is produced.
  - sig length not in {64, 65}: (0, SCHNORR_SIG_SIZE=45), regardless of
    bytes and of sig_last.                            [interpreter.cpp:1736]
  - sig length 64: hashtype is the implicit SIGHASH_DEFAULT (0), sig_last is
    ignored, and the body is the whole element. The shared tail is called
    with (body, 0, 64, TAPSCRIPT); tail 0 -> (1, 0); otherwise
    (0, tail).                                        [1739-1749]
  - sig length 65 and sig_last = 0x00: (0,
    SCHNORR_SIG_HASHTYPE=46), and the tail is NOT called: SIGHASH_DEFAULT is
    implicit only.                                    [1741-1744]
  - sig length 65 and sig_last != 0x00: the trailing byte is popped and the
    body is bytes 0..63; the tail is called with (body, sig_last, 65,
    TAPSCRIPT); tail 0 -> (1, 0); otherwise (0, tail). [1739-1749]
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-161, SCR-162
scr_row_coverage: full
coverage: full
patches: none
source_citations:
  - "script/interpreter.cpp:1726-1752 (CheckSchnorrSignature)"
  - "script/interpreter.cpp:1729 (assert sigversion TAPROOT/TAPSCRIPT)"
  - "script/interpreter.cpp:1731 (assert pubkey_in.size() == 32, caller-enforced)"
  - "script/interpreter.cpp:1736 (sig.size() != 64 && != 65 -> SCHNORR_SIG_SIZE)"
  - "script/interpreter.cpp:1739-1740 (hashtype = SIGHASH_DEFAULT)"
  - "script/interpreter.cpp:1741-1744 (SpanPopBack; explicit 0x00 -> SCHNORR_SIG_HASHTYPE)"
  - "script/interpreter.cpp:1745-1749 (SignatureHashSchnorr / VerifySchnorr, abstract tail)"
  - "spec/core/Bitcoin/Capstone/RealChecker.lean:119-142 (checkSchnorrForInput)"
  - "spec/core/Bitcoin/Crypto/Seam/Entry.lean:156-161 (schnorrHashtype)"
  - "contract/error_kind.h:45,46 (SCHNORR_SIG_SIZE, SCHNORR_SIG_HASHTYPE)"
trust_note: >
  SAME-CRYPTO/SAME-SIGHASH CONDITION: both legs call the one external symbol
  btc_equiv_schnorr_tail with the same (body, hashtype, length, sigversion)
  encoding. Alive2's same-symbol model quantifies over its return and SAW
  pins it to 0 or 47. Nothing here proves BIP340, BIP341, secp256k1,
  SignatureHashSchnorr or SHA256 agreement; the tail's availability checks,
  hashtypeValid (SCR-163), htSingle bound, annex/leaf-hash checks and
  verifyImpl are all inside that shared symbol and are not claimed.

  The C leg is a line-cited source slice of interpreter.cpp at the pin
  (asserts at 1729/1731 are caller contracts, not error paths). The L leg is
  a REVIEWED TRANSLITERATION of RealChecker.lean:119-142 and Entry.lean:
  156-161; the repo's generated twin/ops_ir.py has no tapscript handler.
  Lean's sv guard throws ExecError.schnorrSig for a non-taproot/non-tapscript
  sv; the cell pins sv to TAPSCRIPT in both legs because that is the only
  value the caller produces, so the C assert has no observable counterpart.

  SAW is a concrete-scenario corroboration; Alive2 is the symbolic
  bounded-domain equivalence evidence (length and trailing byte fully
  symbolic). Neither proves the interpreter's caller loop, the sighash
  preimage, the tapscript OP_SUCCESSx pre-scan, or witness parsing.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
mutant: "in C: accept any size != 64 (drop the 65 arm), or treat an explicit 0x00 hashtype as SIGHASH_DEFAULT and continue; in L: return success for the 0x00 trailing byte; expect Alive2/SAW to fail"
mutant_site: "src/c_tap.cpp core_schnorr_shape / src/l_tap.cpp lean_schnorr_shape"
---

# Cell `tapscript/C-L-w32-schnorr-shape`

## Row coverage

| SCR | Branches exercised | Status |
|---|---|---|
| SCR-161 (`else SCHNORR_SIG_SIZE`) | signature length symbolic over 0..255: both in-range lengths (64, 65) and every out-of-range length; SAW also closes 0,1,2,3,4,5,6,31,32,63,66,67,127,128,255 and confirms payload bytes and `sig_last` do not affect the size gate | full |
| SCR-162 (`SIGHASH_DEFAULT` invalid as an explicit byte) | for length 65 the trailing byte is symbolic over 0..255: 0x00 -> `SCHNORR_SIG_HASHTYPE` (46) with no tail call; every non-zero byte reaches the tail; SAW closes 0x01,0x02,0x03,0x41,0x81,0x83,0xFF against both tail verdicts; a 64-byte signature with the same `sig_last` values is unaffected (implicit default) | full |

The Alive2 entry takes the length, the trailing byte and the payload bytes
symbolically, so no branch is covered only by a closed witness. SAW's
scenarios are corroboration against `src/oracle.py`, which is written from
the SCR rows and the Core source, not from either leg.

## What this cell does and does not establish

Established, in both directions, for the bounded element ABI:

* the size gate (64/65 in range, everything else 45);
* the SIGHASH_DEFAULT split: implicit for 64 bytes, forbidden as an
  explicit trailing byte for 65 bytes (46, before any tail work);
* that a 65-byte signature enters the tail with the popped hashtype and a
  64-byte body, while a 64-byte signature enters it with hashtype 0 and
  itself as the body.

Not established here: everything the shared tail symbol abstracts
(`hashtypeValid`, `htSingle` bounds, spent-output/annex/leaf-hash
availability, `sighashTaproot`, `verifyImpl`). Those are SCR-163/165 and the
crypto/hash rows, and they are named as a premise above.

## Reproduce

```sh
cd spec/equiv/cells/tapscript/C-L-w32-schnorr-shape
./alive2/run.sh
./saw/run.sh
cd /tmp/opencode/wave32/28-tapscript-156-162
sha256sum -c spec/equiv/cells/tapscript/C-L-w32-schnorr-shape/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/tapscript/C-L-w32-schnorr-shape/saw/certificate.sha256
```
