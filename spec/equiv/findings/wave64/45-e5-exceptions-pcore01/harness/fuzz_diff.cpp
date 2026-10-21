// Deterministic differential fuzz driver: unpatched Core C leg vs patched
// variants, both loaded with dlopen.  Prototype only; not a proof artifact.
//
// The generator is biased toward the paths P-CORE-01/02/03 can affect:
//   * numeric opcodes with 4/5/6..10-byte and negative-zero operands,
//   * MINIMALDATA on/off (fRequireMinimal true/false),
//   * stack opcodes that can feed numeric conversions,
//   * generic random opcode streams for error-precedence differences.
//
// Every case builds one spending transaction tape (no witness) and calls each
// library with the identical buffer.  Comparison is exact on
// (result, error_kind).
//
// Usage:
//   fuzz_diff --baseline LIB --variant name=path [--variant ...]
//             --n 1000000 --seed 0x... --out summary.json
//
// Exit 0 iff zero divergences.

#include <cinttypes>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <dlfcn.h>
#include <openssl/sha.h>
#include <string>
#include <vector>
#include <algorithm>
#include <map>

#ifndef GENERATOR_SHA256
#define GENERATOR_SHA256 "unset"
#endif

using Entry = int (*)(const uint8_t*, uint64_t, const uint8_t*, uint64_t,
                      int64_t, uint32_t, uint64_t, int*);

struct Leg {
    std::string name;
    void* handle{nullptr};
    Entry fn{nullptr};
    std::string sha256;
};

static uint64_t splitmix64(uint64_t& x)
{
    uint64_t z = (x += 0x9e3779b97f4a7c15ULL);
    z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9ULL;
    z = (z ^ (z >> 27)) * 0x94d049bb133111ebULL;
    return z ^ (z >> 31);
}

static void put_u32(std::vector<uint8_t>& v, uint32_t x)
{
    for (int i = 0; i < 4; ++i) v.push_back(uint8_t(x >> (8 * i)));
}
static void put_i64(std::vector<uint8_t>& v, int64_t x)
{
    for (int i = 0; i < 8; ++i) v.push_back(uint8_t(uint64_t(x) >> (8 * i)));
}
static void put_varint(std::vector<uint8_t>& v, uint64_t n)
{
    if (n < 0xFD) { v.push_back(uint8_t(n)); return; }
    if (n <= 0xFFFF) { v.push_back(0xFD); v.push_back(uint8_t(n)); v.push_back(uint8_t(n >> 8)); return; }
    if (n <= 0xFFFFFFFFULL) {
        v.push_back(0xFE);
        for (int i = 0; i < 4; ++i) v.push_back(uint8_t(n >> (8 * i)));
        return;
    }
    v.push_back(0xFF);
    for (int i = 0; i < 8; ++i) v.push_back(uint8_t(n >> (8 * i)));
}

// Spending transaction with one input and one empty output, serialized
// without witness.  prevout hash is all zeros: no signature in this lane is
// expected to be valid, so only determinism matters.
static std::vector<uint8_t> build_tape(const std::vector<uint8_t>& script_sig,
                                       const std::vector<uint8_t>& spk)
{
    std::vector<uint8_t> v;
    put_u32(v, 1);                       // version
    put_varint(v, 1);                    // vin count
    v.insert(v.end(), 32, 0x00);         // prevout hash
    put_u32(v, 0);                       // prevout index
    put_varint(v, script_sig.size());
    v.insert(v.end(), script_sig.begin(), script_sig.end());
    put_u32(v, 0xFFFFFFFFu);             // sequence
    put_varint(v, 1);                    // vout count
    put_i64(v, 0);                       // value
    put_varint(v, spk.size());
    v.insert(v.end(), spk.begin(), spk.end());
    put_u32(v, 0);                       // locktime
    return v;
}

