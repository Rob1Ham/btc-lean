# BIP-42, formally

BIP-42 is a 2014 April-Fools proposal by Pieter Wuille: it pretends that
Bitcoin's supply grows forever and proposes a soft fork on **1 April 2214**
that sets the block subsidy to zero, capping the supply at "42 halfmillion"
BTC.  The joke is that consensus already caps the supply.

`spec/proofs/BitcoinProofs/Bip/B42/Bip42.lean` is the wink.  It proves,
against the real `Bitcoin.Conservation.blockSubsidy` and the real
`totalIssuance` theorem, that:

* `bip42_subsidy_zero_after_epoch33` — from height
  `33 * 210000 = 6_930_000` onward the subsidy is zero (epoch 33 exhausts the
  `50·COIN` mantissa);
* `bip42_supply_finite` — total issuance is at most
  `42 * 500_000 * 100_000_000` sats = 21,000,000 BTC;
* `bip42_supply_exact` — the exact total is 20,999,999.9769 BTC;
* `bip42_2214_is_noop` — applying BIP-42's "zero from activation" rule at a
  height representative of 2214 is extensionally equal to the consensus
  subsidy.  The satirical soft fork changes nothing.

Core's `halvings >= 64` guard (the code comment's "BIP42 guard") is also
proved: `bip42_subsidy_zero_of_guard`.  It fires later (13,440,000 blocks),
but it closes the shift-count corner; the supply is already finite at epoch
33.

This is intentionally **not** a separate census row.  The satirical 2214
activation is not a mainnet rule; the real schedule and the `halvings >= 64`
guard are already covered by `INV-033` (`bip_cve: BIP42`, `consensus: true`).
The module is a commemorative theorem about the rule that makes the joke land.
It is imported by `BitcoinProofs.lean`, so the default proof build checks it.
