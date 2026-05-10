# `historical/forth68/` -- Charles H. Moore's 1968 FORTH (translated)

This directory will hold a translation of Charles H. Moore's
**original 1968 FORTH for the IBM 1130** into our
`sw-ibm1130-asm` syntax, runnable end-to-end on our
`sw-ibm1130-emulator`. It is the historical-demonstration target
of this crate.

> Status: **structure only**. The actual translation lands in
> the `forth-on-1130` agentrail saga (see
> [`gen-isa/docs/forth-on-1130-plan.md`](https://github.com/sw-vibe-coding/gen-isa/blob/main/docs/forth-on-1130-plan.md)).
> When that step ships, this directory will contain the translated
> kernel, a translation log, and a reproducer.

## What will live here (when populated)

| File                      | Contents                                                      |
| ------------------------- | ------------------------------------------------------------- |
| `NOTICE`                  | Attribution and the permission we are relying on (Moore 2020).|
| `kernel.asm`              | Translation of `FORTH68asm.txt` into `sw-ibm1130-asm` syntax. |
| `listing.fth`             | Translation of `FORTH68lst.txt` (FORTH-level disk dump).      |
| `TRANSLATION-LOG.md`      | Every transformation applied during translation.              |
| `tests/run.rs` (above)    | Integration test that assembles + runs + asserts on output.   |

## Why translate (rather than `include_str!` from `reference/`)

`reference/` is gitignored and exists only on a contributor's
local disk. Anyone running `cargo run --example moore-1968-forth`
needs the kernel **shipped with this repo**. A one-time offline
translation gives us:

- A version pinned to a known revision of the upstream source --
  if monsonite/1968-FORTH changes, our demo doesn't silently
  shift underneath us.
- A version in our own assembler's syntax -- no dual-parser
  burden on `sw-ibm1130-asm`.
- Documented transformations so the relationship to the upstream
  is auditable, not hidden.

## Why ship Moore's work in our repo at all

Moore granted **public-posting permission** in May 2020,
publicising the source via `monsonite/1968-FORTH`. We rely on
that permission for our redistribution. We do not modify Moore's
algorithm or identifier choices; transformations are limited to
syntactic retargeting (column layout, directive names, EBCDIC
literal handling, BSC mask encoding) so the source compiles under
our toolchain. See `TRANSLATION-LOG.md` (when populated) for the
exact list.

If Moore (or his estate) ever objects to this redistribution, we
will retire this directory and revert to a reference-only model.

## See also

- [`docs/references.md`](../../docs/references.md) -- pointers to
  the upstream sources and the broader license-hygiene policy.
- [`historical/README.md`](../README.md) -- repo-wide
  redistribution policy.
- `monsonite/1968-FORTH` (https://github.com/monsonite/1968-FORTH)
  -- the upstream copy we translate from.
