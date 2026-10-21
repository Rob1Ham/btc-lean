; ModuleID = 'probe.b43d45f84f48362-cgu.0'
source_filename = "probe.b43d45f84f48362-cgu.0"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

; Function Attrs: nounwind nonlazybind uwtable
define noundef i64 @probe_sum(i32 noundef %n) unnamed_addr #0 personality ptr @rust_eh_personality {
start:
  %.sink2.i.i = zext i32 %n to i64
  %_33.0.i.i.i = shl nuw nsw i64 %.sink2.i.i, 2
  %0 = icmp eq i32 %n, 0
  br i1 %0, label %"_ZN4core3ptr47drop_in_place$LT$alloc..vec..Vec$LT$u32$GT$$GT$17ha57a76337bb5b3e1E.exit", label %_RNvXs_NtCslNYArtu3iFV_5alloc5allocNtB4_6GlobalNtNtCsgEmfK2I1SDS_4core5alloc9Allocator8allocate.exit.i.i.i

_RNvXs_NtCslNYArtu3iFV_5alloc5allocNtB4_6GlobalNtNtCsgEmfK2I1SDS_4core5alloc9Allocator8allocate.exit.i.i.i: ; preds = %start
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCsfLfy6EI15iL_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #5, !noalias !3
; call __rustc::__rust_alloc
  %1 = tail call noundef align 4 ptr @_RNvCsfLfy6EI15iL_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775805) %_33.0.i.i.i, i64 noundef 4) #5, !noalias !3
  %2 = icmp eq ptr %1, null
  br i1 %2, label %bb3.i.i, label %bb3.i.i.i.i.i.preheader

bb3.i.i.i.i.i.preheader:                          ; preds = %_RNvXs_NtCslNYArtu3iFV_5alloc5allocNtB4_6GlobalNtNtCsgEmfK2I1SDS_4core5alloc9Allocator8allocate.exit.i.i.i
  %min.iters.check = icmp ult i32 %n, 8
  br i1 %min.iters.check, label %bb3.i.i.i.i.i.preheader19, label %vector.ph

vector.ph:                                        ; preds = %bb3.i.i.i.i.i.preheader
  %n.vec = and i64 %.sink2.i.i, 4294967288
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.ind = phi <4 x i32> [ <i32 0, i32 1, i32 2, i32 3>, %vector.ph ], [ %vec.ind.next, %vector.body ]
  %step.add = add <4 x i32> %vec.ind, splat (i32 4)
  %3 = getelementptr inbounds nuw i32, ptr %1, i64 %index
  %4 = getelementptr inbounds nuw i8, ptr %3, i64 16
  store <4 x i32> %vec.ind, ptr %3, align 4, !noalias !8
  store <4 x i32> %step.add, ptr %4, align 4, !noalias !8
  %index.next = add nuw i64 %index, 8
  %vec.ind.next = add <4 x i32> %vec.ind, splat (i32 8)
  %5 = icmp eq i64 %index.next, %n.vec
  br i1 %5, label %middle.block, label %vector.body, !llvm.loop !21

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %n.vec, %.sink2.i.i
  br i1 %cmp.n, label %bb8.i.preheader, label %bb3.i.i.i.i.i.preheader19

bb3.i.i.i.i.i.preheader19:                        ; preds = %bb3.i.i.i.i.i.preheader, %middle.block
  %.ph = phi i64 [ 0, %bb3.i.i.i.i.i.preheader ], [ %n.vec, %middle.block ]
  br label %bb3.i.i.i.i.i

bb3.i.i:                                          ; preds = %_RNvXs_NtCslNYArtu3iFV_5alloc5allocNtB4_6GlobalNtNtCsgEmfK2I1SDS_4core5alloc9Allocator8allocate.exit.i.i.i
; call alloc::raw_vec::handle_error
  tail call void @_RNvNtCslNYArtu3iFV_5alloc7raw_vec12handle_error(i64 noundef 4, i64 %_33.0.i.i.i) #6, !noalias !24
  unreachable

bb3.i.i.i.i.i:                                    ; preds = %bb3.i.i.i.i.i.preheader19, %bb3.i.i.i.i.i
  %6 = phi i64 [ %7, %bb3.i.i.i.i.i ], [ %.ph, %bb3.i.i.i.i.i.preheader19 ]
  %indvars1.i = trunc i64 %6 to i32
  %7 = add nuw nsw i64 %6, 1
  %_3.i.i.i.i.i.i.i = getelementptr inbounds nuw i32, ptr %1, i64 %6
  store i32 %indvars1.i, ptr %_3.i.i.i.i.i.i.i, align 4, !noalias !8
  %exitcond.i = icmp eq i64 %7, %.sink2.i.i
  br i1 %exitcond.i, label %bb8.i.preheader, label %bb3.i.i.i.i.i, !llvm.loop !25

