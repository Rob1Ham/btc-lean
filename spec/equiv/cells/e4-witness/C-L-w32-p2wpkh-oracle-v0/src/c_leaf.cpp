// C leg for cell e4-witness/C-L-w32-p2wpkh-oracle-v0 (SCR-136, full row).
//
// Line-cited source-excerpt slice of Bitcoin Core at the pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66:
//
//   src/script/interpreter.cpp:1947-1953
//       P2WPKH (20-byte v0 program) arm: stack.size() != 2 ->
//       WITNESS_PROGRAM_MISMATCH; exec_script << OP_DUP << OP_HASH160
//                   << program << OP_EQUALVERIFY << OP_CHECKSIG;
//       ExecuteWitnessScript(...)
//   src/script/interpreter.cpp:1842-1879
//       ExecuteWitnessScript: per-item size cap (PUSH_SIZE), EvalScript, the
//       implicit witness cleanstack (CLEANSTACK), CastToBool (EVAL_FALSE)
//   src/script/interpreter.cpp:446-490
//       EvalScript prologue + the per-op checks the loop performs: SCRIPT_SIZE,
//       GetOp failure -> BAD_OPCODE, pushed value <= MAX_SCRIPT_ELEMENT_SIZE,
//       opcode budget (opcode > OP_16), disabled opcodes.  The terminal
//       1000-item STACK_SIZE guard cannot fire at depth <= 4.
//   src/script/interpreter.cpp:803-812        case OP_DUP
//   src/script/interpreter.cpp:896-925        case OP_EQUAL / OP_EQUALVERIFY
//   src/script/interpreter.cpp:1032-1059      case OP_HASH160
//                                             (:1048-1056 CHash160(vch) over
//                                             the whole top element; :1042 the
//                                             20-byte vchHash; :1053-1054
//                                             popstack/push_back)
//   src/script/interpreter.cpp:1069-1088      case OP_CHECKSIG; :1075-1076
//                                             vchSig = stacktop(-2),
//                                             vchPubKey = stacktop(-1);
//                                             EvalChecksig(..., pbegincodehash,
//                                             pend, ...)
//   src/script/interpreter.cpp:331-355        EvalChecksigPreTapscript: scriptCode
//                                             = CScript(pbegincodehash, pend);
//                                             WITNESS_V0 skips FindAndDelete
//   src/script/interpreter.cpp:46-59          CastToBool
//   src/script/script.cpp:313-363             GetScriptOp
//   src/script/script.h:29,32                 MAX_SCRIPT_ELEMENT_SIZE, MAX_OPS_PER_SCRIPT
//   src/script/script.h:408-431,470-488       implied-script byte emission (as in
//                                             cell C-L-w32-p2wpkh-build)
//
// Two things are proved by this cell.
//
// (A) cell_p2wpkh_scr136: the total execution outcome, exactly as the existing
//     cell e4-witness/C-L-w32-p2wpkh-exec does, but with the crypto pieces
//     named as oracle *seams*:
//       * HASH160(pubkey)  -> h0,h1,h2 (20 bytes, free: same-hash premise);
//       * EvalChecksig     -> (ck_err, ck_ok) (free: same-crypto premise).
//     The statement is parametric in both: it holds for every possible hash
//     and every possible checker verdict.  See spec.md for the outcome table.
//
// (B) cell_p2wpkh_seam: the *interface* of those two oracles.  It executes the
//     same five-op machine but instead of the outcome returns a selected word
//     of the argument the oracle receives:
//       sel 0,k : word k of the HASH160 preimage  = the pk witness item;
//       sel 4   : HASH160 preimage length          = pk_len;
//       sel 5   : HASH160 output width             = 20 (interpreter.cpp:1042);
//       sel 1,k : word k of the EvalChecksig signature   = the sig item;
//       sel 2,k : word k of the EvalChecksig pubkey      = the pk item;
//       sel 3,k : word k of the EvalChecksig scriptCode  = the 25 implied bytes
//                 (pbegincodehash=begin, no OP_CODESEPARATOR, WITNESS_V0);
//       sel 6   : signature length seen by EvalChecksig;
//       sel 7   : pubkey length seen by EvalChecksig;
//       sel 8   : scriptCode length seen by EvalChecksig = 25.
//     sel and k are ordinary inputs, so one symbolic proof covers every choice.
//     A sentinel (all ones) means "the selected seam was not reached", which
//     is itself a defined, compared value (arity error, item-size error, a
//     non-matching program before OP_CHECKSIG, or a mutated byte stream).
//
// Bounded representation (declared in spec.md): stack elements carry their
// true byte source (program / hash / signature / pubkey / implied script) plus
// their true length.  The pubkey item window is 72 bytes (9 words) and the
// signature item window 80 bytes (10 words); both cover every DER signature
// (<= 73 bytes) and every compressed (33) or uncompressed (65) pubkey.  Bytes
// past the window take the out-of-domain arm for (B) only; (A) is independent
// of item contents and total over all lengths <= 520.
//
// This cell is bounded and loop-free on purpose: the implied script has exactly
// five instructions, so the EvalScript loop and the GetScriptOp walk are
// unrolled five times.  The 25-byte script is a pure byte selector; there is no
// buffer, heap, call or alloca.

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

