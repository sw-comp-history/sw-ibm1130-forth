# Reference materials for `sw-ibm1130-forth`

This repo does **not** redistribute upstream reference materials.
We link to the canonical sources here and use a local
`reference/` directory (gitignored at the repo root) for working
copies during development. Contributors clone the references
themselves; nothing in `reference/` is part of this repo.

This avoids licensing/attribution complications around carrying
other people's content in our git history.

## How to populate `reference/`

From the repo root:

```bash
git clone https://github.com/monsonite/1968-FORTH reference/1968-FORTH
git clone https://github.com/sw-comp-history/ibm-1130-rs reference/ibm-1130-rs
git clone https://github.com/sw-embed/sw-cor24-forth reference/sw-cor24-forth
```

(Or `cd ~/github/sw-comp-history/sw-ibm1130-forth/reference && git
clone ...` from anywhere.)

If you have these checked out elsewhere already, symlink instead of
re-cloning:

```bash
ln -s ~/github/sw-comp-history/ibm-1130-rs reference/ibm-1130-rs
ln -s ~/github/sw-embed/sw-cor24-forth reference/sw-cor24-forth
```

## Sources

### 1. The original 1968 FORTH (load-bearing)

- **Repo:** https://github.com/monsonite/1968-FORTH
- **License:** Charles H. Moore granted permission for public
  posting in May 2020. See the upstream repo for the canonical
  attribution; we treat it as read-only reference, not as code we
  can vendor and re-license.
- **Contents (per upstream README):**
  - `FORTH68asm.txt` -- 645-line 1130 assembly source for the
    kernel; 28 primitives + dictionary structure.
  - `FORTH68lst.txt` -- 235-line FORTH-level listing dumped from
    the 1130 disk; originally a deck of punched cards.
  - `FORTH-68_notes.txt` -- implementation notes.
  - `notes on FORTX assem code.pdf` -- Carl Claunch's analysis.
- **Provenance:** recovered from Bob Flanders' email circa 2011;
  attracted IBM 1130 restoration interest in March 2018; published
  with Moore's permission in May 2020.
- **Use in this crate:** structural reference for our kernel's
  primitives, register allocation (XR1=W, XR2=DSP per Moore's
  scheme; we differ on XR3 -- see `gen-isa/docs/forth-on-1130-plan.md`
  Sec 4 for why we keep XR3 as the LIBF base), and the FORTH-level
  bootstrap sequence. **Do not copy code verbatim into this repo.**

### 2. `ibm-1130-rs` (CPU and assembler reference)

- **Repo:** https://github.com/sw-comp-history/ibm-1130-rs
- **License:** MIT (per the upstream LICENSE file).
- **Use in this crate:** cross-check 1130 instruction semantics
  against a working educational emulator. Our `sw-ibm1130-emulator`
  has its own implementation; this is a sanity check.

### 3. `sw-cor24-forth` (DTC FORTH structural reference)

- **Repo:** https://github.com/sw-embed/sw-cor24-forth
- **License:** MIT (Mike Wright). User-controlled; reuse is OK in
  principle, but we still develop this crate clean-room against
  the 1130 architecture rather than porting line-for-line.
- **Use in this crate:** structural reference for the modern
  Rust-side parts (parser, compiler, REPL, threading model
  decisions). 2600+ line kernel + three layered crates
  (`forth-from-forth`, `forth-in-forth`, `forth-on-forthish`)
  demonstrate the bootstrap pattern.

## Background reading (no clone needed)

These are web-only references; we don't carry local copies.

- [Charles H. Moore -- Wikipedia](https://en.wikipedia.org/wiki/Charles_H._Moore)
- [Chuck Moore: The Invention of Forth (HOPL)](https://colorforth.github.io/HOPL.html)
- [Forth.com -- Forth programming language history](https://www.forth.com/resources/forth-programming-language/)
- [Retrocomputing forum: First Forth sources, 1968](https://retrocomputingforum.com/t/first-forth-sources-12-pages-1968-for-ibm-1130/1243)
- [ForthHub discussion #63: 1130 FORTH restoration](https://github.com/ForthHub/discussion/issues/63)
- [Rescue 1130 blog: 1130 FORTH restoration](http://rescue1130.blogspot.com/2018/03/historical-recreationrestoration-of.html)
- [bitsavers IBM 1130 manuals](http://bitsavers.org/pdf/ibm/1130/) --
  especially `C26-5929-4` Subroutine Library and `GA26-5881`
  Functional Characteristics for instruction-set reference.

## License hygiene

- Anything in `reference/` is **not** redistributed by this repo
  (gitignored; per-source clone instructions above).
- When the kernel here is hand-authored using these references as
  consultative material, attribute the inspiration in source
  comments (e.g. `; primitive set follows Moore's 1968 FORTH;
  see reference/1968-FORTH/FORTH68asm.txt`).
- Do not copy code verbatim from any of the references unless its
  license explicitly permits and the upstream attribution is
  preserved in this repo.
