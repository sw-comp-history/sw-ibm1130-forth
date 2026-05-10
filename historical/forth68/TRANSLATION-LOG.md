# Translation log: 1968 FORTH -> `sw-ibm1130-asm` syntax

> Status: **placeholder**. Populated during the `forth-on-1130`
> agentrail saga step that performs the translation. Until then,
> this file documents the *intended* policy and template. Do not
> remove this file even when empty -- the policy here is the
> contract for the eventual translation.

## Upstream pin

When the translation lands, record:

- Upstream repo: `https://github.com/monsonite/1968-FORTH`
- Upstream commit hash: `(filled in at translation time)`
- Date of translation: `(filled in at translation time)`
- Translator: `(filled in at translation time)`

## Files translated

| Upstream file                         | Translated to                | Status   |
| ------------------------------------- | ---------------------------- | -------- |
| `FORTH68asm.txt` (645 lines, 1130 asm) | `kernel.asm`                | pending  |
| `FORTH68lst.txt` (235 lines, FORTH)    | `listing.fth`               | pending  |

Other upstream files (`FORTH-68_notes.txt`, `notes on FORTX assem
code.pdf`, `README.md`) are **not** translated. They are
documentation-only; the references doc points at the upstream
copies in `reference/1968-FORTH/` (locally cloned, gitignored).

## Transformation policy

### What changes (and is logged below)

- **Column layout.** Moore's source is fixed-column (label cols
  1-5, opcode cols 7-9, operand cols 11-, comment after col 30).
  Our `sw-ibm1130-asm` is free-form; the translation retargets
  layout but preserves text content and order.
- **Label-suffix `:`.** Our parser requires colon-suffixed
  labels. Each Moore label `FOO` becomes `FOO:` at its definition
  site; references stay bare.
- **Directive renames.** Where Moore uses historical 1130-asm
  directives we have not yet implemented, the translation either
  uses our equivalent (e.g. `BSS` -> our `BSS` once added in
  saga step 4) or substitutes a sequence of our existing
  directives. Each substitution is logged below.
- **EBCDIC string literals.** Moore's source uses EBCDIC-byte DC
  initialisers; until our `DC.STR` directive lands (separate
  saga, see `gen-isa/docs/character-encoding-plan.md`), the
  translation expands each EBCDIC literal into a sequence of
  numeric `DC` initialisers carrying the original byte values.
  Logged below per literal.
- **BSC mask encoding.** Moore's source uses BSC long form with
  condition masks intensively. Until the saga's BSC-mask-fix
  step (`gen-isa/docs/forth-on-1130-plan.md` Sec 10.5) updates
  our ISA spec to expose the mask bits, the translation either
  uses the skip-and-jump idiom or the extended `BSC L target,
  mask` syntax once available. Logged below per BSC site.
- **Comment style.** `* ...` Moore comments become `; ...` ours.
  Mechanical sed-style.

### What does NOT change

- **Algorithm.** Identifier names, instruction order, primitive
  semantics, dictionary structure, threading model are preserved
  exactly.
- **Number of primitives.** The translated kernel still
  implements Moore's 28 primitives; no additions, no deletions.
- **Register allocation.** Moore's XR1=W, XR2=DSP scheme is
  preserved. The one place we differ from Moore -- XR3 -- is
  documented in `gen-isa/docs/forth-on-1130-plan.md` Sec 4 as a
  conscious deviation driven by our ABI's reservation of XR3 as
  the LIBF transfer-vector base.

## Per-line transformation log

When the translation is performed, this section will list every
non-mechanical transformation by upstream-line-range, with the
before-text, the after-text, and the rationale. Mechanical
transformations (column shift, comment-character swap, label
colon-suffix) are NOT logged per occurrence -- they are described
once in "Transformation policy" above and applied uniformly.

```
(no entries yet -- pending translation step)
```
