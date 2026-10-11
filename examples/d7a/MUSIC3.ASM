; MUSIC3.ASM
;
; This is MUSIC3.z80 by Dave Roberts (MUSIC3 20240817.zip), modified to assemble with
; Microsoft M80 under CP/M. Build it with MUSIC3.SUB (M80, then L80 to MUSIC3.HEX).
;
; The code, the tables and the comments are the original. These things are changed:
;   - Added .Z80 and ASEG at the start. Removed the ASM80 ".engine" directive.
;   - ".if", ".else", ".endif", ".macro NAME", ".endm" and ".org" are in M80 form.
;   - Hex constants 0x20 and $F0 are in the form 20H and 0F0H.
;   - msb(X) is HIGH X, and ".align 256" is an ORG to the next 256-byte page.
;   - The EQUs that use RAM are moved to the end, because M80 does not accept a
;     forward reference in an EQU.
;   - DEBUG is 0, for a CP/M .COM at 0100H that plays through the DAC.
;     (Set it to 1 for the original debug build at 0000H.)
;
	.Z80
	ASEG

; Modification history.
; =====================
;
; Version : 
;    Date : 
;  Author : 
;  Change : 
;
; Version : 0.30
;    Date : 30th May 2024
;  Author : Dave Roberts
;  Change : Dang, I lost the last version of my code!
;           Added the song STAR SPANGLED BANNER from the Byte Magazine.
;           Delete the superflous "XOR A".
;           Change the "ADD A,(HL)" to "LD A,(HL)" for the first voice.
;           Update the frequency table for a 248T - 4T = 244T play loop.
;         : Changed all JR to JP. Update T comments. Need to recalculate data tables...
;         : Included code to configure for CP/M (ORG 100) and for the Cromemco D+7A.
;
; Version : 0.20
;    Date : 5th January 2024
;  Author : Dave Roberts
;  Change : It seems to work...
;
; Version : 0.10
;    Date : 4th January 2024
;  Author : Dave Roberts
;  Change : TEMPO and DURATION ito IYH and IYL using the documented
;           undocumented Z80 instructions. I have also added a 
;           compatability mode (which is obviously slower).
;         : Added symbols TEST, DEBUG and USEUNDOC.
;         : Start to convert to 16-bit Voice registers.
;         : Remove TEST. I broke the assembler!
;
; Functionsal description.
; ========================
;
; TODO: @@@

; Definitions
; ===========
;
USEUNDOC    EQU 1
PFIXIY      EQU 0FDH

DAC			EQU	19h			; Cromemco D+7A Analogue Output #1.

DEBUG       EQU 0


    
    IF DEBUG
LOADAT EQU 0000H
	ELSE
LOADAT EQU 0100H
	ENDIF

K   EQU 1024
K2  EQU (2 * K)


    IF DEBUG
TEMPO   EQU 06H ; For testing/debugging.
    ELSE
TEMPO   EQU 99H ; For real. TODO: Check that the value is correct...
    ENDIF
    
; Macros for the undocumented Z80 instructions I am going to use.

LD_IYH_A	MACRO
    IF USEUNDOC
    db  PFIXIY
    LD  H,A
    ELSE
    LD  (IX+IYH),A
    ENDIF
    ENDM
    
LD_IYL_A	MACRO
    IF USEUNDOC
    db  PFIXIY
    LD  L,A
    ELSE
    LD  (IX+IYL),A
    ENDIF
    ENDM
    
DEC_IYH	MACRO
    IF USEUNDOC
    db  PFIXIY
    DEC H
    ELSE
    DEC (IX+IYH)
    ENDIF
    ENDM

DEC_IYL	MACRO
    IF USEUNDOC
    db  PFIXIY
    DEC L
    ELSE
    DEC (IX+IYL)
    ENDIF
    ENDM
    
    ; *******************
    ; ***             ***
    ; ***  ROM code.  ***
    ; ***             ***
    ; *******************
    
    ORG LOADAT
    
    ; ***********************
    ; ***                 ***
    ; ***  Main program.  ***
    ; ***                 ***
    ; ***********************
    
START:

    ; We use subroutine calls, so require a stack. Set it to the top of memory.
    ;
    LD      SP,TOS          ; 10T - Define a stack in RAM to use.
    
    ; Initialise RAM to zero on start-up to guarantee the state.
    ;
    LD      HL,RAM+0        ; 10T - First byte of RAM.
    LD      DE,RAM+1        ; 10T - Second byte of RAM.
    LD      BC,K2           ; 10T - Number of bytes to clear. CHECK K2 or K2-1?
    LD      (HL),0          ; 10T - Seed the first byte with zero (0).
    LDIR                    ;  8T - Go zap! (HL) to (DE), INC HL, INC DE, DEC BC and loop until BC zero.
                            ;       21T [BC <> 0] + 16T [BC == 0].
    CALL    MUSIC           ; 17T - Play the tune...
    HALT                    ;  4T - All finished.
    
    ; ***************************
    ; ***                     ***
    ; ***  MUSIC subroutine.  ***
    ; ***                     ***
    ; ***************************
    
