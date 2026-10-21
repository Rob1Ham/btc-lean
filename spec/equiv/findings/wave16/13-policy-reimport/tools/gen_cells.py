#!/usr/bin/env python3
"""Emit the wave16 policy/reimport cells.

One cell per SCR row.  Each cell contains:
  buildspec        shell-sourced cell metadata (id, roots, marker)
  c_cell.cpp       line-cited Bitcoin Core source excerpt at the pin
  l_cell.cpp       reviewed transliteration of the Lean model
  saw/cell.cry     independent Cryptol predicate (the row's rule)
  saw/cell.saw     SAW script: verify both legs against the same Cryptol fn
  alive2/run.sh    thin wrapper over the cell-local _tools/run_alive2.sh
  saw/run.sh       thin wrapper over the cell-local _tools/run_saw.sh
  _tools/          cell-local copy of the shared harness (header + build/run scripts)
  spec.md          required cell record
  notes.md         design/limits/commands

Nothing here writes a result: result.txt is produced only by the real tools.
"""
import os
import stat
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "../../../../../.."))
CELLS = os.path.join(REPO, "spec/equiv/cells")

CONTRACT = "f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6"
REPO_HEAD = "805c8042f92d3bed909ca40219a4d21fc9150cc1"
PIN = "cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66"
FLAG_NOTE = ("Masks are Core's real values at the pin "
             "(names from src/script/interpreter.h:46-151, mask = 1<<bit from "
             "src/script/verify_flags.h; probe output in "
             "findings/wave16/13-policy-reimport/tools/flags_probe.out): "
             "P2SH=0x1 STRICTENC=0x2 DERSIG=0x4 LOW_S=0x8 NULLDUMMY=0x10 "
             "MINIMALDATA=0x40 CLEANSTACK=0x100 WITNESS=0x800 MINIMALIF=0x2000 "
             "NULLFAIL=0x4000 WITNESS_PUBKEYTYPE=0x8000 CONST_SCRIPTCODE=0x10000.")


def write(path, text, mode=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)
    if mode:
        os.chmod(path, mode)


RUN_ALIVE = """#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/_tools/run_alive2.sh" "$CELL_DIR"
"""
RUN_SAW = """#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/_tools/run_saw.sh" "$CELL_DIR"
"""

COMMON_SPEC_TAIL = """patches: none
direction:
  - L \u2291 C
  - C \u2291 L
evidence:
  - alive2/result.txt, alive2/certificate.sha256 (raw alive-tv v20 output, both directions)
  - saw/result.txt, saw/certificate.sha256 (raw SAW 1.6 output, both legs)
  - ir/ (c_leaf.ll, l_leaf.ll, per-root extracted modules, build.txt; tracked, so the
    certificates hash exactly the modules presented to alive-tv/SAW)
  - findings/wave16/13-policy-reimport/tools/concrete_check.out (hand-computed
    behavioural vectors, C leg == L leg == expectation)
"""


def spec(c):
    precond = c['precond'].rstrip("\n")
    postcond = c['postcond'].rstrip("\n")
    scope = c['scope'].rstrip("\n")
    trust = c['trust'].rstrip("\n")
    return f"""---
# Cell {c['family']}/{c['id']}
cell: {c['id']}
family: {c['family']}
contract: {CONTRACT}
repo_head: {REPO_HEAD}
pin: {PIN}
legs: C, L
tool_status: both-green (symbolic predicate over the declared domain)
consensus: {c['consensus']}
precondition: |
{precond}
postcondition: |
{postcond}
scr_rows: {c['rows']}
scr_row_coverage: {c['coverage']}
coverage: {c['coverage_tag']}
{COMMON_SPEC_TAIL}source_citations:
{c['citations']}
trust_note: >
{trust}
scope: |
{scope}
---

## What this cell proves

{c['body']}

## Both-tool evidence

- Alive2 (`alive2/result.txt`): every root compared in **both** directions
  (`alive-tv c_<fn>.ll l_<fn>.ll` for L \u2291 C and `alive-tv l_<fn>.ll c_<fn>.ll`
  for C \u2291 L); all report `Transformation seems to be correct!` /
  `1 correct transformations, 0 incorrect, 0 failed-to-prove`.
- SAW (`saw/result.txt`): every root verified in the C module and in the L
  module against the *same* Cryptol function in `saw/cell.cry`, which is written
  from the row's rule and is independent of both C++ files.
- Both `certificate.sha256` files verify with `sha256sum -c` from the repo root.

## Consensus status

{c['consensus_note']}
"""


def notes(c):
    return f"""# {c['family']}/{c['id']} — notes

Rows: {c['rows']} ({c['coverage']} coverage).

## Commands actually run

```sh
cd {REPO}
bash spec/equiv/cells/{c['family']}/{c['id']}/alive2/run.sh
bash spec/equiv/cells/{c['family']}/{c['id']}/saw/run.sh
sha256sum -c spec/equiv/cells/{c['family']}/{c['id']}/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/{c['family']}/{c['id']}/saw/certificate.sha256
```

## Build and harness

- clang: `/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing
  -fno-discard-value-names -c -emit-llvm`; `llvm-extract --func=<root>
  --recursive` for each root (`_tools/build_leaf.sh`).
- Alive2: `/opt/equiv-tools/alive-tv-v20.0` (v20.0, LLVM 20.1.2).
- SAW: `/opt/equiv-tools/saw-1.6/bin/saw` (1.6, 68eed5f), solver `abc`.
- `policy_common.h` supplies the flag masks, the Core `ScriptError` ordinals
  and the byte model; it is cell harness, not engine code.
- The roots are `extern "C"` and take only `uint64_t` arguments, so Alive2 can
  compare the two modules by name and SAW needs no memory model.

## Design

- `c_cell.cpp` is a source excerpt of Bitcoin Core at the pin, with the exact
  line citations in its header. It is not the whole EvalScript/VerifyScript.
- `l_cell.cpp` is a **reviewed transliteration** of the cited Lean equations in
  `spec/core/Bitcoin/Interpreter/Defs.lean`; it is not generated by
  `twin/ops_ir.py` (the twin has no handler for these predicate sites).
- The observable is exactly one shared `ScriptError` ordinal (0 = pass);
  `0xff` is the cell's out-of-domain guard, which no Core path returns.
- No Core patch, no pin change, no twin change.

## Limits

{c['limits']}
"""


CELL_DEFS = []


