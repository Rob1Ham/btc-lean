# Tape format and harness domain (normative)

Status: E0 contract. Companion to `ABI.md`; `ABI.md` wins if the two disagree.
Everything here is pinned to Bitcoin Core v32.99 @
`cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`. Any change is a new contract
version and invalidates existing cell records.

## 1. Entry signature (identical in all three shims)

ABI version 2 (`EQUIV_ABI_VERSION` in `error_kind.h`).

```c
/* Normative, proof-bearing symbol. `error_kind` MUST be non-NULL. */
extern "C" int equiv_entry(
    const uint8_t *tx_bytes, uint64_t tx_len,
    const uint8_t *spk,      uint64_t spk_len,
    int64_t amount, uint32_t input_index, uint64_t flags,
    equiv_error_kind *error_kind);

/* Non-normative convenience wrapper; discards the kind. */
extern "C" int entry(
    const uint8_t *tx_bytes, uint64_t tx_len,
    const uint8_t *spk,      uint64_t spk_len,
    int64_t amount, uint32_t input_index, uint64_t flags);
```

Return codes: `0` fail, `1` pass, `2` bad input, `3` internal/exception.
`error_kind` is always written by `equiv_entry` and is one of
`equiv_error_kind` (`contract/error_kind.h`):

| Result | `error_kind` |
|---:|---|
| 1 pass | `EQUIV_ERR_OK` |
| 0 fail | the Core `ScriptError` ordinal (values mirror Core 1:1) |
| 2 bad input | `EQUIV_ERR_UNKNOWN_ERROR` |
| 3 internal | `EQUIV_ERR_UNKNOWN_ERROR` |

Callers own both buffers. A shim never retains a pointer after return.

## 2. `tx_bytes` — Core `TX_WITH_WITNESS` serialization

`tx_bytes` is exactly what `SerializeTransaction(tx, s, TX_WITH_WITNESS)`
writes (`src/primitives/transaction.h`), little-endian throughout:

```
int32   version
[optional extended form only when the tx has a witness:]
  uint8  0x00                     (empty vin dummy)
  uint8  flags                    (bit 0 = witness present; other bits illegal)
CompactSize  vin count
  per input:
    uint8[32] prevout txid
    uint32    prevout vout
    CompactSize scriptSig length + bytes
    uint32    nSequence
CompactSize  vout count
  per output:
    int64     value (sats)
    CompactSize scriptPubKey length + bytes
[if extended, one witness per input:]
  CompactSize stack item count
    per item: CompactSize item length + bytes
uint32   nLockTime
```

Rules:

* Decoding MUST consume the whole buffer. A successfully decoded transaction
  with trailing bytes is **bad input (2)**, not a pass/fail. This is stricter
  than rbitcoin's reference oracle, which ignores trailing bytes.
* Any deserialization failure — EOF, non-canonical `CompactSize`, illegal
  witness flag, superfluous witness record, unknown optional flag — is **2**.
* `vin.size() == 0` cannot be verified: any `input_index` is out of range, so
  the result is **2**.
* No `CheckTransaction` policy/consensus checks are applied. Value ranges of
  outputs, duplicate inputs, empty `vout`, unknown `nVersion`, and `nLockTime`
  are passed through exactly as encoded. They are part of the tape.
* There is no separate witness channel. The witness used for `input_index` is
  `tx.vin[input_index].scriptWitness` decoded from `tx_bytes`. An absent
  extended form means every input's witness is empty.

## 3. `spk` — scriptPubKey

Raw bytes, no length prefix and no `CompactSize`. Any length is allowed,
including zero (an empty scriptPubKey evaluates to `EVAL_FALSE`). There is no
"malformed spk" at the byte level: malformedness is an opcode/execution
outcome, not a decode error. `spk_len > 0` with `spk == NULL` is **2**.
Resource limits (e.g. corpus sanity caps) belong to the harness, not the
contract; they must be recorded as cell preconditions if they exclude inputs.

## 4. `amount`

Spent output value in satoshis, `int64`. Contract domain:
`0 <= amount <= MAX_MONEY` (`21'000'000 * 100'000'000 = 2'100'000'000'000'000`).
Outside that range is **2**. This is a contract restriction: the reference
oracle passes any `int64` to Core. It is fixed here so all three legs share a
representable, Bitcoin-meaningful domain.

## 5. `flags` — Core script-verify bits

`flags` is an unsigned 64-bit mask. Only bits 0..20 are defined at the pin
(`MAX_SCRIPT_VERIFY_FLAGS = 0x1fffff`); any higher bit is **2**.
Core's `VerifyScript` also asserts two implications; to keep the ABI total
instead of aborting a debug build, violations are **2**:

* `WITNESS` ⇒ `P2SH`
* `CLEANSTACK` ⇒ `P2SH` and `WITNESS`

