; ModuleID = '/tmp/opencode/wave16/13-policy-reimport/spec/equiv/cells/policy-flags/C-L-minimalif-v0/build/l_cell_minimalif_v0.bc'
source_filename = "/tmp/opencode/wave16/13-policy-reimport/spec/equiv/cells/policy-flags/C-L-minimalif-v0/l_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local range(i64 0, 256) i64 @cell_minimalif_v0(i64 noundef %flags, i64 noundef %sigversion, i64 noundef %fExec, i64 noundef %vchLen, i64 noundef %vch0Arg) local_unnamed_addr #0 {
entry:
  %cmp.i = icmp ugt i64 %sigversion, 1
  br i1 %cmp.i, label %_Z14l_minimalif_v0mmmmm.exit, label %if.end.i

if.end.i:                                         ; preds = %entry
  %cmp1.i = icmp eq i64 %fExec, 0
  br i1 %cmp1.i, label %_Z14l_minimalif_v0mmmmm.exit, label %if.end3.i

if.end3.i:                                        ; preds = %if.end.i
  %and.i = and i64 %flags, 8192
  %cmp4.not.i = icmp eq i64 %and.i, 0
  %cmp5.i = icmp ugt i64 %vchLen, 1
  br i1 %cmp5.i, label %lor.end.i, label %lor.rhs.i

lor.rhs.i:                                        ; preds = %if.end3.i
  %and.i.i = and i64 %vch0Arg, 255
  %cmp6.i = icmp ne i64 %vchLen, 1
  %cmp7.i = icmp eq i64 %and.i.i, 1
  %.not19.i = or i1 %cmp6.i, %cmp7.i
  br label %lor.end.i

lor.end.i:                                        ; preds = %lor.rhs.i, %if.end3.i
  %.not.i = phi i1 [ false, %if.end3.i ], [ %.not19.i, %lor.rhs.i ]
  %cmp9.i = icmp ne i64 %sigversion, 1
  %brmerge.i = or i1 %cmp9.i, %cmp4.not.i
  %brmerge18.i = or i1 %brmerge.i, %.not.i
  %retval.0.i = select i1 %brmerge18.i, i64 0, i64 31
  br label %_Z14l_minimalif_v0mmmmm.exit

_Z14l_minimalif_v0mmmmm.exit:                     ; preds = %entry, %if.end.i, %lor.end.i
  %retval.1.i = phi i64 [ %retval.0.i, %lor.end.i ], [ 255, %entry ], [ 0, %if.end.i ]
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