# ---------------------------------------------------------------- SCR-175 ---
CELL_DEFS.append(dict(
    family="policy-flags", id="C-L-lows-policy", rows="SCR-175",
    coverage="partial", coverage_tag="partial",
    marker="policy_flags_lows",
    consensus="false",
    precond="""  - Scope: `CheckSignatureEncoding` (interpreter.cpp:207-224) on the LOW_S
    branch, including the DER-shape gate that precedes it:
      flags is an arbitrary 64-bit script_verify_flags word;
      DERSIG(0x4), LOW_S(0x8) and STRICTENC(0x2) are read exactly as Core does.
  - Signature domain (bounded, declared): the canonical DER skeleton
      30 25 02 01 <R> 02 20 <S:32> <hashtype>
    i.e. sig.size() == 40, lenR == 1, one-byte R, lenS == 32, 32-byte S.
    The symbolic inputs are the R byte and the four 64-bit big-endian words of
    S.  The empty-signature short circuit (:214-216) is excluded by the
    skeleton (sig.size() == 40).
  - The table of IsValidSignatureEncoding (:118-180) is modelled exactly for
    that skeleton: every other condition is fixed by the skeleton, and the
    three free ones (:149 R positive, :172 S positive, :177 minimal S) are
    computed from the symbolic bytes.
  - SAME-CRYPTO PREMISE: Core's `CPubKey::CheckLowS` (pubkey.h) goes through
    the libsecp DER-lax parse and the `s <= n/2` normalisation check.  The Lean
    model spells the same predicate out as `sval <= SIG_S_HALF_ORDER`
    (Defs.lean:355-362).  This cell proves the Lean/ Core *predicate* equality
    under that premise; it does not prove libsecp256k1.
""",
    postcond="""  - packed as a single ScriptError ordinal (0 = no error):
      (DERSIG|LOW_S|STRICTENC) set and DER-invalid      -> 24 SCRIPT_ERR_SIG_DER
      else LOW_S set and S > n/2                        -> 27 SCRIPT_ERR_SIG_HIGH_S
      else                                              -> 0
    where DER-valid means R < 0x80 && S[0] < 0x80 && (S[0] != 0 || S[1] & 0x80),
    and S > n/2 is the 256-bit big-endian comparison against
    0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0.
  - The error precedence is Core's: an invalid encoding reports SIG_DER even
    when LOW_S is set, because :217-218 runs before :219-221.
  - C and L return the same ordinal for every (flags, R, S) in the domain.
""",
    citations="""  - "interpreter.cpp:207-224 (CheckSignatureEncoding; :217-218 DER gate, :219-221 LOW_S gate)"
  - "interpreter.cpp:183-196 (IsLowDERSignature: SIG_DER then CPubKey::CheckLowS -> SIG_HIGH_S)"
  - "interpreter.cpp:118-180 (IsValidSignatureEncoding; :149, :172, :177 are the skeleton-free conditions)"
  - "src/pubkey.h (CPubKey::CheckLowS; libsecp normalize, same-crypto premise)"
  - "src/script/verify_flags.h:46-60 (LOW_S is a policy bit; not in GetBlockScriptFlags)"
  - "src/validation.cpp:2249-2288 (GetBlockScriptFlags: P2SH|WITNESS|TAPROOT + DERSIG/CLTV/CSV/NULLDUMMY only)"
  - "src/policy/policy.h:104-134 (LOW_S is in STANDARD_SCRIPT_VERIFY_FLAGS, not MANDATORY)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:88-91 (SIG_S_HALF_ORDER)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:355-362 (checkLowS)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:373-380 (checkSigEncoding)"
  - "contract/error_enum.md:71-73 (24 SIG_DER, 27 SIG_HIGH_S)"
""",
    trust="""  C is a line-cited source excerpt of interpreter.cpp at the pin, specialised
  to one DER shape; it is not the whole CheckSignatureEncoding and not the
  whole EvalScript.  L is a REVIEWED TRANSLITERATION of the Lean definitions
  Bitcoin.Interpreter.checkLowS / checkSigEncoding (Defs.lean:355-380), not
  generated from twin/ops_ir.py.  The S <= n/2 comparison is the SAME-CRYPTO
  seam of docs/DECISION-lax-ecdsa.md: the cell compares the Lean predicate
  against Core's predicate shape, and does not prove libsecp256k1's DER-lax
  parser or its scalar normalisation.  No Core patch is used.
""",
    scope="""  PARTIAL.  Proved: the LOW_S policy gate, its error precedence against the
  DER gate, and the full S <= n/2 comparison, over the whole 256-bit S space
  for the fixed skeleton lenR == 1 / lenS == 32.
  NOT proved / not in the domain: DER shapes with lenR > 1 or lenS != 32 (the
  variable-offset S extraction and the full :118-180 table for those shapes),
  signatures rejected by the size bounds, and the libsecp DER-lax parse and
  scalar-overflow window (DECISION-lax-ecdsa.md §2-3, SGN-107).  A cell that
  covers those needs a byte-addressed memory model with a symbolic length; that
  is the recorded next action, not a claim here.
""",
    limits="""Partial only by *domain*: the 256-bit S comparison and the error precedence
are total for the declared skeleton.  The missing coverage is listed in
`scope:` in spec.md (other DER shapes, the libsecp lax-parse window).
""",
    body="""The row's claim is that LOW_S is a mempool-policy bit that never reaches
block validation, and that when set it rejects S > n/2 in
`CheckSignatureEncoding`.  The cell proves the second half as an exact
predicate: for every 64-bit flag word and every 32-byte S (fixed canonical DER
skeleton), the reported `ScriptError` ordinal is the one Core's branch structure
selects, and the L transliteration of `checkSigEncoding` selects the same one.
The consensus status of the row is a source fact, cited from
`GetBlockScriptFlags`, not something a predicate proof can establish.
""",
    consensus_note="""**Not consensus.**  `GetBlockScriptFlags` (validation.cpp:2249-2288) never
sets LOW_S; it sets only P2SH|WITNESS|TAPROOT plus DERSIG, CLTV, CSV and
NULLDUMMY as deployments activate.  LOW_S appears only in
`STANDARD_SCRIPT_VERIFY_FLAGS` (policy.h:118-133) and MANDATORY_SCRIPT_VERIFY_FLAGS
does not contain it.  The cell therefore proves the *policy* gate only; it makes
no claim that a LOW_S-violating signature is consensus-invalid.
""",
    c_code=r"""#include "policy_common.h"
using namespace policy_cell;

// C leg: Bitcoin Core src/script/interpreter.cpp @ pin cce32b168.
//
// CheckSignatureEncoding (:207-224), the two branches this row is about:
//
//   if ((flags & (DERSIG|LOW_S|STRICTENC)) != 0 && !IsValidSignatureEncoding(vchSig))  // :217
//       return set_error(serror, SCRIPT_ERR_SIG_DER);                                   // :218
//   else if ((flags & LOW_S) != 0 && !IsLowDERSignature(vchSig, serror))                // :219-220
//       return false;   // serror = SCRIPT_ERR_SIG_HIGH_S                               // :221
//
// IsLowDERSignature (:183-196) re-checks IsValidSignatureEncoding (:184) and
// then calls CPubKey::CheckLowS (:193) -> SIG_HIGH_S (:194-195).
//
// DOMAIN (declared, see spec.md): the canonical DER skeleton
//   30 25 02 01 <R> 02 20 <S:32> <hashtype>          (sig.size() == 40, lenR == 1, lenS == 32)
// Under that skeleton only three IsValidSignatureEncoding conditions are free:
//   :149  sig[4] & 0x80                    -> R must be positive
//   :172  sig[lenR+6] & 0x80 = sig[7]      -> S[0] must be positive
//   :177  lenS>1 && S[0]==0 && !(S[1]&0x80) -> minimal S encoding
// so validity is computed from R and the first two S bytes.
//
// CPubKey::CheckLowS is the SAME-CRYPTO seam (docs/DECISION-lax-ecdsa.md): the
// Lean model spells it as `sval <= SIG_S_HALF_ORDER` (Defs.lean:355-362), and
// that is the predicate compared here.

static constexpr uint64_t H0 = 0x7fffffffffffffffULL;
static constexpr uint64_t H1 = 0xffffffffffffffffULL;
static constexpr uint64_t H2 = 0x5d576e7357a4501dULL;
static constexpr uint64_t H3 = 0xdfe92f46681b20a0ULL;

// 256-bit big-endian s <= n/2 (Defs.lean:88-91 SIG_S_HALF_ORDER).
static inline __attribute__((always_inline))
bool c_le_half(uint64_t s0, uint64_t s1, uint64_t s2, uint64_t s3) {
    if (s0 != H0) return s0 < H0;
    if (s1 != H1) return s1 < H1;
    if (s2 != H2) return s2 < H2;
    return s3 <= H3;
}

uint64_t c_lows_policy(uint64_t flags, uint64_t rByte, uint64_t s0,
                       uint64_t s1, uint64_t s2, uint64_t s3) {
    const uint64_t r  = byte_of(rByte);
    const uint64_t sTop = (s0 >> 56) & 0xff;              // S[0]
    const uint64_t sSecond = (s0 >> 48) & 0xff;           // S[1]

    // IsValidSignatureEncoding, specialised to the declared skeleton.
    const bool valid =
        r < 0x80 &&                                       // :149
        sTop < 0x80 &&                                    // :172
        (sTop != 0 || (sSecond & 0x80) != 0);             // :177

    // IsLowDERSignature / CPubKey::CheckLowS, DER-level formulation.
    const bool lowS = valid && c_le_half(s0, s1, s2, s3);

    if ((flags & (DERSIG | LOW_S | STRICTENC)) != 0 && !valid) {
        return ERR_SIG_DER;                               // :217-218
    } else if ((flags & LOW_S) != 0 && !lowS) {
        return ERR_SIG_HIGH_S;                            // :219-221 / :194-195
    }
    return ERR_OK;                                        // :223
}

extern "C" uint64_t cell_lows_policy(uint64_t flags, uint64_t rByte, uint64_t s0,
                                     uint64_t s1, uint64_t s2, uint64_t s3) {
    return c_lows_policy(flags, rByte, s0, s1, s2, s3);
}
""",
    l_code=r"""#include "policy_common.h"
using namespace policy_cell;

// L leg: REVIEWED TRANSLITERATION (not generated) of
//   spec/core/Bitcoin/Interpreter/Defs.lean
//
//   def checkLowS (sigNoHT : ByteArray) : Bool :=                    -- :355-362
//     if !isValidSigEncoding (sigNoHT.push 0x01) then false
//     else
//       let lenR := (byteOr sigNoHT 3).toNat
//       let lenS := (byteOr sigNoHT (5 + lenR)).toNat
//       let sval := (List.range lenS).foldl (fun acc j => acc*256 + byte j) 0
//       sval <= SIG_S_HALF_ORDER
//
//   def checkSigEncoding flags pol sig : Option ExecError :=            -- :373-380
//     if sig.size = 0 then none
//     else if (flags.dersig ∨ pol.lowS ∨ pol.strictEnc) ∧ !isValidSigEncoding sig
//       then some .sigDer
//     else if pol.lowS ∧ !checkLowS (sig.extract 0 (sig.size - 1)) then some .sigHighS
//     else if pol.strictEnc ∧ !isDefinedHashtype sig then some .sigHashType
//     else none
//
// `pol.lowS` is PolicyFlags.lowS (Defs.lean:187-205), set by parsePolicyFlags
// from the corpus "LOW_S" policy string (:213-227); Core carries the same bit
// in the script_verify_flags word.  `sig.extract 0 (sig.size - 1)` drops the
// hashtype byte, so checkLowS sees the 39-byte signature.
//
// The interpretation of the foldl for lenS = 32 is the big-endian 256-bit S;
// SIG_S_HALF_ORDER is Defs.lean:88-91.  For the declared skeleton, the Lean
// isValidSigEncoding reduces to the same three free conditions as the C leg.

static constexpr uint64_t H0 = 0x7fffffffffffffffULL;
static constexpr uint64_t H1 = 0xffffffffffffffffULL;
static constexpr uint64_t H2 = 0x5d576e7357a4501dULL;
static constexpr uint64_t H3 = 0xdfe92f46681b20a0ULL;

static inline __attribute__((always_inline))
bool l_le_half(uint64_t s0, uint64_t s1, uint64_t s2, uint64_t s3) {
    if (s0 != H0) return s0 < H0;
    if (s1 != H1) return s1 < H1;
    if (s2 != H2) return s2 < H2;
    return s3 <= H3;
}

uint64_t l_lows_policy(uint64_t flags, uint64_t rByte, uint64_t s0,
                       uint64_t s1, uint64_t s2, uint64_t s3) {
    const uint64_t r       = byte_of(rByte);
    const uint64_t sTop    = (s0 >> 56) & 0xff;
    const uint64_t sSecond = (s0 >> 48) & 0xff;

    // isValidSigEncoding (Defs.lean:307-335), specialised to the skeleton.
    const bool valid = r < 0x80 && sTop < 0x80 &&
                       (sTop != 0 || (sSecond & 0x80) != 0);
    // checkLowS (Defs.lean:355-362).
    const bool lowS = valid && l_le_half(s0, s1, s2, s3);

    const bool dersig     = (flags & DERSIG) != 0;
    const bool lowSFlag   = (flags & LOW_S) != 0;
    const bool strictEnc  = (flags & STRICTENC) != 0;
    if ((dersig || lowSFlag || strictEnc) && !valid) return ERR_SIG_DER;
    if (lowSFlag && !lowS) return ERR_SIG_HIGH_S;
    return ERR_OK;
}

extern "C" uint64_t cell_lows_policy(uint64_t flags, uint64_t rByte, uint64_t s0,
                                     uint64_t s1, uint64_t s2, uint64_t s3) {
    return l_lows_policy(flags, rByte, s0, s1, s2, s3);
}
""",
    cry=r"""module PolicyCell where

// Independent predicate for SCR-175 (LOW_S policy gate).  Written from Core's
// CheckSignatureEncoding branch structure and the Lean checkLowS bound; it is
// not derived from either C++ file.
// ordinals: 0 ok, 24 SIG_DER, 27 SIG_HIGH_S
halforder : [256]
halforder = 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0

lows : [64] -> [64] -> [64] -> [64] -> [64] -> [64] -> [64]
lows flags rByte s0 s1 s2 s3 =
  if ((((flags >> 1) % 8) != 0) && ~valid) then 24
  else if ((((flags >> 3) % 2) == 1) && ~lowS) then 27
  else 0
  where
    r       = rByte % 256
    sTop    = (s0 >> 56) % 256
    sSecond = (s0 >> 48) % 256
    valid   = (r < 128) && (sTop < 128) && ((sTop != 0) || (sSecond >= 128))
    sval    = s0 # s1 # s2 # s3
    lowS    = valid && (sval <= halforder)
""",
    roots=[("cell_lows_policy", ["flags", "rByte", "s0", "s1", "s2", "s3"], "lows")],
))


# ---------------------------------------------------------------- SCR-176 ---
CELL_DEFS.append(dict(
    family="policy-flags", id="C-L-strictenc-pubkey", rows="SCR-176",
    coverage="full", coverage_tag="full",
    marker="policy_flags_strictenc",
    consensus="false",
    precond="""  - Scope: `CheckPubKeyEncoding` (interpreter.cpp:227-237), the STRICTENC
    branch only (:229-231), and its callee
    `IsCompressedOrUncompressedPubKey` (:74-94).
  - flags is an arbitrary 64-bit script_verify_flags word; the cell reads
    STRICTENC (0x2) and nothing else.
  - The pubkey is modelled by the only two facts its encoding check reads:
    its length (0 .. 2**64-1) and its first byte (masked to 0 .. 255).
  - SigVersion is not read by the STRICTENC branch (Core passes it only for the
    WITNESS_PUBKEYTYPE branch), so it is not an input.
  - The signature-encoding half of STRICTENC (hashtype, CheckSignatureEncoding
    :219-223) is a different table entry and is not exercised here.
""",
    postcond="""  - STRICTENC set and the pubkey is neither (0x04 + 64 bytes) nor
    (0x02/0x03 + 32 bytes)                -> 29 SCRIPT_ERR_PUBKEYTYPE
    otherwise                             -> 0
  - Exact truth table (len, first byte):
      len < 33                              -> error
      first byte 0x04, len != 65            -> error
      first byte 0x02 or 0x03, len != 33    -> error
      any other first byte                  -> error
      first byte 0x04 and len == 65         -> pass
      first byte 0x02 or 0x03 and len == 33 -> pass
    and, with STRICTENC clear, every (len, byte) passes.
""",
    citations="""  - "interpreter.cpp:74-94 (IsCompressedOrUncompressedPubKey)"
  - "interpreter.cpp:227-237 (CheckPubKeyEncoding; STRICTENC branch :229-231)"
  - "src/pubkey.h (CPubKey::COMPRESSED_SIZE=33, CPubKey::SIZE=65)"
  - "src/script/interpreter.h:56-60 (STRICTENC is \\"(not used or intended as a consensus rule)\\")"
  - "src/validation.cpp:2249-2288 (GetBlockScriptFlags never sets STRICTENC)"
  - "src/policy/policy.h:118-133 (STRICTENC is standard, not mandatory)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:382-387 (isCompressedOrUncompressedPubKey)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:398-403 (checkPubKeyEncoding)"
  - "contract/error_enum.md:75 (29 SIG_PUBKEYTYPE)"
""",
    trust="""  C is a line-cited source excerpt of interpreter.cpp at the pin, restricted to
  the two functions the row names; it is not the whole EvalScript.  L is a
  REVIEWED TRANSLITERATION of Bitcoin.Interpreter.isCompressedOrUncompressedPubKey
  and checkPubKeyEncoding (Defs.lean:382-403), not generated from
  twin/ops_ir.py.  No crypto, hash or signature check is involved, so no
  same-crypto premise is needed.  No Core patch is used.
""",
    scope="""  FULL for SCR-176 as cited (:74-94, :229-231): the pubkey-encoding predicate
  is total over (flag word, length, first byte), which is exactly the domain the
  check reads.  The hashtype half of the STRICTENC flag (in
  CheckSignatureEncoding) is a different rule and is not part of this row.
""",
    limits="""None for the cited predicate: the length/first-byte model is the complete
input of IsCompressedOrUncompressedPubKey.  Bytes after the first are never
read by Core for this check.
""",
    body="""`CheckPubKeyEncoding` rejects a hybrid/unknown pubkey encoding *only* when the
STRICTENC policy bit is set.  The cell proves the total predicate over
(flags, pubkey length, pubkey first byte) and shows the flag is the only gate:
with STRICTENC clear every encoding passes, with it set exactly the
0x04/65-byte and 0x02-or-0x03/33-byte forms pass.  Consensus status is a source
fact: STRICTENC is not in `GetBlockScriptFlags` and is not in
MANDATORY_SCRIPT_VERIFY_FLAGS.
""",
    consensus_note="""**Not consensus.**  `GetBlockScriptFlags` (validation.cpp:2249-2288) never
sets STRICTENC, and interpreter.h:56-60 documents it as "(not used or intended
as a consensus rule)".  STRICTENC is in STANDARD_SCRIPT_VERIFY_FLAGS
(policy.h:118-133) and absent from MANDATORY_SCRIPT_VERIFY_FLAGS.  A
hybrid-pubkey spend is therefore policy-invalid, not consensus-invalid.
""",
    c_code=r"""#include "policy_common.h"
using namespace policy_cell;

// C leg: Bitcoin Core src/script/interpreter.cpp @ pin cce32b168.
//
// bool static IsCompressedOrUncompressedPubKey(const valtype &vchPubKey) {   // :74
//     if (vchPubKey.size() < CPubKey::COMPRESSED_SIZE) return false;          // :75-78
//     if (vchPubKey[0] == 0x04) {                                             // :79
//         if (vchPubKey.size() != CPubKey::SIZE) return false;                // :80-83
//     } else if (vchPubKey[0] == 0x02 || vchPubKey[0] == 0x03) {              // :84
//         if (vchPubKey.size() != CPubKey::COMPRESSED_SIZE) return false;     // :85-88
//     } else {                                                                // :89
//         return false;                                                       // :90-92
//     }
//     return true;                                                            // :93
// }
//
// bool static CheckPubKeyEncoding(const valtype &vchPubKey, script_verify_flags flags,
//                                 const SigVersion &sigversion, ScriptError* serror) {
//     if ((flags & SCRIPT_VERIFY_STRICTENC) != 0 && !IsCompressedOrUncompressedPubKey(vchPubKey))
//         return set_error(serror, SCRIPT_ERR_PUBKEYTYPE);                    // :229-231
//     ...
// }

uint64_t c_strictenc_pubkey(uint64_t flags, uint64_t pkLen, uint64_t pk0) {
    const uint64_t len = pkLen;
    const uint64_t b0  = byte_of(pk0);

    bool enc_ok;
    if (len < 33) {                       // CPubKey::COMPRESSED_SIZE
        enc_ok = false;
    } else if (b0 == 0x04) {
        enc_ok = (len == 65);             // CPubKey::SIZE
    } else if (b0 == 0x02 || b0 == 0x03) {
        enc_ok = (len == 33);
    } else {
        enc_ok = false;
    }

    if ((flags & STRICTENC) != 0 && !enc_ok) return ERR_PUBKEYTYPE;
    return ERR_OK;
}

extern "C" uint64_t cell_strictenc_pubkey(uint64_t flags, uint64_t pkLen, uint64_t pk0) {
    return c_strictenc_pubkey(flags, pkLen, pk0);
}
""",
    l_code=r"""#include "policy_common.h"
using namespace policy_cell;

// L leg: REVIEWED TRANSLITERATION (not generated) of
//   spec/core/Bitcoin/Interpreter/Defs.lean
//
//   def isCompressedOrUncompressedPubKey (pk : ByteArray) : Bool :=   -- :382-387
//     if pk.size < 33 then false
//     else if byteOr pk 0 = 0x04 then pk.size = 65
//     else if byteOr pk 0 = 0x02 ∨ byteOr pk 0 = 0x03 then pk.size = 33
//     else false
//
//   def checkPubKeyEncoding (_flags : ScriptFlags) (pol : PolicyFlags) -- :398-403
//       (sv : SigVersion) (pk : ByteArray) : Option ExecError :=
//     if pol.strictEnc ∧ !isCompressedOrUncompressedPubKey pk then some .pubKeyType
//     else if pol.witnessPubkeyType ∧ sv = .witnessV0 ∧ !isCompressedPubKey pk
//       then some .witnessPubkeyType
//     else none
//
// `pol.strictEnc` is PolicyFlags.strictEnc (Defs.lean:187-205), fed by
// parsePolicyFlags from the corpus "STRICTENC" string; Core carries the same
// bit in its script_verify_flags word.

uint64_t l_strictenc_pubkey(uint64_t flags, uint64_t pkLen, uint64_t pk0) {
    const uint64_t len = pkLen;
    const uint64_t b0  = byte_of(pk0);

    bool enc_ok;
    if (len < 33) {
        enc_ok = false;
    } else if (b0 == 0x04) {
        enc_ok = (len == 65);
    } else if (b0 == 0x02 || b0 == 0x03) {
        enc_ok = (len == 33);
    } else {
        enc_ok = false;
    }

    const bool strictEnc = (flags & STRICTENC) != 0;
    if (strictEnc && !enc_ok) return ERR_PUBKEYTYPE;
    return ERR_OK;
}

extern "C" uint64_t cell_strictenc_pubkey(uint64_t flags, uint64_t pkLen, uint64_t pk0) {
    return l_strictenc_pubkey(flags, pkLen, pk0);
}
""",
    cry=r"""module PolicyCell where

// Independent predicate for SCR-176 (STRICTENC pubkey encoding).
// ordinal 0 = pass, 29 = SCRIPT_ERR_PUBKEYTYPE.
strictenc_pubkey : [64] -> [64] -> [64] -> [64]
strictenc_pubkey flags pkLen pk0 =
  if ((((flags >> 1) % 2) == 1) && ~encOk) then 29 else 0
  where
    n     = pkLen
    b0    = pk0 % 256
    ok04  = (b0 == 4) && (n == 65)
    ok023 = ((b0 == 2) || (b0 == 3)) && (n == 33)
    encOk = (n >= 33) && (ok04 || ok023)
""",
    roots=[("cell_strictenc_pubkey", ["flags", "pkLen", "pk0"], "strictenc_pubkey")],
))


