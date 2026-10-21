#include <cstdint>

// Divergence probe, L leg: reviewed transliteration of the Lean model
//   spec/core/Bitcoin/Interpreter/Defs.lean:1207-1245 (executeWitnessScript)
//
//   if sv = .tapscript then
//     if opSuccessScan exec then
//       if pol.discourageOpSuccess then .fail .discourageOpSuccess else .ok
//     else if MAX_STACK_SIZE < items.length then .fail .stackSize
//     else runExec items
//
//   runExec items =
//     if items.any (fun d => 520 < d.size) then .fail .pushSize
//     else match evalScriptBytes ... with ... | .error e => .fail e | ...
//
// evalScriptBytes calls parseWire (Defs.lean:1163-1176) and returns badOpcode
// when the script does not parse.  So a truncated push is reported *after* the
// stack-size and item-size checks on the Lean side, while Core's pre-scan
// reports it before them (probe_c.cpp: interpreter.cpp:1855-1861).
//
// Same packing as the C probe: BAD_OPCODE=64, STACK_SIZE=32, PUSH_SIZE=24,
// DISCOURAGE_OP_SUCCESS=144, success=1.  The script-level EvalScript result is
// abstracted to success when the script parses, exactly as in probe_c.cpp.
//
// The scan returns 0 = end, 1 = found, 2 = decode failure (getOp none), which
// is the information opSuccessScan plus parseWire together carry.

static inline __attribute__((always_inline)) uint8_t pb(uint32_t w, uint32_t i) {
    return (uint8_t)((w >> (8u * i)) & 0xffu);
}

static inline __attribute__((always_inline)) bool succeeds(uint32_t w) {
    return w == 80 || w == 98 || (126 <= w && w <= 129) ||
           (131 <= w && w <= 134) || (137 <= w && w <= 138) ||
           (141 <= w && w <= 142) || (149 <= w && w <= 153) ||
           (187 <= w && w <= 254);
}

// Lean getOp: push-vs-op distinction, Nat (64-bit) bound checks.
static inline __attribute__((always_inline)) bool getop(uint32_t w, uint32_t len, uint32_t i, bool* is_op,
                         uint32_t* next) {
    const uint32_t c = (uint32_t)pb(w, i);
    if (c == 0) {
        *is_op = false;
        *next = i + 1;
        return true;
    }
    if (c <= 0x4b) {
        if ((uint64_t)i + 1u + (uint64_t)c > (uint64_t)len) return false;
        *is_op = false;
        *next = i + 1 + c;
        return true;
    }
    if (c == 0x4c) {
        if ((uint64_t)i + 2u > (uint64_t)len) return false;
        const uint32_t k = (uint32_t)pb(w, i + 1);
        if ((uint64_t)i + 2u + (uint64_t)k > (uint64_t)len) return false;
        *is_op = false;
        *next = i + 2 + k;
        return true;
    }
    if (c == 0x4d) {
        if ((uint64_t)i + 3u > (uint64_t)len) return false;
        const uint32_t k = (uint32_t)pb(w, i + 1) | ((uint32_t)pb(w, i + 2) << 8);
        if ((uint64_t)i + 3u + (uint64_t)k > (uint64_t)len) return false;
        *is_op = false;
        *next = i + 3 + k;
        return true;
    }
    if (c == 0x4e) {
        if ((uint64_t)i + 5u > (uint64_t)len) return false;
        const uint32_t k = (uint32_t)pb(w, i + 1) | ((uint32_t)pb(w, i + 2) << 8) |
                           ((uint32_t)pb(w, i + 3) << 16) | ((uint32_t)pb(w, i + 4) << 24);
        if ((uint64_t)i + 5u + (uint64_t)k > (uint64_t)len) return false;
        *is_op = false;
        *next = i + 5 + k;
        return true;
    }
    if (c == 0x4f || c <= 0x60) {  // pushNum; 0x50 is .op and handled below
        *is_op = (c == 0x50);
        *next = i + 1;
        return true;
    }
    *is_op = true;
    *next = i + 1;
    return true;
}

#define LSTEP()                                                            \
    if (i >= len) return 0u;                                               \
    {                                                                      \
        const uint32_t c = (uint32_t)pb(w, i);                             \
        bool is_op = false;                                                \
        uint32_t nx = 0;                                                   \
        if (!getop(w, len, i, &is_op, &nx)) return 2u;                     \
        if (is_op && succeeds(c)) return 1u;                               \
        i = nx;                                                            \
    }

static inline __attribute__((always_inline)) uint32_t scan(uint32_t len, uint32_t w) {
    uint32_t i = 0;
    LSTEP();
    LSTEP();
    LSTEP();
    LSTEP();
    return 0u;
}

extern "C" uint64_t probe_prescan_order(uint32_t len, uint8_t b0, uint8_t b1,
                                        uint8_t b2, uint8_t b3, uint32_t too_many,
                                        uint32_t oversize, uint32_t discourage) {
    // Cell-domain guard (4-byte probe): keeps the byte shifts in range and
    // gives len > 4 the bad-input marker 6 on both legs.
    if (len > 4) return 6;
    const uint32_t w = (uint32_t)b0 | ((uint32_t)b1 << 8) | ((uint32_t)b2 << 16) |
                       ((uint32_t)b3 << 24);
    const uint32_t s = scan(len, w);
    if (s == 1u) return discourage != 0 ? 144 : 1;
    // Defs.lean:1215-1216: stack size, then item size (1218-1220).
    if (too_many) return 32;
    if (oversize) return 24;
    // runExec -> evalScriptBytes -> parseWire none -> badOpcode (after sizes).
    if (s == 2u) return 64;
    return 1;
}
