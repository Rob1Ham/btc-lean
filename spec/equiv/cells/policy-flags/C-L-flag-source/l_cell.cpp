#include "policy_common.h"
using namespace policy_cell;

// L leg: REVIEWED TRANSLITERATION (not generated) of
//   spec/core/Bitcoin/Activation/Flags.lean
//
//   def buriedActive (_P : ChainParams) (since height : UInt32) : Bool :=
//     since <= height                                                -- BLK-072
//
//   def mainnetExceptionMap : BlockHash -> Option ScriptFlags := fun hash =>
//     if hash = bip16ExceptionHash then
//       some { p2sh := false, witness := false, taproot := false }
//     else if hash = taprootExceptionHash then
//       some { p2sh := true, witness := true, taproot := false }
//     else none                                                      -- INV-133
//
//   def getBlockScriptFlagsP (P : ChainParams) (hash : BlockHash)
//       (height : UInt32) : ScriptFlags :=
//     let base :=
//       match P.scriptFlagExceptions hash with
//       | some exf => exf
//       | none => { p2sh := true, witness := true, taproot := true }
//     { base with
//         dersig    := base.dersig    || buriedActive P P.bip66Height  height
//         cltv      := base.cltv      || buriedActive P P.bip65Height  height
//         csv       := base.csv       || buriedActive P P.csvHeight    height
//         nullDummy := base.nullDummy || buriedActive P P.segwitHeight height }
//                                                                     -- SCR-015
//
//   def flagBits (f : ScriptFlags) : UInt32 :=
//     (bif f.p2sh then 1<<<0 else 0) ||| (bif f.dersig then 1<<<2 else 0) |||
//     (bif f.nullDummy then 1<<<4 else 0) ||| (bif f.cltv then 1<<<9 else 0) |||
//     (bif f.csv then 1<<<10 else 0) ||| (bif f.witness then 1<<<11 else 0) |||
//     (bif f.taproot then 1<<<17 else 0)                             -- flagBits
//
// The hash-keyed lookup is bounded exactly as in the C leg: the hash is
// replaced by its equivalence class under the two-entry mainnet exception map
// (TXV-056 proves the map has exactly those two reduced entries and every
// other hash falls through to `none`).
//
// Policy-only rows, same file:
//   inductive PolicyFlag | lowS | ... | constScriptCode | ...            -- SCR-175/181
//   def standardPolicy : PolicyFlags :=
//     { ..., constScriptCode := true, ..., lowS := true, ... }           -- PDW93b
//   def consensusFullFlags (f : ScriptFlags) : FullFlags :=
//     { consensus := f, policy := fun _ => false }                       -- Flags.lean
//   theorem policy_absent_from_consensus (f) (p) :
//     (consensusFullFlags f).policy p = false := rfl

struct ScriptFlagsRecord {
    bool p2sh = false;
    bool dersig = false;
    bool cltv = false;
    bool csv = false;
    bool nullDummy = false;
    bool witness = false;
    bool taproot = false;
};

static inline __attribute__((always_inline))
bool l_buriedActive(uint64_t since, uint64_t height) {
    return since <= height;
}

// Transliteration of `mainnetExceptionMap` specialised to the three classes.
static inline __attribute__((always_inline))
ScriptFlagsRecord l_mainnet_exception(uint64_t exceptionKind) {
    ScriptFlagsRecord exf;
    if (exceptionKind == EXC_BIP16) {
        exf.p2sh = false; exf.witness = false; exf.taproot = false;
    } else if (exceptionKind == EXC_TAPROOT) {
        exf.p2sh = true; exf.witness = true; exf.taproot = false;
    }
    return exf;
}

// Transliteration of `getBlockScriptFlagsP mainnetParams`.
static inline __attribute__((always_inline))
ScriptFlagsRecord l_getBlockScriptFlagsP(uint64_t exceptionKind, uint64_t height) {
    ScriptFlagsRecord base;
    if (exceptionKind == EXC_BIP16 || exceptionKind == EXC_TAPROOT) {
        base = l_mainnet_exception(exceptionKind);
    } else {
        base.p2sh = true; base.witness = true; base.taproot = true;
    }
    base.dersig    = base.dersig    || l_buriedActive(BIP66_HEIGHT,  height);
    base.cltv      = base.cltv      || l_buriedActive(BIP65_HEIGHT,  height);
    base.csv       = base.csv       || l_buriedActive(CSV_HEIGHT,    height);
    base.nullDummy = base.nullDummy || l_buriedActive(SEGWIT_HEIGHT, height);
    return base;
}

// Transliteration of `flagBits`.
static inline __attribute__((always_inline))
uint64_t l_flagBits(const ScriptFlagsRecord& f) {
    return (f.p2sh      ? P2SH      : 0) |
           (f.dersig    ? DERSIG    : 0) |
           (f.nullDummy ? NULLDUMMY : 0) |
           (f.cltv      ? CLTV      : 0) |
           (f.csv       ? CSV       : 0) |
           (f.witness   ? WITNESS   : 0) |
           (f.taproot   ? TAPROOT   : 0);
}

