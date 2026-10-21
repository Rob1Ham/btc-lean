// L leg for cell e4-witness/C-L-w32-p2wpkh-oracle-v0 (SCR-136, full row).
//
// Reviewed manual transliteration of the Lean model.  There is no generated
// twin body for executeWitnessScript / verifyWitnessProgram (the twin has no
// handler for either), so this is the reviewed-leg route the other e4 cells
// use; the byte-list construction and the five step semantics are indexed
// directly from:
//
//   spec/core/Bitcoin/Interpreter/Defs.lean:1259-1280
//       verifyWitnessProgram, v0 20-byte arm: witness.length != 2 ->
//       witnessProgramMismatch; implied script byte list
//       [0x76,0xa9,0x14] ++ program ++ [0x88,0xac]; executeWitnessScript
//   spec/core/Bitcoin/Interpreter/Defs.lean:1207-1236
//       executeWitnessScript: item size cap (pushSize), runExec, cleanstack,
//       castToBool -> evalFalse
//   spec/core/Bitcoin/Interpreter/Defs.lean:1163-1185
//       evalScriptBytes: SCRIPT_SIZE pre-check, parseWire, evalFrom, finalStack
//   spec/core/Bitcoin/Interpreter/Defs.lean:1144-1152
//       evalFrom: five-step unroll (the implied script parses to five wire ops)
//   spec/core/Bitcoin/Interpreter/Defs.lean:817-860, 940-1010, 1032-1059,
//       1131-1142
//       stepBody/stepChecked: pushSize, opCount, disabledWire, dispatch; the
//       terminal 1000-item STACK_SIZE guard cannot fire at depth <= 4
//   spec/core/Bitcoin/Interpreter/Defs.lean:1030-1036
//       OP_HASH160: hashForOp w (topAt st.stack 1) -- the *whole* top element
//   spec/core/Bitcoin/Interpreter/Defs.lean:1037-1052
//       OP_CHECKSIG/VERIFY: sig = topAt st.stack 2, pk = topAt st.stack 1,
//       evalChecksigDispatch ... signatureExecutionData ctx st ... st.codeSep
//       ctx.bytes (codeSep is 0 here: the implied script has no
//       OP_CODESEPARATOR, Defs.lean:1031-1032)
//   spec/core/Bitcoin/Interpreter/Defs.lean:720-739
//       evalChecksigPreTapscript: scriptCode0 = bytes.extract codeSep
//       bytes.size; WITNESS_V0 takes the non-base branch (no FindAndDelete)
//   spec/core/Bitcoin/Script/Parser/Defs.lean:206-231
//       getOpAux/getOp: the bounds-checked wire decode
//   spec/core/Bitcoin/Numeric/Interface.lean:64-65
//       castToBool = castToBoolList (bytesOf b).reverse
//
// The two crypto pieces are the same named oracle seams as the C leg:
// HASH160(pubkey) -> h0,h1,h2 and EvalChecksig -> (ck_err, ck_ok), both free
// inputs.  The oracle-interface export returns the argument words the Lean
// model hands to those seams, so the two legs are compared on the preimage /
// scriptCode they would hash and check, not only on the final outcome.

#include <cstdint>

#define XINLINE static inline __attribute__((always_inline))

XINLINE uint64_t l_pack(uint32_t result, uint32_t error) {
    return (uint64_t)(result & 3u) | ((uint64_t)(error & 0x3fu) << 2);
}

// Out-of-domain arm (`unjudged` at the leaf seam).
XINLINE uint64_t l_sent(void) { return l_pack(2u, 1u); }

static const uint64_t L_SEAM_SENT = 0xffffffffffffffffull;

enum : uint32_t {
    L_OK = 0,
    L_EVAL_FALSE = 2,
    L_PUSH_SIZE = 6,
    L_OP_COUNT = 7,
    L_EQUALVERIFY = 12,
    L_CHECKSIGVERIFY = 14,
    L_BAD_OPCODE = 16,
    L_DISABLED_OPCODE = 17,
    L_STACK_UNDERFLOW = 18,
    L_CLEANSTACK = 30,
    L_WITNESS_PROGRAM_MISMATCH = 40,
};

