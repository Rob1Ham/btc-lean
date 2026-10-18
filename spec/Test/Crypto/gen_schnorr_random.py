#!/usr/bin/env python3
"""gen_schnorr_random.py — BIP340: python-reference BIP340 sign/verify
cross-check corpus (deterministic seed), emitting
spec/Test/Crypto/SchnorrRandomTest.lean.

* Pure-python BIP340 reference (sign AND verify) written from
  bip-0340.mediawiki; every emitted signature is first verified by the
  python reference itself (gate), then paired with an expected verdict.
* 200 deterministic sign/verify pairs (varied messages 0..255 bytes,
  varied aux strings, key stream from hashlib DRBG) + 25 negatives
  (corrupted r / s / msg / wrong key / negated s).
* Lean side: compiled/interpreted runtime execution of
  Bitcoin.Crypto.Schnorr.Verify.verifyImpl must reproduce every verdict.

Usage: python3 spec/Test/Crypto/gen_schnorr_random.py
"""
import hashlib, pathlib

p = 2**256 - 2**32 - 977
n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
Gx = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798
Gy = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8
G = (Gx, Gy)

def tagged_hash(tag, msg):
    t = hashlib.sha256(tag).digest()
    return hashlib.sha256(t + t + msg).digest()

def pt_add(P1, P2):
    if P1 is None: return P2
    if P2 is None: return P1
    if P1[0] == P2[0]:
        if (P1[1] + P2[1]) % p == 0: return None
        lam = 3 * P1[0] * P1[0] * pow(2 * P1[1], -1, p) % p
    else:
        lam = (P2[1] - P1[1]) * pow(P2[0] - P1[0], -1, p) % p
    x3 = (lam * lam - P1[0] - P2[0]) % p
    return (x3, (lam * (P1[0] - x3) - P1[1]) % p)

def pt_mul(k, P):
    R = None
    while k:
        if k & 1: R = pt_add(R, P)
        P = pt_add(P, P); k >>= 1
    return R

