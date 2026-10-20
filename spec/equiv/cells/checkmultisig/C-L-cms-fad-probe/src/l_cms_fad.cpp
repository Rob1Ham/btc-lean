// L leg -- SCR-115: all nSigsCount signatures are FindAndDelete'd from the
// scriptCode before any checker call, in BASE only.
//
// REVIEWED TRANSLITERATION of Bitcoin.Interpreter.Defs.checkMultiSig's
// FindAndDelete block and of the cmsLoop call that follows it
// (spec/core/Bitcoin/Interpreter/Defs.lean:1088-1118):
//
//   let scriptCode0 := ctx.bytes.extract st.codeSep ctx.bytes.size
//   let fd : Except ExecError ByteArray :=
//     (List.range nSigs).foldl (fun acc k =>
//       match acc with
//       | .error e => .error e
//       | .ok sc =>
//         if ctx.sv = .base then
//           let (found, sc') := findAndDelete sc
//             (pushBytesWire (st.stack[nKeys + k + 2]!))
//           if 0 < found ∧ ctx.pol.constScriptCode then .error .sigFindAndDelete
//           else .ok sc'
//         else .ok sc) (.ok scriptCode0)
//   match fd with
//   | .error e => .error e
//   | .ok scriptCode =>
//     cmsLoop ctx.flags ctx.pol ctx.sv ctx.chk ctx.ed scriptCode
//       st.stack (nKeys + nSigs + 1) nKeys nSigs (nKeys + 3) 2
//
// Key points the cell checks: `List.range nSigs` means every signature is
// folded, in index order, *before* `cmsLoop` is entered; `ctx.sv = .base` is
// the only branch that mutates the scriptCode; the `0 < found ∧
// constScriptCode` latch aborts with .sigFindandDelete (54); and the value
// handed to `cmsLoop` -- hence to every checkECDSASignature call -- is the
// fold's output, not the original.
//
// SCOPE / SAME-SYMBOL PREMISE: `findAndDelete` is an abstract seam symbol
// shared by both legs (Alive2 quantifies over it; SAW links one stub).  Its
// byte-walking algorithm is not proved here (SCR-098/INV-056); this cell
// proves the fold order, BASE gate, found/const latch and the scriptCode seen
// by each check.  Hence scr_row_coverage: partial.
//
// Bound: nSigs <= 2, two loop bodies (the row allows up to 20); nKeys = nSigs.
#include <cstdint>
#include "cms_obs.h"
#include "cms_seam.h"

#define SIG_ENC(k) ((1u << 16) | (0x40u + (k)))
#define KEY_ENC(j) ((1u << 16) | (0x40u + (j)))
#define PUSH_ENC(k) ((1u << 16) | (0x01u << 8) | (0x11u + (k)))

// One `List.range nSigs` fold step.  The fold is total over k but stops
// mutating once non-BASE (Lean's `else .ok sc`) or once the error latch fired.
#define CMS_FAD_STEP(k)                                                    \
  if (!errored && (uint32_t)(k) < nsigs) {                                 \
    if (base) {                                                            \
      const uint64_t r = btc_equiv_find_and_delete(cur, PUSH_ENC(k));       \
      const uint32_t found = (uint32_t)(r & 0xffffffffu);                   \
      cur = (uint32_t)(r >> 32);                                            \
      applied += 1u;                                                        \
      if (found > 0u) {                                                     \
        foundpos += 1u;                                                     \
        if (constflag != 0u) {                                              \
          err = 54u;                                                        \
          errored = true;                                                   \
        }                                                                   \
      }                                                                     \
    }                                                                       \
  }

// One cmsLoop body, used here as the probe: the checker receives `cur`, the
// fold output.  The `nSigs > 0` guard and the early exit are cmsLoop's.
#define CMS_PROBE_STEP(t)                                                  \
  if (!errored && fs && nSigs > 0 && fuelLeft > 0) {                        \
    if (calls == 0u) { c0_eq_final = (cur == finalSc); }                    \
    if (calls == 1u) { c1_eq_c0 = (cur == c0Sc); }                          \
    if (calls == 0u) { c0Sc = cur; }                                        \
    calls += 1u;                                                            \
    const bool ok = btc_equiv_check_sig(SIG_ENC(sigId), KEY_ENC(t), cur,   \
                                         sigversion) != 0;                  \
    if (ok) { sigId += 1; nSigs -= 1; }                                     \
    nKeys -= 1;                                                             \
    fuelLeft -= 1;                                                          \
    if (nSigs > nKeys) fs = false;                                          \
  }

extern "C" uint64_t cell_cms_fad(uint32_t nsigs, uint32_t sigversion,
                                 uint32_t constflag, uint32_t sc) {
  if (nsigs > 2u || sigversion > 1u || constflag > 1u) return 0xFFFFu;

  const bool base = (sigversion == 0u);
  uint32_t cur = sc;                       // Lean's scriptCode0 / fold acc
  uint32_t applied = 0u, foundpos = 0u, err = 0u, calls = 0u;
  uint32_t c0Sc = 0u;
  uint32_t c0_eq_final = 0u, c1_eq_c0 = 0u;
  bool errored = false, fs = true;
  int64_t nSigs = (int64_t)nsigs, nKeys = (int64_t)nsigs;
  int64_t sigId = 0;
  int64_t fuelLeft = (int64_t)(nsigs + nsigs + 1u);   // nKeys+nSigs+1

  CMS_FAD_STEP(0u)
  CMS_FAD_STEP(1u)
  const uint32_t finalSc = cur;

  CMS_PROBE_STEP(0u)
  CMS_PROBE_STEP(1u)

  uint32_t res;
  if (errored) {
    res = 3u;
  } else {
    res = fs ? 1u : 0u;
  }
  return cms_pack_fad(res, err, calls, applied, finalSc, c0_eq_final, c1_eq_c0,
                      foundpos, base ? 1u : 0u);
}
