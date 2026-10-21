#include "limits_common.h"

// L leg: the btc-lean model's own shape (a fold, not an accumulator loop).
//
//   spec/core/Bitcoin/Crypto/Taproot/Program.lean:599-606
//       witnessPayloadSize items =
//         items.foldl (fun acc d =>
//           acc + Int.ofNat ((compactSizeEnc d.size).size + d.size)) 0
//       witnessSerSize items =
//         Int.ofNat (compactSizeEnc items.length).size + witnessPayloadSize items
//   spec/core/Bitcoin/Crypto/Taproot/Program.lean:633-642
//       VALIDATION_WEIGHT_OFFSET = 50
//       validationWeightInit w = witnessSerSize w + VALIDATION_WEIGHT_OFFSET
//   spec/core/Bitcoin/Data/Basic.lean:73-77
//       compactSizeEnc thresholds: <0xfd -> 1 ; <=0xffff -> 3 ;
//       <=0xffffffff -> 5 ; else 9
//
// The C leg threads one SizeComputer accumulator left-to-right through the
// vector serializer's element loop; this leg writes the same value as an
// explicit left fold (count prefix + foldl per-item step).  Equality of the
// two shapes is the bounded IR result of this cell; the arbitrary-count
// transfer is the cell-local Lean theorem in src/lean/LoopToFold.lean, which
// is proved over the *pinned C source text* (serialize.h:666-676), not over
// this twin.

constexpr int64_t LG_VALIDATION_WEIGHT_OFFSET = 50;
constexpr uint32_t LG_MAX_ITEMS = 8;

LIMITS_INLINE uint64_t lg_cs64(uint64_t n) {
    if (n < 0xfd) return 1;
    if (n <= 0xffff) return 3;
    if (n <= 0xffffffffULL) return 5;
    return 9;
}

// The per-item fold step: CompactSize(len) + len.
LIMITS_INLINE int64_t lg_item_step(int64_t acc, uint32_t len) {
    return acc + (int64_t)lg_cs64((uint64_t)len) + (int64_t)len;
}

// Left fold over the (<= LG_MAX_ITEMS) item lengths.
LIMITS_INLINE int64_t lg_fold(const uint32_t* lens, uint32_t n_items) {
    int64_t acc = 0;
#pragma clang loop unroll(full)
    for (uint32_t i = 0; i < LG_MAX_ITEMS; i++) {
        if (i < n_items) acc = lg_item_step(acc, lens[i]);
    }
    return acc;
}

LIMITS_INLINE int64_t lg_vector_ser(uint32_t n_items, const uint32_t* lens) {
    return (int64_t)lg_cs64((uint64_t)n_items) + lg_fold(lens, n_items);
}

extern "C" uint64_t cell_compact_size_size(uint64_t n) { return lg_cs64(n); }

extern "C" int64_t cell_basic_byte_ser(int64_t acc, uint32_t len) {
    return lg_item_step(acc, len);
}

extern "C" int64_t cell_vector_ser(uint32_t n_items, const uint32_t* lens) {
    return lg_vector_ser(n_items, lens);
}

extern "C" int64_t cell_seed(uint32_t n_items, const uint32_t* lens) {
    return lg_vector_ser(n_items, lens) + LG_VALIDATION_WEIGHT_OFFSET;
}

// Bounded Alive2 comparison points, mirroring the C leg's instantiations.
#define CELL_VECTOR_SER_K(K) \
    extern "C" int64_t cell_vector_ser_##K(const uint32_t* lens) { \
        return lg_vector_ser(K, lens); \
    }
#define CELL_SEED_K(K) \
    extern "C" int64_t cell_seed_##K(const uint32_t* lens) { \
        return lg_vector_ser(K, lens) + LG_VALIDATION_WEIGHT_OFFSET; \
    }
CELL_VECTOR_SER_K(0) CELL_VECTOR_SER_K(1) CELL_VECTOR_SER_K(2)
CELL_VECTOR_SER_K(3) CELL_VECTOR_SER_K(4) CELL_VECTOR_SER_K(5)
CELL_VECTOR_SER_K(6) CELL_VECTOR_SER_K(7) CELL_VECTOR_SER_K(8)
CELL_SEED_K(0) CELL_SEED_K(1) CELL_SEED_K(2)
CELL_SEED_K(3) CELL_SEED_K(4) CELL_SEED_K(5)
CELL_SEED_K(6) CELL_SEED_K(7) CELL_SEED_K(8)

