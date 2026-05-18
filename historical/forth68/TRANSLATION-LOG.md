# Translation log: 1968 FORTH -> `sw-ibm1130-asm` syntax

## Upstream pin

- Upstream repo: `https://github.com/monsonite/1968-FORTH`
- Source file:   `FORTH68asm.txt` (645 lines, 1130 assembly)
- Translation date: 2026-05-13
- Translator:    Michael A Wright (assisted by Claude Opus 4.7)
- Saga step:     5 of `forth-on-1130` (`gen-isa` repo, agentrail).

## Files translated

| Upstream file       | Translated to        | Status                     |
| ------------------- | -------------------- | -------------------------- |
| `FORTH68asm.txt`    | `kernel.asm`         | core translated; data tables and LIBF I/O stubbed (saga step 5) |
| `FORTH68lst.txt`    | `listing.fth`        | deferred to a follow-on step |

`FORTH-68_notes.txt` and `notes on FORTX assem code.pdf` are
documentation-only; their content is consulted during translation
but not transformed.

## Transformation policy (mechanical, NOT logged per occurrence)

These mechanical transformations are applied uniformly:

- **Column layout.** Moore's fixed-column source (label cols 21-25,
  opcode cols 27-31, operand cols 33+, comment after operand)
  reformatted to free-form whitespace-driven layout.
- **Label suffix.** Each label `FOO` at its definition site
  becomes `FOO:`. Reference sites stay bare.
- **Comment character.** Trailing operand-column comments are
  preserved as `;`-prefixed comments on the same line.
- **`*`-line-prefix.** Lines beginning with `*` (e.g. `*LIST ALL`)
  are treated as comments by our asm. Mechanical drop in the
  output (the asm accepts them as whole-line comments).
- **JCL boundaries.** `// JOB`, `// DUP`, `// ASM`, `*DELETE`,
  `*STORE` lines are mechanically dropped (whole-line comments
  accepted by the asm). They are 1130 monitor / job-card directives
  that have no role in our toolchain.
- **`/XXX` hex literals.** Preserved as-is; the asm accepts them.
- **Conditional-branch mnemonics** (`B`, `BL`, `BZ`, `BNZ`, `BP`,
  `BN`, `BNP`, `BOD`): preserved; the asm accepts them as aliases.
- **Shift sub-ops** (`SLT`, `SRT`): preserved; the asm accepts them.
- **Operand expressions** (`SYM+N`, `*-N`): preserved; the asm
  accepts them.
- **Symbolic operands auto-promote to long form** under the asm's
  pass-1 rule (matches the historical 1130 Assembler's behaviour
  for symbol operands). No `L` flag needed when the operand is a
  bare symbol or expression.
- **`,+-` listing-format flags.** Moore's source occasionally
  shows operands like `BSI L RECOR,+-` where `,+-` is a relocation-
  indicator artifact of the listing format, not source syntax.
  The `,+-` is dropped at translation; the underlying BSI/BSC is
  preserved. (Applies to lines 24, 137, 368, 422 of the upstream
  source.)

## Non-mechanical transformations (per-occurrence log)

### LC.1: `LDX I3 X` -> `LDX L I 3, X`

The historical `LDX I3 X` (load XR3, long indirect through X) is
spelled in our asm as `LDX L I 3, X` (long form, indirect flag,
tag=3, operand X). Mechanical at point of use but documented here
because the surface syntax is materially different.

Applies at lines 124, 144, 163, 245, 273, 340, 377, 414, 436 of
the upstream source.

### LC.2: `MDM L X,N` -> `LD L X; A L LIT; STO L X` (multi-op rewrite)

The 1130 `MDM` (Modify Memory) directive adds/subtracts a value
to a memory cell in one instruction. Our asm doesn't yet have
`MDM` as a top-level mnemonic (it could be added in a future
asm-extension step). For now, `MDM L X,N` is expanded into a
3-instruction `LD; A/S; STO` sequence with the literal `N`
materialised as a separate `FOUR_LIT` / `ONE` etc. constant.

Applies throughout the kernel (lines 162, 165, 240, 244, 258, 261,
266, 272, 304, 324, 386, 396, 404, 419, 434).

