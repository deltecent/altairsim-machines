;	SS1TEST - test a CompuPro System Support 1 at 50h from the
;	front panel of an Altair, without a console or an operating
;	system. It tests what SS1XIOS.ASM uses: the MSM5832 clock,
;	8253 timer 0, the two 8259As and the interrupt acknowledge.
;
;	Load SS1TEST.HEX, or deposit the bytes, and run at 0100H.
;	The program stops at a HLT. Then examine RESULT at 0103H:
;
;	  00	every test passed
;	  01	the clock digits are not valid: no board at 50h?
;	  02	timer 0 does not count: no clock on bus pin 49?
;	  03	timer 0 counts at the wrong rate: not 2 MHz on pin 49?
;	  04	slave IR1 is high when timer 0 output is low: J8?
;	  05	slave IR1 does not go high at the end of the count: J8?
;	  06	the master does not see the slave interrupt
;	  07	slave IR1 stays high after timer 0 is loaded again
;	  08	no interrupt arrives: bus pin 73 or the master 8259A
;	  09	an 8259A stays in service after the end of interrupt
;
;	If the machine does not stop, or stops at a different HLT,
;	look at RESULT too. It holds the number of the test that was
;	running. A 08 there means the CALL of the interrupt
;	acknowledge went to a wrong address: check J13 (Z-C) and
;	that every memory board turns off on PHANTOM*.
;
;	Other results, for the front panel:
;	  0104H-0105H	timer 0 counts in the delay of test 3
;			(LSB first, about 5E1FH at 2 MHz)
;	  0106H-0107H	polls until IR1 went high in test 5
;			(LSB first, about 028DH at 2 MHz)
;	  0108H-0114H	MSM5832 digits 0-12: seconds, minutes,
;			hours, day of the week, day, month, year,
;			ones digit first
;
;	Interrupts stay disabled except in test 8. The program
;	writes a JMP at 0024H, which slave IR1 CALLs.
;
;	Revision history
;	1.0  23 October 2026  P. Linstruth
;	     First version
;
	org	100h

ss1	equ	50h		; base port
mpic0	equ	ss1+0		; master 8259A, A0=0
mpic1	equ	ss1+1		; master 8259A, A0=1
spic0	equ	ss1+2		; slave 8259A, A0=0
spic1	equ	ss1+3		; slave 8259A, A0=1
tmr0	equ	ss1+4		; 8253 counter 0
tmrctl	equ	ss1+7		; 8253 control word
clkcmd	equ	ss1+10		; MSM5832 command
clkdat	equ	ss1+11		; MSM5832 data

icw1	equ	3ch		; as SS1XIOS: level triggered, cascade
eoi	equ	20h		; OCW2: non-specific end of interrupt
rdirr	equ	0ah		; OCW3: read the IRR
rdisr	equ	0bh		; OCW3: read the ISR
tmrMode	equ	30h		; counter 0, LSB/MSB, mode 0: OUT low
tmrLat	equ	00h		; latch counter 0
tmrCnt	equ	33333		; 60 Hz from 2 MHz
clkRd	equ	50h		; MSM5832 Hold + Read
vector	equ	24h		; slave IR1 CALLs here

	jmp	start

result:	db	0ffh		; 0103H: the test that is running
diff:	dw	0		; 0104H: timer counts in test 3
loops:	dw	0		; 0106H: polls in test 5
clock:	ds	13		; 0108H: MSM5832 digits 0-12
flag:	db	0		; 0115H: set by the interrupt

start:	di
	lxi	sp,stack
	xra	a
	sta	flag
;
; Test 1: read the 13 digits of the clock. The seconds must be
;  valid BCD. With no board at 50h, each digit reads 0FH.
;
	mvi	a,1
	sta	result
	lxi	h,clock
	mvi	b,0
t1:	mov	a,b
	ori	clkRd
	out	clkcmd
	in	clkdat
	ani	0fh
	mov	m,a
	inx	h
	inr	b
	mov	a,b
	cpi	13
	jnz	t1
	xra	a
	out	clkcmd		; Hold off
	lda	clock
	cpi	10
	jnc	fail		; seconds, ones: 0-9
	lda	clock+1
	cpi	6
	jnc	fail		; seconds, tens: 0-5
;
; Test 2: timer 0 counts down. Test 3: at 2 MHz, it counts about
;  24,060 in a delay of 24,060 cycles of a 2 MHz 8080. Accept
;  11,776 to 48,127 (high byte 2EH to 0BBH).
;
	mvi	a,2
	sta	result
	mvi	a,tmrMode
	out	tmrctl
	mvi	a,0ffh
	out	tmr0
	out	tmr0		; count 0FFFFH
	call	rdtmr
	push	h		; first count
	lxi	b,1000
