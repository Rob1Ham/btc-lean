; ModuleID = 'build/l_cell_bip143_preimage_e253.bc'
source_filename = "src/l_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress noinline optnone uwtable
define dso_local i64 @cell_bip143_preimage_e253(ptr noundef %out, i32 noundef %version, ptr noundef %hashPrevouts, ptr noundef %hashSequence, ptr noundef %txid, ptr noundef %vout, ptr noundef %script, i64 noundef %amount, i32 noundef %nSequence, ptr noundef %hashOutputs, i32 noundef %nLockTime, i32 noundef %nHashType) local_unnamed_addr #0 {
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
  %0 = load ptr, ptr %out.addr, align 8
  %add.ptr = getelementptr inbounds nuw i8, ptr %0, i64 0
  %1 = load i32, ptr %version.addr, align 4
  br label %for.cond.i35

for.cond.i35:                                     ; preds = %for.body.i38, %entry
  %i.0.i36 = phi i32 [ 0, %entry ], [ %inc.i44, %for.body.i38 ]
  %cmp.i37 = icmp samesign ult i32 %i.0.i36, 4
  br i1 %cmp.i37, label %for.body.i38, label %_ZL15cell_loop_u32lePhj.exit45

for.body.i38:                                     ; preds = %for.cond.i35
  %mul.i39 = shl nuw nsw i32 %i.0.i36, 3
  %shr.i40 = lshr i32 %1, %mul.i39
  %conv.i41 = trunc i32 %shr.i40 to i8
  %idxprom.i42 = zext nneg i32 %i.0.i36 to i64
  %arrayidx.i43 = getelementptr inbounds nuw i8, ptr %add.ptr, i64 %idxprom.i42
  store i8 %conv.i41, ptr %arrayidx.i43, align 1
  %inc.i44 = add nuw nsw i32 %i.0.i36, 1
  br label %for.cond.i35, !llvm.loop !5

_ZL15cell_loop_u32lePhj.exit45:                   ; preds = %for.cond.i35
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
  store i8 -3, ptr %arrayidx, align 1
  %11 = load ptr, ptr %out.addr, align 8
  %arrayidx5 = getelementptr inbounds nuw i8, ptr %11, i64 105
  store i8 -3, ptr %arrayidx5, align 1
  %12 = load ptr, ptr %out.addr, align 8
  %arrayidx6 = getelementptr inbounds nuw i8, ptr %12, i64 106
  store i8 0, ptr %arrayidx6, align 1
  %13 = load ptr, ptr %out.addr, align 8
  %add.ptr7 = getelementptr inbounds nuw i8, ptr %13, i64 107
  %14 = load ptr, ptr %script.addr, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %add.ptr7, ptr align 1 %14, i64 253, i1 false)
  %15 = load ptr, ptr %out.addr, align 8
  %add.ptr8 = getelementptr inbounds nuw i8, ptr %15, i64 360
  %16 = load i64, ptr %amount.addr, align 8
  br label %for.cond.i46

for.cond.i46:                                     ; preds = %for.body.i49, %_ZL15cell_loop_u32lePhj.exit45
  %i.0.i47 = phi i32 [ 0, %_ZL15cell_loop_u32lePhj.exit45 ], [ %inc.i55, %for.body.i49 ]
  %cmp.i48 = icmp samesign ult i32 %i.0.i47, 8
  br i1 %cmp.i48, label %for.body.i49, label %_ZL15cell_loop_u64lePhm.exit

for.body.i49:                                     ; preds = %for.cond.i46
  %mul.i50 = shl nuw nsw i32 %i.0.i47, 3
  %sh_prom.i = zext nneg i32 %mul.i50 to i64
  %shr.i51 = lshr i64 %16, %sh_prom.i
  %conv.i52 = trunc i64 %shr.i51 to i8
  %idxprom.i53 = zext nneg i32 %i.0.i47 to i64
  %arrayidx.i54 = getelementptr inbounds nuw i8, ptr %add.ptr8, i64 %idxprom.i53
  store i8 %conv.i52, ptr %arrayidx.i54, align 1
  %inc.i55 = add nuw nsw i32 %i.0.i47, 1
  br label %for.cond.i46, !llvm.loop !8

_ZL15cell_loop_u64lePhm.exit:                     ; preds = %for.cond.i46
  %17 = load ptr, ptr %out.addr, align 8
  %add.ptr9 = getelementptr inbounds nuw i8, ptr %17, i64 368
  %18 = load i32, ptr %nSequence.addr, align 4
  br label %for.cond.i24

