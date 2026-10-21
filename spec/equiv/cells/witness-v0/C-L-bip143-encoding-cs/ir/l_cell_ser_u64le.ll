; ModuleID = 'build/l_cell_ser_u64le.bc'
source_filename = "src/l_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress noinline optnone uwtable
define dso_local i64 @cell_ser_u64le(ptr noundef %out, i64 noundef %v) local_unnamed_addr #0 {
entry:
  %out.addr = alloca ptr, align 8
  %v.addr = alloca i64, align 8
  store ptr %out, ptr %out.addr, align 8
  store i64 %v, ptr %v.addr, align 8
  %0 = load ptr, ptr %out.addr, align 8
  %1 = load i64, ptr %v.addr, align 8
  br label %for.cond.i

for.cond.i:                                       ; preds = %for.body.i, %entry
  %i.0.i = phi i32 [ 0, %entry ], [ %inc.i, %for.body.i ]
  %cmp.i = icmp samesign ult i32 %i.0.i, 8
  br i1 %cmp.i, label %for.body.i, label %_ZL15cell_loop_u64lePhm.exit

for.body.i:                                       ; preds = %for.cond.i
  %mul.i = shl nuw nsw i32 %i.0.i, 3
  %sh_prom.i = zext nneg i32 %mul.i to i64
  %shr.i = lshr i64 %1, %sh_prom.i
  %conv.i = trunc i64 %shr.i to i8
  %idxprom.i = zext nneg i32 %i.0.i to i64
  %arrayidx.i = getelementptr inbounds nuw i8, ptr %0, i64 %idxprom.i
  store i8 %conv.i, ptr %arrayidx.i, align 1
  %inc.i = add nuw nsw i32 %i.0.i, 1
  br label %for.cond.i, !llvm.loop !5

_ZL15cell_loop_u64lePhm.exit:                     ; preds = %for.cond.i
  ret i64 8
}

attributes #0 = { mustprogress noinline optnone uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }

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
