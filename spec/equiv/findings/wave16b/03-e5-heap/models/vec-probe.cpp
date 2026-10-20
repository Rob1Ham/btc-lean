// wave16b/03-e5-heap -- isolated std::vector / stack-growth refinement probe.
//
// No engine logic.  These leaves exercise the real libstdc++ vector code with
// the bounded-arena allocator model linked underneath.  They separate "the
// allocator model is adequate for vector growth" from "the engine gets past
// the allocator":
//
//   * w16b_vec_push1    -- one push_back of a symbolic byte on an empty
//                          vector<unsigned char> (the inner valtype alloc).
//   * w16b_stack_grow   -- five push_backs on vector<vector<unsigned char>>
//                          (the EvalScript stack shape: capacity growth
//                          1->2->4->8, element moves, delete of old blocks).
//   * w16b_vec_resize64 -- resize(64, v): fill-insert growth, concrete size.
//   * w16b_vec_resize_big -- resize(N) with N above the arena; used only to
//                          show that the failure branch reaches the libstdc++
//                          throw stub (not hidden).
//
// Each leaf returns a packed summary of the observed vector state instead of
// writing through an out-pointer: bytewise stores read back through a wider
// post-state points-to are not a same-chunk load in Crucible's memory model,
// and the packed return keeps the refinement obligation in the value domain.
//
// Compiled -O0 -fno-exceptions so the module has plain calls (no
// invoke/landingpad); libstdc++'s out-of-memory helpers stay external, so a
// reached failure is a visible missing implementation rather than a silent
// null return.

#include <cstddef>
#include <vector>

// returns (size << 16) | (v[0] << 8) | capacity
extern "C" unsigned long w16b_vec_push1(unsigned char b) {
    std::vector<unsigned char> v;
    v.push_back(b);
    if (v.size() != 1) return ~0UL;
    if (v.capacity() < 1) return ~0UL;
    return (v.size() << 16) | (static_cast<unsigned long>(v[0]) << 8) | v.capacity();
}

// returns 5-byte stack content packed big-endian, or ~0 on a shape mismatch
extern "C" unsigned long w16b_stack_grow(unsigned char seed) {
    std::vector<std::vector<unsigned char>> st;
    unsigned char b = seed;
    for (int i = 0; i < 5; ++i) {
        st.push_back(std::vector<unsigned char>(1, b));
        b = static_cast<unsigned char>(b + 1);
    }
    if (st.size() != 5) return ~0UL;
    unsigned long acc = 0;
    for (int i = 4; i >= 0; --i) {
        if (st[i].size() != 1) return ~0UL;
        acc = (acc << 8) | static_cast<unsigned long>(st[i][0]);
    }
    return acc;
}

// returns (size << 16) | (x[0] << 8) | x[63]
extern "C" unsigned long w16b_vec_resize64(unsigned char v) {
    std::vector<unsigned char> x;
    x.resize(64, v);
    if (x.size() != 64) return ~0UL;
    return (x.size() << 16) | (static_cast<unsigned long>(x[0]) << 8) | x[63];
}

extern "C" unsigned long w16b_vec_resize_big(unsigned long n) {
    std::vector<unsigned char> x;
    x.resize(n, 0xab);
    return x.size();
}
