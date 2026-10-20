; ModuleID = '/tmp/opencode/wave64/18-scr-083/spec/equiv/cells/numeric/C-L-w64-negzero/build/l_leaf.bc'
source_filename = "/tmp/opencode/wave64/18-scr-083/spec/equiv/cells/numeric/C-L-w64-negzero/l_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local range(i64 0, 2199023255552) i64 @cell_negzero(i8 noundef zeroext %b0, i8 noundef zeroext %b1, i8 noundef zeroext %b2, i8 noundef zeroext %b3, i32 noundef %len) local_unnamed_addr #0 {
entry:
  %vch.sroa.0 = alloca i8, align 1
  %vch.sroa.7 = alloca i8, align 1
  %vch.sroa.12 = alloca i8, align 1
  %vch.sroa.17 = alloca i8, align 1
  %cmp = icmp ugt i32 %len, 4
  br i1 %cmp, label %return, label %if.end

if.end:                                           ; preds = %entry
  call void @llvm.lifetime.start.p0(i64 1, ptr nonnull %vch.sroa.0)
  call void @llvm.lifetime.start.p0(i64 1, ptr nonnull %vch.sroa.7)
  call void @llvm.lifetime.start.p0(i64 1, ptr nonnull %vch.sroa.12)
  call void @llvm.lifetime.start.p0(i64 1, ptr nonnull %vch.sroa.17)
  store i8 %b0, ptr %vch.sroa.0, align 1
  store i8 %b1, ptr %vch.sroa.7, align 1
  store i8 %b2, ptr %vch.sroa.12, align 1
  store i8 %b3, ptr %vch.sroa.17, align 1
  switch i32 %len, label %if.then2.i [
    i32 0, label %_ZL13lean_setVchBEPKhj.exit
    i32 1, label %if.end3.i
  ]

if.then2.i:                                       ; preds = %if.end
  %conv.i = zext i8 %b0 to i32
  br label %if.end3.i

if.end3.i:                                        ; preds = %if.then2.i, %if.end
  %lower.0.i = phi i32 [ %conv.i, %if.then2.i ], [ 0, %if.end ]
  %cmp4.i = icmp samesign ugt i32 %len, 2
  %conv7.i = zext i8 %b1 to i32
  %shl.i9 = shl nuw nsw i32 %conv7.i, 8
  %or8.i = select i1 %cmp4.i, i32 %shl.i9, i32 0
  %cmp10.i = icmp eq i32 %len, 4
  %conv13.i = zext i8 %b2 to i32
  %shl14.i = shl nuw nsw i32 %conv13.i, 16
  %or15.i = select i1 %cmp10.i, i32 %shl14.i, i32 0
  %lower.1.i = or disjoint i32 %or15.i, %or8.i
  %lower.2.i = or disjoint i32 %lower.1.i, %lower.0.i
  %cmp17.i = icmp eq i32 %len, 1
  br i1 %cmp17.i, label %cond.end30.i, label %cond.false.i

cond.false.i:                                     ; preds = %if.end3.i
  switch i32 %len, label %cond.false26.i [
    i32 2, label %cond.end30.i
    i32 3, label %cond.true24.i
  ]

cond.true24.i:                                    ; preds = %cond.false.i
  br label %cond.end30.i

cond.false26.i:                                   ; preds = %cond.false.i
  br label %cond.end30.i

cond.end30.i:                                     ; preds = %cond.false.i, %cond.false26.i, %cond.true24.i, %if.end3.i
  %cond31.in.i = phi ptr [ %vch.sroa.12, %cond.true24.i ], [ %vch.sroa.17, %cond.false26.i ], [ %vch.sroa.0, %if.end3.i ], [ %vch.sroa.7, %cond.false.i ]
  %cond31.i = load i8, ptr %cond31.in.i, align 1
  %conv32.i = zext i8 %cond31.i to i32
  br i1 %cmp17.i, label %cond.end43.i, label %cond.false35.i

cond.false35.i:                                   ; preds = %cond.end30.i
  %cmp36.i = icmp eq i32 %len, 2
  br i1 %cmp36.i, label %cond.end43.i, label %cond.false38.i

cond.false38.i:                                   ; preds = %cond.false35.i
  %cmp39.i = icmp eq i32 %len, 3
  %cond40.i = select i1 %cmp39.i, i32 65536, i32 16777216
  br label %cond.end43.i

cond.end43.i:                                     ; preds = %cond.false38.i, %cond.false35.i, %cond.end30.i
  %cond44.i = phi i32 [ 1, %cond.end30.i ], [ %cond40.i, %cond.false38.i ], [ 256, %cond.false35.i ]
  %cmp45.i = icmp sgt i8 %cond31.i, -1
  br i1 %cmp45.i, label %if.then46.i, label %if.end48.i

if.then46.i:                                      ; preds = %cond.end43.i
  %mul.i = mul nuw nsw i32 %cond44.i, %conv32.i
  %add.i = add nuw i32 %mul.i, %lower.2.i
  %conv47.i = zext i32 %add.i to i64
  br label %_ZL13lean_setVchBEPKhj.exit

