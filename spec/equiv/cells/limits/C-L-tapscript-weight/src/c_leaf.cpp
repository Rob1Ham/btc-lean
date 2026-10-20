#include "limits_common.h"

// C leg: line-cited source-excerpt slice of Bitcoin Core at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// SCR-040 budget:
//   interpreter.cpp:1991-1992  (tapscript arm of VerifyWitnessProgram)
//       execdata.m_validation_weight_left =
//           ::GetSerializeSize(witness.stack) + VALIDATION_WEIGHT_OFFSET;
//   script.h:62-65             VALIDATION_WEIGHT_OFFSET = 50
//   serialize.h:291-297        GetSizeOfCompactSize(n):
//         1 byte if n < 253; 3 if <= 0xffff; 5 if <= 0xffffffff; else 9
//   serialize.h:898-906        vector<byte> = CompactSize(size) || bytes
//   serialize.h:1156-1160      GetSerializeSize uses SizeComputer
//
//   witness.stack is vector<vector<unsigned char>>, so the size is
//   CompactSize(items) + sum_i (CompactSize(len_i) + len_i).
//
// The cell bounds the stack to at most 4 items (four length arguments) and
// item lengths to 32 bits.  CompactSize's 9-byte branch needs an item larger
// than 2^32-1, which a serialized witness cannot contain; the 1/3/5-byte
// branches are all covered.  This bound is why SCR-040 is reported partial.
//
// SCR-041/SCR-042 accounting:
//   interpreter.cpp:360-377  EvalChecksigTapscript
//       success = !sig.empty();
//       if (success) {
//           execdata.m_validation_weight_left -= VALIDATION_WEIGHT_PER_SIGOP_PASSED; // 50
//           if (execdata.m_validation_weight_left < 0)
//               return set_error(serror, SCRIPT_ERR_TAPSCRIPT_VALIDATION_WEIGHT);
//       }
//       if (pubkey.size() == 0) -> TAPSCRIPT_EMPTY_PUBKEY
//       else if (pubkey.size() == 32) { if (success && !checker) return false; }
//       else if (DISCOURAGE_UPGRADABLE_PUBKEYTYPE) -> that error
//   script.h:60      VALIDATION_WEIGHT_PER_SIGOP_PASSED = 50
//   BIP342: the weight test precedes the pubkey rules, and an upgradable
//   pubkey version does not skip the charge.
//
// The checker result is an explicit input (the same-crypto seam); its error
// ordinal is not modelled, so decision=2 marks a checker rejection.

constexpr int64_t VALIDATION_WEIGHT_PER_SIGOP_PASSED = 50;
constexpr int64_t VALIDATION_WEIGHT_OFFSET = 50;

LIMITS_INLINE uint64_t c_compact_size_size(uint64_t n) {
    if (n < 253) return 1;
    if (n <= 0xffff) return 3;
    if (n <= 0xffffffffULL) return 5;
    return 9;
}

LIMITS_INLINE int64_t c_tapscript_budget(uint32_t n_items, uint32_t len0, uint32_t len1,
                                         uint32_t len2, uint32_t len3) {
    int64_t total = (int64_t)c_compact_size_size(n_items);
    if (n_items > 0) total += (int64_t)c_compact_size_size(len0) + (int64_t)len0;
    if (n_items > 1) total += (int64_t)c_compact_size_size(len1) + (int64_t)len1;
    if (n_items > 2) total += (int64_t)c_compact_size_size(len2) + (int64_t)len2;
    if (n_items > 3) total += (int64_t)c_compact_size_size(len3) + (int64_t)len3;
    return total + VALIDATION_WEIGHT_OFFSET;                        // :1991-1992
}

// pk_class: 0 = pubkey.size()==0, 1 = ==32, 2 = any other (upgradable) size.
LIMITS_INLINE uint64_t c_tapscript_checksig(int64_t w_in, uint8_t sig_nonempty,
                                            uint8_t pk_class, uint8_t discourage, uint8_t checker_ok) {
    bool success = (sig_nonempty != 0);                             // :367
    int64_t w = w_in;
    if (success) {
        w -= VALIDATION_WEIGHT_PER_SIGOP_PASSED;                    // :372
        if (w < 0)                                                  // :373-376
            return lim_pack_acc(0, 49, 1, w);                       // TAPSCRIPT_VALIDATION_WEIGHT
    }
    if (pk_class == 0)
        return lim_pack_acc(0, 52, success ? 1u : 0u, w);           // TAPSCRIPT_EMPTY_PUBKEY
    if (pk_class == 1) {
        if (success && !checker_ok)
            return lim_pack_acc(2, 0, 1, w);                        // checker rejection
        return lim_pack_acc(1, 0, success ? 1u : 0u, w);
    }
    if (discourage)
        return lim_pack_acc(0, 37, success ? 1u : 0u, w);           // DISCOURAGE_UPGRADABLE_PUBKEYTYPE
    return lim_pack_acc(1, 0, success ? 1u : 0u, w);
}

extern "C" int64_t cell_tapscript_budget(uint32_t n_items, uint32_t len0, uint32_t len1,
                                         uint32_t len2, uint32_t len3) {
    return c_tapscript_budget(n_items, len0, len1, len2, len3);
}

extern "C" uint64_t cell_tapscript_checksig(int64_t w_in, uint8_t sig_nonempty,
                                            uint8_t pk_class, uint8_t discourage, uint8_t checker_ok) {
    return c_tapscript_checksig(w_in, sig_nonempty, pk_class, discourage, checker_ok);
}
