	title	'MP/M II V2.1  Altair 88-DCDD, 88-2SIO, 88-VI/RTC XIOS'
	cseg
;
;	Resident (no bank switching) XIOS for MP/M II on a MITS
;	Altair 8800:
;
;	   88-DCDD	8" floppy controller at 08h, up to 4 drives
;	   88-2SIO	console 0 on port A (10h/11h),
;			console 1 on port B (12h/13h)
;	   88-VI/RTC	control port 0FEh. RTC from the 60 Hz line,
;			divide by 1, RI strapped to VI5 (RST 5, 0028h).
;
;	The structure (jump vectors, commonbase, polling, interrupt
;	handler, clock flags) is DRI's sample RESXIOS.ASM from the
;	MP/M II 2.1 distribution, disk 2. The 88-DCDD code is from
;	Mike Douglas's CP/M 2.2b v2.3 BIOS for the Altair 8" floppy
;	(altairsim: disks/mits-88dcdd/cpm22/buffered/BIOS.ASM), with these changes
;	for MP/M:
;
;	1) Every write goes to the disk before WRITE returns. MP/M II
;	   asks for a non-deferred write (type 1 or 3) on a drive with
;	   a directory check, so a deferred track flush on console input
;	   (as in the CP/M BIOS) is not allowed. WRITE puts the sector
;	   into the track buffer and writes that one sector at once,
;	   then reads it back if fWRTVFY is set in MODE. MODE starts
;	   with fWRTVFY clear. A read back waits one turn of the
;	   disk for each sector, and more than doubles the time of
;	   a write.
;	2) Interrupts are disabled only while one sector passes under
;	   the head. Between sectors they are enabled, so the RTC tick
;	   waits at most one sector time (5.2 ms).
;	3) The track buffer is forgotten on the first select of a drive
;	   after a disk reset (SELDSK with E bit 0 = 0).
;	4) WRITE selects the drive again before it writes a sector
;	   of a track that is already in the buffer. A program such
;	   as AFORMAT drives the controller itself, and can leave a
;	   different drive selected, or none.
;	5) If a seek reaches track 0 before it has stepped out as far
;	   as curTrk says, the head was lower than curTrk. dSeek seeks
;	   again from track 0. (AFORMAT leaves the head on track 0.)
;	6) The CP/M BIOS unloads the head in CONIN. Under MP/M II,
;	   CONIN can run while another process is between two sectors
;	   of a track. Here the tick unloads the head HDTIME ticks
;	   after the last READ or WRITE, and the count stops while
;	   READ or WRITE runs. As in the CP/M BIOS, the next READ or
;	   WRITE after an unload reads the track again, so a disk
;	   that was changed is read again.
;
;	The code assumes a 2 MHz 8080: the 88-DCDD byte loops and the
;	delay routine count cycles.
;
;	Revision history
;	1.0  23 October 2026  P. Linstruth
;	     First version
;	1.1  25 October 2026  P. Linstruth
;	     Unload the head 2 seconds after the last READ or WRITE
;	1.2  26 October 2026  P. Linstruth
;	     Write verify off by default
;
false	equ	0
true	equ	not false
;
;	jump vector for individual subroutines
;
	jmp	commonbase	; commonbase
wboot:
	jmp	warmstart	; warm start
	jmp	const		; console status
	jmp	conin		; console character in
	jmp	conout		; console character out
	jmp	list		; list character out
	jmp	rtnempty	; punch not implemented
	jmp	rtnempty	; reader not implemented
	jmp	home		; move head to home
	jmp	seldsk		; select disk
	jmp	settrk		; set track number
	jmp	setsec		; set sector number
	jmp	setdma		; set dma address
	jmp	read		; read disk
	jmp	write		; write disk
	jmp	pollpt		; list status
	jmp	sectran		; sector translate

	jmp	selmemory	; select memory
	jmp	polldevice	; poll device
	jmp	startclock	; start clock
	jmp	stopclock	; stop clock
	jmp	exitregion	; exit region
	jmp	maxconsole	; maximum console number
	jmp	systeminit	; system initialization
	db	0		; force use of internal dispatch @ idle
;
commonbase:
	 jmp	coldstart
swtuser: jmp	$-$
swtsys:  jmp	$-$
pdisp:   jmp	$-$
xdos:	 jmp	$-$
sysdat:  dw	$-$

coldstart:
warmstart:
	mvi	c,0
	jmp	xdos		; system reset, terminate process
;
;	XDOS functions used here
;
poll	equ	131	; XDOS poll function
flagset	equ	133	; XDOS flag set function
;
;
;  MP/M II V2.0   Console Bios
;
;
nmbcns	equ	2	; number of consoles

pllpt	equ	0	; poll printer
plco0	equ	1	; poll console out #0
plco1	equ	2	; poll console out #1
plci0	equ	3	; poll console in #0
plci1	equ	4	; poll console in #1

;
const:			; Console Status
	call	ptbljmp	; compute and jump to hndlr
	dw	pt0st	; console #0 status routine
	dw	pt1st	; console #1 status routine

conin:			; Console Input
	call	ptbljmp	; compute and jump to hndlr
	dw	pt0in	; console #0 input
	dw	pt1in	; console #1 input

conout:			; Console Output
	call	ptbljmp	; compute and jump to hndlr
	dw	pt0out	; console #0 output
	dw	pt1out	; console #1 output

;
ptbljmp:		; compute and jump to handler
			; d = console #
			; do not destroy d !
	mov	a,d
	cpi	nmbcns
	jc	tbljmp
	pop	psw	; throw away table address
rtnempty:
	xra	a
	ret
tbljmp:			; compute and jump to handler
			; a = table index
	add	a	; double table index for adr offst
	pop	h	; return adr points to jump tbl
	mov	e,a
	mvi	d,0
	dad	d	; add table index * 2 to tbl base
	mov	e,m	; get handler address
	inx	h
	mov	d,m
	xchg
	pchl		; jump to computed cns handler

;
; 88-2SIO port equates (6850 ACIA)
;
ctl0	equ	10h	; port A control/status
data0	equ	11h	; port A data
ctl1	equ	12h	; port B control/status
data1	equ	13h	; port B data
rdrf	equ	01h	; status: receive data register full
tdre	equ	02h	; status: transmit data register empty
sioRst	equ	03h	; control: master reset
sio8n2	equ	11h	; control: divide by 16, 8 data bits, 2 stop bits
;
; Console #0 (2SIO port A) status, input, output
;
pt0st:
polci0:			; return 0ffh if ready,
			;        000h if not
	in	ctl0
	ani	rdrf
	rz
	mvi	a,0ffh
	ret