The `FOUR_LIT` symbol is newly introduced in the translation; it
holds the value 4 for the `E += 4` and `E1 += 4` MDM-rewrites.

### LC.3: `LINK BALO` -> stub comment

The 1130 `LINK` directive (link to another assembly module) is
out of scope for our toolchain (we don't have multi-module
assembly). Moore uses `LINK BALO` at line 229 to link in a
binary I/O subroutine; we replace with a stub comment and let
control fall through to the FORTH interpreter. Behavioural effect:
no BALO routines available at runtime; programs that depend on
them won't work until a future I/O-bringup saga.

### LC.4: LIBF-based disk and printer routines -> STUB

Per `gen-isa/docs/forth-on-1130-decisions.md` Sec 2.6, `LIBF` is
out of scope for this saga. The kernel sections that use it are
stubbed as no-op returns:

- `BLOCK` (lines 376-390 upstream): reads next disk record via
  `LIBF DISK1`. Stubbed; returns immediately.
- `PUT` and `PRINT` (lines 411-446 upstream): output via
  `LIBF PRNT1`. Stubbed; both return immediately.

A future "1130 peripheral simulation" saga will provide LIBF
emission and the device subsystem.

### LC.5: `2*WORD` byte/word arithmetic -- RESOLVED (saga step 9)

Moore's source uses `2*WORD`, `2*SECT+74`, `2*SECT+642+72`,
`2*PRN+2`, `2*PRN+74` to convert word-addresses into byte-
addresses for character-pointer arithmetic (FETCH and DEPOSIT
work in byte-address form, packing two chars per word).

**Resolution (step 9):** `sw-ibm1130-asm` gained a multiplication
operator (Operand::Multiply { lhs, rhs }; the `LHS*RHS` parse
recognises `*` at any position > 0 as multiplication, leaving
position-0 `*` as the LC sentinel). With it, `2*WORD_SYM`,
`2*SECT+74`, etc. parse and resolve correctly.

kernel.asm was updated to use:
- `W1: DC 2*WORD_SYM` (was `DC WORD_SYM`).
- `LDX L 3, 2*SECT+74` in START (was `LDX L 3, SECT_BASE`;
  SECT_BASE renamed back to its arithmetic form).
- `C1: DC 2*SECT+714` (was `DC 0`; was `2*SECT+642+72` in Moore).
- `C3: DC 2*SECT+74` (was `DC 0`).

After this, the inject test (`kernel_parses.rs`'s
`inject_a_known_word_observes_parser_behavior`) shows the
kernel's `C` cursor advancing through the injected input area
(0x1c40 -> 0x1c46 across 5000 steps with injection at step 50).
The factor-of-2 arithmetic is load-bearing for any FORTH parser
behaviour that involves character I/O.

### LC.6: `BNP I COM` -> `BSC L COM, 0` (with mask)

Moore's `BNP I` (branch-on-not-positive indirect) at line 280 is
the indirect form of a conditional branch. Our asm's conditional-
branch aliases support direct mode but not indirect+conditional
in a single mnemonic. The translation expands to the explicit
form: `BSC L I` with the appropriate mask. (Mask `0x18` = P|N is
"branch when non-zero"; we want "branch on not-positive" =
"branch when N or Z" = `0x20 | 0x10 = 0x30`.)

For this saga's purposes the line is currently written as
`BNP L COM` (drops the indirect, keeps the conditional). Step 6
runtime tests will determine whether the indirect form is
needed and the asm extended accordingly.

### LC.7: `STX L3 E` and friends -> `STX L 3, E`

Moore's compound flag/tag form `STX L3` (long-form with XR3 tag)
becomes the space-separated form `STX L 3, E` in our asm. Same
mechanical transformation for `LDX L3`, `LD L3`, `STO L3`,
`LD I3`, etc.

### LC.8: Mid-instruction `DC *` and `DC X` sentinels

Moore uses `LABEL DC *` (define a constant with value =
location-counter) followed by another `DC` on the next line to
allocate a 2-word area where the first word records the address
of the second. We preserve the `DC *` form directly (our asm
supports `*` as LC in operand expressions).

