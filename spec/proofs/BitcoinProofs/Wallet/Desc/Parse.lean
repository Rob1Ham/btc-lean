import Bitcoin.Wallet.Descriptor.Parse

/-!
# Parser and checksum-gate laws

Laws proved here:

* the parser preserves the raw source spelling of every key expression
  (`KeyExpr.raw`), so a parsed key renders back exactly;
* given the parsed origin prefix, the parser preserves the key origin
  (fingerprint and path) verbatim;
* the checksum algorithm has length either `0` (invalid payload) or `8`;
* if a `#` split has the expected two-component shape and the supplied
  checksum is the computed eight-character one, the checksum gate accepts the
  payload and parsing a checksummed descriptor equals parsing its payload;
* the path-element parser is functional (deterministic).

What is *not* proved here: a full success characterisation of
`parseKeyExpr` / `parsePayload` (which would expose the parsed derivation
path and wildcard as functions of an arbitrary successful input), and a
general proof about `String.splitOn` for an arbitrary appended checksum.
Both are recorded as gaps; the
checksum-gate law is stated with the `splitOn` shape as an explicit
hypothesis, which is exactly the condition the gate inspects.
-/

namespace BitcoinProofs.Wallet.Desc

open Bitcoin.Wallet.Descriptor

/-! ## Key-source preservation -/

/-- A successfully parsed key keeps its original source spelling. -/
theorem parseKeyExpr_raw (raw : String) (ctx : KeyContext) (k : KeyExpr)
    (h : parseKeyExpr raw ctx = .ok k) : k.raw = raw := by
  unfold parseKeyExpr at h
  split at h <;> try (cases h)
  all_goals
    (repeat' split at h)
    all_goals try (cases h)
    all_goals simp [KeyExpr.raw]

/-- A successfully parsed key carries exactly the origin prefix that
`parseOrigin` found.  In particular the fingerprint and origin path are not
normalised or discarded. -/
theorem parseKeyExpr_origin (raw : String) (ctx : KeyContext) (k : KeyExpr)
    (o : Option KeyOrigin) (body : String)
    (ho : parseOrigin raw = .ok (o, body))
    (h : parseKeyExpr raw ctx = .ok k) : k.origin = o := by
  unfold parseKeyExpr at h
  simp only [ho] at h
  split at h <;> try (cases h)
  all_goals
    (repeat' split at h)
    all_goals try (cases h)
    all_goals simp [KeyExpr.origin]

/-- Source-spelling preservation in rendering form. -/
theorem parseKeyExpr_renderKey (raw : String) (ctx : KeyContext) (k : KeyExpr)
    (h : parseKeyExpr raw ctx = .ok k) : renderKey k = raw :=
  parseKeyExpr_raw raw ctx k h

/-- Literal keys produced by the parser have no BIP32 path.  This is the
literal-key half of Core's "a literal public key cannot have a derivation
path" rule, visible in the AST shape. -/
theorem parseKeyExpr_const_path (raw : String) (ctx : KeyContext)
    (o : Option KeyOrigin) (pubkey : ByteArray) (xonly : Bool) (r : String)
    (_h : parseKeyExpr raw ctx = .ok (.const o pubkey xonly r)) :
    KeyExpr.path (.const o pubkey xonly r) = [] := rfl

/-- The literal-key wildcard is always `none`. -/
theorem parseKeyExpr_const_wildcard (raw : String) (ctx : KeyContext)
    (o : Option KeyOrigin) (pubkey : ByteArray) (xonly : Bool) (r : String)
    (_h : parseKeyExpr raw ctx = .ok (.const o pubkey xonly r)) :
    KeyExpr.wildcard (.const o pubkey xonly r) = .none := rfl

/-! ## Determinism of path parsing -/

/-- `parsePathElements` is a function: any two successful results for the
same input are equal. -/
theorem parsePathElements_functional (xs : List String) (p q : List UInt32)
    (hp : parsePathElements xs = .ok p)
    (hq : parsePathElements xs = .ok q) : p = q := by
  rw [hp] at hq
  cases hq
  rfl

/-! ## Checksum gate -/

/-- Core's checksum is either the empty invalid-character sentinel or a
well-formed eight-character digest. -/
theorem descriptorChecksum_length (payload : String) :
    (descriptorChecksum payload).length = 0 ∨
      (descriptorChecksum payload).length = 8 := by
  unfold descriptorChecksum
  split
  · left; rfl
  · right; simp

/-- Under the `#`-split shape that the gate inspects, an eight-character
checksum equal to `descriptorChecksum payload` is accepted and the gate
returns the payload. -/
theorem checkChecksum_addChecksum (payload checksum : String)
    (hsplit : (payload ++ "#" ++ checksum).splitOn "#" = [payload, checksum])
    (hcs : checksum = descriptorChecksum payload)
    (hlen : checksum.length = 8) :
    checkChecksum (payload ++ "#" ++ checksum) false = .ok payload := by
  unfold checkChecksum
  rw [hsplit]
  have hlen' : (descriptorChecksum payload).length = 8 := by
    simpa [hcs] using hlen
  have hne : descriptorChecksum payload ≠ "" := by
    intro h
    rw [h] at hlen'
    simp at hlen'
  simp [hcs, hne, hlen']

/-- The same shape with no `#` at all: a payload whose checksum is non-empty
is accepted when no checksum is required. -/
theorem checkChecksum_noChecksum (payload : String)
    (hsplit : payload.splitOn "#" = [payload])
    (hne : descriptorChecksum payload ≠ "") :
    checkChecksum payload false = .ok payload := by
  unfold checkChecksum
  rw [hsplit]
  simp [hne]

/-- A successful checksum gate is the only thing `parse` looks at before
delegating to `parsePayload`. -/
theorem parse_eq_parsePayload_of_checkChecksum (input payload : String)
    (h : checkChecksum input false = .ok payload) :
    parse input = parsePayload payload := by
  unfold parse parseWithChecksum
  rw [h]

/-- Checksummed parsing does not change the parsed descriptor: adding a valid
checksum and re-parsing yields the same result as parsing the payload. -/
theorem parse_addChecksum (payload checksum : String)
    (hsplit : (payload ++ "#" ++ checksum).splitOn "#" = [payload, checksum])
    (hcs : checksum = descriptorChecksum payload)
    (hlen : checksum.length = 8) :
    parse (payload ++ "#" ++ checksum) = parsePayload payload := by
  rw [parse_eq_parsePayload_of_checkChecksum _ _
    (checkChecksum_addChecksum payload checksum hsplit hcs hlen)]

/-- Corollary for `addChecksum`: under the split shape, checksum appending is
transparent to the parsed descriptor. -/
theorem parse_addChecksum_self (payload : String)
    (hsplit : (payload ++ "#" ++ descriptorChecksum payload).splitOn "#" =
      [payload, descriptorChecksum payload])
    (hlen : (descriptorChecksum payload).length = 8) :
    parse (addChecksum payload) = parsePayload payload := by
  unfold addChecksum
  exact parse_addChecksum payload (descriptorChecksum payload) hsplit rfl hlen

end BitcoinProofs.Wallet.Desc
