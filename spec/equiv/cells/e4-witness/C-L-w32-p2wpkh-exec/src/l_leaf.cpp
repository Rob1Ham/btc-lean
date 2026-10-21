// L leg for cell e4-witness/C-L-w32-p2wpkh-exec (SCR-136 execution half).
//
// Reviewed manual transliteration of the Lean model (there is no generated
// twin body for executeWitnessScript, so this is the reviewed-leg route the
// other e4 cells use):
//
//   spec/core/Bitcoin/Interpreter/Defs.lean:1259-1280
//       verifyWitnessProgram, v0 20-byte arm: witness.length ≠ 2 ->
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
//   spec/core/Bitcoin/Script/Parser/Defs.lean:206-231
//       getOpAux/getOp: the bounds-checked wire decode
//   spec/core/Bitcoin/Numeric/Interface.lean:64-65
//       castToBool = castToBoolList (bytesOf b).reverse
//
// Same two seams as the C leg, as symbolic inputs: the HASH160 result of the
// duplicated pubkey, and the fused EvalChecksig outcome (error, fSuccess) for
// witness-v0.  Everything else is the Lean step semantics.

#include <cstdint>

#define XINLINE static inline __attribute__((always_inline))

XINLINE uint64_t l_pack(uint32_t result, uint32_t error) {
    return (uint64_t)(result & 3u) | ((uint64_t)(error & 0x3fu) << 2);
}