uint64_t l_flag_source(uint64_t exceptionKind, uint64_t height) {
    return l_flagBits(l_getBlockScriptFlagsP(exceptionKind, height % 0x100000000ULL));
}

uint64_t l_flag_source_policy_mask(uint64_t exceptionKind, uint64_t height) {
    return l_flagBits(l_getBlockScriptFlagsP(exceptionKind, height % 0x100000000ULL)) &
           (LOW_S | CONST_SCRIPTCODE);
}

// `standardPolicy` (PDW93b) has lowS = true and constScriptCode = true; map
// those two policy fields to their verify_flags.h bits.
uint64_t l_standard_policy_mask() {
    const bool lowS = true;             // standardPolicy.lowS
    const bool constScriptCode = true;  // standardPolicy.constScriptCode
    return (lowS ? LOW_S : 0) | (constScriptCode ? CONST_SCRIPTCODE : 0);
}

// `consensusFullFlags` sets `policy := fun _ => false`; the consensus word is
// the full ScriptFlags record through flagBits, and no policy bit can appear.
uint64_t l_mandatory_policy_mask() {
    ScriptFlagsRecord consensus;
    consensus.p2sh = true; consensus.dersig = true; consensus.cltv = true;
    consensus.csv = true; consensus.nullDummy = true;
    consensus.witness = true; consensus.taproot = true;
    // policy_absent_from_consensus: (consensusFullFlags f).policy p = false.
    const bool lowS = false;
    const bool constScriptCode = false;
    return (l_flagBits(consensus) & (LOW_S | CONST_SCRIPTCODE)) |
           (lowS ? LOW_S : 0) | (constScriptCode ? CONST_SCRIPTCODE : 0);
}

extern "C" uint64_t cell_flag_source(uint64_t exceptionKind, uint64_t height) {
    return l_flag_source(exceptionKind, height);
}

// Integration roots: the L gate is the reviewed transliteration of
// Defs.lean checkSigEncoding (:373-380) and the two CONST_SCRIPTCODE gates
// (:833 decode, :725-729 FindAndDelete), fed the L block word.
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

uint64_t l_lows_gate_block(uint64_t exceptionKind, uint64_t height,
                           uint64_t rByte, uint64_t s0, uint64_t s1,
                           uint64_t s2, uint64_t s3) {
    const uint64_t flags = l_flag_source(exceptionKind, height);
    const uint64_t r       = rByte & 0xff;
    const uint64_t sTop    = (s0 >> 56) & 0xff;
    const uint64_t sSecond = (s0 >> 48) & 0xff;
    const bool valid = r < 0x80 && sTop < 0x80 &&
                       (sTop != 0 || (sSecond & 0x80) != 0);
    const bool lowS = valid && l_le_half(s0, s1, s2, s3);
    const bool dersig    = (flags & DERSIG) != 0;
    const bool lowSFlag  = (flags & LOW_S) != 0;
    const bool strictEnc = (flags & STRICTENC) != 0;
    if ((dersig || lowSFlag || strictEnc) && !valid) return ERR_SIG_DER;
    if (lowSFlag && !lowS) return ERR_SIG_HIGH_S;
    return ERR_OK;
}

uint64_t l_const_gate_block(uint64_t exceptionKind, uint64_t height,
                            uint64_t sigversion, uint64_t opcode,
                            uint64_t foundPositive) {
    if (foundPositive > 1) return OUT_OF_DOMAIN;
    const uint64_t flags = l_flag_source(exceptionKind, height);
    const bool constScriptCode = (flags & CONST_SCRIPTCODE) != 0;
    const bool found = foundPositive != 0;
    if (opcode == 0xab && sigversion == SV_BASE && constScriptCode) {
        return ERR_OP_CODESEPARATOR;
    }
    if (sigversion == SV_BASE && found && constScriptCode) {
        return ERR_SIG_FINDANDDELETE;
    }
    return ERR_OK;
}

extern "C" uint64_t cell_lows_gate_block(uint64_t exceptionKind,
                                         uint64_t height, uint64_t rByte,
                                         uint64_t s0, uint64_t s1, uint64_t s2,
                                         uint64_t s3) {
    return l_lows_gate_block(exceptionKind, height, rByte, s0, s1, s2, s3);
}

extern "C" uint64_t cell_const_gate_block(uint64_t exceptionKind,
                                          uint64_t height, uint64_t sigversion,
                                          uint64_t opcode,
                                          uint64_t foundPositive) {
    return l_const_gate_block(exceptionKind, height, sigversion, opcode,
                              foundPositive);
}

extern "C" uint64_t cell_flag_source_policy_mask(uint64_t exceptionKind,
                                                  uint64_t height) {
    return l_flag_source_policy_mask(exceptionKind, height);
}

extern "C" uint64_t cell_standard_policy_mask() {
    return l_standard_policy_mask();
}

extern "C" uint64_t cell_mandatory_policy_mask() {
    return l_mandatory_policy_mask();
}
