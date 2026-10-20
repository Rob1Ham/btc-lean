#include <cstdint>
#include "twin.cpp"

// L leg: the Lean model's handler arms, transcribed line by line from
// spec/core/Bitcoin/Interpreter/Defs.lean, with the operand decode delegated
// to the generated twin's own `decode_num` (twin/runtime.inc:167-188).
//
//   Defs.lean:857-865  OP_CHECKLOCKTIMEVERIFY
//       if !flags.cltv then .ok st
//       else if st.stack.length < 1 then .error .stackUnderflow
//       else match decodeNum pol (topAt st.stack 1) 5 with
//         | .error e => .error e
//         | .ok n =>
//           if n < 0 then .error .negativeLocktime
//           else if !checkLockTimeDef ctx.chk.env n then .error .unsatisfiedLocktime
//           else .ok st
//   Defs.lean:866-875  OP_CHECKSEQUENCEVERIFY
//       same shape with cap 5, then
//       if (n.toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) ≠ 0 then .ok st
//       else if !checkSequenceDef ctx.chk.env n then .error .unsatisfiedLocktime
//   Defs.lean:272-280  checkLockTimeDef
//   Defs.lean:285-296  checkSequenceDef
//   Defs.lean:1069-1090  stepBody.checkMultiSig
//       if ctx.sv = .tapscript then .error .tapscriptCheckMultiSig
//       else if st.stack.length < 1 then .error .stackUnderflow
//       else match decodeNum pol (topAt st.stack 1) 4 with
//         | .error e => .error e
//         | .ok nkv =>
//           if nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv then .error .pubKeyCount
//           else let opCount₂ := st.opCount + nKeys
//                if MAX_OPS_PER_SCRIPT < opCount₂ then .error .opCount
//                else if st.stack.length < nKeys + 2 then .error .stackUnderflow
//                else match decodeNum pol (st.stack[nKeys+1]!) 4 with
//                  | .error e => .error e
//                  | .ok nsv =>
//                    if nsv < 0 ∨ nKeys < nsv then .error .sigCount
//                    else if st.stack.length < nKeys + nSigs + 3 then .error .stackUnderflow
//                    else … .ok
//
// TRUST NOTE.  The generated twin's handler table does not implement these
// arms: twin/ops_ir.py emits `if (!ctx.flags.cltv) return TWIN_OK;
// return TWIN_INVALID_UNSUPPORTED;` for OP_CLTV (and the csv analogue), and
// gen.py lists OP_CHECKMULTISIG as unsupported.  So there is no generated
// handler body to call.  This leg is therefore a reviewed transcription of
// the Defs.lean arms above, and only the decode call itself is generated code
// (twin::decode_num).  The cell does not claim equivalence of the generated
// twin's handler table; it claims the Lean model arms agree with Core.
//
// The decode is dispatched on the concrete length so the twin's `for
// (i < len)` loop (loop bound = symbolic len) is fully unrolled by clang at
// every length in the domain 0..7; the helper body itself is unchanged.
// The min/max caps (4 and 5) are passed as constants, exactly as at the call
// sites.

