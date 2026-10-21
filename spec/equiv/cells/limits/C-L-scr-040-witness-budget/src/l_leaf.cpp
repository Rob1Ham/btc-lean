#include "limits_common.h"

// L leg: reviewed transliteration of the btc-lean model's BIP342 budget.
//
//   spec/core/Bitcoin/Crypto/Taproot/Program.lean:599-606
//       witnessPayloadSize items =
//         items.foldl (fun acc d =>
//           acc + Int.ofNat ((compactSizeEnc d.size).size + d.size)) 0
//       witnessSerSize items =
//         Int.ofNat (compactSizeEnc items.length).size + witnessPayloadSize items
//   spec/core/Bitcoin/Crypto/Taproot/Program.lean:633-642
//       VALIDATION_WEIGHT_OFFSET = 50
//       validationWeightInit witness = witnessSerSize witness + VALIDATION_WEIGHT_OFFSET
//   spec/core/Bitcoin/Interpreter/Defs.lean:92-93,1197,1229
//       the live interpreter aliases the same definition; :1229 sets
//       validationWeightLeft := vwSer + VALIDATION_WEIGHT_OFFSET
//   spec/core/Bitcoin/Data/Basic.lean:73-77  compactSizeEnc thresholds
//       n < 0xfd -> 1 ; n <= 0xffff -> 3 ; n <= 0xffffffff -> 5 ; else 9
//
// The Lean fold is over `List ByteArray`; the cell's loop is its
// Core-shaped, unrolled (<= 8 element) transliteration, matching the C leg
// element for element.  The arbitrary-list composition is not proved by this
// IR loop; it is the reviewed fold bridge described in spec.md (and is
// independently kernel-checked on the model side in src/lean/).
//
// Every term is the same arithmetic as Core's SizeComputer: prefix size +
// payload length.  Item byte values never enter the size.

constexpr int64_t L_VALIDATION_WEIGHT_OFFSET = 50;
constexpr uint32_t L_MAX_ITEMS = 8;

LIMITS_INLINE uint64_t l_compact_size_size64(uint64_t n) {
    if (n < 0xfd) return 1;
    if (n <= 0xffff) return 3;
    if (n <= 0xffffffffULL) return 5;
    return 9;
}

LIMITS_INLINE int64_t l_write(int64_t acc, uint64_t nbytes) {
    return acc + (int64_t)nbytes;
}

LIMITS_INLINE int64_t l_budget_count(uint32_t n_items) {
    return l_write(0, l_compact_size_size64((uint64_t)n_items)) +
           L_VALIDATION_WEIGHT_OFFSET;
}

LIMITS_INLINE int64_t l_item_step(uint32_t len, int64_t acc) {
    return l_write(l_write(acc, l_compact_size_size64((uint64_t)len)),
                   (uint64_t)len);
}

LIMITS_INLINE int64_t l_witness_serialized_size(uint32_t n_items, const uint32_t* lens) {
    int64_t acc = l_write(0, l_compact_size_size64((uint64_t)n_items));
#pragma clang loop unroll(full)
    for (uint32_t i = 0; i < L_MAX_ITEMS; i++) {
        if (i < n_items) {
            acc = l_write(acc, l_compact_size_size64((uint64_t)lens[i]));
            acc = l_write(acc, (uint64_t)lens[i]);
        }
    }
    return acc;
}

LIMITS_INLINE int64_t l_witness_budget(uint32_t n_items, const uint32_t* lens) {
    return l_witness_serialized_size(n_items, lens) + L_VALIDATION_WEIGHT_OFFSET;
}

extern "C" uint64_t cell_compact_size_size(uint64_t n) {
    return l_compact_size_size64(n);
}

extern "C" int64_t cell_witness_budget_count(uint32_t n_items) {
    return l_budget_count(n_items);
}

extern "C" int64_t cell_witness_item_step(uint32_t len, int64_t acc) {
    return l_item_step(len, acc);
}

extern "C" int64_t cell_witness_serialized_size(uint32_t n_items,
                                                const uint32_t* lens) {
    return l_witness_serialized_size(n_items, lens);
}

extern "C" int64_t cell_witness_budget(uint32_t n_items, const uint32_t* lens) {
    return l_witness_budget(n_items, lens);
}
