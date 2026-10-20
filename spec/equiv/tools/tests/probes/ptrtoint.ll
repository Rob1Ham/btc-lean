; ModuleID = 'tools/tests/probes/ptrtoint.c'
source_filename = "tools/tests/probes/ptrtoint.c"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: noinline nounwind optnone uwtable
define dso_local i64 @p2i(ptr noundef %0) #0 !dbg !15 {
  %2 = alloca ptr, align 8
  store ptr %0, ptr %2, align 8
    #dbg_declare(ptr %2, !18, !DIExpression(), !19)
  %3 = load ptr, ptr %2, align 8, !dbg !20
  %4 = ptrtoint ptr %3 to i64, !dbg !21
  ret i64 %4, !dbg !22
}

; Function Attrs: noinline nounwind optnone uwtable
define dso_local ptr @i2p(i64 noundef %0) #0 !dbg !23 {
  %2 = alloca i64, align 8
  store i64 %0, ptr %2, align 8
    #dbg_declare(ptr %2, !26, !DIExpression(), !27)
  %3 = load i64, ptr %2, align 8, !dbg !28
  %4 = inttoptr i64 %3 to ptr, !dbg !29
  ret ptr %4, !dbg !30
}

attributes #0 = { noinline nounwind optnone uwtable "frame-pointer"="all" "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!7, !8, !9, !10, !11, !12, !13}
!llvm.ident = !{!14}

!0 = distinct !DICompileUnit(language: DW_LANG_C11, file: !1, producer: "Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)", isOptimized: false, runtimeVersion: 0, emissionKind: FullDebug, retainedTypes: !2, splitDebugInlining: false, nameTableKind: None)
!1 = !DIFile(filename: "tools/tests/probes/ptrtoint.c", directory: "/home/ubuntu/btc-lean-public/spec/equiv", checksumkind: CSK_MD5, checksum: "e28399d0d965d1e74381e7529699b19a")
!2 = !{!3, !6}
!3 = !DIDerivedType(tag: DW_TAG_typedef, name: "uintptr_t", file: !4, line: 79, baseType: !5)
!4 = !DIFile(filename: "/usr/include/stdint.h", directory: "", checksumkind: CSK_MD5, checksum: "bfb03fa9c46a839e35c32b929fbdbb8e")
!5 = !DIBasicType(name: "unsigned long", size: 64, encoding: DW_ATE_unsigned)
!6 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: null, size: 64)
!7 = !{i32 7, !"Dwarf Version", i32 5}
!8 = !{i32 2, !"Debug Info Version", i32 3}
!9 = !{i32 1, !"wchar_size", i32 4}
!10 = !{i32 8, !"PIC Level", i32 2}
!11 = !{i32 7, !"PIE Level", i32 2}
!12 = !{i32 7, !"uwtable", i32 2}
!13 = !{i32 7, !"frame-pointer", i32 2}
!14 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
!15 = distinct !DISubprogram(name: "p2i", scope: !1, file: !1, line: 2, type: !16, scopeLine: 2, flags: DIFlagPrototyped, spFlags: DISPFlagDefinition, unit: !0, retainedNodes: !17)
!16 = !DISubroutineType(types: !2)
!17 = !{}
!18 = !DILocalVariable(name: "p", arg: 1, scope: !15, file: !1, line: 2, type: !6)
!19 = !DILocation(line: 2, column: 21, scope: !15)
!20 = !DILocation(line: 2, column: 44, scope: !15)
!21 = !DILocation(line: 2, column: 33, scope: !15)
!22 = !DILocation(line: 2, column: 26, scope: !15)
!23 = distinct !DISubprogram(name: "i2p", scope: !1, file: !1, line: 3, type: !24, scopeLine: 3, flags: DIFlagPrototyped, spFlags: DISPFlagDefinition, unit: !0, retainedNodes: !17)
!24 = !DISubroutineType(types: !25)
!25 = !{!6, !3}
!26 = !DILocalVariable(name: "x", arg: 1, scope: !23, file: !1, line: 3, type: !3)
!27 = !DILocation(line: 3, column: 21, scope: !23)
!28 = !DILocation(line: 3, column: 41, scope: !23)
!29 = !DILocation(line: 3, column: 33, scope: !23)
!30 = !DILocation(line: 3, column: 26, scope: !23)
