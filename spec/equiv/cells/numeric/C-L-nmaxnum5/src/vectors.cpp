#include <cstdint>
#include <cstdio>

// Finite known-answer check for the numeric/C-L-nmaxnum5 leaf.
//
// Not a proof: the universality comes from Alive2 (C == L) and SAW (each leg
// == src/cell.cry).  This driver exists to catch a shared transcription error
// that an equality proof cannot see, by checking hand-computed Core vectors
// against *both* legs.  The vectors are the CScriptNum cases that decide the
// rule: the 5-byte accept boundary, the +-255 minimality exception, negative
// zero, the two 5-byte sign-extension encodings of +-2^31, the +-(2^39-1)
// extremes, the non-minimal 5-byte rejects, the width-6 reject, and the
// default-4 contrast on the same length-5 operand.

#define cell_cltv c_cell_cltv
#define cell_csv c_cell_csv
#define cell_default4 c_cell_default4
#include "c_leaf.cpp"
#undef cell_cltv
#undef cell_csv
#undef cell_default4

#define cell_cltv l_cell_cltv
#define cell_csv l_cell_csv
#define cell_default4 l_cell_default4
#include "l_leaf.cpp"
#undef cell_cltv
#undef cell_csv
#undef cell_default4

namespace {

struct Vec {
  const char* what;
  uint32_t len;
  uint8_t b[5];
  uint32_t md;
  uint32_t err;       // expected err(6)
  long long value;    // expected value40, sign-extended
  uint32_t cltv;      // expected CLTV outcome
  uint32_t csv;       // expected CSV outcome
};

constexpr Vec kVecs[] = {
    {"empty operand",                       0, {0, 0, 0, 0, 0},          0, 0, 0, 1, 1},
    {"empty operand, md on",                0, {0, 0, 0, 0, 0},          1, 0, 0, 1, 1},
    {"one byte 0x01",                       1, {0x01, 0, 0, 0, 0},       0, 0, 1, 1, 1},
    {"one byte 0x81 = -1",                  1, {0x81, 0, 0, 0, 0},       0, 21, -1, 0, 0},
    {"one byte 0x80 = negative zero",       1, {0x80, 0, 0, 0, 0},       0, 0, 0, 1, 1},
    {"0x80 non-minimal, md on",             1, {0x80, 0, 0, 0, 0},       1, 4, 0, 0, 0},
    {"+255 exception 0xff00",               2, {0xff, 0x00, 0, 0, 0},    1, 0, 255, 1, 1},
    {"-255 exception 0xff80",               2, {0xff, 0x80, 0, 0, 0},    1, 21, -255, 0, 0},
    {"zero zero, md on",                    2, {0x00, 0x00, 0, 0, 0},    1, 4, 0, 0, 0},
    {"0x8000 = 32768",                      3, {0x00, 0x80, 0x00, 0, 0}, 1, 0, 32768, 1, 1},
    {"4-byte max 2^31-1",                   4, {0xff, 0xff, 0xff, 0x7f, 0}, 1, 0, 2147483647LL, 1, 1},
    {"5-byte +2^31",                        5, {0x00, 0x00, 0x00, 0x80, 0x00}, 1, 0, 2147483648LL, 1, 2},
    {"5-byte -2^31",                        5, {0x00, 0x00, 0x00, 0x80, 0x80}, 1, 21, -2147483648LL, 0, 0},
    {"5-byte max 2^39-1",                   5, {0xff, 0xff, 0xff, 0xff, 0x7f}, 1, 0, 549755813887LL, 1, 2},
    {"5-byte min -(2^39-1)",                5, {0xff, 0xff, 0xff, 0xff, 0xff}, 1, 21, -549755813887LL, 0, 0},
    {"5-byte zero, md on (non-minimal)",    5, {0x00, 0x00, 0x00, 0x00, 0x00}, 1, 4, 0, 0, 0},
    {"5-byte zero, md off",                 5, {0x00, 0x00, 0x00, 0x00, 0x00}, 0, 0, 0, 1, 1},
    {"5-byte 2^31-1 padded, md on",         5, {0xff, 0xff, 0xff, 0x7f, 0x00}, 1, 4, 0, 0, 0},
    {"5-byte -0, md on (non-minimal)",      5, {0x00, 0x00, 0x00, 0x00, 0x80}, 1, 4, 0, 0, 0},
    {"5-byte +2^31, md off",                5, {0x00, 0x00, 0x00, 0x80, 0x00}, 0, 0, 2147483648LL, 1, 2},
    {"6-byte operand",                      6, {0x01, 0x00, 0x00, 0x00, 0x00}, 0, 4, 0, 0, 0},
    {"uint32 max length",        0xffffffffu, {0x01, 0x00, 0x00, 0x00, 0x00}, 1, 4, 0, 0, 0},
};

constexpr Vec kDefault4[] = {
    {"default-4 rejects length 5 (special-case contrast)", 5, {0x00, 0x00, 0x00, 0x80, 0x00}, 1, 4, 0, 0, 0},
    {"default-4 rejects length 5, md off",                 5, {0x00, 0x00, 0x00, 0x80, 0x00}, 0, 4, 0, 0, 0},
    {"default-4 accepts 4-byte max",                       4, {0xff, 0xff, 0xff, 0x7f, 0},  1, 0, 2147483647LL, 0, 0},
    {"default-4 accepts 2-byte -255",                      2, {0xff, 0x80, 0, 0, 0},        1, 0, -255, 0, 0},
};

long long sign40(uint64_t r) {
  const uint64_t v = (r >> 6) & 0xffffffffffULL;
  return static_cast<long long>(static_cast<int64_t>(v << 24) >> 24);
}

int fail = 0;

void check(const char* leg, const char* fn, const Vec& v, uint64_t r,
           uint32_t want_out) {
  const uint32_t err = static_cast<uint32_t>(r & 0x3fu);
  const long long val = sign40(r);
  const uint32_t out = static_cast<uint32_t>((r >> 46) & 0x3u);
  if (err != v.err || val != v.value || out != want_out) {
    ++fail;
    std::printf("FAIL %s %-12s len=%u b=%02x%02x%02x%02x%02x md=%u -> "
                "err=%u val=%lld out=%u, want err=%u val=%lld out=%u  (%s)\n",
                leg, fn, v.len, v.b[4], v.b[3], v.b[2], v.b[1], v.b[0], v.md,
                err, val, out, v.err, v.value, want_out, v.what);
  }
}

}  // namespace