;
pt0in:			; return character in reg A
	call	pt0st
	jnz	rx0rdy
	mvi	c,poll
	mvi	e,plci0
	call	xdos	; poll console #0 input
rx0rdy:
	in	data0
	ani	7fh	; strip parity bit
	ret
;
pt0out:			; Reg C = character to output
	in	ctl0
	ani	tdre
	jnz	tx0rdy
	push	b
	mvi	c,poll
	mvi	e,plco0
	call	xdos	; poll console #0 output
	pop	b
tx0rdy:
	mov	a,c
	out	data0
	ret
;
polco0:			; return 0ffh if ready,
			;        000h if not
	in	ctl0
	ani	tdre
	rz
	mvi	a,0ffh
	ret
;
; Console #1 (2SIO port B) status, input, output
;
pt1st:
polci1:			; return 0ffh if ready,
			;        000h if not
	in	ctl1
	ani	rdrf
	rz
	mvi	a,0ffh
	ret
;
pt1in:			; return character in reg A
	call	pt1st
	jnz	rx1rdy
	mvi	c,poll
	mvi	e,plci1
	call	xdos	; poll console #1 input
rx1rdy:
	in	data1
	ani	7fh	; strip parity bit
	ret
;
pt1out:			; Reg C = character to output
	in	ctl1
	ani	tdre
	jnz	tx1rdy
	push	b
	mvi	c,poll
	mvi	e,plco1
	call	xdos	; poll console #1 output
	pop	b
tx1rdy:
	mov	a,c
	out	data1
	ret
;
polco1:			; return 0ffh if ready,
			;        000h if not
	in	ctl1
	ani	tdre
	rz
	mvi	a,0ffh
	ret
;
; List device. This machine has no printer: the characters are
; dropped and the list device is always ready.
;
list:			; Reg C = Character to print
	ret
;
pollpt:			; return 0ffh if ready,
			;        000h if not
	mvi	a,0ffh
	ret
;
;
;  MP/M II V2.0   Xios
;
;
polldevice:
			; Reg C = device # to be polled
			; return 0ffh if ready,
			;        000h if not
	mov	a,c
	cpi	nmbdev
	jc	devok
	mvi	a,nmbdev; if dev # >= nmbdev,
			; set to nmbdev
devok:
	call	tbljmp	; jump to dev poll code

devtbl:
	dw	pollpt	; poll printer output
	dw	polco0	; poll console #0 output
	dw	polco1	; poll console #1 output
	dw	polci0	; poll console #0 input
	dw	polci1	; poll console #1 input
nmbdev	equ	($-devtbl)/2	; number of devices to poll
	dw	rtnempty; bad device handler
;
; Select / Protect Memory
;
selmemory:
			; Reg BC = adr of mem descriptor
			; BC ->  base   1 byte,
			;        size   1 byte,
			;        attrib 1 byte,
			;        bank   1 byte.
; this hardware does not have memory protection or
;  bank switching
	ret
;
; Start Clock
;
startclock:
			; will cause flag #1 to be set
			;  at each system time unit tick
	mvi	a,0ffh
	sta	tickn
	ret
;
; Stop Clock
;
stopclock:
			; will stop flag #1 setting at
			;  system time unit tick
	xra	a
	sta	tickn
	ret
;
; Exit Region
;
exitregion:
			; EI if not preempted or in dispatcher
	lda	preemp
	ora	a
	rnz
	ei
	ret
;
; Maximum Console Number
;
maxconsole:
	mvi	a,nmbcns
	ret
;
; 88-VI/RTC equates. One control port, write only.
;
vicmd	equ	0feh	; control port
viOn	equ	80h	; bit 7: enable the vectored interrupt structure
rtcOn	equ	40h	; bit 6: enable the RTC interrupt
rtcDiv	equ	20h	; bit 5: clear the RTC divider
rtcClr	equ	10h	; bit 4: clear the RTC interrupt flip-flop
			; bit 3 = 0: current-level compare off, so any
			;  level may interrupt. MP/M handlers never nest.
rtcRst	equ	28h	; RST 5 address: RI is strapped to VI5
;
; System Initialization
;
systeminit:
;
;  This is the place to insert code to initialize
;  the time of day clock, if it is desired on each
;  booting of the system.
;
	mvi	a,0c3h
	sta	rtcRst
	lxi	h,inthnd
	shld	rtcRst+1	; JMP INTHND at 0028H

	mvi	a,sioRst	; reset both 2SIO ports
	out	ctl0
	out	ctl1
	mvi	a,sio8n2	; 8N2, no 2SIO interrupts
	out	ctl0
	out	ctl1

	mvi	a,viOn+rtcOn+rtcDiv+rtcClr
	out	vicmd		; VI and RTC on, divider at time zero
	ret			; MP/M II enables interrupts

;
;  MP/M II V2.0   Interrupt Handlers
;

inthnd:
			; Interrupt handler entry point
			;  The only interrupt is the RTC, on
			;  RST 5. Location 0028H contains a
			;  jmp to INTHND.
	shld	svdhl
	pop	h
	shld	svdret
	push	psw
	lxi	h,0
	dad	sp
	shld	svdsp		; save users stk ptr
	lxi	sp,lstintstk	; lcl stk for intr hndl
	push	d
	push	b

	mvi	a,0ffh
	sta	preemp	; set preempted flag

				; 60 Hz clock interrupt
	mvi	a,viOn+rtcOn+rtcClr
	out	vicmd		; clear the RTC flip-flop
	mvi	a,viOn+rtcOn
	out	vicmd		; and let it set again

	lxi	h,hdTmr
	mov	a,m
	ora	a		; head unload count running?
	jz	nohdun
	dcr	m
	jnz	nohdun
	mvi	a,cHDUNLD	; HDTIME ticks with no disk I/O:
	out	DRVCMD		;  unload the head
	mvi	a,0ffh
	sta	hdOff
nohdun:
	lda	tickn
	ora	a		; test tickn, indicates
				;  delayed process(es)
	jz	notickn
	mvi	c,flagset
	mvi	e,1
	call	xdos		; set flag #1 each tick