// Seam transcript sentinel: the selected oracle seam was not reached.
static const uint64_t C_SEAM_SENT = 0xffffffffffffffffull;

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
//   OP_DUP(0x76) OP_HASH160(0xa9) push20(0x14) program[0..19]
//   OP_EQUALVERIFY(0x88) OP_CHECKSIG(0xac)
// with the emissions of script.h:408-431 (data-size prefix) and
// script.h:470-488 (one byte per opcode, AppendData copies the span).
// Bytes outside 0..24 exist only to keep the selector total; they are never
// parsed by the canonical script.
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

// Word k (bytes 8k..8k+7) of the implied script, little-endian.  Only bytes
// 0..24 exist, so word 3 has one valid byte.
XINLINE uint64_t c_script_word(uint32_t k, uint64_t p0, uint64_t p1,
                               uint64_t p2) {
    if (k > 3u) return 0ull;
    const uint32_t b = 8u * k;   // 0, 8, 16 or 24
    // Unrolled byte gather: bytes at or past 25 do not exist.
    const uint32_t i0 = b, i1 = b + 1u, i2 = b + 2u, i3 = b + 3u;
    const uint32_t i4 = b + 4u, i5 = b + 5u, i6 = b + 6u, i7 = b + 7u;
    uint64_t w = 0;
    if (i0 < 25u) w |= c_script_byte(p0, p1, p2, i0);
    if (i1 < 25u) w |= c_script_byte(p0, p1, p2, i1) << 8;
    if (i2 < 25u) w |= c_script_byte(p0, p1, p2, i2) << 16;
    if (i3 < 25u) w |= c_script_byte(p0, p1, p2, i3) << 24;
    if (i4 < 25u) w |= c_script_byte(p0, p1, p2, i4) << 32;
    if (i5 < 25u) w |= c_script_byte(p0, p1, p2, i5) << 40;
    if (i6 < 25u) w |= c_script_byte(p0, p1, p2, i6) << 48;
    if (i7 < 25u) w |= c_script_byte(p0, p1, p2, i7) << 56;
    return w;
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
// Bounded valtype: 20-byte payload window + true length + the byte source.
//
// `src` records which witness/derived byte string the element denotes; the
// oracle-interface export reads its bytes through this tag, so a leg that
// hashes the wrong element cannot pass.  The 20-byte window is exact for the
// only comparison this script performs (20-byte program vs 20-byte hash).
// ---------------------------------------------------------------------------
enum : uint32_t {
    SRC_NONE = 0,      // boolean results and out-of-window values
    SRC_PROGRAM = 1,   // the 20-byte witness program
    SRC_HASH = 2,      // the 20-byte HASH160 oracle output
    SRC_SIG = 3,       // witness item 0 (signature)
    SRC_PK = 4,        // witness item 1 (pubkey)
    SRC_SCRIPT = 5,    // the implied exec script
};

struct C_Elem {
    uint64_t w0, w1, w2;   // payload bytes 0..7, 8..15, 16..19 (low 32 bits)
    uint64_t len;          // valtype size (bytes)
    uint32_t src;          // byte source tag above
};

// Head slot = top of stack, mirroring CScriptWitness::stack back() ==
// stacktop(-1) through an explicit re-indexing.  Six slots cover the implied
// script's peak depth 4; the spare slots make the shift helpers unconditional.
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
    s.t5 = C_Elem{0, 0, 0, 0, SRC_NONE};
    s.n -= 1;
}

