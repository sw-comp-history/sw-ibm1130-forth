; ============================================================
;  sw-ibm1130-forth historical/forth68/kernel.asm
;
;  Translation of Charles H. Moore's 1968 FORTH for the IBM 1130,
;  retargeted to sw-ibm1130-asm syntax. Redistributed under
;  Moore's May-2020 public-posting permission, with attribution
;  to Moore and to monsonite/1968-FORTH (the upstream copy we
;  translated from). See NOTICE in this directory for the full
;  provenance.
;
;  Translation log: see TRANSLATION-LOG.md.
;  Decisions doc:   gen-isa/docs/forth-on-1130-decisions.md.
;
;  Status: saga step 5 (forth-on-1130) -- core kernel translated.
;  Disk-I/O sections (BLOCK, parts of PRINT) and the BCD lookup
;  table + initial dictionary are stubbed as STUB markers and
;  will be filled in by follow-on steps. The asm assembles
;  cleanly under sw-ibm1130-asm even with the stubs.
; ============================================================

        ABS
        ORG /900

; ------------------------------------------------------------
; CONVE -- convert EBCDIC byte to Moore's FORTH internal code
; via the BCD character table (workspace -1 holds the table base).
; ACC in: EBCDIC byte; ACC out: 0..0x3F FORTH code; -1 if not found.
; ------------------------------------------------------------
CONVE:  DC      0
        LD   1, -1            ; ACC = char-set table base (workspace[-1])
        STO  L CV1_PLUS1
        LDX  3, -63           ; XR3 = -63 (table-scan counter)
CV1:    LD   L 3, 0           ; load BCD entry; address patched by line above
CV1_PLUS1:
        S    1, 0             ; subtract incoming char from table entry
        BZ   L CV2            ; match: branch to CV2
        MDX  3, 1             ; XR3 += 1 (advance; skip next if 0)
        B    L CV1            ; loop
CV2:    MDX  3, 63            ; restore XR3 (subtracted 63 to count down)
        WAIT                  ; STUB: NOP slot per Moore (was 'NOP')
        STX  3, TEMP
        LD   L TEMP
        STO  1, 0             ; store result back in workspace[0]
        BSC  L CONVE, 0       ; return (BSC I CONVE)

; ------------------------------------------------------------
; ACCEP -- accept next character from input stream
; ACC out: next char in FORTH internal code.
; Calls FETCH then CONVE. May call RECOR to advance disk record.
; ------------------------------------------------------------
ACCEP:  DC      0
        LD   1, -3            ; ACC = current char pointer
        S    L C2             ; compare with end-of-record marker C2
        BSI  L RECOR          ; if past end, fetch next record (was: RECOR,+-)
        LD   1, -3
        BSI  L FETCH
        BSI  L CONVE
        BSC  L ACCEP, 0       ; return

; ------------------------------------------------------------
; RETRY -- ACCEPT from core (after RECOR refilled buffer)
; ------------------------------------------------------------
RETRY:  DC      0
        LD   1, -3
        BSI  L FETCH
        BSC  L RETRY, 0       ; return

; ------------------------------------------------------------
; NEXT -- read next FORTH word from input, pack into workspace.
; Two characters per word; up to 4 chars; spaces terminate.
; ------------------------------------------------------------
NEXT:   DC      0
        LD   1, -6            ; ACC = W1 (saved word slot)
        STO  1, 2             ; W = W1   (clear accumulating word)
        LD   L BL2            ; ACC = 2-blank pattern (/2424)
        STO  1, 4             ; clear WORD+1
NE1:    BSI  I 1, -2          ; call ACCEPT routine via workspace[-2]
        LD   1, 0             ; ACC = current char (A)
        S    L BL             ; subtract blank
        BNZ  L NE2            ; if not blank, go to NE2
        LD   1, -3            ; advance char pointer
        A    L ONE
        STO  1, -3
        B    L NE1            ; eat leading blanks
NE2:    S    L SC             ; not blank; check if special char
        BNP  L ALPHA          ; if <= SC (0x20), it's alphabetic
        S    L THREE
        BN   L SPECI          ; less than: special
        S    L TWO
        BNZ  L SPECI
