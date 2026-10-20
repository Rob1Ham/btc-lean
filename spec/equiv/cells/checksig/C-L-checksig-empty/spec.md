---
# Cell checksig/C-L-checksig-empty
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 4d62a97e551082a69b13f495365bff0a903b0c99
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: checksig/C-L-checksig-empty
family: checksig
tool_status: both-green (narrow empty-signature/error-ordinal cell)
precondition: |
  - base sigversion; flags = 0; amount = 0; input_index = 0; one input.
  - empty signature (`vchSig.size() == 0`) and a 33-byte pubkey.
  - the ECDSA checker is the shared same-crypto model: it returns false for
    the empty signature on both legs. No DER/sighash/pubkey-encoding logic is
    modeled.
  - closed functions; no script parsing, no transaction context.
postcondition: |
  - `cell_checksig_empty`: OP_CHECKSIG pushes `vchFalse` (empty vector):
    packed observable 0x0000000000000101 (result=1, error=0, depth=1,
    top length=0, top value=0).
  - `cell_checksigverify_empty`: OP_CHECKSIGVERIFY fails with Core ordinal
    14 (SCRIPT_ERR_CHECKSIGVERIFY): packed observable
    0x0000000000000038 (result=0, error=14, depth=0).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-109
scr_row_coverage: >-
  partial — only the empty-signature push-false arm and the
  CHECKSIGVERIFY error ordinal 14 are modeled. The checker is a shared model
  returning false for the empty signature, not a proof of Core/libsecp or
  rbitcoin crypto. DER (SCR-102/103), LOW_S (SCR-104), STRICTENC
  (SCR-105/106), WITNESS_PUBKEYTYPE (SCR-107), NULLFAIL (SCR-110), sighash
  (SCR-111), pubkey-failure continuation (SCR-112) and CHECKMULTISIG
  (SCR-114..121) are not covered; their rows remain gaps/seams.
patches: none
source_citations:
  - interpreter.cpp:331-355 (EvalChecksigPreTapscript empty-sig path)
  - interpreter.cpp:120-160 (CheckSignatureEncoding; empty sig accepted)
  - spec/core/Bitcoin/Interpreter/Defs.lean:720-739
    (evalChecksigPreTapscript)
  - spec/core/Bitcoin/Interpreter/Defs.lean:784-793 (evalChecksigDispatch)
  - contract/error_kind.h line 43 (EQUIV_ERR_CHECKSIGVERIFY = 14)
trust_note: >-
  The L leg is a REVIEWED TRANSLITERATION of the Lean empty-signature result,
  not a generated twin handler: twin/ops_ir.py has no real CHECKSIG body.
  The C leg is a narrow source-excerpt slice. The cell is conditional on
  same-crypto and on the empty-signature checker model; it is evidence-tier,
  not a Lean-kernel theorem and not a green SCR-109 row. The E3 role's fuller
  attempt, if any, supersedes this note only with its own evidence.
---

# checksig/C-L-checksig-empty

Fallback E3 attempt built by the orchestrator while the E3 role runs. It
proves only a narrow pair of closed functions:

- empty signature -> `vchFalse` (Core `OP_CHECKSIG`);
- empty signature under `OP_CHECKSIGVERIFY` -> error ordinal 14.

The same-crypto checker is a model that returns false for the empty signature
on both legs. This is deliberately not a DER, sighash, NULLFAIL, or checker
equivalence proof. The row remains `partial` in the ledger, not green.
