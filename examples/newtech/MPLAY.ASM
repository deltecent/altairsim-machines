;
; MICROPLAY REV. A -- NEWTECH COMPUTER SYSTEMS, INC., JUNE 1977
;
; FROM THE MODEL 6 MUSIC BOARD USERS MANUAL. PLAYS THE SCORE AT 100H
; THROUGH THE MODEL 6 AT PORT 24H. TIMED FOR AN 8080 AT 2 MHZ WITH
; NO WAIT STATES.
;
; THE SCORE IS THREE BYTES A NOTE: THE PITCH CONSTANT, THEN THE
; DURATION COUNT, LOW BYTE FIRST, WITH 1 ADDED TO THE HIGH BYTE.
; A ZERO PITCH ENDS THE SCORE, AND THE PROGRAM LOOPS AT HERE.
;
; THE PROGRAM WRITES THE NOTE INTO ITS OWN INSTRUCTIONS AT XFER1
; TO XFER4, SO IT MUST RUN IN RAM.
;
SCORE   EQU     0100H           ;START OF THE SCORE
MODL6   EQU     24H             ;MODEL 6 OUTPUT PORT
LNGTH   EQU     0               ;PATCHED WITH THE DURATION
PITCH   EQU     0               ;PATCHED WITH THE PITCH
;
        ORG     0
;
BEGIN:  LXI     SP,STACK
INIT:   LXI     H,SCORE
        SHLD    PLACE
NEXT:   LHLD    PLACE
        MVI     A,0
        CMP     M
HERE:   JZ      HERE            ;END OF SCORE: LOOP HERE
        MOV     A,M             ;PITCH
        STA     XFER2+1
        STA     XFER4+1
        INX     H
        MOV     A,M             ;DURATION LSB
        STA     XFER1+1
        STA     XFER3+1
        INX     H
        MOV     A,M             ;DURATION MSB
        STA     XFER1+2
        STA     XFER3+2
        INX     H
        SHLD    PLACE
        CALL    PLAY
        JMP     NEXT
;
PLAY:   LXI     H,TBL1          ;ENVELOPE POINTER
        MVI     E,8             ;SEGMENT COUNT
        MOV     A,M             ;STARTING AMPLITUDE
XFER1:  LXI     B,LNGTH         ;DURATION COUNT
LOOP2:  MOV     B,B             ;WASTE TIME
        JMP     XFER2
XFER2:  MVI     D,PITCH         ;PITCH CONSTANT
        OUT     MODL6           ;OUTPUT HALF WAVE
        INR     M               ;WASTE MUCH TIME
        DCR     M
        INR     M
        DCR     M
        INR     M
        DCR     M
LOOP3:  DCR     D               ;DELAY ACCORDING TO PITCH
        JNZ     LOOP3
        XRA     M               ;COMPLEMENT A.
        DCR     C               ;COUNT DOWN DURATION
        JNZ     LOOP2
        DCR     B
        JNZ     XFER2
        OUT     MODL6
        INX     H               ;NEXT SEGMENT
        DCR     E
        RZ                      ;ALL SEGMENTS DONE
XFER3:  LXI     B,LNGTH
XFER4:  MVI     D,PITCH
        MOV     A,M             ;NEW AMPLITUDE
        JMP     LOOP3
;
TBL1:   DB      095H,030H,0D0H,0FEH,0FFH,0FFH,030H,085H  ;ENVELOPE
PLACE:  DW      0               ;SCORE POINTER
STACK   EQU     $+10H
;
        END
