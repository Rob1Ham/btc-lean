// smoke_driver.cpp -- hand-written test harness for the generated twin.
//
// NOT part of the engine or the trust base beyond exercise selection.  It
// calls the normative contract symbol `equiv_entry` and compares
// (result, Core ScriptError ordinal).  Tapes are built in-process with
// TX_WITH_WITNESS serialization (tape.md §2); scriptSig is carried only in
// the tx bytes, so a test that passes through a scriptSig also exercises the
// decoder.

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <tuple>
#include <vector>

#include "error_kind.h"

extern "C" int equiv_entry(const uint8_t*, uint64_t, const uint8_t*, uint64_t,
                           int64_t, uint32_t, uint64_t, equiv_error_kind*);
extern "C" int twin_error_to_core(int);
extern "C" int twin_result_code(int);

namespace {

using Bytes = std::vector<uint8_t>;

Bytes V(std::initializer_list<int> xs) {
  Bytes b;
  for (int x : xs) b.push_back(static_cast<uint8_t>(x));
  return b;
}

Bytes R(uint32_t n, int byte) {
  return Bytes(n, static_cast<uint8_t>(byte));
}

Bytes H(const char* hex) {
  Bytes b;
  for (size_t i = 0; hex[i] && hex[i + 1]; i += 2) {
    auto nib = [](char c) -> int {
      if (c >= '0' && c <= '9') return c - '0';
      if (c >= 'a' && c <= 'f') return c - 'a' + 10;
      return c - 'A' + 10;
    };
    b.push_back(static_cast<uint8_t>((nib(hex[i]) << 4) | nib(hex[i + 1])));
  }
  return b;
}

void put_u32(Bytes& b, uint32_t v) {
  for (int i = 0; i < 4; ++i) b.push_back(static_cast<uint8_t>(v >> (8 * i)));
}
void put_cs(Bytes& b, uint64_t v) {
  if (v < 0xfd) {
    b.push_back(static_cast<uint8_t>(v));
  } else if (v <= 0xffff) {
    b.push_back(0xfd);
    b.push_back(static_cast<uint8_t>(v));
    b.push_back(static_cast<uint8_t>(v >> 8));
  } else {
    b.push_back(0xfe);
    for (int i = 0; i < 4; ++i) b.push_back(static_cast<uint8_t>(v >> (8 * i)));
  }
}

// Canonical push (CheckMinimalPush's forms; used only to build test scripts).
Bytes push(const Bytes& d) {
  Bytes b;
  if (d.empty()) {
    b.push_back(0x00);
  } else if (d.size() <= 75) {
    b.push_back(static_cast<uint8_t>(d.size()));
    b.insert(b.end(), d.begin(), d.end());
  } else if (d.size() <= 0xff) {
    b.push_back(0x4c);
    b.push_back(static_cast<uint8_t>(d.size()));
    b.insert(b.end(), d.begin(), d.end());
  } else {
    b.push_back(0x4d);
    b.push_back(static_cast<uint8_t>(d.size()));
    b.push_back(static_cast<uint8_t>(d.size() >> 8));
    b.insert(b.end(), d.begin(), d.end());
  }
  return b;
}

// Non-extended TX_WITH_WITNESS: one input, one empty output.  `wit == nullptr`
// selects the legacy form; otherwise the extended marker + per-input stack.
Bytes make_tx(const Bytes& ss, const std::vector<Bytes>* wit) {
  Bytes t;
  put_u32(t, 2);                           // version
  if (wit != nullptr) {
    t.push_back(0x00);                     // marker
    t.push_back(0x01);                     // flags: witness present
  }
  put_cs(t, 1);                            // vin count
  t.insert(t.end(), 32, 0x00);             // prevout txid
  put_u32(t, 0xffffffffu);                 // prevout n
  put_cs(t, ss.size());
  t.insert(t.end(), ss.begin(), ss.end());
  put_u32(t, 0xffffffffu);                 // sequence
  put_cs(t, 1);                            // vout count
  for (int i = 0; i < 8; ++i) t.push_back(0);  // value 0
  put_cs(t, 0);                            // empty output script
  if (wit != nullptr) {
    put_cs(t, wit->size());
    for (const Bytes& item : *wit) {
      put_cs(t, item.size());
      t.insert(t.end(), item.begin(), item.end());
    }
  }
  put_u32(t, 0);                           // locktime
  return t;
}

struct Case {
  std::string name;
  Bytes ss;
  Bytes spk;
  std::vector<Bytes> wit;
  bool has_wit = false;
  uint64_t flags = 0;
  int64_t amount = 0;
  uint32_t idx = 0;
  int want_rc = 1;
  int want_err = EQUIV_ERR_OK;
  bool trailing = false;
  bool empty_tx = false;
  bool null_spk = false;
  bool use_raw = false;
  Bytes raw;
};

std::vector<Case> cases;

void add(const std::string& name, Bytes ss, Bytes spk, uint64_t flags,
         int rc, int err) {
  Case c;
  c.name = name;
  c.ss = std::move(ss);
  c.spk = std::move(spk);
  c.flags = flags;
  c.want_rc = rc;
  c.want_err = err;
  cases.push_back(std::move(c));
}
void add_wit(const std::string& name, Bytes ss, Bytes spk, uint64_t flags,
             std::vector<Bytes> wit, int rc, int err) {
  Case c;
  c.name = name;
  c.ss = std::move(ss);
  c.spk = std::move(spk);
  c.flags = flags;
  c.wit = std::move(wit);
  c.has_wit = true;
  c.want_rc = rc;
  c.want_err = err;
  cases.push_back(std::move(c));
}

void add_hash(const char* name, const Bytes& data, int op, const char* digest) {
  Bytes spk = push(data);
  spk.push_back(static_cast<uint8_t>(op));
  const Bytes expected = push(H(digest));
  spk.insert(spk.end(), expected.begin(), expected.end());
  spk.push_back(0x87);  // EQUAL
  add(name, {}, spk, 0, 1, EQUIV_ERR_OK);
}

void build_cases() {
  // ---- contract, eager parse, limits -----------------------------------
  add("push_true", {}, V({0x51}), 0, 1, EQUIV_ERR_OK);
  add("push_false", {}, V({0x00}), 0, 0, EQUIV_ERR_EVAL_FALSE);
  add("truncated_push", {}, V({0x02, 0x01}), 0, 0, EQUIV_ERR_BAD_OPCODE);
  // F-DIV-TWIN-001: Lean parses eagerly, Core decodes per op.  This tail is
  // malformed, so the twin reports BAD_OPCODE even though Core would hit the
  // empty-stack VERIFY first.
  add("fdiv_eager_parse", {}, V({0x69, 0x02, 0x01}), 0, 0,
      EQUIV_ERR_BAD_OPCODE);
  add("pick_nonminimal_num", {}, V({0x00, 0x00, 0x02, 0x00, 0x00, 0x79}),
      0x40, 0, EQUIV_ERR_SCRIPTNUM);
  add("script_too_large", {}, Bytes(10001, 0x51), 0, 0, EQUIV_ERR_SCRIPT_SIZE);
  {
    Bytes spk = V({0x4d, 0x09, 0x02});
    spk.insert(spk.end(), 521, 0x00);
    spk.push_back(0x51);
    add("push_too_large", {}, spk, 0, 0, EQUIV_ERR_PUSH_SIZE);
  }
  add("reserved", {}, V({0x50}), 0, 0, EQUIV_ERR_BAD_OPCODE);
  add("disabled", {}, V({0x7e}), 0, 0, EQUIV_ERR_DISABLED_OPCODE);
  add("op_return", {}, V({0x6a}), 0, 0, EQUIV_ERR_OP_RETURN);
  add("nop1", {}, V({0xb0, 0x51}), 0, 1, EQUIV_ERR_OK);
  add("nop1_discouraged", {}, V({0xb0, 0x51}), 0x80, 0,
      EQUIV_ERR_DISCOURAGE_UPGRADABLE_NOPS);
  add("codesep", {}, V({0xab, 0x51}), 0, 1, EQUIV_ERR_OK);
  add("codesep_const", {}, V({0xab, 0x51}), 0x10000, 0,
      EQUIV_ERR_OP_CODESEPARATOR);
  // Lean checks CONST_SCRIPTCODE before fExec; Core checks inside the
  // executed switch.  This is F-DIV-TWIN-002, mirrored deliberately.
  add("codesep_const_unexecuted", {}, V({0x00, 0x63, 0xab, 0x68, 0x51}),
      0x10000, 0, EQUIV_ERR_OP_CODESEPARATOR);
  add("codesep_unexecuted_ok", {}, V({0x00, 0x63, 0xab, 0x68, 0x51}), 0, 1,
      EQUIV_ERR_OK);
  add("minimaldata_reject", {}, V({0x01, 0x01}), 0x40, 0,
      EQUIV_ERR_MINIMALDATA);
  add("minimaldata_off", {}, V({0x01, 0x01}), 0, 1, EQUIV_ERR_OK);
  add("sigpushonly", V({0x51, 0x61}), V({0x51}), 0x20, 0,
      EQUIV_ERR_SIG_PUSHONLY);
  add("sigpushonly_ok", V({0x51}), V({0x51}), 0x20, 1, EQUIV_ERR_OK);
  add("policy_flags_inert", {}, V({0x51}), 0xd01e, 1, EQUIV_ERR_OK);
  add("taproot_flag_inert", {}, V({0x51}), 0x20000, 1, EQUIV_ERR_OK);
  // Each policy/activation bit alone, with a script that never exercises the
  // gated path, must stay inert (ordinary flagged rows are not result 3).
  const std::vector<std::pair<const char*, uint64_t>> inert_flags = {
      {"flags_only_p2sh", 0x000001},
      {"flags_only_minimaldata", 0x000040},
      {"flags_only_discourage_nops", 0x000080},
      {"flags_only_cltv", 0x000200},
      {"flags_only_csv", 0x000400},
      {"flags_only_witness", 0x000801},
      {"flags_only_cleanstack", 0x000901},
      {"flags_only_const", 0x010000},
  };
  for (const auto& t : inert_flags) {
    add(t.first, {}, V({0x51}), t.second, 1, EQUIV_ERR_OK);
  }
  add("cleanstack", {}, V({0x51, 0x51}), 0x901, 0, EQUIV_ERR_CLEANSTACK);
  add("cltv_noflag", {}, V({0xb1, 0x51}), 0, 1, EQUIV_ERR_OK);
  add("csv_noflag", {}, V({0xb2, 0x51}), 0, 1, EQUIV_ERR_OK);
  add("cltv_flag_unsupported", {}, V({0x51, 0xb1}), 0x200, 3,
      EQUIV_ERR_UNKNOWN_ERROR);
  add("csv_flag_unsupported", {}, V({0x51, 0xb2}), 0x400, 3,
      EQUIV_ERR_UNKNOWN_ERROR);
  add("checksigadd_base", {}, V({0xba}), 0, 0, EQUIV_ERR_BAD_OPCODE);

  // ---- tx decode / flags / witnesses / P2SH ----------------------------
  add("scriptsig_order", V({0x51}), V({0x75, 0x51}), 0, 1, EQUIV_ERR_OK);
  add("scriptsig_only", V({0x51}), V({0x75}), 0, 0, EQUIV_ERR_EVAL_FALSE);
  add("strictenc_inert", {}, V({0x51}), 0x02, 1, EQUIV_ERR_OK);
  add("p2sh_pass", push(V({0x51})),
      V({0xa9, 0x14, 0xda, 0x17, 0x45, 0xe9, 0xb5, 0x49, 0xbd, 0x0b, 0xfa,
         0x1a, 0x56, 0x99, 0x71, 0xc7, 0x7e, 0xba, 0x30, 0xcd, 0x5a, 0x4b,
         0x87}),
      0x01, 1, EQUIV_ERR_OK);
  add("p2sh_false", push(V({0x00})),
      V({0xa9, 0x14, 0x9f, 0x7f, 0xd0, 0x96, 0xd3, 0x7e, 0xd2, 0xc0, 0xe3,
         0xf7, 0xf0, 0xcf, 0xc9, 0x24, 0xbe, 0xef, 0x4f, 0xfc, 0xeb, 0x68,
         0x87}),
      0x01, 0, EQUIV_ERR_EVAL_FALSE);
  add("p2sh_sigpushonly", V({0x01, 0x51, 0x61}),
      V({0xa9, 0x14, 0xda, 0x17, 0x45, 0xe9, 0xb5, 0x49, 0xbd, 0x0b, 0xfa,
         0x1a, 0x56, 0x99, 0x71, 0xc7, 0x7e, 0xba, 0x30, 0xcd, 0x5a, 0x4b,
         0x87}),
      0x01, 0, EQUIV_ERR_SIG_PUSHONLY);
  add("p2sh_flag_off", push(V({0x51})),
      V({0xa9, 0x14, 0xda, 0x17, 0x45, 0xe9, 0xb5, 0x49, 0xbd, 0x0b, 0xfa,
         0x1a, 0x56, 0x99, 0x71, 0xc7, 0x7e, 0xba, 0x30, 0xcd, 0x5a, 0x4b,
         0x87}),
      0, 1, EQUIV_ERR_OK);
  {
    // Redeem script 00 14 <20-byte program>: a P2SH-wrapped witness program.
    Bytes redeem = V({0x00, 0x14});
    redeem.insert(redeem.end(), 20, 0x11);
    const Bytes spk = V({0xa9, 0x14, 0x27, 0xef, 0xfe, 0x58, 0xf4, 0x3f,
                         0x92, 0xc8, 0x59, 0x7b, 0x7c, 0x48, 0x86, 0xf7,
                         0xcc, 0xaf, 0xb1, 0x1b, 0x02, 0x3e, 0x87});
    // Canonical push: reaches the E4 witness engine (result 3).
    add("p2sh_witness_covered", push(redeem), spk, 0x801, 3,
        EQUIV_ERR_UNKNOWN_ERROR);
    // PUSHDATA1 form differs from `CScript() << redeem`: malleated.
    Bytes ss = V({0x4c, 0x16});
    ss.insert(ss.end(), redeem.begin(), redeem.end());
    add("p2sh_witness_malleated", ss, spk, 0x801, 0,
        EQUIV_ERR_WITNESS_MALLEATED_P2SH);
  }
  add("p2sh_cleanstack", push(V({0x51, 0x51})),
      V({0xa9, 0x14, 0xc8, 0xcd, 0xe4, 0xcd, 0x53, 0x4c, 0x55, 0xce, 0x1c,
         0xdb, 0xf1, 0xe6, 0x50, 0x5a, 0x8b, 0x1c, 0x53, 0xc8, 0xf5, 0x50,
         0x87}),
      0x901, 0, EQUIV_ERR_CLEANSTACK);
  add_wit("p2sh_witness_unexpected", push(V({0x51})),
          V({0xa9, 0x14, 0xda, 0x17, 0x45, 0xe9, 0xb5, 0x49, 0xbd, 0x0b,
             0xfa, 0x1a, 0x56, 0x99, 0x71, 0xc7, 0x7e, 0xba, 0x30, 0xcd,
             0x5a, 0x4b, 0x87}),
          0x801, {V({0x01})}, 0, EQUIV_ERR_WITNESS_UNEXPECTED);
  {
    Bytes wp = V({0x00, 0x14});
    wp.insert(wp.end(), 20, 0x11);
    add("witness_bare_empty", {}, wp, 0x801, 3, EQUIV_ERR_UNKNOWN_ERROR);
    add("witness_malleated", V({0x51}), wp, 0x801, 0,
        EQUIV_ERR_WITNESS_MALLEATED);
  }
  add_wit("witness_unexpected", {}, V({0x51}), 0x801, {V({0x01})}, 0,
          EQUIV_ERR_WITNESS_UNEXPECTED);
  add_wit("witness_ignored_noflag", {}, V({0x51}), 0, {V({0x01})}, 1,
          EQUIV_ERR_OK);

  // ---- required stack / altstack / flow opcodes ------------------------
  add("dup", {}, V({0x51, 0x76, 0x75}), 0, 1, EQUIV_ERR_OK);
  add("drop", {}, V({0x51, 0x52, 0x75}), 0, 1, EQUIV_ERR_OK);
  add("swap", {}, V({0x00, 0x51, 0x7c, 0x75, 0x69, 0x51}), 0, 1,
      EQUIV_ERR_OK);
  add("rot", {}, V({0x51, 0x52, 0x53, 0x7b, 0x6d, 0x51}), 0, 1,
      EQUIV_ERR_OK);
  add("toaltstack", {}, V({0x51, 0x6b, 0x51}), 0, 1, EQUIV_ERR_OK);
  add("fromaltstack", {}, V({0x51, 0x6b, 0x6c}), 0, 1, EQUIV_ERR_OK);
  add("2drop", {}, V({0x51, 0x52, 0x6d, 0x51}), 0, 1, EQUIV_ERR_OK);
  add("2dup", {}, V({0x51, 0x52, 0x6e, 0x6d, 0x6d, 0x51}), 0, 1,
      EQUIV_ERR_OK);
  add("3dup", {}, V({0x51, 0x52, 0x53, 0x6f, 0x6d, 0x6d, 0x6d, 0x51}), 0, 1,
      EQUIV_ERR_OK);
  add("2over", {}, V({0x51, 0x52, 0x53, 0x54, 0x70, 0x6d, 0x6d, 0x6d,
                      0x51}), 0, 1, EQUIV_ERR_OK);
  add("2rot", {}, V({0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x71, 0x6d, 0x6d,
                     0x6d, 0x51}), 0, 1, EQUIV_ERR_OK);
  add("2swap", {}, V({0x51, 0x52, 0x53, 0x54, 0x72, 0x6d, 0x6d, 0x51}), 0, 1,
      EQUIV_ERR_OK);
  add("ifdup", {}, V({0x51, 0x73, 0x75}), 0, 1, EQUIV_ERR_OK);
  add("depth", {}, V({0x51, 0x74, 0x51, 0x87}), 0, 1, EQUIV_ERR_OK);
  add("pick", {}, V({0x51, 0x52, 0x00, 0x79, 0x75}), 0, 1, EQUIV_ERR_OK);
  add("roll", {}, V({0x51, 0x52, 0x01, 0x7a, 0x75}), 0, 1, EQUIV_ERR_OK);
  add("tuck", {}, V({0x51, 0x52, 0x7d, 0x6d, 0x51}), 0, 1, EQUIV_ERR_OK);
  add("nip", {}, V({0x51, 0x52, 0x77, 0x75, 0x51}), 0, 1, EQUIV_ERR_OK);
  add("over", {}, V({0x51, 0x52, 0x78, 0x6d, 0x51}), 0, 1, EQUIV_ERR_OK);
  add("if_true", {}, V({0x51, 0x63, 0x52, 0x68}), 0, 1, EQUIV_ERR_OK);
  add("if_false", {}, V({0x00, 0x63, 0x52, 0x68, 0x51}), 0, 1,
      EQUIV_ERR_OK);
  add("notif", {}, V({0x00, 0x64, 0x52, 0x68}), 0, 1, EQUIV_ERR_OK);
  add("else", {}, V({0x00, 0x63, 0x52, 0x67, 0x53, 0x68}), 0, 1,
      EQUIV_ERR_OK);
  add("verify", {}, V({0x51, 0x69, 0x51}), 0, 1, EQUIV_ERR_OK);
  add("verify_false", {}, V({0x00, 0x69}), 0, 0, EQUIV_ERR_VERIFY);
  add("equal", {}, V({0x51, 0x51, 0x87}), 0, 1, EQUIV_ERR_OK);
  add("equal_false_size", {}, V({0x51, 0x52, 0x87, 0x82, 0x00, 0x87}), 0, 1,
      EQUIV_ERR_OK);
  add("equalverify", {}, V({0x51, 0x51, 0x88, 0x51}), 0, 1, EQUIV_ERR_OK);
  add("size", {}, V({0x51, 0x82, 0x51, 0x87}), 0, 1, EQUIV_ERR_OK);
  add("add", {}, V({0x51, 0x52, 0x93, 0x53, 0x87}), 0, 1, EQUIV_ERR_OK);
  add("within", {}, V({0x52, 0x51, 0x53, 0xa5}), 0, 1, EQUIV_ERR_OK);
  add("sub_order", {}, V({0x55, 0x53, 0x94, 0x52, 0x9c}), 0, 1,
      EQUIV_ERR_OK);
  add("lessthan", {}, V({0x52, 0x53, 0x9f}), 0, 1, EQUIV_ERR_OK);
  add("min", {}, V({0x55, 0x53, 0xa3, 0x53, 0x9c}), 0, 1, EQUIV_ERR_OK);
  add("max", {}, V({0x55, 0x53, 0xa4, 0x55, 0x9c}), 0, 1, EQUIV_ERR_OK);

  // ---- hashes (known answers, empty and "abc") -------------------------
  add_hash("sha256_empty", {}, 0xa8,
           "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
  add_hash("sha256_abc", V({0x61, 0x62, 0x63}), 0xa8,
           "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
  add_hash("ripemd160_empty", {}, 0xa6,
           "9c1185a5c5e9fc54612808977ee8f548b2258d31");
  add_hash("ripemd160_abc", V({0x61, 0x62, 0x63}), 0xa6,
           "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc");
  add_hash("hash160_empty", {}, 0xa9,
           "b472a266d0bd89c13706a4132ccfb16f7c3b9fcb");
  add_hash("hash160_abc", V({0x61, 0x62, 0x63}), 0xa9,
           "bb1be98c142444d7a56aa3981c3942a978e4dc33");
  add_hash("hash256_empty", {}, 0xaa,
           "5df6e0e2761359d30a8275058e299fcc0381534545f55cf43e41983f5d4c9456");
  add_hash("hash256_abc", V({0x61, 0x62, 0x63}), 0xaa,
           "4f8b42c22dd3729b519ba6f68d2da7cc5b2d606d05daed5ad5128cc03e6c6358");
  // Padding-boundary / multi-block vectors: 64 bytes exercises the final
  // length field with no extra block; 200 bytes forces multiple blocks.
  add_hash("sha256_64a", R(64, 'a'), 0xa8,
           "ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb");
  add_hash("ripemd160_64a", R(64, 'a'), 0xa6,
           "9dfb7d374ad924f3f88de96291c33e9abed53e32");
  add_hash("hash160_64a", R(64, 'a'), 0xa9,
           "57591c6b8f00df7d36a642cc94021dda9ccd43fc");
  add_hash("hash256_64a", R(64, 'a'), 0xaa,
           "64d28424725a6f219efb17d6f8e4036719bf9e1a8ec2388c22cfb5fc412d46bc");
  add_hash("sha256_200b", R(200, 'b'), 0xa8,
           "aaebc35c4c4e2cc7ac7c65812a7fa476d807b9f3fc60d478dfe098ceeb122321");
  add_hash("ripemd160_200b", R(200, 'b'), 0xa6,
           "ec80c6cb400f788693e26a86cf82e1ce74b70613");
  add_hash("hash160_200b", R(200, 'b'), 0xa9,
           "44fa8aab9501ba1e3652d003f9118ffbb9c2ed63");
  add_hash("hash256_200b", R(200, 'b'), 0xaa,
           "d0dbbd5b474c758244c5674c125758939dc8e4df1e03cf9b1b38d9665e469577");

  // ---- underflow / altstack-empty / conditional errors -----------------
  const std::vector<std::tuple<const char*, int, int>> under = {
      {"u_drop", 0x75, EQUIV_ERR_INVALID_STACK_OPERATION},
      {"u_dup", 0x76, EQUIV_ERR_INVALID_STACK_OPERATION},
      {"u_ifdup", 0x73, EQUIV_ERR_INVALID_STACK_OPERATION},
      {"u_verify", 0x69, EQUIV_ERR_INVALID_STACK_OPERATION},
      {"u_size", 0x82, EQUIV_ERR_INVALID_STACK_OPERATION},
      {"u_toalt", 0x6b, EQUIV_ERR_INVALID_STACK_OPERATION},
      {"u_fromalt", 0x6c, EQUIV_ERR_INVALID_ALTSTACK_OPERATION},
      {"u_swap", 0x7c, EQUIV_ERR_INVALID_STACK_OPERATION},
      {"u_tuck", 0x7d, EQUIV_ERR_INVALID_STACK_OPERATION},
      {"u_nip", 0x77, EQUIV_ERR_INVALID_STACK_OPERATION},
      {"u_over", 0x78, EQUIV_ERR_INVALID_STACK_OPERATION},
      {"u_pick", 0x79, EQUIV_ERR_INVALID_STACK_OPERATION},
      {"u_roll", 0x7a, EQUIV_ERR_INVALID_STACK_OPERATION},
      {"u_2drop", 0x6d, EQUIV_ERR_INVALID_STACK_OPERATION},
      {"u_2dup", 0x6e, EQUIV_ERR_INVALID_STACK_OPERATION},
      {"u_2over", 0x70, EQUIV_ERR_INVALID_STACK_OPERATION},
      {"u_2rot", 0x71, EQUIV_ERR_INVALID_STACK_OPERATION},
      {"u_2swap", 0x72, EQUIV_ERR_INVALID_STACK_OPERATION},
      {"u_3dup", 0x6f, EQUIV_ERR_INVALID_STACK_OPERATION},
      {"u_rot", 0x7b, EQUIV_ERR_INVALID_STACK_OPERATION},
      {"u_if", 0x63, EQUIV_ERR_INVALID_STACK_OPERATION},
      {"u_notif", 0x64, EQUIV_ERR_INVALID_STACK_OPERATION},
      {"u_equal", 0x87, EQUIV_ERR_INVALID_STACK_OPERATION},
      {"u_equalverify", 0x88, EQUIV_ERR_INVALID_STACK_OPERATION},
      {"u_sha256", 0xa8, EQUIV_ERR_INVALID_STACK_OPERATION},
      {"u_hash160", 0xa9, EQUIV_ERR_INVALID_STACK_OPERATION},
      {"u_within", 0xa5, EQUIV_ERR_INVALID_STACK_OPERATION},
  };
  for (const auto& t : under) {
    add(std::get<0>(t), {}, V({std::get<1>(t)}), 0, 0, std::get<2>(t));
  }
  add("else_unbalanced", {}, V({0x67}), 0, 0,
      EQUIV_ERR_UNBALANCED_CONDITIONAL);
  add("endif_unbalanced", {}, V({0x68}), 0, 0,
      EQUIV_ERR_UNBALANCED_CONDITIONAL);

  // ---- unsupported opcodes must be result 3, never a verdict -----------
  const std::vector<std::tuple<const char*, int>> unsup = {
      {"u_checksig", 0xac}, {"u_checksigverify", 0xad},
      {"u_cms", 0xae},      {"u_cmsverify", 0xaf},
      {"u_sha1", 0xa7},
  };
  for (const auto& t : unsup) {
    add(std::get<0>(t), {}, V({std::get<1>(t)}), 0, 3,
        EQUIV_ERR_UNKNOWN_ERROR);
  }
  // Reserved/unknown wires are consensus BAD_OPCODE, not result 3.
  add("undefined_bb", {}, V({0xbb}), 0, 0, EQUIV_ERR_BAD_OPCODE);
  add("undefined_fe", {}, V({0xfe}), 0, 0, EQUIV_ERR_BAD_OPCODE);

  // ---- domain (result 2) -----------------------------------------------
  {
    Case c;
    c.name = "tx_empty";
    c.empty_tx = true;
    c.want_rc = 2;
    c.want_err = EQUIV_ERR_UNKNOWN_ERROR;
    cases.push_back(c);
  }
  {
    Case c;
    c.name = "tx_trailing";
    c.spk = V({0x51});
    c.trailing = true;
    c.want_rc = 2;
    c.want_err = EQUIV_ERR_UNKNOWN_ERROR;
    cases.push_back(c);
  }
  {
    Case c;
    c.name = "tx_bad_index";
    c.spk = V({0x51});
    c.idx = 1;
    c.want_rc = 2;
    c.want_err = EQUIV_ERR_UNKNOWN_ERROR;
    cases.push_back(c);
  }
  {
    Case c;
    c.name = "tx_bad_amount";
    c.spk = V({0x51});
    c.amount = 2100000000000001ll;
    c.want_rc = 2;
    c.want_err = EQUIV_ERR_UNKNOWN_ERROR;
    cases.push_back(c);
  }
  {
    Case c;
    c.name = "tx_bad_flag_mask";
    c.spk = V({0x51});
    c.flags = 0x200000;
    c.want_rc = 2;
    c.want_err = EQUIV_ERR_UNKNOWN_ERROR;
    cases.push_back(c);
  }
  {
    Case c;
    c.name = "tx_witness_without_p2sh";
    c.spk = V({0x51});
    c.flags = 0x800;
    c.want_rc = 2;
    c.want_err = EQUIV_ERR_UNKNOWN_ERROR;
    cases.push_back(c);
  }
  {
    Case c;
    c.name = "tx_null_spk";
    c.spk = V({0x51});
    c.null_spk = true;
    c.want_rc = 2;
    c.want_err = EQUIV_ERR_UNKNOWN_ERROR;
    cases.push_back(c);
  }
  {
    // Non-canonical CompactSize for the scriptSig length (fd 01 00).
    Case c;
    c.name = "tx_noncanonical_cs";
    c.use_raw = true;
    c.raw = {};
    put_u32(c.raw, 2);
    put_cs(c.raw, 1);
    c.raw.insert(c.raw.end(), 32, 0);
    put_u32(c.raw, 0xffffffffu);
    c.raw.push_back(0xfd);
    c.raw.push_back(0x01);
    c.raw.push_back(0x00);
    c.raw.push_back(0x51);
    put_u32(c.raw, 0xffffffffu);
    put_cs(c.raw, 1);
    for (int i = 0; i < 8; ++i) c.raw.push_back(0);
    put_cs(c.raw, 0);
    put_u32(c.raw, 0);
    c.want_rc = 2;
    c.want_err = EQUIV_ERR_UNKNOWN_ERROR;
    cases.push_back(c);
  }
}

bool mapping_ok() {
  bool ok = true;
  for (int i = 0; i < 58; ++i) {
    const int core = twin_error_to_core(i);
    if (core < 0 || core >= EQUIV_ERR_COUNT) {
      std::printf("map id %d -> %d OUT OF RANGE\n", i, core);
      ok = false;
    }
    const int rc = twin_result_code(i);
    if (rc < 0 || rc > 3) {
      std::printf("result id %d -> %d OUT OF RANGE\n", i, rc);
      ok = false;
    }
  }
  for (int id : {56, 57, 37}) {
    if (twin_error_to_core(id) != EQUIV_ERR_UNKNOWN_ERROR) {
      std::printf("sentinel %d names a consensus error\n", id);
      ok = false;
    }
  }
  if (twin_error_to_core(56) == EQUIV_ERR_OK ||
      twin_result_code(56) != 3) {
    std::printf("unsupported sentinel is not distinguished\n");
    ok = false;
  }
  return ok;
}

}  // namespace

int main() {
  build_cases();
  int failures = 0;
  if (!mapping_ok()) {
    std::printf("mapping_coverage FAIL\n");
    ++failures;
  } else {
    std::printf("mapping_coverage             PASS (58/58)\n");
  }

  for (const Case& c : cases) {
    Bytes tx;
    if (c.use_raw) {
      tx = c.raw;
    } else if (!c.empty_tx) {
      tx = make_tx(c.ss, c.has_wit ? &c.wit : nullptr);
      if (c.trailing) tx.push_back(0x00);
    }
    const uint8_t* txp = c.empty_tx ? nullptr : tx.data();
    const uint64_t txl = c.empty_tx ? 0 : tx.size();
    const uint8_t* sp = c.null_spk ? nullptr : c.spk.data();
    const uint64_t spl = c.spk.size();
    equiv_error_kind k = EQUIV_ERR_UNKNOWN_ERROR;
    const int rc = equiv_entry(txp, txl, sp, spl, c.amount, c.idx, c.flags, &k);
    const bool pass = (rc == c.want_rc && static_cast<int>(k) == c.want_err);
    if (!pass) ++failures;
    std::printf("%-28s rc=%d err=%d want=(%d,%d) %s\n", c.name.c_str(), rc,
                static_cast<int>(k), c.want_rc, c.want_err,
                pass ? "PASS" : "FAIL");
  }
  std::printf("cases=%zu failures=%d\n", cases.size() + 1, failures);
  return failures == 0 ? 0 : 1;
}
