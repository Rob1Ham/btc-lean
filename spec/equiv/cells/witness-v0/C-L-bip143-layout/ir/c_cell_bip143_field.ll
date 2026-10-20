; ModuleID = '/tmp/opencode/equiv-pr/spec/equiv/cells/witness-v0/C-L-bip143-layout/build/c_cell_bip143_field.bc'
source_filename = "/tmp/opencode/equiv-pr/spec/equiv/cells/witness-v0/C-L-bip143-layout/src/c_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef i64 @cell_bip143_field(i64 noundef %field, i64 noundef %script_len) local_unnamed_addr #0 {
entry:
  switch i64 %field, label %if.end80 [
    i64 0, label %cleanup
    i64 1, label %if.then5
    i64 2, label %if.then14
    i64 3, label %if.then23
    i64 4, label %if.then32
    i64 5, label %if.then41
    i64 6, label %if.then50
    i64 7, label %if.then59
    i64 8, label %if.then68
    i64 9, label %if.then77
  ]

if.then5:                                         ; preds = %entry
  br label %cleanup

if.then14:                                        ; preds = %entry
  br label %cleanup

if.then23:                                        ; preds = %entry
  br label %cleanup

if.then32:                                        ; preds = %entry
  %add34 = add i64 %script_len, 26625
  br label %cleanup

if.then41:                                        ; preds = %entry
  %add36 = shl i64 %script_len, 8
  %add43 = add i64 %add36, 26888
  br label %cleanup

if.then50:                                        ; preds = %entry
  %add45 = shl i64 %script_len, 8
  %add52 = add i64 %add45, 28932
  br label %cleanup

if.then59:                                        ; preds = %entry
  %add54 = shl i64 %script_len, 8
  %add61 = add i64 %add54, 29984
  br label %cleanup

if.then68:                                        ; preds = %entry
  %add63 = shl i64 %script_len, 8
  %add70 = add i64 %add63, 38148
  br label %cleanup

if.then77:                                        ; preds = %entry
  %add72 = shl i64 %script_len, 8
  %add79 = add i64 %add72, 39172
  br label %cleanup

if.end80:                                         ; preds = %entry
  br label %cleanup

cleanup:                                          ; preds = %entry, %if.end80, %if.then77, %if.then68, %if.then59, %if.then50, %if.then41, %if.then32, %if.then23, %if.then14, %if.then5
  %retval.0 = phi i64 [ 1056, %if.then5 ], [ 9248, %if.then14 ], [ 17444, %if.then23 ], [ %add34, %if.then32 ], [ %add43, %if.then41 ], [ %add52, %if.then50 ], [ %add61, %if.then59 ], [ %add70, %if.then68 ], [ %add79, %if.then77 ], [ 0, %if.end80 ], [ 4, %entry ]
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
