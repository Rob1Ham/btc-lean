// C leg, cell C-L-checksig-bip66.
//
// Bounded, line-cited slice of Bitcoin Core cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66:
//   src/validation.cpp:2249-2270  (GetBlockScriptFlags base set, exception
//                                  replacement, and the DERSIG OR)
//   src/deploymentstatus.h:27-31  (DeploymentActiveAt, buried deployment)
//   src/consensus/params.h:104,151 (BIP66Height / DeploymentHeight)
//   src/kernel/chainparams.cpp:117-124 (mainnet BIP66Height = 363725)
//
// The chain-state and DeploymentActiveAt plumbing is reduced to its value at
// the pin: for a buried deployment the predicate is `index.nHeight >=
// params.DeploymentHeight(dep)`, and for DEPLOYMENT_DERSIG that height is
// Consensus::Params::BIP66Height.  Heights are bounded to [0, 2^31) so the
// signed int compare in Core coincides with the unsigned compare here.
#include "cell_common.h"

#define W16_FLAG_P2SH    1u
#define W16_FLAG_WITNESS 2u
#define W16_FLAG_TAPROOT 4u
#define W16_FLAG_DERSIG  8u

// validation.cpp:2249-2261: base set P2SH|WITNESS|TAPROOT, replaced wholesale
// on an exception hash.
W16INLINE uint32_t core_base_flags(uint32_t exc) {
    uint32_t flags = W16_FLAG_P2SH | W16_FLAG_WITNESS | W16_FLAG_TAPROOT;
    if (exc == 1) flags = 0;                             // BIP16 exception: SCRIPT_VERIFY_NONE
    else if (exc == 2) flags = W16_FLAG_P2SH | W16_FLAG_WITNESS;  // taproot exception
    return flags;
}

// validation.cpp:2262-2270 + deploymentstatus.h:27-31:
//   if (DeploymentActiveAt(block_index, chainman, DEPLOYMENT_DERSIG))
//       flags |= SCRIPT_VERIFY_DERSIG;
//   DeploymentActiveAt(buried)  ==  index.nHeight >= params.DeploymentHeight(dep)
//   DeploymentHeight(DERSIG)    ==  params.BIP66Height
W16INLINE uint32_t core_dersig_or(uint32_t bip66_height, uint32_t height,
                                  uint32_t base_flags) {
    uint32_t flags = base_flags;
    if (height >= bip66_height) flags |= W16_FLAG_DERSIG;
    return flags;
}

extern "C" uint64_t cell_dersig_flag(uint32_t bip66_height, uint32_t height,
                                     uint32_t exc) {
    return (uint64_t)core_dersig_or(bip66_height, height,
                                    core_base_flags(exc));
}

// Mainnet constant (kernel/chainparams.cpp:117-124, also
// spec/core/Bitcoin/Activation/Flags.lean:116).
extern "C" uint64_t cell_dersig_flag_mainnet(uint32_t height, uint32_t exc) {
    return (uint64_t)core_dersig_or(363725u, height, core_base_flags(exc));
}

// The general OR, with the base flag word supplied directly (the Lean
// `base.dersig || buriedActive ...` shape).  Used to prove that the OR never
// drops a base-set DERSIG bit.
extern "C" uint64_t cell_dersig_or(uint32_t bip66_height, uint32_t height,
                                   uint32_t base_flags) {
    return (uint64_t)core_dersig_or(bip66_height, height, base_flags & 15u);
}
