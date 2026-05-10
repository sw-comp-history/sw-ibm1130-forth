//! `sw-ibm1130-forth`: FORTH frontend targeting the IBM 1130.
//!
//! Status: skeleton. Implementation lands in the `forth-on-1130`
//! agentrail saga (see `gen-isa/docs/forth-on-1130-plan.md`).
//!
//! Historical note: the FIRST FORTH was implemented on an IBM 1130
//! by Charles H. Moore in 1968 at Mohasco Industries. This crate
//! recreates the language on its native machine, leveraging:
//!
//! - Moore's original 1968 source (28 primitives, self-extending
//!   dictionary), recovered and posted with permission at
//!   `https://github.com/monsonite/1968-FORTH`. Cloned locally
//!   under `reference/` (gitignored; see `docs/references.md`).
//! - The user's existing COR24 DTC FORTH at
//!   `~/github/sw-embed/sw-cor24-forth` -- structural reference
//!   for the modern Rust-side parts of this crate.