notickn:
	lxi	h,cnt60
	dcr	m		; dec 60 tick cntr
	jnz	intdone
	mvi	m,60
	mvi	c,flagset
	mvi	e,2
	call	xdos		; set flag #2 @ 1 sec

intdone:
	xra	a
	sta	preemp	; clear preempted flag
	pop	b
	pop	d
	lhld	svdsp
	sphl			; restore stk ptr
	pop	psw
	lhld	svdret
	push	h
	lhld	svdhl
; The following dispatch call will force round robin
;  scheduling of processes executing at the same priority
;  each 1/60th of a second.
; Note: Interrupts are not enabled until the dispatcher
;  resumes the next process.  This prevents interrupt
;  over-run of the stacks when stuck or high frequency
;  interrupts are encountered.
	jmp	pdisp		; MP/M dispatch

;****************************************************************************
;
;	Disk I/O Drivers: 88-DCDD
;
;****************************************************************************

;-----------------------------
;  8" floppy equates
;-----------------------------
NUMTRK	equ	77		;number of tracks on the disk
NUMSEC	equ	32		;sectors per track
DATATRK	equ	6		;1st data format track
SECMASK	equ	1Fh		;five bit sector numbers

BSH	equ	4		;allocation block shift factor
BLM	equ	0Fh		;allocation block mask
EXM	equ	0		;extent mask
DSM	equ	149		;max block number (150 blocks of 2K bytes)
DRM	equ	63		;max directory entry number (64 entries)
AL0	equ	0C0h		;directory allocation block bits byte 0
AL1	equ	0		;directory allocation block bits byte 1
RESTRK	equ	2		;reserved tracks for boot image
CKS	equ	(DRM+1)/4	;directory check space

;-----------------------------
; Common disk parameters
;-----------------------------
NUMDISK	equ	4		;four drives supported
CSECLEN	equ	128		;CP/M sector length
SSECLEN	equ	133		;Altair system sector length
DSECLEN	equ	136		;Altair data sector length
TSECLEN	equ	DSECLEN+1	;length of sector in track table

; System tracks (0-5) sector format

SYSDATA	equ	3		;offset of 128 byte data payload

; Data tracks (6-76) sector format

DATDATA	equ	7		;offset of 128 byte data payload

;-----------------------------
; Altair disk controller
;-----------------------------
DRVSLCT	equ	08h		;drive select register (out)
cDSLCT	equ	80h		;deselect drive

DRVSTAT	equ	08h		;drive status register (in)
sENWD	equ	01h		;enter new write data flag
sMOVEOK	equ	02h		;OK to move head
sHDSTAT	equ	04h		;head status flag
sDSKEN	equ	08h		;disk is selected and enabled
sINTEN	equ	20h		;processor interrupts enabled
sTRACK0	equ	40h		;on track zero flag
sNRDA	equ	80h		;new read data available

DRVCMD	equ	09h		;drive command register (out)
cSTEPI	equ	01h		;step in
cSTEPO	equ	02h		;step out
cHDLOAD	equ	04h		;head load
cHDUNLD	equ	08h		;head unload
cINTEN	equ	10h		;interrupt enable
cINTDIS	equ	20h		;interrupt disable
cHCSON	equ	40h		;reduce head current switch
cWRTEN	equ	80h		;write enable

DRVSEC	equ	09h		;drive sector position (in)
sNEWSEC	equ	01h		;new sector flag (sector true)

DRVDATA	equ	0Ah		;drive read/write data (in/out)

;-----------------------------
; Misc equates
;-----------------------------
RDTRIES	equ	6		;read tries (must be <= 8)
WRTRIES	equ	3		;sector writes to try
UNDEF	equ	0FFh		;undefined value

fWRTVFY	equ	40h		;MODE bit: read back each sector written

HDTIME	equ	120		;ticks without READ or WRITE before the
				;   tick unloads the head (2 seconds)

;----------------------------------------------------------------------------
; home - Home BIOS entry. Set trkNum to zero. No drive activity takes place.
;----------------------------------------------------------------------------
home:	xra	a		;set trkNum to zero
	sta	trkNum
	ret

;----------------------------------------------------------------------------
; selDsk - Select Disk BIOS entry. C contains the disk number to select.
;    Validate the disk number and return a pointer to the disk parameter
;    header in HL. Zero is returned in HL for invalid drive number. The
;    disk number is stored in drvNum. No drive activity takes place.
;
; On Entry
;    C = disk number to select
;    E bit 0 = 0 if this is the first select since the drive was reset
;
; On Exit
;    drvNum = disk number to select
;    Success: HL->DPH for this drive. Error: HL=0
;    Clobbers A,D,E,H,L
;----------------------------------------------------------------------------
selDsk:	lxi	h,0		;init HL=0 for invalid drive request
	mov	a,c		;A=drive number
	cpi	NUMDISK		;verify drive number less than number of disks
	rnc			;invalid drive number, return with HL=0=error

	sta	drvNum		;save new drive number

	mov	a,e		;first select since a disk reset?
	rar
	jc	sdDph		;no, keep the track buffer

	lxi	h,bfDrive	;HL->drive in the track buffer
	mov	a,c
	cmp	m		;the drive being logged in?
	jnz	sdDph		;no

	mvi	m,UNDEF		;yes, the disk may have changed: forget it

sdDph:	mov	a,c		;compute disk parameter header address
	rlc			;   as (16*drvNum) + dpHead
	rlc
	rlc
	rlc			;A=16*drvNum

	lxi	h,dpHead  	;HL->start of disk parameter headers
	mov	e,a
	mvi	d,0
	dad	d		;HL->DPH for the passed drive number
	ret

;----------------------------------------------------------------------------
; setTrk - Set Track BIOS entry. C contains the desired track number.
;----------------------------------------------------------------------------
setTrk:	mov	a,c		;save track number passed in C
	sta	trkNum
	ret

;----------------------------------------------------------------------------
; setSec - Set Sector BIOS entry. C contains the 1-indexed CPM physical
;   sector. Saved in secNum as a zero-indexed value.
;----------------------------------------------------------------------------
setSec:	mov	a,c		;A=1-indexed sector number
	dcr	a		;convert to zero indexed
	sta	secNum
	ret

