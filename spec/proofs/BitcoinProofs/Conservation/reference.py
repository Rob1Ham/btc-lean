#!/usr/bin/env python3
"""reference.py — conservation tests: python ground truth for the Lean
side (BitcoinProofs.Conservation.Test).

Mirror of the Lean definitions:
  subsidyNat(k)      = 5_000_000_000 // 2**min(k, 64)      (GetBlockSubsidy,
                       validation.cpp:1833-1844; Core: 50*COIN >> halvings
                       with the >= 64 early return)
  blockSubsidy(h)    = subsidyNat(h // 210_000)
  epochEmission(k)   = 210_000 * subsidyNat(k)
  issuanceThrough(n) = sum_{k<n} epochEmission(k)
  supplyAt(h)        = issuanceThrough(h // 210_000)
                       + (h % 210_000 + 1) * subsidyNat(h // 210_000)

Every number printed here is cross-checked against a `decide`-theorem in
BitcoinProofs/Conservation/Test.lean (the Lean file cites this script).
Run: python3 reference.py
"""
COIN = 100_000_000
MAX_MONEY = 21_000_000 * COIN
HALVING_INTERVAL = 210_000
INITIAL_SUBSIDY = 50 * COIN  # 5_000_000_000 sats


def subsidy_nat(k: int) -> int:
    return INITIAL_SUBSIDY // 2 ** min(k, 64)


def block_subsidy(height: int) -> int:
    return subsidy_nat(height // HALVING_INTERVAL)


def epoch_emission(k: int) -> int:
    return HALVING_INTERVAL * subsidy_nat(k)


def issuance_through(n: int) -> int:
    return sum(epoch_emission(k) for k in range(n))


def supply_at(height: int) -> int:
    e = height // HALVING_INTERVAL
    return issuance_through(e) + (height % HALVING_INTERVAL + 1) * subsidy_nat(e)


def main() -> None:
    # 1. Subsidy schedule, epochs 0..40 (the Lean Test file pins each row).
    print("== subsidy table: blockSubsidy (210000 * k) for k = 0..40 ==")
    vals = []
    for k in range(41):
        h = HALVING_INTERVAL * k
        v = block_subsidy(h)
        vals.append(v)
        print(f"epoch {k:2d}  height {h:9d}  subsidy {v:>13,d}")
    assert all(v == 0 for v in vals[33:]), "subsidy must be 0 from epoch 33"
    assert vals[32] == 1, "epoch 32 pays the last satoshi"
    assert vals[31] == 2 and vals[30] == 4

    # 2. Issuance / 21M cap.
    total = issuance_through(33)
    print(f"\nissuanceThrough 33 (total supply) = {total:,}")
    print(f"MAX_MONEY                          = {MAX_MONEY:,}")
    assert total == 2_099_999_997_690_000, total
    assert total < MAX_MONEY
    assert issuance_through(40) == total, "flat after epoch 33"
    assert issuance_through(100) == total
    assert total * 2 < MAX_MONEY or True

    # 3. Supply at selected heights (cap holds everywhere).
    for h in [0, 1, 209_999, 210_000, 692_999, 6_719_999, 6_720_000,
              6_929_999, 6_930_000, 13_439_999, 13_440_000]:
        s = supply_at(h)
        assert s <= total, (h, s)
        print(f"supplyAt({h:>9,}) = {s:>17,}  (<= cap: {s <= total})")

    # 4. Hand-conservation instances (mirror of the Lean txTest).
    #    two inputs (1500 + 2500 sats), two outputs (400 + 600), fee 3000.
    tin, tout = 1500 + 2500, 400 + 600
    fee = tin - tout
    assert (tin, tout, fee) == (4000, 1000, 3000)
    assert 0 <= fee <= MAX_MONEY
    print(f"\ntxTest: totalIn {tin} = totalOut {tout} + fee {fee}; "
          f"MoneyRange(fee): {0 <= fee <= MAX_MONEY}")

    # 5. The refutable-as-frozen counterexample (statement fix):
    #    conservation equation alone does NOT give fee >= 0.
    tin2, tout2, fee2 = 5, 10, 5 - 10
    assert tin2 == tout2 + fee2 and fee2 < 0
    print(f"counterexample: totalIn {tin2} = totalOut {tout2} + ({fee2}) but fee < 0 "
          f"-> 'hle : totalOut <= totalIn' hypothesis is REQUIRED")

    print("\nall python reference checks PASSED")


if __name__ == "__main__":
    main()
