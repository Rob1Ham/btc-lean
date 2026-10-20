#include <cstdint>
#define LN 4
#define PL 1
// C: interpreter.cpp:239-265 FindAndDelete (scriptCode source slice).
static inline __attribute__((always_inline)) uint32_t bat(const uint8_t* s, uint32_t i) {
  if (i >= LN) return 0u;
  if (i == 0u) return s[0];
  if (i == 1u) return s[1];
  if (i == 2u) return s[2];
  if (i == 3u) return s[3];
  return 0u;
}

// C: interpreter.cpp:313-363 CScript::GetOp (source-slice transliteration,
// bounds expressed on LN; BN packing header is cell harness).
static inline __attribute__((always_inline)) bool getop(const uint8_t* s, uint32_t i, uint32_t& op, uint32_t& next) {
  if (i >= LN) return false;
  op = bat(s, i);
  if (op <= 0x4eu) {
    uint32_t size = 0; uint32_t p = i + 1u;
    if (op < 0x4cu) size = op;
    else if (op == 0x4cu) { if ((int64_t)LN - (int64_t)p < 1) return false; size = bat(s, p); p += 1u; }
    else if (op == 0x4du) { if ((int64_t)LN - (int64_t)p < 2) return false; size = bat(s, p) | (bat(s, p + 1u) << 8); p += 2u; }
    else { if ((int64_t)LN - (int64_t)p < 4) return false; size = bat(s, p) | (bat(s, p + 1u) << 8) | (bat(s, p + 2u) << 16) | (bat(s, p + 3u) << 24); p += 4u; }
    if ((uint64_t)p + (uint64_t)size > (uint64_t)LN) return false;
    next = p + size; return true;
  }
  next = i + 1u; return true;
}
// BN-byte observable sink (cell harness, not engine code).
struct Out { uint8_t b[4]; uint32_t n; };
static inline __attribute__((always_inline)) void put(Out& o, uint8_t v) {
  if (o.n == 0u) o.b[0] = v;
  if (o.n == 1u) o.b[1] = v;
  if (o.n == 2u) o.b[2] = v;
  if (o.n == 3u) o.b[3] = v;
  o.n += 1u;
}
static inline __attribute__((always_inline)) void copy_range(const uint8_t* s, Out& o, uint32_t from, uint32_t to) {
  if (from + 0u < to) put(o, (uint8_t)bat(s, from + 0u));
  if (from + 1u < to) put(o, (uint8_t)bat(s, from + 1u));
  if (from + 2u < to) put(o, (uint8_t)bat(s, from + 2u));
  if (from + 3u < to) put(o, (uint8_t)bat(s, from + 3u));
}
static inline __attribute__((always_inline)) bool match(const uint8_t* s, uint32_t i, const uint8_t* nd) {
  if ((uint64_t)i + 1u > LN) return false;
  bool ok = true;
  if ((uint8_t)bat(s, i + 0u) != nd[0]) ok = false;
  return ok;
}
// Core tries the pattern at the current boundary first, then takes one GetOp
// step.  A GetOp failure copies the verbatim tail.
#define STEP() do { if (i < LN) { if (match(s,i,nd)) { i += PL; ++found; } else { uint32_t op=0, nx=0; if (!getop(s,i,op,nx)) { copy_range(s,o,i,LN); i=LN; } else { copy_range(s,o,i,nx); i=nx; } } } } while (0)
extern "C" uint64_t cell_fad_pl1(uint8_t s0, uint8_t s1, uint8_t s2, uint8_t s3, uint8_t n0) {
  const uint8_t s[LN] = {s0,s1,s2,s3};
  const uint8_t nd[PL] = {n0};
  Out o; o.n = 0; o.b[0] = 0; o.b[1] = 0; o.b[2] = 0; o.b[3] = 0;
  uint32_t i = 0, found = 0;
  STEP();
  STEP();
  STEP();
  STEP();
  STEP();
  copy_range(s, o, i, LN);
  return (uint64_t)(found & 15u) | ((uint64_t)(o.n & 15u) << 4) | ((uint64_t)o.b[0] << 8) | ((uint64_t)o.b[1] << 16) | ((uint64_t)o.b[2] << 24) | ((uint64_t)o.b[3] << 32);
}