;----------------------------------------------------------------------------
; setDma - Set DMA BIOS entry. BC contains the address for reading or
;    writing sector data for subsequent I/O operations. The address is
;    stored in dmaAddr.
;
;    BC = 0FFFFh is the MP/M II flush request. WRITE never defers a
;    write, so there is nothing to flush.
;----------------------------------------------------------------------------
setDma:	mov	a,b		;BC = 0FFFFh?
	ana	c
	inr	a
	rz			;yes, flush: nothing is waiting

	mov	h,b		;save buffer address passed in BC
	mov	l,c
	shld	dmaAddr
	ret

;----------------------------------------------------------------------------
; secTran - Sector translation BIOS entry. Convert zero-indexed logical
;    sector number in BC to a CPM one-indexed physical sector number in HL
;    based on the translate table passed in DE.
;----------------------------------------------------------------------------
secTran:
	xchg			;HL->translate table
	mvi	b,0		;make sure msb of sector is zero
	dad	b		;HL->translated sector num
	mov	l,m		;L=lsb of sector
	mov	h,b		;H=0=msb of sector
	ret

;----------------------------------------------------------------------------
; read - Read sector BIOS entry. Read one sector using the drvNum,
;    trkNum, secNum, and dmaAddr previously specified.
;
; On Exit
;    A=0 if successful, A=1 if not
;    Clobbers all
;----------------------------------------------------------------------------
read:	call	dBegin		;no head unload while the disk is in use
	call	readTrk		;fill track buffer if needed
	jnz	exitDio		;track read error, exit

	call	movRead		;move sector to (dmaAddr)

exitDio:
	mvi	a,HDTIME	;unload the head after HDTIME idle ticks
	sta	hdTmr
	mvi	a,0		;if zero is true, return zero
	rz

	inr	a		;else return A<>0, Z false
	ret

;----------------------------------------------------------------------------
; write - Write sector BIOS entry. Write one sector using the drvNum,
;    trkNum, secNum and dmaAddr specified. The sector is written to the
;    disk before the return, whatever the write type in C.
;
; On Exit
;    A=0 if successful, A=1 if not
;    Clobbers all
;----------------------------------------------------------------------------
write:	call	dBegin		;no head unload while the disk is in use
	call	readTrk		;fill track buffer if needed
	jnz	exitDio		;track read error, exit

	call	dSelDrv		;the drive may not be selected
	jnz	exitDio		;drive select failed, exit

	call	movWrt		;move (dmaAddr) to sector in trkBuf
	call	wrtSec		;and write that sector to the disk
	jmp	exitDio

;----------------------------------------------------------------------------
; dBegin - Stop the head unload count. If the tick unloaded the head
;    since the last READ or WRITE, forget the track buffer. The track
;    is then read again, and dSelDrv loads the head.
;    Clobbers A,H,L
;----------------------------------------------------------------------------
dBegin:	xra	a		;stop the head unload count
	sta	hdTmr
	lxi	h,hdOff		;head unloaded by the tick?
	cmp	m
	rz			;no

	mov	m,a		;yes, clear hdOff
	mvi	a,UNDEF		;and invalidate the track buffer
	sta	bfDrive
	ret

;----------------------------------------------------------------------------
; movRead - Move sector data from track buffer to (dmaAddr) for a
;    CPM read request
;
; On Exit
;    If successful (good sector)
;	sector data moved to (dmaAddr), Z flag set true
;    Else (sector flagged as bad)
;	Z flag set false
;    Clobbers all
;----------------------------------------------------------------------------
movRead:
	call	altSkew		;secNum to hard sector in A
	call	dSecAdr		;HL->sector in trkBuf

	mov	a,m		;A=sector valid flag
	ora	a
	rnz			;bad sector, return error

	lxi	d,DATDATA+1	;DE=offset to data portion of sector
	lda	trkNum		;on a data track?
	cpi	DATATRK
	jnc	mrMove		;yes, data track (DE already correct)

	lxi	d,SYSDATA+1	;DE=offset to data portion of sector

mrMove:	dad	d		;HL->data portion of sector
	xchg			;DE->data portion of sector
	lhld	dmaAddr		;HL->destination for data
	mvi	b,CSECLEN	;B=number of bytes to move

mrLoop:	ldax	d		;move sector from trkBuf to (dmaAddr)
	mov	m,a
	inx	h		;increment pointers
	inx	d
	dcr	b		;loop count
	jnz	mrLoop

	ret			;exit with zero	status

;----------------------------------------------------------------------------
; movWrt - Move sector data from (dmaAddr) to track buffer and create
;    metadata for the sector for a CPM write request.
;
; On Exit
;    Sector data moved to trkBuf from (dmaAddr)
;    Clobbers all
;----------------------------------------------------------------------------
movWrt:	call	altSkew		;secNum to hard sector in A
	call	dSecAdr		;HL->sector in trkBuf

	mvi	m,0		;flag sector as good

	inx	h		;HL->track
	lda	trkNum		;A=track
	ori	80h		;set sync bit
	mov	m,a		;set track in sector

	inx	h		;HL->byte after track
	cpi	DATATRK+80h	;on a system or data track?
	jnc	wDatTrk		;data track 6-76

; Create Altair sector for system tracks 0-5

	xra	a		;put 0100h (16 bit) at offset 1,2
	mov	m,a
	inx	h		;HL->offset 2
	inr	a		;A=1
	mov	m,a

	inx	h		;HL->128 byte CPM sector in Altair sector
	call	mwMove		;move (dmaAddr) to sector in trkBuf

	mvi	m,0FFh		;offset 131 is stop byte (0FFh)

	inx	h		;offset 132 is checksum
	mov	m,b		;store checksum at offset 132
	ret

; wDatTrk- Create Altair sector for tracks 6-76

wDatTrk:
	lda	secNum		;A=sector before Altair skew
	mov	m,a		;store Altair logical sector number

	inx	h		;HL->offset 2 in sector
	xra	a		;store zero at offsets 2-6
	mov	m,a		;offset 2

	inx	h
	mov	m,a		;zero at offset 3

	inx	h
	push	h		;save address of offset 4 = checksum

	inx	h
	mov	m,a		;zero at offset 5

	inx	h
	mov	m,a		;zero at offset 6

	inx	h		;HL->128 byte CPM sector in Altair sector
	call	mwMove		;move (dmaAddr) to sector in trkBuf

	mvi	m,0FFh		;offset 135 is stop byte (0FFh)

	pop	h		;HL->checksum byte in Altair sector
	mov	m,b		;store the checksum
	ret

