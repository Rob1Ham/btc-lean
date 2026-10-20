#include "cell_common.h"

// C leg: line-cited source-excerpt slices of Bitcoin Core
// src/script/interpreter.cpp and src/script/script.cpp at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// Excerpt 1 -- control-block size gate, interpreter.cpp:1980-1982:
//
//   if (control.size() < TAPROOT_CONTROL_BASE_SIZE ||
//       control.size() > TAPROOT_CONTROL_MAX_SIZE ||
//       ((control.size() - TAPROOT_CONTROL_BASE_SIZE) %
//        TAPROOT_CONTROL_NODE_SIZE) != 0) {
//       return set_error(serror, SCRIPT_ERR_TAPROOT_WRONG_CONTROL_SIZE);
//   }
//
// Constants: interpreter.h:244 TAPROOT_CONTROL_BASE_SIZE = 33,
// :245 NODE_SIZE = 32, :247 MAX_SIZE = 33 + 32*128 = 4129.
TAP_INLINE uint64_t c_control_size(uint64_t size) {
  if (size < TAP_CONTROL_BASE_SIZE || size > TAP_CONTROL_MAX_SIZE ||
      ((size - TAP_CONTROL_BASE_SIZE) % TAP_CONTROL_NODE_SIZE) != 0) {
    return tap_pack(TAP_FAIL, TAP_ERR_TAPROOT_WRONG_CONTROL_SIZE);
  }
  return tap_pack(TAP_OK, 0u);
}

// Excerpt 2 -- leaf-version dispatch, interpreter.cpp:1988-1998:
//
//   if ((control[0] & TAPROOT_LEAF_MASK) == TAPROOT_LEAF_TAPSCRIPT) {
//       ... ExecuteWitnessScript(..., SigVersion::TAPSCRIPT, ...);
//   }
//   if (flags & SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION) {
//       return set_error(serror, SCRIPT_ERR_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION);
//   }
//   return set_success(serror);
//
// interpreter.h:242-243: TAPROOT_LEAF_MASK = 0xfe, TAPROOT_LEAF_TAPSCRIPT =
// 0xc0.  control[0] is an unsigned char; `& 0xff` totalises the harness input.
TAP_INLINE uint64_t c_leaf_version(uint64_t control0,
                                   uint64_t discourage_taproot) {
  const uint64_t leaf = (control0 & 0xffu) & TAP_LEAF_MASK;
  if (leaf == TAP_LEAF_TAPSCRIPT) return tap_pack(TAP_TAPSCRIPT, 0u);
  if (discourage_taproot != 0u) {
    return tap_pack(TAP_FAIL, TAP_ERR_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION);
  }
  return tap_pack(TAP_OK, 0u);
}

// Excerpt 3 -- the post-taproot upgradable tail, interpreter.cpp:2000-2008:
//
//   } else if (!is_p2sh && CScript::IsPayToAnchor(witversion, program)) {
//       return true;
//   } else {
//       if (flags & SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM) {
//           return set_error(serror,
//               SCRIPT_ERR_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM);
//       }
//       // Other version/size/p2sh combinations return true for future
//       // softfork compatibility
//       return true;
//   }
//
// CScript::IsPayToAnchor(version, program) (script.cpp:216-222):
//   version == 1 && program.size() == 2 &&
//   program[0] == 0x4e && program[1] == 0x73.
//
// The function models the tail for witversion in 0..16 (the range
// CScript::IsWitnessProgram can produce).  v0 and the native v1-32 arm are
// delegated markers: their outcomes are other cells' subjects.  A version
// outside 0..16 is also delegated (harness domain guard).
TAP_INLINE uint64_t c_tail(uint64_t version, uint64_t program_len,
                           uint64_t prog0, uint64_t prog1, uint64_t is_p2sh,
                           uint64_t discourage_witness) {
  if (version > 16u || version == 0u) return tap_pack(TAP_DELEGATED, 0u);
  // interpreter.cpp:1957 -- native v1-32 is the earlier arm.
  if (version == 1u && program_len == 32u && is_p2sh == 0u) {
    return tap_pack(TAP_DELEGATED, 0u);
  }
  // interpreter.cpp:2000-2001 -- P2A, before the policy flag.
  if (is_p2sh == 0u && version == 1u && program_len == 2u &&
      (prog0 & 0xffu) == 0x4eu && (prog1 & 0xffu) == 0x73u) {
    return tap_pack(TAP_OK, 0u);
  }
  // interpreter.cpp:2002-2008
  if (discourage_witness != 0u) {
    return tap_pack(TAP_FAIL, TAP_ERR_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM);
  }
  return tap_pack(TAP_OK, 0u);
}

extern "C" uint64_t cell_control_size(uint64_t size) {
  return c_control_size(size);
}

extern "C" uint64_t cell_leaf_version(uint64_t control0,
                                      uint64_t discourage_taproot) {
  return c_leaf_version(control0, discourage_taproot);
}

extern "C" uint64_t cell_tail(uint64_t version, uint64_t program_len,
                              uint64_t prog0, uint64_t prog1, uint64_t is_p2sh,
                              uint64_t discourage_witness) {
  return c_tail(version, program_len, prog0, prog1, is_p2sh,
                discourage_witness);
}