XINLINE uint64_t l_pack_err(uint32_t e) { return l_pack(0u, e); }

// ---------------------------------------------------------------------------
// Byte list of the implied script (Defs.lean:1272-1274):
//   [0x76, 0xa9, 0x14] ++ program ++ [0x88, 0xac]
// A total selector: indices 0..24 are the 25 script bytes, anything outside
// is 0 (never reached by a successful parse of this script).
// ---------------------------------------------------------------------------
XINLINE uint64_t l_program_byte(uint64_t p0, uint64_t p1, uint64_t p2,
                                uint32_t k) {
    if (k < 8) return (p0 >> (8u * k)) & 0xffu;
    if (k < 16) return (p1 >> (8u * (k - 8))) & 0xffu;
    if (k < 20) return (p2 >> (8u * (k - 16))) & 0xffu;
    return 0u;
}

XINLINE uint64_t l_script_byte(uint64_t p0, uint64_t p1, uint64_t p2,
                               uint32_t i) {
    if (i < 3) return i == 0 ? 0x76u : (i == 1 ? 0xa9u : 0x14u);
    if (i < 23) return l_program_byte(p0, p1, p2, i - 3);
    if (i == 23) return 0x88u;
    if (i == 24) return 0xacu;
    return 0u;
}

XINLINE uint64_t l_script_word(uint32_t k, uint64_t p0, uint64_t p1,
                               uint64_t p2) {
    if (k > 3u) return 0ull;
    const uint32_t b = 8u * k;
    const uint32_t i0 = b, i1 = b + 1u, i2 = b + 2u, i3 = b + 3u;
    const uint32_t i4 = b + 4u, i5 = b + 5u, i6 = b + 6u, i7 = b + 7u;
    uint64_t w = 0;
    if (i0 < 25u) w |= l_script_byte(p0, p1, p2, i0);
    if (i1 < 25u) w |= l_script_byte(p0, p1, p2, i1) << 8;
    if (i2 < 25u) w |= l_script_byte(p0, p1, p2, i2) << 16;
    if (i3 < 25u) w |= l_script_byte(p0, p1, p2, i3) << 24;
    if (i4 < 25u) w |= l_script_byte(p0, p1, p2, i4) << 32;
    if (i5 < 25u) w |= l_script_byte(p0, p1, p2, i5) << 40;
    if (i6 < 25u) w |= l_script_byte(p0, p1, p2, i6) << 48;
    if (i7 < 25u) w |= l_script_byte(p0, p1, p2, i7) << 56;
    return w;
}

// One getOp result.  `kind` mirrors the WireOp AST node:
//   0 = pushBytes (off/dlen), 1 = pushNum (num), 2 = op (wire byte).
struct L_Op {
    uint32_t kind;
    uint32_t wire;
    uint32_t next;
    uint32_t off;
    uint32_t dlen;
    uint32_t num;
};