MUSIC:

	IF DEBUG
	ld		a,'!'
	call	outa3
	ENDIF
	
    LD      HL,SCORE        ; 10T - The start of the music score to play.

    IF USEUNDOC
    ELSE
    ; IX is not required anymore - as the RAM is referred to by other means.
    ; Apart from the emulated undocumented Z80 instructions.
    ;
    LD      IX,WS           ; 14T - Working memory (IX should remain constant).
    ENDIF
    
    ; Initialise the Voice variable registers to 0.
    ;
    LD      DE,0            ; 10T - Voice 1.
    LD      BC,0            ; 10T - Voice 2.
    EXX                     ;  4T - Switch register set to shadow.
    LD      DE,0            ; 10T - Voice 3.
    LD      BC,0            ; 10T - Voice 4.
    EXX                     ;  4T - Switch register set back to normal again.
    
MUSIC1:

    LD      A,(HL)          ;  7T - Pickup a byte from the score (duration).
    OR      A               ;  4T - Check for a zero in the table.
    RET     Z               ; 10T - Return from subroutine MUSIC if at the end of the SCORE.
    
    LD_IYH_A                ;  8T - Get duration byte into register IYH (for use by subroutine PLAY).

    ; The following code is 'unrolled' for speed (at the expense of size)...
    
    PUSH    BC              ; 11T - Preserve Voice 2 onto the stack whilst we reuse it.

    LD      B,HIGH FREQTBL  ;  7T - Frequency table start. Must be on a 256-byte boundary to work.
    
    ; ******************
    ; ***            ***
    ; ***  Voice 1.  ***
    ; ***            ***
    ; ******************
    
    INC     HL              ;  6T - Bump the pointer into the score table. First/next note.
    LD      C,(HL)          ;  7T - Index into the next byte of the score table. A note ID.
    LD      A,(BC)          ;  7T - Pick up the first byte of the note's frequency - fractional part.
    LD      (V1FC),A        ; 13T - Store it away in the workspace - fractional part.
    INC     C               ;  4T - Index to the next byte of the note's frequency - integer part.
    LD      A,(BC)          ;  7T - Pick up the second byte of the note's frequency - integer part.
    LD      (V1IC),A        ; 13T - Store it away in the workspace - integer part.

    ; ******************
    ; ***            ***
    ; ***  Voice 2.  ***
    ; ***            ***
    ; ******************
    
    INC     HL              ;  6T - Bump the pointer into the score table. First/next note.
    LD      C,(HL)          ;  7T - Index into the next byte of the score table. A note ID.
    LD      A,(BC)          ;  7T - Pick up the first byte of the note's frequency - fractional part.
    LD      (V2FC),A        ; 13T - Store it away in the workspace - fractional part.
    INC     C               ;  4T - Index to the next byte of the note's frequency - integer part.
    LD      A,(BC)          ;  7T - Pick up the second byte of the note's frequency - integer part.
    LD      (V2IC),A        ; 13T - Store it away in the workspace - integer part.

    ; ******************
    ; ***            ***
    ; ***  Voice 3.  ***
    ; ***            ***
    ; ******************
    
    INC     HL              ;  6T - Bump the pointer into the score table. First/next note.
    LD      C,(HL)          ;  7T - Index into the next byte of the score table. A note ID.
    LD      A,(BC)          ;  7T - Pick up the first byte of the note's frequency - fractional part.
    LD      (V3FC),A        ; 13T - Store it away in the workspace - fractional part.
    INC     C               ;  4T - Index to the next byte of the note's frequency - integer part.
    LD      A,(BC)          ;  7T - Pick up the second byte of the note's frequency - integer part.
    LD      (V3IC),A        ; 13T - Store it away in the workspace - integer part.

    ; ******************
    ; ***            ***
    ; ***  Voice 4.  ***
    ; ***            ***
    ; ******************
    
    INC     HL              ;  6T - Bump the pointer into the score table. First/next note.
    LD      C,(HL)          ;  7T - Index into the next byte of the score table. A note ID.
    LD      A,(BC)          ;  7T - Pick up the first byte of the note's frequency - fractional part.
    LD      (V4FC),A        ; 13T - Store it away in the workspace - fractional part.
    INC     C               ;  4T - Index to the next byte of the note's frequency - integer part.
    LD      A,(BC)          ;  7T - Pick up the second byte of the note's frequency - integer part.
    LD      (V4IC),A        ; 13T - Store it away in the workspace - integer part.

    INC     HL              ;  6T - Bump the pointer into the score table again.

    POP     BC              ; 10T - Recover Voice 2 from the stack again.
    
    ; ***********************************************************************
    ; ***                                                                 ***
    ; ***  Go and play the specified note(s) for the specified duration.  ***
    ; ***                                                                 ***
    ; ***********************************************************************
    
    ; Note: PUSH and POP is faster than LD (nn),HL and LD HL,(nn).
    ; Note: 21T verses 32T.
    
    PUSH    HL              ; 11T - Save the score pointer for use later.
    CALL    PLAY            ; 17T - Play the note(s).
    POP     HL              ; 10T - Recover the score pointer.

    JP      MUSIC1          ; 10T - Loop until done...
    
    ; **************************
    ; ***                    ***
    ; ***  PLAY subroutine.  ***
    ; ***                    ***
    ; **************************
    
    ; On entry, register IYH contains the music event duration.

