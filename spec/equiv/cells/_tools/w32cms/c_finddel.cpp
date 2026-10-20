// Wave-32 CHECKMULTISIG FindAndDelete cell -- C leg (SCR-115).
//
// Line-cited slice of Bitcoin Core v32.99
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66:
//   src/script/script.cpp:239-265   CScript::FindAndDelete
//   src/script/script.cpp GetScriptOp (opcode-boundary walk)
// and the OP_CHECKMULTISIG pre-check (interpreter.cpp:1152-1160):
//
//   for (int k = 0; k < nSigsCount; k++) {
//       valtype& vchSig = stacktop(-isig-k);
//       if (sigversion == SigVersion::BASE)
//           scriptCode.FindAndDelete(CScript(vchSig));
//   }
//
// The three exported functions expose (nFound, resulting length, resulting
// bytes) of one FindAndDelete application; cell_fd_chain applies the loop
// above to nSigs in {0,1,2} signature pushes before any checker call.
//
// Bounded domain: script length <= 8, needle length <= 4.
#include "e32_common.h"

#define FD_MAX_SCRIPT 8u
#define FD_MAX_NEEDLE 4u
#define FD_OOD 0xffffffffffffffffull

struct FDBytes { uint32_t n; uint8_t b[FD_MAX_SCRIPT]; };

E32INLINE void fd_unpack(FDBytes& s, uint64_t payload, uint64_t len) {
  s.n = (uint32_t)len;
  for (uint32_t i = 0; i < FD_MAX_SCRIPT; ++i) {
    s.b[i] = (uint8_t)((payload >> (8u * i)) & 0xffu);
  }
}

E32INLINE uint64_t fd_pack(const FDBytes& s) {
  uint64_t r = 0;
  for (uint32_t i = 0; i < FD_MAX_SCRIPT; ++i) {
    r |= (uint64_t)s.b[i] << (8u * i);
  }
  return r;
}

E32INLINE bool fd_match(const uint8_t* s, const uint8_t* b, uint32_t len) {
  for (uint32_t i = 0; i < FD_MAX_NEEDLE; ++i) {
    if (i < len && s[i] != b[i]) return false;
  }
  return true;
}

// GetScriptOp: advance pc past one opcode (and its push payload); false on a
// truncated push.  pc is advanced as Core does even when it returns false.
E32INLINE bool core_get_op(const FDBytes& s, uint32_t& pc) {
  if (pc >= s.n) return false;
  const uint32_t op = s.b[pc];
  pc += 1u;
  uint32_t size = 0;
  if (op <= 0x4bu) {
    size = op;
  } else if (op == 0x4cu) {
    if (s.n - pc < 1u) return false;
    size = s.b[pc];
    pc += 1u;
  } else if (op == 0x4du) {
    if (s.n - pc < 2u) return false;
    size = (uint32_t)s.b[pc] | ((uint32_t)s.b[pc + 1u] << 8);
    pc += 2u;
  } else if (op == 0x4eu) {
    if (s.n - pc < 4u) return false;
    size = (uint32_t)s.b[pc] | ((uint32_t)s.b[pc + 1u] << 8) |
           ((uint32_t)s.b[pc + 2u] << 16) | ((uint32_t)s.b[pc + 3u] << 24);
    pc += 4u;
  } else {
    return true;
  }
  if (size > s.n - pc) return false;
  pc += size;
  return true;
}

E32INLINE uint32_t core_find_delete(const FDBytes& script, const uint8_t* b,
                                    uint32_t blen, FDBytes& out) {
  uint32_t found = 0;
  if (blen == 0u) { out = script; return 0u; }
  FDBytes r; r.n = 0;
  for (uint32_t i = 0; i < FD_MAX_SCRIPT; ++i) r.b[i] = 0;
  uint32_t pc = 0, pc2 = 0;
  do {
    for (uint32_t i = pc2; i < pc && r.n < FD_MAX_SCRIPT; ++i) {
      r.b[r.n++] = script.b[i];
    }
    while (script.n - pc >= blen && fd_match(&script.b[pc], b, blen)) {
      pc += blen;
      found += 1u;
    }
    pc2 = pc;
  } while (core_get_op(script, pc));
  if (found > 0u) {
    for (uint32_t i = pc2; i < script.n && r.n < FD_MAX_SCRIPT; ++i) {
      r.b[r.n++] = script.b[i];
    }
    out = r;
  } else {
    out = script;
  }
  return found;
}