// getOpAux (Script/Parser/Defs.lean:207-231), reading through the selector.
// Fuel: the caller only asks for an op while i < 25, which is parseWire's
// `b.size <= i` termination condition.
XINLINE bool l_get_op(uint64_t p0, uint64_t p1, uint64_t p2, uint32_t size,
                      uint32_t i, L_Op& o) {
    if (size <= i) return false;
    const uint32_t c = (uint32_t)l_script_byte(p0, p1, p2, i);
    o.wire = c;
    o.num = 0;
    o.off = 0;
    o.dlen = 0;
    if (c == 0u) {                              // OP_0: pushBytes empty
        o.kind = 0;
        o.off = i + 1;
        o.next = i + 1;
        return true;
    }
    if (c <= 0x4bu) {                           // direct push
        if (size - (i + 1) < c) return false;
        o.kind = 0;
        o.off = i + 1;
        o.dlen = c;
        o.next = i + 1 + c;
        return true;
    }
    if (c == 0x4cu) {                           // OP_PUSHDATA1
        if (size - (i + 1) < 1) return false;
        const uint32_t k = (uint32_t)l_script_byte(p0, p1, p2, i + 1);
        if (size - (i + 2) < k) return false;
        o.kind = 0;
        o.off = i + 2;
        o.dlen = k;
        o.next = i + 2 + k;
        return true;
    }
    if (c == 0x4du) {                           // OP_PUSHDATA2
        if (size - (i + 1) < 2) return false;
        const uint32_t k = (uint32_t)l_script_byte(p0, p1, p2, i + 1) |
                           ((uint32_t)l_script_byte(p0, p1, p2, i + 2) << 8);
        if (size - (i + 3) < k) return false;
        o.kind = 0;
        o.off = i + 3;
        o.dlen = k;
        o.next = i + 3 + k;
        return true;
    }
    if (c == 0x4eu) {                           // OP_PUSHDATA4
        if (size - (i + 1) < 4) return false;
        const uint32_t k = (uint32_t)l_script_byte(p0, p1, p2, i + 1) |
                           ((uint32_t)l_script_byte(p0, p1, p2, i + 2) << 8) |
                           ((uint32_t)l_script_byte(p0, p1, p2, i + 3) << 16) |
                           ((uint32_t)l_script_byte(p0, p1, p2, i + 4) << 24);
        if (size - (i + 5) < k) return false;
        o.kind = 0;
        o.off = i + 5;
        o.dlen = k;
        o.next = i + 5 + k;
        return true;
    }
    if (c == 0x4fu) {                           // OP_1NEGATE
        o.kind = 1;
        o.num = 0x81u;
        o.next = i + 1;
        return true;
    }
    if (c >= 0x51u && c <= 0x60u) {             // OP_1..OP_16
        o.kind = 1;
        o.num = c - 0x50u;
        o.next = i + 1;
        return true;
    }
    o.kind = 2;
    o.next = i + 1;
    return true;
}

// ---------------------------------------------------------------------------
// Bounded element: 20-byte payload window + true length + byte source.
// ---------------------------------------------------------------------------
enum : uint32_t {
    L_SRC_NONE = 0,
    L_SRC_PROGRAM = 1,
    L_SRC_HASH = 2,
    L_SRC_SIG = 3,
    L_SRC_PK = 4,
    L_SRC_SCRIPT = 5,
};

struct L_Elem {
    uint64_t w0, w1, w2;
    uint64_t len;
    uint32_t src;
};

// Stack with head slot = top (topAt st.stack 1).  Six slots cover depth <= 4.
struct L_Stack {
    L_Elem t0, t1, t2, t3, t4, t5;
    uint32_t n;
    uint32_t opCount;
};

XINLINE L_Elem l_top_at(const L_Stack& s, uint32_t k) {   // topAt stack k
    if (k == 1) return s.t0;
    if (k == 2) return s.t1;
    if (k == 3) return s.t2;
    if (k == 4) return s.t3;
    if (k == 5) return s.t4;
    return s.t5;
}

XINLINE void l_push(L_Stack& s, L_Elem v) {
    s.t5 = s.t4;
    s.t4 = s.t3;
    s.t3 = s.t2;
    s.t2 = s.t1;
    s.t1 = s.t0;
    s.t0 = v;
    s.n += 1;
}

XINLINE void l_pop(L_Stack& s) {
    s.t0 = s.t1;
    s.t1 = s.t2;
    s.t2 = s.t3;
    s.t3 = s.t4;
    s.t4 = s.t5;
    s.t5 = L_Elem{0, 0, 0, 0, L_SRC_NONE};
    s.n -= 1;
}

