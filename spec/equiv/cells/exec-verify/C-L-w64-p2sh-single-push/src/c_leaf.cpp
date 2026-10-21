#include <cstdint>
// C leg — line-cited source-excerpt slice of Bitcoin Core at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// Region: the P2SH-wrapped witness-program guard, SCR-012
// (interpreter.cpp:2090-2096):
//
//   if (pubKey2.IsWitnessProgram(witnessversion, witnessprogram)) {
//       hadWitness = true;
//       if (scriptSig != CScript() << std::vector<unsigned char>(pubKey2.begin(), pubKey2.end())) {
//           // The scriptSig must be _exactly_ a single push of the redeemScript.
//           // Otherwise we reintroduce malleability.
//           return set_error(serror, SCRIPT_ERR_WITNESS_MALLEATED_P2SH);
//       }
//
// Supporting code, cited at the pin:
//   script.h:408-424        CScript::AppendDataSize (canonical push prefix)
//   script.h:484-495        CScript::operator<<(span) = AppendDataSize ++ data
//   script.cpp:313-363      GetScriptOp (push decode; PUSHDATA1/2/4)
//   script.cpp:373-396      CheckMinimalPush
//   script.cpp:250-264      CScript::IsWitnessProgram (4..42-byte template)
//   interpreter.cpp:2029-2031  EvalScript(stack, scriptSig, ...)
//   interpreter.cpp:476-503    the fExec push + MINIMALDATA gate
//   interpreter.cpp:487-488    GetOp failure => SCRIPT_ERR_BAD_OPCODE
//   prevector.h:429         element-wise CScript operator==
//
// Modelling notes (also in notes.md):
//   * The redeemScript `pubKey2` is the last scriptSig stack element; its
//     *shape* (a witness program, 4..42 bytes) is the row domain and is
//     recomputed here exactly (script.cpp:250-264), not assumed.
//   * The redeemScript subscript EvalScript and VerifyWitnessProgram are NOT
//     modelled: the guard is reached only after the subscript returned ok
//     with a truthy top (interpreter.cpp:2080-2086), and a passing guard
//     continues into VerifyWitnessProgram (2097-2098).  Both are declared
//     premises of this cell (other cells cover them).
//   * scriptSig is modelled by its single-push decomposition: a push opcode
//     (any of the four encodings) plus a payload; scriptSigs that are not a
//     single push return the out-of-domain sentinel 3.  The 2092 comparison
//     is still a byte-for-byte comparison of the whole scriptSig (see
//     cell_p2sh_guard below), not a decoded summary.
//   * The domain is 4 <= redeem_len <= 42, scriptSig length 0..49.  At those
//     lengths `CScript() << vector(redeemScript)` is the direct-push branch
//     (AppendDataSize size < OP_PUSHDATA1), which cell_canon_prefix proves
//     for the whole prefix function, including the PUSHDATA1/2/4 branches
//     that the row's domain does not reach.
//
// Nothing here is engine code; every function is a bounded leaf.

#define CINLINE static inline __attribute__((always_inline))

