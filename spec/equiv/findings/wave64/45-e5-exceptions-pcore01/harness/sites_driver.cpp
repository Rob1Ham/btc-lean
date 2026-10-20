// Directed per-call-site differential for the P-CORE-01 lowering.
// 11 of the 12 GetScriptNum sites are reachable in BASE; OP_CHECKSIGADD
// (site 10) is Tapscript-only and is not covered here.
#include <script/interpreter.h>

#include <cstdio>
#include <string>
#include <vector>

static CScript mk(const std::vector<unsigned char>& v) { return CScript(v.begin(), v.end()); }
static void push(std::vector<unsigned char>& s, const std::vector<unsigned char>& v)
{
    s.push_back(static_cast<unsigned char>(v.size()));
    s.insert(s.end(), v.begin(), v.end());
}

struct R { bool ok; int err; };

static R run(const std::vector<unsigned char>& spk_bytes, script_verify_flags flags)
{
    static const BaseSignatureChecker checker{};
    ScriptError err = SCRIPT_ERR_OK;
    CScript spk = mk(spk_bytes);
    CScript empty;
    bool ok = VerifyScript(empty, spk, nullptr, flags, checker, &err);
    return {ok, static_cast<int>(err)};
}

static void show(const char* name, const R& r)
{
    std::printf("%-22s ok=%d err=%d\n", name, r.ok ? 1 : 0, r.err);
}

int main()
{
    const std::vector<unsigned char> five{1,2,3,4,5};
    const std::vector<unsigned char> six{1,2,3,4,5,6};
    const std::vector<unsigned char> one{1};
    const auto none = SCRIPT_VERIFY_NONE;
    const auto cltv = SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY;
    const auto csv = SCRIPT_VERIFY_CHECKSEQUENCEVERIFY;
    std::vector<unsigned char> s;

    // 1 (source :556). CHECKLOCKTIMEVERIFY, 6-byte operand (max is 5)
    s.clear(); push(s, six); s.push_back(0xb1); show("cltv-6byte", run(s, cltv));
    // 2 (:584). CHECKSEQUENCEVERIFY, 6-byte operand
    s.clear(); push(s, six); s.push_back(0xb2); show("csv-6byte", run(s, csv));
    // 3 (:840). OP_ROLL, 5-byte n
    s.clear(); s.push_back(0x51); push(s, five); s.push_back(0x7a); show("roll-5byte", run(s, none));
    // 4 (:939). unary OP_1ADD, 5-byte
    s.clear(); push(s, five); s.push_back(0x8b); show("1add-5byte", run(s, none));
    // 5-6 (:972,:973). binary OP_ADD, each operand position
    s.clear(); push(s, five); push(s, one); s.push_back(0x93); show("add-bn1-5byte", run(s, none));
    s.clear(); push(s, one); push(s, five); s.push_back(0x93); show("add-bn2-5byte", run(s, none));
    // 7-9 (:1017-:1019). OP_WITHIN (x min max), each position
    s.clear(); push(s, five); push(s, one); push(s, one); s.push_back(0xa5); show("within-bn1-5byte", run(s, none));
    s.clear(); push(s, one); push(s, five); push(s, one); s.push_back(0xa5); show("within-bn2-5byte", run(s, none));
    s.clear(); push(s, one); push(s, one); push(s, five); s.push_back(0xa5); show("within-bn3-5byte", run(s, none));
    // 10 (:1103). OP_CHECKSIGADD is Tapscript-only; BAD_OPCODE in BASE.
    s.clear(); push(s, one); push(s, five); push(s, one); s.push_back(0xba); show("checksigadd-base", run(s, none));
    // 11 (:1126). CHECKMULTISIG nKeysCount 5-byte
    s.clear(); push(s, five); s.push_back(0xae); show("cms-keys-5byte", run(s, none));
    // 12 (:1140). CHECKMULTISIG nSigsCount 5-byte, nKeysCount=1
    s.clear(); push(s, five); push(s, one); push(s, one); s.push_back(0xae); show("cms-sigs-5byte", run(s, none));
    // controls: valid 4-byte values must not be SCRIPTNUM
    s.clear(); push(s, std::vector<unsigned char>{1,2,3,4}); s.push_back(0x8b); show("1add-4byte-control", run(s, none));
    s.clear(); push(s, one); push(s, one); s.push_back(0x93); show("add-1byte-control", run(s, none));
    return 0;
}