XINLINE uint64_t l_low_mask(uint64_t k) {
    // Same shift-free constant-byte form as the C leg (value unchanged; avoids
    // a speculative 64-bit shift at k == 8).
    uint64_t m = 0;
    if (k > 0u) m |= 0x00000000000000ffull;
    if (k > 1u) m |= 0x000000000000ff00ull;
    if (k > 2u) m |= 0x0000000000ff0000ull;
    if (k > 3u) m |= 0x00000000ff000000ull;
    if (k > 4u) m |= 0x000000ff00000000ull;
    if (k > 5u) m |= 0x0000ff0000000000ull;
    if (k > 6u) m |= 0x00ff000000000000ull;
    if (k > 7u) m |= 0xff00000000000000ull;
    return m;
}

// List equality on valtype bytes (Defs.lean evalStep OP_EQUAL arm): length
// first, then the bytes.  Both compared elements are 20 bytes in this script.
XINLINE bool l_bytes_eq(L_Elem a, L_Elem b) {
    if (a.len != b.len) return false;
    if (a.len > 20) return false;
    const uint64_t m0 = l_low_mask(a.len < 8 ? a.len : 8);
    if ((a.w0 & m0) != (b.w0 & m0)) return false;
    const uint64_t k1 = a.len > 8 ? a.len - 8 : 0;
    const uint64_t m1 = l_low_mask(k1 < 8 ? k1 : 8);
    if ((a.w1 & m1) != (b.w1 & m1)) return false;
    const uint64_t k2 = a.len > 16 ? a.len - 16 : 0;
    const uint64_t m2 = l_low_mask(k2 < 8 ? k2 : 8) & 0xffffffffull;
    return (a.w2 & m2) == (b.w2 & m2);
}

// castToBool (Numeric/Interface.lean:64-65): false for empty, all-zero, or
// negative zero; true otherwise.
XINLINE bool l_cast_to_bool(L_Elem a) {
    if (a.len == 0) return false;
    if (a.len > 20) return false;
    const uint64_t m0 = l_low_mask(a.len < 8 ? a.len : 8);
    const uint64_t k1 = a.len > 8 ? a.len - 8 : 0;
    const uint64_t m1 = l_low_mask(k1 < 8 ? k1 : 8);
    const uint64_t k2 = a.len > 16 ? a.len - 16 : 0;
    const uint64_t m2 = l_low_mask(k2 < 8 ? k2 : 8) & 0xffffffffull;
    const uint64_t r0 = a.w0 & m0;
    const uint64_t r1 = a.w1 & m1;
    const uint64_t r2 = a.w2 & m2;
    if ((r0 | r1 | r2) == 0) return false;
    uint64_t last;
    if (a.len <= 8) {
        last = (r0 >> (8u * (a.len - 1))) & 0xffu;
    } else if (a.len <= 16) {
        last = (r1 >> (8u * (a.len - 9))) & 0xffu;
    } else {
        last = (r2 >> (8u * (a.len - 17))) & 0xffu;
    }
    if (last != 0x80u) return true;
    if (a.len <= 8) {
        return (r0 & ~(0x80ull << (8u * (a.len - 1)))) != 0;
    } else if (a.len <= 16) {
        return ((r1 & ~(0x80ull << (8u * (a.len - 9)))) | r0) != 0;
    }
    return ((r2 & ~(0x80ull << (8u * (a.len - 17)))) | (r1 | r0)) != 0;
}

// disabledWire (Defs.lean:940-1010 table / interpreter.cpp:467-482 set).
XINLINE bool l_is_disabled(uint32_t w) {
    return w == 0x7eu || w == 0x7fu || w == 0x80u || w == 0x81u ||
           w == 0x83u || w == 0x84u || w == 0x85u || w == 0x86u ||
           w == 0x8du || w == 0x8eu || w == 0x95u || w == 0x96u ||
           w == 0x97u || w == 0x98u || w == 0x99u;
}