namespace {

// Cell storage bounds.  49 scriptSig bytes is the largest wire form the row
// domain can produce (PUSHDATA4 prefix 5 + 42 payload + 2 spare), 42 bytes
// the largest redeemScript (witness program template).
constexpr uint32_t SIG_BYTES = 56;   // 7 x u64 chunks of scriptSig storage
constexpr uint32_t RED_BYTES = 48;   // 6 x u64 chunks of redeemScript storage
constexpr uint32_t MAX_PLEN = 42;
constexpr uint32_t MAX_SLEN = 49;

// Byte i of a little-endian u64 chunk array.  `i` is always a compile-time
// constant at every use below, so this is a shift/mask, never a load.
CINLINE uint32_t cb(const uint64_t* c, uint32_t i) {
    return static_cast<uint32_t>((c[i >> 3] >> (8 * (i & 7))) & 0xffu);
}

// script.h:408-424 — CScript::AppendDataSize(size).
CINLINE void c_append_data_size(uint32_t size, uint32_t& kind, uint32_t& np,
                                uint8_t* pre) {
    if (size < 0x4cu) {                       // OP_PUSHDATA1 == 0x4c
        kind = 0; np = 1; pre[0] = static_cast<uint8_t>(size);
    } else if (size <= 0xffu) {
        kind = 1; np = 2; pre[0] = 0x4cu; pre[1] = static_cast<uint8_t>(size);
    } else if (size <= 0xffffu) {
        kind = 2; np = 3; pre[0] = 0x4du;
        pre[1] = static_cast<uint8_t>(size & 0xffu);
        pre[2] = static_cast<uint8_t>((size >> 8) & 0xffu);
    } else {
        kind = 3; np = 5; pre[0] = 0x4eu;
        pre[1] = static_cast<uint8_t>(size & 0xffu);
        pre[2] = static_cast<uint8_t>((size >> 8) & 0xffu);
        pre[3] = static_cast<uint8_t>((size >> 16) & 0xffu);
        pre[4] = static_cast<uint8_t>((size >> 24) & 0xffu);
    }
}

// script.cpp:250-264 — CScript::IsWitnessProgram, reading only the four
// fields Core reads (size, [0], [1]; the program body is not read here).
CINLINE uint32_t c_is_witness_program(uint32_t plen, const uint64_t* p) {
    if (plen < 4 || plen > 42) return 0;
    const uint32_t v = cb(p, 0);
    if (v != 0x00u && (v < 0x51u || v > 0x60u)) return 0;
    return static_cast<uint32_t>((cb(p, 1) + 2u) == plen);
}

struct CDec {
    uint32_t ok;        // GetScriptOp succeeded
    uint32_t is_push;   // opcode <= OP_PUSHDATA4
    uint32_t op;        // wire opcode
    uint32_t dlen;      // pushed data length
    uint32_t next;      // pc after the opcode
    uint32_t first;     // first payload byte (0 when dlen == 0)
};

// script.cpp:313-363 — GetScriptOp at pc == begin, bounded to 49 bytes.
CINLINE void c_get_script_op(uint32_t slen, const uint64_t* s, CDec& d) {
    d.ok = 0; d.is_push = 0; d.op = 0xffu; d.dlen = 0; d.next = 0; d.first = 0;
    if (slen < 1) return;                              // pc >= end
    const uint32_t op = cb(s, 0);
    uint32_t pc = 1;
    if (op > 0x4eu) {                                  // non-push opcode
        d.ok = 1; d.op = op; d.next = 1;
        return;
    }
    d.is_push = 1;
    uint32_t nSize = 0;
    if (op < 0x4cu) {
        nSize = op;
    } else if (op == 0x4cu) {
        if (slen - pc < 1) { d.op = op; return; }
        nSize = cb(s, pc);
        pc += 1;
        d.first = nSize ? cb(s, pc) : 0;
    } else if (op == 0x4du) {
        if (slen - pc < 2) { d.op = op; return; }
        nSize = cb(s, pc) | (cb(s, pc + 1) << 8);
        pc += 2;
        d.first = nSize ? cb(s, pc) : 0;
    } else {
        if (slen - pc < 4) { d.op = op; return; }
        nSize = cb(s, pc) | (cb(s, pc + 1) << 8) |
                (cb(s, pc + 2) << 16) | (cb(s, pc + 3) << 24);
        pc += 4;
        d.first = nSize ? cb(s, pc) : 0;
    }
    if (slen - pc < nSize) { d.op = op; return; }       // truncated push
    if (op < 0x4cu && nSize) d.first = cb(s, 1);
    d.ok = 1; d.op = op; d.dlen = nSize; d.next = pc + nSize;
}

// script.cpp:373-396 — CheckMinimalPush(vchPushValue, opcode).  Reads only
// data.size() and data[0], exactly like Core.
CINLINE uint32_t c_check_minimal(uint32_t dlen, uint32_t first, uint32_t op) {
    if (dlen == 0) return op == 0x00u;                  // OP_0
    if (dlen == 1 && first >= 1 && first <= 16) return 0;
    if (dlen == 1 && first == 0x81u) return 0;
    if (dlen <= 75) return op == dlen;
    if (dlen <= 255) return op == 0x4cu;
    if (dlen <= 65535) return op == 0x4du;
    return 1;
}

// Payload window equality for one of the four encodings: is s[start .. start
// +dlen) byte-equal to p[0 .. dlen)?  `start` is a template parameter so the
// byte indices are compile-time constants (1/2/3/5 for direct/PUSHDATA1/2/4).
// The fold is a branchless accumulate (an XOR mask over the in-range bytes)
// so the SAW model of this leaf stays a straight-line term.
template <uint32_t START>
CINLINE uint32_t c_window_eq(uint32_t dlen, uint32_t plen, const uint64_t* p,
                             const uint64_t* s) {
    uint32_t diff = 0;
#pragma clang loop unroll(full)
    for (uint32_t i = 0; i < MAX_PLEN; ++i) {
        diff |= (i < dlen) ? (cb(s, START + i) ^ cb(p, i)) : 0u;
    }
    return (dlen == plen) && (diff == 0);
}

CINLINE uint32_t c_elem_eq(const CDec& d, uint32_t plen, const uint64_t* p,
                           const uint64_t* s) {
    if (!d.is_push) return 0;
    if (d.op < 0x4cu) return c_window_eq<1>(d.dlen, plen, p, s);
    if (d.op == 0x4cu) return c_window_eq<2>(d.dlen, plen, p, s);
    if (d.op == 0x4du) return c_window_eq<3>(d.dlen, plen, p, s);
    if (d.op == 0x4eu) return c_window_eq<5>(d.dlen, plen, p, s);
    return 0;
}

CINLINE uint64_t c_pack(uint32_t kind, uint32_t np, const uint8_t* pre) {
    uint64_t r = kind & 3u;
    r |= static_cast<uint64_t>(np & 0xfu) << 2;
    for (uint32_t i = 0; i < 5; ++i)
        r |= static_cast<uint64_t>(pre[i]) << (6 + 8 * i);
    return r;
}

}  // namespace