;------------------------------------------------------------------------------
; mwMove - Move sector buffer (128 bytes) from (dmaAddr) to (HL) as part
;   of a CPM write command. Compute checksum on all bytes moved and return
;   the checksum in B.
;------------------------------------------------------------------------------
mwMove:	xchg			;DE->destination CPM sector in trkBuf
	lhld	dmaAddr		;HL->source buffer
	lxi	b,CSECLEN	;B=checksum (0), C=128 byte count

mwLoop:	mov	a,m		;move from (HL) to (DE)
	stax	d

	add	b		;add byte to checksum
	mov	b,a

	inx	d		;increment both pointers
	inx	h
	dcr	c		;decrement character count
	jnz	mwLoop		;loop until count = 0

	xchg			;return with buffer pointer in HL
	ret

;----------------------------------------------------------------------------
; altSkew - Perform Altair skew on the sector number in secNum and return
;    the result in A. The skew is based on the track as:
;
;	Tracks 0-5, secOut = secIn
;	Tracks 6-76, secOut = (secIn * 17) MOD 32
;
;    The skew computation for tracks 6-76 is implemented as:
;	secOut = secIn if secIn is even
;	secOut = secIn XOR 10h if secIn is odd
;
;    Clobbers A,B
;----------------------------------------------------------------------------
altSkew:
	lda	trkNum		;on a data track?
	cpi	DATATRK
	lda	secNum		;A=unmodified sector number
	rc			;system track, no change to sector

	mov	b,a		;save secNum in B
	rrc			;test for even/odd
	mov	a,b		;restore secNum in A
	rnc			;return with secNum if even

	xri	10h		;else translate as in comments above
	ret

;----------------------------------------------------------------------------
; readTrk- read full track into track buffer if the requested
;    drive (drvNum) or track (trkNum) does not match the buffered
;    drive (bfDrive) or buffered track (bfTrack). The status byte
;    at the start of each sector is set to zero if the sector is
;    good, non-zero if the sector couldn't be read.
;
; On Exit
;    trkNum on drvNum read into trkBuf
;    Zero true if track read or already there, zero false otherwise
;    Interrupts enabled
;    Clobbers all
;----------------------------------------------------------------------------
readTrk:
	lhld	bfDrive		;L=buffered drive, H=buffered track

	lda	drvNum		;A=requested drive
	cmp	l		;same drive buffered?
	jnz	rtNew		;drive doesn't match, need a new buffer

	lda	trkNum		;A=requested track
	cmp	h		;same track buffered?
	rz			;yes, already have this buffer

; rtNew - New track needs to be read

rtNew:	mvi	a,UNDEF		;invalidate buffered data
	sta	bfDrive

	call	dSelDrv		;select drive, load head
	rnz			;drive select failed, exit with error

	mvi	a,2		;init restore/seek try counter
	sta	skRetry

rtRtry:	call	dSeek		;seek to trkNum
	rnz			;a restore was required and failed

	call	initTrk		;init all sectors to "bad" (not read)
	lxi	d,RDTRIES*NUMSEC*256 + NUMSEC
				;D=max sector reads = RDTRIES revolutions
				;E=sectors remaining to fill

; Read sector loop - All sectors are originally marked "bad" (unread) and
;    a sector counter in E is started at NUMSEC (a full track of sectors).
;    Sectors are read until sector counter E reaches zero or the total
;    reads counter in D reaches zero (RDTRIES revolutions). The 1st time
;    the total reads counter reaches zero, a restore and re-seek is
;    performed in case we're on the wrong track. The second time it reaches
;    zero, the bad sectors remain marked as bad in the track buffer.

; Interrupts are disabled from the sector hunt to the end of the sector
;    read, and enabled again at rtNext. A tick that arrives there is
;    taken at once, and the sector it costs is read on a later turn.
;    The DI and EI add 8 cycles to the 230 cycles that the BIOS counts
;    from the last byte read to the sector hunt.

rtLoop:	di			;(4) no interrupt inside a sector
	call	dNxtSec		;(17) wait for next sector, HL->sector buf
	jnz	rtRead		;sector pulse found (inverted logic)

	ei
	inr	a		;force non-zero status
	ret			;return the error

rtRead:	mov	a,m		;A=sector flag byte
	ora	a		;this sector already read?
	jz	rtNext		;yes, skip it

	push	h		;save sector address
	inx	h		;HL->1st read location in sector
	call	dRead		;read the sector
	pop	h		;(10) restore sector address in HL
	jnz	rtNext		;(10) read error

	xra	a		;(4) set sector flag to zero (good sector)
	mov	m,a		;(7)

	dcr	e		;(5) decrement sectors left to fill
	jz	rtExit		;(10) all sectors read without error

rtNext:	ei			;(4) a waiting tick is taken here
	dcr	d		;(5) decrement total sectors counter
	jnz	rtLoop		;(10) go read next sector

	lxi	h,skRetry	;HL->seek retry counter
	dcr	m		;decrement the counter
	jz	rtExit		;re-seek(s) done, we're finished

	call	dRestor		;restore to track zero
	jz	rtRtry		;start over after the re-seek

	ret			;else, exit with error

rtExit:	ei
	lhld	drvNum		;L=drvNum, H=trkNum
	shld	bfDrive		;set the buffered drive and track values
	ret			;exit with Z flag true

;----------------------------------------------------------------------------
; initTrk - Set the flag byte in each sector in trkBuf to "bad" to
;    indicate none of the sectors have been read.
;----------------------------------------------------------------------------
initTrk:
	lxi	b,UNDEF*256 + NUMSEC;  B=UNDEF (bad), C=NUMSEC
	lxi	h,trkBuf	;HL->track buffer
	lxi	d,TSECLEN	;DE=length of each sector in track buffer

itLoop:	mov	m,b		;mark sector as bad (not read)
	dad	d		;HL->next sector in trkBuf
	dcr	c		;repeat for all sectors
	jnz	itLoop

	ret

;----------------------------------------------------------------------------
; wrtSec - Write the sector for trkNum/secNum from trkBuf to the disk.
;    The drive is selected and on trkNum (readTrk was just called).
;    If fWRTVFY is set in MODE, read the sector back on the next turn
;    and compare it with trkBuf. Try WRTRIES times.
;
;    The sector slot is found by the low byte of its trkBuf address.
;    TSECLEN (137) is odd, so the 32 slots have 32 different low bytes.
;
; On Exit
;    Zero true for success, zero false for error
;    Interrupts enabled
;    Clobbers all
;----------------------------------------------------------------------------
wrtSec:	call	altSkew		;A=hard sector to write
	call	dSecAdr		;HL->its slot in trkBuf
	mov	a,l
	sta	wrSlot		;the low byte names the slot

	mvi	e,cWRTEN	;E=write command, normal head current
	lda	trkNum
	cpi	43		;tracks 0-42 are normal head current
	jc	wsInit		;track is 0-42, E is correct

	mvi	e,cWRTEN+cHCSON	;E=write command with reduced current

