#include "cell.h"
// C leg: source-excerpt slice of Bitcoin Core cce32b168
// src/script/interpreter.cpp:613-645 (case OP_IF / OP_NOTIF).
//
//   case OP_IF:
//   case OP_NOTIF:
//   {
//       bool fValue = false;
//       if (fExec)
//       {
//           if (stack.size() < 1)
//               return set_error(serror, SCRIPT_ERR_INVALID_STACK_OPERATION);
//           valtype& vch = stacktop(-1);
//           if (sigversion == SigVersion::TAPSCRIPT) {
//               if (vch.size() > 1 || (vch.size() == 1 && vch[0] != 1)) {
//                   return set_error(serror, SCRIPT_ERR_TAPSCRIPT_MINIMALIF);
//               }
//           }
//           if (sigversion == SigVersion::WITNESS_V0 && (flags & SCRIPT_VERIFY_MINIMALIF)) {
//               if (vch.size() > 1)
//                   return set_error(serror, SCRIPT_ERR_MINIMALIF);
//               if (vch.size() == 1 && vch[0] != 1)
//                   return set_error(serror, SCRIPT_ERR_MINIMALIF);
//           }
//           fValue = CastToBool(vch);
//           if (opcode == OP_NOTIF)
//               fValue = !fValue;
//           popstack(stack);
//       }
//       vfExec.push_back(fValue);
//   }
//   break;
//
// plus CastToBool (interpreter.cpp:46-59) inlined over the bounded element.
// fExec / sigversion / the MINIMALIF flag are leaf inputs; the harness maps
// sv 0=base, 1=witnessV0, 2=tapscript.  There is one exported function per
// element length in {0,1,2} so the CastToBool loop has a constant trip count
// and both tools see a loop-free leaf (the cell's element domain).

BINLINE bool core_cast_to_bool(const uint8_t* vch, unsigned int n) {
  for (unsigned int i = 0; i < n; i++) {
    if (vch[i] != 0) {
      if (i == n - 1 && vch[i] == 0x80)
        return false;
      return true;
    }
  }
  return false;
}

// len is a template constant: the same Core loop with a fixed vch.size().
template <unsigned int LEN>
BINLINE bool core_cast_len(const uint8_t* vch) {
  return core_cast_to_bool(vch, LEN);
}

template <unsigned int LEN>
BINLINE uint32_t core_if_notif(ISt& st, uint32_t isNotif, uint32_t fExec,
                               uint32_t sv, uint32_t minimalif,
                               const uint8_t* vch) {
  bool fValue = false;
  if (fExec) {
    if (st.depth < 1)
      return 18;                                      // SCRIPT_ERR_INVALID_STACK_OPERATION
    if (sv == 2) {                                    // SigVersion::TAPSCRIPT
      if (LEN > 1 || (LEN == 1 && vch[0] != 1))
        return 51;                                    // SCRIPT_ERR_TAPSCRIPT_MINIMALIF
    }
    if (sv == 1 && minimalif) {                       // WITNESS_V0 + SCRIPT_VERIFY_MINIMALIF
      if (LEN > 1)
        return 31;                                    // SCRIPT_ERR_MINIMALIF
      if (LEN == 1 && vch[0] != 1)
        return 31;
    }
    fValue = core_cast_len<LEN>(vch);                 // interpreter.cpp:46-59
    if (isNotif)
      fValue = !fValue;
    st.depth -= 1;                                    // popstack(stack)
  }
  st.vf0 = fValue ? 1u : 0u;                          // vfExec.push_back(fValue)
  st.vf_n += 1;
  return 0;
}

extern "C" uint64_t cell_if_len0(uint32_t isNotif, uint32_t fexec, uint32_t sv,
                                 uint32_t minimalif, uint32_t depth) {
  const uint8_t vch[1] = {0};
  ISt st{depth, 0, 0, 0, 0, 0};
  const uint32_t e = core_if_notif<0>(st, isNotif, fexec, sv, minimalif, vch);
  return if_pack(e, st);
}

extern "C" uint64_t cell_if_len1(uint32_t isNotif, uint32_t fexec, uint32_t sv,
                                 uint32_t minimalif, uint32_t depth, uint8_t b0) {
  const uint8_t vch[1] = {b0};
  ISt st{depth, 1, b0, 0, 0, 0};
  const uint32_t e = core_if_notif<1>(st, isNotif, fexec, sv, minimalif, vch);
  return if_pack(e, st);
}

extern "C" uint64_t cell_if_len2(uint32_t isNotif, uint32_t fexec, uint32_t sv,
                                 uint32_t minimalif, uint32_t depth, uint8_t b0,
                                 uint8_t b1) {
  const uint8_t vch[2] = {b0, b1};
  ISt st{depth, 2, b0, b1, 0, 0};
  const uint32_t e = core_if_notif<2>(st, isNotif, fexec, sv, minimalif, vch);
  return if_pack(e, st);
}
