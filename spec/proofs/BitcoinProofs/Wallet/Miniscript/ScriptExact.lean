import Bitcoin.Wallet.Miniscript
import Bitcoin.Wallet.RuleAttr

/-!
# Script emission: totality and byte length

This file proves two structural facts about `Bitcoin.Wallet.Miniscript.toScript`
(`spec/core/Bitcoin/Wallet/Miniscript/Script.lean`), the model of Core's
`Node::ToScript` (`src/script/miniscript.h:798-880` at pin `cce32b168`):

* `toScript_total`: the emitter is a total function from a context and node
  to a `Script`; it has no failure branch and no `Option`;
* `toScript_size`: its output length is the recursive formula `scriptLen`,
  which mirrors the emitter fragment by fragment.

The length formula is *syntactic*: it counts opcode bytes and push lengths,
including the minimal integer encoding chosen by `pushInt`.  It does not
claim that the emitted bytes are accepted by the consensus interpreter; that
bridge is deliberately outside this file's scope (see
`BitcoinProofs.Wallet.Miniscript.TypeSound`).

What is **not** modelled or claimed here: descriptor key serialization
(`Ctx::ToPKBytes`), checksums, `ToString`/`FromScript` round-trips, and any
semantic property of the emitted script beyond its byte length.
-/

namespace BitcoinProofs.Wallet.Miniscript

open Bitcoin.Wallet.Miniscript
open Bitcoin.Wallet.Miniscript.Node

/-! ## Helper lengths -/

/-- Size of a raw byte list built by `bytes`. -/
theorem bytes_size (l : List Nat) : (bytes l).size = l.length := by
  simp [bytes, ← ByteArray.size_data]

/-- A one-byte opcode has size one. -/
theorem op_size (n : Nat) : (op n).size = 1 := by
  simp [op, bytes, ← ByteArray.size_data]

/-- Size of a concatenation of scripts. -/
theorem concatScripts_size (ss : List Script) :
    (concatScripts ss).size = (ss.map (fun s => s.size)).sum := by
  induction ss with
  | nil => simp [concatScripts]
  | cons s ss ih =>
    simp [concatScripts, ih, List.sum_cons, ByteArray.size_append]

/-- Concatenating scripts after appending one opcode to each adds one byte
per script. -/
theorem concatScripts_map_append_op_size (ss : List Script) (o : Nat) :
    (concatScripts (ss.map (fun s => s ++ op o))).size =
      (ss.map (fun s => s.size)).sum + ss.length := by
  induction ss with
  | nil => simp [concatScripts]
  | cons s ss ih =>
    simp only [List.map_cons, concatScripts, ByteArray.size_append, ih,
      List.sum_cons, List.length_cons, op_size]
    omega

/-- Size of the `OP_ADD`-interspersed threshold branch sequence. -/
theorem intersperseAdd_size (ss : List Script) :
    (intersperseAdd ss).size = (ss.map (fun s => s.size)).sum + (ss.length - 1) := by
  cases ss with
  | nil => simp [intersperseAdd]
  | cons s ss =>
    simp only [intersperseAdd, ByteArray.size_append, concatScripts_map_append_op_size,
      List.map_cons, List.sum_cons, List.length_cons]
    omega

/-- The `multi_a` key sequence pushes each key and appends one
`OP_CHECKSIG`/`OP_CHECKSIGADD` byte to it. -/
theorem concatScripts_map_pushBytes_op_size (keys : List Key) (o : Nat) :
    (concatScripts (keys.map (fun k => pushBytes k ++ op o))).size =
      (keys.map (fun k => (pushBytes k).size)).sum + keys.length := by
  induction keys with
  | nil => simp [concatScripts]
  | cons k rest ih =>
    simp [concatScripts, ByteArray.size_append, ih, op_size]
    all_goals omega

