// Concrete driver for F-DIV-w32-001: calls the C leg and the L leg on the
// same inputs and prints both packed outcomes.
#include <cstdint>
#include <cstdio>

extern "C" uint64_t probe_c_order(uint32_t len, uint8_t b0, uint8_t b1,
                                  uint8_t b2, uint8_t b3, uint32_t too_many,
                                  uint32_t oversize, uint32_t discourage);
extern "C" uint64_t probe_l_order(uint32_t len, uint8_t b0, uint8_t b1,
                                  uint8_t b2, uint8_t b3, uint32_t too_many,
                                  uint32_t oversize, uint32_t discourage);

static void run(const char* name, uint32_t len, uint8_t b0, uint8_t b1,
                uint8_t b2, uint8_t b3, uint32_t tm, uint32_t os,
                uint32_t di) {
    const uint64_t c = probe_c_order(len, b0, b1, b2, b3, tm, os, di);
    const uint64_t l = probe_l_order(len, b0, b1, b2, b3, tm, os, di);
    std::printf("%-10s len=%u bytes=%02x %02x %02x %02x tm=%u os=%u di=%u"
                "  C=%-3llu L=%-3llu %s\n",
                name, len, b0, b1, b2, b3, tm, os, di,
                (unsigned long long)c, (unsigned long long)l,
                c == l ? "agree" : "DIVERGE");
}

int main() {
    // SAW's counterexample: a truncated PUSHDATA4 tail, empty-ish stack, one
    // oversize item.  Core: BAD_OPCODE (64); Lean: PUSH_SIZE (24).
    run("saw-cex", 4, 0x02, 0x02, 0x80, 0x4e, 0, 16, 2048);
    // Same tail with too_many set: Core 64, Lean STACK_SIZE (32).
    run("stack", 1, 0x02, 0x00, 0x00, 0x00, 1, 0, 0);
    // Well-formed OP_SUCCESSx: both legs succeed (1) / discourage (144).
    run("success", 1, 0x50, 0x00, 0x00, 0x00, 0, 0, 0);
    run("disc", 1, 0x50, 0x00, 0x00, 0x00, 0, 0, 1);
    return 0;
}