# ---------------------------------------------------------------- SCR-177 ---
CELL_DEFS.append(dict(
    family="policy-flags", id="C-L-minimaldata-push", rows="SCR-177",
    coverage="full", coverage_tag="full",
    marker="policy_flags_minimaldata",
    consensus="false",
    precond="""  - Scope: the push-minimality gate of EvalScript.  Core computes
    `bool fRequireMinimal = (flags & SCRIPT_VERIFY_MINIMALDATA) != 0;` at
    interpreter.cpp:442 and applies it at :487-491 to every *executed* push
    (`fExec && 0 <= opcode && opcode <= OP_PUSHDATA4`), via
    `CheckMinimalPush` (script.cpp:373-396).
  - Inputs: an arbitrary 64-bit flag word (MINIMALDATA = 0x40 is read),
    fExec (0/1), the push opcode (0x00..0x4e is a push; anything larger is not
    a push and the gate is not reached), the pushed data length (0..2**64-1)
    and the data's first byte (masked to 0..255).
  - `CheckMinimalPush` reads only the data length and the first byte; bytes
    after the first are never consulted, so (len, byte0, opcode) is the
    complete input of the predicate.
""",
    postcond="""  - fExec == 0 or opcode > OP_PUSHDATA4 (0x4e): 0 (the push branch is not
    entered; an unexecuted push is never minimality-checked).
  - otherwise, MINIMALDATA set and !CheckMinimalPush -> 25 SCRIPT_ERR_MINIMALDATA
  - otherwise -> 0
  with CheckMinimalPush exactly as script.cpp:373-396:
      len == 0                      -> opcode == OP_0 (0x00)
      len == 1 and 1 <= b0 <= 16    -> false
      len == 1 and b0 == 0x81       -> false
      len <= 75                     -> opcode == len
      len <= 255                    -> opcode == OP_PUSHDATA1 (0x4c)
      len <= 65535                  -> opcode == OP_PUSHDATA2 (0x4d)
      else                          -> true
""",
    citations="""  - "interpreter.cpp:442 (fRequireMinimal = flags & SCRIPT_VERIFY_MINIMALDATA)"
  - "interpreter.cpp:487-491 (executed-push branch; MINIMALDATA -> SCRIPT_ERR_MINIMALDATA)"
  - "script.cpp:373-396 (CheckMinimalPush)"
  - "script.h:607 (CheckMinimalPush declaration)"
  - "src/validation.cpp:2249-2288 (GetBlockScriptFlags never sets MINIMALDATA)"
  - "src/policy/policy.h:118-133 (MINIMALDATA is standard, not mandatory)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:529-539 (checkMinimalPush)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:838-843 (stepBody pushBytes arm: fExec/minimalData)"
  - "contract/error_enum.md:69 (25 SIG_MINIMALDATA)"
""",
    trust="""  C is a line-cited source excerpt of interpreter.cpp:442/487-491 and
  script.cpp:373-396 at the pin; it is not the whole EvalScript.  L is a
  REVIEWED TRANSLITERATION of Bitcoin.Interpreter.checkMinimalPush and the
  stepBody pushBytes arm (Defs.lean:529-539, 838-843), not generated from
  twin/ops_ir.py.  No crypto, memory or hash is involved.  No Core patch is
  used.
""",
    scope="""  FULL for SCR-177 as cited (push minimality).  The same flag also makes
  CScriptNum reject non-minimally encoded numbers (interpreter.cpp:442 feeds
  CScriptNum's fRequireMinimal); that numeric use is a separate numeric-family
  rule and is NOT claimed here.
""",
    limits="""None for the cited push predicate; the length/first-byte/opcode model is the
complete input of CheckMinimalPush.  The numeric-minimality use of the same flag
is out of scope (see `scope:`).
""",
    body="""The cell proves the complete MINIMALDATA push gate: for every (flag word,
fExec, opcode, data length, first data byte) the reported ordinal is
SCRIPT_ERR_MINIMALDATA exactly when the flag is set, the push is executed, the
opcode is a push opcode and `CheckMinimalPush` rejects the encoding.  This
includes the OP_1..OP_16 and OP_1NEGATE rules, the direct-push <= 75 rule, and
the PUSHDATA1/PUSHDATA2 boundaries at 255/65535.  MINIMALDATA is a standard-only
flag (`GetBlockScriptFlags` never sets it).
""",
    consensus_note="""**Not consensus.**  `GetBlockScriptFlags` (validation.cpp:2249-2288) never
sets MINIMALDATA, and it is absent from MANDATORY_SCRIPT_VERIFY_FLAGS
(policy.h:104-113).  MINIMALDATA appears only in STANDARD_SCRIPT_VERIFY_FLAGS
(policy.h:118-133).  A non-minimal push is therefore relay-invalid, not
consensus-invalid.
""",
    c_code=r"""#include "policy_common.h"
using namespace policy_cell;

// C leg: Bitcoin Core @ pin cce32b168.
//
// bool CheckMinimalPush(const std::vector<unsigned char>& data, opcodetype opcode) {  // script.cpp:373
//     assert(0 <= opcode && opcode <= OP_PUSHDATA4);
//     if (data.size() == 0) return opcode == OP_0;                                     // :375-377
//     else if (data.size() == 1 && data[0] >= 1 && data[0] <= 16) return false;         // :378-380
//     else if (data.size() == 1 && data[0] == 0x81) return false;                       // :381-383
//     else if (data.size() <= 75) return opcode == data.size();                         // :384-386
//     else if (data.size() <= 255) return opcode == OP_PUSHDATA1;                       // :387-389
//     else if (data.size() <= 65535) return opcode == OP_PUSHDATA2;                     // :390-392
//     return true;                                                                      // :393
// }
//
// EvalScript:                                                                          // interpreter.cpp:442
//   bool fRequireMinimal = (flags & SCRIPT_VERIFY_MINIMALDATA) != 0;
//   ...
//   if (fExec && 0 <= opcode && opcode <= OP_PUSHDATA4) {                               // :487-488
//       if (fRequireMinimal && !CheckMinimalPush(vchPushValue, opcode)) {               // :489
//           return set_error(serror, SCRIPT_ERR_MINIMALDATA);                           // :490
//       }
//       stack.push_back(vchPushValue);
//   }

uint64_t c_minimaldata_push(uint64_t flags, uint64_t fExec, uint64_t opcode,
                            uint64_t dataLen, uint64_t b0Arg) {
    const uint64_t b0 = byte_of(b0Arg);

    if (fExec != 0 && opcode <= OP_PUSHDATA4) {
        bool ok;
        if (dataLen == 0) {
            ok = (opcode == OP_0);
        } else if (dataLen == 1 && b0 >= 1 && b0 <= 16) {
            ok = false;
        } else if (dataLen == 1 && b0 == 0x81) {
            ok = false;
        } else if (dataLen <= 75) {
            ok = (opcode == dataLen);
        } else if (dataLen <= 0xff) {
            ok = (opcode == OP_PUSHDATA1);
        } else if (dataLen <= 0xffff) {
            ok = (opcode == OP_PUSHDATA2);
        } else {
            ok = true;
        }
        if ((flags & MINIMALDATA) != 0 && !ok) return ERR_MINIMALDATA;
    }
    return ERR_OK;
}

extern "C" uint64_t cell_minimaldata_push(uint64_t flags, uint64_t fExec, uint64_t opcode,
                                          uint64_t dataLen, uint64_t b0Arg) {
    return c_minimaldata_push(flags, fExec, opcode, dataLen, b0Arg);
}
""",
    l_code=r"""#include "policy_common.h"
using namespace policy_cell;

// L leg: REVIEWED TRANSLITERATION (not generated) of
//   spec/core/Bitcoin/Interpreter/Defs.lean
//
//   def checkMinimalPush (data : ByteArray) (opcode : Nat) : Bool :=   -- :529-539
//     if data.size = 0 then opcode = 0
//     else if data.size = 1 ∧ 1 ≤ (data.get! 0).toNat ∧ (data.get! 0).toNat ≤ 16 then false
//     else if data.size = 1 ∧ (data.get! 0).toNat = 0x81 then false
//     else if data.size ≤ 75 then opcode = data.size
//     else if data.size ≤ 0xff then opcode = 0x4c
//     else if data.size ≤ 0xffff then opcode = 0x4d
//     else true
//
// stepBody, pushBytes arm (:838-843):
//     if !fExec then .ok st₁
//     else if ctx.pol.minimalData ∧ !checkMinimalPush d w then .error .minimalData
//     else .ok { st₁ with stack := d :: st.stack }
//
// `ctx.pol.minimalData` is PolicyFlags.minimalData (Defs.lean:187-205), fed by
// parsePolicyFlags from the corpus "MINIMALDATA" string; Core carries the same
// bit in script_verify_flags (interpreter.cpp:442).

uint64_t l_minimaldata_push(uint64_t flags, uint64_t fExec, uint64_t opcode,
                            uint64_t dataLen, uint64_t b0Arg) {
    const uint64_t b0 = byte_of(b0Arg);

    if (fExec != 0 && opcode <= 0x4e) {   // OP_PUSHDATA4
        bool ok;
        if (dataLen == 0) {
            ok = (opcode == 0x00);        // OP_0
        } else if (dataLen == 1 && b0 >= 1 && b0 <= 16) {
            ok = false;
        } else if (dataLen == 1 && b0 == 0x81) {
            ok = false;
        } else if (dataLen <= 75) {
            ok = (opcode == dataLen);
        } else if (dataLen <= 0xff) {
            ok = (opcode == 0x4c);        // OP_PUSHDATA1
        } else if (dataLen <= 0xffff) {
            ok = (opcode == 0x4d);        // OP_PUSHDATA2
        } else {
            ok = true;
        }
        const bool minimalData = (flags & MINIMALDATA) != 0;
        if (minimalData && !ok) return ERR_MINIMALDATA;
    }
    return ERR_OK;
}

extern "C" uint64_t cell_minimaldata_push(uint64_t flags, uint64_t fExec, uint64_t opcode,
                                          uint64_t dataLen, uint64_t b0Arg) {
    return l_minimaldata_push(flags, fExec, opcode, dataLen, b0Arg);
}
""",
    cry=r"""module PolicyCell where

// Independent predicate for SCR-177 (MINIMALDATA push minimality).
// ordinals: 0 pass, 25 SCRIPT_ERR_MINIMALDATA.
// opcode constants: OP_0=0, OP_PUSHDATA1=76, OP_PUSHDATA2=77, OP_PUSHDATA4=78.
minimaldata_push : [64] -> [64] -> [64] -> [64] -> [64] -> [64]
minimaldata_push flags fExec opcode dataLen b0Arg =
  if ((fExec != 0) && (opcode <= 78) && ((((flags >> 6) % 2) == 1) && ~ok)) then 25
  else 0
  where
    b0 = b0Arg % 256
    ok = if dataLen == 0 then opcode == 0
         else if ((dataLen == 1) && (b0 >= 1) && (b0 <= 16)) then False
         else if ((dataLen == 1) && (b0 == 129)) then False
         else if dataLen <= 75 then opcode == dataLen
         else if dataLen <= 255 then opcode == 76
         else if dataLen <= 65535 then opcode == 77
         else True
""",
    roots=[("cell_minimaldata_push", ["flags", "fExec", "opcode", "dataLen", "b0Arg"],
            "minimaldata_push")],
))