wsInit:	mvi	a,WRTRIES	;initialize write retry count
	sta	wrRetry

wsRtry:	mvi	d,2*NUMSEC	;D=sectors to pass before giving up

wsHunt:	di			;no interrupt inside a sector
	call	dNxtSec		;(78) wait for next sector, HL->sector buf
	jz	wsTmo		;no sector pulse

	lda	wrSlot		;(13) the sector to write?
	cmp	l		;(4)
	jnz	wsNext		;(10) no

	mov	a,e		;(5) issue write command to drive
	out	DRVCMD		;(10) at 120 cycles 60us

	inx	h		;point to 1st byte of sector
	call	dWrite		;write the sector

	mvi	a,6		;delay 600us for tunnel trim erase
	call	delay
	ei
	jmp	wsVfy

wsNext:	ei			;a waiting tick is taken here
	dcr	d		;decrement sector count
	jnz	wsHunt		;loop until the sector comes round
	jmp	wsErr		;it never did

wsTmo:	ei
	jmp	wsErr

; If the verify flag is set in the mode byte, verify the sector just written.

wsVfy:	lda	mode		;verifying writes?
	ani	fWRTVFY
	rz			;no, exit with zero

	mvi	d,2*NUMSEC	;D=sectors to pass before giving up

wvHunt:	di			;no interrupt inside a sector
	call	dNxtSec		;wait for next sector, HL->sector buf
	jz	wsTmo		;no sector pulse

	lda	wrSlot		;the sector just written?
	cmp	l
	jnz	wvNext		;no

	inx	h		;point to 1st byte of sector
	call	dVerify		;verify the sector
	ei
	rz			;it matched, exit with zero
	jmp	wsAgain		;write it again

wvNext:	ei			;a waiting tick is taken here
	dcr	d
	jnz	wvHunt

wsAgain:
	lxi	h,wrRetry	;decrement the write retry counter
	dcr	m
	jnz	wsRtry		;retry starting with the write

wsErr:	mvi	a,UNDEF		;the disk may not match trkBuf: forget it
	sta	bfDrive
	ora	a		;exit with non-zero
	ret

;****************************************************************************
;
; Altair disk I/O routines
;
;****************************************************************************

;---------------------------------------------------------------------------
; dSelDrv - Select the drive specified in drvNum and load the head.
;    Save the track (curTrk) the current drive is on into the track table,
;    load curTrk for the new drive from the track table.
;
; On Exit
;    Drive selected and head loaded
;    curDrv = drvNum
;    curTrk = track the newly selected drive is on
;    Zero true for success, zero false for error
;    Clobbers all
;---------------------------------------------------------------------------
dSelDrv:
	lxi	h,curDrv	;HL->currently selected drive
	mov	e,m		;E=currently selected drive

	lda	drvNum		;A=desired drive
	mov	c,a		;save new drive in C
	cmp	e		;same or different drive?
	jnz	dNewDrv		;different, go select a new drive

	in	DRVSTAT		;drive still selected and enabled?
	ani	sDSKEN
	jz	dSelExt		;yes, exit

	jmp	dReSel		;otherwise, re-select the drive

; dNewDrv - Save current track (curTrk) for the current drive to the track
;    table, load curTrk for the new drive from the track table

dNewDrv:
	mov	m,c		;save new drive in curDrv

	mvi	d,0		;DE=currently selected drive
	lxi	h,trkTbl	;HL->track table
	dad	d		;HL->trkTbl entry for current drive

	lda	curTrk		;A=track current drive is on
	mov	m,a		;save it in the track table

	lxi	h,trkTbl	;HL->track table
	mov	e,c		;DE=offset in trkTbl for new drive
	dad	d		;HL->trkTbl for new drive

	mov	a,m		;A=track new drive is on
	sta	curTrk		;update current track

; Select the new drive with the timeout specified in selTime

dReSel:	lxi	h,selTime	;move select timeout in seconds into B
	mov	b,m

dSelLp1:
	lxi	h,25641		;HL=count of 78 cycle loops for 1 second

dSelLp:	mvi	a,cDSLCT	;(7) deselect a possibly attached drive
	out	DRVSLCT		;(10)

	mov	a,c		;(5) A=drive to select
	out	DRVSLCT		;(10) select it

	in	DRVSTAT		;(10) did drive select work?
	ani	sDSKEN		;(7)
	jz	dSelExt		;(5) yes, exit

	dcx	h		;(5) decr 1 sec counter
	mov	a,h		;(5) test HL counter for zero
	ora	l		;(4)
	jnz	dSelLp		;(10) loop for one second

	dcr	b		;decrement seconds expired
	jnz	dSelLp1		;repeat for a new 1 second

	inr	a		;timeout, return non-zero
	ret

dSelExt:
	mvi	a,cHDLOAD	;issue head load command
	out	DRVCMD

	ret			;return with zero status

;---------------------------------------------------------------------------
; dSeek - Seek to track in trkNum
;
; On Entry
;    Drive selected and ready
;    trkNum = desired track
;    curTrk = current track, UNDEF means we don't know
;
; On Exit
;    curTrk = trkNum
;    Zero true for success, zero false for failure
;	(failure is a failed restore to track zero)
;    Clobbers A,B,C,H,L
;---------------------------------------------------------------------------
dSeek:	lda	curTrk		;A=current track
	cpi	UNDEF		;valid track number?
	jnz	dTrkVld		;yes, track is valid

	call	dRestor		;otherwise, restore to track zero
	rnz			;exit if restore failed

; dTrkVld - Current track is valid, compute direction and number
;     of steps

dTrkVld:
	lxi	h,trkNum	;HL->trkNum
	sub	m		;A=current-requested
	rz			;return if already on correct track

	mvi	b,cSTEPO	;B=step out (assume requested<current)
	jnc	dDoSeek		;it is

	mvi	b,cSTEPI	;B=step in (requested>current)
	cma			;compute A=-A
	inr	a

