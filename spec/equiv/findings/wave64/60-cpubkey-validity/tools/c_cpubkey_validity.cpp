// Independent SCR-112 witness, C side.
//
// Includes the ACTUAL pinned Bitcoin Core header at
//   cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
// (src/pubkey.h) and exercises CPubKey::Set/ValidSize/IsValid directly.
// No reimplementation of GetLen/Set: these are the upstream definitions.
//
// Build/run: tools/run_c.sh
//   g++ -std=c++20 -I "$CORE/src" -I "$CORE/src/secp256k1/include"
//       c_cpubkey_validity.cpp -o c_cpubkey_validity
//
// Core anchors:
//   src/pubkey.h:69-76   CPubKey::GetLen
//   src/pubkey.h:79-82   CPubKey::Invalidate
//   src/pubkey.h:86-88   CPubKey::ValidSize
//   src/pubkey.h:98-105  CPubKey::Set  (header length MUST equal vector length)
//   src/pubkey.h:117     CPubKey::IsValid  (size() > 0, after Set)
//   src/script/interpreter.cpp:1704-1706  CPubKey pubkey(vchPubKey);
//                                        if (!pubkey.IsValid()) return false;
#include <pubkey.h>

#include <cstdint>
#include <cstdio>
#include <string>
#include <vector>

namespace {

int hexNibble(char c)
{
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

std::vector<unsigned char> fromHex(const std::string& s)
{
    std::vector<unsigned char> out;
    for (size_t i = 0; i + 1 < s.size(); i += 2) {
        int hi = hexNibble(s[i]);
        int lo = hexNibble(s[i + 1]);
        if (hi < 0 || lo < 0) return {};
        out.push_back(static_cast<unsigned char>((hi << 4) | lo));
    }
    return out;
}

std::string toHex(const std::vector<unsigned char>& v)
{
    static const char* d = "0123456789abcdef";
    std::string s;
    for (unsigned char b : v) {
        s.push_back(d[b >> 4]);
        s.push_back(d[b & 0x0f]);
    }
    return s;
}

struct Row {
    const char* label;
    std::string hex;
};

const std::vector<Row> kRows{
    {"empty", ""},
    {"badhdr-1B-01", "01"},
    {"min-1B-02", "02"},
    {"one-1B-04", "04"},
    {"two-2B-0400", "0400"},
    {"32B-02", "02" + std::string(62, '0')},
    {"33B-02", "02" + std::string(64, '0')},
    {"34B-02", "02" + std::string(66, '0')},
    {"64B-04", "04" + std::string(126, '0')},
    {"65B-04", "04" + std::string(128, '0')},
    {"66B-04", "04" + std::string(130, '0')},
    {"33B-04", "04" + std::string(64, '0')},
    {"65B-02", "02" + std::string(128, '0')},
    {"33B-06", "06" + std::string(64, '0')},
    {"65B-06", "06" + std::string(128, '0')},
    // A real compressed key (generator G): 33 bytes, 0x02 -- structurally
    // valid under both definitions.
    {"33B-02-G", "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"},
    // A real uncompressed key (generator G): 65 bytes, 0x04 -- valid under both.
    {"65B-04-G", "0479be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
                  "483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8"},
};

} // namespace

int main()
{
    // Column semantics:
    //   core_ValidSize  -- CPubKey::ValidSize(v) = size>0 && GetLen(v[0])==size
    //   core_IsValid    -- CPubKey(v).IsValid()  (Set() ran first)
    //   core_size       -- CPubKey(v).size() = GetLen(stored first byte)
    std::printf("label,hex,len,core_ValidSize,core_IsValid,core_size\n");
    for (const Row& r : kRows) {
        const std::vector<unsigned char> v = fromHex(r.hex);
        const bool vs = CPubKey::ValidSize(v);
        CPubKey key(v); // CPubKey(const std::vector&) -> Set(begin,end)
        const bool ok = key.IsValid();
        std::printf("%s,%s,%zu,%s,%s,%u\n",
                    r.label, toHex(v).c_str(), v.size(),
                    vs ? "true" : "false",
                    ok ? "true" : "false",
                    key.size());
    }
    return 0;
}