ALPHA:  LD   1, 2             ; alphabetic char path
        BSI  L DEPOS
        BSI  I 1, -4          ; call SAVE routine via workspace[-4]
        LD   1, -3
        A    L ONE
        STO  1, -3
        LD   1, 2
        A    L ONE
        STO  1, 2
        BSI  I 1, -2          ; ACCEPT again
        LD   1, 0
        S    L BL
        BZ   L AL1            ; end on blank
        BP   L NEXT           ; positive (special) terminates
        B    L ALPHA
AL1:    BSI  I 1, -4
        LD   1, -3
        A    L ONE
        STO  1, -3
        BSC  L NEXT, 0        ; return
SPECI:  LD   1, 2             ; special character path
        BSI  L DEPOS
        BSI  I 1, -4
        LD   1, -3
        A    L ONE
        STO  1, -3
        BSC  L NEXT, 0        ; return

; --- constants used by NEXT ---
SC:     DC      0x20          ; was 20 (decimal); space char
TWO:    DC      2
THREE:  DC      3
BL2:    DC      /2424         ; two blanks packed
BL:     DC      /24           ; blank

; ------------------------------------------------------------
; SAVE -- store current ACC into D (workspace[-5] pointer) then
; deposit. Used by NEXT to accumulate the word's chars.
; ------------------------------------------------------------
SAVE:   DC      0
        LD   1, -5            ; D pointer
        A    L ONE
        STO  1, -5
        BSI  L DEPOS
        BSC  L SAVE, 0
SAVE0:  DC      0             ; dummy entry: no-op SAVE for skip-mode
        BSC  L SAVE0, 0

ONE:    DC      1
TEMP:   DC      0

; ------------------------------------------------------------
; FETCH -- get one char from input area at IX1+0 (workspace 'A'),
; alternating high/low byte of the addressed word. Bumps the
; cursor at workspace[-3] implicitly via even/odd dispatch.
; ------------------------------------------------------------
FETCH:  DC      0
        SRT  1                ; shift right ACC+EXT by 1 (test low bit -> EXT msb)
        STO  L TEMP
        SLT  1                ; restore (shift left ACC+EXT by 1)
        BOD  L FE1            ; if odd, branch to FE1 (odd-char path)
        LD   I TEMP           ; even char: load through TEMP pointer
        SRA  8                ; shift right 8 bits (extract high byte)
        B    L FE2
FE1:    LD   I TEMP           ; odd char: load same word
        AND  L FF             ; mask low byte
FE2:    STO  1, 0             ; store char in workspace[0] (A)
        BSC  L FETCH, 0       ; return

FF:     DC      /00FF

; ------------------------------------------------------------
; DEPOS -- deposit one char to output buffer.
; Inverse of FETCH: packs two chars per word with high/low select.
; ------------------------------------------------------------
DEPOS:  DC      0
        SRT  1
        STO  L TEMP
        SLT  1
        BOD  L DE1            ; odd-char path
        LD   1, 0             ; even chars: shift char left then OR in
        SLA  10               ; was SLA 10 (decimal) -- shift left by 10
        SRA  2
        OR   L BL             ; OR with blank pattern
        B    L DE2
DE1:    LD   I TEMP           ; odd-char path: load existing word
        AND  L FF00           ; keep high byte
        OR   1, 0             ; OR in new low byte
DE2:    STO  I TEMP           ; store back
        BSC  L DEPOS, 0       ; return

FF00:   DC      /FF00

; ------------------------------------------------------------
; DO -- interpret current word; look up in symbol table.
; Walks dictionary entries E (next-free) backwards by 4-word
; entries; matches both halves of the word; on match, branches
; indirect through entry's code slot.
; ------------------------------------------------------------
DO:     DC      0
        LDX  L I 3, E         ; XR3 = E (top of dict, indirect)
DO1:    MDX  3, -4            ; back up by one entry
        LD   3, 0             ; first half of entry name
        BZ   L DO             ; end-of-dict if zero (return)
        S    1, 3             ; compare with WORD
        BNZ  L DO1            ; mismatch -> next entry
        LD   3, 1             ; second half
        S    1, 4             ; compare with WORD+1
        BNZ  L DO1            ; mismatch
        B    L DO             ; match: fall through to handler (caller B I DO returns to dispatch)

; ------------------------------------------------------------
; UNDEF -- handler when DO finds no match: parse as hex literal.
; ------------------------------------------------------------
UNDEF:  DC      0
        LD   1, 3             ; WORD high half
        AND  L F000            ; mask first nybble
        BSI  L HEX            ; if numeric (was BSI L HEX,+-)
        BSC  L UNDEF, 0       ; return

