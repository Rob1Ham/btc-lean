#include <cstdint>
#define LN 6
// L: spec/core/Bitcoin/Interpreter/Defs.lean:823-833 (CONST_SCRIPTCODE pre-check);
//    1031-1032 OP_CODESEPARATOR arm (fExec dispatch); 720-726 scriptCode extract.
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
// One EvalScript iteration.  mask bit k is the fExec value at opcode k.
#define STEP(k) do { if (!stop && it < LN) { uint32_t op=0, nx=0; if (!getop(s,it,op,nx)) { err = 16; stop = true; } else { if (op == 0xab && sv == 0 && constsc != 0) { err = 53; stop = true; } else { if (((mask >> k) & 1u) != 0 && op == 0xab) codeSep = nx; it = nx; } } } } while (0)
extern "C" uint64_t cell_codesep(uint8_t s0, uint8_t s1, uint8_t s2, uint8_t s3, uint8_t s4, uint8_t s5, uint8_t mask, uint8_t sv, uint8_t constsc) {
  const uint8_t s[LN] = {s0,s1,s2,s3,s4,s5};
  Out o; o.n = 0; o.b[0] = 0; o.b[1] = 0; o.b[2] = 0; o.b[3] = 0; o.b[4] = 0; o.b[5] = 0;
  uint32_t codeSep = 0, it = 0, err = 0; bool stop = false;
  STEP(0);
  STEP(1);
  STEP(2);
  STEP(3);
  STEP(4);
  STEP(5);
  if (err == 0) copy_range(s, o, codeSep, LN);
  uint64_t r = (uint64_t)(err & 63u) | ((uint64_t)(codeSep & 7u) << 6) | ((uint64_t)(o.n & 7u) << 9);
  r |= (uint64_t)o.b[0] << 12;
  r |= (uint64_t)o.b[1] << 20;
  r |= (uint64_t)o.b[2] << 28;
  r |= (uint64_t)o.b[3] << 36;
  r |= (uint64_t)o.b[4] << 44;
  r |= (uint64_t)o.b[5] << 52;
  return r;
}