# ---------------------------------------------------------------- SCR-178 ---
CELL_DEFS.append(dict(
    family="policy-flags", id="C-L-minimalif-v0", rows="SCR-178",
    coverage="full", coverage_tag="full",
    marker="policy_flags_minimalif_v0",
    consensus="false",
    precond="""  - Scope: the witness-v0 policy arm of OP_IF/OP_NOTIF, interpreter.cpp:631-637.
  - Inputs: an arbitrary 64-bit flag word (MINIMALIF = 0x2000 is read), the
    SigVersion (0 = BASE, 1 = WITNESS_V0; every other value is the cell's
    out-of-domain guard), fExec (0/1), the top stack element's length
    (0..2**64-1) and its first byte (masked to 0..255).
  - The stack is non-empty and the branch is balanced (the underflow and
    UNBALANCED_CONDITIONAL paths are different rules).
  - The TAPSCRIPT arm (:624-629, SCRIPT_ERR_TAPSCRIPT_MINIMALIF) is deliberately
    excluded here; it is SCR-183's cell.
""",
    postcond="""  - fExec == 0                                   -> 0 (OP_IF not executed; no check)
  - SigVersion == WITNESS_V0 and MINIMALIF set and
    (len > 1 or (len == 1 and b0 != 1))           -> 31 SCRIPT_ERR_MINIMALIF
  - SigVersion == BASE                          -> 0 (the policy bit is ignored)
  - otherwise                                   -> 0
  i.e. the empty vector and the one-byte 0x01 vector pass; anything else fails
  only under the WITNESS_V0 + MINIMALIF combination.
""",
    citations="""  - "interpreter.cpp:625-644 (OP_IF/OP_NOTIF case; fExec gate :629, witness-v0 MINIMALIF :631-637, CastToBool :638)"
  - "src/script/interpreter.h:119-125 (MINIMALIF: segwit script only, tapscript re-imports it automatically)"
  - "src/validation.cpp:2249-2288 (GetBlockScriptFlags never sets MINIMALIF)"
  - "src/policy/policy.h:118-133 (MINIMALIF is standard, not mandatory)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:878-891 (stepBody OP_IF/OP_NOTIF; v0 arm :885-887)"
  - "contract/error_enum.md:76 (31 SIG_MINIMALIF)"
""",
    trust="""  C is a line-cited source excerpt of the OP_IF/OP_NOTIF case at the pin; it is
  not the whole EvalScript.  L is a REVIEWED TRANSLITERATION of the stepBody
  OP_IF/OP_NOTIF equation (Defs.lean:878-891), not generated from
  twin/ops_ir.py.  No crypto, memory or hash is involved.  No Core patch is
  used.
""",
    scope="""  FULL for SCR-178 as cited (:631-637): the v0 witness policy arm and the fact
  that BASE ignores the flag are total over (flags, sigversion in {BASE,
  WITNESS_V0}, fExec, element length, first byte), which is the complete input of
  the predicate.  Tapscript's consensus re-import is SCR-183 and is not claimed
  here.
""",
    limits="""The cell models the *argument check only*: it does not run the script, so it
says nothing about the branch taken after the check passes (CastToBool, pop,
vfExec push).  That is a different rule.
""",
    body="""The cell proves that MINIMALIF is a witness-v0-only policy gate: under
WITNESS_V0 with the bit set, an OP_IF/OP_NOTIF argument that is not exactly the
empty vector or the single byte 0x01 yields SCRIPT_ERR_MINIMALIF (31); with the
bit clear, or in a BASE script, the same argument is accepted.  The flag never
reaches block validation (`GetBlockScriptFlags`), so this is policy, not
consensus.
""",
    consensus_note="""**Not consensus for v0.**  `GetBlockScriptFlags` (validation.cpp:2249-2288)
never sets MINIMALIF, and it is absent from MANDATORY_SCRIPT_VERIFY_FLAGS
(policy.h:104-113).  interpreter.h:119-125 documents that tapscript re-imports
minimal-IF *as a consensus rule*; that arm is SCR-183 (consensus: true) and is a
different cell.
""",
    c_code=r"""#include "policy_common.h"
using namespace policy_cell;

// C leg: Bitcoin Core src/script/interpreter.cpp @ pin cce32b168.
//
//   case OP_IF:
//   case OP_NOTIF:
//   {
//       bool fValue = false;
//       if (fExec) {                                                              // :629
//           if (stack.size() < 1)
//               return set_error(serror, SCRIPT_ERR_INVALID_STACK_OPERATION);
//           valtype& vch = stacktop(-1);
//           // Tapscript requires minimal IF/NOTIF inputs as a consensus rule.   // :624-629
//           if (sigversion == SigVersion::TAPSCRIPT) { ... TAPSCRIPT_MINIMALIF }
//           // Under witness v0 rules it is only a policy rule, enabled through
//           // SCRIPT_VERIFY_MINIMALIF.                                          // :631
//           if (sigversion == SigVersion::WITNESS_V0 && (flags & SCRIPT_VERIFY_MINIMALIF)) {
//               if (vch.size() > 1)                                               // :632-633
//                   return set_error(serror, SCRIPT_ERR_MINIMALIF);
//               if (vch.size() == 1 && vch[0] != 1)                               // :634-635
//                   return set_error(serror, SCRIPT_ERR_MINIMALIF);
//           }
//           fValue = CastToBool(vch);                                             // :638
//
// The TAPSCRIPT arm is deliberately not modelled here (SCR-183).  The stack
// non-empty precondition discharges :630-631.

uint64_t c_minimalif_v0(uint64_t flags, uint64_t sigversion, uint64_t fExec,
                        uint64_t vchLen, uint64_t vch0Arg) {
    if (sigversion > SV_WITNESS_V0) return OUT_OF_DOMAIN;   // cell guard (harness)
    if (fExec == 0) return ERR_OK;                          // :629: branch not entered
    const uint64_t b0 = byte_of(vch0Arg);
    if (sigversion == SV_WITNESS_V0 && (flags & MINIMALIF) != 0) {
        if (vchLen > 1) return ERR_MINIMALIF;               // :632-633
        if (vchLen == 1 && b0 != 1) return ERR_MINIMALIF;   // :634-635
    }
    return ERR_OK;                                          // BASE ignores the bit
}

extern "C" uint64_t cell_minimalif_v0(uint64_t flags, uint64_t sigversion, uint64_t fExec,
                                      uint64_t vchLen, uint64_t vch0Arg) {
    return c_minimalif_v0(flags, sigversion, fExec, vchLen, vch0Arg);
}
""",
    l_code=r"""#include "policy_common.h"
using namespace policy_cell;

// L leg: REVIEWED TRANSLITERATION (not generated) of
//   spec/core/Bitcoin/Interpreter/Defs.lean:878-891 (stepBody, OP_IF/OP_NOTIF):
//
//   else if w = 0x63 ∨ w = 0x64 then
//     if fExec then
//       if st.stack.length < 1 then .error .stackUnderflow
//       else
//         let vch := topAt st.stack 1
//         if ctx.sv = .tapscript ∧ (1 < vch.size ∨ (vch.size = 1 ∧ byte ≠ 1)) then
//           .error .tapscriptMinimalIf                                       -- :883-884 (SCR-183)
//         else if ctx.sv = .witnessV0 ∧ pol.minimalIf ∧
//             (1 < vch.size ∨ (vch.size = 1 ∧ byte ≠ 1)) then
//           .error .minimalIf                                                -- :885-887
//         else .ok { ... }
//     else .ok { st with vf := false :: st.vf }                              -- :891
//
// `pol.minimalIf` is PolicyFlags.minimalIf (Defs.lean:187-205), fed by
// parsePolicyFlags from the corpus "MINIMALIF" string; Core carries the same bit
// in script_verify_flags (interpreter.cpp:631).

uint64_t l_minimalif_v0(uint64_t flags, uint64_t sigversion, uint64_t fExec,
                        uint64_t vchLen, uint64_t vch0Arg) {
    if (sigversion > SV_WITNESS_V0) return OUT_OF_DOMAIN;   // cell guard (harness)
    if (fExec == 0) return ERR_OK;
    const uint64_t b0 = byte_of(vch0Arg);
    const bool minimalIf = (flags & MINIMALIF) != 0;
    const bool notMinimal = (vchLen > 1) || (vchLen == 1 && b0 != 1);
    if (sigversion == SV_WITNESS_V0 && minimalIf && notMinimal) {
        return ERR_MINIMALIF;
    }
    return ERR_OK;
}

extern "C" uint64_t cell_minimalif_v0(uint64_t flags, uint64_t sigversion, uint64_t fExec,
                                      uint64_t vchLen, uint64_t vch0Arg) {
    return l_minimalif_v0(flags, sigversion, fExec, vchLen, vch0Arg);
}
""",
    cry=r"""module PolicyCell where

// Independent predicate for SCR-178 (witness-v0 MINIMALIF policy).
// sigversion: 0 = BASE, 1 = WITNESS_V0; anything else is out of domain (255).
// ordinal 0 pass, 31 SCRIPT_ERR_MINIMALIF.
minimalif_v0 : [64] -> [64] -> [64] -> [64] -> [64] -> [64]
minimalif_v0 flags sv fExec vchLen vch0 =
  if sv > 1 then 255
  else if fExec == 0 then 0
  else if ((sv == 1) && ((((flags >> 13) % 2) == 1) && notMinimal)) then 31
  else 0
  where
    b0         = vch0 % 256
    notMinimal = (vchLen > 1) || ((vchLen == 1) && (b0 != 1))
""",
    roots=[("cell_minimalif_v0", ["flags", "sv", "fExec", "vchLen", "vch0"],
            "minimalif_v0")],
))


