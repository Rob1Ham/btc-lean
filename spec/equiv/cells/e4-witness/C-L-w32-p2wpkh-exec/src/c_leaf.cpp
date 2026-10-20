// C leg for cell e4-witness/C-L-w32-p2wpkh-exec (SCR-136 execution half).
//
// Line-cited source-excerpt slice of Bitcoin Core at the pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66:
//
//   src/script/interpreter.cpp:1947-1953
//       P2WPKH (20-byte v0 program) arm: arity != 2 -> WITNESS_PROGRAM_MISMATCH;
//       exec_script << OP_DUP << OP_HASH160 << program << OP_EQUALVERIFY
//                   << OP_CHECKSIG; ExecuteWitnessScript(...)
//   src/script/interpreter.cpp:1842-1879
//       ExecuteWitnessScript: per-item size cap (PUSH_SIZE), EvalScript, implicit
//       witness cleanstack (CLEANSTACK), CastToBool (EVAL_FALSE)
//   src/script/interpreter.cpp:446-490
//       EvalScript prologue + the per-op checks the loop performs: SCRIPT_SIZE,
//       GetOp failure -> BAD_OPCODE, pushed value <= MAX_SCRIPT_ELEMENT_SIZE,
//       opcode budget (opcode > OP_16), disabled opcodes.  The terminal
//       1000-item STACK_SIZE guard cannot fire at depth <= 4.
//   src/script/interpreter.cpp:803-812        case OP_DUP
//   src/script/interpreter.cpp:896-925        case OP_EQUAL / OP_EQUALVERIFY
//   src/script/interpreter.cpp:1032-1059      case OP_HASH160 (dispatch point)
//   src/script/interpreter.cpp:1069-1088      case OP_CHECKSIG / OP_CHECKSIGVERIFY
//   src/script/interpreter.cpp:46-59          CastToBool
//   src/script/script.cpp:313-363             GetScriptOp
//   src/script/script.h:29,32                 MAX_SCRIPT_ELEMENT_SIZE, MAX_OPS_PER_SCRIPT
//   src/script/script.h:408-431,470-488       implied-script byte emission (as in
//                                             cell C-L-w32-p2wpkh-build)
//
// This cell is bounded and loop-free on purpose: the implied script has exactly
// five instructions, so the EvalScript loop and GetScriptOp walk are unrolled
// five times.  The 25-byte script is represented as a pure byte selector
// (c_script_byte); there is no buffer, heap or call.  Stack elements are a
// 20-byte payload window plus an explicit length (head slot = top of stack).
//
// Two pieces of the row are *seams*, exposed as ordinary symbolic inputs and
// therefore universally quantified by the proof (see spec.md):
//   * h0,h1,h2   = the modelled HASH160(pubkey) result (20 bytes);
//   * ck_err/ck_ok = the modelled EvalChecksig outcome for witness-v0
//                    (0/ok, or a Core ScriptError ordinal).
// The verified statement is parametric in both: it holds for every possible
// HASH160 and every possible signature checker.  Instantiating them with the
// real implementations is the remaining obligation (see notes.md).

#include <cstdint>

#define XINLINE static inline __attribute__((always_inline))

// Packed observable: result (2 bits) | error ordinal (6 bits) << 2.
// ABI v2 (spec/equiv/contract/ABI.md §2): result 2/3 carry UNKNOWN_ERROR.
XINLINE uint64_t x_pack(uint32_t result, uint32_t error) {
    return (uint64_t)(result & 3u) | ((uint64_t)(error & 0x3fu) << 2);
}

// Out-of-domain arm: the decoded instruction stream is not the implied P2WPKH
// script (only reachable for a mutated builder or a mutated decoder).
XINLINE uint64_t x_sent(void) { return x_pack(2u, 1u); }

// Core ScriptError ordinals used by this slice (contract/error_enum.md).
enum : uint32_t {
    C_OK = 0,
    C_EVAL_FALSE = 2,
    C_PUSH_SIZE = 6,
    C_OP_COUNT = 7,
    C_EQUALVERIFY = 12,
    C_CHECKSIGVERIFY = 14,
    C_BAD_OPCODE = 16,
    C_DISABLED_OPCODE = 17,
    C_INVALID_STACK_OPERATION = 18,
    C_CLEANSTACK = 30,
    C_WITNESS_PROGRAM_MISMATCH = 40,
};

XINLINE uint64_t c_pack_err(uint32_t e) { return x_pack(0u, e); }

