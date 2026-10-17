import Bitcoin.Wallet.Spend.Funding
import Bitcoin.Wallet.Spend.Fee
import Bitcoin.Wallet.Spend.Selection
import Bitcoin.Wallet.Spend.Laws

/-!
# Wallet spend model

An arithmetic model of wallet spend construction: fee and dust
arithmetic (`Fee.lean`), change-to-source and subtract-fee-from-output
funding (`Funding.lean`), two deterministic branch-and-bound-free
selection strategies (`Selection.lean`), and the proven conservation and
non-negativity laws plus worked Core-derived examples (`Laws.lean`).

The consensus transaction checker remains the authority on whether the
constructed transaction is valid.  This model only guarantees the
arithmetic Core's wallet uses while constructing it; it does not model
signing, size estimation, descriptor expansion, or Core's BnB/SRD/
CoinGrinder/knapsack selection policies.
-/
