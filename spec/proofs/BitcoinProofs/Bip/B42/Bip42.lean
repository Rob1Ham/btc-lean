import BitcoinProofs.Conservation.Thms

/-!
# BitcoinProofs.Bip.B42.Bip42 — BIP-42 enforcement, with the joke intact

BIP-42, "A finite monetary supply for Bitcoin" (Pieter Wuille, 2014-04-01),
is a satire.  It claims Bitcoin's supply grows without bound and proposes a
soft fork on **1 April 2214** that "permanently sets the subsidy to zero",
limiting the supply to "42 halfmillion" BTC.

The joke is that consensus already does exactly that, and does it earlier
than 2214.  `GetBlockSubsidy` is `50·COIN >> halvings`; because
`50·COIN < 2^33`, epoch 33 is the first epoch that pays nothing:

    height 33 * 210000 = 6_930_000  (~2140)  =>  subsidy = 0

Core additionally has the belt-and-braces guard

    if (halvings >= 64) return 0;

(validation.cpp:1833-1844 @ cce32b168), which fires at
`64 * 210000 = 13_440_000` (~2265).  The guard prevents a shift-count UB; it
is not what first makes the supply finite.  By BIP-42's alleged 2214
activation the real subsidy has already been zero for decades.

This module is the wink: it states and proves BIP-42's advertised *effect*
as a theorem about the real consensus schedule, and proves that enforcing
the satirical 2214 soft fork would change nothing.  It is deliberately
**not** a separate census row: the satirical 2214 activation is not a mainnet
rule, while the real schedule and `halvings >= 64` guard are already covered
by INV-033.  It is a commemorative theorem about the rule that makes the joke
land.

The "42 halfmillion" unit is 42 * 500_000 = 21_000_000 BTC.
-/

namespace BitcoinProofs.Bip.B42

open Bitcoin.Data Bitcoin.Conservation BitcoinProofs.Conservation

/-- The first height whose subsidy is zero: epoch 33, `33 * 210000`. -/
def bip42ZeroHeight : UInt32 := 6_930_000

/-- Core's `halvings >= 64` guard height: `64 * 210000`. -/
def bip42GuardHeight : UInt32 := 13_440_000

/-- A conservative height for BIP-42's satirical 1 April 2214 activation.
The BIP gives a date, not a height, and any height at or after
`bip42ZeroHeight` works for the no-op theorem. -/
def bip42ActivationHeight : UInt32 := 10_800_000

/-- "42 halfmillion" BTC, in satoshis. -/
def bip42SupplyCap : Nat := 42 * 500_000 * 100_000_000

/-- The BIP-42 / Core `halvings >= 64` guard. -/
def bip42Guard (height : UInt32) : Prop := 64 ≤ halvingsAt height

/-- **BIP-42 enforcement (epoch-33 form).**  From height 6,930,000 onward
the subsidy is exactly zero.  This is the real point at which the money
supply becomes finite — long before the satirical 2214 soft fork. -/
theorem bip42_subsidy_zero_after_epoch33 (height : UInt32)
    (h : bip42ZeroHeight ≤ height) : blockSubsidy height = 0 := by
  apply subsidy_epoch33_zero
  have h' : 6_930_000 ≤ height.toNat := h
  unfold halvingsAt
  omega

/-- The activation height is after the real zero point. -/
theorem bip42_activation_after_zero :
    bip42ZeroHeight ≤ bip42ActivationHeight := by
  decide

/-- **BIP-42 enforcement (guard form).**  Core's `halvings >= 64` guard also
forces the subsidy to zero.  It fires later than epoch 33, but it closes the
shift-count corner. -/
theorem bip42_subsidy_zero_of_guard (height : UInt32)
    (h : bip42Guard height) : blockSubsidy height = 0 :=
  blockSubsidy_zero_ge64 height h

/-- The guard fires at its defining height. -/
theorem bip42_guard_fires : bip42Guard bip42GuardHeight := by
  unfold bip42Guard
  decide

/-- The guard height is after the real zero point. -/
theorem bip42_guard_after_zero : bip42ZeroHeight ≤ bip42GuardHeight := by
  decide

/-- **The satirical soft fork is a no-op.**  Applying BIP-42's "set the
subsidy to zero from activation onward" rule at any height at or after the
real zero point produces exactly the consensus subsidy.  The 2214 soft fork
cannot change a single satoshi. -/
def bip42Subsidy (activation height : UInt32) : Amount :=
  if activation ≤ height then (0 : Amount) else blockSubsidy height

theorem bip42_activation_is_noop (activation height : UInt32)
    (ha : bip42ZeroHeight ≤ activation) (hh : activation ≤ height) :
    bip42Subsidy activation height = blockSubsidy height := by
  have hzero : blockSubsidy height = 0 := by
    apply bip42_subsidy_zero_after_epoch33
    exact Nat.le_trans ha hh
  simp [bip42Subsidy, hh, hzero]

/-- The concrete 2214-style activation is a no-op. -/
theorem bip42_2214_is_noop (height : UInt32)
    (hh : bip42ActivationHeight ≤ height) :
    bip42Subsidy bip42ActivationHeight height = blockSubsidy height :=
  bip42_activation_is_noop _ _ bip42_activation_after_zero hh

/-- **BIP-42's advertised cap.**  Total issuance over all heights is at
most 42 halfmillion BTC. -/
theorem bip42_supply_finite : totalIssuance ≤ bip42SupplyCap := by
  unfold bip42SupplyCap
  rw [totalIssuance_exact]
  decide

/-- The exact total, for the record: 2,099,999,997,690,000 sats
(20,999,999.9769 BTC). -/
theorem bip42_supply_exact : totalIssuance = 2_099_999_997_690_000 :=
  totalIssuance_exact

/-- The cap is approached but never reached: 2,310,000 sats short. -/
theorem bip42_supply_shortfall : totalIssuance + 2_310_000 = bip42SupplyCap := by
  unfold bip42SupplyCap
  rw [totalIssuance_exact]

/-- **The punchline.**  The real schedule already enforces BIP-42's stated
goal: finite supply, bounded by 42 halfmillion BTC, and zero subsidy from
height 6,930,000 onward — before the satirical 2214 activation. -/
theorem bip42_enforced :
    totalIssuance ≤ bip42SupplyCap ∧
    (∀ height : UInt32, bip42ZeroHeight ≤ height → blockSubsidy height = 0) :=
  ⟨bip42_supply_finite, bip42_subsidy_zero_after_epoch33⟩

end BitcoinProofs.Bip.B42
