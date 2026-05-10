# Reference materials for `sw-ibm1130-forth`

Two-tier policy:

- **`reference/`** (gitignored). Local-only working copies of
  upstream content we **read** but do not **redistribute**. Used
  for code-reuse references where redistribution adds nothing
  (e.g. MIT-licensed projects we don't need to vendor).
  Contributors clone the references themselves.
- **`historical/`** (tracked). Translations / adaptations of
  historical content that we **do** redistribute, with full
  attribution and a per-subdirectory `NOTICE` file. Used where
  shipping the artifact in this repo is the point of the
  exercise (e.g. demonstrating Moore's 1968 FORTH literally
  running on our toolchain).

The 1968 FORTH source falls under both: the upstream copy at
`monsonite/1968-FORTH` lives in `reference/1968-FORTH/`
(gitignored, optional, for direct reading and cross-check), and
a translated-into-our-asm-syntax copy lives in
`historical/forth68/` (tracked, redistributed under Moore's
public-posting permission with attribution to Moore and
monsonite). See `historical/forth68/NOTICE` for the redistribution
provenance.

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

### 1. The original 1968 FORTH (load-bearing; both tiers)

- **Upstream repo:** https://github.com/monsonite/1968-FORTH
- **Permission:** Charles H. Moore granted public-posting
  permission in May 2020. The upstream copy operates under that
  permission; our `historical/forth68/` redistribution operates
  under the same permission with attribution to Moore and to
  monsonite. See `historical/forth68/NOTICE`.
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
- **Use in this crate (two tiers):**
  - `reference/1968-FORTH/` (gitignored, optional). Direct
    upstream copy for cross-checking. Clone with
    `git clone https://github.com/monsonite/1968-FORTH reference/1968-FORTH`.
  - `historical/forth68/` (tracked, redistributed). Translation
    into our `sw-ibm1130-asm` syntax so anyone running our demos
    has the kernel without needing to populate `reference/`.
    Translation lands in the `forth-on-1130` saga; until then
    the directory has only `README.md`, `NOTICE`, and a
    `TRANSLATION-LOG.md` placeholder.
- **Key constraint:** algorithm preserved; only syntactic
  retargeting allowed in the translation. Every transformation
  is logged in `historical/forth68/TRANSLATION-LOG.md`.

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