/-- Size of a `multi_a` key sequence. -/
theorem multiAKeyScript_size (keys : List Key) :
    (multiAKeyScript keys).size =
      (keys.map (fun k => (pushBytes k).size)).sum + keys.length := by
  cases keys with
  | nil => simp [multiAKeyScript]
  | cons k rest =>
    simp only [multiAKeyScript, ByteArray.size_append, op_size,
      concatScripts_map_pushBytes_op_size, List.map_cons, List.sum_cons, List.length_cons]
    omega

/-! ## The recursive length formula -/

/-- Byte length of `toScriptWith ctx verify n`, computed in parallel with the
emitter.  The two branches of `thresh`, the `multi`/`multi_a` key lists, and
the conditional `OP_VERIFY` of `wrapV` are counted exactly. -/
def scriptLenWith (ctx : MiniscriptContext) (verify : Bool) : Node → Nat
  | .pkK key => (pushBytes key).size
  | .pkH _ keyHash => 3 + (pushBytes keyHash).size
  | .older n => (pushInt n).size + 1
  | .after n => (pushInt n).size + 1
  | .sha256 h => 6 + (pushBytes h).size
  | .hash256 h => 6 + (pushBytes h).size
  | .ripemd160 h => 6 + (pushBytes h).size
  | .hash160 h => 6 + (pushBytes h).size
  | .wrapA x => 1 + scriptLenWith ctx false x + 1
  | .wrapS x => 1 + scriptLenWith ctx verify x
  | .wrapC x => scriptLenWith ctx verify x + 1
  | .wrapD x => 3 + scriptLenWith ctx false x
  | .wrapV x =>
    if (calcType ctx x).has .x then scriptLenWith ctx true x + 1
    else scriptLenWith ctx true x
  | .wrapJ x => 4 + scriptLenWith ctx false x
  | .wrapN x => scriptLenWith ctx false x + 1
  | .andV x y => scriptLenWith ctx false x + scriptLenWith ctx verify y
  | .andB x y => scriptLenWith ctx false x + scriptLenWith ctx false y + 1
  | .orB x y => scriptLenWith ctx false x + scriptLenWith ctx false y + 1
  | .orD x y => scriptLenWith ctx false x + scriptLenWith ctx false y + 3
  | .orC x y => scriptLenWith ctx false x + scriptLenWith ctx false y + 2
  | .orI x y => scriptLenWith ctx false x + scriptLenWith ctx false y + 3
  | .thresh k xs =>
    (xs.map (scriptLenWith ctx false)).sum + (xs.length - 1) + (pushInt k).size + 1
  | .multi k keys =>
    (pushInt k).size + (keys.map (fun key => (pushBytes key).size)).sum +
      (pushInt keys.length).size + 1
  | .multiA k keys =>
    (keys.map (fun key => (pushBytes key).size)).sum + keys.length +
      (pushInt k).size + 1
  termination_by n => sizeOf n
  decreasing_by
    all_goals simp_wf
    all_goals
      first
        | omega
        | (have h := List.sizeOf_lt_of_mem (by assumption); omega)

/-- Byte length of the top-level script. -/
def scriptLen (ctx : MiniscriptContext) (n : Node) : Nat :=
  scriptLenWith ctx false n

/-! ## Length agreement -/

/-- The threshold branch sequence has the summed length of its branches plus
one `OP_ADD` per separator. -/
theorem intersperseAdd_map_size (ctx : MiniscriptContext) (xs : List Node)
    (ih : ∀ x ∈ xs, (toScriptWith ctx false x).size = scriptLenWith ctx false x) :
    (intersperseAdd (xs.map (fun x => toScriptWith ctx false x))).size =
      (xs.map (fun x => scriptLenWith ctx false x)).sum + (xs.length - 1) := by
  rw [intersperseAdd_size]
  have h : (xs.map (fun x => toScriptWith ctx false x)).map (fun s => s.size) =
      xs.map (fun x => scriptLenWith ctx false x) := by
    rw [List.map_map]
    apply List.map_congr_left
    exact ih
  rw [h, List.length_map]

