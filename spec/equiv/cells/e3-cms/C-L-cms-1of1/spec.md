---
# Cell e3-cms/C-L-cms-1of1
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 4d62a97e551082a69b13f495365bff0a903b0c99
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
r_leg: "not attempted: pinned rbitcoin render/error path is documented non-proof (F-HARNESS-002, F-TOOL-001); see notes.md"
cell: C-L-cms-1of1
family: checkmultisig
tool_status: both-green (bounded closed witnesses, 1-of-1 specialization)
precondition: |
  - Base sigversion (SigVersion::BASE), flags = 0 except where noted:
    DERSIG/LOW_S/STRICTENC/NULLFAIL/CONST_SCRIPTCODE are off, so
    CheckSignatureEncoding and CheckPubKeyEncoding accept in this cell.
  - Exactly one signature and one pubkey: nSigs = nKeys = 1. The numeric
    elements are built by the cell harness as OP_1; nKeys/nSigs range
    checks, decodeNum errors, and the nSigs > nKeys early-exit are outside
    the witness domain.
  - No CODESEPARATOR; scriptCode is the fixed two-byte sequence 0x41 0x42.
  - Witness scripts (closed, no symbolic stack bytes):
      cell_cms            stack bottom->top [<>, <0x41>, 1, <0x02>, 1],
                          OP_CHECKMULTISIG
      cell_cmsverify      same stack, OP_CHECKMULTISIGVERIFY then harness OP_1
      cell_cms_nulldummy  same stack but dummy = <0x55>,
                          OP_CHECKMULTISIG with the NULLDUMMY gate enabled
      cell_cms_empty      empty stack, OP_CHECKMULTISIG
  - Element length <= 1 byte; stack depth <= 5; bounded leaf domain.
  - The ECDSA verdict is the unconstrained return of the shared external
    btc_equiv_check_sig; that is the only nondeterminism Alive2 quantifies.
