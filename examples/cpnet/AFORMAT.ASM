;==============================================================
;     Disk Format-with-Verify Utility for Altair diskettes
;
; Supports both 88-DCDD 8" diskettes and 88-MDS 5.25" minidisks
; Runs under CP/M and MP/M II, but useful for Altair Basic & DOS
; disks too
;==============================================================
;
;USAGE:
;
; AFORMAT <d>: [/N] [/Fnn]
;
;   <d> is the drive to format.
;
;   /Fnn fills the data fields with hex value nn.
;     (Defaults TO E5, which CP/M interprets as an empty disk.)
;
;   /N formats only the non-system tracks
;
;---------------------------
; MP/M II
;---------------------------
; BDOS function 12 returns 01xxh under MP/M II. AFORMAT then
; works this way:
;
; 1) Drives A: through D: are floppy drives 0 through 3. MP/M
;    II gives a program a BIOS jump vector with the console
;    entries only, so AFORMAT does not call SELDSK.
; 2) The console entries go through the BDOS of MP/M II, which
;    enables interrupts. GOBIOS disables them again, so the
;    clock tick cannot stop a track write or verify.
; 3) AFORMAT holds the MXDisk queue of MP/M II while it formats
;    a disk, so no other process uses the disk controller. It
;    gives the queue back while it waits for an answer. For A:,
;    the system disk, it holds the queue from before "Put disk
;    in A" until the MP/M II disk is back in A:.
; 4) The drive is reset (BDOS function 37) before and after the
;    format. MP/M II refuses the reset if a process has a file
;    open on the drive, and AFORMAT then stops.
; 5) At the end, "Put MP/M II disk in A:" if A: was formatted,
;    in place of "Put CP/M disk in A:".
;
;---------------------------
; Altair 8" Diskette Format
;---------------------------
;  Raw Bytes/sector: 137
;     Sectors/Track: 32, numbered 0-31
;   Tracks/Diskette: 77, numbered 0-76
;
; Tracks 0-5 are "System Tracks" (regardless of how they
; are actually used). Sectors on these tracks are
; formatted as follows:
;
;     Byte    Value
;      0      Track number and 80h
;     1-2     Number of bytes in boot file
;    3-130    Data
;     131     0FFh (Stop Byte)
;     132     Checksum of 3-130
;    133-136  Not used
;
; Tracks 6-76 (except track 70) are "Data Tracks." Sectors
; on these tracks are formatted as follows:
;
;  Byte    Value
;     0      Track number and 80h
;     1      Skewed sector = (Sector number * 17) MOD 32
;     2      File number in directory
;     3      Data byte count
;     4      Checksum of 2-3 & 5-134
;    5-6     Pointer to next data group
;   7-134    Data
;    135     0FFh (Stop Byte)
;    136     Not used
;
; Track 70 is the Directory Track. It is formatted the same as
; the Data Tracks, except that each Data field is divided into
; 8 16-byte directory entries. The last 5 of these 16 bytes are
; written as 0 by most versions of Altair Basic and DOS, but are
; used as a password by Multiuser Basic, where five 0's means
; "no password". If these password bytes are not all 0 for a
; given directory entry, then regular (not multiuser) Basic will
; not be able to access the file. The first directory entry that
; has FFh as its first byte is the end-of-directory marker.
; (This FFh is called "the directory stopper byte.") All
; subsequent directory bytes are ignored.
;
;------------------------
; Altair Minidisk Format
;------------------------
;  Raw Bytes/sector: 137
;     Sectors/Track: 16, numbered 0-15
;   Tracks/Diskette: 35, numbered 0-34
;
; On a bootable minidisk, tracks 0-11 are "System Tracks."
; Sectors on these tracks are formatted the same as system
; tracks on an 8" diskette.
;
; Sectors on tracks 12-33 of a bootable minidisk, and on all
; tracks of a non-bootable "data"  minidisk are formatted
; the same as sectors on Data Tracks on an 8" diskette, except
; that the sectors are not skewed.
;
; Track 34 is the minidisk Directory Track. Sectors on this
; track are formatted the same as the Directory Track on an 8"
; diskette.
;
;==============================================================
;                      SYSTEM REQUIREMENTS
; 1) Written to assemble with Digital Research's ASM.
; 2) Requires MITS floppy disk controllers - either the
;    88-DCDD 8" disk controller or the 88-MDS minidisk
;    controller. The disk controller must be addressed at the
;    standard Altair disk controller address = 08H through 0Ah.
; 3) Only floppy drive numbers 0 through 3 are supported.
; 4) Runs on Floppy Disk CP/M (where floppy drives are disks
;    A: through D:) and on Hard Disk CP/M (where floppy drives
;    are disks C: through F:). Runs on MP/M II, where floppy
;    drives are disks A: through D:.
; 5) Requires zero wait-state RAM when formatting 8" diskettes.
; 6) Requires at least 9K of free RAM (not including RAM for
;    CP/M's BIOS) to format an 8" diskette. Requires 5K to
;    format a minidisk. This program can overwrite CP/M's CCP
;   and BDOS, restoring them when done.
; 7) Messages display correctly on screens as small as 16X64.
;==============================================================
;---------------------------
;This Code'S revision number
;---------------------------
VERSION	equ	0112h	;high byte = major revision number
			;low byte=2-digit minor version
;
;REVISION HISTORY
; 1.12  21 October 2026  P. Linstruth
;     Run under MP/M II (see MP/M II above)
; 1.11  28 December 2021  M. Eberhard
;     Detect soft-sector and 10-sector disks, and exit with
;     error message if so
; 1.10 21 March 2019  M, Eberhard
;     Support CP/M 3.x
; 1.09 8 July 2015  M. Eberhard
;     Bug fix: Reload head after calling CONIN when looking
;     for user abort during format (the BIOS unloads the head)
; 1.08 12 Dec 2014  M. Eberhard
;     Option to format another disk when done
; 1.07  11 December 2014
;     Bug fix
; 1.06 7 August 2014  M. Eberhard
;     Change several user interface items to match ACOPY 1.06.
; 1.05  16 July 2014  M. Eberhard
;     No "Insert CP/M disk" message if hard disk. "More" on help
;     screen. Put subroutines in logical order. Trim help
;     messages. Delete unused RTRAC subroutine.
; 1.04  15 July 2014  M. Eberhard
;     change to CP/M-style drive letters. Mask ints.
; 1.03  12 July 2014  M. Eberhard
;     Reduce retries from 16 to 4. Overlay stack and tail end
;     of main code into unused TRKBUF areas. Fix DISEXT bug.
; 1.02  10 July 2014  M. Eberhard
;     Fix system-track bug created in 1.01 streamlining
; 1.01  10 July 2014  M. Eberhard
;     Remove debug code. Fix error-reporting bug. Streamlining
; 1.00  22 June 2014  M. Eberhard
;     Created
;==============================================================
FALSE	equ	0
TRUE	equ	not FALSE

;******************
; ASCII Characters
;******************
CTRLC	equ	3		;Control-C for user-abort
LF	equ	0AH		;Linefeed
CR	equ	0DH		;Carriage return

