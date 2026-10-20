// L leg: REVIEWED TRANSLITERATION (not twin-generated) of
//   spec/core/Bitcoin/Crypto/Ecdsa/Der.lean:210-219
//     def halfN : Nat := n / 2
//     def isLowDERSignature (b : ByteArray) : Bool :=
//       isDERSignature b &&
//       match parseDerLax (dropLastByte b) with
//       | none => false
//       | some (_, s) => s % n ≤ halfN
//
// Domain (see spec.md): the BIP66 gate has already passed, R is canonical and
// neither stripped magnitude exceeds 32 bytes, so parseDerLax's shared
// length-overflow flag is clear and its raw S is the input.  The leaf models
// the numeric half only:
//     s % n <= floor(n/2)
// over 0 <= s < 2^256.  Since n > 2^255, the remainder is one conditional
// subtraction: s < n ? s : s - n.  This is exactly Lean's `%` on Nat for this
// domain and is deliberately implemented differently from the C leg's
// libsecp overflow/zeroing path, so the two legs are not the same code.

#include <cstdint>

static constexpr uint64_t N0 = 0xBFD25E8CD0364141ULL;
static constexpr uint64_t N1 = 0xBAAEDCE6AF48A03BULL;
static constexpr uint64_t N2 = 0xFFFFFFFFFFFFFFFEULL;
static constexpr uint64_t N3 = 0xFFFFFFFFFFFFFFFFULL;

static constexpr uint64_t NH0 = 0xDFE92F46681B20A0ULL;
static constexpr uint64_t NH1 = 0x5D576E7357A4501DULL;
static constexpr uint64_t NH2 = 0xFFFFFFFFFFFFFFFFULL;
static constexpr uint64_t NH3 = 0x7FFFFFFFFFFFFFFFULL;

// 256-bit unsigned comparison, most-significant limb first.
static inline __attribute__((always_inline))
bool ge_n(uint64_t d0, uint64_t d1, uint64_t d2, uint64_t d3) {
    if (d3 != N3) return d3 > N3;
    if (d2 != N2) return d2 > N2;
    if (d1 != N1) return d1 > N1;
    return d0 >= N0;
}

// d - n, valid only when d >= n.  Limb subtraction with explicit borrows.
static inline __attribute__((always_inline))
void sub_n(uint64_t d0, uint64_t d1, uint64_t d2, uint64_t d3,
           uint64_t& r0, uint64_t& r1, uint64_t& r2, uint64_t& r3) {
    const uint64_t b0 = (d0 < N0);
    r0 = d0 - N0;
    const uint64_t t1 = d1 - N1;
    const uint64_t b1 = (d1 < N1);
    r1 = t1 - b0;
    const uint64_t b1b = (t1 < b0);
    const uint64_t t2 = d2 - N2;
    const uint64_t b2 = (d2 < N2);
    r2 = t2 - b1 - b1b;
    const uint64_t b2b = (t2 < (b1 + b1b)) | ((b1 + b1b) < b1);
    r3 = d3 - N3 - b2 - b2b;
}

// s <= floor(n/2), most-significant limb first.
static inline __attribute__((always_inline))
bool le_half(uint64_t d0, uint64_t d1, uint64_t d2, uint64_t d3) {
    if (d3 != NH3) return d3 < NH3;
    if (d2 != NH2) return d2 < NH2;
    if (d1 != NH1) return d1 < NH1;
    return d0 <= NH0;
}

static inline __attribute__((always_inline))
uint64_t lean_lows_numeric(uint32_t lowS, uint64_t s0, uint64_t s1,
                           uint64_t s2, uint64_t s3) {
    if (lowS == 0) return 0;
    uint64_t r0 = s0, r1 = s1, r2 = s2, r3 = s3;
    if (ge_n(s0, s1, s2, s3)) sub_n(s0, s1, s2, s3, r0, r1, r2, r3);
    return le_half(r0, r1, r2, r3) ? 0u : 27u;
}

extern "C" uint64_t cell_lows_numeric(uint32_t lowS, uint64_t s0, uint64_t s1,
                                      uint64_t s2, uint64_t s3) {
    return lean_lows_numeric(lowS, s0, s1, s2, s3);
}
