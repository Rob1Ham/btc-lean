// C leg: byte-level source-excerpt slice of the BIP341 TapLeaf construction at
// Bitcoin Core cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
//   src/script/interpreter.cpp:1882-1884
//     uint256 ComputeTapleafHash(uint8_t leaf_version,
//                                std::span<const unsigned char> script)
//     {
//       return (HashWriter{HASHER_TAPLEAF} << leaf_version
//               << CompactSizeWriter(script.size()) << script).GetSHA256();
//     }
//
//   src/script/interpreter.cpp:1983 (call site)
//     ComputeTapleafHash(control[0] & TAPROOT_LEAF_MASK, script)
//
//   src/script/interpreter.cpp:1477
//     const HashWriter HASHER_TAPLEAF{TaggedHash("TapLeaf")};
//   src/hash.cpp:85-91
//     HashWriter TaggedHash(const std::string& tag) {
//       HashWriter writer{};
//       uint256 taghash;
//       CSHA256().Write((const unsigned char*)tag.data(), tag.size())
//                .Finalize(taghash.begin());
//       writer << taghash << taghash;
//       return writer;
//     }
//   src/hash.h:108-142
//     HashWriter has one CSHA256 ctx; `write` feeds it, `GetSHA256` Finalizes.
//   src/uint256.h:110-114
//     base_blob::Serialize writes the 32 stored bytes raw (no length prefix).
//
// So the stream handed to the SHA256 context is exactly
//
//   pre(v, s) = H("TapLeaf") || H("TapLeaf") || serU8(v) || CS(|s|) || s
//
// with H the (named, opaque) SHA256 oracle.  This cell proves every byte of
// that stream, the 64-byte tag-prefix structure, the mask, and the
// CompactSize placement.  H itself is NOT modelled: no digest is computed,
// and no CSHA256 call appears in this file.
//
// The tag digest T = H("TapLeaf") is passed to the cell as four opaque
// little-endian 64-bit words t0..t3 (bytes 0..31).  Nothing about T is
// assumed except that it is one 32-byte value; both copies of the prefix are
// read from those same four words, so the cell proves that one value is
// duplicated, not that two independent hashes happen to agree.
//
// Observable packing (cell harness, not preimage content):
//   cell_tag_byte(i)     bit8 = i < 7, low byte = tag string byte i
//   cell_prefix_byte(i)  bit8 = i < 64, low byte = prefix byte i
//   cell_leaf_mask(c)    byte0 = c&0xfe, byte1 = c&1 (parity)
//   cell_cs_byte(n,j)    bit8 = j < CompactSize size, low byte = encoding byte j
//   cell_field_kind(i)   field code at preimage offset i (see below)
//   cell_field_index(i)  index within the field at preimage offset i
//   cell_preimage_byte   exact byte i of the composed preimage, len <= 4
//   cell_preimage_len    exact total preimage length, len <= 4

#include <cstdint>

// Defined wrapping subtraction.  Cell arithmetic is total: offsets are formed
// with this helper so the compiler cannot attach `nuw` and create a poison
// value on a path that is merely predicted, not taken (SAW/Alive2 both reject
// poison creation, and a speculative `sub nuw` is exactly that).
static inline __attribute__((always_inline)) uint64_t sub_u64(uint64_t a,
                                                              uint64_t b) {
  uint64_t r;
  (void)__builtin_sub_overflow(a, b, &r);
  return r;
}

static inline __attribute__((always_inline)) uint64_t add_u64(uint64_t a,
                                                              uint64_t b) {
  uint64_t r;
  (void)__builtin_add_overflow(a, b, &r);
  return r;
}

