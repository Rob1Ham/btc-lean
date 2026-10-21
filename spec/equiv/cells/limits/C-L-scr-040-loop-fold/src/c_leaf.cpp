#include "limits_common.h"

// C leg: line-cited source-excerpt slice of Bitcoin Core at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66 (v32.99).
//
// SCR-040: the BIP342 tapscript validation-weight seed is
//
//   interpreter.cpp:1991-1992 (tapscript arm of VerifyWitnessProgram)
//       execdata.m_validation_weight_left =
//           ::GetSerializeSize(witness.stack) + VALIDATION_WEIGHT_OFFSET;
//   script.h:62-65             VALIDATION_WEIGHT_OFFSET = 50
//
// and, for witness.stack : std::vector<std::vector<unsigned char>>,
//
//   serialize.h:1156-1160   GetSerializeSize(t) = (SizeComputer() << t).size()
//   serialize.h:900-902     Serialize(SizeComputer&, vector<vector<u8>>)
//                             -> VectorFormatter<DefaultFormatter>::Ser
//   serialize.h:666-676     VectorFormatter::Ser
//                             Formatter formatter;
//                             WriteCompactSize(s, v.size());
//                             for (const V::value_type& elem : v)
//                                 formatter.Ser(s, elem);
//   serialize.h:901-902     the per-element DefaultFormatter::Ser ->
//                           Serialize(SizeComputer&, vector<u8>) BasicByte arm
//                             WriteCompactSize(os, v.size());
//                             if (!v.empty()) os.write(MakeByteSpan(v));
//   serialize.h:1151-1154   WriteCompactSize(SizeComputer&, n) = s.seek(csSize(n))
//   serialize.h:1127-1130   SizeComputer::seek -> m_size += num
//   serialize.h:1121-1124   SizeComputer::write -> m_size += src.size()
//   serialize.h:291-297     GetSizeOfCompactSize(n): 1/3/5/9 bytes
//
// Each helper below is the exact arithmetic of one of those pinned lines, kept
// separate so the arbitrary-count composition is visible:
//
//   cell_vector_ser = prefix(cs(n_items)) then, for every item in order,
//                     cell_basic_byte_ser (the element serializer's effect).
//
// The loop is unrolled to the declared cell bound 8 because SAW/LLVM and
// Alive2 v20 execute loops by unrolling.  The arbitrary-count closure is the
// cell-local Lean proof in src/lean/LoopToFold.lean, which parses the *pinned
// source text* of serialize.h:666-676 and the per-element body and proves the
// loop semantics equals the fold for an arbitrary list; see spec.md.

constexpr int64_t CG_VALIDATION_WEIGHT_OFFSET = 50;
constexpr uint32_t CG_MAX_ITEMS = 8;

// serialize.h:291-297.  Full 64-bit domain so the 9-byte branch is reachable
// and verified, not merely present.
LIMITS_INLINE uint64_t cg_cs64(uint64_t n) {
    if (n < 253) return 1;
    if (n <= 0xffff) return 3;
    if (n <= 0xffffffffULL) return 5;
    return 9;
}

// serialize.h:1127-1130 (seek) and 1121-1124 (write): the SizeComputer adds
// exactly the number of bytes the serializer emits.
LIMITS_INLINE int64_t cg_seek(int64_t acc, uint64_t nbytes) {
    return acc + (int64_t)nbytes;
}

// serialize.h:1151-1154: WriteCompactSize(SizeComputer&, n) = s.seek(csSize(n)).
LIMITS_INLINE int64_t cg_write_compact_size(int64_t acc, uint64_t n) {
    return cg_seek(acc, cg_cs64(n));
}

// serialize.h:901-902, the BasicByte arm of Serialize(Stream&, vector<T>&) as
// reached by DefaultFormatter::Ser for a witness item vector<unsigned char>:
//   WriteCompactSize(os, v.size());
//   if (!v.empty()) os.write(MakeByteSpan(v));
// `write` adds v.size() bytes; when the vector is empty nothing is added, so
// the effect is csSize(len) + len in both branches.
LIMITS_INLINE int64_t cg_basic_byte_ser(int64_t acc, uint32_t len) {
    acc = cg_write_compact_size(acc, (uint64_t)len);
    // `if (!v.empty()) os.write(...)`: an empty span adds 0 bytes, so the
    // guarded write has the same byte count as an unconditional write of len.
    // The guard itself is proved in src/lean/LoopToFold.lean
    // (`if_empty_size`) and in SAW (`basic_step`); omitting the branch here
    // keeps the bounded IR comparison from exploring 2^item_count guard paths.
    acc = cg_seek(acc, (uint64_t)len);
    return acc;
}

// serialize.h:666-676, VectorFormatter::Ser for
// V = std::vector<std::vector<unsigned char>>: write the element count, then
// run the element serializer over the elements in order, accumulating into the
// same SizeComputer.
LIMITS_INLINE int64_t cg_vector_ser(uint32_t n_items, const uint32_t* lens) {
    int64_t acc = cg_write_compact_size(0, (uint64_t)n_items);
#pragma clang loop unroll(full)
    for (uint32_t i = 0; i < CG_MAX_ITEMS; i++) {
        if (i < n_items) acc = cg_basic_byte_ser(acc, lens[i]);
    }
    return acc;
}

extern "C" uint64_t cell_compact_size_size(uint64_t n) { return cg_cs64(n); }

extern "C" int64_t cell_basic_byte_ser(int64_t acc, uint32_t len) {
    return cg_basic_byte_ser(acc, len);
}

// serialize.h:1156-1160: GetSerializeSize(t) = (SizeComputer() << t).size(),
// i.e. the SizeComputer starts at 0 and is threaded through the serializer.
extern "C" int64_t cell_vector_ser(uint32_t n_items, const uint32_t* lens) {
    return cg_vector_ser(n_items, lens);
}

// interpreter.cpp:1991-1992: seed = GetSerializeSize(witness.stack) + 50.
extern "C" int64_t cell_seed(uint32_t n_items, const uint32_t* lens) {
    return cg_vector_ser(n_items, lens) + CG_VALIDATION_WEIGHT_OFFSET;
}

// Bounded Alive2 comparison points: instantiate the item count so LLVM folds
// the 8-way outer guard away.  The symbolic-count loop above is checked by SAW
// (count <= 8, symbolic lengths) and, at arbitrary count, by the Lean bridge.
#define CELL_VECTOR_SER_K(K) \
    extern "C" int64_t cell_vector_ser_##K(const uint32_t* lens) { \
        return cg_vector_ser(K, lens); \
    }
#define CELL_SEED_K(K) \
    extern "C" int64_t cell_seed_##K(const uint32_t* lens) { \
        return cg_vector_ser(K, lens) + CG_VALIDATION_WEIGHT_OFFSET; \
    }
CELL_VECTOR_SER_K(0) CELL_VECTOR_SER_K(1) CELL_VECTOR_SER_K(2)
CELL_VECTOR_SER_K(3) CELL_VECTOR_SER_K(4) CELL_VECTOR_SER_K(5)
CELL_VECTOR_SER_K(6) CELL_VECTOR_SER_K(7) CELL_VECTOR_SER_K(8)
CELL_SEED_K(0) CELL_SEED_K(1) CELL_SEED_K(2)
CELL_SEED_K(3) CELL_SEED_K(4) CELL_SEED_K(5)
CELL_SEED_K(6) CELL_SEED_K(7) CELL_SEED_K(8)