// ---------------------------------------------------------------------------
// The constructed implied script, as a pure byte selector.
//
// interpreter.cpp:1952 emits
//   OP_DUP(0x76) OP_HASH160(0xa9) push20(0x14) program[0..19] OP_EQUALVERIFY(0x88)
//   OP_CHECKSIG(0xac)
// with the emissions of script.h:408-431 (data-size prefix) and
// script.h:470-488 (one byte per opcode, AppendData copies the span).
// Bytes 25..31 exist only to keep the selector total; they are never parsed.
// ---------------------------------------------------------------------------
XINLINE uint64_t c_program_byte(uint64_t p0, uint64_t p1, uint64_t p2,
                                uint32_t k) {
    if (k < 8) return (p0 >> (8u * k)) & 0xffu;
    if (k < 16) return (p1 >> (8u * (k - 8))) & 0xffu;
    return (p2 >> (8u * (k - 16))) & 0xffu;   // k in 16..19, low 32 bits
}

XINLINE uint64_t c_script_byte(uint64_t p0, uint64_t p1, uint64_t p2,
                               uint32_t i) {
    if (i == 0) return 0x76u;                 // OP_DUP
    if (i == 1) return 0xa9u;                 // OP_HASH160
    if (i == 2) return 0x14u;                 // PUSHDATA length 20
    if (i >= 3 && i <= 22) return c_program_byte(p0, p1, p2, i - 3);
    if (i == 23) return 0x88u;                // OP_EQUALVERIFY
    if (i == 24) return 0xacu;                // OP_CHECKSIG
    return 0u;
}

// One decoded instruction (the fields GetOp hands to the loop).
struct C_Dec {
    uint32_t op;     // opcode byte
    uint32_t off;    // offset of the push payload, when op <= OP_PUSHDATA4
    uint32_t dlen;   // push payload length (0 for non-pushes)
};

// GetScriptOp (script.cpp:313-363), bounded to the implied script.  pc/end are
// indices into the pure byte selector.  Returns false on a malformed walk.
XINLINE bool c_get_op(uint64_t p0, uint64_t p1, uint64_t p2, uint32_t end,
                      uint32_t& pc, C_Dec& d) {
    if (pc >= end) return false;
    const uint32_t op = (uint32_t)c_script_byte(p0, p1, p2, pc);
    pc += 1;
    d.op = op;
    d.off = pc;
    d.dlen = 0;
    if (op <= 0x4eu) {                        // OP_PUSHDATA4 and below
        uint32_t n = 0;
        if (op < 0x4cu) {                     // direct push, incl. OP_0
            n = op;
        } else if (op == 0x4cu) {             // OP_PUSHDATA1
            if (end - pc < 1) return false;
            n = (uint32_t)c_script_byte(p0, p1, p2, pc);
            pc += 1;
        } else if (op == 0x4du) {             // OP_PUSHDATA2
            if (end - pc < 2) return false;
            n = (uint32_t)c_script_byte(p0, p1, p2, pc) |
                ((uint32_t)c_script_byte(p0, p1, p2, pc + 1) << 8);
            pc += 2;
        } else {                              // OP_PUSHDATA4
            if (end - pc < 4) return false;
            n = (uint32_t)c_script_byte(p0, p1, p2, pc) |
                ((uint32_t)c_script_byte(p0, p1, p2, pc + 1) << 8) |
                ((uint32_t)c_script_byte(p0, p1, p2, pc + 2) << 16) |
                ((uint32_t)c_script_byte(p0, p1, p2, pc + 3) << 24);
            pc += 4;
        }
        if (end - pc < n) return false;
        d.off = pc;
        d.dlen = n;
        pc += n;
    }
    return true;
}

// ---------------------------------------------------------------------------
// Bounded valtype: a 20-byte payload window plus the true element length.
// ---------------------------------------------------------------------------
struct C_Elem {
    uint64_t w0, w1, w2;   // payload bytes 0..7, 8..15, 16..19 (low 32 bits)
    uint64_t len;          // valtype size (bytes)
};

// Head slot = top of stack, mirroring CScriptWitness::stack back() == stacktop(-1)
// through an explicit re-indexing.  Six slots cover the implied script's peak
// depth 4; the three spare slots make the shift helpers unconditional.
struct C_Stack {
    C_Elem t0, t1, t2, t3, t4, t5;
    uint32_t n;
    uint32_t opcount;
};

XINLINE C_Elem c_top_at(const C_Stack& s, uint32_t k) {   // stacktop(-k)
    if (k == 1) return s.t0;
    if (k == 2) return s.t1;
    if (k == 3) return s.t2;
    if (k == 4) return s.t3;
    if (k == 5) return s.t4;
    return s.t5;
}

