| label | len | header | Core Set/IsValid | Lean isValidPubKey | Lean validPubKeySize | agree? |
|---|---:|---|---|---|---|---|
| empty | 0 | (none) | false | false | false | yes |
| badhdr-1B-01 | 1 | 01 | false | false | false | yes |
| min-1B-02 | 1 | 02 | false | true | false | **NO** |
| one-1B-04 | 1 | 04 | false | true | false | **NO** |
| two-2B-0400 | 2 | 04 | false | true | false | **NO** |
| 32B-02 | 32 | 02 | false | true | false | **NO** |
| 33B-02 | 33 | 02 | true | true | true | yes |
| 34B-02 | 34 | 02 | false | true | false | **NO** |
| 64B-04 | 64 | 04 | false | true | false | **NO** |
| 65B-04 | 65 | 04 | true | true | true | yes |
| 66B-04 | 66 | 04 | false | true | false | **NO** |
| 33B-04 | 33 | 04 | false | true | false | **NO** |
| 65B-02 | 65 | 02 | false | true | false | **NO** |
| 33B-06 | 33 | 06 | false | true | false | **NO** |
| 65B-06 | 65 | 06 | true | true | true | yes |
| 33B-02-G | 33 | 02 | true | true | true | yes |
| 65B-04-G | 65 | 04 | true | true | true | yes |

Rows: 17; gate-definition mismatches: 10.
