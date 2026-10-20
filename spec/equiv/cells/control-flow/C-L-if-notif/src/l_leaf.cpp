#include "cell.h"
#include "twin_ops.h"
using namespace twinleaf;
// L leg: a direct transcription of the Lean model of OP_IF / OP_NOTIF,
// spec/core/Bitcoin/Interpreter/Defs.lean:878-891 (which cites
// interpreter.cpp:613-645), with the element length fixed per exported
// function.  It is NOT twin/ops_ir.py's OP_IF handler: that handler omits the
// tapscript MINIMALIF and witness-v0 MINIMALIF arms (Defs.lean:883-887),
// which is filed as a twin gap in the cell notes.  The twin's bounded
// cast_to_bool and the TwinErr -> Core ordinal map come from
// build/twin_ops.h; the state translation is cell harness.

template <unsigned int LEN>
BINLINE uint32_t l_if_notif(ISt& st, uint32_t isNotif, uint32_t fExec,
                            uint32_t sv, uint32_t minimalif,
                            const uint8_t* vch) {
  if (fExec) {                                         // if fExec then
    if (st.depth < 1)
      return (uint32_t)core_ord(TWIN_INVALID_STACK_OPERATION);
    // let vch := topAt st.stack 1
    if (sv == 2 && (LEN > 1 || (LEN == 1 && vch[0] != 1)))
      return (uint32_t)core_ord(TWIN_TAPSCRIPT_MINIMALIF);
    if (sv == 1 && minimalif && (LEN > 1 || (LEN == 1 && vch[0] != 1)))
      return (uint32_t)core_ord(TWIN_MINIMALIF);
    bool fValue = cast_to_bool(vch, LEN);
    if (isNotif)
      fValue = !fValue;
    st.depth -= 1;                                     // stack := st.stack.tail
    st.vf0 = fValue ? 1u : 0u;                         // vf := fValue :: st.vf
    st.vf_n += 1;
  } else {
    st.vf0 = 0;                                        // unexecuted IF pushes false
    st.vf_n += 1;
  }
  return 0;
}

extern "C" uint64_t cell_if_len0(uint32_t isNotif, uint32_t fexec, uint32_t sv,
                                 uint32_t minimalif, uint32_t depth) {
  const uint8_t vch[1] = {0};
  ISt st{depth, 0, 0, 0, 0, 0};
  const uint32_t e = l_if_notif<0>(st, isNotif, fexec, sv, minimalif, vch);
  return if_pack(e, st);
}

extern "C" uint64_t cell_if_len1(uint32_t isNotif, uint32_t fexec, uint32_t sv,
                                 uint32_t minimalif, uint32_t depth, uint8_t b0) {
  const uint8_t vch[1] = {b0};
  ISt st{depth, 1, b0, 0, 0, 0};
  const uint32_t e = l_if_notif<1>(st, isNotif, fexec, sv, minimalif, vch);
  return if_pack(e, st);
}

extern "C" uint64_t cell_if_len2(uint32_t isNotif, uint32_t fexec, uint32_t sv,
                                 uint32_t minimalif, uint32_t depth, uint8_t b0,
                                 uint8_t b1) {
  const uint8_t vch[2] = {b0, b1};
  ISt st{depth, 2, b0, b1, 0, 0};
  const uint32_t e = l_if_notif<2>(st, isNotif, fexec, sv, minimalif, vch);
  return if_pack(e, st);
}