bb8.i.preheader:                                  ; preds = %bb3.i.i.i.i.i, %middle.block
  %min.iters.check4 = icmp ult i32 %n, 4
  br i1 %min.iters.check4, label %bb8.i.preheader16, label %vector.ph5

vector.ph5:                                       ; preds = %bb8.i.preheader
  %n.vec7 = and i64 %.sink2.i.i, 4294967292
  br label %vector.body8

vector.body8:                                     ; preds = %vector.body8, %vector.ph5
  %index9 = phi i64 [ 0, %vector.ph5 ], [ %index.next12, %vector.body8 ]
  %vec.phi = phi <2 x i64> [ zeroinitializer, %vector.ph5 ], [ %12, %vector.body8 ]
  %vec.phi10 = phi <2 x i64> [ zeroinitializer, %vector.ph5 ], [ %13, %vector.body8 ]
  %8 = getelementptr inbounds nuw i32, ptr %1, i64 %index9
  %9 = getelementptr inbounds nuw i8, ptr %8, i64 8
  %wide.load = load <2 x i32>, ptr %8, align 4, !alias.scope !26
  %wide.load11 = load <2 x i32>, ptr %9, align 4, !alias.scope !26
  %10 = zext <2 x i32> %wide.load to <2 x i64>
  %11 = zext <2 x i32> %wide.load11 to <2 x i64>
  %12 = add <2 x i64> %vec.phi, %10
  %13 = add <2 x i64> %vec.phi10, %11
  %index.next12 = add nuw i64 %index9, 4
  %14 = icmp eq i64 %index.next12, %n.vec7
  br i1 %14, label %middle.block13, label %vector.body8, !llvm.loop !31

middle.block13:                                   ; preds = %vector.body8
  %bin.rdx = add <2 x i64> %13, %12
  %15 = tail call i64 @llvm.vector.reduce.add.v2i64(<2 x i64> %bin.rdx)
  %cmp.n14 = icmp eq i64 %n.vec7, %.sink2.i.i
  br i1 %cmp.n14, label %bb2.i.i.i.i, label %bb8.i.preheader16

bb8.i.preheader16:                                ; preds = %bb8.i.preheader, %middle.block13
  %i.sroa.0.0.i.ph = phi i64 [ 0, %bb8.i.preheader ], [ %n.vec7, %middle.block13 ]
  %acc.sroa.0.0.i.ph = phi i64 [ 0, %bb8.i.preheader ], [ %15, %middle.block13 ]
  br label %bb8.i

bb8.i:                                            ; preds = %bb8.i.preheader16, %bb8.i
  %i.sroa.0.0.i = phi i64 [ %_27.i, %bb8.i ], [ %i.sroa.0.0.i.ph, %bb8.i.preheader16 ]
  %acc.sroa.0.0.i = phi i64 [ %_4.0.i.i.i, %bb8.i ], [ %acc.sroa.0.0.i.ph, %bb8.i.preheader16 ]
  %_45.i = getelementptr inbounds nuw i32, ptr %1, i64 %i.sroa.0.0.i
  %_3.i.i.i = load i32, ptr %_45.i, align 4, !alias.scope !26, !noundef !32
  %_0.i.i.i = zext i32 %_3.i.i.i to i64
  %_4.0.i.i.i = add i64 %acc.sroa.0.0.i, %_0.i.i.i
  %_27.i = add nuw nsw i64 %i.sroa.0.0.i, 1
  %_28.i = icmp eq i64 %_27.i, %.sink2.i.i
  br i1 %_28.i, label %bb2.i.i.i.i, label %bb8.i, !llvm.loop !33

bb2.i.i.i.i:                                      ; preds = %bb8.i, %middle.block13
  %_4.0.i.i.i.lcssa = phi i64 [ %15, %middle.block13 ], [ %_4.0.i.i.i, %bb8.i ]
; call __rustc::__rust_dealloc
  tail call void @_RNvCsfLfy6EI15iL_7___rustc14___rust_dealloc(ptr noundef nonnull %1, i64 noundef %_33.0.i.i.i, i64 noundef range(i64 1, -9223372036854775807) 4) #5, !noalias !34
  br label %"_ZN4core3ptr47drop_in_place$LT$alloc..vec..Vec$LT$u32$GT$$GT$17ha57a76337bb5b3e1E.exit"

"_ZN4core3ptr47drop_in_place$LT$alloc..vec..Vec$LT$u32$GT$$GT$17ha57a76337bb5b3e1E.exit": ; preds = %start, %bb2.i.i.i.i
  %_0.sroa.0.0.i2 = phi i64 [ %_4.0.i.i.i.lcssa, %bb2.i.i.i.i ], [ 0, %start ]
  ret i64 %_0.sroa.0.0.i2
}