// Field codes shared by cell_field_kind / cell_field_index (harness):
//   0 = first copy of T       (offset 0..31)
//   1 = second copy of T      (offset 32..63)
//   2 = masked leaf version   (offset 64)
//   3 = CompactSize byte      (offset 65..65+cs-1)
//   4 = script byte           (offset 65+cs .. 65+cs+len-1)
//   5 = past the end of the preimage
enum : uint8_t {
  FIELD_TAG0 = 0,
  FIELD_TAG1 = 1,
  FIELD_VERSION = 2,
  FIELD_CS = 3,
  FIELD_SCRIPT = 4,
  FIELD_END = 5
};

// CompactSize length, serialize.h:301-323.
static inline __attribute__((always_inline)) uint64_t cs_size(uint64_t n) {
  if (n < 0xfdULL) return 1;
  if (n <= 0xffffULL) return 3;
  if (n <= 0xffffffffULL) return 5;
  return 9;
}

// Byte j of WriteCompactSize(n) (serialize.h:301-323), zero outside the
// encoding.  ser_writedata16/32/64 are little-endian (serialize.h:57-80).
static inline __attribute__((always_inline)) uint8_t cs_byte(uint64_t n, uint32_t j) {
  const uint64_t sz = cs_size(n);
  if ((uint64_t)j >= sz) return 0;
  if (n < 0xfdULL) {
    return (uint8_t)n;
  }
  if (n <= 0xffffULL) {
    if (j == 0) return 0xfd;
    if (j == 1) return (uint8_t)n;
    return (uint8_t)(n >> 8);
  }
  if (n <= 0xffffffffULL) {
    if (j == 0) return 0xfe;
    if (j == 1) return (uint8_t)n;
    if (j == 2) return (uint8_t)(n >> 8);
    if (j == 3) return (uint8_t)(n >> 16);
    return (uint8_t)(n >> 24);
  }
  if (j == 0) return 0xff;
  if (j == 1) return (uint8_t)n;
  if (j == 2) return (uint8_t)(n >> 8);
  if (j == 3) return (uint8_t)(n >> 16);
  if (j == 4) return (uint8_t)(n >> 24);
  if (j == 5) return (uint8_t)(n >> 32);
  if (j == 6) return (uint8_t)(n >> 40);
  if (j == 7) return (uint8_t)(n >> 48);
  return (uint8_t)(n >> 56);
}

// Byte j (0..31) of the opaque tag digest T, passed as four LE words.
static inline __attribute__((always_inline)) uint8_t t_byte(uint64_t t0, uint64_t t1, uint64_t t2, uint64_t t3,
                             uint32_t j) {
  const uint32_t k = j & 7u;
  if (j < 8) return (uint8_t)(t0 >> (8 * k));
  if (j < 16) return (uint8_t)(t1 >> (8 * k));
  if (j < 24) return (uint8_t)(t2 >> (8 * k));
  return (uint8_t)(t3 >> (8 * k));
}

// The tag string Core hashes: TaggedHash("TapLeaf") (hash.cpp:89) hashes
// exactly these seven bytes, and nothing else.
extern "C" uint16_t cell_tag_byte(uint32_t i) {
  // Inline literals, not a global array: the comparison stays call- and
  // memory-free so Alive2's constant-global model cannot affect the result.
  if (i == 0) return 0x154u;  // 'T'
  if (i == 1) return 0x161u;  // 'a'
  if (i == 2) return 0x170u;  // 'p'
  if (i == 3) return 0x14cu;  // 'L'
  if (i == 4) return 0x165u;  // 'e'
  if (i == 5) return 0x161u;  // 'a'
  if (i == 6) return 0x166u;  // 'f'
  return 0;
}

// The 64-byte tagged-hash prefix: `writer << taghash << taghash`
// (hash.cpp:90) writes the same 32-byte value twice, in this order.
// Both halves are read from the same t0..t3, so this is one value duplicated.
extern "C" uint16_t cell_prefix_byte(uint32_t i, uint64_t t0, uint64_t t1,
                                     uint64_t t2, uint64_t t3) {
  if (i < 64) return (uint16_t)t_byte(t0, t1, t2, t3, i & 31u) | 0x100u;
  return 0;
}

