; ModuleID = 'tools/tests/probes/memory.c'
source_filename = "tools/tests/probes/memory.c"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: noinline nounwind optnone uwtable
define dso_local i32 @store_load(ptr noundef %0, i32 noundef %1) #0 !dbg !10 {
  %3 = alloca ptr, align 8
  %4 = alloca i32, align 4
  store ptr %0, ptr %3, align 8
    #dbg_declare(ptr %3, !16, !DIExpression(), !17)
  store i32 %1, ptr %4, align 4
    #dbg_declare(ptr %4, !18, !DIExpression(), !19)
  %5 = load i32, ptr %4, align 4, !dbg !20
  %6 = load ptr, ptr %3, align 8, !dbg !21
  store i32 %5, ptr %6, align 4, !dbg !22
  %7 = load ptr, ptr %3, align 8, !dbg !23
  %8 = load i32, ptr %7, align 4, !dbg !24
  ret i32 %8, !dbg !25
}

attributes #0 = { noinline nounwind optnone uwtable "frame-pointer"="all" "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!2, !3, !4, !5, !6, !7, !8}
!llvm.ident = !{!9}

!0 = distinct !DICompileUnit(language: DW_LANG_C11, file: !1, producer: "Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)", isOptimized: false, runtimeVersion: 0, emissionKind: FullDebug, splitDebugInlining: false, nameTableKind: None)
!1 = !DIFile(filename: "tools/tests/probes/memory.c", directory: "/home/ubuntu/btc-lean-public/spec/equiv", checksumkind: CSK_MD5, checksum: "67c56d2b44b952b38afded03044e073c")
!2 = !{i32 7, !"Dwarf Version", i32 5}
!3 = !{i32 2, !"Debug Info Version", i32 3}
!4 = !{i32 1, !"wchar_size", i32 4}
!5 = !{i32 8, !"PIC Level", i32 2}
!6 = !{i32 7, !"PIE Level", i32 2}
!7 = !{i32 7, !"uwtable", i32 2}
!8 = !{i32 7, !"frame-pointer", i32 2}
!9 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
!10 = distinct !DISubprogram(name: "store_load", scope: !1, file: !1, line: 1, type: !11, scopeLine: 1, flags: DIFlagPrototyped, spFlags: DISPFlagDefinition, unit: !0, retainedNodes: !15)
!11 = !DISubroutineType(types: !12)
!12 = !{!13, !14, !13}
!13 = !DIBasicType(name: "int", size: 32, encoding: DW_ATE_signed)
!14 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !13, size: 64)
!15 = !{}
!16 = !DILocalVariable(name: "p", arg: 1, scope: !10, file: !1, line: 1, type: !14)
!17 = !DILocation(line: 1, column: 21, scope: !10)
!18 = !DILocalVariable(name: "v", arg: 2, scope: !10, file: !1, line: 1, type: !13)
!19 = !DILocation(line: 1, column: 28, scope: !10)
!20 = !DILocation(line: 1, column: 38, scope: !10)
!21 = !DILocation(line: 1, column: 34, scope: !10)
!22 = !DILocation(line: 1, column: 36, scope: !10)
!23 = !DILocation(line: 1, column: 49, scope: !10)
!24 = !DILocation(line: 1, column: 48, scope: !10)
!25 = !DILocation(line: 1, column: 41, scope: !10)
