#ifndef E32_COMMON_H
#define E32_COMMON_H
// Wave-32 CHECKMULTISIG cell harness (SCR-114..117).
//
// Shared, bounded, loop-free helper layer for the C and L legs of the
// CHECKMULTISIG cells.  Nothing here is engine code: it is the cell ABI
// (element encoding, stack accessor, packed observable).
//
// Element encoding (<= 5 payload bytes, enough to exercise the CScriptNum
// 4-byte width limit):
//   bits  0..7   length (0..5)
//   bits  8..47  payload bytes 0..4 (little-endian wire order)
// This is injective for len <= 5, so a leg that reads an element reads the
// same bytes Core/Lean read at the same stack position.
//
// Stack accessor: the CHECKMULTISIG argument layout is
//   [ dummy, sig_0 .. sig_{nSigs-1}, nSigs, key_0 .. key_{nKeys-1}, nKeys ]
// with nKeys on top.  Only the nKeys element (top, k = 1) and the nSigs
// element (k = nKeys + 2, Core stacktop(-nKeys-2)) carry values in this
// cell domain; every other element is a one-byte zero.  `e32_top` is the
// cell's model of that stack.  A leg that computes the wrong read depth
// gets the filler element, so a depth bug is observable.
#include <cstdint>
#include "error_kind.h"

#define E32INLINE static inline __attribute__((always_inline))

E32INLINE uint32_t e32_len(uint64_t enc) { return (uint32_t)(enc & 0xffu); }
E32INLINE uint32_t e32_byte(uint64_t enc, uint32_t k) {
  return (uint32_t)((enc >> (8u + 8u * k)) & 0xffu);
}

// Build an element from a length and up to five payload bytes.
E32INLINE uint64_t e32_elem(uint32_t len, uint32_t b0, uint32_t b1,
                            uint32_t b2, uint32_t b3, uint32_t b4) {
  return ((uint64_t)(len & 0xffu)) |
         ((uint64_t)(b0 & 0xffu) << 8) |
         ((uint64_t)(b1 & 0xffu) << 16) |
         ((uint64_t)(b2 & 0xffu) << 24) |
         ((uint64_t)(b3 & 0xffu) << 32) |
         ((uint64_t)(b4 & 0xffu) << 40);
}

// One-byte zero filler: the value of every stack slot the row does not read.
E32INLINE uint64_t e32_filler() { return (uint64_t)1u << 8; }

// CScriptNum-shaped decode used ONLY by the harness accessor to locate the
// nSigs element (Core stacktop(-nKeys-2)); the engine legs decode nKeys
// themselves and must agree on the position for the read to hit `sigs_enc`.
E32INLINE bool e32_decode_harness(uint64_t e, int64_t& out) {
  const uint32_t len = e32_len(e);
  if (len > 4) return false;
  if (len == 0) { out = 0; return true; }
  uint64_t v = 0;
  if (len >= 1) v |= (uint64_t)e32_byte(e, 0);
  if (len >= 2) v |= (uint64_t)e32_byte(e, 1) << 8;
  if (len >= 3) v |= (uint64_t)e32_byte(e, 2) << 16;
  if (len >= 4) v |= (uint64_t)e32_byte(e, 3) << 24;
  if ((e32_byte(e, len - 1) & 0x80u) != 0)
    out = -(int64_t)(v & ~((uint64_t)0x80u << (8u * (len - 1))));
  else
    out = (int64_t)v;
  return true;
}

// Element at stacktop(-k) for the CMS argument layout.
E32INLINE uint64_t e32_top(uint32_t k, uint32_t n, uint64_t keys_enc,
                           uint64_t sigs_enc) {
  if (k > n) return e32_filler();
  if (k == 1) return keys_enc;
  int64_t nk = 0;  // initialised so no `undef` reaches the phi at the join
  if (e32_decode_harness(keys_enc, nk) && nk >= 0 &&
      k == (uint32_t)nk + 2u)
    return sigs_enc;
  return e32_filler();
}

