#include "limits_common.h"

// C leg: line-cited source-excerpt slice of Bitcoin Core at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// SCR-040: the BIP342 tapscript validation-weight budget is
//
//   interpreter.cpp:1991-1992 (tapscript arm of VerifyWitnessProgram)
//       execdata.m_validation_weight_left =
//           ::GetSerializeSize(witness.stack) + VALIDATION_WEIGHT_OFFSET;
//   script.h:62-65             VALIDATION_WEIGHT_OFFSET = 50
//   serialize.h:291-297        GetSizeOfCompactSize(n):
//         1 byte if n < 253; 3 if <= 0xffff; 5 if <= 0xffffffff; else 9
//   serialize.h:898-906        vector<byte> = CompactSize(size) || bytes
//   serialize.h:1156-1160      GetSerializeSize uses SizeComputer
//   serialize.h:120-140        SizeComputer::write(len) advances the count by len
//
// witness.stack is vector<vector<unsigned char>>, so its serialized size is
// the actual byte stream
//
//   CompactSize(items) || (CompactSize(len_0) || item_0) || ... ||
//   (CompactSize(len_{n-1}) || item_{n-1})
//
// and the budget is that byte count + 50 WU.
//
// This cell models GetSerializeSize the way Core implements it: a
// SizeComputer whose `write(n)` adds exactly n to a counter.  The loop below
// is the vector serializer's element loop (serialize.h:898-906); item bytes
// are counted by their length, which is all GetSerializeSize can observe.
//
// The loop is unrolled to the declared cell bound LIMITS_BUDGET_ITEMS = 8 so
// SAW can check a *symbolic* item count n_items <= 8 and symbolic 32-bit item
// lengths.  The unbounded count is NOT proved here; see spec.md's
// "arbitrary-count bridge" section.  This is why SCR-040 stays partial.

constexpr int64_t W_VALIDATION_WEIGHT_OFFSET = 50;
constexpr uint32_t W_MAX_ITEMS = 8;

// serialize.h:291-297.  Full 64-bit domain so the 9-byte branch is reachable
// and verified, not merely present.
LIMITS_INLINE uint64_t w_compact_size_size64(uint64_t n) {
    if (n < 253) return 1;
    if (n <= 0xffff) return 3;
    if (n <= 0xffffffffULL) return 5;
    return 9;
}

// SizeComputer::write(len): the serialized size grows by exactly len bytes.
// No item byte value is read; only the length enters the count.
LIMITS_INLINE int64_t w_write(int64_t acc, uint64_t nbytes) {
    return acc + (int64_t)nbytes;
}

// SCR-040 stack-count term: CompactSize(n_items) + 50.
LIMITS_INLINE int64_t w_budget_count(uint32_t n_items) {
    return w_write(0, w_compact_size_size64((uint64_t)n_items)) +
           W_VALIDATION_WEIGHT_OFFSET;
}

// One element of the serializer's loop: write CompactSize(len), then len
// payload bytes.  This is the per-item contribution to the byte count.
LIMITS_INLINE int64_t w_item_step(uint32_t len, int64_t acc) {
    return w_write(w_write(acc, w_compact_size_size64((uint64_t)len)),
                   (uint64_t)len);
}

// GetSerializeSize(witness.stack): write the count prefix, then one
// cs+payload contribution per element.  Unrolled to W_MAX_ITEMS so a
// symbolic item count can be checked; the caller must honour
// n_items <= W_MAX_ITEMS (SAW precondition).
LIMITS_INLINE int64_t w_witness_serialized_size(uint32_t n_items, const uint32_t* lens) {
    int64_t acc = w_write(0, w_compact_size_size64((uint64_t)n_items));
#pragma clang loop unroll(full)
    for (uint32_t i = 0; i < W_MAX_ITEMS; i++) {
        if (i < n_items) {
            acc = w_write(acc, w_compact_size_size64((uint64_t)lens[i]));
            acc = w_write(acc, (uint64_t)lens[i]);
        }
    }
    return acc;
}

// interpreter.cpp:1991-1992: budget = serialized witness size + 50.
LIMITS_INLINE int64_t w_witness_budget(uint32_t n_items, const uint32_t* lens) {
    return w_witness_serialized_size(n_items, lens) + W_VALIDATION_WEIGHT_OFFSET;
}

extern "C" uint64_t cell_compact_size_size(uint64_t n) {
    return w_compact_size_size64(n);
}

extern "C" int64_t cell_witness_budget_count(uint32_t n_items) {
    return w_budget_count(n_items);
}

extern "C" int64_t cell_witness_item_step(uint32_t len, int64_t acc) {
    return w_item_step(len, acc);
}

extern "C" int64_t cell_witness_serialized_size(uint32_t n_items,
                                                const uint32_t* lens) {
    return w_witness_serialized_size(n_items, lens);
}

extern "C" int64_t cell_witness_budget(uint32_t n_items, const uint32_t* lens) {
    return w_witness_budget(n_items, lens);
}
