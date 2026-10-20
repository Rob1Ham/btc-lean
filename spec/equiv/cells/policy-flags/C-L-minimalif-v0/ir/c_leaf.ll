; ModuleID = '/tmp/opencode/equiv-pr/spec/equiv/cells/policy-flags/C-L-minimalif-v0/build/c_leaf.bc'
source_filename = "/tmp/opencode/equiv-pr/spec/equiv/cells/policy-flags/C-L-minimalif-v0/c_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef range(i64 0, 256) i64 @_Z14c_minimalif_v0mmmmm(i64 noundef %flags, i64 noundef %sigversion, i64 noundef %fExec, i64 noundef %vchLen, i64 noundef %vch0Arg) local_unnamed_addr #0 {
entry:
  %cmp = icmp ugt i64 %sigversion, 1
  br i1 %cmp, label %return, label %if.end

if.end:                                           ; preds = %entry
  %cmp1 = icmp eq i64 %fExec, 0
  br i1 %cmp1, label %return, label %if.end3

if.end3:                                          ; preds = %if.end
  %and.i = and i64 %vch0Arg, 255
  %cmp4 = icmp ne i64 %sigversion, 1
  %and = and i64 %flags, 8192
  %cmp5.not = icmp eq i64 %and, 0
  %or.cond18 = or i1 %cmp4, %cmp5.not
  br i1 %or.cond18, label %if.end15, label %if.then6

if.then6:                                         ; preds = %if.end3
  %cmp7 = icmp ugt i64 %vchLen, 1
  br i1 %cmp7, label %return, label %if.end9

if.end9:                                          ; preds = %if.then6
  %cmp10 = icmp eq i64 %vchLen, 1
  %cmp12 = icmp ne i64 %and.i, 1
  %or.cond = and i1 %cmp10, %cmp12
  br i1 %or.cond, label %return, label %if.end15

if.end15:                                         ; preds = %if.end9, %if.end3
  br label %return

return:                                           ; preds = %if.end15, %if.then6, %if.end9, %if.end, %entry
  %retval.1 = phi i64 [ 255, %entry ], [ 0, %if.end ], [ 0, %if.end15 ], [ 31, %if.then6 ], [ 31, %if.end9 ]
  ret i64 %retval.1
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local range(i64 0, 256) i64 @cell_minimalif_v0(i64 noundef %flags, i64 noundef %sigversion, i64 noundef %fExec, i64 noundef %vchLen, i64 noundef %vch0Arg) local_unnamed_addr #0 {
entry:
  %cmp.i = icmp ugt i64 %sigversion, 1
  br i1 %cmp.i, label %_Z14c_minimalif_v0mmmmm.exit, label %if.end.i

if.end.i:                                         ; preds = %entry
  %cmp1.i = icmp eq i64 %fExec, 0
  br i1 %cmp1.i, label %_Z14c_minimalif_v0mmmmm.exit, label %if.end3.i

if.end3.i:                                        ; preds = %if.end.i
  %and.i.i = and i64 %vch0Arg, 255
  %cmp4.i = icmp ne i64 %sigversion, 1
  %and.i = and i64 %flags, 8192
  %cmp5.not.i = icmp eq i64 %and.i, 0
  %or.cond18.i = or i1 %cmp4.i, %cmp5.not.i
  br i1 %or.cond18.i, label %if.end15.i, label %if.then6.i

if.then6.i:                                       ; preds = %if.end3.i
  %cmp7.i = icmp ugt i64 %vchLen, 1
  br i1 %cmp7.i, label %_Z14c_minimalif_v0mmmmm.exit, label %if.end9.i

if.end9.i:                                        ; preds = %if.then6.i
  %cmp10.i = icmp eq i64 %vchLen, 1
  %cmp12.i = icmp ne i64 %and.i.i, 1
  %or.cond.i = and i1 %cmp10.i, %cmp12.i
  br i1 %or.cond.i, label %_Z14c_minimalif_v0mmmmm.exit, label %if.end15.i

if.end15.i:                                       ; preds = %if.end9.i, %if.end3.i
  br label %_Z14c_minimalif_v0mmmmm.exit

_Z14c_minimalif_v0mmmmm.exit:                     ; preds = %entry, %if.end.i, %if.then6.i, %if.end9.i, %if.end15.i
  %retval.1.i = phi i64 [ 255, %entry ], [ 0, %if.end.i ], [ 0, %if.end15.i ], [ 31, %if.then6.i ], [ 31, %if.end9.i ]
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