XINLINE uint64_t c_low_mask(uint64_t k) {     // k <= 8
    // Constant-byte form: no variable shift is formed at all, so the k == 8
    // arm cannot become a 64-bit shift (LLVM poison) even when speculated.
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

// `bool fEqual = (vch1 == vch2)` (interpreter.cpp:906): std::vector equality is
// length first, then the bytes.  The 20-byte window is exact for every value
// compared by the implied script (program and hash are both 20 bytes).
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

// ---------------------------------------------------------------------------
// Symbolic item bytes and the oracle seams.
// ---------------------------------------------------------------------------
struct C_Items {
    uint64_t s0, s1, s2, s3, s4, s5, s6, s7, s8, s9;   // signature, 80 bytes
    uint64_t k0, k1, k2, k3, k4, k5, k6, k7, k8;       // pubkey,    72 bytes
    uint64_t p0, p1, p2;                               // program,   20 bytes
};

// Symbolic selectors over word index k (k is an input, so these branches are
// part of the compared function, not metaprogramming).
XINLINE uint64_t c_sel3(uint32_t k, uint64_t a0, uint64_t a1, uint64_t a2) {
    if (k == 0u) return a0;
    if (k == 1u) return a1;
    if (k == 2u) return a2;
    return 0ull;
}

XINLINE uint64_t c_sel9(uint32_t k, uint64_t a0, uint64_t a1, uint64_t a2,
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

XINLINE uint64_t c_sel10(uint32_t k, uint64_t a0, uint64_t a1, uint64_t a2,
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

// Mask selecting the bytes of word k that belong to an item of length len.
// Bytes at or past len are not part of the preimage and read as 0.
XINLINE uint64_t c_word_mask(uint64_t len, uint32_t k) {
    const uint64_t off = (uint64_t)k * 8ull;
    if (len <= off) return 0ull;
    uint64_t n = len - off;
    if (n > 8ull) n = 8ull;
    return c_low_mask(n);
}

// Word k of an element's true byte string, masked to its length.
XINLINE uint64_t c_item_word(uint32_t src, uint32_t k, uint64_t len,
                             const C_Items& it) {
    uint64_t w = 0;
    if (src == SRC_PROGRAM) {
        w = c_sel3(k, it.p0, it.p1, it.p2);
    } else if (src == SRC_HASH) {
        w = 0;   // the hash output is an oracle value, never a preimage here
    } else if (src == SRC_SIG) {
        w = c_sel10(k, it.s0, it.s1, it.s2, it.s3, it.s4, it.s5, it.s6, it.s7,
                    it.s8, it.s9);
    } else if (src == SRC_PK) {
        w = c_sel9(k, it.k0, it.k1, it.k2, it.k3, it.k4, it.k5, it.k6, it.k7,
                   it.k8);
    } else if (src == SRC_SCRIPT) {
        w = c_script_word(k, it.p0, it.p1, it.p2);
    }
    return w & c_word_mask(len, k);
}

// Seam selectors (see the header comment).  SEL_NONE is the outcome export.
enum : uint32_t {
    SEL_HASH_PRE = 0,
    SEL_SIG_WORD = 1,
    SEL_PK_WORD = 2,
    SEL_SC_WORD = 3,
    SEL_HASH_LEN = 4,
    SEL_HASH_OUT = 5,
    SEL_SIG_LEN = 6,
    SEL_PK_LEN = 7,
    SEL_SC_LEN = 8,
    SEL_NONE = 0xffffffffu,
};

// Symbolic inputs that are not stack items.
struct C_Ctx {
    uint64_t h0, h1, h2;   // modelled HASH160(pubkey), 20 bytes
    uint64_t ck_err;       // modelled EvalChecksig error ordinal (0 = none)
    uint64_t ck_ok;        // modelled EvalChecksig fSuccess when ck_err == 0
    uint32_t sel;          // seam selector, or SEL_NONE
    uint32_t k;            // transcript word index
};

struct C_StepRes {
    uint32_t kind;         // 0 = ok, 1 = ScriptError, 2 = seam value
    uint32_t err;
    uint64_t val;
};

XINLINE C_StepRes c_ok(void) { return C_StepRes{0u, 0u, 0ull}; }
XINLINE C_StepRes c_err(uint32_t e) { return C_StepRes{1u, e, 0ull}; }
XINLINE C_StepRes c_seam(uint64_t v) { return C_StepRes{2u, 0u, v}; }

XINLINE bool c_hash_sel(uint32_t sel) {
    return sel == SEL_HASH_PRE || sel == SEL_HASH_LEN || sel == SEL_HASH_OUT;
}

XINLINE bool c_ck_sel(uint32_t sel) {
    return (sel >= SEL_SIG_WORD && sel <= SEL_SC_WORD) ||
           (sel >= SEL_SIG_LEN && sel <= SEL_SC_LEN);
}

// One EvalScript iteration: checks from interpreter.cpp:457-482 then the
// opcode switch for the instructions that can appear in the implied script.
XINLINE C_StepRes c_step(C_Stack& s, const C_Dec& d, const C_Items& it,
                         const C_Ctx& c) {
    const uint32_t w = d.op;

    // interpreter.cpp:457-459: pushed value size (executed or not).
    if (d.dlen > 520u) return c_err(C_PUSH_SIZE);

    // interpreter.cpp:462-465: opcode budget; OP_16 does not count.
    if (w > 0x60u) {
        s.opcount += 1;
        if (s.opcount > 201u) return c_err(C_OP_COUNT);
    }

    // interpreter.cpp:467-482: disabled opcodes, unexecuted branches included.
    if (c_is_disabled(w)) return c_err(C_DISABLED_OPCODE);

    if (w <= 0x4eu) {                          // push of dlen payload bytes
        if (d.dlen > 20u) return c_seam(C_SEAM_SENT);  // outside payload window
        C_Elem v;
        v.w0 = c_read_word(it.p0, it.p1, it.p2, d.off, 0);
        v.w1 = c_read_word(it.p0, it.p1, it.p2, d.off, 8);
        v.w2 = c_read_word(it.p0, it.p1, it.p2, d.off, 16) & 0xffffffffull;
        v.len = d.dlen;
        v.src = SRC_PROGRAM;
        c_push(s, v);
        return c_ok();
    }
    if (w == 0x4fu) {                          // OP_1NEGATE -> {-1}
        c_push(s, C_Elem{0x81u, 0, 0, 1, SRC_NONE});
        return c_ok();
    }
    if (w >= 0x51u && w <= 0x60u) {            // OP_1..OP_16 -> {n}
        c_push(s, C_Elem{(uint64_t)(w - 0x50u), 0, 0, 1, SRC_NONE});
        return c_ok();
    }

    if (w == 0x76u) {                          // OP_DUP: (x -- x x)
        if (s.n < 1) return c_err(C_INVALID_STACK_OPERATION);
        c_push(s, c_top_at(s, 1));
        return c_ok();
    }

    if (w == 0xa9u) {                          // OP_HASH160: (in -- hash)
        if (s.n < 1) return c_err(C_INVALID_STACK_OPERATION);
        const C_Elem in = c_top_at(s, 1);
        if (c_hash_sel(c.sel)) {
            // The oracle envelope is only claimed when the top element really
            // is the duplicated pubkey item (canonical script).
            if (in.src != SRC_PK) return c_seam(C_SEAM_SENT);
            if (c.sel == SEL_HASH_PRE) {
                return c_seam(c_item_word(SRC_PK, c.k, in.len, it));
            }
            if (c.sel == SEL_HASH_LEN) return c_seam(in.len);
            return c_seam(20ull);              // interpreter.cpp:1042
        }
        // interpreter.cpp:1048-1056 computes CHash160(vch) over the *whole*
        // top element; the 20-byte result is the declared hash seam.
        C_Elem h;
        h.w0 = c.h0;
        h.w1 = c.h1;
        h.w2 = c.h2 & 0xffffffffull;
        h.len = 20;
        h.src = SRC_HASH;
        s.t0 = h;
        return c_ok();
    }

    if (w == 0x87u || w == 0x88u) {            // OP_EQUAL / OP_EQUALVERIFY
        if (s.n < 2) return c_err(C_INVALID_STACK_OPERATION);
        const bool fEqual = c_valtype_eq(c_top_at(s, 2), c_top_at(s, 1));
        c_pop(s);
        c_pop(s);
        if (w == 0x87u) {
            c_push(s, fEqual ? C_Elem{1, 0, 0, 1, SRC_NONE}
                             : C_Elem{0, 0, 0, 0, SRC_NONE});
            return c_ok();
        }
        if (fEqual) return c_ok();
        return c_err(C_EQUALVERIFY);
    }

    if (w == 0xacu || w == 0xadu) {            // OP_CHECKSIG / ...VERIFY
        if (s.n < 2) return c_err(C_INVALID_STACK_OPERATION);
        const C_Elem sig = c_top_at(s, 2);     // stacktop(-2)
        const C_Elem pk = c_top_at(s, 1);      // stacktop(-1)
        if (c_ck_sel(c.sel)) {
            if (sig.src != SRC_SIG || pk.src != SRC_PK) {
                return c_seam(C_SEAM_SENT);
            }
            if (c.sel == SEL_SIG_WORD) {
                return c_seam(c_item_word(SRC_SIG, c.k, sig.len, it));
            }
            if (c.sel == SEL_PK_WORD) {
                return c_seam(c_item_word(SRC_PK, c.k, pk.len, it));
            }
            if (c.sel == SEL_SC_WORD) {
                // scriptCode = CScript(pbegincodehash, pend); no
                // OP_CODESEPARATOR in the implied script, so it is the 25
                // constructed bytes (interpreter.cpp:333-335).
                return c_seam(c_script_word(c.k, it.p0, it.p1, it.p2) &
                              c_word_mask(25ull, c.k));
            }
            if (c.sel == SEL_SIG_LEN) return c_seam(sig.len);
            if (c.sel == SEL_PK_LEN) return c_seam(pk.len);
            return c_seam(25ull);
        }
        // interpreter.cpp:1070-1084: EvalChecksig decides; its error is
        // returned as-is, otherwise fSuccess becomes vchTrue/vchFalse.
        if (c.ck_err != 0) return c_err((uint32_t)(c.ck_err & 0x3fu));
        const bool fSuccess = c.ck_ok != 0;
        c_pop(s);
        c_pop(s);
        c_push(s, fSuccess ? C_Elem{1, 0, 0, 1, SRC_NONE}
                           : C_Elem{0, 0, 0, 0, SRC_NONE});
        if (w == 0xadu) {
            if (!fSuccess) return c_err(C_CHECKSIGVERIFY);
            c_pop(s);
        }
        return c_ok();
    }

    return c_seam(C_SEAM_SENT);                // instruction outside the slice
}

struct C_Run {
    uint32_t kind;         // 0 = success, 1 = ScriptError, 2 = seam value
    uint64_t val;
};

#define C_STEP_ONCE()                                                    \
    do {                                                                 \
        if (!c_get_op(it.p0, it.p1, it.p2, end, pc, d))                  \
            return C_Run{1u, C_BAD_OPCODE};                              \
        const C_StepRes r_ = c_step(s, d, it, c);                        \
        if (r_.kind == 1u) return C_Run{1u, r_.err};                     \
        if (r_.kind == 2u) return C_Run{2u, r_.val};                     \
    } while (0)

// The v0 P2WPKH arm + the five unrolled EvalScript iterations +
// ExecuteWitnessScript's cleanstack/CastToBool tail.
XINLINE C_Run c_run(const C_Items& it, const C_Ctx& c, uint64_t n_wit,
                    uint64_t sig_len, uint64_t pk_len) {
    // interpreter.cpp:1948-1950: BIP141 P2WPKH requires exactly two items.
    if (n_wit != 2u) return C_Run{1u, C_WITNESS_PROGRAM_MISMATCH};

    // interpreter.cpp:1869-1871: witness stack items <= MAX_SCRIPT_ELEMENT_SIZE.
    if (sig_len > 520ull || pk_len > 520ull) return C_Run{1u, C_PUSH_SIZE};

    C_Stack s{};
    s.n = 0;
    s.opcount = 0;

    // Witness stack, first item bottom: [sig, pk]; head slot is the top (pk).
    // The byte sources tag the true witness item each element denotes.
    c_push(s, C_Elem{0, 0, 0, sig_len, SRC_SIG});
    c_push(s, C_Elem{0, 0, 0, pk_len, SRC_PK});

    const uint32_t end = 25;
    uint32_t pc = 0;
    C_Dec d{};

    // EvalScript's loop, unrolled over the implied script's five instructions
    // (script size 25 << MAX_SCRIPT_SIZE, so the size pre-check never fires).
    C_STEP_ONCE();   // OP_DUP
    C_STEP_ONCE();   // OP_HASH160
    C_STEP_ONCE();   // push <program>
    C_STEP_ONCE();   // OP_EQUALVERIFY
    C_STEP_ONCE();   // OP_CHECKSIG

    // A sixth instruction would be outside the implied 25-byte script.
    if (pc != end) return C_Run{2u, C_SEAM_SENT};

    // interpreter.cpp:1876-1879: implicit witness cleanstack + CastToBool.
    if (s.n != 1u) return C_Run{1u, C_CLEANSTACK};
    if (!c_cast_to_bool(c_top_at(s, 1))) return C_Run{1u, C_EVAL_FALSE};
    return C_Run{0u, 0ull};
}

// (A) Total execution outcome, parametric in the two oracle seams.
extern "C" uint64_t cell_p2wpkh_scr136(
    uint64_t p0, uint64_t p1, uint64_t p2,     // 20-byte witness program
    uint64_t n_wit,                            // witness stack size
    uint64_t sig_len, uint64_t pk_len,         // witness item sizes (bytes)
    uint64_t h0, uint64_t h1, uint64_t h2,     // HASH160(pk) seam (20 bytes)
    uint64_t ck_err, uint64_t ck_ok) {         // EvalChecksig seam
    C_Items it{};
    it.p0 = p0;
    it.p1 = p1;
    it.p2 = p2;
    // The checksig error seam is the ABI's 6-bit ScriptError field; bits 6..63
    // are not part of it (contract/error_enum.md: EQUIV_ERR_COUNT = 55).
    const C_Ctx c{h0, h1, h2, ck_err & 0x3full, ck_ok, SEL_NONE, 0u};
    const C_Run r = c_run(it, c, n_wit, sig_len, pk_len);
    if (r.kind == 1u) return c_pack_err((uint32_t)r.val);
    if (r.kind == 2u) return x_sent();
    return x_pack(1u, C_OK);
}

// (B) Oracle-interface transcript.  sel/k are ordinary inputs, so the symbolic
// proofs below cover every selector and every word index at once.
extern "C" uint64_t cell_p2wpkh_seam(
    uint64_t sel, uint64_t k,
    uint64_t p0, uint64_t p1, uint64_t p2,     // 20-byte witness program
    uint64_t n_wit,                            // witness stack size
    uint64_t sig_len, uint64_t pk_len,         // witness item sizes (bytes)
    uint64_t h0, uint64_t h1, uint64_t h2,     // HASH160(pk) seam (20 bytes)
    uint64_t ck_err, uint64_t ck_ok,           // EvalChecksig seam
    uint64_t s0, uint64_t s1, uint64_t s2, uint64_t s3, uint64_t s4,
    uint64_t s5, uint64_t s6, uint64_t s7, uint64_t s8, uint64_t s9,
    uint64_t k0, uint64_t k1, uint64_t k2, uint64_t k3, uint64_t k4,
    uint64_t k5, uint64_t k6, uint64_t k7, uint64_t k8) {
    const C_Items it{s0, s1, s2, s3, s4, s5, s6, s7, s8, s9,
                     k0, k1, k2, k3, k4, k5, k6, k7, k8, p0, p1, p2};
    const C_Ctx c{h0, h1, h2, ck_err & 0x3full, ck_ok,
                  (uint32_t)sel, (uint32_t)k};
    const C_Run r = c_run(it, c, n_wit, sig_len, pk_len);
    if (r.kind == 2u) return r.val;
    return C_SEAM_SENT;
}
