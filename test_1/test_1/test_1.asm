/*
 * test_1.asm
 *
 *  Created: 10/5/2014 8:36:59 PM
 *   Author: radra_000
 */ 


 .nolist
 .include "m16def.inc"
 .list
 /*
ldi r16, $00
out ddra, r16
ldi r16, $0f
out porta, r16
ldi r16, $ff
out ddrb, r16

main_loop:
	in r18, pina
	ldi r19,4
	ldi r20, 0b00001111
	sbic pina,6
	ldi r21,$1
	sbic pina,7
	ldi r22,$1
	cp r21,r22
	brne on_1
loop:
x	out portb, r18
	rjmp loop
on_1:
	sbi portb,7
	rjmp loop
*/
sbi portb, 0
ldi r16,$00
dec r16

