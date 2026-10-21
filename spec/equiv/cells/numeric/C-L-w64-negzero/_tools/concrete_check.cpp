#include <cstdint>
#include <cstdio>

// Concrete corner vectors for SCR-083, run against each leg separately.
// The output is byte-compared between c_cell.cpp and l_cell.cpp by
// concrete_check.sh, so this is a behavioural spot check, not a proof.
extern "C" uint64_t cell_negzero(uint8_t b0, uint8_t b1, uint8_t b2, uint8_t b3,
                                 uint32_t len);

struct Vec {
  const char* name;
  uint8_t b[4];
  uint32_t len;
};

static const Vec kVecs[] = {
    {"empty", {0x00, 0x00, 0x00, 0x00}, 0},
    {"neg-zero-1", {0x80, 0x00, 0x00, 0x00}, 1},
    {"zero-1", {0x00, 0x00, 0x00, 0x00}, 1},
    {"one-1", {0x01, 0x00, 0x00, 0x00}, 1},
    {"neg-zero-2", {0x00, 0x80, 0x00, 0x00}, 2},
    {"neg-zero-3", {0x00, 0x00, 0x80, 0x00}, 3},
    {"neg-zero-4", {0x00, 0x00, 0x00, 0x80}, 4},
    {"plus-128-2", {0x80, 0x00, 0x00, 0x00}, 2},
    {"minus-127-1", {0xff, 0x00, 0x00, 0x00}, 1},
    {"minus-255-2", {0xff, 0x80, 0x00, 0x00}, 2},
    {"max-int32", {0xff, 0xff, 0xff, 0x7f}, 4},
    {"minus-max", {0xff, 0xff, 0xff, 0xff}, 4},
    {"len5-reject", {0x00, 0x00, 0x00, 0x00}, 5},
};

int main() {
  for (const Vec& v : kVecs) {
    const uint64_t r = cell_negzero(v.b[0], v.b[1], v.b[2], v.b[3], v.len);
    std::printf("%-14s len=%u bytes=%02x%02x%02x%02x err=%u value=%d cast=%u "
                "packed=0x%016llx\n",
                v.name, v.len, v.b[0], v.b[1], v.b[2], v.b[3],
                static_cast<unsigned>(r & 0xffu),
                static_cast<int32_t>((r >> 8) & 0xffffffffu),
                static_cast<unsigned>((r >> 40) & 1u),
                static_cast<unsigned long long>(r));
  }
  return 0;
}
