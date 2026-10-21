@alloc_ed7ef490eb9982594db0729b00e3e41b = external hidden unnamed_addr constant <{ ptr, [16 x i8] }>, align 8

; Function Attrs: cold noinline noreturn nounwind nonlazybind uwtable
declare void @_RNvNtNtCsgEmfK2I1SDS_4core5slice5index16slice_index_fail(i64 noundef, i64 noundef, i64 noundef, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24)) unnamed_addr #1


; Function Attrs: nounwind nonlazybind uwtable
define hidden fastcc { ptr, i64 } @src(ptr noundef nonnull readonly align 8 captures(none) %ctx) unnamed_addr #0 !dbg !7 {
start:
  %0 = getelementptr inbounds nuw i8, ptr %ctx, i64 144, !dbg !14
  %_5.0 = load ptr, ptr %0, align 8, !dbg !14, !nonnull !13, !align !15, !noundef !13
  %1 = getelementptr inbounds nuw i8, ptr %ctx, i64 152, !dbg !14
  %_5.1 = load i64, ptr %1, align 8, !dbg !14, !noundef !13
  %_7 = getelementptr inbounds nuw i8, ptr %ctx, i64 128, !dbg !16
  %2 = load i64, ptr %_7, align 8, !dbg !27, !range !28, !noundef !13
  %3 = getelementptr inbounds nuw i8, ptr %ctx, i64 136, !dbg !27
  %4 = load i64, ptr %3, align 8, !dbg !27
  %5 = trunc nuw i64 %2 to i1, !dbg !29
  br i1 %5, label %bb2, label %bb3, !dbg !29

bb2:                                              ; preds = %start
  %_8 = icmp ugt i64 %4, %_5.1, !dbg !30
  br i1 %_8, label %bb4, label %bb5, !dbg !30, !prof !41

bb5:                                              ; preds = %bb2
  %_11 = sub nuw i64 %_5.1, %4, !dbg !42
  %_15 = getelementptr inbounds nuw i8, ptr %_5.0, i64 %4, !dbg !43
  br label %bb3, !dbg !48

bb4:                                              ; preds = %bb2
  tail call void @_RNvNtNtCsgEmfK2I1SDS_4core5slice5index16slice_index_fail(i64 noundef %4, i64 noundef %_5.1, i64 noundef %_5.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_ed7ef490eb9982594db0729b00e3e41b) #2, !dbg !49
  unreachable, !dbg !49

bb3:                                              ; preds = %bb5, %start
  %full.sroa.4.0 = phi i64 [ %_11, %bb5 ], [ %_5.1, %start ], !dbg !50
  %full.sroa.0.0 = phi ptr [ %_15, %bb5 ], [ %_5.0, %start ], !dbg !50
  %6 = insertvalue { ptr, i64 } poison, ptr %full.sroa.0.0, 0, !dbg !51
  %7 = insertvalue { ptr, i64 } %6, i64 %full.sroa.4.0, 1, !dbg !51
  ret { ptr, i64 } %7, !dbg !51
}


; Function Attrs: nounwind nonlazybind uwtable
define hidden fastcc { ptr, i64 } @tgt(ptr noundef nonnull readonly align 8 captures(none) %ctx) unnamed_addr #0 !dbg !7 {
start:
  %0 = getelementptr inbounds nuw i8, ptr %ctx, i64 144, !dbg !14
  %_5.0 = load ptr, ptr %0, align 8, !dbg !14, !nonnull !13, !align !15, !noundef !13
  %1 = getelementptr inbounds nuw i8, ptr %ctx, i64 152, !dbg !14
  %_5.1 = load i64, ptr %1, align 8, !dbg !14, !noundef !13
  %_7 = getelementptr inbounds nuw i8, ptr %ctx, i64 128, !dbg !16
  %2 = load i64, ptr %_7, align 8, !dbg !27, !range !28, !noundef !13
  %3 = getelementptr inbounds nuw i8, ptr %ctx, i64 136, !dbg !27
  %4 = load i64, ptr %3, align 8, !dbg !27
  %5 = icmp eq i64 %2, 1
  br i1 %5, label %bb2, label %bb3

bb2:                                              ; preds = %start
  %_8 = icmp ugt i64 %4, %_5.1, !dbg !30
  br i1 %_8, label %bb4, label %bb5, !dbg !30, !prof !41

bb5:                                              ; preds = %bb2
  %_11 = sub nuw i64 %_5.1, %4, !dbg !42
  %_15 = getelementptr inbounds nuw i8, ptr %_5.0, i64 %4, !dbg !43
  br label %bb3, !dbg !48

bb4:                                              ; preds = %bb2
  tail call void @_RNvNtNtCsgEmfK2I1SDS_4core5slice5index16slice_index_fail(i64 noundef %4, i64 noundef %_5.1, i64 noundef %_5.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_ed7ef490eb9982594db0729b00e3e41b) #2, !dbg !49
  unreachable, !dbg !49

bb3:                                              ; preds = %bb5, %start
  %full.sroa.4.0 = phi i64 [ %_11, %bb5 ], [ %_5.1, %start ], !dbg !50
  %full.sroa.0.0 = phi ptr [ %_15, %bb5 ], [ %_5.0, %start ], !dbg !50
  %6 = insertvalue { ptr, i64 } poison, ptr %full.sroa.0.0, 0, !dbg !51
  %7 = insertvalue { ptr, i64 } %6, i64 %full.sroa.4.0, 1, !dbg !51
  ret { ptr, i64 } %7, !dbg !51
}


