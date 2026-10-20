# P-CORE-05 evaluation — span leaf overloads for `CastToBool` / `CheckMinimalPush`

**Status:** survey + measured prototype. **Recommendation: drop as specified.**
The stated purpose ("removes O1 `ptrtoint` from the leaves") is not achieved;
the `-O0` proof lane is unaffected. Nothing here is used by a cell.

Pin: `cce32b16` (v32.99); clang/LLVM 20.1.2; `-g0`.

## 1. What the registry design says

`patches/core/README.md` P-CORE-05 proposes:

* add `static bool CastToBoolSpan(std::span<const unsigned char>)` and make
  `CastToBool(const valtype&)` forward to it;
* route the engine's seven internal calls to the span form;
* optionally add a span overload of `CheckMinimalPush` in
  `src/script/script.{h,cpp}` and route the one engine call site.

Claimed effect: "`leaf.cpp` experiment (separate TU): span version has 0
`ptrtoint`/`inttoptr` at O0 and O1; vector version has 2 `ptrtoint` at O1."

## 2. What the patch actually measures

Prototype: `P-CORE-05-span-leaves-proposal.patch` (3 files, +15/−10), applied to
the pin and compiled with the pinned clang.

| Variant | module `ptrtoint` | module `inttoptr` | `CastToBool` `ptrtoint` |
|---|---:|---:|---:|
| `-O0` pin | 104 | 0 | 0 |
| `-O0` + P-CORE-05 | **104** | 0 | 0 |
| `-O1` pin | 559 | 4 | 2 |
| `-O1` + P-CORE-05 | **567** | 4 | **2** |

So: no change at `-O0`; a **regression of 8** module-wide at `-O1`; and the
leaf the patch is supposed to clean still has 2 `ptrtoint`s.

## 3. Why (root cause)

The two `ptrtoint`s are not in the leaf body. They are the
`std::vector::size()` computation at the vector boundary:

```llvm
%3 = getelementptr inbounds nuw i8, ptr %0, i64 8     ; vector::end()
%4 = load ptr, ptr %3
%2 = load ptr, ptr %0                                 ; vector::begin()
%5 = ptrtoint ptr %4 to i64
%6 = ptrtoint ptr %2 to i64
%7 = sub i64 %5, %6                                   ; size() = end - begin
```

`std::span` construction from `std::vector` calls `ranges::size`, i.e. the same
`end - begin`. The leaf then sees the length as a field of the span, but the
`vector → span` conversion has already emitted the `ptrtoint`s at the caller.
Adding a span overload and forwarding from the vector form keeps that
conversion at every vector call site, and the extra overload instantiations add
new boundary conversions in the engine (`EvalScript` 223 → 229 at `-O1`).

The standalone leaf experiment reproduces the registry's observation and shows
the missing condition:

| leaf (`-O1`) | `ptrtoint` |
|---|---:|
| `bool CastToBoolSpan(std::span<const unsigned char>)` | 0 |
| `bool CastToBoolVec(const std::vector<unsigned char>&)` | 2 |
| `bool CastToBoolPtr(const unsigned char* p, size_t n)` → span | 0 |

The 0 case requires the **length to be materialised before** the leaf is called
(`(ptr,len)` or a span that already exists), not a `vector` at the boundary.
At `-O0` the `size()` computation is an out-of-line call whose body carries the
2 `ptrtoint`s, so the leaf itself is 0 either way and the module total is the
same.

## 4. Consequences for the lane policy

* The primary proof lane is `-O0` (F-TOOL-004: `-O1` raises module `ptrtoint`
  from 104 to 559 and puts 223 in `EvalScript`). P-CORE-05 has **zero effect**
  on the primary lane.
* On `-O1` it is counterproductive as specified.
* The `CastToBool` leaf is already provable on `-O0` (Alive2
  `--always-verify`, CORE-IR `logs/alive2-leaf-casttobool.log`), so there is no
  blocked leaf proof that this patch unblocks.

## 5. If `-O1` ever matters: the real transform

To remove the boundary `ptrtoint` you must stop calling `vector::size()` at the
engine/leaf boundary, i.e. carry the length explicitly through the stack
representation:

* replace `valtype = std::vector<unsigned char>` at the engine boundary with a
  view type that stores `(const unsigned char*, size_t)` (a `std::span` plus an
  owning buffer for pushes), so `size()` is a field load;
* or pass `(const unsigned char* p, size_t n)` pairs to every leaf and keep the
  vectors only at the ownership layer.

That is a large, invasive, ABI-adjacent refactor (the stack is
`std::vector<std::vector<unsigned char>>` throughout `EvalScript`,
`VerifyScript`, `ExecuteWitnessScript` and the checker API). It is not a
"small cleanup" and would need its own differential. Recommendation: do not
attempt it for this PR; keep `-O0` as the proof lane.

## 6. Verdict

* **As specified:** no-go. Measured no effect at `-O0`, regression at `-O1`,
  stated goal not met.
* **As a small upstream readability change:** harmless but pointless; it does
  not change any proof obligation.
* **Registry status:** should remain `design only`, with the note that the
  measured result contradicts the stated effect. I did not edit the registry
  (out of scope); this file is the evidence for the orchestrator.

Log: `logs/p5-ptrtoint.txt`.