// Packed observable: result (2) | error ordinal (6) | four 8-bit fields.
// On a failure the four fields are zero, mirroring ABI v2 (on failure only
// result + error_kind are observable).
E32INLINE uint64_t e32_out(uint32_t res, uint32_t err, uint32_t f1,
                           uint32_t f2, uint32_t f3, uint32_t f4) {
  return ((uint64_t)(res & 1u)) |
         ((uint64_t)(err & 0x3fu) << 2) |
         ((uint64_t)(f1 & 0xffu) << 8) |
         ((uint64_t)(f2 & 0xffu) << 16) |
         ((uint64_t)(f3 & 0xffu) << 24) |
         ((uint64_t)(f4 & 0xffu) << 32);
}

E32INLINE uint64_t e32_err(uint32_t err) { return e32_out(0, err, 0, 0, 0, 0); }

// ---------------------------------------------------------------------------
// Loop cell (SCR-116/117): bounded element and flag word.
// ---------------------------------------------------------------------------

// 40 bytes is enough for a DER signature with a 32-byte S value (the
// CheckLowS arm), which is the largest element any encoding check reads in
// this bounded domain.  Only the bytes the validators index are ever read.
struct E32Elem { uint32_t len; uint8_t b[40]; };

E32INLINE void e32_zero_elem(E32Elem& e) {
  e.len = 0;
  for (uint32_t i = 0; i < 40u; ++i) e.b[i] = 0;
}

E32INLINE void e32_copy_elem(E32Elem& d, const E32Elem& s) {
  d.len = s.len;
  for (uint32_t i = 0; i < 40u; ++i) d.b[i] = s.b[i];
}

// Flags word used by the loop cell.
//   bit 0 SCRIPT_VERIFY_DERSIG
//   bit 1 SCRIPT_VERIFY_STRICTENC   (policy strictEnc in the twin)
//   bit 2 SCRIPT_VERIFY_LOW_S       (policy lowS in the twin)
//   bit 3 SCRIPT_VERIFY_WITNESS_PUBKEYTYPE (policy in the twin)
//   bit 4 sigversion 1 = WITNESS_V0, 0 = BASE
//   bit 5 OP_CHECKMULTISIGVERIFY wire (0xaf) instead of 0xae
#define E32_F_DERSIG       (1u << 0)
#define E32_F_STRICTENC    (1u << 1)
#define E32_F_LOW_S        (1u << 2)
#define E32_F_WITPUBKEY    (1u << 3)
#define E32_F_WITNESS_V0   (1u << 4)
#define E32_F_VERIFY_WIRE  (1u << 5)

// Cell checker: a concrete deterministic stand-in for the ECDSA seam.  This
// cell proves loop order / encoding precedence, NOT crypto: ordering is made
// observable by using one shared deterministic predicate in both legs
// instead of an uninterpreted external call (Alive2 does not correlate
// external calls by argument; see findings/wave32 report).
E32INLINE bool e32_check_pair(const E32Elem& sig, const E32Elem& pk,
                              uint32_t salt) {
  return (((sig.len * 31u) + (sig.b[0] * 7u) + (pk.len * 13u) +
           (pk.b[0] * 3u) + salt) & 7u) == 0u;
}

// Signature element kinds, selected by (position + salt) % 5:
//   0 empty                        -> encoding pass, checker sees empty sig
//   1 minimal DER, hashtype 0x01   -> encoding pass
//   2 short/invalid DER            -> SIG_DER
//   3 minimal DER, 32-byte high S  -> SIG_HIGH_S under LOW_S
//   4 minimal DER, hashtype 0x00   -> SIG_HASHTYPE under STRICTENC
E32INLINE void e32_sig_elem(uint32_t idx, uint32_t salt, E32Elem& e) {
  e32_zero_elem(e);
  const uint32_t kind = (idx + salt) % 5u;
  if (kind == 0u) { e.len = 0; }
  else if (kind == 1u) {
    e.len = 9;
    e.b[0] = 0x30; e.b[1] = 0x06; e.b[2] = 0x02; e.b[3] = 0x01;
    e.b[4] = 0x01; e.b[5] = 0x02; e.b[6] = 0x01; e.b[7] = 0x01;
    e.b[8] = 0x01;
  } else if (kind == 2u) {
    e.len = 5;
    e.b[0] = 0x30; e.b[1] = 0x06; e.b[2] = 0x02; e.b[3] = 0x01;
    e.b[4] = 0x01;
  } else if (kind == 3u) {
    e.len = 40;
    e.b[0] = 0x30; e.b[1] = 0x25; e.b[2] = 0x02; e.b[3] = 0x01;
    e.b[4] = 0x01; e.b[5] = 0x02; e.b[6] = 0x20; e.b[7] = 0x7F;
    for (uint32_t i = 0; i < 31u; ++i) e.b[8u + i] = 0xFF;
    e.b[39] = 0x01;
  } else {
    e.len = 9;
    e.b[0] = 0x30; e.b[1] = 0x06; e.b[2] = 0x02; e.b[3] = 0x01;
    e.b[4] = 0x01; e.b[5] = 0x02; e.b[6] = 0x01; e.b[7] = 0x01;
    e.b[8] = 0x00;
  }
}

