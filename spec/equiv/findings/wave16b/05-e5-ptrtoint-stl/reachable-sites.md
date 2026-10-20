# ptrtoint site table — pinned Core O0 lane

Module: `ir20/interpreter-O0.ll`, sha256 `fecf7db1a0cb3f4b98f214b6211a206ff5cc267bb1cb0b1b73cd159945c18fec`
(pinned bitcode `ir20/interpreter-O0.bc`, sha256 `f5718af7…`, clang/LLVM 20.1.2, `-O0 -g0`).
`inttoptr` count: **0**.

Depth is BFS distance from the nearest engine entry point. `other obligations`
is the transitive non-`llvm.*` external callee class; `pure` means the helper
reaches no external at all and only the three intrinsics below are possible.

## A. Reachable from `EvalScript` (the E5 claim: 26 helpers, 52 sites)

These are the helpers the residual §B6 names. All 26 are pure pointer-distance.

| # | helper | mangled name | sites | IR lines | ptrtoint shape | observable | other obligations | depth from engine root |
|---|---|---|---:|---|---|---|---|---:|
| 1 | vector&lt;vector&lt;u8&gt;&gt;::size() | `_ZNKSt6vectorIS_IhSaIhEESaIS1_EE4sizeEv` | 2 | 8603,8604 | sub + `sdiv exact` 24 | returned, / sizeof(T) | pure | 1 |
| 2 | vector&lt;u8&gt;::size() | `_ZNKSt6vectorIhSaIhEE4sizeEv` | 2 | 2388,2389 | sub | returned | pure | 1 |
| 3 | normal_iterator difference, const `T*` vs `T*` (vector&lt;T&gt;::insert) | `_ZN9__gnu_cxxmiIPKSt6vectorIhSaIhEEPS3_S1_IS3_SaIS3_EEEEDTmicldtfp_4baseEcldtfp0_4baseEERKNS_17__normal_iteratorIT_T1_EERKNSA_IT0_SC_EE` | 2 | 23008,23009 | sub + `sdiv exact` 24 | returned, / sizeof(T) | pure | 2 |
| 4 | normal_iterator difference, const vs const (vector&lt;vector&lt;u8&gt;&gt;) | `_ZN9__gnu_cxxmiIPKSt6vectorIhSaIhEES1_IS3_SaIS3_EEEENS_17__normal_iteratorIT_T0_E15difference_typeERKSB_SE_` | 2 | 22400,22401 | sub + `sdiv exact` 24 | returned, / sizeof(T) | pure | 2 |
| 5 | _Vector_base&lt;vector&lt;u8&gt;&gt;::~_Vector_base (deallocate) | `_ZNSt12_Vector_baseISt6vectorIhSaIhEESaIS2_EED2Ev` | 2 | 25492,25493 | sub + `sdiv exact` 24 | / sizeof(T) | dealloc | 2 |
| 6 | _Vector_base&lt;u8&gt;::~_Vector_base (deallocate) | `_ZNSt12_Vector_baseIhSaIhEED2Ev` | 2 | 19402,19403 | sub | passed as size arg | dealloc | 2 |
| 7 | vector&lt;vector&lt;u8&gt;&gt;::_M_realloc_insert&lt;const&amp;&gt; | `_ZNSt6vectorIS_IhSaIhEESaIS1_EE17_M_realloc_insertIJRKS1_EEEvN9__gnu_cxx17__normal_iteratorIPS1_S3_EEDpOT_` | 2 | 20764,20765 | sub + `sdiv exact` 24 | / sizeof(T), stored as count | heap | 2 |
| 8 | prevector&lt;36,u8&gt;::operator-(const_iterator) | `_ZmiN9prevectorILj36EhjiE14const_iteratorES1_` | 2 | 3502,3503 | sub + `trunc` i32 | returned, trunc i32 | pure | 2 |
| 9 | normal_iterator difference over `vector<vector<u8>>` | `_ZN9__gnu_cxxmiIPSt6vectorIhSaIhEES1_IS3_SaIS3_EEEENS_17__normal_iteratorIT_T0_E15difference_typeERKSA_SD_` | 2 | 20882,20883 | sub + `sdiv exact` 24 | returned, / sizeof(T) | pure | 3 |
| 10 | vector&lt;vector&lt;u8&gt;&gt;::_M_erase_at_end | `_ZNSt6vectorIS_IhSaIhEESaIS1_EE15_M_erase_at_endEPS1_` | 2 | 22496,22497 | sub + `sdiv exact` 24 | / sizeof(T), stored as count | dealloc | 3 |
| 11 | vector&lt;vector&lt;u8&gt;&gt;::_M_realloc_insert&lt;T&amp;&amp;&gt; | `_ZNSt6vectorIS_IhSaIhEESaIS1_EE17_M_realloc_insertIJS1_EEEvN9__gnu_cxx17__normal_iteratorIPS1_S3_EEDpOT_` | 2 | 21545,21546 | sub + `sdiv exact` 24 | / sizeof(T), stored as count | heap | 3 |
| 12 | basic_string::_M_construct&lt;const char*&gt; | `_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPKcEEvT_S8_St20forward_iterator_tag` | 2 | 26972,26973 | sub | stored as count | heap | 3 |
| 13 | prevector&lt;36,u8&gt;::operator-(iterator) | `_ZmiN9prevectorILj36EhjiE8iteratorES1_` | 2 | 24799,24800 | sub + `trunc` i32 | returned, trunc i32 | pure | 3 |
| 14 | prevector&lt;36,u8&gt;::insert(input_iterator, const u8*) | `_ZN9prevectorILj36EhjiE6insertITkSt14input_iteratorPKhEEvNS0_8iteratorET_S5_` | 2 | 24722,24723 | sub + `trunc` i32 | trunc i32 | heap | 4 |
| 15 | basic_string::_S_copy_chars | `_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE13_S_copy_charsEPcPKcS7_` | 2 | 27166,27167 | sub | passed as size arg | terminate-only | 4 |
| 16 | normal_iterator difference over `span<const u8>` | `_ZN9__gnu_cxxmiIPKhSt4spanIS1_Lm18446744073709551615EEEENS_17__normal_iteratorIT_T0_E15difference_typeERKS8_SB_` | 2 | 25203,25204 | sub | returned | pure | 5 |
| 17 | normal_iterator difference over `vector<const u8>` | `_ZN9__gnu_cxxmiIPKhSt6vectorIhSaIhEEEENS_17__normal_iteratorIT_T0_E15difference_typeERKS9_SC_` | 2 | 19563,19564 | sub | returned | pure | 5 |
| 18 | vector&lt;u8&gt;::_M_realloc_insert&lt;u8&amp;&amp;&gt; | `_ZNSt6vectorIhSaIhEE17_M_realloc_insertIJhEEEvN9__gnu_cxx17__normal_iteratorIPhS1_EEDpOT_` | 2 | 21849,21850 | sub | stored as count | heap | 5 |
| 19 | __equal&lt;true&gt;::equal&lt;u8&gt; (calls memcmp) | `_ZNSt7__equalILb1EE5equalIhEEbPKT_S4_S4_` | 2 | 23451,23452 | sub | stored as count | memcmp | 5 |
| 20 | __niter_wrap&lt;normal_iterator&lt;T*&gt;, T*&gt; | `_ZSt12__niter_wrapIN9__gnu_cxx17__normal_iteratorIPSt6vectorIhSaIhEES2_IS4_SaIS4_EEEES5_ET_S9_T0_` | 2 | 22606,22607 | sub + `sdiv exact` 24 | / sizeof(T) | pure | 5 |
| 21 | normal_iterator difference over `vector<u8>` | `_ZN9__gnu_cxxmiIPhSt6vectorIhSaIhEEEENS_17__normal_iteratorIT_T0_E15difference_typeERKS8_SB_` | 2 | 21950,21951 | sub | returned | pure | 6 |
| 22 | __copy_m&lt;vector&lt;u8&gt;*, vector&lt;u8&gt;*&gt; (move) | `_ZNSt11__copy_moveILb1ELb0ESt26random_access_iterator_tagE8__copy_mIPSt6vectorIhSaIhEES6_EET0_T_S8_S7_` | 2 | 22669,22670 | sub + `sdiv exact` 24 | / sizeof(T), stored as count | dealloc | 7 |
| 23 | __copy_move_backward&lt;vector&lt;u8&gt;*&gt; | `_ZNSt20__copy_move_backwardILb1ELb0ESt26random_access_iterator_tagE13__copy_move_bIPSt6vectorIhSaIhEES6_EET0_T_S8_S7_` | 2 | 23332,23333 | sub + `sdiv exact` 24 | / sizeof(T), stored as count | dealloc | 7 |
| 24 | __relocate_a_1&lt;u8, u8&gt; | `_ZSt14__relocate_a_1IhhENSt9enable_ifIXsr3std24__is_bitwise_relocatableIT_EE5valueEPS1_E4typeES2_S2_S2_RSaIT0_E` | 2 | 22036,22037 | sub | stored as count | pure | 8 |
| 25 | __copy_m&lt;const u8, u8&gt; | `_ZNSt11__copy_moveILb0ELb1ESt26random_access_iterator_tagE8__copy_mIKhhEEPT0_PT_S7_S5_` | 2 | 19874,19875 | sub | stored as count | pure | 9 |
| 26 | __fill_a1&lt;u8&gt; | `_ZSt9__fill_a1IhEN9__gnu_cxx11__enable_ifIXsr9__is_byteIT_EE7__valueEvE6__typeEPS2_S5_RKS2_` | 2 | 20504,20505 | sub | stored as count | pure | 9 |

