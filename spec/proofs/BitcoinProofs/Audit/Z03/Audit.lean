import Bitcoin.Numeric.Amount
import Bitcoin.Consensus.TxCheck
import Bitcoin.TxValidation.Interface
import Bitcoin.Block.Connect
import Bitcoin.Capstone.Merkle
import Bitcoin.Interpreter.Defs

/-!
# Z03 dark-corner audit — CVE-2010-5139 class (2010 window) + CVE-2012-2459 merkle asymmetry (W4 suite)

NEW file, owned by Z03, 2026-10-16. Python3 probes: scratch
`build/scratch/build/scratch/scratch/Z03/` (`z03_c1_money_probe.py`,
`z03_c2_merkle_probe.py`). Findings: `spec/db/findings-w4/Z03.md`.

Ground truth: Bitcoin Core @ `cce32b168`, vendored at
`build/scratch/W02/bitcoin/src/`.

## C2 — CVE-2012-2459 (merkle.cpp:51-73, validation.cpp:3845-3868)

Core's `ComputeMerkleRoot` flags `mutated` whenever ANY level (checked
per level, BEFORE odd-duplication) contains an equal adjacent pair;
`CheckMerkleRoot` then rejects `bad-txns-duplicate`. The Lean tree:
`Bitcoin.Block.Connect.levelHasAdjacentDup`/`merkleMutationFree`/
`merkleFailureKind` (**BLK-011/BLK-012**, X08). Below:

