; ModuleID = '/tmp/opencode/wave16/14-witness-v0/spec/equiv/cells/witness-v0/C-L-p2wpkh-script/build/l_cell_p2wpkh_script.bc'
source_filename = "/tmp/opencode/wave16/14-witness-v0/spec/equiv/cells/witness-v0/C-L-p2wpkh-script/src/l_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: readwrite) uwtable
define dso_local void @cell_p2wpkh_script(ptr nocapture noundef readonly %program, ptr nocapture noundef writeonly initializes((0, 25)) %out) local_unnamed_addr #0 {
entry:
  %arrayidx = getelementptr inbounds nuw i8, ptr %out, i64 23
  store i8 -120, ptr %arrayidx, align 1
  %arrayidx1 = getelementptr inbounds nuw i8, ptr %out, i64 24
  store i8 -84, ptr %arrayidx1, align 1
  %arrayidx2 = getelementptr inbounds nuw i8, ptr %program, i64 19
  %0 = load i8, ptr %arrayidx2, align 1
  %arrayidx3 = getelementptr inbounds nuw i8, ptr %out, i64 22
  store i8 %0, ptr %arrayidx3, align 1
  %arrayidx4 = getelementptr inbounds nuw i8, ptr %program, i64 18
  %1 = load i8, ptr %arrayidx4, align 1
  %arrayidx5 = getelementptr inbounds nuw i8, ptr %out, i64 21
  store i8 %1, ptr %arrayidx5, align 1
  %arrayidx6 = getelementptr inbounds nuw i8, ptr %program, i64 17
  %2 = load i8, ptr %arrayidx6, align 1
  %arrayidx7 = getelementptr inbounds nuw i8, ptr %out, i64 20
  store i8 %2, ptr %arrayidx7, align 1
  %arrayidx8 = getelementptr inbounds nuw i8, ptr %program, i64 16
  %3 = load i8, ptr %arrayidx8, align 1
  %arrayidx9 = getelementptr inbounds nuw i8, ptr %out, i64 19
  store i8 %3, ptr %arrayidx9, align 1
  %arrayidx10 = getelementptr inbounds nuw i8, ptr %program, i64 15
  %4 = load i8, ptr %arrayidx10, align 1
  %arrayidx11 = getelementptr inbounds nuw i8, ptr %out, i64 18
  store i8 %4, ptr %arrayidx11, align 1
  %arrayidx12 = getelementptr inbounds nuw i8, ptr %program, i64 14
  %5 = load i8, ptr %arrayidx12, align 1
  %arrayidx13 = getelementptr inbounds nuw i8, ptr %out, i64 17
  store i8 %5, ptr %arrayidx13, align 1
  %arrayidx14 = getelementptr inbounds nuw i8, ptr %program, i64 13
  %6 = load i8, ptr %arrayidx14, align 1
  %arrayidx15 = getelementptr inbounds nuw i8, ptr %out, i64 16
  store i8 %6, ptr %arrayidx15, align 1
  %arrayidx16 = getelementptr inbounds nuw i8, ptr %program, i64 12
  %7 = load i8, ptr %arrayidx16, align 1
  %arrayidx17 = getelementptr inbounds nuw i8, ptr %out, i64 15
  store i8 %7, ptr %arrayidx17, align 1
  %arrayidx18 = getelementptr inbounds nuw i8, ptr %program, i64 11
  %8 = load i8, ptr %arrayidx18, align 1
  %arrayidx19 = getelementptr inbounds nuw i8, ptr %out, i64 14
  store i8 %8, ptr %arrayidx19, align 1
  %arrayidx20 = getelementptr inbounds nuw i8, ptr %program, i64 10
  %9 = load i8, ptr %arrayidx20, align 1
  %arrayidx21 = getelementptr inbounds nuw i8, ptr %out, i64 13
  store i8 %9, ptr %arrayidx21, align 1
  %arrayidx22 = getelementptr inbounds nuw i8, ptr %program, i64 9
  %10 = load i8, ptr %arrayidx22, align 1
  %arrayidx23 = getelementptr inbounds nuw i8, ptr %out, i64 12
  store i8 %10, ptr %arrayidx23, align 1
  %arrayidx24 = getelementptr inbounds nuw i8, ptr %program, i64 8
  %11 = load i8, ptr %arrayidx24, align 1
  %arrayidx25 = getelementptr inbounds nuw i8, ptr %out, i64 11
  store i8 %11, ptr %arrayidx25, align 1
  %arrayidx26 = getelementptr inbounds nuw i8, ptr %program, i64 7
  %12 = load i8, ptr %arrayidx26, align 1
  %arrayidx27 = getelementptr inbounds nuw i8, ptr %out, i64 10
  store i8 %12, ptr %arrayidx27, align 1
  %arrayidx28 = getelementptr inbounds nuw i8, ptr %program, i64 6
  %13 = load i8, ptr %arrayidx28, align 1
  %arrayidx29 = getelementptr inbounds nuw i8, ptr %out, i64 9
  store i8 %13, ptr %arrayidx29, align 1
  %arrayidx30 = getelementptr inbounds nuw i8, ptr %program, i64 5
  %14 = load i8, ptr %arrayidx30, align 1
  %arrayidx31 = getelementptr inbounds nuw i8, ptr %out, i64 8
  store i8 %14, ptr %arrayidx31, align 1
  %arrayidx32 = getelementptr inbounds nuw i8, ptr %program, i64 4
  %15 = load i8, ptr %arrayidx32, align 1
  %arrayidx33 = getelementptr inbounds nuw i8, ptr %out, i64 7
  store i8 %15, ptr %arrayidx33, align 1
  %arrayidx34 = getelementptr inbounds nuw i8, ptr %program, i64 3
  %16 = load i8, ptr %arrayidx34, align 1
  %arrayidx35 = getelementptr inbounds nuw i8, ptr %out, i64 6
  store i8 %16, ptr %arrayidx35, align 1
  %arrayidx36 = getelementptr inbounds nuw i8, ptr %program, i64 2
  %17 = load i8, ptr %arrayidx36, align 1
  %arrayidx37 = getelementptr inbounds nuw i8, ptr %out, i64 5
  store i8 %17, ptr %arrayidx37, align 1
  %arrayidx38 = getelementptr inbounds nuw i8, ptr %program, i64 1
  %18 = load i8, ptr %arrayidx38, align 1
  %arrayidx39 = getelementptr inbounds nuw i8, ptr %out, i64 4
  store i8 %18, ptr %arrayidx39, align 1
  %19 = load i8, ptr %program, align 1
  %arrayidx41 = getelementptr inbounds nuw i8, ptr %out, i64 3
  store i8 %19, ptr %arrayidx41, align 1
  %arrayidx42 = getelementptr inbounds nuw i8, ptr %out, i64 2
  store i8 20, ptr %arrayidx42, align 1
  %arrayidx43 = getelementptr inbounds nuw i8, ptr %out, i64 1
  store i8 -87, ptr %arrayidx43, align 1
  store i8 118, ptr %out, align 1
  ret void
}

attributes #0 = { mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: readwrite) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
