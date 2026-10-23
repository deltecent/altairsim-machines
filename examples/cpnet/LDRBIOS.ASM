;	MP/M II Loader BIOS for the MITS Altair 8800
;	(a CP/M 2.2 BIOS that MPMLDR uses to read MPM.SYS)
;
;	88-DCDD	8" floppy controller at 08h, drive 0 (A:) only
;	88-2SIO	console on port A (10h/11h)
;
;	The skeleton is DRI's LDRBIOS.ASM from the MP/M II 2.1
;	distribution, disk 2. The 88-DCDD routines are from Mike
;	Douglas's CP/M 2.2b v2.3 BIOS for the Altair 8" floppy
;	(altairsim: disks/mits-88dcdd/cpm22/buffered/BIOS.ASM), cut down to
;	reads of drive 0. The loader never writes to the disk.
;
;	READ reads a whole track into a track buffer, as the CP/M BIOS
;	and the XIOS do. The skew of the disk puts each record 8
;	sectors after the one before it, so a read of one sector at a
;	time gets 4 records in a turn of the disk. The track buffer
;	gets all 32 in about one turn.
;
;	The track buffer is at 2000h-311Fh, above MPMLDR (0100h-1AFFh).
;	BOOT puts its own track buffer there too. MPMLDR loads MP/M II
;	at its final address, which is 6800h or higher on these disks,
;	and uses no other memory between 1B00h and the system.
;
;	Assemble with ASM, then patch into MPMLDR.COM with DDT:
;	   DDT MPMLDR.COM / ILDRBIOS.HEX / R / G0 / SAVE 26 MPMLDR.COM
;
;	The code assumes a 2 MHz 8080: the 88-DCDD read loop and the
;	delay routine count cycles.
;
;	Revision history
;	1.0  23 October 2026  P. Linstruth
;	     First version

false	equ	0
true	equ	not false

bios	equ	1700h		; the loader's BIOS is at 1700h

	org	bios

;	jump vector for individual routines

	jmp	boot
wboote:	jmp	wboot
	jmp	const
	jmp	conin
	jmp	conout
	jmp	list
	jmp	punch
	jmp	reader
	jmp	home
	jmp	seldsk
	jmp	settrk
	jmp	setsec
	jmp	setdma
	jmp	read
	jmp	write
	jmp	listst		; list status poll
	jmp	sectran		; sector translation

;	88-2SIO port A (6850 ACIA)

ctl0	equ	10h		; control/status
data0	equ	11h		; data
rdrf	equ	01h		; status: receive data register full
tdre	equ	02h		; status: transmit data register empty

;	88-DCDD disk controller

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

;	8" floppy

NUMTRK	equ	77		;number of tracks on the disk
NUMSEC	equ	32		;sectors per track
DATATRK	equ	6		;1st data format track
SECMASK	equ	1Fh		;five bit sector numbers
SSECLEN	equ	133		;Altair system sector length
DSECLEN	equ	136		;Altair data sector length
SYSDATA	equ	3		;offset of 128 byte data payload, tracks 0-5
DATDATA	equ	7		;offset of 128 byte data payload, tracks 6-76
TSECLEN	equ	DSECLEN+1	;length of a sector in trkBuf: a flag byte first
CSECLEN	equ	128		;CP/M sector length
RDTRIES	equ	6		;revolutions to try before a restore
UNDEF	equ	0FFh		;undefined value
trkBuf	equ	2000h		;track buffer, NUMSEC*TSECLEN bytes

boot:
wboot:
	ret

;	console

const:	in	ctl0
	ani	rdrf
	rz
	mvi	a,0ffh
	ret

conin:	call	const
	jz	conin
	in	data0
	ani	7fh
	ret

conout:	in	ctl0
	ani	tdre
	jz	conout
	mov	a,c
	out	data0
	ret

;	no list, punch or reader

list:
punch:
	ret

reader:	mvi	a,1ah		; end of file
	ret

listst:	xra	a		; never ready
	ret

;	disk

seldsk:	lxi	h,0		; only drive 0
	mov	a,c
	ora	a
	rnz
	lxi	h,dph
	ret

home:	mvi	c,0
settrk:	mov	a,c
	sta	trkNum
	ret

setsec:	mov	a,c		; 1-indexed sector from sectran
	dcr	a		; to zero indexed
	sta	secNum
	ret

setdma:	mov	h,b
	mov	l,c
	shld	dmaAddr
	ret

