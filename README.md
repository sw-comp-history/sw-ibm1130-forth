# sw-ibm1130-forth

FORTH frontend targeting the IBM 1130.

## Why

Charles H. Moore implemented the **first FORTH** on an IBM 1130 in
1968 at Mohasco Industries. The 1130's 5-character filename limit
turned the working title "FOURTH-generation" into the lowercase
"FORTH" we know today. This crate recreates the language on its
native machine, alongside the rest of the
`sw-comp-history/sw-ibm1130-*` toolchain.

## Status

`0.1.0` skeleton. Implementation lands in the `forth-on-1130`
agentrail saga; see
[`gen-isa/docs/forth-on-1130-plan.md`](https://github.com/sw-vibe-coding/gen-isa/blob/main/docs/forth-on-1130-plan.md).

Sibling crates already shipped:

- [`sw-ibm1130-isa`](https://github.com/sw-comp-history/sw-ibm1130-isa)
- [`sw-ibm1130-target`](https://github.com/sw-comp-history/sw-ibm1130-target)
- [`sw-ibm1130-codegen`](https://github.com/sw-comp-history/sw-ibm1130-codegen)
- [`sw-ibm1130-asm`](https://github.com/sw-comp-history/sw-ibm1130-asm)
- [`sw-ibm1130-emulator`](https://github.com/sw-comp-history/sw-ibm1130-emulator)

## How upstream content is handled

This crate's whole point is to demonstrate a real, historical
artifact (Moore's 1968 FORTH) on a faithful 1130 toolchain. We
have to be honest about whose code we are shipping and under
what terms. Two tiers, both in the repo root:

### `reference/` -- local working copies (gitignored)

A scratch directory each contributor populates locally. Holds
upstream repos we **read** during development but do not
**redistribute**:

- `monsonite/1968-FORTH` (the upstream copy of Moore's source)
- `sw-comp-history/ibm-1130-rs` (MIT, optional cross-check)
- `sw-embed/sw-cor24-forth` (MIT, structural reference)

These are not part of the repo. `cargo build` does not need
them. They exist for humans to read and cross-check while
working on this crate. Clone instructions are in
[`docs/references.md`](docs/references.md).

### `historical/` -- redistributed artifacts (tracked)

Where shipping the artifact in-repo is the point of the
exercise, the artifact lives here -- tracked, attributed, and
auditable. Each subdirectory carries:

- a `NOTICE` file naming the original author, the upstream copy
  we translated from, the permission we are relying on, and the
  year of the original work;
- a `TRANSLATION-LOG.md` documenting every transformation made
  to fit the artifact to our toolchain (so a reader can compare
  our copy to the upstream and see exactly what changed);
- a `README.md` explaining what the directory contains and why
  redistribution was the right call for this artifact.

The first entry is **`historical/forth68/`**, holding a
translation of Charles H. Moore's 1968 FORTH for the IBM 1130.
Moore granted public-posting permission in May 2020 (see
[`historical/forth68/NOTICE`](historical/forth68/NOTICE)); our
redistribution operates under that permission with attribution
to Moore and to the upstream copy at
[`monsonite/1968-FORTH`](https://github.com/monsonite/1968-FORTH).
The translation preserves Moore's algorithm, primitive set, and
identifier choices verbatim; only syntactic retargeting (column
layout, directive names, EBCDIC literal handling, BSC mask
encoding) is performed, and every transformation is logged.

If Moore or his estate ever objects to this redistribution, the
directory will be retired and we will revert to a reference-only
model.

### Why both tiers, why not just one

If we only had `reference/`, anyone running the demo would have
to clone `monsonite/1968-FORTH` separately first, and our build
would either need network I/O (which we refuse) or would simply
fail offline. The headline demo of this crate -- "Moore's 1968
FORTH running on our toolchain" -- has to work from a fresh
`git clone`, and that requires shipping the kernel.

If we only had `historical/`, we would lose the discipline of
reading the upstream copy when sanity-checking the translation.
Keeping the upstream cloneable into `reference/` (gitignored)
preserves the audit trail without making us responsible for the
upstream's full file set.

For the full policy, including `reference/` clone instructions,
the per-source license table, and the license-hygiene rules
governing translations, see
[`docs/references.md`](docs/references.md).

## Sibling layout

Cross-crate deps assume sibling clones at
`~/github/sw-comp-history/sw-ibm1130-*` and
`~/github/sw-langtools/sw-*`.

## License

MIT. See [LICENSE](LICENSE).