if.end48.i:                                       ; preds = %cond.end43.i
  %sub.i = add nsw i32 %conv32.i, -128
  %mul49.i = mul nuw nsw i32 %cond44.i, %sub.i
  %add50.i = add nuw nsw i32 %mul49.i, %lower.2.i
  %conv51.i = zext nneg i32 %add50.i to i64
  %sub52.i = sub nsw i64 0, %conv51.i
  br label %_ZL13lean_setVchBEPKhj.exit

_ZL13lean_setVchBEPKhj.exit:                      ; preds = %if.end, %if.then46.i, %if.end48.i
  %retval.1.i = phi i64 [ 0, %if.end ], [ %conv47.i, %if.then46.i ], [ %sub52.i, %if.end48.i ]
  switch i32 %len, label %land.lhs.true.i [
    i32 0, label %_ZL19lean_castToBoolListPKhj.exit
    i32 1, label %if.end4.i
  ]

land.lhs.true.i:                                  ; preds = %_ZL13lean_setVchBEPKhj.exit
  %cmp2.not.i = icmp ne i8 %b0, 0
  %spec.select.i = zext i1 %cmp2.not.i to i8
  br label %if.end4.i

if.end4.i:                                        ; preds = %land.lhs.true.i, %_ZL13lean_setVchBEPKhj.exit
  %lowerAny.0.i = phi i8 [ 0, %_ZL13lean_setVchBEPKhj.exit ], [ %spec.select.i, %land.lhs.true.i ]
  %cmp5.i = icmp samesign ugt i32 %len, 2
  %cmp9.not.i = icmp eq i8 %b1, 0
  %spec.select50.i = select i1 %cmp9.not.i, i8 %lowerAny.0.i, i8 1
  %lowerAny.1.i = select i1 %cmp5.i, i8 %spec.select50.i, i8 %lowerAny.0.i
  %cmp12.i = icmp eq i32 %len, 4
  %cmp16.not.i = icmp eq i8 %b2, 0
  %spec.select51.i = select i1 %cmp16.not.i, i8 %lowerAny.1.i, i8 1
  %lowerAny.2.i = select i1 %cmp12.i, i8 %spec.select51.i, i8 %lowerAny.1.i
  switch i32 %len, label %cond.false28.i [
    i32 1, label %cond.end32.i
    i32 2, label %cond.true22.i
    i32 3, label %cond.true26.i
  ]

cond.true22.i:                                    ; preds = %if.end4.i
  br label %cond.end32.i

cond.true26.i:                                    ; preds = %if.end4.i
  br label %cond.end32.i

cond.false28.i:                                   ; preds = %if.end4.i
  br label %cond.end32.i

cond.end32.i:                                     ; preds = %cond.false28.i, %cond.true26.i, %cond.true22.i, %if.end4.i
  %cond33.in.i = phi ptr [ %vch.sroa.7, %cond.true22.i ], [ %vch.sroa.12, %cond.true26.i ], [ %vch.sroa.17, %cond.false28.i ], [ %vch.sroa.0, %if.end4.i ]
  %loadedv.i = trunc nuw i8 %lowerAny.2.i to i1
  br i1 %loadedv.i, label %_ZL19lean_castToBoolListPKhj.exit, label %lor.rhs.i

lor.rhs.i:                                        ; preds = %cond.end32.i
  %cond33.i = load i8, ptr %cond33.in.i, align 1
  %0 = and i8 %cond33.i, 127
  %.not = icmp eq i8 %0, 0
  %1 = select i1 %.not, i64 0, i64 1099511627776
  br label %_ZL19lean_castToBoolListPKhj.exit

_ZL19lean_castToBoolListPKhj.exit:                ; preds = %_ZL13lean_setVchBEPKhj.exit, %cond.end32.i, %lor.rhs.i
  %retval.0.i = phi i64 [ 0, %_ZL13lean_setVchBEPKhj.exit ], [ 1099511627776, %cond.end32.i ], [ %1, %lor.rhs.i ]
  %conv2.i = shl nsw i64 %retval.1.i, 8
  %shl.i = and i64 %conv2.i, 1099511627520
  %or6.i = or disjoint i64 %retval.0.i, %shl.i
  call void @llvm.lifetime.end.p0(i64 1, ptr nonnull %vch.sroa.0)
  call void @llvm.lifetime.end.p0(i64 1, ptr nonnull %vch.sroa.7)
  call void @llvm.lifetime.end.p0(i64 1, ptr nonnull %vch.sroa.12)
  call void @llvm.lifetime.end.p0(i64 1, ptr nonnull %vch.sroa.17)
  br label %return

return:                                           ; preds = %entry, %_ZL19lean_castToBoolListPKhj.exit
  %retval.0 = phi i64 [ %or6.i, %_ZL19lean_castToBoolListPKhj.exit ], [ 4, %entry ]
  ret i64 %retval.0
}

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(i64 immarg, ptr nocapture) #1

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(i64 immarg, ptr nocapture) #1

attributes #0 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #1 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
