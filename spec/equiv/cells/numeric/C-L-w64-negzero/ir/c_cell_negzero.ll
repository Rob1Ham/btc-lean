; ModuleID = '/tmp/opencode/wave64-integrate/spec/equiv/cells/numeric/C-L-w64-negzero/build/c_cell_negzero.bc'
source_filename = "/tmp/opencode/wave64-integrate/spec/equiv/cells/numeric/C-L-w64-negzero/c_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local i64 @cell_negzero(i8 noundef zeroext %b0, i8 noundef zeroext %b1, i8 noundef zeroext %b2, i8 noundef zeroext %b3, i32 noundef %len) local_unnamed_addr #0 {
entry:
  %vch = alloca [4 x i8], align 1
  %cmp = icmp ugt i32 %len, 4
  br i1 %cmp, label %return, label %if.end

if.end:                                           ; preds = %entry
  call void @llvm.lifetime.start.p0(i64 4, ptr nonnull %vch) #2
  store i8 %b0, ptr %vch, align 1
  %arrayinit.element = getelementptr inbounds nuw i8, ptr %vch, i64 1
  store i8 %b1, ptr %arrayinit.element, align 1
  %arrayinit.element1 = getelementptr inbounds nuw i8, ptr %vch, i64 2
  store i8 %b2, ptr %arrayinit.element1, align 1
  %arrayinit.element2 = getelementptr inbounds nuw i8, ptr %vch, i64 3
  store i8 %b3, ptr %arrayinit.element2, align 1
  %cmp.i = icmp eq i32 %len, 0
  br i1 %cmp.i, label %for.body.i13, label %if.then3.i

if.then3.i:                                       ; preds = %if.end
  %0 = load i8, ptr %vch, align 1
  %conv.i = zext i8 %0 to i64
  %cmp2.i.1.not = icmp eq i32 %len, 1
  %arrayidx.i.1 = getelementptr inbounds nuw i8, ptr %vch, i64 1
  %1 = load i8, ptr %arrayidx.i.1, align 1
  %conv.i.1 = zext i8 %1 to i64
  %shl.i9.1 = shl nuw nsw i64 %conv.i.1, 8
  %or.i.1 = select i1 %cmp2.i.1.not, i64 0, i64 %shl.i9.1
  %result.1.i.1 = or disjoint i64 %or.i.1, %conv.i
  %cmp2.i.2 = icmp ugt i32 %len, 2
  %arrayidx.i.2 = getelementptr inbounds nuw i8, ptr %vch, i64 2
  %2 = load i8, ptr %arrayidx.i.2, align 1
  %conv.i.2 = zext i8 %2 to i64
  %shl.i9.2 = shl nuw nsw i64 %conv.i.2, 16
  %or.i.2 = select i1 %cmp2.i.2, i64 %shl.i9.2, i64 0
  %result.1.i.2 = or disjoint i64 %result.1.i.1, %or.i.2
  %cmp2.i.3 = icmp eq i32 %len, 4
  %arrayidx.i.3 = getelementptr inbounds nuw i8, ptr %vch, i64 3
  %3 = load i8, ptr %arrayidx.i.3, align 1
  %conv.i.3 = zext i8 %3 to i64
  %shl.i9.3 = shl nuw nsw i64 %conv.i.3, 24
  %or.i.3 = select i1 %cmp2.i.3, i64 %shl.i9.3, i64 0
  %result.1.i.3 = or disjoint i64 %result.1.i.2, %or.i.3
  %sub.i = add nsw i32 %len, -1
  %idxprom5.i = zext nneg i32 %sub.i to i64
  %arrayidx6.i = getelementptr inbounds nuw i8, ptr %vch, i64 %idxprom5.i
  %4 = load i8, ptr %arrayidx6.i, align 1
  %cmp8.not.i = icmp sgt i8 %4, -1
  br i1 %cmp8.not.i, label %for.body.i13, label %if.then9.i

if.then9.i:                                       ; preds = %if.then3.i
  %mul11.i = shl nuw nsw i32 %sub.i, 3
  %sh_prom12.i = zext nneg i32 %mul11.i to i64
  %shl13.i = shl nuw nsw i64 128, %sh_prom12.i
  %not.i = xor i64 %shl13.i, -1
  %and14.i = and i64 %result.1.i.3, %not.i
  %sub15.i = sub nsw i64 0, %and14.i
  br label %for.body.i13