int main() {
  std::printf("# numeric/C-L-nmaxnum5 finite known-answer vectors\n");
  std::printf("# columns: leg len bytes(be) md err value cltv csv\n");
  for (const Vec& v : kVecs) {
    const uint64_t rc = c_cell_cltv(v.len, v.b[0], v.b[1], v.b[2], v.b[3],
                                    v.b[4], v.md);
    const uint64_t rl = l_cell_cltv(v.len, v.b[0], v.b[1], v.b[2], v.b[3],
                                    v.b[4], v.md);
    const uint64_t sc = c_cell_csv(v.len, v.b[0], v.b[1], v.b[2], v.b[3],
                                   v.b[4], v.md);
    const uint64_t sl = l_cell_csv(v.len, v.b[0], v.b[1], v.b[2], v.b[3],
                                   v.b[4], v.md);
    std::printf("cltv C len=%u b=%02x%02x%02x%02x%02x md=%u err=%u val=%lld "
                "out=%u  %s\n",
                v.len, v.b[4], v.b[3], v.b[2], v.b[1], v.b[0], v.md,
                static_cast<uint32_t>(rc & 0x3fu), sign40(rc),
                static_cast<uint32_t>((rc >> 46) & 0x3u), v.what);
    std::printf("cltv L len=%u b=%02x%02x%02x%02x%02x md=%u err=%u val=%lld "
                "out=%u  %s\n",
                v.len, v.b[4], v.b[3], v.b[2], v.b[1], v.b[0], v.md,
                static_cast<uint32_t>(rl & 0x3fu), sign40(rl),
                static_cast<uint32_t>((rl >> 46) & 0x3u), v.what);
    std::printf("csv  C len=%u b=%02x%02x%02x%02x%02x md=%u err=%u val=%lld "
                "out=%u  %s\n",
                v.len, v.b[4], v.b[3], v.b[2], v.b[1], v.b[0], v.md,
                static_cast<uint32_t>(sc & 0x3fu), sign40(sc),
                static_cast<uint32_t>((sc >> 46) & 0x3u), v.what);
    std::printf("csv  L len=%u b=%02x%02x%02x%02x%02x md=%u err=%u val=%lld "
                "out=%u  %s\n",
                v.len, v.b[4], v.b[3], v.b[2], v.b[1], v.b[0], v.md,
                static_cast<uint32_t>(sl & 0x3fu), sign40(sl),
                static_cast<uint32_t>((sl >> 46) & 0x3u), v.what);
    if (rc != rl) {
      ++fail;
      std::printf("FAIL C/L mismatch on cltv for %s\n", v.what);
    }
    if (sc != sl) {
      ++fail;
      std::printf("FAIL C/L mismatch on csv for %s\n", v.what);
    }
    check("C", "cell_cltv", v, rc, v.cltv);
    check("L", "cell_cltv", v, rl, v.cltv);
    check("C", "cell_csv", v, sc, v.csv);
    check("L", "cell_csv", v, sl, v.csv);
  }
  for (const Vec& v : kDefault4) {
    const uint64_t rc = c_cell_default4(v.len, v.b[0], v.b[1], v.b[2], v.b[3],
                                        v.b[4], v.md);
    const uint64_t rl = l_cell_default4(v.len, v.b[0], v.b[1], v.b[2], v.b[3],
                                        v.b[4], v.md);
    std::printf("def4 C len=%u b=%02x%02x%02x%02x%02x md=%u err=%u val=%lld  %s\n",
                v.len, v.b[4], v.b[3], v.b[2], v.b[1], v.b[0], v.md,
                static_cast<uint32_t>(rc & 0x3fu), sign40(rc), v.what);
    std::printf("def4 L len=%u b=%02x%02x%02x%02x%02x md=%u err=%u val=%lld  %s\n",
                v.len, v.b[4], v.b[3], v.b[2], v.b[1], v.b[0], v.md,
                static_cast<uint32_t>(rl & 0x3fu), sign40(rl), v.what);
    if (rc != rl) {
      ++fail;
      std::printf("FAIL C/L mismatch on default4 for %s\n", v.what);
    }
    check("C", "cell_default4", v, rc, v.cltv);
    check("L", "cell_default4", v, rl, v.cltv);
  }
  std::printf("vectors=%zu default4=%zu failures=%d\n",
              sizeof(kVecs) / sizeof(kVecs[0]),
              sizeof(kDefault4) / sizeof(kDefault4[0]), fail);
  return fail == 0 ? 0 : 1;
}
