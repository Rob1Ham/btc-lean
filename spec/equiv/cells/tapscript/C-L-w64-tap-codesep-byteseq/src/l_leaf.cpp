// L leg: the Lean model's walk, transcribed from the pinned definitions.
//
//   spec/core/Bitcoin/SigHash/Ops.lean:50-78   getOpAt (op, total length)
//   spec/core/Bitcoin/Interpreter/Defs.lean:421-431 parseWire / WireOp.next
//   spec/core/Bitcoin/Interpreter/Defs.lean:1031-1032
//       stepBody OP_CODESEPARATOR:
//         { st with codeSep := op.next, codeSepPos := st.opcodeIndex }
//   spec/core/Bitcoin/Interpreter/Defs.lean:1145-1150
//       evalFrom: after each parsed opcode, opcodeIndex := opcodeIndex + 1
//   spec/core/Bitcoin/Interpreter/Defs.lean:601-604,1171
//       codeSep : Nat := 0; codeSepPos : UInt32 := 0xffffffff
//
// Same bounded domain as the C leg: exactly eight symbolic script bytes,
// fExec supplied per parsed opcode by `mask`.  The GetOp transliteration
// follows getOpAt's branch structure (not the C leg's), so the Alive2
// C<->L proof checks two independent transcriptions of the same rules.
#include <cstdint>

#define LN 6
static constexpr uint32_t INIT = 0xFFFFFFFFu;

static inline __attribute__((always_inline)) uint32_t
bat(const uint8_t* s, uint32_t i) {
  if (i == 0u) return s[0];
  if (i == 1u) return s[1];
  if (i == 2u) return s[2];
  if (i == 3u) return s[3];
  if (i == 4u) return s[4];
  if (i == 5u) return s[5];
  if (i == 6u) return s[6];
  if (i == 7u) return s[7];
  return 0u;
}

// getOpAt b i = some (op, len); next = i + len.
static inline __attribute__((always_inline)) bool
getop(const uint8_t* s, uint32_t i, uint32_t& op, uint32_t& next) {
  if (i >= LN) return false;
  const uint32_t v = bat(s, i);
  op = v;
  if (v <= 0x4bu) {
    if ((uint64_t)i + 1u + v <= (uint64_t)LN) { next = i + 1u + v; return true; }
    return false;
  }
  if (v == 0x4cu) {
    if (i + 1u >= LN) return false;
    const uint32_t l = bat(s, i + 1u);
    if ((uint64_t)i + 2u + l <= (uint64_t)LN) { next = i + 2u + l; return true; }
    return false;
  }
  if (v == 0x4du) {
    if (i + 2u >= LN) return false;
    const uint32_t l = bat(s, i + 1u) | (bat(s, i + 2u) << 8);
    if ((uint64_t)i + 3u + l <= (uint64_t)LN) { next = i + 3u + l; return true; }
    return false;
  }
  if (v == 0x4eu) {
    if (i + 4u >= LN) return false;
    const uint64_t l = (uint64_t)bat(s, i + 1u)
                     | ((uint64_t)bat(s, i + 2u) << 8)
                     | ((uint64_t)bat(s, i + 3u) << 16)
                     | ((uint64_t)bat(s, i + 4u) << 24);
    if ((uint64_t)i + 5u + l <= (uint64_t)LN) {
      next = (uint32_t)(i + 5u + l);
      return true;
    }
    return false;
  }
  next = i + 1u;
  return true;
}

extern "C" uint64_t cell_codesep_byteseq(
    uint8_t s0, uint8_t s1, uint8_t s2, uint8_t s3,
    uint8_t s4, uint8_t s5,
    uint32_t mask) {
  const uint8_t s[LN] = {(uint8_t)s0, (uint8_t)s1, (uint8_t)s2, (uint8_t)s3,
                         (uint8_t)s4, (uint8_t)s5};
  uint32_t pc = 0;               // parsedEnd
  uint32_t opcodeIndex = 0;      // st.opcodeIndex
  uint32_t codeSep = 0;          // st.codeSep (Nat)
  uint32_t codeSepPos = INIT;    // st.codeSepPos
  uint32_t bad = 0;

#define L_STEP()                                                     \
  do {                                                               \
    if (!bad && pc < LN) {                                           \
      uint32_t op = 0, nx = 0;                                       \
      if (!getop(s, pc, op, nx)) {                                   \
        bad = 1;                 /* GetOp walk stops */              \
      } else {                                                       \
        if (((mask >> opcodeIndex) & 1u) != 0u && op == 0xabu) {     \
          codeSep = nx;          /* stepBody: codeSep := op.next */  \
          codeSepPos = opcodeIndex;  /* : codeSepPos := opcodeIndex */\
        }                                                            \
        pc = nx;                                                     \
        opcodeIndex += 1u;       /* evalFrom: opcodeIndex + 1 */     \
      }                                                              \
    }                                                                \
  } while (0)
  L_STEP(); L_STEP(); L_STEP();
  L_STEP(); L_STEP(); L_STEP();
#undef L_STEP

  // Same invariant as the C leg; the two fields stay distinct.
  const uint32_t sepOk = (codeSepPos == INIT) ? (codeSep == 0u) : (codeSep > codeSepPos);
  return (uint64_t)codeSepPos
       | ((uint64_t)(codeSep & 0xfu) << 32)
       | ((uint64_t)(opcodeIndex & 0xfu) << 36)
       | ((uint64_t)sepOk << 40)
       | ((uint64_t)bad << 41)
       | ((uint64_t)(pc & 0xfu) << 42);
}