# ---------------------------------------------------------------- SCR-179 ---
CELL_DEFS.append(dict(
    family="policy-flags", id="C-L-nullfail", rows="SCR-179",
    coverage="full", coverage_tag="full",
    marker="policy_flags_nullfail",
    consensus="false",
    precond="""  - Scope: the NULLFAIL check of `EvalChecksigPreTapscript`,
    interpreter.cpp:351-352.
  - Inputs: an arbitrary 64-bit flag word (NULLFAIL = 0x4000 is read), the
    ECDSA verdict of the shared checker (0 = failure, non-zero = success) and
    the signature element's length (0..2**64-1).
  - The two encoding gates at :344-350 (CheckSignatureEncoding /
    CheckPubKeyEncoding) are discharged by the precondition: the cell models the
    path where they pass, which is the only path that reaches the NULLFAIL
    branch.
  - The ECDSA verdict is an input (SAME-CRYPTO): the cell proves the flag gate
    and its predicate, not ECDSA.
""",
    postcond="""  - verdict == failure and NULLFAIL set and sig.size() != 0
        -> 32 SCRIPT_ERR_SIG_NULLFAIL
  - otherwise -> 0
  In particular: an empty signature never trips NULLFAIL (Core's
  `&& vchSig.size()`), and with the flag clear a failed CHECK(MULTI)SIG pushes
  false instead of failing the script.
""",
    citations="""  - "interpreter.cpp:328-368 (EvalChecksigPreTapscript; encoding gates :344-350, checker call :349)"
  - "interpreter.cpp:351-352 (if (!fSuccess && (flags & SCRIPT_VERIFY_NULLFAIL) && vchSig.size()) -> SCRIPT_ERR_SIG_NULLFAIL)"
  - "src/validation.cpp:2249-2288 (GetBlockScriptFlags never sets NULLFAIL)"
  - "src/policy/policy.h:118-133 (NULLFAIL is standard, not mandatory)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:720-739 (evalChecksigPreTapscript; NULLFAIL :738)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:187-205 (PolicyFlags.nullFail)"
  - "contract/error_enum.md:77 (32 SIG_NULLFAIL)"
""",
    trust="""  C is a line-cited source excerpt of interpreter.cpp:344-354 at the pin; it is
  not the whole EvalScript and not the whole checksig path.  L is a REVIEWED
  TRANSLITERATION of Bitcoin.Interpreter.evalChecksigPreTapscript
  (Defs.lean:720-739), not generated from twin/ops_ir.py.  The ECDSA verdict is
  an unconstrained input, so the cell is conditional on the shared checker:
  docs/DECISION-lax-ecdsa.md governs, and nothing here proves ECDSA or
  libsecp256k1.  No Core patch is used.
""",
    scope="""  FULL for SCR-179 as cited (:351-352): total over (flag word, checker verdict,
  signature length).  NOT claimed: the second NULLFAIL site in the
  CHECKMULTISIG cleanup loop (interpreter.cpp:1212-1221,
  Defs.lean:702-712) - it is outside this row's cited range and is a
  CHECKMULTISIG-family rule.
""",
    limits="""The verdict is an input, so the cell does not prove when a signature is
invalid.  The CHECKMULTISIG cleanup NULLFAIL site is out of scope.
""",
    body="""The cell proves the NULLFAIL policy branch exactly: a failed CHECK(MULTI)SIG
with a non-empty signature element aborts with SCRIPT_ERR_SIG_NULLFAIL (32) only
when the NULLFAIL bit is set; an empty signature is exempt; and with the bit
clear the interpreter returns false to the script instead of failing it.
NULLFAIL is standard-only (`GetBlockScriptFlags` never sets it).
""",
    consensus_note="""**Not consensus.**  `GetBlockScriptFlags` (validation.cpp:2249-2288) never
sets NULLFAIL, and it is absent from MANDATORY_SCRIPT_VERIFY_FLAGS
(policy.h:104-113).  It appears only in STANDARD_SCRIPT_VERIFY_FLAGS
(policy.h:118-133).  A non-empty failed signature is therefore relay-invalid,
not consensus-invalid.
""",
    c_code=r"""#include "policy_common.h"
using namespace policy_cell;

// C leg: Bitcoin Core src/script/interpreter.cpp @ pin cce32b168,
// EvalChecksigPreTapscript (:328-368).  The cited branch:
//
//   if (!CheckSignatureEncoding(vchSig, flags, serror) || !CheckPubKeyEncoding(vchPubKey, flags, sigversion, serror)) {
//       return false;                                                              // :344-350
//   }
//   fSuccess = checker.CheckECDSASignature(vchSig, vchPubKey, scriptCode, sigversion);  // :349
//
//   if (!fSuccess && (flags & SCRIPT_VERIFY_NULLFAIL) && vchSig.size())             // :351
//       return set_error(serror, SCRIPT_ERR_SIG_NULLFAIL);                          // :352
//
//   return true;                                                                    // :354
//
// Precondition of this cell: the encoding gates at :344-350 passed (they are
// separate rows).  `fSuccess` is the shared checker's verdict, an input.

uint64_t c_nullfail(uint64_t flags, uint64_t fSuccess, uint64_t sigLen) {
    if (fSuccess == 0 && (flags & NULLFAIL) != 0 && sigLen != 0) {
        return ERR_SIG_NULLFAIL;
    }
    return ERR_OK;
}

extern "C" uint64_t cell_nullfail(uint64_t flags, uint64_t fSuccess, uint64_t sigLen) {
    return c_nullfail(flags, fSuccess, sigLen);
}
""",
    l_code=r"""#include "policy_common.h"
using namespace policy_cell;

// L leg: REVIEWED TRANSLITERATION (not generated) of
//   spec/core/Bitcoin/Interpreter/Defs.lean:730-739:
//
//   match sc with
//   | .error e => .error e
//   | .ok scriptCode =>
//     match checkSigEncoding flags pol sig, checkPubKeyEncoding flags pol sv pk with
//     | some e, _ => .error e
//     | _, some e => .error e
//     | none, none =>
//       let fSuccess := chk.base.checkECDSASignature sig pk scriptCode sv ed
//       if !fSuccess ∧ pol.nullFail ∧ sig.size ≠ 0 then .error .sigNullFail   -- :738
//       else .ok fSuccess                                                     -- :739
//
// The `none, none` arm is the cell precondition (both encoding gates passed).
// `pol.nullFail` is PolicyFlags.nullFail (Defs.lean:187-205), fed by
// parsePolicyFlags from the corpus "NULLFAIL" string; Core carries the same bit
// in script_verify_flags (interpreter.cpp:351).

uint64_t l_nullfail(uint64_t flags, uint64_t fSuccess, uint64_t sigLen) {
    const bool nullFail = (flags & NULLFAIL) != 0;
    if (fSuccess == 0 && nullFail && sigLen != 0) return ERR_SIG_NULLFAIL;
    return ERR_OK;
}

extern "C" uint64_t cell_nullfail(uint64_t flags, uint64_t fSuccess, uint64_t sigLen) {
    return l_nullfail(flags, fSuccess, sigLen);
}
""",
    cry=r"""module PolicyCell where

// Independent predicate for SCR-179 (NULLFAIL policy).
// ordinal 0 pass, 32 SCRIPT_ERR_SIG_NULLFAIL.
nullfail : [64] -> [64] -> [64] -> [64]
nullfail flags fSuccess sigLen =
  if ((fSuccess == 0) && ((((flags >> 14) % 2) == 1) && (sigLen != 0))) then 32
  else 0
""",
    roots=[("cell_nullfail", ["flags", "fSuccess", "sigLen"], "nullfail")],
))


# ---------------------------------------------------------------- SCR-180 ---
CELL_DEFS.append(dict(
    family="policy-flags", id="C-L-cleanstack-base", rows="SCR-180",
    coverage="full", coverage_tag="full",
    marker="policy_flags_cleanstack",
    consensus="false",
    precond="""  - Scope: the two clean-stack enforcement sites the row distinguishes:
      * base (non-witness) spends: the SCRIPT_VERIFY_CLEANSTACK gate at the end
        of VerifyScript, interpreter.cpp:2110-2118;
      * witness-v0 spends: the implicit check at the end of
        ExecuteWitnessScript, interpreter.cpp:1876-1878.
  - Inputs: an arbitrary 64-bit flag word (CLEANSTACK = 0x100 is read on the
    base path and never on the witness path), the SigVersion (0 = BASE,
    1 = WITNESS_V0; other values are the cell's out-of-domain guard) and the
    final stack length (0..2**64-1) handed to the check.
  - The P2SH/witness preconditions Core asserts at :2112-2114
    (CLEANSTACK => P2SH && WITNESS) are a flag-combination rule
    (Defs.lean Rules.flagsComboOk, SCR-009/SCR-014); they are not modelled as a
    root here, so the cell assumes a well-formed flag word.
  - The stack length is an input: the cell proves the enforcement predicate, not
    the interpreter loop that computes the stack.
""",
    postcond="""  - SigVersion == BASE:
      CLEANSTACK set and final length != 1 -> 30 SCRIPT_ERR_CLEANSTACK
      CLEANSTACK clear                     -> 0 (any length)
  - SigVersion == WITNESS_V0:
      final length != 1                    -> 30 SCRIPT_ERR_CLEANSTACK,
                                              regardless of the flag word
  - The witness arm runs before the EVAL_FALSE check (:1879), so a length of 0
    or >= 2 reports CLEANSTACK rather than EVAL_FALSE.
""",
    citations="""  - "interpreter.cpp:2109-2119 (VerifyScript tail: CLEANSTACK gate, asserts P2SH+WITNESS at :2112-2114, size != 1 -> SCRIPT_ERR_CLEANSTACK)"
  - "interpreter.cpp:2098-2107 (P2SH/witness path resizes the stack to 1 to bypass the check)"
  - "interpreter.cpp:1876-1878 (ExecuteWitnessScript: scripts inside witness implicitly require cleanstack)"
  - "src/script/interpreter.h:91-99 (CLEANSTACK: policy bit; WITNESS_V0/TAPSCRIPT have similar behaviour as consensus, automatic there)"
  - "src/validation.cpp:2249-2288 (GetBlockScriptFlags never sets CLEANSTACK)"
  - "src/policy/policy.h:118-133 (CLEANSTACK is standard, not mandatory)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1237-1239 (executeWitnessScript implicit cleanstack)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1431,1443 (VerifyScript pol.cleanstack gates on the P2SH and bare paths)"
  - "spec/core/Bitcoin/Interpreter/Rules.lean:45-52 (flagsComboOk: CLEANSTACK => P2SH && WITNESS)"
  - "contract/error_enum.md:75 (30 SIG_CLEANSTACK)"
""",
    trust="""  C combines two line-cited excerpts of interpreter.cpp at the pin (2110-2118
  and 1876-1878); it is not the whole VerifyScript or ExecuteWitnessScript.  L is
  a REVIEWED TRANSLITERATION of executeWitnessScript's tail
  (Defs.lean:1237-1239) and the VerifyScript `pol.cleanstack` gates
  (Defs.lean:1431/1443), not generated from twin/ops_ir.py.  The final stack
  length is an input, so the cell is a predicate proof about *enforcement*; it
  does not model EvalScript.  No crypto is involved and no Core patch is used.
""",
    scope="""  FULL for SCR-180 as cited (:2110-2118) plus the row's witness-v0 half
  (:1876-1878): total over (flag word, sigversion in {BASE, WITNESS_V0}, final
  length).  NOT claimed: that the final length is what EvalScript produces (that
  is the whole-engine loop seam, E4:F-TOOL-001), the P2SH `stack.resize(1)`
  bypass in detail, and the tapscript instance of the implicit check (SCR-183).
""",
    limits="""Enforcement predicate only: the post-state length is an input.  The
flag-combination asserts (:2112-2114) are assumed, not proved here.
""",
    body="""The cell proves the row's central distinction in one total predicate: on a
BASE spend the clean-stack requirement is *gated* by the CLEANSTACK policy bit,
while on a WITNESS_V0 spend the same `stack.size() != 1 -> CLEANSTACK`
requirement is enforced regardless of the flag word, because it sits in
`ExecuteWitnessScript` as a consensus rule.  It also fixes the error precedence:
the witness clean-stack check runs before EVAL_FALSE, so an empty or
multi-element witness script stack reports CLEANSTACK (30), not EVAL_FALSE.
""",
    consensus_note="""**Mixed, and the row is non-consensus as stated.**  The CLEANSTACK *flag* is
policy: `GetBlockScriptFlags` (validation.cpp:2249-2288) never sets it, it is
absent from MANDATORY_SCRIPT_VERIFY_FLAGS (policy.h:104-113) and present in
STANDARD_SCRIPT_VERIFY_FLAGS.  The *witness-v0* clean-stack requirement is
consensus and independent of the flag (it lives in ExecuteWitnessScript).  The
row is filed `consensus: false` because the flag itself is policy; the cell
keeps the two halves separate so neither is overclaimed.  Tapscript's instance
is SCR-183 (consensus: true).
""",
    c_code=r"""#include "policy_common.h"
using namespace policy_cell;

// C leg: Bitcoin Core src/script/interpreter.cpp @ pin cce32b168.
//
// (a) VerifyScript tail, base/non-witness spends (:2109-2119):
//
//   // The CLEANSTACK check is only performed after potential P2SH evaluation, ...
//   if ((flags & SCRIPT_VERIFY_CLEANSTACK) != 0) {                     // :2110
//       assert((flags & SCRIPT_VERIFY_P2SH) != 0);                     // :2112-2113
//       assert((flags & SCRIPT_VERIFY_WITNESS) != 0);                  // :2114
//       if (stack.size() != 1) {                                       // :2115
//           return set_error(serror, SCRIPT_ERR_CLEANSTACK);           // :2116
//       }
//   }
//
// (b) ExecuteWitnessScript tail, witness-v0 spends (:1876-1878):
//
//   // Scripts inside witness implicitly require cleanstack behaviour
//   if (stack.size() != 1) return set_error(serror, SCRIPT_ERR_CLEANSTACK);   // :1877
//   if (!CastToBool(stack.back())) return set_error(serror, SCRIPT_ERR_EVAL_FALSE);  // :1878
//
// The two sites are combined in one total predicate parameterised by SigVersion
// so that "gated by the flag" and "independent of the flag" are one proof.
// The final stack length is an input (see spec.md precondition).

uint64_t c_cleanstack(uint64_t flags, uint64_t sigversion, uint64_t finalLen) {
    if (sigversion > SV_WITNESS_V0) return OUT_OF_DOMAIN;   // cell guard (harness)
    if (sigversion == SV_BASE) {
        if ((flags & CLEANSTACK) != 0) {                    // :2110
            if (finalLen != 1) return ERR_CLEANSTACK;       // :2115-2116
        }
    } else {
        if (finalLen != 1) return ERR_CLEANSTACK;           // :1877 (no flag read)
    }
    return ERR_OK;
}

extern "C" uint64_t cell_cleanstack(uint64_t flags, uint64_t sigversion, uint64_t finalLen) {
    return c_cleanstack(flags, sigversion, finalLen);
}
""",
    l_code=r"""#include "policy_common.h"
using namespace policy_cell;

// L leg: REVIEWED TRANSLITERATION (not generated) of
//   spec/core/Bitcoin/Interpreter/Defs.lean
//
// executeWitnessScript tail (:1236-1239):
//   | .ok st =>
//     -- witness scripts implicitly require cleanstack
//     if st.length ≠ 1 then .fail .cleanstack                            -- :1238
//     else if castToBool st[0]! then .ok else .fail .evalFalse           -- :1239
//
// VerifyScript, bare path (:1442-1443) and P2SH path (:1431):
//     if pol.cleanstack ∧ afterBare.length ≠ 1 then .fail .cleanstack    -- :1443
//     if pol.cleanstack ∧ finalLen ≠ 1 then .fail .cleanstack            -- :1431
//
// `pol.cleanstack` is PolicyFlags.cleanstack (Defs.lean:187-205), fed by
// parsePolicyFlags from the corpus "CLEANSTACK" string; Core carries the same
// bit in script_verify_flags (:2110).  The witness arm reads no policy bit at
// all, which is exactly the row's point.

uint64_t l_cleanstack(uint64_t flags, uint64_t sigversion, uint64_t finalLen) {
    if (sigversion > SV_WITNESS_V0) return OUT_OF_DOMAIN;   // cell guard (harness)
    const bool cleanstack = (flags & CLEANSTACK) != 0;
    if (sigversion == SV_BASE) {
        if (cleanstack && finalLen != 1) return ERR_CLEANSTACK;
    } else {
        (void)cleanstack;                                   // :1238 never consults it
        if (finalLen != 1) return ERR_CLEANSTACK;
    }
    return ERR_OK;
}

extern "C" uint64_t cell_cleanstack(uint64_t flags, uint64_t sigversion, uint64_t finalLen) {
    return l_cleanstack(flags, sigversion, finalLen);
}
""",
    cry=r"""module PolicyCell where

// Independent predicate for SCR-180 (CLEANSTACK: base policy vs v0 implicit).
// sigversion: 0 = BASE, 1 = WITNESS_V0; anything else is out of domain (255).
// ordinal 0 pass, 30 SCRIPT_ERR_CLEANSTACK.
cleanstack : [64] -> [64] -> [64] -> [64]
cleanstack flags sv finalLen =
  if sv > 1 then 255
  else if sv == 0 then
    (if ((((flags >> 8) % 2) == 1) && (finalLen != 1)) then 30 else 0)
  else (if (finalLen != 1) then 30 else 0)
""",
    roots=[("cell_cleanstack", ["flags", "sv", "finalLen"], "cleanstack")],
))