namespace {

constexpr int64_t LEAN_LOCKTIME_THRESHOLD = 500000000;  // Defs.lean:79
constexpr uint64_t LEAN_SEQUENCE_LOCKTIME_DISABLE_FLAG = 0x80000000ull;
constexpr uint64_t LEAN_SEQUENCE_LOCKTIME_TYPE_FLAG = 0x00400000ull;
constexpr uint64_t LEAN_SEQUENCE_LOCKTIME_MASK = 0x0000ffffull;
constexpr int64_t LEAN_MAX_PUBKEYS_PER_MULTISIG = 20;   // Defs.lean:76
constexpr int64_t LEAN_MAX_OPS_PER_SCRIPT = 201;        // Defs.lean:72

static uint64_t cell_pack(uint32_t res, uint32_t err) {
  return (uint64_t)(res & 3u) | ((uint64_t)(err & 0x3fu) << 2);
}

static uint32_t ord(twin::TwinErr e) {
  return (uint32_t)twin::core_ordinal(e);
}

// The generated twin decode (runtime.inc:167-188) at a concrete length.
static twin::TwinErr lean_decode(const uint8_t* b, uint32_t len, bool minimal,
                                 uint32_t maxSize, int64_t& out) {
  switch (len) {
    case 0: return twin::decode_num(b, 0u, minimal, maxSize, out);
    case 1: return twin::decode_num(b, 1u, minimal, maxSize, out);
    case 2: return twin::decode_num(b, 2u, minimal, maxSize, out);
    case 3: return twin::decode_num(b, 3u, minimal, maxSize, out);
    case 4: return twin::decode_num(b, 4u, minimal, maxSize, out);
    case 5: return twin::decode_num(b, 5u, minimal, maxSize, out);
    case 6: return twin::decode_num(b, 6u, minimal, maxSize, out);
    default: return twin::decode_num(b, 7u, minimal, maxSize, out);
  }
}

// Defs.lean:272-280, checkLockTimeDef.  env.txLockTime and env.txSequence are
// UInt32; the threshold comparison is over Int.
static bool lean_check_lock_time(int64_t n, uint32_t txlt_, uint32_t txseq_) {
  const int64_t txlt = (int64_t)(uint64_t)txlt_;
  if (!((txlt < LEAN_LOCKTIME_THRESHOLD && n < LEAN_LOCKTIME_THRESHOLD) ||
        (txlt >= LEAN_LOCKTIME_THRESHOLD && n >= LEAN_LOCKTIME_THRESHOLD)))
    return false;
  if (n > txlt) return false;
  if ((uint64_t)txseq_ == 0xffffffffull) return false;  // input final
  return true;
}

// Defs.lean:285-296, checkSequenceDef.  n is non-negative at the call site
// (`if n < 0` returned first), so n.toNat is the unsigned magnitude.
static bool lean_check_sequence(int64_t n, uint32_t txver, uint32_t txseq) {
  if (txver < 2u) return false;  // env.txVersion.toUInt32 < 2
  if (((uint64_t)txseq & LEAN_SEQUENCE_LOCKTIME_DISABLE_FLAG) != 0)
    return false;
  const uint64_t mask = LEAN_SEQUENCE_LOCKTIME_TYPE_FLAG | LEAN_SEQUENCE_LOCKTIME_MASK;
  const uint64_t txm = (uint64_t)txseq & mask;
  const uint64_t nm = (uint64_t)n & mask;
  if (!((txm < LEAN_SEQUENCE_LOCKTIME_TYPE_FLAG && nm < LEAN_SEQUENCE_LOCKTIME_TYPE_FLAG) ||
        (txm >= LEAN_SEQUENCE_LOCKTIME_TYPE_FLAG && nm >= LEAN_SEQUENCE_LOCKTIME_TYPE_FLAG)))
    return false;
  return !(nm > txm);
}

}  // namespace

extern "C" uint64_t cell_cltv(uint8_t b0, uint8_t b1, uint8_t b2, uint8_t b3,
                              uint8_t b4, uint8_t len, uint8_t minimal,
                              uint32_t depth, uint32_t txlt, uint32_t txseq,
                              uint8_t cltv_flag) {
  const uint8_t v[5] = {b0, b1, b2, b3, b4};
  const uint32_t l = len & 7u;
  if (!cltv_flag) return cell_pack(1, (uint32_t)EQUIV_ERR_OK);
  if (depth < 1u) return cell_pack(0, ord(twin::TWIN_INVALID_STACK_OPERATION));
  int64_t n = 0;
  const twin::TwinErr e = lean_decode(v, l, minimal != 0, 5u, n);
  if (e != twin::TWIN_OK) return cell_pack(0, ord(e));
  if (n < 0) return cell_pack(0, ord(twin::TWIN_NEGATIVE_LOCKTIME));
  if (!lean_check_lock_time(n, txlt, txseq))
    return cell_pack(0, ord(twin::TWIN_UNSATISFIED_LOCKTIME));
  return cell_pack(1, (uint32_t)EQUIV_ERR_OK);
}

