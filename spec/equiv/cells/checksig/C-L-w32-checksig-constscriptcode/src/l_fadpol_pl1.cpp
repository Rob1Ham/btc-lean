#include <cstdint>
#define LN 6
#define PL 1
// L: spec/core/Bitcoin/Interpreter/Defs.lean:720-733 evalChecksigPreTapscript
//    (if sv = .base then findAndDelete; found>0 and constScriptCode => sigFindAndDelete).
static inline __attribute__((always_inline)) uint32_t bat(const uint8_t* s, uint32_t i) {
  if (i >= LN) return 0u;
  if (i == 0u) return s[0];
  if (i == 1u) return s[1];
  if (i == 2u) return s[2];
  if (i == 3u) return s[3];
  if (i == 4u) return s[4];
  if (i == 5u) return s[5];
  return 0u;
}

// L: spec/core/Bitcoin/SigHash/Ops.lean:50-78 getOpAt (source-slice
// transliteration; returns (op, total length) and rejects truncated pushes).
static inline __attribute__((always_inline)) bool getop(const uint8_t* s, uint32_t i, uint32_t& op, uint32_t& next) {
  if (i >= LN) return false;
  const uint32_t v = bat(s, i); op = v;
  if (v <= 0x4bu) { if ((uint64_t)i + 1u + v <= LN) { next = i + 1u + v; return true; } return false; }
  if (v == 0x4cu) { if (i + 1u >= LN) return false; const uint32_t l = bat(s, i + 1u);
    if ((uint64_t)i + 2u + l <= LN) { next = i + 2u + l; return true; } return false; }
  if (v == 0x4du) { if (i + 2u >= LN) return false; const uint32_t l = bat(s, i + 1u) | (bat(s, i + 2u) << 8);
    if ((uint64_t)i + 3u + l <= LN) { next = i + 3u + l; return true; } return false; }
  if (v == 0x4eu) { if (i + 4u >= LN) return false;
    const uint64_t l = (uint64_t)bat(s, i + 1u) | ((uint64_t)bat(s, i + 2u) << 8) | ((uint64_t)bat(s, i + 3u) << 16) | ((uint64_t)bat(s, i + 4u) << 24);
    if ((uint64_t)i + 5u + l <= LN) { next = (uint32_t)(i + 5u + l); return true; } return false; }
  next = i + 1u; return true;
}
// BN-byte observable sink (cell harness, not engine code).
struct Out { uint8_t b[6]; uint32_t n; };
static inline __attribute__((always_inline)) void put(Out& o, uint8_t v) {
  if (o.n == 0u) o.b[0] = v;
  if (o.n == 1u) o.b[1] = v;
  if (o.n == 2u) o.b[2] = v;
  if (o.n == 3u) o.b[3] = v;
  if (o.n == 4u) o.b[4] = v;
  if (o.n == 5u) o.b[5] = v;
  o.n += 1u;
}
static inline __attribute__((always_inline)) void copy_range(const uint8_t* s, Out& o, uint32_t from, uint32_t to) {
  if (from + 0u < to) put(o, (uint8_t)bat(s, from + 0u));
  if (from + 1u < to) put(o, (uint8_t)bat(s, from + 1u));
  if (from + 2u < to) put(o, (uint8_t)bat(s, from + 2u));
  if (from + 3u < to) put(o, (uint8_t)bat(s, from + 3u));
  if (from + 4u < to) put(o, (uint8_t)bat(s, from + 4u));
  if (from + 5u < to) put(o, (uint8_t)bat(s, from + 5u));
}
static inline __attribute__((always_inline)) bool match(const uint8_t* s, uint32_t i, const uint8_t* nd) {
  if ((uint64_t)i + 1u > LN) return false;
  bool ok = true;
  if ((uint8_t)bat(s, i + 0u) != nd[0]) ok = false;
  return ok;
}
#define STEP() do { if (i < LN) { if (match(s,i,nd)) { i += PL; ++found; } else { uint32_t op=0, nx=0; if (!getop(s,i,op,nx)) { copy_range(s,o,i,LN); i=LN; } else { copy_range(s,o,i,nx); i=nx; } } } } while (0)
extern "C" uint64_t cell_fadpol_pl1(uint8_t s0, uint8_t s1, uint8_t s2, uint8_t s3, uint8_t s4, uint8_t s5, uint8_t n0, uint8_t sv, uint8_t constsc) {
  const uint8_t s[LN] = {s0,s1,s2,s3,s4,s5};
  const uint8_t nd[PL] = {n0};
  Out o; o.n = 0; o.b[0] = 0; o.b[1] = 0; o.b[2] = 0; o.b[3] = 0; o.b[4] = 0; o.b[5] = 0;
  uint32_t i = 0, found = 0, err = 0;
  if (sv == 0) {
    STEP();
    STEP();
    STEP();
    STEP();
    STEP();
    STEP();
    STEP();
    copy_range(s, o, i, LN);
    if (found > 0 && constsc != 0) err = 54;
  } else {
    copy_range(s, o, 0, LN);
  }
  uint64_t r = (uint64_t)(err & 63u) | ((uint64_t)(found & 15u) << 6) | ((uint64_t)(o.n & 15u) << 10);
  r |= (uint64_t)o.b[0] << 14;
  r |= (uint64_t)o.b[1] << 22;
  r |= (uint64_t)o.b[2] << 30;
  r |= (uint64_t)o.b[3] << 38;
  r |= (uint64_t)o.b[4] << 46;
  r |= (uint64_t)o.b[5] << 54;
  return r;
}