; __rustc::__rust_dealloc
; Function Attrs: nounwind nonlazybind allockind("free") uwtable
declare void @_RNvCsfLfy6EI15iL_7___rustc14___rust_dealloc(ptr allocptr noundef captures(address), i64 noundef, i64 noundef range(i64 1, -9223372036854775807)) unnamed_addr #1

; __rustc::__rust_no_alloc_shim_is_unstable_v2
; Function Attrs: nounwind nonlazybind uwtable
declare void @_RNvCsfLfy6EI15iL_7___rustc35___rust_no_alloc_shim_is_unstable_v2() unnamed_addr #0

; __rustc::__rust_alloc
; Function Attrs: nounwind nonlazybind allockind("alloc,uninitialized,aligned") allocsize(0) uwtable
declare noalias noundef ptr @_RNvCsfLfy6EI15iL_7___rustc12___rust_alloc(i64 noundef, i64 allocalign noundef range(i64 1, -9223372036854775807)) unnamed_addr #2

; Function Attrs: nounwind nonlazybind uwtable
declare noundef range(i32 0, 10) i32 @rust_eh_personality(i32 noundef, i32 noundef, i64 noundef, ptr noundef, ptr noundef) unnamed_addr #0

; alloc::raw_vec::handle_error
; Function Attrs: cold minsize noreturn nounwind nonlazybind optsize uwtable
declare void @_RNvNtCslNYArtu3iFV_5alloc7raw_vec12handle_error(i64 noundef range(i64 0, -9223372036854775807), i64) unnamed_addr #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.vector.reduce.add.v2i64(<2 x i64>) #4

attributes #0 = { nounwind nonlazybind uwtable "probe-stack"="inline-asm" "target-cpu"="x86-64" }
attributes #1 = { nounwind nonlazybind allockind("free") uwtable "alloc-family"="__rust_alloc" "probe-stack"="inline-asm" "target-cpu"="x86-64" }
attributes #2 = { nounwind nonlazybind allockind("alloc,uninitialized,aligned") allocsize(0) uwtable "alloc-family"="__rust_alloc" "alloc-variant-zeroed"="_RNvCsfLfy6EI15iL_7___rustc19___rust_alloc_zeroed" "probe-stack"="inline-asm" "target-cpu"="x86-64" }
attributes #3 = { cold minsize noreturn nounwind nonlazybind optsize uwtable "probe-stack"="inline-asm" "target-cpu"="x86-64" }
attributes #4 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #5 = { nounwind }
attributes #6 = { noreturn nounwind }

!llvm.module.flags = !{!0, !1}
!llvm.ident = !{!2}

