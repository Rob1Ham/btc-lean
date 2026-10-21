#include "policy_common.h"
using namespace policy_cell;

// C leg: Bitcoin Core src/script/interpreter.cpp @ pin cce32b168.
//
// CheckSignatureEncoding (:207-224), the two branches this row is about:
//
//   if ((flags & (DERSIG|LOW_S|STRICTENC)) != 0 && !IsValidSignatureEncoding(vchSig))  // :217
//       return set_error(serror, SCRIPT_ERR_SIG_DER);                                   // :218
//   else if ((flags & LOW_S) != 0 && !IsLowDERSignature(vchSig, serror))                // :219-220
//       return false;   // serror = SCRIPT_ERR_SIG_HIGH_S                               // :221
//
// IsLowDERSignature (:183-196) re-checks IsValidSignatureEncoding (:184) and
// then calls CPubKey::CheckLowS (:193) -> SIG_HIGH_S (:194-195).
//
// DOMAIN (declared, see spec.md): the canonical DER skeleton
//   30 25 02 01 <R> 02 20 <S:32> <hashtype>          (sig.size() == 40, lenR == 1, lenS == 32)
// Under that skeleton only three IsValidSignatureEncoding conditions are free:
//   :149  sig[4] & 0x80                    -> R must be positive
//   :172  sig[lenR+6] & 0x80 = sig[7]      -> S[0] must be positive
//   :177  lenS>1 && S[0]==0 && !(S[1]&0x80) -> minimal S encoding
// so validity is computed from R and the first two S bytes.
//
// CPubKey::CheckLowS is the SAME-CRYPTO seam (docs/DECISION-lax-ecdsa.md): the
// Lean model spells it as `sval <= SIG_S_HALF_ORDER` (Defs.lean:355-362), and
// that is the predicate compared here.

static constexpr uint64_t H0 = 0x7fffffffffffffffULL;
static constexpr uint64_t H1 = 0xffffffffffffffffULL;
static constexpr uint64_t H2 = 0x5d576e7357a4501dULL;
static constexpr uint64_t H3 = 0xdfe92f46681b20a0ULL;

// 256-bit big-endian s <= n/2 (Defs.lean:88-91 SIG_S_HALF_ORDER).
static inline __attribute__((always_inline))
bool c_le_half(uint64_t s0, uint64_t s1, uint64_t s2, uint64_t s3) {
    if (s0 != H0) return s0 < H0;
    if (s1 != H1) return s1 < H1;
    if (s2 != H2) return s2 < H2;
    return s3 <= H3;
}

uint64_t c_lows_policy(uint64_t flags, uint64_t rByte, uint64_t s0,
                       uint64_t s1, uint64_t s2, uint64_t s3) {
    const uint64_t r  = byte_of(rByte);
    const uint64_t sTop = (s0 >> 56) & 0xff;              // S[0]
    const uint64_t sSecond = (s0 >> 48) & 0xff;           // S[1]

    // IsValidSignatureEncoding, specialised to the declared skeleton.
    const bool valid =
        r < 0x80 &&                                       // :149
        sTop < 0x80 &&                                    // :172
        (sTop != 0 || (sSecond & 0x80) != 0);             // :177

    // IsLowDERSignature / CPubKey::CheckLowS, DER-level formulation.
    const bool lowS = valid && c_le_half(s0, s1, s2, s3);

    if ((flags & (DERSIG | LOW_S | STRICTENC)) != 0 && !valid) {
        return ERR_SIG_DER;                               // :217-218
    } else if ((flags & LOW_S) != 0 && !lowS) {
        return ERR_SIG_HIGH_S;                            // :219-221 / :194-195
    }
    return ERR_OK;                                        // :223
}

extern "C" uint64_t cell_lows_policy(uint64_t flags, uint64_t rByte, uint64_t s0,
                                     uint64_t s1, uint64_t s2, uint64_t s3) {
    return c_lows_policy(flags, rByte, s0, s1, s2, s3);
}
