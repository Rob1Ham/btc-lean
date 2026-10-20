---
# Cell tapscript/C-L-w32-checksigadd
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
lean_model_rev: 4d62a97e551082a69b13f495365bff0a903b0c99
legs: C, L
r_leg: "not attempted: pinned rbitcoin IR is not Alive2-ingestable (F-TOOL-001) and no tapscript CHECKSIGADD cell exists"
cell: C-L-w32-checksigadd
family: tapscript
tool_status: both-green (Alive2 symbolic over the bounded domain; SAW concrete scenarios)
precondition: |
  - One OP_CHECKSIGADD step, no preceding or following opcode.
  - SigVersion in {BASE(0), WITNESS_V0(1), TAPSCRIPT(2)}. TAPROOT is not a
    script-execution path and is outside the domain (the harness returns the
    out-of-domain sentinel for it).
  - Stack depth is symbolic 0..7; the top three elements are
    (sig, num, pubkey) with sig and pubkey lengths symbolic 0..255 and num
    length symbolic 0..5. Elements are abstract byte strings: only length,
    the five carried bytes, and equality at the checker seam matter.
  - The policy word carries only fRequireMinimal (MINIMALDATA) and
    DISCOURAGE_UPGRADABLE_PUBKEYTYPE; both symbolic.
  - Validation weight `vw` is symbolic in [-100, 923] (seed 0..1023 minus
    100), so both the >= 50 and < 50 branches of the tapscript decrement are
    reachable.
  - The Schnorr verdict is the unconstrained return of the shared external
    btc_equiv_check_schnorr. That is the only non-determinism Alive2
    quantifies beyond the scalar inputs.
postcondition: |
  - BASE / WITNESS_V0: any depth returns (result=0, error=BAD_OPCODE=16).
  - TAPSCRIPT, depth < 3: (0, INVALID_STACK_OPERATION=18), no num parse and
    no checker call.
  - TAPSCRIPT, depth >= 3:
      * num width > 4 or (minimal && non-minimal): (0, SCRIPTNUM=4);
      * EvalChecksigTapscript error: its ordinal (37, 47, 49 or 52);
      * otherwise pop 3, push CScriptNum(num + (success ? 1 : 0)).getvch()
        and return (result=1, error=0, depth-2, top = the canonical minimal
        little-endian encoding, including the 5-byte output for
        +0x80000000).
  - Both legs pack the same 53-bit observable (see src/tap_common.h):
    result, error ordinal, depth, top length, top five bytes.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-156, SCR-157
scr_row_coverage: full
coverage: full
patches: none
source_citations:
  - "script/interpreter.cpp:1094-1113 (case OP_CHECKSIGADD; 1096-1097 BAD_OPCODE; 1100-1101 arity; 1103 CScriptNum; 1112 num + success)"
  - "script/interpreter.cpp:357-400 (EvalChecksigTapscript; 367 success; 372-375 weight; 377-392 pubkey triage)"
  - "script/interpreter.cpp:437-442 (fRequireMinimal)"
  - "script/interpreter.cpp:1236-1240 (scriptnum_error -> SCRIPT_ERR_SCRIPTNUM)"
  - "script/script.h:246-271 (CScriptNum ctor width + minimality)"
  - "script/script.h:335-365 (CScriptNum::serialize / getvch)"
  - "script/script.h:376-391 (CScriptNum::set_vch)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:629-635 (decodeNum)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:757-780 (evalChecksigTapscript)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:803-815 (checksigAddStep)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1048-1059 (CHECKSIGADD arm)"
  - "spec/core/Bitcoin/Numeric/Interface.lean:50-52,60-61 (decodeScriptNum, encodeScriptNum)"
  - "spec/core/Bitcoin/Numeric/ScriptNum.lean:385-389,449-453,493-500,628-631 (encodeSignBE, setVchBE, minimalOkBE, decodeBE)"
  - "contract/error_kind.h:4,16,18,37,45,46,47,49,52 (ordinals)"
