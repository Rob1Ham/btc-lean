// C-side witness for the Wave-64 / SCR-112 F-DIV finding.
//
// This program includes the REAL pinned Bitcoin Core header
//   <pubkey.h> @ cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
// and calls the actual CPubKey constructor / IsValid() on each witness.
// The Lean-model column is a direct transliteration of
//   spec/core/Bitcoin/Crypto/Seam/Der.lean:162-175
// (`pubKeyLen`, `isValidPubKey`), which is *not* patched here: the point
// of the finding is that this definition is header-only.
//
// Core anchors (pinned):
//   src/pubkey.h:69-76   CPubKey::GetLen
//   src/pubkey.h:79-82   CPubKey::Invalidate
//   src/pubkey.h:86-88   CPubKey::ValidSize
//   src/pubkey.h:98-105  CPubKey::Set
//   src/pubkey.h:121     CPubKey::size()  (GetLen(vch[0]))
//   src/pubkey.h:194-197 CPubKey::IsValid()  (size() > 0)
//
// Build/run via ./run.sh; output is captured in c_core_pubkey.out.

#include <pubkey.h>

#include <cstdint>
#include <cstdio>
#include <string>
#include <vector>

namespace {

// ---- Lean model (transliteration, spec/core/Bitcoin/Crypto/Seam/Der.lean) ----

unsigned leanPubKeyLen(const std::vector<unsigned char>& pk) {
    if (pk.size() == 0) return 0;
    if (pk[0] == 0x02 || pk[0] == 0x03) return 33;
    if (pk[0] == 0x04 || pk[0] == 0x06 || pk[0] == 0x07) return 65;
    return 0;
}

bool leanIsValidPubKey(const std::vector<unsigned char>& pk) {
    return leanPubKeyLen(pk) != 0;
}

// ---- output helpers ----

std::string hexPrefix(const std::vector<unsigned char>& v) {
    static const char* d = "0123456789abcdef";
    std::string s;
    const std::size_t n = v.size() < 6 ? v.size() : 6;
    for (std::size_t i = 0; i < n; ++i) {
        s.push_back(d[v[i] >> 4]);
        s.push_back(d[v[i] & 0xf]);
        if (i + 1 != n) s.push_back(' ');
    }
    if (v.size() > n) s += " ..";
    return s;
}

void row(const char* label, const std::vector<unsigned char>& v) {
    const CPubKey core(v);              // actual pinned CPubKey::Set
    const bool coreValid = core.IsValid();
    const bool leanValid = leanIsValidPubKey(v);
    std::printf("pk=%-28s len=%-3zu core.IsValid=%d core.size=%-3u lean.isValidPubKey=%d %s\n",
                label, v.size(), coreValid ? 1 : 0, core.size(),
                leanValid ? 1 : 0,
                coreValid == leanValid ? "agree" : "DIVERGE");
}

std::vector<unsigned char> filled(std::size_t n, unsigned char first,
                                  unsigned char rest) {
    std::vector<unsigned char> v(n, rest);
    if (n) v[0] = first;
    return v;
}

}  // namespace

int main() {
    std::printf("# Core pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66\n");
    std::printf("# Core header: src/pubkey.h (CPubKey::Set / IsValid)\n");
    std::printf("# Lean model: spec/core/Bitcoin/Crypto/Seam/Der.lean:162-175\n");

    row("02 (1B)", {0x02});
    row("04 (1B)", {0x04});
    row("03 (32B)", filled(32, 0x03, 0x00));
    row("02+00*32 (33B)", filled(33, 0x02, 0x00));
    row("03+00*32 (33B)", filled(33, 0x03, 0x00));
    row("02+00*33 (34B)", filled(34, 0x02, 0x00));
    row("04+00*32 (33B)", filled(33, 0x04, 0x00));
    row("04+00*63 (64B)", filled(64, 0x04, 0x00));
    row("04+00*64 (65B)", filled(65, 0x04, 0x00));
    row("06+00*64 (65B)", filled(65, 0x06, 0x00));
    row("07+00*64 (65B)", filled(65, 0x07, 0x00));
    row("02+00*64 (65B)", filled(65, 0x02, 0x00));
    row("05+00*32 (33B)", filled(33, 0x05, 0x00));
    row("ff (1B)", {0xff});
    row("empty", {});
    return 0;
}
