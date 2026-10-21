// runtime.inc -- C++ template for the generated twin.  gen.py substitutes the
// __PLACEHOLDERS__; every opcode handler body is emitted from gen.py's IR
// table (one `// Lean:` anchor per handler).  This file carries the
// structural (non-opcode) code: stack primitives, GetOp decode, EvalScript
// loop, TX_WITH_WITNESS decode and VerifyScript ordering.
//
// GENERATED FILE -- DO NOT EDIT (edit runtime.inc in the generator directory).
// Lean source of record: spec/core/Bitcoin/Interpreter/Defs.lean.

#include <cstdint>
#include <cstddef>
#include <cstring>
#include <new>

#include "error_kind.h"

namespace twin {

constexpr uint32_t MAX_SCRIPT_ELEMENT_SIZE = 520;
constexpr uint32_t MAX_SCRIPT_SIZE = 10000;
constexpr uint32_t MAX_OPS_PER_SCRIPT = 201;
constexpr uint32_t MAX_STACK_SIZE = 1000;
constexpr uint64_t MAX_SERIALIZE_SIZE = 0x02000000ull;
constexpr uint64_t MAX_MONEY = 2100000000000000ll;

// ---- error enum (TwinErr) and the total TwinErr -> Core ordinal map ------
// IDs are stable: TWIN_OK = 0, then 1 + the Lean ExecError constructor index
// (Defs.lean:119-177), then two twin-only sentinels.  The map is total by
// construction: one initializer per enumerator, and TWIN_ERR_COUNT below is
// emitted from the same table.
enum TwinErr : int32_t {
__ERROR_ENUM__
};
constexpr int32_t TWIN_ERR_COUNT = __ERR_COUNT__;
constexpr int32_t CORE_MAP[TWIN_ERR_COUNT] = {
__CORE_MAP__
};
static_assert(sizeof(CORE_MAP) / sizeof(CORE_MAP[0]) == TWIN_ERR_COUNT,
              "every TwinErr needs exactly one Core mapping");
static_assert(CORE_MAP[TWIN_OK] == static_cast<int32_t>(EQUIV_ERR_OK),
              "TWIN_OK must map to EQUIV_ERR_OK");
static_assert(CORE_MAP[TWIN_BAD_INPUT] == static_cast<int32_t>(EQUIV_ERR_UNKNOWN_ERROR),
              "result-2 sentinel must not name a consensus error");
static_assert(CORE_MAP[TWIN_INVALID_UNSUPPORTED] == static_cast<int32_t>(EQUIV_ERR_UNKNOWN_ERROR),
              "unsupported must not name a consensus error");
static_assert(CORE_MAP[TWIN_TAPROOT_DATA_UNAVAILABLE] == static_cast<int32_t>(EQUIV_ERR_UNKNOWN_ERROR),
              "unjudged must not name a consensus error");
static_assert(static_cast<int32_t>(TWIN_BAD_INPUT) == TWIN_ERR_COUNT - 1,
              "TwinErr table shape changed; review the map");

static constexpr int32_t core_ordinal(TwinErr e) {
  const uint32_t i = static_cast<uint32_t>(e);
  return i < static_cast<uint32_t>(TWIN_ERR_COUNT) ? CORE_MAP[i]
                                                   : static_cast<int32_t>(EQUIV_ERR_UNKNOWN_ERROR);
}

// ---- machine state -------------------------------------------------------
// Stack: index 0 = BOTTOM, index n-1 = TOP (Lean head = top).
struct Stack {
  uint32_t n;
  uint32_t len[MAX_STACK_SIZE];
  uint8_t  e[MAX_STACK_SIZE][MAX_SCRIPT_ELEMENT_SIZE];
};

// Consensus flags (Activation/Interface.lean:71-80) and policy flags
// (Defs.lean:184-201).  The tape's one Core bitset is split here once.
struct ScriptFlags {
  bool p2sh, dersig, cltv, csv, nullDummy, witness, taproot;
};
struct PolicyFlags {
  bool minimalData, minimalIf, nullFail, strictEnc, constScriptCode, cleanstack;
  bool sigPushOnly, lowS, witnessPubkeyType, discourageUpgradableNops;
  bool discourageUpgradableWitnessProgram, discourageUpgradablePubkeyType;
  bool discourageOpSuccess, discourageUpgradableTaprootVersion;
};
enum class SigVersion : uint8_t { Base, WitnessV0, Tapscript };

struct Ctx {
  ScriptFlags flags;
  PolicyFlags pol;
  SigVersion sv;
};

// EvalScript's locals (Defs.lean:596-605).  `saved` holds the post-scriptSig
// stack across the scriptPubKey evaluation (VerifyScript's stackCopy).
struct State {
  Stack stack;
  Stack alt;
  Stack saved;
  bool vf[MAX_SCRIPT_SIZE];   // index 0 = outermost, vf_n-1 = innermost
  uint32_t vf_n;
  uint32_t opCount;
  uint32_t codeSep;
  uint32_t codeSepPos;
  uint32_t opcodeIndex;
  int64_t vwLeft;
  bool has_vw;
};

// ---- stack primitives ----------------------------------------------------
static TwinErr st_push(Stack& s, const uint8_t* data, uint32_t len) {
  if (len > MAX_SCRIPT_ELEMENT_SIZE) return TWIN_PUSH_SIZE;
  if (s.n >= MAX_STACK_SIZE) return TWIN_STACK_SIZE;
  if (len != 0) std::memmove(s.e[s.n], data, len);
  s.len[s.n] = len;
  s.n += 1;
  return TWIN_OK;
}

static const uint8_t* st_top(const Stack& s, uint32_t k, uint32_t& len) {
  const uint32_t i = s.n - k;   // caller checked n >= k
  len = s.len[i];
  return s.e[i];
}

// Push a copy of the k-th element from the top (k >= 1).  Used by DUP/OVER.
static TwinErr st_push_copy(Stack& s, uint32_t k) {
  if (s.n < k) return TWIN_INVALID_STACK_OPERATION;
  const uint32_t i = s.n - k;
  const uint32_t l = s.len[i];
  if (l > MAX_SCRIPT_ELEMENT_SIZE) return TWIN_PUSH_SIZE;
  if (s.n >= MAX_STACK_SIZE) return TWIN_STACK_SIZE;
  std::memcpy(s.e[s.n], s.e[i], l);
  s.len[s.n] = l;
  s.n += 1;
  return TWIN_OK;
}

// CastToBool (interpreter.cpp:46-59; Numeric/Interface.lean:87-91).
static bool cast_to_bool(const uint8_t* d, uint32_t len) {
  for (uint32_t i = 0; i < len; ++i) {
    if (d[i] != 0) {
      if (i + 1 == len && d[i] == 0x80) return false;
      return true;
    }
  }
  return false;
}

// CScriptNum serialize (interpreter.cpp:415-427) into `out`, returns length.
static uint32_t encode_num(int64_t v, uint8_t* out) {
  if (v == 0) return 0;
  const bool neg = v < 0;
  uint64_t a = neg ? (static_cast<uint64_t>(-(v + 1)) + 1u)
                   : static_cast<uint64_t>(v);
  uint32_t n = 0;
  while (a != 0) {
    out[n++] = static_cast<uint8_t>(a & 0xffu);
    a >>= 8;
  }
  if ((out[n - 1] & 0x80u) != 0) {
    out[n++] = neg ? 0x80u : 0x00u;
  } else if (neg) {
    out[n - 1] = static_cast<uint8_t>(out[n - 1] | 0x80u);
  }
  return n;
}

static TwinErr st_push_num(Stack& s, int64_t v) {
  uint8_t tmp[10];
  const uint32_t n = encode_num(v, tmp);
  return st_push(s, tmp, n);
}

// CScriptNum decode (interpreter.cpp:429-451): LE sign-magnitude, optional
// minimal check, size <= maxSize.
static TwinErr decode_num(const uint8_t* b, uint32_t len, bool minimal,
                          uint32_t maxSize, int64_t& out) {
  if (len > maxSize) return TWIN_SCRIPTNUM;
  if (minimal && len > 0) {
    if ((b[len - 1] & 0x7fu) == 0) {
      if (len <= 1 || (b[len - 2] & 0x80u) == 0) return TWIN_SCRIPTNUM;
    }
  }
  if (len == 0) {
    out = 0;
    return TWIN_OK;
  }
  uint64_t v = 0;
  for (uint32_t i = 0; i < len; ++i) {
    uint64_t byte = b[i];
    if (i + 1 == len) byte &= 0x7fu;
    v |= byte << (8u * i);
  }
  const bool neg = (b[len - 1] & 0x80u) != 0;
  out = neg ? -static_cast<int64_t>(v) : static_cast<int64_t>(v);
  return TWIN_OK;
}

// CheckMinimalPush (script.cpp:373-396; Defs.lean:529-537).
static bool check_minimal_push(const uint8_t* d, uint32_t len, uint32_t opcode) {
  if (len == 0) return opcode == 0;
  if (len == 1 && d[0] >= 1 && d[0] <= 16) return false;
  if (len == 1 && d[0] == 0x81) return false;
  if (len <= 75) return opcode == len;
  if (len <= 0xff) return opcode == 0x4c;
  if (len <= 0xffff) return opcode == 0x4d;
  return true;
}

static void vf_push(State& st, bool v) {
  st.vf[st.vf_n] = v;
  st.vf_n += 1;
}
static bool vf_all(const State& st) {
  for (uint32_t i = 0; i < st.vf_n; ++i) {
    if (!st.vf[i]) return false;
  }
  return true;
}
static void reset_eval(State& st) {
  st.alt.n = 0;
  st.vf_n = 0;
  st.opCount = 0;
  st.codeSep = 0;
  st.codeSepPos = 0xffffffffu;
  st.opcodeIndex = 0;
  st.vwLeft = 0;
  st.has_vw = false;
}

// ---- GetScriptOp (Parser/Defs.lean:206-229) ------------------------------
enum class Kind : uint8_t { PushBytes, PushNum, Op };

struct Decoded {
  Kind kind;
  const uint8_t* data;
  uint32_t dlen;
  uint32_t wire;
  uint32_t next;
};

static bool read_le(const uint8_t* b, uint32_t size, uint32_t at,
                    uint32_t width, uint32_t& out) {
  if (at > size || width > size - at) return false;
  uint32_t v = 0;
  for (uint32_t j = 0; j < width; ++j) v |= static_cast<uint32_t>(b[at + j]) << (8u * j);
  out = v;
  return true;
}

static bool decode_op(const uint8_t* b, uint32_t size, uint32_t i, Decoded& d) {
  if (i >= size) return false;
  const uint32_t c = b[i];
  d.wire = c;
  d.data = nullptr;
  d.dlen = 0;
  if (c == 0x00) {
    d.kind = Kind::PushBytes;
    d.next = i + 1;
    return true;
  }
  if (c <= 0x4b) {
    if (c > size - (i + 1)) return false;
    d.kind = Kind::PushBytes;
    d.data = b + i + 1;
    d.dlen = c;
    d.next = i + 1 + c;
    return true;
  }
  if (c == 0x4c || c == 0x4d || c == 0x4e) {
    const uint32_t width = (c == 0x4c) ? 1u : (c == 0x4d) ? 2u : 4u;
    uint32_t k = 0;
    if (!read_le(b, size, i + 1, width, k)) return false;
    const uint32_t prefix = 1u + width;
    if (prefix > size - i || k > size - i - prefix) return false;
    d.kind = Kind::PushBytes;
    d.data = b + i + prefix;
    d.dlen = k;
    d.next = i + prefix + k;
    return true;
  }
  if (c == 0x4f || (0x51 <= c && c <= 0x60)) {
    d.kind = Kind::PushNum;
    d.next = i + 1;
    return true;
  }
  d.kind = Kind::Op;
  d.next = i + 1;
  return true;
}

// Eager full-script validation: Lean `evalScriptBytes` calls `parseWire`
// BEFORE `evalFrom` (Defs.lean:1163-1178).  Mirrored deliberately; the
// Lean-vs-Core precedence difference is F-DIV-TWIN-001.
static bool validate_script(const uint8_t* b, uint32_t size) {
  uint32_t i = 0;
  while (i < size) {
    Decoded d;
    if (!decode_op(b, size, i, d)) return false;
    i = d.next;
  }
  return true;
}

enum class PushOnly : uint8_t { Ok, ParseFail, NotPush };
static PushOnly classify_push_only(const uint8_t* b, uint32_t size) {
  uint32_t i = 0;
  while (i < size) {
    Decoded d;
    if (!decode_op(b, size, i, d)) return PushOnly::ParseFail;
    if (d.wire > 0x60) return PushOnly::NotPush;
    i = d.next;
  }
  return PushOnly::Ok;
}

// ---- script templates and flag decoding ---------------------------------
static bool is_p2sh(const uint8_t* b, uint32_t n) {
  return n == 23 && b[0] == 0xa9 && b[1] == 0x14 && b[22] == 0x87;
}
static bool is_witness_program(const uint8_t* b, uint32_t n) {
  if (n < 4 || n > 42) return false;
  const uint8_t v = b[0];
  if (!(v == 0x00 || (0x51 <= v && v <= 0x60))) return false;
  return static_cast<uint32_t>(b[1]) + 2u == n;
}
// `ss == pushBytesWire redeem` (canonical push encoding; Defs.lean:377).
static bool ss_equals_push(const uint8_t* redeem, uint32_t rlen,
                           const uint8_t* ss, uint32_t sslen) {
  uint32_t prefix;
  if (rlen == 0) prefix = 1;
  else if (rlen <= 75) prefix = 1;
  else if (rlen <= 0xff) prefix = 2;
  else if (rlen <= 0xffff) prefix = 3;
  else prefix = 5;
  if (sslen != prefix + rlen) return false;
  if (rlen == 0) return ss[0] == 0x00;
  if (rlen <= 75) {
    if (ss[0] != rlen) return false;
  } else if (rlen <= 0xff) {
    if (ss[0] != 0x4c || ss[1] != rlen) return false;
  } else if (rlen <= 0xffff) {
    if (ss[0] != 0x4d || ss[1] != (rlen & 0xff) || ss[2] != (rlen >> 8)) return false;
  } else {
    if (ss[0] != 0x4e || ss[1] != (rlen & 0xff) || ss[2] != ((rlen >> 8) & 0xff) ||
        ss[3] != ((rlen >> 16) & 0xff) || ss[4] != ((rlen >> 24) & 0xff)) return false;
  }
  return std::memcmp(ss + prefix, redeem, rlen) == 0;
}

constexpr uint64_t F_P2SH = 0x000001;
constexpr uint64_t F_STRICTENC = 0x000002;
constexpr uint64_t F_DERSIG = 0x000004;
constexpr uint64_t F_LOW_S = 0x000008;
constexpr uint64_t F_NULLDUMMY = 0x000010;
constexpr uint64_t F_SIGPUSHONLY = 0x000020;
constexpr uint64_t F_MINIMALDATA = 0x000040;
constexpr uint64_t F_DISCOURAGE_UPGRADABLE_NOPS = 0x000080;
constexpr uint64_t F_CLEANSTACK = 0x000100;
constexpr uint64_t F_CLTV = 0x000200;
constexpr uint64_t F_CSV = 0x000400;
constexpr uint64_t F_WITNESS = 0x000800;
constexpr uint64_t F_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM = 0x001000;
constexpr uint64_t F_MINIMALIF = 0x002000;
constexpr uint64_t F_NULLFAIL = 0x004000;
constexpr uint64_t F_WITNESS_PUBKEYTYPE = 0x008000;
constexpr uint64_t F_CONST_SCRIPTCODE = 0x010000;
constexpr uint64_t F_TAPROOT = 0x020000;
constexpr uint64_t F_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION = 0x040000;
constexpr uint64_t F_DISCOURAGE_OP_SUCCESS = 0x080000;
constexpr uint64_t F_DISCOURAGE_UPGRADABLE_PUBKEYTYPE = 0x100000;
constexpr uint64_t FLAG_MASK = 0x1fffff;

static Ctx make_ctx(uint64_t f) {
  Ctx c{};
  c.sv = SigVersion::Base;
  c.flags.p2sh = (f & F_P2SH) != 0;
  c.flags.dersig = (f & F_DERSIG) != 0;
  c.flags.cltv = (f & F_CLTV) != 0;
  c.flags.csv = (f & F_CSV) != 0;
  c.flags.nullDummy = (f & F_NULLDUMMY) != 0;
  c.flags.witness = (f & F_WITNESS) != 0;
  c.flags.taproot = (f & F_TAPROOT) != 0;
  c.pol.minimalData = (f & F_MINIMALDATA) != 0;
  c.pol.minimalIf = (f & F_MINIMALIF) != 0;
  c.pol.nullFail = (f & F_NULLFAIL) != 0;
  c.pol.strictEnc = (f & F_STRICTENC) != 0;
  c.pol.constScriptCode = (f & F_CONST_SCRIPTCODE) != 0;
  c.pol.cleanstack = (f & F_CLEANSTACK) != 0;
  c.pol.sigPushOnly = (f & F_SIGPUSHONLY) != 0;
  c.pol.lowS = (f & F_LOW_S) != 0;
  c.pol.witnessPubkeyType = (f & F_WITNESS_PUBKEYTYPE) != 0;
  c.pol.discourageUpgradableNops = (f & F_DISCOURAGE_UPGRADABLE_NOPS) != 0;
  c.pol.discourageUpgradableWitnessProgram =
      (f & F_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM) != 0;
  c.pol.discourageUpgradablePubkeyType =
      (f & F_DISCOURAGE_UPGRADABLE_PUBKEYTYPE) != 0;
  c.pol.discourageOpSuccess = (f & F_DISCOURAGE_OP_SUCCESS) != 0;
  c.pol.discourageUpgradableTaprootVersion =
      (f & F_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION) != 0;
  return c;
}

// disabledWire (Defs.lean:455-462): fails even in unexecuted branches.
static bool disabled_wire(uint32_t w) {
  switch (w) {
    case 0x7e: case 0x7f: case 0x80: case 0x81:
    case 0x83: case 0x84: case 0x85: case 0x86:
    case 0x8d: case 0x8e:
    case 0x95: case 0x96: case 0x97: case 0x98:
    case 0x99:
      return true;
    default:
      return false;
  }
}

// ---- hash floor (Interpreter/Hashes.lean; Core crypto/sha256,ripemd160) --
// One-shot SHA-256 and RIPEMD-160 over <=520-byte stack elements.  The
// digest vectors in smoke_driver.cpp pin both against known answers.
static uint32_t rotr32(uint32_t x, uint32_t n) { return (x >> n) | (x << (32 - n)); }
static uint32_t rotl32(uint32_t x, uint32_t n) { return (x << n) | (x >> (32 - n)); }

static void sha256_block(uint32_t h[8], const uint8_t* p) {
  static const uint32_t K[64] = {
    0x428a2f98u,0x71374491u,0xb5c0fbcfu,0xe9b5dba5u,0x3956c25bu,0x59f111f1u,0x923f82a4u,0xab1c5ed5u,
    0xd807aa98u,0x12835b01u,0x243185beu,0x550c7dc3u,0x72be5d74u,0x80deb1feu,0x9bdc06a7u,0xc19bf174u,
    0xe49b69c1u,0xefbe4786u,0x0fc19dc6u,0x240ca1ccu,0x2de92c6fu,0x4a7484aau,0x5cb0a9dcu,0x76f988dau,
    0x983e5152u,0xa831c66du,0xb00327c8u,0xbf597fc7u,0xc6e00bf3u,0xd5a79147u,0x06ca6351u,0x14292967u,
    0x27b70a85u,0x2e1b2138u,0x4d2c6dfcu,0x53380d13u,0x650a7354u,0x766a0abbu,0x81c2c92eu,0x92722c85u,
    0xa2bfe8a1u,0xa81a664bu,0xc24b8b70u,0xc76c51a3u,0xd192e819u,0xd6990624u,0xf40e3585u,0x106aa070u,
    0x19a4c116u,0x1e376c08u,0x2748774cu,0x34b0bcb5u,0x391c0cb3u,0x4ed8aa4au,0x5b9cca4fu,0x682e6ff3u,
    0x748f82eeu,0x78a5636fu,0x84c87814u,0x8cc70208u,0x90befffau,0xa4506cebu,0xbef9a3f7u,0xc67178f2u};
  uint32_t w[64];
  for (uint32_t i = 0; i < 16; ++i) {
    w[i] = (static_cast<uint32_t>(p[4*i]) << 24) |
           (static_cast<uint32_t>(p[4*i+1]) << 16) |
           (static_cast<uint32_t>(p[4*i+2]) << 8) |
           static_cast<uint32_t>(p[4*i+3]);
  }
  for (uint32_t i = 16; i < 64; ++i) {
    const uint32_t s0 = rotr32(w[i-15],7) ^ rotr32(w[i-15],18) ^ (w[i-15] >> 3);
    const uint32_t s1 = rotr32(w[i-2],17) ^ rotr32(w[i-2],19) ^ (w[i-2] >> 10);
    w[i] = w[i-16] + s0 + w[i-7] + s1;
  }
  uint32_t a=h[0],b=h[1],c=h[2],d=h[3],e=h[4],f=h[5],g=h[6],hh=h[7];
  for (uint32_t i = 0; i < 64; ++i) {
    const uint32_t S1 = rotr32(e,6) ^ rotr32(e,11) ^ rotr32(e,25);
    const uint32_t ch = (e & f) ^ (~e & g);
    const uint32_t t1 = hh + S1 + ch + K[i] + w[i];
    const uint32_t S0 = rotr32(a,2) ^ rotr32(a,13) ^ rotr32(a,22);
    const uint32_t maj = (a & b) ^ (a & c) ^ (b & c);
    const uint32_t t2 = S0 + maj;
    hh=g; g=f; f=e; e=d+t1; d=c; c=b; b=a; a=t1+t2;
  }
  h[0]+=a; h[1]+=b; h[2]+=c; h[3]+=d; h[4]+=e; h[5]+=f; h[6]+=g; h[7]+=hh;
}

static void sha256(const uint8_t* data, uint32_t len, uint8_t out[32]) {
  uint32_t h[8] = {0x6a09e667u,0xbb67ae85u,0x3c6ef372u,0xa54ff53au,
                   0x510e527fu,0x9b05688cu,0x1f83d9abu,0x5be0cd19u};
  uint32_t i = 0;
  for (; i + 64 <= len; i += 64) sha256_block(h, data + i);
  uint8_t tail[128];
  const uint32_t rem = len - i;
  std::memset(tail, 0, sizeof(tail));
  if (rem) std::memcpy(tail, data + i, rem);
  tail[rem] = 0x80;
  const uint32_t padlen = (rem < 56) ? 64u : 128u;
  const uint64_t bits = static_cast<uint64_t>(len) * 8u;
  for (uint32_t j = 0; j < 8; ++j) {
    tail[padlen - 1 - j] = static_cast<uint8_t>(bits >> (8u * j));
  }
  sha256_block(h, tail);
  if (padlen == 128) sha256_block(h, tail + 64);
  for (uint32_t j = 0; j < 8; ++j) {
    out[4*j]   = static_cast<uint8_t>(h[j] >> 24);
    out[4*j+1] = static_cast<uint8_t>(h[j] >> 16);
    out[4*j+2] = static_cast<uint8_t>(h[j] >> 8);
    out[4*j+3] = static_cast<uint8_t>(h[j]);
  }
}

static void ripemd160_block(uint32_t h[5], const uint8_t* p) {
  static const uint32_t K1[5] = {0x00000000u,0x5a827999u,0x6ed9eba1u,0x8f1bbcdcu,0xa953fd4eu};
  static const uint32_t K2[5] = {0x50a28be6u,0x5c4dd124u,0x6d703ef3u,0x7a6d76e9u,0x00000000u};
  static const uint8_t R1[80] = {
    0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,
    7,4,13,1,10,6,15,3,12,0,9,5,2,14,11,8,
    3,10,14,4,9,15,8,1,2,7,0,6,13,11,5,12,
    1,9,11,10,0,8,12,4,13,3,7,15,14,5,6,2,
    4,0,5,9,7,12,2,10,14,1,3,8,11,6,15,13};
  static const uint8_t R2[80] = {
    5,14,7,0,9,2,11,4,13,6,15,8,1,10,3,12,
    6,11,3,7,0,13,5,10,14,15,8,12,4,9,1,2,
    15,5,1,3,7,14,6,9,11,8,12,2,10,0,4,13,
    8,6,4,1,3,11,15,0,5,12,2,13,9,7,10,14,
    12,15,10,4,1,5,8,7,6,2,13,14,0,3,9,11};
  static const uint8_t S1[80] = {
    11,14,15,12,5,8,7,9,11,13,14,15,6,7,9,8,
    7,6,8,13,11,9,7,15,7,12,15,9,11,7,13,12,
    11,13,6,7,14,9,13,15,14,8,13,6,5,12,7,5,
    11,12,14,15,14,15,9,8,9,14,5,6,8,6,5,12,
    9,15,5,11,6,8,13,12,5,12,13,14,11,8,5,6};
  static const uint8_t S2[80] = {
    8,9,9,11,13,15,15,5,7,7,8,11,14,14,12,6,
    9,13,15,7,12,8,9,11,7,7,12,7,6,15,13,11,
    9,7,15,11,8,6,6,14,12,13,5,14,13,13,7,5,
    15,5,8,11,14,14,6,14,6,9,12,9,12,5,15,8,
    8,5,12,9,12,5,14,6,8,13,6,5,15,13,11,11};
  uint32_t x[16];
  for (uint32_t i = 0; i < 16; ++i) {
    x[i] = static_cast<uint32_t>(p[4*i]) |
           (static_cast<uint32_t>(p[4*i+1]) << 8) |
           (static_cast<uint32_t>(p[4*i+2]) << 16) |
           (static_cast<uint32_t>(p[4*i+3]) << 24);
  }
  uint32_t al=h[0], bl=h[1], cl=h[2], dl=h[3], el=h[4];
  uint32_t ar=h[0], br=h[1], cr=h[2], dr=h[3], er=h[4];
  for (uint32_t j = 0; j < 80; ++j) {
    uint32_t f1, f2;
    if (j < 16) { f1 = bl ^ cl ^ dl; f2 = br ^ (cr | ~dr); }
    else if (j < 32) { f1 = (bl & cl) | (~bl & dl); f2 = (br & dr) | (cr & ~dr); }
    else if (j < 48) { f1 = (bl | ~cl) ^ dl; f2 = (br | ~cr) ^ dr; }
    else if (j < 64) { f1 = (bl & dl) | (cl & ~dl); f2 = (br & cr) | (~br & dr); }
    else { f1 = bl ^ (cl | ~dl); f2 = br ^ cr ^ dr; }
    uint32_t t = rotl32(al + f1 + x[R1[j]] + K1[j/16], S1[j]) + el;
    al = el; el = dl; dl = rotl32(cl,10); cl = bl; bl = t;
    t = rotl32(ar + f2 + x[R2[j]] + K2[j/16], S2[j]) + er;
    ar = er; er = dr; dr = rotl32(cr,10); cr = br; br = t;
  }
  const uint32_t t = h[1] + cl + dr;
  h[1] = h[2] + dl + er;
  h[2] = h[3] + el + ar;
  h[3] = h[4] + al + br;
  h[4] = h[0] + bl + cr;
  h[0] = t;
}

static void ripemd160(const uint8_t* data, uint32_t len, uint8_t out[20]) {
  uint32_t h[5] = {0x67452301u,0xefcdab89u,0x98badcfeu,0x10325476u,0xc3d2e1f0u};
  uint32_t i = 0;
  for (; i + 64 <= len; i += 64) ripemd160_block(h, data + i);
  uint8_t tail[128];
  const uint32_t rem = len - i;
  std::memset(tail, 0, sizeof(tail));
  if (rem) std::memcpy(tail, data + i, rem);
  tail[rem] = 0x80;
  const uint32_t padlen = (rem < 56) ? 64u : 128u;
  const uint64_t bits = static_cast<uint64_t>(len) * 8u;
  for (uint32_t j = 0; j < 8; ++j) {
    tail[padlen - 8 + j] = static_cast<uint8_t>(bits >> (8u * j));
  }
  ripemd160_block(h, tail);
  if (padlen == 128) ripemd160_block(h, tail + 64);
  for (uint32_t j = 0; j < 5; ++j) {
    out[4*j]   = static_cast<uint8_t>(h[j]);
    out[4*j+1] = static_cast<uint8_t>(h[j] >> 8);
    out[4*j+2] = static_cast<uint8_t>(h[j] >> 16);
    out[4*j+3] = static_cast<uint8_t>(h[j] >> 24);
  }
}

static void hash160(const uint8_t* data, uint32_t len, uint8_t out[20]) {
  uint8_t s[32];
  sha256(data, len, s);
  ripemd160(s, 32, out);
}
static void hash256(const uint8_t* data, uint32_t len, uint8_t out[32]) {
  uint8_t s[32];
  sha256(data, len, s);
  sha256(s, 32, out);
}

// ---- opcode handlers (emitted verbatim from gen.py's IR table) -----------
// Each handler is line-anchored to its Lean equation; see generator.md §5.
__OPS__

// ---- opcode dispatch (Defs.lean:854-1123) --------------------------------
// A valid script opcode outside the twin subset returns
// TWIN_INVALID_UNSUPPORTED, which the boundary maps to result 3.  It never
// maps to a pass/fail verdict.
static TwinErr dispatch(State& st, const Ctx& ctx, const Decoded& d) {
  if (d.kind == Kind::PushBytes) {
    return st_push(st.stack, d.data, d.dlen);
  }
  if (d.kind == Kind::PushNum) {
    // Lean: encodeScriptNum (if n = 0 then -1 else n) false.
    return st_push_num(st.stack, d.wire == 0x4f ? -1 : static_cast<int64_t>(d.wire - 0x50));
  }
  switch (d.wire) {
__DISPATCH_CASES__
    default:
      // Safety net: every wire 0x00..0xff is covered explicitly above, so a
      // hit here means the IR table is incomplete.  Never invent a verdict.
      return TWIN_INVALID_UNSUPPORTED;
  }
}

// ---- EvalScript (stepChecked 1131, evalFrom 1144, evalScriptBytes 1163-1178)
static TwinErr eval_script(const uint8_t* b, uint32_t size, const Ctx& ctx,
                           State& st) {
  if ((ctx.sv == SigVersion::Base || ctx.sv == SigVersion::WitnessV0) &&
      size > MAX_SCRIPT_SIZE) {
    return TWIN_SCRIPT_SIZE;
  }
  if (!validate_script(b, size)) return TWIN_BAD_OPCODE;
  uint32_t i = 0;
  while (i < size) {
    Decoded d;
    if (!decode_op(b, size, i, d)) return TWIN_BAD_OPCODE;  // unreachable after validate
    // (1) element size limit, executed or not (Defs.lean:819-824)
    if (d.kind == Kind::PushBytes && d.dlen > MAX_SCRIPT_ELEMENT_SIZE) {
      return TWIN_PUSH_SIZE;
    }
    // (2) 201-op budget: wire > 0x60 in BASE/WITNESS_V0 (Defs.lean:826-829)
    if ((ctx.sv == SigVersion::Base || ctx.sv == SigVersion::WitnessV0) &&
        d.wire > 0x60) {
      st.opCount += 1;
      if (st.opCount > MAX_OPS_PER_SCRIPT) return TWIN_OP_COUNT;
    }
    // (3) disabled opcodes, unexecuted branches included (Defs.lean:831-833)
    if (disabled_wire(d.wire)) return TWIN_DISABLED_OPCODE;
    // (4) OP_CODESEPARATOR under CONST_SCRIPTCODE in base script
    if (d.wire == 0xab && ctx.sv == SigVersion::Base && ctx.pol.constScriptCode) {
      return TWIN_SIG_OP_CODESEPARATOR;
    }
    const bool fExec = vf_all(st);
    if (d.kind == Kind::PushBytes) {
      if (fExec) {
        if (ctx.pol.minimalData &&
            !check_minimal_push(d.data, d.dlen, d.wire)) {
          return TWIN_MINIMALDATA;
        }
        const TwinErr e = st_push(st.stack, d.data, d.dlen);
        if (e != TWIN_OK) return e;
      }
    } else if (d.kind == Kind::PushNum) {
      if (fExec) {
        const TwinErr e = st_push_num(st.stack,
            d.wire == 0x4f ? -1 : static_cast<int64_t>(d.wire - 0x50));
        if (e != TWIN_OK) return e;
      }
    } else {
      // Unexecuted branch: only the conditional window 0x63..0x68 still runs.
      if (fExec || (0x63 <= d.wire && d.wire <= 0x68)) {
        const TwinErr e = dispatch(st, ctx, d);
        if (e != TWIN_OK) return e;
      }
    }
    // terminal STACK_SIZE guard (stepChecked, Defs.lean:1131-1136)
    if (st.stack.n + st.alt.n > MAX_STACK_SIZE) return TWIN_STACK_SIZE;
    st.opcodeIndex += 1;
    i = d.next;
  }
  if (st.vf_n != 0) return TWIN_UNBALANCED_CONDITIONAL;
  return TWIN_OK;
}

// ---- TX_WITH_WITNESS decode (tape.md §2) --------------------------------
struct TxInfo {
  const uint8_t* ss;
  uint32_t ss_len;
  uint32_t vin_count;
  uint32_t version;
  uint32_t sequence;
  uint32_t locktime;
  bool extended;
  bool witness_nonempty;
  uint64_t witness_items;
};

static bool read_bytes(const uint8_t* /*b*/, uint64_t len, uint64_t& pos, uint64_t n) {
  if (pos > len || n > len - pos) return false;
  pos += n;
  return true;
}
static bool read_u32(const uint8_t* b, uint64_t len, uint64_t& pos, uint32_t& v) {
  if (pos > len || len - pos < 4) return false;
  v = static_cast<uint32_t>(b[pos]) |
      (static_cast<uint32_t>(b[pos + 1]) << 8) |
      (static_cast<uint32_t>(b[pos + 2]) << 16) |
      (static_cast<uint32_t>(b[pos + 3]) << 24);
  pos += 4;
  return true;
}
// Canonical CompactSize (Core streams.h ReadCompactSize at the pin).
static bool read_cs(const uint8_t* b, uint64_t len, uint64_t& pos, uint64_t& v) {
  if (pos >= len) return false;
  const uint8_t c = b[pos++];
  if (c < 0xfd) {
    v = c;
    return true;
  }
  const uint32_t width = (c == 0xfd) ? 2u : (c == 0xfe) ? 4u : 8u;
  if (pos > len || width > len - pos) return false;
  uint64_t x = 0;
  for (uint32_t i = 0; i < width; ++i) {
    x |= static_cast<uint64_t>(b[pos + i]) << (8u * i);
  }
  pos += width;
  if (c == 0xfd && x < 0xfdull) return false;
  if (c == 0xfe && x < 0x10000ull) return false;
  if (c == 0xff && x < 0x100000000ull) return false;
  if (x > MAX_SERIALIZE_SIZE) return false;
  v = x;
  return true;
}

static bool decode_tx(const uint8_t* b, uint64_t len, uint32_t input_index,
                      TxInfo& out) {
  out = TxInfo{nullptr, 0, 0, 0, 0, 0, false, false, 0};
  uint64_t pos = 0;
  if (!read_u32(b, len, pos, out.version)) return false;

  bool extended = false;
  uint64_t vin = 0;
  // The extended marker is 0x00 followed by flags; flags must be exactly 1
  // (bit 0 = witness present).  A zero-input non-extended tx is out of
  // contract (tape.md §2: input_index can never be in range).
  if (pos < len && b[pos] == 0x00) {
    pos += 1;
    if (pos >= len) return false;
    const uint8_t wf = b[pos++];
    if (wf != 1) return false;
    extended = true;
    if (!read_cs(b, len, pos, vin)) return false;
  } else {
    if (!read_cs(b, len, pos, vin)) return false;
  }
  if (vin == 0 || vin > 0xffffffffull) return false;
  if (vin > len - pos) return false;   // each input is at least 41 bytes

  out.ss = nullptr;
  out.ss_len = 0;
  out.sequence = 0;
  for (uint64_t i = 0; i < vin; ++i) {
    if (!read_bytes(b, len, pos, 32 + 4)) return false;   // prevout
    uint64_t sl = 0;
    if (!read_cs(b, len, pos, sl)) return false;
    if (sl > 0xffffffffull || sl > len - pos) return false;
    if (i == input_index) {
      out.ss = b + pos;
      out.ss_len = static_cast<uint32_t>(sl);
    }
    pos += sl;
    uint32_t seq = 0;
    if (!read_u32(b, len, pos, seq)) return false;
    if (i == input_index) out.sequence = seq;
  }

  uint64_t vout = 0;
  if (!read_cs(b, len, pos, vout)) return false;
  if (vout > len - pos) return false;   // each output is at least 9 bytes
  for (uint64_t i = 0; i < vout; ++i) {
    if (!read_bytes(b, len, pos, 8)) return false;        // value
    uint64_t sl = 0;
    if (!read_cs(b, len, pos, sl)) return false;
    if (sl > len - pos) return false;
    pos += sl;
  }

  if (extended) {
    for (uint64_t i = 0; i < vin; ++i) {
      uint64_t items = 0;
      if (!read_cs(b, len, pos, items)) return false;
      if (items > len - pos) return false;                // each item >= 1 byte
      if (i == input_index) {
        out.witness_items = items;
        out.witness_nonempty = items != 0;
      }
      for (uint64_t j = 0; j < items; ++j) {
        uint64_t il = 0;
        if (!read_cs(b, len, pos, il)) return false;
        if (il > len - pos) return false;
        pos += il;
      }
    }
  }

  if (!read_u32(b, len, pos, out.locktime)) return false;
  if (pos != len) return false;          // trailing bytes are bad input
  if (input_index >= vin) return false;
  out.vin_count = static_cast<uint32_t>(vin);
  out.extended = extended;
  return true;
}

// ---- VerifyScript (p2shInner 1327-1361, verifyScriptFull 1363-1445) ------
static TwinErr verify_script_full(const TxInfo& tx, const uint8_t* spk,
                                  uint32_t spk_len, const Ctx& ctx, State& st) {
  // SIGPUSHONLY pre-check (Defs.lean:1341-1351): parse failure is
  // SIG_PUSHONLY here, not BAD_OPCODE.
  if (ctx.pol.sigPushOnly) {
    if (classify_push_only(tx.ss, tx.ss_len) != PushOnly::Ok) {
      return TWIN_SIG_PUSHONLY;
    }
  }

  st.stack.n = 0;
  reset_eval(st);
  TwinErr e = eval_script(tx.ss, tx.ss_len, ctx, st);
  if (e != TWIN_OK) return e;
  st.saved = st.stack;

  st.stack = st.saved;
  reset_eval(st);
  e = eval_script(spk, spk_len, ctx, st);
  if (e != TWIN_OK) return e;
  if (st.stack.n == 0) return TWIN_EVAL_FALSE;
  uint32_t tl = 0;
  const uint8_t* top = st_top(st.stack, 1, tl);
  if (!cast_to_bool(top, tl)) return TWIN_EVAL_FALSE;

  const bool spk_wp = is_witness_program(spk, spk_len);
  if (ctx.flags.witness && spk_wp) {
    if (tx.ss_len != 0) return TWIN_WITNESS_MALLEATED;
    return TWIN_INVALID_UNSUPPORTED;   // witness v0/v1 engine: E4
  }

  if (ctx.flags.p2sh && is_p2sh(spk, spk_len)) {
    const PushOnly po = classify_push_only(tx.ss, tx.ss_len);
    if (po == PushOnly::ParseFail) return TWIN_BAD_OPCODE;
    if (po == PushOnly::NotPush) return TWIN_SIG_PUSHONLY;
    if (st.saved.n == 0) return TWIN_UNKNOWN_ERROR;   // Core assert; unreachable
    const uint32_t rlen = st.saved.len[st.saved.n - 1];
    const uint8_t* redeem = st.saved.e[st.saved.n - 1];

    st.stack = st.saved;
    st.stack.n -= 1;
    reset_eval(st);
    e = eval_script(redeem, rlen, ctx, st);
    if (e != TWIN_OK) return e;
    if (st.stack.n == 0) return TWIN_EVAL_FALSE;
    top = st_top(st.stack, 1, tl);
    if (!cast_to_bool(top, tl)) return TWIN_EVAL_FALSE;
    const uint32_t final_len = st.stack.n;
    const bool redeem_wp = is_witness_program(redeem, rlen);

    if (ctx.flags.witness && redeem_wp) {
      if (!ss_equals_push(redeem, rlen, tx.ss, tx.ss_len)) {
        return TWIN_WITNESS_MALLEATED_P2SH;
      }
      return TWIN_INVALID_UNSUPPORTED;   // witness v0 engine: E4
    }
    if (ctx.pol.cleanstack && final_len != 1) return TWIN_CLEANSTACK;
    if (ctx.flags.witness && tx.witness_nonempty) {
      const bool covered = redeem_wp && ss_equals_push(redeem, rlen, tx.ss, tx.ss_len);
      if (!covered) return TWIN_WITNESS_UNEXPECTED;
    }
    return TWIN_OK;
  }

  if (ctx.pol.cleanstack && st.stack.n != 1) return TWIN_CLEANSTACK;
  if (ctx.flags.witness && tx.witness_nonempty && !spk_wp) {
    return TWIN_WITNESS_UNEXPECTED;
  }
  return TWIN_OK;
}

static int result_code(TwinErr e) {
  switch (e) {
    case TWIN_OK: return 1;
    case TWIN_BAD_INPUT: return 2;
    case TWIN_TAPROOT_DATA_UNAVAILABLE:
    case TWIN_INVALID_UNSUPPORTED: return 3;
    default: return 0;
  }
}

}  // namespace twin

