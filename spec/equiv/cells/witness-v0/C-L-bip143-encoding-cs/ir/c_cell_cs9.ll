; ModuleID = 'build/c_cell_cs9.bc'
source_filename = "src/c_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress noinline optnone uwtable
define dso_local i64 @cell_cs9(ptr noundef %out, i64 noundef %n) local_unnamed_addr #0 {
entry:
  %out.addr = alloca ptr, align 8
  %n.addr = alloca i64, align 8
  store ptr %out, ptr %out.addr, align 8
  store i64 %n, ptr %n.addr, align 8
  %0 = load ptr, ptr %out.addr, align 8
  %arrayidx = getelementptr inbounds nuw i8, ptr %0, i64 0
  store i8 -1, ptr %arrayidx, align 1
  %1 = load ptr, ptr %out.addr, align 8
  %add.ptr = getelementptr inbounds nuw i8, ptr %1, i64 1
  %2 = load i64, ptr %n.addr, align 8
  %conv.i = trunc i64 %2 to i8
  store i8 %conv.i, ptr %add.ptr, align 1
  %shr.i = lshr i64 %2, 8
  %conv2.i = trunc i64 %shr.i to i8
  %arrayidx3.i = getelementptr inbounds nuw i8, ptr %add.ptr, i64 1
  store i8 %conv2.i, ptr %arrayidx3.i, align 1
  %shr4.i = lshr i64 %2, 16
  %conv6.i = trunc i64 %shr4.i to i8
  %arrayidx7.i = getelementptr inbounds nuw i8, ptr %add.ptr, i64 2
  store i8 %conv6.i, ptr %arrayidx7.i, align 1
  %shr8.i = lshr i64 %2, 24
  %conv10.i = trunc i64 %shr8.i to i8
  %arrayidx11.i = getelementptr inbounds nuw i8, ptr %add.ptr, i64 3
  store i8 %conv10.i, ptr %arrayidx11.i, align 1
  %shr12.i = lshr i64 %2, 32
  %conv14.i = trunc i64 %shr12.i to i8
  %arrayidx15.i = getelementptr inbounds nuw i8, ptr %add.ptr, i64 4
  store i8 %conv14.i, ptr %arrayidx15.i, align 1
  %shr16.i = lshr i64 %2, 40
  %conv18.i = trunc i64 %shr16.i to i8
  %arrayidx19.i = getelementptr inbounds nuw i8, ptr %add.ptr, i64 5
  store i8 %conv18.i, ptr %arrayidx19.i, align 1
  %shr20.i = lshr i64 %2, 48
  %conv22.i = trunc i64 %shr20.i to i8
  %arrayidx23.i = getelementptr inbounds nuw i8, ptr %add.ptr, i64 6
  store i8 %conv22.i, ptr %arrayidx23.i, align 1
  %shr24.i = lshr i64 %2, 56
  %conv26.i = trunc nuw i64 %shr24.i to i8
  %arrayidx27.i = getelementptr inbounds nuw i8, ptr %add.ptr, i64 7
  store i8 %conv26.i, ptr %arrayidx27.i, align 1
  ret i64 9
}

attributes #0 = { mustprogress noinline optnone uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
