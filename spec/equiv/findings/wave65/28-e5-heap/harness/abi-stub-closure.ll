; ABI globals left undefined by the canonical [ir] 15-TU closure
; (core-interpreter-O0.bc, sha256 204cf671...).  Same role as
; abi-stub-singletu.ll; the closure already defines GetScriptOp, SHA/RIPEMD and
; uint256 constants, so the list differs.
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

@__dso_handle = hidden global i8 0
@_ZTVN10__cxxabiv120__si_class_type_infoE = constant [8 x ptr] zeroinitializer
@_ZTVN10__cxxabiv117__class_type_infoE = constant [8 x ptr] zeroinitializer
@_ZTVSt9exception = constant { [5 x ptr] } zeroinitializer
@_ZTISt13runtime_error = constant ptr null
@_ZTISt9exception = constant ptr null
@secp256k1_context_static = constant ptr null