trust_note: >
  SCR-156/157 are proved only as a bounded one-step C-L cell.

  SAME-CRYPTO CONDITION: both legs call the one external symbol
  btc_equiv_check_schnorr with the same (sig, pubkey, sigversion) encoding.
  Alive2 treats calls to the same symbol with equal arguments as returning
  the same value and its return is annotated noundef (a C bool return is
  never poison). SAW links one shared stub into each module and pins its
  verdict to 0 and 1. Nothing here proves BIP340, secp256k1, sighash or
  SHA256 agreement; the claim is conditional on the two checkers agreeing,
  exactly as in docs/DECISION-lax-ecdsa.md.

  C is a line-cited source slice of interpreter.cpp and script.h at the
  pin, not the whole EvalScript. The variable-length CScriptNum helpers are
  transliterated loop-free for the declared 5-byte domain. The scriptnum_error
  throw/catch is modelled as the SCRIPT_ERR_SCRIPTNUM return.

  L is a REVIEWED TRANSLITERATION of the Lean equations at
  lean_model_rev, not generated IR: twin/ops_ir.py at this repo head has no
  tapscript CHECKSIGADD handler. The Lean model's `Except` drops the machine
  state on error; the C leg's in-place validation-weight mutation is
  therefore threaded as an explicit harness `vw` in both legs (observable
  only in the SCR-158/159/160 cell).

  The SAW lane is a set of concrete closed scenarios, not a symbolic
  domain proof. Alive2 is the symbolic bounded-domain equivalence evidence;
  SAW corroborates representative branch points against an independent
  oracle (src/oracle.py). Neither tool proves the surrounding EvalScript
  loop, ParseScript, the witness/annex layer, sigop accounting (SCR-155),
  SCRIPT_SIZE, or consensus flag selection. TAPROOT is unreachable and out
  of domain.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
mutant: "in C: return BAD_OPCODE for TAPSCRIPT, or push num without the success increment; in L: swap num+success to num-success; expect Alive2/SAW to fail"
mutant_site: "src/c_tap.cpp core_checksigadd / src/l_tap.cpp lean_checksigadd"
---

# Cell `tapscript/C-L-w32-checksigadd`

## What is proved

`cell_add_dispatch(sv, depth)` and `cell_add_num(num, sig, pk, depth,
minimal, discourage, vw_seed)` are compared bidirectionally by Alive2 over
the declared scalar domain and verified by SAW on concrete branch
scenarios. Both legs use the same 53-bit observable.

| SCR | Branches exercised |
|---|---|
| SCR-156 | BASE and WITNESS_V0 -> `BAD_OPCODE` at every depth; TAPSCRIPT depth 0/1/2 -> `INVALID_STACK_OPERATION`; depth >= 3 -> pop `(sig,num,pk)`, push `num + (success?1:0)` for every value of `success` and every 0..4-byte `num`; `sig` empty/non-empty, `pubkey` len 0/32/other, both `DISCOURAGE_UPGRADABLE_PUBKEYTYPE` states, checker verdict 0/1, weight above/below 50 |
| SCR-157 | `num` length 0..5; `fRequireMinimal` both values; the width-4 limit; minimal rejection of leading zero and negative zero `0x80`; the `0xff00`-style sign-bit exception; lax acceptance of the same bytes; the parse-before-EvalChecksig order (arity first, then num, then signature) |

## Why `full`

The Alive2 entry takes the operand bytes, lengths, sigversion, depth,
policy bits, weight and (through the shared symbol) the Schnorr verdict as
symbolic inputs. No branch named by SCR-156 or SCR-157 is a closed witness
only: every one is reachable for some assignment. SAW's concrete scenarios
are corroboration, not the coverage argument.

Not covered by this cell (separate rows): SCR-158/159/160 are extracted
into the sibling `C-L-w32-pubkey-triage` cell; SCR-161/162 into
`C-L-w32-schnorr-shape`; sigop/validation-weight *initialisation* is not
modelled (the weight is an input); OP_SUCCESSx, script parsing and the
`EvalScript` loop are outside.

## Directions

Both `L ⊑ C` and `C ⊑ L` are required because this is a C-L equivalence
cell. `alive2/result.txt` runs `alive-tv --bidirectional` on each entry;
each block records the raw per-function result and IR hashes.

## Reproduce

```sh
cd spec/equiv/cells/tapscript/C-L-w32-checksigadd
./alive2/run.sh
./saw/run.sh
cd /tmp/opencode/wave32/28-tapscript-156-162
sha256sum -c spec/equiv/cells/tapscript/C-L-w32-checksigadd/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/tapscript/C-L-w32-checksigadd/saw/certificate.sha256
```
