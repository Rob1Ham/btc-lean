// Wave-32 CHECKMULTISIG FindAndDelete cell -- L leg (SCR-115).
//
// REVIEWED TRANSLITERATION of Bitcoin.Interpreter.Defs.findAndDelete and its
// helpers (spec/core/Bitcoin/Interpreter/Defs.lean:545-600):
//   findAndDeleteMatches : greedy run of needle matches at pc
//   findAndDeleteAux     : walk at opcode boundaries, accumulate [pc2, pc)
//   findAndDelete        : (found, acc ++ extract lastPc2 end)
// plus the checkMultiSig pre-loop (Defs.lean:1090-1100) that applies one
// FindAndDelete per signature push when sv = base.
//
// Written from the Lean recursion (fuel-driven, accumulator list) rather than
// from the C iterator formulation.  Bounded: script <= 8 bytes, needle <= 4.
#include "e32_common.h"

#define FD_MAX_SCRIPT 8u
#define FD_MAX_NEEDLE 4u
#define FD_OOD 0xffffffffffffffffull

struct LBytes { uint32_t n; uint8_t b[FD_MAX_SCRIPT]; };

E32INLINE void l_unpack(LBytes& s, uint64_t payload, uint64_t len) {
  s.n = (uint32_t)len;
  for (uint32_t i = 0; i < FD_MAX_SCRIPT; ++i)
    s.b[i] = (uint8_t)((payload >> (8u * i)) & 0xffu);
}

E32INLINE uint64_t l_pack(const LBytes& s) {
  uint64_t r = 0;
  for (uint32_t i = 0; i < FD_MAX_SCRIPT; ++i) r |= (uint64_t)s.b[i] << (8u * i);
  return r;
}

E32INLINE bool l_eq_at(const LBytes& s, const uint8_t* b, uint32_t blen,
                       uint32_t pc) {
  for (uint32_t i = 0; i < FD_MAX_NEEDLE; ++i)
    if (i < blen && s.b[pc + i] != b[i]) return false;
  return true;
}

// findAndDeleteMatches script b pc 0 fuel -> (pc', count)
E32INLINE uint32_t l_fd_matches(const LBytes& s, const uint8_t* b, uint32_t blen,
                                uint32_t pc, uint32_t& count) {
  uint32_t fuel = s.n + 1u;
  while (fuel > 0u) {
    fuel -= 1u;
    if (s.n < pc + blen) break;
    if (!l_eq_at(s, b, blen, pc)) break;
    pc += blen;
    count += 1u;
  }
  return pc;
}

// getOp script pc -> some next | none
E32INLINE bool l_get_op(const LBytes& s, uint32_t pc, uint32_t& next) {
  if (pc >= s.n) return false;
  const uint32_t op = s.b[pc];
  uint32_t q = pc + 1u;
  uint32_t size = 0;
  if (op <= 0x4bu) {
    size = op;
  } else if (op == 0x4cu) {
    if (s.n - q < 1u) return false;
    size = s.b[q]; q += 1u;
  } else if (op == 0x4du) {
    if (s.n - q < 2u) return false;
    size = (uint32_t)s.b[q] | ((uint32_t)s.b[q + 1u] << 8); q += 2u;
  } else if (op == 0x4eu) {
    if (s.n - q < 4u) return false;
    size = (uint32_t)s.b[q] | ((uint32_t)s.b[q + 1u] << 8) |
           ((uint32_t)s.b[q + 2u] << 16) | ((uint32_t)s.b[q + 3u] << 24);
    q += 4u;
  } else {
    next = q;
    return true;
  }
  if (size > s.n - q) return false;
  next = q + size;
  return true;
}

// findAndDeleteAux: acc ++ [pc2, pc); greedy; recurse from next with pc2 = pc'
E32INLINE void l_fd_aux(const LBytes& s, const uint8_t* b, uint32_t blen,
                        uint32_t& pc, uint32_t& pc2, LBytes& acc,
                        uint32_t& found) {
  uint32_t fuel = s.n + 1u;
  while (fuel > 0u) {
    fuel -= 1u;
    for (uint32_t i = pc2; i < pc && acc.n < FD_MAX_SCRIPT; ++i)
      acc.b[acc.n++] = s.b[i];
    uint32_t n2 = 0;
    const uint32_t pcNew = l_fd_matches(s, b, blen, pc, n2);
    found += n2;
    if (s.n <= pcNew) { pc = pcNew; pc2 = pcNew; return; }
    uint32_t next = 0;
    if (!l_get_op(s, pcNew, next)) { pc = pcNew; pc2 = pcNew; return; }
    pc2 = pcNew;
    pc = next;
  }
}

E32INLINE uint32_t l_find_delete(const LBytes& s, const uint8_t* b,
                                 uint32_t blen, LBytes& out) {
  if (blen == 0u) { out = s; return 0u; }
  LBytes acc; acc.n = 0;
  for (uint32_t i = 0; i < FD_MAX_SCRIPT; ++i) acc.b[i] = 0;
  uint32_t pc = 0, pc2 = 0, found = 0;
  l_fd_aux(s, b, blen, pc, pc2, acc, found);
  if (found > 0u) {
    for (uint32_t i = pc2; i < s.n && acc.n < FD_MAX_SCRIPT; ++i)
      acc.b[acc.n++] = s.b[i];
    out = acc;
  } else {
    out = s;
  }
  return found;
}

