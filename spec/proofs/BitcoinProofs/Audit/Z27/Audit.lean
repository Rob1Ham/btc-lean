import Bitcoin.Capstone.Merkle
import Bitcoin.Crypto.Seam.Hash
import Bitcoin.Data.Tx
import Bitcoin.Invariants.RC08

/-!
# Z27 dark-corner audit — witness-commitment reserved value + merkle odd-duplication (W4 suite)

NEW file, owned by Z27, 2026-10-16. Python3 probe:
`build/scratch/build/scratch/scratch/Z27/z27_c1_c2_probe.py` (all Lean
byte-pins below are python3-mirrored there). Findings:
`spec/db/findings-w4/Z27.md`.

Ground truth: Bitcoin Core @ `cce32b168`, vendored at
`build/scratch/W02/bitcoin/src/` (consensus/merkle.cpp,
validation.cpp CheckWitnessMalleation:3878-3917) + Review-1 report
`research/08-block-pow-utxo.md` K4/K5, BLK-008/014/017/018.

## C1 — witness commitment: two DISTINCT zero-roles (merkle.cpp:86-96, 90; validation.cpp:3884-3917)

Core semantics, exactly:

1. **Witness-tree leaf 0 is `uint256()` (32 zero bytes) UNCONDITIONALLY** —
   `leaves.emplace_back(); // The witness hash of the coinbase is 0.`
   (merkle.cpp:90). The coinbase's actual witness nonce NEVER enters the
   witness tree.
2. **The commitment binds the ACTUAL reserved value**:
   `CHash256().Write(hash_witness).Write(witness_stack[0])`
   (validation.cpp:3901-3904) — i.e. `SHA256D(witness_root ‖ nonce)` where
   the nonce is the coinbase's `scriptWitness.stack[0]`, exactly one
   32-byte element (`bad-witness-nonce-size`) with **unconstrained
   content**.

W17's shipped def `Bitcoin.Capstone.Merkle.witnessCommitmentOk` (**BLK-017**)
captures (1) via `witnessLeaves` but hardcodes the zero reserved value in
(2) — it compares against `SHA256D(witness_root ‖ 0x00…00)` only. Core
accepts a block with nonce `0x01…01` and matching commitment; the shipped
def rejects it. The faithful def IS in the tree:
`Bitcoin.Invariants.RC08.witnessCommitmentMatch` (**INV-090**,
validation.cpp:3898-3906), with the zero-nonce reduction theorem
`witnessCommitmentMatch_zeroNonce` — but the Capstone pipeline
(`Bitcoin.Capstone.Block`, Block.lean:341-349) runs the zero-hardcoded
`witnessCommitmentOk`/`commitmentGate`, so the divergence is LIVE there
(latent in practice: all pinned anchors use the zero nonce — 481824/709632
coinbase nonces are 32 zero bytes, python-parsed).

Below: the nonce never enters `witnessMerkleRoot` / `witnessCommitmentOk`
(abstract theorems), plus concrete `rfl` (kernel-computed) pins of the decisive
nonce=0x01…01 block (Core VALID / shipped def false) and the zero-nonce
agreement case.

## C2 — merkle odd-case: duplicate-last hash THEN pair (merkle.cpp:53-73)

`if (hashes.size() & 1) hashes.push_back(hashes.back());` — at EVERY level,
the last element is DUPLICATED (not zero-padded, not dropped, not
first-swapped) before pairing; and a single-leaf tree's root is the leaf
itself (the loop never runs — NO self-pairing even at the top).

The shipped def `merkleLevel`/`merkleRootOf` (**BLK-008/009/013**) is an
exact port; below: abstract expansions for the 3- and 5-leaf cases (odd at
ONE resp. TWO levels), the singleton identity, and concrete `rfl` pins
separating the faithful root from the zero-pad and self-pair variants.
-/

namespace Bitcoin.Proofs.Audit.Z27

open Bitcoin.Data Bitcoin.Capstone.Merkle Bitcoin.Crypto.Seam.Hash
open Bitcoin.Invariants.RC08

/-! ### shared: hex-literal helper (kernel-computable) -/

private def b32 (l : List UInt8) : ByteArray := l.foldl (fun acc b => acc.push b) ByteArray.empty

/-! ### concrete digest pins: build-enforced compilation, not kernel reduction