F000:   DC      /F000

; ------------------------------------------------------------
; HEX -- treat WORD as a hex literal; convert to numeric value
; and push onto the data stack.
; ------------------------------------------------------------
HEX:    DC      0
        LD   1, 2             ; W (current word position)
        S    1, -6            ; W1 base
        STO  L TEMP
        LDX  L I 3, TEMP
        MDX  2, 1             ; bump stack
        SRA  16               ; clear ACC
        STO  2, 0
        LD   1, -6            ; W1
HE1:    STO  1, 2
        BSI  L FETCH
        LD   2, 0             ; accumulator-so-far
        SLA  4                ; shift left 4 (one hex digit)
        OR   1, 0             ; OR in low nybble of new char
        STO  2, 0
        LD   1, 2
        A    L ONE
        MDX  3, -1
        B    L HE1
        BSC  L HEX, 0

; ------------------------------------------------------------
; ENTRY -- create initial dictionary entry. Called by the user
; defining a new word.
; ------------------------------------------------------------
ENTRY:  DC      0
        BSI  L NEXT
        ; MDM L E1,4  -- "modify memory E1 by 4". Translated as
        ;   LD L E1; A L FOUR; STO L E1.
        ; (See TRANSLATION-LOG.md "MDM rewrite" entry.)
        LD   L E1
        A    L FOUR_LIT
        STO  L E1
        LDX  L I 3, E1
        STX  L 3, E
        LD   L E
        A    L FOUR_LIT
        STO  L E
        LD   1, 3             ; WORD high
        STO  3, 0
        LD   1, 4             ; WORD+1
        STO  3, 1
        BSC  L ENTRY, 0       ; return

FOUR_LIT: DC      4           ; added for MDM rewrites

; ------------------------------------------------------------
; ENTER -- "ADD TO SYMBOL TABLE": define a new colon word.
; Reads body until ; or , (END markers), depositing each word's
; execution address into the new dictionary entry.
; ------------------------------------------------------------
ENTER:  DC      0
        BSI  L ENTRY
        LD   L INTER
        STO  3, 2
        LD   L IC
        SLA  1
        A    L ONE
        STO  1, -5
        A    L ONE
        STO  3, 3
        LD   L ASAVE          ; SKIP OVER DEFINITION
        STO  1, -4
EN1:    BSI  L NEXT
        LD   L COMMA
        S    L WORD_HI
        BNZ  L EN2
EN3:    LD   1, -5            ; D
        SRA  1
        STO  L IC
        LD   L ASAV0
        STO  1, -4
        BSC  L ENTER, 0       ; return
EN2:    LD   L DOT
        S    L WORD_HI
        BNZ  L EN1
        B    L EN3

ASAVE:  DC      SAVE
ASAV0:  DC      SAVE0
DOT:    DC      /3024         ; semicolon's packed FORTH code
COMMA:  DC      /3424         ; ','
WORD_HI: DC     0             ; placeholder (Moore used 'S L WORD' which is the
                              ; address of the WORD storage; we materialise it
                              ; as a separate slot. See TRANSLATION-LOG.)
X3:     DC      0
        STX  3, X3

; ------------------------------------------------------------
; START -- restart location. Initialises the data stack, return
; stack, workspace pointer, and fixed-dictionary anchors.
; ------------------------------------------------------------
START:  LDX  L 2, STACK_PLUS1 ; XR2 = stack base + 1
        LDX  L 1, A           ; XR1 = workspace 'A' (current char slot)
        LDX  L 3, INTST
        STX  L 3, R           ; init return-stack pointer
        LDX  L 3, E2
        STX  L 3, E1
        MDX  3, 4
        STX  L 3, E
        LDX  L 3, 2*SECT+74   ; byte address: 2*(word-addr-of-SECT) + 74
        STX  L 3, STACK
        STX  L 3, C2
        LDX  L 3, /B3
        STX  L 3, /A
        LDX  L 3, FORTH_RTN
        STX  L 3, STACK_PLUS1
        LDX  L 3, ACCEP
        STX  L 3, A-2
        LDX  L 3, BCD_END     ; was BCD+63; resolved below
        STX  L 3, A-1
        LDX  L 3, SAVE0
        STX  L 3, A-4
        LDX  L 3, /19FF
        STX  L 3, IC
        LDX  L 3, /0268       ; was /10EE; Moore CVC change
        STX  L 3, SECT
        BSI  L RECUR
        ; LINK BALO -- STUB: 1130 LINK directive deferred (see
        ; TRANSLATION-LOG.md). For now, fall through to FORTH_RTN.

