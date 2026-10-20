---
# Cell tapscript/C-L-w32-tap-single-output
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
lean_model_rev: 4d62a97e551082a69b13f495365bff0a903b0c99
legs: C, L
cell: C-L-w32-tap-single-output
family: tapscript
tool_status: both-green (symbolic; all 8-bit hashtypes, all 32-bit indices/counts)
precondition: |
  - BIP341 SignatureHashSchnorr context; SigVersion TAPROOT or TAPSCRIPT
    (the single-output gate is version-independent).
  - hash_type is any 8-bit value; in_pos and vout_size are any 32-bit
    values.  vout.size() < 2^32 is physically forced by the serialization
    limits (a tx cannot carry 2^32 outputs), so the 32-bit model is the
    whole reachable domain.
  - The output-hash value itself is abstracted (SCR-169); only the
    existence gate is modelled.
postcondition: |
  - output_type = SIGHASH_ALL when hash_type == 0x00, else hash_type & 3.
  - output_type == SIGHASH_SINGLE (3) and in_pos >= vout_size: construction
    fails, packed as ok=0, err=SCHNORR_SIG_HASHTYPE (46).
  - output_type == SIGHASH_SINGLE and in_pos < vout_size: construction
    succeeds and the single-output hash is committed (ok=1, present=1).
  - Any other output type: construction succeeds, no single-output hash
    (ok=1, present=0), including when in_pos >= vout_size.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-166
scr_row_coverage: full — the row's edge (in_pos >= vout.size()) is
  evaluated over the whole reachable domain, both sides of the edge
  (equality included), for SINGLE and non-SINGLE hashtypes, and the
  SCHNORR_SIG_HASHTYPE mapping is part of the observable.
patches: none
source_citations:
  - "interpreter.cpp:1524 (output_type DEFAULT=>ALL / &3)"
  - "interpreter.cpp:1558-1566 (SINGLE output-existence gate)"
  - "interpreter.cpp:1747-1748 (construction failure => SCHNORR_SIG_HASHTYPE)"
  - "spec/core/Bitcoin/Crypto/Taproot/Sighash.lean:168,219-226 (htSingle, singleSlice)"
  - "spec/core/Bitcoin/Capstone/RealChecker.lean:131-132 (none => schnorrSigHashtype)"
  - contract/error_kind.h:87 (46)
trust_note: >
  C is a line-cited slice of SignatureHashSchnorr plus the checker's error
  mapping, not the function: the single-output hash computation and the
  rest of the preimage are abstracted (SCR-169).  L is a reviewed
  transliteration of the Lean singleSlice gate.  The packed observable is
  cell harness.  No hash or crypto claim is made; R is not attempted.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
mutant: "use `>` instead of `>=` in the existence gate; expect both tools to fail at in_pos == vout_size"
mutant_site: "src/c_leaf.cpp / src/l_leaf.cpp existence comparison"
---

# Cell `tapscript/C-L-w32-tap-single-output`

SCR-166: with SIGHASH_SINGLE, `interpreter.cpp:1559-1560`
(`if (in_pos >= tx_to.vout.size()) return false;`) makes the BIP341
construction fail, and `CheckSchnorrSignature` maps that to
`SCRIPT_ERR_SCHNORR_SIG_HASHTYPE`.

`cell_single_output` is symbolic in `(hash_type, in_pos, vout_size)` over
the whole reachable 32-bit domain, so both the equality edge and the
non-SINGLE case are covered. SAW checks each leg against the independent
Cryptol rule; Alive2 checks the C↔L pair.
