; ModuleID = '/tmp/opencode/wave64/64-policy-low-s-codesep/spec/equiv/cells/policy-flags/C-L-flag-source/build/c_cell_flag_source.bc'
source_filename = "/tmp/opencode/wave64/64-policy-low-s-codesep/spec/equiv/cells/policy-flags/C-L-flag-source/c_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local range(i64 0, 135168) i64 @cell_flag_source(i64 noundef %exceptionKind, i64 noundef %height) local_unnamed_addr #0 {
entry:
  %rem.i = and i64 %height, 4294967295
  %switch.selectcmp.i.i = icmp eq i64 %exceptionKind, 2
  %switch.select.i.i = select i1 %switch.selectcmp.i.i, i64 2049, i64 133121
  %switch.selectcmp27.i.i = icmp eq i64 %exceptionKind, 1
  %switch.select28.i.i = select i1 %switch.selectcmp27.i.i, i64 0, i64 %switch.select.i.i
  %cmp4.i.i = icmp samesign ugt i64 %rem.i, 363724
  %or.i.i = or disjoint i64 %switch.select28.i.i, 4
  %spec.select.i.i = select i1 %cmp4.i.i, i64 %or.i.i, i64 %switch.select28.i.i
  %cmp7.i.i = icmp samesign ugt i64 %rem.i, 388380
  %or9.i.i = or disjoint i64 %spec.select.i.i, 512
  %flags.2.i.i = select i1 %cmp7.i.i, i64 %or9.i.i, i64 %spec.select.i.i
  %cmp11.i.i = icmp samesign ugt i64 %rem.i, 419327
  %or13.i.i = or i64 %flags.2.i.i, 1024
  %flags.3.i.i = select i1 %cmp11.i.i, i64 %or13.i.i, i64 %flags.2.i.i
  %cmp15.i.i = icmp samesign ugt i64 %rem.i, 481823
  %or17.i.i = or i64 %flags.3.i.i, 16
  %flags.4.i.i = select i1 %cmp15.i.i, i64 %or17.i.i, i64 %flags.3.i.i
  ret i64 %flags.4.i.i
}

attributes #0 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