;*******************************
; Assembly switches & variables
;*******************************
PACIFY	equ	TRUE

RETRYS	equ	4	;max retries per track read & verify
MAXDRV	equ	3	;drives 0-3 supported
MAXBSL	equ	64	;max /R sector errors in error log

ABTCHR	equ	CTRLC	;abort character
DFDATA	equ	0E5h	;default sector data-field fill character

;---------------------
; Diskette Parameters
;---------------------
SECSIZ	equ	137	;total bytes/sector

DTSECT	equ	1	;Logical sector number in Sys tracks
STDATA	equ	3	;System track sector data start
STCKSM	equ	132	;checksum byte, System tracks

DTCKSM	equ	4	;checksum byte, data tracks
DTDATA	equ	7	;Data track sector data start

SSTOPR	equ	0FFh	;sector data stop byte value
DSTOPR	equ	0FFh	;directory "stopper" value

; 8" diskette parameters

SPT8	equ	32	;8" diskette sectors/track
MAXTK8	equ	76	;8" diskette max track number
NSTK8	equ	6	;# of system tracks for 8" disk
BDTK8	equ	70	;Basic Directory Track, 8"
LCTRAK	equ	43	;low write current starting at this trk

; Minidisk parameters

SPT5	equ	16	;Minidisk sectors/track
MAXTK5	equ	34	;minidisk max track number
NSTK5	equ	12	;# of system tracks for minidisk
BDTK5	equ	34	;Basic Directory Track, minidisk

;--------------------------------------------------------------
; Altair Disk Controller Equates (These are the same for
; the 88-DCDD controller and the 88-MDS controller.)
;--------------------------------------------------------------
DENABL	equ	08H		;Drive Enable output
DDISBL	  equ	  80h		  ;disable disk controller

DSTAT	equ	08H		;Status input (active low)
ENWDAT	  equ	  01H		  ;-Enter Write Data
MVHEAD	  equ	  02H		  ;-Move Head OK
HDSTAT	  equ	  04H		  ;-Head Status
DRVRDY	  equ	  08H		  ;-Drive Ready
INTSTA	  equ	  20H		  ;-Interrupts Enabled
TRACK0	  equ	  40H		  ;-Track 0 detected
NRDA	  equ	  80H		  ;-New Read Data Available

DCTRL	equ	09H		  ;Drive Control output
STEPIN	  equ	  01H		  ;Step-In
STPOUT	  equ	  02H		  ;Step-Out
HDLOAD	  equ	  04H		  ;8" diskette: load head
				  ;Mini: restart 6.4 S timer