; Save target track in curTrk, step there, then verify track

dDoSeek:
	mov	c,a		;C=number of steps

	mov	a,m		;save new track in curTrk
	sta	curTrk

	call	dStep		;do the seek
	jz	dTrkVld		;track 0 came first: seek again from there
	xra	a		;return zero
	ret

;---------------------------------------------------------------------------
; dRestor - Restore to track 0 and then delay to ensure any subsequent
;    seek meets the minimum direction change period.
;
; On Exit
;    If successful
;       curTrk = 0
;	A=0
;	Zero true
;    else
;       curTrk = UNDEF
;       Zero false
;    Clobbers A,B,C
;---------------------------------------------------------------------------
dRestor:
	xra	a
	sta	curTrk		;set current drive track to zero

	in	DRVSTAT		;test for track 0
	ani	sTRACK0
	rz			;at track 0, exit

; Step in three tracks, then step out to track 0

	mvi	c,3		;C=step in 3 tracks
	mvi	b,cSTEPI	;B=step in command
	call	dStep		;do 3 steps in

	mvi	a,200		;20ms delay puts us past the 1ms step window
	call	delay		;  and ensures proper dir change delay

; Seek back out until track 0 detected

	mvi	c,NUMTRK+10	;C=maximum number of step outs to try
	mvi	b,cSTEPO	;B=step out command
	call	dStep		;step until track 0 detected
	jnz	drFail		;restore failed

	mvi	a,200		;20ms delay puts us past the 1ms step window
	call	delay		;  and ensures proper dir change delay
	ret			;return with zero

drFail:	mvi	a,UNDEF		;restore failed, track is still undefined
	sta	curTrk
	ret			;return with non-zero

;---------------------------------------------------------------------------
; dStep - Step head number of steps in C, direction command in B.
;   If track zero is detected during a step-out operation, curTrk
;   is forced to zero and zero is returned in A.
;
; On Exit
;    If stepping out and track zero hit
;	curTrk = 0
;	A = 0
;	Zero true
;    else
;	Zero false
;    Clobbers A,B,C
;---------------------------------------------------------------------------
dStep:	in	DRVSTAT		;loop until OK to move the head
	ani	sMOVEOK
	jnz	dStep

	in	DRVSTAT		;see if we are at track 0
	ani	sTRACK0		;at track zero?
	jnz	dStep1		;no, go on

	mov	a,b		;stepping out?
	sbi	cSTEPO
	jz	dStep0		;yes, we've hit track 0

dStep1:	mov	a,b		;A=step command and direction
	out	DRVCMD		;issue the step

	dcr	c		;decrement step counter
	jnz	dStep		;loop until count reaches zero

	inr	c		;force non-zero
	ret

dStep0:	sta	curTrk		;curTrk=0
	ret			;return with zero true and A=0

;---------------------------------------------------------------------------
; dNxtSec - Wait for next (any) sector. Returns pointer to the sector
;    buffer within trkBuf. Control is back to caller at 78 cycles (39us).
;
; On Exit
;    HL->sector buffer in trkBuf for sector found, zero false
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
; dSecAdr - Convert hard sector in A to address within trkBuf for
;    the specified sector
;
; On Entry
;    A = Hard sector number
;
; On Exit
;    HL->sector buffer in trkBuf
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
; delay - Delay for A x 100us
;
; On Exit
;    A=0
;    Zero true
;    Clobbers A,B
;----------------------------------------------------------------------------
delay:	mvi	b,(200/20)	;20 cycles in the loop below

delayLp:
	mov	b,b		;(5) delay 5 cycles
	dcr	b		;(5)
	jnz	delayLp		;(10)

	dcr	a		;decrement 100us counter
	jnz	delay
	ret

;---------------------------------------------------------------------------
; dRead - Read a sector, verify checksum, stop byte, and track number.
;    Verification is done after the sector is read in the time between
;    the last byte of the sector and before the start of the next sector.
;    With index alignment and rotation speed tolerance accounted for,
;    we safely have 360 cycles from the last byte of the sector until code
;    should be in the sector true hunt loop. The RET is complete from this
;    routine 152 cycles worst case after the last byte is read.
;
; On Entry
;    Drive is selected, sector true just detected
;    HL->sector buffer
;
; On Exit
;    Sector read to (HL)
;    C = track number from disk with sync bit set
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

; The sector transfer loop is 116 cycles for two bytes read (has to be
;     less than 128) and computes checksum over all bytes read.

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

; drSecDn - Sector read is complete, now validate the sector based on whether
;   it is from a system track or data track.

drSecDn:
	lda	curTrk		;(10) A=track we're supposed to be on
	cpi	DATATRK		;(7) system or data track?
	jnc	drDatTk		;(10) data track

; Validate a system track sector. A system track sector is three bytes
;    bytes shorter, so this codes starts 3*64 cycles sooner than for a
;    data sector. This code completes before a data sector would even
;    finish reading. Therefore, a data sector is the worst timing path.

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

; Validate a data track sector (125 + 27 cycles for sector type jump)

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

;---------------------------------------------------------------------------
; dVerify - Verify a sector
;    The read loop is 116 cycles for two bytes. This must complete in 128
;    cycles, so there is plenty of headroom. The 2nd byte is read is at
;    70 cycles which gives six cycles of headroom (70-64).
;
; On Entry
;    Drive is selected, sector true just detected
;    HL->sector buffer to compare against
;
; On Exit
;    Zero true if match, zero false for error
;    Clobbers A,B,C,H,L
;---------------------------------------------------------------------------
dVerify:
	lxi	b,DSECLEN	;(10) B=0, C=data sector length
	lda	curTrk		;(13) A=track we're on
	cpi	DATATRK		;(7) data track or system track?
	jnc	dVfLoop		;(10) data track, length in C is correct

	mvi	c,SSECLEN	;(7) set C=length of a system sector

dVfLoop:
	in	DRVSTAT		;(10) get drive status byte
	ora	a		;(4) wait for NRDA flag true (zero)
	jm	dVfLoop		;(10)

	in	DRVDATA		;(10) read first byte at 24-48 cycles
	xra	m		;(7) verify data matches buffer
	ora	b		;(4) accumulate errors in b
	mov	b,a		;(5)

	inx	h		;(5) increment buffer pointer
	dcr	c		;(5) decrement characters remaining counter
	jz	dVfDone		;(10) done verifying bytes

	in	DRVDATA		;(10) read 2nd byte at 70-94 cycles
	xra	m		;(7) verify data matches buffer
	ora	b		;(4) accumlate errors in b
	mov	b,a		;(5)

	inx	h		;(5) increment buffer pointer
	dcr	c		;(5) decrement byte counter
	jnz	dVfLoop		;(10) loop for all bytes

