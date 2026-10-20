#include "policy_common.h"
using namespace policy_cell;

// L leg: REVIEWED TRANSLITERATION (not generated) of
//   spec/core/Bitcoin/Interpreter/Defs.lean
//
//   def isCompressedPubKey (pk : ByteArray) : Bool :=                    -- :389-391
//     pk.size = 33 ∧ (byteOr pk 0 = 0x02 ∨ byteOr pk 0 = 0x03)
//
//   def checkPubKeyEncoding (_flags : ScriptFlags) (pol : PolicyFlags)   -- :398-403
//       (sv : SigVersion) (pk : ByteArray) : Option ExecError :=
//     if pol.strictEnc ∧ !isCompressedOrUncompressedPubKey pk then some .pubKeyType
//     else if pol.witnessPubkeyType ∧ sv = .witnessV0 ∧ !isCompressedPubKey pk
//       then some .witnessPubkeyType                                      -- :401-402
//     else none
//
// `pol.witnessPubkeyType` is PolicyFlags.witnessPubkeyType (Defs.lean:187-205),
// fed by parsePolicyFlags from the corpus "WITNESS_PUBKEYTYPE" string; Core
// carries the same bit in script_verify_flags (:233-235).  The first arm is the
// cell precondition (strictEnc clear).

uint64_t l_witness_pubkeytype(uint64_t flags, uint64_t sigversion,
                              uint64_t pkLen, uint64_t pk0Arg) {
    if (sigversion > SV_TAPSCRIPT) return OUT_OF_DOMAIN;   // cell guard (harness)
    const uint64_t b0 = byte_of(pk0Arg);
    const bool compressed = (pkLen == 33) && (b0 == 0x02 || b0 == 0x03);
    const bool witnessPubkeyType = (flags & WITNESS_PUBKEYTYPE) != 0;
    if (witnessPubkeyType && sigversion == SV_WITNESS_V0 && !compressed) {
        return ERR_WITNESS_PUBKEYTYPE;
    }
    return ERR_OK;
}

extern "C" uint64_t cell_witness_pubkeytype(uint64_t flags, uint64_t sigversion,
                                            uint64_t pkLen, uint64_t pk0Arg) {
    return l_witness_pubkeytype(flags, sigversion, pkLen, pk0Arg);
}
