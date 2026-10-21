#ifndef CELL_CASTTOBOOL_FULL_H
#define CELL_CASTTOBOOL_FULL_H
#include <cstdint>
// Cell harness only: the element representation is (pointer, length) with
// length in the consensus domain 0..520.  It is not engine code.
#define BINLINE static inline __attribute__((always_inline))
#endif
