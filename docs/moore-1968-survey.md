# Survey: Moore's 1968 FORTH for the IBM 1130

> Prose findings from reading `monsonite/1968-FORTH` (cloned to
> `reference/1968-FORTH/` per `docs/references.md`). Saga step 2
> of `forth-on-1130`. ASCII-only.
>
> The companion document
> [`moore-1968-primitives.md`](moore-1968-primitives.md) is the
> mechanical side-by-side primitive table; this one is the
> narrative reading.
>
> All quotes / paraphrases attribute to Moore (the author),
> Carl Claunch (whose 2018 analysis fills the historical gaps),
> or the upstream `monsonite/1968-FORTH` README.

## 1. The shape of the system

Moore's 1968 FORTH is a kernel + a FORTH-source overlay loaded
from disk. Two files survive:

- `FORTH68asm.txt` -- 645 lines of IBM 1130 assembly. The kernel.
  Provides the text interpreter, the dictionary mechanics, the
  primitive functions for stack manipulation and code generation,
  and bootstrap I/O for console + disk.
- `FORTH68lst.txt` -- 234 lines of FORTH source. A "deck of
  cards" that defines higher-level words (instruction templates,
  control words, file system, the REPL) on top of the kernel.

The kernel was originally a card deck assembled to absolute
memory at `/900` (hex 0x900 = decimal 2304); the FORTH disk file
was loaded by FORTH itself once the kernel booted. When the
saga's translation step ships, this two-file shape is preserved:
`historical/forth68/kernel.asm` (translated from the assembly)
plus `historical/forth68/listing.fth` (translated from the FORTH
listing).

## 2. Threading model: indirect-threaded, by name "interpretation"

Moore's preface (and Claunch's analysis) describe the kernel's
inner loop as `NEXT`: fetch the next FORTH word, look it up in
the dictionary, and execute. Each colon-defined word's body is a
sequence of execution addresses; each entry triggers another
lookup-and-execute through `NEXT`.

This is **indirect-threaded code (ITC)** in the modern sense.
Moore did not use the term in 1968 (the threading vocabulary came
later) -- he just called it "interpretation". Same mechanism.

There is no compile-to-native step. The variable-dictionary entry
for `: SQ DUP * ;` is the literal sequence of execution addresses
for `DUP` and `*`. Compilation is "deposit each word's exec
address into the variable dictionary in order".

Important consequence: the saga's hand-written kernel
(translated from Moore's) does NOT need a register allocator to
work. ACC is a scratch register; XR1, XR2 are the load-bearing
pointers; XR3 is repurposed (Moore used it freely, we cannot --
delta 2.2 in the decisions doc). FORTH primitives are short
(typically 3-10 instructions). Codegen for user-defined words
is just "emit a list of execution-address words", which the slot-
based no-allocator codegen from the 1130 bring-up can handle.

## 3. Register conventions Moore actually used

The README states "X1 as a pointer to a 28 word workspace, X2 as
the data stack pointer, and X3 had various minor uses." Reading
the kernel and Claunch's notes:

| Reg | Use                                                    |
| --- | ------------------------------------------------------ |
| ACC | scratch; primitive-local result; argument to deposit   |
| EXT | high half of multiply-pair; rotated via XCH for swap   |
| XR1 | workspace pointer (W). Workspace cells named -1 (A=current char), -2 (accept entry-point address), -3 (C=character pointer), -5 (D=deposit pointer), -6 (W1=word being parsed), 2 (W=accumulating word), etc. |
| XR2 | data stack pointer (DSP). Grows up; `MS` (modify stack) increments XR2 by a displacement. `LS`/`SS` are LD/STO via XR2; `LSI`/`SSI` are indirect-via-XR2. |
| XR3 | code-generation pointer; loop counter; LX-with-mask helper. Set transiently via `BASE`/`BASA`. |
| IAR | program counter; written by BSI; read into accumulator nowhere directly (kernel uses BSI to capture return addresses) |

**Our delta on XR3:** the LIBF transfer-vector reservation
(decisions doc Sec 2.2) means we can't use XR3 for code-gen
pointer or loop counter freely. The translation will rewrite
each XR3 use as a memory cell operation. Per-primitive overhead
is small (2 instructions added to a primitive that touches
XR3); the translation log records each rewrite.

## 4. Branching idioms (and the BSC-mask call-site count)

> **Status (2026-05-12, saga step 3 closed):** the BSC-mask gap
> described in this section is **resolved**. `sw-ibm1130-isa`'s
> `Instruction::Long` now carries a 7-bit `mask` field;
> `sw-ibm1130-asm` populates it for `BSC L target, mask` /
> `BSI L target, mask` syntax; `sw-ibm1130-emulator` reads it with
> Moore's authoritative bit assignments (E=0x04, P=0x08, N=0x10,
> Z=0x20, C=0x40). The demos (conditions, loops, strings, hello)
> have been rewritten to use direct masked branches instead of
> the skip-and-jump workaround. The notes below are kept for
> historical context describing what was wrong before the fix.