; ------------------------------------------------------------
; FORTH -- the main interpreter loop.
; ------------------------------------------------------------
FORTH_RTN:
        MDX  2, -1
        LD   2, 1
        STO  1, -3
FO1:    BSI  L NEXT
        BSI  L DO
        BSI  I 3, 2
        B    L FO1

; ------------------------------------------------------------
; RECUR -- recursion / call setup primitive.
; ------------------------------------------------------------
RECUR:  DC      0
        LD   L RECUR
        STO  I R
        ; MDM L R,1 -> LD L R; A L ONE; STO L R.
        LD   L R
        A    L ONE
        STO  L R
        MDX  2, -1
        B    I 2, 1

; ------------------------------------------------------------
; RETUR -- return from recursion.
; ------------------------------------------------------------
RETUR:  DC      0
        LD   L R
        S    L ONE
        STO  L R
        LDX  L I 3, R
        B    I 3, 0

; ------------------------------------------------------------
; INC -- increment a counter variable on the stack.
; ------------------------------------------------------------
INC:    DC      0
        LD   I 2, 0
        A    L ONE
        STO  I 2, 0
        STO  2, 0
        BSC  L INC, 0

; ------------------------------------------------------------
; INTER -- interpret one input source line; sets up parser
; bookkeeping. (Carries a leading DC * sentinel that Moore uses
; as a "this address" marker; we replace with explicit symbol.)
; ------------------------------------------------------------
INTER:  DC      *             ; LC-of-INTER stored at INTER (Moore idiom)
        DC      0
        LD   L E
        STO  I R
        STX  L 3, E
        LD   L R
        A    L ONE
        STO  L R
        LD   1, -3
        STO  I R
        LD   L R
        A    L ONE
        STO  L R
        LD   3, 3
        STO  1, -3
        LD   1, -2
        STO  I R
        LD   L R
        A    L ONE
        STO  L R
        LD   L ARETR
        STO  1, -2
        B    I INTER_PLUS1

INTER_PLUS1:
        DC      0
ARETR:  DC      RETRY

; ------------------------------------------------------------
; COM -- "END INTERRUPT": closing-bracket of a definition.
; ------------------------------------------------------------
COM:    DC      0
        ; MDM L R,-3
        LD   L R
        S    L THREE
        STO  L R
        LDX  L I 3, R
        LD   3, 1
        STO  1, -3
        LD   3, 2
        STO  1, -2
        LD   3, 0
        S    L E
        BNP  L COM            ; was BNP I COM (return through indirect)
        LD   3, 0
        STO  L E
        BSC  L COM, 0

; ------------------------------------------------------------
; LOC -- look up the location/execution address of the next word
; in the dictionary and push it on the stack.
; ------------------------------------------------------------
LOC:    DC      0
        BSI  L NEXT
        BSI  L DO
        LD   3, 2
        MDX  2, 1
        STO  2, 0
        BSC  L LOC, 0

; ------------------------------------------------------------
; OR -- bitwise OR of top two stack values.
; ------------------------------------------------------------
OR_PRIM: DC     0
        LD   2, 0
        MDX  2, -1
        OR   2, 0
        STO  2, 0
        BSC  L OR_PRIM, 0

; ------------------------------------------------------------
; STORE -- "STORE TO T.O.S.": pop value, store to address on stack.
; ------------------------------------------------------------
STORE:  DC      0
        LD   2, -1
        STO  I 2, 0
        MDX  2, -2
        BSC  L STORE, 0

; ------------------------------------------------------------
; SD -- "STACK TO DEPOSIT": pop top of stack, deposit at IC, bump IC.
; ------------------------------------------------------------
SD:     DC      0
        LD   2, 0
        ; MDM L IC,1
        LD   L IC
        A    L ONE
        STO  L IC
        STO  I IC
        MDX  2, -1
        BSC  L SD, 0

