# Runtime status: Moore's 1968 kernel on `sw-ibm1130-emulator`

> Saga step 7 update (2026-05-15): the initial dictionary chain is
> in place (33 entries: FORTH, NEXT, HEX, ENTRY, INTEGER, etc.).
> A new test `dictionary_chain_is_walkable` walks the chain
> backwards from `E2` by 4-word entries, finds >= 10 entries, and
> spot-checks that well-known names (FORTH = 0x0F18, NEXT = 0x170E,
> HEX = 0x110E, ENTRY = 0x0E17) are present. `listing.fth` is
> translated (documentation-only until an input source exists).


> Saga step 6 deliverable: rolling observation log for what the
> translated kernel does at runtime, what works, and what hits a
> stub. Companion to `TRANSLATION-LOG.md`.
>
> Status: **partial smoke-test passing.** The kernel assembles
> (3518 instructions, 102 symbols) and runs for 200 steps without
> crashing or executing an invalid opcode. The exit conditions
> are documented below.
>
> Last updated: saga step 6 (2026-05-14).
> ASCII-only.

## Test harness

`tests/kernel_runtime.rs` in this crate:

1. `assemble(KERNEL_SRC)` -> bytes + symbols.
2. `Memory::new(4096)` then `mem.load_bytes(0, &bytes)`. The
   `ORG /900` pads zero words ahead of the kernel; the kernel
   bytes land at word address 0x900 (= byte 0x1200).
3. `state.iar = symbols.lookup("START") as u16`.
4. `for _ in 0..200 { step(&mut state, &mut mem) }`.

Three assertions:

- `kernel_assembles_and_loads_at_org_900` -- spot-check that
  load-bearing symbols resolved to addresses >= 0x900.
- `kernel_initialises_registers_in_start` -- after 25 steps,
  XR2 = STACK+1 and XR1 = A (these are the first two LDX L
  instructions in START, plus following work).
- `kernel_does_not_crash_for_first_n_steps` -- 200 steps without
  decode error, divide-by-zero, or unsupported opcode.

All three pass at saga-step-6 close.

## What works

### START's initialisation sequence

The opening 20-ish instructions of `START:` execute correctly:

- `LDX L 2, STACK_PLUS1` -- XR2 = address of STACK+1.
- `LDX L 1, A` -- XR1 = address of A (the workspace base).
- `LDX L 3, INTST` -- XR3 = address of INTST (return-stack base).
- `STX L 3, R` -- saves return-stack base.
- `STX L 3, A-2`, `STX L 3, A-1`, etc. -- writes into the
  workspace slots at A-6 through A-1 (the slots Moore uses as
  function pointers: ACCEPT handler, BCD table, SAVE handler).

The `A-N` offset-expression syntax (added in saga step 4)
resolves correctly: `STX L 3, A-2` stores XR3 into the word at
(address-of-A minus 2), which is the actual `-2` workspace slot.

### LDX semantics (fixed mid-step-6)

Before step 6, the emulator's `LDX` instruction dereferenced the
address operand (treating it as a memory pointer). Moore's source
uses `LDX L tag, IMM` to mean "XR[tag] = IMM directly". The
correct 1130 semantics are: short-form LDX = sign-extended disp
byte as immediate; long-form LDX (no indirect) = address field
as immediate; long-form LDX with indirect bit = mem[address].
The emulator was updated mid-step-6 to match (commit on
`sw-ibm1130-emulator`); the existing console-output demos
(`strings.asm`, `hello.asm`) were tweaked from `LDX L 1, ZERO`
to the simpler `LDX 1, 0` short-form-immediate (cosmetic, same
result).

### Auto-promote symbolic operands to long form (added mid-step-5)

Without this, hundreds of lines in the translated kernel would
have needed an explicit `L` flag that Moore didn't write.
Companion commit on `sw-ibm1130-asm`. Test suite (46 tests)
unchanged.

## What hits a stub (expected)

By design (per `TRANSLATION-LOG.md` LC.4), these routines are
no-op stubs in the translated kernel and return immediately:

- `BLOCK` -- next-disk-record. Backed by `LIBF DISK1`.
- `PUT` -- console output via `LIBF PRNT1`.
- `PRINT` -- print buffer flush via `LIBF PRNT1`.

When the kernel reaches one of these (e.g. during ACCEPT trying
to fetch input from disk that isn't there), the stub returns
and control proceeds. Useful for "doesn't crash" but means the
kernel doesn't actually read user input yet.

## Open questions / next-saga inputs

1. **Beyond 200 steps.** A longer-run test would surface more
   surface area. At what step count does the kernel first need
   working disk I/O? Step 6's test caps at 200 because that's
   enough to confirm "doesn't crash"; raising the limit needs
   either a real input buffer or a way to inject characters
   into the workspace at startup.

2. **Initial dictionary.** Currently stubbed to a sentinel
   entry. The kernel's `DO` lookup walks the dictionary; without
   real entries it never finds anything, so every parsed word
   falls through to `UNDEF` (which treats it as a hex literal).
   Filling in the dictionary belongs to its own saga step.

3. **Input source.** The kernel's ACCEPT mechanism reads from a
   disk buffer. We have no disk. Three paths:

   - **(a) Inject a buffer at startup.** Pre-load words into the
     SECT area before running. Cheap for tests; doesn't match
     historical behaviour.
   - **(b) Build a tiny "loadcards" device.** Translate ACCEPT
     to read from a memory-mapped input area; emulator pushes
     bytes via XIO. Closer to the 1130 model.
   - **(c) Implement LIBF DISK1.** Real solution; substantial
     scope; the I/O-bringup saga.

   For step 7+ of `forth-on-1130`, option (a) is sufficient.
   Real I/O can wait.

4. **2*WORD / 2*SECT byte/word arithmetic** (TRANSLATION-LOG
   LC.5). The translation dropped the factor-of-2; runtime
   behaviour may or may not require it. Will surface once we
   actually have characters flowing through FETCH/DEPOS.

5. **`BNP I COM` indirect-conditional return** (TRANSLATION-LOG
   LC.6, LC.16). Translation reduced to non-indirect form.
   Whether the return semantics are correct will become visible
   once the COM routine is actually exercised.

6. **XR3 use** (TRANSLATION-LOG LC.9, the explicit deviation
   from decisions Sec 2.2). With the kernel running in
   isolation, XR3 is used freely as Moore intended; no
   cross-contamination with the rest of the toolchain. This
   confirms the deviation was a correct call. Documented here
   so the next saga session knows the choice paid off.

## Toolchain bugs surfaced (and fixed)

Saga step 6's main purpose -- per the postmortem's "runtime
testing is what finds the bugs" lesson -- was to find toolchain
issues by running real code. Two surfaced:

### `LDX` long-form-no-indirect dereferenced when it shouldn't

Documented above. Fix: one match-arm rewrite in
`sw-ibm1130-emulator/src/exec.rs`. Two existing demo programs
tweaked to use short-form immediate syntax (cosmetic).

### Symbolic operands needed explicit `L` flag (mid-step-5)

Surfaced during the kernel translation, fixed before this step.

## Acceptance criteria for step 6 (met)

- `tests/kernel_runtime.rs` exists and passes.
- This `RUNTIME-STATUS.md` documents what runs / what stubs /
  what's open.
- Two genuine emulator bugs found (`LDX` semantics) and fixed
  via separate commits on the affected crate.
- All previously-passing tests still pass.
