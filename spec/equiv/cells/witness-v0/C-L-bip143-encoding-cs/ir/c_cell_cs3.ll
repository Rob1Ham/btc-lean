; ModuleID = 'build/c_cell_cs3.bc'
source_filename = "src/c_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress noinline optnone uwtable
define dso_local i64 @cell_cs3(ptr noundef %out, i64 noundef %n) local_unnamed_addr #0 {
entry:
  %out.addr = alloca ptr, align 8
  %n.addr = alloca i64, align 8
  store ptr %out, ptr %out.addr, align 8
  store i64 %n, ptr %n.addr, align 8
  %0 = load ptr, ptr %out.addr, align 8
  %arrayidx = getelementptr inbounds nuw i8, ptr %0, i64 0
  store i8 -3, ptr %arrayidx, align 1
  %1 = load ptr, ptr %out.addr, align 8
  %add.ptr = getelementptr inbounds nuw i8, ptr %1, i64 1
  %2 = load i64, ptr %n.addr, align 8
  %conv = trunc i64 %2 to i16
  %conv1.i = trunc i16 %conv to i8
  store i8 %conv1.i, ptr %add.ptr, align 1
  %3 = lshr i16 %conv, 8
  %conv4.i = trunc nuw i16 %3 to i8
  %arrayidx5.i = getelementptr inbounds nuw i8, ptr %add.ptr, i64 1
  store i8 %conv4.i, ptr %arrayidx5.i, align 1
  ret i64 3
}

attributes #0 = { mustprogress noinline optnone uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