PLAY:

PLAY1:

    LD      A,TEMPO         ;  7T - TEMPO is a constant.
    LD_IYL_A                ;  8T - stored in IYL.
    
    ; Symbol naming is as follows: V <voice number> <F or I> <C>
    ;
    ; Where:
    ; 
    ; F is the fractional part of the word.
    ; I is the integer    part of the word.
    ;
    ; C is the constant word.
    ;
    ; The numbers are addresses of bytes within the workspace.
    ;
    ; Note that the order is important. The fractional byte of the word
    ; must be at a lower address than the integer byte of the word. This
    ; is to ensure the correct byte order for loading HL via an
    ; instruction of the form LD HL,(V1FC). This will load the fractional
    ; byte into register L and the integer byte into register H.
    ;
    ; The Z80 registers are used as follows:
    ;
    ; DE  = Voice 1.
    ; BC  = Voice 2.
    ; DE' = Voice 3.
    ; BC' = Voice 4.
    ;
    ; These registers MUST be preserved at all times for use during the PLAY
    ; subroutine. They must NOT be corrupted by the MUSIC subroutine either.
    ;
    




PLAY2:

    ; ******************
    ; ***            ***
    ; ***  Voice 1.  ***
    ; ***            ***
    ; ******************
    
    LD      HL,(V1FC)   	; 16T - Voice 1 constant.
    ADD     HL,DE       	; 11T - Sum HL to Voice 1 variable.
    EX      DE,HL       	;  4T - Store resultant sum into Voice 1 variable.
    
    ; ******************
    ; ***            ***
    ; ***  Voice 2.  ***
    ; ***            ***
    ; ******************
    
    LD      HL,(V2FC)   	; 16T - Voice 2 constant.
    ADD     HL,BC       	; 11T - Sum HL to Voice 2 variable.
    LD      B,H         	;  4T - Store resultant sum into Voice 1 variable (high byte).
    LD      C,L         	;  4T - Store resultant sum into Voice 1 variable (low  byte).
    
    EXX                 	;  4T - Switch to shadow register set to process Voices 3 and 4.
    
    ; ******************
    ; ***            ***
    ; ***  Voice 3.  ***
    ; ***            ***
    ; ******************
    
    LD      HL,(V3FC)   	; 16T - Voice 3 constant.
    ADD     HL,DE       	; 11T - Sum HL' to Voice 3 variable.
    EX      DE,HL       	;  4T - Store resultant sum into Voice 1 variable.
    
    ; ******************
    ; ***            ***
    ; ***  Voice 4.  ***
    ; ***            ***
    ; ******************
    
    LD      HL,(V4FC)   	; 16T - Voice 4 constant.
    ADD     HL,BC       	; 11T - Sum HL' to Voice 4 variable.
    LD      B,H         	;  4T - Store resultant sum into Voice 4 variable (high byte).
    LD      C,L         	;  4T - Store resultant sum into Voice 4 variable (low  byte).

    ; Derive the DAC output.
    
    ; Mote that we keep the shadow set of registers mapped in and process Voices 3 and 4
    ; first before switching to process Voices 1 and 2. This saves an EXX instruction (4T).
    
    LD      H,HIGH WAVETBL  ;  7T - This table should be page aligned.

    LD      L,D         	;  4T - Voice 3 Integer byte.
    LD      A,(HL)      	;  7T - Index wave table for Voice 3 Integer byte.
    
    LD      L,B         	;  4T - Voice 4 Integer byte.
    ADD     A,(HL)      	;  7T - Index wave table for Voice 4 Integer byte.
    
    EXX                 	;  4T - Switch back to the normal register set to process Voices 1 and 2.
    
    LD      H,HIGH WAVETBL  ;  7T - This table should be page aligned.

    LD      L,D         	;  4T - Voice 1 Integer byte.
    ADD     A,(HL)      	;  7T - Index wave table for Voice 1 Integer byte.
    
    LD      L,B         	;  4T - Voice 2 Integer byte.
    ADD     A,(HL)      	;  7T - Index wave table for Voice 2 Integer byte.

    SUB		80h				; 7T - Convert from UNIPOLAR to BIPOLAR for Cromemco D+7A.
    
    IF DEBUG
    CALL    OUTAHEX     	; For debugging.
    ELSE
    OUT     (DAC),A     	; 11T - Send the value in register A to the DAC.
    ENDIF
    
    DEC_IYL             	;  8T - Decrement the TEMPO.
    JP      NZ,PLAY2    	;  10T - Loop for more...
    
    DEC_IYH             	;  8T - Decrement the duration.
    JP      NZ,PLAY1    	;  10T - Loop for more...

    ; ***********************
    ; ***                 ***
    ; ***  All finished.  ***
    ; ***                 ***
    ; ***********************
    
    RET                     ; 10T - Return from suproutine PLAY...

    IF DEBUG
    