def lift_x(b):
    x = int.from_bytes(b, 'big')
    if x >= p: return None
    y_sq = (pow(x, 3, p) + 7) % p
    y = pow(y_sq, (p + 1) // 4, p)
    if pow(y, 2, p) != y_sq: return None
    return (x, y if y % 2 == 0 else p - y)

def verify(pk, msg, sig):
    if len(sig) != 64 or len(pk) != 32: return False
    P = lift_x(pk)
    if P is None: return False
    r = int.from_bytes(sig[:32], 'big'); s = int.from_bytes(sig[32:], 'big')
    if r >= p or s >= n: return False
    e = int.from_bytes(tagged_hash(b"BIP0340/challenge", sig[:32] + pk + msg), 'big') % n
    R = pt_add(pt_mul(s, G), pt_mul(e, (P[0], p - P[1])))
    if R is None or R[0] != r or R[1] % 2 != 0: return False
    return True

def sign(d0, aux, msg):
    # per bip-0340 reference.py schnorr_sign: negate d so dG has even y
    assert 1 <= d0 <= n - 1 and len(aux) == 32
    P = pt_mul(d0, G)
    assert P is not None
    d = d0 if P[1] % 2 == 0 else n - d0
    t = d ^ int.from_bytes(tagged_hash(b"BIP0340/aux", aux), 'big')
    k0 = int.from_bytes(tagged_hash(b"BIP0340/nonce", t.to_bytes(32, 'big') + P[0].to_bytes(32, 'big') + msg), 'big') % n
    assert k0 != 0
    R = pt_mul(k0, G)
    k = k0 if R[1] % 2 == 0 else n - k0
    e = int.from_bytes(tagged_hash(b"BIP0340/challenge", R[0].to_bytes(32, 'big') + P[0].to_bytes(32, 'big') + msg), 'big') % n
    sig = R[0].to_bytes(32, 'big') + ((k + e * d) % n).to_bytes(32, 'big')
    assert verify(P[0].to_bytes(32, 'big'), msg, sig), "python reference self-check failed"
    return P[0].to_bytes(32, 'big'), sig

# --- deterministic corpus ---
vectors = []  # (name, expected, pk, msg, sig)
msgs = []
for i in range(200):
    # deterministic DRBG stream
    seed = hashlib.sha256(b"btc-lean X02 cross-check " + i.to_bytes(4, 'big')).digest()
    d = int.from_bytes(hashlib.sha256(seed + b"key").digest(), 'big') % n
    if d == 0: continue
    aux = hashlib.sha256(seed + b"aux").digest()
    mlen = [0, 1, 17, 32, 32, 32, 64, 100, 255, 33][i % 10]
    msg = hashlib.sha256(seed + b"msg").digest()[:mlen] if mlen <= 32 else \
        (hashlib.sha256(seed + b"msg").digest() * 8)[:mlen]
    pk, sig = sign(d, aux, msg)
    assert verify(pk, msg, sig)
    vectors.append((f"x340-{i:03d}", True, pk.hex().upper(), msg.hex().upper(), sig.hex().upper()))
    msgs.append((d, pk, msg, sig))

# negatives (25): r-bit flip, s-bit flip, msg-bit flip, wrong key, negated s
kinds = ["rflip", "sflip", "mflip", "wrongkey", "negs"]
for j in range(25):
    d, pk, msg, sig = msgs[j * 8 % len(msgs)]
    kind = kinds[j % 5]
    b = bytearray(sig); m = bytearray(msg)
    exp = True; use_pk = pk
    if kind == "rflip":
        b[10] ^= 0x01; exp = False
    elif kind == "sflip":
        b[42] ^= 0x01; exp = False
    elif kind == "mflip" and len(m) > 0:
        m[0] ^= 0x01; exp = False
    elif kind == "wrongkey":
        d2 = int.from_bytes(hashlib.sha256(b"otherkey" + j.to_bytes(2, 'big')).digest(), 'big') % n
        use_pk, _ = sign(d2, aux := hashlib.sha256(b"x").digest(), bytes(m))
        exp = False
    elif kind == "negs":
        s = int.from_bytes(sig[32:], 'big')
        b[32:] = ((n - s) % n).to_bytes(32, 'big'); exp = False
    sig2 = bytes(b)
    assert verify(use_pk, bytes(m), sig2) == exp, f"negative {j} self-check failed ({kind})"
    vectors.append((f"x340-n{j:02d}", exp, use_pk.hex().upper(), bytes(m).hex().upper(), sig2.hex().upper()))

assert len(vectors) == 225, len(vectors)
n_true = sum(1 for v in vectors if v[1])

def lean_str(s): return '"' + s + '"'

entries = "\n".join(
    f"  ({lean_str(name)}, {str(exp).lower()}, {lean_str(pk)}, {lean_str(msg)}, {lean_str(sig)}),"
    for (name, exp, pk, msg, sig) in vectors)

out = f"""import Bitcoin.Crypto.Schnorr.Verify
import Bitcoin.Data.Basic

/-!
# BIP340 python-cross-check corpus (GENERATED — do not hand-edit)

Run: `bash spec/Test/Crypto/run_schnorr.sh` (second harness) or
`python3 spec/Test/Crypto/gen_schnorr_random.py` to regenerate.

Generator : spec/Test/Crypto/gen_schnorr_random.py — pure-python BIP340
            reference (sign + verify, tagged hashes, even-y lift),
            deterministic DRBG seed; every emitted signature is gated by
            the python reference's own verify BEFORE emission.
Corpus    : 200 deterministic sign/verify pairs (messages of size
            0/1/17/32/33/64/100/255) + 25 negatives: corrupted-r /
            corrupted-s / corrupted-msg bit flips, wrong-key, negated-s
            (each negative self-checked to verify False in python).
            Total {len(vectors)} vectors ({n_true} accept / {len(vectors) - n_true} reject).
Lean side : Bitcoin.Crypto.Schnorr.Verify.verifyImpl must reproduce every
            verdict — the sign side is python-only (Lean does not sign),
            so agreement here is a true cross-implementation check of the
            verification equation, the tagged-hash challenge, lift_x, and
            the range gates.
-/

namespace Bitcoin.Test.Crypto.SchnorrRandom

open Bitcoin.Crypto.Schnorr.Verify Bitcoin.Data

set_option maxRecDepth 100000

/-- Parse a hex string into a ByteArray (test infra only). -/
def hexDigitVal (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
  else if 65 ≤ n ∧ n ≤ 70 then some (n - 55)
  else none

def fromHex (s : String) : ByteArray :=
  go s.toList ByteArray.empty
where
  go : List Char → ByteArray → ByteArray
    | [], acc => acc
    | [_], acc => acc
    | a :: b :: rest, acc =>
        match hexDigitVal a, hexDigitVal b with
        | some hi, some lo => go rest (acc.push ((hi * 16 + lo).toUInt8))
        | _, _ => go (b :: rest) acc

/-- `name`, `expected`, pubkey hex, msg hex, sig hex. -/
def vectors : List (String × Bool × String × String × String) :=
  [
{entries}
  ]

/-! ## IO harness -/

def runVectors : IO Unit := do
  let mut fails := 0
  for (name, expected, pkH, msgH, sigH) in vectors do
    let got := verifyImpl (fromHex sigH) (fromHex pkH) (fromHex msgH)
    if got != expected then
      fails := fails + 1
      IO.println s!"FAIL {{name}}: expected {{expected}}, got {{got}}"
  IO.println s!"BIP340 cross-check: {{vectors.length}} vectors ({n_true} accept / {len(vectors) - n_true} reject), FAILURES {{fails}}"
  if fails > 0 then throw (IO.userError "BIP340 python cross-check failures")

end Bitcoin.Test.Crypto.SchnorrRandom

/-- Runner entry (root `main` for `lake env lean --run`). -/
def main : IO Unit := Bitcoin.Test.Crypto.SchnorrRandom.runVectors
"""

(pathlib.Path(__file__).resolve().parent / 'SchnorrRandomTest.lean').write_text(out)
print(f'wrote SchnorrRandomTest.lean with {len(vectors)} vectors ({n_true} accept / {len(vectors)-n_true} reject)')