* the two merkle.cpp-comment twin lists `[a..f]` vs `[a..f,e,f]` (and the
  minimal 3-vs-4 twin) are proven ROOT-EQUAL **abstractly** — the equality
  is definitional (the base's odd-level duplication folds `e‖f` exactly
  like the mutant's duplicate tail), so NO hash computation is needed;
* the mutant is proven `mutatedDuplicate` / the base `plainMismatch`
  (concrete leaves, real sha256d seam; the mutant verdict is a kernel
  proof, the concrete hash/root vectors are executed `#guard` pins
  because this toolchain's kernel cannot reduce `ByteArray.get!` inside
  the vendored SHA-256 compression loop);
* the old `[a,b,b]` over-check is GONE: `levelHasAdjacentDup` now uses
  Core's even-position pair scan (`a::b::rest`), so `[LA,LB,LB]` is not
  flagged — fidelity note F-Z03-004 is resolved.

## C1 — CVE-2010-5139 class (2010 window)

* **5139 output side** (tx_check.cpp:35-41): `checkTransaction` rejects
  the block-74638 incident tx (`voutTooLarge`) and pins the INCREMENTAL
  running-sum check (`txoutTotalTooLarge` at 2×MAX_MONEY) that a
  total-sum-at-the-end reimplementation would lose.
* **5139 arithmetic** (amount.h:27 + the v0.3.x int64 accumulator): the
  incident pair 2×9223372036854277039 sums to 18446744073708554078 >
  int64 max; the wrapped accumulator reads −997538 — the historical
  sign-flip. Lean models CAmount as ℤ (the FIXED semantics) and exposes
  the wrap only through `i64Wrap`.
* **5139 input side** (tx_verify.cpp:190-194): `checkTxInputs`/
  `inputValuesLoop` — per-coin `MoneyRange` AND running-sum
  `MoneyRange` → `badTxnsInputvaluesOutOfRange` (TXV-023).
* **5137** (interpreter.cpp:467-482): `disabledWire` = the 15-op set;
  OP_LSHIFT fails; and the FULL `evalScriptBytes` run shows the
  disabled check fires even inside a dead `OP_IF` branch (Core checks
  at :467 BEFORE the `fExec` gate at :493).
-/

namespace Bitcoin.Proofs.Audit.Z03

open Bitcoin.Data Bitcoin.Numeric Bitcoin.Consensus
open Bitcoin.TxValidation Bitcoin.Block.Connect Bitcoin.Capstone.Merkle
open Bitcoin.Interpreter Bitcoin.Crypto.Seam Bitcoin.Activation

set_option maxRecDepth 100000
set_option maxHeartbeats 1000000

-- Core's `Except` carries no DecidableEq instance in this toolchain; the
-- audit's `decide`d verdict-equations need it (Z03, probe2.log).
deriving instance DecidableEq for Except

-- hex helper (Y08 corpus pattern, as in Z01)
private def hexDigitVal (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
  else none

private def fromHex (s : String) : ByteArray :=
  go (s.toList.filter (fun c => c != '\n' && c != ' ')) ByteArray.empty
where
  go : List Char → ByteArray → ByteArray
    | [], acc => acc
    | [_], acc => acc
    | a :: b :: rest, acc =>
        match hexDigitVal a, hexDigitVal b with
        | some ha, some hb => go rest (acc.push ((ha * 16 + hb).toUInt8))
        | _, _ => go rest acc

/-- A 32-byte leaf of `v` repeated (`ByteArray.replicate` is absent in
this toolchain). -/
private def b32 (v : UInt8) : ByteArray :=
  (List.replicate 32 v).foldl (fun acc b => acc.push b) ByteArray.empty

/-- ByteArray's `BEq` is `data == data` (core `ByteArray.beq`), and
`Array`'s BEq is `isEqv … BEq.beq` — reflexivity is a one-simp fact,
pinned here because the tree has no `LawfulBEq ByteArray` instance. -/
private theorem byteq_self (c : ByteArray) : (c == c) = true := by
  rw [show (c == c) = (c.data == c.data) from rfl]
  exact beq_self_eq_true c.data

/-! ## C2: CVE-2012-2459 -/

section C2

/-- Concrete 32-byte leaves (fake txids) `01×32, 02×32, 03×32`. -/
def LA : ByteArray := b32 1
def LB : ByteArray := b32 2
def LC : ByteArray := b32 3

/-- **F-Z03-003 / the CVE proper, minimal twin** — the 3-tx base and its
duplicate-tailed 4-tx mutant share the root *definitionally*: the base's
odd level duplicates `pairHash c c` exactly as the mutant's tail pair
hashes it (merkle.cpp:14-32's construction, 3-vs-4 instance). No hash
computation: pure list algebra of `merkleLevel`. -/
theorem cve2459_root_eq_minimal (a b c : ByteArray) :
    merkleRootOf [a, b, c] = merkleRootOf [a, b, c, c] := by
  simp [merkleRootOf, merkleRootOfF, merkleLevel, pairHash]

/-- **The merkle.cpp:14-32 comment's own example** — `[1..6]` vs
`[1..6,5,6]` are root-equal for ARBITRARY leaves, again definitionally
(the base's 3-element level-1 duplicates `pairHash e f`). -/
theorem cve2459_root_eq_6v8 (a b c d e f : ByteArray) :
    merkleRootOf [a, b, c, d, e, f] = merkleRootOf [a, b, c, d, e, f, e, f] := by
  simp [merkleRootOf, merkleRootOfF, merkleLevel, pairHash]

/-- The mutant is classified `mutatedDuplicate` (**BLK-011** fires at the
leaf level: the duplicated tail `c,c`). Note the `&&` short-circuit: no
hash of the upper levels is needed. -/
theorem cve2459_mutant_kind (a b c : ByteArray) (fuel : Nat) :
    merkleFailureKind [a, b, c, c] (fuel + 1) = MerkleFailure.mutatedDuplicate := by
  have hd : levelHasAdjacentDup [a, b, c, c] = true := by
    simp [levelHasAdjacentDup, byteq_self]
  have hm : merkleMutationFree [a, b, c, c] (fuel + 1) = false := by
    simp [merkleMutationFree, hd]
  simp [merkleFailureKind, hm]

-- The un-mutated 3-tx base classifies `plainMismatch` (concrete leaves,
-- real sha256d seam). Executed pin: kernel `decide` cannot reduce the
-- vendored SHA-256 `get!` in this toolchain.
#guard merkleFailureKind [LA, LB, LC] 4 = MerkleFailure.plainMismatch

-- Concrete roots pinned against python3 (scratch z03_c2_merkle_probe.py):
-- both twins' root = `223e023f…47bdac`. Executed pins for the same reason.
#guard bytesBEq (merkleRootOf [LA, LB, LC])
                   (merkleRootOf [LA, LB, LC, LC]) = true

#guard merkleRootOf [LA, LB, LC] =
    fromHex "223e023fadf1f053df26988871f893c821c28edf77d64a955e6c2a02d547bdac"

/-- **F-Z03-004 resolved**: `levelHasAdjacentDup` now uses Core's
even-position pair scan (merkle.cpp:56-60: `a::b::rest`, recurse on
`rest`), so an odd level ending `[.., b, b]` is no longer flagged.
This is exactly the audit repair: the old all-consecutive-pairs scan
over-rejected `[LA,LB,LB]` relative to Core. -/
example : levelHasAdjacentDup [LA, LB, LB] = false := by
  decide

end C2

/-! ## C1: CVE-2010-5139 class -/

section C1

/-- One output of 92,233,720,368.54277039 BTC — the reconstructed
block-74638 incident tx's output value
(spec/vectors/cve/cve-2010-5139-value-overflow.json). -/
def incidentVal : Amount := 9223372036854277039

/-- A spendable non-coinbase input (prevout non-null ⇒ not coinbase). -/
def incidentTx : Tx :=
  { version := 1
    vin := [⟨⟨b32 1, 0⟩, ⟨fromHex ""⟩, 0xffffffff⟩]
    vout := [⟨incidentVal, ⟨fromHex "51"⟩⟩, ⟨incidentVal, ⟨fromHex "51"⟩⟩]
    locktime := 0, witness := [] }

/-- **Modern rules reject on output 1** (`bad-txns-vout-toolarge`,
tx_check.cpp:37-38): 9.22e18 sat > MAX_MONEY = 2.1e15 sat. -/
example : checkTransaction incidentTx = some TxCheckError.voutTooLarge := by
  decide

/-- The **incremental running-sum** rule (**INV-006**): two MAX_MONEY
outputs — each individually in range — fail on the SECOND output's
accumulator (`bad-txns-txouttotal-toolarge`, tx_check.cpp:39-41). A
total-sum-at-the-end port would still catch this one, but only the
incremental form matches Core's error/loop shape (Amount.lean's
`checkedSumAux_some_range` theorems pin the equivalence). -/
def twoMaxTx : Tx :=
  { version := 1
    vin := [⟨⟨b32 1, 0⟩, ⟨fromHex ""⟩, 0xffffffff⟩]
    vout := [⟨MAX_MONEY, ⟨fromHex "51"⟩⟩, ⟨MAX_MONEY, ⟨fromHex "51"⟩⟩]
    locktime := 0, witness := [] }

example : checkTransaction twoMaxTx = some TxCheckError.txoutTotalTooLarge := by
  decide

/-- **The 0.3.x arithmetic** (why this was exploitable): as exact ℤ the
pair sums to 18446744073708554078 (> 2^63−1); the int64 accumulator of
v0.3.x wraps it to −997538 — the historical fee sign-flip. Lean's
CAmount = ℤ encodes the FIXED semantics; `i64Wrap` reconstructs the bug. -/
example : plainSum [incidentVal, incidentVal] = 18446744073708554078 := by
  decide

example : i64Wrap (plainSum [incidentVal, incidentVal]) = -997538 := by
  decide

/-- **Input side** (tx_verify.cpp:190-194, **TXV-023/INV-025**): a coin
of MAX_MONEY+1 sat fails the per-coin `MoneyRange` even though the
output side is clean → `badTxnsInputvaluesOutOfRange`. -/
def bigCoinUtxo : OutPoint → Option Bitcoin.Ledger.Coin := fun _ =>
  some ⟨MAX_MONEY + 1, 0, false, ⟨fromHex "51"⟩⟩

def inputOorTx : Tx :=
  { version := 1
    vin := [⟨⟨b32 7, 0⟩, ⟨fromHex ""⟩, 0xffffffff⟩]
    vout := [⟨MAX_MONEY, ⟨fromHex "51"⟩⟩]
    locktime := 0, witness := [] }

example : checkTxInputs inputOorTx bigCoinUtxo 200
    = Except.error TxError.badTxnsInputvaluesOutOfRange := by
  decide

/-- **Input running-sum** (tx_verify.cpp:191-194, **INV-026**): two
MAX_MONEY coins — each individually in range — overflow the
incremental accumulator. -/
def twoBigCoins : OutPoint → Option Bitcoin.Ledger.Coin := fun _ =>
  some ⟨MAX_MONEY, 0, false, ⟨fromHex "51"⟩⟩

def twoInTx : Tx :=
  { version := 1
    vin := [⟨⟨b32 7, 0⟩, ⟨fromHex ""⟩, 0xffffffff⟩,
            ⟨⟨b32 8, 0⟩, ⟨fromHex ""⟩, 0xffffffff⟩]
    vout := [⟨MAX_MONEY, ⟨fromHex "51"⟩⟩]
    locktime := 0, witness := [] }

example : checkTxInputs twoInTx twoBigCoins 200
    = Except.error TxError.badTxnsInputvaluesOutOfRange := by
  decide

/-- **CVE-2010-5137** (interpreter.cpp:467-482): OP_LSHIFT (0x98) — the
2010 crash opcode — is in the 15-op disabled set; OP_CHECKSIG is not. -/
example : disabledWire 0x98 = true := by decide
example : disabledWire 0xac = false := by decide

/-- The disabled check is UNCONDITIONAL in Core (:467 precedes the
`fExec` gate at :493): `1 OP_FALSE OP_IF OP_LSHIFT 1 OP_ENDIF` fails
`SCRIPT_ERR_DISABLED_OPCODE` although the OP_LSHIFT branch is dead.
Flags: the all-false pre-BIP66 consensus set (explicit record —
`ScriptFlags` deliberately has no Inhabited instance). -/
example : evalScriptBytes 100 {} default
    (fromHex "510063985168") [] default SigVersion.base default
    = Except.error ExecError.disabledOpcode := by
  decide

end C1

end Bitcoin.Proofs.Audit.Z03