OUTAHEX:

    push    af
    call    outa1
    pop     af
    call    outa2
    ld      a,'/'
    call    outa3
    ret
    
outa1:
    rra
    rra
    rra
    rra
outa2:
    or      0F0H
    daa
    add     a,0A0H
    adc     a,040H
outa3:
    out     (2),a
    ret

    ENDIF
    
    ; This table needs to be on a page (256 byte) boundary.
    ; =====================================================
    ;
    ORG	($+255) AND 0FF00H
    ;
    ; Cosine integer wave table (4 voices @ 0-3F amplitude each, sum to FC).
    ; ======================================================================
    ;
WAVETBL:
    ;  ;                        ;                        ;                        ;    
    DB 20H, 20H, 21H, 22H,  23H, 23H, 24H, 25H,  26H, 26H, 27H, 28H,  29H, 29H, 2AH, 2BH ; 00
    DB 2CH, 2CH, 2DH, 2EH,  2EH, 2FH, 30H, 30H,  31H, 32H, 32H, 33H,  34H, 34H, 35H, 35H ; 10
    DB 36H, 36H, 37H, 37H,  38H, 38H, 39H, 39H,  3AH, 3AH, 3BH, 3BH,  3BH, 3CH, 3CH, 3CH ; 20
    DB 3DH, 3DH, 3DH, 3DH,  3EH, 3EH, 3EH, 3EH,  3EH, 3FH, 3FH, 3FH,  3FH, 3FH, 3FH, 3FH ; 30
    DB 3FH, 3FH, 3FH, 3FH,  3FH, 3FH, 3FH, 3EH,  3EH, 3EH, 3EH, 3EH,  3EH, 3DH, 3DH, 3DH ; 40
    DB 3CH, 3CH, 3CH, 3BH,  3BH, 3BH, 3AH, 3AH,  39H, 39H, 39H, 38H,  38H, 37H, 37H, 36H ; 50
    DB 35H, 35H, 34H, 34H,  33H, 33H, 32H, 31H,  31H, 30H, 2FH, 2FH,  2EH, 2DH, 2DH, 2CH ; 60
    DB 2BH, 2AH, 2AH, 29H,  28H, 27H, 27H, 26H,  25H, 24H, 24H, 23H,  22H, 21H, 21H, 20H ; 70
    DB 1FH, 1EH, 1DH, 1DH,  1CH, 1BH, 1AH, 1AH,  19H, 18H, 17H, 17H,  16H, 15H, 14H, 14H ; 80
    DB 13H, 12H, 11H, 11H,  10H, 0FH, 0FH, 0EH,  0DH, 0DH, 0CH, 0CH,  0BH, 0AH, 0AH, 09H ; 90
    DB 09H, 08H, 08H, 07H,  07H, 06H, 06H, 05H,  05H, 05H, 04H, 04H,  03H, 03H, 03H, 02H ; A0
    DB 02H, 02H, 02H, 01H,  01H, 01H, 01H, 01H,  00H, 00H, 00H, 00H,  00H, 00H, 00H, 00H ; B0
    DB 00H, 00H, 00H, 00H,  00H, 00H, 00H, 01H,  01H, 01H, 01H, 01H,  02H, 02H, 02H, 02H ; C0
    DB 03H, 03H, 03H, 04H,  04H, 05H, 05H, 05H,  06H, 06H, 07H, 07H,  08H, 08H, 09H, 09H ; D0
    DB 0AH, 0AH, 0BH, 0CH,  0CH, 0DH, 0DH, 0EH,  0FH, 0FH, 10H, 11H,  11H, 12H, 13H, 14H ; E0
    DB 14H, 15H, 16H, 17H,  17H, 18H, 19H, 1AH,  1AH, 1BH, 1CH, 1DH,  1DH, 1EH, 1FH, 1FH ; F0

    ; This table needs to be on a page (256 byte) boundary.
    ; =====================================================
    ;
    ORG	($+255) AND 0FF00H
    ;
