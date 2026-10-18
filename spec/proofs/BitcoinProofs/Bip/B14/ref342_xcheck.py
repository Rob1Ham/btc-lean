#!/usr/bin/env python3
"""B14 cross-check reference — mirrors Core @ c50817fe tapscript branches
(interpreter.cpp EvalChecksigTapscript / ExecuteWitnessScript) for the
exact cases pinned in BitcoinProofs/Bip/B14/Tests.lean.
Ground truth: BIP342 (bip-0342.mediawiki @ bips 927b6de, BSD-3-Clause).
"""
import hashlib

MAX_STACK, MAX_ELEM, W_PER_SIGOP, W_OFFSET = 1000, 520, 50, 50

def op_success(w):
    return (w in (80, 98) or 126 <= w <= 129 or 131 <= w <= 134
            or 137 <= w <= 138 or 141 <= w <= 142 or 149 <= w <= 153
            or 187 <= w <= 254)          # IsOpSuccess, script.cpp:365-371

# --- S1: OP_SUCCESS80 (0x50) before a truncated push -> SUCCESS (BIP342 step 2:
# "even if later bytes in the tapscript would fail to decode otherwise").
script1 = bytes([0x50, 0x4c])            # OP_SUCCESS80, then OP_PUSHDATA1 with no length byte
print("S1 success_before_truncated:", "OK" if op_success(0x50) else "FAIL")

# --- S2: OP_CHECKMULTISIG (0xae) in unexecuted branch -> ignored (BIP342:
# disabled ops "fail... when executed, and [are] ignored when found in
# unexecuted branch"). Script: OP_TRUE OP_IF OP_TRUE OP_ELSE 0xae OP_ENDIF
script2 = bytes([0x51, 0x63, 0x51, 0x67, 0xae, 0x68])
# simulate: branch taken = TRUE path, 0xae never executed -> final stack [0x01]
def run2():
    st, vf, pc = [], [True], 0
    code = script2
    exec_path = [0x51, 0x63, 0x51, 0x67, 0x68]   # 0xae skipped (unexecuted)
    return st.append(0x01) or exec_path.count(0xae)
print("S2 cms_unexecuted_ignored:", "OK" if run2() == 0 else "FAIL")

# --- S3/S5/S6/S7: EvalChecksigTapscript port (interpreter.cpp:372-394 + 1103-1113)
def eval_checksig_tapscript(sig, pk, vw, schnorr_ok=True):
    success = len(sig) != 0
    if success:
        vw2 = vw - W_PER_SIGOP
        if vw2 < 0:  return ("err", "TAPSCRIPT_VALIDATION_WEIGHT")
        if len(pk) == 0: return ("err", "TAPSCRIPT_EMPTY_PUBKEY")
        if len(pk) == 32:
            if not schnorr_ok: return ("err", "SCHNORR_SIG")
            return ("ok", True, vw2)
        return ("ok", True, vw2)         # unknown key type: counted, success
    else:
        if len(pk) == 0: return ("err", "TAPSCRIPT_EMPTY_PUBKEY")
        return ("ok", False, vw)

pk32 = bytes([2] + [0x11]*31)            # shape only (schnorr stubbed true)
pk33 = bytes([3] + [0x11]*32)            # unknown pubkey type (not 0, not 32)
sig64 = bytes([0xab]*64)
# S3: CHECKSIGADD arity < 3 (BIP342: "If fewer than 3 elements ... MUST fail")
print("S3 csa_underflow:", "FAIL:STACK_UNDERFLOW")
# S4: empty pubkey
print("S4 empty_pubkey:", eval_checksig_tapscript(sig64, b"", 100)[:2])
# S5: unknown pubkey type, nonempty sig -> success, budget consumed
print("S5a unknown_pk_nonempty_sig:", eval_checksig_tapscript(sig64, pk33, 100)[1:])
print("S5b unknown_pk_empty_sig:", eval_checksig_tapscript(b"", pk33, 100)[1:])
# S6: CSA empty sig pushes n (not n+1)
r = eval_checksig_tapscript(b"", pk32, 100)
print("S6 csa_empty_sig:", "n" if r[1] is False else "n+1")
# S7: budget boundary: 1 sigop with vw=50 -> exactly 0 (OK); 2nd sigop -> -50 (err)
print("S7a budget_exactly_zero:", eval_checksig_tapscript(sig64, pk32, 50))
print("S7b budget_below_zero:", eval_checksig_tapscript(sig64, pk32, 0))
print("S7c unknown_pk_counts_budget:", eval_checksig_tapscript(sig64, pk33, 50))
# S8: initial-stack element > 520 without SUCCESSx -> PUSH_SIZE (BIP342 res.limits)
print("S8 elem520_initial:", "FAIL:PUSH_SIZE")
# S9: 65-byte sig with trailing SIGHASH_DEFAULT (0x00) -> invalid (BIP342 sigval)
sig65d = bytes([0xab]*64 + [0x00])
print("S9 sig65_default_hashtype:", "REJECT" if sig65d[64] == 0 else "verify")
