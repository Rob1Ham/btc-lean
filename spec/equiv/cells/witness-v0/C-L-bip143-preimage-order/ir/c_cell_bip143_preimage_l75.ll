; ModuleID = '/tmp/opencode/wave64-integrate/spec/equiv/cells/witness-v0/C-L-bip143-preimage-order/build/c_cell_bip143_preimage_l75.bc'
source_filename = "/tmp/opencode/wave64-integrate/spec/equiv/cells/witness-v0/C-L-bip143-preimage-order/src/c_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(i64 immarg, ptr nocapture) #0

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: readwrite)
declare void @llvm.memcpy.p0.p0.i64(ptr noalias nocapture writeonly, ptr noalias nocapture readonly, i64, i1 immarg) #1

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(i64 immarg, ptr nocapture) #0

; Function Attrs: mustprogress noinline nounwind optnone uwtable
define dso_local i64 @cell_bip143_preimage_l75(ptr noundef %out, ptr noundef %version, ptr noundef %hashPrevouts, ptr noundef %hashSequence, ptr noundef %txid, ptr noundef %vout, ptr noundef %script, ptr noundef %amount, ptr noundef %nSequence, ptr noundef %hashOutputs, ptr noundef %nLockTime, ptr noundef %nHashType) local_unnamed_addr #2 {
entry:
  %out.addr = alloca ptr, align 8
  %version.addr = alloca ptr, align 8
  %hashPrevouts.addr = alloca ptr, align 8
  %hashSequence.addr = alloca ptr, align 8
  %txid.addr = alloca ptr, align 8
  %vout.addr = alloca ptr, align 8
  %script.addr = alloca ptr, align 8
  %amount.addr = alloca ptr, align 8
  %nSequence.addr = alloca ptr, align 8
  %hashOutputs.addr = alloca ptr, align 8
  %nLockTime.addr = alloca ptr, align 8
  %nHashType.addr = alloca ptr, align 8
  %off = alloca i64, align 8
  store ptr %out, ptr %out.addr, align 8
  store ptr %version, ptr %version.addr, align 8
  store ptr %hashPrevouts, ptr %hashPrevouts.addr, align 8
  store ptr %hashSequence, ptr %hashSequence.addr, align 8
  store ptr %txid, ptr %txid.addr, align 8
  store ptr %vout, ptr %vout.addr, align 8
  store ptr %script, ptr %script.addr, align 8
  store ptr %amount, ptr %amount.addr, align 8
  store ptr %nSequence, ptr %nSequence.addr, align 8
  store ptr %hashOutputs, ptr %hashOutputs.addr, align 8
  store ptr %nLockTime, ptr %nLockTime.addr, align 8
  store ptr %nHashType, ptr %nHashType.addr, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr %off) #3
  store i64 0, ptr %off, align 8
  %0 = load ptr, ptr %out.addr, align 8
  %1 = load i64, ptr %off, align 8
  %add.ptr = getelementptr inbounds nuw i8, ptr %0, i64 %1
  %2 = load ptr, ptr %version.addr, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %add.ptr, ptr align 1 %2, i64 4, i1 false)
  %3 = load i64, ptr %off, align 8
  %add = add i64 %3, 4
  store i64 %add, ptr %off, align 8
  %4 = load ptr, ptr %out.addr, align 8
  %5 = load i64, ptr %off, align 8
  %add.ptr1 = getelementptr inbounds nuw i8, ptr %4, i64 %5
  %6 = load ptr, ptr %hashPrevouts.addr, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %add.ptr1, ptr align 1 %6, i64 32, i1 false)
  %7 = load i64, ptr %off, align 8
  %add2 = add i64 %7, 32
  store i64 %add2, ptr %off, align 8
  %8 = load ptr, ptr %out.addr, align 8
  %9 = load i64, ptr %off, align 8
  %add.ptr3 = getelementptr inbounds nuw i8, ptr %8, i64 %9
  %10 = load ptr, ptr %hashSequence.addr, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %add.ptr3, ptr align 1 %10, i64 32, i1 false)
  %11 = load i64, ptr %off, align 8
  %add4 = add i64 %11, 32
  store i64 %add4, ptr %off, align 8
  %12 = load ptr, ptr %out.addr, align 8
  %13 = load i64, ptr %off, align 8
  %add.ptr5 = getelementptr inbounds nuw i8, ptr %12, i64 %13
  %14 = load ptr, ptr %txid.addr, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %add.ptr5, ptr align 1 %14, i64 32, i1 false)
  %15 = load i64, ptr %off, align 8
  %add6 = add i64 %15, 32
  store i64 %add6, ptr %off, align 8
  %16 = load ptr, ptr %out.addr, align 8
  %17 = load i64, ptr %off, align 8
  %add.ptr7 = getelementptr inbounds nuw i8, ptr %16, i64 %17
  %18 = load ptr, ptr %vout.addr, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %add.ptr7, ptr align 1 %18, i64 4, i1 false)
  %19 = load i64, ptr %off, align 8
  %add8 = add i64 %19, 4
  store i64 %add8, ptr %off, align 8
  %20 = load ptr, ptr %out.addr, align 8
  %21 = load i64, ptr %off, align 8
  %arrayidx = getelementptr inbounds nuw i8, ptr %20, i64 %21
  store i8 75, ptr %arrayidx, align 1
  %22 = load i64, ptr %off, align 8
  %add9 = add i64 %22, 1
  store i64 %add9, ptr %off, align 8
  %23 = load ptr, ptr %out.addr, align 8
  %24 = load i64, ptr %off, align 8
  %add.ptr10 = getelementptr inbounds nuw i8, ptr %23, i64 %24
  %25 = load ptr, ptr %script.addr, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %add.ptr10, ptr align 1 %25, i64 75, i1 false)
  %26 = load i64, ptr %off, align 8
  %add11 = add i64 %26, 75
  store i64 %add11, ptr %off, align 8
  %27 = load ptr, ptr %out.addr, align 8
  %28 = load i64, ptr %off, align 8
  %add.ptr12 = getelementptr inbounds nuw i8, ptr %27, i64 %28
  %29 = load ptr, ptr %amount.addr, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %add.ptr12, ptr align 1 %29, i64 8, i1 false)
  %30 = load i64, ptr %off, align 8
  %add13 = add i64 %30, 8
  store i64 %add13, ptr %off, align 8
  %31 = load ptr, ptr %out.addr, align 8
  %32 = load i64, ptr %off, align 8
  %add.ptr14 = getelementptr inbounds nuw i8, ptr %31, i64 %32
  %33 = load ptr, ptr %nSequence.addr, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %add.ptr14, ptr align 1 %33, i64 4, i1 false)
  %34 = load i64, ptr %off, align 8
  %add15 = add i64 %34, 4
  store i64 %add15, ptr %off, align 8
  %35 = load ptr, ptr %out.addr, align 8
  %36 = load i64, ptr %off, align 8
  %add.ptr16 = getelementptr inbounds nuw i8, ptr %35, i64 %36
  %37 = load ptr, ptr %hashOutputs.addr, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %add.ptr16, ptr align 1 %37, i64 32, i1 false)
  %38 = load i64, ptr %off, align 8
  %add17 = add i64 %38, 32
  store i64 %add17, ptr %off, align 8
  %39 = load ptr, ptr %out.addr, align 8
  %40 = load i64, ptr %off, align 8
  %add.ptr18 = getelementptr inbounds nuw i8, ptr %39, i64 %40
  %41 = load ptr, ptr %nLockTime.addr, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %add.ptr18, ptr align 1 %41, i64 4, i1 false)
  %42 = load i64, ptr %off, align 8
  %add19 = add i64 %42, 4
  store i64 %add19, ptr %off, align 8
  %43 = load ptr, ptr %out.addr, align 8
  %44 = load i64, ptr %off, align 8
  %add.ptr20 = getelementptr inbounds nuw i8, ptr %43, i64 %44
  %45 = load ptr, ptr %nHashType.addr, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %add.ptr20, ptr align 1 %45, i64 4, i1 false)
  %46 = load i64, ptr %off, align 8
  %add21 = add i64 %46, 4
  store i64 %add21, ptr %off, align 8
  %47 = load i64, ptr %off, align 8
  call void @llvm.lifetime.end.p0(i64 8, ptr %off) #3
  ret i64 %47
}

attributes #0 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #1 = { nocallback nofree nounwind willreturn memory(argmem: readwrite) }
attributes #2 = { mustprogress noinline nounwind optnone uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #3 = { nounwind }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