FREQTBL:
    ;
    ; Frequency table for a 4 MHz Z80 CPU.
    ; ====================================
    ;
    ; The INCREMENT is calculated from the formula:
    ;
    ; INCREMENT = 256 * f / T
    ;
    ; Where:
    ;
    ; f is the desired note frequency (in Hertz).
    ; T is the sample rate (in Hertz).
    ;
    ; T is a function of the time taken to execute one iteration of
    ; the play loop. Calculate the time for one iteration (in seconds)
    ; and take the reciprocal (1/x) of the value to derive T.
    ;
    ; The floating point number obtained will be X.Y where X is the integer
    ; part and Y is the fractional part.
    ;
    ; The integer part (X) is used as the high byte directly whilst the fractional 
    ; part is converted into a byte value in the range 0 through 255.
    ;
    ; As an example (from the BYTE article):
    ;
    ; 8.772 kHz sample rate.
    ; Desired frequency = C2 = 65.405 Hz
    ; Given increment = 1.9089
    ; Given bytes = integer = 1, fractional = 233.
    ;
    ; 1.9089 = an integer part of 1.
    ; 0.9089 * 256 = 232.7 (rounded to 233). Although why 256 and not 255?
    ;
    ; Using the formual above for INCREMENT:
    ;
    ; INCREMENT = 256 * 65.405 / 8772 = 1.9089 (rounded).
    ; 
    ; Now, I need to ascertain the corresponding maths for the Z80 implementation...
    ;
    ; The following hexadecimal word values are taken from the handwriting on the
    ; 6502 frequency table listing.
    ;
    ; Ideally, I will generate the byte table from a spreadsheet containing the 
    ; note frequencies and the entered number of T states (at a clock frequency of 
    ; 4 MHz).
    ;
    ; This table is for the 'original' Z80 project.
    ;
    IF 0
    ;           ; ID  NOTE FREQUENCY
    DW  0000H  ;  0  SILENCE
    DW  0305H  ;  2  C2     65.405
    DW  0333H  ;  4  C2#    69.295
    DW  0364H  ;  6  D2     73.415
    DW  039BH  ;  8  D2#    77.783
    DW  03CEH  ; 10  E2     82.408
    DW  040BH  ; 12  F2     87.308
    DW  0446H  ; 14  F2#    92.498
    DW  04B7H  ; 16  G2     97.998
    DW  04CCH  ; 18  G2#   103.83
    DW  0515H  ; 20  A2    110.00
    DW  0562H  ; 22  A2#   116.54
    DW  0564H  ; 24  B2    123.47
    DW  060BH  ; 26  C3    130.81
    DW  0667H  ; 28  C3#   138.59
    DW  06C8H  ; 30  D3    146.83
    DW  0795H  ; 32  D3#   155.57
    DW  079DH  ; 34  E3    164.82
    DW  0811H  ; 36  F3    174.62
    DW  08CCH  ; 38  F3#   185.00
    DW  090EH  ; 40  G3    196.00
    DW  0998H  ; 42  G3#   207.65
    DW  0A2AH  ; 44  A3    220.00
    DW  0AC5H  ; 46  A3#   233.08
    DW  0B69H  ; 48  B3    246.94
    DW  0C16H  ; 50  C4    261.62
    DW  0CCFH  ; 52  C4#   277.18
    DW  0D91H  ; 54  D4    293.66
    DW  0E60H  ; 56  D4#   311.13
    DW  0F3BH  ; 58  E4    329.63
    DW  1023H  ; 60  F4    349.23
    DW  1118H  ; 62  F4#   369.99
    DW  121DH  ; 64  G4    391.99
    DW  1330H  ; 66  G4#   415.30
    DW  1455H  ; 68  A4    440.00
    DW  158AH  ; 70  A4#   466.16
    DW  16D2H  ; 72  B4    493.88
    DW  182DH  ; 74  C5    523.24
    DW  199EH  ; 76  C5#   554.36
    DW  1B23H  ; 78  D5    587.32
    DW  1CC1H  ; 80  D5#   622.26
    DW  1E77H  ; 82  E5    659.26
    DW  2046H  ; 84  F5    698.46
    DW  2231H  ; 86  F5#   739.98
    DW  243AH  ; 88  G5    783.98
    DW  2661H  ; 90  G5#   830.60
    DW  28AAH  ; 92  A5    880.00
    DW  2B15H  ; 94  A5#   932.32
    DW  2DA5H  ; 96  B5    987.76
    DW  305CH  ; 98  C6   1046.5
    ENDIF
   
    IF 0
    ;
    ; This is the table for a 4.0 Mhz Z80 clock and a 248T PLAY subroutine.
    ; Giving a 16,129 Hz sample rate.
    ;
    DW 0000H ;  0 SILENCE
    DW 010AH ;  2 C2     
    DW 011AH ;  4 C2#    
    DW 012AH ;  6 D2     
    DW 013CH ;  8 D2#    
    DW 014FH ; 10 E2     
    DW 0163H ; 12 F2     
    DW 0178H ; 14 F2#    
    DW 018EH ; 16 G2     
    DW 01A6H ; 18 G2#    
    DW 01BFH ; 20 A2     
    DW 01DAH ; 22 A2#    
    DW 01F6H ; 24 B2     
    DW 0214H ; 26 C3     
    DW 0233H ; 28 C3#    
    DW 0255H ; 30 D3     
    DW 0278H ; 32 D3#    
    DW 029EH ; 34 E3     
    DW 02C6H ; 36 F3     
    DW 02F0H ; 38 F3#    
    DW 031CH ; 40 G3     
    DW 034CH ; 42 G3#    
    DW 037EH ; 44 A3     
    DW 03B3H ; 46 A3#    
    DW 03EBH ; 48 B3     
    DW 0427H ; 50 C4     
    DW 0466H ; 52 C4#    
    DW 04A9H ; 54 D4     
    DW 04F0H ; 56 D4#    
    DW 053BH ; 58 E4     
    DW 058BH ; 60 F4     
    DW 05DFH ; 62 F4#    
    DW 0639H ; 64 G4     
    DW 0697H ; 66 G4#    
    DW 06FCH ; 68 A4     
    DW 0766H ; 70 A4#    
    DW 07D7H ; 72 B4     
    DW 084EH ; 74 C5     
    DW 08CCH ; 76 C5#    
    DW 0952H ; 78 D5     
    DW 09E0H ; 80 D5#    
    DW 0A77H ; 82 E5     
    DW 0B16H ; 84 F5     
    DW 0BBFH ; 86 F5#    
    DW 0C71H ; 88 G5     
    DW 0D2FH ; 90 G5#    
    DW 0DF8H ; 92 A5     
    DW 0ECCH ; 94 A5#    
    DW 0FADH ; 96 B5     
    DW 109CH ; 98 C6     
    ENDIF

    IF 1
    ;
    ; This is the table for a 4.0 Mhz Z80 clock and a 244T PLAY subroutine.
    ; Giving a 16,393 Hz sample rate.
    ;
    DW 0000H ;  0 SILENCE
    DW 0105H ;  2 C2     
    DW 0115H ;  4 C2#    
    DW 0125H ;  6 D2     
    DW 0137H ;  8 D2#    
    DW 0149H ; 10 E2     
    DW 015DH ; 12 F2     
    DW 0172H ; 14 F2#    
    DW 0188H ; 16 G2     
    DW 019FH ; 18 G2#    
    DW 01B8H ; 20 A2     
    DW 01D2H ; 22 A2#    
    DW 01EEH ; 24 B2     
    DW 020BH ; 26 C3     
    DW 022AH ; 28 C3#    
    DW 024BH ; 30 D3     
    DW 026EH ; 32 D3#    
    DW 0293H ; 34 E3     
    DW 02BAH ; 36 F3     
    DW 02E4H ; 38 F3#    
    DW 0310H ; 40 G3     
    DW 033EH ; 42 G3#    
    DW 036FH ; 44 A3     
    DW 03A4H ; 46 A3#    
    DW 03DBH ; 48 B3     
    DW 0416H ; 50 C4     
    DW 0454H ; 52 C4#    
    DW 0496H ; 54 D4     
    DW 04DCH ; 56 D4#    
    DW 0526H ; 58 E4     
    DW 0574H ; 60 F4     
    DW 05C7H ; 62 F4#    
    DW 061FH ; 64 G4     
    DW 067CH ; 66 G4#    
    DW 06DFH ; 68 A4     
    DW 0748H ; 70 A4#    
    DW 07B6H ; 72 B4     
    DW 082CH ; 74 C5     
    DW 08A8H ; 76 C5#    
    DW 092CH ; 78 D5     
    DW 09B8H ; 80 D5#    
    DW 0A4CH ; 82 E5     
    DW 0AE8H ; 84 F5     
    DW 0B8EH ; 86 F5#    
    DW 0C3EH ; 88 G5     
    DW 0CF8H ; 90 G5#    
    DW 0DBEH ; 92 A5     
    DW 0E8FH ; 94 A5#    
    DW 0F6DH ; 96 B5     
    DW 1058H ; 98 C6     
    ENDIF

    ; Song table.
    ; ===========
    ;
    ; This table consists of 5 bytes per musical event.
    ; The first byte indicates the duration of the event
    ; (according to the value of tempo). A value of zero
    ; indicates the end of the song.
    ;
    ; The next four (4) bytes corresponds to a byte for 
    ; each of the four voices corresponding to the 
    ; desired note ID. Zero indicates no note (or 
    ; silence).
    ;
    ; The alignment is strictly not necessary - but makes the starting address
    ; for the score nice and simple to remember...
    ;
    ORG	($+255) AND 0FF00H
    ;