The concrete `sha256d` values below cannot be closed by kernel `rfl`/`decide`
in toolchain v4.35.0: the seam's digest is built through `Array.map`, whose
indexing does not reduce in the kernel (the same limitation recorded as
F-Z01-004 in `Audit/Z01`). They are therefore evaluated by the compiler and
the build fails if any pin is false — no `native_decide`, no `sorryAx`, no
new axiom. The abstract theorems in this file remain kernel-checked. -/

/-- Build-enforced concrete pin: `#eval` reports an error (failing the build)
when `b` is `false`. -/
private def pin (name : String) (b : Bool) : IO Unit :=
  unless b do throw (IO.userError s!"Z27 concrete pin failed: {name}")

/-! ## C2 — merkle odd-case: duplicate-last THEN pair -/

/-- **BLK-008**, one odd level: `[a,b,c]` pairs `(a,b)` and `(c,c)` — the
last element DUPLICATED first, never zero-padded. -/
theorem merkleLevel_odd3 (a b c : ByteArray) :
    merkleLevel [a, b, c] = [pairHash a b, pairHash c c] := by
  simp [merkleLevel, pairHash]

/-- The 3-leaf root = `SHA256D(SHA256D(a‖b) ‖ SHA256D(c‖c))` — dup-last at
level 1 only. -/
theorem merkleRootOf_odd3 (a b c : ByteArray) :
    merkleRootOf [a, b, c] = pairHash (pairHash a b) (pairHash c c) := by
  simp [merkleRootOf, merkleRootOfF, merkleLevel, pairHash]

/-- 5 leaves: odd at TWO levels (5 → 3 → 2 → 1); the odd tail `e`
self-pairs at level 1, and `pairHash e e` self-pairs AGAIN at level 2
(`SHA256D(SHA256D(e‖e) ‖ SHA256D(e‖e))`). -/
theorem merkleRootOf_odd5 (a b c d e : ByteArray) :
    merkleRootOf [a, b, c, d, e] =
      pairHash (pairHash (pairHash a b) (pairHash c d))
               (pairHash (pairHash e e) (pairHash e e)) := by
  simp [merkleRootOf, merkleRootOfF, merkleLevel, pairHash]

/-- **BLK-013 corollary**: a single-leaf root IS the leaf — Core's loop
`while (hashes.size() > 1)` never runs, so there is NO top-level
self-pairing. -/
theorem merkleRootOf_singleton_id (a : ByteArray) : merkleRootOf [a] = a := by
  simp [merkleRootOf, merkleRootOfF]

/-- Concrete vectors (python probe, sha256d of `"Z27-C2-tx0/1/2"`): -/
def T0 : ByteArray := b32 [0x5b,0x60,0xfd,0x75,0x2c,0xda,0xc4,0x84,0x2e,0xae,0xdf,0xef,0x8a,0x08,0x96,0xc3,
                           0xd9,0x1d,0x5d,0xc8,0x4b,0x3e,0xe0,0x49,0x75,0xc8,0xc4,0x43,0x30,0x3a,0x37,0x62]
def T1 : ByteArray := b32 [0x3a,0x2b,0xcd,0x8d,0xd4,0xb9,0xe4,0x16,0xc3,0x48,0x9b,0xcc,0x62,0xd0,0xd2,0xf0,
                           0x9f,0xc1,0xb1,0x6b,0x75,0x88,0x7f,0xc8,0x1f,0x35,0xac,0xac,0x07,0x32,0xbc,0xf9]
def T2 : ByteArray := b32 [0x8a,0x0f,0x17,0xd6,0xfd,0xf6,0xab,0x60,0x4c,0x4f,0xff,0x69,0xf0,0x1d,0x10,0xcc,
                           0x41,0xed,0xd3,0x71,0x5e,0x7a,0x01,0x71,0x43,0x1e,0xea,0xff,0xfe,0xad,0x0b,0x3b]

/- Root of `[T0,T1,T2]` = the dup-last expansion
`7b56b01a…` (python-mirrored). -/
#eval pin "merkleRootOf[T0,T1,T2] = dup-last 7b56b01a…"
  (bytesBEq (merkleRootOf [T0, T1, T2])
    (b32 [0x7b,0x56,0xb0,0x1a,0x8b,0xdf,0x68,0x30,0xa4,0x1d,0xd0,0x06,0x67,0x9c,0x64,0x94,
          0x36,0x50,0x9c,0x59,0xc7,0x24,0xf9,0xba,0xe1,0xa6,0x9f,0x17,0x2c,0x22,0x07,0x4a]))