// ---------------------------------------------------------------------------
// 1. Canonical push prefix: `CScript() << vector(data)` (script.h:408-424).
//    Output: kind(2) | nprefix(4)<<2 | prefix bytes 0..4 (8 bits each)<<6.
//    kind 0 direct, 1 PUSHDATA1, 2 PUSHDATA2, 3 PUSHDATA4.
// ---------------------------------------------------------------------------
extern "C" uint64_t cell_canon_prefix(uint64_t dlen) {
    if (dlen > 0xffffffffull) return 3;                 // out of cell domain
    uint32_t kind = 0, np = 0;
    uint8_t pre[5] = {0, 0, 0, 0, 0};
    c_append_data_size(static_cast<uint32_t>(dlen), kind, np, pre);
    return c_pack(kind, np, pre);
}

// ---------------------------------------------------------------------------
// 2. scriptSig single-push production (interpreter.cpp:476-503, 487-488,
//    2029-2031): decode the first opcode of scriptSig, and report whether the
//    scriptSig is exactly one complete push (`single`), the pushed element
//    length, and the EvalScript error this one-op script would produce.
//    Output: ok(1) | is_push(1)<<1 | single(1)<<2 | depth(2)<<3
//            | err(6)<<5 | op(8)<<11 | dlen(16)<<19 | next(16)<<35
//            | min_ok(1)<<51
// ---------------------------------------------------------------------------
extern "C" uint64_t cell_sig_push(uint64_t slen, uint64_t s0, uint64_t s1,
                                  uint64_t s2, uint64_t s3, uint64_t s4,
                                  uint64_t s5, uint64_t s6,
                                  uint64_t minimaldata) {
    if (slen > MAX_SLEN) return 3;                      // out of cell domain
    const uint64_t S[7] = {s0, s1, s2, s3, s4, s5, s6};
    const uint32_t n = static_cast<uint32_t>(slen);
    CDec d;
    c_get_script_op(n, S, d);
    if (!d.ok) {
        // Core's GetScriptOp writes opcodeRet before failing (it sets
        // OP_INVALIDOPCODE, then the wire opcode); EvalScript returns
        // BAD_OPCODE immediately and never observes it (487-488).  The
        // packed observables are therefore defined only on a successful
        // decode: a failure reports the failure, not the partial decode.
        d.op = 0; d.is_push = 0; d.dlen = 0; d.next = 0; d.first = 0;
    }
    const uint32_t single = d.ok && d.is_push && d.next == n;
    const uint32_t min_ok = d.ok && c_check_minimal(d.dlen, d.first, d.op);
    uint32_t err = 0;
    if (!d.ok) err = 16;                                // SCR_ERR_BAD_OPCODE
    else if (single && (minimaldata & 1u) && !min_ok) err = 25;  // MINIMALDATA
    const uint32_t depth = single ? 1u : 0u;            // one push, one item
    uint64_t r = d.ok & 1u;
    r |= static_cast<uint64_t>(d.is_push & 1u) << 1;
    r |= static_cast<uint64_t>(single & 1u) << 2;
    r |= static_cast<uint64_t>(depth & 3u) << 3;
    r |= static_cast<uint64_t>(err & 0x3fu) << 5;
    r |= static_cast<uint64_t>(d.op & 0xffu) << 11;
    r |= static_cast<uint64_t>(d.dlen & 0xffffu) << 19;
    r |= static_cast<uint64_t>(d.next & 0xffffu) << 35;
    r |= static_cast<uint64_t>(min_ok & 1u) << 51;
    return r;
}

