# L2-FUZZ2 — seeded grammar fuzz corpus (CLASS=fuzz2)

Grammar-based differential corpus: every case is **structurally valid and
then mutated at one semantic decision point** (not a raw-byte random
mutation — that case family belongs to L2-FUZZ). Seed space is fresh and
deterministic: `sha256("L2-FUZZ2:0xF2A5EED:<category>:<i>")`.

Oracle = the campaign law
(`no verdict -> UNJUDGED; got_ok != want_ok -> VERDICT-DIVERGE;
got_err != want_err -> KIND-DIVERGE; else AGREE`, canonical
`spec/scripts/l2/l2_harness.py`), with wants derived by an independent
Python oracle (`gen_fuzz2.py`), never from the Lean DUT.

## Files

| Path | Contents |
|---|---|
| `gen_fuzz2.py` | seeded generator + independent oracle + self-tests (`python3 gen_fuzz2.py`) |
| `cases/script.l2c` | 230 legacy/segwit/taproot spends (15-field L2ScrRunner form) |
| `cases/tx.f2c` | 178 stateless `checkTransaction` grammar cases |
| `cases/hdr.f2c` | 181 PoW (nBits) + merkle-root grammar cases |
| `Fuzz2Runner.lean` | Lean DUT: `lake env lean --run …` (no build wiring needed) |
| `results/fuzz2.l2r` | canonical rows `id|got_ok|got_err|want_ok|want_err|verdict` |

589 cases total; `want_ok=U` means the oracle declines (campaign law
counts it UNJUDGED, never AGREE).

## Case formats

`script.l2c` — identical to L2ScrRunner:

```
id|want_ok|want_err|value|policyFlags|p2sh|dersig|cltv|csv|nullDummy|
witness|taproot|ss_hex|spk_hex|wit_hex_items('-'=none,';'=stack,','=item)
```

`tx.f2c`:

```
id|want_ok|want_err|version|locktime|vin|vout|wit
vin  = '-' | hash_hex:n:ss_hex('-'=empty):sequence  (';'-separated)
vout = '-' | value:spk_hex('-'=empty)               (';'-separated)
```

`hdr.f2c` (tx indices point into the shared 6-tx bank; `[0]` is the
genesis coinbase, a serialization anchor):

```
id|kind(pow|merkle)|want_ok|want_err|version|prev_hex|merkle_hex|
time|bits|nonce|txidx(','-separated | '-')
```

## Oracle (independent of the DUT)

* **tx** — Core `CheckTransaction` (tx_check.cpp) transliteration; the 9
  Core reject strings (`bad-txns-*`, `bad-cb-length`) are asserted.
* **hdr/pow** — `arith_uint256::SetCompact` magnitude, nonzero /
  `≤ powLimit` gate, SHA256d header hashed as a little-endian integer
  (`BAD_TARGET` vs `HIGH_HASH`).
* **hdr/merkle** — `ComputeMerkleRoot` with odd-tail duplication; genesis
  coinbase → real genesis merkle root is a self-test.
* **script** — valid spends are signed with a pure-Python secp256k1 over
  the **Core script_tests credit/spend pair** (the same synthetic tx the
  Lean judge builds), legacy and BIP143; mutations assert the Core gate
  they violate. `gen_fuzz2.py` self-tests RIPEMD-160, genesis
  serialization, compact targets, ECDSA, legacy/BIP143 digests and the
  SIGHASH_SINGLE `uint256::ONE` digest.

## Reproduce

```bash
cd <checkout>/spec/vectors/l2/fuzz2
python3 gen_fuzz2.py
cd <checkout>/spec
lake env lean --run vectors/l2/fuzz2/Fuzz2Runner.lean \
  vectors/l2/fuzz2/cases/script.l2c vectors/l2/fuzz2/cases/tx.f2c \
  vectors/l2/fuzz2/cases/hdr.f2c vectors/l2/fuzz2/results/fuzz2.l2r
cd <checkout>
python3 spec/scripts/l2/l2_harness.py --class fuzz2
```

Expected: `589 cases, 584 AGREE, 0 DIVERGE, 5 UNJUDGED, 0 integrity`.

## Declined rows (UNJUDGED, known seams)

Five taproot rows are structurally valid but the Lean judge cannot reach
a verdict: BIP342 `sighashSchnorr` is the fail-closed X03/X04 stand-in
(`realSchnorrEntry`), and taproot **script-path** spending is the
documented `CheckTapTweak` seam (F-CORPUS-005). They are counted
UNJUDGED, not agreement.
