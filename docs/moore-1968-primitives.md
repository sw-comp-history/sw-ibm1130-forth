# Side-by-Side Primitive Table: Moore's 1968 FORTH vs. cor24-forth

> Saga step 2 of `forth-on-1130`. Mechanical reference for the
> translation step; companion to the prose survey at
> [`moore-1968-survey.md`](moore-1968-survey.md).
>
> Sources for the Moore-1968 column are
> `reference/1968-FORTH/FORTH-68_notes.txt` (Carl Claunch's 2018
> analysis) and `reference/1968-FORTH/FORTH68asm.txt` (Moore's
> kernel). The cor24-forth column draws from the README at
> `~/github/sw-embed/sw-cor24-forth` and the kernel at
> `forth.s`; treat it as a structural reference, not a porting
> target.
>
> ASCII-only.

## Reading this table

- **Layer:** `K` = in the assembly kernel; `L` = defined in the
  FORTH-source listing.
- **Stack effect:** `( before -- after )`, oldest-on-stack-bottom.
- **cor24-forth equivalent:** "same name" if the modern word set
  has the same name with similar semantics; "(none)" if absent;
  "(see notes)" if substantially different.
- **Translation note:** anything saga step 5 needs to handle
  beyond the syntactic mechanics already documented in
  `historical/forth68/TRANSLATION-LOG.md`'s policy section.

## Section A: kernel primitives (in `FORTH68asm.txt`)

These are the primitives Moore wrote in 1130 assembly. The
translation in saga step 5 produces `historical/forth68/kernel.
asm` containing all of these.

| Moore's name | Layer | Stack effect | cor24-forth equivalent | Translation note |
| ------------ | ----- | ------------ | ---------------------- | ---------------- |
| `E`          | K     | `( -- a )`        | (none; cor24 uses HERE for next-free) | Pushes addr of next-free dictionary slot (variable area) |
| `E1`         | K     | `( -- a )`        | LATEST | Pushes addr of last-used dictionary entry |
| `IC`         | K     | `( -- a )`        | (none; cor24 uses dedicated compiler vars) | Pushes addr of current instruction-counter variable (variable-dict deposit pointer) |
| `LIT`        | K     | `( -- n )`        | LIT (modern FORTH) | Pushes the literal constant baked into the colon body |
| `OR`         | K     | `( a b -- a|b )`  | OR | Bitwise; uses XR2 stack |
| `LOC`        | K     | `( -- xt )`       | `'` (tick) | Read next name from input stream; push its execution address |
| `NEXT`       | K     | (inner loop)      | NEXT (inner interpreter; not user-callable) | Find next word, look up, execute. The threading inner loop. |
| `INC`        | K     | `( a -- v )`      | (closest: `+!` then `@`) | Bump variable at addr by 1; push the new value |
| `HEX`        | K     | `( -- )`          | HEX (modern: switches input base) -- but Moore uses it for variable allocation | Allocates space in variable dict for a hex variable. **Different semantics from modern HEX.** |
| `;`, `,`, `END` | K  | `( -- )`          | `;` | End of definition; switches back to execute mode. (Moore wrote `,`; we accept either.) |
| `:`, `.`     | K     | `( -- )`          | `:` | Start of definition. (Moore wrote `.`; we accept either.) |
| `OPERATION`, `cents-sign` | K | `( -- )` | `CODE` | Begin a machine-code primitive. (Moore wrote cent-sign; modern asm uses CODE.) |
| `ENTRY`      | K     | `( -- )`          | (closest: CREATE) | Make a fixed-dictionary entry from the next stream name |
| `INTEGER`    | K     | `( -- )`          | (closest: VARIABLE) | Allocate an integer variable; push-its-address on use |
| `CONVERT`    | K     | (string in -- )   | (none) | Translate EBCDIC bytes to Moore's FORTH internal code via the CSKB lookup |
| `DEPOSIT`    | K     | `( c -- )`        | (closest: `C,`) | Put char in work area; overridden by FORTH disk file |
| `FETCH`      | K     | `( -- c )`        | (closest: KEY) | Get next char from input buffer (disk / typewriter / user disk) |
| `FIND`       | K     | `( -- xt | 0 )`   | FIND | Look up an entry in the dictionary. **Not in bootup FORTH; defined in the kernel only.** |
| `RECURSE`    | K     | `( -- )`          | RECURSE | Push down return address and start exec |
| `FORT`       | K     | (REPL)            | QUIT | Start the basic FORTH loop (read-interpret-execute). |
| `PUT`        | K     | `( c -- )`        | EMIT (closest) | Put char from stack into print line |
| `PRINT`      | K     | `( -- )`          | (closest: TYPE) | Print the current print line |
| `ADDRESS`    | K     | `( -- a )`        | (helper, not user-facing) | Store address (e.g. of variable or code pointer); called by E, E1, IC |
| `SD`         | K     | `( n -- IC )`     | (none) | Replace TOS with the current code pointer (IC) |