// ---------------------------------------------------------------------------
// 3. The 2092 guard, composed with the scriptSig single-push production.
//    Output: verdict(2) | err(6)<<2 | eq(1)<<8 | single(1)<<9
//            | elem_eq(1)<<10 | elem_len(8)<<11 | wit(1)<<19
//      verdict 0 reject, 1 pass, 3 out-of-domain (scriptSig is not exactly
//      one complete push, so EvalScript's loop is outside this cell).
//      err 0/16/25/42, Core ordinals (contract/error_kind.h).
// ---------------------------------------------------------------------------
extern "C" uint64_t cell_p2sh_guard(uint64_t plen, uint64_t p0, uint64_t p1,
                                    uint64_t p2, uint64_t p3, uint64_t p4,
                                    uint64_t p5, uint64_t slen, uint64_t s0,
                                    uint64_t s1, uint64_t s2, uint64_t s3,
                                    uint64_t s4, uint64_t s5, uint64_t s6,
                                    uint64_t minimaldata) {
    if (plen > MAX_PLEN || slen > MAX_SLEN) return 3;   // out of cell domain
    const uint64_t P[6] = {p0, p1, p2, p3, p4, p5};
    const uint64_t S[7] = {s0, s1, s2, s3, s4, s5, s6};
    const uint32_t pn = static_cast<uint32_t>(plen);
    const uint32_t sn = static_cast<uint32_t>(slen);

    // interpreter.cpp:2092 — scriptSig != CScript() << vector(pubKey2).
    // On the row domain AppendDataSize(pn) is the single byte `pn`, so the
    // compared bytes are [pn] ++ p[0..pn).  This is the whole-scriptSig byte
    // comparison; nothing is decoded here.  Branchless XOR fold.
    uint32_t diff = 0;
#pragma clang loop unroll(full)
    for (uint32_t i = 0; i < MAX_PLEN; ++i) {
        diff |= (i < pn) ? (cb(S, 1 + i) ^ cb(P, i)) : 0u;
    }
    const uint32_t eq = (sn == pn + 1u) && (cb(S, 0) == pn) && (diff == 0);

    // The producing scriptSig evaluation (2029-2031) for the single-push
    // domain, plus its pre-2092 errors: BAD_OPCODE (487-488) and the
    // MINIMALDATA gate (491-503).
    CDec d;
    c_get_script_op(sn, S, d);
    const uint32_t single = d.ok && d.is_push && d.next == sn;
    const uint32_t min_ok = c_check_minimal(d.dlen, d.first, d.op);
    const uint32_t wit = c_is_witness_program(pn, P);
    const uint32_t elem_eq = single ? c_elem_eq(d, pn, P, S) : 0u;
    const uint32_t elem_len = single ? (d.dlen & 0xffu) : 0u;

    uint32_t verdict = 1, err = 0;
    if (!d.ok) {                       // scriptSig eval failed: BAD_OPCODE
        verdict = 0; err = 16;
    } else if (!single) {              // not a single push: out of model
        verdict = 3; err = 0;
    } else if ((minimaldata & 1u) && !min_ok) {
        verdict = 0; err = 25;         // MINIMALDATA precedes the 42 guard
    } else if (wit && !eq) {
        verdict = 0; err = 42;         // WITNESS_MALLEATED_P2SH (2092-2096)
    }

    uint64_t r = verdict & 3u;
    r |= static_cast<uint64_t>(err & 0x3fu) << 2;
    r |= static_cast<uint64_t>(eq & 1u) << 8;
    r |= static_cast<uint64_t>(single & 1u) << 9;
    r |= static_cast<uint64_t>(elem_eq & 1u) << 10;
    r |= static_cast<uint64_t>(elem_len & 0xffu) << 11;
    r |= static_cast<uint64_t>(wit & 1u) << 19;
    return r;
}