static const uint8_t NUM_OPS[] = {
    0x8b, 0x8c, 0x8f, 0x90, 0x91, 0x92,             // 1ADD 1SUB NEGATE ABS NOT 0NOTEQUAL
    0x93, 0x94, 0x9a, 0x9b, 0x9c, 0x9e,             // ADD SUB BOOLAND BOOLOR NUMEQUAL NUMNOTEQUAL
    0x9f, 0xa0, 0xa1, 0xa2, 0xa3, 0xa4, 0xa5,       // comparisons MIN MAX WITHIN
    0x9d,                                            // NUMEQUALVERIFY
};
static const uint8_t STACK_OPS[] = {
    0x69, 0x6b, 0x6c, 0x6d, 0x6e, 0x6f, 0x73, 0x74, 0x75, 0x76,
    0x77, 0x78, 0x79, 0x7a, 0x7b, 0x7c, 0x7d, 0x82, 0x63, 0x67, 0x68,
};

static void push_data(std::vector<uint8_t>& s, const std::vector<uint8_t>& d)
{
    if (d.empty()) { s.push_back(0x00); return; }
    s.push_back(uint8_t(d.size()));      // <= 75 bytes in this generator
    s.insert(s.end(), d.begin(), d.end());
}

// CScriptNum serialization (minimal little-endian, sign bit in high bit).
static std::vector<uint8_t> scriptnum(int64_t n)
{
    std::vector<uint8_t> out;
    if (n == 0) return out;
    bool neg = n < 0;
    uint64_t a = neg ? uint64_t(-(n + 1)) + 1 : uint64_t(n);
    while (a) { out.push_back(uint8_t(a & 0xFF)); a >>= 8; }
    if (out.back() & 0x80) out.push_back(neg ? 0x80 : 0x00);
    else if (neg) out.back() |= 0x80;
    return out;
}

struct Case {
    int tmpl{0};
    std::vector<uint8_t> script_sig;
    std::vector<uint8_t> spk;
    uint64_t flags{0};
    bool numeric_biased{false};
};

static std::vector<uint8_t> gen_operand(uint64_t& rng, int kind)
{
    switch (kind) {
    case 0: {  // canonical small/medium scriptnum
        int64_t v = int64_t(splitmix64(rng) % 2000001) - 1000000;
        return scriptnum(v);
    }
    case 1: {  // negative zero / one-byte high-bit
        uint8_t b = uint8_t(splitmix64(rng) & 0xFF);
        b |= 0x80;
        return {b};
    }
    case 2: {  // exactly 4 bytes, may be non-minimal
        std::vector<uint8_t> d(4);
        for (auto& x : d) x = uint8_t(splitmix64(rng));
        return d;
    }
    case 3: {  // exactly 5 bytes: always > nDefaultMaxNumSize
        std::vector<uint8_t> d(5);
        for (auto& x : d) x = uint8_t(splitmix64(rng));
        return d;
    }
    default: {  // 6..10 bytes
        size_t n = 6 + size_t(splitmix64(rng) % 5);
        std::vector<uint8_t> d(n);
        for (auto& x : d) x = uint8_t(splitmix64(rng));
        return d;
    }
    }
}