// (nFound, len, bytes) for one application.
E32INLINE uint64_t core_fd_found(uint64_t script, uint64_t slen, uint64_t needle,
                                 uint64_t nlen) {
  if (slen > FD_MAX_SCRIPT || nlen > FD_MAX_NEEDLE) return FD_OOD;
  FDBytes s, out; fd_unpack(s, script, slen);
  uint8_t b[FD_MAX_NEEDLE];
  for (uint32_t i = 0; i < FD_MAX_NEEDLE; ++i)
    b[i] = (uint8_t)((needle >> (8u * i)) & 0xffu);
  return (uint64_t)core_find_delete(s, b, (uint32_t)nlen, out);
}
E32INLINE uint64_t core_fd_len(uint64_t script, uint64_t slen, uint64_t needle,
                               uint64_t nlen) {
  if (slen > FD_MAX_SCRIPT || nlen > FD_MAX_NEEDLE) return FD_OOD;
  FDBytes s, out; fd_unpack(s, script, slen);
  uint8_t b[FD_MAX_NEEDLE];
  for (uint32_t i = 0; i < FD_MAX_NEEDLE; ++i)
    b[i] = (uint8_t)((needle >> (8u * i)) & 0xffu);
  (void)core_find_delete(s, b, (uint32_t)nlen, out);
  return (uint64_t)out.n;
}
E32INLINE uint64_t core_fd_bytes(uint64_t script, uint64_t slen, uint64_t needle,
                                 uint64_t nlen) {
  if (slen > FD_MAX_SCRIPT || nlen > FD_MAX_NEEDLE) return FD_OOD;
  FDBytes s, out; fd_unpack(s, script, slen);
  uint8_t b[FD_MAX_NEEDLE];
  for (uint32_t i = 0; i < FD_MAX_NEEDLE; ++i)
    b[i] = (uint8_t)((needle >> (8u * i)) & 0xffu);
  (void)core_find_delete(s, b, (uint32_t)nlen, out);
  return fd_pack(out);
}

// CScript(vchSig) for a <=4-byte element is a direct push: [len, bytes...].
E32INLINE uint64_t core_fd_chain(uint64_t nSigs, uint64_t script, uint64_t slen,
                                 uint64_t sig0, uint64_t sig0len,
                                 uint64_t sig1, uint64_t sig1len) {
  if (slen > FD_MAX_SCRIPT || nSigs > 2u || sig0len > FD_MAX_NEEDLE ||
      sig1len > FD_MAX_NEEDLE)
    return FD_OOD;
  FDBytes sc; fd_unpack(sc, script, slen);
  for (uint32_t k = 0; k < 2u; ++k) {
    if (k >= nSigs) break;
    const uint64_t sig = (k == 0u) ? sig0 : sig1;
    const uint32_t len = (uint32_t)((k == 0u) ? sig0len : sig1len);
    FDBytes push; push.n = len + 1u;
    push.b[0] = (uint8_t)len;                       // push opcode (len <= 4)
    for (uint32_t i = 0; i < FD_MAX_NEEDLE; ++i)
      push.b[1u + i] = (uint8_t)((sig >> (8u * i)) & 0xffu);
    FDBytes o;
    (void)core_find_delete(sc, push.b, push.n, o);
    sc = o;
  }
  return ((uint64_t)sc.n << 56) | (fd_pack(sc) & 0x00ffffffffffffffull);
}

// checkMultiSig pre-loop, nSigs symbolic in [0,20], base-only.  Signature
// pushes are position-distinct one-byte elements (sig byte = 37*k + salt);
// the script itself is symbolic.  sv = 0 is BASE (delete), else no-op.
E32INLINE uint64_t core_fd_chain_n(uint64_t nSigs, uint64_t script,
                                   uint64_t slen, uint64_t salt, uint64_t sv) {
  if (slen > FD_MAX_SCRIPT || nSigs > 20u) return FD_OOD;
  FDBytes sc; fd_unpack(sc, script, slen);
  for (uint32_t k = 0; k < 20u; ++k) {
    if (k >= nSigs) break;
    if (sv != 0u) continue;                       // base sigversion only
    const uint32_t len = 1u;
    uint8_t push[FD_MAX_NEEDLE + 1u];  // push opcode + up to FD_MAX_NEEDLE bytes
    push[0] = (uint8_t)len;
    push[1] = (uint8_t)((37u * k + (uint32_t)salt) & 0xffu);
    FDBytes o;
    (void)core_find_delete(sc, push, 2u, o);
    sc = o;
  }
  return ((uint64_t)sc.n << 56) | (fd_pack(sc) & 0x00ffffffffffffffull);
}

extern "C" uint64_t cell_fd_chain_n(uint64_t ns, uint64_t s, uint64_t sl,
                                    uint64_t salt, uint64_t sv) {
  return core_fd_chain_n(ns, s, sl, salt, sv);
}

extern "C" uint64_t cell_fd_found(uint64_t s, uint64_t sl, uint64_t n,
                                  uint64_t nl) { return core_fd_found(s, sl, n, nl); }
extern "C" uint64_t cell_fd_len(uint64_t s, uint64_t sl, uint64_t n,
                                uint64_t nl) { return core_fd_len(s, sl, n, nl); }
extern "C" uint64_t cell_fd_bytes(uint64_t s, uint64_t sl, uint64_t n,
                                  uint64_t nl) { return core_fd_bytes(s, sl, n, nl); }
extern "C" uint64_t cell_fd_chain(uint64_t ns, uint64_t s, uint64_t sl,
                                  uint64_t s0, uint64_t s0l, uint64_t s1,
                                  uint64_t s1l) {
  return core_fd_chain(ns, s, sl, s0, s0l, s1, s1l);
}