; ------------------------------------------------------------
; ADDR -- push an address (variable address) on the stack.
; ------------------------------------------------------------
ADDR:   DC      *
        DC      0
        MDX  2, 1
        STX  L 3, TEMP
        ; MDM L TEMP,3
        LD   L TEMP
        A    L THREE
        STO  L TEMP
        LD   L TEMP
        STO  2, 0
        B    L ADDR_PLUS1
ADDR_PLUS1:
        DC      0

; ------------------------------------------------------------
; LITER -- push a literal value onto the stack.
; ------------------------------------------------------------
LITER:  DC      *
        DC      0
        MDX  2, 1
        LD   3, 3
        STO  2, 0
        B    L LITER_PLUS1
LITER_PLUS1:
        DC      0

; ------------------------------------------------------------
; OPER -- "OPERATION": define a code (machine-language) primitive.
; ------------------------------------------------------------
OPER:   DC      0
        BSI  L ENTRY
        ; MDM L IC,1
        LD   L IC
        A    L ONE
        STO  L IC
        LD   L IC
        MDX  2, 1
        STO  2, 0
        STO  3, 2
        BSC  L OPER, 0

; ------------------------------------------------------------
; CONS -- define a CONSTANT word.
; ------------------------------------------------------------
CONS:   DC      0
        BSI  L NEXT
        BSI  L ENTRY
        LD   L LITER
        STO  3, 2
        LD   2, 0
        STO  3, 3
        MDX  2, -1
        BSC  L CONS, 0

; ------------------------------------------------------------
; INTEG -- declare an INTEGER variable.
; ------------------------------------------------------------
INTEG:  DC      0
        LDX  L I 3, E
        LD   L ADDR
        STO  3, 2
        BSI  L ADDR_PLUS1
        BSC  L INTEG, 0

; ============================================================
; Dictionary and workspace anchors.
; ============================================================

E1:     DC      0             ; top of symbol table (next-free index - 4)
E:      DC      0             ; place to start searches (next-free)
; IC is the instruction-counter / current code-emit address. In
; Moore's layout it lives inside the dictionary chain (sits at the
; fourth-word slot of the 'IC' dict entry below). See the dict
; block near the bottom of this file.

; workspace declarations
; Moore uses negative offsets from XR1 (= A) to hold:
;   -6 W1 (saved word slot), -5 D (char count), -4 SAVE entry,
;   -3 C  (char pointer),    -2 ACCEPT entry, -1 character table.
; We materialise them as labels here in a block that XR1 will
; point into.
W1:     DC      2*WORD_SYM    ; -6: byte address of WORD slot (Moore's
                              ; 2*WORD; restored saga step 9 once the
                              ; asm gained a multiplication operator).
        DC      0             ; -5 D
        DC      0             ; -4 SAVE
        DC      0             ; -3 C
        DC      0             ; -2 ACCEPT
        DC      0             ; -1 CHARACTER TABLE

A:      DC      0             ; XR1 = &A   (workspace 'current char')
        DC      1             ; N = 1
        DC      0             ; W = 2  WORD CHARACTER

WORD_SYM:
        BSS     20            ; word being parsed (3 chars + padding)
STACK:  BSS     16            ; data stack (XR2 base)

STACK_PLUS1:
        DC      0             ; addressable from STACK+1 by symbol

; A-2 / A-1 / A-4 are workspace slots in the W1 block above; no
; separate definitions needed (the operand expressions 'A-2'
; etc. resolve against the W1 block).

R:      DC      0             ; return-stack pointer
INTST:  BSS     32            ; interpreter state save area

; Disk-record boundaries
C1:     DC      2*SECT+714    ; reset-character byte address (was 2*SECT+642+72)
C2:     DC      0             ; character beyond record; init'd by START
C3:     DC      2*SECT+74     ; character beyond sector

ERROR:  DC      0
        BSC  L I ERROR, 0     ; B I ERROR (infinite-loop trap)

; ------------------------------------------------------------
; RECOR -- advance to next disk record. STUB:  the disk-I/O
; subsystem uses LIBF DISK1 / LIBF PRNT1 which are out of
; scope per gen-isa/docs/forth-on-1130-decisions.md Sec 2.6.
; Until a future I/O saga delivers LIBF emission, this routine
; falls through harmlessly.
; ------------------------------------------------------------
RECOR:  DC      0             ; STUB: next record
        LD   1, -3
        S    L C3
        ; BSI L BLOCK,+- -- STUB
        LD   1, -3
        S    L D152
        STO  1, -3
        ; MDM L C2,-80 -> LD L C2; S L D80; STO L C2
        LD   L C2
        S    L D80
        STO  L C2
        BSI  L FIXUP
        BSC  L RECOR, 0