// ---- contract boundary (ABI.md §1/§2, tape.md §7) -----------------------
extern "C" int twin_error_to_core(int e) {
  if (e < 0 || e >= static_cast<int>(twin::TWIN_ERR_COUNT)) return -1;
  return twin::core_ordinal(static_cast<twin::TwinErr>(e));
}

extern "C" int twin_result_code(int e) {
  if (e < 0 || e >= static_cast<int>(twin::TWIN_ERR_COUNT)) return -1;
  return twin::result_code(static_cast<twin::TwinErr>(e));
}

extern "C" int equiv_entry(
    const uint8_t* tx_bytes, uint64_t tx_len,
    const uint8_t* spk,      uint64_t spk_len,
    int64_t amount, uint32_t input_index, uint64_t flags,
    equiv_error_kind* error_kind) {
  using namespace twin;
  if (error_kind) *error_kind = EQUIV_ERR_UNKNOWN_ERROR;

  // ---- domain checks (result 2), no engine semantics ----
  if (tx_len == 0 || tx_bytes == nullptr) return 2;
  if (spk_len != 0 && spk == nullptr) return 2;
  if (amount < 0 || static_cast<uint64_t>(amount) > MAX_MONEY) return 2;
  if ((flags & ~FLAG_MASK) != 0) return 2;
  if ((flags & F_WITNESS) != 0 && (flags & F_P2SH) == 0) return 2;
  if ((flags & F_CLEANSTACK) != 0 &&
      ((flags & F_P2SH) == 0 || (flags & F_WITNESS) == 0)) return 2;
  if (spk_len > 0xffffffffull) return 2;

  TxInfo tx;
  if (!decode_tx(tx_bytes, tx_len, input_index, tx)) return 2;
  if (input_index >= tx.vin_count) return 2;

  State* st = new (std::nothrow) State;
  if (st == nullptr) return 3;
  const Ctx ctx = make_ctx(flags);
  TwinErr e;
  try {
    e = verify_script_full(tx, spk, static_cast<uint32_t>(spk_len), ctx, *st);
  } catch (...) {
    delete st;
    return 3;
  }
  delete st;
  if (error_kind) {
    *error_kind = static_cast<equiv_error_kind>(core_ordinal(e));
  }
  return result_code(e);
}

// 7-argument convenience wrapper (ABI.md §1); non-normative.
extern "C" int entry(
    const uint8_t* tx_bytes, uint64_t tx_len,
    const uint8_t* spk,      uint64_t spk_len,
    int64_t amount, uint32_t input_index, uint64_t flags) {
  return equiv_entry(tx_bytes, tx_len, spk, spk_len, amount, input_index, flags, nullptr);
}

// Retained name for the E0 smoke driver; same semantics as equiv_entry.
extern "C" int twin_entry(
    const uint8_t* tx_bytes, uint64_t tx_len,
    const uint8_t* spk,      uint64_t spk_len,
    int64_t amount, uint32_t input_index, uint64_t flags,
    int32_t* error_kind) {
  equiv_error_kind k = EQUIV_ERR_UNKNOWN_ERROR;
  const int rc = equiv_entry(tx_bytes, tx_len, spk, spk_len, amount, input_index,
                             flags, &k);
  if (error_kind) *error_kind = static_cast<int32_t>(k);
  return rc;
}
