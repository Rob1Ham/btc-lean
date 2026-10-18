import Bitcoin.Interpreter.Defs

/-!
# BitcoinProofs.Theorems.Ops.O04 — per-opcode semantics: stack manipulation

O04. Sorry-free per-opcode semantics theorems over
interpreter tier (`Bitcoin.Interpreter.Defs`, `stepBody.dispatchOp` — the
`switch (opcode)` of Core's `EvalScript`) for the stack2 group:

* OP_2DUP 0x6e, OP_3DUP 0x6f, OP_2OVER 0x70, OP_2ROT 0x71, OP_2SWAP 0x72
* OP_NIP 0x77, OP_OVER 0x78, OP_PICK 0x79, OP_ROLL 0x7a, OP_TUCK 0x7d

Ground truth: Core interpreter.cpp @ `cce32b168`
(OP_2DUP :715-725, OP_3DUP :727-739, OP_2OVER :741-751, OP_2ROT :753-764,
OP_2SWAP :766-774, OP_NIP :814-821, OP_OVER :823-831, OP_PICK/OP_ROLL
:833-849, OP_TUCK :872-880), independently cross-checked by
an oracle script (`oracle.py`, python3
transcription of those C++ cases; 25 rows). Lean stacks are HEAD-FIRST
(head = top), the reverse of Core's `std::vector` (back = top);
`topAt s k = s[k-1]!` is `stacktop(-k)`.

Error mapping (VERIFIED, Defs.lean:109-140 constructor comments): Core's
`SCRIPT_ERR_INVALID_STACK_OPERATION` — the error every shape violation in
this family returns — is `ExecError.stackUnderflow`; a failing
`CScriptNum` decode of the PICK/ROLL depth operand is
`SCRIPT_ERR_SCRIPTNUM` → `ExecError.scriptNum`.

Proof discipline: the `< n` underflow guards appear inside `stepBody.dispatchOp`
as `if st.stack.length < 2 …`; after `simp [h-shape]`+`List.length_cons`
normalization the guard is `List.length r + 1 + 1 < 2` (etc.), so the
guard-failure facts are stated in EXACTLY that normalized form (else the
hypothesis never matches — build3 diagnosis).

| theorem(s) | Core anchor | content |
|---|---|---|
| `nip_underflow` / `nip_ok` | :814-821 | (x1 x2 -- x2), <2 fails |
| `over_underflow` / `over_ok` | :823-831 | (x1 x2 -- x1 x2 x1), <2 fails |
| `tuck_underflow` / `tuck_ok` | :872-880 | (x1 x2 -- x2 x1 x2), <2 fails |
| `twodup_underflow` / `twodup_ok` | :715-725 | (x1 x2 -- x1 x2 x1 x2) |
| `threedup_underflow` / `threedup_ok` | :727-739 | (x1 x2 x3 -- x1 x2 x3 x1 x2 x3) |
| `twoover_underflow` / `twoover_ok` | :741-751 | (x1..x4 -- x1..x4 x1 x2) |
| `twoswap_underflow` / `twoswap_ok` | :766-774 | (x1..x4 -- x3 x4 x1 x2) |
| `tworot_underflow` / `tworot_ok` | :753-764 | (x1..x6 -- x3..x6 x1 x2) |
| `pickroll_underflow_lt2` | :834-835 | <2 fails before decode |
| `pick_ok` / `pick_depth_rule` / `pick_neg_fail` / `pick_depth_fail` / `pick_decode_fail` | :833-849 | OP_PICK semantics + THE DEPTH RULE |
| `roll_ok` / `roll_depth_rule` / `roll0_identity` / `pick0_eq_dupTop` | :833-849 | OP_ROLL = moving PICK; ROLL-0 = identity, PICK-0 = DUP |
| 25 `*_verdict` examples | — | python3-cross-checked concrete verdicts |

Axiom footprints pinned by `#guard_msgs` at the file tail.
-/

namespace BitcoinProofs.Theorems.Ops.O04

open Bitcoin.Interpreter Bitcoin.Numeric

/-! ## Fixtures -/

/-- `Except` has no core `DecidableEq` for this type; derive one locally
so the cross-checked concrete verdicts are `decide`-closed (axiom-free). -/
local instance : DecidableEq (Except ExecError State) := fun a b => by
  match a, b with
  | .ok x, .ok y =>
      exact dite (x = y) (fun h => .isTrue (by rw [h]))
        (fun h => .isFalse (fun hh => h (Except.ok.inj hh)))
  | .error x, .error y =>
      exact dite (x = y) (fun h => .isTrue (by rw [h]))
        (fun h => .isFalse (fun hh => h (Except.error.inj hh)))
  | .ok _, .error _ => exact .isFalse (fun hh => by cases hh)
  | .error _, .ok _ => exact .isFalse (fun hh => by cases hh)

/-- Base policy / sig-version context: the checker is the stub (this
opcode group never reaches it); `dispatchOp` in this group reads only
`pol` (and only on the PICK/ROLL path). -/
def ctxD : Ctx :=
  ⟨{ p2sh := false, dersig := false, cltv := false, csv := false,
     nullDummy := false, witness := false, taproot := false },
   {}, default, .base, ByteArray.empty, default⟩

/-- Base-policy context with MINIMALDATA on (for the non-minimal depth
operand edge case). -/
def ctxMin : Ctx := { ctxD with pol := { minimalData := true } }

/-- Literal wire op for wire byte `n`. -/
def opw (n : Nat) : WireOp := ⟨.op ⟨n % 256, by omega⟩, n, 1⟩

/-- Normalized underflow-guard fact for a 2-deep stack `a :: b :: r`
(`simp` sees the guard as `List.length r + 1 + 1 < 2`). -/
theorem len_ge2 {r : Stack} : ¬ (List.length r + 1 + 1 < 2) := by omega

/-! ## NIP / OVER / TUCK / 2DUP — the 2-deep family (pre: `a :: b :: r`)

`a` = top of stack (`x2` in Core's bottom-up comments), `b` = `x1`. -/

/-- OP_NIP (interpreter.cpp:814-821): `stack.size() < 2` →
INVALID_STACK_OPERATION. -/
theorem nip_underflow (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (h : st.stack.length < 2) :
    stepBody.dispatchOp ctx op 0x77 fExec st = .error .stackUnderflow := by
  simp [stepBody.dispatchOp, h]

/-- OP_NIP (interpreter.cpp:814-821, `stack.erase(stack.end() - 2)`):
`(x1 x2 -- x2)` — top kept, second-from-top removed, rest untouched. -/
theorem nip_ok (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (a b : ByteArray) (r : Stack) (h : st.stack = a :: b :: r) :
    stepBody.dispatchOp ctx op 0x77 fExec st = .ok { st with stack := a :: r } := by
  simp [stepBody.dispatchOp, h, topAt, len_ge2]

/-- OP_OVER (interpreter.cpp:823-831): `stack.size() < 2` → fail. -/
theorem over_underflow (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (h : st.stack.length < 2) :
    stepBody.dispatchOp ctx op 0x78 fExec st = .error .stackUnderflow := by
  simp [stepBody.dispatchOp, h]

/-- OP_OVER (interpreter.cpp:823-831, push `stacktop(-2)`): `(x1 x2 -- x1 x2 x1)`. -/
theorem over_ok (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (a b : ByteArray) (r : Stack) (h : st.stack = a :: b :: r) :
    stepBody.dispatchOp ctx op 0x78 fExec st =
      .ok { st with stack := b :: a :: b :: r } := by
  simp [stepBody.dispatchOp, h, topAt, len_ge2]

/-- OP_TUCK (interpreter.cpp:872-880): `stack.size() < 2` → fail. -/
theorem tuck_underflow (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (h : st.stack.length < 2) :
    stepBody.dispatchOp ctx op 0x7d fExec st = .error .stackUnderflow := by
  simp [stepBody.dispatchOp, h]

/-- OP_TUCK (interpreter.cpp:872-880, `stack.insert(stack.end()-2, stacktop(-1))`):
`(x1 x2 -- x2 x1 x2)` — a copy of the top inserted UNDER the second element. -/
theorem tuck_ok (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (a b : ByteArray) (r : Stack) (h : st.stack = a :: b :: r) :
    stepBody.dispatchOp ctx op 0x7d fExec st =
      .ok { st with stack := a :: b :: a :: r } := by
  simp [stepBody.dispatchOp, h, topAt, len_ge2]

/-- OP_2DUP (interpreter.cpp:715-725): `stack.size() < 2` → fail. -/
theorem twodup_underflow (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (h : st.stack.length < 2) :
    stepBody.dispatchOp ctx op 0x6e fExec st = .error .stackUnderflow := by
  simp [stepBody.dispatchOp, h]

/-- OP_2DUP (interpreter.cpp:715-725): `(x1 x2 -- x1 x2 x1 x2)`. -/
theorem twodup_ok (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (a b : ByteArray) (r : Stack) (h : st.stack = a :: b :: r) :
    stepBody.dispatchOp ctx op 0x6e fExec st =
      .ok { st with stack := a :: b :: a :: b :: r } := by
  simp [stepBody.dispatchOp, h, topAt, len_ge2]

/-! ## 3DUP / 2OVER / 2SWAP / 2ROT — the wider copy family -/

/-- OP_3DUP (interpreter.cpp:727-739): `stack.size() < 3` → fail. -/
theorem threedup_underflow (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (h : st.stack.length < 3) :
    stepBody.dispatchOp ctx op 0x6f fExec st = .error .stackUnderflow := by
  simp [stepBody.dispatchOp, h]

/-- OP_3DUP (interpreter.cpp:727-739): `(x1 x2 x3 -- x1 x2 x3 x1 x2 x3)`. -/
theorem threedup_ok (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (a b c : ByteArray) (r : Stack) (h : st.stack = a :: b :: c :: r) :
    stepBody.dispatchOp ctx op 0x6f fExec st =
      .ok { st with stack := a :: b :: c :: a :: b :: c :: r } := by
  have hlen : ¬ (List.length r + 1 + 1 + 1 < 3) := by omega
  simp [stepBody.dispatchOp, h, topAt, hlen]

/-- OP_2OVER (interpreter.cpp:741-751): `stack.size() < 4` → fail. -/
theorem twoover_underflow (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (h : st.stack.length < 4) :
    stepBody.dispatchOp ctx op 0x70 fExec st = .error .stackUnderflow := by
  simp [stepBody.dispatchOp, h]

/-- OP_2OVER (interpreter.cpp:741-751): `(x1 x2 x3 x4 -- x1 x2 x3 x4 x1 x2)`. -/
theorem twoover_ok (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (a b c d : ByteArray) (r : Stack) (h : st.stack = a :: b :: c :: d :: r) :
    stepBody.dispatchOp ctx op 0x70 fExec st =
      .ok { st with stack := c :: d :: a :: b :: c :: d :: r } := by
  have hlen : ¬ (List.length r + 1 + 1 + 1 + 1 < 4) := by omega
  simp [stepBody.dispatchOp, h, topAt, hlen]

/-- OP_2SWAP (interpreter.cpp:766-774): `stack.size() < 4` → fail. -/
theorem twoswap_underflow (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (h : st.stack.length < 4) :
    stepBody.dispatchOp ctx op 0x72 fExec st = .error .stackUnderflow := by
  simp [stepBody.dispatchOp, h]

/-- OP_2SWAP (interpreter.cpp:766-774, the two `swap`s): `(x1 x2 x3 x4 -- x3 x4 x1 x2)`. -/
theorem twoswap_ok (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (a b c d : ByteArray) (r : Stack) (h : st.stack = a :: b :: c :: d :: r) :
    stepBody.dispatchOp ctx op 0x72 fExec st =
      .ok { st with stack := c :: d :: a :: b :: r } := by
  have hlen : ¬ (List.length r + 1 + 1 + 1 + 1 < 4) := by omega
  simp [stepBody.dispatchOp, h, topAt, hlen]

/-- OP_2ROT (interpreter.cpp:753-764): `stack.size() < 6` → fail. -/
theorem tworot_underflow (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (h : st.stack.length < 6) :
    stepBody.dispatchOp ctx op 0x71 fExec st = .error .stackUnderflow := by
  simp [stepBody.dispatchOp, h]

/-- OP_2ROT (interpreter.cpp:753-764, `erase(end()-6, end()-4)` + push):
`(x1 x2 x3 x4 x5 x6 -- x3 x4 x5 x6 x1 x2)`. -/
theorem tworot_ok (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (a b c d e f : ByteArray) (r : Stack)
    (h : st.stack = a :: b :: c :: d :: e :: f :: r) :
    stepBody.dispatchOp ctx op 0x71 fExec st =
      .ok { st with stack := e :: f :: a :: b :: c :: d :: r } := by
  have hlen : ¬ (List.length r + 1 + 1 + 1 + 1 + 1 + 1 < 6) := by omega
  simp [stepBody.dispatchOp, h, topAt, hlen]

/-! ## OP_PICK 0x79 / OP_ROLL 0x7a — interpreter.cpp:833-849

Core (shared case label):
```
if (stack.size() < 2) return ... INVALID_STACK_OPERATION;   // :834-835
int n = CScriptNum(stacktop(-1), fRequireMinimal).getint(); // :836, 4-byte bound (default nMaxNumSize)
popstack(stack);                                            // :837
if (n < 0 || n >= (int)stack.size())                        // :839 — POST-POP depth check
  return ... INVALID_STACK_OPERATION;
valtype vch = stacktop(-n-1);                               // :841 — n-th from top, post-pop
if (opcode == OP_ROLL) stack.erase(stack.end()-n-1);        // :842 — ROLL also erases
stack.push_back(vch);                                       // :844/847
```
Post-pop stack = `st.stack.tail` in the head-first model; `stacktop(-n-1)`
= `st.stack.tail[n.toNat]!`. The DEPTH RULE is `n < 0 ∨ st.stack.tail.length ≤ n`
(Lean) ⟺ `n < 0 ∨ n ≥ stack.size()` post-pop (Core:839). -/

/-- OP_PICK/OP_ROLL (interpreter.cpp:834-835): `stack.size() < 2` → fail,
BEFORE any decode of the depth operand. -/
theorem pickroll_underflow_lt2 (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (w : Nat) (hw : w = 0x79 ∨ w = 0x7a) (h : st.stack.length < 2) :
    stepBody.dispatchOp ctx op w fExec st = .error .stackUnderflow := by
  rcases hw with rfl | rfl <;> simp [stepBody.dispatchOp, h]

/-- OP_PICK success case (interpreter.cpp:836-848, w = 0x79): the depth
operand is POPPED and a COPY of the n-th-from-top of the remainder is
pushed (`hlt` ⟺ Core:839's `n < stack.size()` post-pop; `hn` its `n ≥ 0`
half). -/
theorem pick_ok (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (x b : ByteArray) (t : Stack) (h : st.stack = x :: b :: t)
    {n : Bitcoin.Numeric.ScriptNum}
    (hdec : decodeNum ctx.pol x 4 = .ok n)
    (hn : 0 ≤ n) (hlt : n.toNat < (b :: t).length) :
    stepBody.dispatchOp ctx op 0x79 fExec st =
      .ok { st with stack := (b :: t)[n.toNat]! :: b :: t } := by
  simp only [List.length_cons] at hlt
  have hlen : ¬ (List.length t + 1 + 1 < 2) := len_ge2
  have hn' : ¬ (n < 0) := Int.not_lt_of_ge hn
  have hleB : ¬ (List.length t + 1 ≤ n.toNat) := by omega
  simp [stepBody.dispatchOp, h, hdec, topAt, hn', hleB, hlen]

/-- OP_PICK with an OUT-OF-RANGE decoded depth (interpreter.cpp:839
`n >= (int)stack.size()` post-pop): fails even though the operand decodes. -/
theorem pick_depth_fail (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (x b : ByteArray) (t : Stack) (h : st.stack = x :: b :: t)
    {n : Bitcoin.Numeric.ScriptNum}
    (hdec : decodeNum ctx.pol x 4 = .ok n)
    (_hn : 0 ≤ n) (hle : (b :: t).length ≤ n.toNat) :
    stepBody.dispatchOp ctx op 0x79 fExec st = .error .stackUnderflow := by
  simp only [List.length_cons] at hle
  by_cases hg : List.length t + 1 + 1 < 2
  · simp [stepBody.dispatchOp, h, hg]
  · simp [stepBody.dispatchOp, h, hg, hdec, topAt, hle]

/-- OP_PICK with a NEGATIVE decoded depth (interpreter.cpp:839 `n < 0`):
fails even on a deep stack. -/
theorem pick_neg_fail (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (x b : ByteArray) (t : Stack) (h : st.stack = x :: b :: t)
    {n : Bitcoin.Numeric.ScriptNum}
    (hdec : decodeNum ctx.pol x 4 = .ok n) (hn : n < 0) :
    stepBody.dispatchOp ctx op 0x79 fExec st = .error .stackUnderflow := by
  by_cases hg : List.length t + 1 + 1 < 2
  · simp [stepBody.dispatchOp, h, hg]
  · simp [stepBody.dispatchOp, h, hg, hdec, topAt, hn]

/-- **THE OP_PICK DEPTH RULE** (interpreter.cpp:839, iff-form): with the
depth operand decoded to `n ≥ 0`, executed OP_PICK succeeds with the
copy-push effect IFF `n` indexes the POST-POP stack (`n.toNat < t.length`
⟺ Core's `n < stack.size()` after `popstack`). Failure side =
INVALID_STACK_OPERATION. -/
theorem pick_depth_rule (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (x b : ByteArray) (t : Stack) (h : st.stack = x :: b :: t)
    {n : Bitcoin.Numeric.ScriptNum}
    (hdec : decodeNum ctx.pol x 4 = .ok n) (hn : 0 ≤ n) :
    (stepBody.dispatchOp ctx op 0x79 fExec st =
        .ok { st with stack := (b :: t)[n.toNat]! :: b :: t })
      ↔ n.toNat < (b :: t).length := by
  constructor
  · intro hres
    by_cases hlt : n.toNat < (b :: t).length
    · exact hlt
    · have hle : (b :: t).length ≤ n.toNat := by omega
      have herr := pick_depth_fail ctx op fExec st x b t h hdec hn hle
      rw [herr] at hres
      simp at hres
  · intro hlt
    exact pick_ok ctx op fExec st x b t h hdec hn hlt

/-- OP_PICK with a failing `CScriptNum` decode of the depth operand
(Core:836 throws `scriptnum_error` → caught → SCRIPT_ERR_SCRIPTNUM; e.g.
a > 4-byte or, under MINIMALDATA, non-minimal encoding): the decode
error propagates verbatim. -/
theorem pick_decode_fail (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (e : ExecError) (hlen : 2 ≤ st.stack.length)
    (hdec : decodeNum ctx.pol (topAt st.stack 1) 4 = .error e) :
    stepBody.dispatchOp ctx op 0x79 fExec st = .error e := by
  have hlen' : ¬ (st.stack.length < 2) := by omega
  simp [stepBody.dispatchOp, hdec, hlen']

/-- OP_ROLL success case (interpreter.cpp:836-848, w = 0x7a): as OP_PICK
but the selected element is ERASED from its depth position
(`stack.erase(stack.end()-n-1)` → `t.take k ++ t.drop (k+1)`, `k = n.toNat`)
before the copy is pushed on top. -/
theorem roll_ok (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (x b : ByteArray) (t : Stack) (h : st.stack = x :: b :: t)
    {n : Bitcoin.Numeric.ScriptNum}
    (hdec : decodeNum ctx.pol x 4 = .ok n)
    (hn : 0 ≤ n) (hlt : n.toNat < (b :: t).length) :
    stepBody.dispatchOp ctx op 0x7a fExec st =
      .ok { st with stack :=
        (b :: t)[n.toNat]! :: ((b :: t).take n.toNat ++ (b :: t).drop (n.toNat + 1)) } := by
  simp only [List.length_cons] at hlt
  have hlen : ¬ (List.length t + 1 + 1 < 2) := len_ge2
  have hn' : ¬ (n < 0) := Int.not_lt_of_ge hn
  have hleB : ¬ (List.length t + 1 ≤ n.toNat) := by omega
  simp [stepBody.dispatchOp, h, hdec, topAt, hn', hleB, hlen]

/-- OP_ROLL depth rule: same post-pop discipline as OP_PICK (the two
opcodes share Core's case label :833). -/
theorem roll_depth_rule (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (x b : ByteArray) (t : Stack) (h : st.stack = x :: b :: t)
    {n : Bitcoin.Numeric.ScriptNum}
    (hdec : decodeNum ctx.pol x 4 = .ok n) (hn : 0 ≤ n) :
    (stepBody.dispatchOp ctx op 0x7a fExec st =
        .ok { st with stack :=
          (b :: t)[n.toNat]! :: ((b :: t).take n.toNat ++ (b :: t).drop (n.toNat + 1)) })
      ↔ n.toNat < (b :: t).length := by
  constructor
  · intro hres
    by_cases hlt : n.toNat < (b :: t).length
    · exact hlt
    · have hle : (b :: t).length ≤ n.toNat := by omega
      simp only [List.length_cons] at hle
      -- OP_ROLL shares Core's case label, hence the same depth discipline
      have hrol : stepBody.dispatchOp ctx op 0x7a fExec st =
          .error .stackUnderflow := by
        by_cases hg : List.length t + 1 + 1 < 2
        · simp [stepBody.dispatchOp, h, hg]
        · simp [stepBody.dispatchOp, h, hg, hdec, topAt, hle]
      rw [hrol] at hres
      simp at hres
  · intro hlt
    exact roll_ok ctx op fExec st x b t h hdec hn hlt

/-- OP_ROLL with depth 0 is the IDENTITY on the post-pop stack
(Core:842-847: `stack.erase(stack.end()-0-1)` removes the TOP, then
`stack.push_back(vch)` pushes a copy of it right back — net effect none).
(Oracle `roll0` row: `[00, 01, 02] --ROLL--> [01, 02]`.) -/
theorem roll0_identity (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (x b : ByteArray) (t : Stack) (h : st.stack = x :: b :: t)
    (hdec : decodeNum ctx.pol x 4 = .ok 0) :
    stepBody.dispatchOp ctx op 0x7a fExec st = .ok { st with stack := b :: t } := by
  have hle0 : ¬ (List.length t + 1 ≤ 0) := by omega
  simp [stepBody.dispatchOp, h, hdec, topAt, len_ge2, hle0]

/-- OP_PICK with depth 0 DUPLICATES the top (Core:841-847 with `n = 0`:
`vch = stacktop(-1)` and nothing is erased). (Oracle `pick0` row:
`[00, 01, 02] --PICK--> [01, 01, 02]`.) -/
theorem pick0_eq_dupTop (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (x b : ByteArray) (t : Stack) (h : st.stack = x :: b :: t)
    (hdec : decodeNum ctx.pol x 4 = .ok 0) :
    stepBody.dispatchOp ctx op 0x79 fExec st =
      .ok { st with stack := b :: b :: t } := by
  have hle0 : ¬ (List.length t + 1 ≤ 0) := by omega
  simp [stepBody.dispatchOp, h, hdec, topAt, len_ge2, hle0]

/-! ## Python3-cross-checked concrete verdicts (oracle.py rows)

`0x01`/`0x02`/`0x03`/`0x04`/`0x05`/`0x06` are the minimal encodings of
ScriptNums 1..6; `0x81` of -1; the empty byte string of 0; `01 00` is a
NON-minimal encoding of 1. Each verdict below was computed by
`oracle.py` (verbatim C++ transcription) and is proved in-kernel
by `decide` (axiom-free). -/

def b0 : ByteArray := ByteArray.empty                  -- minimal 0
def b1 : ByteArray := ByteArray.mk #[0x01]
def b2 : ByteArray := ByteArray.mk #[0x02]
def b3 : ByteArray := ByteArray.mk #[0x03]
def b4 : ByteArray := ByteArray.mk #[0x04]
def b5 : ByteArray := ByteArray.mk #[0x05]
def b6 : ByteArray := ByteArray.mk #[0x06]
def bn1 : ByteArray := ByteArray.mk #[0x81]            -- minimal -1
def bnonmin : ByteArray := ByteArray.mk #[0x01, 0x00]  -- non-minimal 1

/-- The empty machine state. -/
def st0 : State := ⟨[], [], [], 0, 0, none⟩

/-- Oracle row `nip_ok`: `[01, 02] --NIP--> [01]`. -/
example : stepBody.dispatchOp ctxD (opw 0x77) 0x77 true
    { st0 with stack := [b1, b2] } =
  .ok { st0 with stack := [b1] } := by decide

/-- Oracle row `nip_1`: singleton stack → INVALID_STACK_OPERATION. -/
example : stepBody.dispatchOp ctxD (opw 0x77) 0x77 true
    { st0 with stack := [b1] } = .error .stackUnderflow := by decide

/-- Oracle row `over_ok`: `[01, 02] --OVER--> [02, 01, 02]`. -/
example : stepBody.dispatchOp ctxD (opw 0x78) 0x78 true
    { st0 with stack := [b1, b2] } =
  .ok { st0 with stack := [b2, b1, b2] } := by decide

/-- Oracle row `over_1`: singleton stack → fail. -/
example : stepBody.dispatchOp ctxD (opw 0x78) 0x78 true
    { st0 with stack := [b1] } = .error .stackUnderflow := by decide

/-- Oracle row `tuck_ok`: `[01, 02] --TUCK--> [01, 02, 01]`. -/
example : stepBody.dispatchOp ctxD (opw 0x7d) 0x7d true
    { st0 with stack := [b1, b2] } =
  .ok { st0 with stack := [b1, b2, b1] } := by decide

/-- Oracle row `tuck_1`: singleton stack → fail. -/
example : stepBody.dispatchOp ctxD (opw 0x7d) 0x7d true
    { st0 with stack := [b1] } = .error .stackUnderflow := by decide

/-- Oracle row `2dup_ok`: `[01, 02] --2DUP--> [01, 02, 01, 02]`. -/
example : stepBody.dispatchOp ctxD (opw 0x6e) 0x6e true
    { st0 with stack := [b1, b2] } =
  .ok { st0 with stack := [b1, b2, b1, b2] } := by decide

/-- Oracle row `2dup_1`: singleton stack → fail. -/
example : stepBody.dispatchOp ctxD (opw 0x6e) 0x6e true
    { st0 with stack := [b1] } = .error .stackUnderflow := by decide

/-- Oracle row `3dup_ok`: `[01, 02, 03] --3DUP--> [01, 02, 03, 01, 02, 03]`. -/
example : stepBody.dispatchOp ctxD (opw 0x6f) 0x6f true
    { st0 with stack := [b1, b2, b3] } =
  .ok { st0 with stack := [b1, b2, b3, b1, b2, b3] } := by decide

/-- Oracle row `3dup_2`: 2-deep stack → fail. -/
example : stepBody.dispatchOp ctxD (opw 0x6f) 0x6f true
    { st0 with stack := [b1, b2] } = .error .stackUnderflow := by decide

/-- Oracle row `2over_ok`:
`[01, 02, 03, 04] --2OVER--> [03, 04, 01, 02, 03, 04]`. -/
example : stepBody.dispatchOp ctxD (opw 0x70) 0x70 true
    { st0 with stack := [b1, b2, b3, b4] } =
  .ok { st0 with stack := [b3, b4, b1, b2, b3, b4] } := by decide

/-- Oracle row `2over_3`: 3-deep stack → fail. -/
example : stepBody.dispatchOp ctxD (opw 0x70) 0x70 true
    { st0 with stack := [b1, b2, b3] } = .error .stackUnderflow := by decide

/-- Oracle row `2swap_ok`: `[01, 02, 03, 04] --2SWAP--> [03, 04, 01, 02]`. -/
example : stepBody.dispatchOp ctxD (opw 0x72) 0x72 true
    { st0 with stack := [b1, b2, b3, b4] } =
  .ok { st0 with stack := [b3, b4, b1, b2] } := by decide

/-- Oracle row `2swap_3`: 3-deep stack → fail. -/
example : stepBody.dispatchOp ctxD (opw 0x72) 0x72 true
    { st0 with stack := [b1, b2, b3] } = .error .stackUnderflow := by decide

/-- Oracle row `2rot_ok`:
`[01..06] --2ROT--> [05, 06, 01, 02, 03, 04]`. -/
example : stepBody.dispatchOp ctxD (opw 0x71) 0x71 true
    { st0 with stack := [b1, b2, b3, b4, b5, b6] } =
  .ok { st0 with stack := [b5, b6, b1, b2, b3, b4] } := by decide

/-- Oracle row `2rot_5`: 5-deep stack → fail. -/
example : stepBody.dispatchOp ctxD (opw 0x71) 0x71 true
    { st0 with stack := [b1, b2, b3, b4, b5] } = .error .stackUnderflow := by decide

/-- Oracle row `pick1`: `[n=1, 01, 02, 03] --PICK--> [02, 01, 02, 03]`
(copies the 2nd-from-top of the post-pop stack). -/
example : stepBody.dispatchOp ctxD (opw 0x79) 0x79 true
    { st0 with stack := [b1, b1, b2, b3] } =
  .ok { st0 with stack := [b2, b1, b2, b3] } := by decide

/-- Oracle row `pick0`: `[n=0, 01, 02] --PICK--> [01, 01, 02]`
(depth 0 degenerates to DUP of the top). -/
example : stepBody.dispatchOp ctxD (opw 0x79) 0x79 true
    { st0 with stack := [b0, b1, b2] } =
  .ok { st0 with stack := [b1, b1, b2] } := by decide

/-- Oracle row `pick_oob`: depth 3 into a 3-deep post-pop stack → fail
(THE DEPTH RULE, upper end). -/
example : stepBody.dispatchOp ctxD (opw 0x79) 0x79 true
    { st0 with stack := [b3, b1, b2, b3] } = .error .stackUnderflow := by decide

/-- Oracle row `pick_neg`: depth operand -1 (minimal 0x81) → fail even
on a deep stack (THE DEPTH RULE, negative end). -/
example : stepBody.dispatchOp ctxD (opw 0x79) 0x79 true
    { st0 with stack := [bn1, b1, b2, b3] } = .error .stackUnderflow := by decide

/-- Oracle row `pick_deep`: depth 2 into a 9-deep post-pop stack
succeeds; the untouched tail is preserved in order. -/
example :
    stepBody.dispatchOp ctxD (opw 0x79) 0x79 true
      { st0 with stack := [b2, b1, b2, b3, b4, b5, b6,
          ByteArray.mk #[0x07], ByteArray.mk #[0x08], ByteArray.mk #[0x09]] } =
  .ok { st0 with stack := [b3, b1, b2, b3, b4, b5, b6,
          ByteArray.mk #[0x07], ByteArray.mk #[0x08], ByteArray.mk #[0x09]] } := by
  decide

/-- Oracle row `pick_minimal`: under MINIMALDATA, the non-minimal depth
encoding `01 00` → SCRIPT_ERR_SCRIPTNUM (Core:836 CScriptNum throw). -/
example : stepBody.dispatchOp ctxMin (opw 0x79) 0x79 true
    { st0 with stack := [bnonmin, b1, b2] } = .error .scriptNum := by decide

/-- Oracle row `roll2`: `[n=2, 01, 02, 03] --ROLL--> [03, 01, 02]`
(the element MOVES: erased from depth 2, pushed on top). -/
example : stepBody.dispatchOp ctxD (opw 0x7a) 0x7a true
    { st0 with stack := [b2, b1, b2, b3] } =
  .ok { st0 with stack := [b3, b1, b2] } := by decide

/-- Oracle row `roll0`: `[n=0, 01, 02] --ROLL--> [01, 02]`
(depth 0 = IDENTITY: erase top, push the copy back). -/
example : stepBody.dispatchOp ctxD (opw 0x7a) 0x7a true
    { st0 with stack := [b0, b1, b2] } =
  .ok { st0 with stack := [b1, b2] } := by decide

/-- Oracle row `roll_oob`: depth 5 into a 3-deep post-pop stack → fail. -/
example : stepBody.dispatchOp ctxD (opw 0x7a) 0x7a true
    { st0 with stack := [b5, b1, b2, b3] } = .error .stackUnderflow := by decide

/-! ## Axiom pins (#guard_msgs) -/

/-- info: 'BitcoinProofs.Theorems.Ops.O04.nip_ok' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms nip_ok

/-- info: 'BitcoinProofs.Theorems.Ops.O04.over_ok' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms over_ok

/-- info: 'BitcoinProofs.Theorems.Ops.O04.tuck_ok' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms tuck_ok

/-- info: 'BitcoinProofs.Theorems.Ops.O04.twodup_ok' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms twodup_ok

/-- info: 'BitcoinProofs.Theorems.Ops.O04.threedup_ok' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms threedup_ok

/-- info: 'BitcoinProofs.Theorems.Ops.O04.twoover_ok' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms twoover_ok

/-- info: 'BitcoinProofs.Theorems.Ops.O04.twoswap_ok' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms twoswap_ok

/-- info: 'BitcoinProofs.Theorems.Ops.O04.tworot_ok' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms tworot_ok

/-- info: 'BitcoinProofs.Theorems.Ops.O04.pick_depth_rule' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms pick_depth_rule

/-- info: 'BitcoinProofs.Theorems.Ops.O04.roll_depth_rule' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms roll_depth_rule

/-- info: 'BitcoinProofs.Theorems.Ops.O04.pick_ok' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms pick_ok

/-- info: 'BitcoinProofs.Theorems.Ops.O04.roll_ok' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms roll_ok

/-- info: 'BitcoinProofs.Theorems.Ops.O04.pick_depth_fail' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms pick_depth_fail

/-- info: 'BitcoinProofs.Theorems.Ops.O04.roll0_identity' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms roll0_identity

/-- info: 'BitcoinProofs.Theorems.Ops.O04.pick0_eq_dupTop' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms pick0_eq_dupTop

end BitcoinProofs.Theorems.Ops.O04
