;fsm 
;input = r17:r16
/*
.def pstatel = r24		;low byte of presnt state
.def pstateh = r25		;high byte of present state

.equ i0 = $00
.equ i1	= $01
.equ i2 = $02
.equ i3 = $03
.equ eol = $ff


state_table:
	;keycode	NxtSt	Task
s0:	.dw	i1,		s1,		task1
	.dw	i3,		s2,		task1
	.dw	eol,	s0,		task0

s1:	.dw	i0,		s0,		task3
	.dw	i2,		s1,		task1
	.dw	eol,	s0,		task0

s2:	.dw	i0,		s0,		task3
	.dw	i2,		s2,		task2
	.dw	eol,	s0,		task0

fsm:
	mov ZL, pstatel		;ld z-ptr with pstate address*2
	add ZL, ZL			;(as z is used as a byte ptr w/LPM)
	mov ZH, pstateh
	adc ZH, ZH

	;search for input keyword match in present state subtable
	; of the state table

state:
	lpm	r18, Z+	;get keycode low byte from state table
	cp r18, r16	;compare table entry with low byte
	brne check_eol	; of input keycode

	;if bytes match, high byes must be checked

lowmatch:
	lpm r19, Z+	;get highbyte of keycode
	cp r19, r17	; from state table
	breq match	;if match, z pointing to next state
	sbiw ZH:ZL, $01	;else adjust z-ptr

	;check for table keycode for eol value
check_eol:
	cpi r18, low(eol)	;cp low byte of table entry
	breq lowmatch_eol	; with low byte of eol
	adiw ZH:ZL, $01		;no match fo low bytes, adjust z-ptr
	rjmp nomatch

	;low byte of osmbol matches eol, high bytes must be checked
lowmatch_eol:
	lpm r18, z+		;get high byte of keycode from table
	cpi r19, HIGH(eol)	;compare high byte of table entry
	breq match
nomatch:
	adiw ZL, $04		;adjust zptr to nexyt row of the state table and
	rjmp search			; continue searching
	
	;a match on input value to keycode has been found,
	;the next word in the rowist he next state adress,
	; the word after that is the taskk subroutine's address
match:
	lpm pstatel, z+		;copy next state address
	lpm pstateh, z+		; to present state (r25:r24);
	lpm r20, z+			;get task/subr addr from the state table
	lpm r21, z	
	mov ZL, r20
	mov ZH, r21
	icall				;zptr is now used as a word ptr
	ret

	*/

	.nolist

.include "m16def.inc"

.list

.equ stacklength = 32

.dseg

myspl: .byte 1 ;user stack pointer low

mysph: .byte 1 ;user stack pointer high

mystack: .byte stacklength ;user stack

.cseg

reset:

 rjmp start

;push subroutine - byte to be pushed must be in r16

mypushdown:

 lds XL, myspl

 lds XH, mysph

 st X+, r16

 sts myspl, XL
 //mov r21 , XL 

 sts mysph, XH
// MOV R22, XH

 ret

;pop subroutine - byte poped is returned in r16


mypopup:

 lds XL, myspl

 lds XH, mysph

 ld r16, -X

 sts myspl, XL

 sts mysph, XH

 ret

 

;program to test mypush and pop mypop subroutines

start:

 ldi r16, LOW(RAMEND) ;load stack pointer

 out SPL, r16

 ldi r16, HIGH(RAMEND)

 out SPH, r16

 ldi r16, LOW(mystack) ;load user stack pointer

 sts myspl, r16

 ldi r16, HIGH(mystack)

 sts mysph, r16

main_loop:

 ldi r16, $00 ;initailize data to be pushed on user stack

 ldi r18, stacklength ;loop control variable for pushes and pops

pushloop:

 call mypushdown ;push a byte on user stack

 inc r16 ;increment data value

 dec r18 ;decrement loop counter

 brne pushloop ;branch is user stack not full

 ldi r18, stacklength

poploop:

 call mypopup ;pop a byte from user stack

 dec r18 ;decrement loop counter

 brne poploop ;branch if user stack not empty

 rjmp main_loop