HDUNLD	  equ	  08h		  ;unload head (8" only)
IENABL	  equ	  10H		  ;Enable sector interrupt
IDSABL	  equ	  20H		  ;Disable interrupts
HCS	  equ	  40h		  ;Head Current Switch
				  ;..set for tracks>42
WENABL	  equ	  80H		  ;Enable drive write circuits

DSECTR	equ	09H		;Sector Position input
SVALID	  equ	  01h		  ;Sector Valid (1st 30 uS
				  ;..of sector pulse)
SECMSK	  equ	  3Eh		  ;Sector mask for MDSEC

DDATA	equ	0AH		;Disk Data (input/output)

;**************
; CP/M Equates
;**************
;--------------------------------------------
; CP/M Entry Points and low-memory locations
;--------------------------------------------
WBOOT	equ	0000H		;Jump to BIOS Warm Boot code
WBOOTA	equ	WBOOT+1		;Address of Warm Boot code
BDOS	equ	WBOOT+5		;BDOS Entry Point
BDOSA	equ	WBOOT+6		;First address of BDOS

COMBUF	equ	WBOOT+80H	;command line buffer
USAREA	equ	WBOOT+100H	;User program area

;----------------------------------------------------------
; BIOS Entry Points, relative to the base address in WBOOT
;----------------------------------------------------------
CONST	equ	06h	;Console Status
CONIN	equ	09h	;Console Input
CONOUT	equ	0Ch	;Console output
SELDSK	equ	1Bh	;Select Disk. Returns hl=DPH address

;------------------------------------------
;BDOS Function Codes, passed in register C
;------------------------------------------
BVERSN	equ	0Ch	;Returns CP/M version in HL
DRESET	equ	25h	;Reset the drives in de
OPENQ	equ	87h	;MP/M II: open queue
READQ	equ	89h	;MP/M II: read queue
WRITEQ	equ	8Bh	;MP/M II: write queue

;==============================================================
; Start of code
;==============================================================
	org	USAREA

;------------------------------------------------------
; Initialize and get format parameters from user, using
; code that gets wiped out by TRKBUF
;------------------------------------------------------
	lxi	SP,STACK	;create local stack
	call	INIT

;-------------------------------------------------------
; Main loop to format disks until the user says to stop.
; On Entry:
;   MINTRK = starting track
;   MAXTRK = ending track
;   NSTRKS = number of system tracks
;   NSTRKS >= MINTRK
;   FILDAT = data to write into sector Data fields
;   DSTDSK is selected
;   head is loaded and on track 0
;-------------------------------------------------------
FMTDSK:

;----------------------------
; Seek MINTRK (if it's not 0) 
;----------------------------
	lda	MINTRK
	mov	e,a		;e=MINTRK for format
	mov	d,e		;tracks to skip

SKLOOP:	dcr	d		;this loop could go 0 times
	jm	ONMIN		;on MINTRK?

	mvi	a,STEPIN
	call	STEP
	jmp	SKLOOP		;step in another track
ONMIN:

;===Function============================================
; Format Diskette
;  Tracks 0 to NSTRKS-1 are formatted as System Tracks
;  Tracks NSTRKS to MAXTRK are formatted as Data Tracks
; On Entry:
;   e=MINTRK
;   MINTRK = starting track
;   MAXTRK = ending track
;   NSTRKS = number of system tracks
;   NSTRKS >= MINTRK
;   FILDAT = data to write into sector Data fields
;   DSTDSK is selected
;   head is loaded and on MINTRK
; Trashes all registers
;=======================================================

;-------------------------------
; Format System Tracks, if any
;  Byte    Value
;   0      Track number and 80h
;  1-2     0
; 3-130    FILDAT
;  131     0FFh (Stop Byte)
;  132     Checksum of 3-130
; 133-136  0
;-------------------------------

; Any system tracks on this disk?

	lda	NSTRKS		;number of system tracks
	cmp	e
	jz	FSDONE		;n: skipping system tracks

; create system-track data in the track buffer

	mvi	d,(256-SECSIZ)+STDATA ;start of data
	call	FILBUF		;fill buffer data

; Loop to write system track info to all system tracks

FSLOOP:	call	TNBUFF		;install track numbers

; write & verify track

	call	WVTRAC		;write & verify track

; Next track

	call	NEXTRK		;next track, if possible

	inx	d		;bump e without changing Z

	jz	FMTDON

	lda	NSTRKS		;number of system tracks
	cmp	e
	jnz	FSLOOP
FSDONE:

;-------------------------------------
; Format Data Tracks
;  Byte    Value
;   0      Track number and 80h
;   1      (Sector number * 17) MOD 32
;  2-3     0
;   4      Checksum of 2-3 & 5-134
;  5-6     0
; 7-134    FILDAT
;  135     0FFh (Stop Byte)
;  136     0
;-------------------------------------
; Create data-track data & sector numbers in track buffer

	mvi	d,(256-SECSIZ)+DTDATA ;start of data
	call	FILBUF		;fill buffer data field

; Write logical sector numbers into every sector's header.
; Logical sector numbers are skewed 17:1 (which is the
; same as 1:1 for a 16-sector minidisk). Skew of 17 is
; quickly calculated this way:
;   next sector = ((sector + 1) XOR 10h) MOD SPT

	lxi	h,TRKBUF+(256-SECSIZ)+1
	lda	SPT
	mov	c,a		;sector count
	dcr	a		;modula for sector skew
	mov	b,a		;b=skew modula mask
	xra	a		;start with sector 0

SNBLUP:	mov	m,a		;install skewed sector number

; Calculate a=next logical sector number.
; For minidisks, b=0. For 8" diskettes, b=10h.

	inr	a		;next sector
	xri	10h		;skew 17
	ana	b		;modula SPT

	inr	h		;next sector
	dcr	c
	jnz	SNBLUP

; Loop to write data-track info to the remaining tracks

FDLOOP:	call	TNBUFF		;install track numbers

; If this is directory track, then write the directory
; "stopper" byte into the first data byte of sector 0.

	lxi	h,TRKBUF+(256-SECSIZ)+DTCKSM

	lda	BDTRAC		;directory track?
	sub	e
	jz	DOSTPR		;yes: install a stopper

	inr	a		;track after directory?
	jnz	NOSTPR

	lda	FILDAT		;y: put data back
	sta	TRKBUF+(256-SECSIZ)+DTDATA

	ani	01h		;restore checksum
	rrc

	jmp	STPDON

; Install directory stopper in 1st data byte of 1st
; sector on the directory track

DOSTPR:	mvi	a,DSTOPR	;directory stopper
	sta	TRKBUF+(256-SECSIZ)+DTDATA

; fix directory sector's checksum:
; cksum := cksum - FILDAT + FFh

	lda	FILDAT
	cma			;a= ffh - FILDAT
	add	m
STPDON:	mov	m,a		;install cksum

NOSTPR:

; Write & verify track

	call	WVTRAC		;write & verify track

; next track

	call	NEXTRK		;next track if possible

	inx	d		;bump e without changing Z

	jnz	FDLOOP

;---------------------------------------------------------
; Format is done. See if the user wants to format another.
; This will allow the user to format another disk with the
; same format parameters as the previous disk, and assumes
; that the drive did not magically change types.
;---------------------------------------------------------
FMTDON:	call	RESTOR		;restore to track 0

	lda	DSTDSK		;formatting the system disk?
	ora	a
	cnz	RELMX		;n: MP/M II: give back the disks

	call	CILPRT
	db	'Format anothe','r'+80h
	call	ASKYN

; If the user wants to format another, ask to insert disk

	cz	CONFRM
	jnz	CPMEXT		;quit if not ready

	call	GETDSK		;MP/M II: take the disks

	call	SELECT		;select and load head
	jmp	FMTDSK

;===Subroutine========================
; Write track with verify and retries
; On Entry:
;   e=current track
; Trashes a,bc,d,hl
;=====================================
WVTRAC:	mvi	d,RETRYS+1

WRETRY:	call	WTRACK		;write the track
	call	FNDSEC		;(29)must skip one sector
				;..for the end of trim-erase

	call	VTRACK		;(17)
	rz			;done if no error

	call	VETELL		;report retry, abort
				;..if too many retries
	jnz	WRETRY		;try again, unless too many
	ret			;give up on track

;===Subroutine================================================
; Write all SPT sectors to the current track from the current
; track slot in the track buffer, starting with the first
; encountered sector. Use the physical sector number to
; read each sector from its appropriate sector slot in the
; buffer. Each sector is positioned in the buffer such that
; its last address is xxFFh.
; On Entry:
;   e = track number
; Trashes a,bc,hl
;=============================================================

; Create write command, with reduced write current if needed

WTRACK:	mvi	b,WENABL	;compute correct write enable
	mov	a,e		;track number
	cpi	LCTRAK		;below track 43?
	jc	HICRNT		;y: high write current
	mvi	b,WENABL+HCS	;n: low current
HICRNT:

; Loop to write SPT sectors to the disk

	lda	SPT		;sectors per track
	mov	c,a		;c counts sectors

TWLUP:	call	FNDSEC		; Find the next sector

; ENWDAT becomes true 280 uS after -SVALID becomes true, and
; occurs every 32 uS thereafter. This loop takes 28 uS. 

	mov	a,b		;initiate write ASAP
	out	DCTRL		;with HCS set appropriately	

DWLUP:	in	DSTAT		;(10)Read the drive status
	rrc			;(4)test ENWDAT ready to write?
	jc	DWLUP		;(10)no: wait

	mov	a,m		;(7)write data
	out	DDATA		;(10)
	inr	l		;(5)Move to next buffer address
				;..and test for end
	jnz	DWLUP		;(10)Loop if more data

; Write the final 0 to end the write

DWLUP2:	in	DSTAT		;(10)Read the drive status
	rrc			;(4)ready to write?
	jc	DWLUP2		;(10)no: wait

	xra	a		;(4)write 0
	out	DDATA		;(10)Read data byte

; Next sector, until all SPT sectors are written

	dcr	c
	jnz	TWLUP

	ret

;===Subroutine==============================================
; Verify all SPT sectors of the current track by comparing
; the disk data to the data in the current track slot in
; the track buffer, starting with the first encountered
; sector. Use the physical sector number to find each
; sector's  slot in the buffer. Each sector is positioned
; in the buffer such that its last address is xxFFh.
; On Exit:
;  Z set if track matches
;  Z clear if any mismatch
; Trashes a,c,hl
;===========================================================

; Loop to verify all SPT sectors on the current track

VTRACK:	lda	SPT		;(7)sectors per track
	mov	c,a		;(4)c counts sectors

TCLUP:	call	FNDSEC		;(17)find the next sector

; NRDA becomes true 140 uS after -SVALID becomes true, and
; occurs every 32 uS thereafter. This loop takes 30.5 uS.

DCLUP:	in	DSTAT		;(10)Read the drive status
	rlc			;(4)New Read Data Available?
	jc	DCLUP		;(10)no: wait for data

	in	DDATA		;(10)Read data byte
	cmp	m		;(7)Store it in sector buffer
	rnz			;(5)fail: ret with Z cleared
	
	inr	l		;(5)Move to next buffer address
	jnz	DCLUP		;(10)Loop if more data

; Next sector, until all SPT sectors have been verified.
 
	dcr	c		;next sector
	jnz	TCLUP		;until all sectors are verified

	ret			;success: ret with Z set

;===Subroutine================================
; Find the next sector
;   -SVALID is low for 30 uS.
; On Exit:
;   hl = buffer address = buffer base address
;        + (256 x sector number)
;   Sector is ready to read or write
;=============================================
FNDSEC:	lxi	h,TRKBUF+(256-SECSIZ)	;page-aligned

WVALID:	in	DSECTR		;(10)Read the sector position
	rrc			;(4)put -SVALID in carry
	jc	WVALID		;(10)wait for sector to be valid

	ani	SECMSK/2	;(7)Mask sector bits
	add	h		;(4)point into sector buffer
	mov	h,a		;(4)
	ret			;(10)

;===Subroutine=============================================
; Step in one track, and give the user a chance to abort.
; This routine does not check if stepping is allowed, nor
; does it wait for the step to complete, since it is always
; followed by a track read or write. The hardware will hold
; off on starting a read or write until the stepping has
; completed, and a track read/write takes longer than the
; minimum step time.
;
; We call SELECT to test for user abort, because the BIOS
; will unload the head on calls to CONIN. SELECT will
; reload the head if the user typed something, causing a
; call to CONIN.
; On Entry:
;  e=current track
; On Exit:
;  z set if already on last track
;  z clear, head stepped in in otherwise
; trashes a
;==========================================================
NEXTRK:	call	SELECT		;give user a chance to quit

	lda	MAXTRK		;last track?
	cmp	e
	rz

	mvi	a,STEPIN	;step in (no need to wait)
	out	DCTRL

 if PACIFY
	call	ILPRNT		;print pacifier dot
	db	'.'+80h
 endif
	ret

;===Subroutine============================================
; Write track number into every sector's header byte 0
; Turn on the 'sync bit' (bit 7) in the track numbers.
; On Entry:
;   e=track number
; Trashes a,c,hl
;=========================================================
TNBUFF:	lda	SPT
	mov	c,a		;c counts sectors

	mov	a,e
	ori	80h		;install sync bit

	lxi	h,TRKBUF+(256-SECSIZ)

TNBLUP:	mov	m,a
	inr	h
	dcr	c
	jnz	TNBLUP

	ret

;===Subroutine===========================================
; Fill track buffer with data, stop bytes and checksums,
; skipping the track number and writing 0 to all other
; metadata bytes
; On Entry:
;  FILDAT=data-field fill data
;  d= buffer byte # where 128-byte data field starts
; On Exit:
;  Trashes a,bc,hl
;========================================================
FILBUF:	mvi	h,TRKBUF/256
	lda	SPT
	mov	c,a		;# of sectors
	mvi	b,0		;start filling with 0s

CBLUP1:	mvi	l,(256-SECSIZ)+1 ;skip track number

CBLUP2:	mov	a,l
	sub	d		;beginning of fill data?
	jnz	FB1

	lda	FILDAT		;fill with FILDAT now
	mov	b,a
	mov	a,l		;restore a=address low byte

FB1:	sui	80h		;end of fill data?
	cz	ISBCSM		;y: do stop byte & checksum

	mov	m,b		;write data
	inr	l
	jnz	CBLUP2		;next byte

	inr	h		;next sector
	dcr	c		;more sectors?
	jnz	CBLUP1

	ret

;----Local subroutine-----------------------------------------
; Install stop byte and checksum in the correct byte position
; in the buffer. Note that with 128 data bytes, the checksum
; will be 0 for even FILDAT, and 80h for odd FILDAT.
; For system tracks, the checksum goes in sector byte 132.
; For data tracks, it goes in sector byte 4.
; On Entry:
;   a=0
;   hl=address of last data byte + 1
;   c=remaining sectors
; On Exit:
;   b=0
;   System track: hl=address of byte after checksum
;   data track: hl=address of byte after stop byte
;------------------------------------------------------------
ISBCSM:	mov	b,a		;data=0 for ret
	mvi	m,SSTOPR	;install stop byte
	inr	l		;bump pointers

	lda	FILDAT		;compute checksum
	ani	1		;will either be 0 or 80h
	rrc
	mov	m,a		;put checksum after stop byte

	inr	l		;one past checksum
	rnz			;z means its a data track

; Put checksum in byte 4 for a data track

	mvi	l,(256-SECSIZ)+DTCKSM
	mov	m,a		;install checksum
	mvi	l,0FFh		;last sector byte
	ret			;byte after stop will get 0

;===Subroutine end=========================
;Report retry failure
; On Exit:
;   a = 0
;   Z  set to give up on this track
;===========================================
BADTRK:	call	ILPRNT
	db	' FAI','L'+80h
	xra	a		;set Z: give up on this track
	ret

;===Subroutine==============================
;Report Write retry
; with opportunity for user to abort
; On Entry:
;   d = remaining retries+1
;   e = track number
; On Exit:
;   d decremented
;   Z  cleared to retry the track
;   Z  set to give up on this track
;   minidisk controller has been nudged
; Trashes a,bc,hl
;===========================================
VETELL:	dcr	d		;too many retries?
	jz	BADTRK

	call	CILPRT
	db	'Retry on track',' '+80h

	mov	a,e		;track number
	call	PADEC2

; Fall into SELECT to give the user a chance to abort,
; and to reload the head
	
;===Subroutine===========================================
; Give user a chance to abort, then wait for user to
; insert a diskette into the destination drive, and then
; load that drive's head.  Note that a minidisk will
; always report that it is ready. Minidisks will hang
; (later on) waiting for sector 0F, until a few seconds
; after the user inserts a disk.
;On Entry:
;  DSTDSK=drive to select
;On Exit:
;  a=HDLOAD
;  Z cleared
;========================================================
SELECT:	mvi	a,CONST		;console status
	call	GOBIOS		;via CP/M BIOS
	ora	a		;any chr waiting?
	cnz	GETCON		;y: test it for abort chr

	lda	DSTDSK		;enable destination disk
	out	DENABL

	in	DSTAT		;Read drive status
	ani	DRVRDY		;Diskette in drive?
	jnz	SELECT		;no: wait for drive ready

	mvi	a,HDLOAD	;Load 8" disk head, or enable
	out	DCTRL		;..minidisk for 6.4 Sec
	ora	a		;clear Z flag
	ret

;===Subroutine========
; Restore to track 0
;=====================
RESTOR:	mvi	a,STPOUT	;Step out to track 0
	call	STEP
	jnz	RESTOR
	ret

;===Subroutine=======================
; Step once, and wait for completion
; On Entry:
;   a=STEPIN or STPOUT
; On Exit:
;   z set if on track 0
;====================================
STEP:	out	DCTRL		;step in/out

WSTEP:	in	DSTAT		;wait for step to complete
	rrc			;put MVHEAD bit in carry
	rrc			;is the servo stable?
	jc	WSTEP		;no: wait for servo to settle

	ani	TRACK0/4	;Are we at track 00?

	ret

;===Subroutine=========================================
; Print a as 2 decimal digits on the console
; On Entry:
;  b=value, a < 100
; Trashes a,bc
;=======================================================

; Divide a by c (=10) and print result

PADEC2:	mvi	c,10
	mvi	b,0FFh		;DIGLP will go once to many

DIGLP:	inr	b
	sub	c
	jnc	DIGLP

	add	c		;loop went once 2 many
	mov	c,a		;save remainder in c
				;quotient is in b

	mov	a,b		;quotient
	call	PASCII

; Print remainder = lsd
	mov	a,c		;remainder is least sig digit

; Fall into PASCII

;===Subroutine=============================
; Print character in a as ASCII
; trashes a
;==========================================
PASCII:	adi	'0'		;make it ASCII

; Fall into PRINTA

;===Subroutine=============================
; Print character in a on console via BIOS
; trashes a
;==========================================
PRINTA:	push	b
	ani	7Fh		;strip end-of-string
	mov	c,a		;value to print
	mvi	a,CONOUT

	db	06h		;'mvi b' skips one instr.

; Fall into GOBIOS, skipping 'push b'

;===Subroutine=============================
; Go call a BIOS driver directly
; On Entry:
;   c=value for BIOS routine, if any
;   a = BIOS call address offset
; On Return:
;   psw is as BIOS left it
;==========================================
GOBIOS:	push	b

	push	d
	push	h

	call	DOBIOS		;BIOS entry in a
	di			;MP/M II's BDOS enables ints

	pop	h
	pop	d
	pop	b
	ret

;===Subroutine============================
; Go call a BIOS driver directly
; On Entry:
;   a = BIOS call address offset
;  all other registers as BIOS needs them
; On Return:
;   all registers as BIOS left them
;=========================================
DOBIOS:	lhld	WBOOTA		;get BIOS base address
	mov	l,a		;a has jump vector

	pchl			;'call' BIOS routine

;===Subroutine=========================================
; Print CR, LF, then In-line Message
;  The call to ILPRNT is followed by a message string.
;  The last message chr has its msb set.
; Trashes a
;======================================================
CILPRT:	CALL	ILPRNT
	DB	CR,LF+80H

; Fall into ILPRNT

;===Subroutine=========================================
; Print In-line Message
;  The call to ILPRNT is followed by a message string.
;  The last message chr has its msb set.
; On Exit:
;  Z cleared
; Trashes a
;======================================================
ILPRNT:	xthl			;Save hl, get msg addr

IPLOOP:	mov	a,m
	call	PRINTA		;print byte
	mov	a,m		;end?
	inx	h		;Next byte
	ora	a		;msb set?
	jp	IPLOOP		;Do all bytes of msg

	xthl			;Restore hl,
				;..get return address
	ret

;===Subroutine=========================
; Ask user to insert a disk
; On Exit:
;   Z set if user typed "y"
;======================================
CONFRM:	call	CILPRT
	db	'Put disk in',' '+80h

	lda	DSTDSK
	mov	d,a
	lda	DOFFST		;get drive offset
	add	d		;add drive letter
	adi	'A'		;make it a drive letter
	call	PRINTA

; Fall inot ASKRDY

;===Subroutine=============
; Ask if the user is ready
; On Exit:
;   Z set if Y
;==========================
ASKRDY:	call	CILPRT
	db	'Read','y'+80h

; Fall into ASKYN

;===Subroutine========================================
; Ask user Y or N, accepting lowercase too. Spin here
; until Y or N typed, echoing only a Y or N.
; (GETCON will abort if ABTCHR is typed.) 
; On Exit:
;   Z set if Y, clear if N
;=====================================================
ASKYN:	call	ILPRNT
	db	' (Y/N)','?'+80h

ASKAGN:	call	GETCON		;get user input

	cpi	'Y'
	jz	ASKYN1
	
	cpi	'N'
	jnz	ASKAGN		;accept nothing else
	
	ora	a		;clear Z

;Y or N - echo, return with Z correctly set, chr in a

ASKYN1:	push	psw
	call	PRINTA		;echo
	pop	psw

	ret

;===Subroutine============================================
; Get one console chr, abort if it is the abort character
; On Exit:
;  a=console chr
;=========================================================
GETCON:	mvi	a,CONIN		;console input
	call	GOBIOS		;via CP/M BIOS

	ani	('a'-'A') xor 7Fh
				;strip parity, make uppercase

	cpi	ABTCHR		;abort?
	rnz			;n: return with a=uppercase chr

; Abort character detected. Fall into CPMEXT

;===Exit==============================================
; Give the user a chance to replace the CP/M diskette
; if drive A: is a floppy disk (not a hard disk)
;=====================================================
CPMEXT:	lda	MPM		;MP/M II?
	ora	a
	jnz	MPMEXT		;y: no message

	lda	DOFFST		;hard disk CP/M?
	ora	a
	jnz	DISEXT		;y: no message

WAITY:	call	CILPRT
	db 'Put CP/M disk in A',':'+80h

	call	ASKRDY		;ready?
	jnz	WAITY

; Fall into DISEXT

;===Exit=========================================
; Disable the disk controller and return to CP/M
;================================================
DISEXT:	lda	MPM		;MP/M II?
	ora	a
	jnz	MPMEXT		;y: the disks may not be ours

	mvi	a,DDISBL	;disable disk controller
	out	DENABL

	jmp	WBOOT

;===Exit=======================================================
; MP/M II: give back the disks, reset the drive so that MP/M II
; logs it in again, and return to MP/M II
;==============================================================
MPMEXT:	lda	DSTDSK		;formatted A:?
	ora	a
	jnz	MPMX1		;n

	lda	MXHELD		;did we take A:?
	ora	a
	jz	MPMX1		;n: the system disk is in A:

WAITM:	call	CILPRT
	db 'Put MP/M II disk in A',':'+80h

	call	ASKRDY		;ready?
	jnz	WAITM

MPMX1:	call	RELMX		;give back the disks

	lda	DSTDSK		;drive chosen?
	cpi	MAXDRV+1
	cc	RSTDRV		;y: reset it

	jmp	WBOOT

;===Subroutine=================================================
; MP/M II: reset the drive, then take the MXDisk queue, so that
; no other process uses the disk controller. Exit if a process
; has a file open on the drive.
; On Exit:
;   the disks are ours, MXHELD=1
;   interrupts disabled
; Trashes all registers
;==============================================================
GETDSK:	lda	MPM		;MP/M II?
	ora	a
	rz			;n: nothing to do

	lda	MXHELD		;already ours?
	ora	a
	rnz			;y: nothing to do

	call	RSTDRV		;reset the drive
	ora	a		;refused?
	jnz	ERROPN		;y: a file is open on it

	mvi	c,READQ		;wait for the MXDisk queue
	call	MXCALL
	di			;no interrupts while ours

	mvi	a,1
	sta	MXHELD
	ret

;===Subroutine=================================================
; MP/M II: give back the MXDisk queue, if we hold it. The disk
; controller is disabled first, so that the XIOS selects its
; drive again.
; Trashes all registers
;==============================================================
RELMX:	lda	MXHELD		;do we hold the disks?
	ora	a
	rz			;n: nothing to do

	xra	a
	sta	MXHELD

	mvi	a,DDISBL	;disable disk controller
	out	DENABL

	mvi	c,WRITEQ	;give back the MXDisk queue

; Fall into MXCALL

;===Subroutine==================================
; MP/M II: queue call for the MXDisk queue
; On Entry:
;   c = BDOS function
; On Exit:
;   a = BDOS result
;===============================================
MXCALL:	lxi	d,MXQCB
	jmp	BDOS

;===Subroutine=================================================
; MP/M II: reset the drive in DSTDSK
; On Exit:
;   a = 0 if reset, FFh if a process has a file open on it
; Trashes all registers
;==============================================================
RSTDRV:	lda	DSTDSK
	mov	b,a		;b counts shifts
	mvi	a,1		;drive A: is bit 0

RSTLP:	dcr	b
	jm	RSTGO
	add	a		;next drive
	jmp	RSTLP

RSTGO:	mov	e,a		;de=drive vector
	mvi	d,0
	mvi	c,DRESET
	jmp	BDOS

;***Exit**********************************
; MP/M II: a file is open on the drive
;*****************************************
ERROPN:	call	CILPRT
	db	'A file is open on that driv','e'+80h
	jmp	MPMEXT

;===Load-Initialized RAM Variables=============================
VSTART:
NOSYS:	db	0	;1: do only non-system tracks
FILDAT:	db	DFDATA	;sector fill data
SPT:	db	SPT8	;sectors per track
MAXTRK:	db	MAXTK8	;max track (must follow SPT)
MINTRK:	db	0	;min track number
NSTRKS:	db	NSTK8	;Number of system-type tracks
BDTRAC:	db	BDTK8	;Basic directory track (follows NSTRKS)
DSTDSK:	db	0FFh	;destination disk
DOFFST:	db	0	;CP/M offset to floppy drives
MPM:	db	0	;1: running under MP/M II
MXHELD:	db	0	;1: MP/M II: we hold the disks

;MP/M II user queue control block for the MXDisk queue
MXQCB:	dw	0	;set by open queue
	dw	MXMSG	;message address (no message)
	db	'MXDisk  '
MXMSG:	db	0

;===========================================================
; Track buffer is 32 x 256 bytes = 8K bytes
; Each sector occupies the last 137 bytes of a 256-byte
; page.This buffer over-writes the following initialization.
; The address of TRKBUF actually overlays the above code a
; bit, because its first (256-SECSIZE) bytes are not used.
;===========================================================
TRKBUF	equ	($-(256-SECSIZ)+255) and 0FF00h

;*************************************************************
; The following subroutines are used only during the initial *
; command line processing, and get wiped out by the TRKBUF,  *
; once initialization is complete.                           *
;*************************************************************

;***Subroutine*****************************************
; Initialization: parse command line, set up RAM
; variables based on user input.
; On Exit:
;   MINTRK = starting track
;   MAXTRK = ending track
;   NSTRKS = number of system tracks
;   NSTRKS >= MINTRK
;   FILDAT = data to write into sector Data fields
;   DSTDSK is selected
;   head is loaded and on track 0
;******************************************************
INIT:	di			;no interrupts ever.

;Ask CP/M which version it is, and remember in TBMAX
;so that we can adjust a few paramaters during init.

	mvi	c,BVERSN	;Ask CP/M its version
	call	BDOS		;result in hl
	di			;MP/M II's BDOS enables ints

	dcr	h		;h=1 means MP/M
	jnz	NOTMPM

	mvi	a,1		;MP/M II: no SELDSK, no offset
	sta	MPM

	mvi	c,OPENQ		;open the MXDisk queue
	call	MXCALL
	di
	ora	a		;found?
	jz	FDCPM		;y: go parse the command line

	call	CILPRT
	db	'No MXDisk queu','e'+80h
	jmp	WBOOT

NOTMPM:	mov	a,l
	push	psw		;temp save for later

; Look at drive A sectors/track to determine the drive
; offset =0 for floppy disk CP/M, =2 for hard disk CP/M.

	mvi	c,0		;select disk 0=A
	mvi	a,SELDSK	;SELDSK returns hl=DPH
	call	DOBIOS

	lxi	b,10		;offset to DPH address

	pop	psw		;version from CP/M
	sui	30h		;msb means 2.x or lower
	jc	FLB1
	mvi	c,12		;CP/M 3's offset
FLB1:
	dad	b
	mov	e,m		;get address of DPB
	inx	h
	mov	d,m		;de=address of DPB
	xchg			;hl=address of DPB

	mvi	a,SPT8		;DPB first byte = SPT
	cmp	m		;greater than 8" SPT?
	jnc	FDCPM		;n: it's a floppy CP/M

	mvi	a,2		;y: hard disk offset = 2
	sta	DOFFST		;remember offset
FDCPM:

; Prepare to parse the command line

	lxi	h,COMBUF	;CP/M put cmd line here

	mov	b,m		;1st byte is byte count
	inx	h		;point to the string

	call	SSKIP		;skip initial spaces; get 1st
	jz	HLPEXT		;no parameters?

;------------------------------
; Get destination drive number
;------------------------------
	push	h
	lxi	h,DOFFST
	sui	'A'		;un-ASCII
	sub	m		;un-offset
	pop	h
	cpi	MAXDRV+1
	jnc	BADINP		;no carry: bogus source drive
	sta	DSTDSK		;save destination disk

	call	CMDCHR		;get mandatory colon
	cpi	':'
	jnz	BADINP

;-------------------------------------------------------------
; Parse all command line options & set variables accordingly.
; Each option must be preceeded by a '/' Options may be
; preceeded by any reasonable number of spaces.
;-------------------------------------------------------------
OPTLUP:	call	SSKIP		;skip spaces
	jz	OPTDON		;end of input line?

	cpi	'/'		;all start with /
	jnz	BADINP		;error:no slash

	call	CMDCHR		;Get an option chr, a=0 if none

;-------------------------------------------------------------
; Got a command line option in a. Loop through table of
; options, looking for a match. Update the appropriate option
; variable with the table value. Error exit if not in table.
;  a=option character
;-------------------------------------------------------------
	push	h		;Save COMBUF pointer
	lxi	h,OPTTAB

OPHUNT:	cmp	m		;Match? (alpha order)
	inx	h		;get var value
	mov	c,m
	inx	h		;get var address offset
	mov	e,m
	inx	h

	jc	BADINP		;not in table
	jnz	OPHUNT		;No match: keep looking

;---------------------------------------------
; Option match. Save value, and look for more
;  c = option value
;  e = address offset
;---------------------------------------------
OPMTCH:	lxi	h,VSTART	;start of variable table
	mvi	d,0

	dad	d		;offset to our variable
	xchg			;address to de
	pop	h		;command line pointer
	mov	a,c		;get value?
	inr	a		;FF means yes
	cz	GETVAL		;get c=hex value
	mov	a,c
	stax	d

	jmp	OPTLUP		;look for more
OPTDON:

;--------------------------
; Confirm format with user
;--------------------------
	lda	DSTDSK		;the system disk?
	ora	a
	cz	GETDSK		;y: MP/M II: take the disks now

	call	CONFRM
	jz	CONFOK		;y: go format

	call	RELMX		;MP/M II: give back the disks
	jmp	WBOOT		;abort if not y

CONFOK:	call	GETDSK		;MP/M II: take the disks

;---------------------------------------------------------
; Wait for user to insert a diskette into the destination
; drive, and then load that drive's head.  Note that a
; minidisk will always report that it is ready. Minidisks
; will hang (later on) waiting for sector 0F, until a few
; seconds after the user inserts a disk.
;---------------------------------------------------------
	mvi	a,DDISBL
	out	DENABL		;disable current drive

	call	SELECT		;select destination drive

;-------------------------------------------
; Restore disk to track 0
; Step away from track 0 first, in case
; the head is jammed against the end-stop.
;------------------------------------------
RSTIN:	mvi	a,STEPIN	;Step in until
	call	STEP		;..no longer on track 0
	jz	RSTIN

	call	RESTOR

;-------------------------------------------------------------
; Determine if this is an 8" disk or a minidisk by seeing
; what sector follows sector 0Fh. An 8" disk has 20h sectors,
; numbered 0-1Fh. A minidisk has 10h sectors, numbered 0-0Fh.
; Print particulars of format or copy on console.
; On Entry:
;   set up for 8" disks
;     MAXTRK = MAXTK8
;     SPT = SPT8
;     BDTRAC = BDTK8
;     NSTRKS = NSTK8
; On Exit, if a minidisk is discovered:
;   set up for minidisks
;     MAXTRK = MAXTK5
;     SPT = SPT5
;     BDTRAC = BDTK5
;     if /N option
;        NSTRKS = NSTK5
;     else
;        NSTRKS = 0
;-------------------------------------------------------------

	lxi	h,0		;initialize 14.9-rev timeout
				;cycles per rev 300,000/68.5=4380
	lxi	b,((SPT5-1)*2*256)+(SECMSK+SVALID)

;Wait for the highest minidisk sector, sector number 0Fh
;Timeout if 10-sector or soft sector disk
;(in-to-in is 23.5 uS, must be less than 30 uS)

CKDSK0:	in	DSECTR		;(10)Read the sector position
	ana	c		;(4)Mask sector bits, and hunt
	cmp	b		;(4)..for minidisk last sector
	jz	CKDSK1		;(10)..only while SVALID is 0

	dcx	h		;(5)Bump timeout timer

	in	DSECTR		;(10)Read the sector position
	ana	c		;(4)Mask sector bits, and hunt
	cmp	b		;(4)..for minidisk last sector
	jz	CKDSK1		;(10)..only while SVALID is 0

	in	DSECTR		;(10)Read the sector position
	ana	c		;(4)Mask sector bits, and hunt
	cmp	b		;(4)..for minidisk last sector
	jz	CKDSK1		;(10)..only while SVALID is 0

	mov	a,h		;(5)Timeout?
	ora	l		;(4)
	jz	ERRDSS		;(10)Implies 10- or soft-sector

	in	DSECTR		;(10)Read the sector position
	ana	c		;(4)Mask sector bits, and hunt
	cmp	b		;(4)..for minidisk last sector
	jnz	CKDSK0		;(10)..only while SVALID is 0
				;137 cycles=68.5 uS per pass
CKDSK1:

; Wait for this sector to pass

CKDSK2:	in	DSECTR		;Read the sector position
	rrc			;wait for invalid sector
	jnc	CKDSK2

; Wait for and get the next sector number

CKDSK3:	in	DSECTR		;Read the sector position
	rrc			;put SVALID in carry
	jc	CKDSK3		;wait for sector to be valid

;------------------
; Starting message
;------------------
	push	psw
	call	CILPRT
	db	'Formatting ','a'+80h	
	pop	psw

; The next sector after sector 0Fh will be 0 for a minidisk,
; and 10h for an 8" disk.

; The load initialized variables for 8" disks. If this is
; an 8" disk, then we only need to announce the disk type.

	ani	SPT8-1		;lose the other bits
	jz	ITSMNI		;sector 0: it's a minidisk

;--------------------------------------------
; We have an 8" disk. Everything is already
; setup right, so just announce it.
;--------------------------------------------
	call	ILPRNT
	db	'n 8" Dis','k'+80h
	jmp	SETUP

;----------------------------------------
; We have a minidisk, so set up the disk 
; variables appropriately.
;----------------------------------------
ITSMNI:	lxi	h,MAXTK5*256+SPT5
	shld	SPT		;saves also MAXTRK

	lxi	h,BDTK5*256+0	;l may get changed

; Minidisk format: skip system tracks if /N option selected

	lda	NOSYS		;/N selected?
	ora	a
	jz	SUMINI		;n: announce minidisk

	call	ILPRNT		;y: announce bootable minidisk
	db	' bootabl','e'+80h

	mvi	l,NSTK5		;skip system tracks

; Save minidisk parameters, and announce minidisk

SUMINI:	SHLD	NSTRKS		;saves also BDTRAC

	call	ILPRNT
	db	' minidis','k'+80h
	
; Fall into SETUP

;------------------------------------
; Adjust parameters based on options
;------------------------------------
; Increase MINTRK if /N option (skip system tracks) is selected

SETUP:	lda	NOSYS		;no system?
	ora	a
	jz	NS1

	lda	NSTRKS		;skip system tracks
	sta	MINTRK

	call	CILPRT
	db	'Basic/DOS non-system tracks onl','y'+80h
NS1:

;-----------------
; Return from INIT
;-----------------
	ret

;***Subroutine**********************************
; Get a 2-digit hex value from the command line
; On Entry:
;   hl=address of next command line chr
;   b=remaining bytes in command line buffer
; On Exit:
;   c has new value
;   hl, b advanced
;   a trashed
;***********************************************
GETVAL:	mvi	c,0		;initial value

GVALUP:	call	CMDCHR
	rz			;Z means no chr
	cpi	' '		;Space means end but no error
	rz
	cpi	'/'		;Next param crammed against this?
	jz	BACKUP		;ok but backup

; Convert hex digit input to binary

	cpi	'9'+1		;below ASCII 9?
	jc	HC1		;y: deal with digit

	cpi	'A'		;Between '9' and 'A'?
	jc	BADINP		;y: error
	sui	'A'-'9'-1	;N: subtract offset	

HC1:	sui	'0'		;un-ASCII
	cpi	10h		;valid?
	jnc	BADINP
	
; Combine with previous digit: c = c * 16 + a

	push	d
	mov	e,a		;temp
	mov	a,c		;previous digit
	add	a
	add	a
	add	a
	add	a		;times 16
	add	e		;plus new digit
	mov	c,a		;..is the new result
	pop	d

	jmp	GVALUP

BACKUP:	dcx	h		;undo CMDCHR
	inr	b
	ret

;***Subroutine************************************
; Skip over spaces in command line buffer until
; a non-space character is found 
; On Entry:
;    b has remaining COMBUF byte count
;    hl points to the next chr in COMBUF
; On Exit:
;    a = chr from COMBUF
;    b has been decremented
;    hl has been advanced
;    Z=1 means end of buffer (and a is not valid)
;*************************************************
SSKIP:	call	CMDCHR
	rz			;Z set for nothing left
	cpi	' '		;white space?
	jz	SSKIP
	ret			;chr in a, Z clear

;***Subroutine***************************
; Get next chr from command line buffer
; On Entry:
;    b has remaining COMBUF byte count
;    hl points to the next chr in COMBUF
; On Exit:
;    a = chr from COMBUF, parity stripped
;    b has been decremented
;    hl has been advanced
;    Z=1 means end of buffer, and a=0
;*****************************************
CMDCHR:	mov	a,b		;End of buffer already?
	ora	a		;also clears carry
	rz			;and clears a

	mov	a,m		;get buffer chr
	inx	h		;bump buffer pointers
	dcr	b	
	ani	7FH		;Strip parity, clear Z
	ret			;with Z cleared


;***Exit**************************
; Soft-sector or 10-sector disk.
; Print message and return to CP/M
;*********************************
ERRDSS:	call	CILPRT
	db	'Unsupported disk typ','e'+80h
	jmp	DISEXT

;***Exit****************************************
; Input error. Print message and return to CP/M
;***********************************************
BADINP:	call	CILPRT
	db	'Illegal optio','n'+80h
	
; Fall into HLPEXT

;***Exit***************************
; Print help, then return to CP/M.
; Pause after each page.
;**********************************
HLPEXT:	call	CILPRT

;    1234567890123456789012345678901234567890123456789012345678901234
 db 'Altair Disk Format Utility   Vers. '
 db ((VERSION AND 0F00h)/256)+'0','.'
 db ((VERSION AND 0F0h)/16)+'0',(VERSION AND 0Fh) +'0'
 db ' by M. Eberhard'
 db CR,LF,CR,LF
 db 'USAGE'
 db CR,LF
 db ' AFORMAT <d>: [/Fhh] [/N]'
 db CR,LF
 db '  <d> is the drive to format, from',' '+80h

	lda	DOFFST		;min drive number
	adi	'A'
	mov	d,a		;save
	call	PRINTA

	call	ILPRNT
	db	' through',' '+80h

	mov	a,d
	adi	MAXDRV
	call	PRINTA

	lxi	d,HLPMSG

; Print remaining help pages, asking the user for more

PRINTH:	ldax	d
	call	PRINTA		;strips msb

	ldax	d		;test for end
	inx	d
	ora	a		;msb set?
	jp	PRINTH


	ldax	d		;is next chr the null term?
	ora	a
	jz	DISEXT		;y: done

	call	CILPRT
	db	CR,LF,'Mor','e'+80h

	call	ASKYN
	jz	PRINTH

	jmp	DISEXT

;***Help Strings*****************************************
;* each message page is terminated by msb set. The help
;* message continues until final null termination.
;********************************************************
HLPMSG:
 db CR,LF
 db '  /Fhh Fills all data fields with hh hex (Default: E5)'
 db CR,LF
 db '  /N Formats just non-system tracks, only for Basic/DOS disk'
 db 's'+80h

 db CR,LF,CR,LF
;    1234567890123456789012345678901234567890123456789012345678901234
 db 'AFORMAT formats and verifies Altair 8" disks and minidisks for'
 db CR,LF
 db 'use with Altair Basic, DOS, CP/M, or MP/M II.'

 db CR,LF,CR,LF
;    1234567890123456789012345678901234567890123456789012345678901234
 db 'USING AFORMAT'
 db CR,LF,CR,LF
 db 'To format C:, type "AFORMAT C:"  An 8" disk will be formatted'
 db CR,LF
 db 'with 6 system tracks and 71 non-system tracks; a minidisk will'
 db CR,LF
 db 'be formatted with 35 non-system tracks. (Use ACOPY or SYSGEN to'
 db CR,LF
 db 'copy system tracks onto the the disk, to make it bootable.)'
 db CR,LF,CR,LF
 db '/N (re)formats just the non-system tracks on an Altair Basic/DOS'
 db CR,LF
 db 'disk. Do not use /N for CP/M disks'
 db '.'+80h

 db CR,LF,CR,LF
;    1234567890123456789012345678901234567890123456789012345678901234
 db 'SYSTEM TRACKS'
 db CR,LF,CR,LF
 db 'Altair disks have 2 track types, with different formats. Tracks'
 db CR,LF
 db '0-5 on an 8" disk, and tracks 0-11 on a bootable minidisk are'
 db CR,LF
 db 'formatted as system tracks. All other tracks are non-system'
 db CR,LF
 db 'tracks. A non-bootable minidisk only has non-system tracks. The'
 db CR,LF
 db 'Format does not depend on how the tracks are actually used. For'
 db CR,LF
 db 'example, 8" CP/M uses tracks 0-1 for its boot image, but tracks'
 db CR,LF
 db  '0-5 are all still formatted as system tracks'
 db '.'+80h

 db CR,LF,CR,LF
;    1234567890123456789012345678901234567890123456789012345678901234
 db 'DIRECTORY INITIALIZATION'
 db CR,LF,CR,LF
 db 'Altair software keeps the directory on track 70 of 8" disks and'
 db CR,LF
 db 'track 34 of minidisks, requiring a "Stopper Byte" (FFh) to mark'
 db CR,LF
 db 'the directory end. AFORMAT installs an FFh in data byte 0,'
 db CR,LF
 db 'sector 0 of the directory track, indicating an empty Altair'
 db CR,LF
 db 'directory. (CP/M will ignore this FFh.)'
 db CR,LF,CR,LF
 db 'CP/M keeps the directory on the first track(s) after the CP/M'
 db CR,LF
 db 'boot tracks. CP/M interprets a directory filled with E5 as'
 db CR,LF
 db 'empty, hence the default data-field fill value is E5. (Altair'
 db CR,LF
 db 'software ignores all data bytes on an empty disk.)'
 db CR,LF+80h

 db 0		;final termination of help message

;******************************************************
;Command Line Options Table
; Table entries must be in alphabetical order, and
; terminated with 0FFh
;
; Each entry is 3 bytes long:
;  byte1 = uppercase legal option letter
;  byte2 = value for variable.
;          FFh means get hex value from command line
;  byte3 = variable address offset
;******************************************************
OPTTAB:
;Fill Value: gets command line value and puts it in FILDAT	
	db	'F',0FFh,FILDAT-VSTART

;Non-System tracks only
	db	'N',1,NOSYS-VSTART

;end-of-table marker
	db	0FFh

;===========================================
; System Stack
; Tucked between sectors in TRKBUF, leaving
; (256-SECSIZ)=119 bytes for the stack 
; (Grows downward from this address.)
;===========================================
STACK	equ	(($+255) and 0FF00h)+(256-SECSIZ)

	END







