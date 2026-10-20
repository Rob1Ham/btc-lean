; ModuleID = '/tmp/opencode/equiv-pr/spec/equiv/cells/witness-v0/C-L-bip143-layout/build/l_cell_bip143_field.bc'
source_filename = "/tmp/opencode/equiv-pr/spec/equiv/cells/witness-v0/C-L-bip143-layout/src/l_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef i64 @cell_bip143_field(i64 noundef %field, i64 noundef %script_len) local_unnamed_addr #0 {
entry:
  switch i64 %field, label %if.end42 [
    i64 0, label %return
    i64 1, label %if.then2
    i64 2, label %if.then5
    i64 3, label %if.then8
    i64 4, label %if.then11
    i64 5, label %if.then15
    i64 6, label %if.then20
    i64 7, label %if.then26
    i64 8, label %if.then32
    i64 9, label %if.then38
  ]

if.then2:                                         ; preds = %entry
  br label %return

if.then5:                                         ; preds = %entry
  br label %return

if.then8:                                         ; preds = %entry
  br label %return

if.then11:                                        ; preds = %entry
  %add12 = add i64 %script_len, 26625
  br label %return

if.then15:                                        ; preds = %entry
  %add16 = shl i64 %script_len, 8
  %add17 = add i64 %add16, 26888
  br label %return

if.then20:                                        ; preds = %entry
  %add21 = shl i64 %script_len, 8
  %add23 = add i64 %add21, 28932
  br label %return

if.then26:                                        ; preds = %entry
  %add27 = shl i64 %script_len, 8
  %add29 = add i64 %add27, 29984
  br label %return

if.then32:                                        ; preds = %entry
  %add33 = shl i64 %script_len, 8
  %add35 = add i64 %add33, 38148
  br label %return

if.then38:                                        ; preds = %entry
  %add39 = shl i64 %script_len, 8
  %add41 = add i64 %add39, 39172
  br label %return

if.end42:                                         ; preds = %entry
  br label %return

return:                                           ; preds = %entry, %if.end42, %if.then38, %if.then32, %if.then26, %if.then20, %if.then15, %if.then11, %if.then8, %if.then5, %if.then2
  %retval.0 = phi i64 [ 1056, %if.then2 ], [ 9248, %if.then5 ], [ 17444, %if.then8 ], [ %add12, %if.then11 ], [ %add17, %if.then15 ], [ %add23, %if.then20 ], [ %add29, %if.then26 ], [ %add35, %if.then32 ], [ %add41, %if.then38 ], [ 0, %if.end42 ], [ 4, %entry ]
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