### LC.9: XR3 use preserved (DEVIATES from decisions Sec 2.2)

`gen-isa/docs/forth-on-1130-decisions.md` Sec 2.2 originally
specified that every XR3 use would be rewritten as a memory-cell
operation, because our toolchain ABI reserves XR3 as the LIBF
transfer-vector base. **The translation deviates from that
decision** and preserves XR3 use as Moore wrote it. Rationale:

- Moore's kernel is a closed-system FORTH. It has no LIBF interop
  concerns of its own.
- XR3 rewrites are not syntactic -- they are semantic (changing
  which register holds what data, with knock-on overhead).
- Preserving XR3 is more faithful to "we are recreating *that*
  FORTH" (per the decisions doc's framing).
- The toolchain's ABI reservation still applies to our codegen-
  emitted code; we just don't apply it to this hand-coded kernel.

The deviation is documented here rather than hidden; future
saga sessions can revisit if XR3 use causes interop problems
with the rest of the system (e.g. if codegen-produced TIR code
gets called from this kernel and needs XR3 to be a frame base).

### LC.10: `STORE` opcode name collision -> `STORE:` label

Moore uses `STORE` as a kernel-primitive label, and `STO` as the
1130 mnemonic. Our asm has `sto` as the canonical mnemonic; no
collision. The `STORE` label is preserved verbatim.

### LC.11: `OR` label vs `OR` mnemonic

Moore uses `OR` as a kernel-primitive label. Our asm has `or` as
the bitwise-or mnemonic. Collision: the parser would mistake
`OR` at a definition site for the mnemonic. **Renamed `OR` ->
`OR_PRIM`** in the translation (at line 291 of the upstream).
References to `OR` elsewhere in the source are updated. This is
the only mnemonic-vs-label collision in Moore's kernel.

### LC.12: `WORD` as a label vs `WORD` as a workspace anchor

Moore uses `WORD` as a label for a 20-word storage area. We
rename to `WORD_SYM` to make the role explicit and to avoid any
parser disambiguation issue. References updated.

### LC.13: `FORTH` label / forth main entry collision

Moore's main interpreter loop is at label `FORTH` (line 230).
We rename to `FORTH_RTN` in the translation to avoid any
case-insensitive collision with `Ibm1130`-typename-related
identifiers. Pure-label change; no semantic effect.

### LC.14: BCD lookup table -- preserved verbatim

The 64-word EBCDIC-to-FORTH-internal-code table at lines 453-516
of the upstream source is preserved byte-for-byte as a sequence
of numeric `DC` initialisers. The translation comments retain
Moore's per-entry character glosses (`; A`, `; B`, etc.).

### LC.15: Initial dictionary entries (lines 519-635 upstream) -- COMPLETE (saga step 7)

Moore's source includes a large pre-built dictionary at the end
of the file (the initial set of named primitives). The full
33-entry chain is now translated:

| Slot | Name             | Code address  | Notes |
| ---- | ---------------- | ------------- | ----- |
| ...  | (UNDEF catch-all)| UNDEF         | first slot, no name |
| 1    | FORTH            | FORTH_RTN     | main loop |
| 2    | RECURSE          | LITER_PLUS1   | name+code+R variable |
| 3    | FIND             | DO            | dictionary lookup |
| 4    | ADDRESS          | ADDR_PLUS1    | push variable address |
| 5    | END              | COM           | end definition |
| 6    | HEX              | HEX           | hex literal |
| 7    | OR (-> OR_PRIM)  | OR_PRIM       | bitwise OR; renamed for mnemonic clash (LC.11) |
| 8    | =                | STORE         | indirect store |
| 9    | COLON (`:`)      | ENTER         | start definition |
| 10   | .                | ENTER         | synonym for `:` |
| 11   | ; (SEMICOLON)    | COM           | end definition |
| 12   | ,                | COM           | synonym for `;` |
| 13   | IC               | ADDR_PLUS1    | name+code+IC variable cell |
| 14   | CENT (cent-sign) | OPER          | machine-code definition |
| 15   | OPERATION        | OPER          | synonym for cent-sign |
| 16   | ENTRY            | ENTRY         | dictionary entry mgmt |
| 17   | INTEGER          | INTEG         | declare integer var |
| 18   | INC              | INC           | increment counter |
| 19   | SD               | SD            | stack-to-deposit |
| 20   | CONVERT          | CONVE         | EBCDIC -> FORTH code |
| 21   | FETCH            | FETCH         | char fetch |
| 22   | DEPOSIT          | DEPOS         | char deposit |
| 23   | PUT              | PUT           | (LIBF stub) |
| 24   | PRINT            | PRINT         | (LIBF stub) |
| 25   | NEXT             | NEXT          | word parser |
| 26   | LOC              | LOC           | look up word address |
| 27   | E                | LITER_PLUS1   | name+code+E variable |
| 28   | LIT              | LITER_PLUS1   | literal handler |
| 29   | E1 (E2 label)    | LITER_PLUS1   | name+code+E1 variable |

