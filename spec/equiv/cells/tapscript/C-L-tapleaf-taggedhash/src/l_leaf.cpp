// L leg: REVIEWED TRANSLITERATION of the btc-lean model of the TapLeaf hash
// input, assembled arithmetically rather than by memory stores.
//
//   spec/core/Bitcoin/Interpreter/Rules.lean:681-686
//     def tapLeafHash (leafVersion : UInt8) (script : ByteArray) : ByteArray :=
//       Bitcoin.Crypto.Schnorr.taggedHash Bitcoin.Crypto.Schnorr.tagTapLeaf
//         (ByteArray.mk #[leafVersion &&& 0xfe] ++
//           compactSizeEnc script.size ++ script)
//
//   spec/core/Bitcoin/Crypto/Schnorr/TaggedHash.lean:29-31
//     def taggedHash (tag msg : ByteArray) : ByteArray :=
//       sha256 (sha256 tag ++ sha256 tag ++ msg)
//   spec/core/Bitcoin/Crypto/Schnorr/TaggedHash.lean:46
//     def tagTapLeaf : ByteArray := "TapLeaf".toUTF8
//
//   spec/core/Bitcoin/Crypto/Taproot/Program.lean:554-555
//     def leafVersionOf (control : ByteArray) : Nat :=
//       ((control.get! 0).toNat &&& 0xfe)
//   spec/core/Bitcoin/Data/Basic.lean:42 serU8
//     serU8 x = ByteArray.empty.push x
//   spec/core/Bitcoin/Data/Basic.lean:73-77 compactSizeEnc
//     n < 0xfd -> 1 byte; n <= 0xffff -> 0xfd + serU16;
//     n <= 0xffffffff -> 0xfe + serU32; else 0xff + serU64
//   spec/proofs/BitcoinProofs/AF/PDW58/PDW58.lean:160-164
//     tapLeafHash_preimage_row (the same equation, definitionally)
//
// In `taggedHash` the Lean term `sha256 tag` occurs twice; it denotes ONE
// value.  The cell passes that opaque value once (t0..t3) and reads both
// prefix halves from it, which is exactly the Lean sharing.
//
// Observable packing is the harness documented in c_leaf.cpp.

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

enum : uint8_t {
  FIELD_TAG0 = 0,
  FIELD_TAG1 = 1,
  FIELD_VERSION = 2,
  FIELD_CS = 3,
  FIELD_SCRIPT = 4,
  FIELD_END = 5
};

// Nat comparison structure of compactSizeEnc (Basic.lean:73-77).
static inline __attribute__((always_inline)) uint64_t lean_cs_size(uint64_t n) {
  if (n < 0xfdULL) return 1;
  if (n <= 0xffffULL) return 3;
  if (n <= 0xffffffffULL) return 5;
  return 9;
}

// Byte j of compactSizeEnc n, written as a LittleEndian fold (serU16/32/64):
// after the marker byte, byte j is (n >>> (8*(j-1))) &&& 0xff.
static inline __attribute__((always_inline)) uint8_t lean_cs_byte(uint64_t n, uint32_t j) {
  if (n < 0xfdULL) return (j == 0) ? (uint8_t)n : 0;
  const uint32_t k = j - 1;                       // only read when j >= 1
  if (n <= 0xffffULL) {
    if (j == 0) return 0xfd;
    if (j <= 2) return (uint8_t)(n >> (8 * k));
    return 0;
  }
  if (n <= 0xffffffffULL) {
    if (j == 0) return 0xfe;
    if (j <= 4) return (uint8_t)(n >> (8 * k));
    return 0;
  }
  if (j == 0) return 0xff;
  if (j <= 8) return (uint8_t)(n >> (8 * k));
  return 0;
}

// `leafVersionOf` (Program.lean:554-555): (control.get! 0).toNat &&& 0xfe,
// written as clearing the parity bit.  The parity bit is `c - version`.
static inline __attribute__((always_inline)) uint8_t lean_mask(uint8_t c) {
  return (uint8_t)(c - (uint8_t)(c & 1));
}

// Byte j (0..31) of `sha256 tagTapLeaf` (one opaque value shared by both
// prefix copies).  Bytes are little-endian within each 64-bit word.
static inline __attribute__((always_inline)) uint8_t lean_t_byte(uint64_t t0, uint64_t t1, uint64_t t2,
                                  uint64_t t3, uint32_t j) {
  const uint32_t k = j & 7u;
  if (j < 8) return (uint8_t)(t0 >> (8 * k));
  if (j < 16) return (uint8_t)(t1 >> (8 * k));
  if (j < 24) return (uint8_t)(t2 >> (8 * k));
  return (uint8_t)(t3 >> (8 * k));
}

