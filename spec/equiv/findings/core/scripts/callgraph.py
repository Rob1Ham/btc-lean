import re, sys, json, collections
path=sys.argv[1]
lines=open(path).read().splitlines()
defs={}; calls=collections.defaultdict(set); ptr=collections.Counter(); inv=collections.Counter()
cur=None; depth=0
for l in lines:
    if l.startswith('define '):
        m=re.search(r'@([^ (]+)\(',l); cur=m.group(1); defs[cur]=0; depth=l.count('{')-l.count('}')
    elif l.startswith('}') and cur:
        depth += l.count('{')-l.count('}')
        if depth<=0: cur=None
    if cur:
        for m in re.finditer(r'\b(?:call|invoke)\b[^@\n]*@([\w.$]+)\(', l):
            calls[cur].add(m.group(1))
        if ' ptrtoint ' in l: ptr[cur]+=1
        if ' landingpad' in l: inv[cur]+=1
# reachable from EvalScript (both overloads) and VerifyScript
roots=[f for f in defs if 'EvalScript' in f]
seen=set(); stack=list(roots)
while stack:
    f=stack.pop()
    if f in seen: continue
    seen.add(f)
    for g in calls.get(f,()):
        if g in defs: stack.append(g)
ext=set()
for f in seen:
    for g in calls.get(f,()):
        if g not in defs and not g.startswith('llvm.'): ext.add(g)
print("module funcs:",len(defs))
print("reachable from EvalScript:",len(seen))
rp=[(v,k) for k,v in ptr.items() if k in seen and v]
print("ptrtoint in reachable funcs:",sum(v for v,k in rp),"across",len(rp),"funcs")
for v,k in sorted(rp, reverse=True)[:15]: print(f"  {v:3} {k}")
print("landingpad in reachable:",sum(v for k,v in inv.items() if k in seen))
print("external callees reachable:",len(ext))
for e in sorted(ext): print("  ",e)
