// L leg: reviewed transliteration of the Lean twin's BIP341 message
// structure facts for SCR-169.
//
//   Crypto/Taproot/Sighash.lean:181-183  spendType ext haveAnnex
//   Crypto/Taproot/Sighash.lean:171-178  extFlagOf (TAPROOT 0, TAPSCRIPT 1,
//                                        other => none/assert)
//   Crypto/Taproot/Sighash.lean:257-286  sigMsgTaproot: serU8 ht starts msg
//   Crypto/Taproot/Sighash.lean:297-300  sighashTaproot = taggedHash tag
//                                        (serU8 0 ++ msg)
//   Crypto/Taproot/Sighash.lean:273-278  (if d.annexPresent then d.annexHash
//                                        else ByteArray.empty)
//   Crypto/Seam/Interface.lean:105-110   annexHash : uint256 (32 bytes)
//
// `taggedHash`/`sha256` are not modelled: the epoch byte value and its
// position, the spend_type byte and the annex-hash inclusion are the slice.
#include <cstdint>

static constexpr uint32_t TAPROOT = 0;
static constexpr uint32_t TAPSCRIPT = 1;
static constexpr uint64_t DOMAIN_REJECT = 0xdeadbeefULL;

extern "C" uint64_t cell_epoch_ht(uint8_t hash_type) {
  // sighashTaproot = taggedHash tag (serU8 0 ++ sigMsgTaproot ...), and
  // sigMsgTaproot begins with serU8 ht.  The epoch is the first byte.
  const uint64_t epoch = 0;
  return (epoch & 0xffULL) | ((uint64_t)hash_type << 8);
}

extern "C" uint64_t cell_spend_type(uint32_t sv, bool annex_present) {
  uint32_t ext_flag;
  if (sv == TAPROOT) ext_flag = 0;        // extFlagOf .taproot = some 0
  else if (sv == TAPSCRIPT) ext_flag = 1; // extFlagOf .tapscript = some 1
  else return DOMAIN_REJECT;              // extFlagOf _ = none
  // Sighash.lean:181-183
  const uint32_t spend_type = ext_flag * 2 + (annex_present ? 1u : 0u);
  return (uint64_t)(spend_type & 0xffu) | ((uint64_t)(ext_flag & 0xffu) << 8);
}

extern "C" uint64_t cell_annex_slice(bool annex_present, uint64_t h0) {
  if (!annex_present) return 0;
  return 1ULL | ((uint64_t)32 << 8) | ((h0 & 0xffffffffULL) << 16);
}
