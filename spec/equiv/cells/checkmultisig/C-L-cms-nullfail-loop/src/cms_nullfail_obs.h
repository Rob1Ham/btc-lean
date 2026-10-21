#ifndef CMS_NULLFAIL_OBS_H
#define CMS_NULLFAIL_OBS_H
// Cell-local packed observable for the SCR-110 CHECKMULTISIG NULLFAIL cell.
//
// This is *harness*, not engine code: it turns the cleanup scan's trace into
// one uint64_t so a gate that fires on the wrong stack item, at the wrong
// position, with the wrong ikey2, or not at all cannot hide behind a common
// (result, error) pair.  Both legs include this header; the Cryptol oracle
// (saw/model.cry) re-implements the same layout independently, so a wrong
// packer in both legs is still caught by SAW.
//
// Layout:
//   bits  0..1   result       (0 error, 1 continuation/ok, 3 out-of-domain)
//   bits  2..7   error ordinal (contract/error_kind.h)
//   bits  8..11  cleanup pops actually performed (0..6)
//   bits 12..15  fire position, 1-based (0 = the NULLFAIL gate never fired)
//   bits 16..18  ikey2 *before* the gate test at the fire position (7 = none)
//   bits 19..20  length bucket of the item at the fire position
//                (0 empty, 1 non-empty, 2 = no fire)
//   bits 21..24  stack depth after the pops that were performed (0..7)
//   bits 25..26  dummy length bucket entering the NULLDUMMY gate (0/1)
//   bits 27..28  pushed boolean (0 vchFalse, 1 vchTrue, 2 = no push/error)
//   bit  29      final stack depth (1 = the pushed boolean, 0 = no push)
//   bit  30      fSuccess entering the cleanup
//   bits 31..63  reserved, zero
//
// The engine-observable part is bits 0..7; the rest is proof instrumentation,
// exactly as in the family's other *_pack helpers (see ../_shared/cms_obs.h).
// The canonical test stack of this cell has no items below the dummy (that
// surviving-prefix shape is the tail cell's cell, with NULLFAIL off).
#include <cstdint>

// contract/error_kind.h ordinals used by this cell.
#define NF_OK 0
#define NF_SIG_NULLFAIL 32
#define NF_SIG_NULLDUMMY 28
#define NF_INVALID_STACK_OPERATION 18

static inline uint64_t cms_nf_pack(uint32_t res, uint32_t err,
                                   uint32_t popped, uint32_t firePos,
                                   uint32_t ikey2Fire, uint32_t fireLen,
                                   uint32_t depthAfter, uint32_t dummyLen,
                                   uint32_t pushed, uint32_t finalDepth,
                                   uint32_t fsuccess) {
  uint64_t r = 0;
  r |= (uint64_t)(res & 3u);
  r |= (uint64_t)(err & 0x3fu) << 2;
  r |= (uint64_t)(popped & 0xfu) << 8;
  r |= (uint64_t)(firePos & 0xfu) << 12;
  r |= (uint64_t)(ikey2Fire & 7u) << 16;
  r |= (uint64_t)(fireLen & 3u) << 19;
  r |= (uint64_t)(depthAfter & 0xfu) << 21;
  r |= (uint64_t)(dummyLen & 3u) << 25;
  r |= (uint64_t)(pushed & 3u) << 27;
  r |= (uint64_t)(finalDepth & 1u) << 29;
  r |= (uint64_t)(fsuccess & 1u) << 30;
  return r;
}

#endif
