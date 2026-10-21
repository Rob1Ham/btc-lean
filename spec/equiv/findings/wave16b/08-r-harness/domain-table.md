# Domain table — contract vs adapter (R) vs Core oracle

Source of the contract column: `spec/equiv/contract/tape.md` §1–§7.
“Adapter” is `adapter/entry_r3.rs` as built here (sha in `README.md`).
“Observed” is from `logs/behavior.log`; `2` is `BAD_INPUT`.

## 1. Input-level domain

| Dimension | Contract | Adapter (R) | Observed C vs R |
|---|---|---|---|
| `tx_bytes` NULL / `tx_len == 0` | reject `2` | reject `2` | agree (`E0 empty tx`) |
| trailing bytes | reject `2` | full-buffer `deserialize` → `2` | agree |
| `spk_len != 0 && spk == NULL` | reject `2` | reject `2` | same rule |
| `0 <= amount <= MAX_MONEY` | enforce `2` | enforce `2` | agree (`amount > MAX_MONEY`, `amount negative`) |
| `flags & ~0x1fffff` | reject `2` | reject `2` | agree (`flags unknown high bit`) |
| `WITNESS ⇒ P2SH` | reject `2` | reject `2` | agree |
| `CLEANSTACK ⇒ P2SH ∧ WITNESS` | reject `2` | reject `2` | agree |
| `input_index >= vin.size()` | reject `2` | reject `2` | agree |
| `input_index == 0`, single input | supported | supported | agree on all 69 core cases |
| `input_index == 0`, multi-input, BASE | supported | synthetic OP_TRUE prevouts on other inputs; discard `vin != 0` failure | agree (`multi input0 pass`, `multi input0 fail`) |
| `input_index == 0`, multi-input, WITNESS_V0 | supported | same emulation; BIP143 is exact for input 0 | agree (`multi input0 p2wsh pass, input1 invalid`) |
| `input_index == 0`, multi-input, native witness v1+ | in-domain by tape.md §6, but signatures use synthetic other outputs | **`2`** | R-inadmissible (B3) |
| `input_index == 0`, multi-input, P2SH-wrapped v1 | in-domain; **not** BIP341 (Core excludes `is_p2sh` v1) | supported; engine takes the unknown-program ACS path | agree (`multi input0 p2sh-v1 ACS`) |
| `input_index > 0` | in-domain if `< vin.size()` | **`2`** | R-inadmissible (B2) |
| single-input taproot key path | supported; exact per tape.md §6 | supported | agree (`p2tr empty key sig` = 45; empty witness encoding = 2 at both decoders) |
| `spk` length > 10,000 | in-domain; Core reports `SCRIPT_SIZE (5)` | no pre-cap; engine reports 5 | agree (`spk > 10000 bytes`) |
| `spk` arbitrary bytes | in-domain | forwarded | agree on corpus |
| `vin.size() == 0` | any index out of range → `2` | `2` | same rule |

### Multi-input emulation: why it is exact for input 0

The public R entry verifies all inputs in order and returns at the first
failure. The adapter sets non-target prevouts to `(0, OP_TRUE)` and discards a
failure annotated `vin != 0`. For a target at index 0:

- BASE legacy sighash commits to the tx (including other inputs’ scriptSigs)
  and the current input’s scriptCode; it does not consult other prevouts.
- WITNESS_V0/BIP143 commits to `hashPrevouts`, `hashSequence`, `hashOutputs`
  and the current input’s amount/scriptCode; other inputs’ *amounts/scripts*
  are not hashed.
- A later-input failure can only occur after input 0 has passed, so discarding
  it cannot change input 0’s verdict. A later-input **panic** would surface as
  `3`; no such case is in the corpus.

This is not the contract’s `(0, empty)` convention for other prevouts. It is an
emulation that only exists to let the all-inputs engine reach input 0; it is
invisible to input 0’s verdict for BASE/WITNESS_V0. For native witness v1+ it
is *not* invisible (BIP341 hashes all spent outputs), hence the `2`.

P2SH-wrapped v1 is deliberately *not* rejected: Core’s `VerifyWitnessProgram`
guards the taproot branch with `&& !is_p2sh`, so a P2SH-wrapped v1 program is
an “other version/size/p2sh combination” and returns success for future
softfork compatibility. It never enters BIP341, never hashes the synthetic
prevouts, and the adapter matches Core (`multi input0 p2sh-v1 ACS`).

## 2. Flag-word domain

Core bits from `tape.md` §5. `ScriptVerifyFlags` is rbitcoin’s full public
flag struct; it has 16 fields.