XINLINE uint64_t l_read_word(uint64_t p0, uint64_t p1, uint64_t p2,
                             uint32_t off, uint32_t j) {
    return l_script_byte(p0, p1, p2, off + j) |
           (l_script_byte(p0, p1, p2, off + j + 1) << 8) |
           (l_script_byte(p0, p1, p2, off + j + 2) << 16) |
           (l_script_byte(p0, p1, p2, off + j + 3) << 24) |
           (l_script_byte(p0, p1, p2, off + j + 4) << 32) |
           (l_script_byte(p0, p1, p2, off + j + 5) << 40) |
           (l_script_byte(p0, p1, p2, off + j + 6) << 48) |
           (l_script_byte(p0, p1, p2, off + j + 7) << 56);
}

struct L_Items {
    uint64_t s0, s1, s2, s3, s4, s5, s6, s7, s8, s9;
    uint64_t k0, k1, k2, k3, k4, k5, k6, k7, k8;
    uint64_t p0, p1, p2;
};

XINLINE uint64_t l_sel3(uint32_t k, uint64_t a0, uint64_t a1, uint64_t a2) {
    if (k == 0u) return a0;
    if (k == 1u) return a1;
    if (k == 2u) return a2;
    return 0ull;
}

XINLINE uint64_t l_sel9(uint32_t k, uint64_t a0, uint64_t a1, uint64_t a2,
                        uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6,
                        uint64_t a7, uint64_t a8) {
    if (k == 0u) return a0;
    if (k == 1u) return a1;
    if (k == 2u) return a2;
    if (k == 3u) return a3;
    if (k == 4u) return a4;
    if (k == 5u) return a5;
    if (k == 6u) return a6;
    if (k == 7u) return a7;
    if (k == 8u) return a8;
    return 0ull;
}

XINLINE uint64_t l_sel10(uint32_t k, uint64_t a0, uint64_t a1, uint64_t a2,
                         uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6,
                         uint64_t a7, uint64_t a8, uint64_t a9) {
    if (k == 0u) return a0;
    if (k == 1u) return a1;
    if (k == 2u) return a2;
    if (k == 3u) return a3;
    if (k == 4u) return a4;
    if (k == 5u) return a5;
    if (k == 6u) return a6;
    if (k == 7u) return a7;
    if (k == 8u) return a8;
    if (k == 9u) return a9;
    return 0ull;
}

XINLINE uint64_t l_word_mask(uint64_t len, uint32_t k) {
    const uint64_t off = (uint64_t)k * 8ull;
    if (len <= off) return 0ull;
    uint64_t n = len - off;
    if (n > 8ull) n = 8ull;
    return l_low_mask(n);
}

XINLINE uint64_t l_item_word(uint32_t src, uint32_t k, uint64_t len,
                             const L_Items& it) {
    uint64_t w = 0;
    if (src == L_SRC_PROGRAM) {
        w = l_sel3(k, it.p0, it.p1, it.p2);
    } else if (src == L_SRC_SIG) {
        w = l_sel10(k, it.s0, it.s1, it.s2, it.s3, it.s4, it.s5, it.s6, it.s7,
                    it.s8, it.s9);
    } else if (src == L_SRC_PK) {
        w = l_sel9(k, it.k0, it.k1, it.k2, it.k3, it.k4, it.k5, it.k6, it.k7,
                   it.k8);
    } else if (src == L_SRC_SCRIPT) {
        w = l_script_word(k, it.p0, it.p1, it.p2);
    }
    return w & l_word_mask(len, k);
}

enum : uint32_t {
    L_SEL_HASH_PRE = 0,
    L_SEL_SIG_WORD = 1,
    L_SEL_PK_WORD = 2,
    L_SEL_SC_WORD = 3,
    L_SEL_HASH_LEN = 4,
    L_SEL_HASH_OUT = 5,
    L_SEL_SIG_LEN = 6,
    L_SEL_PK_LEN = 7,
    L_SEL_SC_LEN = 8,
    L_SEL_NONE = 0xffffffffu,
};

