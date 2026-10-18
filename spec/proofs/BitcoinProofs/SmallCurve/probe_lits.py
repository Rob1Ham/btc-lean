P = 65647; N = 65173; B = 7
# P1
print("P1:", (65647 >> 3) % 2)
# P2
print("P2:", [(12345 >> i) % 2 == 1 for i in range(16)])
# P3: addRaw'-copy over my literals, double G=(1,31426)
def addM(m, x, y): return (x + y) % m
def subM(m, x, y): return (x + m - y) % m
def mulM(m, x, y): return (x * y) % m
def invP(d): return pow(d, P-2, P)   # Fermat structural
def negN(y): return subM(P, 0, y)
def doubleRaw(x, y):
    if y == 0: return None
    lam = mulM(P, mulM(P, 3, mulM(P, x, x)), invP(addM(P, y, y)))
    x3 = subM(P, mulM(P, lam, lam), addM(P, x, x))
    y3 = subM(P, mulM(P, lam, subM(P, x, x3)), y)
    return (x3, y3)
def addRaw(x1, y1, x2, y2):
    if x1 == x2 and y1 == y2: return doubleRaw(x1, y1)
    if x1 == x2 and y1 == negN(y2): return None
    lam = mulM(P, subM(P, y2, y1), invP(subM(P, x2, x1)))
    x3 = subM(P, subM(P, mulM(P, lam, lam), x1), x2)
    y3 = subM(P, mulM(P, lam, subM(P, x1, x3)), y1)
    return (x3, y3)
d2 = addRaw(1, 31426, 1, 31426)
print("P3: addRaw 1 31426 1 31426 =", d2)
def add(p1, p2):
    if p1 is None: return p2
    if p2 is None: return p1
    x1,y1 = p1; x2,y2 = p2
    if x1 == x2 and (y1 + y2) % P == 0: return None
    if p1 == p2:
        l = (3*x1*x1) * pow(2*y1, P-2, P) % P
    else:
        l = (y2 - y1) * pow(x2 - x1, P-2, P) % P
    x3 = (l*l - x1 - x2) % P; y3 = (l*(x1 - x3) - y1) % P
    return (x3, y3)
print("P3-check 2G =", add((1, 31426), (1, 31426)), "match:", d2 == add((1, 31426), (1, 31426)))
d3 = addRaw(d2[0], d2[1], 1, 31426)
print("P3b: addRaw 2G G =", d3, "= 3G?", d3 == add(add((1, 31426), (1, 31426)), (1, 31426)))
# P4: parseDerLax sim (Der.lean:56-142 copy)
def byteAt(b, i): return b[i] if i < len(b) else 0
def blen(b): return len(b)
def readBE(b, pos, ln):
    r = 0
    for j in range(ln): r = r*256 + byteAt(b, pos + j)
    return r
def skipZeroBytes(b, pos, cnt):
    while cnt > 0:
        if byteAt(b, pos) == 0: pos += 1; cnt -= 1
        else: return (pos, cnt)
    return (pos, 0)
def stripZeros(b, pos, ln):
    while ln > 0:
        if byteAt(b, pos) == 0: pos += 1; ln -= 1
        else: return (pos, ln)
    return (pos, 0)
def readLenAt(b, pos):
    if pos >= blen(b): return None
    lb = byteAt(b, pos)
    if lb < 0x80: return (lb, pos+1)
    lf = lb - 0x80
    if lf > blen(b) - (pos+1): return None
    (pos2, cnt) = skipZeroBytes(b, pos+1, lf)
    if cnt >= 4: return None
    return (readBE(b, pos2, cnt), pos2+cnt)
def parseDerLax(b):
    if blen(b) < 1 or byteAt(b, 0) != 0x30: return None
    if blen(b) < 2: return None
    lb0 = byteAt(b, 1)
    pos1 = 2 if lb0 < 0x80 else 2 + (lb0 - 0x80)
    if lb0 >= 0x80 and pos1 > blen(b): return None
    if pos1 >= blen(b) or byteAt(b, pos1) != 0x02: return None
    t = readLenAt(b, pos1+1)
    if t is None: return None
    (rlen, rpos) = t
    if rlen > blen(b) - rpos: return None
    pos2 = rpos + rlen
    if pos2 >= blen(b) or byteAt(b, pos2) != 0x02: return None
    t = readLenAt(b, pos2+1)
    if t is None: return None
    (slen, spos) = t
    if slen > blen(b) - spos: return None
    (rpos2, rlen2) = stripZeros(b, rpos, rlen)
    (spos2, slen2) = stripZeros(b, spos, slen)
    ov = rlen2 > 32 or slen2 > 32
    r = 0 if ov else readBE(b, rpos2, rlen2)
    s = 0 if ov else readBE(b, spos2, slen2)
    return (r, s)
b = [0x30, 0x06, 0x02, 0x01, 0xAB, 0x02, 0x01, 0xCD]
print("P4:", parseDerLax(b))
print("bits(17, 65645) =", [bool((65645 >> i) & 1) for i in range(17)])
print("bits(16, 65171) =", [bool((65171 >> i) & 1) for i in range(16)])
