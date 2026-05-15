//! Runtime smoke test: assemble `historical/forth68/kernel.asm`,
//! load into the emulator at the kernel's `ORG /900`, set IAR to
//! `START`, and run for a bounded number of steps. The current
//! goal is "doesn't crash"; richer behavioural assertions land
//! once stubs (LIBF disk I/O, dictionary table) are filled in.
//!
//! See `historical/forth68/RUNTIME-STATUS.md` for the rolling
//! observation log.

use sw_ibm1130_asm::assemble;
use sw_ibm1130_emulator::{CpuState, Memory, exec::ExecError, step};

const KERNEL_SRC: &str = include_str!("../historical/forth68/kernel.asm");

/// Assemble the kernel, load at byte 0 (the ORG padding places
/// the actual kernel bytes at word 0x900), and prepare a fresh
/// CPU pointing at START.
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
fn kernel_assembles_and_loads_at_org_900() {
    let (state, _mem, symbols) = boot();
    // The ORG was /900; the asm pads zeros to that point, then the
    // first real instruction is somewhere at or after word 0x900.
    // START is the first executable label after the data prelude.
    assert!(
        state.iar >= 0x900,
        "START symbol resolved to {:#x}; expected >= 0x900",
        state.iar
    );
    // Spot-check a few symbols that the kernel needs to have
    // resolved correctly.
    let must_have = ["START", "NEXT", "FETCH", "ENTER", "FORTH_RTN", "BCD"];
    for sym in must_have {
        let v = symbols.lookup(sym).expect("symbol defined");
        assert!(v >= 0x900, "{sym} = {v:#x}; expected >= 0x900");
    }
}

#[test]
fn kernel_does_not_crash_for_first_n_steps() {
    let (mut state, mut mem, _symbols) = boot();
    // Cap at 200 steps. The kernel will likely hit a stubbed
    // routine (BLOCK / PUT / PRINT) or read from an empty input
    // buffer and loop; either way, 200 steps is enough to surface
    // an outright decode failure or illegal-state crash.
    let max_steps = 200;
    let mut last_iar = state.iar;
    let mut steps_taken = 0;
    for i in 0..max_steps {
        if state.halted {
            break;
        }
        match step(&mut state, &mut mem) {
            Ok(()) => {
                steps_taken = i + 1;
                last_iar = state.iar;
            }
            Err(ExecError::Halted) => break,
            Err(ExecError::Decode(msg)) => {
                panic!("decode error after {steps_taken} steps at IAR={last_iar:#x}: {msg}");
            }
            Err(ExecError::DivideByZero) => {
                panic!("divide-by-zero after {steps_taken} steps at IAR={last_iar:#x}");
            }
            Err(ExecError::Unsupported(op)) => {
                panic!("unsupported opcode {op:?} after {steps_taken} steps at IAR={last_iar:#x}");
            }
        }
    }
    // Acceptance: we ran some non-trivial number of instructions
    // without crashing. Exact behaviour depends on the stubs;
    // see RUNTIME-STATUS.md.
    assert!(
        steps_taken > 5,
        "expected to execute more than 5 instructions; ran {steps_taken}"
    );
}

#[test]
fn kernel_initialises_registers_in_start() {
    // Run far enough to get past START's register-setup block.
    // START loads XR2 with STACK+1, XR1 with A, etc. Verify the
    // post-setup register state.
    let (mut state, mut mem, symbols) = boot();
    // The START block has ~20 instructions. Run 25 to be safe.
    for _ in 0..25 {
        if state.halted {
            break;
        }
        if step(&mut state, &mut mem).is_err() {
            break;
        }
    }
    let stack_plus1 = symbols.lookup("STACK_PLUS1").expect("STACK_PLUS1 symbol") as u16;
    let a_addr = symbols.lookup("A").expect("A symbol") as u16;
    // After START's first few LDX L instructions: XR2 = STACK+1,
    // XR1 = A. The values must reflect those assignments.
    assert_eq!(
        state.xr2, stack_plus1,
        "XR2 should hold STACK+1 ({stack_plus1:#x}); got {:#x}",
        state.xr2
    );
    assert_eq!(
        state.xr1, a_addr,
        "XR1 should hold A ({a_addr:#x}); got {:#x}",
        state.xr1
    );
}
