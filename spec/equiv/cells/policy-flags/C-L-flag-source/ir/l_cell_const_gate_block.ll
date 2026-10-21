; ModuleID = '/tmp/opencode/wave64-integrate/spec/equiv/cells/policy-flags/C-L-flag-source/build/l_cell_const_gate_block.bc'
source_filename = "/tmp/opencode/wave64-integrate/spec/equiv/cells/policy-flags/C-L-flag-source/l_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef range(i64 0, 256) i64 @cell_const_gate_block(i64 noundef %exceptionKind, i64 noundef %height, i64 noundef %sigversion, i64 noundef %opcode, i64 noundef %foundPositive) local_unnamed_addr #0 {
entry:
  %cmp.i = icmp ugt i64 %foundPositive, 1
  %retval.1.i = select i1 %cmp.i, i64 255, i64 0
  ret i64 %retval.1.i
}

attributes #0 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