SCORE:

    ; Simple sine wave test.
    ; DB  64,2,0,0,0  ; Note ID 2 = C2 = 65.405 Hz.
    ; DB  0

    ; SONG TABLE FOR THE STAR SPANGLED BANNER BY FRANCIS SCOTT KEY
    ; AMD J. STAFFORD SMITH
    ; DURATION COUNT = 64 FOR QUARTER NOTE
    ;
    ; Copied from BYTE Magazine, Volume 2, Number 9 (September 1977) Pages 77 and 78.
    ;
    DB  96,74,0,0,50		; 3/8		C5						C4		1
    DB  16,68,0,0,44		; 1/16		A4						A3
    DB  64,64,0,0,36		; 1/4		G4						F3		2
    DB  64,68,0,0,36		; 1/4		A4						F3
    DB  64,74,0,0,34		; 1/4		C5						E3
    DB  128,84,78,68,30		; 1/2		F5		D5		A4		D3		3
    DB  48,92,82,68,28		; 3/16		A5		E5		A4		C#3
    DB  16,88,0,64,28		; 1/16		G5				G4		C#3
    DB  64,84,0,60,30		; 1/4		F5				F4		D3		4
    DB  64,68,0,60,30		; 1/4		A4				F4		D3
    DB  64,72,64,60,40		; 1/4		B4		G4		F4		G3
    DB  128,74,64,58,50		; 1/2		C5		G4		E4		C4		5
    DB  32,74,0,0,50		; 1/8		C5						C4
    DB  32,74,0,0,50		; 1/8		C5						C4
    DB  96,92,84,68,36		; 3/8		A5		F5		A4		F3		6
    DB  32,88,0,64,40		; 1/8		G5				G4		G3
    DB  64,84,0,60,44		; 1/4		F5				F4		A3
    DB  128,82,74,64,50		; 1/2		E5		C5		G4		C4		7
    DB  48,78,70,0,46		; 3/16		D5		B#4				B#3
    DB  15,82,74,64,46		; 1/16		E5		C5		G4		B#3
    DB  64,84,74,68,44		; 1/4		F5		C5		A4		A3		8
    DB  64,84,0,0,60		; 1/4		F5						F4
    DB  64,74,0,0,50		; 1/4		C5						C4
    DB  64,68,0,0,44		; 1/4		A4						A3		9
    DB  64,60,0,0,36		; 1/4		F4						F3
    DB  48,74,0,0,50		; 3/16		C5						C4
    DB  16,68,0,0,44		; 1/16		A4						A3
    DB  64,60,0,0,36		; 1/4		F4						F3		10
    DB  64,68,0,0,36		; 1/4		A4						F3
    DB  64,74,0,0,34		; 1/4		C5						E3
    DB  128,84,78,68,30		; 1/2		F5		D5		A4		D3		11
    DB  48,92,82,68,28		; 3/16		A5		E5		A4		C#3
    
    DB  16,88,0,64,28		; 1/16		G5				G4		C#3
    DB  64,84,0,60,30		; 1/4		F5				F4		D3		12
    DB  64,68,0,60,30		; 1/4		A4				F4		D3
    DB  64,72,64,60,40		; 1/4		B4		G4		F4		G3
    DB  128,74,64,58,50		; 1/2		C5		G4		E4		C4		13
    DB  32,74,0,0,50		; 1/8		C5						C4
    DB  32,74,0,0,50		; 1/8		C5						C4
    DB  96,92,84,68,36		; 3/8		A5		F5		A4		F3		14
    DB  32,88,0,64,40		; 1/8		G5				G4		G3
    DB  32,84,0,60,44		; 1/8		F5				F4		A3
    DB  128,82,74,64,50		; 1/2		E5		C5		G4		C4		15
    DB  48,78,70,0,46		; 3/16		D5		B#4				B#3
    DB  16,82,74,64,46		; 1/16		E5		C5		G4		B#3
    DB  64,84,74,68,44		; 1/4		F5		C5		A4		A3		16
    DB  64,84,0,0,60		; 1/4		F5						F4
    DB  64,74,0,0,50		; 1/4		C5						C4
    DB  64,68,0,0,44		; 1/4		A4						A3		17
    DB  64,60,0,0,36		; 1/4		F4						F3
    
    DB  48,92,84,68,40		; 3/16		A5		F5		A4		G3
    DB  16,92,84,68,40		; 1/16		A5		F5		A4		G3
    DB  64,92,84,68,36		; 1/4		A5		F5		A4		F3		18
    DB  64,94,84,70,40		; 1/4		B#5		F5		B#4		G3
    DB  64,98,84,74,44		; 1/4		C6		F5		C5		A3
    DB  128,98,84,74,44		; 1/2		C6		F5		C5		A3		19
    DB  32,94,84,70,40		; 1/8		B#5		F5		B#4		G3
    DB  32,92,84,68,44		; 1/8		A5		F5		A4		A3
    DB  64,88,82,64,50		; 1/4		G5		E5		G4		C4		20
    DB  64,92,84,68,60		; 1/4		A5		F5		A4		F4
    DB  64,94,82,70,64		; 1/4		B#5		E5		B#4		G4
    DB  128,94,88,70,26		; 1/2		B#5		G5		B#4		C3		21
    DB  64,94,82,70,26		; 1/4		B#5		E5		B#4		C3
    DB  96,92,74,68,36		; 3/8		A5		C5		A4		F3		22
    DB  32,88,74,64,40		; 1/8		G5		C5		G4		G3
    DB  64,84,74,60,44		; 1/4		F5		C5		F4		A3
    DB  128,82,74,64,50		; 1/32		E5		C5		G4		C4		23
    DB  32,78,0,54,46		; 1/8		D5				D4		B#3
    DB  32,82,74,58,46		; 1/8		E5		C5		E4		B#3
    DB  64,84,74,60,44		; 1/4		F5		C5		F4		A3		24
    DB  64,68,60,0,54		; 1/4		A4		F4				D4
    
    DB  64,72,64,60,40		; 1/4		B4		G4		F4		G3
    DB  128,74,64,58,26		; 1/2		C5		G4		E4		C3		25
    DB  64,74,0,0,50		; 1/4		C5						C4
    DB  64,84,74,68,36		; 1/4		F5		C5		A4		F3		26
    DB  64,84,70,64,40		; 1/4		F5		B#4		G4		G3
    DB  32,84,74,68,44		; 1/8		F5		C5		A4		A3
    DB  32,82,74,68,44		; 1/8		E5		C5		A4		A3
    DB  64,78,70,60,46		; 1/4		D5		B#4		F4		B#3		27
    DB  64,78,70,60,46		; 1/4		D5		B#4		F4		B#3
    DB  64,78,74,62,44		; 1/4		D5		C5		F#4		A3
    DB  64,88,70,64,40		; 1/4		G5		B#4		G4		G3		28
    DB  32,94,70,0,40		; 1/8		B#5		B#4				G3
    DB  32,92,68,0,44		; 1/8		A5		A4				A3
    DB  32,88,64,0,46		; 1/8		G5		G4				B#3
    
    DB  32,84,60,0,48		; 1/8		F5		F4				B3
    DB  64,84,74,68,50		; 1/4		F5		C5		A4		C4		29
    DB  64,82,74,64,26		; 1/4		E5		C5		G4		C3
    DB  32,74,0,0,50		; 1/8		C5						C4
    DB  32,74,0,0,46		; 1/8		C5						B#3
    DB  96,84,74,68,44		; 3/8		F5		C5		A4		A3		30
    DB  32,88,0,64,50		; G5				G4		C4
    DB  32,92,0,68,64		; 1/8		A5				A4		G4
    DB  32,94,0,70,64		; 1/8		B#5				B#4		G4
    DB  128,98,92,84,68		; 1/2		C6		A5		F5		A4		31
    DB  32,84,78,68,54		; 1/8		F5		D5		A4		D4
    DB  32,88,72,64,52		; 1/8		G5		B4		G4		D#4
    DB  96,92,84,74,50		; 3/8		A5		F5		C5		C4		32
    DB  32,94,84,78,50		; 1/8		B#5		F5		D5		C4
    DB  64,88,82,70,50		; 1/4		G5		E5		B#4		C4
    DB  128,84,74,68,60		; 1/2		F5		C5		A4		F4		33
    ;
    DB  0					; END OF PIECE

