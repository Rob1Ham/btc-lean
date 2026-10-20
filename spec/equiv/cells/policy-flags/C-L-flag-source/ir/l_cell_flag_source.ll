; ModuleID = '/tmp/opencode/wave64/64-policy-low-s-codesep/spec/equiv/cells/policy-flags/C-L-flag-source/build/l_cell_flag_source.bc'
source_filename = "/tmp/opencode/wave64/64-policy-low-s-codesep/spec/equiv/cells/policy-flags/C-L-flag-source/l_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local range(i64 0, 135168) i64 @cell_flag_source(i64 noundef %exceptionKind, i64 noundef %height) local_unnamed_addr #0 {
entry:
  %0 = add i64 %exceptionKind, -3
  %or.cond.i.i = icmp ult i64 %0, -2
  %cond16.i.i = select i1 %or.cond.i.i, i64 131072, i64 0
  %.not.i = icmp eq i64 %exceptionKind, 1
  %retval.i.sroa.14.0.i = select i1 %.not.i, i64 0, i64 2048
  %narrow.i = icmp ne i64 %exceptionKind, 1
  %retval.i.sroa.0.0.i = zext i1 %narrow.i to i64
  %rem.i = and i64 %height, 4294967295
  %cmp.i16.i = icmp samesign ugt i64 %rem.i, 363724
  %cmp.i15.i = icmp samesign ugt i64 %rem.i, 388380
  %cmp.i14.i = icmp samesign ugt i64 %rem.i, 419327
  %cmp.i.i = icmp samesign ugt i64 %rem.i, 481823
  %cond2.i.i = select i1 %cmp.i16.i, i64 4, i64 0
  %cond4.i.i = select i1 %cmp.i.i, i64 16, i64 0
  %cond7.i.i = select i1 %cmp.i15.i, i64 512, i64 0
  %cond10.i.i = select i1 %cmp.i14.i, i64 1024, i64 0
  %or.i.i = or disjoint i64 %retval.i.sroa.14.0.i, %retval.i.sroa.0.0.i
  %or5.i.i = or disjoint i64 %or.i.i, %cond16.i.i
  %or8.i.i = or disjoint i64 %or5.i.i, %cond2.i.i
  %or11.i.i = or disjoint i64 %or8.i.i, %cond4.i.i
  %or14.i.i = or disjoint i64 %or11.i.i, %cond7.i.i
  %or17.i.i = or i64 %or14.i.i, %cond10.i.i
  ret i64 %or17.i.i
}

attributes #0 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
