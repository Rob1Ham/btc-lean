// L leg -- reviewed transliteration of the Lean model at 4d62a97e.
//
// Cited source (btc-lean-public @ 4d62a97e551082a69b13f495365bff0a903b0c99):
//   spec/core/Bitcoin/Interpreter/Defs.lean:285-297  checkSequenceDef
//       (only the tail -- mask + comparisons -- is used here; the version and
//        disable-flag prefix is proved in locktime/C-L-csv-op, SCR-128/129)
//   spec/core/Bitcoin/DataLaws/Laws.lean:240        seqRelative
//   spec/core/Bitcoin/DataLaws/Laws.lean:250-252    seqIsTimeBased
//   spec/core/Bitcoin/DataLaws/Laws.lean:427-428    seqTimeGranularity_pow (512 = 2^9)
//   spec/core/Bitcoin/DataLaws/Laws.lean:431-434    seqTimeOk
//   spec/core/Bitcoin/DataLaws/Laws.lean:440-444    seqTimeLock_last_invalid
//
// src/lean_excerpt.md holds the Lean text this file mirrors.
#include <cstdint>

namespace lean_slice {

// ---- Defs.lean:80-85 / Laws.lean:54-56 ---------------------------------
inline constexpr uint32_t SEQUENCE_LOCKTIME_TYPE_FLAG = 0x00400000u;  // 1 << 22
inline constexpr uint32_t SEQUENCE_LOCKTIME_MASK      = 0x0000ffffu;

// ---- DataLaws/Laws.lean:240 -------------------------------------------
//   def seqRelative (s : UInt32) : Nat := (s &&& SEQUENCE_LOCKTIME_MASK).toNat
inline uint64_t seq_relative(uint32_t s)
{
    return static_cast<uint64_t>(s & SEQUENCE_LOCKTIME_MASK);
}

// ---- DataLaws/Laws.lean:250-252 ---------------------------------------
//   def seqIsTimeBased (s : UInt32) : Bool :=
//     decide ((s &&& SEQUENCE_LOCKTIME_TYPE_FLAG) ≠ 0)
inline bool seq_is_time_based(uint32_t s)
{
    return (s & SEQUENCE_LOCKTIME_TYPE_FLAG) != 0u;
}

// ---- DataLaws/Laws.lean:431-434 ---------------------------------------
//   def seqTimeOk (mtpParent : Nat) (s : UInt32) (mtpBlock : Nat) : Bool :=
//     decide (mtpBlock ≥ mtpParent + seqRelative s * 512)
inline bool seq_time_ok(uint64_t mtp_parent, uint32_t s, uint64_t mtp_block)
{
    return mtp_block >= mtp_parent + seq_relative(s) * 512u;
}

}  // namespace lean_slice

extern "C" int32_t cell_csv_masked(int64_t operand, uint32_t tx_sequence)
{
    using namespace lean_slice;
    // Defs.lean:291-296: mask := TYPE_FLAG ||| MASK; txMasked := txSeq &&& mask;
    // nMasked := n.toNat &&& mask; type agreement; then !(nMasked > txMasked).
    const uint32_t mask = SEQUENCE_LOCKTIME_TYPE_FLAG | SEQUENCE_LOCKTIME_MASK;
    const uint32_t tx_masked = tx_sequence & mask;
    const uint32_t n_masked = static_cast<uint32_t>(operand) & mask;

    const bool same_type =
        (tx_masked <  SEQUENCE_LOCKTIME_TYPE_FLAG && n_masked <  SEQUENCE_LOCKTIME_TYPE_FLAG) ||
        (tx_masked >= SEQUENCE_LOCKTIME_TYPE_FLAG && n_masked >= SEQUENCE_LOCKTIME_TYPE_FLAG);
    if (!same_type) return 22;
    if (n_masked > tx_masked) return 22;
    return 0;
}

// Cell harness (identical construction on both legs): the probe compares the
// transliterated verdict with itself under a toggle of the bits that the BIP68
// mask discards.
extern "C" int32_t cell_csv_mask_probe(int64_t operand, uint32_t tx_sequence, uint32_t junk)
{
    using namespace lean_slice;
    const uint32_t JUNK_MASK = 0x7fbf0000u;   // bits 16..21 and 23..30
    const uint32_t d = junk & JUNK_MASK;
    const uint32_t mask = SEQUENCE_LOCKTIME_TYPE_FLAG | SEQUENCE_LOCKTIME_MASK;

    const uint32_t tx_a = tx_sequence & mask;
    const uint32_t n_a = static_cast<uint32_t>(operand) & mask;
    const uint32_t tx_b = (tx_sequence ^ d) & mask;
    const uint32_t n_b = static_cast<uint32_t>(operand ^ (int64_t)d) & mask;

    const bool a =
        ((tx_a <  SEQUENCE_LOCKTIME_TYPE_FLAG && n_a <  SEQUENCE_LOCKTIME_TYPE_FLAG) ||
         (tx_a >= SEQUENCE_LOCKTIME_TYPE_FLAG && n_a >= SEQUENCE_LOCKTIME_TYPE_FLAG)) &&
        !(n_a > tx_a);
    const bool b =
        ((tx_b <  SEQUENCE_LOCKTIME_TYPE_FLAG && n_b <  SEQUENCE_LOCKTIME_TYPE_FLAG) ||
         (tx_b >= SEQUENCE_LOCKTIME_TYPE_FLAG && n_b >= SEQUENCE_LOCKTIME_TYPE_FLAG)) &&
        !(n_b > tx_b);
    return a == b ? 1 : 0;
}

// DataLaws/Laws.lean:427-428 + :240: 512 = 2^9, and the masked payload is
// scaled by exactly 512 seconds.
extern "C" int64_t cell_seq_granularity(uint32_t tx_sequence)
{
    using namespace lean_slice;
    return static_cast<int64_t>(seq_relative(tx_sequence) * 512u);
}

// DataLaws/Laws.lean:250-252 (branch guard) + 431-434 (seqTimeOk).
// The guard mirrors Core's `if (txin.nSequence & TYPE_FLAG)` branch of
// CalculateSequenceLocks (tx_verify.cpp:79-80): a height-based sequence
// contributes nothing to the time lane, leaving nMinTime = -1, which is
// always below an unsigned block MTP.
extern "C" int32_t cell_seq_time_ok(uint32_t mtp_parent, uint32_t tx_sequence, uint32_t mtp_block)
{
    using namespace lean_slice;
    if (!seq_is_time_based(tx_sequence))
        return 1;
    return seq_time_ok(static_cast<uint64_t>(mtp_parent), tx_sequence,
                       static_cast<uint64_t>(mtp_block)) ? 1 : 0;
}
