; ModuleID = '/tmp/opencode/equiv-pr/spec/equiv/cells/tapscript-reimport/C-L-tapscript-reimport/build/l_cell_tapscript_cleanstack.bc'
source_filename = "/tmp/opencode/equiv-pr/spec/equiv/cells/tapscript-reimport/C-L-tapscript-reimport/l_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef range(i64 0, 256) i64 @cell_tapscript_cleanstack(i64 noundef %flags, i64 noundef %sigversion, i64 noundef %finalLen) local_unnamed_addr #0 {
entry:
  %0 = add i64 %sigversion, -3
  %or.cond.i = icmp ult i64 %0, -2
  %cmp2.not.i = icmp eq i64 %finalLen, 1
  %..i = select i1 %cmp2.not.i, i64 0, i64 30
  %retval.0.i = select i1 %or.cond.i, i64 255, i64 %..i
  ret i64 %retval.0.i
}

attributes #0 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
