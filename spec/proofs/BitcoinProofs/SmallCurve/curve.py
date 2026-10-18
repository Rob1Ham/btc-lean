P = 65647; N = 65173; B = 7
def is_prime(m):
    for i in range(2, int(m**0.5)+1):
        if m % i == 0: return False
    return m > 1
assert is_prime(P) and is_prime(N) and P % 4 == 3 and P % 3 == 1 and N != P
assert N % 2 == 1 and (P+1-N) % 2 == 1

# point count sanity (1 + sum_x #roots)
ysq = [0]*P
for y in range(P): ysq[(y*y) % P] += 1
cnt = 1
for x in range(P): cnt += ysq[(x*x*x + B) % P]
assert cnt == N, cnt
print("#E =", N, "= n  (h = 1)  VERIFIED")

def add(p1, p2):
    if p1 is None: return p2
    if p2 is None: return p1
    x1, y1 = p1; x2, y2 = p2
    if x1 == x2 and (y1 + y2) % P == 0: return None
    if p1 == p2:
        l = (3*x1*x1) * pow(2*y1, P-2, P) % P
    else:
        l = (y2 - y1) * pow(x2 - x1, P-2, P) % P
    x3 = (l*l - x1 - x2) % P
    y3 = (l*(x1 - x3) - y1) % P
    return (x3, y3)

def mul(k, p):
    r = None
    while k:
        if k & 1: r = add(r, p)
        p = add(p, p); k >>= 1
    return r

# G: smallest x>=1 with y2 QR nonzero; even y
G = None
for gx in range(1, 200):
    y2 = (gx*gx*gx + B) % P
    r = pow(y2, (P+1)//4, P) if y2 else 0
    if y2 and (r*r) % P == y2:
        gy = r if r % 2 == 0 else P - r
        assert gy % 2 == 0
        G = (gx, gy); break
gx, gy = G
print("G = (%d, %d)  gy-hex=%x  onCurve:" % (gx, gy, gy), (gy*gy - gx**3 - B) % P == 0)
assert mul(N, G) is None, "n*G != O!"
for m in range(1, 40):
    assert mul(m, G) is not None
print("n*G = O VERIFIED; ord(G) = n (n prime, G!=O)")
print("p-hex=%x n-hex=%x p-2=%x(%d-bit) n-2=%x(%d-bit) sqrtExp=(p+1)/4=%d(%x,%d-bit)"
      % (P, N, P-2, (P-2).bit_length(), N-2, (N-2).bit_length(), (P+1)//4, (P+1)//4, ((P+1)//4).bit_length()))
def bits(w, v):
    return [bool((v >> i) & 1) for i in range(w)]
print("bitsP2(17,%d) =" % (P-2), bits(17, P-2))
print("bitsN2(%d,%d) =" % ((N-2).bit_length(), N-2), bits((N-2).bit_length(), N-2))
print("bitsSqrt(%d,%d) =" % (((P+1)//4).bit_length(), (P+1)//4), bits(((P+1)//4).bit_length(), (P+1)//4))

# ---------------- ECDSA over (P, N, B, G) — the sign/verify sim ----------------
def sign(d, k, z):
    Q = mul(d, G)
    R = mul(k, G)
    r = R[0] % N
    s = (pow(k, N-2, N) * (z + r*d)) % N
    assert r != 0 and s != 0
    return (r, s, Q)

def verify(r0, s0, z, Q):
    r, s = r0 % N, s0 % N
    if r == 0 or s == 0: return False
    w = pow(s, N-2, N)
    u1, u2 = z*w % N, r*w % N
    R = add(mul(u1, G), mul(u2, Q))
    if R is None: return False
    return R[0] % N == r

print("---- roundtrips (d, k, z): verify(sign) must be True")
ok = 0
for (d, k, z) in [(1,1,1),(2,3,5),(12345,6789,101112),(65172,65171,65170),(33333,44444,55555),
                  (65172,65172,65172),(65536,65535,65537),(1,65172,65171),(31426,31425,31424)]:
    r, s, Q = sign(d, k, z)
    v = verify(r, s, z, Q)
    ok += v
    print("d=%-6d k=%-6d z=%-6d r=%-6d s=%-6d  verify=%s" % (d, k, z, r, s, v))
    # high-S: s -> n - s must ALSO verify (the lax-ECDSA invariance!)
    v2 = verify(r, N - s, z, Q)
    print("   high-S (n-s=%-6d) verify=%s  (want True)" % (N - s, v2))
    ok += v2

print("---- negatives")
r, s, Q = sign(999, 888, 777)
print("wrong z:", verify(r, s, 778, Q), "(want False)")
print("wrong r:", verify(r+1 if r+1<N else 1, s, 777, Q), "(want False)")
print("wrong s:", verify(r, s+1 if s+1<N else 1, 777, Q), "(want False)")
print("wrong Q:", verify(r, s, 777, mul(998, G)), "(want False)")
print("r=0 mod n (r0=n):", verify(N, s, 777, Q), "(want False)")
print("s=0 mod n (s0=n):", verify(r, N, 777, Q), "(want False)")
print("mod-n reduction r0=r+n:", verify(r+N, s, 777, Q), "(want True)")
print("mod-n reduction s0=s+n:", verify(r, s+N, 777, Q), "(want True)")
print("r0=2n+r:", verify(r+2*N, s, 777, Q), "(want True)")
# R = infinity hunt: z s.t. u1 G + u2 Q = O -> verify False
found_O = None
for z in range(1, 3000):
    r, s, Q = sign(999, 888, z)
    w = pow(s, N-2, N); u1, u2 = z*w % N, r*w % N
    R = add(mul(u1, G), mul(u2, Q))
    if R is None: found_O = (z, r, s); break
print("R=O case:", found_O)