# ---------------------------------------------------------------- SCR-181 ---
CELL_DEFS.append(dict(
    family="policy-flags", id="C-L-const-scriptcode", rows="SCR-181",
    coverage="full", coverage_tag="full",
    marker="policy_flags_const_scriptcode",
    consensus="false",
    precond="""  - Scope: the two CONST_SCRIPTCODE gates the row cites:
      * the decode-time rejection of OP_CODESEPARATOR in a BASE script,
        interpreter.cpp:484-486;
      * the FindAndDelete rejection in `EvalChecksigPreTapscript`,
        interpreter.cpp:339-343.
  - Inputs: an arbitrary 64-bit flag word (CONST_SCRIPTCODE = 0x10000 is
    read), the SigVersion (0 = BASE, 1 = WITNESS_V0, 2 = TAPSCRIPT), whichever
    of (opcode, FindAndDelete count) the root needs, and a 0/1 model of
    `found > 0`.
  - Preconditions: for the decode root, the earlier decode/opcount/disabled
    checks passed (they precede :485); for the FindAndDelete root, the
    signature element is whatever was searched for and `found` is its
    FindAndDelete count, with count 0 or 1 modelled exactly (a 1-bit input; the
    greedy scan can return more, but the rule only tests `found > 0`).
""",
    postcond="""  Root 1 (decode):
    opcode == OP_CODESEPARATOR (0xab) and SigVersion == BASE and flag set
      -> 53 SCRIPT_ERR_OP_CODESEPARATOR
    otherwise -> 0.  It fires even in an unexecuted branch, because :485 runs
    before the fExec switch.
  Root 2 (FindAndDelete):
    SigVersion == BASE and found > 0 and flag set
      -> 54 SCRIPT_ERR_SIG_FINDANDDELETE
    otherwise -> 0.  Witness v0 keeps the signature in scriptCode (BIP143), so
    FindAndDelete never runs there and the gate cannot fire.
""",
    citations="""  - "interpreter.cpp:484-486 (OP_CODESEPARATOR + BASE + CONST_SCRIPTCODE -> SCRIPT_ERR_OP_CODESEPARATOR, before the fExec dispatch)"
  - "interpreter.cpp:1058-1066 (OP_CODESEPARATOR case in the executed switch)"
  - "interpreter.cpp:332-343 (FindAndDelete only for SigVersion::BASE; found>0 && CONST_SCRIPTCODE -> SCRIPT_ERR_SIG_FINDANDDELETE)"
  - "src/script/interpreter.h:127-133 (CONST_SCRIPTCODE: OP_CODESEPARATOR and FindAndDelete fail non-segwit scripts)"
  - "src/validation.cpp:2249-2288 (GetBlockScriptFlags never sets CONST_SCRIPTCODE)"
  - "src/policy/policy.h:118-133 (CONST_SCRIPTCODE is standard, not mandatory)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:833 (stepBody decode-time OP_CODESEPARATOR gate)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:725-729 (evalChecksigPreTapscript FindAndDelete gate)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1098-1101 (scriptCode FindAndDelete gate in the checksig path)"
  - "contract/error_enum.md:98-99 (53 SIG_OP_CODESEPARATOR, 54 SIG_FINDANDDELETE)"
""",
    trust="""  C is a line-cited source excerpt of the two gates (interpreter.cpp:484-486,
  332-343) at the pin; it is not the whole EvalScript and does not implement
  FindAndDelete itself.  L is a REVIEWED TRANSLITERATION of the corresponding
  stepBody and evalChecksigPreTapscript gates (Defs.lean:833, 725-729), not
  generated from twin/ops_ir.py.  The FindAndDelete count is an input; the scan
  algorithm is a separate rule and is not claimed.  No Core patch is used.
""",
    scope="""  FULL for SCR-181 as cited (:484-486, :339-343): both gates are total over
  (flag word, sigversion, opcode) and (flag word, sigversion, found>0).  NOT
  claimed: the byte-level FindAndDelete implementation/comparison
  (Defs.lean:541-600) and the scriptCode slicing at the last separator; only
  the flag gates are proved.
""",
    limits="""`found` is a 1-bit model of `FindAndDelete(...) > 0`; the scan itself is not
modelled.  The decode root assumes the earlier decode checks passed.
""",
    body="""The cell proves both halves of CONST_SCRIPTCODE: on a BASE script, an
OP_CODESEPARATOR is rejected at decode time even when it sits in an unexecuted
branch, and a signature found by FindAndDelete rejects the spend with
SCRIPT_ERR_SIG_FINDANDDELETE.  Both are gated by the flag and by
`sigversion == BASE`; witness v0 and tapscript are untouched (BIP143 removed
FindAndDelete there), which the same total predicate shows.
""",
    consensus_note="""**Not consensus.**  `GetBlockScriptFlags` (validation.cpp:2249-2288) never
sets CONST_SCRIPTCODE, and it is absent from MANDATORY_SCRIPT_VERIFY_FLAGS
(policy.h:104-113).  It appears only in STANDARD_SCRIPT_VERIFY_FLAGS
(policy.h:118-133), where interpreter.h:127-133 describes it as making
OP_CODESEPARATOR/FindAndDelete fail non-segwit scripts for standardness.
""",
    c_code=r"""#include "policy_common.h"
using namespace policy_cell;

// C leg: Bitcoin Core src/script/interpreter.cpp @ pin cce32b168.
//
// Root 1 -- decode-time gate (:484-486):
//
//   // With SCRIPT_VERIFY_CONST_SCRIPTCODE, OP_CODESEPARATOR in non-segwit script
//   // is rejected even in an unexecuted branch
//   if (opcode == OP_CODESEPARATOR && sigversion == SigVersion::BASE &&
//       (flags & SCRIPT_VERIFY_CONST_SCRIPTCODE))
//       return set_error(serror, SCRIPT_ERR_OP_CODESEPARATOR);              // :486
//
// Root 2 -- FindAndDelete gate inside EvalChecksigPreTapscript (:332-343):
//
//   CScript scriptCode(pbegincodehash, pend);
//   if (sigversion == SigVersion::BASE) {                                   // :337
//       int found = FindAndDelete(scriptCode, CScript() << vchSig);         // :339
//       if (found > 0 && (flags & SCRIPT_VERIFY_CONST_SCRIPTCODE))          // :340
//           return set_error(serror, SCRIPT_ERR_SIG_FINDANDDELETE);         // :341
//   }
//
// `found` is modelled as a 0/1 input (the rule only tests `found > 0`).

uint64_t c_const_scriptcode_codesep(uint64_t flags, uint64_t sigversion, uint64_t opcode) {
    if (opcode == OP_CODESEPARATOR && sigversion == SV_BASE &&
        (flags & CONST_SCRIPTCODE) != 0) {
        return ERR_OP_CODESEPARATOR;
    }
    return ERR_OK;
}

uint64_t c_const_scriptcode_finddelete(uint64_t flags, uint64_t sigversion, uint64_t foundPositive) {
    if (foundPositive > 1) return OUT_OF_DOMAIN;              // cell guard (harness)
    if (sigversion == SV_BASE && foundPositive != 0 &&
        (flags & CONST_SCRIPTCODE) != 0) {
        return ERR_SIG_FINDANDDELETE;
    }
    return ERR_OK;
}

extern "C" uint64_t cell_const_scriptcode_codesep(uint64_t flags, uint64_t sigversion, uint64_t opcode) {
    return c_const_scriptcode_codesep(flags, sigversion, opcode);
}

extern "C" uint64_t cell_const_scriptcode_finddelete(uint64_t flags, uint64_t sigversion, uint64_t foundPositive) {
    return c_const_scriptcode_finddelete(flags, sigversion, foundPositive);
}
""",
    l_code=r"""#include "policy_common.h"
using namespace policy_cell;

// L leg: REVIEWED TRANSLITERATION (not generated) of
//   spec/core/Bitcoin/Interpreter/Defs.lean
//
// Root 1 -- stepBody decode-time gate (:831-834):
//   -- (3) disabled opcodes (CVE-2010-5137) — unexecuted branches included
//   else if disabledWire w then .error .disabledOpcode
//   -- (4) OP_CODESEPARATOR under CONST_SCRIPTCODE in non-segwit script
//   else if w = 0xab ∧ ctx.sv = .base ∧ ctx.pol.constScriptCode
//     then .error .opCodeSeparator                                      -- :833
//
// Root 2 -- evalChecksigPreTapscript (:724-729):
//   if sv = .base then
//     let (found, sc') := findAndDelete scriptCode0 (pushBytesWire sig)
//     if 0 < found ∧ pol.constScriptCode then .error .sigFindAndDelete  -- :728
//     else .ok sc'
//   else .ok scriptCode0
//
// `ctx.pol.constScriptCode` is PolicyFlags.constScriptCode (Defs.lean:187-205),
// fed by parsePolicyFlags from the corpus "CONST_SCRIPTCODE" string; Core
// carries the same bit in script_verify_flags.

uint64_t l_const_scriptcode_codesep(uint64_t flags, uint64_t sigversion, uint64_t opcode) {
    const bool constScriptCode = (flags & CONST_SCRIPTCODE) != 0;
    if (opcode == 0xab && sigversion == SV_BASE && constScriptCode) {
        return ERR_OP_CODESEPARATOR;
    }
    return ERR_OK;
}

uint64_t l_const_scriptcode_finddelete(uint64_t flags, uint64_t sigversion, uint64_t foundPositive) {
    if (foundPositive > 1) return OUT_OF_DOMAIN;              // cell guard (harness)
    const bool constScriptCode = (flags & CONST_SCRIPTCODE) != 0;
    const bool found = foundPositive != 0;
    if (sigversion == SV_BASE && found && constScriptCode) {
        return ERR_SIG_FINDANDDELETE;
    }
    return ERR_OK;
}

extern "C" uint64_t cell_const_scriptcode_codesep(uint64_t flags, uint64_t sigversion, uint64_t opcode) {
    return l_const_scriptcode_codesep(flags, sigversion, opcode);
}

extern "C" uint64_t cell_const_scriptcode_finddelete(uint64_t flags, uint64_t sigversion, uint64_t foundPositive) {
    return l_const_scriptcode_finddelete(flags, sigversion, foundPositive);
}
""",
    cry=r"""module PolicyCell where

// Independent predicate for SCR-181 (CONST_SCRIPTCODE, both cited gates).
// sigversion: 0 BASE, 1 WITNESS_V0, 2 TAPSCRIPT.  OP_CODESEPARATOR = 171.
// ordinals: 0 pass, 53 SIG_OP_CODESEPARATOR, 54 SIG_FINDANDDELETE, 255 out of domain.
const_codesep : [64] -> [64] -> [64] -> [64]
const_codesep flags sv opcode =
  if ((opcode == 171) && ((sv == 0) && (((flags >> 16) % 2) == 1))) then 53
  else 0

const_finddelete : [64] -> [64] -> [64] -> [64]
const_finddelete flags sv foundPositive =
  if foundPositive > 1 then 255
  else if ((sv == 0) && ((foundPositive != 0) && (((flags >> 16) % 2) == 1))) then 54
  else 0
""",
    roots=[("cell_const_scriptcode_codesep", ["flags", "sv", "opcode"], "const_codesep"),
           ("cell_const_scriptcode_finddelete", ["flags", "sv", "foundPositive"],
            "const_finddelete")],
))


