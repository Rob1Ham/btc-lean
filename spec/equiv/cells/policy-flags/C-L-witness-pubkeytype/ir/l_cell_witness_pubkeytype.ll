; ModuleID = '/tmp/opencode/equiv-pr/spec/equiv/cells/policy-flags/C-L-witness-pubkeytype/build/l_cell_witness_pubkeytype.bc'
source_filename = "/tmp/opencode/equiv-pr/spec/equiv/cells/policy-flags/C-L-witness-pubkeytype/l_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local range(i64 0, 256) i64 @cell_witness_pubkeytype(i64 noundef %flags, i64 noundef %sigversion, i64 noundef %pkLen, i64 noundef %pk0Arg) local_unnamed_addr #0 {
entry:
  %cmp.i = icmp ugt i64 %sigversion, 2
  br i1 %cmp.i, label %_Z20l_witness_pubkeytypemmmm.exit, label %if.end.i

if.end.i:                                         ; preds = %entry
  %cmp1.i = icmp eq i64 %pkLen, 33
  %0 = and i64 %pk0Arg, 254
  %1 = icmp eq i64 %0, 2
  %2 = and i1 %cmp1.i, %1
  %and.i = and i64 %flags, 32768
  %cmp4.i = icmp eq i64 %and.i, 0
  %cmp6.i = icmp ne i64 %sigversion, 1
  %or.cond.not15.i = or i1 %cmp4.i, %cmp6.i
  %brmerge.i = or i1 %or.cond.not15.i, %2
  %retval.0.i = select i1 %brmerge.i, i64 0, i64 44
  br label %_Z20l_witness_pubkeytypemmmm.exit

_Z20l_witness_pubkeytypemmmm.exit:                ; preds = %entry, %if.end.i
  %retval.1.i = phi i64 [ %retval.0.i, %if.end.i ], [ 255, %entry ]
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