## B. Additional helpers reachable from other engine entry points

`VerifyScript`, `VerifyWitnessProgram`, `ExecuteWitnessScript`, `EvalChecksig*`, `CastToBool` add these 11 helpers / 26 sites. They matter for a whole-engine claim but not for an `EvalScript`-only claim.

| # | helper | mangled name | sites | IR lines | ptrtoint shape | observable | other obligations | depth from engine root |
|---|---|---|---:|---|---|---|---|---:|
| H27 | vector&lt;vector&lt;u8&gt;&gt;::operator=(const&amp;) | `_ZNSt6vectorIS_IhSaIhEESaIS1_EEaSERKS3_` | 2 | 16273,16274 | sub + `sdiv exact` 24 | / sizeof(T), stored as count | heap | 1 |
| H28 | vector&lt;vector&lt;u8&gt;&gt;::capacity() | `_ZNKSt6vectorIS_IhSaIhEESaIS1_EE8capacityEv` | 2 | 28899,28900 | sub + `sdiv exact` 24 | returned, / sizeof(T) | pure | 2 |
| H29 | vector&lt;vector&lt;u8&gt;&gt;::_M_default_append | `_ZNSt6vectorIS_IhSaIhEESaIS1_EE17_M_default_appendEm` | 4 | 31963,31964,32073,32074 | sub + `sdiv exact` 24 | / sizeof(T), stored as count | heap | 2 |
| H30 | normal_iterator difference, vector &harr; span | `_ZN9__gnu_cxxmiIPKSt6vectorIhSaIhEESt4spanIS4_Lm18446744073709551615EEEENS_17__normal_iteratorIT_T0_E15difference_typeERKSB_SE_` | 2 | 31382,31383 | sub + `sdiv exact` 24 | returned, / sizeof(T) | pure | 5 |
| H31 | __copy_m&lt;const vector&lt;u8&gt;*, vector&lt;u8&gt;*&gt; | `_ZNSt11__copy_moveILb0ELb0ESt26random_access_iterator_tagE8__copy_mIPKSt6vectorIhSaIhEEPS5_EET0_T_SA_S9_` | 2 | 29477,29478 | sub + `sdiv exact` 24 | / sizeof(T), stored as count | heap | 6 |
| H32 | __copy_m&lt;vector&lt;u8&gt;*, vector&lt;u8&gt;*&gt; | `_ZNSt11__copy_moveILb0ELb0ESt26random_access_iterator_tagE8__copy_mIPSt6vectorIhSaIhEES6_EET0_T_S8_S7_` | 2 | 30225,30226 | sub + `sdiv exact` 24 | / sizeof(T), stored as count | heap | 6 |
| H33 | vector&lt;u8&gt;::operator=(const&amp;) | `_ZNSt6vectorIhSaIhEEaSERKS1_` | 2 | 29587,29588 | sub | stored as count | heap | 7 |
| H34 | vector&lt;u8&gt;::capacity() | `_ZNKSt6vectorIhSaIhEE8capacityEv` | 2 | 29711,29712 | sub | returned | pure | 8 |
| H35 | __lexicographical_compare::__3way&lt;u8,u8&gt; | `_ZNSt25__lexicographical_compareILb1EE6__3wayIhhEElPKT_S4_PKT0_S7_` | 4 | 28785,28786,28791,28792 | sub | returned, stored as count | memcmp | 9 |
| H36 | __niter_wrap&lt;normal_iterator&lt;u8*&gt;, u8*&gt; | `_ZSt12__niter_wrapIN9__gnu_cxx17__normal_iteratorIPhSt6vectorIhSaIhEEEES2_ET_S7_T0_` | 2 | 29972,29973 | sub | passed as size arg | pure | 10 |
| H37 | __copy_m&lt;u8, u8&gt; | `_ZNSt11__copy_moveILb0ELb1ESt26random_access_iterator_tagE8__copy_mIhhEEPT0_PT_S6_S4_` | 2 | 30081,30082 | sub | stored as count | pure | 12 |

