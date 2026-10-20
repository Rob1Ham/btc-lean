# witness-v0/C-L-bip143-hashoutputs-single-oor

SCR-141: in the BIP143 segwit v0 sighash, SIGHASH_SINGLE with an out-of-range
input index leaves `hashOutputs` at the default zero uint256, not the legacy
`uint256::ONE` value (interpreter.cpp:1647-1653).

## Design

`cell_bip143_hashoutputs_mode(hash_type, n_in, vout_len)` returns a mode for
the value written into the preimage's `hashOutputs` slot:

| mode | meaning |
|---:|---|
| 0 | default zero uint256 (the SCR-141 value) |
| 1 | `uint256::ONE` (legacy SIGHASH_SINGLE overflow; must be unreachable) |
| 2 | SHA256d over all outputs |
| 3 | SHA256d over the single output at nIn |

with `b = hash_type mod 32`: SINGLE (b=3) in range -> 3, else 0; NONE (b=2) ->
0; everything else -> 2.  Carrying mode 1 in the observable makes the negative
claim explicit and mirrors Lean's distinction between `zeroHashL` and
`singleOverflowOneB`.

The C leg is a line-cited excerpt of the WITNESS_V0 arm; the L leg is a
reviewed transliteration of `hashOutputsL`
(`spec/core/Bitcoin/SigHash/Digest.lean:274-285`), using a switch-shaped order.
The two SHA256d computations are opaque.

## Exact commands

```sh
bash spec/equiv/cells/witness-v0/C-L-bip143-hashoutputs-single-oor/alive2/run.sh
bash spec/equiv/cells/witness-v0/C-L-bip143-hashoutputs-single-oor/saw/run.sh
sha256sum -c spec/equiv/cells/witness-v0/C-L-bip143-hashoutputs-single-oor/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/witness-v0/C-L-bip143-hashoutputs-single-oor/saw/certificate.sha256
```

## Versions

Alive2 v20.0 (`/opt/equiv-tools/alive-tv-v20.0`, LLVM 20.1.2), SAW 1.6
(68eed5f, solver abc), clang 20.1.2.

## Result

- Alive2: `Transformation seems to be correct!` (semantic; C if-chain vs L
  switch), `STATUS=alive2-green`.
- SAW: two `Proof succeeded!` (C and L), `STATUS=saw-green`.

## Limits / blockers

- The hash outputs and the tx output serializer are opaque; only the selection
  is proved.  Same-hash premise, `spec/equiv/README.md` §7.
- `vout_len` is a count, not a decoded output vector; the tape/tx decoder is
  not in the cell.
- ANYONECANPAY, hashPrevouts and hashSequence are other rows.