XINLINE void c_push(C_Stack& s, C_Elem v) {   // stack.push_back(v)
    s.t5 = s.t4;
    s.t4 = s.t3;
    s.t3 = s.t2;
    s.t2 = s.t1;
    s.t1 = s.t0;
    s.t0 = v;
    s.n += 1;
}

XINLINE void c_pop(C_Stack& s) {              // popstack(stack)
    s.t0 = s.t1;
    s.t1 = s.t2;
    s.t2 = s.t3;
    s.t3 = s.t4;
    s.t4 = s.t5;
    s.t5 = C_Elem{0, 0, 0, 0};
    s.n -= 1;
}

XINLINE uint64_t c_low_mask(uint64_t k) {     // k <= 8
    return k >= 8 ? ~0ull : ((1ull << (8u * k)) - 1ull);
}

// `bool fEqual = (vch1 == vch2)` (interpreter.cpp:906): std::vector equality is
// length first, then the `len` bytes.  The 20-byte window is exact for every
// value compared by the implied script (both operands are 20 bytes); len > 20
// is outside the modelled payload window.
XINLINE bool c_valtype_eq(C_Elem a, C_Elem b) {
    if (a.len != b.len) return false;
    if (a.len > 20) return false;
    const uint64_t m0 = c_low_mask(a.len < 8 ? a.len : 8);
    if ((a.w0 & m0) != (b.w0 & m0)) return false;
    const uint64_t k1 = a.len > 8 ? a.len - 8 : 0;
    const uint64_t m1 = c_low_mask(k1 < 8 ? k1 : 8);
    if ((a.w1 & m1) != (b.w1 & m1)) return false;
    const uint64_t k2 = a.len > 16 ? a.len - 16 : 0;
    const uint64_t m2 = c_low_mask(k2 < 8 ? k2 : 8) & 0xffffffffull;
    return (a.w2 & m2) == (b.w2 & m2);
}

// CastToBool (interpreter.cpp:46-59): false for empty, all-zero, or negative
// zero; true otherwise.
XINLINE bool c_cast_to_bool(C_Elem a) {
    if (a.len == 0) return false;
    if (a.len > 20) return false;             // outside the payload window
    const uint64_t m0 = c_low_mask(a.len < 8 ? a.len : 8);
    const uint64_t k1 = a.len > 8 ? a.len - 8 : 0;
    const uint64_t m1 = c_low_mask(k1 < 8 ? k1 : 8);
    const uint64_t k2 = a.len > 16 ? a.len - 16 : 0;
    const uint64_t m2 = c_low_mask(k2 < 8 ? k2 : 8) & 0xffffffffull;
    const uint64_t r0 = a.w0 & m0;
    const uint64_t r1 = a.w1 & m1;
    const uint64_t r2 = a.w2 & m2;
    if ((r0 | r1 | r2) == 0) return false;
    // last byte of the value
    uint64_t last;
    if (a.len <= 8) {
        last = (r0 >> (8u * (a.len - 1))) & 0xffu;
    } else if (a.len <= 16) {
        last = (r1 >> (8u * (a.len - 9))) & 0xffu;
    } else {
        last = (r2 >> (8u * (a.len - 17))) & 0xffu;
    }
    if (last != 0x80u) return true;
    // negative zero: the 0x80 must be the only non-zero byte
    if (a.len <= 8) {
        return (r0 & ~(0x80ull << (8u * (a.len - 1)))) != 0;
    } else if (a.len <= 16) {
        return ((r1 & ~(0x80ull << (8u * (a.len - 9)))) | r0) != 0;
    }
    return ((r2 & ~(0x80ull << (8u * (a.len - 17)))) | (r1 | r0)) != 0;
}

// Disabled opcodes (interpreter.cpp:467-482): OP_CAT, OP_SUBSTR, OP_LEFT,
// OP_RIGHT, OP_INVERT, OP_AND, OP_OR, OP_XOR, OP_2MUL, OP_2DIV, OP_MUL,
// OP_DIV, OP_MOD, OP_LSHIFT, OP_RSHIFT.
XINLINE bool c_is_disabled(uint32_t w) {
    return w == 0x7eu || w == 0x7fu || w == 0x80u || w == 0x81u ||
           w == 0x83u || w == 0x84u || w == 0x85u || w == 0x86u ||
           w == 0x8du || w == 0x8eu || w == 0x95u || w == 0x96u ||
           w == 0x97u || w == 0x98u || w == 0x99u;
}

