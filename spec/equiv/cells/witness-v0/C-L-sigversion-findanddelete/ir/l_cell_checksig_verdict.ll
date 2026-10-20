; ModuleID = '/tmp/opencode/wave16/14-witness-v0/spec/equiv/cells/witness-v0/C-L-sigversion-findanddelete/build/l_cell_checksig_verdict.bc'
source_filename = "/tmp/opencode/wave16/14-witness-v0/spec/equiv/cells/witness-v0/C-L-sigversion-findanddelete/src/l_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef range(i64 1, 217) i64 @cell_checksig_verdict(i64 noundef %sigversion, i64 noundef %found, i64 noundef %const_scriptcode_flag) local_unnamed_addr #0 {
entry:
  %cmp = icmp eq i64 %sigversion, 0
  %cmp1 = icmp ne i64 %found, 0
  %or.cond = and i1 %cmp, %cmp1
  %tobool = icmp ne i64 %const_scriptcode_flag, 0
  %or.cond4 = and i1 %or.cond, %tobool
  %. = select i1 %or.cond4, i64 216, i64 1
  ret i64 %.
}

attributes #0 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