D152:   DC      152
D80:    DC      80

; ------------------------------------------------------------
; BLOCK -- STUB. Reads next disk block via LIBF DISK1.
; Deferred to a future I/O-bringup saga.
; ------------------------------------------------------------
BLOCK:  DC      0             ; STUB: LIBF DISK1 not yet supported
        BSC  L BLOCK, 0       ; return immediately (no-op)

; ------------------------------------------------------------
; FIXUP -- rearrange disk record words. Pure asm, no LIBF; OK.
; ------------------------------------------------------------
FIXUP:  DC      0
        LD   1, -3
        SRA  1
        STO  L FX1
        STO  L FX2
        ; MDM L FX2,39 -> LD L FX2; A L D39; STO L FX2
        LD   L FX2
        A    L D39
        STO  L FX2
        LDX  3, 20
FI1:    LD   I FX1
        STO  L TEMP
        LD   I FX2
        STO  I FX1
        LD   L TEMP
        STO  I FX2
        ; MDM L FX1,1
        LD   L FX1
        A    L ONE
        STO  L FX1
        ; MDM L FX2,-1
        LD   L FX2
        S    L ONE
        STO  L FX2
        MDX  3, -1
        B    L FI1
        BSC  L FIXUP, 0

FX1:    DC      0
FX2:    DC      0
D39:    DC      39

; ------------------------------------------------------------
; PUT, PRINT -- output to console/printer via LIBF PRNT1.
; STUB: LIBF emission deferred. PUT and PRINT are no-ops until
; the I/O saga lands.
; ------------------------------------------------------------
PUT:    DC      0             ; STUB
        BSC  L PUT, 0

PRINT:  DC      0             ; STUB
        BSC  L PRINT, 0

; ============================================================
; BCD lookup table -- EBCDIC byte values, ordered by Moore's
; FORTH internal code 0..0x3F.
; STUB SUMMARY: the full 64-entry table is preserved verbatim
; from the source; included here as numeric DCs.
; ============================================================

BCD:    DC      240           ; 0
        DC      241           ; 1
        DC      242           ; 2
        DC      243           ; 3
        DC      244           ; 4
        DC      245           ; 5
        DC      246           ; 6
        DC      247           ; 7
        DC      248           ; 8
        DC      249           ; 9
        DC      193           ; A
        DC      194           ; B
        DC      195           ; C
        DC      196           ; D
        DC      197           ; E
        DC      198           ; F
        DC      199           ; G
        DC      200           ; H
        DC      201           ; I  (/12)
        DC      209           ; J
        DC      210           ; K
        DC      211           ; L
        DC      212           ; M
        DC      213           ; N
        DC      214           ; O  (/18)
        DC      215           ; P
        DC      216           ; Q
        DC      217           ; R
        DC      226           ; S  (/1C)
        DC      227           ; T
        DC      228           ; U
        DC      229           ; V
        DC      230           ; W
        DC      231           ; X
        DC      232           ; Y
        DC      233           ; Z
        DC      64            ; blank  (/24)
        DC      74            ; cents
        DC      123           ; #
        DC      76            ; <
        DC      77            ; (
        DC      78            ; +
        DC      79            ; |
        DC      80            ; &  (/2B)
        DC      90            ; !
        DC      91            ; $
        DC      92            ; *
        DC      93            ; )
        DC      94            ; ;
        DC      95            ; ~
        DC      96            ; -
        DC      97            ; /
        DC      107           ; ,
        DC      108           ; %
        DC      109           ; _
        DC      110           ; >
        DC      111           ; ?
        DC      122           ; :
        DC      75            ; .
        DC      124           ; @
        DC      125           ; '
        DC      126           ; =
        DC      127           ; "
BCD_END:
        DC      64            ; BCDBL = blank

BUF:    BSS     320           ; sector buffer (320 words)