sectran:
	xchg			;HL->translate table
	mvi	b,0
	dad	b
	mov	l,m		;L=translated sector
	mov	h,b
	ret

write:	mvi	a,1		; the loader never writes
	ret

;----------------------------------------------------------------------------
; read - read the sector at trkNum/secNum into (dmaAddr). Read its track
;    into trkBuf first if trkBuf holds a different track.
;    Return A=0 if the sector was read, A=1 if not.
;----------------------------------------------------------------------------
read:	call	dSel		;select drive 0, load the head
	lda	trkNum
	lxi	h,bfTrack
	cmp	m		;the track in trkBuf?
	jz	rdMove		;yes
	call	readTrk		;no, read it
	mvi	a,1
	rnz			;the track could not be read

rdMove:	call	altSkew		;A=hard sector
	call	dSecAdr		;HL->its slot in trkBuf
	mov	a,m		;A=sector flag byte
	ora	a
	mvi	a,1
	rnz			;the sector could not be read

	lxi	d,DATDATA+1	;DE=offset to the data of a data track sector
	lda	trkNum
	cpi	DATATRK
	jnc	rdMv1
	lxi	d,SYSDATA+1	;DE=offset to the data of a system track sector
rdMv1:	dad	d		;HL->data
	xchg			;DE->data
	lhld	dmaAddr		;HL->destination
	mvi	b,CSECLEN
rdMvLp:	ldax	d
	mov	m,a
	inx	h
	inx	d
	dcr	b
	jnz	rdMvLp
	xra	a		;A=0, sector read
	ret

;----------------------------------------------------------------------------
; readTrk - read track trkNum into trkBuf. Read the sectors in the order
;    they come under the head. Try RDTRIES revolutions, then restore to
;    track 0, seek and try RDTRIES revolutions again. A sector that was
;    not read keeps a non-zero flag byte.
;
; On Exit
;    Zero true if the sectors were read (good or bad), zero false if no
;    sector pulse came
;    Clobbers all
;----------------------------------------------------------------------------
readTrk:
	mvi	a,UNDEF		;trkBuf holds no track
	sta	bfTrack
	mvi	a,2		;two seeks
	sta	tries

rtRtry:	call	dSeek		;to trkNum
	call	initTrk		;mark every sector as not read
	lxi	d,RDTRIES*NUMSEC*256 + NUMSEC
				;D=sectors to pass, RDTRIES revolutions
				;E=sectors left to read

rtLoop:	call	dNxtSec		;(17) wait for the next sector, HL->slot
	jnz	rtRead		;sector pulse found
	inr	a		;no sector pulse: non-zero
	ret

rtRead:	mov	a,m		;A=sector flag byte
	ora	a		;this sector already read?
	jz	rtNext		;yes, skip it

	push	h		;save the slot address
	inx	h		;HL->1st byte of the sector
	call	dRead		;read the sector
	pop	h		;(10) restore the slot address
	jnz	rtNext		;(10) read error

	xra	a		;(4) set the flag byte to zero (good)
	mov	m,a		;(7)

	dcr	e		;(5) decrement sectors left to read
	jz	rtExit		;(10) all sectors read

rtNext:	dcr	d		;(5) decrement sectors to pass
	jnz	rtLoop		;(10) read the next sector

	lxi	h,tries		;restore, seek and try again?
	dcr	m
	jz	rtExit		;no, keep the sectors that were read
	mvi	a,UNDEF		;forget the track: dSeek restores
	sta	curTrk
	jmp	rtRtry

rtExit:	lda	trkNum		;trkBuf holds trkNum
	sta	bfTrack
	xra	a		;zero true
	ret

;----------------------------------------------------------------------------
; initTrk - set the flag byte of each sector in trkBuf to UNDEF: not read.
;----------------------------------------------------------------------------
initTrk:
	lxi	b,UNDEF*256 + NUMSEC ;B=UNDEF (not read), C=NUMSEC
	lxi	h,trkBuf	;HL->track buffer
	lxi	d,TSECLEN	;DE=length of each sector in trkBuf
itLoop:	mov	m,b		;mark the sector as not read
	dad	d		;HL->next sector in trkBuf
	dcr	c
	jnz	itLoop
	ret

