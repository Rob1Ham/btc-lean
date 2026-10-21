; ModuleID = '/tmp/opencode/wave64-integrate/spec/equiv/cells/tapscript-reimport/C-L-tapscript-reimport/build/l_leaf.bc'
source_filename = "/tmp/opencode/wave64-integrate/spec/equiv/cells/tapscript-reimport/C-L-tapscript-reimport/l_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef range(i64 0, 256) i64 @_Z21l_tapscript_minimalifmmmmm(i64 noundef %flags, i64 noundef %sigversion, i64 noundef %fExec, i64 noundef %vchLen, i64 noundef %vch0Arg) local_unnamed_addr #0 {
entry:
  %cmp = icmp ugt i64 %sigversion, 2
  br i1 %cmp, label %return, label %if.end

if.end:                                           ; preds = %entry
  %cmp1 = icmp eq i64 %fExec, 0
  br i1 %cmp1, label %return, label %if.end3

if.end3:                                          ; preds = %if.end
  %cmp4 = icmp ugt i64 %vchLen, 1
  br i1 %cmp4, label %lor.end, label %lor.rhs

lor.rhs:                                          ; preds = %if.end3
  %and.i = and i64 %vch0Arg, 255
  %cmp5 = icmp ne i64 %vchLen, 1
  %cmp6 = icmp eq i64 %and.i, 1
  %.not28 = or i1 %cmp5, %cmp6
  br label %lor.end

lor.end:                                          ; preds = %lor.rhs, %if.end3
  %.not = phi i1 [ false, %if.end3 ], [ %.not28, %lor.rhs ]
  %cmp9 = icmp ne i64 %sigversion, 2
  %brmerge = or i1 %cmp9, %.not
  br i1 %brmerge, label %if.end11, label %return

if.end11:                                         ; preds = %lor.end
  %and = and i64 %flags, 8192
  %cmp7.not = icmp eq i64 %and, 0
  %cmp12 = icmp ne i64 %sigversion, 1
  %brmerge25 = or i1 %cmp12, %cmp7.not
  %brmerge27 = or i1 %brmerge25, %.not
  %spec.select = select i1 %brmerge27, i64 0, i64 31
  br label %return

return:                                           ; preds = %if.end11, %lor.end, %if.end, %entry
  %retval.1 = phi i64 [ 255, %entry ], [ 0, %if.end ], [ 51, %lor.end ], [ %spec.select, %if.end11 ]
  ret i64 %retval.1
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef range(i64 0, 256) i64 @_Z22l_tapscript_cleanstackmmm(i64 noundef %flags, i64 noundef %sigversion, i64 noundef %finalLen) local_unnamed_addr #0 {
entry:
  %0 = add i64 %sigversion, -3
  %or.cond = icmp ult i64 %0, -2
  %cmp2.not = icmp eq i64 %finalLen, 1
  %. = select i1 %cmp2.not, i64 0, i64 30
  %retval.0 = select i1 %or.cond, i64 255, i64 %.
  ret i64 %retval.0
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local range(i64 0, 256) i64 @cell_tapscript_minimalif(i64 noundef %flags, i64 noundef %sigversion, i64 noundef %fExec, i64 noundef %vchLen, i64 noundef %vch0Arg) local_unnamed_addr #0 {
entry:
  %cmp.i = icmp ugt i64 %sigversion, 2
  br i1 %cmp.i, label %_Z21l_tapscript_minimalifmmmmm.exit, label %if.end.i

if.end.i:                                         ; preds = %entry
  %cmp1.i = icmp eq i64 %fExec, 0
  br i1 %cmp1.i, label %_Z21l_tapscript_minimalifmmmmm.exit, label %if.end3.i

if.end3.i:                                        ; preds = %if.end.i
  %cmp4.i = icmp ugt i64 %vchLen, 1
  br i1 %cmp4.i, label %lor.end.i, label %lor.rhs.i

lor.rhs.i:                                        ; preds = %if.end3.i
  %and.i.i = and i64 %vch0Arg, 255
  %cmp5.i = icmp ne i64 %vchLen, 1
  %cmp6.i = icmp eq i64 %and.i.i, 1
  %.not28.i = or i1 %cmp5.i, %cmp6.i
  br label %lor.end.i

lor.end.i:                                        ; preds = %lor.rhs.i, %if.end3.i
  %.not.i = phi i1 [ false, %if.end3.i ], [ %.not28.i, %lor.rhs.i ]
  %cmp9.i = icmp ne i64 %sigversion, 2
  %brmerge.i = or i1 %cmp9.i, %.not.i
  br i1 %brmerge.i, label %if.end11.i, label %_Z21l_tapscript_minimalifmmmmm.exit

if.end11.i:                                       ; preds = %lor.end.i
  %and.i = and i64 %flags, 8192
  %cmp7.not.i = icmp eq i64 %and.i, 0
  %cmp12.i = icmp ne i64 %sigversion, 1
  %brmerge25.i = or i1 %cmp12.i, %cmp7.not.i
  %brmerge27.i = or i1 %brmerge25.i, %.not.i
  %spec.select.i = select i1 %brmerge27.i, i64 0, i64 31
  br label %_Z21l_tapscript_minimalifmmmmm.exit

_Z21l_tapscript_minimalifmmmmm.exit:              ; preds = %entry, %if.end.i, %lor.end.i, %if.end11.i
  %retval.1.i = phi i64 [ 255, %entry ], [ 0, %if.end.i ], [ 51, %lor.end.i ], [ %spec.select.i, %if.end11.i ]
  ret i64 %retval.1.i
}

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
