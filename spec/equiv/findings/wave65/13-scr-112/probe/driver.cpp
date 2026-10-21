// Concrete witness driver for SCR-112 / F-DIV-004.
//
// Prints the exact packed outcomes of the C (Core-exact) and pinned-Lean
// probes for the minimal witness `pk = [0x02]` (header 0x02, length 1) under
// block/default policy.  The two probe functions are linked from the two
// source files; this driver adds no logic.
#include <cstdint>
#include <cstdio>

extern "C" uint64_t probe_core(uint8_t hdr, uint32_t len, uint32_t strict_enc,
                               uint32_t witness_pubkey_type, uint32_t sv,
                               uint32_t sig_len, uint32_t crypto_ok,
                               uint32_t null_fail);
extern "C" uint64_t probe_pinned(uint8_t hdr, uint32_t len, uint32_t strict_enc,
                                 uint32_t witness_pubkey_type, uint32_t sv,
                                 uint32_t sig_len, uint32_t crypto_ok,
                                 uint32_t null_fail);

static void row(const char* label, uint8_t hdr, uint32_t len, uint32_t se,
                uint32_t wpt, uint32_t sv, uint32_t sl, uint32_t co,
                uint32_t nf) {
    const uint64_t c = probe_core(hdr, len, se, wpt, sv, sl, co, nf);
    const uint64_t l = probe_pinned(hdr, len, se, wpt, sv, sl, co, nf);
    std::printf("%-34s hdr=%02x len=%u se=%u wpt=%u sv=%u sig_len=%u "
                "crypto_ok=%u null_fail=%u -> core=%llu pinned_lean=%llu %s\n",
                label, hdr, len, se, wpt, sv, sl, co, nf,
                (unsigned long long)c, (unsigned long long)l,
                c == l ? "agree" : "DIVERGE");
}

int main() {
    // Minimal witness: compressed header promising 33 bytes, actual 1 byte.
    row("block policy, nonempty sig", 0x02, 1, 0, 0, 0, 1, 1, 0);
    row("block policy, crypto_ok=0", 0x02, 1, 0, 0, 0, 1, 0, 0);
    row("block policy, empty sig", 0x02, 1, 0, 0, 0, 0, 1, 0);
    row("STRICTENC policy", 0x02, 1, 1, 0, 0, 1, 1, 0);
    row("NULLFAIL policy", 0x02, 1, 0, 0, 0, 1, 1, 1);
    // Canonical compressed key: both accept.
    row("canonical 33-byte 02", 0x02, 33, 0, 0, 0, 1, 1, 0);
    // 65-byte uncompressed under v0 policy: encoding abort in both.
    row("v0 WITNESS_PUBKEYTYPE 65B", 0x04, 65, 0, 1, 1, 1, 1, 0);
    // Another length-mismatch class: 34-byte compressed header.
    row("block policy, 34-byte 02", 0x02, 34, 0, 0, 0, 1, 1, 0);
    return 0;
}