// Out-of-domain arm (`unjudged` at the leaf seam).
XINLINE uint64_t l_sent(void) { return l_pack(2u, 1u); }

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
// Indexed as a total selector: indices 0..24 are the 25 script bytes, and
// anything outside is 0 (never reached by a successful parse of this script).
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
// `b.size ≤ i` termination condition.
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
    if (c == 0x4fu) {                           // OP_1NEGATE = pushNum 0
        o.kind = 1;
        o.num = 0;                              // stepBody encodes 0 as -1
        o.next = i + 1;
        return true;
    }
    if (c == 0x50u) {                           // OP_RESERVED: an op, not a push
        o.kind = 2;
        o.next = i + 1;
        return true;
    }
    if (c <= 0x60u) {                           // OP_1..OP_16
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
// Stack: Lean `Stack = List ByteArray` with head = top (Defs.lean:596).
// ---------------------------------------------------------------------------
struct L_Elem {
    uint64_t w0, w1, w2;   // 20-byte payload window
    uint64_t len;          // ByteArray size
};

struct L_Stack {
    L_Elem t0, t1, t2, t3, t4, t5;
    uint32_t n;
    uint32_t opcount;
};

XINLINE L_Elem l_top_at(const L_Stack& st, uint32_t k) {   // st[k-1]!
    if (k == 1) return st.t0;
    if (k == 2) return st.t1;
    if (k == 3) return st.t2;
    if (k == 4) return st.t3;
    if (k == 5) return st.t4;
    return st.t5;
}

XINLINE void l_push(L_Stack& st, L_Elem v) {   // v :: st.stack
    st.t5 = st.t4;
    st.t4 = st.t3;
    st.t3 = st.t2;
    st.t2 = st.t1;
    st.t1 = st.t0;
    st.t0 = v;
    st.n += 1;
}

XINLINE void l_drop1(L_Stack& st) {            // st.stack.tail
    st.t0 = st.t1;
    st.t1 = st.t2;
    st.t2 = st.t3;
    st.t3 = st.t4;
    st.t4 = st.t5;
    st.t5 = L_Elem{0, 0, 0, 0};
    st.n -= 1;
}

XINLINE void l_drop2(L_Stack& st) {            // st.stack.drop 2
    l_drop1(st);
    l_drop1(st);
}

XINLINE uint64_t l_byte_at(L_Elem e, uint32_t i) {
    if (i < 8) return (e.w0 >> (8u * i)) & 0xffu;
    if (i < 16) return (e.w1 >> (8u * (i - 8))) & 0xffu;
    return (e.w2 >> (8u * (i - 16))) & 0xffu;
}

// `a == b` for ByteArray (length, then bytes).  The 20 comparisons are the
// bounded unroll of Core's byte loop over the window; both operands of the
// implied script's EQUALVERIFY are 20-byte values.
XINLINE bool l_valtype_eq(L_Elem a, L_Elem b) {
    if (a.len != b.len) return false;
    if (a.len > 20) return false;              // outside the payload window
    if (a.len > 0 && l_byte_at(a, 0) != l_byte_at(b, 0)) return false;
    if (a.len > 1 && l_byte_at(a, 1) != l_byte_at(b, 1)) return false;
    if (a.len > 2 && l_byte_at(a, 2) != l_byte_at(b, 2)) return false;
    if (a.len > 3 && l_byte_at(a, 3) != l_byte_at(b, 3)) return false;
    if (a.len > 4 && l_byte_at(a, 4) != l_byte_at(b, 4)) return false;
    if (a.len > 5 && l_byte_at(a, 5) != l_byte_at(b, 5)) return false;
    if (a.len > 6 && l_byte_at(a, 6) != l_byte_at(b, 6)) return false;
    if (a.len > 7 && l_byte_at(a, 7) != l_byte_at(b, 7)) return false;
    if (a.len > 8 && l_byte_at(a, 8) != l_byte_at(b, 8)) return false;
    if (a.len > 9 && l_byte_at(a, 9) != l_byte_at(b, 9)) return false;
    if (a.len > 10 && l_byte_at(a, 10) != l_byte_at(b, 10)) return false;
    if (a.len > 11 && l_byte_at(a, 11) != l_byte_at(b, 11)) return false;
    if (a.len > 12 && l_byte_at(a, 12) != l_byte_at(b, 12)) return false;
    if (a.len > 13 && l_byte_at(a, 13) != l_byte_at(b, 13)) return false;
    if (a.len > 14 && l_byte_at(a, 14) != l_byte_at(b, 14)) return false;
    if (a.len > 15 && l_byte_at(a, 15) != l_byte_at(b, 15)) return false;
    if (a.len > 16 && l_byte_at(a, 16) != l_byte_at(b, 16)) return false;
    if (a.len > 17 && l_byte_at(a, 17) != l_byte_at(b, 17)) return false;
    if (a.len > 18 && l_byte_at(a, 18) != l_byte_at(b, 18)) return false;
    if (a.len > 19 && l_byte_at(a, 19) != l_byte_at(b, 19)) return false;
    return true;
}

// castToBool (Numeric/Interface.lean:64-65) with the byte list reversed:
// false for empty, all-zero, and the negative zero 0x80.
XINLINE bool l_cast_to_bool(L_Elem e) {
    if (e.len == 0) return false;
    if (e.len > 20) return false;              // outside the payload window
    const uint32_t last = (uint32_t)e.len - 1;
    const uint64_t d = l_byte_at(e, last);
    uint64_t rest = 0;
    if (last > 0) rest |= l_byte_at(e, 0);
    if (last > 1) rest |= l_byte_at(e, 1);
    if (last > 2) rest |= l_byte_at(e, 2);
    if (last > 3) rest |= l_byte_at(e, 3);
    if (last > 4) rest |= l_byte_at(e, 4);
    if (last > 5) rest |= l_byte_at(e, 5);
    if (last > 6) rest |= l_byte_at(e, 6);
    if (last > 7) rest |= l_byte_at(e, 7);
    if (last > 8) rest |= l_byte_at(e, 8);
    if (last > 9) rest |= l_byte_at(e, 9);
    if (last > 10) rest |= l_byte_at(e, 10);
    if (last > 11) rest |= l_byte_at(e, 11);
    if (last > 12) rest |= l_byte_at(e, 12);
    if (last > 13) rest |= l_byte_at(e, 13);
    if (last > 14) rest |= l_byte_at(e, 14);
    if (last > 15) rest |= l_byte_at(e, 15);
    if (last > 16) rest |= l_byte_at(e, 16);
    if (last > 17) rest |= l_byte_at(e, 17);
    if (last > 18) rest |= l_byte_at(e, 18);
    // castToBoolList: rest.any (· ≠ 0) || (d ≠ 0 ∧ d ≠ 128)
    return rest != 0 || (d != 0 && d != 128);
}

// disabledWire (Defs.lean:455-457).
XINLINE bool l_disabled(uint32_t w) {
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

struct L_Ctx {
    uint64_t h0, h1, h2;   // modelled HASH160(pubkey), 20 bytes
    uint64_t ck_err;       // modelled EvalChecksig error ordinal (0 = none)
    uint64_t ck_ok;        // modelled EvalChecksig fSuccess when ck_err == 0
};

static const uint64_t L_SENT = 0xffffffffull;

// stepBody plus the reachable part of stepChecked (Defs.lean:817-860,
// 1131-1142).  No conditional stack exists in the implied script, so fExec is
// constantly true and vf stays empty; the 1000-item terminal guard cannot fire
// at depth <= 4.
XINLINE uint64_t l_step(L_Stack& st, const L_Op& op, uint64_t p0, uint64_t p1,
                        uint64_t p2, const L_Ctx& c) {
    // (1) element size limit right after GetOp (pushBytes only).
    if (op.kind == 0 && op.dlen > 520u) return L_PUSH_SIZE;

    // (2) opcode budget: sv = witnessV0, counts iff 0x60 < wire.
    if (op.wire > 0x60u) {
        st.opcount += 1;
        if (st.opcount > 201u) return L_OP_COUNT;
    }

    // (3) disabled opcodes.
    if (l_disabled(op.wire)) return L_DISABLED_OPCODE;

    // (4a) pushBytes d -> d :: stack (unexecuted branches do not exist here).
    if (op.kind == 0) {
        if (op.dlen > 20u) return L_SENT;
        L_Elem v;
        v.w0 = l_read_word(p0, p1, p2, op.off, 0);
        v.w1 = l_read_word(p0, p1, p2, op.off, 8);
        v.w2 = l_read_word(p0, p1, p2, op.off, 16) & 0xffffffffull;
        v.len = op.dlen;
        l_push(st, v);
        return L_OK;
    }

    // (4b) pushNum n -> encodeScriptNum (if n = 0 then -1 else n) false
    if (op.kind == 1) {
        const uint64_t b = op.num == 0u ? 0x81u : (uint64_t)op.num;
        l_push(st, L_Elem{b, 0, 0, 1});
        return L_OK;
    }

    const uint32_t w = op.wire;

    if (w == 0x76u) {                          // OP_DUP (x -- x x)
        if (st.n < 1u) return L_STACK_UNDERFLOW;
        l_push(st, l_top_at(st, 1));
        return L_OK;
    }

    if (w == 0x87u || w == 0x88u) {            // OP_EQUAL / OP_EQUALVERIFY
        if (st.n < 2u) return L_STACK_UNDERFLOW;
        const bool fEqual = l_valtype_eq(l_top_at(st, 2), l_top_at(st, 1));
        if (w == 0x87u) {
            l_drop2(st);
            l_push(st, fEqual ? L_Elem{1, 0, 0, 1} : L_Elem{0, 0, 0, 0});
            return L_OK;
        }
        if (fEqual) {
            l_drop2(st);
            return L_OK;
        }
        return L_EQUALVERIFY;
    }

    if (w == 0xa9u) {                          // OP_HASH160 (in -- hash)
        if (st.n < 1u) return L_STACK_UNDERFLOW;
        L_Elem h;
        h.w0 = c.h0;
        h.w1 = c.h1;
        h.w2 = c.h2 & 0xffffffffull;
        h.len = 20;
        st.t0 = h;                              // hashForOp 0xa9 ..
        return L_OK;
    }

    if (w == 0xacu || w == 0xadu) {            // OP_CHECKSIG / ...VERIFY
        if (st.n < 2u) return L_STACK_UNDERFLOW;
        // EvalChecksig's fused outcome: an error replaces the opcode's own
        // result, otherwise fSuccess becomes vchTrue/vchFalse.
        if (c.ck_err != 0u) return (uint32_t)(c.ck_err & 0x3fu);
        const bool fSuccess = c.ck_ok != 0u;
        if (w == 0xadu) {
            if (fSuccess) {
                l_drop2(st);
                return L_OK;
            }
            return L_CHECKSIGVERIFY;
        }
        l_drop2(st);
        l_push(st, fSuccess ? L_Elem{1, 0, 0, 1} : L_Elem{0, 0, 0, 0});
        return L_OK;
    }

    return L_SENT;
}

XINLINE uint64_t l_run_step(L_Stack& st, uint64_t p0, uint64_t p1, uint64_t p2,
                            uint32_t size, uint32_t& i, const L_Ctx& c) {
    L_Op op{};
    if (!l_get_op(p0, p1, p2, size, i, op)) return L_BAD_OPCODE;
    i = op.next;
    return l_step(st, op, p0, p1, p2, c);
}

extern "C" uint64_t cell_p2wpkh_exec(
    uint64_t p0, uint64_t p1, uint64_t p2,
    uint64_t n_wit,
    uint64_t sig_len, uint64_t pk_len,
    uint64_t h0, uint64_t h1, uint64_t h2,
    uint64_t ck_err, uint64_t ck_ok) {

    // Defs.lean:1267-1270: v0, program.size = 20, witness.length ≠ 2.
    if (n_wit != 2u) return l_pack_err(L_WITNESS_PROGRAM_MISMATCH);

    // executeWitnessScript runExec: every item <= MAX_SCRIPT_ELEMENT_SIZE.
    if (sig_len > 520u || pk_len > 520u) return l_pack_err(L_PUSH_SIZE);

    L_Stack st{};
    st.n = 0;
    st.opcount = 0;

    // witness items in witness order (first pushed = bottom); the machine
    // stack is head = TOP, so the list is reversed (Defs.lean:1215-1217).
    l_push(st, L_Elem{0, 0, 0, sig_len});
    l_push(st, L_Elem{0, 0, 0, pk_len});

    // evalScriptBytes: script.size = 25 << MAX_SCRIPT_SIZE, parseWire yields
    // exactly five wire ops, evalFrom fuel 5 consumes them.
    // The checksig error seam is the ABI's 6-bit ScriptError field.
    L_Ctx c{h0, h1, h2, ck_err & 0x3fu, ck_ok};
    const uint32_t size = 25;
    uint32_t i = 0;
    uint64_t r;

    r = l_run_step(st, p0, p1, p2, size, i, c);
    if (r == L_SENT) return l_sent();
    if (r != L_OK) return l_pack_err((uint32_t)r);

    r = l_run_step(st, p0, p1, p2, size, i, c);
    if (r == L_SENT) return l_sent();
    if (r != L_OK) return l_pack_err((uint32_t)r);

    r = l_run_step(st, p0, p1, p2, size, i, c);
    if (r == L_SENT) return l_sent();
    if (r != L_OK) return l_pack_err((uint32_t)r);

    r = l_run_step(st, p0, p1, p2, size, i, c);
    if (r == L_SENT) return l_sent();
    if (r != L_OK) return l_pack_err((uint32_t)r);

    r = l_run_step(st, p0, p1, p2, size, i, c);
    if (r == L_SENT) return l_sent();
    if (r != L_OK) return l_pack_err((uint32_t)r);

    if (i != size) return l_sent();             // a sixth wire op: not this script

    // executeWitnessScript tail: implicit cleanstack + CastToBool.
    if (st.n != 1u) return l_pack_err(L_CLEANSTACK);
    if (!l_cast_to_bool(l_top_at(st, 1))) return l_pack_err(L_EVAL_FALSE);
    return l_pack(1u, L_OK);
}