!0 = !{i32 8, !"PIC Level", i32 2}
!1 = !{i32 2, !"RtLibUseGOT", i32 1}
!2 = !{!"rustc version 1.95.0 (59807616e 2026-04-14)"}
!3 = !{!4, !6}
!4 = distinct !{!4, !5, !"_ZN5alloc7raw_vec20RawVecInner$LT$A$GT$15try_allocate_in17h5d6cccff9fd6f144E: %_0"}
!5 = distinct !{!5, !"_ZN5alloc7raw_vec20RawVecInner$LT$A$GT$15try_allocate_in17h5d6cccff9fd6f144E"}
!6 = distinct !{!6, !7, !"_ZN111_$LT$alloc..vec..Vec$LT$T$GT$$u20$as$u20$alloc..vec..spec_from_iter_nested..SpecFromIterNested$LT$T$C$I$GT$$GT$9from_iter17he552cf7b9eb717acE: %_0"}
!7 = distinct !{!7, !"_ZN111_$LT$alloc..vec..Vec$LT$T$GT$$u20$as$u20$alloc..vec..spec_from_iter_nested..SpecFromIterNested$LT$T$C$I$GT$$GT$9from_iter17he552cf7b9eb717acE"}
!8 = !{!9, !11, !13, !15, !17, !19, !6}
!9 = distinct !{!9, !10, !"_ZN5alloc3vec16Vec$LT$T$C$A$GT$14extend_trusted28_$u7b$$u7b$closure$u7d$$u7d$17h8afe5621c68d09abE: %_1"}
!10 = distinct !{!10, !"_ZN5alloc3vec16Vec$LT$T$C$A$GT$14extend_trusted28_$u7b$$u7b$closure$u7d$$u7d$17h8afe5621c68d09abE"}
!11 = distinct !{!11, !12, !"_ZN4core4iter6traits8iterator8Iterator8for_each4call28_$u7b$$u7b$closure$u7d$$u7d$17hf5c3ab5e6de8622aE: %_1"}
!12 = distinct !{!12, !"_ZN4core4iter6traits8iterator8Iterator8for_each4call28_$u7b$$u7b$closure$u7d$$u7d$17hf5c3ab5e6de8622aE"}
!13 = distinct !{!13, !14, !"_ZN4core4iter6traits8iterator8Iterator4fold17hed81b0e7aabb7835E: %f"}
!14 = distinct !{!14, !"_ZN4core4iter6traits8iterator8Iterator4fold17hed81b0e7aabb7835E"}
!15 = distinct !{!15, !16, !"_ZN4core4iter6traits8iterator8Iterator8for_each17h95413d936c4fc046E: %f"}
!16 = distinct !{!16, !"_ZN4core4iter6traits8iterator8Iterator8for_each17h95413d936c4fc046E"}
!17 = distinct !{!17, !18, !"_ZN5alloc3vec16Vec$LT$T$C$A$GT$14extend_trusted17h2d361437575d99a9E: %self"}
!18 = distinct !{!18, !"_ZN5alloc3vec16Vec$LT$T$C$A$GT$14extend_trusted17h2d361437575d99a9E"}
!19 = distinct !{!19, !20, !"_ZN97_$LT$alloc..vec..Vec$LT$T$C$A$GT$$u20$as$u20$alloc..vec..spec_extend..SpecExtend$LT$T$C$I$GT$$GT$11spec_extend17h5a16389ace454422E: %self"}
!20 = distinct !{!20, !"_ZN97_$LT$alloc..vec..Vec$LT$T$C$A$GT$$u20$as$u20$alloc..vec..spec_extend..SpecExtend$LT$T$C$I$GT$$GT$11spec_extend17h5a16389ace454422E"}
!21 = distinct !{!21, !22, !23}
!22 = !{!"llvm.loop.isvectorized", i32 1}
!23 = !{!"llvm.loop.unroll.runtime.disable"}
!24 = !{!6}
!25 = distinct !{!25, !23, !22}
!26 = !{!27, !29}
!27 = distinct !{!27, !28, !"_ZN5probe9probe_sum28_$u7b$$u7b$closure$u7d$$u7d$17h912f331ed23ed266E: %x"}
!28 = distinct !{!28, !"_ZN5probe9probe_sum28_$u7b$$u7b$closure$u7d$$u7d$17h912f331ed23ed266E"}
!29 = distinct !{!29, !30, !"_ZN4core4iter8adapters3map8map_fold28_$u7b$$u7b$closure$u7d$$u7d$17he0dbe4e0ebecafc2E: %elt"}
!30 = distinct !{!30, !"_ZN4core4iter8adapters3map8map_fold28_$u7b$$u7b$closure$u7d$$u7d$17he0dbe4e0ebecafc2E"}
!31 = distinct !{!31, !22, !23}
!32 = !{}
!33 = distinct !{!33, !23, !22}
!34 = !{!35, !37, !39, !41}
!35 = distinct !{!35, !36, !"_ZN5alloc7raw_vec20RawVecInner$LT$A$GT$10deallocate17heb44bf7e4f54b630E: %self"}
!36 = distinct !{!36, !"_ZN5alloc7raw_vec20RawVecInner$LT$A$GT$10deallocate17heb44bf7e4f54b630E"}
!37 = distinct !{!37, !38, !"_ZN77_$LT$alloc..raw_vec..RawVec$LT$T$C$A$GT$$u20$as$u20$core..ops..drop..Drop$GT$4drop17h197a6b2f1f90c9f1E: %self"}
!38 = distinct !{!38, !"_ZN77_$LT$alloc..raw_vec..RawVec$LT$T$C$A$GT$$u20$as$u20$core..ops..drop..Drop$GT$4drop17h197a6b2f1f90c9f1E"}
!39 = distinct !{!39, !40, !"_ZN4core3ptr54drop_in_place$LT$alloc..raw_vec..RawVec$LT$u32$GT$$GT$17h5c606771de846b14E: %_1"}
!40 = distinct !{!40, !"_ZN4core3ptr54drop_in_place$LT$alloc..raw_vec..RawVec$LT$u32$GT$$GT$17h5c606771de846b14E"}
!41 = distinct !{!41, !42, !"_ZN4core3ptr47drop_in_place$LT$alloc..vec..Vec$LT$u32$GT$$GT$17ha57a76337bb5b3e1E: %_1"}
!42 = distinct !{!42, !"_ZN4core3ptr47drop_in_place$LT$alloc..vec..Vec$LT$u32$GT$$GT$17ha57a76337bb5b3e1E"}