t2:	dcx	b		; 24 cycles each
	mov	a,b
	ora	c
	jnz	t2
	call	rdtmr
	pop	d		; HL = DE - HL
	mov	a,e
	sub	l
	mov	l,a
	mov	a,d
	sbb	h
	mov	h,a
	shld	diff
	ora	l
	jz	fail		; no change: the timer does not count
	mvi	a,3
	sta	result
	mov	a,h
	cpi	2eh
	jc	fail		; too slow
	cpi	0bch
	jnc	fail		; too fast
;
; Test 4: set up the 8259As as SS1XIOS does, and timer 0 as for
;  a tick. Timer 0 output is now low, so slave IR1 must be low.
;
	mvi	a,4
	sta	result
	mvi	a,icw1		; master
	out	mpic0
	xra	a		; ICW2
	out	mpic1
	mvi	a,80h		; ICW3: the slave is on IR7
	out	mpic1
	mvi	a,7fh		; OCW1: only IR7 open
	out	mpic1
	mvi	a,icw1		; slave
	out	spic0
	xra	a		; ICW2
	out	spic1
	mvi	a,07h		; ICW3: slave ID 7
	out	spic1
	mvi	a,0fdh		; OCW1: only IR1 open
	out	spic1
	mvi	a,rdirr		; a read of port 0 gives the IRR
	out	spic0
	out	mpic0
	call	settmr
	in	spic0
	ani	02h
	jnz	fail		; IR1 is high
;
; Test 5: after 33,333 counts (16.7 ms), timer 0 output and
;  slave IR1 go high. Wait for IR1 up to about 1.7 seconds.
;
	mvi	a,5
	sta	result
	lxi	d,0
t5:	in	spic0		; 51 cycles each
	ani	02h
	jnz	t5ok
	inx	d
	mov	a,d
	ora	e
	jnz	t5
	jmp	fail		; IR1 did not go high
t5ok:	xchg
	shld	loops
;
; Test 6: the slave interrupt output is on master IR7.
;
	mvi	a,6
	sta	result
	in	mpic0
	ani	80h
	jz	fail
;
; Test 7: a new mode word and count set timer 0 output low
;  again, as the interrupt handler of SS1XIOS does. IR1 and the
;  slave interrupt must go low.
;
	mvi	a,7
	sta	result
	call	settmr
	in	spic0
	ani	02h
	jnz	fail
	in	mpic0
	ani	80h
	jnz	fail
;
; Test 8: take one interrupt. Slave IR1 CALLs 0024H, which jumps
;  to INTRPT. INTRPT sets FLAG. Wait up to about 1.7 seconds.
;
	mvi	a,8
	sta	result
	mvi	a,0c3h
	sta	vector
	lxi	h,intrpt
	shld	vector+1	; JMP INTRPT at 0024H
	lxi	d,0
	ei
t8:	lda	flag		; 51 cycles each
	ora	a
	jnz	t8ok
	inx	d
	mov	a,d
	ora	e
	jnz	t8
	di
	jmp	fail		; no interrupt
t8ok:	di
;
; Test 9: after the end of interrupt, no level is in service.
;
	mvi	a,9
	sta	result
	mvi	a,rdisr		; a read of port 0 gives the ISR
	out	spic0
	out	mpic0
	in	spic0
	ora	a
	jnz	fail
	in	mpic0
	ora	a
	jnz	fail
;
; Every test passed.
;
	xra	a
	sta	result
	hlt
	jmp	$-1

fail:	hlt			; RESULT is the test that failed
	jmp	fail
;
; The interrupt handler of test 8. A new mode word sets timer 0
;  output low, and no count follows, so the timer stops. Then an
;  end of interrupt to the slave and the master. Interrupts stay
;  disabled.
;
intrpt:	push	psw
	mvi	a,tmrMode
	out	tmrctl
	mvi	a,eoi
	out	spic0
	out	mpic0
	mvi	a,1
	sta	flag
	pop	psw
	ret
;
; settmr - timer 0 in mode 0, count 33333.
;
settmr:	mvi	a,tmrMode
	out	tmrctl
	mvi	a,tmrCnt and 0ffh
	out	tmr0
	mvi	a,tmrCnt shr 8
	out	tmr0
	ret
;
; rdtmr - HL = the count of timer 0.
;
rdtmr:	mvi	a,tmrLat
	out	tmrctl
	in	tmr0
	mov	l,a
	in	tmr0
	mov	h,a
	ret

	ds	32
stack:
	end