;----------------------------------------------------------------------------
; altSkew - return in A the hard sector for secNum on track trkNum.
;    Tracks 0-5, the same sector. Tracks 6-76, (secNum * 17) MOD 32: an
;    even sector stays the same, and an odd sector has bit 4 swapped.
;    Clobbers A,B
;----------------------------------------------------------------------------
altSkew:
	lda	trkNum		;on a data track?
	cpi	DATATRK
	lda	secNum		;A=sector
	rc			;system track, no change

	mov	b,a
	rrc			;even or odd?
	mov	a,b
	rnc			;even, no change
	xri	10h		;odd, swap bit 4
	ret

;---------------------------------------------------------------------------
; dNxtSec - wait for the next (any) sector. Return to the caller at 78
;    cycles (39us).
;
; On Exit
;    HL->slot of the sector in trkBuf, zero false
;    Zero true if no sector pulse came in 1.4s
;    Clobbers A,B,C,H,L
;---------------------------------------------------------------------------
dNxtSec:
	lxi	b,0		;1.4s timeout

dnLoop:	dcx	b		;decrement the 1.4s timer
	mov	a,b		;test for zero
	ora	c
	rz			;exit on timeout (zero=error)

	in	DRVSEC		;read sector position register
	rar			;wait for sector true (0=true)
	jc	dnLoop

	ani	SECMASK		;(7) get sector number alone
				;fall into dSecAdr

;---------------------------------------------------------------------------
; dSecAdr - return HL->the slot in trkBuf of the hard sector in A.
;    Return zero false.
;    Clobbers A,B,C,H,L
;---------------------------------------------------------------------------
dSecAdr:
	lxi	h,secAddr  	;(10) HL->sector address table
	mvi	b,0		;(7) form BC=sector*2
	rlc			;(4) A=sector*2 (2 bytes per table entry)
	mov	c,a		;(5) BC=sector*2
	dad	b		;(10) HL->address table entry for passed sector

	mov	a,m		;(7) A=lsb of sector buffer address
	inx	h		;(5)
	mov	h,m		;(7) H=msb of sector buffer address
	mov	l,a		;(5) HL->sector buffer

	ora	h		;(4) force non-zero return status (good)
	ret			;(11)

;----------------------------------------------------------------------------
; dSel - select drive 0 and load the head
;----------------------------------------------------------------------------
dSel:	xra	a		;select drive 0
	out	DRVSLCT
	in	DRVSTAT		;selected and enabled?
	ani	sDSKEN
	jnz	dSel		;not yet (0=true)
	mvi	a,cHDLOAD
	out	DRVCMD
	ret

;----------------------------------------------------------------------------
; dSeek - step from curTrk to trkNum. If curTrk is UNDEF, step out to
;    track 0 first.
;----------------------------------------------------------------------------
dSeek:	lda	curTrk
	cpi	UNDEF
	jnz	skGo

	mvi	c,NUMTRK+10	;C=maximum number of step outs to try
skHome:	in	DRVSTAT		;at track 0?
	ani	sTRACK0
	jz	skAt0		;yes (0=true)
	mvi	b,cSTEPO
	call	dStep
	dcr	c
	jnz	skHome
skAt0:	xra	a
	sta	curTrk
	mvi	a,200		;20ms before the next step
	call	delay

skGo:	lxi	h,trkNum
	lda	curTrk
	cmp	m
	rz			;on the track
	jc	skIn		;curTrk < trkNum: step in
	dcr	a
	mvi	b,cSTEPO
	jmp	skDo
skIn:	inr	a
	mvi	b,cSTEPI
skDo:	sta	curTrk
	call	dStep
	jmp	skGo

; dStep - wait until the head may move, then step it. B = step command.

dStep:	in	DRVSTAT
	ani	sMOVEOK
	jnz	dStep		;not yet (0=true)
	mov	a,b
	out	DRVCMD
	ret

; delay - delay for A x 100us. Clobbers A,B.

delay:	mvi	b,(200/20)	;20 cycles in the loop below
delayLp:
	mov	b,b		;(5) delay 5 cycles
	dcr	b		;(5)
	jnz	delayLp		;(10)
	dcr	a		;decrement 100us counter
	jnz	delay
	ret

;---------------------------------------------------------------------------
; dRead - Read a sector to (HL), verify checksum, stop byte, and track
;    number. From the CP/M BIOS: see its timing notes.
;
; On Entry
;    Drive is selected, sector true just detected
;    HL->sector buffer
;
; On Exit
;    Zero true if no error, Zero false for checksum error, missing
;	FF stop byte, or track number error
;    Clobbers A,B,C,H,L
;---------------------------------------------------------------------------
dRead:	push	h		;(11) save pointer to start of sector

	lxi	b,256+DSECLEN	;(10) B=chksum (-FF), C=bytes to read
	lda	curTrk		;(13) A=track we're on
	cpi	DATATRK		;(7) data track or system track?
	jnc	drSecWt		;(10) data track, length in C is correct

	mvi	c,SSECLEN	;(7) C=length of a system sector

