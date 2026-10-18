import Bitcoin.Chain.Basic
import Bitcoin.Crypto.Seam.Hash
import Bitcoin.Data.Tx
import Bitcoin.Serialization.Interface
import Bitcoin.Capstone.Pow

/-!
# Bitcoin.Capstone.Merkle — merkle root + witness commitment (S2b)

Direct ports of Core `consensus/merkle.cpp @cce32b168`:

* `merkleLevel` / `merkleRootOf` — `ComputeMerkleRoot` (:51-73): fold
  level-by-level; **BLK-008** an odd-sized level duplicates its last
  element before pairing; **BLK-009** a pair hash is
  `SHA256d(left ‖ right)`; a single-element level terminates
  (**BLK-013**: the empty list ⇒ null root — unreachable for real blocks,
  **BLK-022**).
* `txidOf` — **BLK-005**: `SHA256d(tx without witness)`; `wtxidOf` —
  **BLK-006**: `SHA256d(tx with witness)` (the BIP144 encoding; `encodeTx`
  = base form exactly when no witness).
* `merkleRootOfBlock` — **BLK-007**: leaves are `txid_i` in block order;
  **BLK-010** the header root must match (`bad-txnmrklroot`).
* `witnessMerkleRoot` — **BLK-014**: the coinbase's leaf is `0x00…00`,
  the other leaves are the `wtxid`s.
* `witnessCommitmentOutput` — **BLK-015**: a commitment output is a
  coinbase output ≥ 38 bytes whose script starts `6a24aa21a9ed`; the last
  one counts. **BLK-016**: its value is 0.
* `witnessCommitmentOk` — **BLK-017**:
  `SHA256d(witnessRoot ‖ reserved) = scriptPubKey[6..38]`, where the
  32-byte item is the coinbase witness reserved value (the
  zero-reserved shape is the `witnessCommitmentOkZero` reference).
* `commitmentNonceOk` — **BLK-018**: the coinbase scriptWitness is
  exactly one 32-byte element (`bad-witness-nonce-size`).
* `commitmentGate` — **BLK-019/BLK-020**: witness txs exist iff a valid
  commitment does (`unexpected-witness` otherwise).

BLK-011 (pair-aligned-duplicate rejection) is enforced by the pipeline
through `merkleMutationOk`: the fold below is the import-cycle bridge to
`Bitcoin.Block.Connect.merkleMutationFree` (Connect imports this module and
`Capstone/Block.lean`, so the pipeline cannot import Connect directly).
`PDW12.merkleMutationFreeCap_eq` proves the bridge is exactly Connect's
detector; the reject verdict is `bad-txns-duplicate` / `BLOCK_MUTATED`
(not `BLOCK_CONSENSUS`, BLK-012). The BIP30 cross-block duplicate face
remains the ledger fold's business.
-/

namespace Bitcoin.Capstone.Merkle

open Bitcoin.Chain Bitcoin.Crypto.Seam.Hash Bitcoin.Data Bitcoin.Serialization

/-- **BLK-005**: `CTransaction::ComputeHash` — txid over the base
(no-witness) serialization. -/
@[rule "BLK-005"]
def txidOf (tx : Tx) : ByteArray := sha256d (serTx tx)

/-- **BLK-006**: `ComputeWitnessHash` — wtxid over the BIP144 encoding
(`encodeTx` extends exactly when `hasWitness`). SWT-041 (the txid/wtxid
split): the txid half is BLK-005's `txidOf` (base serialization), the
wtxid half is this def (with-witness serialization when a witness is
present, base serialization otherwise — Core returns txid verbatim). -/
@[rule "BLK-006", rule "SWT-041"]
def wtxidOf (tx : Tx) : ByteArray :=
  if hasWitness tx then sha256d (encodeTx tx) else sha256d (serTx tx)

/-- One merkle pairing level (merkle.cpp:67): `SHA256d(a ‖ b)`. -/
@[rule "BLK-009"]
def pairHash (a b : ByteArray) : ByteArray := sha256d (a ++ b)

/-- `ComputeMerkleRoot`'s level step (merkle.cpp:51-66): an odd-sized
level duplicates its last element (**BLK-008**) BEFORE pairing, so every
surviving element is a level-hash. `merkleRootOfF` stops at size 1, so
this function only ever folds levels of size ≥ 2 — the singleton case
is the odd-tail carried up from the pair recursion. -/
@[rule "BLK-008"]
def merkleLevel : List ByteArray → List ByteArray
  | [] => []
  | [a] => [pairHash a a]
  | a :: b :: rest => pairHash a b :: merkleLevel rest

/-- Fuel-dropped `ComputeMerkleRoot` (merkle.cpp:51-73): fold levels
until a single element remains. `f = l.length + 1` always suffices
(each level at least halves, and the single-element level terminates). -/
def merkleRootOfF : Nat → List ByteArray → ByteArray
  | 0, l => match l with
    | [a] => a
    | _ => Bitcoin.Data.zeroBytes 32   -- unreachable at adequate fuel
  | _+1, [] => Bitcoin.Data.zeroBytes 32
  | _+1, [a] => a
  | f+1, l => merkleRootOfF f (merkleLevel l)

