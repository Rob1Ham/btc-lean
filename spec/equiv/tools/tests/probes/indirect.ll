; ModuleID = 'tools/tests/probes/indirect.c'
source_filename = "tools/tests/probes/indirect.c"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

@g = dso_local global ptr @inc, align 8, !dbg !0

; Function Attrs: noinline nounwind optnone uwtable
define dso_local i32 @inc(i32 noundef %0) #0 !dbg !17 {
  %2 = alloca i32, align 4
  store i32 %0, ptr %2, align 4
    #dbg_declare(ptr %2, !19, !DIExpression(), !20)
  %3 = load i32, ptr %2, align 4, !dbg !21
  %4 = add nsw i32 %3, 1, !dbg !22
  ret i32 %4, !dbg !23
}

; Function Attrs: noinline nounwind optnone uwtable
define dso_local i32 @call_g(i32 noundef %0) #0 !dbg !24 {
  %2 = alloca i32, align 4
  store i32 %0, ptr %2, align 4
    #dbg_declare(ptr %2, !25, !DIExpression(), !26)
  %3 = load ptr, ptr @g, align 8, !dbg !27
  %4 = load i32, ptr %2, align 4, !dbg !28
  %5 = call i32 %3(i32 noundef %4), !dbg !27
  ret i32 %5, !dbg !29
}

; Function Attrs: noinline nounwind optnone uwtable
define dso_local i32 @apply(ptr noundef %0, i32 noundef %1) #0 !dbg !30 {
  %3 = alloca ptr, align 8
  %4 = alloca i32, align 4
  store ptr %0, ptr %3, align 8
    #dbg_declare(ptr %3, !34, !DIExpression(), !35)
  store i32 %1, ptr %4, align 4
    #dbg_declare(ptr %4, !36, !DIExpression(), !37)
  %5 = load ptr, ptr %3, align 8, !dbg !38
  %6 = load i32, ptr %4, align 4, !dbg !39
  %7 = call i32 %5(i32 noundef %6), !dbg !38
  ret i32 %7, !dbg !40
}

attributes #0 = { noinline nounwind optnone uwtable "frame-pointer"="all" "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }

!llvm.dbg.cu = !{!2}
!llvm.module.flags = !{!9, !10, !11, !12, !13, !14, !15}
!llvm.ident = !{!16}

!0 = !DIGlobalVariableExpression(var: !1, expr: !DIExpression())
!1 = distinct !DIGlobalVariable(name: "g", scope: !2, file: !3, line: 3, type: !5, isLocal: false, isDefinition: true)
!2 = distinct !DICompileUnit(language: DW_LANG_C11, file: !3, producer: "Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)", isOptimized: false, runtimeVersion: 0, emissionKind: FullDebug, globals: !4, splitDebugInlining: false, nameTableKind: None)
!3 = !DIFile(filename: "tools/tests/probes/indirect.c", directory: "/home/ubuntu/btc-lean-public/spec/equiv", checksumkind: CSK_MD5, checksum: "69563605a9e5e9352e84699262190d2c")
!4 = !{!0}
!5 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !6, size: 64)
!6 = !DISubroutineType(types: !7)
!7 = !{!8, !8}
!8 = !DIBasicType(name: "int", size: 32, encoding: DW_ATE_signed)
!9 = !{i32 7, !"Dwarf Version", i32 5}
!10 = !{i32 2, !"Debug Info Version", i32 3}
!11 = !{i32 1, !"wchar_size", i32 4}
!12 = !{i32 8, !"PIC Level", i32 2}
!13 = !{i32 7, !"PIE Level", i32 2}
!14 = !{i32 7, !"uwtable", i32 2}
!15 = !{i32 7, !"frame-pointer", i32 2}
!16 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
!17 = distinct !DISubprogram(name: "inc", scope: !3, file: !3, line: 2, type: !6, scopeLine: 2, flags: DIFlagPrototyped, spFlags: DISPFlagDefinition, unit: !2, retainedNodes: !18)
!18 = !{}
!19 = !DILocalVariable(name: "x", arg: 1, scope: !17, file: !3, line: 2, type: !8)
!20 = !DILocation(line: 2, column: 13, scope: !17)
!21 = !DILocation(line: 2, column: 25, scope: !17)
!22 = !DILocation(line: 2, column: 27, scope: !17)
!23 = !DILocation(line: 2, column: 18, scope: !17)
!24 = distinct !DISubprogram(name: "call_g", scope: !3, file: !3, line: 4, type: !6, scopeLine: 4, flags: DIFlagPrototyped, spFlags: DISPFlagDefinition, unit: !2, retainedNodes: !18)
!25 = !DILocalVariable(name: "x", arg: 1, scope: !24, file: !3, line: 4, type: !8)
!26 = !DILocation(line: 4, column: 16, scope: !24)
!27 = !DILocation(line: 4, column: 28, scope: !24)
!28 = !DILocation(line: 4, column: 30, scope: !24)
!29 = !DILocation(line: 4, column: 21, scope: !24)
!30 = distinct !DISubprogram(name: "apply", scope: !3, file: !3, line: 5, type: !31, scopeLine: 5, flags: DIFlagPrototyped, spFlags: DISPFlagDefinition, unit: !2, retainedNodes: !18)
!31 = !DISubroutineType(types: !32)
!32 = !{!8, !33, !8}
!33 = !DIDerivedType(tag: DW_TAG_typedef, name: "fn", file: !3, line: 1, baseType: !5)
!34 = !DILocalVariable(name: "f", arg: 1, scope: !30, file: !3, line: 5, type: !33)
!35 = !DILocation(line: 5, column: 14, scope: !30)
!36 = !DILocalVariable(name: "x", arg: 2, scope: !30, file: !3, line: 5, type: !8)
!37 = !DILocation(line: 5, column: 21, scope: !30)
!38 = !DILocation(line: 5, column: 33, scope: !30)
!39 = !DILocation(line: 5, column: 35, scope: !30)
!40 = !DILocation(line: 5, column: 26, scope: !30)
