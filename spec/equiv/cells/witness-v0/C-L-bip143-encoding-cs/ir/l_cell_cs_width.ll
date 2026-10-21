; ModuleID = 'build/l_cell_cs_width.bc'
source_filename = "src/l_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress noinline nounwind optnone uwtable
define dso_local i64 @cell_cs_width(i64 noundef %n) local_unnamed_addr #0 {
entry:
  %retval = alloca i64, align 8
  %n.addr = alloca i64, align 8
  store i64 %n, ptr %n.addr, align 8
  %0 = load i64, ptr %n.addr, align 8
  %cmp = icmp ule i64 %0, 4294967295
  br i1 %cmp, label %if.then, label %if.end4

if.then:                                          ; preds = %entry
  %1 = load i64, ptr %n.addr, align 8
  %cmp1 = icmp ule i64 %1, 65535
  br i1 %cmp1, label %if.then2, label %if.end

if.then2:                                         ; preds = %if.then
  %2 = load i64, ptr %n.addr, align 8
  %cmp3 = icmp ult i64 %2, 253
  %3 = zext i1 %cmp3 to i64
  %cond = select i1 %cmp3, i32 1, i32 3
  %conv = zext nneg i32 %cond to i64
  store i64 %conv, ptr %retval, align 8
  br label %return

if.end:                                           ; preds = %if.then
  store i64 5, ptr %retval, align 8
  br label %return

if.end4:                                          ; preds = %entry
  store i64 9, ptr %retval, align 8
  br label %return

return:                                           ; preds = %if.end4, %if.end, %if.then2
  %4 = load i64, ptr %retval, align 8
  ret i64 %4
}

attributes #0 = { mustprogress noinline nounwind optnone uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