// Read 8 script bytes at off+j as a little-endian word (payload copy).
XINLINE uint64_t c_read_word(uint64_t p0, uint64_t p1, uint64_t p2,
                             uint32_t off, uint32_t j) {
    return c_script_byte(p0, p1, p2, off + j) |
           (c_script_byte(p0, p1, p2, off + j + 1) << 8) |
           (c_script_byte(p0, p1, p2, off + j + 2) << 16) |
           (c_script_byte(p0, p1, p2, off + j + 3) << 24) |
           (c_script_byte(p0, p1, p2, off + j + 4) << 32) |
           (c_script_byte(p0, p1, p2, off + j + 5) << 40) |
           (c_script_byte(p0, p1, p2, off + j + 6) << 48) |
           (c_script_byte(p0, p1, p2, off + j + 7) << 56);
}

// The two crypto seams, as inputs.
struct C_Ctx {
    uint64_t h0, h1, h2;   // modelled HASH160(pubkey), 20 bytes
    uint64_t ck_err;       // modelled EvalChecksig error ordinal (0 = none)
    uint64_t ck_ok;        // modelled EvalChecksig fSuccess when ck_err == 0
};

// Sentinel for "instruction outside this cell's closed dispatch".
static const uint64_t C_SENT = 0xffffffffull;

// One EvalScript iteration: checks from interpreter.cpp:457-482 then the
// opcode switch for the instructions that can appear in the implied script.
XINLINE uint64_t c_step(C_Stack& s, const C_Dec& d, uint64_t p0, uint64_t p1,
                        uint64_t p2, const C_Ctx& c) {
    const uint32_t w = d.op;

    // interpreter.cpp:457-459: pushed value size (executed or not).
    if (d.dlen > 520u) return C_PUSH_SIZE;

    // interpreter.cpp:462-465: opcode budget; OP_16 does not count.
    if (w > 0x60u) {
        s.opcount += 1;
        if (s.opcount > 201u) return C_OP_COUNT;
    }

    // interpreter.cpp:467-482: disabled opcodes, unexecuted branches included.
    if (c_is_disabled(w)) return C_DISABLED_OPCODE;

    if (w <= 0x4eu) {                          // push of dlen payload bytes
        if (d.dlen > 20u) return C_SENT;       // outside the 20-byte window
        C_Elem v;
        v.w0 = c_read_word(p0, p1, p2, d.off, 0);
        v.w1 = c_read_word(p0, p1, p2, d.off, 8);
        v.w2 = c_read_word(p0, p1, p2, d.off, 16) & 0xffffffffull;
        v.len = d.dlen;
        c_push(s, v);
        return C_OK;
    }
    if (w == 0x4fu) {                          // OP_1NEGATE -> {-1}
        c_push(s, C_Elem{0x81u, 0, 0, 1});
        return C_OK;
    }
    if (w >= 0x51u && w <= 0x60u) {            // OP_1..OP_16 -> {n}
        c_push(s, C_Elem{(uint64_t)(w - 0x50u), 0, 0, 1});
        return C_OK;
    }

    if (w == 0x76u) {                          // OP_DUP: (x -- x x)
        if (s.n < 1) return C_INVALID_STACK_OPERATION;
        c_push(s, c_top_at(s, 1));
        return C_OK;
    }

    if (w == 0xa9u) {                          // OP_HASH160: (in -- hash)
        if (s.n < 1) return C_INVALID_STACK_OPERATION;
        // interpreter.cpp:1048-1056 computes CHash160(vch); the result is the
        // declared hash seam, pushed in place of the top item.
        C_Elem h;
        h.w0 = c.h0;
        h.w1 = c.h1;
        h.w2 = c.h2 & 0xffffffffull;
        h.len = 20;
        s.t0 = h;
        return C_OK;
    }

    if (w == 0x87u || w == 0x88u) {            // OP_EQUAL / OP_EQUALVERIFY
        if (s.n < 2) return C_INVALID_STACK_OPERATION;
        const bool fEqual = c_valtype_eq(c_top_at(s, 2), c_top_at(s, 1));
        c_pop(s);
        c_pop(s);
        if (w == 0x87u) {
            c_push(s, fEqual ? C_Elem{1, 0, 0, 1} : C_Elem{0, 0, 0, 0});
            return C_OK;
        }
        if (fEqual) return C_OK;
        return C_EQUALVERIFY;
    }

    if (w == 0xacu || w == 0xadu) {            // OP_CHECKSIG / ...VERIFY
        if (s.n < 2) return C_INVALID_STACK_OPERATION;
        // interpreter.cpp:1070-1084: EvalChecksig decides; its error is
        // returned as-is, otherwise fSuccess becomes vchTrue/vchFalse.
        if (c.ck_err != 0) return (uint32_t)(c.ck_err & 0x3fu);
        const bool fSuccess = c.ck_ok != 0;
        c_pop(s);
        c_pop(s);
        c_push(s, fSuccess ? C_Elem{1, 0, 0, 1} : C_Elem{0, 0, 0, 0});
        if (w == 0xadu) {
            if (!fSuccess) return C_CHECKSIGVERIFY;
            c_pop(s);
        }
        return C_OK;
    }

    return C_SENT;                             // instruction outside the slice
}

