import sys, re
# Build M2-style module: pinned (or patched) interpreter + script + stub-abi,
# bnZero/bnOne guards left at 0 (real guard protocol runs), vchTrue guard pinned
# to 1 and its storage set to an explicit read-only {0x01} vector.
src, dst, mode = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(src).read()
V='@_ZZ10EvalScriptRSt6vectorIS_IhSaIhEESaIS1_EERK7CScript19script_verify_flagsRK20BaseSignatureChecker10SigVersionR19ScriptExecutionDataP13ScriptError_tE7vchTrue'
G='@_ZGVZ10EvalScriptRSt6vectorIS_IhSaIhEESaIS1_EERK7CScript19script_verify_flagsRK20BaseSignatureChecker10SigVersionR19ScriptExecutionDataP13ScriptError_tE7vchTrue'
init=('{ %"struct.std::_Vector_base.13" { '
      '%"struct.std::_Vector_base<CTxIn, std::allocator<CTxIn>>::_Vector_impl" { '
      '%"struct.std::_Vector_base<CTxIn, std::allocator<CTxIn>>::_Vector_impl_data" { '
      'ptr @e5.vchTrue.byte, '
      'ptr getelementptr inbounds (i8, ptr @e5.vchTrue.byte, i64 1), '
      'ptr getelementptr inbounds (i8, ptr @e5.vchTrue.byte, i64 1) } } } }')
if mode in ('explicit','patched-explicit'):
    old = f'{V} = internal global %"class.std::vector.12" zeroinitializer, align 8'
    assert old in s, 'vchTrue decl'
    s = s.replace(old, f'{V} = internal constant %"class.std::vector.12" {init}, align 8')
    oldg = f'{G} = internal global i64 0, align 8'
    assert oldg in s, 'vchTrue guard'
    s = s.replace(oldg, f'{G} = internal constant i64 1, align 8')
    s = s.replace('@llvm.global_ctors', '@e5.vchTrue.byte = internal constant i8 1, align 1\n@llvm.global_ctors', 1)
elif mode in ('pinned','pinned-zero'):
    # the existing E5 recipe: every guard pinned to 1, all storage zeroinitializer
    for g in re.findall(r'^@_ZGVZ10EvalScript[^ ]* = internal global i64 0, align 8$', s, re.M):
        s = s.replace(g, g.replace('internal global i64 0','internal constant i64 1'))
else:
    raise SystemExit('mode?')
open(dst,'w').write(s)
