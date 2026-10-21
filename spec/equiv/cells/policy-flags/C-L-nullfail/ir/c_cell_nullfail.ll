; ModuleID = '/tmp/opencode/wave64-integrate/spec/equiv/cells/policy-flags/C-L-nullfail/build/c_cell_nullfail.bc'
source_filename = "/tmp/opencode/wave64-integrate/spec/equiv/cells/policy-flags/C-L-nullfail/c_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local range(i64 0, 33) i64 @cell_nullfail(i64 noundef %flags, i64 noundef %fSuccess, i64 noundef %sigLen) local_unnamed_addr #0 {
entry:
  %cmp.i = icmp eq i64 %fSuccess, 0
  br i1 %cmp.i, label %land.lhs.true.i, label %if.end.i

land.lhs.true.i:                                  ; preds = %entry
  %and.i = and i64 %flags, 16384
  %cmp1.i = icmp ne i64 %and.i, 0
  %cmp3.i = icmp ne i64 %sigLen, 0
  %or.cond.i = and i1 %cmp1.i, %cmp3.i
  br i1 %or.cond.i, label %_Z10c_nullfailmmm.exit, label %if.end.i

if.end.i:                                         ; preds = %land.lhs.true.i, %entry
  br label %_Z10c_nullfailmmm.exit

_Z10c_nullfailmmm.exit:                           ; preds = %land.lhs.true.i, %if.end.i
  %retval.0.i = phi i64 [ 0, %if.end.i ], [ 32, %land.lhs.true.i ]
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