/-- The emitter's output length is exactly `scriptLenWith`. -/
theorem toScriptWith_size (ctx : MiniscriptContext) (verify : Bool) (n : Node) :
    (toScriptWith ctx verify n).size = scriptLenWith ctx verify n := by
  fun_induction scriptLenWith ctx verify n with
  | case1 =>
    simp_all only [toScriptWith, scriptLenWith]
  | case2 =>
    simp_all only [toScriptWith, scriptLenWith, ByteArray.size_append, op_size]
    all_goals omega
  | case3 =>
    simp_all only [toScriptWith, scriptLenWith, ByteArray.size_append, op_size]
    all_goals omega
  | case4 =>
    simp_all only [toScriptWith, scriptLenWith, ByteArray.size_append, op_size]
    all_goals omega
  | case5 =>
    simp_all only [toScriptWith, scriptLenWith, ByteArray.size_append, op_size]
    try (split <;> simp_all only [ByteArray.size_append, op_size])
    all_goals omega
  | case6 =>
    simp_all only [toScriptWith, scriptLenWith, ByteArray.size_append, op_size]
    try (split <;> simp_all only [ByteArray.size_append, op_size])
    all_goals omega
  | case7 =>
    simp_all only [toScriptWith, scriptLenWith, ByteArray.size_append, op_size]
    try (split <;> simp_all only [ByteArray.size_append, op_size])
    all_goals omega
  | case8 =>
    simp_all only [toScriptWith, scriptLenWith, ByteArray.size_append, op_size]
    try (split <;> simp_all only [ByteArray.size_append, op_size])
    all_goals omega
  | case9 =>
    simp_all only [toScriptWith, scriptLenWith, ByteArray.size_append, op_size]
    all_goals omega
  | case10 =>
    simp_all only [toScriptWith, scriptLenWith, ByteArray.size_append, op_size]
    all_goals omega
  | case11 =>
    simp_all only [toScriptWith, scriptLenWith, ByteArray.size_append, op_size]
    try (split <;> simp_all only [ByteArray.size_append, op_size])
    all_goals omega
  | case12 =>
    simp_all only [toScriptWith, scriptLenWith, ByteArray.size_append, op_size]
    all_goals omega
  | case13 =>
    rename_i verify x hx ih
    simp [toScriptWith, scriptLenWith, hx, ByteArray.size_append, op_size, ih]
    all_goals omega
  | case14 =>
    rename_i verify x hx ih
    simp [toScriptWith, scriptLenWith, hx, ByteArray.size_append, op_size, ih]
    all_goals omega
  | case15 =>
    simp_all only [toScriptWith, scriptLenWith, ByteArray.size_append, op_size]
    all_goals omega
  | case16 =>
    simp_all only [toScriptWith, scriptLenWith, ByteArray.size_append, op_size]
    all_goals omega
  | case17 =>
    simp_all only [toScriptWith, scriptLenWith, ByteArray.size_append]
    all_goals omega
  | case18 =>
    simp_all only [toScriptWith, scriptLenWith, ByteArray.size_append, op_size]
    all_goals omega
  | case19 =>
    simp_all only [toScriptWith, scriptLenWith, ByteArray.size_append, op_size]
    all_goals omega
  | case20 =>
    simp_all only [toScriptWith, scriptLenWith, ByteArray.size_append, op_size]
    all_goals omega
  | case21 =>
    simp_all only [toScriptWith, scriptLenWith, ByteArray.size_append, op_size]
    all_goals omega
  | case22 =>
    simp_all only [toScriptWith, scriptLenWith, ByteArray.size_append, op_size]
    all_goals omega
  | case23 =>
    rename_i verify k xs ih
    simp only [toScriptWith, scriptLenWith, ByteArray.size_append, op_size,
      intersperseAdd_map_size ctx xs ih]
    try (split <;> simp_all only [ByteArray.size_append, op_size])
    all_goals omega
  | case24 =>
    rename_i verify k keys
    simp [toScriptWith, scriptLenWith, ByteArray.size_append, op_size,
      concatScripts_size, List.map_map, Function.comp_def]
    try (split <;> simp_all only [ByteArray.size_append, op_size])
    all_goals omega
  | case25 =>
    rename_i verify k keys
    simp only [toScriptWith, scriptLenWith, ByteArray.size_append, op_size,
      multiAKeyScript_size]
    try (split <;> simp_all only [ByteArray.size_append, op_size])
    all_goals omega