postcondition: |
  - cell_cms: checker false -> cleanup pops 4 (sig, nSigs, pubkey, nKeys),
    dummy popped, push vchFalse={} (len 0), script ends false => packed
    (result=0, error=EQUIV_ERR_EVAL_FALSE=2, depth=1, top len 0), 0x108.
    Checker true -> push vchTrue={1} => result=1, error=0, depth=1,
    top (len=1,val=1), packed 0x2901. Both legs equal.
  - cell_cmsverify: checker false => cleanup and dummy pop run, vchFalse is
    pushed, then the exact Core ordinal EQUIV_ERR_CHECKMULTISIGVERIFY=13 is
    returned (ABI failure packs result=0, error=13, empty stack), 0x34.
    Checker true => verdict popped; harness OP_1 yields result=1, error=0,
    0x2901.
  - cell_cms_nulldummy: NULLDUMMY on with a one-byte dummy (0x55) => after
    the same cleanup, EQUIV_ERR_SIG_NULLDUMMY=28, 0x70. No checker call.
  - cell_cms_empty: zero-element stack => EQUIV_ERR_INVALID_STACK_OPERATION
    =18, no pops, no checker call, 0x48.
  - On failure only (result, error_kind) is observable per contract/ABI.md v2;
    the cell packs an empty stack on error in both legs (Core mutates the
    stack before returning false; Lean's Except error carries no state).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-114, SCR-118, SCR-119, SCR-120
scr_row_coverage: partial
coverage: partial
patches: none
source_citations:
  - "interpreter.cpp:1115-1225 (OP_CHECKMULTISIG / OP_CHECKMULTISIGVERIFY)"
  - "interpreter.cpp:1122-1124 (i = 1 depth check), 1136-1138 (ikey depth check), 1143-1145 (isig depth check)"
  - "interpreter.cpp:1140-1142 (nSigs range; 1-of-1 witness fixes nSigs = 1)"
  - "interpreter.cpp:1152-1160 (per-sig FindAndDelete, base only; no-op for the fixed scriptCode)"
  - "interpreter.cpp:1171-1174 (encoding gates; flags = 0 in this cell)"
  - "interpreter.cpp:1177 (checker.CheckECDSASignature), 1194-1205 (cleanup pops), 1209-1212 (dummy + NULLDUMMY), 1215-1223 (bool push / CMSVERIFY ordinal)"
  - "interpreter.cpp:1876-1880 (EVAL_FALSE tail, via the cell finish harness)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:305-310 (vchTrue/vchFalse/pushBoolV)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:672-700 (cmsLoop, 1-of-1 arm)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:702-718 (cmsCleanup; nullFail false here)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1071-1127 (checkMultiSig; dummy and verify arms)"
  - "contract/error_kind.h:27,42,49,63 (EVAL_FALSE=2, CHECKMULTISIGVERIFY=13, INVALID_STACK_OPERATION=18, SIG_NULLDUMMY=28)"
trust_note: >
  SAME-CRYPTO CONDITION: both legs call the one external symbol
  btc_equiv_check_sig with the same arguments (sig element, pubkey element,
  scriptCode, sigversion).  Alive2 ingests a bare declaration in both
  modules, so calls with equal arguments return the same value; its return is
  annotated noundef (a C bool return is never poison) by a deterministic
  harness transform recorded in run_alive2.sh.  SAW verifies both legs against
  one shared checker stub linked into each module, pinned to 0 and then 1.
  Nothing here proves ECDSA/secp256k1 agreement; it is the proof-level
  counterpart of docs/DECISION-lax-ecdsa.md and the whole claim is
  conditional on the two checkers agreeing.
  C is a line-cited source slice of Bitcoin Core interpreter.cpp at the pin,
  specialized to the 1-of-1 stack shape, not the whole EvalScript.  L is a
  REVIEWED TRANSLITERATION of the Lean checkMultiSig/cmsLoop/cmsCleanup
  equations: at repo_head 4d62a97 twin/ops_ir.py has no CHECKMULTISIG handler
  (wires 0xae/0xaf map to OP_UNSUPPORTED_CHECKSIG), so this handler was NOT
  generated by twin/gen.py.  The bounded init/push/finish/pack code and the
  1-of-1 domain guard are cell harness, not engine code.  These are bounded
  closed witnesses over the checker verdict, not a whole-engine equivalence
  proof: nKeys/nSigs range and count checks (SCR-114 in general), matching
  order and early exit (SCR-116), per-pair encoding policy (SCR-117),
  FindAndDelete/CONST_SCRIPTCODE (SCR-115), NULLFAIL (SCR-110), arbitrary
  non-empty dummies under NULLDUMMY off, CODESEPARATOR, and tapscript are
  outside this cell.  No Core source patch is used.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
  - behavior/result.txt, behavior/certificate.sha256 (behavioral only)
  - build/ (generated twin_ops.h, extracted C/L IR, build.txt)
mutant: "invert the checker result in the L leg (btc_equiv_check_sig(...) == 0), return 11 instead of EQUIV_ERR_CHECKMULTISIGVERIFY=13, or return SIG_NULLFAIL instead of SIG_NULLDUMMY=28; expect Alive2/SAW to fail"
mutant_site: "cells/_tools/e3/cellsig/l_cms.cpp (reviewed transliteration)"
---

# Cell `e3-cms/C-L-cms-1of1`

## What is proved

Four closed witness functions per leg, compared with Alive2 and verified
against oracle-derived packed constants with SAW. The CHECKMULTISIG operand
tuple is specialized to one signature and one pubkey.

| Function | Checker | Expected packed | Meaning |
|---|---|---|---|
| `cell_cms` | 0 | `0x108` | push false; script ends EVAL_FALSE(2), depth 1, `{}` |
| `cell_cms` | 1 | `0x2901` | push `{1}`; pass |
| `cell_cmsverify` | 0 | `0x34` | CHECKMULTISIGVERIFY returns ordinal 13 |
| `cell_cmsverify` | 1 | `0x2901` | verify succeeds, harness OP_1 passes |
| `cell_cms_nulldummy` | — | `0x70` | non-empty dummy under NULLDUMMY returns ordinal 28 |
| `cell_cms_empty` | — | `0x48` | empty stack returns ordinal 18 |

Alive2 quantifies over the checker verdict (the external call); SAW pins it
to 0 and 1 in two builds. `0x2901` is result=1, error=0, depth=1,
top=(len=1,val=1). Exact outputs are in `alive2/result.txt` and
`saw/result.txt`; certificates hash sources, IR, and outputs.

## SCR coverage is partial

- **SCR-114** ("nKeys∈[0,20], nSigs∈[0,nKeys], depth checks"): the depth
  underflow arm (`cell_cms_empty`, ordinal 18) and the in-range 1-of-1
  layout are covered. Range/decode errors, nKeys>1/nSigs>1, and the
  nSigs>nKeys arm are not modeled.
- **SCR-118** ("extra stack item consumed unchecked"): the unconditional
  dummy consumption after cleanup is proved for an empty dummy
  (`cell_cms`, `cell_cmsverify`). It does not exercise a non-empty dummy
  with NULLDUMMY off, so "contents unchecked" is only partially shown.
- **SCR-119** ("dummy must be ∅", consensus post-SegWit): covered for a
  one-byte non-empty dummy returning SIG_NULLDUMMY=28. Empty dummy under the
  enabled gate is not separately exercised.
- **SCR-120** ("false ⇒ CHECKMULTISIGVERIFY error"): covered exactly —
  checker false returns ordinal 13 with no stack observable.
- Not covered at all: SCR-115 (FindAndDelete), SCR-116 (matching order /
  early exit), SCR-117 (per-pair encoding policy), SCR-110 (NULLFAIL), the
  legacy `nSigs=0` shape, CODESEPARATOR, tapscript CHECKMULTISIG rejection.
  These need their own cells or a filed gap.

## Directions

`alive2/result.txt` compares `c_*.ll` (source) with `l_*.ll` (target) using
`alive-tv --bidirectional`, which checks both refinement directions
(L ⊑ C and C ⊑ L) for these total functions; `behavior/` compares both legs
on the same oracle constants as corroboration. No whole-entry or R claim is
made.
