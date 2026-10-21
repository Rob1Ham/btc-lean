#include "policy_common.h"
using namespace policy_cell;

// L leg: REVIEWED TRANSLITERATION (not generated) of
//   spec/core/Bitcoin/Interpreter/Defs.lean
//
//   def checkLowS (sigNoHT : ByteArray) : Bool :=                    -- :355-362
//     if !isValidSigEncoding (sigNoHT.push 0x01) then false
//     else
//       let lenR := (byteOr sigNoHT 3).toNat
//       let lenS := (byteOr sigNoHT (5 + lenR)).toNat
//       let sval := (List.range lenS).foldl (fun acc j => acc*256 + byte j) 0
//       sval <= SIG_S_HALF_ORDER
//
//   def checkSigEncoding flags pol sig : Option ExecError :=            -- :373-380
//     if sig.size = 0 then none
//     else if (flags.dersig ∨ pol.lowS ∨ pol.strictEnc) ∧ !isValidSigEncoding sig
//       then some .sigDer
//     else if pol.lowS ∧ !checkLowS (sig.extract 0 (sig.size - 1)) then some .sigHighS
//     else if pol.strictEnc ∧ !isDefinedHashtype sig then some .sigHashType
//     else none
//
// `pol.lowS` is PolicyFlags.lowS (Defs.lean:187-205), set by parsePolicyFlags
// from the corpus "LOW_S" policy string (:213-227); Core carries the same bit
// in the script_verify_flags word.  `sig.extract 0 (sig.size - 1)` drops the
// hashtype byte, so checkLowS sees the 39-byte signature.
//
// The interpretation of the foldl for lenS = 32 is the big-endian 256-bit S;
// SIG_S_HALF_ORDER is Defs.lean:88-91.  For the declared skeleton, the Lean
// isValidSigEncoding reduces to the same three free conditions as the C leg.

static constexpr uint64_t H0 = 0x7fffffffffffffffULL;
static constexpr uint64_t H1 = 0xffffffffffffffffULL;
static constexpr uint64_t H2 = 0x5d576e7357a4501dULL;
static constexpr uint64_t H3 = 0xdfe92f46681b20a0ULL;

static inline __attribute__((always_inline))
bool l_le_half(uint64_t s0, uint64_t s1, uint64_t s2, uint64_t s3) {
    if (s0 != H0) return s0 < H0;
    if (s1 != H1) return s1 < H1;
    if (s2 != H2) return s2 < H2;
    return s3 <= H3;
}

uint64_t l_lows_policy(uint64_t flags, uint64_t rByte, uint64_t s0,
                       uint64_t s1, uint64_t s2, uint64_t s3) {
    const uint64_t r       = byte_of(rByte);
    const uint64_t sTop    = (s0 >> 56) & 0xff;
    const uint64_t sSecond = (s0 >> 48) & 0xff;

    // isValidSigEncoding (Defs.lean:307-335), specialised to the skeleton.
    const bool valid = r < 0x80 && sTop < 0x80 &&
                       (sTop != 0 || (sSecond & 0x80) != 0);
    // checkLowS (Defs.lean:355-362).
    const bool lowS = valid && l_le_half(s0, s1, s2, s3);

    const bool dersig     = (flags & DERSIG) != 0;
    const bool lowSFlag   = (flags & LOW_S) != 0;
    const bool strictEnc  = (flags & STRICTENC) != 0;
    if ((dersig || lowSFlag || strictEnc) && !valid) return ERR_SIG_DER;
    if (lowSFlag && !lowS) return ERR_SIG_HIGH_S;
    return ERR_OK;
}

extern "C" uint64_t cell_lows_policy(uint64_t flags, uint64_t rByte, uint64_t s0,
                                     uint64_t s1, uint64_t s2, uint64_t s3) {
    return l_lows_policy(flags, rByte, s0, s1, s2, s3);
}
