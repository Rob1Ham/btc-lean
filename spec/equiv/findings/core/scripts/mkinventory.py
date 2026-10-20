import subprocess, re, sys, json
files=[("unpatched-O0","ir/interpreter-O0.ll"),
       ("unpatched-O1","ir/interpreter-O1.ll"),
       ("unpatched-O0-ftrapv","ir/interpreter-O0-ftrapv.ll"),
       ("patched-O0","ir-proto/interpreter-O0-patched.ll"),
       ("patched-O0-erased","ir-proto/interpreter-O0-patched-noexc-s.ll")]
mod_keys=["invoke","landingpad","resume","ptrtoint","inttoptr","personality ptr @__gxx_personality_v0","getelementptr inbounds ptr, ptr"]
print("variant\tfile\tlines\tdefines\t"+"\t".join(k.split()[0] for k in mod_keys)+"\tindirect_callsite")
for name,f in files:
    s=open(f).read(); L=s.splitlines()
    vals=[len(re.findall(re.escape(k), s)) for k in mod_keys]
    ind=sum(1 for l in L if re.search(r'(invoke|call) [^@\n]*%[-\w.$]+ *\(', l))
    print("\t".join(map(str,[name,f,len(L),sum(1 for l in L if l.startswith('define '))]+vals+[ind])))
print()
print("variant\tfunction\tir_body_lines\tinvoke\tlandingpad\tptrtoint\tinttoptr\tindirect\tline")
keys=['EvalScript','VerifyScript','VerifyWitnessProgram','ExecuteWitnessScript','EvalChecksigPreTapscript','EvalChecksigTapscript','CastToBool','CheckSignatureEncoding','CScriptNumC2ERKSt6vector','CountWitnessSigOps','FindAndDelete']
for name,f in files[:2]+files[3:]:
    L=open(f).read().splitlines(); cur=None
    for i,l in enumerate(L):
        if l.startswith('define '):
            cur={'n':re.search(r'@([^ (]+)\(',l).group(1),'line':i+1,'instr':0,'inv':0,'lp':0,'pti':0,'iti':0,'ind':0}
            for k in keys:
                if k in cur['n']:
                    # find end
                    depth=0; end=len(L)
                    for j in range(i,len(L)):
                        depth+=L[j].count('{')-L[j].count('}')
                        if j>i and depth==0: end=j; break
                    body=L[i:end+1]
                    print("\t".join(map(str,[name,cur['n'][:70],len(body),
                        sum(x.count(' invoke ') for x in body), sum(x.count('landingpad') for x in body),
                        sum(x.count(' ptrtoint ') for x in body), sum(x.count(' inttoptr ') for x in body),
                        sum(1 for x in body if re.search(r'(invoke|call) [^@\n]*%[-\w.$]+ *\(',x)), i+1])))
                    break
