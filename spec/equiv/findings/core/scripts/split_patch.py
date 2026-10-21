import re, sys
src=open('combined.patch').read().splitlines()
files={}
headers={}
cur=None
for l in src:
    if l.startswith('diff --git '):
        cur=l.split(' b/')[-1]; files[cur]=[]; headers[cur]=[l]
    elif not files[cur] and not l.startswith('@@'):
        headers[cur].append(l)
    else:
        files[cur].append(l)

def hunks(lines):
    out=[]; h=None
    for l in lines:
        if l.startswith('@@'):
            if h: out.append(h)
            h=[l]
        elif h is not None:
            h.append(l)
    if h: out.append(h)
    return out

assign={}  # patch id -> {file: [hunks]}
def put(pid, f, h): assign.setdefault(pid,{}).setdefault(f,[]).append(h)

for f, lines in files.items():
    if f.endswith('interpreter.h'):
        for h in hunks(lines): put('P-CORE-02', f, h)
        continue
    if f.endswith('script.h'):
        for h in hunks(lines): put('P-CORE-01', f, h)
        continue
    # interpreter.cpp: classify
    for h in hunks(lines):
        text='\n'.join(h)
        if 'BTC_EQUIV_HOIST_STATICS' in text or ('#ifndef BTC_EQUIV_HOIST_STATICS' in text):
            put('P-CORE-03', f, h)
        else:
            put('P-CORE-01', f, h)

names={'P-CORE-01':'P-CORE-01-scriptnum-error-returns.patch',
       'P-CORE-02':'P-CORE-02-devirtualize-checker.patch',
       'P-CORE-03':'P-CORE-03-hoist-evalscript-statics.patch'}
for pid, fmap in assign.items():
    out=[]
    for f, hs in fmap.items():
        out.extend(headers[f])
        out.extend(hs[0])  # includes @@
        for h in hs[1:]:
            out.extend(h)
    open(names[pid],'w').write('\n'.join(out)+'\n')
    print(names[pid], 'files', list(fmap), 'hunks', sum(len(v) for v in fmap.values()))
