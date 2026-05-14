//! Smoke test: `historical/forth68/kernel.asm` assembles cleanly
//! under `sw-ibm1130-asm`. This is the saga step 5 acceptance
//! check; runtime behaviour comes in step 6.

#[test]
fn forth68_kernel_assembles() {
    let src = include_str!("../historical/forth68/kernel.asm");
    let out = sw_ibm1130_asm::assemble(src).unwrap_or_else(|e| {
        panic!("kernel.asm failed to assemble: {e}");
    });
    // Sanity-check sizes. The exact instruction count may shift
    // as the translation log is refined; just assert that a
    // non-trivial body was produced.
    assert!(
        out.instructions.len() > 100,
        "expected >100 instructions; got {}",
        out.instructions.len()
    );
    // A handful of load-bearing symbols must be defined.
    for sym in &[
        "START",
        "NEXT",
        "FETCH",
        "DEPOS",
        "ENTER",
        "ENTRY",
        "DO",
        "FORTH_RTN",
        "BCD",
    ] {
        assert!(
            out.symbols.lookup(sym).is_some(),
            "kernel.asm should define `{sym}`"
        );
    }
}
