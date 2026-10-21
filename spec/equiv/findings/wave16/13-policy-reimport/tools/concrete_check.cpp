// Concrete behavioural cross-check for the wave16 policy/reimport cells.
//
// WHAT THIS IS.  A table of hand-computed input vectors, each annotated with the
// rule text it comes from and the Core ScriptError ordinal it must produce
// under the pin's semantics.  The smart contracts (Alive2 both directions,
// SAW over both legs) prove C == L for *all* inputs; this binary is the
// independent sanity check that the agreed predicate is the *right* one, i.e.
// that it matches the cases a reviewer can verify by hand from
// src/script/interpreter.cpp.
//
// The C leg and the reviewed Lean transliteration (L leg) are both linked in
// (L symbols renamed to lcell_* by run_concrete.sh) and both are compared with
// the same expected ordinal, so a vector passes only when three independent
// things agree: hand-written expectation, C excerpt, Lean transliteration.
//
// 0xff is the harness out-of-domain guard and is never an engine behaviour.
#include <cstdint>
#include <cstdio>
#include <cstring>

#include "policy_common.h"
using namespace policy_cell;

extern "C" {
uint64_t cell_cleanstack(uint64_t, uint64_t, uint64_t);
uint64_t cell_const_scriptcode_codesep(uint64_t, uint64_t, uint64_t);
uint64_t cell_const_scriptcode_finddelete(uint64_t, uint64_t, uint64_t);
uint64_t cell_lows_policy(uint64_t, uint64_t, uint64_t, uint64_t, uint64_t, uint64_t);
uint64_t cell_minimaldata_push(uint64_t, uint64_t, uint64_t, uint64_t, uint64_t);
uint64_t cell_minimalif_v0(uint64_t, uint64_t, uint64_t, uint64_t, uint64_t);
uint64_t cell_nullfail(uint64_t, uint64_t, uint64_t);
uint64_t cell_strictenc_pubkey(uint64_t, uint64_t, uint64_t);
uint64_t cell_witness_pubkeytype(uint64_t, uint64_t, uint64_t, uint64_t);
uint64_t cell_tapscript_minimalif(uint64_t, uint64_t, uint64_t, uint64_t, uint64_t);
uint64_t cell_tapscript_cleanstack(uint64_t, uint64_t, uint64_t);

uint64_t lcell_cleanstack(uint64_t, uint64_t, uint64_t);
uint64_t lcell_const_scriptcode_codesep(uint64_t, uint64_t, uint64_t);
uint64_t lcell_const_scriptcode_finddelete(uint64_t, uint64_t, uint64_t);
uint64_t lcell_lows_policy(uint64_t, uint64_t, uint64_t, uint64_t, uint64_t, uint64_t);
uint64_t lcell_minimaldata_push(uint64_t, uint64_t, uint64_t, uint64_t, uint64_t);
uint64_t lcell_minimalif_v0(uint64_t, uint64_t, uint64_t, uint64_t, uint64_t);
uint64_t lcell_nullfail(uint64_t, uint64_t, uint64_t);
uint64_t lcell_strictenc_pubkey(uint64_t, uint64_t, uint64_t);
uint64_t lcell_witness_pubkeytype(uint64_t, uint64_t, uint64_t, uint64_t);
uint64_t lcell_tapscript_minimalif(uint64_t, uint64_t, uint64_t, uint64_t, uint64_t);
uint64_t lcell_tapscript_cleanstack(uint64_t, uint64_t, uint64_t);
}

namespace {

int g_fail = 0;
int g_total = 0;
const char* g_cell = "";

void check(const char* name, uint64_t got, uint64_t got_l, uint64_t want,
           const char* rule) {
    ++g_total;
    const bool ok = (got == want) && (got_l == want);
    if (!ok) ++g_fail;
    std::printf("%-4s %-34s %-46s C=%-3llu L=%-3llu want=%-3llu (%s)\n",
                ok ? "ok" : "FAIL", g_cell, name,
                (unsigned long long)got, (unsigned long long)got_l,
                (unsigned long long)want, rule);
}

void cell(const char* name) { g_cell = name; }

}  // namespace