struct L_Ctx {
    uint64_t h0, h1, h2;
    uint64_t ck_err;
    uint64_t ck_ok;
    uint32_t sel;
    uint32_t k;
};

struct L_StepRes {
    uint32_t kind;         // 0 = ok, 1 = ExecError, 2 = seam value
    uint32_t err;
    uint64_t val;
};

XINLINE L_StepRes l_ok(void) { return L_StepRes{0u, 0u, 0ull}; }
XINLINE L_StepRes l_err(uint32_t e) { return L_StepRes{1u, e, 0ull}; }
XINLINE L_StepRes l_seam(uint64_t v) { return L_StepRes{2u, 0u, v}; }

XINLINE bool l_hash_sel(uint32_t sel) {
    return sel == L_SEL_HASH_PRE || sel == L_SEL_HASH_LEN ||
           sel == L_SEL_HASH_OUT;
}

XINLINE bool l_ck_sel(uint32_t sel) {
    return (sel >= L_SEL_SIG_WORD && sel <= L_SEL_SC_WORD) ||
           (sel >= L_SEL_SIG_LEN && sel <= L_SEL_SC_LEN);
}

// stepBody (Defs.lean:817-1059): check order is size, opCount, disabled,
// dispatch.  Only the five implied-script operations have semantics here.
XINLINE L_StepRes l_step(L_Stack& s, const L_Op& op, const L_Items& it,
                         const L_Ctx& c) {
    const uint32_t w = op.wire;

    // (1) element size limit, executed or not (Defs.lean:820-824).
    if (op.kind == 0 && op.dlen > 520u) return l_err(L_PUSH_SIZE);
    // (2) opcode budget, base/witnessV0 only (Defs.lean:826-829).
    if (w > 0x60u) {
        s.opCount += 1;
        if (s.opCount > 201u) return l_err(L_OP_COUNT);
    }
    // (3) disabled table (Defs.lean:940-1010).
    if (l_is_disabled(w)) return l_err(L_DISABLED_OPCODE);

    // (4) dispatch.
    if (op.kind == 1) {                         // pushNum
        l_push(s, L_Elem{(uint64_t)op.num, 0, 0, 1, L_SRC_NONE});
        return l_ok();
    }
    if (op.kind == 0) {                         // pushBytes d
        if (op.dlen > 20u) return l_seam(L_SEAM_SENT);
        L_Elem v;
        v.w0 = l_read_word(it.p0, it.p1, it.p2, op.off, 0);
        v.w1 = l_read_word(it.p0, it.p1, it.p2, op.off, 8);
        v.w2 = l_read_word(it.p0, it.p1, it.p2, op.off, 16) & 0xffffffffull;
        v.len = op.dlen;
        v.src = L_SRC_PROGRAM;
        l_push(s, v);
        return l_ok();
    }

    if (w == 0x76u) {                           // OP_DUP (Defs.lean:9xx)
        if (s.n < 1) return l_err(L_STACK_UNDERFLOW);
        l_push(s, l_top_at(s, 1));
        return l_ok();
    }

    if (w == 0xa9u) {                           // OP_HASH160
        if (s.n < 1) return l_err(L_STACK_UNDERFLOW);
        const L_Elem in = l_top_at(s, 1);
        if (l_hash_sel(c.sel)) {
            if (in.src != L_SRC_PK) return l_seam(L_SEAM_SENT);
            if (c.sel == L_SEL_HASH_PRE) {
                return l_seam(l_item_word(L_SRC_PK, c.k, in.len, it));
            }
            if (c.sel == L_SEL_HASH_LEN) return l_seam(in.len);
            return l_seam(20ull);
        }
        // Defs.lean:1030-1036: hashForOp w (topAt st.stack 1); hashForOp for
        // 0xa9 is hash160 (20-byte output, Defs.lean:637-643).  The digest is
        // the declared hash seam.
        L_Elem h;
        h.w0 = c.h0;
        h.w1 = c.h1;
        h.w2 = c.h2 & 0xffffffffull;
        h.len = 20;
        h.src = L_SRC_HASH;
        s.t0 = h;
        return l_ok();
    }

    if (w == 0x87u || w == 0x88u) {             // OP_EQUAL / OP_EQUALVERIFY
        if (s.n < 2) return l_err(L_STACK_UNDERFLOW);
        const bool fEqual = l_bytes_eq(l_top_at(s, 2), l_top_at(s, 1));
        l_pop(s);
        l_pop(s);
        if (w == 0x87u) {
            l_push(s, fEqual ? L_Elem{1, 0, 0, 1, L_SRC_NONE}
                             : L_Elem{0, 0, 0, 0, L_SRC_NONE});
            return l_ok();
        }
        if (fEqual) return l_ok();
        return l_err(L_EQUALVERIFY);
    }

    if (w == 0xacu || w == 0xadu) {             // OP_CHECKSIG / ...VERIFY
        if (s.n < 2) return l_err(L_STACK_UNDERFLOW);
        const L_Elem sig = l_top_at(s, 2);      // topAt st.stack 2
        const L_Elem pk = l_top_at(s, 1);       // topAt st.stack 1
        if (l_ck_sel(c.sel)) {
            if (sig.src != L_SRC_SIG || pk.src != L_SRC_PK) {
                return l_seam(L_SEAM_SENT);
            }
            if (c.sel == L_SEL_SIG_WORD) {
                return l_seam(l_item_word(L_SRC_SIG, c.k, sig.len, it));
            }
            if (c.sel == L_SEL_PK_WORD) {
                return l_seam(l_item_word(L_SRC_PK, c.k, pk.len, it));
            }
            if (c.sel == L_SEL_SC_WORD) {
                // evalChecksigPreTapscript (Defs.lean:720-739):
                // scriptCode0 = bytes.extract codeSep bytes.size; codeSep is 0
                // here (no OP_CODESEPARATOR), so scriptCode is all 25 bytes.
                return l_seam(l_script_word(c.k, it.p0, it.p1, it.p2) &
                              l_word_mask(25ull, c.k));
            }
            if (c.sel == L_SEL_SIG_LEN) return l_seam(sig.len);
            if (c.sel == L_SEL_PK_LEN) return l_seam(pk.len);
            return l_seam(25ull);
        }
        // Defs.lean:1037-1052 + evalChecksigPreTapscript: the fused outcome is
        // the declared same-crypto seam (error first, then fSuccess).
        if (c.ck_err != 0) return l_err((uint32_t)(c.ck_err & 0x3fu));
        const bool fSuccess = c.ck_ok != 0;
        l_pop(s);
        l_pop(s);
        l_push(s, fSuccess ? L_Elem{1, 0, 0, 1, L_SRC_NONE}
                           : L_Elem{0, 0, 0, 0, L_SRC_NONE});
        if (w == 0xadu) {
            if (!fSuccess) return l_err(L_CHECKSIGVERIFY);
            l_pop(s);
        }
        return l_ok();
    }

    return l_seam(L_SEAM_SENT);                 // opcode outside this slice
}

