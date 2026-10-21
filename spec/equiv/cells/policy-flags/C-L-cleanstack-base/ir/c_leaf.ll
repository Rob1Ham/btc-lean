; ModuleID = '/tmp/opencode/wave64-integrate/spec/equiv/cells/policy-flags/C-L-cleanstack-base/build/c_leaf.bc'
source_filename = "/tmp/opencode/wave64-integrate/spec/equiv/cells/policy-flags/C-L-cleanstack-base/c_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef range(i64 0, 256) i64 @_Z12c_cleanstackmmm(i64 noundef %flags, i64 noundef %sigversion, i64 noundef %finalLen) local_unnamed_addr #0 {
entry:
  %cmp = icmp ugt i64 %sigversion, 1
  br i1 %cmp, label %return, label %if.end

if.end:                                           ; preds = %entry
  %cmp1 = icmp eq i64 %sigversion, 0
  br i1 %cmp1, label %if.then2, label %if.else

if.then2:                                         ; preds = %if.end
  %and = and i64 %flags, 256
  %cmp3 = icmp ne i64 %and, 0
  %cmp5 = icmp ne i64 %finalLen, 1
  %or.cond = and i1 %cmp3, %cmp5
  br i1 %or.cond, label %return, label %if.end12

if.else:                                          ; preds = %if.end
  %cmp9.not = icmp eq i64 %finalLen, 1
  br i1 %cmp9.not, label %if.end12, label %return

if.end12:                                         ; preds = %if.else, %if.then2
  br label %return

return:                                           ; preds = %if.else, %if.then2, %entry, %if.end12
  %retval.0 = phi i64 [ 0, %if.end12 ], [ 255, %entry ], [ 30, %if.then2 ], [ 30, %if.else ]
  ret i64 %retval.0
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local range(i64 0, 256) i64 @cell_cleanstack(i64 noundef %flags, i64 noundef %sigversion, i64 noundef %finalLen) local_unnamed_addr #0 {
entry:
  %cmp.i = icmp ugt i64 %sigversion, 1
  br i1 %cmp.i, label %_Z12c_cleanstackmmm.exit, label %if.end.i

if.end.i:                                         ; preds = %entry
  %cmp1.i = icmp eq i64 %sigversion, 0
  br i1 %cmp1.i, label %if.then2.i, label %if.else.i

if.then2.i:                                       ; preds = %if.end.i
  %and.i = and i64 %flags, 256
  %cmp3.i = icmp ne i64 %and.i, 0
  %cmp5.i = icmp ne i64 %finalLen, 1
  %or.cond.i = and i1 %cmp3.i, %cmp5.i
  br i1 %or.cond.i, label %_Z12c_cleanstackmmm.exit, label %if.end12.i

if.else.i:                                        ; preds = %if.end.i
  %cmp9.not.i = icmp eq i64 %finalLen, 1
  br i1 %cmp9.not.i, label %if.end12.i, label %_Z12c_cleanstackmmm.exit

if.end12.i:                                       ; preds = %if.else.i, %if.then2.i
  br label %_Z12c_cleanstackmmm.exit

_Z12c_cleanstackmmm.exit:                         ; preds = %entry, %if.then2.i, %if.else.i, %if.end12.i
  %retval.0.i = phi i64 [ 0, %if.end12.i ], [ 255, %entry ], [ 30, %if.then2.i ], [ 30, %if.else.i ]
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
