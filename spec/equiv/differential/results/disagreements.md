# Differential disagreements

Generated deterministically by `spec/equiv/differential/run.py`. Every case-like row of the pinned corpus is represented in `c-l.jsonl`; nothing is dropped.

**Leg identities (F-HARNESS-001).** `L_twin` is the generated C++ twin (`twin/build/libtwin.so`), the actual L leg. `L` (and the lean-model columns) is `tierC.l2r`, produced by the Lean *interpreter model* at oracle pin `c50817fe`; it is an oracle cross-check, never the L leg.

A behavioral agreement is evidence about these builds on this corpus, **not** an LLVM IR proof.

## Counts

| Metric | Count |
|---|---:|
| Rows in corpus | 1258 |
| C calls attempted | 1258 |
| C vs L_twin (twin) agree | 922 |
| C vs L_twin (twin) disagree | 0 |
| C vs L_twin blocked (twin result 3, declared boundary) | 336 |
| C vs Lean-model oracle agree | 1251 |
| C vs Lean-model oracle disagree | 0 |
| C vs Lean-model blocked (UNJUDGED) | 7 |
| C vs expected agree | 1258 |
| C vs expected disagree | 0 |
| Out of contract domain (C result 2) | 0 |
| C internal errors (result 3) | 0 |
| Encode failures | 0 |
| C-call failures | 0 |
| Twin-call failures | 0 |
| Determinism re-run | identical |

## C vs L (twin) disagreements

None.

## C vs Lean-model oracle disagreements

None.

## C vs expected disagreements

None. (The C leg reproduces Core's own test expectation on every row it judged.)

## Blocked rows (explicit, not hidden)

### C vs L_twin: 336 rows

**336 rows** — outside twin subset: L_twin returned 3 (declared boundary, not a verdict)

Families: checksig, cms, flow, hash, locktime, numeric, stack, taproot, witness

```
sc-0044 sc-0049 sc-0204 sc-0205 sc-0206 sc-0388 sc-0403 sc-0404 sc-0405 sc-0406 sc-0407 sc-0408 sc-0409
sc-0410 sc-0411 sc-0412 sc-0413 sc-0414 sc-0415 sc-0416 sc-0417 sc-0418 sc-0419 sc-0420 sc-0421 sc-0422
sc-0423 sc-0424 sc-0425 sc-0426 sc-0427 sc-0428 sc-0429 sc-0430 sc-0431 sc-0432 sc-0433 sc-0434 sc-0435
sc-0436 sc-0437 sc-0438 sc-0439 sc-0440 sc-0441 sc-0442 sc-0443 sc-0444 sc-0445 sc-0446 sc-0447 sc-0448
sc-0449 sc-0450 sc-0451 sc-0452 sc-0453 sc-0563 sc-0564 sc-0565 sc-0566 sc-0567 sc-0568 sc-0569 sc-0570
sc-0571 sc-0572 sc-0573 sc-0574 sc-0575 sc-0576 sc-0577 sc-0578 sc-0579 sc-0580 sc-0581 sc-0582 sc-0583
sc-0584 sc-0585 sc-0586 sc-0804 sc-0881 sc-0885 sc-0886 sc-0887 sc-0888 sc-0889 sc-0890 sc-0891 sc-0892
sc-0893 sc-0894 sc-0895 sc-0896 sc-0897 sc-0898 sc-0974 sc-0975 sc-0976 sc-0977 sc-0978 sc-0979 sc-0980
sc-0981 sc-0982 sc-0983 sc-0984 sc-0985 sc-0986 sc-0987 sc-0988 sc-0989 sc-0990 sc-0991 sc-0992 sc-0993
sc-0994 sc-0995 sc-0996 sc-0997 sc-0998 sc-0999 sc-1000 sc-1001 sc-1002 sc-1003 sc-1010 sc-1011 sc-1012
sc-1013 sc-1015 sc-1016 sc-1017 sc-1019 sc-1022 sc-1023 sc-1024 sc-1025 sc-1026 sc-1027 sc-1028 sc-1029
sc-1030 sc-1031 sc-1032 sc-1033 sc-1034 sc-1035 sc-1036 sc-1037 sc-1038 sc-1039 sc-1040 sc-1041 sc-1042
sc-1043 sc-1044 sc-1045 sc-1046 sc-1047 sc-1048 sc-1049 sc-1050 sc-1051 sc-1052 sc-1053 sc-1054 sc-1055
sc-1056 sc-1057 sc-1058 sc-1059 sc-1060 sc-1061 sc-1062 sc-1063 sc-1064 sc-1065 sc-1066 sc-1067 sc-1068
sc-1069 sc-1070 sc-1071 sc-1072 sc-1073 sc-1074 sc-1075 sc-1076 sc-1077 sc-1078 sc-1079 sc-1080 sc-1081
sc-1082 sc-1083 sc-1084 sc-1085 sc-1086 sc-1089 sc-1092 sc-1093 sc-1094 sc-1095 sc-1096 sc-1097 sc-1098
sc-1099 sc-1100 sc-1101 sc-1102 sc-1103 sc-1104 sc-1105 sc-1110 sc-1111 sc-1112 sc-1113 sc-1114 sc-1115
sc-1116 sc-1117 sc-1118 sc-1121 sc-1122 sc-1123 sc-1124 sc-1125 sc-1126 sc-1127 sc-1128 sc-1129 sc-1130
sc-1131 sc-1132 sc-1133 sc-1134 sc-1135 sc-1136 sc-1137 sc-1138 sc-1139 sc-1140 sc-1141 sc-1142 sc-1143
sc-1144 sc-1145 sc-1146 sc-1147 sc-1148 sc-1149 sc-1150 sc-1151 sc-1152 sc-1153 sc-1154 sc-1155 sc-1156
sc-1157 sc-1158 sc-1159 sc-1160 sc-1161 sc-1162 sc-1163 sc-1164 sc-1165 sc-1166 sc-1189 sc-1190 sc-1191
sc-1192 sc-1193 sc-1194 sc-1195 sc-1196 sc-1197 sc-1198 sc-1199 sc-1200 sc-1201 sc-1202 sc-1203 sc-1204
sc-1205 sc-1206 sc-1207 sc-1208 sc-1209 sc-1210 sc-1211 sc-1212 sc-1213 sc-1214 sc-1215 sc-1216 sc-1217
sc-1218 sc-1219 sc-1220 sc-1221 sc-1222 sc-1223 sc-1224 sc-1225 sc-1226 sc-1227 sc-1228 sc-1229 sc-1230
sc-1231 sc-1232 sc-1233 sc-1234 sc-1235 sc-1236 sc-1237 sc-1238 sc-1239 sc-1240 sc-1241 sc-1242 sc-1243
sc-1244 sc-1245 sc-1246 sc-1247 sc-1248 sc-1249 sc-1250 sc-1251 sc-1255 sc-1256 sc-1257
```

These rows have **no twin verdict**; they are not counted as disagreements.

### C vs Lean-model oracle: 7 rows

**7 rows** — Lean-model verdict is UNJUDGED (no verdict produced for this row)

```
sc-1237 sc-1238 sc-1239 sc-1240 sc-1241 sc-1242 sc-1243
```

## Out-of-domain rows

None. Every vector encoded to a tape in the ABI v2 domain.

## Encode / call failures

None. Every vector was encoded and every C/L_twin call returned.

