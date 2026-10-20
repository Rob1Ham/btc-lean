// Hand-computed behavioural vectors for policy-flags/C-L-flag-source.
//
// Compiled twice from the two cell legs with the root symbols renamed, then
// linked against this driver.  The expectations are written from Core's
// GetBlockScriptFlags at the pin, not from either cell's output.
#include <cstdint>
#include <cstdio>

extern "C" uint64_t c_cell_flag_source(uint64_t, uint64_t);
extern "C" uint64_t c_cell_flag_source_policy_mask(uint64_t, uint64_t);
extern "C" uint64_t l_cell_flag_source(uint64_t, uint64_t);
extern "C" uint64_t l_cell_flag_source_policy_mask(uint64_t, uint64_t);
extern "C" uint64_t c_cell_lows_gate_block(uint64_t, uint64_t, uint64_t, uint64_t, uint64_t, uint64_t, uint64_t);
extern "C" uint64_t l_cell_lows_gate_block(uint64_t, uint64_t, uint64_t, uint64_t, uint64_t, uint64_t, uint64_t);
extern "C" uint64_t c_cell_const_gate_block(uint64_t, uint64_t, uint64_t, uint64_t, uint64_t);
extern "C" uint64_t l_cell_const_gate_block(uint64_t, uint64_t, uint64_t, uint64_t, uint64_t);
extern "C" uint64_t c_cell_standard_policy_mask();
extern "C" uint64_t l_cell_standard_policy_mask();
extern "C" uint64_t c_cell_mandatory_policy_mask();
extern "C" uint64_t l_cell_mandatory_policy_mask();

namespace {
constexpr uint64_t P2SH = 1ull << 0, DERSIG = 1ull << 2, NULLDUMMY = 1ull << 4;
constexpr uint64_t LOW_S = 1ull << 3, CLTV = 1ull << 9, CSV = 1ull << 10;
constexpr uint64_t WITNESS = 1ull << 11, CONST_SCRIPTCODE = 1ull << 16;
constexpr uint64_t TAPROOT = 1ull << 17;
constexpr uint64_t BASE = P2SH | WITNESS | TAPROOT;
constexpr uint64_t BURIED = DERSIG | CLTV | CSV | NULLDUMMY;
constexpr uint64_t M = LOW_S | CONST_SCRIPTCODE;

int failures = 0;
void check(const char* what, uint64_t gotC, uint64_t gotL, uint64_t want) {
    const bool ok = gotC == want && gotL == want;
    if (!ok) ++failures;
    std::printf("%-42s C=0x%05llx L=0x%05llx want=0x%05llx %s\n", what,
                (unsigned long long)gotC, (unsigned long long)gotL,
                (unsigned long long)want, ok ? "PASS" : "FAIL");
}
}  // namespace

int main() {
    struct Vec { const char* name; uint64_t kind; uint64_t height; uint64_t want; };
    const Vec vecs[] = {
        {"none / 0 (pre-BIP66)",             0, 0,      BASE},
        {"none / 363724 (BIP66-1)",          0, 363724, BASE},
        {"none / 363725 (BIP66)",            0, 363725, BASE | DERSIG},
        {"none / 388381 (BIP65)",            0, 388381, BASE | DERSIG | CLTV},
        {"none / 419328 (CSV)",              0, 419328, BASE | DERSIG | CLTV | CSV},
        {"none / 481824 (segwit/NULLDUMMY)", 0, 481824, BASE | BURIED},
        {"BIP16 exception / 170060",         1, 170060, 0},
        {"taproot exception / 692261",       2, 692261, P2SH | WITNESS | BURIED},
        {"taproot exception / 0",            2, 0,      P2SH | WITNESS},
        {"unknown class 3 / 481824",         3, 481824, BASE | BURIED},
        {"height high bits masked off",      0, 0x100000000ull + 481824, BASE | BURIED},
    };
    for (const auto& v : vecs) {
        check(v.name,
              c_cell_flag_source(v.kind, v.height),
              l_cell_flag_source(v.kind, v.height), v.want);
        check("  policy mask",
              c_cell_flag_source_policy_mask(v.kind, v.height),
              l_cell_flag_source_policy_mask(v.kind, v.height), 0);
    }
    // Integration: a valid-DER high-S signature under the block word must not
    // reach SIG_HIGH_S (27).  s0=0x7fff... > n/2 while S[0] < 0x80 stays
    // DER-valid, so only a present LOW_S bit could reject it.
    const uint64_t hi0 = 0x7fffffffffffffffULL;
    const uint64_t hi1 = 0xffffffffffffffffULL;
    const uint64_t hi2 = 0xffffffffffffffffULL;
    const uint64_t hi3 = 0xffffffffffffffffULL;
    check("block flags: high-S at 481824",
          c_cell_lows_gate_block(0, 481824, 0x01, hi0, hi1, hi2, hi3),
          l_cell_lows_gate_block(0, 481824, 0x01, hi0, hi1, hi2, hi3), 0);
    check("block flags: high-S at BIP16 170060",
          c_cell_lows_gate_block(1, 170060, 0x01, hi0, hi1, hi2, hi3),
          l_cell_lows_gate_block(1, 170060, 0x01, hi0, hi1, hi2, hi3), 0);
    check("block flags: invalid DER at 481824 (DERSIG)",
          c_cell_lows_gate_block(0, 481824, 0x80, 0, 0, 0, 0),
          l_cell_lows_gate_block(0, 481824, 0x80, 0, 0, 0, 0), 24);
    check("block flags: OP_CODESEPARATOR at 481824",
          c_cell_const_gate_block(0, 481824, 0, 0xab, 0),
          l_cell_const_gate_block(0, 481824, 0, 0xab, 0), 0);
    check("block flags: FindAndDelete at 481824",
          c_cell_const_gate_block(0, 481824, 0, 0, 1),
          l_cell_const_gate_block(0, 481824, 0, 0, 1), 0);
    check("block flags: out-of-domain found=2",
          c_cell_const_gate_block(0, 481824, 0, 0, 2),
          l_cell_const_gate_block(0, 481824, 0, 0, 2), 0xff);
    check("standard policy mask", c_cell_standard_policy_mask(),
          l_cell_standard_policy_mask(), M);
    check("mandatory policy mask", c_cell_mandatory_policy_mask(),
          l_cell_mandatory_policy_mask(), 0);
    std::printf("concrete vectors: %s\n", failures ? "FAIL" : "ALL PASS");
    return failures ? 1 : 0;
}