/- The zero-pad variant (odd level padded with `uint256()`) gives a
DIFFERENT root `16ec6104…` — the dark corner is decisive: -/
#eval pin "merkleRootOf[T0,T1,T2] ≠ zero-pad 16ec6104…"
  (!(bytesBEq (merkleRootOf [T0, T1, T2])
    (b32 [0x16,0xec,0x61,0x04,0xb3,0xc6,0x41,0x78,0x93,0x61,0xea,0xcb,0xab,0xb1,0x13,0x3a,
          0x1b,0xfc,0xf6,0x2c,0x56,0x12,0x43,0x61,0xa0,0x6d,0x99,0xfb,0x20,0x60,0x56,0x12])))

/- Single-leaf pin: `S = SHA256D("Z27-C2-single")` is its own root… -/
#eval pin "sha256d(\"Z27-C2-single\") = a12edca4…"
  (bytesBEq (sha256d ("Z27-C2-single".toUTF8))
    (b32 [0xa1,0x2e,0xdc,0xa4,0xec,0xa7,0xa1,0x68,0x3b,0x63,0xc4,0xa8,0xca,0x51,0x4a,0x4f,
          0xb0,0x66,0xd9,0xee,0xeb,0x91,0x44,0xdd,0x2f,0xbc,0x63,0xa5,0x22,0x74,0xb1,0x06]))

/- …and the self-paired top (a common reimplementation bug) is NOT the
root: `SHA256D(S‖S) = 90cd4f2f… ≠ S`. -/
#eval pin "self-paired top ≠ single-leaf root"
  (!(bytesBEq (pairHash (sha256d ("Z27-C2-single".toUTF8)) (sha256d ("Z27-C2-single".toUTF8)))
    (sha256d ("Z27-C2-single".toUTF8))))

/-- The witness tree of a coinbase-only block: leaf 0 is `0x00…00`
UNCONDITIONALLY — the coinbase's actual witness nonce never enters it
(merkle.cpp:90 `leaves.emplace_back()`). -/
theorem witnessLeaves_coinbase_leaf_zero (cb : Tx) (rest : List Tx) :
    witnessLeaves (cb :: rest) = zeroBytes 32 :: rest.map wtxidOf := by rfl

/-- Corollary: the witness root of a coinbase-only block is `0x00…00`
whatever the coinbase's witness contains (even with NO witness stack). -/
theorem witnessMerkleRoot_ignores_cb_witness (cb : Tx) :
    witnessMerkleRoot [cb] = zeroBytes 32 := by
  simp [witnessMerkleRoot, witnessLeaves, merkleRootOf, merkleRootOfF]

/-! ## C1 — witness commitment: leaf-0 zero vs the UNCONSTRAINED nonce -/

/-- The shipped BLK-017 def never consults the coinbase witness: two
coinbases with identical vout get identical verdicts even when their
reserved values differ. This is the formal statement of the divergence
(F-Z27-001): the def models the zero-reserved special case only. -/
theorem witnessCommitmentOk_ignores_coinbase_witness (txs : List Tx) (tx₁ tx₂ : Tx)
    (h : tx₁.vout = tx₂.vout) :
    witnessCommitmentOk txs tx₁ = witnessCommitmentOk txs tx₂ := by
  have hcongr : witnessCommitmentOutput tx₁ = witnessCommitmentOutput tx₂ := by
    unfold witnessCommitmentOutput
    rw [h]
  unfold witnessCommitmentOk
  rw [hcongr]

/-- Concrete nonce vectors: `N0 = 0x00…00`, `N1 = 0x01…01` (content
unconstrained in Core — `bad-witness-nonce-size` fixes only SIZE, 32). -/
def N0 : ByteArray := zeroBytes 32
def N1 : ByteArray := (List.range 32).foldl (fun acc _ => acc.push 0x01) ByteArray.empty

/-- The two commitment values (python-mirrored):
`COM0 = SHA256D(0^32 ‖ 0^32) = e2f61c3f…`,
`COM1 = SHA256D(0^32 ‖ 0x01…01) = 705ede9d…` (witness root of a
coinbase-only block is `0^32` by the lemma above). -/
def COM0 : ByteArray := b32 [0xe2,0xf6,0x1c,0x3f,0x71,0xd1,0xde,0xfd,0x3f,0xa9,0x99,0xdf,0xa3,0x69,0x53,0x75,
                             0x5c,0x69,0x06,0x89,0x79,0x99,0x62,0xb4,0x8b,0xeb,0xd8,0x36,0x97,0x4e,0x8c,0xf9]