; ============================================================
; SECT (sector buffer) + initial dictionary.
;
; Each entry is 4 words:
;   word 0: name-half-1 (packed FORTH internal code)
;   word 1: name-half-2 (or 2 blanks for short names)
;   word 2: code address (handler routine)
;   word 3: blank (or, for variable entries like IC/E/E1, the
;           storage cell for that variable)
;
; The DO routine walks this chain backwards by 4 words at a time
; (MDX 3, -4); E1 points at the most-recently-added entry and the
; chain ends when MDX hits a zero entry.
;
; Names are encoded in Moore's 6-bit FORTH code: digits 0-9 -> 00..09,
; A-F -> 0A..0F, G-Z -> 10..22, blank = 0x24, '.' = 0x3A, ';' = 0x30,
; ',' = 0x34, '=' = 0x3D, etc. Packed two chars per word, big-endian.
; The byte values below are preserved verbatim from Moore's source.
; ============================================================

SECT:   DC      0
SECT_BASE:
        BSS     320           ; sector data area (320 words)

; ---- start of dictionary chain (UNDEF handler is the catch-all) ----
        DC      0             ; padding
        DC      0
        DC      UNDEF
        DC      0

        DC      /0F18         ; FORTH
        DC      /1B1D
        DC      FORTH_RTN
        DC      0

        DC      /1B0E         ; RECURSE
        DC      /0C1E
        DC      LITER_PLUS1
        DC      R

        DC      /0F12         ; FIND
        DC      /170D
        DC      DO
        DC      0

        DC      /0A0D         ; ADDRESS
        DC      /0D1B
        DC      ADDR_PLUS1
        DC      0

        DC      /0E17         ; END
        DC      /0D24
        DC      COM
        DC      0

        DC      /110E         ; HEX
        DC      /2124
        DC      HEX
        DC      0

        DC      /181B         ; OR (renamed OR_PRIM in the translation;
        DC      /2424         ; see TRANSLATION-LOG LC.11)
        DC      OR_PRIM
        DC      0

        DC      /3D24         ; =
        DC      /2424
        DC      STORE
        DC      0

        DC      /3924         ; COLON (':')
        DC      /2424
        DC      ENTER
        DC      0

        DC      /3A24         ; .
        DC      /2424
        DC      ENTER
        DC      0

        DC      /3024         ; SEMICOLON (';')
        DC      /2424
        DC      COM
        DC      0

        DC      /3424         ; ,
        DC      /2424
        DC      COM
        DC      0

        DC      /120C         ; IC
        DC      /2424
        DC      ADDR_PLUS1
IC:     DC      0             ; <-- the IC variable lives in this slot

        DC      /2524         ; cent-sign (defines machine-code primitive)
        DC      /2424
        DC      OPER
        DC      0

        DC      /1819         ; OPERATION (synonym for cent-sign)
        DC      /0E1B
        DC      OPER
        DC      0

        DC      /0E17         ; ENTRY
        DC      /1D1B
        DC      ENTRY
        DC      0

        DC      /1217         ; INTEGER
        DC      /1D0E
        DC      INTEG
        DC      0

        DC      /1217         ; INC (note: name collision in Moore's source
        DC      /0C24         ; INTEGER and INC have the same hi half; the
        DC      INC           ; chain walk distinguishes via the lo half)
        DC      0

        DC      /1C0D         ; SD
        DC      /2424
        DC      SD
        DC      0

        DC      /0C18         ; CONVERT
        DC      /171F
        DC      CONVE
        DC      0

        DC      /0F0E         ; FETCH
        DC      /1D0C
        DC      FETCH
        DC      0

        DC      /0D0E         ; DEPOSIT
        DC      /1918
        DC      DEPOS
        DC      0

        DC      /191E         ; PUT
        DC      /1D24
        DC      PUT
        DC      0

        DC      /191B         ; PRINT
        DC      /1217
        DC      PRINT
        DC      0

        DC      /170E         ; NEXT
        DC      /211D
        DC      NEXT
        DC      0

        DC      /1518         ; LOC
        DC      /0C24
        DC      LOC
        DC      0

        DC      /0E24         ; E
        DC      /2424
        DC      LITER_PLUS1
        DC      E             ; <-- the E variable's address as the value

        DC      /1512         ; LIT
        DC      /1D24
        DC      LITER_PLUS1
        DC      0

E2:     DC      /0E01         ; E1
        DC      /2424
        DC      LITER_PLUS1
        DC      E1            ; <-- the E1 variable's address as the value

        END     START