for.body.i13:                                     ; preds = %if.then9.i, %if.then3.i, %if.end
  %retval.1.i = phi i64 [ 0, %if.end ], [ %sub15.i, %if.then9.i ], [ %result.1.i.3, %if.then3.i ]
  %cmp1.i14.not = icmp eq i32 %len, 0
  %5 = load i8, ptr %vch, align 1
  %cmp2.not.i = icmp eq i8 %5, 0
  %or.cond = select i1 %cmp1.i14.not, i1 true, i1 %cmp2.not.i
  br i1 %or.cond, label %for.inc.i15, label %if.then.i

if.then.i:                                        ; preds = %for.inc.i15.2, %for.inc.i15.1, %for.inc.i15, %for.body.i13
  %i.0.i1123.lcssa.wide = phi i32 [ 0, %for.body.i13 ], [ 1, %for.inc.i15 ], [ 2, %for.inc.i15.1 ], [ 3, %for.inc.i15.2 ]
  %.lcssa = phi i8 [ %5, %for.body.i13 ], [ %7, %for.inc.i15 ], [ %8, %for.inc.i15.1 ], [ %9, %for.inc.i15.2 ]
  %sub.i19 = add nsw i32 %len, -1
  %cmp3.i = icmp ne i32 %i.0.i1123.lcssa.wide, %sub.i19
  %cmp8.i = icmp ne i8 %.lcssa, -128
  %or.cond.i.not = or i1 %cmp3.i, %cmp8.i
  %6 = select i1 %or.cond.i.not, i64 1099511627776, i64 0
  br label %_ZL17core_cast_to_boolPKhj.exit

for.inc.i15:                                      ; preds = %for.body.i13
  %cmp1.i14.1 = icmp ult i32 %len, 2
  %arrayidx.i18.1 = getelementptr inbounds nuw i8, ptr %vch, i64 1
  %7 = load i8, ptr %arrayidx.i18.1, align 1
  %cmp2.not.i.1 = icmp eq i8 %7, 0
  %or.cond28 = select i1 %cmp1.i14.1, i1 true, i1 %cmp2.not.i.1
  br i1 %or.cond28, label %for.inc.i15.1, label %if.then.i

for.inc.i15.1:                                    ; preds = %for.inc.i15
  %cmp1.i14.2 = icmp ult i32 %len, 3
  %arrayidx.i18.2 = getelementptr inbounds nuw i8, ptr %vch, i64 2
  %8 = load i8, ptr %arrayidx.i18.2, align 1
  %cmp2.not.i.2 = icmp eq i8 %8, 0
  %or.cond29 = select i1 %cmp1.i14.2, i1 true, i1 %cmp2.not.i.2
  br i1 %or.cond29, label %for.inc.i15.2, label %if.then.i

for.inc.i15.2:                                    ; preds = %for.inc.i15.1
  %cmp1.i14.3 = icmp ne i32 %len, 4
  %arrayidx.i18.3 = getelementptr inbounds nuw i8, ptr %vch, i64 3
  %9 = load i8, ptr %arrayidx.i18.3, align 1
  %cmp2.not.i.3 = icmp eq i8 %9, 0
  %or.cond30 = select i1 %cmp1.i14.3, i1 true, i1 %cmp2.not.i.3
  br i1 %or.cond30, label %_ZL17core_cast_to_boolPKhj.exit, label %if.then.i

_ZL17core_cast_to_boolPKhj.exit:                  ; preds = %for.inc.i15.2, %if.then.i
  %spec.select.i = phi i64 [ %6, %if.then.i ], [ 0, %for.inc.i15.2 ]
  %conv2.i = shl i64 %retval.1.i, 8
  %shl.i = and i64 %conv2.i, 1099511627520
  %or6.i = or disjoint i64 %spec.select.i, %shl.i
  call void @llvm.lifetime.end.p0(i64 4, ptr nonnull %vch) #2
  br label %return

return:                                           ; preds = %entry, %_ZL17core_cast_to_boolPKhj.exit
  %retval.0 = phi i64 [ %or6.i, %_ZL17core_cast_to_boolPKhj.exit ], [ 4, %entry ]
  ret i64 %retval.0
}

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(i64 immarg, ptr nocapture) #1

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(i64 immarg, ptr nocapture) #1

attributes #0 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #1 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #2 = { nounwind }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