def COM1 : ByteArray := b32 [0x70,0x5e,0xde,0x9d,0x42,0x47,0x6f,0xc3,0xe5,0xa9,0x78,0xb0,0x42,0xce,0x79,0x0a,
                             0x19,0x36,0x78,0xf4,0x6d,0x19,0xf4,0x7e,0xc4,0xab,0x46,0x53,0x9c,0x47,0xb7,0x6d]

#eval pin "COM0 = SHA256D(0^32 ‖ 0^32)"
  (bytesBEq (sha256d (zeroBytes 32 ++ N0)) COM0)
#eval pin "COM1 = SHA256D(0^32 ‖ 0x01…01)"
  (bytesBEq (sha256d (zeroBytes 32 ++ N1)) COM1)

/-- A coinbase carrying a commitment output for reserved value `nonce`
(`6a24aa21a9ed ‖ SHA256D(witroot ‖ nonce)`). -/
def cbTx (nonce com : ByteArray) : Tx :=
  { version := 1
    vin := [⟨OutPoint.null, Script.empty, 0xffffffff⟩]
    vout := [⟨0, ⟨wcm ++ com⟩⟩]
    locktime := 0
    witness := [[nonce]] }

/- Core's verdict (RC08 INV-090, ACTUAL reserved value): the zero-nonce
block with matching commitment is VALID. -/
#eval pin "Core: zero-nonce commitment VALID"
  (witnessCommitmentMatch [cbTx N0 COM0] (cbTx N0 COM0))

/- Core's verdict: the `0x01…01`-nonce block with ITS matching commitment
is ALSO VALID — the reserved value's content is unconstrained
(validation.cpp:3884-3892, 3901-3904). -/
#eval pin "Core: 0x01…01-nonce commitment VALID"
  (witnessCommitmentMatch [cbTx N1 COM1] (cbTx N1 COM1))

/- The shipped BLK-017 def agrees with Core on the zero-nonce block… -/
#eval pin "shipped def agrees on zero-nonce block"
  (witnessCommitmentOk [cbTx N0 COM0] (cbTx N0 COM0))

/- …but DIVERGES on the `0x01…01`-nonce block: the shipped def returns
`false` (it only ever compares against `SHA256D(witroot ‖ 0^32)`), while
Core accepts. Decisive F-Z27-001 witness, python-mirrored. -/
#eval pin "shipped def DIVERGES on 0x01…01 nonce"
  (!(witnessCommitmentOk [cbTx N1 COM1] (cbTx N1 COM1)))

/- The divergence is two-sided, and stronger than mere incompleteness: on a
block whose commitment is bound to the WRONG nonce (`witness = N1`,
`commitment = COM0`) Core rejects, while the shipped nonce-blind def
ACCEPTS it because it recomputes against the all-zero nonce and finds
`COM0`. So the shipped def is INCOMPLETE (rejects the valid `N1/COM1` block)
AND UNSOUND (accepts the invalid `N1/COM0` block) for non-zero reserved
values; it is exact only in the zero-nonce special case. This is the
content of `witnessCommitmentOk_ignores_coinbase_witness` above. -/
#eval pin "wrong-nonce block ACCEPTED by nonce-blind shipped def"
  (witnessCommitmentOk [cbTx N1 COM0] (cbTx N1 COM0))
#eval pin "wrong-nonce block rejected (Core-faithful)"
  (!(witnessCommitmentMatch [cbTx N1 COM0] (cbTx N1 COM0)))

/-! Cross-references (already in-tree, sorry-free):
* `Bitcoin.Invariants.RC08.witnessCommitmentMatch` — the Core-faithful
  def (INV-090), validation.cpp:3898-3906.
* `Bitcoin.Invariants.RC08.witnessCommitmentMatch_zeroNonce` — the shipped
  BLK-017 def is exactly the zero-reserved special case.
* `Bitcoin.Proofs.Theorems.CapstoneCommitmentCor.witnessMerkleRoot_single_cb`
  — the leaf-0 zero rule (BLK-014 corollary).
* `Bitcoin.Capstone.Block` (acceptBlock) wires `commitmentGate` →
  `witnessCommitmentOk`, i.e. the zero-hardcoded variant, live in the
  pipeline (Block.lean:341-349).
-/

end Bitcoin.Proofs.Audit.Z27
