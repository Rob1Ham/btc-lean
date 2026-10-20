; ModuleID = 'from_iter-195.bc'
source_filename = "rbitcoin_consensus.feaf38542b4ff5dd-cgu.0"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

%"bitcoin::blockdata::transaction::TxOut" = type { %"bitcoin::blockdata::script::owned::ScriptBuf", i64 }
%"bitcoin::blockdata::script::owned::ScriptBuf" = type { %"alloc::vec::Vec<u8>" }
%"alloc::vec::Vec<u8>" = type { %"alloc::raw_vec::RawVec<u8>", i64 }
%"alloc::raw_vec::RawVec<u8>" = type { %"alloc::raw_vec::RawVecInner", %"core::marker::PhantomData<u8>" }
%"alloc::raw_vec::RawVecInner" = type { i64, ptr, %"alloc::alloc::Global" }
%"alloc::alloc::Global" = type {}
%"core::marker::PhantomData<u8>" = type {}

; Function Attrs: nounwind nonlazybind uwtable
define hidden fastcc void @"_ZN111_$LT$alloc..vec..Vec$LT$T$GT$$u20$as$u20$alloc..vec..spec_from_iter_nested..SpecFromIterNested$LT$T$C$I$GT$$GT$9from_iter17h4edb8bfb10638b77E"(ptr dead_on_unwind noalias noundef nonnull writable writeonly align 8 captures(none) dereferenceable(24) %_0, ptr dead_on_return noalias noundef nonnull readonly align 8 captures(none) dereferenceable(32) %iterator) unnamed_addr #0 personality ptr @rust_eh_personality !dbg !7 {
bb3:
  %0 = getelementptr inbounds nuw i8, ptr %iterator, i64 16, !dbg !15
  %iterator.val = load i64, ptr %0, align 8, !dbg !15, !alias.scope !16, !noalias !19, !noundef !14
  %1 = getelementptr inbounds nuw i8, ptr %iterator, i64 24, !dbg !15
  %iterator.val1 = load i64, ptr %1, align 8, !dbg !15, !alias.scope !19, !noalias !16, !noundef !14
  %spec.select.i.i = tail call i64 @llvm.usub.sat.i64(i64 %iterator.val1, i64 %iterator.val), !dbg !21
  %_33.0.i.i = shl i64 %spec.select.i.i, 5, !dbg !35
  %_33.1.i.i = icmp ugt i64 %spec.select.i.i, 576460752303423487, !dbg !35
  %_38.not.i.i = icmp ugt i64 %_33.0.i.i, 9223372036854775800
  %or.cond.i.i = or i1 %_33.1.i.i, %_38.not.i.i, !dbg !69
  br i1 %or.cond.i.i, label %bb3.i, label %bb18.i.i, !dbg !69, !prof !75

bb18.i.i:                                         ; preds = %bb3
  %2 = icmp eq i64 %_33.0.i.i, 0, !dbg !76
  br i1 %2, label %"_ZN5alloc3vec16Vec$LT$T$C$A$GT$7reserve17h2ef5308c87538310E.exit.i.i", label %bb3.i.i, !dbg !76

bb3.i.i:                                          ; preds = %bb18.i.i
  tail call void @_RNvCsfLfy6EI15iL_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #6, !dbg !78, !noalias !79
  %3 = tail call noundef align 8 ptr @_RNvCsfLfy6EI15iL_7___rustc12___rust_alloc(i64 noundef %_33.0.i.i, i64 noundef range(i64 1, 9) 8) #6, !dbg !82, !noalias !79
  %4 = icmp eq ptr %3, null, !dbg !96
  br i1 %4, label %bb3.i, label %"_ZN5alloc3vec16Vec$LT$T$C$A$GT$7reserve17h2ef5308c87538310E.exit.i.i", !dbg !98

bb3.i:                                            ; preds = %bb3.i.i, %bb3
  %_4.sroa.4.0.ph.i = phi i64 [ 8, %bb3.i.i ], [ 0, %bb3 ]
  tail call void @_RNvNtCslNYArtu3iFV_5alloc7raw_vec12handle_error(i64 noundef %_4.sroa.4.0.ph.i, i64 %_33.0.i.i) #7, !dbg !99
  unreachable, !dbg !99

"_ZN5alloc3vec16Vec$LT$T$C$A$GT$7reserve17h2ef5308c87538310E.exit.i.i": ; preds = %bb3.i.i, %bb18.i.i
  %_4.sroa.4.0.i = phi i64 [ 0, %bb18.i.i ], [ %spec.select.i.i, %bb3.i.i ], !dbg !101
  %_4.sroa.10.0.i = phi ptr [ inttoptr (i64 8 to ptr), %bb18.i.i ], [ %3, %bb3.i.i ]
  %_7.i = icmp samesign ule i64 %spec.select.i.i, %_4.sroa.4.0.i, !dbg !102
  tail call void @llvm.assume(i1 %_7.i), !dbg !106
  %_11.sroa.0.0.copyload = load ptr, ptr %iterator, align 8, !dbg !111, !nonnull !14, !noundef !14
  %_0.i.i.i9.i.i.i.i.i = icmp ult i64 %iterator.val, %iterator.val1, !dbg !113
  br i1 %_0.i.i.i9.i.i.i.i.i, label %bb3.lr.ph.i.i.i.i.i, label %"_ZN97_$LT$alloc..vec..Vec$LT$T$C$A$GT$$u20$as$u20$alloc..vec..spec_extend..SpecExtend$LT$T$C$I$GT$$GT$11spec_extend17h96bb259d1f25c1b1E.exit", !dbg !148

bb3.lr.ph.i.i.i.i.i:                              ; preds = %"_ZN5alloc3vec16Vec$LT$T$C$A$GT$7reserve17h2ef5308c87538310E.exit.i.i"
  %_11.sroa.4.0.iterator.sroa_idx = getelementptr inbounds nuw i8, ptr %iterator, i64 8, !dbg !111
  %_11.sroa.4.0.copyload = load ptr, ptr %_11.sroa.4.0.iterator.sroa_idx, align 8, !dbg !111, !nonnull !14, !noundef !14
  %5 = getelementptr inbounds nuw i8, ptr %_11.sroa.4.0.copyload, i64 24
  %6 = getelementptr i8, ptr %_11.sroa.4.0.copyload, i64 8
  %7 = getelementptr i8, ptr %_11.sroa.4.0.copyload, i64 16
  br label %bb3.i.i.i.i.i, !dbg !148

bb3.i.i.i.i.i:                                    ; preds = %"_ZN4core4iter8adapters3map8map_fold28_$u7b$$u7b$closure$u7d$$u7d$17h837f94b8d4ce32e9E.exit.i.i.i.i.i", %bb3.lr.ph.i.i.i.i.i
  %8 = phi i64 [ 0, %bb3.lr.ph.i.i.i.i.i ], [ %12, %"_ZN4core4iter8adapters3map8map_fold28_$u7b$$u7b$closure$u7d$$u7d$17h837f94b8d4ce32e9E.exit.i.i.i.i.i" ]
  %self.sroa.0.010.i.i.i.i.i = phi i64 [ %iterator.val, %bb3.lr.ph.i.i.i.i.i ], [ %_0.i1.i.i.i.i.i.i.i, %"_ZN4core4iter8adapters3map8map_fold28_$u7b$$u7b$closure$u7d$$u7d$17h837f94b8d4ce32e9E.exit.i.i.i.i.i" ]
  %_0.i1.i.i.i.i.i.i.i = add i64 %self.sroa.0.010.i.i.i.i.i, 1, !dbg !149
  %_4.i.i3.i.i.i.i.i = load i64, ptr %_11.sroa.0.0.copyload, align 8, !dbg !156, !noalias !167, !noundef !14
  %_3.i.i.i.i.i.i.i = icmp eq i64 %self.sroa.0.010.i.i.i.i.i, %_4.i.i3.i.i.i.i.i, !dbg !186
  br i1 %_3.i.i.i.i.i.i.i, label %bb1.i.i.i.i.i.i.i, label %"_ZN4core4iter8adapters3map8map_fold28_$u7b$$u7b$closure$u7d$$u7d$17h837f94b8d4ce32e9E.exit.i.i.i.i.i", !dbg !186

