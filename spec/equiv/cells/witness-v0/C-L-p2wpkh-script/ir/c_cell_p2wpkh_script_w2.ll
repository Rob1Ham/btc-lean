; ModuleID = '/tmp/opencode/wave16/14-witness-v0/spec/equiv/cells/witness-v0/C-L-p2wpkh-script/build/c_cell_p2wpkh_script_w2.bc'
source_filename = "/tmp/opencode/wave16/14-witness-v0/spec/equiv/cells/witness-v0/C-L-p2wpkh-script/src/c_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local range(i64 -8646911284551352320, -8574853690513424384) i64 @cell_p2wpkh_script_w2(i64 noundef %p0, i64 noundef %p1, i64 noundef %p2) local_unnamed_addr #0 {
entry:
  %shr37.i = lshr i64 %p1, 40
  %conv = and i64 %shr37.i, 255
  %0 = lshr i64 %p1, 40
  %shl = and i64 %0, 65280
  %1 = lshr i64 %p1, 40
  %shl6 = and i64 %1, 16711680
  %conv9 = shl i64 %p2, 24
  %shl10 = and i64 %conv9, 4278190080
  %2 = shl i64 %p2, 24
  %shl14 = and i64 %2, 1095216660480
  %3 = shl i64 %p2, 24
  %shl18 = and i64 %3, 280375465082880
  %4 = shl i64 %p2, 24
  %shl22 = and i64 %4, 71776119061217280
  %or = or disjoint i64 %conv, %shl
  %or7 = or disjoint i64 %or, %shl6
  %or11 = or disjoint i64 %or7, %shl10
  %or15 = or disjoint i64 %or11, %shl14
  %or19 = or disjoint i64 %or15, %shl18
  %or23 = or i64 %or19, %shl22
  %or27 = or i64 %or23, -8646911284551352320
  ret i64 %or27
}

attributes #0 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