static Case gen_case(uint64_t& rng)
{
    Case c;
    uint64_t r = splitmix64(rng);
    c.tmpl = int(r % 7);
    c.flags = ((splitmix64(rng) & 1) ? 0x40ULL : 0ULL);  // MINIMALDATA on/off
    if ((splitmix64(rng) % 8) == 0) c.flags |= 0x4000ULL; // NULLFAIL rarely
    c.numeric_biased = true;

    auto operand = [&](void) {
        int kind = int(splitmix64(rng) % 5);
        if (kind == 0 && (splitmix64(rng) % 3) == 0) kind = 3;
        return gen_operand(rng, kind);
    };

    std::vector<uint8_t> s;
    switch (c.tmpl) {
    case 0: {  // unary numeric
        push_data(s, operand());
        s.push_back(NUM_OPS[splitmix64(rng) % 6]);
        break;
    }
    case 1: {  // binary numeric
        push_data(s, operand());
        push_data(s, operand());
        static const uint8_t bin[] = {0x93,0x94,0x9a,0x9b,0x9c,0x9e,0x9f,0xa0,0xa1,0xa2,0xa3,0xa4};
        s.push_back(bin[splitmix64(rng) % sizeof(bin)]);
        break;
    }
    case 2: {  // ternary numeric (WITHIN) or NUMEQUALVERIFY
        if (splitmix64(rng) & 1) {
            push_data(s, operand());
            push_data(s, operand());
            push_data(s, operand());
            s.push_back(0xa5);  // WITHIN
        } else {
            push_data(s, operand());
            push_data(s, operand());
            s.push_back(0x9d);  // NUMEQUALVERIFY
        }
        break;
    }
    case 3: {  // stack op feeding a later numeric conversion
        push_data(s, operand());
        push_data(s, operand());
        s.push_back(STACK_OPS[splitmix64(rng) % sizeof(STACK_OPS)]);
        if (splitmix64(rng) & 1) push_data(s, operand());
        s.push_back(NUM_OPS[splitmix64(rng) % sizeof(NUM_OPS)]);
        break;
    }
    case 5: {  // CHECKSIG: exercises the P-CORE-02 hook with invalid sigs
        size_t sig_len = 8 + size_t(splitmix64(rng) % 65);
        size_t pk_len = (splitmix64(rng) & 1) ? 33 : 65;
        std::vector<uint8_t> sig(sig_len), pk(pk_len);
        for (auto& x : sig) x = uint8_t(splitmix64(rng));
        for (auto& x : pk) x = uint8_t(splitmix64(rng));
        push_data(s, sig);
        push_data(s, pk);
        s.push_back(0xac);  // OP_CHECKSIG
        c.numeric_biased = false;
        break;
    }
    case 6: {  // CHECKLOCKTIMEVERIFY / CHECKSEQUENCEVERIFY: P-CORE-02 hooks
        push_data(s, operand());
        if (splitmix64(rng) & 1) {
            s.push_back(0xb1);  // CLTV
            c.flags |= 0x200ULL;
        } else {
            s.push_back(0xb2);  // CSV
            c.flags |= 0x400ULL;
        }
        break;
    }
    default: {  // generic random opcode stream
        size_t n = 1 + size_t(splitmix64(rng) % 24);
        for (size_t i = 0; i < n; ++i) {
            if (splitmix64(rng) & 1) {
                s.push_back(STACK_OPS[splitmix64(rng) % sizeof(STACK_OPS)]);
            } else {
                s.push_back(NUM_OPS[splitmix64(rng) % sizeof(NUM_OPS)]);
            }
        }
        c.numeric_biased = false;
        break;
    }
    }

    // Alternate which field carries the script; both are executed by
    // VerifyScript for non-P2SH flags.
    if (splitmix64(rng) & 1) c.spk = std::move(s);
    else c.script_sig = std::move(s);
    return c;
}

