// cells/_tools/limits — shared, cell-harness-only helpers for the E6
// `limits` family cells (sigop counting: SCR-032..SCR-037).
//
// NOT engine code and NOT part of the trust base.  This header fixes the
// cell ABI used by every limits cell:
//
//   a CScript is passed as a packed 64-bit word plus a byte count.
//   byte i (0-based) is (w >> (8*i)) & 0xff, i.e. little-endian packing of
//   the script bytes.  All eight packed bytes are readable, but only the
//   first LIMITS_MAX_SCRIPT_BYTES = 4 are inside the cell domain.
//
// LIMITS_MAX_SCRIPT_BYTES is the cell domain bound: every bounded function
// returns LIMITS_OUT_OF_DOMAIN for len > 4.  The sentinel is outside every
// Core count (a count over four bytes is at most 80) and is applied
// identically to the C and L legs, so it is a domain guard, not engine
// semantics.  Four bytes is enough to exercise every opcode class, the
// OP_1..OP_16 CHECKMULTISIG lookback, direct/PUSHDATA1/PUSHDATA2 pushes and
// every truncated-push tail that fits; a PUSHDATA4 payload can never fit in
// four bytes, so only its truncation arm is reachable (recorded in the cell
// notes).
//
// The script is unpacked once into eight scalar fields and every byte read
// goes through an explicit index dispatch.  Two alternatives were tried and
// rejected as unsound cell harness: (a) a variable 64-bit shift is undefined
// C++ for i >= 8, and clang's speculative form makes Alive2 report spurious
// poison; (b) a byte array in an alloca lets Alive2 lose the memory contents
// and report a vacuous "correct".  Scalar fields with constant shifts have
// neither problem: the emitted IR is memory-free and poison-free.
#pragma once
#include <cstdint>
#include <cstddef>

#define LIMITS_ABI_SCRIPT_BYTES 8u
#define LIMITS_MAX_SCRIPT_BYTES 4u
#define LIMITS_STEPS 4u
#define LIMITS_OUT_OF_DOMAIN 0xffffffffu

#define CLINLINE static inline __attribute__((always_inline))

struct LimitsScript {
  uint32_t b0, b1, b2, b3, b4, b5, b6, b7;
  uint32_t len;  // byte count, 0..LIMITS_MAX_SCRIPT_BYTES
};

// Harness unpacking of the cell ABI word into the eight scalar fields.
CLINLINE LimitsScript limits_script(uint64_t w, uint32_t len) {
  LimitsScript s;
  s.b0 = static_cast<uint32_t>(w & 0xffull);
  s.b1 = static_cast<uint32_t>((w >> 8) & 0xffull);
  s.b2 = static_cast<uint32_t>((w >> 16) & 0xffull);
  s.b3 = static_cast<uint32_t>((w >> 24) & 0xffull);
  s.b4 = static_cast<uint32_t>((w >> 32) & 0xffull);
  s.b5 = static_cast<uint32_t>((w >> 40) & 0xffull);
  s.b6 = static_cast<uint32_t>((w >> 48) & 0xffull);
  s.b7 = static_cast<uint32_t>((w >> 56) & 0xffull);
  s.len = len;
  return s;
}

// Script byte i.  Out-of-range indices return 0 so the helper is total; every
// engine slice only reads indices below s.len.
CLINLINE uint32_t limits_byte(const LimitsScript& s, uint32_t i) {
  if (i == 0) return s.b0;
  if (i == 1) return s.b1;
  if (i == 2) return s.b2;
  if (i == 3) return s.b3;
  if (i == 4) return s.b4;
  if (i == 5) return s.b5;
  if (i == 6) return s.b6;
  if (i == 7) return s.b7;
  return 0u;
}

// Core opcodetype values used by the sigop counters (src/script/opcodes.h).
enum LimitsCoreOp : uint32_t {
  LOP_0 = 0x00,
  LOP_PUSHDATA1 = 0x4c,
  LOP_PUSHDATA2 = 0x4d,
  LOP_PUSHDATA4 = 0x4e,
  LOP_1NEGATE = 0x4f,
  LOP_RESERVED = 0x50,
  LOP_1 = 0x51,
  LOP_16 = 0x60,
  LOP_CHECKSIG = 0xac,
  LOP_CHECKSIGVERIFY = 0xad,
  LOP_CHECKMULTISIG = 0xae,
  LOP_CHECKMULTISIGVERIFY = 0xaf,
  LOP_INVALIDOPCODE = 0xff,
};

// MAX_PUBKEYS_PER_MULTISIG (src/script/interpreter.h at the pin).
static const uint32_t LIMITS_MAX_PUBKEYS_PER_MULTISIG = 20u;