struct L_Run {
    uint32_t kind;
    uint64_t val;
};

#define L_STEP_ONCE()                                                    \
    do {                                                                 \
        if (!l_get_op(it.p0, it.p1, it.p2, end, pc, o))                  \
            return L_Run{1u, L_BAD_OPCODE};                              \
        pc = o.next;                                                     \
        const L_StepRes r_ = l_step(s, o, it, c);                        \
        if (r_.kind == 1u) return L_Run{1u, r_.err};                     \
        if (r_.kind == 2u) return L_Run{2u, r_.val};                     \
    } while (0)

XINLINE L_Run l_run(const L_Items& it, const L_Ctx& c, uint64_t n_wit,
                    uint64_t sig_len, uint64_t pk_len) {
    // Defs.lean:1265-1270: witness.length != 2 -> witnessProgramMismatch.
    if (n_wit != 2u) return L_Run{1u, L_WITNESS_PROGRAM_MISMATCH};

    // Defs.lean:1207-1216: every witness item <= MAX_SCRIPT_ELEMENT_SIZE.
    if (sig_len > 520ull || pk_len > 520ull) return L_Run{1u, L_PUSH_SIZE};

    L_Stack s{};
    s.n = 0;
    s.opCount = 0;
    l_push(s, L_Elem{0, 0, 0, sig_len, L_SRC_SIG});
    l_push(s, L_Elem{0, 0, 0, pk_len, L_SRC_PK});

    // Defs.lean:1163-1185: SCRIPT_SIZE pre-check (25 << 10000), parseWire,
    // evalFrom unrolled here over the five implied instructions.
    const uint32_t end = 25;
    uint32_t pc = 0;
    L_Op o{};

    L_STEP_ONCE();   // OP_DUP
    L_STEP_ONCE();   // OP_HASH160
    L_STEP_ONCE();   // push <program>
    L_STEP_ONCE();   // OP_EQUALVERIFY
    L_STEP_ONCE();   // OP_CHECKSIG

    if (pc != end) return L_Run{2u, L_SEAM_SENT};

    // Defs.lean:1224-1236: implicit cleanstack + castToBool.
    if (s.n != 1u) return L_Run{1u, L_CLEANSTACK};
    if (!l_cast_to_bool(l_top_at(s, 1))) return L_Run{1u, L_EVAL_FALSE};
    return L_Run{0u, 0ull};
}

