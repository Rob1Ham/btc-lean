; ModuleID = '/tmp/opencode/wave16/13-policy-reimport/spec/equiv/cells/policy-flags/C-L-cleanstack-base/build/l_cell_cleanstack.bc'
source_filename = "/tmp/opencode/wave16/13-policy-reimport/spec/equiv/cells/policy-flags/C-L-cleanstack-base/l_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local range(i64 0, 256) i64 @cell_cleanstack(i64 noundef %flags, i64 noundef %sigversion, i64 noundef %finalLen) local_unnamed_addr #0 {
entry:
  %cmp.i = icmp ugt i64 %sigversion, 1
  br i1 %cmp.i, label %_Z12l_cleanstackmmm.exit, label %if.end.i

if.end.i:                                         ; preds = %entry
  %cmp2.i = icmp eq i64 %sigversion, 0
  br i1 %cmp2.i, label %if.then3.i, label %if.else.i

if.then3.i:                                       ; preds = %if.end.i
  %and.i = and i64 %flags, 256
  %cmp1.i = icmp ne i64 %and.i, 0
  %cmp4.i = icmp ne i64 %finalLen, 1
  %or.cond.i = and i1 %cmp1.i, %cmp4.i
  br i1 %or.cond.i, label %_Z12l_cleanstackmmm.exit, label %if.end10.i

if.else.i:                                        ; preds = %if.end.i
  %cmp7.not.i = icmp eq i64 %finalLen, 1
  br i1 %cmp7.not.i, label %if.end10.i, label %_Z12l_cleanstackmmm.exit

if.end10.i:                                       ; preds = %if.else.i, %if.then3.i
  br label %_Z12l_cleanstackmmm.exit

_Z12l_cleanstackmmm.exit:                         ; preds = %entry, %if.then3.i, %if.else.i, %if.end10.i
  %retval.1.i = phi i64 [ 255, %entry ], [ 0, %if.end10.i ], [ 30, %if.then3.i ], [ 30, %if.else.i ]
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
