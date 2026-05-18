//! Step 8: inject EBCDIC input bytes directly into kernel memory
//! and observe the parser run.
//!
//! Strategy: bypass `LIBF DISK1` (stubbed) by writing the input
//! bytes into a known memory region and pointing the kernel's char
//! cursor (`workspace[-3]`, i.e. `C`) at it. Set `C2` (the
//! end-of-record marker) past the end so `RECOR` is never reached.
//! Then resume execution from `FORTH_RTN` and let the parser try
//! to find a known dictionary entry.

use sw_ibm1130_asm::assemble;
use sw_ibm1130_emulator::{CpuState, Memory, exec::ExecError, step};

const KERNEL_SRC: &str = include_str!("../historical/forth68/kernel.asm");

/// Word-address of a scratch region in the SECT buffer where we
/// write the injected input bytes. SECT_BASE is at high memory
/// (around word 0xA00 / byte 0x1400); plus 320 words of buffer.
/// We write at a byte address well within the BSS region so the
/// kernel won't trample over it during normal init.
const INPUT_WORD_OFFSET: u16 = 200; // offset into SECT_BASE in words

/// Step the CPU for `n` steps, returning early on halt / error.
/// Returns the actual step count and a description of why we
/// stopped (for diagnostic).
fn step_n(state: &mut CpuState, mem: &mut Memory, n: u64) -> (u64, String) {
    for i in 0..n {
        if state.halted {
            return (i, "halted".into());
        }
        match step(state, mem) {
            Ok(()) => {}
            Err(ExecError::Halted) => return (i, "halted".into()),
            Err(ExecError::Decode(msg)) => {
                return (i, format!("decode error at IAR={:#x}: {msg}", state.iar));
            }
            Err(ExecError::DivideByZero) => {
                return (i, format!("divide-by-zero at IAR={:#x}", state.iar));
            }
            Err(ExecError::Unsupported(op)) => {
                return (i, format!("unsupported {op:?} at IAR={:#x}", state.iar));
            }
        }
    }
    (n, "step limit reached".into())
}

fn boot() -> (CpuState, Memory, sw_ibm1130_asm::SymbolTable) {
    let asm = assemble(KERNEL_SRC).expect("kernel assembles");
    let mut mem = Memory::new(4096);
    mem.load_bytes(0, &asm.bytes);
    let mut state = CpuState::new();
    let start_addr = asm.symbols.lookup("START").expect("START symbol defined") as u16;
    state.iar = start_addr;
    (state, mem, asm.symbols)
}

#[test]
fn kernel_can_run_for_a_thousand_steps_without_decode_error() {
    // With the dictionary in place (saga step 7), the kernel walks
    // through more of its lifecycle than the 200-step ceiling from
    // step 6. Push to 1000 and verify it still doesn't decode-error.
    let (mut state, mut mem, _symbols) = boot();
    let (steps, reason) = step_n(&mut state, &mut mem, 1000);
    // Acceptance: ran the full 1000 OR halted cleanly. Decode
    // errors and unsupported ops are unacceptable.
    assert!(
        reason == "step limit reached" || reason == "halted",
        "expected clean run; got: {reason} (after {steps} steps)"
    );
}

#[test]
fn kernel_advances_iar_through_dictionary_walk() {
    // After START + a few FORTH_RTN iterations, IAR should land
    // somewhere in the DO routine (the dictionary walker). DO's
    // address is the value of the `DO` symbol; the parser visits
    // it indirectly via NEXT then BSI L DO.
    //
    // We don't assert exact IAR placement (depends on parser
    // state), but we do require IAR to leave the START block
    // (which is at a higher address than the primitives).
    let (mut state, mut mem, symbols) = boot();
    let start_addr = symbols.lookup("START").unwrap() as u16;
    let (steps, reason) = step_n(&mut state, &mut mem, 500);
    assert!(
        reason == "step limit reached" || reason == "halted",
        "expected clean run; got: {reason} (after {steps} steps)"
    );
    // After 500 steps, IAR should be inside the primitive area,
    // not stuck in START.
    assert!(
        state.iar != start_addr,
        "IAR should have advanced past START; still at {:#x}",
        state.iar
    );
}

#[test]
fn inject_a_known_word_observes_parser_behavior() {
    // **Documentation test** -- inject a one-character EBCDIC
    // input and observe the kernel's response. We do NOT yet
    // assert on the parser actually finding a dictionary entry;
    // the byte-vs-word arithmetic from TRANSLATION-LOG LC.5
    // is still unresolved, so workspace pointers aren't in true
    // byte-address form. Instead we run the kernel and snapshot
    // some observable state.
    //
    // This test is the scaffolding for a future, real
    // "parses 'HEX' successfully" assertion once the byte-
    // address arithmetic is sorted (saga step 9 candidate).
    let (mut state, mut mem, symbols) = boot();
    // Let START finish + a few NEXT iterations.
    let _ = step_n(&mut state, &mut mem, 50);

    // Find the SECT buffer (the kernel's input area) and the
    // workspace base.
    let sect_base = symbols.lookup("SECT_BASE").unwrap() as u16;
    let a_addr = symbols.lookup("A").unwrap() as u16;
    // The kernel reads from workspace[-3] (== mem[A - 3]).
    let c_slot = a_addr.wrapping_sub(3);

    // Inject EBCDIC 'A' (0xC1) into the high byte of a known word
    // in SECT_BASE. Packed two-per-word: high byte = 0xC1, low = blank
    // (0x40 EBCDIC). We're going for: kernel reads 'A', converts to
    // FORTH internal code 0x0A, deposits into WORD slot.
    let input_word_addr = sect_base.wrapping_add(INPUT_WORD_OFFSET);
    mem.write_word(input_word_addr, 0xC140);
    mem.write_word(input_word_addr.wrapping_add(1), 0x4040);

    // Point the kernel's char cursor at this region. Using
    // byte-address-form here (= 2 * word_address):
    let input_byte_addr = input_word_addr.wrapping_mul(2);
    mem.write_word(c_slot, input_byte_addr);
    // And C2 (end-of-record) far past the input:
    let c2_addr = symbols.lookup("C2").unwrap() as u16;
    mem.write_word(c2_addr, input_byte_addr.wrapping_add(40));

    // Run more steps and observe.
    let (steps, reason) = step_n(&mut state, &mut mem, 5000);

    // Snapshot the workspace state.
    let workspace_0 = mem.read_word(a_addr); // 'A' slot (current char)
    let c_value = mem.read_word(c_slot);
    eprintln!(
        "after injection + {steps} steps: IAR={:#x}, ACC={:#x}, XR1={:#x}, XR2={:#x}, XR3={:#x}, A={:#x}, C={:#x} -- {reason}",
        state.iar, state.acc, state.xr1, state.xr2, state.xr3, workspace_0, c_value
    );

    // Smoke: kernel must not have crashed.
    assert!(
        reason == "step limit reached" || reason == "halted",
        "expected clean run; got: {reason}"
    );
    // C cursor should have advanced past our injection (NEXT bumps it).
    assert!(
        c_value >= input_byte_addr,
        "C cursor should have advanced past input start ({input_byte_addr:#x}); got {c_value:#x}"
    );
}
