; ModuleID = '/tmp/opencode/wave64-integrate/spec/equiv/cells/witness-v0/C-L-bip143-preimage-order/build/l_cell_bip143_preimage_l75.bc'
source_filename = "/tmp/opencode/wave64-integrate/spec/equiv/cells/witness-v0/C-L-bip143-preimage-order/src/l_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: readwrite)
declare void @llvm.memcpy.p0.p0.i64(ptr noalias nocapture writeonly, ptr noalias nocapture readonly, i64, i1 immarg) #0

; Function Attrs: mustprogress noinline nounwind optnone uwtable
define dso_local i64 @cell_bip143_preimage_l75(ptr noundef %out, ptr noundef %version, ptr noundef %hashPrevouts, ptr noundef %hashSequence, ptr noundef %txid, ptr noundef %vout, ptr noundef %script, ptr noundef %amount, ptr noundef %nSequence, ptr noundef %hashOutputs, ptr noundef %nLockTime, ptr noundef %nHashType) local_unnamed_addr #1 {
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
  %0 = load ptr, ptr %out.addr, align 8
  %add.ptr = getelementptr inbounds nuw i8, ptr %0, i64 0
  %1 = load ptr, ptr %version.addr, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %add.ptr, ptr align 1 %1, i64 4, i1 false)
  %2 = load ptr, ptr %out.addr, align 8
  %add.ptr1 = getelementptr inbounds nuw i8, ptr %2, i64 4
  %3 = load ptr, ptr %hashPrevouts.addr, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %add.ptr1, ptr align 1 %3, i64 32, i1 false)
  %4 = load ptr, ptr %out.addr, align 8
  %add.ptr2 = getelementptr inbounds nuw i8, ptr %4, i64 36
  %5 = load ptr, ptr %hashSequence.addr, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %add.ptr2, ptr align 1 %5, i64 32, i1 false)
  %6 = load ptr, ptr %out.addr, align 8
  %add.ptr3 = getelementptr inbounds nuw i8, ptr %6, i64 68
  %7 = load ptr, ptr %txid.addr, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %add.ptr3, ptr align 1 %7, i64 32, i1 false)
  %8 = load ptr, ptr %out.addr, align 8
  %add.ptr4 = getelementptr inbounds nuw i8, ptr %8, i64 100
  %9 = load ptr, ptr %vout.addr, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %add.ptr4, ptr align 1 %9, i64 4, i1 false)
  %10 = load ptr, ptr %out.addr, align 8
  %arrayidx = getelementptr inbounds nuw i8, ptr %10, i64 104
  store i8 75, ptr %arrayidx, align 1
  %11 = load ptr, ptr %out.addr, align 8
  %add.ptr5 = getelementptr inbounds nuw i8, ptr %11, i64 105
  %12 = load ptr, ptr %script.addr, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %add.ptr5, ptr align 1 %12, i64 75, i1 false)
  %13 = load ptr, ptr %out.addr, align 8
  %add.ptr6 = getelementptr inbounds nuw i8, ptr %13, i64 180
  %14 = load ptr, ptr %amount.addr, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %add.ptr6, ptr align 1 %14, i64 8, i1 false)
  %15 = load ptr, ptr %out.addr, align 8
  %add.ptr7 = getelementptr inbounds nuw i8, ptr %15, i64 188
  %16 = load ptr, ptr %nSequence.addr, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %add.ptr7, ptr align 1 %16, i64 4, i1 false)
  %17 = load ptr, ptr %out.addr, align 8
  %add.ptr8 = getelementptr inbounds nuw i8, ptr %17, i64 192
  %18 = load ptr, ptr %hashOutputs.addr, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %add.ptr8, ptr align 1 %18, i64 32, i1 false)
  %19 = load ptr, ptr %out.addr, align 8
  %add.ptr9 = getelementptr inbounds nuw i8, ptr %19, i64 224
  %20 = load ptr, ptr %nLockTime.addr, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %add.ptr9, ptr align 1 %20, i64 4, i1 false)
  %21 = load ptr, ptr %out.addr, align 8
  %add.ptr10 = getelementptr inbounds nuw i8, ptr %21, i64 228
  %22 = load ptr, ptr %nHashType.addr, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %add.ptr10, ptr align 1 %22, i64 4, i1 false)
  ret i64 232
}

attributes #0 = { nocallback nofree nounwind willreturn memory(argmem: readwrite) }
attributes #1 = { mustprogress noinline nounwind optnone uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