bb1.i.i.i.i.i.i.i:                                ; preds = %bb3.i.i.i.i.i
  %_8.i.i.i.i.i.i.i = load i64, ptr %5, align 8, !dbg !187, !noalias !167, !noundef !14
  %_7.val.i.i.i.i.i.i.i = load ptr, ptr %6, align 8, !dbg !202, !noalias !167, !nonnull !14, !noundef !14
  %_7.val1.i.i.i.i.i.i.i = load i64, ptr %7, align 8, !dbg !202, !noalias !167, !noundef !14
  %9 = icmp eq i64 %_7.val1.i.i.i.i.i.i.i, 0, !dbg !210
  br i1 %9, label %"_ZN4core4iter8adapters3map8map_fold28_$u7b$$u7b$closure$u7d$$u7d$17h837f94b8d4ce32e9E.exit.i.i.i.i.i", label %bb3.i.i.i.i.i.i.i.i.i.i.i, !dbg !210

bb3.i.i.i.i.i.i.i.i.i.i.i:                        ; preds = %bb1.i.i.i.i.i.i.i
  tail call void @_RNvCsfLfy6EI15iL_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #6, !dbg !231, !noalias !232
  %10 = tail call noundef ptr @_RNvCsfLfy6EI15iL_7___rustc12___rust_alloc(i64 noundef range(i64 0, -9223372036854775808) %_7.val1.i.i.i.i.i.i.i, i64 noundef range(i64 1, 9) 1) #6, !dbg !240, !noalias !232
  %11 = icmp eq ptr %10, null, !dbg !245
  br i1 %11, label %bb3.i.i.i.i.i.i.i.i.i.i, label %bb1.i.i.i.i.i.i.i.i.i, !dbg !246

bb3.i.i.i.i.i.i.i.i.i.i:                          ; preds = %bb3.i.i.i.i.i.i.i.i.i.i.i
  tail call void @_RNvNtCslNYArtu3iFV_5alloc7raw_vec12handle_error(i64 noundef 1, i64 range(i64 0, -9223372036854775808) %_7.val1.i.i.i.i.i.i.i) #7, !dbg !247, !noalias !248
  unreachable, !dbg !247

bb1.i.i.i.i.i.i.i.i.i:                            ; preds = %bb3.i.i.i.i.i.i.i.i.i.i.i
  tail call void @llvm.memcpy.p0.p0.i64(ptr nonnull align 1 %10, ptr nonnull readonly align 1 %_7.val.i.i.i.i.i.i.i, i64 range(i64 0, -9223372036854775808) %_7.val1.i.i.i.i.i.i.i, i1 false), !dbg !249, !noalias !260
  br label %"_ZN4core4iter8adapters3map8map_fold28_$u7b$$u7b$closure$u7d$$u7d$17h837f94b8d4ce32e9E.exit.i.i.i.i.i", !dbg !261

"_ZN4core4iter8adapters3map8map_fold28_$u7b$$u7b$closure$u7d$$u7d$17h837f94b8d4ce32e9E.exit.i.i.i.i.i": ; preds = %bb1.i.i.i.i.i.i.i.i.i, %bb1.i.i.i.i.i.i.i, %bb3.i.i.i.i.i
  %_8.sink.i.i.i.i.i.i.i = phi i64 [ 0, %bb3.i.i.i.i.i ], [ %_8.i.i.i.i.i.i.i, %bb1.i.i.i.i.i.i.i ], [ %_8.i.i.i.i.i.i.i, %bb1.i.i.i.i.i.i.i.i.i ]
  %_7.val1.sink1.i.i.i.i.i.i.i = phi i64 [ 0, %bb3.i.i.i.i.i ], [ 0, %bb1.i.i.i.i.i.i.i ], [ %_7.val1.i.i.i.i.i.i.i, %bb1.i.i.i.i.i.i.i.i.i ]
  %_10.sroa.5.0.sink.i.i.i.i.i.i.i = phi ptr [ inttoptr (i64 1 to ptr), %bb3.i.i.i.i.i ], [ inttoptr (i64 1 to ptr), %bb1.i.i.i.i.i.i.i ], [ %10, %bb1.i.i.i.i.i.i.i.i.i ]
  %_3.i.i.i5.i.i.i.i.i = getelementptr inbounds nuw %"bitcoin::blockdata::transaction::TxOut", ptr %_4.sroa.10.0.i, i64 %8, !dbg !262
  store i64 %_7.val1.sink1.i.i.i.i.i.i.i, ptr %_3.i.i.i5.i.i.i.i.i, align 8, !dbg !276, !noalias !279
  %_5.sroa.4.0._3.i.i.sroa_idx.i.i.i.i.i.i = getelementptr inbounds nuw i8, ptr %_3.i.i.i5.i.i.i.i.i, i64 8, !dbg !276
  store ptr %_10.sroa.5.0.sink.i.i.i.i.i.i.i, ptr %_5.sroa.4.0._3.i.i.sroa_idx.i.i.i.i.i.i, align 8, !dbg !276, !noalias !279
  %_5.sroa.5.0._3.i.i.sroa_idx.i.i.i.i.i.i = getelementptr inbounds nuw i8, ptr %_3.i.i.i5.i.i.i.i.i, i64 16, !dbg !276
  store i64 %_7.val1.sink1.i.i.i.i.i.i.i, ptr %_5.sroa.5.0._3.i.i.sroa_idx.i.i.i.i.i.i, align 8, !dbg !276, !noalias !279
  %_5.sroa.6.0._3.i.i.sroa_idx.i.i.i.i.i.i = getelementptr inbounds nuw i8, ptr %_3.i.i.i5.i.i.i.i.i, i64 24, !dbg !276
  store i64 %_8.sink.i.i.i.i.i.i.i, ptr %_5.sroa.6.0._3.i.i.sroa_idx.i.i.i.i.i.i, align 8, !dbg !276, !noalias !279
  %12 = add nuw i64 %8, 1, !dbg !284
  %exitcond.not.i.i.i.i.i = icmp eq i64 %_0.i1.i.i.i.i.i.i.i, %iterator.val1, !dbg !113
  br i1 %exitcond.not.i.i.i.i.i, label %"_ZN97_$LT$alloc..vec..Vec$LT$T$C$A$GT$$u20$as$u20$alloc..vec..spec_extend..SpecExtend$LT$T$C$I$GT$$GT$11spec_extend17h96bb259d1f25c1b1E.exit", label %bb3.i.i.i.i.i, !dbg !148

"_ZN97_$LT$alloc..vec..Vec$LT$T$C$A$GT$$u20$as$u20$alloc..vec..spec_extend..SpecExtend$LT$T$C$I$GT$$GT$11spec_extend17h96bb259d1f25c1b1E.exit": ; preds = %"_ZN4core4iter8adapters3map8map_fold28_$u7b$$u7b$closure$u7d$$u7d$17h837f94b8d4ce32e9E.exit.i.i.i.i.i", %"_ZN5alloc3vec16Vec$LT$T$C$A$GT$7reserve17h2ef5308c87538310E.exit.i.i"
  %f.val2.i.i.i.i.i = phi i64 [ 0, %"_ZN5alloc3vec16Vec$LT$T$C$A$GT$7reserve17h2ef5308c87538310E.exit.i.i" ], [ %12, %"_ZN4core4iter8adapters3map8map_fold28_$u7b$$u7b$closure$u7d$$u7d$17h837f94b8d4ce32e9E.exit.i.i.i.i.i" ], !dbg !290
  store i64 %_4.sroa.4.0.i, ptr %_0, align 8, !dbg !291
  %vector.sroa.4.0._0.sroa_idx = getelementptr inbounds nuw i8, ptr %_0, i64 8, !dbg !291
  store ptr %_4.sroa.10.0.i, ptr %vector.sroa.4.0._0.sroa_idx, align 8, !dbg !291
  %vector.sroa.6.0._0.sroa_idx = getelementptr inbounds nuw i8, ptr %_0, i64 16, !dbg !291
  store i64 %f.val2.i.i.i.i.i, ptr %vector.sroa.6.0._0.sroa_idx, align 8, !dbg !291
  ret void, !dbg !292
}

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(inaccessiblemem: write)
declare void @llvm.assume(i1 noundef) #1

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: readwrite)
declare void @llvm.memcpy.p0.p0.i64(ptr noalias writeonly captures(none), ptr noalias readonly captures(none), i64, i1 immarg) #2