The asm uses standard 1130 mnemonics for conditional branches:

| Mnemonic | Meaning                          | Encodes as |
| -------- | -------------------------------- | ---------- |
| `B`      | Unconditional branch (short)     | BSC short, mask = 0 |
| `BL`     | Unconditional branch long        | BSC long,  mask = 0 |
| `BZ`     | Branch if zero                   | BSC long,  mask includes Z |
| `BNZ`    | Branch if non-zero               | BSC long,  mask = inverse of Z |
| `BP`     | Branch if positive               | BSC long,  mask includes + |
| `BN`     | Branch if negative               | BSC long,  mask includes - |
| `BNP`    | Branch if not positive           | BSC long,  mask = inverse of + |
| `BOD`    | Branch on odd                    | BSC long,  mask includes E (or its inverse?) |

**The BSC-mask call-site count is high.** A grep of
`FORTH68asm.txt` for `BZ`, `BNZ`, `BP`, `BN`, `BNP`, `BOD` finds
many sites (rough count: 30+); the kernel is dense with
conditional branches.

**Plus** the FORTH-source listing (`FORTH68lst.txt`) contains a
high-level idiom for conditional CALLS that mixes the BSC-mask
field with `BSI` (Branch and Store IAR):

```
:CONDITION 0 LS FF MS BSI OR L LOC NEXT DEPOSIT RETURN;
   ...generates: 7201, C200, 72FF, 44nn, NEXT, 4C80, return
```

The `44nn` is `BSI long + mask=nn`. So Moore is also putting
the mask in the reserved bits of `BSI` long-form. Same field,
different opcode (`BSC` long = 0x4800 base; `BSI` long = 0x4000
base). Both rely on the field our ISA spec dropped.

This justifies saga step 3 (BSC-mask-fix) unambiguously: closing
the gap is the difference between running Moore's kernel and
not. The expansion-into-skip-and-jump idiom would multiply
kernel size 2-3x (every `BZ` becomes `BSC short + B long`) and
break the BSI-long-with-mask pattern entirely (no equivalent
expansion exists for "conditional call").

**Mask-bit values observed in the FORTH listing:** the
`:CONDITION` family explicitly uses these constants:

- `:NONZERO 18 CONDITION` -- mask 0x18 -> NZ test
- `:FALSE 20 CONDITION`   -- mask 0x20 -> FALSE / Equal  
- `:EVEN 04 CONDITION`    -- mask 0x04 -> Even
- `:POSITIVE 8`           -- mask 0x08 -> Positive
- `:NEGATIVE 10`          -- mask 0x10 -> Negative
- `:EQUAL 20`             -- mask 0x20 -> Equal (same as FALSE)
- `:NOT 18`               -- mask 0x18 -> Not (negate)

Saga step 3 (BSC-mask-fix) uses these exact bit assignments to
verify the implementation. They differ from the
emulator's current convention (which `sw-ibm1130-emulator`'s
`exec.rs` documents as `Z=0x01, -=0x02, +=0x04, E=0x08, C=0x10,
O=0x20`). The differences are real and must be reconciled --
Moore's encoding is the authoritative one for the historical
ISA, since his code dictates which bits mean what when running
on a real 1130.

**Action item for saga step 3:** when re-running `gen-isa
scaffold --spec`, reconcile the bit assignments. The fix is the
emulator's convention, not Moore's; he's right.

## 5. Character encodings (more nuanced than "just EBCDIC")

The README mentions that Moore "created his own character coding
to make the use of hexadecimal numbers easier and to facilitate
alphabetical dictionary searches." Reading the kernel and the
listing reveals THREE coexisting encodings:

1. **FORTH internal code (Moore's custom).** Hex digits 0-9 ->
   0x00-0x09. A-F -> 0x0A-0x0F. G-Z -> 0x10-0x22. Plus space
   and a few specials. **6-bit-ish, packed two per 16-bit word.**
   This is what dictionary entries use. Hex literal conversion
   is trivial: take the FORTH code value as the hex digit value.

2. **EBCDIC.** What the IBM 1130 card reader / disk produces.
   The `CONVERT` primitive translates EBCDIC bytes to FORTH
   internal code via a 64-word lookup table.

3. **PTTC/8** (Selectric-printer code). What the 1054/1131
   console expects on output. The `CSCP` table (64 entries, 8
   bits left-justified per word) maps FORTH internal code to
   PTTC/8. `CSKB` table maps Hollerith (card column patterns)
   to FORTH internal code.

So Moore's source contains TWO lookup tables (CSCP, CSKB)
hand-encoded as `DC` initialisers. The translation step must
preserve their byte values exactly (the lookup table's
correctness is its byte content; nothing about it is
"renderable as ASCII").

**Implication for our ASCII delta (decisions Sec 2.1):** we
keep Moore's three-encoding pipeline intact. Source-level
literals in the FORTH listing get EBCDIC-bytes translated into
ASCII bytes for our toolchain (since we type/read ASCII). The
two lookup tables stay unchanged. The PTTC/8 console-output
table feeds our emulator's XIO console -- which currently
treats raw bytes as ASCII for display, so PTTC/8 output will
look like garbage in the captured console buffer until we add
PTTC/8-to-ASCII translation on the consumer side.

That's a follow-up TODO for the saga's REPL step (or earlier if
we want clean console output for demos): a small "PTTC/8 ->
ASCII" hook in the runner that decodes the captured
`console_output` for human reading. Worth pinning down before
saga step 9 (end-to-end demo).

## 6. Definition syntax (`. ,` instead of `: ;`)

Moore's source uses `.` for "start a definition" and `,` for
"end a definition". The 1968-FORTH README says: "New Forth
words are defined with a statement beginning with a dot and
ending with a comma. This was later changed to the more
familiar colon and semicolon notation."

Carl's notes confirm:

```
"In the actual file written by Chuck Moore used:
   .  as a synonym for :
   ,  as a synonym for ;
   OPERATION as a synonym for cent-sign or CODE"
```

The kernel includes both forms (the assembler aliases). The
translation preserves Moore's choice; the FORTH listing remains
`.WORD body ,` per the original.

The saga's parser/compiler steps (saga steps 7-8) accept both
`.`/`,` and `:`/`;` -- Moore's source uses the former, modern
FORTH uses the latter; both are valid input.

## 7. The "code generation" primitive set

A surprising finding: a substantial chunk of the bootstrap FORTH
source is dedicated to **building 1130 instructions on the fly**
from FORTH primitives. Each 1130 opcode becomes a constant-
pushing FORTH word; modifiers (long-form, indirect, index-
register tag, address) are OR'd in via stack ops; the result is
a 1- or 2-word instruction sequence deposited into the variable
dictionary.

```
.LD C000,                    \\ load instruction template
.ST D000,                    \\ store instruction template
.X1 100 OR,                  \\ XR1 tag (note: 0x0100, IBM-asm tag bits)
.LONG L DEPOSIT,             \\ make long-form, deposit
.STORE ST LONG,              \\ store-long: deposits D400 + addr
.LOAD LD LONG,               \\ load-long:  deposits C400 + addr
```

This is Moore's "compile-time codegen" -- effectively a tiny
1130-asm-as-FORTH-DSL that the kernel uses to generate
threaded-code primitives at runtime. Our saga's translation
preserves this verbatim (saga step 5); the generated 1130
instructions are exactly what runs on the emulator.

**Implication for `sw-ibm1130-codegen`:** none. This codegen is
internal to the FORTH system and runs on the 1130 itself; our
Rust-side codegen (the one that lowers TIR to 1130) is separate
and not invoked by FORTH. The two systems coexist; the
FORTH-side compile-time codegen produces user-defined-word
bodies, the Rust-side codegen produces the kernel from
high-level user code that doesn't exist yet.

## 8. Asm directives Moore uses (data for saga step 4)

Reading the kernel surfaces these directives:

| Directive | Meaning | In our scope (decisions Sec 2.6)? |
| --------- | ------- | --------------------------------- |
| `// JOB` / `// ASM` | 1130 monitor job control | Out (treat as comments / ignore) |
| `*LIST ALL` | listing-output flag | Out (no-op) |
| `ABS` | absolute (non-relocatable) program | Add as no-op (or note in TRANSLATION-LOG) |
| `ORG /XXX` | origin (hex) | In; already supported (decimal); add hex `/XXX` literal form |
| `DC` | data constant | In; already supported. Hex `/XXX` literals needed. |
| `BSS` | block storage symbol | In; saga step 4 |
| (none of `BES`, `DEC`, `DSA`, `EBC`, `LIBF`, `CALL`, `ENT`, `EXT`, `ISS`, `ILS` observed in the kernel I scanned) | -- | -- |

**Plus** the conditional-branch mnemonics `B`, `BL`, `BZ`, `BNZ`,
`BP`, `BN`, `BNP`, `BOD` (Sec 4 above). Either:

- Add them to `sw-ibm1130-asm` as macro-style aliases for `BSC`
  with specific mask values, OR
- Translate them at translation time to explicit `BSC L addr,
  mask` form.

Recommendation for saga step 4: **add the mnemonics**. They're
small (one line in `mnemonic_to_opcode` plus a mask-from-mnemonic
helper), they make Moore's source readable, and they're
historically authentic. Translation-step rewrites would lose
information.

**Plus** the `SLT` (Shift Left Together) and `SRT` (Shift Right
Together) sub-ops of the `SLA`/`SRA` family. These shift the
ACC+EXT pair (32-bit) rather than ACC alone. They're encoded by
displacement bits on the SLA/SRA opcode. Saga step 4 needs to
either add them as separate mnemonics or document the
displacement-bit convention.

**Plus** the hex-literal prefix `/XXX`. Currently our asm parses
`0xXXX` and decimal; Moore uses `/XXX`. Saga step 4 adds it.

**Plus** comments. Moore's listing doesn't appear to use a
distinct comment prefix in the operand area -- text after the
operand on the same line is just the listing's positional
comment column. Saga step 4 either:

- Strips trailing operand-comments at translation time
  (mechanical), or
- Adds an opt-in "everything past column N is a comment" mode
  (heavy).

Recommendation: strip at translation time. `;` comments in our
syntax are a clean replacement; the original column-positional
comments are translated to `;`-prefixed ones one-for-one.

## 9. What's NOT in Moore's kernel (good news)

The deferred items in our decisions doc Sec 2.6 -- LIBF/CALL,
ENT/EXT, ISS/ILS, ABS/RLD -- ARE NOT used by the kernel as far
as I can see in the assembly source skim. The kernel is closed-
system: no library subroutine calls, no relocation, no
interrupt-service registration via `ISS`. So all of those stay
deferred; saga step 4 doesn't have to add them.

Block I/O via 8C00/8D00/8E00 XIO commands IS present in the
FORTH listing (the SECTOR/WRITE words). Per decisions Sec 2.7,
those primitives translate to no-op stubs with a deferred-saga
pointer; the FORTH listing's I/O-using words become non-runnable
until the future I/O saga lands.

## 10. Summary: what saga steps 3-5 must deliver

Triangulating the above:

- **Saga step 3 (bsc-mask-fix):** absolutely required. Moore's
  kernel has 30+ BSC/BSI long-form mask call sites. The skip-and-
  jump workaround would bloat the kernel and doesn't cover BSI.
  The mask field must be exposed in the ISA spec, `Instruction::
  Long`, the asm encoder, and the emulator's `exec_bsc` /
  `exec_bsi`. Bit assignments per Sec 4 above.

- **Saga step 4 (asm-extensions):** required additions are:
  - `BSS` directive
  - `/XXX` hex literal prefix
  - Conditional-branch mnemonic aliases: `B` / `BL` / `BZ` /
    `BNZ` / `BP` / `BN` / `BNP` / `BOD`
  - `SLT` / `SRT` sub-op mnemonics
  - Literal expressions in operands (`SYM+1`, `*-2`)
  - `END LABEL` operand form
  - `ABS` directive accepted as no-op
  - `*LIST ALL` and `// JOB` / `// ASM` accepted as comments
  
  Items still NOT needed (per decisions Sec 2.6): `LIBF`,
  `CALL` (pseudo-op), `ENT`, `EXT`, `ISS`, `ILS`, `ABS` /
  `RLD` relocation, `DEC` / `HEX` typed-constant directives.

- **Saga step 5 (translation):** the kernel translation produces
  `historical/forth68/kernel.asm` (from `FORTH68asm.txt`) and
  `historical/forth68/listing.fth` (from `FORTH68lst.txt`). XR3
  uses get rewritten to memory-cell operations (delta 2.2). Each
  rewrite is logged in `TRANSLATION-LOG.md`. The two character-
  encoding tables (CSCP, CSKB) get carried over byte-for-byte;
  EBCDIC string literals in the listing become numeric DC
  sequences carrying the original byte values.

## 11. References

- `reference/1968-FORTH/FORTH-68_notes.txt` -- Carl Claunch's
  primitive-by-primitive analysis (980 lines).
- `reference/1968-FORTH/FORTH68asm.txt` -- Moore's kernel.
- `reference/1968-FORTH/FORTH68lst.txt` -- the FORTH-source
  overlay (the "deck of cards").
- `reference/1968-FORTH/notes on FORTX assem code.pdf` -- Carl's
  PDF analysis (not read in detail for this survey; would
  triangulate against during the actual translation).
- `historical/forth68/NOTICE` -- redistribution provenance.
- [`gen-isa/docs/forth-on-1130-decisions.md`](https://github.com/sw-vibe-coding/gen-isa/blob/main/docs/forth-on-1130-decisions.md)
  -- saga's locked deltas; this survey is the data behind them.
- [`gen-isa/docs/postmortem-1130-bringup.md`](https://github.com/sw-vibe-coding/gen-isa/blob/main/docs/postmortem-1130-bringup.md)
  Sec 4 -- BSC-mask gap context.