| Bit | Hex | Core name | R representation | Adapter behavior | R-admissible? |
|---:|---:|---|---|---|---|
| 0 | `0x000001` | P2SH | `bip16_active` | forward | yes |
| 1 | `0x000002` | STRICTENC | `strictenc` | forward | yes |
| 2 | `0x000004` | DERSIG | `bip66_active` | forward | yes |
| 3 | `0x000008` | LOW_S | `low_s` | forward | yes |
| 4 | `0x000010` | NULLDUMMY | `null_dummy` | forward | yes |
| 5 | `0x000020` | SIGPUSHONLY | — | **`2`** | **no (B1)** |
| 6 | `0x000040` | MINIMALDATA | `minimal_data` | forward | yes |
| 7 | `0x000080` | DISCOURAGE_UPGRADABLE_NOPS | — | **`2`** | **no (B1)** |
| 8 | `0x000100` | CLEANSTACK | `cleanstack` | forward | yes |
| 9 | `0x000200` | CHECKLOCKTIMEVERIFY | `bip65_active` | forward | yes |
| 10 | `0x000400` | CHECKSEQUENCEVERIFY | `bip112_active` | forward | yes |
| 11 | `0x000800` | WITNESS | `witness_active` | forward | yes |
| 12 | `0x001000` | DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM | `discourage_upgradable_witness` | forward | yes |
| 13 | `0x002000` | MINIMALIF | `minimal_if` | forward | yes |
| 14 | `0x004000` | NULLFAIL | `nullfail` | forward | yes |
| 15 | `0x008000` | WITNESS_PUBKEYTYPE | `witness_pubkeytype` | forward | yes |
| 16 | `0x010000` | CONST_SCRIPTCODE | `const_scriptcode` | forward | yes |
| 17 | `0x020000` | TAPROOT | `taproot_active` | forward | yes (single input) |
| 18 | `0x040000` | DISCOURAGE_UPGRADABLE_TAPROOT_VERSION | — | **`2`** | **no (B1)** |
| 19 | `0x080000` | DISCOURAGE_OP_SUCCESS | — | **`2`** | **no (B1)** |
| 20 | `0x100000` | DISCOURAGE_UPGRADABLE_PUBKEYTYPE | — | **`2`** | **no (B1)** |

Behavioral evidence for the five rejections: `flags bit 5`, `flags bit 7`,
`flags bit 18`, `flags bit 19`, `flags bit 20` in `logs/behavior.log` (all C
pass/verdict, R `(2,1)`). Bits 18–20 also matter only inside taproot execution;
the adapter rejects the whole word conservatively.

## 3. Error-kind domain

The contract returns Core `ScriptError` ordinals (`contract/error_enum.md`).
The adapter maps the engine’s string vocabulary; the census is the authority
for classification (`logs/census.log`).

| Group | Tokens | Adapter class | Result |
|---|---:|---|---|
| Exact mapped | 77 | mapped | `0` + Core ordinal |
| Opcode-prefix families | 3 | mapped-dynamic | `disabled → 17`, `unknown → 16`, `0x6a → 3` |
| Internal sentinels | 25 | internal | `3` |
| Test-only helper tokens | 2 | not reachable | — |
| Known ambiguity | 1 (`p2wpkh empty witness item`) | gap | `0` + `UNKNOWN (1)` |
| Unclassified | 0 | — | — |

Context-sensitive handling: `der sig` → 24 if DERSIG else 2. This is the only
token whose Core ordinal depends on the flag word.

### Rows excluded from C-R error equality

| Row | Reason |
|---|---|
| `p2wpkh empty witness item` (empty sig or empty pubkey in a v0/20 witness) | Core reaches `EVAL_FALSE (2)` or `EQUALVERIFY (12)` depending on the pubkey hash; one engine token (B4) |
| any token in the 25 internal class | returns `3`, not a script verdict |
| `p2sh non-push + hash mismatch` | genuine engine precedence divergence, C `(0,2)` vs R `(0,26)` (B5) |
| `malleated + false program` | genuine engine precedence divergence, C `(0,2)` vs R `(0,41)` (B5) |

## 4. Row admissibility

| Row shape | C-R behavior | L-R proof | Marking |
|---|---|---|---|
| single input, `input_index=0`, flags ⊆ supported 16 bits, outcome in mapped tokens, not B4/B5 | admissible (advisory evidence) | **blocked** | no green; behavioral note only |
| uses flag bits 5/7/18/19/20 | R-inadmissible (B1) | blocked | gap |
| `input_index > 0` | R-inadmissible (B2) | blocked | gap |
| multi-input native witness v1+ target | R-inadmissible (B3) | blocked | gap (also tape §6) |
| error equality depends on `p2wpkh empty witness item` | R-inadmissible (B4) | blocked | gap |
| hits B5 precedence case | **diverges** | blocked | red finding, not a gap |
| any row claiming refinement/equivalence | no | **blocked (F-TOOL-001)** | never green under the pin |

The `core` category in the differential is the maximal behavioral set that is
both in-domain and free of B1–B5; it is a test corpus, not a proof scope.
