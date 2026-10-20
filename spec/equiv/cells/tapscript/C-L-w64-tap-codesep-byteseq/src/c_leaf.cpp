// C leg: line-cited source slice of Bitcoin Core cce32b16874e8.
//
//   script/interpreter.cpp:431-446
//       CScript::const_iterator pc = script.begin();
//       CScript::const_iterator pbegincodehash = script.begin();
//       uint32_t opcode_pos = 0;
//       execdata.m_codeseparator_pos = 0xFFFFFFFFUL;
//       for (; pc < pend; ++opcode_pos) { ... }
//   script/interpreter.cpp:1058-1066
//       case OP_CODESEPARATOR:
//         pbegincodehash = pc;                    // pc is *after* GetOp
//         execdata.m_codeseparator_pos = opcode_pos;
//   script/script.cpp:313-363  CScript::GetScriptOp (the pc advance)
//
// Bounded domain: scripts of exactly eight bytes, every byte symbolic.  All
// GetScriptOp forms are modelled (direct push, PUSHDATA1/2/4, 1-byte
// opcode); truncated pushes fail the walk exactly as in Core.  `mask` bit
// k is the caller-supplied fExec value at the k-th *parsed* opcode (the
// vfExec derivation is a premise, as in the row's other counter cells).
#include <cstdint>

#define LN 6
static constexpr uint32_t INIT = 0xFFFFFFFFu;  // interpreter.cpp:445

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

// CScript::GetScriptOp translated verbatim from script.cpp:313-363.
// Returns (opcode, next offset); `next` is Core's post-GetOp `pc`.
static inline __attribute__((always_inline)) bool
getop(const uint8_t* s, uint32_t i, uint32_t& op, uint32_t& next) {
  if (i >= LN) return false;
  const uint32_t v = bat(s, i);
  op = v;
  if (v <= 0x4eu) {  // OP_PUSHDATA4
    uint32_t size = 0, p = i + 1u;
    if (v < 0x4cu) {
      size = v;
    } else if (v == 0x4cu) {
      if ((int64_t)LN - (int64_t)p < 1) return false;
      size = bat(s, p); p += 1u;
    } else if (v == 0x4du) {
      if ((int64_t)LN - (int64_t)p < 2) return false;
      size = bat(s, p) | (bat(s, p + 1u) << 8); p += 2u;
    } else {
      if ((int64_t)LN - (int64_t)p < 4) return false;
      size = bat(s, p) | (bat(s, p + 1u) << 8) |
             (bat(s, p + 2u) << 16) | (bat(s, p + 3u) << 24);
      p += 4u;
    }
    if ((uint64_t)p + (uint64_t)size > (uint64_t)LN) return false;
    next = p + size;
    return true;
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
  uint32_t pc = 0;                 // interpreter.cpp:431
  uint32_t opcodeIndex = 0;        // interpreter.cpp:444 opcode_pos
  uint32_t codeSep = 0;            // interpreter.cpp:432 pbegincodehash
  uint32_t codeSepPos = INIT;      // interpreter.cpp:445
  uint32_t bad = 0;

#define C_STEP()                                                     \
  do {                                                               \
    if (!bad && pc < LN) {                                           \
      uint32_t op = 0, nx = 0;                                       \
      if (!getop(s, pc, op, nx)) {                                   \
        bad = 1;                 /* SCRIPT_ERR_BAD_OPCODE */        \
      } else {                                                       \
        if (((mask >> opcodeIndex) & 1u) != 0u && op == 0xabu) {     \
          codeSep = nx;          /* interpreter.cpp:1064 */          \
          codeSepPos = opcodeIndex;  /* interpreter.cpp:1065 */      \
        }                                                            \
        pc = nx;                                                     \
        opcodeIndex += 1u;       /* for-update ++opcode_pos */       \
      }                                                              \
    }                                                                \
  } while (0)
  C_STEP(); C_STEP(); C_STEP();
  C_STEP(); C_STEP(); C_STEP();
#undef C_STEP

  // Strict separation: the legacy byte offset (codeSep) is never the
  // opcode index (codeSepPos).  With no executed separator the legacy
  // default is offset 0 while the tapscript field stays at the sentinel.
  const uint32_t sepOk = (codeSepPos == INIT) ? (codeSep == 0u) : (codeSep > codeSepPos);
  return (uint64_t)codeSepPos
       | ((uint64_t)(codeSep & 0xfu) << 32)
       | ((uint64_t)(opcodeIndex & 0xfu) << 36)
       | ((uint64_t)sepOk << 40)
       | ((uint64_t)bad << 41)
       | ((uint64_t)(pc & 0xfu) << 42);
}