// (A) Total execution outcome, parametric in the two oracle seams.
extern "C" uint64_t cell_p2wpkh_scr136(
    uint64_t p0, uint64_t p1, uint64_t p2,
    uint64_t n_wit, uint64_t sig_len, uint64_t pk_len,
    uint64_t h0, uint64_t h1, uint64_t h2,
    uint64_t ck_err, uint64_t ck_ok) {
    L_Items it{};
    it.p0 = p0;
    it.p1 = p1;
    it.p2 = p2;
    const L_Ctx c{h0, h1, h2, ck_err & 0x3full, ck_ok, L_SEL_NONE, 0u};
    const L_Run r = l_run(it, c, n_wit, sig_len, pk_len);
    if (r.kind == 1u) return l_pack_err((uint32_t)r.val);
    if (r.kind == 2u) return l_sent();
    return l_pack(1u, L_OK);
}

// (B) Oracle-interface transcript, symbolic in sel and k.
extern "C" uint64_t cell_p2wpkh_seam(
    uint64_t sel, uint64_t k,
    uint64_t p0, uint64_t p1, uint64_t p2,
    uint64_t n_wit, uint64_t sig_len, uint64_t pk_len,
    uint64_t h0, uint64_t h1, uint64_t h2,
    uint64_t ck_err, uint64_t ck_ok,
    uint64_t s0, uint64_t s1, uint64_t s2, uint64_t s3, uint64_t s4,
    uint64_t s5, uint64_t s6, uint64_t s7, uint64_t s8, uint64_t s9,
    uint64_t k0, uint64_t k1, uint64_t k2, uint64_t k3, uint64_t k4,
    uint64_t k5, uint64_t k6, uint64_t k7, uint64_t k8) {
    const L_Items it{s0, s1, s2, s3, s4, s5, s6, s7, s8, s9,
                     k0, k1, k2, k3, k4, k5, k6, k7, k8, p0, p1, p2};
    const L_Ctx c{h0, h1, h2, ck_err & 0x3full, ck_ok,
                  (uint32_t)sel, (uint32_t)k};
    const L_Run r = l_run(it, c, n_wit, sig_len, pk_len);
    if (r.kind == 2u) return r.val;
    return L_SEAM_SENT;
}
