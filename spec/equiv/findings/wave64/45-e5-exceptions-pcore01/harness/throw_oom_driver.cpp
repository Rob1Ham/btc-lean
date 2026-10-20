// Re-audit driver: direct VerifyScript calls with (a) a checker that throws
// from CheckECDSASignature and (b) a global operator new that throws
// std::bad_alloc when armed.  Prototype only.
//
// Expected:
//   baseline   throw test -> false, SCRIPT_ERR_UNKNOWN_ERROR
//              OOM test   -> false, SCRIPT_ERR_UNKNOWN_ERROR
//   p01        both       -> exception propagates out of VerifyScript
//   p01amend   both       -> false, SCRIPT_ERR_UNKNOWN_ERROR
#include <script/interpreter.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <new>
#include <stdexcept>
#include <string>
#include <vector>

// ---------------------------------------------------------------- OOM injection
static bool g_armed = false;
static long g_countdown = 0;

void* operator new(std::size_t n)
{
    if (g_armed) {
        if (g_countdown <= 0) throw std::bad_alloc();
        --g_countdown;
    }
    if (void* p = std::malloc(n ? n : 1)) return p;
    throw std::bad_alloc();
}
void* operator new[](std::size_t n) { return operator new(n); }
void operator delete(void* p) noexcept { std::free(p); }
void operator delete[](void* p) noexcept { std::free(p); }
void operator delete(void* p, std::size_t) noexcept { std::free(p); }
void operator delete[](void* p, std::size_t) noexcept { std::free(p); }

// ---------------------------------------------------------------- checker
struct ThrowingChecker : public BaseSignatureChecker {
    bool CheckECDSASignature(const std::vector<unsigned char>&,
                             const std::vector<unsigned char>&,
                             const CScript&, SigVersion) const override
    {
        throw std::runtime_error("injected external throw");
    }
};

struct NullChecker : public BaseSignatureChecker {};

static CScript mk(const std::vector<unsigned char>& v)
{
    return CScript(v.begin(), v.end());
}

struct Outcome {
    bool threw{false};
    bool ok{false};
    int err{-1};
    std::string what;
};

static Outcome run(const CScript& sig, const CScript& spk,
                   const BaseSignatureChecker& checker, ScriptError* err)
{
    Outcome o;
    *err = SCRIPT_ERR_OK;
    try {
        o.ok = VerifyScript(sig, spk, nullptr, SCRIPT_VERIFY_NONE, checker, err);
        o.err = static_cast<int>(*err);
    } catch (const std::exception& e) {
        o.threw = true;
        o.what = e.what();
        o.err = static_cast<int>(*err);
    }
    return o;
}

static void print(const char* name, const Outcome& o)
{
    if (o.threw) {
        std::printf("%s: PROPAGATED exception what=\"%s\" err=%d\n", name,
                    o.what.c_str(), o.err);
    } else {
        std::printf("%s: ok=%d err=%d (%s)\n", name, o.ok ? 1 : 0, o.err,
                    o.err == static_cast<int>(SCRIPT_ERR_UNKNOWN_ERROR)
                        ? "SCRIPT_ERR_UNKNOWN_ERROR"
                        : (o.err == static_cast<int>(SCRIPT_ERR_OK) ? "OK" : "other"));
    }
}

int main()
{
    const CScript empty;
    ScriptError err;

    // CHECKSIG on a 1-byte sig + 1-byte pubkey; flags=0 reaches the checker.
    const std::vector<unsigned char> checksig{0x01, 0x02, 0x01, 0x03, 0xac};
    ThrowingChecker throwing;
    Outcome t = run(empty, mk(checksig), throwing, &err);
    print("throw_test", t);

    // OP_1: the first stack push allocates.  Arm the allocator for the call.
    const std::vector<unsigned char> op1{0x51};
    NullChecker nullchecker;
    g_countdown = 0;
    g_armed = true;
    Outcome m = run(empty, mk(op1), nullchecker, &err);
    g_armed = false;
    print("oom_test", m);

    return 0;
}
