#include "limits_common.h"
// C leg — source-excerpt slice of Bitcoin Core cce32b168.
//
//   src/script/interpreter.cpp:427-428
//       // sigversion cannot be TAPROOT here...
//       assert(sigversion == SigVersion::BASE || ... WITNESS_V0 || ... TAPSCRIPT);
//   src/script/interpreter.cpp:438-440
//       if ((sigversion == SigVersion::BASE || sigversion == SigVersion::WITNESS_V0)
//           && script.size() > MAX_SCRIPT_SIZE) {
//           return set_error(serror, SCRIPT_ERR_SCRIPT_SIZE);
//       }
//   src/script/script.h:41   inline constexpr int MAX_SCRIPT_SIZE{10'000};
//
// The guard is evaluated ONCE at EvalScript entry, before the opcode loop
// (interpreter.cpp:449).  This cell models exactly that guard: script_len is
// the whole-script byte length (`script.size()`) and sv is the sigversion.
// The payload on the admitted branch is the length that the loop would parse,
// truncated to the 24-bit cell payload; it is a state projection, not a
// verdict.  The cell harness rejects sigversion codes outside
// {BASE, WITNESS_V0, TAPSCRIPT} as out of domain (result 2).

extern "C" uint64_t cell_script_size(uint64_t script_len, uint8_t sv) {
  if (!lim_valid_sigversion(sv)) return lim_bad_input();

  if ((sv == LIM_SV_BASE || sv == LIM_SV_WITNESS_V0) &&
      script_len > LIM_MAX_SCRIPT_SIZE) {
    return lim_pack(0, EQUIV_ERR_SCRIPT_SIZE, 0);
  }
  // Guard admitted the script to the opcode loop.  result=1 here means
  // "admitted", not "VerifyScript passed"; the row is the guard.
  return lim_pack(1, EQUIV_ERR_OK,
                  static_cast<uint32_t>(script_len & 0x00ffffffu));
}
