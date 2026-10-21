import sys,re
s=open(sys.argv[1]).read()
subs=[
 (r'^@_ZTVN10__cxxabiv120__si_class_type_infoE = external global \[0 x ptr\]$',
  '@_ZTVN10__cxxabiv120__si_class_type_infoE = internal constant [4 x ptr] zeroinitializer'),
 (r'^@_ZTVN10__cxxabiv117__class_type_infoE = external global \[0 x ptr\]$',
  '@_ZTVN10__cxxabiv117__class_type_infoE = internal constant [4 x ptr] zeroinitializer'),
 (r'^@_ZTISt13runtime_error = external constant ptr$','@_ZTISt13runtime_error = internal constant ptr null'),
 (r'^@_ZTISt9exception = external constant ptr$','@_ZTISt9exception = internal constant ptr null'),
 (r'^@_ZTVSt9exception = external unnamed_addr constant \{ \[5 x ptr\] \}(, align 8)?$',
  '@_ZTVSt9exception = internal constant { [5 x ptr] } zeroinitializer'),
 (r'^@__dso_handle = external hidden global i8$','@__dso_handle = internal constant i8 0'),
 (r'^@_ZN7uint2563ONEE = external global %class\.uint256, align 1$',
  '@_ZN7uint2563ONEE = internal constant %class.uint256 zeroinitializer, align 1'),
]
for a,b in subs:
    n=len(re.findall(a,s,re.M))
    s=re.sub(a,b,s,flags=re.M)
    print(f'{n:2d}  {a[:60]}')
open(sys.argv[2],'w').write(s)