That's 24 visible primitives. The kernel also contains low-level
helpers (`SAVE`, `ACCEP`, `SPECI`, `ALPHA`, etc.) used internally
by the parser/loader and not directly exposed; the README's "28
primitives" count includes some of these.

## Section B: code-generation primitives (in `FORTH68lst.txt`)

These are FORTH-defined "instruction-template builder" words
loaded from the disk file. They are NOT in the assembly kernel;
they are colon (`.WORD`) and code (`OPERATION`) definitions in
FORTH that produce 1130 machine-instruction templates on the
stack, OR them with modifiers, and DEPOSIT them into the
variable dictionary.

These are unique to Moore's 1968 system and have no analog in
cor24-forth (which generates code via a separate Rust assembler
pipeline, not via in-FORTH instruction templates).

| Moore's name | Stack effect | What it pushes / does |
| ------------ | ------------ | --------------------- |
| `LD`   | `( -- 0xC000 )`         | 1130 LD opcode template |
| `ST`   | `( -- 0xD000 )`         | 1130 STO opcode template |
| `ADD`  | `( -- 0x8000 )`         | A opcode template |
| `SUB`  | `( -- 0x9000 )`         | S opcode template |
| `MUL`  | `( -- 0xA000 )`         | M opcode template |
| `DIV`  | `( -- 0xA800 )`         | D opcode template |
| `LX`   | `( -- 0x6000 )`         | LDX opcode template |
| `SX`   | `( -- 0x6800 )`         | STX opcode template |
| `MX`   | `( -- 0x7000 )`         | MDX opcode template |
| `B`    | `( -- 0x7000 )`         | unconditional branch (= MDX with tag 0) |
| `BL`   | `( -- 0x4800 )`         | BSC long opcode template |
| `BSI`  | `( -- 0x4000 )`         | BSI opcode template |
| `XIO`  | `( -- 0x0800 )`         | XIO opcode template |
| `X1`   | `( n -- n|0x0100 )`     | OR with XR1 tag |
| `X2`   | `( n -- n|0x0200 )`     | OR with XR2 tag (wait: should be 0x0200 per 1130 tag bits; Moore's notes say 0x0200, listing says `200 OR`) |
| `X3`   | `( n -- n|0x0300 )`     | OR with XR3 tag |
| `L`    | `( n -- n|0x0400 )`     | OR with long-form bit |
| `I`    | `( n m -- )`            | OR m with 0x0480 (long+indirect), deposit, deposit n as address |
| `MDM`  | `( n m -- )`            | OR with 0x7400 (modify memory long), inst+addr deposit |
| `LONG` | `( n m -- )`            | Make instruction long, deposit + addr |
| `STORE`| `( n -- )`              | "STO long, addr" -> deposits 0xD400 + n |
| `LOAD` | `( n -- )`              | "LD long, addr" -> deposits 0xC400 + n |
| `CALL` | `( n -- )`              | "BSI long, addr" -> deposits 0x4400 + n |
| `ACC`  | `( n m -- )`            | Branch over next word; deposit n as inline constant; deposit m+0xFE for short-form access |
| `GDEP` | `( -- )`                | Bump IC; emit code that stores ACC at current location |
| `GOR`, `GAND`, `GWAIT` | (templates) | OR / AND / WAIT instruction templates |
| `REL`, `RELS`, `BASE`, `BASA` | (XR3-relative emit helpers) | Build long-form instruction using XR3; **delta 2.2 applies** -- translation rewrites the XR3 references |
| `TOD`, `TOM`, `TXD`, `TXM`, `TAD`, `ZF`, `LF` | (shift-instruction templates) | SLT / SRT / SLA / SRA variants per displacement bits |
| `FS`, `LS`, `SS`, `LSI`, `SSI`, `MS` | (XR2-stack helpers) | LD/STO via XR2 (stack pointer) and indirect-via-XR2 |
| `RETURN` | `( -- )`              | Branch Long Indirect = 0x4C80 -- the standard 1130 return |
| `DISP` | `( n -- low8 )`         | AND off top half of cell to extract 8-bit displacement |
| `LITS` | `( n -- n addr-deref )` | Like VALUE but inline (not callable) -- bumps stack and stores fetched value |
| `MSI`  | `( n1 n2 -- )`          | Compose stack-relative load + add + store sequence |

These are essentially Moore's "asm-as-FORTH-DSL" -- the kernel
uses them at runtime to produce the threaded-code bodies of new
colon definitions. **The translation preserves them all
verbatim** (with XR3 rewrites where applicable per delta 2.2).

## Section C: high-level FORTH primitives (in `FORTH68lst.txt`)

These are the standard arithmetic / stack / control words --
recognisable from any FORTH descendant.

| Moore's name | Stack effect | cor24-forth equivalent | Notes |
| ------------ | ------------ | ---------------------- | ----- |
| `CONSTANT`  | `( n -- )`             | CONSTANT          | Same intent: name a constant |
| `REVERT`    | `( -- )`               | (none; closest: FORGET) | Roll back the last dictionary entry |
| `TOP`       | `( -- )`               | (none) | Restore last-used pointer to next-free |
| `DUP`       | `( n -- n n )`         | DUP               | Same |
| `VALUE`     | `( a -- @a )`          | `@`               | Fetch through pointer |
| `DROP`      | `( n -- )`             | DROP              | Same |
| `RAISE`     | `( -- x )`             | (none; "make a hole") | Bump SP without storing -- intermediate result slot |
| `SWAP`      | `( a b -- b a )`       | SWAP              | Same |
| `+`         | `( a b -- a+b )`       | `+`               | Same |
| `AND`       | `( a b -- a&b )`       | AND               | Same |
| `-`         | `( a b -- b-a )`       | `-`               | Note Moore's order: subtrahend first. cor24 follows the same modern convention. |
| `MINUS`     | `( n -- -n )`          | NEGATE            | Same |
| `/`        | `( a b -- b/a )`       | `/`               | Same |
| `*`         | `( a b -- a*b )`       | `*`               | Same |
| `PUSH`      | `( n1 n2 -- )`         | (none) | Push n1 onto user-defined stack pointed to by n2 |
| `PULL`      | `( n -- @n-1 @n )`     | (none) | Pop from user-defined stack |
| `STACK`     | (compile-time helper)  | (none) | Inline DUP via two-instruction sequence |
| `EXECUTE`   | `( xt -- )`            | EXECUTE           | Same; runs the word at xt |
| `BACK`, `MARK`, `LOOP`, `START`, `STOP`, `IF`, `THEN`, `ELSE` | (control-flow words) | corresponding cor24 control-flow | Moore's naming is older; semantics align |
| `POSITIVE`, `NEGATIVE`, `EQUAL`, `NOT` | `( -- mask )` | (none) | Push the BSC-mask byte for the named condition. **Used to construct conditional-branch templates; depends on saga step 3 being complete.** |
| `NONZERO`, `FALSE`, `EVEN` | `( -- )`     | (none) | Generate a CONDITION+mask call sequence |
| `PROGRAM`   | `( -- )`               | (none) | Begin a program; emit "branch over next word, deposit 0" |
| `QUEUE`     | `( -- )`               | (none) | Idle-until-event primitive; uses 1130 WAIT instruction |
| `ENQUEUE`   | `( a -- )`             | (none) | Set up a queued event handler |
| `REACTIVATE`| `( -- )`               | (none) | Resume queued execution |
| `BNZ`       | `( -- 0x4820 )`        | (none) | First word of a BNZ long-form instruction |
| `BUFFER`    | `( a -- )`             | BUFFER (modern FORTH block I/O) | Manage disk buffer linkage. **Block I/O delta 2.7 applies** -- translation stubs as no-op. |
| `CSKB`, `CSCP` | (data table)        | (none) | Hollerith / PTTC code conversion tables. Translation preserves byte values. |
| `RIBBON`, `BLACK`, `RED` | `( -- )`     | (none) | Selectric printer ribbon control codes |
| `TYPE`      | `( a n -- )`           | TYPE              | Type n characters from address a (uses PTTC/8) |
| `MESSAGE`   | `( a n -- )`           | (none) | TYPE wrapped with ribbon switching |
| `RESTORE`, `CONTINUE`, `READY`, `CHA` | (interrupt handlers) | (none) | Console keyboard / interrupt handlers. **Block-I/O-adjacent**; deferred. |
| `ACCEPT`    | `( -- )`               | ACCEPT (modern)   | Console-input loop |
| `CONSOLE`   | `( -- )`               | (none) | Set up parser to read from console |
| `TYP`       | `( c -- )`             | EMIT (closest)    | Type one character to console |
| `QUERY`, `DONE`, `HOME`, `IN`, `CYLINDER`, `SECTOR`, `WRITE` | (disk I/O) | (none) | Disk-I/O word set. **Block-I/O delta 2.7 applies.** |
| `REP`, `FILL`, `BLANK` | (string-fill helpers) | (none) | Loop/stop-based fill with a test character |
| `LIZ`, `'`, `(` | (parser/comment helpers) | `(` | Process special chars; comments |
| `$`         | `( -- )`               | (none) | Type "OK" via REPLY |
| `FILE`, `LINE`, `L`, `RELATIVE`, `T`, `EXAMINE`, `EMPLACE` | (file system) | (none; cor24 has none) | File-and-line oriented FORTH source on disk. **Block-I/O-adjacent.** |
| `S`, `SV`, `MOVE`, `COMPARE`, `SEARCH`, `CREATE`, `ACTIVATE`, `WARN`, `DELETE` | (file management) | various | File-system layer. Deferred per block-I/O delta. |
| `SET`, `STRAIGHT` | (parser internals) | (none) | Source-line cursor management |
| `INTERPRET` | `( -- )`               | INTERPRET (modern) | Execute one source line; coordinate with file system |
| `RETRIEVE`, `FORGET`, `REMEMBER` | (dictionary management) | FORGET (modern) | Add or roll back named entries |

## Section D: directives Moore uses

Reading `FORTH68asm.txt` surfaces these IBM 1130-asm directives:

| Directive    | Used for | In `sw-ibm1130-asm`? |
| ------------ | -------- | -------------------- |
| `// JOB`     | 1130 monitor job-card boundary | **Out** (treat as comment / ignore at translation) |
| `// ASM`     | invoke the 1130 assembler | **Out** (translation drops) |
| `*LIST ALL`  | listing-output flag | **Out** (translation drops) |
| `ABS`        | absolute (non-relocatable) program | **Add as no-op** (saga step 4) |
| `ORG /XXX`   | origin in hex | **In** (already supported with decimal; saga step 4 adds `/XXX` hex literal) |
| `DC`         | data constant | **In** (already supported with decimal/`0xXXX`; saga step 4 adds `/XXX` hex literal) |
| `BSS`        | block-storage symbol; reserve N words | **Add** (saga step 4) |
| `END`        | end-of-source; optional entry-point label | **In** (saga step 4 adds the `END LABEL` operand form) |

Items the decisions doc Sec 2.6 listed as out-of-scope but
worth confirming: `BES`, `DEC`, `HEX`, `DSA`, `EBC`, `LIBF`,
`CALL` (pseudo-op), `ENT`, `EXT`, `ISS`, `ILS`, `ABS` /
`RLD` relocation -- **none observed in `FORTH68asm.txt`**.
Saga step 4 stays at the current scope.

## Section E: branch-condition mnemonics

These are 1130-asm convenience mnemonics for `BSC` long with
specific masks. Moore uses them throughout the kernel. Per
saga step 4 plan, we add them to `sw-ibm1130-asm`:

| Moore's mnemonic | Encodes as | Saga step 4 mask |
| ---------------- | ---------- | ---------------- |
| `B`              | BSC, mask = 0  | unconditional (always branch) |
| `BL`             | BSC L, mask = 0 | unconditional long |
| `BZ`             | BSC L, mask includes Z | branch on zero |
| `BNZ`            | BSC L, mask = NOT Z | branch on non-zero |
| `BP`             | BSC L, mask includes + | branch on positive |
| `BN`             | BSC L, mask includes - | branch on negative |
| `BNP`            | BSC L, mask = NOT + | branch on non-positive |
| `BOD`            | BSC L, mask = E (or NOT E) | branch on odd |
| `BNN`            | BSC L, mask = NOT - | branch on non-negative (observed in 1130 asm style; verify usage in Moore's source) |

The exact mask-bit assignments for Z, +, -, E come from the
FORTH listing's `:POSITIVE 8` / `:NEGATIVE 10` / `:EQUAL 20` /
`:EVEN 04` definitions. Saga step 3 uses these to fix the
emulator's bit assignments to match. This is THE
authoritative source.

## Section F: shift sub-op mnemonics

Moore's source uses the full shift family; our spec has only
SLA / SRA top-level. The sub-ops are encoded by displacement
bits on those opcodes per the IBM 1130 FC manual:

| Moore's mnemonic | Meaning | Saga step 4 |
| ---------------- | ------- | ----------- |
| `SLA n`          | Shift Left Accumulator by n | Already in (already a top-level mnemonic in our asm) |
| `SLT n`          | Shift Left Together (ACC+EXT) by n | Add (sub-op of SLA via disp bits) |
| `SLC n`          | Shift Left Circular (ACC) by n | Add (sub-op of SLA) |
| `SLCA n`         | Shift Left Circular A | Add (sub-op of SLA) |
| `SRA n`          | Shift Right Arithmetic by n | Already in |
| `SRT n`          | Shift Right Together by n | Add (sub-op of SRA) |

Moore's kernel uses `SRT 1` and `SLT 1` directly (in `FETCH`
and `DEPOS`). Saga step 4 must add at least these two; the
others depend on what the kernel actually uses.

## Cross-links

- [`moore-1968-survey.md`](moore-1968-survey.md) -- prose findings
  this table is the data behind.
- `historical/forth68/TRANSLATION-LOG.md` -- where the
  per-line translations get logged once saga step 5 runs.
- [`gen-isa/docs/forth-on-1130-decisions.md`](https://github.com/sw-vibe-coding/gen-isa/blob/main/docs/forth-on-1130-decisions.md)
  -- forced deltas this table refines.
- `reference/1968-FORTH/FORTH-68_notes.txt` -- Carl Claunch's
  primitive-by-primitive analysis (read alongside this table for
  the algorithm-level details).