int main(int argc, char** argv)
{
    std::string baseline_path, out_path, seed_str = "0x16b10";
    uint64_t n = 100000;
    std::vector<std::pair<std::string, std::string>> variants;
    for (int i = 1; i < argc; ++i) {
        std::string a = argv[i];
        auto next = [&](void) -> std::string { return argv[++i]; };
        if (a == "--baseline") baseline_path = next();
        else if (a == "--variant") {
            std::string v = next();
            auto p = v.find('=');
            variants.emplace_back(v.substr(0, p), v.substr(p + 1));
        } else if (a == "--n") n = std::strtoull(next().c_str(), nullptr, 0);
        else if (a == "--seed") seed_str = next();
        else if (a == "--out") out_path = next();
        else { std::fprintf(stderr, "unknown arg %s\n", a.c_str()); return 2; }
    }
    if (baseline_path.empty() || out_path.empty()) {
        std::fprintf(stderr, "need --baseline and --out\n");
        return 2;
    }
    uint64_t seed = std::strtoull(seed_str.c_str(), nullptr, 0);

    auto load = [&](const std::string& name, const std::string& path) -> Leg {
        Leg leg;
        leg.name = name;
        leg.handle = dlopen(path.c_str(), RTLD_NOW | RTLD_LOCAL);
        if (!leg.handle) {
            std::fprintf(stderr, "dlopen %s: %s\n", path.c_str(), dlerror());
            std::exit(2);
        }
        leg.fn = reinterpret_cast<Entry>(dlsym(leg.handle, "equiv_entry"));
        if (!leg.fn) {
            std::fprintf(stderr, "dlsym equiv_entry in %s failed\n", path.c_str());
            std::exit(2);
        }
        char cmd[4096];
        std::snprintf(cmd, sizeof(cmd), "sha256sum '%s'", path.c_str());
        FILE* p = popen(cmd, "r");
        char buf[128] = {0};
        if (p) { if (fgets(buf, sizeof(buf), p)) leg.sha256 = buf; pclose(p); }
        if (!leg.sha256.empty() && leg.sha256.back() == '\n') leg.sha256.pop_back();
        auto space = leg.sha256.find(' ');
        if (space != std::string::npos) leg.sha256.resize(space);
        return leg;
    };

    Leg baseline = load("baseline", baseline_path);
    std::vector<Leg> legs;
    for (auto& v : variants) legs.push_back(load(v.first, v.second));

    SHA256_CTX corpus_ctx;
    SHA256_Init(&corpus_ctx);

    uint64_t rng = seed;
    uint64_t divergences = 0, cases_with_divergence = 0;
    uint64_t in_domain = 0, out_domain = 0, internal = 0;
    std::map<std::string, uint64_t> per_variant_div;
    std::map<std::string, uint64_t> kind_hist;
    std::map<int, uint64_t> tmpl_hist;
    std::vector<std::string> samples;
    std::vector<std::vector<std::pair<int,int>>> results(legs.size());
    for (auto& r : results) r.resize(n);
    std::vector<int> tmpls(n);
    std::vector<uint64_t> flagsv(n);

    for (uint64_t i = 0; i < n; ++i) {
        Case c = gen_case(rng);
        tmpls[i] = c.tmpl;
        flagsv[i] = c.flags;
        tmpl_hist[c.tmpl]++;
        std::vector<uint8_t> tape = build_tape(c.script_sig, c.spk);
        // Corpus digest: length-prefixed (tape, spk, amount, flags) per case.
        {
            uint8_t lens[32];
            uint64_t tl = tape.size(), sl = c.spk.size();
            for (int k = 0; k < 8; ++k) {
                lens[k] = uint8_t(tl >> (8 * k));
                lens[8 + k] = uint8_t(sl >> (8 * k));
                lens[16 + k] = 0;  // amount is 0 in this lane
                lens[24 + k] = uint8_t(c.flags >> (8 * k));
            }
            SHA256_Update(&corpus_ctx, lens, sizeof(lens));
            SHA256_Update(&corpus_ctx, tape.data(), tape.size());
            SHA256_Update(&corpus_ctx, c.spk.data(), c.spk.size());
        }
        const uint8_t* spk = c.spk.empty() ? nullptr : c.spk.data();
        int base_kind = -1;
        int base_res = baseline.fn(tape.data(), tape.size(), spk, c.spk.size(),
                                   0, 0, c.flags, &base_kind);
        if (base_res == 1 || base_res == 0) in_domain++;
        else if (base_res == 3) internal++;
        else out_domain++;
        kind_hist[std::to_string(base_kind)]++;
        bool case_div = false;
        for (size_t j = 0; j < legs.size(); ++j) {
            int kind = -1;
            int res = legs[j].fn(tape.data(), tape.size(), spk, c.spk.size(),
                                 0, 0, c.flags, &kind);
            results[j][i] = {res, kind};
            if (res != base_res || kind != base_kind) {
                divergences++;
                per_variant_div[legs[j].name]++;
                case_div = true;
                if (samples.size() < 30) {
                    char line[512];
                    std::snprintf(line, sizeof(line),
                        "variant=%s i=%" PRIu64 " tmpl=%d flags=0x%" PRIx64
                        " base=(%d,%d) var=(%d,%d) spk_len=%zu ss_len=%zu",
                        legs[j].name.c_str(), i, c.tmpl, c.flags,
                        base_res, base_kind, res, kind,
                        c.spk.size(), c.script_sig.size());
                    samples.emplace_back(line);
                }
            }
        }
        if (case_div) cases_with_divergence++;
    }

    unsigned char corpus_digest[SHA256_DIGEST_LENGTH];
    SHA256_Final(corpus_digest, &corpus_ctx);
    char corpus_hex[SHA256_DIGEST_LENGTH * 2 + 1];
    for (int k = 0; k < SHA256_DIGEST_LENGTH; ++k)
        std::snprintf(corpus_hex + 2 * k, 3, "%02x", corpus_digest[k]);

    FILE* f = std::fopen(out_path.c_str(), "w");
    if (!f) { std::perror("fopen out"); return 2; }
    std::fprintf(f, "{\n");
    std::fprintf(f, "  \"seed\": \"%s\",\n", seed_str.c_str());
    std::fprintf(f, "  \"n\": %" PRIu64 ",\n", n);
    std::fprintf(f, "  \"corpus_sha256\": \"%s\",\n", corpus_hex);
    std::fprintf(f, "  \"generator_source_sha256\": \"%s\",\n", GENERATOR_SHA256);
    std::fprintf(f, "  \"baseline\": {\"path\": \"%s\", \"sha256\": \"%s\"},\n",
                 baseline_path.c_str(), baseline.sha256.c_str());
    std::fprintf(f, "  \"variants\": {\n");
    for (size_t j = 0; j < legs.size(); ++j) {
        std::fprintf(f, "    \"%s\": {\"path\": \"%s\", \"sha256\": \"%s\", "
                        "\"divergent_cases\": %" PRIu64 "}%s\n",
                     legs[j].name.c_str(), variants[j].second.c_str(),
                     legs[j].sha256.c_str(), per_variant_div[legs[j].name],
                     (j + 1 == legs.size()) ? "" : ",");
    }
    std::fprintf(f, "  },\n");
    std::fprintf(f, "  \"divergent_case_calls\": %" PRIu64 ",\n", divergences);
    std::fprintf(f, "  \"cases_with_divergence\": %" PRIu64 ",\n", cases_with_divergence);
    std::fprintf(f, "  \"baseline_domain\": {\"in\": %" PRIu64 ", \"out\": %" PRIu64
                    ", \"internal\": %" PRIu64 "},\n",
                 in_domain, out_domain, internal);
    std::fprintf(f, "  \"templates\": {");
    bool first = true;
    for (auto& kv : tmpl_hist) {
        std::fprintf(f, "%s\"%d\": %" PRIu64, first ? "" : ", ", kv.first, kv.second);
        first = false;
    }
    std::fprintf(f, "},\n");
    std::fprintf(f, "  \"baseline_error_kind_histogram\": {");
    first = true;
    for (auto& kv : kind_hist) {
        std::fprintf(f, "%s\"%s\": %" PRIu64, first ? "" : ", ", kv.first.c_str(), kv.second);
        first = false;
    }
    std::fprintf(f, "},\n");
    std::fprintf(f, "  \"divergence_samples\": [\n");
    for (size_t i = 0; i < samples.size(); ++i) {
        std::fprintf(f, "    \"%s\"%s\n", samples[i].c_str(),
                     i + 1 == samples.size() ? "" : ",");
    }
    std::fprintf(f, "  ],\n");
    std::fprintf(f, "  \"result\": \"%s\"\n",
                 divergences == 0 ? "zero-divergence" : "DIVERGENCE");
    std::fprintf(f, "}\n");
    std::fclose(f);
    std::printf("n=%" PRIu64 " divergent_calls=%" PRIu64
                " cases_with_divergence=%" PRIu64 " in=%" PRIu64
                " out=%" PRIu64 " internal=%" PRIu64 "\n",
                n, divergences, cases_with_divergence, in_domain, out_domain, internal);
    return divergences == 0 ? 0 : 1;
}
