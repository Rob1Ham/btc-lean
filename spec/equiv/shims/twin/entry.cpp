// spec/equiv/shims/twin/entry.cpp — L leg skeleton.
//
// STATUS: STUB. The TWIN role replaces the body below with a call into the
// Lean-derived twin (generated C/C++ or reviewed transliteration). This file
// deliberately contains no script logic and returns a fixed internal-error
// result so that E0 has a compiling, linkable third leg; it must NOT be used
// in any green cell until replaced.
//
// Contract: ../contract/ABI.md v2 + ../contract/tape.md.  Both symbols are
// exported: `equiv_entry` (normative, mandatory error_kind) and `entry`
// (7-argument convenience wrapper).  Result codes 0/1/2/3.
//
// Build (skeleton):  g++ -std=c++20 -c shims/twin/entry.cpp -I contract -o twin.o
// (the filled version may need additional twin object files; see ../README.md)

#include "error_kind.h"

#include <cstdint>

static_assert(EQUIV_ABI_VERSION == 2, "unexpected ABI version");

extern "C" int equiv_entry(
    const uint8_t* tx_bytes,
    uint64_t tx_len,
    const uint8_t* spk,
    uint64_t spk_len,
    int64_t amount,
    uint32_t input_index,
    uint64_t flags,
    equiv_error_kind* error_kind)
{
    (void)tx_bytes;
    (void)tx_len;
    (void)spk;
    (void)spk_len;
    (void)amount;
    (void)input_index;
    (void)flags;

    // TODO(TWIN): decode the tape exactly as tape.md §2–§5 requires, call the
    // twin engine, and map its failure result to equiv_error_kind. Domain
    // violations return 2; unexpected exceptions/aborts return 3.
    if (error_kind != nullptr) *error_kind = EQUIV_ERR_UNKNOWN_ERROR;
    return 3;
}

extern "C" int entry(
    const uint8_t* tx_bytes,
    uint64_t tx_len,
    const uint8_t* spk,
    uint64_t spk_len,
    int64_t amount,
    uint32_t input_index,
    uint64_t flags)
{
    equiv_error_kind kind = EQUIV_ERR_UNKNOWN_ERROR;
    return equiv_entry(tx_bytes, tx_len, spk, spk_len, amount, input_index, flags, &kind);
}