int main() {
    // Shared 256-bit S words: s = s0||s1||s2||s3, big-endian, S[0]=s0>>56.
    const uint64_t Z = 0;
    const uint64_t FF = 0xffffffffffffffffULL;

    // ---- SCR-175 policy-flags/C-L-lows-policy -------------------------------
    cell("lows-policy");
    // LOW_S set, S = 0 (S[0]=0, S[1]=0 -> non-minimal DER at :177) -> DER error
    // fires before LOW_S is consulted (:217-218 precede :219-221).
    check("LOW_S, S=0 (non-minimal DER)", cell_lows_policy(LOW_S, 1, 0, 0, 0, 0),
          lcell_lows_policy(LOW_S, 1, 0, 0, 0, 0), ERR_SIG_DER, ":217");
    // Valid canonical S with top byte 0x01 < 0x7f -> automatically low.
    check("LOW_S, S[0]=0x01 (low)", cell_lows_policy(LOW_S, 1,
          0x0100000000000000ULL, FF, FF, FF),
          lcell_lows_policy(LOW_S, 1, 0x0100000000000000ULL, FF, FF, FF),
          ERR_OK, ":219-223");
    // S = 0x7f ff..ff is canonical and above n/2 -> high-S.
    check("LOW_S, S=7fff..ff (high)", cell_lows_policy(LOW_S, 1,
          0x7fffffffffffffffULL, FF, FF, FF),
          lcell_lows_policy(LOW_S, 1, 0x7fffffffffffffffULL, FF, FF, FF),
          ERR_SIG_HIGH_S, ":219-221");
    // Same high-S value with only DERSIG: LOW_S bit clear -> accepted.
    check("DERSIG only, S=7fff..ff (high)", cell_lows_policy(DERSIG, 1,
          0x7fffffffffffffffULL, FF, FF, FF),
          lcell_lows_policy(DERSIG, 1, 0x7fffffffffffffffULL, FF, FF, FF),
          ERR_OK, ":217/:219");
    // R with high bit set is non-canonical (:149), STRICTENC enables the gate.
    check("STRICTENC, R[0]=0x80", cell_lows_policy(STRICTENC, 0x80, 1ULL << 56, 0, 0, 0),
          lcell_lows_policy(STRICTENC, 0x80, 1ULL << 56, 0, 0, 0),
          ERR_SIG_DER, ":149/:217");
    // S[0]=0 && !(S[1]&0x80) is non-minimal (:177) -> DER error.
    check("DERSIG, leading-zero S", cell_lows_policy(DERSIG, 1, 0, 0x0100000000000000ULL, 0, 0),
          lcell_lows_policy(DERSIG, 1, 0, 0x0100000000000000ULL, 0, 0),
          ERR_SIG_DER, ":177/:217");
    // No encoding/low-S flag at all: the whole check is skipped.
    check("no flags, invalid S", cell_lows_policy(0, 0x80, 0, 0, 0, 0),
          lcell_lows_policy(0, 0x80, 0, 0, 0, 0), ERR_OK, ":217/:219");

    // ---- SCR-176 policy-flags/C-L-cleanstack-base ---------------------------
    cell("cleanstack-base");
    check("BASE, len=2, CLEANSTACK", cell_cleanstack(CLEANSTACK, SV_BASE, 2),
          lcell_cleanstack(CLEANSTACK, SV_BASE, 2), ERR_CLEANSTACK, ":2110-2116");
    check("BASE, len=2, no flag", cell_cleanstack(0, SV_BASE, 2),
          lcell_cleanstack(0, SV_BASE, 2), ERR_OK, ":2110");
    check("BASE, len=1, CLEANSTACK", cell_cleanstack(CLEANSTACK, SV_BASE, 1),
          lcell_cleanstack(CLEANSTACK, SV_BASE, 1), ERR_OK, ":2115");
    check("WITNESS_V0, len=2, no flag", cell_cleanstack(0, SV_WITNESS_V0, 2),
          lcell_cleanstack(0, SV_WITNESS_V0, 2), ERR_CLEANSTACK, ":1877");
    check("WITNESS_V0, len=1, no flag", cell_cleanstack(0, SV_WITNESS_V0, 1),
          lcell_cleanstack(0, SV_WITNESS_V0, 1), ERR_OK, ":1877");
    check("sv=3 out of domain", cell_cleanstack(0, 3, 2),
          lcell_cleanstack(0, 3, 2), OUT_OF_DOMAIN, "guard");

    // ---- SCR-177 policy-flags/C-L-const-scriptcode --------------------------
    cell("const-scriptcode");
    check("codesep, BASE, flag", cell_const_scriptcode_codesep(CONST_SCRIPTCODE, SV_BASE, OP_CODESEPARATOR),
          lcell_const_scriptcode_codesep(CONST_SCRIPTCODE, SV_BASE, OP_CODESEPARATOR),
          ERR_OP_CODESEPARATOR, ":333-336");
    check("codesep, BASE, no flag", cell_const_scriptcode_codesep(0, SV_BASE, OP_CODESEPARATOR),
          lcell_const_scriptcode_codesep(0, SV_BASE, OP_CODESEPARATOR), ERR_OK, ":334");
    check("codesep, WITNESS_V0, flag", cell_const_scriptcode_codesep(CONST_SCRIPTCODE, SV_WITNESS_V0, OP_CODESEPARATOR),
          lcell_const_scriptcode_codesep(CONST_SCRIPTCODE, SV_WITNESS_V0, OP_CODESEPARATOR),
          ERR_OK, ":334");
    check("finddelete, BASE, found=1, flag", cell_const_scriptcode_finddelete(CONST_SCRIPTCODE, SV_BASE, 1),
          lcell_const_scriptcode_finddelete(CONST_SCRIPTCODE, SV_BASE, 1),
          ERR_SIG_FINDANDDELETE, ":337-341");
    check("finddelete, BASE, found=0, flag", cell_const_scriptcode_finddelete(CONST_SCRIPTCODE, SV_BASE, 0),
          lcell_const_scriptcode_finddelete(CONST_SCRIPTCODE, SV_BASE, 0), ERR_OK, ":340");
    check("finddelete, WITNESS_V0, flag", cell_const_scriptcode_finddelete(CONST_SCRIPTCODE, SV_WITNESS_V0, 1),
          lcell_const_scriptcode_finddelete(CONST_SCRIPTCODE, SV_WITNESS_V0, 1), ERR_OK, ":337");
    check("finddelete, found=2 out of domain", cell_const_scriptcode_finddelete(0, SV_BASE, 2),
          lcell_const_scriptcode_finddelete(0, SV_BASE, 2), OUT_OF_DOMAIN, "guard");

    // ---- SCR-178 policy-flags/C-L-minimaldata-push --------------------------
    cell("minimaldata-push");
    // One-byte value 0x05 must be pushed with OP_5, not a direct 1-byte push.
    check("len=1 b0=05 direct, MINIMALDATA", cell_minimaldata_push(MINIMALDATA, 1, 1, 1, 5),
          lcell_minimaldata_push(MINIMALDATA, 1, 1, 1, 5), ERR_MINIMALDATA, ":489-491");
    check("len=1 b0=05 direct, no flag", cell_minimaldata_push(0, 1, 1, 1, 5),
          lcell_minimaldata_push(0, 1, 1, 1, 5), ERR_OK, ":487");
    check("len=1 b0=05 direct, fExec=0", cell_minimaldata_push(MINIMALDATA, 0, 1, 1, 5),
          lcell_minimaldata_push(MINIMALDATA, 0, 1, 1, 5), ERR_OK, ":487");
    check("len=1 b0=11 direct, MINIMALDATA", cell_minimaldata_push(MINIMALDATA, 1, 1, 1, 0x11),
          lcell_minimaldata_push(MINIMALDATA, 1, 1, 1, 0x11), ERR_OK, ":489");
    check("len=0 OP_0, MINIMALDATA", cell_minimaldata_push(MINIMALDATA, 1, OP_0, 0, 0),
          lcell_minimaldata_push(MINIMALDATA, 1, OP_0, 0, 0), ERR_OK, ":489");
    check("len=0 direct-1, MINIMALDATA", cell_minimaldata_push(MINIMALDATA, 1, 1, 0, 0),
          lcell_minimaldata_push(MINIMALDATA, 1, 1, 0, 0), ERR_MINIMALDATA, ":489");
    check("len=76 PUSHDATA1, MINIMALDATA", cell_minimaldata_push(MINIMALDATA, 1, OP_PUSHDATA1, 76, 0),
          lcell_minimaldata_push(MINIMALDATA, 1, OP_PUSHDATA1, 76, 0), ERR_OK, ":489");
    // 76 bytes must use OP_PUSHDATA1 (0x4c), not the longer OP_PUSHDATA2.
    check("len=76 PUSHDATA2, MINIMALDATA", cell_minimaldata_push(MINIMALDATA, 1, OP_PUSHDATA2, 76, 0),
          lcell_minimaldata_push(MINIMALDATA, 1, OP_PUSHDATA2, 76, 0), ERR_MINIMALDATA, ":489");
    check("len=300 PUSHDATA2, MINIMALDATA", cell_minimaldata_push(MINIMALDATA, 1, OP_PUSHDATA2, 300, 0),
          lcell_minimaldata_push(MINIMALDATA, 1, OP_PUSHDATA2, 300, 0), ERR_OK, ":489");
    check("len=1 b0=81 direct, MINIMALDATA", cell_minimaldata_push(MINIMALDATA, 1, 1, 1, 0x81),
          lcell_minimaldata_push(MINIMALDATA, 1, 1, 1, 0x81), ERR_MINIMALDATA, ":489");

    // ---- SCR-179 policy-flags/C-L-minimalif-v0 ------------------------------
    cell("minimalif-v0");
    check("WITNESS_V0, MINIMALIF, len=1 b0=2", cell_minimalif_v0(MINIMALIF, SV_WITNESS_V0, 1, 1, 2),
          lcell_minimalif_v0(MINIMALIF, SV_WITNESS_V0, 1, 1, 2), ERR_MINIMALIF, ":631-635");
    check("WITNESS_V0, MINIMALIF, len=2", cell_minimalif_v0(MINIMALIF, SV_WITNESS_V0, 1, 2, 1),
          lcell_minimalif_v0(MINIMALIF, SV_WITNESS_V0, 1, 2, 1), ERR_MINIMALIF, ":632-633");
    check("WITNESS_V0, MINIMALIF, len=1 b0=1", cell_minimalif_v0(MINIMALIF, SV_WITNESS_V0, 1, 1, 1),
          lcell_minimalif_v0(MINIMALIF, SV_WITNESS_V0, 1, 1, 1), ERR_OK, ":638");
    check("WITNESS_V0, MINIMALIF, len=0", cell_minimalif_v0(MINIMALIF, SV_WITNESS_V0, 1, 0, 0),
          lcell_minimalif_v0(MINIMALIF, SV_WITNESS_V0, 1, 0, 0), ERR_OK, ":638");
    check("WITNESS_V0, no flag, len=1 b0=2", cell_minimalif_v0(0, SV_WITNESS_V0, 1, 1, 2),
          lcell_minimalif_v0(0, SV_WITNESS_V0, 1, 1, 2), ERR_OK, ":631");
    check("BASE, MINIMALIF, len=1 b0=2", cell_minimalif_v0(MINIMALIF, SV_BASE, 1, 1, 2),
          lcell_minimalif_v0(MINIMALIF, SV_BASE, 1, 1, 2), ERR_OK, ":631");
    check("WITNESS_V0, MINIMALIF, fExec=0", cell_minimalif_v0(MINIMALIF, SV_WITNESS_V0, 0, 1, 2),
          lcell_minimalif_v0(MINIMALIF, SV_WITNESS_V0, 0, 1, 2), ERR_OK, ":629");
    check("sv=2 out of domain", cell_minimalif_v0(MINIMALIF, SV_TAPSCRIPT, 1, 1, 2),
          lcell_minimalif_v0(MINIMALIF, SV_TAPSCRIPT, 1, 1, 2), OUT_OF_DOMAIN, "guard");

    // ---- SCR-180 policy-flags/C-L-nullfail ----------------------------------
    cell("nullfail");
    check("NULLFAIL, fail, sig non-empty", cell_nullfail(NULLFAIL, 0, 10),
          lcell_nullfail(NULLFAIL, 0, 10), ERR_SIG_NULLFAIL, ":351-352");
    check("NULLFAIL, fail, sig empty", cell_nullfail(NULLFAIL, 0, 0),
          lcell_nullfail(NULLFAIL, 0, 0), ERR_OK, ":351");
    check("NULLFAIL, success, sig non-empty", cell_nullfail(NULLFAIL, 1, 10),
          lcell_nullfail(NULLFAIL, 1, 10), ERR_OK, ":351");
    check("no flag, fail, sig non-empty", cell_nullfail(0, 0, 10),
          lcell_nullfail(0, 0, 10), ERR_OK, ":351");

    // ---- SCR-181 policy-flags/C-L-strictenc-pubkey --------------------------
    cell("strictenc-pubkey");
    check("STRICTENC, 33/02", cell_strictenc_pubkey(STRICTENC, 33, 0x02),
          lcell_strictenc_pubkey(STRICTENC, 33, 0x02), ERR_OK, ":74-93");
    check("STRICTENC, 32/02", cell_strictenc_pubkey(STRICTENC, 32, 0x02),
          lcell_strictenc_pubkey(STRICTENC, 32, 0x02), ERR_PUBKEYTYPE, ":75-78");
    check("STRICTENC, 65/04", cell_strictenc_pubkey(STRICTENC, 65, 0x04),
          lcell_strictenc_pubkey(STRICTENC, 65, 0x04), ERR_OK, ":79-83");
    check("STRICTENC, 64/04", cell_strictenc_pubkey(STRICTENC, 64, 0x04),
          lcell_strictenc_pubkey(STRICTENC, 64, 0x04), ERR_PUBKEYTYPE, ":80-83");
    check("STRICTENC, 33/04", cell_strictenc_pubkey(STRICTENC, 33, 0x04),
          lcell_strictenc_pubkey(STRICTENC, 33, 0x04), ERR_PUBKEYTYPE, ":80-83");
    check("STRICTENC, 33/05", cell_strictenc_pubkey(STRICTENC, 33, 0x05),
          lcell_strictenc_pubkey(STRICTENC, 33, 0x05), ERR_PUBKEYTYPE, ":89-92");
    check("STRICTENC, 65/02", cell_strictenc_pubkey(STRICTENC, 65, 0x02),
          lcell_strictenc_pubkey(STRICTENC, 65, 0x02), ERR_PUBKEYTYPE, ":85-88");
    check("no flag, 32/02", cell_strictenc_pubkey(0, 32, 0x02),
          lcell_strictenc_pubkey(0, 32, 0x02), ERR_OK, ":229");

    // ---- SCR-182 policy-flags/C-L-witness-pubkeytype ------------------------
    cell("witness-pubkeytype");
    check("flag, WITNESS_V0, 33/02", cell_witness_pubkeytype(WITNESS_PUBKEYTYPE, SV_WITNESS_V0, 33, 0x02),
          lcell_witness_pubkeytype(WITNESS_PUBKEYTYPE, SV_WITNESS_V0, 33, 0x02), ERR_OK, ":233-235");
    check("flag, WITNESS_V0, 65/04", cell_witness_pubkeytype(WITNESS_PUBKEYTYPE, SV_WITNESS_V0, 65, 0x04),
          lcell_witness_pubkeytype(WITNESS_PUBKEYTYPE, SV_WITNESS_V0, 65, 0x04), ERR_WITNESS_PUBKEYTYPE, ":233-235");
    check("flag, BASE, 65/04", cell_witness_pubkeytype(WITNESS_PUBKEYTYPE, SV_BASE, 65, 0x04),
          lcell_witness_pubkeytype(WITNESS_PUBKEYTYPE, SV_BASE, 65, 0x04), ERR_OK, ":234");
    check("flag, TAPSCRIPT, 65/04", cell_witness_pubkeytype(WITNESS_PUBKEYTYPE, SV_TAPSCRIPT, 65, 0x04),
          lcell_witness_pubkeytype(WITNESS_PUBKEYTYPE, SV_TAPSCRIPT, 65, 0x04), ERR_OK, ":234");
    check("no flag, WITNESS_V0, 65/04", cell_witness_pubkeytype(0, SV_WITNESS_V0, 65, 0x04),
          lcell_witness_pubkeytype(0, SV_WITNESS_V0, 65, 0x04), ERR_OK, ":233");
    check("sv=3 out of domain", cell_witness_pubkeytype(0, 3, 65, 0x04),
          lcell_witness_pubkeytype(0, 3, 65, 0x04), OUT_OF_DOMAIN, "guard");

    // ---- SCR-183 tapscript-reimport/C-L-tapscript-reimport ------------------
    cell("tapscript-reimport");
    // Consensus: TAPSCRIPT minimal-IF fires regardless of the policy bit.
    check("TAPSCRIPT, no flag, len=1 b0=2", cell_tapscript_minimalif(0, SV_TAPSCRIPT, 1, 1, 2),
          lcell_tapscript_minimalif(0, SV_TAPSCRIPT, 1, 1, 2), ERR_TAPSCRIPT_MINIMALIF, ":624-629");
    check("TAPSCRIPT, MINIMALIF, len=1 b0=2", cell_tapscript_minimalif(MINIMALIF, SV_TAPSCRIPT, 1, 1, 2),
          lcell_tapscript_minimalif(MINIMALIF, SV_TAPSCRIPT, 1, 1, 2), ERR_TAPSCRIPT_MINIMALIF, ":624-629");
    check("TAPSCRIPT, len=2", cell_tapscript_minimalif(0, SV_TAPSCRIPT, 1, 2, 1),
          lcell_tapscript_minimalif(0, SV_TAPSCRIPT, 1, 2, 1), ERR_TAPSCRIPT_MINIMALIF, ":624-629");
    check("TAPSCRIPT, len=1 b0=1", cell_tapscript_minimalif(0, SV_TAPSCRIPT, 1, 1, 1),
          lcell_tapscript_minimalif(0, SV_TAPSCRIPT, 1, 1, 1), ERR_OK, ":624-629");
    check("TAPSCRIPT, len=0", cell_tapscript_minimalif(0, SV_TAPSCRIPT, 1, 0, 0),
          lcell_tapscript_minimalif(0, SV_TAPSCRIPT, 1, 0, 0), ERR_OK, ":624-629");
    check("TAPSCRIPT, fExec=0", cell_tapscript_minimalif(0, SV_TAPSCRIPT, 0, 1, 2),
          lcell_tapscript_minimalif(0, SV_TAPSCRIPT, 0, 1, 2), ERR_OK, ":629");
    check("WITNESS_V0, MINIMALIF, len=1 b0=2", cell_tapscript_minimalif(MINIMALIF, SV_WITNESS_V0, 1, 1, 2),
          lcell_tapscript_minimalif(MINIMALIF, SV_WITNESS_V0, 1, 1, 2), ERR_MINIMALIF, ":631-637");
    check("WITNESS_V0, no flag, len=1 b0=2", cell_tapscript_minimalif(0, SV_WITNESS_V0, 1, 1, 2),
          lcell_tapscript_minimalif(0, SV_WITNESS_V0, 1, 1, 2), ERR_OK, ":631");
    check("minimalif sv=3 out of domain", cell_tapscript_minimalif(0, 3, 1, 1, 2),
          lcell_tapscript_minimalif(0, 3, 1, 1, 2), OUT_OF_DOMAIN, "guard");
    check("cleanstack, WITNESS_V0, len=2", cell_tapscript_cleanstack(0, SV_WITNESS_V0, 2),
          lcell_tapscript_cleanstack(0, SV_WITNESS_V0, 2), ERR_CLEANSTACK, ":1876-1878");
    check("cleanstack, TAPSCRIPT, len=2", cell_tapscript_cleanstack(0, SV_TAPSCRIPT, 2),
          lcell_tapscript_cleanstack(0, SV_TAPSCRIPT, 2), ERR_CLEANSTACK, ":1876-1878");
    check("cleanstack, WITNESS_V0, len=1", cell_tapscript_cleanstack(0, SV_WITNESS_V0, 1),
          lcell_tapscript_cleanstack(0, SV_WITNESS_V0, 1), ERR_OK, ":1876-1878");
    check("cleanstack, BASE out of domain", cell_tapscript_cleanstack(0, SV_BASE, 2),
          lcell_tapscript_cleanstack(0, SV_BASE, 2), OUT_OF_DOMAIN, "guard");

    std::printf("\nvectors=%d failures=%d\n", g_total, g_fail);
    return g_fail == 0 ? 0 : 1;
}
