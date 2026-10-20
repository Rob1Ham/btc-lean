; ModuleID = 'tools/tests/probes/loop.c'
source_filename = "tools/tests/probes/loop.c"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: noinline nounwind optnone uwtable
define dso_local i32 @sum_to(i32 noundef %0) #0 !dbg !10 {
  %2 = alloca i32, align 4
  %3 = alloca i32, align 4
  %4 = alloca i32, align 4
  store i32 %0, ptr %2, align 4
    #dbg_declare(ptr %2, !15, !DIExpression(), !16)
    #dbg_declare(ptr %3, !17, !DIExpression(), !18)
  store i32 0, ptr %3, align 4, !dbg !18
    #dbg_declare(ptr %4, !19, !DIExpression(), !21)
  store i32 0, ptr %4, align 4, !dbg !21
  br label %5, !dbg !22

5:                                                ; preds = %13, %1
  %6 = load i32, ptr %4, align 4, !dbg !23
  %7 = load i32, ptr %2, align 4, !dbg !25
  %8 = icmp slt i32 %6, %7, !dbg !26
  br i1 %8, label %9, label %16, !dbg !27

9:                                                ; preds = %5
  %10 = load i32, ptr %4, align 4, !dbg !28
  %11 = load i32, ptr %3, align 4, !dbg !29
  %12 = add nsw i32 %11, %10, !dbg !29
  store i32 %12, ptr %3, align 4, !dbg !29
  br label %13, !dbg !30

13:                                               ; preds = %9
  %14 = load i32, ptr %4, align 4, !dbg !31
  %15 = add nsw i32 %14, 1, !dbg !31
  store i32 %15, ptr %4, align 4, !dbg !31
  br label %5, !dbg !32, !llvm.loop !33

16:                                               ; preds = %5
  %17 = load i32, ptr %3, align 4, !dbg !36
  ret i32 %17, !dbg !37
}

attributes #0 = { noinline nounwind optnone uwtable "frame-pointer"="all" "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!2, !3, !4, !5, !6, !7, !8}
!llvm.ident = !{!9}

!0 = distinct !DICompileUnit(language: DW_LANG_C11, file: !1, producer: "Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)", isOptimized: false, runtimeVersion: 0, emissionKind: FullDebug, splitDebugInlining: false, nameTableKind: None)
!1 = !DIFile(filename: "tools/tests/probes/loop.c", directory: "/home/ubuntu/btc-lean-public/spec/equiv", checksumkind: CSK_MD5, checksum: "bd831e6351ffe8eb9ba7a0c8c9d625de")
!2 = !{i32 7, !"Dwarf Version", i32 5}
!3 = !{i32 2, !"Debug Info Version", i32 3}
!4 = !{i32 1, !"wchar_size", i32 4}
!5 = !{i32 8, !"PIC Level", i32 2}
!6 = !{i32 7, !"PIE Level", i32 2}
!7 = !{i32 7, !"uwtable", i32 2}
!8 = !{i32 7, !"frame-pointer", i32 2}
!9 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
!10 = distinct !DISubprogram(name: "sum_to", scope: !1, file: !1, line: 1, type: !11, scopeLine: 1, flags: DIFlagPrototyped, spFlags: DISPFlagDefinition, unit: !0, retainedNodes: !14)
!11 = !DISubroutineType(types: !12)
!12 = !{!13, !13}
!13 = !DIBasicType(name: "int", size: 32, encoding: DW_ATE_signed)
!14 = !{}
!15 = !DILocalVariable(name: "n", arg: 1, scope: !10, file: !1, line: 1, type: !13)
!16 = !DILocation(line: 1, column: 16, scope: !10)
!17 = !DILocalVariable(name: "s", scope: !10, file: !1, line: 1, type: !13)
!18 = !DILocation(line: 1, column: 25, scope: !10)
!19 = !DILocalVariable(name: "i", scope: !20, file: !1, line: 1, type: !13)
!20 = distinct !DILexicalBlock(scope: !10, file: !1, line: 1, column: 32)
!21 = !DILocation(line: 1, column: 41, scope: !20)
!22 = !DILocation(line: 1, column: 37, scope: !20)
!23 = !DILocation(line: 1, column: 48, scope: !24)
!24 = distinct !DILexicalBlock(scope: !20, file: !1, line: 1, column: 32)
!25 = !DILocation(line: 1, column: 52, scope: !24)
!26 = !DILocation(line: 1, column: 50, scope: !24)
!27 = !DILocation(line: 1, column: 32, scope: !20)
!28 = !DILocation(line: 1, column: 65, scope: !24)
!29 = !DILocation(line: 1, column: 62, scope: !24)
!30 = !DILocation(line: 1, column: 60, scope: !24)
!31 = !DILocation(line: 1, column: 56, scope: !24)
!32 = !DILocation(line: 1, column: 32, scope: !24)
!33 = distinct !{!33, !27, !34, !35}
!34 = !DILocation(line: 1, column: 65, scope: !20)
!35 = !{!"llvm.loop.mustprogress"}
!36 = !DILocation(line: 1, column: 75, scope: !10)
!37 = !DILocation(line: 1, column: 68, scope: !10)
