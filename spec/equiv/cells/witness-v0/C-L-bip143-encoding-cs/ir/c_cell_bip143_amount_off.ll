; ModuleID = 'build/c_cell_bip143_amount_off.bc'
source_filename = "src/c_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress noinline nounwind optnone uwtable
define dso_local i64 @cell_bip143_amount_off(i64 noundef %script_len) local_unnamed_addr #0 {
entry:
  %script_len.addr = alloca i64, align 8
  %w = alloca i64, align 8
  store i64 %script_len, ptr %script_len.addr, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr %w) #2
  %0 = load i64, ptr %script_len.addr, align 8
  %cmp = icmp ult i64 %0, 253
  br i1 %cmp, label %if.then, label %if.else

if.then:                                          ; preds = %entry
  store i64 1, ptr %w, align 8
  br label %if.end8

if.else:                                          ; preds = %entry
  %1 = load i64, ptr %script_len.addr, align 8
  %cmp1 = icmp ule i64 %1, 65535
  br i1 %cmp1, label %if.then2, label %if.else3

if.then2:                                         ; preds = %if.else
  store i64 3, ptr %w, align 8
  br label %if.end7

if.else3:                                         ; preds = %if.else
  %2 = load i64, ptr %script_len.addr, align 8
  %cmp4 = icmp ule i64 %2, 4294967295
  br i1 %cmp4, label %if.then5, label %if.else6

if.then5:                                         ; preds = %if.else3
  store i64 5, ptr %w, align 8
  br label %if.end

if.else6:                                         ; preds = %if.else3
  store i64 9, ptr %w, align 8
  br label %if.end

if.end:                                           ; preds = %if.else6, %if.then5
  br label %if.end7

if.end7:                                          ; preds = %if.end, %if.then2
  br label %if.end8

if.end8:                                          ; preds = %if.end7, %if.then
  %3 = load i64, ptr %script_len.addr, align 8
  %add = add i64 105, %3
  %4 = load i64, ptr %w, align 8
  %sub = sub i64 %4, 1
  %add9 = add i64 %add, %sub
  call void @llvm.lifetime.end.p0(i64 8, ptr %w) #2
  ret i64 %add9
}

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(i64 immarg, ptr nocapture) #1

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(i64 immarg, ptr nocapture) #1

attributes #0 = { mustprogress noinline nounwind optnone uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #1 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #2 = { nounwind }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
