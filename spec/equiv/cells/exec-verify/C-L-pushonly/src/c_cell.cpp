#include "common.h"

// C leg — line-cited source-excerpt slice of Core at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// SCR-010 (policy pre-check), interpreter.cpp:2022-2024:
//
//   if ((flags & SCRIPT_VERIFY_SIGPUSHONLY) != 0 && !scriptSig.IsPushOnly()) {
//       return set_error(serror, SCRIPT_ERR_SIG_PUSHONLY);
//   }
//
// SCR-006 (P2SH arm), interpreter.cpp:2065-2066:
//
//   // scriptSig must be literals-only or validation fails
//   if (!scriptSig.IsPushOnly())
//       return set_error(serror, SCRIPT_ERR_SIG_PUSHONLY);
//
// `CScript::IsPushOnly` is script.cpp:266-285:
//
//   bool CScript::IsPushOnly(const_iterator pc) const
//   {
//       while (pc < end())
//       {
//           opcodetype opcode;
//           if (!GetOp(pc, opcode))
//               return false;
//           if (opcode > OP_16)                    // OP_16 = 0x60
//               return false;
//       }
//       return true;
//   }
//
// and `GetScriptOp` is script.cpp:313-363: one wire byte; for opcodes
// 0x01-0x4b the opcode *is* the payload length; 0x4c/0x4d/0x4e read a
// 1/2/4-byte little-endian length; a push whose payload runs past the end is
// a decode failure.  Opcodes >= 0x4f carry no payload.  The comment in Core
// notes that OP_RESERVED (0x50) counts as push-type for IsPushOnly (it is
// <= OP_16); it fails later in execution, not here.
//
// BOUND: the cell packs the script into one u64, so script length 0..8 is
// claimed.  Longer scripts are the out-of-model marker 3 (the general GetOp
// loop is the E5 residual).  The loop is *unrolled* to eight steps for the
// claimed domain: every executed step consumes at least one byte, so after
// eight steps the walk has reached the end of an 8-byte script.  This is the
// exact loop body, not a weakened check.

EVINLINE void c_step(uint64_t len, uint64_t script, uint64_t *pcp,
                     uint64_t *okp) {
    uint64_t pc = *pcp;
    if (!*okp || pc >= len) return;

    // script.cpp:317 — read one instruction
    const uint64_t opcode = ev_script_byte(script, pc);
    ++pc;

    uint64_t nsize = 0;
    uint64_t is_push = 0;
    uint64_t ok = 1;

    if (opcode <= 0x4b) {
        // direct push: the opcode is the payload length
        nsize = opcode;
        is_push = 1;
    } else if (opcode == 0x4c) {
        if (len - pc < 1) ok = 0;                 // truncated length field
        else { nsize = ev_script_byte(script, pc); pc += 1; is_push = 1; }
    } else if (opcode == 0x4d) {
        if (len - pc < 2) ok = 0;
        else {
            nsize = ev_script_byte(script, pc) |
                    (ev_script_byte(script, pc + 1) << 8);
            pc += 2;
            is_push = 1;
        }
    } else if (opcode == 0x4e) {
        if (len - pc < 4) ok = 0;
        else {
            nsize = ev_script_byte(script, pc) |
                    (ev_script_byte(script, pc + 1) << 8) |
                    (ev_script_byte(script, pc + 2) << 16) |
                    (ev_script_byte(script, pc + 3) << 24);
            pc += 4;
            is_push = 1;
        }
    }

    if (ok && is_push) {
        // script.cpp:355-357 — `if (end - pc < nSize) return false;`
        if (len - pc < nsize) ok = 0;
        else pc += nsize;
    }

    // script.cpp:277-279 — `if (opcode > OP_16) return false;`
    if (ok && opcode > 0x60) ok = 0;

    *pcp = pc;
    *okp = *okp && ok;
}

EVINLINE void c_walk8(uint64_t len, uint64_t script, uint64_t *pc,
                      uint64_t *ok) {
    c_step(len, script, pc, ok);
    c_step(len, script, pc, ok);
    c_step(len, script, pc, ok);
    c_step(len, script, pc, ok);
    c_step(len, script, pc, ok);
    c_step(len, script, pc, ok);
    c_step(len, script, pc, ok);
    c_step(len, script, pc, ok);
}

EVINLINE uint64_t c_ispushonly(uint64_t len, uint64_t script) {
    if (len > EV_SCRIPT_MAX) return 3;   // out of model
    uint64_t pc = 0;
    uint64_t ok = 1;
    c_walk8(len, script, &pc, &ok);
    return ok ? 1 : 0;
}

EVINLINE uint64_t c_pushonly_early(uint64_t sigpushonly, uint64_t len,
                                   uint64_t script) {
    // interpreter.cpp:2022-2024, with Core's short-circuit order: the flag is
    // tested first, so with the flag off IsPushOnly is never consulted.
    if (!sigpushonly) return ev_pack(1, 0);       // check not applicable
    const uint64_t po = c_ispushonly(len, script);
    if (po == 3) return ev_pack(3, 0);            // out of model
    if (!po) return ev_pack(0, EV_SIG_PUSHONLY);
    return ev_pack(1, 0);                          // pre-check passed
}

EVINLINE uint64_t c_pushonly_p2sh(uint64_t p2sh, uint64_t spk_p2sh,
                                  uint64_t len, uint64_t script) {
    // interpreter.cpp:2062-2066: the check is unconditional once the P2SH arm
    // is entered (no separate flag).
    if (!(p2sh && spk_p2sh)) return ev_pack(1, 0);  // arm not entered
    const uint64_t po = c_ispushonly(len, script);
    if (po == 3) return ev_pack(3, 0);              // out of model
    if (!po) return ev_pack(0, EV_SIG_PUSHONLY);
    return ev_pack(1, 0);                            // arm accepted
}

extern "C" uint64_t cell_ispushonly(uint64_t len, uint64_t script) {
    return c_ispushonly(len & 0x0fu, script);
}

extern "C" uint64_t cell_pushonly_early(uint64_t sigpushonly, uint64_t len,
                                        uint64_t script) {
    return c_pushonly_early(sigpushonly & 1u, len & 0x0fu, script);
}

extern "C" uint64_t cell_pushonly_p2sh(uint64_t p2sh, uint64_t spk_p2sh,
                                       uint64_t len, uint64_t script) {
    return c_pushonly_p2sh(p2sh & 1u, spk_p2sh & 1u, len & 0x0fu, script);
}
