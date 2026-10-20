; ModuleID = '/tmp/opencode/equiv-pr/spec/equiv/cells/policy-flags/C-L-lows-policy/build/c_cell_lows_policy.bc'
source_filename = "/tmp/opencode/equiv-pr/spec/equiv/cells/policy-flags/C-L-lows-policy/c_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef range(i64 0, 28) i64 @cell_lows_policy(i64 noundef %flags, i64 noundef %rByte, i64 noundef %s0, i64 noundef %s1, i64 noundef %s2, i64 noundef %s3) local_unnamed_addr #0 {
entry:
  %and.i.i = and i64 %rByte, 128
  %cmp.i = icmp eq i64 %and.i.i, 0
  %0 = icmp sgt i64 %s0, 36028797018963967
  %spec.select.i = and i1 %cmp.i, %0
  br i1 %spec.select.i, label %land.rhs7.i, label %_Z13c_lows_policymmmmmm.exit

land.rhs7.i:                                      ; preds = %entry
  %cmp.not.i.i = icmp eq i64 %s0, 9223372036854775807
  br i1 %cmp.not.i.i, label %if.end.i.i, label %if.then.i.i

if.then.i.i:                                      ; preds = %land.rhs7.i
  %cmp1.i.i = icmp ult i64 %s0, 9223372036854775807
  br label %_Z13c_lows_policymmmmmm.exit

if.end.i.i:                                       ; preds = %land.rhs7.i
  %cmp2.not.i.i = icmp eq i64 %s1, -1
  br i1 %cmp2.not.i.i, label %if.end5.i.i, label %_Z13c_lows_policymmmmmm.exit

if.end5.i.i:                                      ; preds = %if.end.i.i
  %cmp6.not.i.i = icmp eq i64 %s2, 6725966010171805725
  br i1 %cmp6.not.i.i, label %if.end9.i.i, label %if.then7.i.i

if.then7.i.i:                                     ; preds = %if.end5.i.i
  %cmp8.i.i = icmp ult i64 %s2, 6725966010171805725
  br label %_Z13c_lows_policymmmmmm.exit

if.end9.i.i:                                      ; preds = %if.end5.i.i
  %cmp10.i.i = icmp ult i64 %s3, -2312264954237214559
  br label %_Z13c_lows_policymmmmmm.exit

_Z13c_lows_policymmmmmm.exit:                     ; preds = %entry, %if.then.i.i, %if.end.i.i, %if.then7.i.i, %if.end9.i.i
  %1 = phi i1 [ false, %entry ], [ %cmp1.i.i, %if.then.i.i ], [ %cmp8.i.i, %if.then7.i.i ], [ %cmp10.i.i, %if.end9.i.i ], [ true, %if.end.i.i ]
  %and11.i = and i64 %flags, 14
  %cmp12.not.i = icmp eq i64 %and11.i, 0
  %brmerge.i = or i1 %cmp12.not.i, %spec.select.i
  %and15.i = and i64 %flags, 8
  %cmp16.not.i = icmp eq i64 %and15.i, 0
  %brmerge30.i = or i1 %cmp16.not.i, %1
  %spec.select31.i = select i1 %brmerge30.i, i64 0, i64 27
  %retval.0.i = select i1 %brmerge.i, i64 %spec.select31.i, i64 24
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
