; ModuleID = '/tmp/opencode/wave64-integrate/spec/equiv/cells/witness-v0/C-L-bip143-hashoutputs-single-oor/build/l_cell_bip143_hashoutputs_mode.bc'
source_filename = "/tmp/opencode/wave64-integrate/spec/equiv/cells/witness-v0/C-L-bip143-hashoutputs-single-oor/src/l_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local range(i64 0, 4) i64 @cell_bip143_hashoutputs_mode(i64 noundef %hash_type, i64 noundef %n_in, i64 noundef %vout_len) local_unnamed_addr #0 {
entry:
  %rem = and i64 %hash_type, 31
  switch i64 %rem, label %if.end6 [
    i64 3, label %if.then
    i64 2, label %cleanup
  ]

if.then:                                          ; preds = %entry
  %cmp1 = icmp ult i64 %n_in, %vout_len
  %. = select i1 %cmp1, i64 3, i64 0
  br label %cleanup

if.end6:                                          ; preds = %entry
  br label %cleanup

cleanup:                                          ; preds = %entry, %if.then, %if.end6
  %retval.0 = phi i64 [ 2, %if.end6 ], [ %., %if.then ], [ 0, %entry ]
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
