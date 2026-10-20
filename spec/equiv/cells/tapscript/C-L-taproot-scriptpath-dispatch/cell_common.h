#ifndef CELLS_TAPSCRIPT_SCRIPTPATH_COMMON_H
#define CELLS_TAPSCRIPT_SCRIPTPATH_COMMON_H
#include <cstdint>

#define TAP_INLINE static inline __attribute__((always_inline))

TAP_INLINE uint64_t tap_pack(uint32_t result, uint32_t error) {
  return (uint64_t)(result & 3u) | ((uint64_t)(error & 0x3fu) << 2);
}

// Harness result codes (not engine semantics).
//   0 = failure, error field is the Core ScriptError ordinal
//   1 = success
//   2 = tapscript arm selected (0xc0 leaf version); execution is SCR-153/155
//   3 = shape delegated to another arm of VerifyWitnessProgram
enum { TAP_FAIL = 0, TAP_OK = 1, TAP_TAPSCRIPT = 2, TAP_DELEGATED = 3 };

// interpreter.h:244-247
enum {
  TAP_CONTROL_BASE_SIZE = 33,
  TAP_CONTROL_NODE_SIZE = 32,
  TAP_CONTROL_MAX_SIZE = 33 + 128 * 32,  // 4129
  TAP_LEAF_MASK = 0xfe,
  TAP_LEAF_TAPSCRIPT = 0xc0
};

// contract/error_enum.md
enum {
  TAP_ERR_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM = 34,
  TAP_ERR_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION = 35,
  TAP_ERR_TAPROOT_WRONG_CONTROL_SIZE = 48
};

#endif
