// Wave64 / 41-div-w32-p2sh-cleanstack
// Concrete Core probe for finding F-DIV-W32-01: is a valid P2SH-P2WPKH spend
// accepted by Bitcoin Core's VerifyScript under SCRIPT_VERIFY_CLEANSTACK?
//
// This links the *real* src/script/interpreter.cpp, src/script/script.cpp and
// src/pubkey.cpp from the pinned tree (cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66)
// and calls VerifyScript directly.  The only stub is the signature checker
// (BaseSignatureChecker subclass returning true for ECDSA/Schnorr and the
// locktime/sequence predicates), exactly as Core's own script_tests do with
// BaseSignatureChecker for non-signature rows.  No interpreter logic is
// excerpted or rewritten.
//
// Build/run: see run.sh in this directory.

#include <script/interpreter.h>
#include <script/script.h>
#include <hash.h>
#include <pubkey.h>
#include <uint256.h>

#include <cstdio>
#include <cstring>
#include <span>
#include <string>
#include <vector>

using valtype = std::vector<unsigned char>;

// A checker that accepts every signature / locktime / sequence predicate.
// This isolates VerifyScript's control flow (the SCR-008 seam) from
// signature-algorithm questions that are not part of this finding.
class AcceptAllChecker : public BaseSignatureChecker {
public:
    bool CheckECDSASignature(const valtype&, const valtype&, const CScript&,
                             SigVersion) const override { return true; }
    bool CheckSchnorrSignature(std::span<const unsigned char>,
                               std::span<const unsigned char>, SigVersion,
                               ScriptExecutionData&, ScriptError*) const override {
        return true;
    }
    bool CheckLockTime(const CScriptNum&) const override { return true; }
    bool CheckSequence(const CScriptNum&) const override { return true; }
};

static std::string hex(const valtype& v) {
    static const char* d = "0123456789abcdef";
    std::string s;
    s.reserve(v.size() * 2);
    for (unsigned char b : v) {
        s.push_back(d[b >> 4]);
        s.push_back(d[b & 0xf]);
    }
    return s;
}

static const char* err_name(ScriptError e) {
    switch (e) {
    case SCRIPT_ERR_OK: return "OK";
    case SCRIPT_ERR_CLEANSTACK: return "CLEANSTACK";
    case SCRIPT_ERR_EVAL_FALSE: return "EVAL_FALSE";
    case SCRIPT_ERR_WITNESS_PROGRAM_MISMATCH: return "WITNESS_PROGRAM_MISMATCH";
    case SCRIPT_ERR_WITNESS_MALLEATED_P2SH: return "WITNESS_MALLEATED_P2SH";
    default: return "OTHER";
    }
}

struct Tape {
    CScript ss;
    CScript spk;
    CScriptWitness wit;
    bool p2sh;
    bool witness;
    bool cleanstack;
    const char* name;
};

static Tape make_p2sh_p2wpkh() {
    // 33-byte compressed pubkey; content irrelevant, checker accepts.
    valtype pubkey;
    pubkey.push_back(0x02);
    pubkey.insert(pubkey.end(), 32, 0x11);

    const uint160 keyhash = Hash160(pubkey);
    valtype kh(keyhash.begin(), keyhash.end());

    // redeem = OP_0 <20-byte keyhash>   (v0 P2WPKH witness program)
    CScript redeem;
    redeem << OP_0 << kh;

    // scriptPubKey = OP_HASH160 <hash160(redeem)> OP_EQUAL
    CScript spk;
    const uint160 rh = Hash160(std::vector<unsigned char>(redeem.begin(), redeem.end()));
    spk << OP_HASH160 << valtype(rh.begin(), rh.end()) << OP_EQUAL;

    // scriptSig = single canonical push of the redeem script
    CScript ss;
    ss << valtype(redeem.begin(), redeem.end());

    CScriptWitness wit;
    valtype sig{0x30, 0x01, 0x01};  // dummy DER-ish sig; checker accepts
    wit.stack.push_back(sig);
    wit.stack.push_back(pubkey);

    return Tape{ss, spk, wit, true, true, true, "p2sh-p2wpkh"};
}