## C. Module-wide sites NOT reachable from any engine entry point

For completeness: 12 helpers / 26 sites. Note that `tinyformat` is here, so the residual §B6 phrase "26 std::vector / iterator / tinyformat helpers" overstates the surface: at O0 no `tinyformat` `ptrtoint` is reachable.

| # | helper | mangled name | sites | IR lines | ptrtoint shape | observable | other obligations | depth from engine root |
|---|---|---|---:|---|---|---|---|---:|
| U01 | _ZN10tinyformat6detail24printFormatStringLiteralERSoPKc | `_ZN10tinyformat6detail24printFormatStringLiteralERSoPKc` | 4 | 39030,39031,39050,39051 | sub | passed as size arg | terminate-only | - |
| U02 | _ZN9__gnu_cxxmiIPNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEESt6vectorIS6_SaIS6_EEEENS_17__normal_iteratorIT_T0_E15difference_typeERKSE_SH_ | `_ZN9__gnu_cxxmiIPNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEESt6vectorIS6_SaIS6_EEEENS_17__normal_iteratorIT_T0_E15difference_typeERKSE_SH_` | 2 | 33744,33745 | sub + `sdiv exact` 32 | returned, / sizeof(T) | pure | - |
| U03 | _ZN9prevectorILj36EhjiE5eraseENS0_8iteratorES1_ | `_ZN9prevectorILj36EhjiE5eraseENS0_8iteratorES1_` | 2 | 35965,35966 | sub | passed as size arg | pure | - |
| U04 | _ZNKSt6vectorI5CTxInSaIS0_EE4sizeEv | `_ZNKSt6vectorI5CTxInSaIS0_EE4sizeEv` | 2 | 10679,10680 | sub + `sdiv exact` 112 | returned, / sizeof(T) | pure | - |
| U05 | _ZNKSt6vectorI6CTxOutSaIS0_EE4sizeEv | `_ZNKSt6vectorI6CTxOutSaIS0_EE4sizeEv` | 2 | 10661,10662 | sub + `sdiv exact` 48 | returned, / sizeof(T) | pure | - |
| U06 | _ZNKSt6vectorINSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEESaIS5_EE4sizeEv | `_ZNKSt6vectorINSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEESaIS5_EE4sizeEv` | 2 | 33901,33902 | sub + `sdiv exact` 32 | returned, / sizeof(T) | pure | - |
| U07 | _ZNSt12_Vector_baseI6CTxOutSaIS0_EED2Ev | `_ZNSt12_Vector_baseI6CTxOutSaIS0_EED2Ev` | 2 | 26733,26734 | sub + `sdiv exact` 48 | / sizeof(T) | dealloc | - |
| U08 | _ZNSt12_Vector_baseINSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEESaIS5_EED2Ev | `_ZNSt12_Vector_baseINSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEESaIS5_EED2Ev` | 2 | 34411,34412 | sub + `sdiv exact` 32 | / sizeof(T) | dealloc | - |
| U09 | _ZNSt6vectorINSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEESaIS5_EE17_M_realloc_insertIJRKS5_EEEvN9__gnu_cxx17__normal_iteratorIPS5_S7_EEDpOT_ | `_ZNSt6vectorINSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEESaIS5_EE17_M_realloc_insertIJRKS5_EEEvN9__gnu_cxx17__normal_iteratorIPS5_S7_EEDpOT_` | 2 | 33367,33368 | sub + `sdiv exact` 32 | / sizeof(T), stored as count | heap | - |
| U10 | _ZNSt6vectorINSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEESaIS5_EE17_M_realloc_insertIJS5_EEEvN9__gnu_cxx17__normal_iteratorIPS5_S7_EEDpOT_ | `_ZNSt6vectorINSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEESaIS5_EE17_M_realloc_insertIJS5_EEEvN9__gnu_cxx17__normal_iteratorIPS5_S7_EEDpOT_` | 2 | 34327,34328 | sub + `sdiv exact` 32 | / sizeof(T), stored as count | heap | - |
| U11 | _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag | `_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag` | 2 | 33551,33552 | sub | stored as count | heap | - |
| U12 | _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE13_S_copy_charsEPcS5_S5_ | `_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE13_S_copy_charsEPcS5_S5_` | 2 | 33630,33631 | sub | passed as size arg | terminate-only | - |

## D. Summary (EvalScript-only set)

- helpers: 26, sites: 52
- pure (zero external callees): 14
- needs allocator: 5
- needs deallocation only: 5
- needs memcmp: 1
- `inttoptr` sites in the whole module: 0 (so every entry above is `ptrtoint` only)
