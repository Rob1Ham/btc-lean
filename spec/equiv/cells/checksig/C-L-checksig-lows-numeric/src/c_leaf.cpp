// C leg: Bitcoin Core cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
//   src/pubkey.cpp:393-399          CPubKey::CheckLowS
//   src/pubkey.cpp:45-193           ecdsa_signature_parse_der_lax
//   src/secp256k1/src/secp256k1.c:407-425  ecdsa_signature_parse_compact
//   src/secp256k1/src/secp256k1.c:453-470  ecdsa_signature_normalize
//   src/secp256k1/src/scalar_4x64_impl.h:62-72   scalar_check_overflow
//   src/secp256k1/src/scalar_4x64_impl.h:244-256 scalar_is_high
//
// CPubKey::CheckLowS parses the DER part laxly and returns
// !secp256k1_ecdsa_signature_normalize(...).  parse_der_lax copies the
// stripped magnitudes into a 64-byte compact buffer and calls
// ecdsa_signature_parse_compact; that call rejects (and zeroes BOTH r and s)
// iff scalar_set_b32 reports overflow, i.e. iff r >= n or s >= n.  normalize
// then returns scalar_is_high(s), so CheckLowS accepts iff s is canonical and
// <= n/2, and also accepts when s was zeroed by the overflow path.
//
// This leaf isolates the S half of that path.  Domain (see spec.md):
//   * R is canonical (r < n) and neither stripped magnitude exceeds 32 bytes,
//     so the shared overflow flag is driven by S alone;
//   * s is the raw big-endian S magnitude, passed as four little-endian
//     64-bit limbs (s0 least significant), 0 <= s < 2^256.
// The leaf therefore returns Core's verdict as a function of raw S:
//   s >= n  -> parse_compact zeroes s -> normalize sees 0 -> low-S
//   s <  n  -> normalize sees s -> low-S iff s <= n/2.
//
// No DER byte parsing, no ECDSA verification, no sighash.  The R-overflow
// coupling and the length-overflow window are outside this leaf and are filed
// in findings/wave64/24-scr-104-low-s/SEAM.md.

#include <cstdint>

static constexpr uint64_t N0 = 0xBFD25E8CD0364141ULL;
static constexpr uint64_t N1 = 0xBAAEDCE6AF48A03BULL;
static constexpr uint64_t N2 = 0xFFFFFFFFFFFFFFFEULL;
static constexpr uint64_t N3 = 0xFFFFFFFFFFFFFFFFULL;

static constexpr uint64_t NH0 = 0xDFE92F46681B20A0ULL;
static constexpr uint64_t NH1 = 0x5D576E7357A4501DULL;
static constexpr uint64_t NH2 = 0xFFFFFFFFFFFFFFFFULL;
static constexpr uint64_t NH3 = 0x7FFFFFFFFFFFFFFFULL;

// secp256k1_scalar_check_overflow (scalar_4x64_impl.h:62-72), verbatim in
// limb form.  Returns 1 iff the 256-bit value is >= n.
static inline __attribute__((always_inline))
int scalar_check_overflow(uint64_t d0, uint64_t d1, uint64_t d2, uint64_t d3) {
    int yes = 0;
    int no = 0;
    no |= (d3 < N3);
    no |= (d2 < N2);
    yes |= (d2 > N2) & ~no;
    no |= (d1 < N1);
    yes |= (d1 > N1) & ~no;
    yes |= (d0 >= N0) & ~no;
    return yes;
}

// secp256k1_scalar_is_high (scalar_4x64_impl.h:244-256), verbatim.
static inline __attribute__((always_inline))
int scalar_is_high(uint64_t d0, uint64_t d1, uint64_t d2, uint64_t d3) {
    int yes = 0;
    int no = 0;
    no |= (d3 < NH3);
    yes |= (d3 > NH3) & ~no;
    no |= (d2 < NH2) & ~yes; /* No need for a > check. */
    no |= (d1 < NH1) & ~yes;
    yes |= (d1 > NH1) & ~no;
    yes |= (d0 > NH0) & ~no;
    return yes;
}

static inline __attribute__((always_inline))
uint64_t core_lows_numeric(uint32_t lowS, uint64_t s0, uint64_t s1,
                           uint64_t s2, uint64_t s3) {
    if (lowS == 0) return 0;
    // ecdsa_signature_parse_compact: overflow rejects and memsets the
    // signature; normalize then reads s = 0 and reports "not high".
    if (scalar_check_overflow(s0, s1, s2, s3) != 0) return 0;
    return (scalar_is_high(s0, s1, s2, s3) != 0) ? 27u : 0u;
}

extern "C" uint64_t cell_lows_numeric(uint32_t lowS, uint64_t s0, uint64_t s1,
                                      uint64_t s2, uint64_t s3) {
    return core_lows_numeric(lowS, s0, s1, s2, s3);
}
