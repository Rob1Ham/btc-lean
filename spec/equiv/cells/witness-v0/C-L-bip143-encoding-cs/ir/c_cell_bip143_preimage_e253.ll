; ModuleID = 'build/c_cell_bip143_preimage_e253.bc'
source_filename = "src/c_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(i64 immarg, ptr nocapture) #0

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(i64 immarg, ptr nocapture) #0

; Function Attrs: mustprogress noinline optnone uwtable
define dso_local i64 @cell_bip143_preimage_e253(ptr noundef %out, i32 noundef %version, ptr noundef %hashPrevouts, ptr noundef %hashSequence, ptr noundef %txid, ptr noundef %vout, ptr noundef %script, i64 noundef %amount, i32 noundef %nSequence, ptr noundef %hashOutputs, i32 noundef %nLockTime, i32 noundef %nHashType) local_unnamed_addr #1 {
entry:
  %out.addr = alloca ptr, align 8
  %version.addr = alloca i32, align 4
  %hashPrevouts.addr = alloca ptr, align 8
  %hashSequence.addr = alloca ptr, align 8
  %txid.addr = alloca ptr, align 8
  %vout.addr = alloca ptr, align 8
  %script.addr = alloca ptr, align 8
  %amount.addr = alloca i64, align 8
  %nSequence.addr = alloca i32, align 4
  %hashOutputs.addr = alloca ptr, align 8
  %nLockTime.addr = alloca i32, align 4
  %nHashType.addr = alloca i32, align 4
  %off = alloca i64, align 8
  store ptr %out, ptr %out.addr, align 8
  store i32 %version, ptr %version.addr, align 4
  store ptr %hashPrevouts, ptr %hashPrevouts.addr, align 8
  store ptr %hashSequence, ptr %hashSequence.addr, align 8
  store ptr %txid, ptr %txid.addr, align 8
  store ptr %vout, ptr %vout.addr, align 8
  store ptr %script, ptr %script.addr, align 8
  store i64 %amount, ptr %amount.addr, align 8
  store i32 %nSequence, ptr %nSequence.addr, align 4
  store ptr %hashOutputs, ptr %hashOutputs.addr, align 8
  store i32 %nLockTime, ptr %nLockTime.addr, align 4
  store i32 %nHashType, ptr %nHashType.addr, align 4
  call void @llvm.lifetime.start.p0(i64 8, ptr %off) #3
  store i64 0, ptr %off, align 8
  %0 = load ptr, ptr %out.addr, align 8
  %1 = load i64, ptr %off, align 8
  %add.ptr = getelementptr inbounds nuw i8, ptr %0, i64 %1
  %2 = load i32, ptr %version.addr, align 4
  %conv.i46 = trunc i32 %2 to i8
  store i8 %conv.i46, ptr %add.ptr, align 1
  %shr.i47 = lshr i32 %2, 8
  %conv2.i48 = trunc i32 %shr.i47 to i8
  %arrayidx3.i49 = getelementptr inbounds nuw i8, ptr %add.ptr, i64 1
  store i8 %conv2.i48, ptr %arrayidx3.i49, align 1
  %shr4.i50 = lshr i32 %2, 16
  %conv6.i51 = trunc i32 %shr4.i50 to i8
  %arrayidx7.i52 = getelementptr inbounds nuw i8, ptr %add.ptr, i64 2
  store i8 %conv6.i51, ptr %arrayidx7.i52, align 1
  %shr8.i53 = lshr i32 %2, 24
  %conv10.i54 = trunc nuw i32 %shr8.i53 to i8
  %arrayidx11.i55 = getelementptr inbounds nuw i8, ptr %add.ptr, i64 3
  store i8 %conv10.i54, ptr %arrayidx11.i55, align 1
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
  store i8 -3, ptr %arrayidx, align 1
  %22 = load ptr, ptr %out.addr, align 8
  %23 = load i64, ptr %off, align 8
  %add9 = add i64 %23, 1
  %arrayidx10 = getelementptr inbounds nuw i8, ptr %22, i64 %add9
  store i8 -3, ptr %arrayidx10, align 1
  %24 = load ptr, ptr %out.addr, align 8
  %25 = load i64, ptr %off, align 8
  %add11 = add i64 %25, 2
  %arrayidx12 = getelementptr inbounds nuw i8, ptr %24, i64 %add11
  store i8 0, ptr %arrayidx12, align 1
  %26 = load i64, ptr %off, align 8
  %add13 = add i64 %26, 3
  store i64 %add13, ptr %off, align 8
  %27 = load ptr, ptr %out.addr, align 8
  %28 = load i64, ptr %off, align 8
  %add.ptr14 = getelementptr inbounds nuw i8, ptr %27, i64 %28
  %29 = load ptr, ptr %script.addr, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %add.ptr14, ptr align 1 %29, i64 253, i1 false)
  %30 = load i64, ptr %off, align 8
  %add15 = add i64 %30, 253
  store i64 %add15, ptr %off, align 8
  %31 = load ptr, ptr %out.addr, align 8
  %32 = load i64, ptr %off, align 8
  %add.ptr16 = getelementptr inbounds nuw i8, ptr %31, i64 %32
  %33 = load i64, ptr %amount.addr, align 8
  %conv.i56 = trunc i64 %33 to i8
  store i8 %conv.i56, ptr %add.ptr16, align 1
  %shr.i57 = lshr i64 %33, 8
  %conv2.i58 = trunc i64 %shr.i57 to i8
  %arrayidx3.i59 = getelementptr inbounds nuw i8, ptr %add.ptr16, i64 1
  store i8 %conv2.i58, ptr %arrayidx3.i59, align 1
  %shr4.i60 = lshr i64 %33, 16
  %conv6.i61 = trunc i64 %shr4.i60 to i8
  %arrayidx7.i62 = getelementptr inbounds nuw i8, ptr %add.ptr16, i64 2
  store i8 %conv6.i61, ptr %arrayidx7.i62, align 1
  %shr8.i63 = lshr i64 %33, 24
  %conv10.i64 = trunc i64 %shr8.i63 to i8
  %arrayidx11.i65 = getelementptr inbounds nuw i8, ptr %add.ptr16, i64 3
  store i8 %conv10.i64, ptr %arrayidx11.i65, align 1
  %shr12.i = lshr i64 %33, 32
  %conv14.i = trunc i64 %shr12.i to i8
  %arrayidx15.i = getelementptr inbounds nuw i8, ptr %add.ptr16, i64 4
  store i8 %conv14.i, ptr %arrayidx15.i, align 1
  %shr16.i = lshr i64 %33, 40
  %conv18.i = trunc i64 %shr16.i to i8
  %arrayidx19.i = getelementptr inbounds nuw i8, ptr %add.ptr16, i64 5
  store i8 %conv18.i, ptr %arrayidx19.i, align 1
  %shr20.i = lshr i64 %33, 48
  %conv22.i = trunc i64 %shr20.i to i8
  %arrayidx23.i = getelementptr inbounds nuw i8, ptr %add.ptr16, i64 6
  store i8 %conv22.i, ptr %arrayidx23.i, align 1
  %shr24.i = lshr i64 %33, 56
  %conv26.i = trunc nuw i64 %shr24.i to i8
  %arrayidx27.i = getelementptr inbounds nuw i8, ptr %add.ptr16, i64 7
  store i8 %conv26.i, ptr %arrayidx27.i, align 1
  %34 = load i64, ptr %off, align 8
  %add17 = add i64 %34, 8
  store i64 %add17, ptr %off, align 8
  %35 = load ptr, ptr %out.addr, align 8
  %36 = load i64, ptr %off, align 8
  %add.ptr18 = getelementptr inbounds nuw i8, ptr %35, i64 %36
  %37 = load i32, ptr %nSequence.addr, align 4
  %conv.i36 = trunc i32 %37 to i8
  store i8 %conv.i36, ptr %add.ptr18, align 1
  %shr.i37 = lshr i32 %37, 8
  %conv2.i38 = trunc i32 %shr.i37 to i8
  %arrayidx3.i39 = getelementptr inbounds nuw i8, ptr %add.ptr18, i64 1
  store i8 %conv2.i38, ptr %arrayidx3.i39, align 1
  %shr4.i40 = lshr i32 %37, 16
  %conv6.i41 = trunc i32 %shr4.i40 to i8
  %arrayidx7.i42 = getelementptr inbounds nuw i8, ptr %add.ptr18, i64 2
  store i8 %conv6.i41, ptr %arrayidx7.i42, align 1
  %shr8.i43 = lshr i32 %37, 24
  %conv10.i44 = trunc nuw i32 %shr8.i43 to i8
  %arrayidx11.i45 = getelementptr inbounds nuw i8, ptr %add.ptr18, i64 3
  store i8 %conv10.i44, ptr %arrayidx11.i45, align 1
  %38 = load i64, ptr %off, align 8
  %add19 = add i64 %38, 4
  store i64 %add19, ptr %off, align 8
  %39 = load ptr, ptr %out.addr, align 8
  %40 = load i64, ptr %off, align 8
  %add.ptr20 = getelementptr inbounds nuw i8, ptr %39, i64 %40
  %41 = load ptr, ptr %hashOutputs.addr, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %add.ptr20, ptr align 1 %41, i64 32, i1 false)
  %42 = load i64, ptr %off, align 8
  %add21 = add i64 %42, 32
  store i64 %add21, ptr %off, align 8
  %43 = load ptr, ptr %out.addr, align 8
  %44 = load i64, ptr %off, align 8
  %add.ptr22 = getelementptr inbounds nuw i8, ptr %43, i64 %44
  %45 = load i32, ptr %nLockTime.addr, align 4
  %conv.i26 = trunc i32 %45 to i8
  store i8 %conv.i26, ptr %add.ptr22, align 1
  %shr.i27 = lshr i32 %45, 8
  %conv2.i28 = trunc i32 %shr.i27 to i8
  %arrayidx3.i29 = getelementptr inbounds nuw i8, ptr %add.ptr22, i64 1
  store i8 %conv2.i28, ptr %arrayidx3.i29, align 1
  %shr4.i30 = lshr i32 %45, 16
  %conv6.i31 = trunc i32 %shr4.i30 to i8
  %arrayidx7.i32 = getelementptr inbounds nuw i8, ptr %add.ptr22, i64 2
  store i8 %conv6.i31, ptr %arrayidx7.i32, align 1
  %shr8.i33 = lshr i32 %45, 24
  %conv10.i34 = trunc nuw i32 %shr8.i33 to i8
  %arrayidx11.i35 = getelementptr inbounds nuw i8, ptr %add.ptr22, i64 3
  store i8 %conv10.i34, ptr %arrayidx11.i35, align 1
  %46 = load i64, ptr %off, align 8
  %add23 = add i64 %46, 4
  store i64 %add23, ptr %off, align 8
  %47 = load ptr, ptr %out.addr, align 8
  %48 = load i64, ptr %off, align 8
  %add.ptr24 = getelementptr inbounds nuw i8, ptr %47, i64 %48
  %49 = load i32, ptr %nHashType.addr, align 4
  %conv.i = trunc i32 %49 to i8
  store i8 %conv.i, ptr %add.ptr24, align 1
  %shr.i = lshr i32 %49, 8
  %conv2.i = trunc i32 %shr.i to i8
  %arrayidx3.i = getelementptr inbounds nuw i8, ptr %add.ptr24, i64 1
  store i8 %conv2.i, ptr %arrayidx3.i, align 1
  %shr4.i = lshr i32 %49, 16
  %conv6.i = trunc i32 %shr4.i to i8
  %arrayidx7.i = getelementptr inbounds nuw i8, ptr %add.ptr24, i64 2
  store i8 %conv6.i, ptr %arrayidx7.i, align 1
  %shr8.i = lshr i32 %49, 24
  %conv10.i = trunc nuw i32 %shr8.i to i8
  %arrayidx11.i = getelementptr inbounds nuw i8, ptr %add.ptr24, i64 3
  store i8 %conv10.i, ptr %arrayidx11.i, align 1
  %50 = load i64, ptr %off, align 8
  %add25 = add i64 %50, 4
  store i64 %add25, ptr %off, align 8
  %51 = load i64, ptr %off, align 8
  call void @llvm.lifetime.end.p0(i64 8, ptr %off) #3
  ret i64 %51
}

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: readwrite)
declare void @llvm.memcpy.p0.p0.i64(ptr noalias nocapture writeonly, ptr noalias nocapture readonly, i64, i1 immarg) #2

attributes #0 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #1 = { mustprogress noinline optnone uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #2 = { nocallback nofree nounwind willreturn memory(argmem: readwrite) }
attributes #3 = { nounwind }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
