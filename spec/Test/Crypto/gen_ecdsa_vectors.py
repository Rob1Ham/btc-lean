#!/usr/bin/env python3
"""
gen_ecdsa_vectors.py — ECDSA-lax conformance vector generator.

Emits spec/Test/Crypto/EcdsaTest.lean and EcdsaBench.lean from a table of
(name, expected, sigHex, pkHex, msgHex) checked against
Bitcoin.Crypto.Ecdsa.verifyLax by spec/Test/Crypto/EcdsaTest.lean.

Oracle: independent pure-python secp256k1 ECDSA (no external libs),
semantics matched to Core @ cce32b168:
  - lax DER parse (pubkey.cpp::ecdsa_signature_parse_der_lax)
  - scalar_set_b32 mod-n reduction of r,s,z BEFORE the nonzero check
  - verify: w=s^-1, u1=zw, u2=rw, R=u1*G+u2*Q, R.x % n == r
  - NO low-S normalization (high-S verifies: SGN-108)
Deterministic: fixed RNG seed.
"""
import hashlib, random, os

P = 2**256 - 2**32 - 977
N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
Gx = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798
Gy = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8
G = (Gx, Gy)

def inv(a, m): return pow(a, -1, m)

def padd(p, q):
    if p is None: return q
    if q is None: return p
    x1, y1 = p; x2, y2 = q
    if x1 == x2 and (y1 + y2) % P == 0: return None
    if p == q: lam = 3 * x1 * x1 * inv(2 * y1, P) % P
    else:      lam = (y2 - y1) * inv(x2 - x1, P) % P
    x3 = (lam * lam - x1 - x2) % P
    return (x3, (lam * (x1 - x3) - y1) % P)

def pmul(k, p):
    r = None
    while k:
        if k & 1: r = padd(r, p)
        p = padd(p, p); k >>= 1
    return r

def dsha(b): return hashlib.sha256(hashlib.sha256(b).digest()).digest()

def oncurve(pt):
    x, y = pt
    return (y * y - x * x * x - 7) % P == 0