// control[0] & TAPROOT_LEAF_MASK (interpreter.cpp:1983, interpreter.h:242):
// byte 0 is the version that is hashed, byte 1 is the output-key parity bit
// consumed later by VerifyTaprootCommitment (interpreter.cpp:1925).
extern "C" uint16_t cell_leaf_mask(uint8_t control0) {
  const uint8_t version = (uint8_t)(control0 & 0xfe);
  const uint8_t parity = (uint8_t)(control0 & 1);
  return (uint16_t)version | ((uint16_t)parity << 8);
}

// WriteCompactSize size (serialize.h:301-323).
extern "C" uint8_t cell_cs_size(uint64_t n) {
  return (uint8_t)cs_size(n);
}

// Byte j of WriteCompactSize(n); bit8 marks j as inside the encoding.
extern "C" uint16_t cell_cs_byte(uint64_t n, uint32_t j) {
  if ((uint64_t)j >= cs_size(n)) return 0;
  return (uint16_t)cs_byte(n, j) | 0x100u;
}

// Which field of pre(v, s) sits at offset i, for every 64-bit script length.
extern "C" uint8_t cell_field_kind(uint64_t i, uint64_t len) {
  const uint64_t cs = cs_size(len);
  if (i < 32) return FIELD_TAG0;
  if (i < 64) return FIELD_TAG1;
  if (i == 64) return FIELD_VERSION;
  if (i < 65 + cs) return FIELD_CS;
  if (sub_u64(i, 65 + cs) < len) return FIELD_SCRIPT;
  return FIELD_END;
}

// Index inside the field at offset i (0 for FIELD_END); total for all lengths.
extern "C" uint64_t cell_field_index(uint64_t i, uint64_t len) {
  const uint64_t cs = cs_size(len);
  if (i < 32) return i;
  if (i < 64) return sub_u64(i, 32);
  if (i == 64) return 0;
  if (i < 65 + cs) return sub_u64(i, 65);
  if (sub_u64(i, 65 + cs) < len) return sub_u64(i, 65 + cs);
  return 0;
}

// Exact byte i of the composed preimage for a short script (len <= 4):
//   T || T || serU8(control0 & 0xfe) || CS(len) || script
// bit8 marks i as inside the preimage; the domain guard keeps the script
// content within the four supplied bytes.
extern "C" uint16_t cell_preimage_byte(uint64_t i, uint64_t t0, uint64_t t1,
                                       uint64_t t2, uint64_t t3,
                                       uint8_t control0, uint64_t len,
                                       uint8_t s0, uint8_t s1,
                                       uint8_t s2, uint8_t s3) {
  if (len > 4) return 0;                    // harness domain guard
  const uint8_t script[4] = {s0, s1, s2, s3};
  const uint64_t cs = cs_size(len);
  const uint64_t total = add_u64(add_u64(64, 1), add_u64(cs, len));
  if (i >= total) return 0;
  if (i < 32) return (uint16_t)t_byte(t0, t1, t2, t3, (uint32_t)i) | 0x100u;
  if (i < 64) return (uint16_t)t_byte(t0, t1, t2, t3, (uint32_t)(sub_u64(i, 32))) | 0x100u;
  if (i == 64) return (uint16_t)(control0 & 0xfe) | 0x100u;
  const uint64_t j = sub_u64(i, 65);
  if (j < cs) return (uint16_t)cs_byte(len, (uint32_t)j) | 0x100u;
  return (uint16_t)script[sub_u64(j, cs)] | 0x100u;
}

// Exact total preimage length for a short script (len <= 4); 0 outside the
// domain.  The prefix is always 64 bytes.
extern "C" uint64_t cell_preimage_len(uint64_t len) {
  if (len > 4) return 0;
  return add_u64(add_u64(64, 1), add_u64(cs_size(len), len));
}