// Pubkey element kinds, selected by (position + salt) % 3:
//   0 33-byte compressed (0x02)   -> valid; compressed
//   1 65-byte uncompressed (0x04) -> valid; not compressed (WITNESS_PUBKEYTYPE)
//   2 1-byte bad prefix           -> PUBKEYTYPE under STRICTENC
E32INLINE void e32_key_elem(uint32_t idx, uint32_t salt, E32Elem& e) {
  e32_zero_elem(e);
  const uint32_t kind = (idx + salt) % 3u;
  if (kind == 0u) { e.len = 33; e.b[0] = 0x02; }
  else if (kind == 1u) { e.len = 65; e.b[0] = 0x04; }
  else { e.len = 1; e.b[0] = 0x05; }
}

// CHECKMULTISIG stack shape (bottom 0 .. top depth-1), all on the base
// witness/script stack:
//   [ dummy(empty), sig_0..sig_{ns-1}, nSigs, key_0..key_{nk-1}, nKeys ]
// nKeys and nSigs elements are one-byte scriptnums, so the decoded value is
// the count (0..20) and the opCount prelude cannot fail in this domain.
E32INLINE uint64_t e32_depth(uint32_t nk, uint32_t ns) {
  return (uint64_t)nk + (uint64_t)ns + 3u;
}

E32INLINE void e32_stack_at(uint64_t nk, uint64_t ns, uint64_t salt,
                            uint64_t i, E32Elem& e) {
  e32_zero_elem(e);
  if (i == 0u) return;                          // dummy: empty
  if (i >= 1u && i <= ns) {                     // sigs
    e32_sig_elem((uint32_t)(i - 1u), (uint32_t)salt, e);
    return;
  }
  if (i == ns + 1u) { e.len = 1; e.b[0] = (uint8_t)ns; return; }  // nSigs
  if (i >= ns + 2u && i <= ns + 1u + nk) {       // keys
    e32_key_elem((uint32_t)(i - (ns + 2u)), (uint32_t)salt, e);
    return;
  }
  e.len = 1; e.b[0] = (uint8_t)nk;              // nKeys (top)
}

E32INLINE void e32_stack_top(uint64_t nk, uint64_t ns, uint64_t salt,
                             uint64_t k, E32Elem& e) {
  const uint64_t depth = e32_depth((uint32_t)nk, (uint32_t)ns);
  if (k > depth) { e32_zero_elem(e); return; }
  e32_stack_at(nk, ns, salt, depth - k, e);
}

// Loop-cell observable:
// result(2) | err(6) | fSuccess(1) | early(1) | nSigsLeft(6) |
// nKeysLeft(6) | isig(6) | ikey(6)
E32INLINE uint64_t e32_loop_out(uint32_t res, uint32_t err, uint32_t fSuccess,
                                uint32_t early, uint32_t ns, uint32_t nk,
                                uint32_t isig, uint32_t ikey) {
  return ((uint64_t)(res & 3u)) |
         ((uint64_t)(err & 0x3fu) << 2) |
         ((uint64_t)(fSuccess & 1u) << 8) |
         ((uint64_t)(early & 1u) << 9) |
         ((uint64_t)(ns & 0x3fu) << 10) |
         ((uint64_t)(nk & 0x3fu) << 16) |
         ((uint64_t)(isig & 0x3fu) << 22) |
         ((uint64_t)(ikey & 0x3fu) << 28);
}

#endif
