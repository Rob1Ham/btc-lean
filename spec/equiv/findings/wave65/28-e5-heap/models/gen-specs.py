#!/usr/bin/env python3
"""Emit the committed SAW specs for wave65/28.

Usage: gen-specs.py <module_dir> <spec_dir>

The emitted specs contain absolute module paths (the repo's established
pattern for SAW cells).  Regenerate after changing $OUT.
"""
import os
import struct
import sys

OUT = sys.argv[1]
SPECS = sys.argv[2]

VERIFY = "_Z12VerifyScriptRK7CScriptS1_PK14CScriptWitness19script_verify_flagsRK20BaseSignatureCheckerP13ScriptError_t"

GUARDS = {
    "gz": "_ZGVZ10EvalScriptRSt6vectorIS_IhSaIhEESaIS1_EERK7CScript19script_verify_flagsRK20BaseSignatureChecker10SigVersionR19ScriptExecutionDataP13ScriptError_tE6bnZero",
    "go": "_ZGVZ10EvalScriptRSt6vectorIS_IhSaIhEESaIS1_EERK7CScript19script_verify_flagsRK20BaseSignatureChecker10SigVersionR19ScriptExecutionDataP13ScriptError_tE5bnOne",
    "gt": "_ZGVZ10EvalScriptRSt6vectorIS_IhSaIhEESaIS1_EERK7CScript19script_verify_flagsRK20BaseSignatureChecker10SigVersionR19ScriptExecutionDataP13ScriptError_tE7vchTrue",
    "oz": "_ZZ10EvalScriptRSt6vectorIS_IhSaIhEESaIS1_EERK7CScript19script_verify_flagsRK20BaseSignatureChecker10SigVersionR19ScriptExecutionDataP13ScriptError_tE6bnZero",
    "oo": "_ZZ10EvalScriptRSt6vectorIS_IhSaIhEESaIS1_EERK7CScript19script_verify_flagsRK20BaseSignatureChecker10SigVersionR19ScriptExecutionDataP13ScriptError_tE5bnOne",
    "ot": "_ZZ10EvalScriptRSt6vectorIS_IhSaIhEESaIS1_EERK7CScript19script_verify_flagsRK20BaseSignatureChecker10SigVersionR19ScriptExecutionDataP13ScriptError_tE7vchTrue",
}

HEAD = '''// {title}
//
// Module: {module} (sha256 in ../logs/build-hashes.txt)
// Script: {script_desc}
// Pre-state: scriptSig empty; scriptPubKey inline prevector with size {size};
//            no witness; flags 0; 8-byte checker and error cells (unread on
//            this path).
// Heap: cell-local bump arena (CAP={cap}) via ../../models/cell-model.ll.tmpl.
// Guards: {guard_mode}
m <- llvm_load_module "{module}";
let gz = "{gz}";
let go = "{go}";
let gt = "{gt}";
let oz = "{oz}";
let oo = "{oo}";
let ot = "{ot}";
let verify_script = "{verify}";
thm <- llvm_verify m verify_script [] false
  (do {{
'''


def spk_array(bs):
    assert len(bs) <= 36
    arr = bs + [0] * (36 - len(bs)) + list(struct.pack("<i", len(bs)))
    return ",".join("0x%02x" % b for b in arr)