| Bit | Hex | Name |
|---:|---:|---|
| 0 | 0x000001 | `SCRIPT_VERIFY_P2SH` |
| 1 | 0x000002 | `SCRIPT_VERIFY_STRICTENC` |
| 2 | 0x000004 | `SCRIPT_VERIFY_DERSIG` |
| 3 | 0x000008 | `SCRIPT_VERIFY_LOW_S` |
| 4 | 0x000010 | `SCRIPT_VERIFY_NULLDUMMY` |
| 5 | 0x000020 | `SCRIPT_VERIFY_SIGPUSHONLY` |
| 6 | 0x000040 | `SCRIPT_VERIFY_MINIMALDATA` |
| 7 | 0x000080 | `SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_NOPS` |
| 8 | 0x000100 | `SCRIPT_VERIFY_CLEANSTACK` |
| 9 | 0x000200 | `SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY` |
| 10 | 0x000400 | `SCRIPT_VERIFY_CHECKSEQUENCEVERIFY` |
| 11 | 0x000800 | `SCRIPT_VERIFY_WITNESS` |
| 12 | 0x001000 | `SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM` |
| 13 | 0x002000 | `SCRIPT_VERIFY_MINIMALIF` |
| 14 | 0x004000 | `SCRIPT_VERIFY_NULLFAIL` |
| 15 | 0x008000 | `SCRIPT_VERIFY_WITNESS_PUBKEYTYPE` |
| 16 | 0x010000 | `SCRIPT_VERIFY_CONST_SCRIPTCODE` |
| 17 | 0x020000 | `SCRIPT_VERIFY_TAPROOT` |
| 18 | 0x040000 | `SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION` |
| 19 | 0x080000 | `SCRIPT_VERIFY_DISCOURAGE_OP_SUCCESS` |
| 20 | 0x100000 | `SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_PUBKEYTYPE` |

The table was checked by compiling `script_verify_flag_name` at the pin
(`MAX_SCRIPT_VERIFY_FLAGS_BITS == 21`, mask `0x1fffff`). Flags are passed
verbatim; no shim adds or removes a flag.

## 6. Spent-output (prevout) convention — TAPROOT caveat

`PrecomputedTransactionData::Init` requires one `CTxOut` per input. The tape
supplies only `input_index`'s `(amount, spk)`, so the contract defines:

```
spent_outputs[i] = (amount, spk)   if i == input_index
                   (0, empty)      otherwise
```

Consequences, all deliberate:

* `SigVersion::BASE` and `WITNESS_V0`: other inputs' spent outputs are not
  hashed by BIP143. The convention is invisible.
* `TAPROOT`/`TAPSCRIPT`: BIP341 hashes **all** spent amounts and scriptPubKeys.
  With a multi-input tx, signatures are therefore checked against synthetic
  values for the other inputs. This is a **harness tape**, not consensus
  behavior. Corpus generators must compute signatures under the same
  convention. Cells that need genuine multi-input taproot sighash semantics
  are out of contract and must be filed as a gap (E4/E5), not silently
  claimed.
* Single-input taproot txs are exact: the only spent output is the tape's.

The rbitcoin reference oracle instead passes a one-element vector. That is
correct only for one-input transactions (a debug Core asserts
`spent_outputs.size() == vin.size()`); our convention generalizes it
deterministically.

## 7. Domain summary

An input is **in domain** iff:

1. `tx_len > 0` and `tx_bytes != NULL`; `spk_len == 0 || spk != NULL`;
2. `tx_bytes` decodes as `TX_WITH_WITNESS` with no trailing bytes;
3. `input_index < tx.vin.size()`;
4. `0 <= amount <= MAX_MONEY`;
5. `flags & ~0x1fffff == 0`;
6. `flags` satisfies the `WITNESS`/`CLEANSTACK` implications above.

Out-of-domain input yields **2**. A shim MUST NOT abort, throw, or return
pass/fail for out-of-domain input. Inside the domain the result is a pure
function of the tape (no time, environment, locale, allocator, or global
state).

## 8. Corpus encoding

Hex is lowercase, no `0x`, even length; empty bytes are `""`. The JSONL
record format is `corpus_schema.md`. Byte-exact equality of tapes is required
for deduplication; a re-serialization is not an acceptable substitute.

## 9. Difference from rbitcoin's `script-oracle/verify.cpp`

The reference (studied at `reardencode/rbitcoin`, `master`, 2026-10-19)
establishes the ABI pattern: `TX_WITH_WITNESS` decode, input-index check,
`CTransaction`, `PrecomputedTransactionData`, `TransactionSignatureChecker`
with `MissingDataBehavior::FAIL`, `VerifyScript`, `1/0/2/3`. Our shim differs
only in marshalling and domain policy:

| Aspect | rbitcoin oracle | this contract |
|---|---|---|
| symbol | `rbtc_core_verify` | `equiv_entry` (normative) + `entry` wrapper |
| decode exception | `3` (catch-all) | `2` |
| trailing bytes | ignored | `2` |
| amount range | unchecked | `0..MAX_MONEY`, else `2` |
| flags | passed through (debug asserts possible) | mask + implications, else `2` |
| spent outputs | one-element vector | one per input, synthetic (§6) |
| error detail | none | `error_kind` out-parameter (Core ordinal) |

These are contract choices, not claims about Core: Core itself is unmodified.

## 10. Contract hash

Cell records cite a contract hash. Compute it as the SHA-256 of the
concatenation, in this exact order, of the file bytes:

```sh
{ cat contract/ABI.md; cat contract/tape.md; \
  cat contract/error_kind.h; cat contract/corpus_schema.md; \
  cat contract/error_enum.md; } | sha256sum
```

`error_enum.md` is normative (ABI §8) and is included in the v3 recipe; a
contract edit that changes any of these five files must update the record.

Record the whole `sha256sum` line plus `git rev-parse HEAD` of this repo. A
contract edit without a new hash in the cell record is a gate failure.
