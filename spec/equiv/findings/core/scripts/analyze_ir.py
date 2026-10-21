import re, sys, collections, json
path=sys.argv[1]
lines=open(path, errors='replace').read().splitlines()
funcs=[]  # (name,start,end)
cur=None
for i,l in enumerate(lines):
    if l.startswith('define '):
        m=re.search(r'@([^ (]+)\(', l)
        cur={'name':m.group(1),'start':i+1,'end':None,'invoke':[],'landingpad':[],'indcall':[],'ptrtoint':[],'inttoptr':[],'loops':0,'trap':[],'extern':collections.Counter()}
        funcs.append(cur)
    elif l.startswith('}') and cur:
        cur['end']=i+1; cur=None
# label map per func
for f in funcs:
    se=lines[f['start']-1:f['end'] or len(lines)]
    labels={}
    for j,l in enumerate(se):
        m=re.match(r'^([\w.]+):', l)
        if m: labels[m.group(1)]=j
    for j,l in enumerate(se):
        ln=f['start']+j
        if ' invoke ' in l:
            m=re.search(r'@([^ (]+)\(',l); f['invoke'].append((ln, m.group(1) if m else '?'))
        if 'landingpad' in l: f['landingpad'].append(ln)
        if ' ptrtoint ' in l: f['ptrtoint'].append(ln)
        if ' inttoptr ' in l: f['inttoptr'].append(ln)
        if '@llvm.trap' in l: f['trap'].append(ln)
        if re.search(r'^br .*label %([\w.]+)', l):
            tgt=re.search(r'label %([\w.]+)', l).group(1)
            if tgt in labels and labels[tgt] <= j: f['loops']+=1
        m=re.match(r'^\s*(?:%\S+ = )?(?:tail )?call [^@]*?@([\w.$]+)\(', l)
        if m: f['extern'][m.group(1)]+=1
for f in funcs:
    f['ninstr']=sum(1 for l in lines[f['start']-1:(f['end'] or len(lines))] if l.startswith('  '))
print(f"funcs={len(funcs)}")
key=[f for f in funcs if re.search(r'EvalScript|VerifyScript|VerifyWitnessProgram|ExecuteWitnessScript|CastToBool|CheckSignatureEncoding|EvalChecksig|CountWitnessSigOps|FindAndDelete|CScriptNum|GetOp', f['name'])]
key.sort(key=lambda f:-f['ninstr'])
print(f"{'function':70} {'instr':>6} {'inv':>4} {'lp':>3} {'ind':>4} {'loop':>4} {'pti':>4} {'iti':>4}")
for f in key[:25]:
    print(f"{f['name'][:70]:70} {f['ninstr']:6} {len(f['invoke']):4} {len(f['landingpad']):3} {len(f['indcall']):4} {f['loops']:4} {len(f['ptrtoint']):4} {len(f['inttoptr']):4}")
json.dump(funcs, open(path+'.funcs.json','w'))
