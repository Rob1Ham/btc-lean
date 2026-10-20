# E3 report — CHECKSIG / CHECKMULTISIG, symbolic checker, error enums

**Role:** E3 (integrated by orchestrator; all results below are from the
checked-in cell runners).
**Date:** 2026-10-19
**Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
**Contract:** v3 `f1841e36…` (recipe in `contract/tape.md` §10).
**Tools:** Alive2 v20.0, SAW 1.6, pinned clang 20.1.2.

## Cells

| Cell | Rows | Alive2 | SAW | Coverage |
|---|---|---|---|---|
| `cells/e3-checksig/C-L-checksig-dispatch` | SCR-109, SCR-112 | green | green (12/12) | partial |
| `cells/e3-cms/C-L-cms-1of1` | SCR-114, 116, 118, 119, 120 | green (4/4) | green (16/16) | partial |
| `cells/checksig/C-L-checksig-empty` | SCR-109 | green (2/2) | green (4/4) | partial, narrow fallback |

The checksig cell uses three closed witnesses per leg. The checker is the
single external symbol `btc_equiv_check_sig`; Alive2 quantifies over its
verdict and SAW links one stub returning 0 and one returning 1. The C leg is
a line-cited source slice of `interpreter.cpp:331-369`,
`interpreter.cpp:397-413`, and `interpreter.cpp:1069-1092`; the L leg is a
reviewed transliteration of `Defs.lean:720-742`, `776-791`, `1033-1047`
(the twin has no real CHECKSIG handler).

The CMS cell is a 1-of-1 specialization of
`interpreter.cpp:1115-1225`, with the same shared checker. It exercises the
cleanup/dummy consumption, NULLDUMMY rejection, the empty-stack underflow, and
the CHECKMULTISIGVERIFY verdict. The L leg is a reviewed transliteration of
`Defs.lean:1071-1127`.

## Error-enum equality observed

| Path | Expected ordinal | Evidence |
|---|---:|---|
| CHECKSIG false then script tail | `EVAL_FALSE = 2` | checksig `cell_checksig`, packed `0x108` |
| OP_CHECKSIGVERIFY false | `CHECKSIGVERIFY = 14` | checksig `cell_checksigverify`, `0x38`; small fallback also `0x38` |
| OP_CHECKMULTISIGVERIFY false | `CHECKMULTISIGVERIFY = 13` | CMS `cell_cmsverify`, `0x34` |
| non-empty dummy + NULLDUMMY | `SIG_NULLDUMMY = 28` | CMS `cell_cms_nulldummy`, `0x70` |
| empty stack | `INVALID_STACK_OPERATION = 18` | CMS `cell_cms_empty`, `0x48` |
| CHECKSIG/CMS stack underflow | `INVALID_STACK_OPERATION = 18` | checksig underflow and CMS empty |

Both legs agree on every value. This is **error-map equality for the modeled
branches**, not a proof that Core, Lean, and rbitcoin share a complete error
enum.

## Honest limits

- **Partial rows.** The checksig cell proves the push-false/pass mechanism
  conditional on the checker verdict; it does not prove that the real ECDSA
  checker returns false for an empty/invalid signature. The CMS cell does not
  prove general `nKeys/nSigs ∈ [0,20]`, multi-signature order/early failure,
  FindAndDelete, DER/LOW_S/STRICTENC/NULLFAIL, hashtype, or tapscript
  CHECKSIGADD. Ledger rows remain gaps/seams.
- **Same-crypto.** The checker is abstracted on both legs; see
  `docs/DECISION-lax-ecdsa.md`. No claim about libsecp256k1 internals.
- **R.** Not attempted for these cells: the pinned rbitcoin entry has a narrow
  error map and no typed `ScriptError` (`F-HARNESS-002`, `F-TOOL-001`;
  R-GAP-01..05).
- **Bounded.** Closed witnesses and a bounded leaf domain; no whole-engine
  `EvalScript`/`VerifyScript` proof.

## Mutation

`M-E3-008` mutated the reviewed L CMS handler's CHECKMULTISIGVERIFY return to
a different error ordinal. Alive2 failed on `cell_cmsverify` (source `0x34`
vs target `0x18`); SAW failed 5/16 proofs. Reverted and baseline restored:
Alive2 green, SAW 16/16. Raw run:
`cells/_redteam/runs/M-E3-008-e3-cell-20261019T230115Z.md`.
This is the passed E3 mutation test; it is also an error-enum mutation, so a
verdict-only cell would not have killed it.

No Core patch was used. No commits were made.