extern "C" uint64_t cell_p2wpkh_exec(
    uint64_t p0, uint64_t p1, uint64_t p2,     // 20-byte witness program
    uint64_t n_wit,                            // witness stack size
    uint64_t sig_len, uint64_t pk_len,         // witness item sizes (bytes)
    uint64_t h0, uint64_t h1, uint64_t h2,     // HASH160(pk) seam (20 bytes)
    uint64_t ck_err, uint64_t ck_ok) {         // EvalChecksig seam

    // interpreter.cpp:1948-1950: BIP141 P2WPKH requires exactly two items.
    if (n_wit != 2u) return c_pack_err(C_WITNESS_PROGRAM_MISMATCH);

    // interpreter.cpp:1869-1871: witness stack items <= MAX_SCRIPT_ELEMENT_SIZE.
    if (sig_len > 520u || pk_len > 520u) return c_pack_err(C_PUSH_SIZE);

    C_Stack s{};
    s.n = 0;
    s.opcount = 0;

    // Witness stack, first item bottom: [sig, pk]; head slot is the top (pk).
    // The byte contents of sig/pk are opaque here: the implied script only
    // copies pk (OP_DUP) and hands both to the checksig seam.
    c_push(s, C_Elem{0, 0, 0, sig_len});
    c_push(s, C_Elem{0, 0, 0, pk_len});

    // The checksig error seam is the ABI's 6-bit ScriptError field; bits 6..63
    // are not part of it (contract/error_enum.md: EQUIV_ERR_COUNT = 55).
    C_Ctx c{h0, h1, h2, ck_err & 0x3fu, ck_ok};
    const uint32_t end = 25;
    uint32_t pc = 0;
    C_Dec d{};
    uint64_t r;

    // EvalScript's loop, unrolled over the implied script's five instructions
    // (script size 25 << MAX_SCRIPT_SIZE, so the size pre-check never fires).
    if (!c_get_op(p0, p1, p2, end, pc, d)) return c_pack_err(C_BAD_OPCODE);
    r = c_step(s, d, p0, p1, p2, c);
    if (r == C_SENT) return x_sent();
    if (r != C_OK) return c_pack_err((uint32_t)r);

    if (!c_get_op(p0, p1, p2, end, pc, d)) return c_pack_err(C_BAD_OPCODE);
    r = c_step(s, d, p0, p1, p2, c);
    if (r == C_SENT) return x_sent();
    if (r != C_OK) return c_pack_err((uint32_t)r);

    if (!c_get_op(p0, p1, p2, end, pc, d)) return c_pack_err(C_BAD_OPCODE);
    r = c_step(s, d, p0, p1, p2, c);
    if (r == C_SENT) return x_sent();
    if (r != C_OK) return c_pack_err((uint32_t)r);

    if (!c_get_op(p0, p1, p2, end, pc, d)) return c_pack_err(C_BAD_OPCODE);
    r = c_step(s, d, p0, p1, p2, c);
    if (r == C_SENT) return x_sent();
    if (r != C_OK) return c_pack_err((uint32_t)r);

    if (!c_get_op(p0, p1, p2, end, pc, d)) return c_pack_err(C_BAD_OPCODE);
    r = c_step(s, d, p0, p1, p2, c);
    if (r == C_SENT) return x_sent();
    if (r != C_OK) return c_pack_err((uint32_t)r);

    // A sixth instruction would be outside the implied 25-byte script.
    if (pc != end) return x_sent();

    // interpreter.cpp:1876-1879: implicit witness cleanstack + CastToBool.
    if (s.n != 1u) return c_pack_err(C_CLEANSTACK);
    if (!c_cast_to_bool(c_top_at(s, 1))) return c_pack_err(C_EVAL_FALSE);
    return x_pack(1u, C_OK);
}