extern "C" uint64_t cell_csv(uint8_t b0, uint8_t b1, uint8_t b2, uint8_t b3,
                             uint8_t b4, uint8_t len, uint8_t minimal,
                             uint32_t depth, uint32_t txver, uint32_t txseq,
                             uint8_t csv_flag) {
  const uint8_t v[5] = {b0, b1, b2, b3, b4};
  const uint32_t l = len & 7u;
  if (!csv_flag) return cell_pack(1, (uint32_t)EQUIV_ERR_OK);
  if (depth < 1u) return cell_pack(0, ord(twin::TWIN_INVALID_STACK_OPERATION));
  int64_t n = 0;
  const twin::TwinErr e = lean_decode(v, l, minimal != 0, 5u, n);
  if (e != twin::TWIN_OK) return cell_pack(0, ord(e));
  if (n < 0) return cell_pack(0, ord(twin::TWIN_NEGATIVE_LOCKTIME));
  if (((uint64_t)n & LEAN_SEQUENCE_LOCKTIME_DISABLE_FLAG) != 0)
    return cell_pack(1, (uint32_t)EQUIV_ERR_OK);
  if (!lean_check_sequence(n, txver, txseq))
    return cell_pack(0, ord(twin::TWIN_UNSATISFIED_LOCKTIME));
  return cell_pack(1, (uint32_t)EQUIV_ERR_OK);
}

extern "C" uint64_t cell_cms(uint8_t k0, uint8_t k1, uint8_t k2, uint8_t k3,
                             uint8_t k4, uint8_t klen, uint8_t s0, uint8_t s1,
                             uint8_t s2, uint8_t s3, uint8_t s4, uint8_t slen,
                             uint8_t minimal, uint32_t depth,
                             uint32_t opcount) {
  const uint8_t kv[5] = {k0, k1, k2, k3, k4};
  const uint8_t sv[5] = {s0, s1, s2, s3, s4};
  const uint32_t kl = klen & 7u;
  const uint32_t sl = slen & 7u;

  if (depth < 1u) return cell_pack(0, ord(twin::TWIN_INVALID_STACK_OPERATION));
  int64_t nkv = 0;
  const twin::TwinErr e1 = lean_decode(kv, kl, minimal != 0, 4u, nkv);
  if (e1 != twin::TWIN_OK) return cell_pack(0, ord(e1));
  if (nkv < 0 || LEAN_MAX_PUBKEYS_PER_MULTISIG < nkv)
    return cell_pack(0, ord(twin::TWIN_PUBKEY_COUNT));
  const int64_t op2 = (int64_t)(uint64_t)opcount + nkv;
  if (LEAN_MAX_OPS_PER_SCRIPT < op2)
    return cell_pack(0, ord(twin::TWIN_OP_COUNT));
  if ((int64_t)(uint64_t)depth < nkv + 2)
    return cell_pack(0, ord(twin::TWIN_INVALID_STACK_OPERATION));
  int64_t nsv = 0;
  const twin::TwinErr e2 = lean_decode(sv, sl, minimal != 0, 4u, nsv);
  if (e2 != twin::TWIN_OK) return cell_pack(0, ord(e2));
  if (nsv < 0 || nkv < nsv) return cell_pack(0, ord(twin::TWIN_SIG_COUNT));
  if ((int64_t)(uint64_t)depth < nkv + nsv + 3)
    return cell_pack(0, ord(twin::TWIN_INVALID_STACK_OPERATION));
  return cell_pack(1, (uint32_t)EQUIV_ERR_OK);
}

// Defs.lean:1048-1059 (OP_CHECKSIGADD):
//   if ctx.sv = .base ∨ ctx.sv = .witnessV0 then .error .badOpcode
//   else if st.stack.length < 3 then .error .stackUnderflow
//   else match checksigAddStep … with
//     | .error e => .error e                    -- decodeNum … 4 → .scriptNum
//     | .ok (r, vw') => .ok st
//   checksigAddStep (Defs.lean:803-811) decodes `num` with cap 4 before
//   evalChecksigTapscript; only the decode error is observed here.
extern "C" uint64_t cell_checksigadd(uint8_t b0, uint8_t b1, uint8_t b2,
                                     uint8_t b3, uint8_t b4, uint8_t len,
                                     uint8_t minimal, uint32_t depth,
                                     uint8_t sigversion) {
  const uint8_t v[5] = {b0, b1, b2, b3, b4};
  const uint32_t l = len & 7u;
  if (sigversion == 0u || sigversion == 1u)
    return cell_pack(0, ord(twin::TWIN_BAD_OPCODE));
  if (depth < 3u) return cell_pack(0, ord(twin::TWIN_INVALID_STACK_OPERATION));
  int64_t n = 0;
  const twin::TwinErr e = lean_decode(v, l, minimal != 0, 4u, n);
  if (e != twin::TWIN_OK) return cell_pack(0, ord(e));
  return cell_pack(1, (uint32_t)EQUIV_ERR_OK);
}