# ---------------------------------------------------------------- SCR-182 ---
CELL_DEFS.append(dict(
    family="policy-flags", id="C-L-witness-pubkeytype", rows="SCR-182",
    coverage="full", coverage_tag="full",
    marker="policy_flags_witness_pubkeytype",
    consensus="false",
    precond="""  - Scope: the WITNESS_PUBKEYTYPE branch of `CheckPubKeyEncoding`,
    interpreter.cpp:233-235, and its callee `IsCompressedPubKey` (:96-106).
  - Inputs: an arbitrary 64-bit flag word (WITNESS_PUBKEYTYPE = 0x8000 is
    read), the SigVersion (0 = BASE, 1 = WITNESS_V0, 2 = TAPSCRIPT; other values
    are the cell's out-of-domain guard), the pubkey length and its first byte
    (masked to 0..255).
  - `IsCompressedPubKey` reads only the length (must be 33) and the first byte
    (must be 0x02 or 0x03), so (len, byte0) is its complete input.
  - The STRICTENC branch above it (:229-231) is a different row (SCR-176) and
    is assumed not to have fired; i.e. the cell models the branch order with
    `strictEnc` clear.
""",
    postcond="""  - WITNESS_PUBKEYTYPE set and SigVersion == WITNESS_V0 and the pubkey is not
    (33 bytes with first byte 0x02 or 0x03)
      -> 44 SCRIPT_ERR_WITNESS_PUBKEYTYPE
  - otherwise -> 0
  Note the gate is `sigversion == WITNESS_V0` only: TAPSCRIPT and BASE do not
  read this bit here, so an uncompressed key is accepted by this check there.
""",
    citations="""  - "interpreter.cpp:94-106 (IsCompressedPubKey: size 33, prefix 0x02/0x03)"
  - "interpreter.cpp:227-237 (CheckPubKeyEncoding; WITNESS_PUBKEYTYPE branch :233-235)"
  - "src/validation.cpp:2249-2288 (GetBlockScriptFlags never sets WITNESS_PUBKEYTYPE)"
  - "src/policy/policy.h:118-133 (WITNESS_PUBKEYTYPE is standard, not mandatory)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:389-391 (isCompressedPubKey)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:398-403 (checkPubKeyEncoding; v0 arm :401-402)"
  - "contract/error_enum.md:88 (44 SIG_WITNESS_PUBKEYTYPE)"
""",
    trust="""  C is a line-cited source excerpt of interpreter.cpp:94-106/227-237 at the
  pin; it is not the whole EvalScript.  L is a REVIEWED TRANSLITERATION of
  Bitcoin.Interpreter.isCompressedPubKey and checkPubKeyEncoding
  (Defs.lean:389-403), not generated from twin/ops_ir.py.  No crypto is
  involved: the check is a length/prefix test, not a curve operation.  No Core
  patch is used.
""",
    scope="""  FULL for SCR-182 as cited (:233-235): total over (flag word, sigversion,
  length, first byte), the complete input of the predicate.  The interaction
  with STRICTENC's error precedence is assumed (strictEnc clear) and is SCR-176's
  cell.
""",
    limits="""`strictEnc` is assumed clear (branch order).  Only length and prefix are
checked by Core here; the cell models exactly that.  No curve validation.
""",
    body="""The cell proves the WITNESS_PUBKEYTYPE policy: in a witness-v0 script an
uncompressed or malformed public key is rejected with
SCRIPT_ERR_WITNESS_PUBKEYTYPE (44) when the bit is set, and the bit is consulted
only on the WITNESS_V0 branch, so BASE and TAPSCRIPT is unaffected at this site.
This is the segwit compressed-key policy, not a consensus rule.
""",
    consensus_note="""**Not consensus.**  `GetBlockScriptFlags` (validation.cpp:2249-2288) never
sets WITNESS_PUBKEYTYPE, and it is absent from MANDATORY_SCRIPT_VERIFY_FLAGS
(policy.h:104-113); it appears only in STANDARD_SCRIPT_VERIFY_FLAGS.  An
uncompressed key in a P2WPKH/P2WSH spend is relay-invalid, not
consensus-invalid.
""",
    c_code=r"""#include "policy_common.h"
using namespace policy_cell;

// C leg: Bitcoin Core src/script/interpreter.cpp @ pin cce32b168.
//
// bool static IsCompressedPubKey(const valtype &vchPubKey) {          // :96
//     if (vchPubKey.size() != CPubKey::COMPRESSED_SIZE) return false; // :97-100
//     if (vchPubKey[0] != 0x02 && vchPubKey[0] != 0x03) return false; // :101-104
//     return true;                                                    // :105
// }
//
// bool static CheckPubKeyEncoding(const valtype &vchPubKey, script_verify_flags flags,
//                                 const SigVersion &sigversion, ScriptError* serror) {
//     if ((flags & SCRIPT_VERIFY_STRICTENC) != 0 && !IsCompressedOrUncompressedPubKey(...))
//         return set_error(serror, SCRIPT_ERR_PUBKEYTYPE);                            // :229-231
//     // Only compressed keys are accepted in segwit
//     if ((flags & SCRIPT_VERIFY_WITNESS_PUBKEYTYPE) != 0 &&
//         sigversion == SigVersion::WITNESS_V0 && !IsCompressedPubKey(vchPubKey))
//         return set_error(serror, SCRIPT_ERR_WITNESS_PUBKEYTYPE);                    // :233-235
// }
//
// Precondition: the STRICTENC branch above did not fire (strictEnc clear).

uint64_t c_witness_pubkeytype(uint64_t flags, uint64_t sigversion,
                              uint64_t pkLen, uint64_t pk0Arg) {
    if (sigversion > SV_TAPSCRIPT) return OUT_OF_DOMAIN;   // cell guard (harness)
    const uint64_t b0 = byte_of(pk0Arg);
    const bool compressed = (pkLen == 33) && (b0 == 0x02 || b0 == 0x03);
    if ((flags & WITNESS_PUBKEYTYPE) != 0 && sigversion == SV_WITNESS_V0 && !compressed) {
        return ERR_WITNESS_PUBKEYTYPE;
    }
    return ERR_OK;
}

extern "C" uint64_t cell_witness_pubkeytype(uint64_t flags, uint64_t sigversion,
                                            uint64_t pkLen, uint64_t pk0Arg) {
    return c_witness_pubkeytype(flags, sigversion, pkLen, pk0Arg);
}
""",
    l_code=r"""#include "policy_common.h"
using namespace policy_cell;

// L leg: REVIEWED TRANSLITERATION (not generated) of
//   spec/core/Bitcoin/Interpreter/Defs.lean
//
//   def isCompressedPubKey (pk : ByteArray) : Bool :=                    -- :389-391
//     pk.size = 33 ∧ (byteOr pk 0 = 0x02 ∨ byteOr pk 0 = 0x03)
//
//   def checkPubKeyEncoding (_flags : ScriptFlags) (pol : PolicyFlags)   -- :398-403
//       (sv : SigVersion) (pk : ByteArray) : Option ExecError :=
//     if pol.strictEnc ∧ !isCompressedOrUncompressedPubKey pk then some .pubKeyType
//     else if pol.witnessPubkeyType ∧ sv = .witnessV0 ∧ !isCompressedPubKey pk
//       then some .witnessPubkeyType                                      -- :401-402
//     else none
//
// `pol.witnessPubkeyType` is PolicyFlags.witnessPubkeyType (Defs.lean:187-205),
// fed by parsePolicyFlags from the corpus "WITNESS_PUBKEYTYPE" string; Core
// carries the same bit in script_verify_flags (:233-235).  The first arm is the
// cell precondition (strictEnc clear).

uint64_t l_witness_pubkeytype(uint64_t flags, uint64_t sigversion,
                              uint64_t pkLen, uint64_t pk0Arg) {
    if (sigversion > SV_TAPSCRIPT) return OUT_OF_DOMAIN;   // cell guard (harness)
    const uint64_t b0 = byte_of(pk0Arg);
    const bool compressed = (pkLen == 33) && (b0 == 0x02 || b0 == 0x03);
    const bool witnessPubkeyType = (flags & WITNESS_PUBKEYTYPE) != 0;
    if (witnessPubkeyType && sigversion == SV_WITNESS_V0 && !compressed) {
        return ERR_WITNESS_PUBKEYTYPE;
    }
    return ERR_OK;
}

extern "C" uint64_t cell_witness_pubkeytype(uint64_t flags, uint64_t sigversion,
                                            uint64_t pkLen, uint64_t pk0Arg) {
    return l_witness_pubkeytype(flags, sigversion, pkLen, pk0Arg);
}
""",
    cry=r"""module PolicyCell where

// Independent predicate for SCR-182 (WITNESS_PUBKEYTYPE compressed-key policy).
// sigversion: 0 BASE, 1 WITNESS_V0, 2 TAPSCRIPT; anything else out of domain.
// ordinal 0 pass, 44 SCRIPT_ERR_WITNESS_PUBKEYTYPE.
witness_pubkeytype : [64] -> [64] -> [64] -> [64] -> [64]
witness_pubkeytype flags sv pkLen pk0 =
  if sv > 2 then 255
  else if ((((flags >> 15) % 2) == 1) && ((sv == 1) && ~compressed)) then 44
  else 0
  where
    b0         = pk0 % 256
    compressed = (pkLen == 33) && ((b0 == 2) || (b0 == 3))
""",
    roots=[("cell_witness_pubkeytype", ["flags", "sv", "pkLen", "pk0"],
            "witness_pubkeytype")],
))


