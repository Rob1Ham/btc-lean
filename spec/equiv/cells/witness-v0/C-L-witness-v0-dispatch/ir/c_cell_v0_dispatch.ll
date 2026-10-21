; ModuleID = '/tmp/opencode/wave64-integrate/spec/equiv/cells/witness-v0/C-L-witness-v0-dispatch/build/c_cell_v0_dispatch.bc'
source_filename = "/tmp/opencode/wave64-integrate/spec/equiv/cells/witness-v0/C-L-witness-v0-dispatch/src/c_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local range(i64 2, 161) i64 @cell_v0_dispatch(i64 noundef %program_len, i64 noundef %witness_n, i64 noundef %hash_match) local_unnamed_addr #0 {
entry:
  switch i64 %program_len, label %return [
    i64 32, label %if.then
    i64 20, label %if.then8
  ]

if.then:                                          ; preds = %entry
  %cmp1 = icmp eq i64 %witness_n, 0
  br i1 %cmp1, label %return, label %if.end

if.end:                                           ; preds = %if.then
  %tobool.not = icmp eq i64 %hash_match, 0
  %. = select i1 %tobool.not, i64 160, i64 2
  br label %return

if.then8:                                         ; preds = %entry
  %cmp9.not = icmp eq i64 %witness_n, 2
  %.19 = select i1 %cmp9.not, i64 2, i64 160
  br label %return

return:                                           ; preds = %entry, %if.then8, %if.end, %if.then
  %retval.0 = phi i64 [ 156, %if.then ], [ %., %if.end ], [ %.19, %if.then8 ], [ 152, %entry ]
  ret i64 %retval.0
}

attributes #0 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
