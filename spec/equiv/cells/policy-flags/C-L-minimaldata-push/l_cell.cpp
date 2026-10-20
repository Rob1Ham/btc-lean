#include "policy_common.h"
using namespace policy_cell;

// L leg: REVIEWED TRANSLITERATION (not generated) of
//   spec/core/Bitcoin/Interpreter/Defs.lean
//
//   def checkMinimalPush (data : ByteArray) (opcode : Nat) : Bool :=   -- :529-539
//     if data.size = 0 then opcode = 0
//     else if data.size = 1 ∧ 1 ≤ (data.get! 0).toNat ∧ (data.get! 0).toNat ≤ 16 then false
//     else if data.size = 1 ∧ (data.get! 0).toNat = 0x81 then false
//     else if data.size ≤ 75 then opcode = data.size
//     else if data.size ≤ 0xff then opcode = 0x4c
//     else if data.size ≤ 0xffff then opcode = 0x4d
//     else true
//
// stepBody, pushBytes arm (:838-843):
//     if !fExec then .ok st₁
//     else if ctx.pol.minimalData ∧ !checkMinimalPush d w then .error .minimalData
//     else .ok { st₁ with stack := d :: st.stack }
//
// `ctx.pol.minimalData` is PolicyFlags.minimalData (Defs.lean:187-205), fed by
// parsePolicyFlags from the corpus "MINIMALDATA" string; Core carries the same
// bit in script_verify_flags (interpreter.cpp:442).

uint64_t l_minimaldata_push(uint64_t flags, uint64_t fExec, uint64_t opcode,
                            uint64_t dataLen, uint64_t b0Arg) {
    const uint64_t b0 = byte_of(b0Arg);

    if (fExec != 0 && opcode <= 0x4e) {   // OP_PUSHDATA4
        bool ok;
        if (dataLen == 0) {
            ok = (opcode == 0x00);        // OP_0
        } else if (dataLen == 1 && b0 >= 1 && b0 <= 16) {
            ok = false;
        } else if (dataLen == 1 && b0 == 0x81) {
            ok = false;
        } else if (dataLen <= 75) {
            ok = (opcode == dataLen);
        } else if (dataLen <= 0xff) {
            ok = (opcode == 0x4c);        // OP_PUSHDATA1
        } else if (dataLen <= 0xffff) {
            ok = (opcode == 0x4d);        // OP_PUSHDATA2
        } else {
            ok = true;
        }
        const bool minimalData = (flags & MINIMALDATA) != 0;
        if (minimalData && !ok) return ERR_MINIMALDATA;
    }
    return ERR_OK;
}

extern "C" uint64_t cell_minimaldata_push(uint64_t flags, uint64_t fExec, uint64_t opcode,
                                          uint64_t dataLen, uint64_t b0Arg) {
    return l_minimaldata_push(flags, fExec, opcode, dataLen, b0Arg);
}