def spec(path, title, module, cap, script_desc, opcodes, ret, trace=None,
         guard_mode="modeled: start 0, execute the real static initializers", pinned=False):
    body = HEAD.format(title=title, module=module, script_desc=script_desc,
                       size=len(opcodes), cap=cap, guard_mode=guard_mode,
                       verify=VERIFY, **GUARDS)
    if pinned:
        body += (
            '     llvm_alloc_global "__dso_handle"; llvm_points_to (llvm_global "__dso_handle") (llvm_term {{ 0 : [8] }});\n'
        )
    else:
        body += (
            '     llvm_alloc_global "__dso_handle"; llvm_points_to (llvm_global "__dso_handle") (llvm_term {{ 0 : [8] }});\n'
            '     llvm_alloc_global oz; llvm_alloc_global oo; llvm_alloc_global ot;\n'
            '     llvm_alloc_global gz; llvm_points_to (llvm_global gz) (llvm_term {{ 0 : [64] }});\n'
            '     llvm_alloc_global go; llvm_points_to (llvm_global go) (llvm_term {{ 0 : [64] }});\n'
            '     llvm_alloc_global gt; llvm_points_to (llvm_global gt) (llvm_term {{ 0 : [64] }});\n'
        )
    spk = spk_array(opcodes)
    body += f'''     llvm_alloc_global "w65_arena"; llvm_points_to (llvm_global "w65_arena") (llvm_term {{{{ zero : [{cap}][8] }}}});
     llvm_alloc_global "w65_off";    llvm_points_to (llvm_global "w65_off")    (llvm_term {{{{ 0 : [64] }}}});
     llvm_alloc_global "w65_hw";     llvm_points_to (llvm_global "w65_hw")     (llvm_term {{{{ 0 : [64] }}}});
     llvm_alloc_global "w65_calls";  llvm_points_to (llvm_global "w65_calls")  (llvm_term {{{{ 0 : [64] }}}});
     llvm_alloc_global "w65_failed"; llvm_points_to (llvm_global "w65_failed") (llvm_term {{{{ 0 : [64] }}}});
     llvm_alloc_global "w65_first";  llvm_points_to (llvm_global "w65_first")  (llvm_term {{{{ 0 : [64] }}}});
     llvm_alloc_global "w65_last";   llvm_points_to (llvm_global "w65_last")   (llvm_term {{{{ 0 : [64] }}}});
     ss  <- llvm_alloc_aligned 8 (llvm_array 40 (llvm_int 8));
     spk <- llvm_alloc_aligned 8 (llvm_array 40 (llvm_int 8));
     chk <- llvm_alloc_aligned 8 (llvm_array 8 (llvm_int 8));
     err <- llvm_alloc_aligned 8 (llvm_array 8 (llvm_int 8));
     llvm_points_to ss  (llvm_term {{{{ zero : [40][8] }}}});
     llvm_points_to spk (llvm_term {{{{ [{spk}] : [40][8] }}}});
     llvm_points_to chk (llvm_term {{{{ zero : [8][8] }}}});
     llvm_points_to err (llvm_term {{{{ zero : [8][8] }}}});
     llvm_execute_func [ss, spk, llvm_term {{{{ 0 : [64] }}}},
                        llvm_term {{{{ 0 : [64] }}}}, chk, err];
     llvm_return (llvm_term {{{{ {ret} : [1] }}}});
'''
    if trace:
        calls, first, last, off, hw = trace
        body += f'''     llvm_points_to (llvm_global "w65_failed") (llvm_term {{{{ 0 : [64] }}}});
     llvm_points_to (llvm_global "w65_calls")  (llvm_term {{{{ {calls} : [64] }}}});
     llvm_points_to (llvm_global "w65_first")  (llvm_term {{{{ {first} : [64] }}}});
     llvm_points_to (llvm_global "w65_last")   (llvm_term {{{{ {last} : [64] }}}});
     llvm_points_to (llvm_global "w65_off")    (llvm_term {{{{ {off} : [64] }}}});
     llvm_points_to (llvm_global "w65_hw")     (llvm_term {{{{ {hw} : [64] }}}});
'''
    if not pinned:
        body += '''     llvm_points_to (llvm_global gz) (llvm_term {{ 2 : [64] }});
     llvm_points_to (llvm_global go) (llvm_term {{ 2 : [64] }});
     llvm_points_to (llvm_global gt) (llvm_term {{ 2 : [64] }});
'''
    body += '   }) z3;\nprint "PROOF_DONE";\n'
    open(os.path.join(SPECS, path), "w").write(body)


os.makedirs(SPECS, exist_ok=True)
P = lambda n: os.path.join(OUT, n)

