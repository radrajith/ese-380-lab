/*
 * incr_decr.asm
 *
 *  Created: 9/29/2014 5:02:01 PM
 *   Author: Raymond
 */ 


 .nolist
 .include "m16dec.inc"
 .list

  //load all the pins in port B, Port D and port A 0, as outputs, Port C (0,6,7) as inputs. 
 //pull ups enabled in port D and A
 reset:
    LDI R16, low(RAMEND)
	OUT SPL, R16
    LDI R16, high(RAMEND)
    OUT SPH, R16				;this code is for rcall, from ese 123
	ldi r16, $ff				;load r16 with 1's
	out PORTB, r16				;set up the 7seg disp
	ldi r16, $00				;load r16 with 0's
	out DDRD, r16				;set up dip switch, port d as input
	ldi r16, $ff				;load r16 with 1's
	out PORTD, r16				;set up the pull ups in D
	ldi r16, $c1				;set up pullups for
	out PORTD, r16				;the 8th 7th and 1st bit
	ldi r17, $2					;delay timer
	ldi r19, $9  				;clear r19 for use compare for overflow
	ldi r18, $00				;clear r18 for use on counter
	ldi r20, $00				;clear for overflow
main_loop:
	sbic PINC,0  				;check for button press increment
	rjmp dec_check				;keep checking
	rcall delay					;delay to check for bounce
	cp r18,r19
	breq overflow
	inc r18						;inc counter for LED
	rjmp bcd_7seg				;jump to bcd display
dec_check:						;check for dec pushbutton
	sbic PINC,6					;check if button is pressed
	rjmp reset_check			;if not jump to reset check
	rcall delay
	dec r18
	rjmp bcd_7seg
reset_check:
	sbic PINC,7
	rjmp main_loop
	rcall delay
	ldi r18,$40
	out PORTB, r18
	rjmp reset
overflow:
	ldi r20, $FE;
bcd_7seg:
	ldi ZH, high (table*2)		;set Z to start of table
	ldi ZL, high (table*2)		;
	ldi r16, $00				;clear for later use
	add ZL, r18					;add low byte
	adc ZH, r16					;add in the CY
	lpm r18,Z					;Load in the byte pattern from table into r18
display:
	out PORTA, r20				;ouput overflow
	out PORTB, r18				;output the LEDs
	sbis PINC, 0				;Check PINC0 for 
	rjmp display      			;when it is not pressed
	rcall delay					;check for the
	sbis PINC, 0				;debounce
	rjmp display				;if debounce then check again
	sbis PINC, 6				;Check PINC6 for 
	rjmp display      			;when it is not pressed
	rcall delay					;check for the
	sbis PINC, 6				;debounce
	rjmp display				;if debounce then check again
	rjmp main_loop
	;table of seven segment display 0-9
table: .db $40,$79,$24,$30,$19,$12,$03,$78,$0,$18
//this is a subroutine
delay:
	dec r17						;decrement for 8 cycles
	brne delay					;loop for 8 cyles
	ldi r17, $2					;reset delay timer
	ret							;return