E32INLINE uint64_t l_fd_found(uint64_t script, uint64_t slen, uint64_t needle,
                              uint64_t nlen) {
  if (slen > FD_MAX_SCRIPT || nlen > FD_MAX_NEEDLE) return FD_OOD;
  LBytes s, out; l_unpack(s, script, slen);
  uint8_t b[FD_MAX_NEEDLE];
  for (uint32_t i = 0; i < FD_MAX_NEEDLE; ++i)
    b[i] = (uint8_t)((needle >> (8u * i)) & 0xffu);
  return (uint64_t)l_find_delete(s, b, (uint32_t)nlen, out);
}
E32INLINE uint64_t l_fd_len(uint64_t script, uint64_t slen, uint64_t needle,
                            uint64_t nlen) {
  if (slen > FD_MAX_SCRIPT || nlen > FD_MAX_NEEDLE) return FD_OOD;
  LBytes s, out; l_unpack(s, script, slen);
  uint8_t b[FD_MAX_NEEDLE];
  for (uint32_t i = 0; i < FD_MAX_NEEDLE; ++i)
    b[i] = (uint8_t)((needle >> (8u * i)) & 0xffu);
  (void)l_find_delete(s, b, (uint32_t)nlen, out);
  return (uint64_t)out.n;
}
E32INLINE uint64_t l_fd_bytes(uint64_t script, uint64_t slen, uint64_t needle,
                              uint64_t nlen) {
  if (slen > FD_MAX_SCRIPT || nlen > FD_MAX_NEEDLE) return FD_OOD;
  LBytes s, out; l_unpack(s, script, slen);
  uint8_t b[FD_MAX_NEEDLE];
  for (uint32_t i = 0; i < FD_MAX_NEEDLE; ++i)
    b[i] = (uint8_t)((needle >> (8u * i)) & 0xffu);
  (void)l_find_delete(s, b, (uint32_t)nlen, out);
  return l_pack(out);
}

E32INLINE uint64_t l_fd_chain(uint64_t nSigs, uint64_t script, uint64_t slen,
                              uint64_t sig0, uint64_t sig0len, uint64_t sig1,
                              uint64_t sig1len) {
  if (slen > FD_MAX_SCRIPT || nSigs > 2u || sig0len > FD_MAX_NEEDLE ||
      sig1len > FD_MAX_NEEDLE)
    return FD_OOD;
  LBytes sc; l_unpack(sc, script, slen);
  for (uint32_t k = 0; k < 2u; ++k) {
    if (k >= nSigs) break;
    const uint64_t sig = (k == 0u) ? sig0 : sig1;
    const uint32_t len = (uint32_t)((k == 0u) ? sig0len : sig1len);
    LBytes push; push.n = len + 1u;
    push.b[0] = (uint8_t)len;
    for (uint32_t i = 0; i < FD_MAX_NEEDLE; ++i)
      push.b[1u + i] = (uint8_t)((sig >> (8u * i)) & 0xffu);
    LBytes o;
    (void)l_find_delete(sc, push.b, push.n, o);
    sc = o;
  }
  return ((uint64_t)sc.n << 56) | (l_pack(sc) & 0x00ffffffffffffffull);
}

// checkMultiSig pre-loop (Defs.lean:1090-1100): (List.range nSigs).foldl,
// deleting pushBytesWire sig only when sv = base.
E32INLINE uint64_t l_fd_chain_n(uint64_t nSigs, uint64_t script, uint64_t slen,
                                uint64_t salt, uint64_t sv) {
  if (slen > FD_MAX_SCRIPT || nSigs > 20u) return FD_OOD;
  LBytes sc; l_unpack(sc, script, slen);
  for (uint32_t k = 0; k < 20u; ++k) {
    if (k >= nSigs) break;
    if (sv != 0u) continue;
    uint8_t push[FD_MAX_NEEDLE + 1u];  // push opcode + up to FD_MAX_NEEDLE bytes
    push[0] = 0x01u;                              // pushBytesWire of a 1-byte sig
    push[1] = (uint8_t)((37u * k + (uint32_t)salt) & 0xffu);
    LBytes o;
    (void)l_find_delete(sc, push, 2u, o);
    sc = o;
  }
  return ((uint64_t)sc.n << 56) | (l_pack(sc) & 0x00ffffffffffffffull);
}

extern "C" uint64_t cell_fd_chain_n(uint64_t ns, uint64_t s, uint64_t sl,
                                    uint64_t salt, uint64_t sv) {
  return l_fd_chain_n(ns, s, sl, salt, sv);
}

extern "C" uint64_t cell_fd_found(uint64_t s, uint64_t sl, uint64_t n,
                                  uint64_t nl) { return l_fd_found(s, sl, n, nl); }
extern "C" uint64_t cell_fd_len(uint64_t s, uint64_t sl, uint64_t n,
                                uint64_t nl) { return l_fd_len(s, sl, n, nl); }
extern "C" uint64_t cell_fd_bytes(uint64_t s, uint64_t sl, uint64_t n,
                                  uint64_t nl) { return l_fd_bytes(s, sl, n, nl); }
extern "C" uint64_t cell_fd_chain(uint64_t ns, uint64_t s, uint64_t sl,
                                  uint64_t s0, uint64_t s0l, uint64_t s1,
                                  uint64_t s1l) {
  return l_fd_chain(ns, s, sl, s0, s0l, s1, s1l);
}
