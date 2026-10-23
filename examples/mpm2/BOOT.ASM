;	MP/M II V2.1 cold start loader for the MITS Altair 8800
;	(88-DCDD 8" floppy, booted by the DBL PROM)
;
;	The DBL PROM loads sectors 0 and 2 of track 0 to 0000h-00FFh
;	and jumps to 0000h. This loader reads MPMLDR.COM (MPMLDR,
;	LDRBDOS and the LDRBIOS) from the rest of tracks 0 and 1 to
;	0100h and jumps to 0100h, as section 1.5 of the MP/M II System
;	Implementor's Guide asks. MPMLDR then loads MPM.SYS.
;
;	The read code is the cold boot loader of Mike Douglas's CP/M
;	2.2b v2.3 for the Altair 8" floppy (altairsim:
;	disks/mits-88dcdd/cpm22/buffered/BOOT.ASM), with these changes:
;
;	1) The load address is 0100h, not the CCP. The track buffer
;	   moves from 0100h to 2000h, above MPMLDR.
;	2) 005Ch-006Bh hold the blank FCB that the CCP gives a command
;	   with no parameters. MPMLDR reads 005Dh: a blank name loads
;	   MPM.SYS. MPMLDR reads the FCB at 006Ch only after a $B in
;	   the first (guide section 6), so code can go there.
;	3) The track, not the sector or the address, is in memory.
;	   The sector is in C and the address in HL. The loader must
;	   fit in 256 bytes.
;	4) Before it jumps to MPMLDR, the loader puts DI, HLT at 0000h.
;	   LDRBDOS jumps to 0000h after an error, and the machine halts.
;
;	Disk layout (SYSGEN image at 0900h):
;	   track 0, sectors 0 and 2	this loader (0900h, 0A00h)
;	   track 0, sector 3, to	MPMLDR.COM, 0100h-1AFFh
;	   track 1, sector 22		(0A80h-247Fh)
;
;	Assemble with ASM. Then, with MPMLDR.COM already patched:
;	   DDT MPMLDR.COM
;	   -M100,1AFF,3000	(MPMLDR to 0A80h, through 3000h:
;	   -M3000,49FF,A80	 the two areas overlap)
;	   -IBOOT.HEX
;	   -R900
;	   -M980,9FF,A00	(sector 2 gets the second half)
;	   -G0
;	   A>SYSGEN		(no source, destination drive)
;
;	The code assumes a 2 MHz 8080: the 88-DCDD read loop counts
;	cycles.
;
;	Revision history
;	1.0  23 October 2026  P. Linstruth
;	     First version

NUMSEC	equ	32		;sectors per track
SECMASK	equ	1Fh		;five bit sector numbers
STRTSEC	equ	3		;starting sector of MPMLDR on track 0
LDRPGS	equ	26		;pages of MPMLDR.COM (SAVE 26)
SECCNT	equ	LDRPGS*2	;sectors to read, 61 at most

LDRBASE	equ	0100h		;load and execution address of MPMLDR
TBPAGE	equ	20h		;track buffer page, 256 bytes a sector
STACK	equ	TBPAGE*256	;the stack grows down from the buffer

CSECLEN	equ	128		;CP/M sector length
SSECLEN	equ	133		;Altair system sector length
SYSDATA	equ	3		;offset of 128 byte data payload

; Altair disk controller

DRVSLCT	equ	08h		;drive select register (out)
DRVSTAT	equ	08h		;drive status register (in)
sMOVEOK	equ	02h		;OK to move head
sDSKEN	equ	08h		;disk is selected and enabled
sTRACK0	equ	40h		;on track zero flag
DRVCMD	equ	09h		;drive command register (out)
cSTEPI	equ	01h		;step in
cSTEPO	equ	02h		;step out
cHDLOAD	equ	04h		;head load
DRVSEC	equ	09h		;drive sector position (in)
DRVDATA	equ	0Ah		;drive read/write data (in/out)

;--------------------------------------------------------------------------
;  Entry point
;--------------------------------------------------------------------------
	org	0

start	di			;disable interrupts
	lxi	sp,STACK
	jmp	dSelLp

;----------------------------------------------------------------------------
; read - Read one sector of track trkNum.
;
; On Entry
;    C = sector number to read (0-31)
;    HL = address to read it to
;
; On Exit
;    HL = HL + CSECLEN
;    Clobbers all
;----------------------------------------------------------------------------
read	push	b		;save sector number
	push	h		;save destination
	call	readTrk		;fill track buffer if needed
	pop	h
	pop	b

	mov	a,c		;DE->data portion of sector C in trkBuf
	adi	TBPAGE
	mov	d,a
	mvi	e,SYSDATA+1

	mvi	b,CSECLEN	;B=number of bytes to move

mrLoop	ldax	d		;move sector from trkBuf to (HL)
	mov	m,a
	inx	h		;increment pointers
	inx	d
	dcr	b		;loop count
	jnz	mrLoop
	ret

;----------------------------------------------------------------------------
; readTrk- read full track into track buffer if the requested
;    track (trkNum) does not match the buffered track (bfTrack).
;    All sectors must read without error before it exits.
;----------------------------------------------------------------------------
readTrk	lda	trkNum		;A=requested track
	lxi	h,bfTrack	;HL->buffered track number
	cmp	m		;same track buffered?
	rz			;yes, already have this track

	mov	m,a		;update buffered track number
	jc	skpStep		;unknown track to track 0, skip step

	mvi	a,cSTEPI	;step in to next track (assume track
	out	DRVCMD		;   change is always by +1)

skpStep	lxi	h,(TBPAGE+NUMSEC)*256 ;HL->past the last sector of trkBuf

