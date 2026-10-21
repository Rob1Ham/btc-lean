; ModuleID = '/tmp/opencode/wave64-integrate/spec/equiv/cells/witness-v0/C-L-p2wsh-hashmatch/build/l_cell_p2wsh_hashmatch.bc'
source_filename = "/tmp/opencode/wave64-integrate/spec/equiv/cells/witness-v0/C-L-p2wsh-hashmatch/src/l_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef range(i64 2, 161) i64 @cell_p2wsh_hashmatch(i64 noundef %d0, i64 noundef %d1, i64 noundef %d2, i64 noundef %d3, i64 noundef %p0, i64 noundef %p1, i64 noundef %p2, i64 noundef %p3) local_unnamed_addr #0 {
entry:
  %cmp = icmp eq i64 %d0, %p0
  %cmp1 = icmp eq i64 %d1, %p1
  %or.cond = and i1 %cmp, %cmp1
  %cmp3 = icmp eq i64 %d2, %p2
  %or.cond7 = and i1 %or.cond, %cmp3
  %cmp5 = icmp eq i64 %d3, %p3
  %or.cond8 = and i1 %or.cond7, %cmp5
  %. = select i1 %or.cond8, i64 2, i64 160
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