# --- modeled-guard proofs ---------------------------------------------------
spec("singletu-op1.saw",
     "E5 OP_1: pinned single-TU carrier + script.cpp, modeled guards, CAP=128",
     P("singletu-model-128.bc"), 128, "OP_1 (0x51), 1 byte", [0x51], 1,
     trace=(3, 1, 24, 57, 57))
spec("singletu-op1add.saw",
     "E5 OP_1ADD: pinned single-TU carrier + script.cpp, modeled guards, CAP=128",
     P("singletu-model-128.bc"), 128, "OP_1 OP_1ADD (0x51 0x8b), 2 bytes", [0x51, 0x8b], 1,
     trace=(4, 1, 1, 66, 66))
spec("singletu-op1sub.saw",
     "E5 OP_1SUB: pinned single-TU carrier + script.cpp, modeled guards, CAP=128",
     P("singletu-model-128.bc"), 128, "OP_1 OP_1SUB (0x51 0x8c), 2 bytes", [0x51, 0x8c], 0,
     trace=(3, 1, 24, 57, 57))
spec("closure-op1add.saw",
     "E5 OP_1ADD: canonical [ir] closure, modeled guards, CAP=128",
     P("closure-model-128.bc"), 128, "OP_1 OP_1ADD (0x51 0x8b), 2 bytes", [0x51, 0x8b], 1,
     trace=(4, 1, 1, 66, 66))
spec("closure-op1sub.saw",
     "E5 OP_1SUB: canonical [ir] closure, modeled guards, CAP=128",
     P("closure-model-128.bc"), 128, "OP_1 OP_1SUB (0x51 0x8c), 2 bytes", [0x51, 0x8c], 0,
     trace=(3, 1, 24, 57, 57))
spec("closure-op1add-cap66.saw",
     "E5 OP_1ADD at the exact capacity boundary: CAP=66",
     P("closure-model-66.bc"), 66, "OP_1 OP_1ADD (0x51 0x8b), 2 bytes", [0x51, 0x8b], 1,
     trace=(4, 1, 1, 66, 66))

# --- negative controls (must fail / must stop) ------------------------------
spec("neg-singletu-op1sub-expect-true.saw",
     "NEGATIVE CONTROL: OP_1SUB cannot return true under modeled guards",
     P("singletu-model-128.bc"), 128, "OP_1 OP_1SUB (0x51 0x8c), 2 bytes", [0x51, 0x8c], 1)
spec("neg-closure-op1add-cap65.saw",
     "NEGATIVE CONTROL: CAP=65 is one byte short; must stop at the throw external",
     P("closure-model-65.bc"), 65, "OP_1 OP_1ADD (0x51 0x8b), 2 bytes", [0x51, 0x8b], 1)
spec("neg-closure-pinned-op1sub-expect-false.saw",
     "NEGATIVE CONTROL: the pinned-guard module cannot return false on OP_1SUB",
     P("closure-pinned.bc"), 128, "OP_1 OP_1SUB (0x51 0x8c), 2 bytes", [0x51, 0x8c], 0,
     pinned=True)

# --- divergence witnesses (the pinned-guard shortcut changes the result) ----
spec("pinned-singletu-op1sub.saw",
     "DIVERGENCE WITNESS: guards pinned to 1 make OP_1SUB return true",
     P("singletu-pinned.bc"), 128, "OP_1 OP_1SUB (0x51 0x8c), 2 bytes", [0x51, 0x8c], 1,
     trace=(3, 1, 1, 50, 50), pinned=True,
     guard_mode="PINNED to constant 1 (wave16b/64 shortcut) - initialization skipped")
spec("pinned-closure-op1sub.saw",
     "DIVERGENCE WITNESS: guards pinned to 1 make OP_1SUB return true (closure)",
     P("closure-pinned.bc"), 128, "OP_1 OP_1SUB (0x51 0x8c), 2 bytes", [0x51, 0x8c], 1,
     trace=(3, 1, 1, 50, 50), pinned=True,
     guard_mode="PINNED to constant 1 (wave16b/64 shortcut) - initialization skipped")

print("wrote", len(os.listdir(SPECS)), "specs to", SPECS)
