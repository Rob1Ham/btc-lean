// Flag-mask probe: read the numeric values of the pin's script_verify_flags
// names straight out of src/script/interpreter.h, so the cell constants are not
// hand-copied from a comment.
//
// Build (from /tmp/opencode/core-pin):
//   clang++-20 -std=c++20 -I src -I src/script -c flags_probe.cpp -o /tmp/flags_probe.o
// The pin's header may pull in config-dependent includes; run_flags_probe.sh
// falls back to preprocessing the enum if a full compile is not possible.
#include <cstdint>
#include <cstdio>

#include <script/interpreter.h>

int main() {
    struct Row { const char* name; uint8_t bit; } rows[] = {
        {"P2SH", static_cast<uint8_t>(SCRIPT_VERIFY_P2SH)},
        {"STRICTENC", static_cast<uint8_t>(SCRIPT_VERIFY_STRICTENC)},
        {"DERSIG", static_cast<uint8_t>(SCRIPT_VERIFY_DERSIG)},
        {"LOW_S", static_cast<uint8_t>(SCRIPT_VERIFY_LOW_S)},
        {"NULLDUMMY", static_cast<uint8_t>(SCRIPT_VERIFY_NULLDUMMY)},
        {"SIGPUSHONLY", static_cast<uint8_t>(SCRIPT_VERIFY_SIGPUSHONLY)},
        {"MINIMALDATA", static_cast<uint8_t>(SCRIPT_VERIFY_MINIMALDATA)},
        {"DISCOURAGE_NOPS", static_cast<uint8_t>(SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_NOPS)},
        {"CLEANSTACK", static_cast<uint8_t>(SCRIPT_VERIFY_CLEANSTACK)},
        {"CLTV", static_cast<uint8_t>(SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY)},
        {"CSV", static_cast<uint8_t>(SCRIPT_VERIFY_CHECKSEQUENCEVERIFY)},
        {"WITNESS", static_cast<uint8_t>(SCRIPT_VERIFY_WITNESS)},
        {"DISCOURAGE_WITNESS", static_cast<uint8_t>(SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM)},
        {"MINIMALIF", static_cast<uint8_t>(SCRIPT_VERIFY_MINIMALIF)},
        {"NULLFAIL", static_cast<uint8_t>(SCRIPT_VERIFY_NULLFAIL)},
        {"WITNESS_PUBKEYTYPE", static_cast<uint8_t>(SCRIPT_VERIFY_WITNESS_PUBKEYTYPE)},
        {"CONST_SCRIPTCODE", static_cast<uint8_t>(SCRIPT_VERIFY_CONST_SCRIPTCODE)},
        {"TAPROOT", static_cast<uint8_t>(SCRIPT_VERIFY_TAPROOT)},
    };
    for (const auto& r : rows) {
        std::printf("%-20s bit=%2u mask=0x%05llx\n", r.name, r.bit,
                    1ull << r.bit);
    }
    return 0;
}