; Function Attrs: nounwind nonlazybind uwtable
declare void @_RNvCsfLfy6EI15iL_7___rustc35___rust_no_alloc_shim_is_unstable_v2() unnamed_addr #0

; Function Attrs: nounwind nonlazybind allockind("alloc,uninitialized,aligned") allocsize(0) uwtable
declare noalias noundef ptr @_RNvCsfLfy6EI15iL_7___rustc12___rust_alloc(i64 noundef, i64 allocalign noundef range(i64 1, -9223372036854775807)) unnamed_addr #3

; Function Attrs: nounwind nonlazybind uwtable
declare noundef range(i32 0, 10) i32 @rust_eh_personality(i32 noundef, i32 noundef, i64 noundef, ptr noundef, ptr noundef) unnamed_addr #0

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.usub.sat.i64(i64, i64) #4

; Function Attrs: cold minsize noreturn nounwind nonlazybind optsize uwtable
declare void @_RNvNtCslNYArtu3iFV_5alloc7raw_vec12handle_error(i64 noundef range(i64 0, -9223372036854775807), i64) unnamed_addr #5

attributes #0 = { nounwind nonlazybind uwtable "probe-stack"="inline-asm" "target-cpu"="x86-64" }
attributes #1 = { nocallback nofree nosync nounwind willreturn memory(inaccessiblemem: write) }
attributes #2 = { nocallback nofree nounwind willreturn memory(argmem: readwrite) }
attributes #3 = { nounwind nonlazybind allockind("alloc,uninitialized,aligned") allocsize(0) uwtable "alloc-family"="__rust_alloc" "alloc-variant-zeroed"="_RNvCsfLfy6EI15iL_7___rustc19___rust_alloc_zeroed" "probe-stack"="inline-asm" "target-cpu"="x86-64" }
attributes #4 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #5 = { cold minsize noreturn nounwind nonlazybind optsize uwtable "probe-stack"="inline-asm" "target-cpu"="x86-64" }
attributes #6 = { nounwind }
attributes #7 = { noreturn nounwind }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}
!llvm.dbg.cu = !{!5}