/-- Top-level byte length: `toScript` has the length given by `scriptLen`. -/
theorem toScript_size (ctx : MiniscriptContext) (n : Node) :
    (toScript ctx n).size = scriptLen ctx n :=
  toScriptWith_size ctx false n

/-- Totality: for every context and node, the emitter returns a script.
There is no error branch. -/
theorem toScript_total (ctx : MiniscriptContext) (n : Node) :
    ∃ s : Script, toScript ctx n = s :=
  ⟨toScript ctx n, rfl⟩

/-! ## Fragment length equations -/

theorem toScript_pkK (ctx : MiniscriptContext) (key : Key) :
    toScript ctx (.pkK key) = pushBytes key := by
  simp [toScript, toScriptWith]

theorem toScript_pkH (ctx : MiniscriptContext) (key : Key) (keyHash : ByteArray) :
    toScript ctx (.pkH key keyHash) =
      op 0x76 ++ op 0xa9 ++ pushBytes keyHash ++ op 0x88 := by
  simp [toScript, toScriptWith]

/-- MS-023: PK_K emits only the key push; PK_H emits OP_DUP, OP_HASH160,
the key hash and OP_EQUALVERIFY. -/
@[walletRule "MS-023"]
theorem toScript_pk_fragments (ctx : MiniscriptContext) (key : Key) (keyHash : ByteArray) :
    toScript ctx (.pkK key) = pushBytes key ∧
    toScript ctx (.pkH key keyHash) =
      op 0x76 ++ op 0xa9 ++ pushBytes keyHash ++ op 0x88 := by
  exact ⟨toScript_pkK ctx key, toScript_pkH ctx key keyHash⟩


theorem toScript_older (ctx : MiniscriptContext) (n : Nat) :
    toScript ctx (.older n) = pushInt n ++ op 0xb2 := by
  simp [toScript, toScriptWith]

theorem toScript_after (ctx : MiniscriptContext) (n : Nat) :
    toScript ctx (.after n) = pushInt n ++ op 0xb1 := by
  simp [toScript, toScriptWith]

/-- The four hash fragments share one shape and differ only in the hash
opcode byte (`OP_SHA256` 0xa8, `OP_HASH256` 0xaa, `OP_RIPEMD160` 0xa6,
`OP_HASH160` 0xa9). -/
theorem toScript_hash (ctx : MiniscriptContext) (h : ByteArray)
    (frag : Node) (hf : frag = .sha256 h ∨ frag = .hash256 h ∨
      frag = .ripemd160 h ∨ frag = .hash160 h) :
    ∃ hop : Nat, (hop = 0xa8 ∨ hop = 0xaa ∨ hop = 0xa6 ∨ hop = 0xa9) ∧
      toScript ctx frag =
        op 0x82 ++ op 0x01 ++ op 0x20 ++ op 0x88 ++ op hop ++
          pushBytes h ++ op 0x87 := by
  rcases hf with rfl | rfl | rfl | rfl
  · exact ⟨0xa8, by simp, by simp [toScript, toScriptWith]⟩
  · exact ⟨0xaa, by simp, by simp [toScript, toScriptWith]⟩
  · exact ⟨0xa6, by simp, by simp [toScript, toScriptWith]⟩
  · exact ⟨0xa9, by simp, by simp [toScript, toScriptWith]⟩

end BitcoinProofs.Wallet.Miniscript