def der_int(v):
    b = v.to_bytes((v.bit_length() + 7) // 8 or 1, 'big')
    if b[0] & 0x80: b = b'\x00' + b
    return b

def der_sig(r, s):
    rb, sb = der_int(r), der_int(s)
    body = b'\x02' + bytes([len(rb)]) + rb + b'\x02' + bytes([len(sb)]) + sb
    return b'\x30' + bytes([len(body)]) + body

def sign(d, z_bytes):
    z = int.from_bytes(z_bytes, 'big')
    k = int.from_bytes(hashlib.sha256(d.to_bytes(32, 'big') + z_bytes).digest(), 'big') % N
    assert k != 0
    R = pmul(k, G)
    r = R[0] % N
    s = inv(k, N) * (z + r * d) % N
    if s == 0: raise RuntimeError("k degenerate; skip")
    return r, s

def keypair(seed):
    rng = random.Random(seed)
    d = rng.randrange(1, N)
    Q = pmul(d, G)
    assert oncurve(Q)
    return d, Q

def ser_pk(Q, form='compressed'):
    x, y = Q
    if form == 'compressed': return bytes([2 + (y & 1)]) + x.to_bytes(32, 'big')
    if form == 'uncompressed': return b'\x04' + x.to_bytes(32, 'big') + y.to_bytes(32, 'big')
    if form == 'hybrid': return bytes([6 + (y & 1)]) + x.to_bytes(32, 'big') + y.to_bytes(32, 'big')
    raise ValueError

# oracle verify (independent check of what we emit)
def overify(sig, Q, z_bytes):
    if Q is None: return False
    if len(sig) < 2 or sig[0] != 0x30: return False
    i = 1
    lb = sig[i]; i += 1
    if lb & 0x80:                      # long-form seq length: skipped unchecked (lax)
        i += (lb & 0x7f)
    if i >= len(sig) or sig[i] != 2: return False
    rl = sig[i+1]; i += 2
    if rl > len(sig) - i: return False
    r = int.from_bytes(sig[i:i+rl], 'big'); i += rl
    if i >= len(sig) or sig[i] != 2: return False
    sl = sig[i+1]; i += 2
    if sl > len(sig) - i: return False
    s = int.from_bytes(sig[i:i+sl], 'big')
    z = int.from_bytes(z_bytes, 'big') % N
    r %= N; s %= N
    if r == 0 or s == 0: return False
    w = inv(s, N)
    R = padd(pmul(z * w % N, G), pmul(r * w % N, Q))
    return R is not None and R[0] % N == r

vecs = []  # (name, expected, sigHex, pkHex, msgHex)
def add(name, expected, sig, pk, msg):
    # sanity: oracle must agree with the expectation we emit
    assert overify(sig, pk_from_hex(pk.hex()), msg) == expected, f"oracle disagrees: {name}"
    vecs.append((name, expected, sig.hex(), pk.hex(), msg.hex()))

def pk_from_hex(h):
    """Strict mirror of Lean parsePubKey: returns None on any reject."""
    b = bytes.fromhex(h)
    if len(b) == 33 and b[0] in (2, 3):
        x = int.from_bytes(b[1:], 'big')
        if x >= P: return None
        y2 = (pow(x, 3, P) + 7) % P
        y = pow(y2, (P + 1) // 4, P)
        if (y * y - y2) % P != 0: return None
        if y % 2 != (b[0] & 1): y = P - y
        return (x, y)
    if len(b) == 65 and b[0] in (4, 6, 7):
        x = int.from_bytes(b[1:33], 'big'); y = int.from_bytes(b[33:], 'big')
        if x >= P or y >= P: return None
        if b[0] in (6, 7) and ((y & 1) != (b[0] == 7)): return None
        if not oncurve((x, y)): return None
        return (x, y)
    return None

# --- 1. 100 valid random sign/verify pairs -------------------------------
d1, Q1 = keypair(1)
for i in range(100):
    d, Q = keypair(1000 + i)
    msg = dsha(f"W14b conformance message {i}".encode())
    r, s = sign(d, msg)
    sig = der_sig(r, s)
    add(f"valid-{i:03d}", True, sig, ser_pk(Q), msg)

# --- 2. wrong key (20) ---------------------------------------------------
for i in range(20):
    d, Q = keypair(1000 + i)
    d2, Q2 = keypair(2000 + i)
    msg = dsha(f"W14b conformance message {i}".encode())
    r, s = sign(d, msg)
    add(f"wrongkey-{i:03d}", False, der_sig(r, s), ser_pk(Q2), msg)

# --- 3. corrupted message (20) ------------------------------------------
for i in range(20):
    d, Q = keypair(1000 + i)
    msg = dsha(f"W14b conformance message {i}".encode())
    bad = bytearray(msg); bad[i % 32] ^= 1
    r, s = sign(d, msg)
    add(f"badmsg-{i:03d}", False, der_sig(r, s), ser_pk(Q), bytes(bad))

# --- 4. high-S variant still verifies (SGN-108, 10) ----------------------
for i in range(10):
    d, Q = keypair(1000 + i)
    msg = dsha(f"W14b conformance message {i}".encode())
    r, s = sign(d, msg)
    add(f"highS-{i:03d}", True, der_sig(r, N - s), ser_pk(Q), msg)

# --- 5. r >= n encoded as 33-byte integer (mod-n reduction, 10) ----------
cnt = 0
for i in range(40):
    if cnt >= 10: break
    d, Q = keypair(1000 + i)
    msg = dsha(f"W14b conformance message {i}".encode())
    r, s = sign(d, msg)
    if r + N >= 2**256 or r + N < 2**255: continue
    rb = b'\x00' + (r + N).to_bytes(32, 'big')     # 33-byte minimal-DER encoding of r+n
    body = b'\x02' + bytes([33]) + rb + b'\x02' + der_int(s)
    sig = b'\x30' + bytes([len(body)]) + body
    assert overify(sig, Q, msg) is True
    add(f"rmodn-{i:03d}", True, sig, ser_pk(Q), msg)
    cnt += 1

# --- 6. overlong r => overflow zeroes BOTH r,s (SGN-106, 5) --------------
for i in range(5):
    d, Q = keypair(1000 + i)
    msg = dsha(f"W14b conformance message {i}".encode())
    r, s = sign(d, msg)
    rb = (2**256 + r).to_bytes(33, 'big')          # 33 bytes, first byte nonzero
    assert rb[0] != 0
    body = b'\x02' + bytes([33]) + rb + b'\x02' + der_int(s)
    sig = b'\x30' + bytes([len(body)]) + body
    add(f"overflow-{i:03d}", False, sig, ser_pk(Q), msg)

# --- 7. DER garbage (10) --------------------------------------------------
d, Q = keypair(1000)
msg = dsha("W14b conformance message 0".encode())
r, s = sign(d, msg)
good = der_sig(r, s)
garb = [
    ("der-empty", b"", False),
    ("der-tag", b"\x31" + good[1:], False),
    ("der-trunc", good[:-3], False),
    ("der-inttag", good[:2] + b'\x03' + good[3:], False),
    ("der-lenskip", good[:1] + b'\x81' + good[1:], True),   # long-form seq len skipped (lax!)
    ("der-nonseq", bytes([0x02]) + good[1:], False),
    ("der-scut", good[:-2] + b'\x02\x01', False),
    ("der-emptykey", b"", False),
    ("der-r-only", b'\x30' + bytes([2 + len(der_int(r))]) + b'\x02' + bytes([len(der_int(r))]) + der_int(r), False),
]
# negative-DER r (top bit set, NO 0x00 pad — lax tolerates, value unchanged)
for i in range(40):
    d_neg, Q_neg = keypair(1000 + i)
    msg_i = dsha(f"W14b conformance message {i}".encode())
    r, s = sign(d_neg, msg_i)
    rb = r.to_bytes(32, 'big')
    if rb[0] & 0x80:
        sb = der_int(s)
        body = b'\x02' + bytes([32]) + rb + b'\x02' + bytes([len(sb)]) + sb
        add("der-negpad", True, b'\x30' + bytes([len(body)]) + body, ser_pk(Q_neg), msg_i)
        break
for name, sig, exp in garb:
    add(name, exp, sig, ser_pk(Q), msg)

# --- 8. pubkey negatives (10) --------------------------------------------
x, y = Q
pkneg = [
    ("pk-badtag", bytes([0x05]) + x.to_bytes(32, 'big') + y.to_bytes(32, 'big')),
    ("pk-x-ge-p", bytes([2 + (y & 1)]) + P.to_bytes(32, 'big')),
    ("pk-offcurve", bytes([4]) + x.to_bytes(32, 'big') + ((y + 1) % P).to_bytes(32, 'big')),
    ("pk-short", bytes([2 + (y & 1)]) + x.to_bytes(32, 'big')[:31]),
    ("pk-long", bytes([4]) + x.to_bytes(32, 'big') + y.to_bytes(32, 'big') + b'\x00'),
    ("pk-hybrid-wrong-parity", bytes([6 + (1 - (y & 1))]) + x.to_bytes(32, 'big') + y.to_bytes(32, 'big')),
    ("pk-hybrid-even-tag-odd-y", bytes([6]) + x.to_bytes(32, 'big') + ((y | 1) % P).to_bytes(32, 'big') if (y | 1) % P != y else bytes([6]) + x.to_bytes(32,'big') + ((y + 1) % P).to_bytes(32,'big')),
    ("pk-empty", b""),
    ("pk-garbage", bytes(range(33))),
    ("pk-compressed-wrong-parity", bytes([2 + (1 - (y & 1))]) + x.to_bytes(32, 'big')),
]
for name, pk in pkneg:
    add(name, False, good, pk, msg)

# --- 9. uncompressed + hybrid pubkey forms of valid sigs (10) ------------
for i, form in enumerate(['uncompressed', 'hybrid'] * 5):
    d, Q = keypair(1000 + i)
    msg = dsha(f"W14b conformance message {i}".encode())
    r, s = sign(d, msg)
    add(f"pkform-{form}-{i:03d}", True, der_sig(r, s), ser_pk(Q, form), msg)

# --- 10. trailing sighash byte tolerated by the lax parser (5) -----------
for i in range(5):
    d, Q = keypair(1000 + i)
    msg = dsha(f"W14b conformance message {i}".encode())
    r, s = sign(d, msg)
    add(f"sighashbyte-{i:03d}", True, der_sig(r, s) + bytes([0x01]), ser_pk(Q), msg)

# --- 11. BIP-0340 corpus keys (EC-adjacent; sign w/ their secrets) -------
import csv
from pathlib import Path
bip = csv.DictReader(open(Path(__file__).resolve().parents[3] / 'spec' / 'data' / 'bips' / 'bip-0340_test-vectors.csv'))
for row in bip:
    if row['verification result'] != 'TRUE' or not row['secret key'].strip(): continue
    d = int(row['secret key'], 16)
    Qb = pmul(d, G)
    # pubkey hex from csv must round-trip
    ph = row['public key']
    # BIP340 pubkeys are x-only (even-y lift); our parser accepts either parity
    assert ser_pk(Qb)[1:].hex().upper() == ph, f"bip340 pubkey mismatch {ph}"
    msg = bytes.fromhex(row['message'])[:32].ljust(32, b'\x00')
    try:
        r, s = sign(d, msg)
    except RuntimeError:
        continue
    # CSV pubkey column is x-only (32 bytes); we emit the tag matching the
    # ACTUAL parity of dG (parsePubKey sqrt-recovers y and auto-adjusts).
    ph_bytes = bytes.fromhex(ph)
    tag = 2 + (Qb[1] & 1)
    add(f"bip340-key-{row['index']}", True, der_sig(r, s), bytes([tag]) + ph_bytes, msg)
    # flipped-parity pubkey = -Q: parses fine but the sig must NOT verify
    # (skip the all-zero-msg u1=0 case where R ↦ -R has the same x)
    msg2 = dsha(f"W14b flip {row['index']}".encode())
    r2, s2 = sign(d, msg2)
    fl = overify(der_sig(r2, s2), (Qb[0], P - Qb[1]), msg2)
    if not fl:
        add(f"bip340-flip-{row['index']}", False, der_sig(r2, s2), bytes([2 + (1 - (Qb[1] & 1))]) + ph_bytes, msg2)

# --- 12. r=0 / s=0 DER (verify fails nonzero check, 2) -------------------
add("zero-r", False, b'\x30\x06\x02\x01\x00\x02\x01\x01', ser_pk(Q), msg)
add("zero-s", False, b'\x30\x06\x02\x01\x01\x02\x01\x00', ser_pk(Q), msg)

# --- 13. Core key_tests.cpp deterministic vectors (2 + negatives) --------
hmsg = dsha(b"Very deterministic message")
def wif_priv(s):
    B58 = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
    v = 0
    for c in s: v = v * 58 + B58.index(c)
    full = v.to_bytes((v.bit_length() + 7) // 8, 'big')
    pad = 0
    for c in s:
        if c == '1': pad += 1
        else: break
    d = (b'\x00' * pad + full)[1:-4]
    return int.from_bytes(d, 'big')
dA = wif_priv("5HxWvvfubhXpYYpS3tJkw6fq9jE9j18THftkZjHHfmFiWtmAbrj")
dB = wif_priv("5KC4ejrDjv152FGwP386VD1i2NYc5KkfSMyv1nGy1VGDxGHqVY3")
QA = pmul(dA, G); QB = pmul(dB, G)
sigA = bytes.fromhex("304402205dbbddda71772d95ce91cd2d14b592cfbc1dd0aabd6a394b6c2d377bbe59d31d022014ddda21494a4e221f0824f0b8b924c43fa43c0ad57dccdaa11f81a6bd4582f6")
sigB = bytes.fromhex("3044022052d8a32079c11e79db95af63bb9600c5b04f21a9ca33dc129c2bfa8ac9dc1cd5022061d8ae5e0f6c1a16bde3719c64c2fd70e404b6428ab9a69566962e8771b5944d")
assert overify(sigA, QA, hmsg) and overify(sigB, QB, hmsg)
add("core-detsig1", True, sigA, ser_pk(QA), hmsg)
add("core-detsig1C", True, sigA, ser_pk(QA, 'compressed'), hmsg)
add("core-detsig2", True, sigB, ser_pk(QB), hmsg)
add("core-detsig2C", True, sigB, ser_pk(QB, 'compressed'), hmsg)
add("core-detsig1-on2", False, sigA, ser_pk(QB), hmsg)
add("core-detsig2-on1", False, sigB, ser_pk(QA), hmsg)
add("core-detsig1-badhash", False, sigA, ser_pk(QA), dsha(b"other message"))

# --- emit ----------------------------------------------------------------
hdr = """import Bitcoin.Crypto.Ecdsa.Interface

/-!
# ECDSA-lax conformance harness (GENERATED — do not hand-edit)

Run: `bash spec/Test/Crypto/run_ecdsa.sh`.

Generator : spec/Test/Crypto/gen_ecdsa_vectors.py (pure-python secp256k1
            oracle, deterministic seed; re-run to regenerate).
Semantics : Core @ cce32b168 — lax DER parse, scalar_set_b32 mod-n
            reduction before the nonzero check, no low-S normalization.
Checked by: compiled runtime execution (`main` below) of `verifyLax`
            against the oracle-pinned expectations — deliberately NOT
            kernel/native_decide through the WF-recursive mulP/expM
            (ECDSA §5 finding: decide cannot reduce WF-recursive defs).
Kernel checks stay on the structural Der-layer defs only.

Corpus (%d vectors; %d accept / %d reject): 100 valid sign/verify ·
20 wrong-key · 20 corrupted-msg · 10 high-S (SGN-108) · 10 r ≥ n as
33-byte DER integers (SGN-107 mod-n reduction) · 5 overlong-integer
overflow (SGN-106: BOTH r,s zeroed) · DER-structure cases (lax long-form
seq-len skip, negative-DER r, truncations, r-only) · 10 pubkey negatives
(bad tag, x ≥ p, off-curve, hybrid parity, wrong length) · 10
uncompressed/hybrid forms · 5 trailing-sighash-byte · 8 BIP-0340 corpus
keys (EC-adjacent; sqrt recovery + parity) + flipped-parity rejects ·
2 zero-r/zero-s · 7 Core key_tests.cpp deterministic vectors.
-/

namespace Bitcoin.Test.Crypto.EcdsaVectors

open Bitcoin.Crypto.Ecdsa

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

/-- `name`, `expected`, sig hex, pubkey hex, msg(32) hex. -/
def vectors : List (String × Bool × String × String × String) :=
  [
""" % (len(vecs), sum(1 for v in vecs if v[1]), sum(1 for v in vecs if not v[1]))
body = "".join(
    f'    ("{n}", {("true" if e else "false")}, "{sg}", "{pk}", "{m}")'
    + ("," if i < len(vecs) - 1 else "")
    + "\n"
    for i, (n, e, sg, pk, m) in enumerate(vecs))
tail = """  ]

/-! ## Kernel-checkable structural examples (Der layer ONLY — no WF defs) -/

-- The empty signature does not lax-parse.
example : Bitcoin.Crypto.Ecdsa.Der.parseDerLax ByteArray.empty = none := by
  decide

-- The Core deterministic signature + trailing sighash byte is strict-DER
-- (BIP66) valid. (BIP66 counts the sighash byte: sig[1] = size − 3.)
example : Bitcoin.Crypto.Ecdsa.Der.isDERSignature (fromHex
    "304402205dbbddda71772d95ce91cd2d14b592cfbc1dd0aabd6a394b6c2d377bbe59d31d022014ddda21494a4e221f0824f0b8b924c43fa43c0ad57dccdaa11f81a6bd4582f601") = true := by
  decide

-- Without the sighash byte the BIP66 size check fails (interpreter-level
-- encoding gate, NOT the lax consensus parser — which accepts it).
example : Bitcoin.Crypto.Ecdsa.Der.isDERSignature (fromHex
    "304402205dbbddda71772d95ce91cd2d14b592cfbc1dd0aabd6a394b6c2d377bbe59d31d022014ddda21494a4e221f0824f0b8b924c43fa43c0ad57dccdaa11f81a6bd4582f6") = false := by
  decide

-- Lax parser tolerates the long-form sequence length (skipped unchecked).
example : (Bitcoin.Crypto.Ecdsa.Der.parseDerLax (fromHex
    "3081450220e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a022084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd")).isSome = true := by
  decide

/-! ## IO harness: the conformance vectors through `verifyLax` -/

def main : IO Unit := do
  let mut fails := 0
  for (name, expected, sg, pk, m) in vectors do
    let got := verifyLax (fromHex sg) (fromHex pk) (fromHex m)
    if got != expected then
      fails := fails + 1
      IO.println s!"FAIL {name}: expected {expected}, got {got}"
  IO.println s!"TOTAL {vectors.length} FAILURES {fails}"
  if fails > 0 then throw (IO.userError "ECDSA conformance failures")

end Bitcoin.Test.Crypto.EcdsaVectors

/-- Runner entry (root `main` for `lake env lean --run`). -/
def main : IO Unit := Bitcoin.Test.Crypto.EcdsaVectors.main
"""

out = hdr + body + tail
path = os.path.join(os.path.dirname(__file__), 'EcdsaTest.lean')
open(path, 'w').write(out)
print(f"wrote {path}: {len(vecs)} vectors")
ntrue = sum(1 for v in vecs if v[1])
print(f"  expected-true: {ntrue}, expected-false: {len(vecs) - ntrue}")

# --- bench file: timed verify loop over the ACCEPT vectors ---------------
accept = [(sg, pk, m) for (n, e, sg, pk, m) in vecs if e][:50]
bench = """import Bitcoin.Crypto.Ecdsa.Interface

/-!
# ECDSA-lax benchmark — verifyLax wall clock (GENERATED — do not hand-edit)

Run: `bash spec/Test/Crypto/run_ecdsa.sh --bench` (or
`cd spec/core && lake env lean --run ../Test/Crypto/EcdsaBench.lean`).

50 valid conformance vectors x 20 rounds = %d verifyLax calls,
compiled native execution; reports µs per full verify (DER parse +
pubkey parse + mod-n reduce + 2 scalar muls). Compare ECDSA field-layer
numbers (mulMod 275-281 ns, invMod 38 µs) — a full verify costs ~2.5k
field muls incl. one inversion per ECDSA §2.6 estimate.
-/

namespace Bitcoin.Test.Crypto.EcdsaBench

open Bitcoin.Crypto.Ecdsa

set_option maxRecDepth 100000

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

def work : List (ByteArray × ByteArray × ByteArray) :=
  [
""" % (len(accept) * 20)
bench += "".join(
    f'    (fromHex "{sg}", fromHex "{pk}", fromHex "{m}")' + ("," if i < len(accept) - 1 else "") + "\n"
    for i, (sg, pk, m) in enumerate(accept))
bench += """  ]

def main : IO Unit := do
  -- warm-up + correctness spot check
  let mut acc := 0
  for (sg, pk, m) in work do
    if verifyLax sg pk m then acc := acc + 1
  if acc != work.length then throw (IO.userError s!"bench sanity: {acc}/{work.length}")
  let rounds := 20
  let t0 ← IO.monoMsNow
  for _ in [0:rounds] do
    for (sg, pk, m) in work do
      if !verifyLax sg pk m then throw (IO.userError "bench: verify flipped")
  let t1 ← IO.monoMsNow
  let total := rounds * work.length
  let usPer := (t1 - t0) * 1000 / total
  IO.println s!"bench: {total} verifies in {t1 - t0} ms => {usPer} µs/verify"

end Bitcoin.Test.Crypto.EcdsaBench

/-- Runner entry (root `main`). -/
def main : IO Unit := Bitcoin.Test.Crypto.EcdsaBench.main
"""
bpath = os.path.join(os.path.dirname(__file__), 'EcdsaBench.lean')
open(bpath, 'w').write(bench)
print(f"wrote {bpath}: {len(accept)} accept vectors x 20 rounds")