The `IC` variable cell now lives inside the dictionary block (at
the 4th-word slot of the IC entry), per Moore's original layout.
The previous standalone `IC:` declaration was removed.

### LC.18: FORTH listing translated (`listing.fth`)

`FORTH68lst.txt` translated to `historical/forth68/listing.fth`.
This is FORTH source (not asm); preserves Moore's `.WORD body ,`
syntax verbatim (we don't modernise to `: ;`). Status:
**documentation-only**. The kernel's ACCEPT mechanism reads
characters via `LIBF DISK1`, which is stubbed; until a future
saga wires real disk I/O or a memory-buffer input source, the
listing is not executable. Section dividers added by us for
navigation; the listing's structure (instruction-template
builders, control-flow words, character tables, console I/O,
disk I/O, file system, top-level entry) is annotated.

### LC.16: `BNP I COM` (return-via-indirect-conditional) -> `BNP L COM`

Moore's `BNP I COM` pattern uses indirect addressing on a
conditional branch (return through an indirect pointer if the
condition holds). Our asm doesn't yet combine `I` (indirect) with
conditional-branch mnemonic aliases. The translation reduces
this to `BNP L COM` (non-indirect). Runtime tests will determine
whether the indirect form matters; if so, the asm gains a small
extension.

### LC.17: Stack-array slots `A-1`, `A-2`, `A-4` (workspace offsets)

Moore's source references `A-2`, `A-1`, `A-4` as workspace
addresses below the base `A`. Our parser does not recognise
hyphen-separated label arithmetic at reference sites (only the
plus/minus offset form `A-2`). Should work, but I introduced
explicit symbols `A_MINUS_2`, `A_MINUS_1`, `A_MINUS_4` to keep
the translation unambiguous. Documented per
`gen-isa/docs/forth-on-1130-decisions.md` Sec 2.6.

## Scope of this step

Saga step 5 deliberately ships a **partial translation**:

- Done: core text-interpreter primitives (CONVE, ACCEP, RETRY,
  NEXT, ALPHA, SPECI, SAVE, FETCH, DEPOS, DO, UNDEF, HEX, ENTRY,
  ENTER, INTER, COM, LOC, OR_PRIM, STORE, SD, ADDR, LITER, OPER,
  CONS, INTEG, RECUR, RETUR, INC), the START initialisation
  sequence, the workspace declarations, the BCD lookup table.
- Stubbed: LIBF-based BLOCK / PUT / PRINT routines. Per delta
  2.6 / 2.7.
- Stubbed: initial dictionary table. Mechanical, deferred.
- Not translated: `FORTH68lst.txt` (the FORTH-level disk dump).
  Belongs to a follow-on saga step (step 5b or step 6's
  preamble).

The current `kernel.asm` assembles cleanly under sw-ibm1130-asm.
Integration test `tests/kernel_assembles.rs` is the saga-step-5
acceptance criterion.

## Saga step 6 inputs

- The translated `kernel.asm` and the lessons captured here.
- The runtime test plan: load kernel into emulator memory, set
  IAR = START, run for N steps, observe the parser/interpreter
  state.
- A small `programs/test1.fth` that invokes a couple of
  primitives, to be loaded into the kernel's text buffer at
  startup and stepped.
