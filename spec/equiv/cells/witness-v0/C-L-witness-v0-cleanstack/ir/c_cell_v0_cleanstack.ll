; ModuleID = '/tmp/opencode/wave64-integrate/spec/equiv/cells/witness-v0/C-L-witness-v0-cleanstack/build/c_cell_v0_cleanstack.bc'
source_filename = "/tmp/opencode/wave64-integrate/spec/equiv/cells/witness-v0/C-L-witness-v0-cleanstack/src/c_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef range(i64 1, 121) i64 @cell_v0_cleanstack(i64 noundef %stack_size, i64 noundef %top_truthy) local_unnamed_addr #0 {
entry:
  %cmp.not = icmp eq i64 %stack_size, 1
  %tobool.not = icmp eq i64 %top_truthy, 0
  %. = select i1 %tobool.not, i64 8, i64 1
  %retval.0 = select i1 %cmp.not, i64 %., i64 120
  ret i64 %retval.0
}

attributes #0 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