drSecWt:
	in	DRVSTAT		;(10) get drive status byte
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

drSecDn:
	lda	curTrk		;(10) A=track we're supposed to be on
	cpi	DATATRK		;(7) system or data track?
	jnc	drDatTk		;(10) data track

	mov	a,b		;(5) A=calculated checksum over all bytes
	dcx	h		;(5) HL->checksum in sector
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
	jmp	drExit		;(10) do common compares and exit

drDatTk:
	dcx	h		;(5) HL->stop byte
	mov	a,m		;(7) A=stop byte
	pop	h		;(10) restore HL->start of buffer
	inr	a		;(4) was FF stop byte there?
	rnz			;(5/11) no, return error

	mov	a,b		;(5) A=calculated checksum over all bytes
	mov	c,m		;(7) C=track number from disk
	sub	c		;(4) take track out of checksum

	inx	h		;(5) HL->sector number
	sub	m		;(7) take out of checksum

	inx	h		;(5) move to checksum byte
	inx	h		;(5)
	inx	h		;(5) HL->checksum

	sub	m		;(7) subtract from checksum
drExit:	sub	m		;(7) checksums match?
	rnz			;(5/11) no, exit with error

	lda	curTrk		;(10) A=track we should be on
	ori	80h		;(7) set sync bit
	cmp	c		;(4) same track as from sector?
	ret			;(11) exit with compare status

;	disk tables: the same disk as the CP/M 2.2 BIOS

dph:	dw	tranTbl,0000h	;translate table
	dw	0000h,0000h	;scratch area
	dw	dirbuf,dpb	;dir buff, parm block
	dw	csv0,alv0	;check, alloc vectors

dpb:	dw	NUMSEC		;sectors per track
	db	4		;block shift (2K blocks)
	db	0Fh		;block mask
	db	0		;extent mask
	dw	149		;disk size-1
	dw	63		;directory max
	db	0C0h		;alloc0
	db	0		;alloc1
	dw	16		;check size
	dw	2		;offset

tranTbl:
	db	01,09,17,25,03,11,19,27,05,13,21,29,07,15,23,31
	db	02,10,18,26,04,12,20,28,06,14,22,30,08,16,24,32

curTrk:	db	UNDEF		;track the head is on, UNDEF = not known
bfTrack:
	db	UNDEF		;track in trkBuf, UNDEF = none

; secAddr - the address of each hard sector in trkBuf

secAddr:
	dw	trkBuf+00*TSECLEN,trkBuf+01*TSECLEN,trkBuf+02*TSECLEN
	dw	trkBuf+03*TSECLEN,trkBuf+04*TSECLEN,trkBuf+05*TSECLEN
	dw	trkBuf+06*TSECLEN,trkBuf+07*TSECLEN,trkBuf+08*TSECLEN
	dw	trkBuf+09*TSECLEN,trkBuf+10*TSECLEN,trkBuf+11*TSECLEN
	dw	trkBuf+12*TSECLEN,trkBuf+13*TSECLEN,trkBuf+14*TSECLEN
	dw	trkBuf+15*TSECLEN,trkBuf+16*TSECLEN,trkBuf+17*TSECLEN
	dw	trkBuf+18*TSECLEN,trkBuf+19*TSECLEN,trkBuf+20*TSECLEN
	dw	trkBuf+21*TSECLEN,trkBuf+22*TSECLEN,trkBuf+23*TSECLEN
	dw	trkBuf+24*TSECLEN,trkBuf+25*TSECLEN,trkBuf+26*TSECLEN
	dw	trkBuf+27*TSECLEN,trkBuf+28*TSECLEN,trkBuf+29*TSECLEN
	dw	trkBuf+30*TSECLEN,trkBuf+31*TSECLEN

;	uninitialized data. It may lie above 1A00h: it is not saved
;	with MPMLDR.COM.

trkNum:	ds	1		;track number from settrk
secNum:	ds	1		;zero-indexed sector from setsec
dmaAddr:
	ds	2		;dma address from setdma
tries:	ds	1		;seeks left before an error
dirbuf:	ds	128		;directory access buffer
alv0:	ds	19
csv0:	ds	16

	end