for.cond.i24:                                     ; preds = %for.body.i27, %_ZL15cell_loop_u64lePhm.exit
  %i.0.i25 = phi i32 [ 0, %_ZL15cell_loop_u64lePhm.exit ], [ %inc.i33, %for.body.i27 ]
  %cmp.i26 = icmp samesign ult i32 %i.0.i25, 4
  br i1 %cmp.i26, label %for.body.i27, label %_ZL15cell_loop_u32lePhj.exit34

for.body.i27:                                     ; preds = %for.cond.i24
  %mul.i28 = shl nuw nsw i32 %i.0.i25, 3
  %shr.i29 = lshr i32 %18, %mul.i28
  %conv.i30 = trunc i32 %shr.i29 to i8
  %idxprom.i31 = zext nneg i32 %i.0.i25 to i64
  %arrayidx.i32 = getelementptr inbounds nuw i8, ptr %add.ptr9, i64 %idxprom.i31
  store i8 %conv.i30, ptr %arrayidx.i32, align 1
  %inc.i33 = add nuw nsw i32 %i.0.i25, 1
  br label %for.cond.i24, !llvm.loop !5

_ZL15cell_loop_u32lePhj.exit34:                   ; preds = %for.cond.i24
  %19 = load ptr, ptr %out.addr, align 8
  %add.ptr10 = getelementptr inbounds nuw i8, ptr %19, i64 372
  %20 = load ptr, ptr %hashOutputs.addr, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %add.ptr10, ptr align 1 %20, i64 32, i1 false)
  %21 = load ptr, ptr %out.addr, align 8
  %add.ptr11 = getelementptr inbounds nuw i8, ptr %21, i64 404
  %22 = load i32, ptr %nLockTime.addr, align 4
  br label %for.cond.i13

for.cond.i13:                                     ; preds = %for.body.i16, %_ZL15cell_loop_u32lePhj.exit34
  %i.0.i14 = phi i32 [ 0, %_ZL15cell_loop_u32lePhj.exit34 ], [ %inc.i22, %for.body.i16 ]
  %cmp.i15 = icmp samesign ult i32 %i.0.i14, 4
  br i1 %cmp.i15, label %for.body.i16, label %_ZL15cell_loop_u32lePhj.exit23

for.body.i16:                                     ; preds = %for.cond.i13
  %mul.i17 = shl nuw nsw i32 %i.0.i14, 3
  %shr.i18 = lshr i32 %22, %mul.i17
  %conv.i19 = trunc i32 %shr.i18 to i8
  %idxprom.i20 = zext nneg i32 %i.0.i14 to i64
  %arrayidx.i21 = getelementptr inbounds nuw i8, ptr %add.ptr11, i64 %idxprom.i20
  store i8 %conv.i19, ptr %arrayidx.i21, align 1
  %inc.i22 = add nuw nsw i32 %i.0.i14, 1
  br label %for.cond.i13, !llvm.loop !5

_ZL15cell_loop_u32lePhj.exit23:                   ; preds = %for.cond.i13
  %23 = load ptr, ptr %out.addr, align 8
  %add.ptr12 = getelementptr inbounds nuw i8, ptr %23, i64 408
  %24 = load i32, ptr %nHashType.addr, align 4
  br label %for.cond.i

for.cond.i:                                       ; preds = %for.body.i, %_ZL15cell_loop_u32lePhj.exit23
  %i.0.i = phi i32 [ 0, %_ZL15cell_loop_u32lePhj.exit23 ], [ %inc.i, %for.body.i ]
  %cmp.i = icmp samesign ult i32 %i.0.i, 4
  br i1 %cmp.i, label %for.body.i, label %_ZL15cell_loop_u32lePhj.exit

for.body.i:                                       ; preds = %for.cond.i
  %mul.i = shl nuw nsw i32 %i.0.i, 3
  %shr.i = lshr i32 %24, %mul.i
  %conv.i = trunc i32 %shr.i to i8
  %idxprom.i = zext nneg i32 %i.0.i to i64
  %arrayidx.i = getelementptr inbounds nuw i8, ptr %add.ptr12, i64 %idxprom.i
  store i8 %conv.i, ptr %arrayidx.i, align 1
  %inc.i = add nuw nsw i32 %i.0.i, 1
  br label %for.cond.i, !llvm.loop !5

_ZL15cell_loop_u32lePhj.exit:                     ; preds = %for.cond.i
  ret i64 412
}

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: readwrite)
declare void @llvm.memcpy.p0.p0.i64(ptr noalias nocapture writeonly, ptr noalias nocapture readonly, i64, i1 immarg) #1

attributes #0 = { mustprogress noinline optnone uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #1 = { nocallback nofree nounwind willreturn memory(argmem: readwrite) }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
!5 = distinct !{!5, !6, !7}
!6 = !{!"llvm.loop.mustprogress"}
!7 = !{!"llvm.loop.unroll.disable"}
!8 = distinct !{!8, !6, !7}