dVfDone:
	ora	a		;A=zero if all bytes matched
	ret			;return status

;---------------------------------------------------------------------------
; dWrite - Write a sector
;    The write loop is 61 cycles which gives just 3 cycles (64-61) of
;    headroom. However, since the write timing required by the FDC board
;    is derived from the 2 MHz CPU/bus clock, this loop is always exactly
;    in sync with the FDC write timing. 3 cycles of headroom is plenty.
;
; On Entry
;    Drive is selected, sector true just detected, and
;	the write command has already been issued
;    HL->sector buffer to write
;
; On Exit
;   Clobbers A,C,H,L
;---------------------------------------------------------------------------
dWrite:	mvi	c,DSECLEN	;C=number of bytes to write
	lda	curTrk		;(13) A=track we're on
	cpi	DATATRK		;(7) data track or system track?
	jnc	dWrLoop		;(10) data track, length in C is correct

	mvi	c,SSECLEN	;(7) set C=length of a system sector

dWrLoop:
	in	DRVSTAT		;(10) read drive status register
	rrc			;(4) wait for ENWD flag (zero)
	jc	dWrLoop		;(10)

	mov	a,m		;(7) A=next byte to write
	out	DRVDATA		;(10) write 2nd byte at 68-92 cycles
	inx	h		;(5) increment buffer pointer
	dcr	c		;(5) decrement bytes remaining
	jnz	dWrLoop		;(10) loop until all bytes written

dWrDone:
	in	DRVSTAT		;wait for another write flag
	rrc
	jc	dWrDone

	xra	a		;write a trailing zero
	out	DRVDATA
	ret

;******************************************************************************
;
;   XIOS Data Area
;
;******************************************************************************

mode:	db	0		;default mode byte, write verify off
selTime:
	db	7		;drive select timeout in seconds

;---------------------------------------------------------------------------
; secAddr - Sector address table. Returns sector buffer address within
;    the track buffer when indexed by hard sector number. Each sector
;    requires TSECLEN bytes.
;---------------------------------------------------------------------------
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

;-----------------------------------------------------------------------------
; dpHead - disk parameter header for each drive
;-----------------------------------------------------------------------------
dpHead:	dw	tranTbl,0,0,0,dirBuf,dpb,csv0,alv0
	dw	tranTbl,0,0,0,dirBuf,dpb,csv1,alv1
	dw	tranTbl,0,0,0,dirBuf,dpb,csv2,alv2
	dw	tranTbl,0,0,0,dirBuf,dpb,csv3,alv3

;-----------------------------------------------------------------------------
; dpb - disk parameter block. The same disk as the CP/M 2.2 BIOS:
;   2K blocks, 150 blocks, 64 directory entries, 2 reserved tracks.
;-----------------------------------------------------------------------------
dpb:	dw	NUMSEC		;sectors per track
	db	BSH		;allocation block shift factor (BSH)
	db	BLM		;data location block mask (BLM)
	db	EXM		;extent mask (EXM)
	dw	DSM		;maximum block number
	dw	DRM		;maximum directory entry number
	db	AL0,AL1		;AL0, AL1
	dw	CKS		;CKS=(DRM+1)/4
	dw	RESTRK		;reserved tracks for CPM and bootloader

tranTbl:
	db	01,09,17,25,03,11,19,27,05,13,21,29,07,15,23,31
	db	02,10,18,26,04,12,20,28,06,14,22,30,08,16,24,32

;----------------------------------------------------------------------------
; Initialized data
;----------------------------------------------------------------------------
curDrv:	db	0		;drive number currently selected
curTrk:	db	UNDEF		;track the selected drive is on
trkTbl:	db	UNDEF,UNDEF,UNDEF,UNDEF		;track each drive is on

bfDrive:
	db	UNDEF		;drive currently in track buffer
bfTrack:
	db	UNDEF		;currently buffered track (MUST follow bfDrive)

cnt60:	db	60	; 60 tick cntr = 1 sec
intstk:			; local intrpt stk
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h,0c7c7h
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h,0c7c7h
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h,0c7c7h
	dw	0c7c7h,0c7c7h,0c7c7h,0c7c7h,0c7c7h
lstintstk:
svdhl:	dw	0	; saved Regs HL during int hndl
svdsp:	dw	0	; saved SP during int hndl
svdret:	dw	0	; saved return during int hndl
tickn:	db	0	; ticking boolean,true = delayed
preemp:	db	0	; preempted boolean
hdTmr:	db	HDTIME	; ticks to the head unload, 0 = stopped
hdOff:	db	0	; true = the tick unloaded the head

;----------------------------------------------------------------------------
; Non-initialized data
;----------------------------------------------------------------------------
drvNum:	ds	1		;drive number from CP/M call
trkNum:	ds	1		;track number from CP/M call (MUST follow drvNum)
secNum:	ds	1		;sector number from CP/M call
dmaAddr:
	ds	2		;dma address for disk operations from CP/M call

wrSlot:	ds	1		;low byte of the trkBuf slot being written
wrRetry:
	ds	1		;write retry counter
skRetry:
	ds	1		;restore and seek retry counter

;-----------------------------------------------------------------------------
;  Disk scratchpad areas defined in the DPH table
;-----------------------------------------------------------------------------
dirBuf:	ds	128		;bdos directory scratchpad
alv0:	ds	(DSM/8 + 1)	;allocation vector storage
csv0:	ds	CKS		;change disk scratchpad
alv1:	ds	(DSM/8 + 1)
csv1:	ds	CKS
alv2:	ds	(DSM/8 + 1)
csv2:	ds	CKS
alv3:	ds	(DSM/8 + 1)
csv3:	ds	CKS

;-----------------------------------------------------------------------------
; Track buffer. One extra byte is allocated at the start of each sector
;    to flag a bad sector (read failure). This byte is zero if the sector
;    is good, non-zero if the sector is bad.
;-----------------------------------------------------------------------------
trkBuf:	ds	NUMSEC*TSECLEN

	db	0	;force out last byte in hex file

	end
