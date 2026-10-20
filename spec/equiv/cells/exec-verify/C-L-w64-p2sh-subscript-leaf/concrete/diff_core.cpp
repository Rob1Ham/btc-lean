// Concrete differential: the cell's C model vs the *real* Core EvalScript.
//
// The cell proves a two-leg model pair; this harness additionally checks that
// the C transcription matches the built Bitcoin Core `EvalScript` at the pin
// on the whole declared leaf domain, with the EVAL_FALSE checks of
// interpreter.cpp:2083-2086 applied to the stack the real call returns.
//
// Not a proof: a finite, exhaustive-over-script-bytes differential over the
// leaf. The scripts are all byte strings of length 0, 1 and 2; the stack is
// (depth 1, 2, 3, 12) x (a set of `prev` elements covering the CastToBool
// arms). Inputs on which the cell returns the out-of-model marker are skipped
// and counted.
//
// Build/run: concrete/run.sh (links the local Core build at the pin).

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <vector>

#include <script/interpreter.h>
#include <script/script.h>
#include <script/script_error.h>
#include <script/verify_flags.h>

extern "C" uint64_t cell_p2sh_subscript_leaf(uint64_t ss_depth, uint64_t ss_top,
                                             uint64_t ss_top_len,
                                             uint64_t prev_top, uint64_t prev_len);

// Core defines `CastToBool` in interpreter.cpp with external linkage but does
// not declare it in a public header (same declaration as the fuzz harness,
// src/test/fuzz/script_interpreter.cpp:17). Linked from libbitcoin_consensus.
bool CastToBool(const std::vector<unsigned char>& vch);

namespace {

uint64_t pack(uint32_t result, uint32_t error) {
  return (uint64_t)(result & 3u) | ((uint64_t)(error & 0x3fu) << 2);
}

void print_outcome(const char* tag, uint64_t v) {
  std::printf("%s result=%llu error=%llu\n", tag,
              (unsigned long long)(v & 3u),
              (unsigned long long)((v >> 2) & 0x3fu));
}

}  // namespace

int main() {
  BaseSignatureChecker checker;
  // The cell's precondition: the P2SH arm is entered, MINIMALDATA is off.
  // EvalScript reads the P2SH bit nowhere else; SCRIPT_VERIFY_WITNESS and the
  // other flags do not change the in-leaf opcodes.
  const script_verify_flags flags = SCRIPT_VERIFY_P2SH;

  const uint64_t depths[] = {1, 2, 3, 12};
  struct Prev {
    uint64_t top;
    uint64_t len;
  };
  const Prev prevs[] = {
      {0x00, 0},      // empty element
      {0x01, 1},      // true
      {0x80, 1},      // negative zero -> false
      {0x0101, 2},    // true (leading byte nonzero)
      {0x0001, 2},    // true (second byte nonzero, len 2)
      {0x0080, 2},    // negative zero at the last byte -> false
      {0x8100, 3},    // true
  };

  unsigned long long checked = 0, skipped = 0, mismatches = 0;

  for (uint64_t depth : depths) {
    for (const Prev& p : prevs) {
      for (unsigned len = 0; len <= 2; ++len) {
        const unsigned long total = (len == 0) ? 1ul : (len == 1 ? 256ul : 65536ul);
        for (unsigned long s = 0; s < total; ++s) {
          const uint8_t b[2] = {(uint8_t)(s & 0xffu), (uint8_t)((s >> 8) & 0xffu)};
          const uint64_t top = (uint64_t)b[0] | ((uint64_t)b[1] << 8);
          const uint64_t model =
              cell_p2sh_subscript_leaf(depth, top, (uint64_t)len, p.top, p.len);
          if (model == pack(0, 1)) {  // out-of-model marker (guards / outside leaf)
            ++skipped;
            continue;
          }

          // Real Core: the restored stack (stackCopy minus the redeem element)
          // and the redeem element itself as pubKey2.
          std::vector<std::vector<unsigned char>> stack(depth - 1);
          if (!stack.empty()) {
            std::vector<unsigned char>& t = stack.back();
            t.resize(p.len);
            for (uint64_t i = 0; i < p.len; ++i) {
              t[i] = (unsigned char)((p.top >> (8u * i)) & 0xffu);
            }
          }
          const CScript pubKey2(b, b + len);
          ScriptExecutionData execdata;
          ScriptError serror = SCRIPT_ERR_UNKNOWN_ERROR;
          const bool ok = EvalScript(stack, pubKey2, flags, checker,
                                     SigVersion::BASE, execdata, &serror);
          uint64_t core;
          if (!ok) {
            core = pack(0, (uint32_t)serror);
          } else if (stack.empty()) {
            core = pack(0, (uint32_t)SCRIPT_ERR_EVAL_FALSE);
          } else if (!CastToBool(stack.back())) {
            core = pack(0, (uint32_t)SCRIPT_ERR_EVAL_FALSE);
          } else {
            core = pack(1, 0);
          }
          ++checked;
          if (core != model) {
            ++mismatches;
            if (mismatches <= 10) {
              std::printf("MISMATCH depth=%llu len=%u bytes=%02x %02x prev=%016llx/%llu\n",
                          (unsigned long long)depth, len, b[0], b[1],
                          (unsigned long long)p.top, (unsigned long long)p.len);
              print_outcome("  model", model);
              print_outcome("  core ", core);
            }
          }
        }
      }
    }
  }

  std::printf("checked=%llu skipped_out_of_model=%llu mismatches=%llu\n",
              checked, skipped, mismatches);
  return mismatches == 0 ? 0 : 1;
}
