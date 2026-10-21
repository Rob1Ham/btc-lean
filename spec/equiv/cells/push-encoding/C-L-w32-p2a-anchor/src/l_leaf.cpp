#include <cstdint>

// L leg: line-by-line transcription of the Lean twin's anchor predicate.
//
//   spec/core/Bitcoin/Interpreter/Defs.lean:523-526
//   def isPayToAnchor (version : Nat) (program : ByteArray) : Bool :=
//     version = 1 ∧ program.size = 2 ∧ (program.get! 0).toNat = 0x4e ∧
//       (program.get! 1).toNat = 0x73
//
// NOTE (trust): the imperative twin (twin/runtime.inc) has no anchor helper;
// its VerifyScript returns TWIN_INVALID_UNSUPPORTED for every witness
// program, so there is no generated L function to call.  This leg is a
// direct, reviewed transcription of the four-conjunct Lean definition above
// and is therefore weaker than a call into generated twin code.  The
// transcription is included in the cell certificate.  The C-L binding of
// this predicate into the P2A branch of VerifyWitnessProgram is NOT proved
// here.
static constexpr uint8_t kP2aVersion = 1;
static constexpr uint8_t kP2a0 = 0x4e;
static constexpr uint8_t kP2a1 = 0x73;

static bool lean_is_pay_to_anchor(uint32_t version, const uint8_t* program,
                                  uint32_t plen) {
  return version == kP2aVersion && plen == 2 && program[0] == kP2a0 &&
         program[1] == kP2a1;
}

extern "C" uint64_t cell_p2a(uint8_t version, uint8_t p0, uint8_t p1,
                             uint32_t plen) {
  const uint8_t program[2] = {p0, p1};
  return lean_is_pay_to_anchor(version, program, plen) ? 1u : 0u;
}