static Tape make_p2sh_p2wsh() {
    valtype pubkey;
    pubkey.push_back(0x02);
    pubkey.insert(pubkey.end(), 32, 0x22);

    valtype script;
    script.push_back(0x51);  // OP_TRUE
    uint256 sh;              // P2WSH commits to SHA256(witnessScript), not Hash256
    CSHA256().Write(script.data(), script.size()).Finalize(sh.begin());
    valtype shb(sh.begin(), sh.end());

    CScript redeem;
    redeem << OP_0 << shb;  // v0 P2WSH, 32-byte program

    CScript spk;
    const uint160 rh = Hash160(std::vector<unsigned char>(redeem.begin(), redeem.end()));
    spk << OP_HASH160 << valtype(rh.begin(), rh.end()) << OP_EQUAL;

    CScript ss;
    ss << valtype(redeem.begin(), redeem.end());

    CScriptWitness wit;
    wit.stack.push_back(script);

    return Tape{ss, spk, wit, true, true, true, "p2sh-p2wsh"};
}

static Tape make_bare_p2wpkh() {
    valtype pubkey;
    pubkey.push_back(0x02);
    pubkey.insert(pubkey.end(), 32, 0x11);
    const uint160 keyhash = Hash160(pubkey);
    valtype kh(keyhash.begin(), keyhash.end());

    CScript spk;
    spk << OP_0 << kh;  // bare v0 P2WPKH

    CScriptWitness wit;
    wit.stack.push_back(valtype{0x30, 0x01, 0x01});
    wit.stack.push_back(pubkey);

    return Tape{CScript(), spk, wit, false, true, true, "bare-p2wpkh"};
}

static Tape make_p2sh_plain() {
    // Plain (non-witness) P2SH: redeem = OP_TRUE, so the inner stack length is
    // 1 and the model's `finalLen` re-evaluation agrees with Core.
    CScript redeem;
    redeem << OP_TRUE;

    CScript spk;
    const uint160 rh = Hash160(std::vector<unsigned char>(redeem.begin(), redeem.end()));
    spk << OP_HASH160 << valtype(rh.begin(), rh.end()) << OP_EQUAL;

    CScript ss;
    ss << valtype(redeem.begin(), redeem.end());

    return Tape{ss, spk, CScriptWitness{}, true, true, true, "p2sh-plain"};
}

static void run(const Tape& t, bool with_cleanstack) {
    script_verify_flags flags;
    flags |= SCRIPT_VERIFY_P2SH;
    flags |= SCRIPT_VERIFY_WITNESS;
    if (with_cleanstack) flags |= SCRIPT_VERIFY_CLEANSTACK;

    ScriptError err = SCRIPT_ERR_UNKNOWN_ERROR;
    AcceptAllChecker chk;
    const bool ok = VerifyScript(t.ss, t.spk, &t.wit, flags, chk, &err);

    std::printf("tape=%-14s cleanstack=%d verify=%s err=%s(%d) scriptSig=%s scriptPubKey=%s\n",
                t.name, with_cleanstack ? 1 : 0, ok ? "true" : "false",
                err_name(err), (int)err,
                hex(valtype(t.ss.begin(), t.ss.end())).c_str(),
                hex(valtype(t.spk.begin(), t.spk.end())).c_str());
}

int main() {
    const Tape a = make_p2sh_p2wpkh();
    const Tape b = make_p2sh_p2wsh();
    const Tape c = make_bare_p2wpkh();
    const Tape d = make_p2sh_plain();

    // The recorded divergence: valid spend, cleanstack policy on.
    run(a, true);
    run(b, true);
    // Control: same tape without the policy bit must be accepted in both.
    run(a, false);
    run(b, false);
    // Control: the bare arm the Lean model *does* resize.
    run(c, true);
    run(c, false);
    // Control: plain P2SH (non-witness) under cleanstack — both models agree.
    run(d, true);
    run(d, false);
    return 0;
}