initLp	dcr	h		;preceding sector
	mov	m,h		;set sector flag false (non-zero)
	mov	a,h
	cpi	TBPAGE
	jnz	initLp

	mvi	e,NUMSEC	;E=sectors remaining to fill

rdLoop	in	DRVSEC		;wait for sector true (0=true)
	rar
	jc	rdLoop
	ani	SECMASK		;HL->sector in trkBuf
	adi	TBPAGE
	mov	h,a
	mvi	l,0

	mov	a,m		;A=sector flag byte
	ora	a		;this sector already read?
	jz	rdLoop		;yes, skip it
	jmp	rdSec		;the rest is past the FCB

;--------------------------------------------------------------------------
; The FCB at 005Ch, as the CCP leaves it for a command with no
; parameters
;--------------------------------------------------------------------------
	org	5Ch

	db	0,'           ',0,0,0,0

;--------------------------------------------------------------------------
; Select drive 0 (the DBL PROM deselects it), restore to track 0, and
; load MPMLDR
;--------------------------------------------------------------------------
dSelLp	xra	a		;select drive 0
	out	DRVSLCT

	in	DRVSTAT		;see if select worked
	ani	sDSKEN
	jnz	dSelLp		;not selected, try again

	mvi	a,cHDLOAD	;load head
	out	DRVCMD

seek0	in	DRVSTAT		;loop until OK to move the head
	ani	sMOVEOK
	jnz	seek0

	in	DRVSTAT		;see if we are at track 0
	ani	sTRACK0		;at track zero?
	jz	load		;yes, start the load process

	mvi	a,cSTEPO	;issue step out
	out	DRVCMD
	jmp	seek0

load	lxi	b,SECCNT*256+STRTSEC    ;B=# secs to read, C=start sec
	lxi	h,LDRBASE	;HL->MPMLDR load address
	xra	a		;start on track 0

trkLoop	sta	trkNum		;save track number to use

secLoop	push	b		;save sector count and number
	call	read		;read sector C to HL, and advance HL
	pop	b

	dcr	b		;decrement total sector count
	jz	done

	inr	c		;bump to next sector number
	mvi	a,NUMSEC	;A=number of sectors on a track
	sub	c		;all 32 sectors on the track done?
	jnz	secLoop		;no, read next sector

	mov	c,a		;start with C=sector 0 on next track
	lda	trkNum		;increment track number
	inr	a
	jmp	trkLoop

done	mvi	a,76h		;HLT after the DI at 0000h
	sta	1
	jmp	LDRBASE

;---------------------------------------------------------------------------
; rdSec - read the sector at HL+1, and mark it good in its flag byte at HL
;---------------------------------------------------------------------------
rdSec	push	h		;save sector address
	inx	h		;HL->1st read location in sector
	call	dRead		;read the sector
	pop	h		;restore sector address in HL
	jnz	rdLoop		;read error

	xra	a		;set sector flag to zero (good sector)
	mov	m,a

	dcr	e		;decrement sectors left to fill
	jnz	rdLoop		;loop until all sectors good
	ret

;---------------------------------------------------------------------------
; dRead - Read a sector, verify checksum, stop byte, and track number.
;    The checks run between the last byte of the sector and the next
;    sector, as in the CP/M loader.
;
; On Entry
;    Drive is selected, sector true just detected
;    HL->sector buffer
;
; On Exit
;    Zero true if no error, Zero false for checksum error, missing
;        FF stop byte, or track number error
;    Clobbers A,B,C,H,L
;---------------------------------------------------------------------------
dRead	push	h		;(11) save pointer to start of sector
	lxi	b,256+SSECLEN	;(10) B=chksum (-FF), C=bytes to read

drSecWt	in	DRVSTAT		;(10) get drive status byte
	ora	a		;(4) wait for NRDA flag true (zero)
	jm	drSecWt		;(10)

	in	DRVDATA		;(10) read first byte at 24-48 cycles
	mov	m,a		;(7) store in buffer
	add	b		;(4) update checksum
	mov	b,a		;(5) keep checksum in B
	inx	h		;(5) increment buffer pointer
	dcr	c		;(5) decrement byte count
	jz	drSecDn		;(10) exit if done

	in	DRVDATA		;(10) read at 70-94 cycles (data at 64 and 128)
	mov	m,a		;(7) store in buffer
	add	b		;(4) update checksum
	mov	b,a		;(5) keep checksum in B
	inx	h		;(5) increment buffer pointer
	dcr	c		;(5) decrement byte count
	jnz	drSecWt		;(10) repeat until done

drSecDn	dcx	h		;(5) HL->checksum in sector
	sub	m		;(7) subtract from computed checksum
	sub	m		;(7) final sum will be zero

	dcx	h		;(5) HL->stop byte
	mov	b,m		;(7) B=stop byte
	pop	h		;(10) restore HL->start of buffer
	inr	b		;(4) was FF stop byte there?
	rnz			;(5/11) no, return error

	mov	c,m		;(7) C=track number from disk
	sub	c		;(4) take track out of checksum

	inx	h		;(5) HL->2nd byte of sector
	sub	m		;(7) take out of checksum

	inx	h		;(5) HL->3rd byte of sector
	sub	m		;(7) sum should be zero here
	rnz			;(5/11) exit with error

	lda	trkNum		;(10) A=track we should be on
	ori	80h		;(7) set sync bit
	cmp	c		;(4) same track as from sector?
	ret			;(11) exit with compare status

;-------------------------------------------------------------------------
; Data Area
;-------------------------------------------------------------------------
bfTrack	db	0FFh		;currently buffered track (none)
trkNum	ds	1		;track number

	end