/-- **BLK-013**: `ComputeMerkleRoot` — `[]` ⇒ the 32-zero null root. -/
@[rule "BLK-013"]
def merkleRootOf (l : List ByteArray) : ByteArray := merkleRootOfF (l.length + 1) l

/-- **BLK-007**: the block's merkle leaves are the txids in order. -/
@[rule "BLK-007"]
def merkleRootOfBlock (txs : List Tx) : ByteArray :=
  merkleRootOf (txs.map txidOf)

/-- **BLK-010**: header root must equal the computed root. -/
@[rule "BLK-010"]
def merkleOk (h : BlockHeader) (txs : List Tx) : Bool :=
  bytesBEq h.hashMerkleRoot (merkleRootOfBlock txs)

/-! ## BLK-011 — mutation detection bridge for the real pipeline

Core's `CheckMerkleRoot` (merkle.cpp:55-73, validation.cpp:3853-3864)
runs the root comparison and the CVE-2012-2459 `mutated` scan in the same
place and returns `bad-txns-duplicate` for a tree with an equal pair at
an EVEN offset in some level. The executable detector is
`Bitcoin.Block.Connect.merkleMutationFree`; because `Block/Connect.lean`
imports both this module and `Capstone/Block.lean`, the real pipeline
cannot import it without a module cycle. The definitions below are the
identical fold placed on the upstream side of that cycle; the proof
module `PDW12.lean` proves `merkleMutationFreeCap = merkleMutationFree`
(using Connect's `levelHasAdjacentDup` characterization), so the pipeline
gate has exactly the existing detector's semantics. -/

/-- BLK-011 bridge: pair-aligned equal-pair scan over one merkle level.
Identical body to `Bitcoin.Block.Connect.levelHasAdjacentDup`. -/
def levelHasAdjacentDupCap : List ByteArray → Bool
  | [] => false
  | [_] => false
  | a :: b :: rest => (a == b) || levelHasAdjacentDupCap rest

/-- BLK-011 bridge: every level of the `merkleLevel` fold is
pair-aligned-dup-free. Identical body to
`Bitcoin.Block.Connect.merkleMutationFree`. -/
def merkleMutationFreeCap : List ByteArray → Nat → Bool
  | _, 0 => true
  | l, f+1 =>
    if l.length ≤ 1 then true
    else !(levelHasAdjacentDupCap l) && merkleMutationFreeCap (merkleLevel l) f

/-- **BLK-011**: the pipeline mutation gate over the block's real merkle
leaves (`txid_i` in block order). A `false` result is Core's
`BLOCK_MUTATED` / `bad-txns-duplicate` reject, distinct from
`bad-txnmrklroot` (BLK-010) and not a `BLOCK_CONSENSUS` cache write
(BLK-012). -/
@[rule "BLK-011"]
def merkleMutationOk (txs : List Tx) : Bool :=
  merkleMutationFreeCap (txs.map txidOf) (txs.length + 1)

/-- The witness-tree leaf vector — coinbase → `0x00…00`, everyone else →
their wtxid (merkle.cpp:118-126 `WitnessMerkleRoot`). -/
@[rule "BLK-014", rule "INV-092"]
def witnessLeaves (txs : List Tx) : List ByteArray :=
  match txs with
  | [] => []
  | cb :: rest => zeroBytes 32 :: rest.map wtxidOf

/-- The witness merkle root (merkle.cpp:118-126). SWT-032: root over the
wtxids of all NON-coinbase txs; the coinbase leaf is the 32-byte zero
(`witnessLeaves`). -/
@[rule "SWT-032"]
def witnessMerkleRoot (txs : List Tx) : ByteArray :=
  merkleRootOf (witnessLeaves txs)

/-- The 6-byte commitment script prefix `OP_RETURN OP_PUSH36 0x24
aa21a9ed` (BIP141). -/
def wcm : ByteArray :=
  [0x6a, 0x24, 0xaa, 0x21, 0xa9, 0xed].foldl (fun acc b => acc.push b) ByteArray.empty

/-- **BLK-015**: a commitment output is a coinbase output of ≥ 38 bytes
whose scriptPubKey starts with `wcm`; Core takes the LAST such output.
SWT-029: the `OP_RETURN 0x24 0xaa 0x21 0xa9 0xed <32B>` output template
that SELECTS the commitment. -/
@[rule "BLK-015", rule "SWT-029", rule "INV-088"]
def witnessCommitmentOutput (tx : Tx) : Option ByteArray :=
  match (tx.vout.filter (fun o =>
      38 ≤ o.scriptPubKey.bytes.size &&
      bytesBEq (o.scriptPubKey.bytes.extract 0 6) wcm)).getLast? with
  | some o => some o.scriptPubKey.bytes
  | none => none

/-- **BLK-016**: every commitment output's value is 0 (BIP141). -/
@[rule "BLK-016"]
def commitmentValueZero (tx : Tx) : Bool :=
  (tx.vout.filter (fun o =>
      38 ≤ o.scriptPubKey.bytes.size &&
      bytesBEq (o.scriptPubKey.bytes.extract 0 6) wcm)).all (fun o => o.value = 0)

/-- The coinbase witness reserved value, exactly Core's
`witness_stack.size() == 1 && witness_stack[0].size() == 32` shape
(validation.cpp:3886-3893): the head witness stack must be the singleton
`[nonce]` with `nonce.size = 32`; every other shape is `none` (the
`bad-witness-nonce-size` reject is the caller's BLK-018 check). -/
@[rule "BLK-017", rule "BLK-018", rule "SWT-030"]
def witnessReservedValue (cb : Tx) : Option ByteArray :=
  match cb.witness.getD 0 [] with
  | [nonce] => if nonce.size = 32 then some nonce else none
  | _ => none

/-- **BLK-017**: `SHA256d(witnessRoot ‖ reserved) = script[6..38]`,
where `reserved` is the ACTUAL coinbase witness reserved value (Core
`CheckWitnessMalleation`, validation.cpp:3884-3906: the 32-byte item is
hashed, not a hard-coded zero); `script[6..38]` is the 32-byte
commitment the coinbase carries. The gate fails closed when no
commitment output is selected or the reserved value is not exactly one
32-byte item.
SWT-030: the committed value = SHA256d(witness_merkle_root ‖
reserved_value) compared to scriptPubKey[6..38]. -/
@[rule "BLK-017", rule "SWT-030"]
def witnessCommitmentOk (txs : List Tx) (cb : Tx) : Bool :=
  match witnessCommitmentOutput cb, witnessReservedValue cb with
  | some script, some reserved =>
      bytesBEq (sha256d (witnessMerkleRoot txs ++ reserved))
        (script.extract 6 38)
  | _, _ => false

/-- The pre-fix zero-reserved equation, retained as a reference so the
compatibility proof (`WitnessCommitmentReserved.lean`) can state exactly
what the old constant-only gate accepted. -/
def witnessCommitmentOkZero (txs : List Tx) (cb : Tx) : Bool :=
  match witnessCommitmentOutput cb with
  | none => false
  | some script =>
      bytesBEq (sha256d (witnessMerkleRoot txs ++ Bitcoin.Data.zeroBytes 32))
        (script.extract 6 38)

/-- **BLK-018**: the coinbase's scriptWitness must be exactly one 32-byte
element (content = the nonce, unconstrained). SWT-031: the witness
reserved-value shape (validation.cpp:3886-3893). -/
@[rule "BLK-018", rule "SWT-031", rule "INV-089"]
def commitmentNonceOk (cb : Tx) : Bool :=
  match cb.witness.getD 0 [] with
  | [nonce] => nonce.size = 32
  | _ => false

/-- Some tx in the block carries witness data (BIP144 framing). -/
def anyWitness (txs : List Tx) : Bool := txs.any hasWitness

/-- **BLK-019+BLK-020**: the commitment gate, conditional on SegWit
activation exactly as Core's `CheckWitnessMalleation(block,
expect_witness_commitment, state)` (validation.cpp:3878-3924), where
`expect_witness_commitment = DeploymentActiveAfter(pindexPrev,
DEPLOYMENT_SEGWIT)` (validation.cpp:4177).

* activation ON and a commitment output present ⇒ the commitment must
  BIND the witness tree (BLK-020/SWT-034);
* otherwise (pre-activation, or no commitment output) the gate is the
  Core fall-through no-witness rule: witness data is forbidden
  (`unexpected-witness`, SWT-033). In particular pre-activation the
  whole commitment requirement is a **no-op** — a commitment-shaped
  output without witness data is accepted (block 470000).

`segwitActive` is `SEGWIT_HEIGHT ≤ blockHeight` (buried
`DEPLOYMENT_SEGWIT`, kernel/chainparams.cpp:124; `DeploymentActiveAfter`
uses `pindexPrev->nHeight + 1`, deploymentstatus.h). -/
@[rule "BLK-019", rule "BLK-020", rule "SWT-033", rule "SWT-034", rule "INV-091", rule "INV-136"]
def commitmentGate (segwitActive : Bool) (txs : List Tx) (cb : Tx) : Bool :=
  if segwitActive && (witnessCommitmentOutput cb).isSome then
    witnessCommitmentOk txs cb
  else
    !(anyWitness txs)

/-- Pre-activation the commitment requirement is exactly Core's
fall-through no-witness check (validation.cpp:3913-3921). -/
theorem commitmentGate_pre_activation (txs : List Tx) (cb : Tx) :
    commitmentGate false txs cb = !(anyWitness txs) := by
  simp [commitmentGate]

/-- Post-activation, a commitment output forces the binding check;
without one the no-witness fall-through applies. -/
theorem commitmentGate_post_activation (txs : List Tx) (cb : Tx) :
    commitmentGate true txs cb =
      (if (witnessCommitmentOutput cb).isSome then
         witnessCommitmentOk txs cb else !(anyWitness txs)) := by
  simp [commitmentGate]

/-- **BLK-022**: a block has at least one tx (the coinbase). -/
@[rule "BLK-022"]
def vtxNonempty (txs : List Tx) : Bool := !txs.isEmpty

end Bitcoin.Capstone.Merkle
