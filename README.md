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

## Reference materials

This repo does **not** redistribute upstream reference materials.
See [`docs/references.md`](docs/references.md) for sources and
clone instructions. The `reference/` directory at the repo root
is gitignored; you populate it yourself.

## Sibling layout

Cross-crate deps assume sibling clones at
`~/github/sw-comp-history/sw-ibm1130-*` and
`~/github/sw-langtools/sw-*`.

## License

MIT. See [LICENSE](LICENSE).