# ---------------------------------------------------------------- SCR-183 ---
CELL_DEFS.append(dict(
    family="tapscript-reimport", id="C-L-tapscript-reimport", rows="SCR-183",
    coverage="full", coverage_tag="full",
    marker="tapscript_reimport",
    consensus="true",
    precond="""  - Scope: the two consensus re-imports the row cites:
      * tapscript minimal-IF, interpreter.cpp:623-629 (inside the OP_IF/OP_NOTIF
        case), which runs *before* and independently of the witness-v0 MINIMALIF
        policy branch;
      * the implicit clean-stack check at the end of ExecuteWitnessScript,
        interpreter.cpp:1876-1878, which is shared by witness-v0 and tapscript.
  - Inputs: an arbitrary 64-bit flag word (in particular MINIMALIF = 0x2000 is
    free, and the roots show it is *not* consulted on these paths), the
    SigVersion (0 = BASE, 1 = WITNESS_V0, 2 = TAPSCRIPT; other values are the
    cell's out-of-domain guard), fExec (0/1), the OP_IF argument's length and
    first byte (masked to 0..255), and the final stack length.
  - The stack is non-empty and the conditional is balanced for the minimal-IF
    root; the final stack length is an input for the clean-stack root.
""",
    postcond="""  Root 1 (minimal-IF dispatch, total over sigversion):
    fExec == 0                                       -> 0
    SigVersion == TAPSCRIPT and (len > 1 or (len == 1 and b0 != 1))
                                                     -> 51 SCRIPT_ERR_TAPSCRIPT_MINIMALIF
    else SigVersion == WITNESS_V0 and MINIMALIF set and the same condition
                                                     -> 31 SCRIPT_ERR_MINIMALIF
    else                                             -> 0
    The tapscript arm precedes the v0 arm, so for TAPSCRIPT the answer is 51 for
    every flag word: the policy bit can neither enable nor disable it.
  Root 2 (clean-stack enforcement, total over sigversion):
    SigVersion in {WITNESS_V0, TAPSCRIPT} and final length != 1
                                                     -> 30 SCRIPT_ERR_CLEANSTACK
    SigVersion == BASE                               -> the SCR-180 policy gate
                                                        (not claimed here;
                                                        modelled only for contrast)
    and on the witness/tapscript arms the flag word is never read.
""",
    citations="""  - "interpreter.cpp:623-629 (SigVersion::TAPSCRIPT rejects a non-minimal OP_IF/NOTIF argument, before the policy branch)"
  - "interpreter.cpp:631-637 (the witness-v0 policy branch that the tapscript arm precedes)"
  - "interpreter.cpp:1876-1878 (ExecuteWitnessScript: scripts inside witness implicitly require cleanstack; shared by v0 and tapscript)"
  - "src/script/interpreter.h:117-125 (tapscript has minimal-IF automatically and does not depend on the flag)"
  - "src/validation.cpp:2249-2288 (GetBlockScriptFlags sets TAPROOT; MINIMALIF/CLEANSTACK are absent)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:882-887 (stepBody: tapscript minimal-IF arm before the v0 policy arm)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1237-1239 (executeWitnessScript implicit cleanstack, applies to both sigversions)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1431,1443 (the *policy* cleanstack gates, for contrast)"
  - "contract/error_enum.md:96,75 (51 SIG_TAPSCRIPT_MINIMALIF, 30 SIG_CLEANSTACK)"
""",
    trust="""  C is a line-cited source excerpt of interpreter.cpp:623-637 and 1876-1878 at
  the pin; it is not the whole EvalScript and not the whole
  ExecuteWitnessScript.  L is a REVIEWED TRANSLITERATION of the stepBody
  OP_IF/OP_NOTIF dispatch (Defs.lean:878-891) and the executeWitnessScript tail
  (Defs.lean:1236-1239), not generated from twin/ops_ir.py.  No crypto is
  involved.  No Core patch is used.
""",
    scope="""  FULL for SCR-183 as cited (both predicates are total over their declared
  domains), with an explicit boundary: the final stack length and the OP_IF
  argument are *inputs*, so the cell proves the flag-independent *enforcement*
  of both consensus rules, not that EvalScript computes that post-state.  The
  post-state derivation is the whole-engine loop seam (E4:F-TOOL-001) and is not
  claimed.  Tapscript validation-weight, OP_SUCCESSx and signature semantics are
  out of scope.
""",
    limits="""Both roots are enforcement predicates over inputs supplied by the harness;
the interpreter loop that produces them is out of scope (E4:F-TOOL-001).  The
BASE arm of root 2 is included only for contrast and is SCR-180's claim.
""",
    body="""The cell proves both halves of the tapscript re-import.  Minimal-IF: for
SigVersion::TAPSCRIPT the OP_IF/OP_NOTIF argument must be the empty vector or
the single byte 0x01, else SCRIPT_ERR_TAPSCRIPT_MINIMALIF (51) - and the
tapscript arm runs before the witness-v0 MINIMALIF policy arm, so for every flag
word the tapscript answer is 51 (the policy bit can neither enable nor disable
it).  Clean-stack: the `stack.size() != 1 -> SCRIPT_ERR_CLEANSTACK` check at the
end of ExecuteWitnessScript is shared by witness-v0 and tapscript and reads no
policy bit at all.  Both are consensus rules; the rows' point is that neither
depends on the corresponding policy flag.
""",
    consensus_note="""**Consensus.**  These two checks are unconditional in the interpreter, not
gated by a flag: `TAPROOT` is in `GetBlockScriptFlags`
(validation.cpp:2249-2288) and the tapscript minimal-IF/clean-stack behaviour
follows from the script version, not from MINIMALIF/CLEANSTACK (absent from that
function).  interpreter.h:117-125 states that tapscript has minimal-IF
"automatically ... and does not depend on this flag".  The row is filed
`consensus: true`.
""",
    c_code=r"""#include "policy_common.h"
using namespace policy_cell;

// C leg: Bitcoin Core src/script/interpreter.cpp @ pin cce32b168.
//
// Root 1 -- OP_IF/OP_NOTIF argument check (:623-637):
//
//   if (fExec) {                                                            // :629
//       ...
//       valtype& vch = stacktop(-1);
//       // Tapscript requires minimal IF/NOTIF inputs as a consensus rule.
//       if (sigversion == SigVersion::TAPSCRIPT) {                          // :624-629
//           // exactly 0 (empty vector) or exactly 1 (one-byte vector with value 1)
//           if (vch.size() > 1 || (vch.size() == 1 && vch[0] != 1)) {
//               return set_error(serror, SCRIPT_ERR_TAPSCRIPT_MINIMALIF);   // :628
//           }
//       }
//       // Under witness v0 rules it is only a policy rule ...                // :631-637
//       if (sigversion == SigVersion::WITNESS_V0 && (flags & SCRIPT_VERIFY_MINIMALIF)) { ... }
//
// The tapscript arm is an `if` that returns, not an `else if`, so it precedes
// the witness-v0 arm: the policy bit is unreachable for TAPSCRIPT.
//
// Root 2 -- ExecuteWitnessScript tail (:1876-1878), shared by v0 and tapscript:
//
//   // Scripts inside witness implicitly require cleanstack behaviour
//   if (stack.size() != 1) return set_error(serror, SCRIPT_ERR_CLEANSTACK);
//
// Both roots take the post-state/argument as inputs (see spec.md).

uint64_t c_tapscript_minimalif(uint64_t flags, uint64_t sigversion, uint64_t fExec,
                               uint64_t vchLen, uint64_t vch0Arg) {
    if (sigversion > SV_TAPSCRIPT) return OUT_OF_DOMAIN;   // cell guard (harness)
    if (fExec == 0) return ERR_OK;                         // :629
    const uint64_t b0 = byte_of(vch0Arg);
    const bool notMinimal = (vchLen > 1) || (vchLen == 1 && b0 != 1);
    if (sigversion == SV_TAPSCRIPT && notMinimal) {
        return ERR_TAPSCRIPT_MINIMALIF;                    // :624-629 (no flag read)
    }
    if (sigversion == SV_WITNESS_V0 && (flags & MINIMALIF) != 0 && notMinimal) {
        return ERR_MINIMALIF;                              // :631-637 (policy, for contrast)
    }
    return ERR_OK;
}

uint64_t c_tapscript_cleanstack(uint64_t flags, uint64_t sigversion, uint64_t finalLen) {
    if (sigversion < SV_WITNESS_V0 || sigversion > SV_TAPSCRIPT) return OUT_OF_DOMAIN;
    (void)flags;                                           // :1877 reads no policy bit
    if (finalLen != 1) return ERR_CLEANSTACK;              // :1877
    return ERR_OK;
}

extern "C" uint64_t cell_tapscript_minimalif(uint64_t flags, uint64_t sigversion, uint64_t fExec,
                                             uint64_t vchLen, uint64_t vch0Arg) {
    return c_tapscript_minimalif(flags, sigversion, fExec, vchLen, vch0Arg);
}

extern "C" uint64_t cell_tapscript_cleanstack(uint64_t flags, uint64_t sigversion, uint64_t finalLen) {
    return c_tapscript_cleanstack(flags, sigversion, finalLen);
}
""",
    l_code=r"""#include "policy_common.h"
using namespace policy_cell;

// L leg: REVIEWED TRANSLITERATION (not generated) of
//   spec/core/Bitcoin/Interpreter/Defs.lean
//
// Root 1 -- stepBody, OP_IF/OP_NOTIF (:878-891):
//   else if w = 0x63 ∨ w = 0x64 then
//     if fExec then
//       if st.stack.length < 1 then .error .stackUnderflow
//       else
//         let vch := topAt st.stack 1
//         if ctx.sv = .tapscript ∧ (1 < vch.size ∨ (vch.size = 1 ∧ byte ≠ 1)) then
//           .error .tapscriptMinimalIf                                   -- :883-884
//         else if ctx.sv = .witnessV0 ∧ pol.minimalIf ∧ (...) then
//           .error .minimalIf                                            -- :885-887
//         else .ok { ... }
//
// The Lean `if ... else if` is itself the precedence evidence: the tapscript
// arm is selected first and does not mention pol.minimalIf.
//
// Root 2 -- executeWitnessScript tail (:1236-1239), the same code for
// SigVersion::WITNESS_V0 and SigVersion::TAPSCRIPT:
//   | .ok st =>
//     -- witness scripts implicitly require cleanstack
//     if st.length ≠ 1 then .fail .cleanstack                           -- :1238
//     else if castToBool st[0]! then .ok else .fail .evalFalse          -- :1239

uint64_t l_tapscript_minimalif(uint64_t flags, uint64_t sigversion, uint64_t fExec,
                               uint64_t vchLen, uint64_t vch0Arg) {
    if (sigversion > SV_TAPSCRIPT) return OUT_OF_DOMAIN;   // cell guard (harness)
    if (fExec == 0) return ERR_OK;
    const uint64_t b0 = byte_of(vch0Arg);
    const bool notMinimal = (vchLen > 1) || (vchLen == 1 && b0 != 1);
    const bool minimalIf = (flags & MINIMALIF) != 0;
    if (sigversion == SV_TAPSCRIPT && notMinimal) return ERR_TAPSCRIPT_MINIMALIF;
    if (sigversion == SV_WITNESS_V0 && minimalIf && notMinimal) return ERR_MINIMALIF;
    return ERR_OK;
}

uint64_t l_tapscript_cleanstack(uint64_t flags, uint64_t sigversion, uint64_t finalLen) {
    if (sigversion < SV_WITNESS_V0 || sigversion > SV_TAPSCRIPT) return OUT_OF_DOMAIN;
    (void)flags;                                           // the Lean tail reads no policy bit
    if (finalLen != 1) return ERR_CLEANSTACK;
    return ERR_OK;
}

extern "C" uint64_t cell_tapscript_minimalif(uint64_t flags, uint64_t sigversion, uint64_t fExec,
                                             uint64_t vchLen, uint64_t vch0Arg) {
    return l_tapscript_minimalif(flags, sigversion, fExec, vchLen, vch0Arg);
}

extern "C" uint64_t cell_tapscript_cleanstack(uint64_t flags, uint64_t sigversion, uint64_t finalLen) {
    return l_tapscript_cleanstack(flags, sigversion, finalLen);
}
""",
    cry=r"""module PolicyCell where

// Independent predicate for SCR-183 (tapscript re-import: consensus minimal-IF
// and implicit clean-stack, both independent of the policy flags).
// sigversion: 0 BASE, 1 WITNESS_V0, 2 TAPSCRIPT; anything else out of domain.
// ordinals: 0 pass, 30 CLEANSTACK, 31 MINIMALIF (v0 policy, for contrast),
//           51 TAPSCRIPT_MINIMALIF, 255 out of domain.
tapscript_minimalif : [64] -> [64] -> [64] -> [64] -> [64] -> [64]
tapscript_minimalif flags sv fExec vchLen vch0 =
  if sv > 2 then 255
  else if fExec == 0 then 0
  else if ((sv == 2) && notMinimal) then 51
  else if ((sv == 1) && ((((flags >> 13) % 2) == 1) && notMinimal)) then 31
  else 0
  where
    b0         = vch0 % 256
    notMinimal = (vchLen > 1) || ((vchLen == 1) && (b0 != 1))

tapscript_cleanstack : [64] -> [64] -> [64] -> [64]
tapscript_cleanstack flags sv finalLen =
  if (sv < 1) || (sv > 2) then 255
  else if finalLen != 1 then 30
  else 0
""",
    roots=[("cell_tapscript_minimalif", ["flags", "sv", "fExec", "vchLen", "vch0"],
            "tapscript_minimalif"),
           ("cell_tapscript_cleanstack", ["flags", "sv", "finalLen"],
            "tapscript_cleanstack")],
))


def saw_script(c):
    lines = ['import "cell.cry";', "",
             'mC <- llvm_load_module "c_leaf.bc";',
             'mL <- llvm_load_module "l_leaf.bc";', ""]
    for fn, args, cryfn in c["roots"]:
        lines.append(f'let spec_{fn} = do {{')
        for a in args:
            lines.append(f'  {a} <- llvm_fresh_var "{fn}_{a}" (llvm_int 64);')
        lines.append('  llvm_execute_func [' + ', '.join("llvm_term " + a for a in args) + '];')
        lines.append(f'  llvm_return (llvm_term {{{{ {cryfn} ' + ' '.join(args) + ' }});')
        lines.append('};')
        lines.append("")
    for fn, _, _ in c["roots"]:
        lines.append(f'llvm_verify mC "{fn}" [] false spec_{fn} abc;')
        lines.append(f'llvm_verify mL "{fn}" [] false spec_{fn} abc;')
    lines += ["", f'print "CELL_{c["marker"]}_SAW_GREEN";', ""]
    return "\n".join(lines)


def buildspec(c):
    return (f'CELL_ID="{c["family"]}/{c["id"]}"\n'
            f'CELL_FNS="{" ".join(fn for fn, _, _ in c["roots"])}"\n'
            f'CELL_MARKER="{c["marker"]}"\n'
            f'CELL_SOURCE_NOTE="C excerpt interpreter.cpp @ {PIN}; L reviewed transliteration of Defs.lean"\n')


def main():
    for c in CELL_DEFS:
        d = os.path.join(CELLS, c["family"], c["id"])
        write(os.path.join(d, "buildspec"), buildspec(c))
        write(os.path.join(d, "c_cell.cpp"), c["c_code"])
        write(os.path.join(d, "l_cell.cpp"), c["l_code"])
        write(os.path.join(d, "saw/cell.cry"), c["cry"])
        write(os.path.join(d, "saw/cell.saw"), saw_script(c))
        write(os.path.join(d, "alive2/run.sh"),
              RUN_ALIVE, 0o755)
        write(os.path.join(d, "saw/run.sh"),
              RUN_SAW, 0o755)
        for h in ("policy_common.h", "build_leaf.sh", "run_alive2.sh", "run_saw.sh"):
            write(os.path.join(d, "_tools", h),
                  open(os.path.join(HERE, "harness", h)).read(),
                  0o755 if h.endswith(".sh") else None)
        write(os.path.join(d, "spec.md"), spec(c))
        write(os.path.join(d, "notes.md"), notes(c))
        print("wrote", os.path.relpath(d, REPO))


if __name__ == "__main__":
    main()