// "TapLeaf".toUTF8 (TaggedHash.lean:46): seven ASCII bytes, no terminator.
extern "C" uint16_t cell_tag_byte(uint32_t i) {
  if (i > 6) return 0;
  const uint8_t b =
      (i == 0) ? 0x54 :  // 'T'
      (i == 1) ? 0x61 :  // 'a'
      (i == 2) ? 0x70 :  // 'p'
      (i == 3) ? 0x4c :  // 'L'
      (i == 4) ? 0x65 :  // 'e'
      (i == 5) ? 0x61 :  // 'a'
                 0x66;   // 'f'
  return (uint16_t)b | 0x100u;
}

// `sha256 tag ++ sha256 tag` in taggedHash: 64 bytes, both halves the same
// value.  Byte i reads T[i mod 32] from the single opaque input.
extern "C" uint16_t cell_prefix_byte(uint32_t i, uint64_t t0, uint64_t t1,
                                     uint64_t t2, uint64_t t3) {
  if (i >= 64) return 0;
  return (uint16_t)lean_t_byte(t0, t1, t2, t3, i % 32u) | 0x100u;
}

// ((control.get! 0).toNat &&& 0xfe) and the parity bit.
extern "C" uint16_t cell_leaf_mask(uint8_t control0) {
  const uint8_t version = lean_mask(control0);
  const uint8_t parity = (uint8_t)(control0 - version);
  return (uint16_t)version | ((uint16_t)parity << 8);
}

extern "C" uint8_t cell_cs_size(uint64_t n) {
  return (uint8_t)lean_cs_size(n);
}

extern "C" uint16_t cell_cs_byte(uint64_t n, uint32_t j) {
  if ((uint64_t)j >= lean_cs_size(n)) return 0;
  return (uint16_t)lean_cs_byte(n, j) | 0x100u;
}

// Field at preimage offset i: 64 bytes of tag prefix, then serU8 v (1 byte),
// then compactSizeEnc len, then script.
extern "C" uint8_t cell_field_kind(uint64_t i, uint64_t len) {
  const uint64_t cs = lean_cs_size(len);
  if (i < 32) return FIELD_TAG0;
  if (i < 64) return FIELD_TAG1;
  if (i == 64) return FIELD_VERSION;
  const uint64_t j = sub_u64(i, 65);
  if (j < cs) return FIELD_CS;
  if (sub_u64(j, cs) < len) return FIELD_SCRIPT;
  return FIELD_END;
}

extern "C" uint64_t cell_field_index(uint64_t i, uint64_t len) {
  const uint64_t cs = lean_cs_size(len);
  if (i < 32) return i;
  if (i < 64) return sub_u64(i, 32);
  if (i == 64) return 0;
  const uint64_t j = sub_u64(i, 65);
  if (j < cs) return j;
  if (sub_u64(j, cs) < len) return sub_u64(j, cs);
  return 0;
}

// Byte i of serU8 v ++ compactSizeEnc len ++ script, prefixed by T ++ T.
// `v` is masked exactly where Rules.lean's tapLeafHash masks it.
extern "C" uint16_t cell_preimage_byte(uint64_t i, uint64_t t0, uint64_t t1,
                                       uint64_t t2, uint64_t t3,
                                       uint8_t control0, uint64_t len,
                                       uint8_t s0, uint8_t s1,
                                       uint8_t s2, uint8_t s3) {
  if (len > 4) return 0;                    // harness domain guard
  const uint8_t script[4] = {s0, s1, s2, s3};
  const uint64_t cs = lean_cs_size(len);
  const uint64_t total = add_u64(add_u64(64, 1), add_u64(cs, len));
  if (i >= total) return 0;
  if (i < 64) {
    return (uint16_t)lean_t_byte(t0, t1, t2, t3, (uint32_t)(i % 32u)) | 0x100u;
  }
  if (i == 64) return (uint16_t)lean_mask(control0) | 0x100u;
  {
    const uint64_t j = sub_u64(i, 65);
    if (j < cs) return (uint16_t)lean_cs_byte(len, (uint32_t)j) | 0x100u;
    return (uint16_t)script[sub_u64(j, cs)] | 0x100u;
  }
}

extern "C" uint64_t cell_preimage_len(uint64_t len) {
  if (len > 4) return 0;
  return add_u64(add_u64(64, 1), add_u64(lean_cs_size(len), len));
}