attributes #0 = { nounwind nonlazybind uwtable "probe-stack"="inline-asm" "target-cpu"="x86-64" }
attributes #1 = { cold noinline noreturn nounwind nonlazybind uwtable "probe-stack"="inline-asm" "target-cpu"="x86-64" }
attributes #2 = { noinline noreturn nounwind }

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
!7 = distinct !DISubprogram(name: "script_code_bytes", linkageName: "_ZN18rbitcoin_consensus6script11interpreter17script_code_bytes17h40d2a455b3d63addE", scope: !9, file: !8, line: 1249, type: !12, scopeLine: 1249, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !13)
!8 = !DIFile(filename: "crates/rbitcoin-consensus/src/script/interpreter.rs", directory: "/tmp/opencode/equiv-work/rbitcoin", checksumkind: CSK_MD5, checksum: "43ff25281d01a03a992b7854e2465ace")
!9 = !DINamespace(name: "interpreter", scope: !10)
!10 = !DINamespace(name: "script", scope: !11)
!11 = !DINamespace(name: "rbitcoin_consensus", scope: null)
!12 = !DISubroutineType(types: !13)
!13 = !{}
!14 = !DILocation(line: 1250, column: 16, scope: !7)
!15 = !{i64 1}
!16 = !DILocation(line: 2447, column: 9, scope: !17, inlinedAt: !22)
!17 = distinct !DISubprogram(name: "get<core::option::Option<usize>>", linkageName: "_ZN4core4cell19UnsafeCell$LT$T$GT$3get17h8838bf215af7d593E", scope: !19, file: !18, line: 2443, type: !12, scopeLine: 2443, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !13)
!18 = !DIFile(filename: "library/core/src/cell.rs", directory: "/rustc/59807616e1fa2540724bfbac14d7976d7e4a3860", checksumkind: CSK_MD5, checksum: "96404e804c6faf0fea9fa631bcb8d1d2")
!19 = !DINamespace(name: "UnsafeCell", scope: !20)
!20 = !DINamespace(name: "cell", scope: !21)
!21 = !DINamespace(name: "core", scope: null)
!22 = !DILocation(line: 555, column: 30, scope: !23, inlinedAt: !25)
!23 = distinct !DISubprogram(name: "get<core::option::Option<usize>>", linkageName: "_ZN4core4cell13Cell$LT$T$GT$3get17hefd2472ecaedf1deE", scope: !24, file: !18, line: 552, type: !12, scopeLine: 552, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !13)
!24 = !DINamespace(name: "Cell", scope: !20)
!25 = !DILocation(line: 1251, column: 40, scope: !26)
!26 = distinct !DILexicalBlock(scope: !7, file: !8, line: 1250, column: 5)
!27 = !DILocation(line: 555, column: 18, scope: !23, inlinedAt: !25)
!28 = !{i64 0, i64 2}
!29 = !DILocation(line: 1251, column: 5, scope: !26)
!30 = !DILocation(line: 568, column: 12, scope: !31, inlinedAt: !36)
!31 = distinct !DISubprogram(name: "index<u8>", linkageName: "_ZN110_$LT$core..ops..range..RangeFrom$LT$usize$GT$$u20$as$u20$core..slice..index..SliceIndex$LT$$u5b$T$u5d$$GT$$GT$5index17h41b5b1acb78497f6E", scope: !33, file: !32, line: 567, type: !12, scopeLine: 567, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !13)
!32 = !DIFile(filename: "library/core/src/slice/index.rs", directory: "/rustc/59807616e1fa2540724bfbac14d7976d7e4a3860", checksumkind: CSK_MD5, checksum: "35f1d9855ef780cd44773269ad8900cd")
!33 = !DINamespace(name: "{impl#7}", scope: !34)
!34 = !DINamespace(name: "index", scope: !35)
!35 = !DINamespace(name: "slice", scope: !21)
!36 = !DILocation(line: 19, column: 15, scope: !37, inlinedAt: !39)
!37 = distinct !DISubprogram(name: "index<u8, core::ops::range::RangeFrom<usize>>", linkageName: "_ZN4core5slice5index74_$LT$impl$u20$core..ops..index..Index$LT$I$GT$$u20$for$u20$$u5b$T$u5d$$GT$5index17h4364d227090c54e4E", scope: !38, file: !32, line: 18, type: !12, scopeLine: 18, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !13)
!38 = !DINamespace(name: "{impl#0}", scope: !34)
!39 = !DILocation(line: 1253, column: 27, scope: !40)
!40 = distinct !DILexicalBlock(scope: !26, file: !8, line: 1253, column: 9)
!41 = !{!"branch_weights", !"expected", i32 1, i32 2000}
!42 = !DILocation(line: 573, column: 27, scope: !31, inlinedAt: !36)
!43 = !DILocation(line: 89, column: 24, scope: !44, inlinedAt: !46)
!44 = distinct !DILexicalBlock(scope: !45, file: !32, line: 87, column: 5)
!45 = distinct !DISubprogram(name: "get_offset_len_noubcheck<u8>", linkageName: "_ZN4core5slice5index24get_offset_len_noubcheck17hedbc2dee5880cc6aE", scope: !34, file: !32, line: 82, type: !12, scopeLine: 82, flags: DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !5, templateParams: !13)
!46 = !DILocation(line: 574, column: 15, scope: !47, inlinedAt: !36)
!47 = distinct !DILexicalBlock(scope: !31, file: !32, line: 573, column: 13)
!48 = !DILocation(line: 1253, column: 33, scope: !26)
!49 = !DILocation(line: 569, column: 13, scope: !31, inlinedAt: !36)
!50 = !DILocation(line: 0, scope: !7)
!51 = !DILocation(line: 1256, column: 2, scope: !7)
