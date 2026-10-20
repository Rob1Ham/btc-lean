#ifndef CELL_CASTTOBOOL_H
#define CELL_CASTTOBOOL_H
#include <cstdint>
// Cell harness only: the bounded element representation is (len, b0, b1)
// with len in {0,1,2}; it is not engine code.
#define BINLINE static inline __attribute__((always_inline))
#endif