; =============================================================

	; Data space - follows after code...
	
	; but aligned...
	;
	ORG	($+255) AND 0FF00H

RAM:
WS:
    DS      2               ; + 0 and + 1.
    DS      2               ; + 2 and + 3.
    DS      2               ; + 4 and + 5.
    DS      2               ; + 6 and + 7.
    DS      2               ; + 8 and + 9.
    DS      2               ; +10 and +11.
    DS      2               ; +12 and +13.
    DS      2               ; +14 and +15.

    IF USEUNDOC
    ELSE
    IYL EQU 16
    IYH EQU 17
    ENDIF
    
TOS EQU RAM + K2
V1FC    EQU RAM + 0 		; Voice 1 Fractional Constant.
V1IC    EQU RAM + 1 		; Voice 1 Integer    Constant.
V2FC    EQU RAM + 2 		; Voice 2 Fractional Constant.
V2IC    EQU RAM + 3 		; Voice 2 Integer    Constant.
V3FC    EQU RAM + 4 		; Voice 3 Fractional Constant.
V3IC    EQU RAM + 5 		; Voice 3 Integer    Constant.
V4FC    EQU RAM + 6 		; Voice 4 Fractional Constant.
V4IC    EQU RAM + 7 		; Voice 4 Integer    Constant.
    END
    
    
