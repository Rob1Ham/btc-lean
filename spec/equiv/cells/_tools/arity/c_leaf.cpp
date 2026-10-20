#include "gate_common.h"
// C leg: the per-case arity guards from Bitcoin Core cce32b168
// src/script/interpreter.cpp.  Each function sets an empty stack; every
// guarded case returns SCRIPT_ERR_INVALID_STACK_OPERATION (18).  The success
// branches of these opcodes are covered by the other E1 cells, not here.
BINLINE uint32_t g1(const BStack& s) { return s.n < 1 ? 18 : 0; }
BINLINE uint32_t g2(const BStack& s) { return s.n < 2 ? 18 : 0; }
BINLINE uint32_t g3(const BStack& s) { return s.n < 3 ? 18 : 0; }
BINLINE uint32_t g4(const BStack& s) { return s.n < 4 ? 18 : 0; }
BINLINE uint32_t g6(const BStack& s) { return s.n < 6 ? 18 : 0; }
#define CELL(name, guard) \
  extern "C" uint64_t name() { BStack s; b_clear(s); return b_pack(0, guard(s), s); }
CELL(cell_2drop, g2)   // interpreter.cpp:888-895
CELL(cell_2dup,  g2)   // interpreter.cpp:897-905
CELL(cell_3dup,  g3)   // interpreter.cpp:907-915
CELL(cell_2over, g4)   // interpreter.cpp:917-925
CELL(cell_2rot,  g6)   // interpreter.cpp:927-935
CELL(cell_2swap, g4)   // interpreter.cpp:937-945
CELL(cell_ifdup, g1)   // interpreter.cpp:949-956
CELL(cell_drop,  g1)   // interpreter.cpp:958-964
CELL(cell_dup,   g1)   // interpreter.cpp:966-972
CELL(cell_nip,   g2)   // interpreter.cpp:974-981
CELL(cell_over,  g2)   // interpreter.cpp:983-990
CELL(cell_pick,  g2)   // interpreter.cpp:992-1004
CELL(cell_roll,  g2)   // interpreter.cpp:1006-1018
CELL(cell_rot,   g3)   // interpreter.cpp:1020-1028
CELL(cell_swap,  g2)   // interpreter.cpp:1030-1036
CELL(cell_tuck,  g2)   // interpreter.cpp:1038-1045
