; ModuleID = '/tmp/opencode/wave64-integrate/spec/equiv/cells/policy-flags/C-L-const-scriptcode/build/c_leaf.bc'
source_filename = "/tmp/opencode/wave64-integrate/spec/equiv/cells/policy-flags/C-L-const-scriptcode/c_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef range(i64 0, 54) i64 @_Z26c_const_scriptcode_codesepmmm(i64 noundef %flags, i64 noundef %sigversion, i64 noundef %opcode) local_unnamed_addr #0 {
entry:
  %cmp = icmp ne i64 %opcode, 171
  %cmp1 = icmp ne i64 %sigversion, 0
  %or.cond.not5 = or i1 %cmp1, %cmp
  %and = and i64 %flags, 65536
  %cmp3.not = icmp eq i64 %and, 0
  %or.cond4 = or i1 %cmp3.not, %or.cond.not5
  %retval.0 = select i1 %or.cond4, i64 0, i64 53
  ret i64 %retval.0
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef range(i64 0, 256) i64 @_Z29c_const_scriptcode_finddeletemmm(i64 noundef %flags, i64 noundef %sigversion, i64 noundef %foundPositive) local_unnamed_addr #0 {
entry:
  %cmp = icmp ugt i64 %foundPositive, 1
  br i1 %cmp, label %return, label %if.end

if.end:                                           ; preds = %entry
  %cmp1 = icmp ne i64 %sigversion, 0
  %cmp2 = icmp eq i64 %foundPositive, 0
  %or.cond.not9 = or i1 %cmp1, %cmp2
  %and = and i64 %flags, 65536
  %cmp4.not = icmp eq i64 %and, 0
  %or.cond8 = or i1 %cmp4.not, %or.cond.not9
  %spec.select = select i1 %or.cond8, i64 0, i64 54
  br label %return

return:                                           ; preds = %if.end, %entry
  %retval.0 = phi i64 [ 255, %entry ], [ %spec.select, %if.end ]
  ret i64 %retval.0
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef range(i64 0, 54) i64 @cell_const_scriptcode_codesep(i64 noundef %flags, i64 noundef %sigversion, i64 noundef %opcode) local_unnamed_addr #0 {
entry:
  %cmp.i = icmp ne i64 %opcode, 171
  %cmp1.i = icmp ne i64 %sigversion, 0
  %or.cond.not5.i = or i1 %cmp1.i, %cmp.i
  %and.i = and i64 %flags, 65536
  %cmp3.not.i = icmp eq i64 %and.i, 0
  %or.cond4.i = or i1 %cmp3.not.i, %or.cond.not5.i
  %retval.0.i = select i1 %or.cond4.i, i64 0, i64 53
  ret i64 %retval.0.i
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local range(i64 0, 256) i64 @cell_const_scriptcode_finddelete(i64 noundef %flags, i64 noundef %sigversion, i64 noundef %foundPositive) local_unnamed_addr #0 {
entry:
  %cmp.i = icmp ugt i64 %foundPositive, 1
  br i1 %cmp.i, label %_Z29c_const_scriptcode_finddeletemmm.exit, label %if.end.i

if.end.i:                                         ; preds = %entry
  %cmp1.i = icmp ne i64 %sigversion, 0
  %cmp2.i = icmp eq i64 %foundPositive, 0
  %or.cond.not9.i = or i1 %cmp1.i, %cmp2.i
  %and.i = and i64 %flags, 65536
  %cmp4.not.i = icmp eq i64 %and.i, 0
  %or.cond8.i = or i1 %cmp4.not.i, %or.cond.not9.i
  %spec.select.i = select i1 %or.cond8.i, i64 0, i64 54
  br label %_Z29c_const_scriptcode_finddeletemmm.exit

_Z29c_const_scriptcode_finddeletemmm.exit:        ; preds = %entry, %if.end.i
  %retval.0.i = phi i64 [ 255, %entry ], [ %spec.select.i, %if.end.i ]
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