!0 = !{i32 8, !"PIC Level", i32 2}
!1 = !{i32 2, !"RtLibUseGOT", i32 1}
!2 = !{i32 7, !"Dwarf Version", i32 4}
!3 = !{i32 2, !"Debug Info Version", i32 3}
!4 = !{!"rustc version 1.95.0 (59807616e 2026-04-14)"}
!5 = distinct !DICompileUnit(language: DW_LANG_Rust, file: !6, producer: "clang LLVM (rustc version 1.95.0 (59807616e 2026-04-14))", isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug, splitDebugInlining: false, nameTableKind: None)
!6 = !DIFile(filename: "crates/rbitcoin-consensus/src/lib.rs/@/rbitcoin_consensus.feaf38542b4ff5dd-cgu.0", directory: "/tmp/opencode/equiv-work/rbitcoin")
!7 = distinct !DISubprogram(name: "from_iter<bitcoin::blockdata::transaction::TxOut, core::iter::adapters::map::Map<core::ops::range::Range<usize>, rbitcoin_consensus::script::ffi::verify_impl::{closure_env#0}>>", linkageName: "_ZN111_$LT$alloc..vec..Vec$LT$T$GT$$u20$as$u20$alloc..vec..spec_from_iter_nested..SpecFromIterNested$LT$T$C$I$GT$$GT$9from_iter17h4edb8bfb10638b77E", scope: !9, file: !8, line: 50, type: !13, scopeLine: 50, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!8 = !DIFile(filename: "library/alloc/src/vec/spec_from_iter_nested.rs", directory: "/rustc/59807616e1fa2540724bfbac14d7976d7e4a3860", checksumkind: CSK_MD5, checksum: "f1ca97f56309a9c2b99339993bd752ef")
!9 = !DINamespace(name: "{impl#1}", scope: !10)
!10 = !DINamespace(name: "spec_from_iter_nested", scope: !11)
!11 = !DINamespace(name: "vec", scope: !12)
!12 = !DINamespace(name: "alloc", scope: null)
!13 = !DISubroutineType(types: !14)
!14 = !{}
!15 = !DILocation(line: 51, column: 41, scope: !7)
!16 = !{!17}
!17 = distinct !{!17, !18, !"_RNvXsU_NtNtCsgEmfK2I1SDS_4core3cmp5implsjNtB7_10PartialOrd2lt: %self"}
!18 = distinct !{!18, !"_RNvXsU_NtNtCsgEmfK2I1SDS_4core3cmp5implsjNtB7_10PartialOrd2lt"}
!19 = !{!20}
!20 = distinct !{!20, !18, !"_RNvXsU_NtNtCsgEmfK2I1SDS_4core3cmp5implsjNtB7_10PartialOrd2lt: %other"}
!21 = !DILocation(line: 862, column: 12, scope: !22, inlinedAt: !28)
!22 = distinct !DISubprogram(name: "size_hint<usize>", linkageName: "_ZN4core4iter5range101_$LT$impl$u20$core..iter..traits..iterator..Iterator$u20$for$u20$core..ops..range..Range$LT$A$GT$$GT$9size_hint17h1bd66d8e44a5288cE", scope: !24, file: !23, line: 861, type: !13, scopeLine: 861, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!23 = !DIFile(filename: "library/core/src/iter/range.rs", directory: "/rustc/59807616e1fa2540724bfbac14d7976d7e4a3860", checksumkind: CSK_MD5, checksum: "e302cc3146df1591d87c4742d277fd2d")
!24 = !DINamespace(name: "{impl#6}", scope: !25)
!25 = !DINamespace(name: "range", scope: !26)
!26 = !DINamespace(name: "iter", scope: !27)
!27 = !DINamespace(name: "core", scope: null)
!28 = distinct !DILocation(line: 112, column: 19, scope: !29, inlinedAt: !34)
!29 = distinct !DISubprogram(name: "size_hint<bitcoin::blockdata::transaction::TxOut, core::ops::range::Range<usize>, rbitcoin_consensus::script::ffi::verify_impl::{closure_env#0}>", linkageName: "_ZN102_$LT$core..iter..adapters..map..Map$LT$I$C$F$GT$$u20$as$u20$core..iter..traits..iterator..Iterator$GT$9size_hint17hd9fd6d28ee265c95E", scope: !31, file: !30, line: 111, type: !13, scopeLine: 111, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!30 = !DIFile(filename: "library/core/src/iter/adapters/map.rs", directory: "/rustc/59807616e1fa2540724bfbac14d7976d7e4a3860", checksumkind: CSK_MD5, checksum: "47fd4c3c8424e034238ec6bb5a169812")
!31 = !DINamespace(name: "{impl#2}", scope: !32)
!32 = !DINamespace(name: "map", scope: !33)
!33 = !DINamespace(name: "adapters", scope: !26)
!34 = distinct !DILocation(line: 51, column: 41, scope: !7)
!35 = !DILocation(line: 3051, column: 26, scope: !36, inlinedAt: !40)
!36 = distinct !DISubprogram(name: "overflowing_mul", linkageName: "_RNvMs9_NtCsgEmfK2I1SDS_4core3numj15overflowing_mul", scope: !38, file: !37, line: 3050, type: !13, scopeLine: 3050, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!37 = !DIFile(filename: "library/core/src/num/uint_macros.rs", directory: "/rustc/59807616e1fa2540724bfbac14d7976d7e4a3860", checksumkind: CSK_MD5, checksum: "de2f29a3485fc28d710ba6c3062e6efa")
!38 = !DINamespace(name: "{impl#11}", scope: !39)
!39 = !DINamespace(name: "num", scope: !27)
!40 = distinct !DILocation(line: 1161, column: 31, scope: !41, inlinedAt: !42)
!41 = distinct !DISubprogram(name: "checked_mul", linkageName: "_RNvMs9_NtCsgEmfK2I1SDS_4core3numj11checked_mul", scope: !38, file: !37, line: 1160, type: !13, scopeLine: 1160, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!42 = distinct !DILocation(line: 527, column: 39, scope: !43, inlinedAt: !49)
!43 = distinct !DILexicalBlock(scope: !45, file: !44, line: 527, column: 54)
!44 = !DIFile(filename: "library/core/src/alloc/layout.rs", directory: "/rustc/59807616e1fa2540724bfbac14d7976d7e4a3860", checksumkind: CSK_MD5, checksum: "742dc9b469eb35aa4fa4088d8f093c03")
!45 = distinct !DISubprogram(name: "repeat_packed", linkageName: "_RNvMNtNtCsgEmfK2I1SDS_4core5alloc6layoutNtB2_6Layout13repeat_packed", scope: !46, file: !44, line: 526, type: !13, scopeLine: 526, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!46 = !DINamespace(name: "Layout", scope: !47)
!47 = !DINamespace(name: "layout", scope: !48)
!48 = !DINamespace(name: "alloc", scope: !27)
!49 = distinct !DILocation(line: 900, column: 23, scope: !50, inlinedAt: !53)
!50 = distinct !DISubprogram(name: "layout_array", linkageName: "_RNvNtCslNYArtu3iFV_5alloc7raw_vec12layout_array", scope: !52, file: !51, line: 894, type: !13, scopeLine: 894, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!51 = !DIFile(filename: "library/alloc/src/raw_vec/mod.rs", directory: "/rustc/59807616e1fa2540724bfbac14d7976d7e4a3860", checksumkind: CSK_MD5, checksum: "78584250230dfe0aae92794a07566ae7")
!52 = !DINamespace(name: "raw_vec", scope: !12)
!53 = distinct !DILocation(line: 453, column: 28, scope: !54, inlinedAt: !56)
!54 = distinct !DISubprogram(name: "try_allocate_in<alloc::alloc::Global>", linkageName: "_ZN5alloc7raw_vec20RawVecInner$LT$A$GT$15try_allocate_in17h863d84537b3ee1b3E", scope: !55, file: !51, line: 445, type: !13, scopeLine: 445, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!55 = !DINamespace(name: "RawVecInner", scope: !52)
!56 = distinct !DILocation(line: 433, column: 15, scope: !57, inlinedAt: !58)
!57 = distinct !DISubprogram(name: "with_capacity_in<alloc::alloc::Global>", linkageName: "_ZN5alloc7raw_vec20RawVecInner$LT$A$GT$16with_capacity_in17h4b7c5b0a570540dbE", scope: !55, file: !51, line: 432, type: !13, scopeLine: 432, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!58 = distinct !DILocation(line: 177, column: 20, scope: !59, inlinedAt: !61)
!59 = distinct !DISubprogram(name: "with_capacity_in<bitcoin::blockdata::transaction::TxOut, alloc::alloc::Global>", linkageName: "_ZN5alloc7raw_vec19RawVec$LT$T$C$A$GT$16with_capacity_in17h2f63b0c2e0f1ff8dE", scope: !60, file: !51, line: 175, type: !13, scopeLine: 175, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!60 = !DINamespace(name: "RawVec", scope: !52)
!61 = !DILocation(line: 965, column: 20, scope: !62, inlinedAt: !65)
!62 = distinct !DISubprogram(name: "with_capacity_in<bitcoin::blockdata::transaction::TxOut, alloc::alloc::Global>", linkageName: "_ZN5alloc3vec16Vec$LT$T$C$A$GT$16with_capacity_in17h24cfd95cbd319d9cE", scope: !64, file: !63, line: 964, type: !13, scopeLine: 964, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!63 = !DIFile(filename: "library/alloc/src/vec/mod.rs", directory: "/rustc/59807616e1fa2540724bfbac14d7976d7e4a3860", checksumkind: CSK_MD5, checksum: "561105229399139e451a3aa6309b761e")
!64 = !DINamespace(name: "Vec", scope: !11)
!65 = !DILocation(line: 524, column: 9, scope: !66, inlinedAt: !67)
!66 = distinct !DISubprogram(name: "with_capacity<bitcoin::blockdata::transaction::TxOut>", linkageName: "_ZN5alloc3vec12Vec$LT$T$GT$13with_capacity17he515cbb961d4c987E", scope: !64, file: !63, line: 523, type: !13, scopeLine: 523, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!67 = !DILocation(line: 52, column: 33, scope: !68)
!68 = distinct !DILexicalBlock(scope: !7, file: !8, line: 52, column: 13)
!69 = !DILocation(line: 457, column: 8, scope: !70, inlinedAt: !73)
!70 = distinct !DISubprogram(name: "unlikely", linkageName: "_RNvNtCsgEmfK2I1SDS_4core10intrinsics8unlikely", scope: !72, file: !71, line: 456, type: !13, scopeLine: 456, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!71 = !DIFile(filename: "library/core/src/intrinsics/mod.rs", directory: "/rustc/59807616e1fa2540724bfbac14d7976d7e4a3860", checksumkind: CSK_MD5, checksum: "b1b7915c1b8b57766c20270acae549ce")
!72 = !DINamespace(name: "intrinsics", scope: !27)
!73 = distinct !DILocation(line: 1162, column: 16, scope: !74, inlinedAt: !42)
!74 = distinct !DILexicalBlock(scope: !41, file: !37, line: 1161, column: 13)
!75 = !{!"branch_weights", i32 2002, i32 2000}
!76 = !DILocation(line: 459, column: 12, scope: !77, inlinedAt: !56)
!77 = distinct !DILexicalBlock(scope: !54, file: !51, line: 453, column: 9)
!78 = !DILocation(line: 0, scope: !77, inlinedAt: !56)
!79 = !{!80}
!80 = distinct !{!80, !81, !"_ZN5alloc7raw_vec20RawVecInner$LT$A$GT$15try_allocate_in17h863d84537b3ee1b3E: %_0"}
!81 = distinct !{!81, !"_ZN5alloc7raw_vec20RawVecInner$LT$A$GT$15try_allocate_in17h863d84537b3ee1b3E"}
!82 = !DILocation(line: 95, column: 9, scope: !83, inlinedAt: !86)
!83 = distinct !DISubprogram(name: "alloc", linkageName: "_RNvNtCslNYArtu3iFV_5alloc5alloc5alloc", scope: !85, file: !84, line: 89, type: !13, scopeLine: 89, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!84 = !DIFile(filename: "library/alloc/src/alloc.rs", directory: "/rustc/59807616e1fa2540724bfbac14d7976d7e4a3860", checksumkind: CSK_MD5, checksum: "57066d22da38e4b1f3bfd29f3d5ff5ae")
!85 = !DINamespace(name: "alloc", scope: !12)
!86 = distinct !DILocation(line: 190, column: 73, scope: !87, inlinedAt: !90)
!87 = distinct !DILexicalBlock(scope: !88, file: !84, line: 189, column: 13)
!88 = distinct !DISubprogram(name: "alloc_impl_runtime", linkageName: "_RNvMNtCslNYArtu3iFV_5alloc5allocNtB2_6Global18alloc_impl_runtime", scope: !89, file: !84, line: 185, type: !13, scopeLine: 185, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!89 = !DINamespace(name: "Global", scope: !85)
!90 = distinct !DILocation(line: 312, column: 9, scope: !91, inlinedAt: !92)
!91 = distinct !DISubprogram(name: "alloc_impl", linkageName: "_RNvMNtCslNYArtu3iFV_5alloc5allocNtB2_6Global10alloc_impl", scope: !89, file: !84, line: 311, type: !13, scopeLine: 311, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!92 = distinct !DILocation(line: 429, column: 14, scope: !93, inlinedAt: !95)
!93 = distinct !DISubprogram(name: "allocate", linkageName: "_RNvXs_NtCslNYArtu3iFV_5alloc5allocNtB4_6GlobalNtNtCsgEmfK2I1SDS_4core5alloc9Allocator8allocate", scope: !94, file: !84, line: 428, type: !13, scopeLine: 428, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!94 = !DINamespace(name: "{impl#1}", scope: !85)
!95 = distinct !DILocation(line: 464, column: 47, scope: !77, inlinedAt: !56)
!96 = !DILocation(line: 468, column: 25, scope: !97, inlinedAt: !56)
!97 = distinct !DILexicalBlock(scope: !77, file: !51, line: 463, column: 9)
!98 = !DILocation(line: 468, column: 19, scope: !97, inlinedAt: !56)
!99 = !DILocation(line: 441, column: 25, scope: !100, inlinedAt: !58)
!100 = distinct !DILexicalBlock(scope: !57, file: !51, line: 441, column: 13)
!101 = !DILocation(line: 0, scope: !54, inlinedAt: !56)
!102 = !DILocation(line: 765, column: 9, scope: !103, inlinedAt: !104)
!103 = distinct !DISubprogram(name: "needs_to_grow<alloc::alloc::Global>", linkageName: "_ZN5alloc7raw_vec20RawVecInner$LT$A$GT$13needs_to_grow17h151518b8acd622bcE", scope: !55, file: !51, line: 764, type: !13, scopeLine: 764, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!104 = distinct !DILocation(line: 437, column: 50, scope: !105, inlinedAt: !58)
!105 = distinct !DILexicalBlock(scope: !57, file: !51, line: 434, column: 13)
!106 = !DILocation(line: 210, column: 9, scope: !107, inlinedAt: !110)
!107 = distinct !DISubprogram(name: "assert_unchecked", linkageName: "_RNvNtCsgEmfK2I1SDS_4core4hint16assert_unchecked", scope: !109, file: !108, line: 202, type: !13, scopeLine: 202, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!108 = !DIFile(filename: "library/core/src/hint.rs", directory: "/rustc/59807616e1fa2540724bfbac14d7976d7e4a3860", checksumkind: CSK_MD5, checksum: "2a901a283eb5f69871d8be07d256ca78")
!109 = !DINamespace(name: "hint", scope: !27)
!110 = distinct !DILocation(line: 437, column: 21, scope: !105, inlinedAt: !58)
!111 = !DILocation(line: 60, column: 28, scope: !112)
!112 = distinct !DILexicalBlock(scope: !7, file: !8, line: 51, column: 9)
!113 = !DILocation(line: 1916, column: 50, scope: !114, inlinedAt: !119)
!114 = distinct !DISubprogram(name: "lt", linkageName: "_RNvXsU_NtNtCsgEmfK2I1SDS_4core3cmp5implsjNtB7_10PartialOrd2lt", scope: !116, file: !115, line: 1916, type: !13, scopeLine: 1916, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!115 = !DIFile(filename: "library/core/src/cmp.rs", directory: "/rustc/59807616e1fa2540724bfbac14d7976d7e4a3860", checksumkind: CSK_MD5, checksum: "9b875f3ee90b4abbf50efdba3db39504")
!116 = !DINamespace(name: "{impl#58}", scope: !117)
!117 = !DINamespace(name: "impls", scope: !118)
!118 = !DINamespace(name: "cmp", scope: !27)
!119 = distinct !DILocation(line: 772, column: 12, scope: !120, inlinedAt: !122)
!120 = distinct !DISubprogram(name: "spec_next<usize>", linkageName: "_ZN89_$LT$core..ops..range..Range$LT$T$GT$$u20$as$u20$core..iter..range..RangeIteratorImpl$GT$9spec_next17h6aea1b1c48f9af4cE", scope: !121, file: !23, line: 771, type: !13, scopeLine: 771, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!121 = !DINamespace(name: "{impl#5}", scope: !25)
!122 = distinct !DILocation(line: 857, column: 14, scope: !123, inlinedAt: !124)
!123 = distinct !DISubprogram(name: "next<usize>", linkageName: "_ZN4core4iter5range101_$LT$impl$u20$core..iter..traits..iterator..Iterator$u20$for$u20$core..ops..range..Range$LT$A$GT$$GT$4next17h6b609cfe31821434E", scope: !24, file: !23, line: 856, type: !13, scopeLine: 856, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!124 = distinct !DILocation(line: 2646, column: 34, scope: !125, inlinedAt: !132)
!125 = distinct !DILexicalBlock(scope: !127, file: !126, line: 2646, column: 41)
!126 = !DIFile(filename: "library/core/src/iter/traits/iterator.rs", directory: "/rustc/59807616e1fa2540724bfbac14d7976d7e4a3860", checksumkind: CSK_MD5, checksum: "03f316921fc0b2bb7786dd4fa41456f9")
!127 = distinct !DILexicalBlock(scope: !128, file: !126, line: 2645, column: 9)
!128 = distinct !DISubprogram(name: "fold<core::ops::range::Range<usize>, (), core::iter::adapters::map::map_fold::{closure_env#0}<usize, bitcoin::blockdata::transaction::TxOut, (), rbitcoin_consensus::script::ffi::verify_impl::{closure_env#0}, core::iter::traits::iterator::Iterator::for_each::call::{closure_env#0}<bitcoin::blockdata::transaction::TxOut, alloc::vec::{impl#21}::extend_trusted::{closure_env#0}<bitcoin::blockdata::transaction::TxOut, alloc::alloc::Global, core::iter::adapters::map::Map<core::ops::range::Range<usize>, rbitcoin_consensus::script::ffi::verify_impl::{closure_env#0}>>>>>", linkageName: "_ZN4core4iter6traits8iterator8Iterator4fold17h5c61167e44d9de29E", scope: !129, file: !126, line: 2640, type: !13, scopeLine: 2640, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!129 = !DINamespace(name: "Iterator", scope: !130)
!130 = !DINamespace(name: "iterator", scope: !131)
!131 = !DINamespace(name: "traits", scope: !26)
!132 = distinct !DILocation(line: 128, column: 19, scope: !133, inlinedAt: !134)
!133 = distinct !DISubprogram(name: "fold<bitcoin::blockdata::transaction::TxOut, core::ops::range::Range<usize>, rbitcoin_consensus::script::ffi::verify_impl::{closure_env#0}, (), core::iter::traits::iterator::Iterator::for_each::call::{closure_env#0}<bitcoin::blockdata::transaction::TxOut, alloc::vec::{impl#21}::extend_trusted::{closure_env#0}<bitcoin::blockdata::transaction::TxOut, alloc::alloc::Global, core::iter::adapters::map::Map<core::ops::range::Range<usize>, rbitcoin_consensus::script::ffi::verify_impl::{closure_env#0}>>>>", linkageName: "_ZN102_$LT$core..iter..adapters..map..Map$LT$I$C$F$GT$$u20$as$u20$core..iter..traits..iterator..Iterator$GT$4fold17h08a732d7cd6a7c4eE", scope: !31, file: !30, line: 124, type: !13, scopeLine: 124, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!134 = distinct !DILocation(line: 845, column: 14, scope: !135, inlinedAt: !136)
!135 = distinct !DISubprogram(name: "for_each<core::iter::adapters::map::Map<core::ops::range::Range<usize>, rbitcoin_consensus::script::ffi::verify_impl::{closure_env#0}>, alloc::vec::{impl#21}::extend_trusted::{closure_env#0}<bitcoin::blockdata::transaction::TxOut, alloc::alloc::Global, core::iter::adapters::map::Map<core::ops::range::Range<usize>, rbitcoin_consensus::script::ffi::verify_impl::{closure_env#0}>>>", linkageName: "_ZN4core4iter6traits8iterator8Iterator8for_each17h5475f8bbf521be5eE", scope: !129, file: !126, line: 835, type: !13, scopeLine: 835, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!136 = distinct !DILocation(line: 4001, column: 26, scope: !137, inlinedAt: !142)
!137 = distinct !DILexicalBlock(scope: !138, file: !63, line: 4000, column: 17)
!138 = distinct !DILexicalBlock(scope: !139, file: !63, line: 3999, column: 17)
!139 = distinct !DILexicalBlock(scope: !140, file: !63, line: 3990, column: 40)
!140 = distinct !DILexicalBlock(scope: !141, file: !63, line: 3989, column: 9)
!141 = distinct !DISubprogram(name: "extend_trusted<bitcoin::blockdata::transaction::TxOut, alloc::alloc::Global, core::iter::adapters::map::Map<core::ops::range::Range<usize>, rbitcoin_consensus::script::ffi::verify_impl::{closure_env#0}>>", linkageName: "_ZN5alloc3vec16Vec$LT$T$C$A$GT$14extend_trusted17h8905d31d05ae9fc9E", scope: !64, file: !63, line: 3988, type: !13, scopeLine: 3988, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!142 = distinct !DILocation(line: 27, column: 14, scope: !143, inlinedAt: !147)
!143 = distinct !DISubprogram(name: "spec_extend<bitcoin::blockdata::transaction::TxOut, core::iter::adapters::map::Map<core::ops::range::Range<usize>, rbitcoin_consensus::script::ffi::verify_impl::{closure_env#0}>, alloc::alloc::Global>", linkageName: "_ZN97_$LT$alloc..vec..Vec$LT$T$C$A$GT$$u20$as$u20$alloc..vec..spec_extend..SpecExtend$LT$T$C$I$GT$$GT$11spec_extend17h96bb259d1f25c1b1E", scope: !145, file: !144, line: 26, type: !13, scopeLine: 26, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!144 = !DIFile(filename: "library/alloc/src/vec/spec_extend.rs", directory: "/rustc/59807616e1fa2540724bfbac14d7976d7e4a3860", checksumkind: CSK_MD5, checksum: "64fc232c5e502e0225698dc98d50caf8")
!145 = !DINamespace(name: "{impl#1}", scope: !146)
!146 = !DINamespace(name: "spec_extend", scope: !11)
!147 = distinct !DILocation(line: 60, column: 16, scope: !112)
!148 = !DILocation(line: 772, column: 12, scope: !120, inlinedAt: !122)
!149 = !DILocation(line: 844, column: 17, scope: !150, inlinedAt: !151)
!150 = distinct !DISubprogram(name: "unchecked_add", linkageName: "_RNvMs9_NtCsgEmfK2I1SDS_4core3numj13unchecked_add", scope: !38, file: !37, line: 832, type: !13, scopeLine: 832, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!151 = distinct !DILocation(line: 213, column: 28, scope: !152, inlinedAt: !154)
!152 = distinct !DISubprogram(name: "forward_unchecked", linkageName: "_RNvXsF_NtNtCsgEmfK2I1SDS_4core4iter5rangejNtB5_4Step17forward_unchecked", scope: !153, file: !23, line: 211, type: !13, scopeLine: 211, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!153 = !DINamespace(name: "{impl#43}", scope: !25)
!154 = distinct !DILocation(line: 775, column: 35, scope: !155, inlinedAt: !122)
!155 = distinct !DILexicalBlock(scope: !120, file: !23, line: 773, column: 13)
!156 = !DILocation(line: 135, column: 21, scope: !157, inlinedAt: !163)
!157 = distinct !DISubprogram(name: "{closure#0}", linkageName: "_ZN18rbitcoin_consensus6script3ffi11verify_impl28_$u7b$$u7b$closure$u7d$$u7d$17h2175e1177c5b1142E", scope: !159, file: !158, line: 134, type: !13, scopeLine: 134, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!158 = !DIFile(filename: "crates/rbitcoin-consensus/src/script/ffi.rs", directory: "/tmp/opencode/equiv-work/rbitcoin", checksumkind: CSK_MD5, checksum: "6719aed55dc65501694b1f27576ed9d6")
!159 = !DINamespace(name: "verify_impl", scope: !160)
!160 = !DINamespace(name: "ffi", scope: !161)
!161 = !DINamespace(name: "script", scope: !162)
!162 = !DINamespace(name: "rbitcoin_consensus", scope: null)
!163 = distinct !DILocation(line: 88, column: 28, scope: !164, inlinedAt: !166)
!164 = distinct !DISubprogram(name: "{closure#0}<usize, bitcoin::blockdata::transaction::TxOut, (), rbitcoin_consensus::script::ffi::verify_impl::{closure_env#0}, core::iter::traits::iterator::Iterator::for_each::call::{closure_env#0}<bitcoin::blockdata::transaction::TxOut, alloc::vec::{impl#21}::extend_trusted::{closure_env#0}<bitcoin::blockdata::transaction::TxOut, alloc::alloc::Global, core::iter::adapters::map::Map<core::ops::range::Range<usize>, rbitcoin_consensus::script::ffi::verify_impl::{closure_env#0}>>>>", linkageName: "_ZN4core4iter8adapters3map8map_fold28_$u7b$$u7b$closure$u7d$$u7d$17h837f94b8d4ce32e9E", scope: !165, file: !30, line: 88, type: !13, scopeLine: 88, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!165 = !DINamespace(name: "map_fold", scope: !32)
!166 = distinct !DILocation(line: 2647, column: 21, scope: !125, inlinedAt: !132)
!167 = !{!168, !170, !172, !174, !176, !177, !179, !180, !182, !183, !185}
!168 = distinct !{!168, !169, !"_ZN18rbitcoin_consensus6script3ffi11verify_impl28_$u7b$$u7b$closure$u7d$$u7d$17h2175e1177c5b1142E: %_0"}
!169 = distinct !{!169, !"_ZN18rbitcoin_consensus6script3ffi11verify_impl28_$u7b$$u7b$closure$u7d$$u7d$17h2175e1177c5b1142E"}
!170 = distinct !{!170, !171, !"_ZN4core4iter8adapters3map8map_fold28_$u7b$$u7b$closure$u7d$$u7d$17h837f94b8d4ce32e9E: %_1"}
!171 = distinct !{!171, !"_ZN4core4iter8adapters3map8map_fold28_$u7b$$u7b$closure$u7d$$u7d$17h837f94b8d4ce32e9E"}
!172 = distinct !{!172, !173, !"_ZN4core4iter6traits8iterator8Iterator4fold17h5c61167e44d9de29E: %f"}
!173 = distinct !{!173, !"_ZN4core4iter6traits8iterator8Iterator4fold17h5c61167e44d9de29E"}
!174 = distinct !{!174, !175, !"_ZN102_$LT$core..iter..adapters..map..Map$LT$I$C$F$GT$$u20$as$u20$core..iter..traits..iterator..Iterator$GT$4fold17h08a732d7cd6a7c4eE: %self"}
!175 = distinct !{!175, !"_ZN102_$LT$core..iter..adapters..map..Map$LT$I$C$F$GT$$u20$as$u20$core..iter..traits..iterator..Iterator$GT$4fold17h08a732d7cd6a7c4eE"}
!176 = distinct !{!176, !175, !"_ZN102_$LT$core..iter..adapters..map..Map$LT$I$C$F$GT$$u20$as$u20$core..iter..traits..iterator..Iterator$GT$4fold17h08a732d7cd6a7c4eE: %g"}
!177 = distinct !{!177, !178, !"_ZN4core4iter6traits8iterator8Iterator8for_each17h5475f8bbf521be5eE: %self"}
!178 = distinct !{!178, !"_ZN4core4iter6traits8iterator8Iterator8for_each17h5475f8bbf521be5eE"}
!179 = distinct !{!179, !178, !"_ZN4core4iter6traits8iterator8Iterator8for_each17h5475f8bbf521be5eE: %f"}
!180 = distinct !{!180, !181, !"_ZN5alloc3vec16Vec$LT$T$C$A$GT$14extend_trusted17h8905d31d05ae9fc9E: %self"}
!181 = distinct !{!181, !"_ZN5alloc3vec16Vec$LT$T$C$A$GT$14extend_trusted17h8905d31d05ae9fc9E"}
!182 = distinct !{!182, !181, !"_ZN5alloc3vec16Vec$LT$T$C$A$GT$14extend_trusted17h8905d31d05ae9fc9E: %iterator"}
!183 = distinct !{!183, !184, !"_ZN97_$LT$alloc..vec..Vec$LT$T$C$A$GT$$u20$as$u20$alloc..vec..spec_extend..SpecExtend$LT$T$C$I$GT$$GT$11spec_extend17h96bb259d1f25c1b1E: %self"}
!184 = distinct !{!184, !"_ZN97_$LT$alloc..vec..Vec$LT$T$C$A$GT$$u20$as$u20$alloc..vec..spec_extend..SpecExtend$LT$T$C$I$GT$$GT$11spec_extend17h96bb259d1f25c1b1E"}
!185 = distinct !{!185, !184, !"_ZN97_$LT$alloc..vec..Vec$LT$T$C$A$GT$$u20$as$u20$alloc..vec..spec_extend..SpecExtend$LT$T$C$I$GT$$GT$11spec_extend17h96bb259d1f25c1b1E: %iterator"}
!186 = !DILocation(line: 135, column: 16, scope: !157, inlinedAt: !163)
!187 = !DILocation(line: 868, column: 16, scope: !188, inlinedAt: !194)
!188 = distinct !DILexicalBlock(scope: !190, file: !189, line: 868, column: 16)
!189 = !DIFile(filename: "src/amount.rs", directory: "/home/ubuntu/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/bitcoin-units-0.1.101", checksumkind: CSK_MD5, checksum: "9ac93ec0234078317cf085ac1d9b427c")
!190 = distinct !DISubprogram(name: "clone", linkageName: "_ZN68_$LT$bitcoin_units..amount..Amount$u20$as$u20$core..clone..Clone$GT$5clone17hcffd042468fd237eE", scope: !191, file: !189, line: 868, type: !13, scopeLine: 868, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!191 = !DINamespace(name: "{impl#154}", scope: !192)
!192 = !DINamespace(name: "amount", scope: !193)
!193 = !DINamespace(name: "bitcoin_units", scope: null)
!194 = distinct !DILocation(line: 652, column: 10, scope: !195, inlinedAt: !201)
!195 = distinct !DISubprogram(name: "clone", linkageName: "_ZN77_$LT$bitcoin..blockdata..transaction..TxOut$u20$as$u20$core..clone..Clone$GT$5clone17hd037c2e3e77d8b01E", scope: !197, file: !196, line: 652, type: !13, scopeLine: 652, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!196 = !DIFile(filename: "src/blockdata/transaction.rs", directory: "/home/ubuntu/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/bitcoin-0.32.102", checksumkind: CSK_MD5, checksum: "5a3470065a613bef1811c2740cfe2f02")
!197 = !DINamespace(name: "{impl#125}", scope: !198)
!198 = !DINamespace(name: "transaction", scope: !199)
!199 = !DINamespace(name: "blockdata", scope: !200)
!200 = !DINamespace(name: "bitcoin", scope: null)
!201 = distinct !DILocation(line: 136, column: 24, scope: !157, inlinedAt: !163)
!202 = !DILocation(line: 39, column: 19, scope: !203, inlinedAt: !208)
!203 = distinct !DISubprogram(name: "clone", linkageName: "_ZN83_$LT$bitcoin..blockdata..script..owned..ScriptBuf$u20$as$u20$core..clone..Clone$GT$5clone17he1724358ad2f324eE", scope: !205, file: !204, line: 39, type: !13, scopeLine: 39, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!204 = !DIFile(filename: "src/blockdata/script/owned.rs", directory: "/home/ubuntu/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/bitcoin-0.32.102", checksumkind: CSK_MD5, checksum: "75b0b567ad5c0134cbb75d0bcb0fce73")
!205 = !DINamespace(name: "{impl#4}", scope: !206)
!206 = !DINamespace(name: "owned", scope: !207)
!207 = !DINamespace(name: "script", scope: !199)
!208 = distinct !DILocation(line: 652, column: 10, scope: !209, inlinedAt: !201)
!209 = !DILexicalBlockFile(scope: !195, file: !196, discriminator: 2)
!210 = !DILocation(line: 459, column: 12, scope: !77, inlinedAt: !211)
!211 = distinct !DILocation(line: 433, column: 15, scope: !57, inlinedAt: !212)
!212 = distinct !DILocation(line: 177, column: 20, scope: !213, inlinedAt: !214)
!213 = distinct !DISubprogram(name: "with_capacity_in<u8, alloc::alloc::Global>", linkageName: "_ZN5alloc7raw_vec19RawVec$LT$T$C$A$GT$16with_capacity_in17h0bdfdcf1695b87b8E", scope: !60, file: !51, line: 175, type: !13, scopeLine: 175, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!214 = distinct !DILocation(line: 965, column: 20, scope: !215, inlinedAt: !216)
!215 = distinct !DISubprogram(name: "with_capacity_in<u8, alloc::alloc::Global>", linkageName: "_ZN5alloc3vec16Vec$LT$T$C$A$GT$16with_capacity_in17h7bbe374ec8ebd6e6E", scope: !64, file: !63, line: 964, type: !13, scopeLine: 964, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!216 = distinct !DILocation(line: 448, column: 29, scope: !217, inlinedAt: !224)
!217 = distinct !DILexicalBlock(scope: !219, file: !218, line: 447, column: 17)
!218 = !DIFile(filename: "library/alloc/src/slice.rs", directory: "/rustc/59807616e1fa2540724bfbac14d7976d7e4a3860", checksumkind: CSK_MD5, checksum: "c354101fc648df7ae7a06556360deeb9")
!219 = distinct !DISubprogram(name: "to_vec<u8, alloc::alloc::Global>", linkageName: "_ZN87_$LT$T$u20$as$u20$alloc..slice..$LT$impl$u20$$u5b$T$u5d$$GT$..to_vec_in..ConvertVec$GT$6to_vec17h40185a762448c357E", scope: !220, file: !218, line: 446, type: !13, scopeLine: 446, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!220 = !DINamespace(name: "{impl#1}", scope: !221)
!221 = !DINamespace(name: "to_vec_in", scope: !222)
!222 = !DINamespace(name: "{impl#0}", scope: !223)
!223 = !DINamespace(name: "slice", scope: !12)
!224 = distinct !DILocation(line: 400, column: 16, scope: !225, inlinedAt: !226)
!225 = distinct !DISubprogram(name: "to_vec_in<u8, alloc::alloc::Global>", linkageName: "_ZN5alloc5slice29_$LT$impl$u20$$u5b$T$u5d$$GT$9to_vec_in17ha67aa4274a1d15f1E", scope: !222, file: !218, line: 396, type: !13, scopeLine: 396, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!226 = distinct !DILocation(line: 3749, column: 9, scope: !227, inlinedAt: !230)
!227 = distinct !DILexicalBlock(scope: !228, file: !63, line: 3748, column: 9)
!228 = distinct !DISubprogram(name: "clone<u8, alloc::alloc::Global>", linkageName: "_ZN67_$LT$alloc..vec..Vec$LT$T$C$A$GT$$u20$as$u20$core..clone..Clone$GT$5clone17hb1b34ee757dcdfc4E", scope: !229, file: !63, line: 3747, type: !13, scopeLine: 3747, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!229 = !DINamespace(name: "{impl#12}", scope: !11)
!230 = distinct !DILocation(line: 39, column: 19, scope: !203, inlinedAt: !208)
!231 = !DILocation(line: 0, scope: !77, inlinedAt: !211)
!232 = !{!233, !235, !237, !238, !168, !170, !172, !174, !176, !177, !179, !180, !182, !183, !185}
!233 = distinct !{!233, !234, !"_ZN5alloc7raw_vec20RawVecInner$LT$A$GT$15try_allocate_in17h863d84537b3ee1b3E: %_0"}
!234 = distinct !{!234, !"_ZN5alloc7raw_vec20RawVecInner$LT$A$GT$15try_allocate_in17h863d84537b3ee1b3E"}
!235 = distinct !{!235, !236, !"_ZN87_$LT$T$u20$as$u20$alloc..slice..$LT$impl$u20$$u5b$T$u5d$$GT$..to_vec_in..ConvertVec$GT$6to_vec17h40185a762448c357E: %v"}
!236 = distinct !{!236, !"_ZN87_$LT$T$u20$as$u20$alloc..slice..$LT$impl$u20$$u5b$T$u5d$$GT$..to_vec_in..ConvertVec$GT$6to_vec17h40185a762448c357E"}
!237 = distinct !{!237, !236, !"_ZN87_$LT$T$u20$as$u20$alloc..slice..$LT$impl$u20$$u5b$T$u5d$$GT$..to_vec_in..ConvertVec$GT$6to_vec17h40185a762448c357E: %s.0"}
!238 = distinct !{!238, !239, !"_ZN67_$LT$alloc..vec..Vec$LT$T$C$A$GT$$u20$as$u20$core..clone..Clone$GT$5clone17hb1b34ee757dcdfc4E: %_0"}
!239 = distinct !{!239, !"_ZN67_$LT$alloc..vec..Vec$LT$T$C$A$GT$$u20$as$u20$core..clone..Clone$GT$5clone17hb1b34ee757dcdfc4E"}
!240 = !DILocation(line: 95, column: 9, scope: !83, inlinedAt: !241)
!241 = distinct !DILocation(line: 190, column: 73, scope: !87, inlinedAt: !242)
!242 = distinct !DILocation(line: 312, column: 9, scope: !91, inlinedAt: !243)
!243 = distinct !DILocation(line: 429, column: 14, scope: !93, inlinedAt: !244)
!244 = distinct !DILocation(line: 464, column: 47, scope: !77, inlinedAt: !211)
!245 = !DILocation(line: 468, column: 25, scope: !97, inlinedAt: !211)
!246 = !DILocation(line: 468, column: 19, scope: !97, inlinedAt: !211)
!247 = !DILocation(line: 441, column: 25, scope: !100, inlinedAt: !212)
!248 = !{!235, !237, !238, !168, !170, !172, !174, !176, !177, !179, !180, !182, !183, !185}
!249 = !DILocation(line: 547, column: 14, scope: !250, inlinedAt: !253)
!250 = distinct !DISubprogram(name: "copy_nonoverlapping<u8>", linkageName: "_ZN4core3ptr19copy_nonoverlapping17heb33bba51c9dc77cE", scope: !252, file: !251, line: 526, type: !13, scopeLine: 526, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!251 = !DIFile(filename: "library/core/src/ptr/mod.rs", directory: "/rustc/59807616e1fa2540724bfbac14d7976d7e4a3860", checksumkind: CSK_MD5, checksum: "8f706ae0a0620120e6e931983ef127f1")
!252 = !DINamespace(name: "ptr", scope: !27)
!253 = distinct !DILocation(line: 1252, column: 18, scope: !254, inlinedAt: !258)
!254 = distinct !DISubprogram(name: "copy_to_nonoverlapping<u8>", linkageName: "_ZN4core3ptr9const_ptr33_$LT$impl$u20$$BP$const$u20$T$GT$22copy_to_nonoverlapping17h9f85b7ce45773255E", scope: !256, file: !255, line: 1247, type: !13, scopeLine: 1247, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!255 = !DIFile(filename: "library/core/src/ptr/const_ptr.rs", directory: "/rustc/59807616e1fa2540724bfbac14d7976d7e4a3860", checksumkind: CSK_MD5, checksum: "48638a38fe414ca30cde797e4a40b3a9")
!256 = !DINamespace(name: "{impl#0}", scope: !257)
!257 = !DINamespace(name: "const_ptr", scope: !252)
!258 = distinct !DILocation(line: 454, column: 36, scope: !259, inlinedAt: !224)
!259 = distinct !DILexicalBlock(scope: !217, file: !218, line: 448, column: 17)
!260 = !{!235, !238, !168, !170, !172, !174, !176, !177, !179, !180, !182, !183, !185}
!261 = !DILocation(line: 452, column: 17, scope: !259, inlinedAt: !224)
!262 = !DILocation(line: 961, column: 18, scope: !263, inlinedAt: !267)
!263 = distinct !DISubprogram(name: "add<bitcoin::blockdata::transaction::TxOut>", linkageName: "_ZN4core3ptr7mut_ptr31_$LT$impl$u20$$BP$mut$u20$T$GT$3add17h074283200187d322E", scope: !265, file: !264, line: 927, type: !13, scopeLine: 927, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!264 = !DIFile(filename: "library/core/src/ptr/mut_ptr.rs", directory: "/rustc/59807616e1fa2540724bfbac14d7976d7e4a3860", checksumkind: CSK_MD5, checksum: "7c03c8e0ae695174f7f10881dc49d2cb")
!265 = !DINamespace(name: "{impl#0}", scope: !266)
!266 = !DINamespace(name: "mut_ptr", scope: !252)
!267 = distinct !DILocation(line: 4002, column: 36, scope: !268, inlinedAt: !271)
!268 = distinct !DISubprogram(name: "{closure#0}<bitcoin::blockdata::transaction::TxOut, alloc::alloc::Global, core::iter::adapters::map::Map<core::ops::range::Range<usize>, rbitcoin_consensus::script::ffi::verify_impl::{closure_env#0}>>", linkageName: "_ZN5alloc3vec16Vec$LT$T$C$A$GT$14extend_trusted28_$u7b$$u7b$closure$u7d$$u7d$17hf48f6adbe879c4fdE", scope: !269, file: !63, line: 4001, type: !13, scopeLine: 4001, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!269 = !DINamespace(name: "extend_trusted", scope: !270)
!270 = !DINamespace(name: "{impl#21}", scope: !11)
!271 = distinct !DILocation(line: 842, column: 29, scope: !272, inlinedAt: !275)
!272 = distinct !DISubprogram(name: "{closure#0}<bitcoin::blockdata::transaction::TxOut, alloc::vec::{impl#21}::extend_trusted::{closure_env#0}<bitcoin::blockdata::transaction::TxOut, alloc::alloc::Global, core::iter::adapters::map::Map<core::ops::range::Range<usize>, rbitcoin_consensus::script::ffi::verify_impl::{closure_env#0}>>>", linkageName: "_ZN4core4iter6traits8iterator8Iterator8for_each4call28_$u7b$$u7b$closure$u7d$$u7d$17hdb0fba580f4f5b48E", scope: !273, file: !126, line: 842, type: !13, scopeLine: 842, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!273 = !DINamespace(name: "call", scope: !274)
!274 = !DINamespace(name: "for_each", scope: !129)
!275 = distinct !DILocation(line: 88, column: 21, scope: !164, inlinedAt: !166)
!276 = !DILocation(line: 1917, column: 41, scope: !277, inlinedAt: !278)
!277 = distinct !DISubprogram(name: "write<bitcoin::blockdata::transaction::TxOut>", linkageName: "_ZN4core3ptr5write17h485604ff6480eaa5E", scope: !252, file: !251, line: 1894, type: !13, scopeLine: 1894, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!278 = distinct !DILocation(line: 4002, column: 21, scope: !268, inlinedAt: !271)
!279 = !{!280, !282, !170, !172, !174, !176, !177, !179, !180, !182, !183, !185}
!280 = distinct !{!280, !281, !"_ZN5alloc3vec16Vec$LT$T$C$A$GT$14extend_trusted28_$u7b$$u7b$closure$u7d$$u7d$17hf48f6adbe879c4fdE: %_1"}
!281 = distinct !{!281, !"_ZN5alloc3vec16Vec$LT$T$C$A$GT$14extend_trusted28_$u7b$$u7b$closure$u7d$$u7d$17hf48f6adbe879c4fdE"}
!282 = distinct !{!282, !283, !"_ZN4core4iter6traits8iterator8Iterator8for_each4call28_$u7b$$u7b$closure$u7d$$u7d$17hdb0fba580f4f5b48E: %_1"}
!283 = distinct !{!283, !"_ZN4core4iter6traits8iterator8Iterator8for_each4call28_$u7b$$u7b$closure$u7d$$u7d$17hdb0fba580f4f5b48E"}
!284 = !DILocation(line: 19, column: 9, scope: !285, inlinedAt: !289)
!285 = distinct !DISubprogram(name: "increment_len", linkageName: "_RNvMNtNtCslNYArtu3iFV_5alloc3vec15set_len_on_dropNtB2_12SetLenOnDrop13increment_len", scope: !287, file: !286, line: 18, type: !13, scopeLine: 18, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !14)
!286 = !DIFile(filename: "library/alloc/src/vec/set_len_on_drop.rs", directory: "/rustc/59807616e1fa2540724bfbac14d7976d7e4a3860", checksumkind: CSK_MD5, checksum: "9a0d01ce4a85900df996691fa734ffd7")
!287 = !DINamespace(name: "SetLenOnDrop", scope: !288)
!288 = !DINamespace(name: "set_len_on_drop", scope: !11)
!289 = distinct !DILocation(line: 4006, column: 31, scope: !268, inlinedAt: !271)
!290 = !DILocation(line: 2650, column: 5, scope: !128, inlinedAt: !132)
!291 = !DILocation(line: 61, column: 9, scope: !112)
!292 = !DILocation(line: 62, column: 6, scope: !7)
