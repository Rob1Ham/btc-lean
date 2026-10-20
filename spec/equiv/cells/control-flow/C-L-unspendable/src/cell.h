#ifndef CELL_UNSPENDABLE_H
#define CELL_UNSPENDABLE_H
#include <cstdint>
// Cell harness only.  The script is observed as (size, first byte); no array
// is materialised because IsUnspendable reads only those two facts.
#define BINLINE static inline __attribute__((always_inline))
#endif
