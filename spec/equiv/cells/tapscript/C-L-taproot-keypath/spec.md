---
# Cell tapscript/C-L-taproot-keypath
cell: C-L-taproot-keypath
family: tapscript
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (symbolic dispatch over a shared abstract Schnorr checker)
precondition: |
  - Cell seam: the key-path arm after the annex strip,
    interpreter.cpp:1970-1975.
  - Witness is a native v1-32 non-P2SH spend with SCRIPT_VERIFY_TAPROOT set;
    any annex has already been removed (sibling cell C-L-taproot-annex).
  - `stack_n` = number of post-annex witness items, arbitrary 64-bit.
  - `sig_id` identifies the single item (the signature candidate);
    `program_key_id` identifies the 32-byte x-only output key. They are passed
    to the shared checker unchanged.
  - The checker is the single external symbol in checker_abi.h. Its
    (ok, error) result is the same-crypto premise; BIP340 itself is not
    modelled or proved.
  - No sighash, no transaction context, no script execution.
postcondition: |
  - Packed observable result(2) | error_ordinal(6) << 2.
  - stack_n = 1:
      checker rejects with ordinal e -> (0, e), passed through unchanged
        (Core :1972-1973 returns false with serror set by the checker)
      checker accepts           -> (1, 0)  (Core :1975 set_success)
  - stack_n != 1 -> (2, 0) script path, a sibling cell's subject.
  - The cell proves that both legs call the shared checker with the same
    arguments (sig_id, program_key_id, TAPROOT=2, key_len=32) and that the
    verdict/error is passed through without reinterpretation.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-144
scr_row_coverage: |
  full (conditional on the same-crypto premise P12 in
  spec/equiv/docs/TRUST-BASE.md and docs/DECISION-lax-ecdsa.md). The row's
  dispatch claim is exercised completely: exactly one post-annex item takes
  the key-path arm, zero or more than one do not, the checker is called with
  the single signature and the 32-byte output key at SigVersion::TAPROOT, and
  the outcome is exactly the checker's (success on accept, the checker's own
  error ordinal on reject). BIP340/libsecp verification is abstract, not
  proved; the row is promoted only under the declared same-crypto premise.
patches: none
source_citations:
  - "interpreter.cpp:1970 (if (stack.size() == 1))"
  - "interpreter.cpp:1972 (checker.CheckSchnorrSignature(stack.front(), program, SigVersion::TAPROOT, execdata, serror))"
  - "interpreter.cpp:1973 (return false; serror is set)"
  - "interpreter.cpp:1975 (return set_success(serror))"
  - "interpreter.h:201-206 (SigVersion::TAPROOT = 2)"
  - "interpreter.h:240 (WITNESS_V1_TAPROOT_SIZE = 32)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1190-1193 (schnorrOutcome)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1298 (checkSchnorrWithContext chk stack[0]! program .taproot ed)"
  - "spec/core/Bitcoin/Interpreter/Rules.lean:388-398 (verifyWitnessProgram_keypath)"
  - "spec/core/Bitcoin/Crypto/Seam/Interface.lean:119-125 (SigVersion.taproot)"
  - "spec/equiv/docs/TRUST-BASE.md P12 (crypto same on all legs)"
  - "docs/DECISION-lax-ecdsa.md (crypto seam boundary)"
trust_note: >
  SAME-CRYPTO CONDITION: both legs declare and call the one external symbol
  btc_equiv_check_schnorr with the same arguments (single item id, 32-byte
  output-key id, sigversion 2, key length 32). Alive2 ingests a bare
  declaration in both modules, so equal arguments return the same value; its
  return is annotated noundef (a C uint32_t return is never poison). SAW links
  one shared checker stub into both legs and pins it to success and to a
  SCHNORR_SIG rejection. Nothing here proves BIP340 or libsecp256k1; this is
  the proof-level counterpart of the same-crypto premise. C is a line-cited
  source slice; L is a reviewed transliteration of the Lean
  verifyWitnessProgram key-path arm and schnorrOutcome (the twin has no
  VerifyWitnessProgram handler). No Core source patch is used.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
mutant: >
  Proposed, not executed: in l_leg.cpp swap the accept/reject mapping so a
  checker rejection returns (1,0) and acceptance returns (0,47). Expected
  Alive2 counterexample on stack_n=1 and a SAW proof failure for both checker
  builds.
mutant_site: "cells/tapscript/C-L-taproot-keypath/l_leg.cpp l_keypath, schnorrOutcome mapping"
---

# `tapscript/C-L-taproot-keypath`

## What is proved

`cell_keypath(stack_n, sig_id, program_key_id)` is symbolic in all three
arguments. Both legs:

1. take the key-path arm exactly when `stack_n == 1` (Core :1970);
2. call the shared external checker with the single item, the 32-byte output
   key, `SigVersion::TAPROOT` (2) and key length 32 (:1972);
3. return success on acceptance and pass the checker's own error ordinal
   through on rejection (:1973-1975, Lean `schnorrOutcome`).

Alive2 is run `--bidirectional` over the external declaration, so it also
proves the two legs pass identical arguments. SAW links a shared stub into
both modules, once returning success and once returning
`SCRIPT_ERR_SCHNORR_SIG` (47).

## What is not proved

- BIP340 verification, x-only key parsing or libsecp256k1 internals. The
  checker is the same-crypto premise.
- Sighash construction and the signature's byte-level validity.
- The script-path arm (`stack_n != 1`); that is
  `C-L-taproot-scriptpath-dispatch`.

## Why `full` is conditional

SCR-144's claim is the key-path dispatch and the binding of the one item to
the 32-byte output key. Both are proved. The cryptographic check is abstract,
so the row is promoted only under P12: the checker is assumed to agree on both
legs. If the orchestrator requires a concrete BIP340 witness, this cell is the
dispatch half and a crypto-witness cell would be additional.

## Exact commands

```sh
bash spec/equiv/cells/tapscript/C-L-taproot-keypath/alive2/run.sh
bash spec/equiv/cells/tapscript/C-L-taproot-keypath/saw/run.sh
sha256sum -c spec/equiv/cells/tapscript/C-L-taproot-keypath/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/tapscript/C-L-taproot-keypath/saw/certificate.sha256
```
